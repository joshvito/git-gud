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
  TPR_REPO       exact repo dir name; skips the picker entirely
  TPR_NO_IGNORE  set to skip dropping a lock-file .tuicrignore in the repo
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

# TPR_REPO names a repo dir outright (tprs sets it) - nothing to pick.
if [[ -n ${TPR_REPO:-} ]]; then
  repo="$TPR_REPO"
else
  case "$picker" in
    fzf)    repo="$(pick_fzf || true)" ;;
    select) repo="$(pick_select || true)" ;;
    *)      echo "tpr: unknown TPR_PICKER '$picker' (want fzf or select)" >&2; exit 1 ;;
  esac
fi

# Esc / no match / empty selection: nothing to do, and not an error.
[[ -n ${repo:-} ]] || exit 0

dir="$REPOS/$repo"
[[ -d $dir ]] || { echo "tpr: not a directory: $dir" >&2; exit 1; }

# --- lock-file .tuicrignore --------------------------------------------------
# tuicr filters diff files through the repo-root .tuicrignore at diff-load
# time, so the file has to exist before tuicr starts for the session to be
# born filtered. Lock files are machine-generated and never worth reading.
#
# Nothing in here may abort the launch - same bargain as the fetch below.

append_tuicrignore_block() {
  local file="$1"
  if [[ -s $file ]]; then printf '\n' >>"$file"; fi
  cat >>"$file" <<'EOF'
# --- tpr managed: package manager lock files ---
# Delete this whole block to opt out, or add `!<file>` below it to keep one
# lock file visible - later .tuicrignore rules win.
.tuicrignore
package-lock.json
npm-shrinkwrap.json
yarn.lock
pnpm-lock.yaml
bun.lock
bun.lockb
packages.lock.json
project.assets.json
Cargo.lock
go.sum
composer.lock
Gemfile.lock
poetry.lock
Pipfile.lock
uv.lock
gradle.lockfile
Package.resolved
.terraform.lock.hcl
# --- end tpr managed ---
EOF
}

ensure_tuicrignore() {
  local dir="$1"
  local file="$dir/.tuicrignore"
  local git_dir exclude

  # A tracked .tuicrignore is the repo's, not ours: appending to it would show
  # up as a real modification in the very diff we're about to review.
  if git -C "$dir" ls-files --error-unmatch .tuicrignore >/dev/null 2>&1; then
    return 0
  fi

  if [[ ! -f $file ]] || ! grep -qF 'tpr managed' "$file" 2>/dev/null; then
    if ! append_tuicrignore_block "$file"; then
      echo "tpr: could not write $file, opening anyway" >&2
      return 0
    fi
  fi

  # tuicr's matcher only reads .gitignore and .tuicrignore, so the self-ignore
  # line in the block above is what hides this file from tuicr; info/exclude is
  # what hides it from `git status`. Two readers, two mechanisms.
  git_dir="$(git -C "$dir" rev-parse --git-dir 2>/dev/null || true)"
  [[ -n $git_dir ]] || return 0
  # Linked worktrees report a relative gitdir, and .git is a file there.
  [[ $git_dir = /* || $git_dir = ?:* ]] || git_dir="$dir/$git_dir"
  exclude="$git_dir/info/exclude"
  if ! grep -qxF '.tuicrignore' "$exclude" 2>/dev/null; then
    mkdir -p "$git_dir/info" 2>/dev/null || return 0
    printf '.tuicrignore\n' >>"$exclude" 2>/dev/null || true
  fi
}

# --- fetch + run -------------------------------------------------------------
# A stale review beats no review, so a failed fetch warns instead of aborting;
# tuicr's own error is clear if it turns out the PR's SHAs are missing.
if ((! no_fetch)); then
  git -C "$dir" fetch || echo "tpr: fetch failed in $repo, opening anyway" >&2
fi

if [[ -z ${TPR_NO_IGNORE:-} ]]; then
  ensure_tuicrignore "$dir"
fi

# Subshell keeps the caller's cwd untouched.
( cd "$dir" && exec "$bin" ${passthru[@]+"${passthru[@]}"} )
