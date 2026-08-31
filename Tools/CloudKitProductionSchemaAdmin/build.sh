#!/bin/bash

set -euo pipefail

tool_directory="$(cd "$(dirname "$0")" && pwd)"
repository_root="$(cd "$tool_directory/../.." && pwd)"
build_root="${KM_PRODUCTION_SCHEMA_BUILD_ROOT:-/private/tmp/KitchenMemoryProductionSchemaAdminBuild}"
archive="${KM_PRODUCTION_ARCHIVE:-}"
derived_data="$build_root/DerivedData"
app="$build_root/CloudKitProductionSchemaAdmin.app"
products="$derived_data/Build/Products/Develop"
framework="$products/KitchenKit.framework"
profile="$archive/Products/Applications/KitchenMemory.app/Contents/embedded.provisionprofile"
executable="$app/Contents/MacOS/CloudKitProductionSchemaAdmin"

if [[ -z "$archive" || ! -f "$profile" ]]; then
  echo "Set KM_PRODUCTION_ARCHIVE to the reviewed macOS acceptance archive." >&2
  exit 64
fi

xcodebuild build \
  -quiet \
  -project "$repository_root/KitchenMemory.xcodeproj" \
  -scheme KitchenMemory \
  -configuration Develop \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data"

if [[ ! -d "$framework" ]]; then
  echo "The Develop KitchenKit framework was not produced." >&2
  exit 1
fi

mkdir -p "$app/Contents/MacOS" "$app/Contents/Frameworks"
cp "$tool_directory/Info.plist" "$app/Contents/Info.plist"
cp "$profile" "$app/Contents/embedded.provisionprofile"
ditto "$framework" "$app/Contents/Frameworks/KitchenKit.framework"

sdk="$(xcrun --sdk macosx --show-sdk-path)"
xcrun swiftc \
  -swift-version 6 \
  -parse-as-library \
  -target arm64-apple-macos26.0 \
  -sdk "$sdk" \
  -F "$products" \
  -framework KitchenKit \
  -framework CoreData \
  -framework SwiftData \
  -Xlinker -rpath \
  -Xlinker '@executable_path/../Frameworks' \
  "$tool_directory/Sources/main.swift" \
  -o "$executable"

identity="${KM_PRODUCTION_SCHEMA_SIGNING_IDENTITY:-}"
if [[ -z "$identity" ]]; then
  identity="$(security find-identity -v -p codesigning | awk -F '"' '/Apple Development/ { print $2; exit }')"
fi
if [[ -z "$identity" ]]; then
  echo "Set KM_PRODUCTION_SCHEMA_SIGNING_IDENTITY to an Apple Development identity." >&2
  exit 1
fi

codesign --force --sign "$identity" --timestamp=none \
  "$app/Contents/Frameworks/KitchenKit.framework"
codesign --force --sign "$identity" --timestamp=none \
  --entitlements "$tool_directory/ProductionDevelopment.entitlements" \
  "$app"
codesign --verify --deep --strict "$app"

echo "$app"
