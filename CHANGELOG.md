# Changelog

All notable changes to the reusable workflows. Versions are exact SemVer tags (`v1.0.0`); consumers pin one
and take upgrades through Dependabot pull requests.

Each major version states the **script contract version** it needs (`scripts/ci/CONTRACT_VERSION` in the
consumer). A change to a script's invocation, environment or exit codes raises the contract version and needs a
new major version.

## Unreleased

- `reusable-playwright.yml` (job `e2e`; input `timeout-minutes`): runs `scripts/ci/e2e.sh`, uploads the report,
  tears the stack down on exit. No tool setup. Needs script contract 1.

- `reusable-mutation.yml` (job `mutation`; `mode` nightly|weekly, `strict`, `python-version`, `node-version`,
  `timeout-minutes`), `reusable-slow.yml` (job `slow`) and `reusable-pre-release.yml` (job `pre-release`, owns the
  Postgres service and the Playwright browser install). Need script contract 1. The mutants cache key is unchanged
  (`mutmut-mutants-<os>-<run id>`), so existing caches keep working.

- All workflows run on `ubuntu-24.04` instead of `ubuntu-latest`, so GitHub's move of the label to Ubuntu 26
  cannot change the runner OS underneath a release.

- `reusable-django-ci.yml`: jobs `quality`, `test`, `test-postgres`; inputs `python-version` (`3.12`),
  `node-version` (`26`), `postgres-version` (`18`), `run-postgres-tier` (`true`). Needs script contract 1
  (`scripts/ci/CONTRACT_VERSION`, `scripts/ci/setup.sh`).
- `reusable-semgrep.yml`: Semgrep scan in the `semgrep/semgrep:1.181.1` image; optional `SEMGREP_APP_TOKEN`
  secret, skips with a notice when unset. No inputs.

- Repository scaffold: `scripts/lint.sh` (actionlint, shellcheck, shared-block checks with fixture tests) run by
  the `lint` workflow, `.github/dependabot.yml` for the repo's own action pins, README with the shared-block
  rules and the release checklist.
