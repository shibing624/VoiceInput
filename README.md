[**🌐 English**](README_EN.md) | [**🇨🇳 中文**](README.md)

<div align="center">
  <img src="Assets/AppIcon.iconset/icon_128x128.png" width="96" alt="VoiceInput 图标" />
  <h1>VoiceInput — 语音输入</h1>
  <p>按住按键 → 说话 → 松开。文字自动出现在光标位置。</p>

  ![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple)
  ![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
  ![License](https://img.shields.io/badge/license-Apache%202.0-green)
  ![Build](https://img.shields.io/badge/build-passing-brightgreen)
</div>

---

## 简介

VoiceInput 是一个轻量级 macOS 菜单栏应用，将语音实时转换为文字并注入任意输入框——终端、浏览器、聊天软件、编辑器——无需切换窗口，无需点击任何地方。

按住 **Fn**（或 **右 ⌘**）→ 说话 → 松开。搞定。

> **这个项目是基于一句话 Prompt 生成的。** 完整 Prompt 见 [`PROMPT.sh`](PROMPT.sh)，使用 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 一次性生成了全部代码、构建脚本和项目结构。

https://github.com/user-attachments/assets/3228f78a-f035-447d-98ef-8826798a122c

## 功能特性

| 功能 | 说明 |
|------|------|
| 🎙 **按键触发** | 按住 Fn / 右 Command 录音，松开即注入文字 |
| 🖱 **鼠标触发** | 点击菜单栏"开始语音输入"，无需键盘操作 |
| 🌊 **悬浮波形 HUD** | 屏幕底部胶囊面板，动态波形 + 实时转录预览 |
| 🔤 **中文输入法兼容** | 注入前自动退出拼音/注音等输入法，注入后恢复 |
| 🌍 **多语言支持** | 英语、简体中文、繁体中文、日语、韩语 |
| 🤖 **LLM 纠错（可选）** | 接入任意 OpenAI 兼容接口，修复同音字和专业词汇误识 |
| 🔒 **设备端语音识别** | 基于 Apple Speech 框架，音频不离开本机 |

## 触发按键支持

| 键盘类型 | 触发按键 |
|----------|----------|
| MacBook 内置键盘 | **Fn** |
| Apple Magic Keyboard | **Fn** |
| 带 Fn 键的外接键盘 | **Fn**（需固件将 Fn 事件转发给系统） |
| 任意键盘 | **右 ⌘**（通用兜底方案） |

> **提示：** 如果外接键盘的 Fn 键无效（固件层拦截），使用**右 Command 键**——所有键盘都有，同样有效。

## 系统要求

- macOS 14.0（Sonoma）及以上
- Xcode Command Line Tools（`xcode-select --install`）

## 安装方式

### 方式一 — 直接下载（推荐）

从 [GitHub Releases](https://github.com/shibing624/VoiceInput/releases/latest) 下载最新的 `VoiceInput.dmg`，双击打开，拖动 `VoiceInput.app` 到 `Applications` 文件夹即可。

### 方式二 — 自行构建 DMG

```bash
make dmg            # 构建 release/VoiceInput.dmg
open release/VoiceInput.dmg
# 拖动 VoiceInput.app 到 Applications 文件夹
```

### 方式三 — 直接编译安装

```bash
make install        # 编译并复制到 /Applications/VoiceInput.app
```

### 方式四 — 不安装直接运行

```bash
make run            # 编译并从 release/ 启动
```

> **为什么要安装到 `/Applications`？**  
> 辅助功能（全局按键监听）权限与应用路径绑定。  
> 安装到 `/Applications` 后，只需授权**一次**，重新构建不会失效。  
> 直接从构建目录运行，每次重建都会触发重新授权弹窗。

## 首次启动 — 权限授权

首次启动时系统会依次请求三项权限：

| 权限 | 用途 | 授权位置 |
|------|------|----------|
| **麦克风** | 录制音频 | 系统设置 › 隐私与安全 › 麦克风 |
| **语音识别** | Apple 设备端语音转文字 | 系统设置 › 隐私与安全 › 语音识别 |
| **辅助功能** | 全局监听 Fn / 右 ⌘ 按键 | 系统设置 › 隐私与安全 › 辅助功能 |

授予辅助功能权限后，应用约 2 秒内自动检测，无需手动重启。

## 使用方法

### 按键触发

1. 将光标置于任意文本输入框
2. **按住 Fn**（或**右 ⌘**）— 屏幕底部出现 HUD 面板
3. **说话** — 波形动画，实时显示转录内容
4. **松开按键** — 文字注入到光标位置

### 鼠标触发（无需键盘）

1. 点击菜单栏的**波形图标**
2. 点击 **"开始语音输入"**
3. 说话 — 同样的 HUD 面板出现
4. 再次点击菜单栏图标 → 点击 **"停止录音"** 完成输入

录音期间状态栏图标变为实心波形（●），直观显示录音状态。

### 语言设置

菜单栏图标 → **Language** → 选择语言  
设置立即生效并自动保存。

### LLM 纠错（可选）

通过大语言模型修复语音识别错误（同音字、专有名词）：

1. 菜单栏图标 → **LLM Refinement → Settings…**
2. 填写 **API Base URL**、**API Key**、**模型名称**（支持任意 OpenAI 兼容接口）
3. 点击 **Test Connection** 验证连通性
4. **Save** 保存，再通过 **LLM Refinement → Enable** 开启

启用后，松开按键时 HUD 短暂显示"Refining…"，完成后注入纠错后的文字。

## 构建命令

```bash
make build      # 编译 + 打包 release/VoiceInput.app（含图标）
make run        # 编译 + 直接运行
make install    # 编译 + 安装到 /Applications
make dmg        # 编译 + 打包为 release/VoiceInput.dmg
make clean      # 删除 release/ 及生成的 Assets
```

## 项目结构

```
VoiceInput/
├── Sources/VoiceInputApp/
│   ├── App/
│   │   ├── main.swift              # NSApplication 入口
│   │   └── AppDelegate.swift       # 应用生命周期，组件连接
│   ├── Audio/
│   │   ├── AudioRecorder.swift     # AVAudioEngine 录音 + RMS 电平计算
│   │   └── SpeechRecognizer.swift  # Apple Speech 流式识别
│   ├── UI/
│   │   ├── StatusBarController.swift  # 菜单栏图标、菜单、录音状态
│   │   ├── FloatingPanel.swift        # HUD 胶囊窗口
│   │   ├── WaveformView.swift         # 5 柱波形动画（CVDisplayLink）
│   │   └── SettingsWindow.swift       # LLM API 配置界面
│   ├── Input/
│   │   ├── FnKeyMonitor.swift      # 全局 Fn / 右 ⌘ 按键监听（CGEvent tap）
│   │   └── TextInjector.swift      # 剪贴板 + Cmd+V 注入，中文输入法处理
│   ├── LLM/
│   │   └── LLMRefiner.swift        # OpenAI 兼容接口后处理
│   └── Utils/
│       └── Defaults.swift          # UserDefaults 键名常量
├── Assets/
│   └── AppIcon.icns                # 由 Scripts/make_icon.py 生成
├── Scripts/
│   └── make_icon.py                # 用 Pillow 生成 AppIcon.icns
├── Info.plist
├── Entitlements.plist
├── Makefile
└── Package.swift
```

## 工作原理

```
[按住 Fn / 右 ⌘ / 点击菜单]
        │
        ▼
  CGEvent tap（FnKeyMonitor）
        │
        ├─► AVAudioEngine 启动 → PCM 音频流送入 SpeechRecognizer
        │
        ├─► SFSpeechAudioBufferRecognitionRequest → 实时部分结果
        │         显示在 FloatingPanel HUD
        │
[松开按键 / 点击"停止录音"]
        │
        ▼
  最终转录文本
        │
        ├─ (LLM 已开启?) ──► OpenAI 兼容接口 ──► 纠错后文本
        │
        └─► TextInjector：保存剪贴板 → 写入文本 → Cmd+V 粘贴 → 恢复剪贴板
                          （注入前先退出中文输入法）
```

## 常见问题

**Q: 按 Fn 键没有反应？**  
A: 检查辅助功能权限是否已授予（系统设置 › 隐私与安全 › 辅助功能）。也可以改用**右 Command 键**作为触发键。

**Q: 外接键盘的 Fn 键不生效？**  
A: 大多数第三方键盘的 Fn 键由固件处理，不向系统发送按键事件。使用**右 ⌘** 代替即可，效果完全相同。

**Q: 重新编译后辅助功能权限失效了？**  
A: 直接运行 `.build/` 下的二进制文件会导致这个问题。请使用 `make install` 安装到 `/Applications`，路径固定后只需授权一次。

**Q: 中文识别准确率不够高？**  
A: 开启 LLM 纠错功能（接入 GPT-4、Qwen 等模型），可显著修复同音字错误和专有名词误识。

## 许可证

[Apache License 2.0](LICENSE)

## 贡献

欢迎提交 Pull Request。重大改动请先开 Issue 讨论。
