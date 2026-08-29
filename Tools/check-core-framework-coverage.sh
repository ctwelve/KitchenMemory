#!/bin/sh

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <result-bundle.xcresult>" >&2
  exit 2
fi

RESULT_BUNDLE=$1
SCRIPT_DIRECTORY=$(CDPATH= cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIRECTORY")
KITCHEN_KIT_DIRECTORY="$PROJECT_ROOT/KitchenKit"
PERSISTENCE_DIRECTORY="$KITCHEN_KIT_DIRECTORY/Persistence"
PERSISTENCE_RUNTIME_ADAPTER="$PERSISTENCE_DIRECTORY/Cloud/PersonalCloudStatusMonitor.swift"

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
  "$KITCHEN_KIT_DIRECTORY" \
  "$PROJECT_ROOT/KitchenKitTests" \
  "$PROJECT_ROOT/Configurations" \
  "$PROJECT_ROOT/KitchenMemory.xcodeproj/project.pbxproj" \
  "$PROJECT_ROOT/KitchenMemory.xcodeproj/xcshareddata/xcschemes/KitchenKit.xcscheme" \
  "$PROJECT_ROOT/KitchenMemory.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" \
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
COVERAGE_FAILED=0
while IFS='|' read -r TARGET MODULE_DIRECTORY; do
  BUILD_TARGET=${TARGET%.framework}
  TARGET_MARKER="(in target '$BUILD_TARGET' from project 'KitchenMemory')"
  if ! TARGET_REPORT=$(
    xcrun xccov view --report --files-for-target "$TARGET" "$RESULT_BUNDLE"
  ); then
    echo "Coverage gate error: xccov could not inspect target $TARGET" >&2
    exit 2
  fi

  EXCLUDED_SOURCE=
  if [ "$TARGET" = "KitchenKit.framework" ]; then
    # This file is the narrow Apple-runtime bridge: it calls CKContainer and
    # translates ObjC notifications whose event type has no public initializer.
    # Its deterministic status reducer lives in PersonalCloudStatus.swift and
    # remains inside the exact business-logic gate.
    # Xcode may canonicalize /private/tmp to /tmp in coverage paths, so compare
    # the stable repository-relative suffix rather than the absolute spelling.
    EXCLUDED_SOURCE=${PERSISTENCE_RUNTIME_ADAPTER#"$PROJECT_ROOT"}
  fi

  if TARGET_COVERAGE=$(printf '%s\n' "$TARGET_REPORT" | awk \
    -v target="$TARGET" -v excluded="$EXCLUDED_SOURCE" '
      /^[[:space:]]*[0-9]+[[:space:]]+/ {
        count = $NF
        gsub(/^\(/, "", count)
        gsub(/\)$/, "", count)
        partCount = split(count, parts, "/")
        if (partCount != 2 || parts[1] !~ /^[0-9]+$/ || parts[2] !~ /^[0-9]+$/) {
          malformed = $NF
          next
        }
        if (excluded != "" && index($0, excluded)) {
          excludedLines += parts[2]
          next
        }
        fileCount++
        covered += parts[1]
        executable += parts[2]
      }

      END {
        if (fileCount == 0 || malformed != "" || executable == 0 || covered > executable) {
          printf "Coverage gate error: invalid line counts for %s: %s\n", \
            target, malformed > "/dev/stderr"
          exit 1
        }

        printf "%s: %d/%d business-logic executable lines covered", \
          target, covered, executable
        if (excludedLines > 0) {
          printf " (%d runtime-adapter lines excluded)", excludedLines
        }
        printf "\n"

        if (covered != executable) {
          printf "Coverage gate error: %s has %d uncovered business-logic line(s)\n", \
            target, executable - covered > "/dev/stderr"
          exit 1
        }
      }
    ')
  then
    printf '%s\n' "$TARGET_COVERAGE"
  else
    printf '%s\n' "$TARGET_COVERAGE"
    COVERAGE_FAILED=1
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
KitchenKit.framework|$KITCHEN_KIT_DIRECTORY
EOF

if [ "$COVERAGE_FAILED" -ne 0 ]; then
  exit 1
fi
echo "KitchenKit business-logic coverage gate passed."
