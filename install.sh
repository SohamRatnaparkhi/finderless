#!/usr/bin/env bash
# finderless installer. Idempotent: safe to re-run after every git pull.
#
#   ./install.sh                 install everything
#   ./install.sh --no-deps       skip the Homebrew step
#   ./install.sh --no-ghostty    leave the Ghostty config alone
#   ./install.sh --copy          copy files instead of symlinking them
#
# Written for bash 3.2, the version macOS still ships.

set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}
CACHE_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/zsh-completions
ZSHRC=${ZDOTDIR:-$HOME}/.zshrc
STAMP=$(date +%Y%m%d%H%M%S)

FORMULAE="fzf fd ripgrep bat eza zoxide yazi poppler chafa"

DO_DEPS=1
DO_GHOSTTY=1
MODE=link

while [ $# -gt 0 ]; do
  case "$1" in
    --no-deps)    DO_DEPS=0 ;;
    --no-ghostty) DO_GHOSTTY=0 ;;
    --copy)       MODE=copy ;;
    -h|--help)    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

say()  { printf '\033[1m::\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31mxx\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- preflight

[ "$(uname -s)" = "Darwin" ] || die "macOS only: this leans on open(1), mdfind(1) and qlmanage(1)."

# ---------------------------------------------------------------- packages

if [ "$DO_DEPS" -eq 1 ]; then
  if command -v brew >/dev/null 2>&1; then
    missing=""
    for f in $FORMULAE; do
      brew list --formula "$f" >/dev/null 2>&1 || missing="$missing $f"
    done
    if [ -n "$missing" ]; then
      say "installing:$missing"
      # shellcheck disable=SC2086
      brew install $missing
    else
      say "all Homebrew formulae already present"
    fi
  else
    warn "Homebrew not found; skipping packages. Install it from https://brew.sh"
    warn "or provide these yourself:$FORMULAE"
  fi
fi

# ---------------------------------------------------------------- files

# place <source-in-repo> <destination>
place() {
  src=$1
  dest=$2
  mkdir -p "$(dirname "$dest")"

  # An existing symlink already pointing at the repo needs no work.
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    say "ok       ${dest/#$HOME/\~}"
    return
  fi
  # Anything else that is already there gets moved aside, never clobbered.
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mv "$dest" "$dest.bak.$STAMP"
    warn "backed up ${dest/#$HOME/\~} -> $(basename "$dest").bak.$STAMP"
  fi

  if [ "$MODE" = copy ]; then
    cp "$src" "$dest"
  else
    ln -s "$src" "$dest"
  fi
  say "$MODE     ${dest/#$HOME/\~}"
}

place "$REPO_DIR/shell/open.zsh"   "$CONFIG_DIR/shell/open.zsh"
place "$REPO_DIR/shell/preview.sh" "$CONFIG_DIR/shell/preview.sh"
place "$REPO_DIR/fd/open-ignore"   "$CONFIG_DIR/fd/open-ignore"
chmod +x "$REPO_DIR/shell/preview.sh"

# ---------------------------------------------------------------- zshrc hook

MARKER='# >>> fuzzy open layer >>>'
if [ -f "$ZSHRC" ] && grep -qF "$MARKER" "$ZSHRC"; then
  say "ok       ${ZSHRC/#$HOME/\~} already sources the layer"
else
  [ -f "$ZSHRC" ] && cp "$ZSHRC" "$ZSHRC.bak.$STAMP"
  cat >> "$ZSHRC" <<EOF

$MARKER
# fzf/fd/zoxide-backed file finding and opening. Run \`oh\` for the cheatsheet.
source "\$HOME/.config/shell/open.zsh"
# <<< fuzzy open layer <<<
EOF
  say "hooked   ${ZSHRC/#$HOME/\~}"
fi

# ---------------------------------------------------------------- ghostty

# Ghostty does not send Option as Alt by default, which leaves alt-c (fzf's cd
# widget) and any Opt+Backspace / Opt+arrow zsh bindings dead.
if [ "$DO_GHOSTTY" -eq 1 ] && [ -d "/Applications/Ghostty.app" ]; then
  GHOSTTY_CONF="$CONFIG_DIR/ghostty/config"
  mkdir -p "$(dirname "$GHOSTTY_CONF")"
  if [ ! -f "$GHOSTTY_CONF" ]; then
    cp "$REPO_DIR/ghostty/config" "$GHOSTTY_CONF"
    say "wrote    ${GHOSTTY_CONF/#$HOME/\~}"
  else
    # Append only the lines that are missing so a re-run after git pull
    # picks up the cmd+v pin without clobbering the rest of the file.
    added=0
    while IFS= read -r line; do
      case "$line" in
        ''|\#*) continue ;;
      esac
      key="${line%%=*}"
      key="$(printf '%s' "$key" | sed 's/[[:space:]]*$//')"
      if grep -q "^[[:space:]]*${key}[[:space:]]*=" "$GHOSTTY_CONF"; then
        continue
      fi
      if [ "$added" -eq 0 ]; then
        {
          echo
          echo "# Added by finderless"
        } >> "$GHOSTTY_CONF"
      fi
      printf '%s\n' "$line" >> "$GHOSTTY_CONF"
      added=$((added + 1))
    done < "$REPO_DIR/ghostty/config"
    if [ "$added" -eq 0 ]; then
      say "ok       ghostty config already has the finderless keys"
    else
      say "appended $added ghostty line(s)"
    fi
  fi
  warn "reload Ghostty (cmd+shift+,) or restart it for that to take effect"
fi

# ---------------------------------------------------------------- caches

# open.zsh caches `fzf --zsh` and `zoxide init zsh` here; drop them so the next
# shell regenerates against whatever versions were just installed.
rm -f "$CACHE_DIR/fzf.zsh" "$CACHE_DIR/zoxide.zsh"

say "done. open a new shell (or: source ${ZSHRC/#$HOME/\~}) and run 'oh'"
