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
