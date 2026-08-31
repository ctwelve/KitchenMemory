#!/bin/bash

set -euo pipefail

build_root="${KM_PRODUCTION_SCHEMA_BUILD_ROOT:-/private/tmp/KitchenMemoryProductionSchemaAdminBuild}"
executable="$build_root/CloudKitProductionSchemaAdmin.app/Contents/MacOS/CloudKitProductionSchemaAdmin"
candidate="${1:-}"

if [[ ! "$candidate" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Usage: $0 <accepted-product-commit>" >&2
  exit 64
fi
if [[ ! -x "$executable" ]]; then
  echo "Build the Production schema administration tool first." >&2
  exit 1
fi

"$executable" initialize --candidate "$candidate"
