#!/usr/bin/env bash
# Keeps the blocks that must be identical in every reusable workflow identical, and present (decisions D13, D16).
# A block sits between marker comments in the workflow YAML:
#
#       # BEGIN shared:setup
#       - uses: astral-sh/setup-uv@v10.3.0
#       - run: bash scripts/ci/setup.sh "${{ github.job }}"
#       # END shared:setup
#
# Two rules:
#   1. Every copy of a named block, in every workflow file, is identical once leading whitespace is dropped.
#      An unclosed, nested or mismatched marker fails too.
#   2. Presence: in every reusable-*.yml, the number of `shared:contract` blocks equals the number of
#      `actions/checkout` steps (every job that checks out checks the script contract), and so does the number of
#      `shared:setup` blocks, except for the allowlisted workflows below. A deleted or forgotten block fails.
#
#   bash scripts/check_shared_blocks.sh [workflow-dir]     # default: .github/workflows

set -Eeuo pipefail

# Workflows that do not need a block (they run no project scripts, or no Python/Node setup).
NO_CONTRACT=(reusable-semgrep.yml)
NO_SETUP=(reusable-semgrep.yml reusable-playwright.yml)

dir="${1:-.github/workflows}"
shopt -s nullglob
files=("$dir"/*.yml "$dir"/*.yaml)
if ((${#files[@]} == 0)); then
    echo "No workflow files in $dir: nothing to compare."
    exit 0
fi

# One line per block copy: <name> TAB <file> TAB <lines joined with a unit separator>.
blocks="$(awk '
    function fail(msg) { printf "%s:%d: %s\n", FILENAME, FNR, msg > "/dev/stderr"; bad = 1 }
    function close_check(where) {
        if (name != "") { fail("BEGIN shared:" name " is not closed " where); name = "" }
    }
    FNR == 1 { close_check("before the end of the previous file") }
    /^[[:space:]]*# BEGIN shared:/ {
        close_check("before the next BEGIN")
        name = $0; sub(/^.*# BEGIN shared:/, "", name); sub(/[[:space:]]+$/, "", name)
        body = ""; start = FILENAME; next
    }
    /^[[:space:]]*# END shared:/ {
        end = $0; sub(/^.*# END shared:/, "", end); sub(/[[:space:]]+$/, "", end)
        if (name == "") { fail("END shared:" end " without BEGIN") }
        else if (end != name) { fail("END shared:" end " closes shared:" name); name = "" }
        else { printf "%s\t%s\t%s\n", name, start, body; name = "" }
        next
    }
    name != "" { line = $0; sub(/^[[:space:]]+/, "", line); body = body line "\037" }
    END { close_check("before the end of the file"); exit bad }
' "${files[@]}")" || exit 1

status=0

# Rule 1: every copy of a named block is identical.
if [[ -n "$blocks" ]]; then
    while IFS= read -r name; do
        distinct="$(awk -F'\t' -v n="$name" '$1 == n { print $3 }' <<<"$blocks" | sort -u | wc -l)"
        copies="$(awk -F'\t' -v n="$name" '$1 == n' <<<"$blocks" | wc -l)"
        if ((distinct > 1)); then
            echo "::error::shared block '$name' differs between its $copies copies:" >&2
            awk -F'\t' -v n="$name" '$1 == n { print "  " $2 }' <<<"$blocks" | sort | uniq -c >&2
            status=1
        else
            echo "shared:$name: $copies identical copies"
        fi
    done < <(cut -f1 <<<"$blocks" | sort -u)
fi

# Rule 2: presence in every reusable workflow.
in_list() { # in_list <item> <list item>...
    local item="$1" candidate
    shift
    for candidate in "$@"; do
        [[ "$candidate" == "$item" ]] && return 0
    done
    return 1
}

count_blocks() { # count_blocks <name> <file>
    awk -F'\t' -v n="$1" -v f="$2" '$1 == n && $2 == f' <<<"$blocks" | wc -l
}

for file in "${files[@]}"; do
    base="$(basename "$file")"
    [[ "$base" == reusable-* ]] || continue
    checkouts="$(grep -cE '^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*actions/checkout@' "$file" || true)"
    if ((checkouts == 0)); then
        echo "::error::$base has no actions/checkout step; every reusable workflow needs one." >&2
        status=1
        continue
    fi
    for name in contract setup; do
        case "$name" in
            contract) allow=("${NO_CONTRACT[@]}") ;;
            setup) allow=("${NO_SETUP[@]}") ;;
        esac
        if in_list "$base" "${allow[@]}"; then
            continue
        fi
        have="$(count_blocks "$name" "$file")"
        if ((have != checkouts)); then
            echo "::error::$base has $checkouts checkout step(s) but $have 'shared:$name' block(s); each job needs one." >&2
            status=1
        fi
    done
done

[[ -n "$blocks" ]] || echo "No shared blocks found in $dir."
exit "$status"
