#!/usr/bin/env bash
# The one place that names the lint tools and their pinned versions (D19). Used by the `lint` workflow and by
# hand. The two tool versions are bumped manually at release time (Dependabot does not manage them).
#
#   bash scripts/lint.sh
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

ACTIONLINT="actionlint-py==1.7.12.25"
SHELLCHECK="shellcheck-py==0.11.0.1"

command -v uvx >/dev/null || {
    echo "uvx is required (https://docs.astral.sh/uv/)." >&2
    exit 2
}

echo "==> actionlint"
uvx --from "$ACTIONLINT" actionlint

echo "==> shellcheck"
uvx --from "$SHELLCHECK" shellcheck -x scripts/*.sh tests/*.sh

echo "==> shared blocks"
bash scripts/check_shared_blocks.sh

echo "==> check_shared_blocks.sh fixtures"
bash tests/test_check_shared_blocks.sh
