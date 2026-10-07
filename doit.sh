#!/bin/bash
# Mac Do It — build & run, test, release.
#   ./doit.sh              build + (re)start the app
#   ./doit.sh test         run the Store self-check
#   ./doit.sh release 1.2.0  universal build, tag, push, GitHub release
set -euo pipefail
cd "$(dirname "$0")"
APP=build/MacDoIt.app

build() {  # args: architectures
  rm -rf "$APP"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
  local bins=()
  for arch in "$@"; do
    swiftc -O -swift-version 5 -target "$arch-apple-macos14.0" Sources/*.swift -o "build/MacDoIt-$arch"
    bins+=("build/MacDoIt-$arch")
  done
  lipo -create "${bins[@]}" -output "$APP/Contents/MacOS/MacDoIt"
  cp Info.plist "$APP/Contents/"
  cp Resources/* "$APP/Contents/Resources/"
  plutil -replace CFBundleShortVersionString -string "${VERSION:-dev}" "$APP/Contents/Info.plist"
  codesign --force -s - "$APP"
}

case "${1:-run}" in
  run)
    build "$(uname -m)"
    pkill -x MacDoIt && sleep 0.5 || true
    open "$APP"
    echo "🔥 Mac Do It is running. JUST DO IT."
    ;;
  test)
    mkdir -p build
    swiftc -swift-version 5 Sources/Store.swift Tests/main.swift -o build/test
    build/test
    ;;
  release)
    VERSION="${2:?usage: ./doit.sh release 1.2.0}"
    git diff --quiet HEAD || { echo "Commit your changes first."; exit 1; }
    "$0" test
    VERSION=$VERSION build arm64 x86_64
    (cd build && rm -f MacDoIt.zip && ditto -c -k --keepParent MacDoIt.app MacDoIt.zip)
    git tag "v$VERSION"
    git push origin HEAD --tags
    gh release create "v$VERSION" build/MacDoIt.zip --title "Mac Do It v$VERSION" --generate-notes
    ;;
  *) sed -n '2,5p' "$0"; exit 1 ;;
esac
