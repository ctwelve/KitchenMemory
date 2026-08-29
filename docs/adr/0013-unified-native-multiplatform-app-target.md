# Unify the native application target

- Status: Accepted

Kitchen Memory uses one native multiplatform `KitchenMemory` application target
for iPhone, iPad, iOS Simulator, and Mac because the products currently share
their application entry point, composition, presentation, localization, and
starter content. Destination selection still produces separate native bundles
and archives: SDK- and configuration-conditional settings select distinct iOS
and macOS ordinary/testing entitlements and separate editor-friendly property
lists, keeping iOS launch and background declarations out of the Mac product;
platform filters compile the localized launch resources only for iOS. One
multiplatform hosted-test target, one UI-smoke target, one saved application
scheme, and one saved plan exercise that contract on both destinations;
`KitchenKit` and its exact coverage lane remain separate and unchanged.

This supersedes [ADR 0009](0009-separate-native-app-targets.md). Separate app
targets were useful while the platform packaging contracts were being learned,
but they duplicated one application contract and allowed configuration drift.
Reintroduce a platform app target only when it owns a genuinely independent
product, source boundary, or evolution need that platform filters and
conditional settings can no longer express clearly.
