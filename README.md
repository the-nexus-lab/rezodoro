# Rezodoro

A tiny Pomodoro timer that lives in the macOS menu bar. No frills.

## Features

- Focus / short break / long break timer, running in the menu bar (Rezodoro
  logo + a countdown, e.g. `24:59`, while a session is active)
- All three interval lengths (and sessions-per-long-break) adjustable right in the dropdown
- Every completed or skipped session is auto-logged to
  `~/Library/Application Support/Rezodoro/sessions.csv`
- "Export Logs as CSV…" saves a copy of that log anywhere you like
- Every discrete action (start, pause, resume, skip, complete, reset,
  settings change, app launch/quit) is separately timestamped to
  `~/Library/Application Support/Rezodoro/events.jsonl` — a richer,
  background record for future usage analysis (idle gaps between
  sessions, skip/reset frequency, etc). Not shown in the CSV export.
- System notification when a session ends

## Build & run

```sh
./build.sh          # release build -> .build/Rezodoro.app
open .build/Rezodoro.app
```

Use `./build.sh debug` for a debug build instead.

### Install to /Applications (optional)

```sh
./build.sh
cp -R .build/Rezodoro.app /Applications/
```

Then launch it from Spotlight/Applications like any other app. To have it
start at login, add it in System Settings → General → Login Items.

## Notes

- It's a menu-bar-only app (no Dock icon) — quit it from the dropdown menu.
- App icon assets live in `Sources/Rezodoro/Resources/`:
  `AppIcon-source.png` is the original logo, `AppIcon.icns` is the compiled
  app icon (referenced by `Info.plist`'s `CFBundleIconFile`), and
  `MenuBarIcon.png` is a monochrome "template" silhouette derived from the
  logo for the menu bar status item (template images auto-adapt to
  light/dark menu bars). Regenerate `AppIcon.icns` with `iconutil` from a
  fresh `.iconset` if the source logo changes.
- Notification banners don't show the app icon — this is a macOS
  limitation for `LSUIElement` (menu-bar-only) apps, not fixable via
  Info.plist/codesign from here.
- CSV log format: `kind,started_at,ended_at,planned_minutes,actual_minutes,completed`
- Event log format (JSONL, one JSON object per line):
  `type, timestamp, sessionKind, plannedMinutes, remainingSeconds, settingName, settingValue`
  (fields are present only when relevant to that event type)

## License

MIT — see [LICENSE](LICENSE).
