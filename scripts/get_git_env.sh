#!/usr/bin/env bash
# Export useful git environment variables for CI and local usage.
# Usage:
#   - source scripts/get_git_env.sh    # to set env vars in current shell
#   - scripts/get_git_env.sh           # to print vars for debugging
# Options:
#   --quiet    Don't print output, only export (useful when sourced from CI)
#   --print    Print variables (default when executed; ignored when sourced)

set -euo pipefail

QUIET=false
PRINT=true

for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=true; PRINT=false ;;
    --print) PRINT=true ;;
    -h|--help)
      cat <<'USAGE'
Usage: get_git_env.sh [--quiet|--print]

If sourced, the script will export variables into your shell environment. If run, it prints them.
It is safe to run in a non-git directory; variables will be empty or set to 'unknown'.
USAGE
      return 0 2>/dev/null || exit 0
      ;;
  esac
done

_cmd_exists() { command -v "$1" >/dev/null 2>&1; }
_safe() { "$@" 2>/dev/null || true; }

GIT_REPO_ROOT=""
GIT_COMMIT=""
GIT_COMMIT_SHORT=""
GIT_BRANCH=""
GIT_TAG=""
GIT_COMMIT_DATE=""
GIT_COMMIT_TIMESTAMP=""
GIT_COMMIT_AUTHOR_NAME=""
GIT_COMMIT_AUTHOR_EMAIL=""
GIT_COMMIT_MESSAGE=""
GIT_REMOTE_URL=""
GIT_UPSTREAM=""
GIT_IS_DIRTY=""
GIT_STATUS=""

if _cmd_exists git && _safe git rev-parse --git-dir >/dev/null; then
  GIT_REPO_ROOT=$(_safe git rev-parse --show-toplevel || echo "")
  GIT_COMMIT=$(_safe git rev-parse --verify HEAD 2>/dev/null || echo "")
  if [ -n "$GIT_COMMIT" ]; then
    # If GIT_COMMIT is at least 7 characters, use the first 7; otherwise, use the whole value (may be empty or short in edge cases)
    if [ "${#GIT_COMMIT}" -ge 7 ]; then
      GIT_COMMIT_SHORT=${GIT_COMMIT:0:7}
    else
      GIT_COMMIT_SHORT="$GIT_COMMIT"
    fi
  fi
  # branch or short ref
  GIT_BRANCH=$(_safe git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [ "$GIT_BRANCH" = "HEAD" ]; then
    GIT_BRANCH="$(git describe --all --always 2>/dev/null || echo "${GIT_COMMIT_SHORT}")"
  fi
  # tag if any
  GIT_TAG=$(_safe git describe --tags --exact-match HEAD 2>/dev/null || echo "")
  GIT_COMMIT_DATE=$(_safe git show -s --format=%ci HEAD 2>/dev/null || echo "")
  GIT_COMMIT_TIMESTAMP=$(_safe git show -s --format=%ct HEAD 2>/dev/null || echo "")
  GIT_COMMIT_AUTHOR_NAME=$(_safe git show -s --format=%an HEAD 2>/dev/null || echo "")
  GIT_COMMIT_AUTHOR_EMAIL=$(_safe git show -s --format=%ae HEAD 2>/dev/null || echo "")
  GIT_COMMIT_MESSAGE=$(_safe git show -s --format=%s HEAD 2>/dev/null || echo "")
  GIT_REMOTE_URL=$(_safe git remote get-url origin 2>/dev/null || echo "")
  GIT_UPSTREAM=$(_safe git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "")
  GIT_STATUS=$(_safe git status --porcelain 2>/dev/null || echo "")
  if [ -n "$GIT_STATUS" ]; then
    GIT_IS_DIRTY="true"
  else
    GIT_IS_DIRTY="false"
  fi
fi

export GIT_REPO_ROOT
export GIT_COMMIT
export GIT_COMMIT_SHORT
export GIT_BRANCH
export GIT_TAG
export GIT_COMMIT_DATE
export GIT_COMMIT_TIMESTAMP
export GIT_COMMIT_AUTHOR_NAME
export GIT_COMMIT_AUTHOR_EMAIL
export GIT_COMMIT_MESSAGE
export GIT_REMOTE_URL
export GIT_UPSTREAM
export GIT_IS_DIRTY
export GIT_STATUS

_print_var() {
  printf "%s=%s\n" "$1" "$2"
}

if [ "$PRINT" = true ] && [ "$QUIET" = false ]; then
  _print_var GIT_REPO_ROOT "$GIT_REPO_ROOT"
  _print_var GIT_COMMIT "$GIT_COMMIT"
  _print_var GIT_COMMIT_SHORT "$GIT_COMMIT_SHORT"
  _print_var GIT_BRANCH "$GIT_BRANCH"
  _print_var GIT_TAG "$GIT_TAG"
  _print_var GIT_COMMIT_DATE "$GIT_COMMIT_DATE"
  _print_var GIT_COMMIT_TIMESTAMP "$GIT_COMMIT_TIMESTAMP"
  _print_var GIT_COMMIT_AUTHOR_NAME "$GIT_COMMIT_AUTHOR_NAME"
  _print_var GIT_COMMIT_AUTHOR_EMAIL "$GIT_COMMIT_AUTHOR_EMAIL"
  _print_var GIT_COMMIT_MESSAGE "$GIT_COMMIT_MESSAGE"
  _print_var GIT_REMOTE_URL "$GIT_REMOTE_URL"
  _print_var GIT_UPSTREAM "$GIT_UPSTREAM"
  _print_var GIT_IS_DIRTY "$GIT_IS_DIRTY"
  _print_var GIT_STATUS "$GIT_STATUS"
fi

return 0 2>/dev/null || exit 0
