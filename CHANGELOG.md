# Changelog

All notable changes to the reusable workflows. Versions are exact SemVer tags (`v1.0.0`); consumers pin one
and take upgrades through Dependabot pull requests.

Each major version states the **script contract version** it needs (`scripts/ci/CONTRACT_VERSION` in the
consumer). A change to a script's invocation, environment or exit codes raises the contract version and needs a
new major version.

## Unreleased

- Repository scaffold: `lint` workflow (actionlint, shellcheck, shared-block drift check), README skeleton.
