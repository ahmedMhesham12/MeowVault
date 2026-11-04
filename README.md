# MeowVault

![MeowVault banner](assets/banner.png)

Fast native macOS clipboard history in the menu bar.

## Features

- Menu bar app with no Dock icon
- Global shortcut: `Cmd+Shift+V`
- Search clipboard history
- Smart groups: links, code, images, emails, text
- Pin important clips
- Keep pinned clips first
- Duplicate cleanup
- Quick preview
- Copy as plain text
- Text, link, and image clipboard support
- Compact PNG storage for copied images when possible
- Open-at-login toggle
- Local encrypted and compressed clipboard storage
- Restart retention setting: keep all clips or pinned clips only
- Configurable history limit
- Optional app password lock
- Light, dark, and system appearance

## Requirements

- macOS 14 or newer
- Xcode command line tools
- Swift 6.2 or newer

## Build

```bash
swift test
swift build -c release --arch x86_64 --arch arm64
```

## Package DMG

```bash
chmod +x scripts/package.sh
./scripts/package.sh
```

Output:

```text
dist/MeowVault.app
dist/MeowVault.dmg
```

## Local Data

MeowVault stores clipboard history locally under:

```text
~/Library/Application Support/MeowVault/
```

The clipboard database is compressed, then encrypted as `clips.enc`. The local encryption key is generated per user in `storage.key` with `0600` permissions and is excluded from backups. The key sits next to the data, so this protects against casual file access and copies of `clips.enc` alone, not against other processes running as your user.

Clips that password managers mark as concealed, transient, or auto-generated (`org.nspasteboard.*`) are never saved.

In Settings, users can choose whether restart keeps all clips or only pinned clips. The history limit is also configurable, and pinned clips are kept first when the list is trimmed.

The optional app password locks the MeowVault window (stored as a salted PBKDF2-SHA256 hash). It is separate from storage encryption.

## Download

Download the latest DMG from GitHub Releases, or use the packaged DMG included in the repo:

```text
dist/MeowVault.dmg
```

Install by opening the DMG and dragging `MeowVault.app` to Applications.

## Uninstall

```bash
./scripts/uninstall.sh
```

Or manually:

```text
Quit MeowVault
Delete /Applications/MeowVault.app
Delete ~/Library/Application Support/MeowVault
```
