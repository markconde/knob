# Knob

A native macOS menu bar app for offline push-to-talk dictation using [whisper.cpp](https://github.com/ggml-org/whisper.cpp).

Hold a hotkey, speak, release — transcribed text is pasted at your cursor. No cloud, no accounts, no Electron. Just a Swift app and a C library.

## Requirements

- macOS 14+ (Sonoma or later)
- Apple Silicon (M1/M2/M3/M4)
- Xcode 16+
- [CMake](https://cmake.org/) and [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Quick Start

```bash
# Install build tools
brew install cmake xcodegen

# Clone with submodules
git clone --recurse-submodules https://github.com/markconde/knob.git
cd knob

# Generate Xcode project and build
xcodegen generate
bash Knob/Scripts/build-whisper.sh
xcodebuild -project Knob.xcodeproj -scheme Knob -configuration Debug -arch arm64 build
```

### Download the model

Knob uses the `ggml-small.en.bin` whisper model (~466 MB). Download it from [Hugging Face](https://huggingface.co/ggerganov/whisper.cpp/tree/main) and place it in:

```
~/Library/Application Support/Knob/models/ggml-small.en.bin
```

## How It Works

1. **Hold Right Option** — starts recording from your microphone
2. **Release** — audio is transcribed locally via whisper.cpp with Metal GPU acceleration
3. **Text is pasted** at your cursor position via synthetic Cmd+V

The entire pipeline runs offline on your Mac. Audio never leaves the device.

## Permissions

Knob requires two macOS permissions:

| Permission | Purpose |
|---|---|
| **Accessibility** | Global hotkey capture and synthetic paste |
| **Microphone** | Audio recording |

On first launch the app will prompt you to grant these in System Settings.

## Project Structure

```
Knob/
├── App/             # App entry point
├── Sources/         # Application code
├── Resources/       # Asset catalog
├── Support/         # Info.plist, entitlements, bridging header
└── Scripts/         # Build scripts (whisper.cpp CMake)
vendor/
└── whisper.cpp/     # Git submodule
project.yml          # XcodeGen spec (source of truth)
```

## Performance Targets

- < 2s inference for 10s of audio
- < 3s end-to-end for 5s of speech
- < 200 MB RAM idle, < 1 GB during inference

## License

MIT
