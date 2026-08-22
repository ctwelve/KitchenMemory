#!/bin/sh

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: GPL-3.0-only

set -eu

if [ "$#" -ne 0 ]; then
  echo "Usage: $0" >&2
  exit 2
fi

SCRIPT_DIRECTORY=$(CDPATH= cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIRECTORY")
COVERAGE_RUN_DIRECTORY=$(mktemp -d "/private/tmp/KitchenMemoryCoreCoverage.XXXXXX")
DERIVED_DATA_PATH="$COVERAGE_RUN_DIRECTORY/DerivedData"
RESULT_BUNDLE="$COVERAGE_RUN_DIRECTORY/Tests.xcresult"

echo "Coverage evidence directory: $COVERAGE_RUN_DIRECTORY"

DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
export DEVELOPER_DIR

xcodebuild test \
  -project "$PROJECT_ROOT/KitchenMemory.xcodeproj" \
  -scheme KitchenMemory \
  -testPlan KitchenMemory \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -skip-testing:KitchenMemoryUITests \
  CODE_SIGNING_ALLOWED=NO

"$SCRIPT_DIRECTORY/check-core-framework-coverage.sh" "$RESULT_BUNDLE"
