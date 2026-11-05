#!/bin/bash
# 本机安装：构建 → 签名 → 旧版移废纸篓 → 装到 /Applications → 启动
# 必须在 Mac 的「终端」（图形会话）里运行，否则拿不到钥匙串里的签名私钥。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NAME="UlanziDialNative"
DEST="/Applications/$NAME.app"

echo "==> 1/5 构建并签名"
bash scripts/build.sh

SIGINFO="$(codesign -dv --verbose=2 "build/$NAME.app" 2>&1 || true)"
case "$SIGINFO" in
    *"Authority=Developer ID Application"*) echo "    签名身份：Developer ID ✓" ;;
    *)
        echo "✗ 不是 Developer ID 签名（钥匙串可能已锁）"
        echo "  先执行：security unlock-keychain ~/Library/Keychains/login.keychain-db"
        exit 1
        ;;
esac

echo "==> 2/5 退出正在运行的实例"
osascript -e "tell application \"$NAME\" to quit" >/dev/null 2>&1 || true
sleep 1

echo "==> 3/5 旧版移入废纸篓（可恢复）"
if [ -d "$DEST" ]; then
    osascript -e "tell application \"Finder\" to delete POSIX file \"$DEST\"" >/dev/null 2>&1 || true
    sleep 1
fi
# 旧名字的安装副本也一并收走
for OLD in "/Applications/DialNative.app" "/Applications/UlanziDialLite.app"; do
    if [ -d "$OLD" ]; then
        osascript -e "tell application \"Finder\" to delete POSIX file \"$OLD\"" >/dev/null 2>&1 || true
        echo "    已把旧版 $OLD 移入废纸篓"
        sleep 1
    fi
done

echo "==> 4/5 安装到 $DEST"
ditto "build/$NAME.app" "$DEST"

echo "==> 5/6 安装命令行工具"
if [ -w /usr/local/bin ]; then
    cp build/ulanzidial /usr/local/bin/ulanzidial
    CLI_PATH="/usr/local/bin/ulanzidial"
else
    mkdir -p "$HOME/.local/bin"
    cp build/ulanzidial "$HOME/.local/bin/ulanzidial"
    CLI_PATH="$HOME/.local/bin/ulanzidial"
fi
chmod 755 "$CLI_PATH"
echo "    已安装：$CLI_PATH"
case ":$PATH:" in
    *":$(dirname "$CLI_PATH"):"*) ;;
    *) echo "    提示：$(dirname "$CLI_PATH") 不在 PATH 里，可加到 ~/.zshrc：
      export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

echo "==> 6/6 启动并验证"
open "$DEST"
sleep 2
codesign -dv --verbose=2 "$DEST" 2>&1 | grep -E "Authority=Developer ID Application|TeamIdentifier" || true
echo
echo "✓ 已安装：$DEST"
echo "  设置窗口：⌥⌘D（或再双击一次 App）"
