#!/bin/sh

#  ci_post_clone.sh
#  KitchenMemory
#
#  Created by Justin Croonenberghs on 8/20/26.
#

set -e

# Disable fingerprint validation for pinned package dependencies. This tradeoff
# enables SwiftLint in Xcode Cloud's noninteractive build environment.
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

# Xcode's package-validation preference key deliberately contains this typo.
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
