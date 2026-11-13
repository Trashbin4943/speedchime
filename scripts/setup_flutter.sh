#!/usr/bin/env bash
# Installs the Flutter SDK (stable) into ~/flutter if missing, then fetches deps.
# Used by cloud sessions / fresh Linux machines. macOS devs: use your own install.
set -euo pipefail
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"
if ! command -v flutter >/dev/null 2>&1 && [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
flutter config --no-analytics >/dev/null
flutter --version
cd "$(dirname "$0")/.."
flutter pub get
