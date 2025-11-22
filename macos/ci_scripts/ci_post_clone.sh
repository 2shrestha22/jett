#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# The default execution directory of this script is the ci_scripts directory.
cd $CI_PRIMARY_REPOSITORY_PATH # change working directory to the root of your cloned repo.

# Extract Flutter version from pubspec.yaml
FLUTTER_VERSION=$(grep -A 5 "environment:" pubspec.yaml | grep "flutter:" | awk '{print $2}')
echo "Flutter version from pubspec.yaml: $FLUTTER_VERSION"

if [ -z "$FLUTTER_VERSION" ]; then
  echo "Error: Could not extract Flutter version from pubspec.yaml"
  exit 1
fi

echo "Downloading Flutter..."
curl -o flutter.zip https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_$FLUTTER_VERSION-stable.zip

echo "Extracting Flutter..."
unzip -q flutter.zip -d $HOME
rm flutter.zip

export PATH="$PATH:$HOME/flutter/bin"

# Install CocoaPods using Homebrew.
echo "Installing CocoaPods..."
HOMEBREW_NO_AUTO_UPDATE=1 # disable homebrew's automatic updates.
brew install cocoapods

# Install Flutter artifacts for iOS (--ios), or macOS (--macos) platforms.
echo "Pre-caching Flutter artifacts..."
flutter precache --macos

# Configure macOS app.
echo "Configuring macOS app..."
flutter build macos --config-only

exit 0
