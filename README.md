# django-ai-ci

Reusable GitHub Actions workflows for Django projects generated from the `django-build` Copier template.
They own *how* a job runs (runners, tool setup, caches, service containers, report upload). The project owns
*what* runs, in `scripts/ci/*.sh`. See `docs/ci.md` in a generated project for the ownership contract and the
script contract.

NOTE: this repo must stay public for project repos to be able to reference versions.

Status: scaffold. No workflow is published yet.

## Workflows

| Workflow | Purpose | Added |
|---|---|---|
| `reusable-semgrep.yml` | Semgrep scan; skips with a notice when `SEMGREP_APP_TOKEN` is unset. No inputs; secret `SEMGREP_APP_TOKEN` (optional); needs `contents: read` | unreleased |
| `reusable-django-ci.yml` | `quality`, `test`, `test-postgres`. Inputs: `python-version`, `node-version`, `postgres-version`, `run-postgres-tier`; needs script contract 1 | unreleased |
| `reusable-mutation.yml` | job `mutation`. Inputs: `mode` (`nightly`\|`weekly`, required), `strict` (weekly only), `python-version`, `node-version`, `timeout-minutes` (300); needs script contract 1 | unreleased |
| `reusable-slow.yml` | job `slow`. Inputs: `python-version`, `node-version`, `timeout-minutes` (240); needs script contract 1 | unreleased |
| `reusable-pre-release.yml` | job `pre-release`. Inputs: `python-version`, `node-version`, `postgres-version`; needs script contract 1 | unreleased |
| `reusable-playwright.yml` | job `e2e`. Input: `timeout-minutes` (60). Runs `scripts/ci/e2e.sh`, uploads `playwright-report/` and `test-results/` (30 days), tears the stack down; needs Docker on the runner and script contract 1 | unreleased |

Inputs, secrets and permissions are documented per workflow here as each one lands.

## Calling a workflow

```yaml
jobs:
  ci:
    uses: jvezina/django-ai-ci/.github/workflows/reusable-django-ci.yml@v1.0.0
    secrets: inherit
```

`schedule:` and `workflow_dispatch:` triggers stay in the caller. Caller `env:` does not cross into a reusable
workflow; use `with:` inputs.

## Shared blocks

Two blocks of steps are copied into the jobs that need them, between `# BEGIN shared:<name>` and
`# END shared:<name>` comment markers:

- `shared:contract`: reads the project's `scripts/ci/CONTRACT_VERSION` and fails fast, before any tool is
  installed, when it does not match the number written in the step. Every job that runs project scripts has it.
- `shared:setup`: `setup-uv`, `setup-node` and `bash scripts/ci/setup.sh "${{ github.job }}"`. Every job that
  needs Python and Node has it. The job id is passed as the tier, so job ids are part of the script contract.

`scripts/check_shared_blocks.sh` fails when copies of a block differ, and when a `reusable-*.yml` has a different
number of blocks than `actions/checkout` steps (a job lost its block). Playwright (no setup) and Semgrep (neither
block) are allowlisted in the script. Edit all copies together.

## Rules for changing a workflow

- **Inputs are public contract.** Add one only when a second project needs it. A project's own tools,
  services and packages go in the project (`scripts/ci/setup.local.sh`, its own scripts or workflow files),
  never here.
- **Pins.** Third-party actions, the Semgrep image and the runner image (`ubuntu-24.04`, never
  `ubuntu-latest`) are pinned to exact versions, written literally. Moving to a newer Ubuntu is a deliberate
  release: test it from a consumer first, and make it a minor version at least.
- **Job ids.** The ids `quality`, `test`, `test-postgres`, `mutation`, `slow` and `pre-release` are passed to
  projects' `setup.sh`/`setup.local.sh`. Renaming or removing one is a new major version; adding one is a minor.
- **Test from a consumer.** Open a draft PR in a consumer that points `uses:` at your branch
  (`…@my-branch`) and get it green before merging. Merge and tag only then.
- **Contract.** A change to a project script's invocation, environment or exit codes raises
  `CONTRACT_VERSION`, changes the number in `shared:contract` everywhere, and is a new major version.

## Releasing a new version of the CI

Work in this repo. Tags are immutable: never move or delete a published tag. A bad release is fixed by a new
patch version.

1. **Pick the version number** (`vMAJOR.MINOR.PATCH`):
   - patch: a fix, or a bumped pin (action, Semgrep image), with no change to inputs or behavior;
   - minor: a new workflow, a new optional input, or a new job id;
   - major: a removed or renamed workflow, input, secret or job id, a required new input, or a new script
     contract version (`CONTRACT_VERSION`).
2. **Branch** from `main` (`git switch -c release/vX.Y.Z`) and make the change.
3. **Contract change only (major):** change the expected number in the `# BEGIN shared:contract` step in
   *every* workflow (the lint fails if the copies differ). Plan the matching project change: the template
   must ship the new scripts and `scripts/ci/CONTRACT_VERSION` before projects move to this release.
4. **Bump by hand what Dependabot does not manage:** the Semgrep image tag in `reusable-semgrep.yml` and the
   tool versions in `scripts/lint.sh`. Dependabot keeps the action pins in the workflows current.
5. **Update `CHANGELOG.md`:** a new `## vX.Y.Z` section (move the Unreleased entries into it) that states the
   script contract version the release needs and anything a project must change.
6. **Run the checks:** `bash scripts/lint.sh` passes.
7. **Test from a consumer before merging.** In a project, on a branch, point every `uses:` line at your branch
   (`jvezina/django-ai-ci/.github/workflows/<file>@release/vX.Y.Z`), push, and get all checks green. For a
   major release also run the project's negative cases (see the project's `docs/ci.md`).
8. **Open the PR here** and merge it once the `lint` check is green.
9. **Tag the merge commit** on `main` and push the tag:
   ```bash
   git switch main && git pull --ff-only
   git tag vX.Y.Z && git push origin vX.Y.Z
   ```
10. **Optionally create a GitHub release** for the tag, with the CHANGELOG section as the notes.
11. **Discard the test branch** in the consumer (or move on to the next section with the real tag).

## Switching a project to a new version of the CI

Work in a project branch. Dependabot normally opens this change as a pull request (it updates every
`uses: jvezina/django-ai-ci/...@vX.Y.Z` line). The manual steps are the same.

1. **Read the CHANGELOG** for every version between the project's current one and the target, especially the
   script contract version each needs and any "project must change" notes.
2. **Branch** from `main` (`git switch -c ci/django-ai-ci-vX.Y.Z`).
3. **Contract changed?** If the target needs a newer script contract than the project's
   `scripts/ci/CONTRACT_VERSION`, update the project first: run `uvx copier update` to take the template's new
   scripts and contract file, resolve conflicts, and commit that before the version change. A project at a
   newer contract than the workflow supports fails fast at the contract step with a message saying so.
4. **Change the pin** in every project workflow that calls this repo:
   ```bash
   grep -rn "jvezina/django-ai-ci" .github/workflows
   ```
   Set every `@vOLD` to `@vX.Y.Z`. All callers should use the same version.
5. **Push and open a PR.** All checks must pass: `quality`, `test`, `test-postgres`, and the Semgrep and e2e
   runs. Scheduled workflows (nightly, weekly, pre-release) don't run on PRs; trigger the ones the release
   touched with `workflow_dispatch` on the branch and check them.
6. **If a check fails,** compare it with the same check on `main`. A failure only on the branch is a problem
   in the release or in the project's `scripts/ci/setup.local.sh`: fix it in the project, or report it here
   and wait for a patch version. Do not merge a red upgrade.
7. **Merge.** The project is now on the new version.
8. **Roll back** if a problem shows up after merging: revert the merge commit, or set the pins back to the
   previous tag. Old tags stay available.

## Local checks

```bash
bash scripts/lint.sh          # actionlint, shellcheck, shared-block checks and their fixtures (needs uvx)
```

Dependabot keeps the action pins in this repo's workflows current (`.github/dependabot.yml`).
