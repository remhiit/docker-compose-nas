#!/bin/bash
set -euo pipefail

# Only run in the Claude Code remote (web) environment.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}"

# The repository validates itself with `docker compose config`, which requires
# a `.env` file (variables are interpolated at parse time). `.env` is gitignored,
# so create it from the tracked example if it does not already exist.
if [ ! -f .env ] && [ -f .env.example ]; then
  cp .env.example .env
  echo "Created .env from .env.example"
else
  echo ".env already present or no .env.example found; leaving it untouched"
fi
