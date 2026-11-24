#!/bin/zsh
# Prepares a release of AZ Itqan for GitHub:
#   ./release.sh 1.2.0 "إيه الجديد في النسخة دي"
# Produces dist/AZ-Itqan-<version>.zip and dist/version.json — upload BOTH to a new GitHub release
# tagged v<version> (github.com/<repo>/releases/new). The app checks the latest release's version.json.
set -e
cd "$(dirname "$0")"
VERSION="$1"; NOTES="$2"
[[ -z "$VERSION" || -z "$NOTES" ]] && { echo 'Usage: ./release.sh 1.2.0 "notes"'; exit 1; }
source ./release.conf
[[ -z "$GITHUB_REPO" ]] && { echo "Set GITHUB_REPO in release.conf first (username/repo)."; exit 1; }

PLIST=Resources/Info.plist
BUILD=$(( $(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" $PLIST) + 1 ))
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" $PLIST
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" $PLIST

./build.sh
ZIP="AZ-Itqan-$VERSION.zip"
rm -f "dist/$ZIP"
ditto -c -k --keepParent "dist/AZ Itqan.app" "dist/$ZIP"

python3 - "$VERSION" "$NOTES" "https://github.com/$GITHUB_REPO/releases/download/v$VERSION/$ZIP" > dist/version.json <<'PY'
import json, sys
print(json.dumps({"version": sys.argv[1], "notes": sys.argv[2], "url": sys.argv[3]}, ensure_ascii=False))
PY

echo
echo "✓ جاهز: dist/$ZIP  +  dist/version.json"
echo "١) افتح https://github.com/$GITHUB_REPO/releases/new"
echo "٢) Tag: v$VERSION   ·   Title: AZ Itqan $VERSION"
echo "٣) اسحب الملفين dist/$ZIP و dist/version.json في خانة الملفات، واكتب إيه الجديد، واضغط Publish release"
