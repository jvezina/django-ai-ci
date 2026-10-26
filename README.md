# django-ai-ci

Reusable GitHub Actions workflows for Django projects generated from the `django-build` Copier template.
They own *how* a job runs (runners, tool setup, caches, service containers, report upload). The project owns
*what* runs, in `scripts/ci/*.sh`. See `docs/ci.md` in a generated project for the ownership contract and the
script contract.

Status: scaffold. No workflow is published yet.

## Workflows

| Workflow | Purpose | Added |
|---|---|---|
| `reusable-semgrep.yml` | Semgrep scan; skips with a notice when `SEMGREP_APP_TOKEN` is unset | planned |
| `reusable-django-ci.yml` | `quality`, `test`, `test-postgres` | planned |
| `reusable-mutation.yml` | nightly (incremental, cached) and weekly (clean full) mutation testing | planned |
| `reusable-pre-release.yml` | full build and validation pass | planned |
| `reusable-playwright.yml` | e2e against the project's test environment | planned |

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

## Rules for changing a workflow

- **Shared blocks.** The setup steps (`setup-uv`, `setup-node`, `bash scripts/ci/setup.sh <job>`) and the
  contract check are copied into every job, between `# BEGIN shared:<name>` and `# END shared:<name>` comment
  markers. `scripts/check_shared_blocks.sh` (run by the `lint` workflow) fails when copies differ. Edit all
  copies together.
- **Inputs are public contract.** Add one only when a second project needs it. A project's own tools,
  services and packages go in the project (`scripts/ci/setup.local.sh`, its own scripts or workflow files),
  never here.
- **Pins.** Third-party actions and tools are pinned to exact versions.
- **Test from a consumer.** Open a draft PR in a consumer that points `uses:` at your branch
  (`…@my-branch`) and get it green before merging. Merge and tag only then.
- **Releases.** Update `CHANGELOG.md` (including the contract version the release needs) and tag an exact
  SemVer version. A removed or renamed input, or a changed script contract, is a new major version.

## Local checks

```bash
uvx --from actionlint-py==1.7.12.25 actionlint
uvx --from shellcheck-py==0.11.0.1 shellcheck -x scripts/*.sh
bash scripts/check_shared_blocks.sh
```
