# Mac Do It 🔥

<p align="center"><img src="Resources/doit.gif" alt="Shia LaBeouf: JUST DO IT" width="420"></p>

> Don't let your dreams be dreams. **JUST DO IT.**

A tiny macOS menu bar todo list, powered by Shia LaBeouf's legendary motivational speech.

- Shia lives in your menu bar with the number of things you still haven't done.
- Click him: add tasks, check them off, click a task for notes.
- Every finished task gets you a **JUST DO IT** meme and sound.
- Tasks you didn't finish yesterday stay at the bottom with a 🔥 counter of how many days you've been ignoring them.
- Resizable popover; everything autosaves.

## Install

1. Download `MacDoIt.zip` from [Releases](../../releases/latest) and unzip.
2. Move `MacDoIt.app` to `/Applications`.
3. The app is not notarized, so the first time run: `xattr -cr /Applications/MacDoIt.app` (or right-click → Open).

Requires macOS 14+. Want it on login? System Settings → General → Login Items → add Mac Do It.

## Build from source

Needs Xcode Command Line Tools (`xcode-select --install`).

```sh
./doit.sh        # build + run
./doit.sh test   # self-check
```

Your tasks are stored in `~/Library/Application Support/MacDoIt/todos.json`.

## Credits

Meme from *#INTRODUCTIONS* (2015) — written by Joshua Parker, performed by Shia LaBeouf.
GIFs via GIPHY, sound via MyInstants. Fan project, not affiliated with anyone.
