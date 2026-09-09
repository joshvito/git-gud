#!/usr/bin/env bash
# tprs - list every open pull request in an Azure DevOps project, drafts tagged.
#
# The list side of tpr: tpr starts from a repo, this starts from the PR. One
# `az repos pr list` call covers the whole project, so you see what is open
# everywhere without walking repos. Draft PRs look identical to real ones in
# the ADO web list, so they get a DRAFT tag here.
#
# -t hands the picked PR to tpr, which owns the cd + fetch + .tuicrignore work.
#
# Requires: az cli (+ azure-devops extension), jq. fzf optional (nicer picker).

set -uo pipefail

TENANT='6b77b66a-12e3-422f-a0cb-e0248ed409f4'
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { echo "tprs: $*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
usage: tprs [-m] [-r] [-c] [-D] [-u] [-R repo] [-t [ID]] [QUERY]

List active pull requests in an Azure DevOps project. Drafts are tagged DRAFT.
The APPROVERS column holds the initials of everyone who approved; !XX rejected,
~XX is waiting on the author.

  QUERY            case-insensitive substring on repo name or title
  -m, --mine       only PRs I created
  -r, --review     only PRs where I am a reviewer and have not voted
  -c, --cwd        only PRs for the repo I am standing in
  -D, --no-drafts  hide drafts
  -u, --url        show the PR URL instead of the title
  -R, --repo REPO  only this repo (substring)
  -t, --tuicr [ID] open a PR in tuicr via tpr. Bare -t picks from the list,
                   -t 2063 skips the picker
  -h, --help       this

Env:
  TPRS_ORG       org, default: origin's org, else encoura
  TPRS_PROJECT   project, default: origin's project, else engage
  TPRS_ME        who mine/review means, default: git config user.email
  TPRS_TOP       max PRs to ask for (default 200)
  TPRS_JSON      read PR json from this file instead of calling az (testing)
  TPR_ROOT       repo root for -t (default ~/source/repos)
  TPR_PICKER     'fzf' (default when installed) or 'select' bash builtin
USAGE
}

mine=0
needs_review=0
cwd_only=0
hide_drafts=0
show_url=0
handoff=0
repo_filter=''
query=''
pr_id=''

while (($#)); do
  case "$1" in
    -m|--mine)      mine=1 ;;
    -r|--review)    needs_review=1 ;;
    -c|--cwd)       cwd_only=1 ;;
    -D|--no-drafts) hide_drafts=1 ;;
    -u|--url)       show_url=1 ;;
    -R|--repo)      shift; [[ $# -gt 0 ]] || die "-R needs a repo name"; repo_filter="$1" ;;
    -t|--tuicr)     handoff=1
                    # an id may follow -t; anything non-numeric is the next flag or the query
                    if [[ ${2:-} =~ ^[0-9]+$ ]]; then pr_id="$2"; shift; fi ;;
    -h|--help)      usage; exit 0 ;;
    -*)             usage >&2; die "invalid option $1" ;;
    *)              if [[ -z $query ]]; then query="$1"; else die "unexpected argument: $1"; fi ;;
  esac
  shift
done

# `tprs -t 2063` and `tprs 2063 -t` should mean the same thing.
if ((handoff)) && [[ -z $pr_id && $query =~ ^[0-9]+$ ]]; then
  pr_id="$query"
  query=''
fi

# --- org / project ----------------------------------------------------------
# Standing in a repo tells us which org and project to ask about; it does not
# narrow the list to that repo (that is -c). An explicit env var always wins.
det_org=''
det_project=''
cwd_repo=''
if remote=$(git config --get remote.origin.url 2>/dev/null) && [[ -n $remote ]]; then
  u=${remote%.git}; u=${u#*://}; u=${u#*@}
  rest=''
  case "$u" in
    dev.azure.com/*)      rest=${u#dev.azure.com/} ;;
    *.visualstudio.com/*) h=${u%%/*}; rest="${h%%.*}/${u#*/}" ;;
  esac
  if [[ -n $rest ]]; then
    o=${rest%%/*}; rest=${rest#*/}
    p=${rest%%/*}; rest=${rest#*/}
    case "$rest" in _git/*) r=${rest#_git/}; r=${r%%/*} ;; *) r='' ;; esac
    if [[ -n $o && -n $p ]]; then det_org=$o; det_project=$p; cwd_repo=$r; fi
  fi
fi

org="${TPRS_ORG:-${det_org:-encoura}}"
project="${TPRS_PROJECT:-${det_project:-engage}}"

if ((cwd_only)); then
  [[ -n $cwd_repo ]] || die "-c needs an Azure DevOps repo as the working directory"
  repo_filter="$cwd_repo"
fi

# --- prerequisites ----------------------------------------------------------
command -v az >/dev/null 2>&1 || die "az cli is not installed"
command -v jq >/dev/null 2>&1 || die "jq is not available and is required"

me="${TPRS_ME:-$(git config user.email 2>/dev/null || true)}"
if ((mine || needs_review)) && [[ -z $me ]]; then
  die "cannot tell who you are - set TPRS_ME to your Azure DevOps email"
fi

if ! az account show >/dev/null 2>&1; then
  echo "tprs: no azure session, starting device-code login" >&2
  az login --use-device-code --tenant "$TENANT" >/dev/null || die "az login failed"
  az account show >/dev/null 2>&1 || die "still not logged in to azure"
fi

# --- fetch ------------------------------------------------------------------
# --detect false: without it az guesses org/project from the cwd and fails
# outright when you are not standing in a repo.
if [[ -n ${TPRS_JSON:-} ]]; then
  [[ -f $TPRS_JSON ]] || die "no such file: $TPRS_JSON"
  prs=$(cat "$TPRS_JSON") || die "could not read $TPRS_JSON"
else
  prs=$(az repos pr list --only-show-errors --detect false \
    --org "https://dev.azure.com/$org/" --project "$project" \
    --status active --top "${TPRS_TOP:-200}" -o json) \
    || die "could not list pull requests in $org/$project"
fi

# --- filter + shape ---------------------------------------------------------
# One row per PR: id, repo, DRAFT flag, author, title, url, approvers.
# Newest first.
rows=$(jq -r \
  --arg me "$me" --arg q "$query" --arg rf "$repo_filter" \
  --arg org "$org" --arg project "$project" \
  --argjson mine "$mine" --argjson review "$needs_review" --argjson nodrafts "$hide_drafts" '
  def lc: ascii_downcase;
  # "Federico Vela Garcia" -> FVG, "Josh Vito" -> JV
  def initials: [splits("[ ,._-]+")]
    | map(select(length > 0) | .[0:1] | ascii_upcase) | .[0:3] | join("");
  # rejections and change-requests sort first so they survive a clipped cell
  def votes: [ (. // [])[]
      | select((.isContainer // false) | not)
      | select((.vote // 0) != 0)
      | if .vote <= -10 then { rank: 0, token: "!" + (.displayName // "?" | initials) }
        elif .vote < 0   then { rank: 1, token: "~" + (.displayName // "?" | initials) }
        else                  { rank: 2, token:       (.displayName // "?" | initials) }
        end ]
    | sort_by(.rank) | map(.token) | join(" ");
  [ .[]
    | . as $pr
    | ($pr.repository.name // "?") as $repo
    | ($pr.title // "") as $title
    | select($nodrafts == 0 or (($pr.isDraft // false) | not))
    | select($rf == "" or ($repo | lc | contains($rf | lc)))
    | select($q == "" or (($repo + " " + $title) | lc | contains($q | lc)))
    | select($mine == 0 or (($pr.createdBy.uniqueName // "") | lc) == ($me | lc))
    # container reviewers are teams (ADO-Engage-Pull-Request-Reviewers), not me
    | select($review == 0 or ([ ($pr.reviewers // [])[]
        | select((.isContainer // false) | not)
        | select(((.uniqueName // "") | lc) == ($me | lc))
        | select(.vote == 0) ] | length) > 0)
    | [ ($pr.pullRequestId | tostring),
        $repo,
        (if ($pr.isDraft // false) then "DRAFT" else "" end),
        ($pr.createdBy.displayName // "?"),
        ($title | gsub("[\\t\\r\\n]+"; " ")),
        "https://dev.azure.com/\($org)/\($project|@uri)/_git/\($repo|@uri)/pullrequest/\($pr.pullRequestId)",
        ($pr.reviewers | votes)
      ]
  ]
  | sort_by(.[0] | tonumber) | reverse
  | .[] | @tsv
' <<<"$prs") || die "could not read the pull request list"

if [[ -z $rows ]]; then
  echo "tprs: no open PRs match" >&2
  exit 0
fi

# --- render -----------------------------------------------------------------
c_bold=''; c_draft=''; c_bad=''; c_off=''
if [[ -t 1 ]]; then
  c_bold=$(tput bold 2>/dev/null || true)
  c_draft=$(tput setaf 3 2>/dev/null || true)
  c_bad=$(tput setaf 1 2>/dev/null || true)
  c_off=$(tput sgr0 2>/dev/null || true)
fi

width=${COLUMNS:-0}
if ((width == 0)); then width=$(tput cols 2>/dev/null || echo 100); fi

render() {
  # $1: 1 = header + colors, 0 = plain rows only (picker input)
  awk -v pretty="$1" -v showurl="$show_url" -v width="$width" \
      -v cb="$c_bold" -v cd="$c_draft" -v cbad="$c_bad" -v co="$c_off" '
    function pad(s, w) { while (length(s) < w) s = s " "; return s }
    function clip(s, w) { return (w > 3 && length(s) > w) ? substr(s, 1, w - 3) "..." : s }
    # color the !/~ tokens, then pad on the PLAIN length - escapes have no width
    function pad_votes(cell, w,   k, t, i, out, plain, tok, col) {
      k = split(cell, t, " ")
      out = ""; plain = 0
      for (i = 1; i <= k; i++) {
        tok = t[i]
        col = (substr(tok, 1, 1) == "!") ? cbad : (substr(tok, 1, 1) == "~") ? cd : ""
        out = out (i > 1 ? " " : "") (col == "" ? tok : col tok co)
        plain += length(tok) + (i > 1 ? 1 : 0)
      }
      while (plain++ < w) out = out " "
      return out
    }
    BEGIN { FS = "\t"; n = 0; w1 = 2; w2 = 4; w4 = 6; w5 = 0; anydraft = 0 }
    {
      id[n] = $1; repo[n] = $2; flag[n] = $3
      auth[n] = clip($4, 18)
      last[n] = (showurl ? $6 : $5)
      appr[n] = clip($7, 16)
      if (length(id[n])   > w1) w1 = length(id[n])
      if (length(repo[n]) > w2) w2 = length(repo[n])
      if (length(auth[n]) > w4) w4 = length(auth[n])
      if (length(appr[n]) > w5) w5 = length(appr[n])
      if (flag[n] != "") anydraft = 1
      n++
    }
    END {
      # a column only exists when something in view fills it
      fw = anydraft ? 7 : 0
      if (w5 > 0 && w5 < length("APPROVERS")) w5 = length("APPROVERS")
      aw = w5 ? w5 + 2 : 0
      avail = width - (w1 + 2) - (w2 + 2) - fw - (w4 + 2) - aw
      if (avail < 24) avail = 24
      if (pretty) {
        h = pad("PR", w1) "  " pad("REPO", w2) "  "
        if (anydraft) h = h pad("", 7)
        h = h pad("AUTHOR", w4) "  "
        if (w5) h = h pad("APPROVERS", w5) "  "
        print cb h (showurl ? "URL" : "TITLE") co
      }
      for (i = 0; i < n; i++) {
        line = pad(id[i], w1) "  " pad(repo[i], w2) "  "
        if (anydraft) {
          if (flag[i] != "") line = line (pretty ? cd "DRAFT" co "  " : "DRAFT  ")
          else               line = line pad("", 7)
        }
        line = line pad(auth[i], w4) "  "
        if (w5) line = line (pretty ? pad_votes(appr[i], w5) : pad(appr[i], w5)) "  "
        # urls stay whole so they remain clickable and copyable
        line = line (showurl ? last[i] : clip(last[i], avail))
        print line
      }
    }
  '
}

if ((! handoff)); then
  printf '%s\n' "$rows" | render 1
  exit 0
fi

# --- hand off to tpr --------------------------------------------------------
REPOS="${TPR_ROOT:-$HOME/source/repos}"
TPR_SH="$SELF_DIR/tpr.sh"
[[ -f $TPR_SH ]] || die "cannot find tpr.sh next to this script ($SELF_DIR)"

pick_row() {
  local -a lines=()
  local line
  mapfile -t lines < <(printf '%s\n' "$rows" | render 0)

  if ((${#lines[@]} == 1)); then printf '%s\n' "${lines[0]}"; return 0; fi

  local picker="${TPR_PICKER:-}"
  if [[ -z $picker ]]; then
    if command -v fzf >/dev/null 2>&1; then picker=fzf; else picker=select; fi
  fi
  [[ -t 0 ]] || { echo "tprs: ${#lines[@]} PRs match - pass an id" >&2; return 1; }

  case "$picker" in
    fzf)
      printf '%s\n' "${lines[@]}" | fzf -i --height=40% --reverse --border \
        --prompt='pr> ' --select-1 --exit-0
      ;;
    select)
      PS3="pr> "
      select line in "${lines[@]}"; do
        [[ -n $line ]] && { printf '%s\n' "$line"; return 0; }
      done
      return 1
      ;;
    *) echo "tprs: unknown TPR_PICKER '$picker' (want fzf or select)" >&2; return 1 ;;
  esac
}

row_for_id() {
  printf '%s\n' "$rows" | awk -F'\t' -v id="$1" '$1 == id { print; exit }'
}

if [[ -n $pr_id ]]; then
  row=$(row_for_id "$pr_id")
  [[ -n $row ]] || die "PR $pr_id is not in the open list for $org/$project"
else
  picked=$(pick_row) || exit 1
  # Esc / no match / empty selection: nothing to do, and not an error.
  [[ -n $picked ]] || exit 0
  pr_id=${picked%% *}
  row=$(row_for_id "$pr_id")
  [[ -n $row ]] || die "could not match the picked line back to a PR"
fi
repo_name=$(cut -f2 <<<"$row")

# ADO casing and directory casing drift apart (Public-api, repo.stamper), so
# match the clone case-insensitively.
resolve_dir() {
  local want="$1" d base
  for d in "$REPOS"/*/; do
    [[ -e "${d}.git" ]] || continue
    d=${d%/}; base=${d##*/}
    if [[ ${base,,} == "${want,,}" ]]; then printf '%s\n' "$base"; return 0; fi
  done
  return 1
}

dir_name=$(resolve_dir "$repo_name") || die "$repo_name is not cloned under $REPOS
  git -C '$REPOS' clone https://$org@dev.azure.com/$org/$project/_git/$repo_name"

# TPR_REPO skips tpr's repo picker; tpr still owns the fetch and .tuicrignore.
TPR_REPO="$dir_name" exec bash "$TPR_SH" -- pr "$pr_id"
