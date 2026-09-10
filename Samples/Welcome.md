# Welcome to Markmer

Markmer is a small, fast Markdown reader for macOS with first-class **Mermaid** support.
Open a file with <kbd>⌘O</kbd>, drop one on the window, or pick it from the sidebar.

## What you get

- GitHub-flavoured Markdown: tables, task lists, strikethrough, autolinks
- Mermaid diagrams rendered inline, themed for light and dark mode
- Syntax highlighting for fenced code blocks
- Live reload: edit the file in your editor and Markmer re-renders in place
- A sidebar of recently opened files, searchable and persistent

## Mermaid

```mermaid
flowchart LR
    A([Open .md]) --> B[Parse Markdown]
    B --> C{Mermaid block?}
    C -- yes --> D[Render diagram]
    C -- no --> E[Highlight code]
    D --> F([Display])
    E --> F
```

```mermaid
sequenceDiagram
    participant U as You
    participant M as Markmer
    participant E as Editor
    U->>M: Open README.md
    M-->>U: Rendered page
    E->>M: File saved (write event)
    M-->>U: Re-render, keep scroll position
```

```mermaid
gantt
    title Release plan
    dateFormat  YYYY-MM-DD
    section Build
    Core reader        :done,    a1, 2026-09-01, 5d
    Mermaid support    :done,    a2, after a1, 3d
    section Polish
    App icon           :active,  b1, 2026-09-10, 2d
    Offline bundling   :         b2, after b1, 2d
```

## Code

```swift
struct RecentFile: Identifiable, Codable {
    var path: String
    var lastOpened: Date
    var id: String { path }
}
```

```bash
# Bundle the JS libraries so the app works offline
./Tools/vendor.sh
```

## Tables and tasks

| Feature            | Status |
| ------------------ | :----: |
| Markdown rendering |   ✅   |
| Mermaid diagrams   |   ✅   |
| Recent files       |   ✅   |
| Live reload        |   ✅   |

- [x] Build the reader
- [x] Draw a logo
- [ ] Ship it

> Tip: links to other `.md` files open inside Markmer. External links open in your browser.
