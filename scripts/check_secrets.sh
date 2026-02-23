#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "${repo_root}"

status=0

declare -a firebase_files=(
  "android/app/google-services.json"
  "ios/Runner/GoogleService-Info.plist"
  "macos/Runner/GoogleService-Info.plist"
)

for rel in "${firebase_files[@]}"; do
  if git ls-files --error-unmatch "${rel}" >/dev/null 2>&1; then
    echo "ERROR: secret config is tracked: ${rel}"
    status=1
  fi
done

if git grep -n -E 'AIza[0-9A-Za-z_-]{35}' -- . >/tmp/mct_secrets_scan.out 2>/dev/null; then
  echo "ERROR: possible Google API key found in tracked files:"
  cat /tmp/mct_secrets_scan.out
  status=1
fi

if [[ "${status}" -eq 0 ]]; then
  echo "OK: no tracked Firebase secret files or obvious Google API keys found."
fi

exit "${status}"
