# release-tool

Creates `-stg` and `-prd` GitHub releases from semver tags to automate
the deployment to stage and production.

## Setup

```bash
uv sync
export GITHUB_TOKEN=ghp_xxx  # needs "repo" scope, or "Contents: Read and write"
```

## Usage

Create the next staging release (bumps the latest `-stg` tag, e.g. `v1.2.3-stg` → `v1.2.4-stg`):

```bash
uv run release.py FlyingCockatoo/platform-web stage
uv run release.py FlyingCockatoo/platform-final stage --bump minor
uv run release.py FlyingCockatoo/backoffice-final stage --target release/1.3
```

Promote the latest staging release to production (`v1.2.4-stg` → `v1.2.4-prd`, same commit):

```bash
uv run release.py FlyingCockatoo/platform-final prod
```

Preview without creating anything, or pass the token directly:

```bash
uv run release.py FlyingCockatoo/platform-final prod --dry-run
uv run release.py FlyingCockatoo/platform-final stage --token ghp_xxx
```

Every release asks for confirmation before it is created. Run `uv run release.py --help` for all options.
