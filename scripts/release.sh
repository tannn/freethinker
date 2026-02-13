#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 --version <version> [options]

Options:
  --version <v>           Release version (required)
  --app-path <path>       Existing .app bundle path (optional)
  --project <path>        Xcode project path for archive build (optional)
  --scheme <name>         Xcode scheme (default: FreeThinker)
  --configuration <name>  Build configuration (default: Release)
  --output-dir <path>     Output directory (default: dist)
  --publish               Execute distribution actions (default is dry-run)
  --help                  Show this help

Default behavior is non-destructive dry-run. Use --publish to execute signing/notarization/appcast steps.
USAGE
}

log() {
  printf '[release] %s\n' "$*"
}

fail() {
  printf '[release] ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || fail "Missing required environment variable: $name"
}

run_publish_step() {
  if [[ "$PUBLISH" -eq 1 ]]; then
    "$@"
  else
    log "SKIP (publish only): $*"
  fi
}

VERSION=""
APP_PATH=""
PROJECT_PATH="${PROJECT_PATH:-}"
SCHEME="${SCHEME:-FreeThinker}"
CONFIGURATION="${CONFIGURATION:-Release}"
OUTPUT_DIR="dist"
PUBLISH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --app-path)
      APP_PATH="${2:-}"
      shift 2
      ;;
    --project)
      PROJECT_PATH="${2:-}"
      shift 2
      ;;
    --scheme)
      SCHEME="${2:-}"
      shift 2
      ;;
    --configuration)
      CONFIGURATION="${2:-}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --publish)
      PUBLISH=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$VERSION" ]] || fail "--version is required"

require_cmd xcodebuild
require_cmd xcrun
require_cmd ditto
require_cmd codesign
require_cmd security

mkdir -p "$OUTPUT_DIR"

RELEASE_DIR="$OUTPUT_DIR/FreeThinker-$VERSION"
mkdir -p "$RELEASE_DIR"

ARCHIVE_PATH="$RELEASE_DIR/FreeThinker.xcarchive"
ZIP_PATH="$RELEASE_DIR/FreeThinker-$VERSION.zip"

if [[ -z "$APP_PATH" && -n "$PROJECT_PATH" ]]; then
  APP_PATH="$ARCHIVE_PATH/Products/Applications/FreeThinker.app"
  log "Building archive from project: $PROJECT_PATH"
  if [[ "$PUBLISH" -eq 1 ]]; then
    xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION" -archivePath "$ARCHIVE_PATH" archive
  else
    # Dry-run still builds a local unsigned release candidate for validation.
    xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION" -archivePath "$ARCHIVE_PATH" archive CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
  fi
fi

[[ -n "$APP_PATH" ]] || fail "Provide --app-path or --project"
[[ -d "$APP_PATH" ]] || fail "App bundle not found: $APP_PATH"

if [[ "$PUBLISH" -eq 1 ]]; then
  require_env SIGNING_IDENTITY
  require_env APPLE_ID
  require_env APPLE_APP_SPECIFIC_PASSWORD
  require_env APPLE_TEAM_ID
  require_env APPCAST_PATH
  require_env APPCAST_PRIVATE_KEY_PATH

  [[ -d "$APP_PATH" ]] || fail "App bundle not found: $APP_PATH"
  [[ -f "$APPCAST_PATH" ]] || fail "Appcast file not found: $APPCAST_PATH"
  [[ -f "$APPCAST_PRIVATE_KEY_PATH" ]] || fail "Appcast private key not found: $APPCAST_PRIVATE_KEY_PATH"

  if ! security find-identity -v -p codesigning | grep -F "$SIGNING_IDENTITY" >/dev/null; then
    fail "Signing identity not found in keychain: $SIGNING_IDENTITY"
  fi
fi

if [[ "$PUBLISH" -eq 1 ]]; then
  log "Signing app bundle"
  codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_PATH"
fi

if [[ "$PUBLISH" -eq 1 ]]; then
  log "Verifying code signature"
  codesign --verify --deep --strict "$APP_PATH"
else
  log "Skipping signature verification in dry-run (unsigned candidates are allowed)."
fi

log "Packaging app bundle"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

log "Writing checksum"
shasum -a 256 "$ZIP_PATH" > "$ZIP_PATH.sha256"

if [[ "$PUBLISH" -eq 1 ]]; then
  log "Notarization + stapling"
  run_publish_step xcrun notarytool submit "$ZIP_PATH" --apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait
  run_publish_step xcrun stapler staple "$APP_PATH"
  run_publish_step xcrun stapler validate "$APP_PATH"

  log "Appcast prerequisites"
  run_publish_step /usr/bin/env bash -lc "echo 'Update appcast at \"$APPCAST_PATH\" for version $VERSION and sign with \"$APPCAST_PRIVATE_KEY_PATH\".'"
else
  log "DRY-RUN: notarization and appcast steps are skipped until --publish is provided."
fi

if [[ "$PUBLISH" -eq 1 ]]; then
  log "Release publish flow completed."
else
  log "Dry-run completed. Re-run with --publish to execute distribution actions."
fi
