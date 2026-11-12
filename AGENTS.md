# AGENTS.md

Two deliverables in one repo, both named `next-siderolabs/talos-toolbox`:

1. **`kubectl-talos_toolbox`** (bash script) — a kubectl plugin. It reads
   `~/.config/talos-toolbox/config.env` (`OMNI_ENDPOINT`,
   `OMNI_SERVICE_ACCOUNT_KEY`, `OMNI_CLUSTER_NAME`), resolves the latest
   `sha-<short7>` tag of this repo via the GitHub API, and runs
   `kubectl debug node/<node> --profile=sysadmin --image-pull-policy=Always -- bash`.
   The trailing `-- bash` is load-bearing: the image's `CMD` is
   `sleep infinity`, not a shell.
   The filename prefix `kubectl-` is load-bearing, and so is the underscore:
   `kubectl talos-toolbox` looks up `kubectl-talos_toolbox` (kubectl swaps
   `-`→`_` in plugin lookup), so never rename it to all-hyphens. Config lives
   under XDG config; a legacy `talos-toolbx` fallback path exists — keep it
   working. If the GitHub API is unreachable the plugin falls back to the
   `latest` tag.
2. **`Dockerfile`** — Alpine debug image published to
   `ghcr.io/next-siderolabs/talos-toolbox` with tags `latest`, `YYYYMMDD`, and
   `sha-<short7>`. `bashrc` is copied to `/root/.bashrc` inside the image; its
   `load-talos` / `load-kube` aliases expect the three OMNI env vars the plugin
   injects.

## CI / release flow

- No local build/test/lint scripts. All publishing happens in
  `.github/workflows/build-push.yaml`: builds on push to main, build-only on
  PRs (the check Renovate automerge waits on), weekly cron (fresh apk
  packages), and manual dispatch.
- Merging to main is gated: `build-push.yaml` fails if the push is not a
  merged PR with a passing `review` status check from
  `opencode-review.yml`. So the flow is always: branch → PR → OpenCode
  review → merge → image published. Comment `/oc` or `/opencode` on a PR to
  re-run the review on demand.
- The review workflow skips fork PRs, so a fork PR can never pass the gate —
  always work on branches of the repo itself.
- Renovate (config in `renovate.json`) automerges minor/patch/digest/pin bumps
  of the Dockerfile `ARG *_VERSION` pins; majors stay on the dashboard for a
  human.
- The plugin resolves the `sha-` tag from the latest commit on `main`
  (hardcoded in the script), so image changes only take effect after merge.

## Dockerfile rules

- amd64 only — the `TARGETARCH` case statement exits on anything else.
- Each tool has a `# renovate: datasource=... depName=...` comment above its
  `ARG <NAME>_VERSION`. Renovate bot bumps these automatically; never change
  a version string without keeping its renovate comment intact.
- Versions must match upstream release tag names exactly. Several download
  URLs strip the leading `v` (`${X_VERSION#v}`); check the URL pattern
  before assuming a new version will resolve.
- Two verification stages: the install `RUN` only checks every binary exists
  and is executable; the final `RUN` runs `--version` on a subset (talosctl,
  kubectl, helm, just, sops, age, openstack). A new tool must be added to
  both, or a broken binary can pass the build. Validate changes with
  `docker build .`, not CI.

## Gotchas

- `bashrc` is baked into the image; edits require a new image publish, not
  just a plugin-script change.
- The review bot's provider config is injected inline via
  `OPENCODE_CONFIG_CONTENT` in `opencode-review.yml`, *not* from
  `opencode.json`. Both `opencode.json` and `.opencode.json` are gitignored
  personal local-dev config — never commit them.
- The plugin expects `ghcr.io` to already have the `sha-<hash>` tag; the
  tag only exists after CI finishes building the merge commit.
