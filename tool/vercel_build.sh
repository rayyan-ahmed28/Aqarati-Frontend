#!/usr/bin/env bash
# Vercel build step: installs the pinned Flutter SDK, then builds the Flutter web app in the
# current directory into build/web. Extra arguments go to `flutter build web`.
#
# Used by vercel.json (customer app, repo root) and admin_web/vercel.json (admin console).
# Locally you can point FLUTTER_HOME at an existing SDK to skip the download.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.7}"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter-$FLUTTER_VERSION}"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  # The Flutter tool needs unzip to unpack the Dart and web SDKs; the Vercel image may lack it.
  if ! command -v unzip >/dev/null 2>&1; then
    dnf install -y unzip >/dev/null
  fi
  echo "Installing Flutter $FLUTTER_VERSION"
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
flutter config --no-analytics >/dev/null
flutter --version
flutter pub get
flutter build web --release "$@"
