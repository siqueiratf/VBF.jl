#!/usr/bin/env bash
set -euo pipefail

pattern="${1:-}"

if [[ -z "$pattern" ]]; then
  echo "Usage: ./add_papers <string>"
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

git ls-files --modified --others --exclude-standard -z \
  | grep -zF "$pattern" \
  | xargs -0 -r git add --