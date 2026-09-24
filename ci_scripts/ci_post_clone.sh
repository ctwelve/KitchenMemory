#!/bin/sh

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

set -eu

repository_path=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

# Share the same repository contracts with local checks and GitHub Actions.
ruby "$repository_path/Tools/check-repository.rb"

# Disable fingerprint validation for pinned package dependencies. This tradeoff
# enables SwiftLint in Xcode Cloud's noninteractive build environment.
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

# Xcode's package-validation preference key deliberately contains this typo.
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
