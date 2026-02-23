#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/setup_local_firebase.sh [SECRETS_ROOT]

SECRETS_ROOT defaults to:
  $HOME/.config/multicamera_tracking/firebase/dev

Expected source tree:
  SECRETS_ROOT/android/app/google-services.json
  SECRETS_ROOT/ios/Runner/GoogleService-Info.plist
  SECRETS_ROOT/macos/Runner/GoogleService-Info.plist
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

repo_root="$(git rev-parse --show-toplevel)"
secrets_root="${1:-$HOME/.config/multicamera_tracking/firebase/dev}"

declare -a files=(
  "android/app/google-services.json"
  "ios/Runner/GoogleService-Info.plist"
  "macos/Runner/GoogleService-Info.plist"
)

copied_count=0

for rel in "${files[@]}"; do
  src="${secrets_root}/${rel}"
  dst="${repo_root}/${rel}"

  if [[ -f "${src}" ]]; then
    mkdir -p "$(dirname "${dst}")"
    cp "${src}" "${dst}"
    chmod 600 "${dst}" || true
    echo "Copied ${rel}"
    copied_count=$((copied_count + 1))
  else
    echo "Skipped ${rel} (missing: ${src})"
  fi
done

if [[ "${copied_count}" -eq 0 ]]; then
  echo "No Firebase config files were copied."
  echo "Run with --help to verify expected paths."
  exit 1
fi

echo "Firebase local setup complete (${copied_count} files copied)."
