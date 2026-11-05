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

IDENTITY="${SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
    IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)"
fi

if [ -n "$IDENTITY" ]; then
    echo "signing with: $IDENTITY"
    if ! codesign --force --options runtime --timestamp \
        --identifier "local.timmy.ulanzidiallite" \
        --sign "$IDENTITY" "$OUT"; then
        echo "警告：Developer ID 签名失败（通常是登录钥匙串已锁定或私钥访问未授权）"
        echo "      本机终端里先执行 security unlock-keychain，或运行一次并点「始终允许」"
        echo "      本次退回 ad-hoc 签名，App 仍可运行，但 TCC 授权会随重编译失效"
        codesign --force --sign - --identifier "local.timmy.ulanzidiallite" "$OUT"
    fi
else
    echo "警告：未找到 Developer ID Application，退回 ad-hoc 签名（每次重编译都会要求重新授权）"
    codesign --force --sign - --identifier "local.timmy.ulanzidiallite" "$OUT"
fi

codesign --verify --deep --strict --verbose=2 "$OUT"
echo "built: $ROOT/$OUT"
