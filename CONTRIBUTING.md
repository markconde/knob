# Contributing

Knob is a personal project, but these guidelines keep the codebase consistent.

## Development workflow

1. Make sure prerequisites are installed (see [SETUP.md](SETUP.md))
2. Create a feature branch off `main`
3. Make changes
4. Regenerate the project if you modified `project.yml`:
   ```bash
   xcodegen generate
   ```
5. Build and test:
   ```bash
   xcodebuild -project Knob.xcodeproj -scheme Knob -configuration Debug -arch arm64 build
   ```
6. Commit with a clear message

## Project conventions

### Source of truth

- **`project.yml`** defines the Xcode project. Never edit `Knob.xcodeproj` directly — it is gitignored and regenerated from `project.yml` via XcodeGen.

### Code style

- Swift 6 with strict concurrency enabled
- No third-party Swift packages unless absolutely necessary
- whisper.cpp is the only external dependency, linked as a static C library
- Keep the bridging header minimal — only `#include "whisper.h"`

### File organization

| Directory | Contents |
|---|---|
| `Knob/App/` | App entry point (`@main`) |
| `Knob/Sources/` | All application code |
| `Knob/Resources/` | Asset catalog, any bundled resources |
| `Knob/Support/` | Info.plist, entitlements, bridging header |
| `Knob/Scripts/` | Build scripts |
| `vendor/whisper.cpp/` | Git submodule (do not modify) |

### Adding new Swift files

Place them in `Knob/Sources/`. XcodeGen automatically picks up new files in source directories — just regenerate:

```bash
xcodegen generate
```

### Updating whisper.cpp

```bash
cd vendor/whisper.cpp
git fetch origin
git checkout <desired-tag-or-commit>
cd ../..
git add vendor/whisper.cpp
```

Then rebuild:

```bash
bash Knob/Scripts/build-whisper.sh
```

Check for linker changes — new versions may add or rename static libraries.

## Commit messages

- Use imperative mood: "Add hotkey listener", not "Added hotkey listener"
- Keep the first line under 72 characters
- Reference the implementation phase if relevant (e.g., "Phase 2: add CGEvent tap")

