#!/usr/bin/env bash
# Fixture tests for scripts/check_shared_blocks.sh: each case builds a directory of workflow files and checks
# the script's exit status. Run by scripts/lint.sh.
#
#   bash tests/test_check_shared_blocks.sh
set -Eeuo pipefail

script="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/check_shared_blocks.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

failures=0
cases=0

contract_block() {
    printf '      # BEGIN shared:contract\n      - name: Check the script contract version\n        run: echo "contract %s"\n      # END shared:contract\n' "${1:-1}"
}
setup_block() {
    # shellcheck disable=SC2016 # the ${{ }} expression is literal workflow text
    printf '      # BEGIN shared:setup\n      - uses: astral-sh/setup-uv@v10.3.0\n      - run: bash scripts/ci/setup.sh "${{ github.job }}"\n      # END shared:setup\n'
}
# job <id> <checkout:0|1> <contract:none|N> <setup:0|1>
job() {
    printf '  %s:\n    runs-on: ubuntu-latest\n    steps:\n' "$1"
    if [[ "$2" == 1 ]]; then printf '      - uses: actions/checkout@v7\n'; fi
    if [[ "$3" != none ]]; then contract_block "$3"; fi
    if [[ "$4" == 1 ]]; then setup_block; fi
    printf '      - run: echo work\n'
}
workflow() { printf 'on: workflow_call\njobs:\n'; }

# expect <name> <pass|fail> <dir>
expect() {
    local name="$1" want="$2" dir="$3" got=pass
    cases=$((cases + 1))
    if ! bash "$script" "$dir" >/dev/null 2>&1; then got=fail; fi
    if [[ "$got" == "$want" ]]; then
        echo "ok   $name"
    else
        echo "FAIL $name: expected $want, got $got"
        failures=$((failures + 1))
    fi
}

new_dir() { mkdir -p "$work/$1" && echo "$work/$1"; }

d="$(new_dir good)"
{ workflow; job quality 1 1 1; job test 1 1 1; } >"$d/reusable-django-ci.yml"
{ workflow; job slow 1 1 1; } >"$d/reusable-slow.yml"
expect "complete blocks in every job" pass "$d"

d="$(new_dir missing-contract)"
{ workflow; job quality 1 1 1; job test 1 none 1; } >"$d/reusable-django-ci.yml"
expect "a job without the contract block" fail "$d"

d="$(new_dir missing-setup)"
{ workflow; job quality 1 1 1; job test 1 1 0; } >"$d/reusable-django-ci.yml"
expect "a job without the setup block" fail "$d"

d="$(new_dir extra-block)"
{ workflow; job quality 1 1 1; job test 0 1 1; } >"$d/reusable-django-ci.yml"
expect "a block in a job without checkout (count differs)" fail "$d"

d="$(new_dir drift)"
{ workflow; job quality 1 1 1; } >"$d/reusable-django-ci.yml"
{ workflow; job slow 1 2 1; } >"$d/reusable-slow.yml"
expect "contract blocks that differ between workflows" fail "$d"

d="$(new_dir semgrep-allowlisted)"
{ workflow; job semgrep 1 none 0; } >"$d/reusable-semgrep.yml"
{ workflow; job quality 1 1 1; } >"$d/reusable-django-ci.yml"
expect "semgrep without any block" pass "$d"

d="$(new_dir playwright-allowlisted)"
{ workflow; job test 1 1 0; } >"$d/reusable-playwright.yml"
{ workflow; job quality 1 1 1; } >"$d/reusable-django-ci.yml"
expect "playwright with the contract block only" pass "$d"

d="$(new_dir playwright-no-contract)"
{ workflow; job test 1 none 0; } >"$d/reusable-playwright.yml"
expect "playwright without the contract block" fail "$d"

d="$(new_dir no-checkout)"
{ workflow; job quality 0 none 0; } >"$d/reusable-django-ci.yml"
expect "a reusable workflow without checkout" fail "$d"

d="$(new_dir not-reusable)"
{ printf 'on: push\njobs:\n'; job lint 1 none 0; } >"$d/lint.yml"
expect "a non-reusable workflow needs no blocks" pass "$d"

d="$(new_dir indentation)"
{ workflow; job quality 1 1 1; } >"$d/reusable-django-ci.yml"
{ workflow; job slow 1 1 1; } | sed 's/^/ /;s/^ on:/on:/;s/^ jobs:/jobs:/' >"$d/reusable-slow.yml"
expect "the same block at another indentation" pass "$d"

d="$(new_dir unclosed)"
{ workflow; job quality 1 1 1; printf '      # BEGIN shared:setup\n      - run: x\n'; } >"$d/reusable-django-ci.yml"
expect "an unclosed marker" fail "$d"

d="$(new_dir empty)"
expect "no workflow files" pass "$d"

echo "$((cases - failures))/$cases cases passed"
((failures == 0))
