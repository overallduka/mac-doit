# Mac Do It (repo: mac-doit, folder: mac-doit-todo)

Menu bar todo app for macOS, themed on Shia LaBeouf's "JUST DO IT" meme.
Native Swift + SwiftUI, compiled with plain `swiftc` (no Xcode project, no dependencies). macOS 14+.

## Features (keep them working)
- Menu bar item: Shia's face (colored, round) + count of pending tasks (all days).
- Click → popover: add tasks (title), check/uncheck, delete on hover, click a task to expand its notes (editable).
- Today's tasks on top (done ones sink). Unfinished tasks from earlier days below under
  "YESTERDAY YOU SAID TOMORROW" with a 🔥 age badge (`Nd`) that gets redder with age.
- Checking a task → random meme GIF overlay + emoji burst + "do it" sound.
- Popover is resizable (grip bottom-right); size saved in UserDefaults (`width`/`height`).
- Every change auto-saves to `~/Library/Application Support/MacDoIt/todos.json` (ISO dates, pretty JSON).

## Layout
- `Sources/Store.swift` — `Todo` model, day buckets (`today`, `older`, `days`), actions, JSON persistence.
- `Sources/App.swift` — entry point, status item, popover.
- `Sources/Views.swift` — all SwiftUI views, meme overlay, sound.
- `Resources/` — `face.png` (menu bar icon), `doit.gif`, `yesyoucan.gif` (add a gif + list it in `memes` in Views.swift), `doit.mp3`.
- `Tests/main.swift` — Store self-check (preconditions).
- `doit.sh` — build/run/test/release. `Info.plist` — bundle info (`LSUIElement`: no Dock icon).

## Workflow
- After ANY code change: `./doit.sh` (builds, kills the old app, relaunches it). The user expects to see changes live.
- If you touch Store logic: `./doit.sh test`.
- Keep it simple (KISS/YAGNI): few files, no dependencies, no Xcode project.

## Deploy (when the user says "deploy"/"release")
1. `./doit.sh test` and `./doit.sh` (must build & run).
2. Commit everything with a clear message, on `main`.
3. Pick next version from `git tag --sort=-v:refname | head -1` (patch for fixes, minor for features).
4. `./doit.sh release X.Y.Z` → universal (arm64+x86_64) build, zip, tag, push, GitHub release with `build/MacDoIt.zip`.
5. Give the user the release URL.
