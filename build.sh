#!/bin/zsh
# Builds "AZ Itqan.app" into dist/ (and installs it to /Applications with --install).
set -e
cd "$(dirname "$0")"
swift build -c release
.build/release/AZSalah --make-icon Resources/icon-1024.png
APP="dist/AZ Itqan.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -R Resources/adhan "$APP/Contents/Resources/adhan"
cp -R Resources/fonts "$APP/Contents/Resources/fonts"   # Amiri Quran for the share cards
cp .build/release/AZSalah "$APP/Contents/MacOS/AZSalah"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Update feed: the latest GitHub release's version.json (see release.sh / release.conf).
source ./release.conf 2>/dev/null || true
FEED=""
[[ -n "$GITHUB_REPO" ]] && FEED="https://github.com/$GITHUB_REPO/releases/latest/download/version.json"
/usr/libexec/PlistBuddy -c "Add :AZUpdateFeed string $FEED" "$APP/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :AZUpdateFeed $FEED" "$APP/Contents/Info.plist"

ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) Resources/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP"
echo "Built: $APP"

if [[ "$1" == "--install" ]]; then
  pkill -x AZSalah 2>/dev/null || true
  # Older builds were called "AZ Salah"; replace them with the renamed app.
  for old in "/Applications/AZ Salah.app" "/Applications/AZ Itqan.app"; do
    [[ -d "$old" ]] && rm -rf "$old"
  done
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/AZ Itqan.app"
fi
