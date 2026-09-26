# Rezodoro

A tiny Pomodoro timer that lives in the macOS menu bar. No frills.

## Features

- Focus / short break / long break timer, running in the menu bar (Rezodoro
  logo + a countdown, e.g. `24:59`, while a session is active)
- All three interval lengths (and sessions-per-long-break) adjustable right in the dropdown
- A rotating message of the day above the countdown (list in
  `MessageOfTheDay.swift`; switch interval adjustable in 6-hour steps)
- Every completed or skipped session is auto-logged to
  `sessions.csv` in the app's sandbox container
  (`~/Library/Containers/com.rezodoro.app/Data/Library/Application Support/Rezodoro/`)
- "Export Logs as CSV…" saves a copy of that log anywhere you like
- Every discrete action (start, pause, resume, skip, complete, reset,
  settings change, app launch/quit) is separately timestamped to
  `events.jsonl` in the same folder — a richer,
  background record for future usage analysis (idle gaps between
  sessions, skip/reset frequency, etc). Not shown in the CSV export.
- System notification when a session ends (scheduled with the system up
  front, so it arrives on time even if the app is napping or the Mac just
  woke up); clicking it opens the dropdown
- Starting a session closes the dropdown
- History: a hoverable bar chart of focus time per day for the last 10 days,
  read from `sessions.csv`
- Liquid Glass look on macOS 26+ (glass dropdown and buttons), with the
  classic blurred-menu look on macOS 14–15
- Sandboxed and App Store ready; data never leaves the Mac

## Build & run

```sh
./build.sh          # release build -> .build/Rezodoro.app
open .build/Rezodoro.app
```

Use `./build.sh debug` for a debug build instead. Both are ad-hoc signed
with the same sandbox entitlements as the App Store build. On the first
sandboxed launch, macOS moves logs from older unsandboxed builds
(`~/Library/Application Support/Rezodoro/`) into the container
(`container-migration.plist`).

### Mac App Store

Needs an Apple Developer account, an "Apple Distribution" and a "3rd Party
Mac Developer Installer" certificate in the keychain, and a Mac App Store
provisioning profile for the bundle ID in `Info.plist` (`com.rezodoro.app`
— change it if that ID is taken). Then:

```sh
TEAM_ID=ABCDE12345 \
APP_IDENTITY="Apple Distribution: Your Name (ABCDE12345)" \
INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Your Name (ABCDE12345)" \
PROVISIONING_PROFILE=~/Downloads/Rezodoro.provisionprofile \
./build.sh appstore
```

This builds a universal (Apple silicon + Intel) binary, signs it and
writes `.build/Rezodoro.pkg`; upload that with the Transporter app. Bump
`CFBundleVersion` in `Info.plist` for every upload.

Requires macOS 14 or later. Builds with just the Command Line Tools — on
the macOS 27 SDK `@State` became a macro whose plugin only ships with
Xcode, so the code uses the `ViewState` alias (see `ContentView.swift`)
for the underlying property wrapper instead.

### Install to /Applications (optional)

```sh
./build.sh
cp -R .build/Rezodoro.app /Applications/
```

Then launch it from Spotlight/Applications like any other app. To have it
start at login, add it in System Settings → General → Login Items.

## Notes

- It's a menu-bar-only app (no Dock icon) — quit it from the dropdown menu.
- The menu bar item is a plain `NSStatusItem` with a custom glass panel
  (`MenuBarController.swift`) rather than SwiftUI's `MenuBarExtra`, because
  `MenuBarExtra` can't be opened or closed from code.
- App bundle files live in `Sources/Rezodoro/Resources/` and are copied
  into the .app by `build.sh` (not a SwiftPM resource bundle, whose lookup
  only works from this machine's `.build`): `AppIcon-source.png` is the
  original logo, `AppIcon.icns` the compiled app icon (referenced by
  `Info.plist`'s `CFBundleIconFile`), `MenuBarIcon.png` a monochrome
  "template" silhouette trimmed tight to the glyph so it centers with the
  countdown digits, plus `PrivacyInfo.xcprivacy` and
  `container-migration.plist`. Regenerate `AppIcon.icns` with `iconutil`
  from a fresh `.iconset` if the source logo changes.
- Notification banners don't show the app icon — this is a macOS
  limitation for `LSUIElement` (menu-bar-only) apps, not fixable via
  Info.plist/codesign from here.
- CSV log format: `kind,started_at,ended_at,planned_minutes,actual_minutes,completed`
- Event log format (JSONL, one JSON object per line):
  `type, timestamp, sessionKind, plannedMinutes, remainingSeconds, settingName, settingValue`
  (fields are present only when relevant to that event type)

## License

MIT — see [LICENSE](LICENSE).
