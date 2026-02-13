# Release Guide (Direct Download)

## Scope
This flow prepares an unsigned/direct-download style release candidate and supports optional publish actions (signing/notarization/appcast) behind an explicit flag.

## Required Tooling
- Xcode command line tools (`xcodebuild`, `xcrun`)
- `codesign`
- `ditto`
- Access to signing identity and notarization credentials (publish only)

## Environment Variables (publish only)
- `SIGNING_IDENTITY`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`
- `APPCAST_PATH`
- `APPCAST_PRIVATE_KEY_PATH`

Reference template: `.env.example`

## Preflight Checks Implemented
- Required commands available
- Required env vars present (when `--publish`)
- Signing identity present in keychain (when `--publish`)
- App bundle exists (when `--publish`)
- Appcast file exists (when `--publish`)
- Appcast private key exists (when `--publish`)

## Publish Flow Steps
1. Sign app bundle with `SIGNING_IDENTITY`.
2. Verify code signature.
3. Package zip artifact.
4. Submit for notarization, staple ticket, validate staple.
5. Perform appcast prerequisite step.

## Script Usage
Dry-run (default, non-destructive):
```bash
scripts/release.sh --version 0.1.0 --app-path /path/to/FreeThinker.app
```

Publish flow:
```bash
set -a; source .env; set +a
scripts/release.sh --version 0.1.0 --app-path /path/to/FreeThinker.app --publish
```

Build archive from project then package:
```bash
scripts/release.sh --version 0.1.0 --project FreeThinker.xcodeproj --scheme FreeThinker --publish
```

Build a runnable app bundle via SwiftPM (developer convenience):
```bash
swift build -c release
```

Note: SwiftPM builds a runnable binary, but does not produce a Finder-launchable `.app` bundle by default.
For shipping artifacts, prefer the `--app-path` (prebuilt `.app`) or `--project` archive flow.

Generated artifacts are written to:
- `dist/FreeThinker-<version>/FreeThinker.xcarchive`
- `dist/FreeThinker-<version>/FreeThinker-<version>.zip`

## Failure Guidance
- `Missing required environment variable`: load `.env` and retry.
- `Signing identity not found`: confirm certificate is imported into login keychain.
- `Appcast file not found`: ensure `APPCAST_PATH` points to the existing appcast file.
- `notarytool submit` failure: verify Apple credentials/team ID and network access.
- `stapler validate` failure: rerun notarization submission and ensure ticket issued.

## Rollback Notes
1. Do not modify previous release artifacts in-place.
2. Keep each release under a versioned output directory (`dist/FreeThinker-<version>`).
3. If publish fails after packaging, discard the failed candidate ZIP and rebuild from clean source tag.
4. Repoint appcast to last known-good version until a corrected candidate is validated.
