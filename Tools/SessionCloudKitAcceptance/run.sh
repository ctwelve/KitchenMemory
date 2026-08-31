#!/bin/bash

set -euo pipefail

if [[ $# -lt 2 || "$1" != "--replica-root" ]]; then
  echo "usage: run.sh --replica-root /private/tmp/KitchenMemorySessionAcceptance-REPLICA [harness arguments]" >&2
  exit 64
fi

replica_root="$2"
shift 2
case "$replica_root" in
  /private/tmp/KitchenMemorySessionAcceptance-*) ;;
  *)
    echo "replica root must be a dedicated /private/tmp/KitchenMemorySessionAcceptance-* path" >&2
    exit 64
    ;;
esac

tool_directory="$(cd "$(dirname "$0")" && pwd)"
build_root="${KM_ACCEPTANCE_BUILD_ROOT:-/private/tmp/KitchenMemorySessionAcceptanceBuild}"
app="${KM_ACCEPTANCE_APP:-$build_root/SessionCloudKitAcceptance.app}"
executable="$app/Contents/MacOS/SessionCloudKitAcceptance"

if [[ ! -x "$executable" ]]; then
  "$tool_directory/build.sh"
fi

mkdir -p "$replica_root"
CFFIXED_USER_HOME="$replica_root" \
KM_ACCEPTANCE_DISPOSABLE_ROOT="$replica_root" \
KM_ACCEPTANCE_REPLICA="${replica_root##*/}" \
  "$executable" "$@"
