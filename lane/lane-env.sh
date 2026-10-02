# Sourced by the lane scripts. Resolves the project repo (main checkout) and its per-project state dir.
# LANES_REPO overrides the repo; default = main worktree of the git repo containing $PWD.
lanes_repo() {
  if [ -n "${LANES_REPO:-}" ]; then printf '%s\n' "$LANES_REPO"; return; fi
  local top; top=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || { echo "lanes: not inside a git repo (set LANES_REPO)" >&2; return 1; }
  dirname "$top"
}
lanes_state() { # ~/.local/state/lanes/<repo-name>-<8 hex of repo path>
  local r; r=$(lanes_repo) || return 1
  local d="$HOME/.local/state/lanes/$(basename "$r")-$(printf '%s' "$r" | { sha256sum 2>/dev/null || shasum -a 256; } | cut -c1-8)"
  mkdir -p "$d"; printf '%s\n' "$d"
}
