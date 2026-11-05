# AGENTS.md

Two deliverables in one repo, both named `next-siderolabs/talos-toolbox`:

1. **`kubectl-talos_toolbox`** (bash script) — a kubectl plugin. It reads
   `~/.config/talos-toolbox/config.env` (`OMNI_ENDPOINT`,
   `OMNI_SERVICE_ACCOUNT_KEY`, `OMNI_CLUSTER_NAME`), resolves the latest
   `sha-<short7>` tag of this repo via the GitHub API, and runs
   `kubectl debug node/<node> --profile=sysadmin --image-pull-policy=Always`.
   The filename prefix `kubectl-` is load-bearing (kubectl discovers plugins
   by name). Config lives under XDG config; a legacy `talos-toolbx` fallback
   path exists — keep it working.
2. **`Dockerfile`** — Alpine debug image published to
   `ghcr.io/next-siderolabs/talos-toolbox` with tags `latest`, `YYYYMMDD`, and
   `sha-<short7>`. `bashrc` is copied to `/root/.bashrc` inside the image; its
   `load-talos` / `load-kube` aliases expect the three OMNI env vars the plugin
   injects.

## CI / release flow

- No local build/test/lint scripts. All publishing happens in
  `.github/workflows/build-push.yaml`: builds on push to main, weekly cron
  (fresh apk packages), and manual dispatch.
- Merging to main is gated: `build-push.yaml` fails if the push is not a
  merged PR with a passing `review` status check from
  `opencode-review.yml`. So the flow is always: branch → PR → OpenCode
  review → merge → image published.
- The plugin resolves the `sha-` tag from the *default branch's latest
  commit*, so image changes only take effect after merge to main.

## Dockerfile rules

- amd64 only — the `TARGETARCH` case statement exits on anything else.
- Each tool has a `# renovate: datasource=... depName=...` comment above its
  `ARG <NAME>_VERSION`. Renovate bot bumps these automatically; never change
  a version string without keeping its renovate comment intact.
- Versions must match upstream release tag names exactly. Several download
  URLs strip the leading `v` (`${X_VERSION#v}`); check the URL pattern
  before assuming a new version will resolve.
- The final `RUN` is the smoke test: it runs `--version` on the installed
  CLIs, so a broken binary fails the build. Validate changes with
  `docker build .`, not CI.

## Gotchas

- `bashrc` is baked into the image; edits require a new image publish, not
  just a plugin-script change.
- `opencode.json` (tracked) configures the OpenCode review bot;
  `.opencode.json` is gitignored — don't commit it.
- The plugin expects `ghcr.io` to already have the `sha-<hash>` tag; the
  tag only exists after CI finishes building the merge commit.
