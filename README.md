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
| `reusable-slow.yml` | long-running tests (`pytest -m slow`) | planned |
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
- **Pins.** Third-party actions and the Semgrep image are pinned to exact versions, written literally.
- **Job ids.** The ids `quality`, `test`, `test-postgres`, `mutation`, `slow` and `pre-release` are passed to
  projects' `setup.sh`/`setup.local.sh`. Renaming or removing one is a new major version; adding one is a minor.
- **Test from a consumer.** Open a draft PR in a consumer that points `uses:` at your branch
  (`…@my-branch`) and get it green before merging. Merge and tag only then.
- **Contract.** A change to a project script's invocation, environment or exit codes raises
  `CONTRACT_VERSION`, changes the number in `shared:contract` everywhere, and is a new major version.

## Release checklist

1. `bash scripts/lint.sh` passes.
2. Bump by hand what Dependabot does not manage: the Semgrep image tag in `reusable-semgrep.yml` and the tool
   versions in `scripts/lint.sh`.
3. Update `CHANGELOG.md`, stating the script contract version the release needs.
4. Tag an exact SemVer version (`v1.0.0`). No refs are rewritten.

## Local checks

```bash
bash scripts/lint.sh          # actionlint, shellcheck, shared-block checks and their fixtures (needs uvx)
```

Dependabot keeps the action pins in this repo's workflows current (`.github/dependabot.yml`).
