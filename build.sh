#!/bin/bash
# Builds Rezodoro.app.
#
#   ./build.sh            release build for this Mac, ad-hoc signed
#   ./build.sh debug      debug build, ad-hoc signed
#   ./build.sh appstore   universal (Apple silicon + Intel) build, signed for
#                         the Mac App Store and packaged as Rezodoro.pkg.
#                         Needs these environment variables:
#                           TEAM_ID              your 10-character Apple team ID
#                           APP_IDENTITY         e.g. "Apple Distribution: Name (TEAMID)"
#                           INSTALLER_IDENTITY   e.g. "3rd Party Mac Developer Installer: Name (TEAMID)"
#                           PROVISIONING_PROFILE path to the Mac App Store .provisionprofile
set -euo pipefail

cd "$(dirname "$0")"

MODE="${1:-release}"
APP_NAME="Rezodoro"
SRC="Sources/${APP_NAME}"
APP_BUNDLE=".build/${APP_NAME}.app"
ENTITLEMENTS="${SRC}/${APP_NAME}.entitlements"

case "${MODE}" in
  debug) CONFIG=debug ;;
  release | appstore) CONFIG=release ;;
  *) echo "Unknown mode '${MODE}' (use release, debug or appstore)" >&2; exit 1 ;;
esac

if [ "${MODE}" = appstore ]; then
  : "${TEAM_ID:?set TEAM_ID}" "${APP_IDENTITY:?set APP_IDENTITY}"
  : "${INSTALLER_IDENTITY:?set INSTALLER_IDENTITY}" "${PROVISIONING_PROFILE:?set PROVISIONING_PROFILE}"
fi

echo "Building ${APP_NAME} (${MODE})..."
if [ "${MODE}" = appstore ]; then
  BIN_PATH=".build/${APP_NAME}-universal"
  ARCH_BINS=()
  for ARCH in arm64 x86_64; do
    SCRATCH=".build/${ARCH}"
    swift build -c release --triple "${ARCH}-apple-macosx14.0" --scratch-path "${SCRATCH}"
    ARCH_BINS+=("$(swift build -c release --triple "${ARCH}-apple-macosx14.0" --scratch-path "${SCRATCH}" --show-bin-path)/${APP_NAME}")
  done
  lipo -create "${ARCH_BINS[@]}" -output "${BIN_PATH}"
else
  swift build -c "${CONFIG}"
  BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)/${APP_NAME}"
fi

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${SRC}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
cp "${SRC}/Resources/AppIcon.icns" \
   "${SRC}/Resources/MenuBarIcon.png" \
   "${SRC}/Resources/PrivacyInfo.xcprivacy" \
   "${SRC}/Resources/container-migration.plist" \
   "${APP_BUNDLE}/Contents/Resources/"

if [ "${MODE}" = appstore ]; then
  cp "${PROVISIONING_PROFILE}" "${APP_BUNDLE}/Contents/embedded.provisionprofile"

  # The App Store needs the app and team identifiers in the signature,
  # matching the provisioning profile (Xcode normally adds these).
  BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${SRC}/Info.plist")"
  SIGNED_ENTITLEMENTS=".build/${APP_NAME}.appstore.entitlements"
  cp "${ENTITLEMENTS}" "${SIGNED_ENTITLEMENTS}"
  /usr/libexec/PlistBuddy \
    -c "Add :com.apple.application-identifier string ${TEAM_ID}.${BUNDLE_ID}" \
    -c "Add :com.apple.developer.team-identifier string ${TEAM_ID}" \
    "${SIGNED_ENTITLEMENTS}"

  codesign --force --options runtime --timestamp --sign "${APP_IDENTITY}" \
    --entitlements "${SIGNED_ENTITLEMENTS}" "${APP_BUNDLE}"
  codesign --verify --strict --verbose=2 "${APP_BUNDLE}"

  productbuild --component "${APP_BUNDLE}" /Applications \
    --sign "${INSTALLER_IDENTITY}" ".build/${APP_NAME}.pkg"
  echo "App Store package created at .build/${APP_NAME}.pkg"
  echo "Upload it with the Transporter app, or: xcrun altool --upload-app -t macos -f .build/${APP_NAME}.pkg ..."
else
  # Ad-hoc signed (free, no Apple Developer account) but with the same
  # sandbox entitlements as the App Store build, so it behaves the same.
  codesign --force --sign - --entitlements "${ENTITLEMENTS}" "${APP_BUNDLE}"
  echo "App bundle created at ${APP_BUNDLE}"
  echo "Run with: open '${APP_BUNDLE}'"
fi
