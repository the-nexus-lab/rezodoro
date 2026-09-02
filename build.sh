#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP_NAME="Rezodoro"
APP_BUNDLE=".build/${APP_NAME}.app"

echo "Building ${APP_NAME} (${CONFIG})..."
swift build -c "${CONFIG}"

BIN_PATH=".build/${CONFIG}/${APP_NAME}"

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Sources/${APP_NAME}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# Sign the bundle so macOS can verify its identity (required for
# UserNotifications to register the app; an ad-hoc identity is free
# and doesn't need an Apple Developer account).
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "App bundle created at ${APP_BUNDLE}"
echo "Run with: open '${APP_BUNDLE}'"
