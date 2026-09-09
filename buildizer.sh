#!/usr/bin/env bash
# buildizer.sh - queue the Azure DevOps pipeline for the repo/branch you are standing in.
# Repo comes from origin's URL, branch from the checked out HEAD.
# Requires: git, az cli (+ azure-devops extension), jq.

set -uo pipefail

TENANT='6b77b66a-12e3-422f-a0cb-e0248ed409f4'

die() { echo "buildizer: $*" >&2; exit 1; }

usage() {
    cat <<'USAGE'
usage: buildizer [-b branch] [-v NAME=value] [-n] [-o] [-y] [ci|tf|<text>]

  ci          only the "<Repo> CI" pipeline
  tf          only the "<Repo> Terraform" pipeline (also: terraform)
  <text>      substring match on pipeline name
  (no arg)    pick from every pipeline attached to the repo

  -b BRANCH   queue this branch instead of the checked out one
  -v NAME=VAL pipeline variable, repeatable
  -n          dry run - resolve and print, queue nothing
  -o          open the run in a browser
  -y          no prompts; with no filter this queues every match
  -h          this
USAGE
}

branch=''
dry=''
open_run=''
assume_yes=''
vars=()

OPTIND=1
while getopts ":b:v:noyh" opt; do
    case "$opt" in
        b) branch="$OPTARG";;
        v) vars+=("$OPTARG");;
        n) dry=1;;
        o) open_run=1;;
        y) assume_yes=1;;
        h) usage; exit 0;;
        :) die "-$OPTARG needs a value";;
        \?) usage >&2; die "invalid option -$OPTARG";;
    esac
done
shift $((OPTIND - 1))
filter="${1:-}"

# --- where am i -------------------------------------------------------------
git rev-parse --show-toplevel >/dev/null 2>&1 || die "not a git repo: $PWD"

remote=$(git config --get remote.origin.url)
[ -n "$remote" ] || die "no origin remote"

url=${remote%.git}
url=${url#*://}
url=${url#*@}
case "$url" in
    dev.azure.com/*) rest=${url#dev.azure.com/};;
    *.visualstudio.com/*) host=${url%%/*}; rest="${host%%.*}/${url#*/}";;
    *) die "origin is not an Azure DevOps remote: $remote";;
esac

org=${rest%%/*};     rest=${rest#*/}
project=${rest%%/*}; rest=${rest#*/}
case "$rest" in
    _git/*) repo=${rest#_git/}; repo=${repo%%/*};;
    *) die "cannot read repo name out of $remote";;
esac
[ -n "$org" ] && [ -n "$project" ] && [ -n "$repo" ] || die "cannot read org/project/repo out of $remote"

org_url="https://dev.azure.com/$org/"
project_url=${project// /%20}

# --- which branch -----------------------------------------------------------
if [ -z "$branch" ]; then
    branch=$(git symbolic-ref --quiet --short HEAD) || die "detached HEAD - pass -b <branch>"
fi

# --- az session -------------------------------------------------------------
if ! az account show >/dev/null 2>&1; then
    echo "buildizer: no azure session, starting device-code login" >&2
    az login --use-device-code --tenant "$TENANT" >/dev/null || die "az login failed"
    az account show >/dev/null 2>&1 || die "still not logged in to azure"
fi

# --- the branch has to exist server side ------------------------------------
if ! git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    echo "error: $branch not on origin" >&2
    echo "  git push -u origin $branch" >&2
    exit 1
fi

# --- pipelines for this repo ------------------------------------------------
pipelines=$(az pipelines list --only-show-errors \
    --org "$org_url" --project "$project" \
    --repository "$repo" --repository-type tfsgit \
    --query "[].{id:id,name:name}" -o json) \
    || die "could not list pipelines for $repo"

case "$(printf '%s' "$filter" | tr '[:upper:]' '[:lower:]')" in
    '')          matches=$pipelines;;
    ci)          matches=$(jq -c '[.[] | select(.name | test("[ ._-]ci$"; "i"))]' <<<"$pipelines");;
    tf|terraform) matches=$(jq -c '[.[] | select(.name | test("terraform$"; "i"))]' <<<"$pipelines");;
    *)           matches=$(jq -c --arg n "$(printf '%s' "$filter" | tr '[:upper:]' '[:lower:]')" \
                     '[.[] | select(.name | ascii_downcase | contains($n))]' <<<"$pipelines");;
esac

count=$(jq 'length' <<<"$matches")
if [ "$count" -eq 0 ]; then
    if [ "$(jq 'length' <<<"$pipelines")" -eq 0 ]; then
        die "no pipelines attached to $repo in $org/$project"
    fi
    echo "buildizer: nothing matching '$filter' for $repo. attached pipelines:" >&2
    jq -r '.[].name | "  " + .' <<<"$pipelines" >&2
    exit 1
fi

# --- pick -------------------------------------------------------------------
selected=$matches
if [ "$count" -gt 1 ] && [ -z "$assume_yes" ]; then
    [ -t 0 ] || die "$count pipelines match - pass ci/tf or -y"
    echo "repo $repo  branch $branch"
    jq -r 'to_entries[] | "  \(.key + 1)) \(.value.name)"' <<<"$matches"
    read -r -p "pick [1]: " pick
    pick=${pick:-1}
    case "$pick" in ''|*[!0-9]*) die "not a number: $pick";; esac
    { [ "$pick" -ge 1 ] && [ "$pick" -le "$count" ]; } || die "out of range: $pick"
    selected=$(jq -c --argjson i "$((pick - 1))" '[.[$i]]' <<<"$matches")
fi
count=$(jq 'length' <<<"$selected")

if [ -n "$dry" ]; then
    echo "dry run - would queue on $branch:"
    jq -r '.[] | "  \(.name) (id \(.id))"' <<<"$selected"
    exit 0
fi

# --- confirm ----------------------------------------------------------------
if [ -z "$assume_yes" ]; then
    [ -t 0 ] || die "not a terminal - pass -y to queue without confirming"
    if [ "$count" -eq 1 ]; then
        prompt="queue '$(jq -r '.[0].name' <<<"$selected")' on $branch? [Y/n]: "
    else
        jq -r '.[] | "  " + .name' <<<"$selected"
        prompt="queue $count pipelines on $branch? [Y/n]: "
    fi
    read -r -p "$prompt" answer
    case "${answer:-Y}" in
        [Yy]*) ;;
        *) echo "nothing queued"; exit 0;;
    esac
fi

# --- queue ------------------------------------------------------------------
rc=0
while IFS=$'\t' read -r id name; do
    [ -n "$id" ] || continue
    out=$(az pipelines run --only-show-errors \
        --org "$org_url" --project "$project" \
        --id "$id" --branch "$branch" \
        ${open_run:+--open} \
        ${vars[@]+--variables "${vars[@]}"} \
        -o json)
    if [ $? -ne 0 ]; then
        echo "buildizer: failed to queue $name" >&2
        rc=1
        continue
    fi
    build_id=$(jq -r '.id' <<<"$out")
    build_num=$(jq -r '.buildNumber // .id' <<<"$out")
    echo "$name  #$build_num  https://dev.azure.com/$org/$project_url/_build/results?buildId=$build_id&view=results"
done < <(jq -r '.[] | "\(.id)\t\(.name)"' <<<"$selected")

exit $rc
