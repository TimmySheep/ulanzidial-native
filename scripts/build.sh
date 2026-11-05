#!/bin/bash
# 构建 UlanziDialLite.app（不使用 rm，重复构建直接覆盖）
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NAME="UlanziDialLite"
OUT="build/$NAME.app"

mkdir -p "$OUT/Contents/MacOS"
mkdir -p "$OUT/Contents/Resources"
cp "Sources/$NAME/Info.plist" "$OUT/Contents/Info.plist"

xcrun swiftc -O \
    -target arm64-apple-macosx13.0 \
    -o "$OUT/Contents/MacOS/$NAME" \
    Sources/$NAME/*.swift

codesign --force --sign - --identifier "local.timmy.ulanzidiallite" "$OUT" >/dev/null

echo "built: $ROOT/$OUT"
