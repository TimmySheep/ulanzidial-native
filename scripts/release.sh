#!/bin/bash
# 一键发布：构建 → Developer ID 签名 → 公证 → staple → 验证
# 必须在 Mac 的「终端」（图形会话）里运行，否则拿不到钥匙串里的签名私钥。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NAME="UlanziDialLite"
APP="build/$NAME.app"
ZIP="build/$NAME.zip"
KEY="$HOME/.appstoreconnect/private_keys/AuthKey_GT622JVW4H.p8"
KEY_ID="GT622JVW4H"
ISSUER="797306ef-5e59-477e-b00d-b2109a4d5b63"

echo "==> 1/5 构建并签名"
bash scripts/build.sh

echo "==> 2/5 确认签名身份"
SIGINFO="$(codesign -dv --verbose=2 "$APP" 2>&1 || true)"
printf '%s\n' "$SIGINFO" | sed -n 's/^\(Authority=[^,]*\).*/  \1/p' | head -3
case "$SIGINFO" in
    *"Authority=Developer ID Application"*) ;;
    *)
        echo "✗ 当前不是 Developer ID 签名，停止。请先执行："
        echo "  security unlock-keychain ~/Library/Keychains/login.keychain-db"
        exit 1
        ;;
esac

echo "==> 3/5 打包并提交公证"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" \
    --key "$KEY" --key-id "$KEY_ID" --issuer "$ISSUER" \
    --wait

echo "==> 4/5 钉公证票据（失败会重试，票据同步有时间差）"
for i in 1 2 3 4 5; do
    if xcrun stapler staple "$APP"; then
        break
    fi
    echo "  第 $i 次失败，等 20 秒后重试…"
    sleep 20
done
xcrun stapler validate "$APP"

echo "==> 5/5 验证"
codesign --verify --deep --strict --verbose=2 "$APP"
xcrun stapler validate "$APP"
spctl -a -vv "$APP" || true

echo
echo "✓ 完成：$ROOT/$APP"
