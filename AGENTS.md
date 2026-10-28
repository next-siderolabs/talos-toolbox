# AGENTS.md

Shell-script + Dockerfile repo. There is no source code, test suite, linter, or local
build tooling. Do not search for a test runner or lint config — they don't exist.
CI reviews then builds: every PR into `main`/`master` gets an automatic OpenCode
review (`.github/workflows/opencode-review.yml`, job `review`; also on-demand via
`/oc` comments; automatic mode only fires for OWNER/MEMBER/COLLABORATOR authors) and
a build-only check (`build-push.yaml`). `build-push.yaml` gates main pushes: its
`Verify the merge was reviewed` step (push events only) fails the job unless the head
commit came from a merged PR whose `review` check-run succeeded on the PR head SHA;
cron and workflow_dispatch rebuilds skip the step. Blocking bad merges outright is a
repo setting, not in the files: branch protection on `main` should require the
`review` + build checks and restrict direct pushes. Pushes to `main` or `master` push
to GHCR with tags `latest` + `YYYYMMDD` + `sha-<7chars>` (the date/latest tags are
default-branch only). No platform matrix is configured, so published images are
linux/amd64 only. A weekly cron rebuild keeps the apk packages fresh.

## The three pieces and how they're wired

- `kubectl-talos_toolbox` — a kubectl plugin. The filename MUST stay `kubectl-<name>`
  (kubectl maps the command's dash onto the filename's underscore — verified with
  kubectl 1.37: `kubectl foo-bar` executes `kubectl-foo_bar`), which makes the command
  `kubectl talos-toolbox`. Client-side: reads
  `${XDG_CONFIG_HOME:-~/.config}/talos-toolbox/config.env` (with a fallback to the legacy
  `talos-toolbx` dir for old installs), exports its three `OMNI_*`
  variables, and passes them as `--env` flags to
  `kubectl debug node/<name> --profile=sysadmin` (which mounts the host root at `/host`).
- `Dockerfile` + `bashrc` — the debug image. `bashrc` is COPYed to `/root/.bashrc`;
  it defines `load-talos`/`load-kube` (which consume exactly those three `OMNI_*` env
  vars — renaming one side requires editing both files), an EXIT trap that wipes
  `~/.kube` and `~/.talos`, and a `drbdadm` wrapper that `crictl exec`s into the Linstor
  satellite container. All crictl/containerd endpoints assume the host is mounted at `/host`.
- The image tag chain: CI tags pushes with `type=sha,format=short` (`sha-<7chars>`),
  and the plugin queries the GitHub commits API for the latest short SHA on `main` to
  pick the `ghcr.io/...:sha-<7chars>` tag. The `latest` fallback only fires when the API
  request fails, not when the tag is missing: running the plugin right after a push to
  `main`, before CI has finished, fails with an image-pull error. After pushing, wait
  for the CI build before testing the plugin against that commit.

## Repo naming is coupled across three places

The plugin pins its image/tag resolution to one `REPO` variable
(`next-siderolabs/talos-toolbox`) + branch `main` (GitHub API for the tag, and the
`ghcr.io/...` image); CI builds `${{ github.repository }}`, and the README documents the
clone URL. The plugin's API query follows `main` only, even though CI also triggers on
`master`. If the repo is renamed or the default branch changes, update the script's
`REPO`, and the README (CI follows the repo automatically).

Branding is unified to `Toolbox` everywhere except the script's launch message (cosmetic
only). The config dir is `talos-toolbox`
now; the script keeps a legacy `talos-toolbx` fallback (marked with a `shortcut:`
comment) — don't remove it until no old installs exist.

## Adding tools to the image

- Check the upstream release asset list (GitHub `/releases/latest` API) before writing a
  download URL: asset naming differs per repo and often drops the `v` prefix
  (`helmfile_1.8.2_linux_amd64.tar.gz` with underscores vs `diff-3.15.15-linux-amd64.tgz`
  with dashes vs `k9s_Linux_amd64.tar.gz`). Pins are v-prefixed; the Dockerfile strips it
  with `${VAR#v}` inside the URL strings.
- `kubectl-ko` is not a binary: it is a shell script (arch-independent, needs `chmod`)
  fetched from `raw.githubusercontent.com/kubeovn/kube-ovn/<tag>/dist/images/kubectl-ko`;
  its Renovate pin tracks `kubeovn/kube-ovn` releases.
- helm-diff installs as a helm plugin extracted into `/root/.local/share/helm/plugins`
  (not a `/usr/local/bin` binary); `helm diff` resolves it from there.
- Keep the README "Pre-installed Tooling" list in sync with the Dockerfile.

## Renovate conventions

Tool versions are pinned as `ARG *_VERSION` in the Dockerfile, each preceded by a
`# renovate: datasource=... depName=...` comment. The custom regex manager requires the
comment line immediately above the `ARG` line — keep them adjacent and in that format
or Renovate stops tracking the version. Minor/patch bumps automerge, gated on the CI
build check; majors wait on the dashboard.

## Verifying changes

- Dockerfile changes: `docker build -t talos-toolbox .` is the only local check
  (needs network to fetch tool tarballs; buildkit passes `TARGETARCH`).
- Script/bashrc changes: verify with `bash -n <file>` and, if available, `shellcheck`.
  No automated test exists; behavior only manifests against a real Omni-backed cluster.
- `opencode.json` is local personal config (a local model provider with an API key);
  keep it out of commits.
