#!/usr/bin/env bash
# Re-render the iOS widget screenshots from the real WidgetKit views.
#   docs/store/tools/widget/render.sh "23 Sep" "23 сент."
# Writes docs/store/screenshots/src/{en,ru}_ioswidget.png (1092x510).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
TMP="$(mktemp -d)"
sed '/^struct RectangularView/,$d' "$ROOT/ios/AdPocketWidget/Views.swift" | sed '1s/^import SwiftUI/import SwiftUI\nimport AppKit/' > "$TMP/views.swift"
cp "$(dirname "$0")/main.swift" "$TMP/main.swift"
swiftc -O -parse-as-library -o "$TMP/render" "$TMP/views.swift" "$TMP/main.swift"
"$TMP/render" "$ROOT/docs/store/screenshots/src" "${1:?en day, e.g. 23 Sep}" "${2:?ru day, e.g. 23 сент.}"
rm -rf "$TMP"
