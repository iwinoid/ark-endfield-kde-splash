#!/bin/bash
# SPDX-FileCopyrightText: 2026 Ark Endfield Loading Demo
# SPDX-License-Identifier: GPL-2.0-or-later
# 打商店分发包：只含 metadata.json + contents/（kpackagetool 装整仓会把 tools/docs 也拷进主题目录）
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
OUT="$SRC/dist/ark-endfield-loading.tar.gz"
mkdir -p "$SRC/dist"
rm -f "$OUT"
tar -czf "$OUT" -C "$SRC" metadata.json contents
echo "已生成：$OUT"
tar -tzf "$OUT" | head -n 12
