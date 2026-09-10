# Markmer

A native macOS Markdown reader with built-in Mermaid diagram rendering and a sidebar of recent files.

![Markmer icon](Markmer/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png)

## Features

- GitHub-flavoured Markdown with syntax-highlighted code blocks
- Mermaid diagrams rendered inline, themed for light and dark mode
- Sidebar of recently opened files (searchable, persistent)
- Open via ⌘O, File ▸ Open Recent, drag and drop, or double-click in Finder
- Live reload when the file changes on disk, keeping the scroll position
- Zoom with the toolbar − / + buttons or ⌘− / ⌘= (⌘0 resets); the level is remembered

## Install

Grab the latest `Markmer-<version>.zip` from the [Releases page](https://github.com/dhanajitkapali/Markmer/releases), unzip it, and drag **Markmer.app** into your Applications folder.

Markmer is not notarized (it is a free, open-source app with no Apple Developer subscription behind it), so macOS blocks the very first launch. Either:

- open **System Settings → Privacy & Security**, scroll down, click **Open Anyway**, and confirm; or
- run this once in Terminal:

  ```bash
  xattr -dr com.apple.quarantine /Applications/Markmer.app
  ```

After that it opens like any other app. To open a file from the command line:

```bash
open -a Markmer README.md
```

## Build

Requires Xcode 16 or newer and [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate
open Markmer.xcodeproj
```

Or from the command line:

```bash
xcodebuild -project Markmer.xcodeproj -scheme Markmer -configuration Release build
```

## Offline use

By default the renderer loads `marked`, `mermaid` and `highlight.js` from jsDelivr. To bundle them into the app so it works without a network connection, run once and rebuild:

```bash
./Tools/vendor.sh
```

## Cut a release

Bump `MARKETING_VERSION` in `project.yml`, commit, then tag and push:

```bash
git tag v1.0.0 && git push origin main --tags
```

GitHub Actions ([release.yml](.github/workflows/release.yml)) builds the app, zips it, and attaches it to a GitHub Release with install notes. To build the same zip locally:

```bash
./Tools/release.sh
```

## Regenerate the icon

```bash
swift Tools/make-icon.swift Markmer/Assets.xcassets/AppIcon.appiconset
```

## Layout

- `Markmer/MarkmerApp.swift`: app entry, menu commands, Finder open handling
- `Markmer/DocumentStore.swift`: current document, recents persistence, open panel
- `Markmer/FileWatcher.swift`: live reload on file changes
- `Markmer/ContentView.swift`: split view, sidebar, empty state, drag and drop
- `Markmer/MarkdownWebView.swift`: WKWebView host and HTML page assembly
- `Markmer/Resources/Template.html`: page styles and the JS render pipeline
