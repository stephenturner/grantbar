#!/bin/bash
set -e

APP_NAME="GrantBar"
VERSION="${1:-$(cat VERSION)}"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
STAGING="dist-staging"

echo "==> Building app bundle..."
bash build.sh

echo "==> Staging DMG contents..."
rm -rf "$STAGING"
mkdir "$STAGING"
cp -r "$APP_NAME.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating DMG..."
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -o "$DMG_NAME"

rm -rf "$STAGING"

echo ""
echo "Done: $DMG_NAME"
