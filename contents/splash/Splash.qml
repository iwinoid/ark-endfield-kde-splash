/*
 * SPDX-FileCopyrightText: 2026 Ark Endfield Loading Demo
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * Ark: Endfield Page Loading · Plasma Splash
 * 动效：深色底 + 左侧自上而下进度轨 + 品牌蓝整板自左向右扫满
 * （时间线参数对齐终末地官网 __00-Loading 实测值，见 README 对照表）
 * 进度真相：ksplash 只给 int stage（plasma-workspace ksplash/ksplashqml/splashapp.cpp，
 *   6 档：initial/startPlasma/kcminit/ksmserver/wm/desktop；1/2/3 启动瞬间连发，
 *   4/5 由会话实报，6 到即关窗）。所以进度 = stage/5，5 档满格开扫，扫屏板播在 5→6 的缝隙里。
 *
 * 与 Web 式加载页的一个本质差异：ksplash 窗口是不透明全屏，QML 里没有“变透明露出桌面”这回事，
 * Breeze 官方 Splash.qml 也只做内容淡入、从不把根节点变透明。桌面是 ksplash 进程退出那一刻
 * 露出来的（QML 收到 stage 6 时 QGuiApplication::exit）。所以收尾的淡出在这里翻成
 * “5 档满格开扫、扫屏板铺满 hold 住等 6 到关窗”，视觉上就是蓝闪一下进桌面。
 * 注意扫必须播在 5 里：6 到窗口就没了。
 */

import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    // KSplash 注入：int stage，6 档（Breeze 在 2 开始 intro、5 收尾、6 关窗）
    property int stage: 0
    // ---- 可调时间线（对齐官网：扫延迟 500 / 扫 600 / hold 1000） ----
    property real progress: 0
    // 0–100 = stage/5*100，只跟真 stage，不自增
    property bool leaving: false
    // 开扫标记
    property int wipeDelayMs: 500
    // 开扫延迟
    property int wipeDurationMs: 600
    // 扫屏时长
    property int holdMs: 1000
    // 配色：kde 品牌蓝 #0068C6（默认）/ valley 谷地黄 #fff500 / wuling 武陵青 #14d0d0 /
    // system 跟随系统强调色（颜色 KCM 里换）。
    // 欢迎屏幕 KCM 不加载主题配置页（实测 kcm_splashscreen.so 无 config 机制，只管选主题），
    // 所以配色是改这一行，没有设置页开关；要发行多色就打多个包。
    property string palette: "kde"
    property color accent: palette === "valley" ? "#fff500" : palette === "wuling" ? "#14d0d0" : palette === "system" ? Kirigami.Theme.highlightColor : "#0068C6"
    property color dim: "#8d8d8d" // 次要文字灰
    // prefers-reduced-motion 对应：关动画用户直接静态满格
    property bool animationsEnabled: Kirigami.Units.longDuration > 1
    // 竖屏：轨道收窄 + 品牌居中，进度方向不变（依旧自上而下）
    property bool isPortrait: height > width
    property int railWidth: isPortrait ? 12 : 20 // 左轨宽度（桌面 20 / 竖屏 12）
    property real wipeT: 0

    color: "#101010" // 底色（比官网 #141414 再压黑一档）
    // 进度跟真 stage（splashapp.cpp：6 档 initial/startPlasma/kcminit/ksmserver/wm/desktop；
    // 1/2/3 启动瞬间连发，4/5 会话实报，6 到即关窗）。映射 stage/5：1→20 … 5→100 满格开扫。
    // 开头 0→60% 的 glide 是 Behavior 动画抹平的连发三跳。5 是最后一个可见档，扫播在 5→6 缝隙。
    onStageChanged: {
        if (stage >= 5) {
            progress = 100;
            if (!leaving)
                leaving = true;

        } else if (stage > 0) {
            progress = stage * 20;
        } else {
            progress = 0;
        }
    }
    Component.onCompleted: {
        if (animationsEnabled) {
            progress = Math.max(0, Math.min(5, stage)) * 20;
            if (stage >= 5)
                leaving = true;

        } else {
            progress = 100; // 减弱动态：静态满格，不播扫屏
        }
    }
    onLeavingChanged: {
        if (leaving) {
            if (animationsEnabled)
                wipeAnim.start();
            else
                wipeT = 1;
        }
    }

    // ================= 背景层 =================
    // 网格 + 烘焙等高线，整体不透明度随进度 0.45→1，越加载越清晰，有“对焦”感。
    Item {
        id: bg

        anchors.fill: parent
        opacity: 0.45 + 0.55 * (progress / 100)

        // 网格线：80px 一格，白色 5%
        Repeater {
            model: Math.ceil(parent.width / 80) + 1

            Rectangle {
                x: index * 80
                width: 1
                height: bg.height
                color: "white"
                opacity: 0.05
            }

        }

        Repeater {
            model: Math.ceil(parent.height / 80) + 1

            Rectangle {
                y: index * 80
                height: 1
                width: bg.width
                color: "white"
                opacity: 0.05
            }

        }
        // 烘焙等高线（tools/make_contours.py 离线 marching squares，散段缝合成连续折线后

        // 以中点二次曲线输出 SVGZ 矢量：Q 指令原生曲线，不断点；Breeze 同款 .svgz 做法）
        Image {
            anchors.fill: parent
            source: "images/contours.svgz"
            sourceSize.width: 1920
            sourceSize.height: 1080
            fillMode: Image.PreserveAspectCrop
            opacity: 0.9
            asynchronous: true
        }

    }

    // ================= 顶栏 mono 标签 =================
    Text {
        x: railWidth + 30
        y: 26
        text: "KDE // Plasma Desktop Environment"
        color: dim
        font.family: "monospace"
        font.pixelSize: 11
        font.letterSpacing: 3
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 28
        y: 26
        text: "STG 0" + Math.min(5, Math.max(0, stage)) + " / 05"
        color: dim
        font.family: "monospace"
        font.pixelSize: 11
        font.letterSpacing: 3
    }

    // ================= 品牌：Plasma 标，下不配字 =================
    // 海报式右区站位（桌面 64% / 30%，竖屏居中 / 20%）；
    // 字只留在顶栏/阶段行/右下署名里，标下干净。
    Image {
        id: brand

        width: 154 // 128 的 +20%；svgz 矢量，sourceSize 同步，无损
        height: 154
        x: isPortrait ? (parent.width - width) / 2 : parent.width * 0.64
        y: isPortrait ? parent.height * 0.2 : parent.height * 0.3
        source: "images/plasma.svgz"
        sourceSize.width: 154
        sourceSize.height: 154
        asynchronous: true
    }

    // ================= 左侧进度条，自上而下 =================
    Rectangle {
        id: rail

        x: 0
        y: 0
        width: railWidth
        height: parent.height
        color: "transparent"

        Rectangle {
            id: fill

            width: parent.width
            height: parent.height * (progress / 100) // 只灌 height：从顶部往下长
            color: accent

            // 每跳过渡 .45s
            Behavior on height {
                enabled: animationsEnabled

                NumberAnimation {
                    duration: 450
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    // 数字块缀在条尖，钳在屏内防 100% 时掉出底边；
    // 开扫后隐藏，扫屏板接管画面
    Item {
        id: num

        visible: !leaving
        x: railWidth + (isPortrait ? 20 : 30) // 官网 progressText left:3.125rem=50px
        y: Math.min(Math.max(0, rail.height * (progress / 100) - 10), rail.height - 150)
        width: 320
        height: 150

        // 刻度 + 当前模块状态（阶段真名），缀条尖一起走
        Row {
            spacing: 8

            Rectangle {
                width: 8
                height: 30
                radius: 4
                color: accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: dim
                text: ["—", "INITIALIZE", "START PLASMA", "KCMINIT", "KSMSERVER", "SHELL READY"][Math.min(5, Math.max(0, stage))]
                font.family: "monospace"
                font.pixelSize: isPortrait ? 10 : 11
                font.letterSpacing: 2
            }

        }

        Row {
            y: 40
            spacing: 4

            // 官网 value 4.375rem=70px
            Text {
                text: Math.round(progress)
                color: accent
                font.family: "monospace"
                font.pixelSize: isPortrait ? 40 : 68
                font.bold: true
            }

            // 官网 symbol 3.25rem=52px，按比例略收
            Text {
                text: "%"
                color: accent
                font.pixelSize: isPortrait ? 26 : 44
                anchors.baseline: parent.children[0].baseline
            }

        }
        // LOADING… / READY（省略号呼吸；与数字间距同上段 10px 对齐）

        Text {
            y: 118
            color: dim
            text: progress >= 100 ? "READY" : ("LOADING" + "...".substring(0, dotsTimer.dots))
            font.family: "monospace"
            font.pixelSize: isPortrait ? 10 : 11
            font.letterSpacing: 4
        }

        // 数字块纵向跟随：过渡 .45s，缀着条尖跑
        Behavior on y {
            enabled: animationsEnabled

            NumberAnimation {
                duration: 450
                easing.type: Easing.OutCubic
            }

        }

    }

    // ================= 右下：Breeze 原 Row + 官网 Freedom（摆官网位） =================
    // 微行 = Breeze 右下 Row 原样搬运（catalog/上下文/源文/样式全同，仅标提前到文前）；
    // 位置取官网（左线 64.45%、slogan 基线 73%），不取 Breeze 右下角。
    // Breeze 原调用保留（catalog/上下文/源文三同即同一条目：中文环境显示“KDE Plasma 桌面环境”，
    // 德/法亦有官方译文，日文回落英文；将来上游增译自动跟进）。Experience Freedom 非等宽收底，左边缘对齐。
    Column {
        // 官网位（rem 公式反推，见 README）：与标块同左线 left:64.45%，slogan 基线恒定 73% 屏高；
        // 竖屏改左对齐。
        x: isPortrait ? railWidth + 30 : parent.width * 0.6445
        y: parent.height * 0.73 - 68 // 块内像素高度固定（微行 gridUnit*2 + 间距 + slogan），反推块顶，保证基线恒 73%
        spacing: 12

        // Breeze 右下 Row 原样搬运，唯一改动：KDE 标提前到文前
        Row {
            spacing: Kirigami.Units.largeSpacing

            Image {
                anchors.verticalCenter: parent.verticalCenter
                asynchronous: true
                source: "images/kde.svgz"
                sourceSize.height: Kirigami.Units.gridUnit * 2
                sourceSize.width: Kirigami.Units.gridUnit * 2
            }
            // 一字不改：见 Breeze Splash.qml 第 76-83 行

            Text {
                color: "#eff0f1"
                anchors.verticalCenter: parent.verticalCenter
                text: i18ndc("plasma_lookandfeel_org.kde.lookandfeel", "This is the first text the user sees while starting in the splash screen, should be translated as something short, is a form that can be seen on a product. Plasma is the project name so shouldn't be translated.", "Plasma made by KDE")
                Accessible.name: text
                Accessible.role: Accessible.StaticText
                textFormat: Text.PlainText
            }

        }

        // 官网 OVER THE FRONTIER 位置：非等宽字体收尾
        Text {
            text: "Experience Freedom"
            color: "#e8e8e8"
            font.pixelSize: 15
            font.letterSpacing: 2
        }

    }

    // ================= 品牌蓝扫屏板 =================
    // CSS：transform-origin:left + scaleX(0→1) + cubic-bezier(1,0,.7,1)。
    // QML 等价写法是宽 0→满屏（左锚定），easing 用 OutExpo 近似那股先冲后收的工业感。
    Rectangle {
        id: wipe

        x: 0
        y: 0
        width: parent.width * wipeT
        height: parent.height
        color: accent
    }

    SequentialAnimation {
        id: wipeAnim

        running: false

        // t0+500 开扫
        PauseAnimation {
            duration: wipeDelayMs
        }

        // 扫 600ms 自左向右铺满
        NumberAnimation {
            target: root
            property: "wipeT"
            from: 0
            to: 1
            duration: wipeDurationMs
            easing.type: Easing.OutExpo
        }

        // 铺满 hold，等 6 到关窗（离场淡出段）
        PauseAnimation {
            duration: holdMs
        }

    }

    // ================= 待机呼吸点（stage 间隙长时屏幕不像死机） =================
    // 只动省略号，不动进度条——进度只跟真 stage，不自增。
    Timer {
        id: dotsTimer

        property int dots: 0

        interval: 500
        repeat: true
        running: animationsEnabled && !leaving
        onTriggered: dots = (dots + 1) % 4
    }

}
