#!/bin/zsh
# Builds the Debug app signed with the local "Notch Local Signing" certificate,
# so macOS keeps Notch's permissions across rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Notch Local Signing" DEVELOPMENT_TEAM="" \
  OTHER_CODE_SIGN_FLAGS="--timestamp=none" ENABLE_DEBUG_DYLIB=NO ENABLE_HARDENED_RUNTIME=NO \
  build
