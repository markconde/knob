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

### Download a whisper model

Knob uses [whisper.cpp GGML models](https://huggingface.co/ggerganov/whisper.cpp). The default is `small.en` — a good balance of speed and accuracy for English dictation.

```bash
mkdir -p ~/Library/Application\ Support/Knob/models
curl -L -o ~/Library/Application\ Support/Knob/models/ggml-small.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin
```

#### Available models

All models are hosted at [huggingface.co/ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp/tree/main). English-only (`.en`) models are faster and more accurate for English. Multilingual models support [99 languages](https://github.com/openai/whisper#available-models-and-languages).

| Model | English-only | Multilingual | Size | Relative speed | Notes |
|-------|-------------|-------------|------|---------------|-------|
| tiny | `ggml-tiny.en.bin` | `ggml-tiny.bin` | ~75 MB | Fastest | Low accuracy, good for testing |
| base | `ggml-base.en.bin` | `ggml-base.bin` | ~142 MB | Fast | Decent for short phrases |
| small | `ggml-small.en.bin` | `ggml-small.bin` | ~466 MB | Moderate | **Recommended.** Best speed/accuracy tradeoff |
| medium | `ggml-medium.en.bin` | `ggml-medium.bin` | ~1.5 GB | Slow | Better accuracy, noticeably slower |
| large-v3-turbo | — | `ggml-large-v3-turbo.bin` | ~1.6 GB | Slow | Best multilingual accuracy with turbo speed |

To download a different model, replace the filename in the curl command:

```bash
# Example: download the tiny.en model for faster but less accurate transcription
curl -L -o ~/Library/Application\ Support/Knob/models/ggml-tiny.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin
```

#### Configuration

Knob reads its settings from `~/Library/Application Support/Knob/config.json`. The file is created automatically on first launch with these defaults:

```json
{
  "language" : "en",
  "model" : "ggml-small.en.bin"
}
```

To use a different model, download it to the models directory and update `config.json`:

```bash
# 1. Download the model you want
curl -L -o ~/Library/Application\ Support/Knob/models/ggml-medium.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin

# 2. Update config.json to point to it
cat > ~/Library/Application\ Support/Knob/config.json << 'EOF'
{
  "model": "ggml-medium.en.bin",
  "language": "en"
}
EOF
```

Restart Knob after changing the config.

**`model`** — filename of the GGML model in the `models/` directory. Can be any model from the table above.

**`language`** — language code for transcription. Use `"en"` for English-only models. For multilingual models, use a [language code](https://github.com/openai/whisper#available-models-and-languages) like `"es"`, `"fr"`, `"de"`, `"ja"`, etc. Set to `"auto"` for automatic language detection.

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

## Custom Vocabulary

You can improve recognition of names, jargon, and uncommon words by adding them to a vocabulary file:

```bash
mkdir -p ~/Library/Application\ Support/Knob
cat > ~/Library/Application\ Support/Knob/vocab.txt << 'EOF'
Kubernetes
PostgreSQL
Anthropic
EOF
```

One word or phrase per line. These are passed as hints to whisper's `initial_prompt` parameter, which biases the model toward recognizing these terms. Restart Knob after editing — vocab is loaded fresh for each transcription.

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

## Troubleshooting

**Build fails with missing `whisper.h`** — run `bash Knob/Scripts/build-whisper.sh` manually before the Xcode build.

**Linker errors (undefined symbols)** — the set of `.a` files whisper.cpp emits can change between versions. Check `vendor/whisper.cpp/build/install/lib/` and update `OTHER_LDFLAGS` in `project.yml` to match, then rerun `xcodegen generate`.

**Accessibility permission not taking effect** — make sure you're granting permission to the exact binary you're running (during development that's the DerivedData build, not a copy). Quit and relaunch Knob after granting.

## TODO

- **Adaptive silence threshold.** The incremental transcription autosave splits audio at silence windows using a fixed absolute RMS threshold (0.01). In noisy environments (TV, fan, café), the noise floor sits above that threshold and no chunks are emitted — the app falls back to a single final paste. Upgrade the detector to a relative/adaptive threshold (e.g. split at windows significantly quieter than the surrounding audio's global RMS) so it self-calibrates to the ambient noise level.

## License

MIT
