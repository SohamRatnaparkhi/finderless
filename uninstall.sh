#!/usr/bin/env bash
# Removes what install.sh put in place. Homebrew formulae and any .bak.* files
# are left alone deliberately: they may predate this repo.

set -euo pipefail

CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}
CACHE_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/zsh-completions
ZSHRC=${ZDOTDIR:-$HOME}/.zshrc
STAMP=$(date +%Y%m%d%H%M%S)

say() { printf '\033[1m::\033[0m %s\n' "$*"; }

for f in "$CONFIG_DIR/shell/open.zsh" "$CONFIG_DIR/shell/preview.sh" "$CONFIG_DIR/fd/open-ignore"; do
  if [ -e "$f" ] || [ -L "$f" ]; then
    rm -f "$f"
    say "removed ${f/#$HOME/\~}"
  fi
done

if [ -f "$ZSHRC" ] && grep -qF '# >>> fuzzy open layer >>>' "$ZSHRC"; then
  cp "$ZSHRC" "$ZSHRC.bak.$STAMP"
  # Delete the marker block, including the blank line that precedes it.
  awk '
    /^# >>> fuzzy open layer >>>$/ { skip = 1 }
    skip == 0 { buf[++n] = $0 }
    /^# <<< fuzzy open layer <<<$/ { skip = 0; if (n > 0 && buf[n] == "") n-- }
    END { for (i = 1; i <= n; i++) print buf[i] }
  ' "$ZSHRC.bak.$STAMP" > "$ZSHRC"
  say "unhooked ${ZSHRC/#$HOME/\~} (backup: $(basename "$ZSHRC").bak.$STAMP)"
fi

rm -f "$CACHE_DIR/fzf.zsh" "$CACHE_DIR/zoxide.zsh"
say "done. the macos-option-as-alt line in your Ghostty config was left in place."
