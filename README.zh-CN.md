# Ark: Endfield Page Loading

[English](README.md) · 中文版

![Built with DeepSeek Harness](https://img.shields.io/badge/built_with-DeepSeek_Harness-0068C6)

Plasma 6 启动欢迎屏幕（Splash）主题：深色工业风，左侧进度轨自上而下，进度走满后品牌蓝整板自左向右扫满进桌面。

![预览](contents/previews/splash.png)

<img src="preview-demo.webp" width="960" alt="动态演示：60% 行进 → 满格 → 品牌蓝扫屏离场（离屏实机渲染，5 秒循环）">

## 安装

```bash
bash install.sh
```

然后打开**系统设置 → 欢迎屏幕**，选中「Ark: Endfield Page Loading」→ 应用。注销重登看效果。

回滚：在同一页选回原来的主题即可（脚本不碰你现在的 `~/.config/ksplashrc` 选择）。

## 布局

- **左侧**：20px 进度轨自上而下，刻度 + 百分比 + 当前阶段名缀着条尖走，进度跟随 ksplash 真实 stage（1→20% … 5→100%）
- **右区**：Plasma 齿轮标（64% / 30% 海报站位）
- **右下微构图**：Breeze 原生署名行 + `Experience Freedom`，位置对齐终末地官网加载页
- **背景**：网格 + 烘焙等高线矢量底

## 自定义

- **配色**：改 `contents/splash/Splash.qml` 顶部 `palette` —— `kde` 品牌蓝 `#0068C6`（默认）/ `valley` 谷地黄 `#fff500` / `wuling` 武陵青 `#14d0d0` / `system` 跟随系统强调色
- **右下文案**：`Experience Freedom` 那一行；Breeze 署名行请勿改 catalog/上下文/源文，否则脱离官方译文
- **等高线底图**：`python3 tools/make_contours.py` 重新烘焙（marching squares → SVGZ 矢量）

## 文件结构

```
ark-endfield-loading/
├── metadata.json            # Plasma 6 包描述（Id = 目录名）
├── contents/
│   ├── splash/Splash.qml    # 主题本体
│   ├── splash/images/       # contours.svgz（自烘焙）+ Breeze 的 plasma/kde 标
│   ├── previews/splash.png  # 设置页缩略图
│   └── defaults             # 全局主题联动时的 ksplash 指向
├── preview-demo.webp        # 动态演示（离屏实机渲染，见上）
├── tools/make_contours.py   # 等高线底图烘焙脚本
├── .github/workflows/       # 打 tag 自动构建商店包并挂到 Release
├── install.sh               # 一键安装到用户主题目录
├── dist.sh                  # 打商店分发包（仅 metadata.json + contents/）
└── LICENSE                  # GPL-2.0-or-later 全文
```

本地另有 `docs/`（开发笔记）、离屏渲染抓拍工具与 `dist/` 产物，均不入库。

## 许可与出处

- 本主题代码 GPL-2.0-or-later；`plasma.svgz` / `kde.svgz` 取自 Breeze（同许可）
- 设计语言参考 [dsh-theme-endfield](https://github.com/ymh0000123/dsh-theme-endfield) 与终末地官网加载页（实现均为原创，未使用官方素材）
