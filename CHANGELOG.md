# Changelog

All notable changes to the reusable workflows. Versions are exact SemVer tags (`v1.0.0`); consumers pin one
and take upgrades through Dependabot pull requests.

Each major version states the **script contract version** it needs (`scripts/ci/CONTRACT_VERSION` in the
consumer). A change to a script's invocation, environment or exit codes raises the contract version and needs a
new major version.

## Unreleased

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
