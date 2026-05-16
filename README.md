# Chlipist

Chlipist is a macOS clipboard history app.

## Features

- Stores up to 50 copied text entries
- Shows a native history menu near the mouse cursor with **⌘⇧V**
- Automatically pastes the selected item back into the app
- Assigns **1-9 / 0** as keyboard shortcuts for the top 10 entries and groups older items under **More**
- Lets you open the history menu or clear history from the menu bar icon

## Build

### Build in Xcode

1. Open `Chlipist.xcodeproj`
2. Select the `Chlipist` target
3. Build with **Product > Build** (⌘B)
4. Run with **Product > Run** (⌘R)

Code signing is already disabled for local builds.

### Build from the command line

```bash
xcodebuild -project Chlipist.xcodeproj \
           -scheme Chlipist \
           -configuration Release \
           -derivedDataPath ./.build \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO \
           build
```

The app bundle is generated in `./.build/Build/Products/Release`.

```bash
rsync -av ./.build/Build/Products/Release/Chlipist.app /Applications
```

## Formatting and Linting

This repository uses the default `swift-format` rules via `make`.

```bash
make format
make lint
```

- `make format` rewrites Swift files in `Chlipist` and `ChlipistTests`.
- `make lint` checks the same paths with `swift-format lint --strict`.
- CI uses the same `make lint` target before test and build jobs.

`Makefile` invokes `xcrun swift-format`, so you need an Xcode toolchain that includes `swift-format`.

### Git Hook

To run the same formatting and linting checks before each commit, enable the repository-managed hook:

```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
```

The pre-commit hook runs `make format` and `make lint` for staged Swift files, then re-stages those files.

## GitHub Actions Artifacts

The GitHub Actions workflow re-signs the built app with an ad-hoc signature. This avoids the damaged-bundle state that can happen when `xcodebuild` runs with signing disabled on GitHub Actions.

The artifact is still not notarized, so macOS may ask you to trust the app on first launch. For personal use, that is expected.

If the downloaded app is blocked by quarantine, remove the attribute after copying the app to `/Applications`:

```bash
xattr -dr com.apple.quarantine /Applications/Chlipist.app
```

Depending on the macOS version, you can also use Finder's context menu or allow the app from **System Settings > Privacy & Security** after the first launch attempt.

## First Launch

After launching the app, grant the following permissions:

1. **Accessibility** — required to simulate ⌘V in other apps
   Add **Chlipist** in **System Settings > Privacy & Security > Accessibility**.
   The app prompts for this automatically on first launch.

2. **Launch at Login** — enabled automatically on first launch. You can turn it off later from the menu bar item **Launch at Login**.

> **Note:** The global hotkey (**⌘⇧V**) uses the Carbon API, so opening the history menu does not require Accessibility permission. Only paste simulation requires it.

## History Storage

- Clipboard history is stored in memory and on disk for the current user.
- Persisted clipboard history is encrypted at rest before it is written to disk.
- The encryption key is stored in the local login Keychain as a device-local item and is not intended to sync through iCloud Keychain.
- The app still limits file and directory permissions to the current user.
- The history storage directory and persisted history file are marked excluded from normal backups such as Time Machine.
- Clipboard history is still application-managed data, not the OS-managed transient clipboard itself.
- Choosing **Clear History** removes both the in-memory and persisted history.

## License

Sample code for personal use.

## next
- ui、履歴を表示→ペースト、app実行のたびにメニューのところで実行されていること、ショートカットで貼り付けられることがわかるように
- tooltip要らない