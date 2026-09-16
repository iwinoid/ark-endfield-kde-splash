#!/bin/bash
# Ark: Endfield Page Loading · 一键安装到当前用户主题目录（不碰你现在的 ksplashrc 选择）
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.local/share/plasma/look-and-feel/ark-endfield-loading"
mkdir -p "$DEST"
cp -r "$SRC/metadata.json" "$SRC/contents" "$DEST/"
echo "已安装到：$DEST"
echo "下一步：系统设置 → 欢迎屏幕 → 选中「Ark: Endfield Page Loading」→ 应用。"
echo "回滚：在同一页选回原来的主题即可（你的旧选择目前是 $(grep -h Theme ~/.config/ksplashrc 2>/dev/null || echo 未知)）。"
