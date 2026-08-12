#!/usr/bin/env bash
# tpr - pick a repo under ~/source/repos, fetch it, and open tuicr there.
#
# tuicr has no repo/directory flag: it resolves the repo from the current
# working directory, and it never fetches on your behalf (the Azure DevOps PR
# diff fails outright when the base/head SHAs aren't local). So this wrapper
# does the two things you'd otherwise type every time: cd + git fetch.
#
# The caller's cwd is never changed - tuicr runs in a subshell.

set -euo pipefail

REPOS="${TPR_ROOT:-$HOME/source/repos}"
DEBUG_BIN="$REPOS/tuicr/target/debug/tuicr.exe"

usage() {
  cat <<'EOF'
usage: tpr [-d] [-n] [QUERY] [-- TUICR_ARGS...]

Fuzzy-pick a git repo under ~/source/repos, fetch it, and open tuicr in it.

  QUERY          pre-filter the picker; a unique match skips the menu entirely
  -d, --debug    use the local debug build instead of tuicr from PATH
  -n, --no-fetch skip the git fetch
  -h, --help     this

Any other argument is forwarded to tuicr, e.g.
  tpr comp.submissions -w          review the working tree
  tpr comp.submissions -- pr 1234  open a specific PR

Env:
  TPR_ROOT       repo root (default ~/source/repos)
  TPR_PICKER     'fzf' (default when installed) or 'select' bash builtin
EOF
}

use_debug=0
no_fetch=0
query=""
declare -a passthru=()

while (($#)); do
  case "$1" in
    -d|--debug)    use_debug=1 ;;
    -n|--no-fetch) no_fetch=1 ;;
    -h|--help)     usage; exit 0 ;;
    --)            shift; passthru+=("$@"); break ;;
    -*)            passthru+=("$1") ;;
    *)             if [[ -z $query ]]; then query="$1"; else passthru+=("$1"); fi ;;
  esac
  shift
done

[[ -d $REPOS ]] || { echo "tpr: no such directory: $REPOS (set TPR_ROOT)" >&2; exit 1; }

# --- which binary ------------------------------------------------------------
if ((use_debug)); then
  if [[ ! -x $DEBUG_BIN ]]; then
    echo "tpr: no debug build at $DEBUG_BIN" >&2
    echo "tpr: build it with: (cd '$REPOS/tuicr' && cargo build)" >&2
    exit 1
  fi
  bin="$DEBUG_BIN"
else
  bin="$(command -v tuicr || true)"
  if [[ -z $bin ]]; then
    echo "tpr: tuicr is not on PATH; use -d to run the local debug build" >&2
    exit 1
  fi
fi

# --- repo list ---------------------------------------------------------------
# Pure bash: 150+ basename spawns is measurably slow on Windows.
# -e rather than -d so linked worktrees (.git as a file) still count.
list_repos() {
  local d
  for d in "$REPOS"/*/; do
    [[ -e "${d}.git" ]] || continue
    d="${d%/}"
    printf '%s\n' "${d##*/}"
  done
}

# --- pickers -----------------------------------------------------------------
pick_fzf() {
  # --select-1: a unique match runs straight through, no menu
  # --exit-0:   a query that matches nothing exits quietly
  # -i: repo dirs are CamelCase (Comp.Submissions) but you type lowercase
  list_repos | fzf -i \
    --height=40% --reverse --border \
    --prompt='repo> ' --query="$query" \
    --select-1 --exit-0
}

pick_select() {
  local -a repos=() hits=()
  local r
  mapfile -t repos < <(list_repos)

  if [[ -n $query ]]; then
    # nocasematch: repo dirs are CamelCase (Comp.Submissions), queries aren't
    local restore_nocasematch
    restore_nocasematch="$(shopt -p nocasematch)"
    shopt -s nocasematch
    for r in "${repos[@]}"; do
      [[ $r == *"$query"* ]] && hits+=("$r")
    done
    eval "$restore_nocasematch"
    case ${#hits[@]} in
      0) return 1 ;;
      1) printf '%s\n' "${hits[0]}"; return 0 ;;
      *) repos=("${hits[@]}") ;;
    esac
  fi

  # select writes its menu and prompt to stderr, so stdout stays clean
  PS3="repo> "
  select r in "${repos[@]}"; do
    [[ -n $r ]] && { printf '%s\n' "$r"; return 0; }
  done
  return 1
}

picker="${TPR_PICKER:-}"
if [[ -z $picker ]]; then
  if command -v fzf >/dev/null 2>&1; then picker=fzf; else picker=select; fi
fi

case "$picker" in
  fzf)    repo="$(pick_fzf || true)" ;;
  select) repo="$(pick_select || true)" ;;
  *)      echo "tpr: unknown TPR_PICKER '$picker' (want fzf or select)" >&2; exit 1 ;;
esac

# Esc / no match / empty selection: nothing to do, and not an error.
[[ -n ${repo:-} ]] || exit 0

dir="$REPOS/$repo"
[[ -d $dir ]] || { echo "tpr: not a directory: $dir" >&2; exit 1; }

# --- fetch + run -------------------------------------------------------------
# A stale review beats no review, so a failed fetch warns instead of aborting;
# tuicr's own error is clear if it turns out the PR's SHAs are missing.
if ((! no_fetch)); then
  git -C "$dir" fetch || echo "tpr: fetch failed in $repo, opening anyway" >&2
fi

# Subshell keeps the caller's cwd untouched.
( cd "$dir" && exec "$bin" ${passthru[@]+"${passthru[@]}"} )
