#!/usr/bin/env bash
# Fails when a block that must be identical in every reusable workflow differs between copies (decision D13).
# A block sits between marker comments in the workflow YAML:
#
#       # BEGIN shared:setup
#       - uses: astral-sh/setup-uv@v10.3.0
#       - run: bash scripts/ci/setup.sh quality
#       # END shared:setup
#
# Every copy of a named block, in every workflow, must be identical once leading whitespace is dropped.
# An unclosed, nested or mismatched marker fails too. With no markers at all it passes (nothing to compare).
#
#   bash scripts/check_shared_blocks.sh [workflow-dir]     # default: .github/workflows
set -Eeuo pipefail

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

if [[ -z "$blocks" ]]; then
    echo "No shared blocks found in $dir: nothing to compare."
    exit 0
fi

status=0
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
exit "$status"
