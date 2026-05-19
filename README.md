# CleanX

Native macOS screenshot app inspired by [CleanShot X](https://cleanshot.com/). Menu-bar utility built in Swift, AppKit, SwiftUI on top of ScreenCaptureKit.

**Version:** 1.0.0 · **Requires:** macOS 14+

## Features

- **Capture** — area, window, fullscreen. Multi-monitor.
- **Quick Access overlay** — bottom-left floating thumbnail, hover reveals Copy / Save / Edit / Cloud / Pin / Close. Auto-dismiss.
- **Annotation editor** — arrow, rectangle, ellipse, highlight, text, blur (CIPixellate). Color picker, stroke slider, undo, copy / save.
- **Recents panel** — horizontal carousel of past captures (60 max). Right-click for Open / Copy / Save As / Reveal / Delete. Mouse-wheel scroll, drag-out to any app.
- **Drag-out** — drop screenshots into Finder, browsers, chat apps, terminals as real files.
- **Global hotkeys** — fully rebindable. Defaults `⌘⌥⇧2/3/4/5/6`.
- **Settings** — sidebar nav (General / Capture / Shortcuts / About). PNG/JPEG with quality slider, save folder, copy-on-capture, save-on-capture, Dock visibility.
- **Stable code signing** — self-signed identity script so screen recording TCC permission survives rebuilds.

## Build

```bash
./scripts/build.sh
open .build/CleanX.app
```

First launch will request **Screen Recording** permission. Approve in System Settings → Privacy & Security → Screen Recording, then relaunch.

### One-time: stable signing identity (recommended)

```bash
./scripts/create-signing-cert.sh
```

Creates a self-signed `CleanX Developer` cert in your login keychain. Without it, every rebuild changes the code hash and macOS re-prompts for permission.

## Default hotkeys

| Action             | Hotkey  |
|--------------------|---------|
| Capture area       | ⌘⌥⇧2    |
| Capture window     | ⌘⌥⇧3    |
| Capture fullscreen | ⌘⌥⇧4    |
| Open last capture  | ⌘⌥⇧5    |
| Toggle Recents     | ⌘⌥⇧6    |

Rebindable in Settings → Shortcuts.

## Project layout

```
Package.swift
Info.plist
AppIcon.icns
scripts/
  build.sh                 SPM build + .app assembly + codesign
  make-icon.swift          Programmatic CoreGraphics icon generator
  create-signing-cert.sh   One-shot stable self-signed identity
Sources/CleanX/
  App/                     Entry point, AppDelegate, menu bar
  Capture/                 ScreenCaptureKit, area / window pickers
  Editor/                  Annotation model, canvas, renderer
  Hotkeys/                 Carbon RegisterEventHotKey wrapper
  Storage/                 File save, clipboard, drag, last capture
  Permissions/             Screen Recording TCC
  QuickAccess/             Post-capture overlay
  Recents/                 Recents store, horizontal carousel
  Settings/                Preferences + SwiftUI UI
```

## Distribution

For shipping to others (Apple Developer ID required):

```bash
codesign --force --options runtime --sign "Developer ID Application: YOUR NAME (TEAMID)" .build/CleanX.app
xcrun notarytool submit CleanX.zip --wait
xcrun stapler staple .build/CleanX.app
```

## Not yet built

- Scrolling capture · Screen recording (mp4/gif) · Webcam · OCR · Cloud upload backend · Self-timer · Hide desktop · Sparkle auto-update

## License

MIT.
