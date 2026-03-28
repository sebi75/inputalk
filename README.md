# Inputalk

Free, open-source dictation for macOS. Hold Fn, speak, release — text appears wherever your cursor is.

No cloud. No API keys. No cost. Transcription runs entirely on your Mac via [WhisperKit](https://github.com/argmaxinc/WhisperKit).

<video src="https://inputalk.s3.us-east-1.amazonaws.com/assets/demo.mp4" width="100%" autoplay loop muted playsinline></video>

## How it works

- **Hold Fn** — push-to-talk dictation. Release to transcribe and paste.
- **Double-press Fn** — hands-free dictation. Press Fn again to stop.
- Works in any app — Slack, VS Code, Terminal, Messages, browser, email, anything with a text field.

## Install

Download the latest `.dmg` from [inputalk.com](https://inputalk.com).

Open the DMG, drag to Applications. On first launch, grant Microphone and Accessibility permissions when prompted.

## Models

Whisper models download on first use and run on Apple Neural Engine.

| Model | Size | Speed | Quality |
|-------|------|-------|---------|
| tiny | 75 MB | ~10x realtime | Basic |
| **base** | **142 MB** | **~7x realtime** | **Good (default)** |
| small | 466 MB | ~4x realtime | Very good |
| medium | 1.5 GB | ~2x realtime | Excellent |

Switch models in Settings. Model data is stored in `~/Library/Application Support/com.inputalk.app/Models/` and removed on uninstall.

## Requirements

- macOS 15+
- Apple Silicon or Intel

## Build from source

```bash
cd macos
swift build
swift run
```

### Release build (signed + notarized)

```bash
# Set up .env with CODE_SIGN_IDENTITY
cd macos
./scripts/release.sh          # build + sign + notarize + DMG
./scripts/publish-release.sh  # upload to S3 + update latest.json
```

## Project structure

```
macos/          Swift app (SPM, macOS 15+)
  Sources/      AppDelegate, services, views
  Resources/    Info.plist, entitlements, icons
  scripts/      build, release, publish
web/            Landing page (Next.js 15 + Tailwind)
video/          Launch video (Remotion)
```

## Tech

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) — on-device speech-to-text via CoreML
- Swift 6, Swift Package Manager
- CGEvent tap for global Fn key capture
- Clipboard + simulated Cmd+V for text insertion
- Liquid Glass floating indicator (macOS Tahoe)

## License

[MIT](LICENSE)
