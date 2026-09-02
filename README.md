# Rezodoro

A tiny Pomodoro timer that lives in the macOS menu bar. No frills.

## Features

- Focus / short break / long break timer, running in the menu bar (e.g. `🍅 24:59`)
- All three interval lengths (and sessions-per-long-break) adjustable right in the dropdown
- Every completed or skipped session is auto-logged to
  `~/Library/Application Support/Rezodoro/sessions.csv`
- "Export Logs as CSV…" saves a copy of that log anywhere you like
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
- Log format: `kind,started_at,ended_at,planned_minutes,actual_minutes,completed`

## License

MIT — see [LICENSE](LICENSE).
