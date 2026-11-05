# AGENTS.md

Operational notes for agents working in this repo. `talos-toolbox` is a Docker
debug image for Talos nodes on Sidero Omni, plus a kubectl plugin that launches
it. No test runner or lint config exists and none should be inferred — validate
shell with `bash -n` and let the CI build be the release gate.

## Repo layout

- `Dockerfile` — the image: `alpine:3.24.3` base, `TARGETARCH=amd64` default (no
  platform matrix, so published images are linux/amd64 only), three RUN layers
  then `COPY`/`ENV`/`ENTRYPOINT`.
- `bashrc` → `COPY`d to `/root/.bashrc`.
- `.github/workflows/` — two workflows (below).
- `README.md` — user-facing docs; keep its "Pre-installed Tooling" list in sync
  with the Dockerfile.

## Dockerfile structure

- Layer 1: `apk add` — distro-provided tooling (kubectl, helm, sops, age,
  jq/vim/tmux/aws-cli/debug tools). The weekly cron rebuild keeps apk packages
  fresh; pin the base tag (`alpine:3.24.x`).
- Layer 2: a `&&`-chained list of pinned downloads. Two asset patterns coexist:
  versionless assets (fetch directly, latest-style) and **versioned** assets
  whose asset names embed the version (`helm`, `helmfile`, `flux`, `sops`, `age`,
  `just` style — these fetch under `/releases/download/<tag>/...`). Versioned
  assets unpack to a scratch dir inside the layer (`/tmp`, or a dedicated dir
  like `/root/.local/share/helm/plugins` for helm plugins); the final `rm -rf`
  line of the layer removes that scratch content so it never bloats the image.
  Before writing a download URL, check the upstream release's asset list —
  asset names differ per project and change over time.
- Layer 3: writes `/etc/crictl.yaml` pointing at the containerd socket on the
  **host root mounted at `/host`**, plus symlinks `/var/log/pods` and
  `/var/log/containers` to `/host`.
- `COPY bashrc`, `ENV IMAGE_SERVICE_ENDPOINT` + `CONTAINER_RUNTIME_ENDPOINT`
  (same socket URI), `ENTRYPOINT [ "/bin/bash" ]`.

## CI / release flow

- `build-push.yaml`: pushes to `main`/`master` build and push to GHCR; weekly
  cron (`0 3 * * 0`) rebuilds. Published tags: `latest` + `YYYYMMDD` (default
  branch only) and `sha-<7 chars>` per commit. Its `Verify the merge was
  reviewed` step (push events only) fails unless the pushed SHA has a passing
  `review` check-run — so merge → push is the release path; direct pushes skip
  nothing except when branch protection blocks them.
- `opencode-review.yml`: OpenCode review on PRs from this repo's branches and
  `/oc` comments (OWNER/MEMBER/COLLABORATOR). Self-hosted runner group; injects
  its OpenCode config inline (repo variable `STRATA_BASE_URL`, secret
  `STRATA_API_KEY`), which overrides any config file in the checkout.
- Branch protection on `main` (settings, not files) should require the `review`
  and build checks and restrict direct pushes.

## Conventions

- Renovate tracks each tool's version via a `# renovate: datasource=github-releases
  depName=<owner>/<repo>` comment immediately above each
  `ARG <NAME>_VERSION` line — keep them adjacent and one per tool.
- Keep the final in-layer cleanup list (`rm -rf ...`) in sync with wherever new
  scratch content lands.
- Verify Dockerfile changes with `docker build -t talos-toolbox .` locally when
  possible; CI runs the identical build on push.
