# Ark: Endfield Page Loading · Plasma 欢迎屏幕主题

把 `loader-wipe/` 的 Web 效果（深色底 + 左侧自上而下进度条 + 整板自左向右扫满，
原型为黄色，现默认 KDE 品牌蓝）
复刻成 Plasma 6 的 Splash（KSplash）QML 主题，品牌文案为终末地风格（原创措辞）。
在 Plasma 6.7.5 + `qmllint` 离屏验证通过，与官方 Breeze 行为对齐（离屏加载零报错零输出）。

```
ark-endfield-loading/
├── metadata.json            # Plasma 6 包描述，Id=ark-endfield-loading（= 目录名，改名要同步改这里）
├── contents/
│   ├── splash/Splash.qml    # ★ 本体：进度→扫屏→hold 的全部逻辑
│   ├── previews/splash.png  # 设置页缩略图（暂复用旧品牌截图，改名后待重截：装上主题注销看一次，Spectacle 截一张换掉）
│   └── defaults             # 全局主题联动时把 ksplash 定到本主题
├── install.sh               # 一键拷到 ~/.local/share/plasma/look-and-feel/
└── README.md                # 本文档
```

## 安装 / 预览

```bash
cd ark-endfield-loading
bash install.sh
# 系统设置 → 欢迎屏幕 → 选中「Ark: Endfield Page Loading」→ 应用
# 真机效果要注销重登看一次；改崩了在同一页选回原主题即可
```

回滚只改 `~/.config/ksplashrc` 里 `[KSplash] Theme=` 一行，脚本本身不碰它。

## Web → QML 对应表

| Web（loader.css / loader.js） | QML（Splash.qml） | 说明 |
|---|---|---|
| `--lw-ink #141414` | `root.color` | 底色 |
| `--lw-accent #fffa00` | `accent`（默认 KDE 品牌蓝 `#0068C6`） | 进度条 / 数字 / 扫屏板，全包只读这一个变量 |
| `.lw-bg` 网格+径向高光+`blur(8px→0)` | `bg` 网格 Repeater+烘焙等高线 SVGZ，`opacity 0.45→1` | QML 无 CSS blur，用不透明度近似“对焦感”；等高线 `tools/make_contours.py` 离线烘（12 层、缝合+中点二次曲线、`.svgz` 矢量，微光已删） |
| `.lw-logo` 切角标+标题 | `brand` Plasma 齿轮标居中（Breeze `plasma.svgz` 拷入），下不配字 | 原切角标已换成 Plasma 原生标；底色压黑到 `#101010` |
| `.lw-fill height 0→100%` + `.45s` 过渡 | `fill.height` + `Behavior 450ms OutCubic` | 自上而下，方向不变 |
| `.lw-num top: p%` 缀条尖 | `num.y = rail.height*p%` + 同样 Behavior | 100% 时钳在屏内，防掉出底边（与 Web 差几 px） |
| `LOADING…/READY` | 同名绑定 `progress>=100` | 一致 |
| `total/stepMs` 演示节拍 | 删掉：进度 = stage/5，只跟 ksplash 真 stage | 1→20 … 5→100，5 档满格开扫（源码见下） |
| —（dsh-theme-endfield 新增） | 刻度右侧顶格放阶段真名（INITIALIZE … SHELL READY），LOADING 下移至 114 与数字拉开 | 跟真 stage；三段纵向 0/40/114 不重叠 |
| —（官方式） | 右下：Breeze 原 Row 原样搬运（标提前到文前），摆官网位；下行 `Experience Freedom` 非等宽 | 内容零改动、只借位置：左线 64.45%、slogan 基线恒 73%；三角点阵已删 |
| —（同上） | 顶栏 `KDE // Plasma Desktop Environment` + `STG 0X / 05` mono 标签 | 编辑排印：mono + letterspacing |
| 百分比字形 | 等宽（monospace 粗体） | 对应“数字等宽”规则，跳动不抖 |
| `.lw-leaving::after scaleX(0→1) 600ms cubic-bezier(1,0,.7,1) 延迟500ms` | `wipeT 0→1`，`Pause 500 + Number 600 OutExpo` | `width` 写法视觉等价，easing 近似那股先冲后收 |
| 整层 `opacity→0` 淡出 1s | **扫屏板铺满 hold 1000ms，等 6 到关窗** | 见下“本质差异” |
| `prefers-reduced-motion` 跳过 | `Kirigami.Units.longDuration>1` 判断，静态满格 | 一致 |
| 竖屏轨道 12px + 品牌居中 | `isPortrait` 分支 | 方向依旧自上而下 |

## 一个本质差异（必读）

ksplash 窗口是不透明全屏，QML 里不存在“变透明露出桌面”——Breeze 官方
`Splash.qml`（`lookandfeel/org.kde.breeze/contents/splash/Splash.qml`）也只做内容淡入、
从不动根节点透明度。桌面是 ksplash 进程退出那一刻露出来的。

所以 Web 版最后的“整层淡出”在这里翻成“5 档满格开扫，扫屏板铺满 hold 住等 6 到关窗”。
你看到的就是 `wipe.png` 定格那帧黄闪一下进桌面。注意扫必须播在 5 里：6 到窗口就没了。

stage 的真相（`plasma-workspace/ksplash/ksplashqml/splashapp.cpp` 原话）：

> There are 6 stages in ksplash: initial / startPlasma / kcminit / ksmserver / wm / desktop

其中 1/2/3 由 ksplash 自己在启动瞬间连发，4/5 由会话各组件实报，6 到即关窗。
所以开头 0→60% 的 glide 是动画抹平的连发三跳，5 是最后一个可见档。对照本地 MC 主题
（`minecraftworldloading-kde-splash`）：1–6 切图 + 手编百分比 8/24/42/58/76/93
（注释自认 arbitrary）；我们取线性映射 + 扫屏板离场，百分比如实反映最后收到的 stage。

## 官网实测对照（`__00-Loading`，见 `../官网参照/`）

用无头 Chromium 实拍 + HAR 抓包拿到的官方面板参数，逐项对照：

| 官网值 | 本主题 | 状态 |
|---|---|---|
| 底 `#141414`，`z-index:100` 全屏 fixed | 底 `#101010`（按反馈压黑一档） | 有意差异 |
| 背景 verified `bg.jpg` 照片 + `blur(8px)` | 网格 + 烘焙等高线（原创，无版权图） | 有意差异：不捆官方素材 |
| 信号色 `#fffa00` | 默认 `#0068C6` KDE 品牌蓝（`palette` 可切回 valley） | 按指定 |
| 左轨 `width:1.25rem=20px` 全高，`height:0→100%` | 一致 | ✅ |
| 数字 `left:3.125rem=50px` 缀条尖 | `railWidth+30=50px` | ✅ |
| 刻度 `8×30px` 圆角 + 数字 `70px` + `%` `52px` | 刻度一致；数字 68px / `%` 44px | ✅ 基本一致 |
| 标位 `left:64.45%` | `64%` | ✅ |
| 微构图（三角 SVG + deco SVG + 70rem 渐变分隔线 + slogan 1.5rem） | 三角字形 + i18n 微文 + 点阵 + `Experience Freedom`，分隔线按反馈删掉 | 结构对齐，零官方素材 |
| rem 自适应公式（`r*=t/2560` 等，按屏比缩放根字号） | 块顶按 `0.73H-56px` 反推，slogan 基线恒定 73% | 块内像素固定才成立；全 rem 化以后再说 |
| 离场 `opacity 1s 1.4s` + 黄板 `.6s cubic-bezier(1,0,.7,1) .5s` | `wipeDelay/Duration/fadeDelay/fadeDuration` 逐字对应 | ✅ 逐字相同 |
| 竖屏改底部横条（`width:82.4%`） | 竖屏保持竖条（沿用 loader-wipe 改动） | 有意差异 |

## 改色 / 改时长

- 换色：改 `palette`（`kde` 品牌蓝 `#0068C6` 默认 / `valley` 谷地黄 `#fff500` / `wuling` 武陵青 `#14d0d0` / `system` 跟系统强调色），
  或直接改 `accent` / `root.color`。品牌蓝在近黑底上约 3.5:1，大字号数字够 AA 大字标准，细字仍走灰色。
- 改扫屏时长：`wipeDelayMs / wipeDurationMs / holdMs` 三个 property。
- 改右下上行文案：不要动 catalog/上下文/源文（三者任改其一就脱离官方译文），换句等于自建目录自己打 `.po`。

## 出处

- 动效原型：本仓库 `loader-wipe/`（原创重写，终末地开屏行为观察学习）。
- Splash 机制文档：KDE UserBase《System Settings/Splash Screen》、
  develop.kde.org《Plasma themes and plugins → Splash Screen》、
  Breeze `Splash.qml`（`property int stage / onStageChanged` 模型）、
  `splashapp.cpp`（6 档 stage 定义与 `stage==6` 关窗逻辑）。
- 对照实现：本地 `minecraftworldloading-kde-splash`（Samsu-F，GPLv3）按 stage 切图。
- 绘制语言参考：[dsh-theme-endfield](https://github.com/ymh0000123/dsh-theme-endfield)
  （`docs/design-language.md` 色板与直角规范、`docs/features.md` 启动动画时序与海报排版）——
  阶段行、STG 读数、谷地黄/武陵青双配色取自这套规范（水印、光晕、取景框已按反馈拿掉）。
