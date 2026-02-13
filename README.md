# FreeThinker
![macOS](https://img.shields.io/badge/macOS-blue) ![License](https://img.shields.io/badge/license-GPLv3-green)

Menu bar macOS app for generating concise AI provocations from selected text using on-device Apple Foundation Models.

![FreeThinker popup with AI generated provocation on user selected text on website](docs/images/preview.png)

> **Beta** — under active development

## What it does

FreeThinker is a local-first AI thought companion. Select text anywhere on your Mac, press the global hotkey, and get AI-generated "provocations" that challenge and extend your thinking — all without sending a single byte off your machine.

Strenghten your thinking. Be a FreeThinker.

### Features

- **Completely local** — AI runs on-device via Apple Foundation Models. No API keys, no cloud, no internet required after install.
- **Private by design** — all text input, customizations, and AI interactions stay on your Mac. Nothing is transmitted to external services.
- **AI provocations** — select text to get a short, thought-provoking AI response streamed in real time.
- **Customizable provocation styles** - Choose from contrarian, socratic, or systems thinking to interrogate selected text.
- **Free software** — GPLv3.

## Requirements
- macOS 26+
- Apple Silicon
- Xcode 16.0+ to build from source

## Developer Entry Points
- Quickstart: `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/quickstart.md`
- Manual QA checklist: `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/research/manual-qa-checklist.md`
- Release sign-off: `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/research/release-signoff.md`
- Release process: `docs/release.md`

## Test Command
```bash
swift test
```
