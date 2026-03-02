# FreeThinker
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/tannn/freethinker/swift.yml) ![macOS](https://img.shields.io/badge/macOS-blue) ![License](https://img.shields.io/badge/license-GPLv3-green)

Menu bar macOS app for generating concise AI provocations from selected text using on-device Apple Foundation Models. Think of it as your personal thought companion.

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

## Getting Started

### Clone & Resolve
```bash
git clone https://github.com/tannn/freethinker.git
cd freethinker
swift package resolve
```

### Building
You can open `Package.swift` directly in Xcode, or generate the Xcode project via XcodeGen:

```bash
# Generate .xcodeproj from project.yml
xcodegen generate
```

To build from the command line:
```bash
swift build
```

### Running Tests
```bash
# Via SwiftPM
swift test

# Via xcodebuild (if using .xcodeproj)
xcodebuild test -scheme FreeThinker
```

## Development Setup

### Git Hooks

After cloning, install the tracked git hooks to enable local enforcement of project standards:

```bash
bash scripts/setup-hooks.sh
```

This symlinks everything in `git-hooks/` into `.git/hooks/`. It is idempotent — safe to re-run.

### Commit Convention

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>
```

- **type** — one of: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `style`, `perf`, `ci`
- **scope** — optional, lowercase alphanumeric (e.g. `ui`, `model`, `deps`)
- **description** — lowercase imperative phrase, no trailing period, max 72 chars on the subject line
- **body** — optional; must be separated from the subject by a blank line

Examples:

```
feat(ui): add dark mode toggle
fix: handle nil pointer in model loader
docs: update contributing guidelines
chore(deps): bump sparkle to 2.6.4
```

The `commit-msg` hook (installed by `setup-hooks.sh`) validates this format automatically.
