#!/bin/bash

set -euo pipefail

tool_directory="$(cd "$(dirname "$0")" && pwd)"
repository_root="$(cd "$tool_directory/../.." && pwd)"
build_root="${KM_ACCEPTANCE_IOS_BUILD_ROOT:-/private/tmp/KitchenMemorySessionAcceptanceIOSBuild}"
derived_data="$build_root/DerivedData"
app="$build_root/SessionCloudKitAcceptance.app"
products="$derived_data/Build/Products/Develop-iphoneos"
framework="$products/KitchenKit.framework"
product_app="$products/KitchenMemory.app"
executable="$app/SessionCloudKitAcceptance"

xcodebuild build \
  -quiet \
  -project "$repository_root/KitchenMemory.xcodeproj" \
  -scheme KitchenMemory \
  -configuration Develop \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$derived_data"

if [[ ! -d "$framework" || ! -f "$product_app/embedded.mobileprovision" ]]; then
  echo "The signed Kitchen Memory iPhone Develop products were not produced." >&2
  exit 1
fi

mkdir -p "$app/Frameworks"
cp "$tool_directory/Info-iOS.plist" "$app/Info.plist"
cp "$product_app/embedded.mobileprovision" "$app/embedded.mobileprovision"
ditto "$framework" "$app/Frameworks/KitchenKit.framework"

sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun --sdk iphoneos swiftc \
  -swift-version 6 \
  -parse-as-library \
  -enable-testing \
  -target arm64-apple-ios26.0 \
  -sdk "$sdk" \
  -F "$products" \
  -framework KitchenKit \
  -framework CoreData \
  -framework SwiftData \
  -Xlinker -rpath \
  -Xlinker '@executable_path/Frameworks' \
  "$tool_directory"/Sources/*.swift \
  -o "$executable"

identity="${KM_ACCEPTANCE_SIGNING_IDENTITY:-}"
if [[ -z "$identity" ]]; then
  identity="$(security find-identity -v -p codesigning | awk -F '"' '/Apple Development/ { print $2; exit }')"
fi
if [[ -z "$identity" ]]; then
  echo "Set KM_ACCEPTANCE_SIGNING_IDENTITY to an Apple Development identity." >&2
  exit 1
fi

codesign --force --sign "$identity" --timestamp=none \
  "$app/Frameworks/KitchenKit.framework"
codesign --force --sign "$identity" --timestamp=none \
  --entitlements "$tool_directory/SessionCloudKitAcceptance-iOS.entitlements" \
  "$app"
codesign --verify --deep --strict "$app"

echo "$app"
