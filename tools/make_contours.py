#!/usr/bin/env python3
"""离线烘焙 splash 用静态等高线（SVGZ 矢量，真 marching squares，不是贴图平移）。

场 = 若干正负高斯凸起（有山有洼） + 三道长波正弦，与 dsh-theme-endfield 文档同构；
12 个等间距高度取等值线。splash 里跑实时场不划算（只活 2–6 秒），烘矢量最稳。

相对 PNG 版的关键改进（对 dsh-theme-endfield 工程笔记的回应）：
- 散段按端点缝合成连续折线（闭合环自动闭环），再以中点二次曲线绘制：
  每个原顶点当控制点、曲线穿过线段中点，C1 连续；SVG 的 Q 指令原生表达，
  不用展平成折线。末段按笔记结论用 lineTo 收尾（退化二次曲线会倒退 1/6 段拖出倒刺）。
- 输出 .svgz（gzip SVG，Breeze 同款做法），QML Image 原生支持。
用法：在项目根目录跑 python3 tools/make_contours.py
"""
import gzip
import math
import random

import numpy as np

W, H = 1920, 1080
GW, GH = 240, 135  # 场网格（8px/格）
LEVELS = 12
SEED = 7
OUT = "contents/splash/images/contours.svgz"
STROKE_OPACITY = 0.13  # 细线不透明度：暗底装饰，按“可见但不抢”取


def build_field():
    rng = random.Random(SEED)
    xs = np.arange(GW + 1, dtype=float)
    ys = np.arange(GH + 1, dtype=float)
    xx, yy = np.meshgrid(xs, ys)
    f = np.zeros_like(xx)
    for _ in range(5):  # 高斯凸起，正负相间；大 sigma 出干净岛屿
        cx = rng.uniform(0, GW)
        cy = rng.uniform(0, GH)
        sigma = rng.uniform(35, 75)
        amp = rng.uniform(0.5, 1.0) * (1 if rng.random() < 0.5 else -1)
        f += amp * np.exp(-((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * sigma**2))
    for k in range(3):  # 长波正弦；幅度压小，否则平行条纹盖过岛屿
        fx, fy = rng.uniform(1, 3), rng.uniform(1, 3)
        px, py = rng.uniform(0, 6.28), rng.uniform(0, 6.28)
        f += 0.06 * np.sin(2 * math.pi * (xx * fx / GW + yy * fy / GH) + px + py)
    f -= f.min()
    f /= f.max()
    return f


def interp(p1, p2, v1, v2, level):
    t = (level - v1) / (v2 - v1) if v2 != v1 else 0.5
    return (p1[0] + (p2[0] - p1[0]) * t, p1[1] + (p2[1] - p1[1]) * t)


def extract(f, level):
    """返回像素坐标线段 [(x1,y1,x2,y2), ...]。"""
    sx, sy = W / GW, H / GH
    segs = []
    for j in range(GH):
        for i in range(GW):
            a, b = f[j, i], f[j, i + 1]
            c, d = f[j + 1, i + 1], f[j + 1, i]
            idx = (a > level) * 1 | (b > level) * 2 | (c > level) * 4 | (d > level) * 8
            if idx in (0, 15):
                continue
            pa, pb, pc, pd = (i * sx, j * sy), ((i + 1) * sx, j * sy), ((i + 1) * sx, (j + 1) * sy), (i * sx, (j + 1) * sy)
            T = lambda: interp(pa, pb, a, b, level)  # noqa: E731
            R = lambda: interp(pb, pc, b, c, level)  # noqa: E731
            B = lambda: interp(pd, pc, d, c, level)  # noqa: E731
            L = lambda: interp(pa, pd, a, d, level)  # noqa: E731
            table = {
                1: [("T", "L")], 2: [("T", "R")], 3: [("L", "R")],
                4: [("R", "B")], 6: [("T", "B")], 7: [("L", "B")],
                8: [("L", "B")], 9: [("T", "B")], 11: [("R", "B")],
                12: [("L", "R")], 13: [("T", "R")], 14: [("T", "L")],
            }
            if idx in (5, 10):  # 歧义格按中心均值定向
                center = (a + b + c + d) / 4 >= level
                pairs = [("T", "L"), ("R", "B")] if (idx == 5) == center else [("T", "R"), ("L", "B")]
            else:
                pairs = table[idx]
            edges = {"T": T, "R": R, "B": B, "L": L}
            for e1, e2 in pairs:
                x1, y1 = edges[e1]()
                x2, y2 = edges[e2]()
                segs.append((x1, y1, x2, y2))
    return segs


def key(pt):
    return (round(pt[0], 2), round(pt[1], 2))


def stitch(segs):
    """散段按端点缝合成连续折线 [ [p0, p1, ...], ... ]，闭合环首尾相接。"""
    adj = {}
    for n, (x1, y1, x2, y2) in enumerate(segs):
        adj.setdefault(key((x1, y1)), []).append(n)
        adj.setdefault(key((x2, y2)), []).append(n)
    used = [False] * len(segs)
    lines = []
    for n, (x1, y1, x2, y2) in enumerate(segs):
        if used[n]:
            continue
        used[n] = True
        chain = [(x1, y1), (x2, y2)]
        while True:  # 从尾向前接
            nxt = next((m for m in adj.get(key(chain[-1]), []) if not used[m]), None)
            if nxt is None:
                break
            used[nxt] = True
            sx1, sy1, sx2, sy2 = segs[nxt]
            chain.append((sx2, sy2) if key((sx1, sy1)) == key(chain[-1]) else (sx1, sy1))
        while True:  # 从头向后接
            nxt = next((m for m in adj.get(key(chain[0]), []) if not used[m]), None)
            if nxt is None:
                break
            used[nxt] = True
            sx1, sy1, sx2, sy2 = segs[nxt]
            chain.insert(0, (sx2, sy2) if key((sx1, sy1)) == key(chain[0]) else (sx1, sy1))
        lines.append(chain)
    return lines


def fmt(v):
    s = f"{v:.1f}"
    return s[:-2] if s.endswith(".0") else s


def mid(p, q):
    return ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)


def to_path(pts):
    """中点二次曲线路径。闭环用循环形式（接缝落在段中，保持 C1）；末段 lineTo。"""
    if len(pts) < 2:
        return ""
    if key(pts[0]) == key(pts[-1]) and len(pts) > 3:  # 闭合环
        pts = pts[:-1]
        m0 = mid(pts[-1], pts[0])
        d = [f"M{fmt(m0[0])},{fmt(m0[1])}"]
        for i, p in enumerate(pts):
            m = mid(p, pts[(i + 1) % len(pts)])
            d.append(f"Q{fmt(p[0])},{fmt(p[1])} {fmt(m[0])},{fmt(m[1])}")
        d.append("Z")
        return "".join(d)
    if len(pts) == 2:  # noqa: RET504
        return f"M{fmt(pts[0][0])},{fmt(pts[0][1])}L{fmt(pts[1][0])},{fmt(pts[1][1])}"
    m0 = mid(pts[0], pts[1])
    d = [f"M{fmt(m0[0])},{fmt(m0[1])}"]
    for i in range(1, len(pts) - 1):
        m = mid(pts[i], pts[i + 1])
        d.append(f"Q{fmt(pts[i][0])},{fmt(pts[i][1])} {fmt(m[0])},{fmt(m[1])}")
    d.append(f"L{fmt(pts[-1][0])},{fmt(pts[-1][1])}")  # 末段 lineTo，不倒退
    return "".join(d)


def main():
    f = build_field()
    paths = []
    total_segs = 0
    for level in np.linspace(0.08, 0.92, LEVELS):
        segs = extract(f, float(level))
        total_segs += len(segs)
        for chain in stitch(segs):
            d = to_path(chain)
            if d:
                paths.append(f'<path d="{d}"/>')
    body = "".join(paths)
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
        f'<g fill="none" stroke="#ffffff" stroke-width="1" stroke-opacity="{STROKE_OPACITY}">{body}</g></svg>'
    )
    with gzip.open(OUT, "wt", encoding="utf-8") as fh:
        fh.write(svg)
    import os
    print(f"{OUT}: {W}x{H}, {LEVELS} levels, {total_segs} segments -> {len(paths)} paths, "
          f"svg {len(svg)//1024}KB -> gz {os.path.getsize(OUT)//1024}KB")


if __name__ == "__main__":
    main()
