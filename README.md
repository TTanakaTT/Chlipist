# chlips

chlips is a macOS clipboard history app inspired by the Windows **Win + V** experience.

## Features

- Stores up to 50 copied text entries
- Persists history in `Application Support/chlips/clipboard-history.json` for each user
- Shows a floating history panel near the mouse cursor with **⌘⇧V**
- Automatically pastes the selected item back into the app that was previously focused
- Displays shortcut badges for the top 10 entries with **1-9 / 0**
- Lets you open the history panel or clear history from the menu bar icon

## Requirements

- macOS 13 Ventura or later
- No Apple Developer account required for local builds

## Build

### Build in Xcode

1. Open `chlips.xcodeproj` in Xcode 15 or later
2. Select the `chlips` target
3. Build with **Product > Build** (⌘B)
4. Run with **Product > Run** (⌘R)

Code signing is already disabled for local builds.

### Build from the command line

```bash
xcodebuild -project chlips.xcodeproj \
           -scheme chlips \
           -configuration Release \
           -derivedDataPath ./.build \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO \
           build
```

The app bundle is generated in `./.build/Build/Products/Release`.

```bash
rsync -a ./.build/Build/Products/Release/chlips.app /Applications
```

## First Launch

After launching the app, grant the following permissions:

1. **Accessibility** — required to simulate ⌘V in other apps
   Add **chlips** in **System Settings > Privacy & Security > Accessibility**.
   The app prompts for this automatically on first launch.

2. **Launch at Login** — enabled automatically on first launch. You can turn it off later from the menu bar item **Launch at Login**.

> **Note:** The global hotkey (**⌘⇧V**) uses the Carbon API, so opening the history panel does not require Accessibility permission. Only paste simulation requires it.

## History Storage

- Clipboard history is stored in memory and on disk for the current user.
- The storage path is `~/Library/Application Support/chlips/clipboard-history.json`.
- The app limits file and directory permissions to the current user, but the stored history is plain text.
- The file may be included in backups such as Time Machine, so handle sensitive clipboard data accordingly.
- Choosing **Clear History** removes both the in-memory and persisted history.

## Project Structure

```text
chlips/
├── chlips.xcodeproj/
│   └── project.pbxproj
└── chlips/
    ├── main.swift
    ├── AppDelegate.swift
    ├── ClipboardManager.swift
    ├── HotKeyManager.swift
    ├── ClipboardHistoryWindowController.swift
    ├── Info.plist
    ├── chlips.entitlements
    └── Assets.xcassets/
```

## License

Sample code for personal use.
