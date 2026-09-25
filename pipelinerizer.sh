#!/usr/bin/env bash
# pipelinerizer.sh - search the Engage project for pipelines by name and queue every match on one branch.
# Unlike buildizer, this ignores the repo you are standing in.
# Requires: az cli (+ azure-devops extension), jq.

set -uo pipefail

TENANT='6b77b66a-12e3-422f-a0cb-e0248ed409f4'
ORG_URL='https://dev.azure.com/Encoura/'
PROJECT='Engage'

die() { echo "pipelinerizer: $*" >&2; exit 1; }

usage() {
    cat <<'USAGE'
usage: pipelinerizer [-t term | -q jmespath | -p regex] [-b branch] [-n] [-y]

  -t TERM     pipelines whose name contains TERM (case sensitive)
  -q QUERY    raw JMESPATH for az --query, must return a list of names
  -p REGEX    jq regex over every pipeline name
              precedence: -p over -q over -t; none given prompts for a term [Terraform]
  -b BRANCH   branch to queue (default main)
  -n          dry run - list matches, queue nothing
  -y          no prompt
  -h          this
USAGE
}

tit=''
query=''
pattern=''
branch='main'
dry=''
assume_yes=''

OPTIND=1
while getopts ":t:q:p:b:nyh" opt; do
    case "$opt" in
        t) tit="$OPTARG";;
        q) query="$OPTARG";;
        p) pattern="$OPTARG";;
        b) branch="$OPTARG";;
        n) dry=1;;
        y) assume_yes=1;;
        h) usage; exit 0;;
        :) die "-$OPTARG needs a value";;
        \?) usage >&2; die "invalid option -$OPTARG";;
    esac
done
shift $((OPTIND - 1))

# --- what to search for -----------------------------------------------------
if [ -z "$pattern" ] && [ -z "$query" ] && [ -z "$tit" ]; then
    [ -t 0 ] || die "no search given - pass -t, -q or -p"
    read -r -p "Build pipeline search term (case sensitive) [Terraform]: " tit
    tit=${tit:-Terraform}
fi

if [ -n "$pattern" ]; then
    query='[].name'
elif [ -z "$query" ]; then
    query="[?contains(name, '${tit}')].name"
fi

# --- az session -------------------------------------------------------------
if ! az account show >/dev/null 2>&1; then
    echo "pipelinerizer: no azure session, starting device-code login" >&2
    az login --use-device-code --tenant "$TENANT" >/dev/null || die "az login failed"
    az account show >/dev/null 2>&1 || die "still not logged in to azure"
fi

# --- find pipelines ---------------------------------------------------------
names=$(az pipelines build definition list --only-show-errors \
    --org "$ORG_URL" --project "$PROJECT" \
    --query "$query" -o json) \
    || die "could not list pipelines"

if [ -n "$pattern" ]; then
    names=$(jq -c --arg pat "$pattern" '[.[] | select(test($pat))]' <<<"$names") \
        || die "bad regex: $pattern"
fi

count=$(jq 'length' <<<"$names") || die "query did not return a list: $query"
[ "$count" -gt 0 ] || die "no pipelines matched"

echo "pipelines to queue on $branch:"
jq -r '.[] | "  " + .' <<<"$names"

if [ -n "$dry" ]; then
    echo "dry run - queued nothing"
    exit 0
fi

# --- confirm ----------------------------------------------------------------
if [ -z "$assume_yes" ]; then
    [ -t 0 ] || die "not a terminal - pass -y to queue without confirming"
    read -r -p "queue $count pipelines on $branch? [Y/n]: " answer
    case "${answer:-Y}" in
        [Yy]*) ;;
        *) echo "nothing queued"; exit 0;;
    esac
fi

# --- queue ------------------------------------------------------------------
rc=0
while read -r name; do
    name=${name%$'\r'}
    [ -n "$name" ] || continue
    out=$(az pipelines build queue --only-show-errors \
        --org "$ORG_URL" --project "$PROJECT" \
        --definition-name "$name" --branch "$branch" \
        -o json)
    if [ $? -ne 0 ]; then
        echo "pipelinerizer: failed to queue $name" >&2
        rc=1
        continue
    fi
    build_id=$(jq -r 'if type == "array" then .[0] else . end | .id' <<<"$out")
    echo "$name  https://dev.azure.com/Encoura/$PROJECT/_build/results?buildId=$build_id&view=results"
done < <(jq -r '.[]' <<<"$names")

exit $rc
