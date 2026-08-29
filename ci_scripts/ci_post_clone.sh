#!/bin/sh

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: GPL-3.0-only

set -eu

repository_path=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

# Exercise the repository-owned contract through its dependency-free Ruby entry
# point in the same way locally and in Xcode Cloud.
ruby "$repository_path/Tools/Tests/check_release_version_test.rb"
ruby "$repository_path/Tools/Tests/check_project_structure_test.rb"
ruby "$repository_path/Tools/Tests/check_software_inventory_test.rb"

# Keep the native target split, automatic plans, minimal KitchenKit scheme,
# destinations, and cross-platform UI-test host selection synchronized.
ruby "$repository_path/Tools/check-project-structure.rb"

# Keep the reviewed SPDX inventory synchronized with SwiftPM pins and the
# marketing version before package code or executable plugins run.
ruby "$repository_path/Tools/check-software-inventory.rb"

# Branch and pull-request actions have no tag and pass without a release check.
# Archives require an immutable tag that matches the version committed in Xcode.
ruby "$repository_path/Tools/check-release-version.rb"

# Disable fingerprint validation for pinned package dependencies. This tradeoff
# enables SwiftLint in Xcode Cloud's noninteractive build environment.
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

# Xcode's package-validation preference key deliberately contains this typo.
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
