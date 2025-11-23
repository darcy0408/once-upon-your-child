#!/usr/bin/env bash
set -euo pipefail

# Install Flutter (stable channel) into $HOME/flutter if not already present
FLUTTER_ROOT="$HOME/flutter"
if [ ! -d "$FLUTTER_ROOT" ]; then
  git clone -b stable https://github.com/flutter/flutter.git --depth 1 "$FLUTTER_ROOT"
fi

# Add flutter to PATH for this build
export PATH="$FLUTTER_ROOT/bin:$PATH"

# Ensure web tooling is enabled and precached
flutter --version
flutter config --enable-web
flutter precache --web
