#!/bin/sh

#  ci_post_clone.sh
#  KitchenMemory
#
#  Created by Justin Croonenberghs on 8/20/26.
#

set -eu

repository_path=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

# Exercise the repository-owned contract through its dependency-free Ruby entry
# point in the same way locally and in Xcode Cloud.
ruby "$repository_path/Tools/Tests/check_release_version_test.rb"

# Branch and pull-request actions have no tag and pass without a release check.
# Archives require an immutable tag that matches the version committed in Xcode.
ruby "$repository_path/Tools/check-release-version.rb"

# Disable fingerprint validation for pinned package dependencies. This tradeoff
# enables SwiftLint in Xcode Cloud's noninteractive build environment.
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

# Xcode's package-validation preference key deliberately contains this typo.
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
