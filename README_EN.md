[**🌐 English**](README_EN.md) | [**🇨🇳 中文**](README.md)

<div align="center">
  <img src="Assets/AppIcon.iconset/icon_128x128.png" width="96" alt="VoiceInput icon" />
  <h1>VoiceInput</h1>
  <p>Hold a key → speak → release. Text appears wherever your cursor is.</p>

  ![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple)
  ![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
  ![License](https://img.shields.io/badge/license-Apache%202.0-green)
  ![Build](https://img.shields.io/badge/build-passing-brightgreen)
</div>

---

## Overview

VoiceInput is a lightweight macOS menu-bar app that converts speech to text and injects it into any focused input field — terminal, browser, chat app, editor — without switching windows or clicking anything.

Press and hold **Fn** (or **Right ⌘**) → speak → release. Done.

> **This entire project was generated from a single prompt.** See [`PROMPT.sh`](PROMPT.sh) for the full prompt, powered by [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

https://github.com/user-attachments/assets/3228f78a-f035-447d-98ef-8826798a122c

## Features

| Feature | Description |
|---------|-------------|
| 🎙 **Push-to-talk** | Hold Fn / Right Command to record; release to inject |
| 🖱 **Mouse trigger** | Click "Start Voice Input" in the menu bar — no keyboard required |
| 🌊 **Live waveform HUD** | Capsule panel at the bottom of the screen with animated bars and real-time transcription preview |
| 🔤 **CJK-aware injection** | Automatically exits CJK input methods (Pinyin, Zhuyin, etc.) before pasting, then restores |
| 🌍 **Multi-language** | English, Simplified Chinese, Traditional Chinese, Japanese, Korean |
| 🤖 **LLM refinement** | Optional post-processing via any OpenAI-compatible API to fix homophones and technical terms |
| 🔒 **On-device STT** | Powered by Apple's Speech framework — audio never leaves your Mac |

## Keyboard Trigger Support

| Keyboard | Trigger key |
|----------|-------------|
| MacBook built-in | **Fn** |
| Apple Magic Keyboard | **Fn** |
| External keyboard with Fn | **Fn** (if firmware forwards to OS) |
| Any keyboard | **Right ⌘** (universal fallback) |

> **Tip:** If your external keyboard's Fn key doesn't work, use **Right ⌘** — it works on every keyboard.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode Command Line Tools (`xcode-select --install`)

## Installation

### Option A — Direct download (recommended)

Download  [VoiceInput.dmg](https://github.com/shibing624/VoiceInput/releases/download/v1.0.0/VoiceInput.dmg) , open it, and drag `VoiceInput.app` to your `Applications` folder.

### Option B — Build DMG yourself

```bash
make dmg            # builds release/VoiceInput.dmg
open release/VoiceInput.dmg
# drag VoiceInput.app → Applications
```

### Option C — Build & install directly

```bash
make install        # builds and copies to /Applications/VoiceInput.app
```

### Option D — Run without installing

```bash
make run            # builds and launches from release/
```

> **Why install to `/Applications`?**  
> Accessibility (global key monitoring) permission is tied to the app's path.  
> Installing to `/Applications` means you only need to grant it **once**.  
> Running directly from the build directory re-triggers the permission dialog on every rebuild.

## First Launch — Permissions

The app requires three permissions. macOS will prompt for each on first launch:

| Permission | Purpose | Where to grant |
|------------|---------|---------------|
| **Microphone** | Audio recording | System Settings › Privacy & Security › Microphone |
| **Speech Recognition** | Apple on-device STT | System Settings › Privacy & Security › Speech Recognition |
| **Accessibility** | Global Fn / Right ⌘ key monitoring | System Settings › Privacy & Security › Accessibility |

After granting Accessibility, the app auto-detects it within ~2 seconds — no manual restart needed.

## Usage

### Push-to-talk (keyboard)

1. Place cursor in any text field
2. **Hold Fn** (or **Right ⌘**) — HUD appears at the bottom of the screen
3. **Speak** — waveform animates, transcription previews in real time
4. **Release** — text is injected at the cursor position

### Click-to-talk (mouse)

1. Click the **waveform icon** in the menu bar
2. Click **"Start Voice Input"**
3. Speak — same HUD appears
4. Click the menu bar icon again → **"Stop Recording"** to finish

The status bar icon changes to a filled waveform (●) while recording.

### Language

Menu bar icon → **Language** → select your language.  
The setting is saved and applied immediately.

### LLM Refinement (optional)

Fixes speech recognition errors (homophones, misheard technical terms) via an LLM:

1. Menu bar icon → **LLM Refinement → Settings…**
2. Enter **API Base URL**, **API Key**, and **Model** (any OpenAI-compatible endpoint)
3. Click **Test Connection** to verify
4. **Save**, then enable via **LLM Refinement → Enable**

While active, the HUD briefly shows "Refining…" before the corrected text is injected.

## Build Commands

```bash
make build      # compile + assemble release/VoiceInput.app (with icon)
make run        # build + launch
make install    # build + install to /Applications
make dmg        # build + package as release/VoiceInput.dmg
make clean      # remove release/ and generated assets
```

## Project Structure

```
VoiceInput/
├── Sources/VoiceInputApp/
│   ├── App/
│   │   ├── main.swift              # NSApplication entry point
│   │   └── AppDelegate.swift       # App lifecycle, wires all components
│   ├── Audio/
│   │   ├── AudioRecorder.swift     # AVAudioEngine recording + RMS level metering
│   │   └── SpeechRecognizer.swift  # Apple Speech streaming recognition
│   ├── UI/
│   │   ├── StatusBarController.swift  # Menu bar icon, menus, recording state
│   │   ├── FloatingPanel.swift        # HUD capsule window
│   │   ├── WaveformView.swift         # 5-bar waveform animation (CVDisplayLink)
│   │   └── SettingsWindow.swift       # LLM API configuration UI
│   ├── Input/
│   │   ├── FnKeyMonitor.swift      # Global Fn / Right ⌘ key listener (CGEvent tap)
│   │   └── TextInjector.swift      # Clipboard + Cmd+V injection, CJK method handling
│   ├── LLM/
│   │   └── LLMRefiner.swift        # OpenAI-compatible API post-processing
│   └── Utils/
│       └── Defaults.swift          # UserDefaults key constants
├── Assets/
│   └── AppIcon.icns                # Generated by Scripts/make_icon.py
├── Scripts/
│   └── make_icon.py                # Generates AppIcon.icns via Pillow
├── Info.plist
├── Entitlements.plist
├── Makefile
└── Package.swift
```

## How It Works

```
[Hold Fn / Right ⌘ / Click menu]
        │
        ▼
  CGEvent tap (FnKeyMonitor)
        │
        ├─► AVAudioEngine starts → PCM buffers streamed to SpeechRecognizer
        │
        ├─► SFSpeechAudioBufferRecognitionRequest → live partial results
        │         shown in FloatingPanel HUD
        │
[Release key / Click "Stop Recording"]
        │
        ▼
  Final transcription text
        │
        ├─ (LLM enabled?) ──► OpenAI-compatible API ──► refined text
        │
        └─► TextInjector: save clipboard → write text → Cmd+V → restore clipboard
                          (exits CJK input method first if needed)
```

## Community & Support

- **GitHub Issues** — [Submit issue](https://github.com/shibing624/VoiceInput/issues)
- **WeChat Group** — Add WeChat ID `xuming624`, and leave a message "llm" to join the technical discussion group

<img src="https://github.com/shibing624/TreeSearch/blob/main/docs/wechat.jpeg" width="200" />

## License

[Apache License 2.0](LICENSE)

## Contributing

Pull requests are welcome. For major changes, please open an issue first.
