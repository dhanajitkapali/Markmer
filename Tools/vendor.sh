#!/bin/zsh
# Downloads the rendering libraries into Markmer/Resources/vendor so the app
# works fully offline. Optional: without it, Markmer loads them from jsDelivr.
set -euo pipefail
cd "$(dirname "$0")/.."
dest="Markmer/Resources/vendor"
mkdir -p "$dest"
curl -fsSL -o "$dest/marked.min.js"       "https://cdn.jsdelivr.net/npm/marked@12/marked.min.js"
curl -fsSL -o "$dest/mermaid.min.js"      "https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"
curl -fsSL -o "$dest/highlight.min.js"    "https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11/highlight.min.js"
curl -fsSL -o "$dest/github.min.css"      "https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11/styles/github.min.css"
curl -fsSL -o "$dest/github-dark.min.css" "https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11/styles/github-dark.min.css"
echo "Vendored libraries into $dest. Rebuild the app to bundle them."
