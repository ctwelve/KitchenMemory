#!/bin/sh

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: GPL-3.0-only

set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <result-bundle.xcresult>" >&2
  exit 2
fi

RESULT_BUNDLE=$1
SCRIPT_DIRECTORY=$(CDPATH= cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIRECTORY")
DOMAIN_DIRECTORY="$PROJECT_ROOT/KitchenMemory/Modules/KitchenMemoryDomain"
IMPORT_DIRECTORY="$PROJECT_ROOT/KitchenMemory/Modules/KitchenMemoryImport"
PERSISTENCE_DIRECTORY="$PROJECT_ROOT/KitchenMemory/Modules/KitchenMemoryPersistence"

if [ ! -r "$RESULT_BUNDLE" ]; then
  echo "Coverage gate error: result bundle is not readable: $RESULT_BUNDLE" >&2
  exit 2
fi

# A mathematically perfect old report is still the wrong evidence. Read the
# action's embedded start time instead of trusting the xcresult wrapper's mtime:
# copying an old bundle refreshes the latter, and completion time cannot detect
# a source edit made while a long build/test action is still running.
if ! BUILD_RESULTS=$(
  xcrun xcresulttool get build-results --compact --path "$RESULT_BUNDLE"
); then
  echo "Coverage gate error: xcresulttool could not read build metadata" >&2
  exit 2
fi
if ! RESULT_START_TIME=$(
  printf '%s\n' "$BUILD_RESULTS" | plutil -extract startTime raw -o - -
); then
  echo "Coverage gate error: result bundle has no readable build start time" >&2
  exit 2
fi

# Include the test corpus and project membership metadata because either can
# change what was built or exercised without changing a framework source file.
if ! INPUT_TIMESTAMPS=$(find \
  "$DOMAIN_DIRECTORY" \
  "$IMPORT_DIRECTORY" \
  "$PERSISTENCE_DIRECTORY" \
  "$PROJECT_ROOT/KitchenMemoryTests" \
  "$PROJECT_ROOT/KitchenMemory.xcodeproj/project.pbxproj" \
  "$PROJECT_ROOT/KitchenMemory.xcodeproj/xcshareddata/xcschemes/KitchenMemory.xcscheme" \
  "$PROJECT_ROOT/KitchenMemory.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" \
  "$PROJECT_ROOT/KitchenMemory.xctestplan" \
  -type f -exec stat -f '%Fm %N' {} +); then
  echo "Coverage gate error: could not inventory coverage inputs" >&2
  exit 2
fi
NEWER_INPUTS=$(printf '%s\n' "$INPUT_TIMESTAMPS" | awk -v start="$RESULT_START_TIME" '
  $1 >= start {
    sub(/^[^ ]+ /, "")
    print
  }
')
if [ -n "$NEWER_INPUTS" ]; then
  echo "Coverage gate error: coverage inputs changed after the build began:" >&2
  printf '%s\n' "$NEWER_INPUTS" >&2
  exit 2
fi

if ! COVERAGE_REPORT=$(xcrun xccov view --report --only-targets "$RESULT_BUNDLE"); then
  echo "Coverage gate error: xccov could not read: $RESULT_BUNDLE" >&2
  exit 2
fi

# Exact aggregate counts cannot reveal a source file accidentally omitted from
# its framework target. The build log proves membership for declaration-only
# files, which xccov legitimately omits, while the per-target reports place each
# executable source in its expected coverage target.
if ! BUILD_LOG=$(
  xcrun xcresulttool get log --type build --path "$RESULT_BUNDLE"
); then
  echo "Coverage gate error: xcresulttool could not read the build log" >&2
  exit 2
fi
while IFS='|' read -r TARGET MODULE_DIRECTORY; do
  BUILD_TARGET=${TARGET%.framework}
  TARGET_MARKER="(in target '$BUILD_TARGET' from project 'KitchenMemory')"
  if ! TARGET_REPORT=$(
    xcrun xccov view --report --files-for-target "$TARGET" "$RESULT_BUNDLE"
  ); then
    echo "Coverage gate error: xccov could not inspect target $TARGET" >&2
    exit 2
  fi

  if ! MODULE_SOURCES=$(find "$MODULE_DIRECTORY" -type f -name '*.swift' -print); then
    echo "Coverage gate error: could not inventory sources for $TARGET" >&2
    exit 2
  fi
  if [ -z "$MODULE_SOURCES" ]; then
    echo "Coverage gate error: no Swift sources found for $TARGET" >&2
    exit 2
  fi

  while IFS= read -r SOURCE_PATH; do
    SOURCE_SUFFIX=${SOURCE_PATH#"$PROJECT_ROOT"}
    if ! printf '%s\n' "$BUILD_LOG" | awk \
      -v source="$SOURCE_SUFFIX" -v marker="$TARGET_MARKER" '
        index($0, "\"commandDetails\"") && index($0, source) && index($0, marker) {
          found = 1
        }
        END { exit found ? 0 : 1 }
      '
    then
      echo "Coverage gate error: $BUILD_TARGET did not compile source $SOURCE_SUFFIX" >&2
      exit 1
    fi
    if printf '%s\n' "$TARGET_REPORT" | grep -F -q "$SOURCE_SUFFIX"; then
      continue
    fi
    # A compiled file absent from xccov has no executable coverage regions.
    # Its target membership is still established by the fresh build log.
  done <<EOF
$MODULE_SOURCES
EOF
done <<EOF
KitchenMemoryDomain.framework|$DOMAIN_DIRECTORY
KitchenMemoryImport.framework|$IMPORT_DIRECTORY
KitchenMemoryPersistence.framework|$PERSISTENCE_DIRECTORY
EOF

printf '%s\n' "$COVERAGE_REPORT" | awk '
  BEGIN {
    order[1] = "KitchenMemoryDomain.framework"
    order[2] = "KitchenMemoryImport.framework"
    order[3] = "KitchenMemoryPersistence.framework"
    for (position = 1; position <= 3; position++) {
      wanted[order[position]] = 1
    }
  }

  $2 in wanted {
    target = $2
    count = $NF
    gsub(/^\(/, "", count)
    gsub(/\)$/, "", count)
    partCount = split(count, parts, "/")

    found[target]++
    if (partCount != 2 || parts[1] !~ /^[0-9]+$/ || parts[2] !~ /^[0-9]+$/) {
      malformed[target] = $NF
      next
    }
    covered[target] = parts[1] + 0
    executable[target] = parts[2] + 0
  }

  END {
    failed = 0
    for (position = 1; position <= 3; position++) {
      target = order[position]
      if (found[target] == 0) {
        print "Coverage gate error: missing target " target > "/dev/stderr"
        failed = 1
        continue
      }
      if (found[target] != 1) {
        print "Coverage gate error: duplicate target " target > "/dev/stderr"
        failed = 1
        continue
      }
      if (target in malformed || executable[target] == 0 || covered[target] > executable[target]) {
        print "Coverage gate error: invalid line counts for " target ": " malformed[target] \
          > "/dev/stderr"
        failed = 1
        continue
      }

      printf "%s: %d/%d executable lines covered\n", \
        target, covered[target], executable[target]
      if (covered[target] != executable[target]) {
        printf "Coverage gate error: %s has %d uncovered executable line(s)\n", \
          target, executable[target] - covered[target] > "/dev/stderr"
        failed = 1
      }
    }

    if (failed == 0) {
      print "Core framework coverage gate passed."
    }
    exit failed
  }
'
