#!/bin/sh

#  ci_post_clone.sh
#  KitchenMemory
#
#  Created by Justin Croonenberghs on 8/20/26.
#

# Yes, there is a typo.
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
