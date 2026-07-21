# Repository guidance for Claude

## Branch workflow (important)

This repository is a **fork** of an upstream project, with a specific branch layout:

- **`master`** — mirror of the upstream fork's `master`. **Do not target it with PRs.**
  Updates arrive here only by syncing with the upstream repository, never through
  changes authored in this fork.
- **`home_nas`** — the working branch for all local modifications. **Every PR must
  target `home_nas`.**

### Rules

- Base all feature branches on `home_nas` and open pull requests **against `home_nas`**.
- Never push to, or open PRs against, `master`.
- Never merge `home_nas` into `master`; keep `master` a clean mirror of upstream.

## Project overview

An opinionated Docker Compose configuration for a self-hosted NAS (media
automation, VPN, reverse proxy, and optional self-hosted apps). There are no
application-code dependencies to install.

## Validation

CI (`.github/workflows/main.yml`) validates the stack with `docker compose config`,
which interpolates variables from a `.env` file. To validate locally:

```bash
cp .env.example .env   # if .env does not already exist
docker compose config
```

A `SessionStart` hook (`.claude/hooks/session-start.sh`) creates `.env` from
`.env.example` automatically in Claude Code web sessions.
