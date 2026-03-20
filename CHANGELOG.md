# Changelog

All notable changes to Knob are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Push-to-talk dictation via Right Option key
- whisper.cpp inference with Metal GPU acceleration (small.en model)
- Audio capture via AVAudioEngine with 48kHz to 16kHz resampling
- Clipboard save/restore with synthetic Cmd+V paste
- Menu bar UI with status display (Ready/Recording/Transcribing)
- Accessibility permission check with automatic prompt and polling
- XcodeGen-based build system
- whisper.cpp as git submodule with CMake build script
