# Fuzzy file layer: find and open anything without opening Finder.
# Everything here is a thin wrapper over fd / rg / mdfind piped into fzf.
# `oh` prints the cheatsheet.

# ------------------------------------------------------------------ settings

: ${OPEN_ROOT:=$HOME}                                  # what the global commands search
: ${OPEN_RECENT_WINDOW:=14d}                           # how far back `recent` looks
(( $+OPEN_APP_DIRS )) ||                               # where `a` looks for apps
  OPEN_APP_DIRS=(/Applications /System/Applications "$HOME/Applications")
OPEN_IGNORE=${XDG_CONFIG_HOME:-$HOME/.config}/fd/open-ignore
OPEN_PREVIEW=${XDG_CONFIG_HOME:-$HOME/.config}/shell/preview.sh
OPEN_PREVIEW_WINDOW='right,55%,border-left,wrap,<90(up,55%,border-bottom)'

# The editor the `oe` / `s` commands hand files to. Zed first, then whatever
# else is installed. $VISUAL / $EDITOR are only consulted as a fallback so that
# a terminal editor set for git commits does not hijack `oe`; export
# OPEN_EDITOR to override.
if [[ -z ${OPEN_EDITOR-} ]]; then
  for _c in zed cursor code nvim vim; do
    (( $+commands[$_c] )) && { OPEN_EDITOR=$_c; break }
  done
  unset _c
  : ${OPEN_EDITOR:=${VISUAL:-${EDITOR:-}}}
fi

export FZF_DEFAULT_OPTS="
  --height=80% --layout=reverse --border=rounded --info=inline-right --cycle
  --tmux=center,90%,80%
  --scheme=path --tiebreak=begin,length
  --prompt='» ' --pointer='▸' --marker='✓'
  --bind='ctrl-/:toggle-preview'
  --bind='ctrl-a:select-all,ctrl-x:deselect-all'
  --bind='ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down'
  --bind='alt-up:preview-up,alt-down:preview-down'
"
export FZF_DEFAULT_COMMAND="fd --type f --type l --hidden --follow --ignore-file $OPEN_IGNORE"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview '$OPEN_PREVIEW {}' --preview-window '$OPEN_PREVIEW_WINDOW'"
export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --ignore-file $OPEN_IGNORE"
export FZF_ALT_C_OPTS="--preview '$OPEN_PREVIEW {}' --preview-window '$OPEN_PREVIEW_WINDOW'"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window 'down,3,wrap,border-top'"

# Ctrl-T (insert a path), Ctrl-R (history), Alt-C (cd), plus zoxide's `z`.
# Cached under ~/.cache/zsh-completions like the k9s completions in .zshrc:
# both generators fork a process, which is ~40ms off every shell start.
# Delete that directory after upgrading fzf or zoxide.
_open_cache=${XDG_CACHE_HOME:-$HOME/.cache}/zsh-completions
[[ -d $_open_cache ]] || mkdir -p "$_open_cache"
if (( $+commands[fzf] )); then
  [[ -s $_open_cache/fzf.zsh ]] || fzf --zsh > "$_open_cache/fzf.zsh"
  source "$_open_cache/fzf.zsh"
fi
if (( $+commands[zoxide] )); then
  [[ -s $_open_cache/zoxide.zsh ]] || zoxide init zsh > "$_open_cache/zoxide.zsh"
  source "$_open_cache/zoxide.zsh"
fi
unset _open_cache

# ------------------------------------------------------------------ internals

# Shared fd flags for a given search root, into the caller's $_open_fd array.
# Whole-$HOME searches skip dotfiles: agent and editor state under ~ swamps the
# results (310k entries with them, 38k without). Anything scoped to a directory
# you are standing in keeps them, so project dotfiles stay reachable through
# `oc` / `s` / ctrl-t. Set OPEN_HIDDEN=1 to include them everywhere.
_open_flags() {
  _open_fd=(--follow --ignore-file "$OPEN_IGNORE")
  [[ $1 != "$OPEN_ROOT" || -n ${OPEN_HIDDEN-} ]] && _open_fd+=(--hidden)
}

# Candidate producers. Each prints one path per line.
_open_files() {
  local dir=${1:-$OPEN_ROOT}; local -a _open_fd; _open_flags "$dir"
  fd --type f --type l $_open_fd . "$dir"
}
_open_dirs() {
  local dir=${1:-$OPEN_ROOT}; local -a _open_fd; _open_flags "$dir"
  fd --type d $_open_fd . "$dir"
}
_open_docs() {
  local dir=${1:-$OPEN_ROOT}; local -a _open_fd; _open_flags "$dir"
  fd --type f $_open_fd \
     -e pdf -e epub -e djvu -e mobi -e azw3 -e ps \
     -e doc -e docx -e ppt -e pptx -e xls -e xlsx \
     -e pages -e key -e numbers -e md -e txt \
     . "$dir"
}
_open_recent() {
  local dir=${1:-$OPEN_ROOT}; local -a _open_fd; _open_flags "$dir"
  fd --type f $_open_fd --changed-within "$OPEN_RECENT_WINDOW" . "$dir" \
     -X stat -f '%m %N' 2>/dev/null | sort -rn | cut -d' ' -f2-
}

# Installed applications. Not reachable through the file commands on purpose:
# an .app is a directory of thousands of files, so `open-ignore` skips the
# bundles wholesale and they get their own producer instead. Depth 2 picks up
# /System/Applications/Utilities without descending into bundle internals.
# /System/Library/CoreServices is left out: it is full of internal agents like
# WindowManagerShowDesktopEducation.app that you would never launch by hand.
# Add it to OPEN_APP_DIRS yourself if you want Finder.app in the list.
_open_apps() {
  local -a dirs=(${^OPEN_APP_DIRS}(N-/))   # keep only the ones that exist
  (( $#dirs )) || return
  fd --type d --extension app --max-depth 2 . $dirs 2>/dev/null | sed 's:/$::'
}

_open_edit_at() {  # open $1 at line $2 in whichever editor is configured
  local file=$1 line=${2:-1}
  case ${OPEN_EDITOR:t} in
    cursor|code|codium|windsurf) "${=OPEN_EDITOR}" --goto "$file:$line" ;;
    zed)                         "${=OPEN_EDITOR}" "$file:$line" ;;
    vim|nvim|vi|view)            "${=OPEN_EDITOR}" "+$line" "$file" ;;
    *)                           "${=OPEN_EDITOR}" "$file" ;;
  esac
}

# Extra fzf flags for a single call. Declared global-and-empty on purpose: an
# *unset* array expands to one empty word in zsh, which fzf rejects as an
# unknown option. Commands that need extras shadow it with a `local -a`.
typeset -ga _open_opts=()

# _open_run <action> <prompt> <query> <producer> [producer-args...]
# Runs the producer through fzf and applies the action to the selection.
# Callers may set a local `_open_opts` array to add fzf flags. Deliberately not
# a pipeline so that the `cd` action lands in the calling shell.
_open_run() {
  local action=$1 prompt=$2 query=$3; shift 3
  local -a sel
  sel=("${(@f)$("$@" | fzf --multi --prompt="$prompt" --query="$query" \
        --preview="$OPEN_PREVIEW {}" --preview-window="$OPEN_PREVIEW_WINDOW" \
        "${_open_opts[@]}")}")
  [[ -n ${sel[1]-} ]] || return 1
  case $action in
    open)   open -- "${sel[@]}" ;;
    edit)   if [[ -n $OPEN_EDITOR ]]; then "${=OPEN_EDITOR}" "${sel[@]}"
            else print -u2 "no editor found; set OPEN_EDITOR"; return 1; fi ;;
    print)  print -rl -- "${sel[@]}" ;;
    peek)   qlmanage -p -- "${sel[@]}" >/dev/null 2>&1 ;;
    reveal) open -R -- "${sel[1]}" ;;
    cd)     builtin cd -- "${sel[1]}" && print -r -- "$PWD" ;;
    copy)   print -rn -- "${(j:\n:)sel}" | pbcopy && print -r -- "copied ${#sel} path(s)" ;;
  esac
}

# ------------------------------------------------------------------ commands

o()   { _open_run open   'open> '      "$*" _open_files "$OPEN_ROOT" }   # anywhere under $HOME
oc()  { _open_run open   'open·here> ' "$*" _open_files .            }   # current directory tree
od()  { _open_run open   'docs> '      "$*" _open_docs  "$OPEN_ROOT" }   # pdf / epub / office only
oe()  { _open_run edit   'edit> '      "$*" _open_files "$OPEN_ROOT" }   # open in $OPEN_EDITOR
ql()  { _open_run peek   'peek> '      "$*" _open_files "$OPEN_ROOT" }   # Quick Look, no app launch
rv()  { _open_run reveal 'reveal> '    "$*" _open_files "$OPEN_ROOT" }   # reveal in Finder
f()   { _open_run print  'path> '      "$*" _open_files "$OPEN_ROOT" }   # print path(s): cp "$(f)" .
fc()  { _open_run copy   'copy> '      "$*" _open_files "$OPEN_ROOT" }   # copy path to clipboard
cdf() { _open_run cd     'cd> '        "$*" _open_dirs  "$OPEN_ROOT" }   # jump to any directory
a()   { _open_run open   'app> '       "$*" _open_apps              }   # launch an installed app

ow() {  # open a file with an app you pick, instead of its default one
  local file app
  file=$(_open_files "$OPEN_ROOT" | fzf --prompt='file> ' --query="$*" \
           --preview="$OPEN_PREVIEW {}" --preview-window="$OPEN_PREVIEW_WINDOW") || return
  [[ -n $file ]] || return
  app=$(_open_apps | fzf --prompt="open ${file:t} with> " \
           --preview="$OPEN_PREVIEW {}" --preview-window="$OPEN_PREVIEW_WINDOW") || return
  [[ -n $app ]] || return
  open -a "$app" -- "$file"
}

recent() {  # files touched in the last $OPEN_RECENT_WINDOW, newest first
  local -a _open_opts=(--no-sort)
  _open_run open 'recent> ' '' _open_recent "${1:-$OPEN_ROOT}"
}

sp() {  # Spotlight-backed search: matches file *contents* and metadata, whole disk
  local src="mdfind -onlyin ${(q)OPEN_ROOT}"
  local -a _open_opts=(
    --disabled --no-sort
    --bind "start:reload:[ -n {q} ] && $src {q} 2>/dev/null | head -500 || true"
    --bind "change:reload:sleep 0.15; [ -n {q} ] && $src {q} 2>/dev/null | head -500 || true"
  )
  _open_run open 'spotlight> ' "$*" true
}

s() {  # live ripgrep through file contents in the current tree, open at the match
  local rg="rg --column --line-number --no-heading --color=always --smart-case --hidden --glob=!.git"
  local out
  out=$(fzf --ansi --disabled --no-multi --query="$*" --prompt='grep> ' \
      --delimiter=: \
      --bind "start:reload:$rg -- {q} || true" \
      --bind "change:reload:sleep 0.1; $rg -- {q} || true" \
      --bind "ctrl-o:execute-silent(open -- {1})" \
      --preview 'bat --style=numbers --color=always --highlight-line={2} -- {1}' \
      --preview-window="right,55%,border-left,+{2}/3,~0,<90(up,55%,border-bottom,+{2}/3)") || return
  [[ -n $out ]] || return
  local file=${out%%:*} rest=${out#*:}
  _open_edit_at "$file" "${rest%%:*}"
}

y() {  # yazi file manager; cd to wherever you left off on quit
  local tmp cwd
  tmp=$(mktemp -t yazi-cwd.XXXXXX) || return
  yazi "$@" --cwd-file="$tmp"
  if cwd=$(command cat -- "$tmp") && [[ -n $cwd && $cwd != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  command rm -f -- "$tmp"
}

# ------------------------------------------------------------------ keys

# Ctrl-O from any prompt: pick a file and open it, leaving the typed line intact.
# (Ctrl-T, from fzf, already covers inserting a path at the cursor.)
_open_widget() { zle -I; o; zle reset-prompt }
zle -N _open_widget
bindkey '^O' _open_widget

# ------------------------------------------------------------------ help

oh() {
  print -- "
  \e[1mopen anything\e[0m                      (query is optional on every command)
    o    [query]   open a file from anywhere under \$HOME, default app
    oc   [query]   same, but only the current directory tree
    od   [query]   documents only: pdf epub docx pptx xlsx md txt
    oe   [query]   open in ${OPEN_EDITOR:-<no editor set>}
    ql   [query]   Quick Look preview, no app launch
    rv   [query]   reveal in Finder
    y    [dir]     yazi file manager, cds where you left off

  \e[1mapps\e[0m
    a    [query]   launch an installed app:  a zed, a cursor, a ghostty
    ow   [query]   open a file with an app you pick, not its default one

  \e[1msearch by content\e[0m
    s    [text]    live ripgrep in this tree, opens at the matching line
    sp   [text]    Spotlight: searches file contents disk-wide, opens the hit

  \e[1mpaths and navigation\e[0m
    f    [query]   print the path            e.g.  cp \"\$(f raft)\" .
    fc   [query]   copy the path to clipboard
    cdf  [query]   cd into any directory under \$HOME
    z    <query>   zoxide: jump to a directory you have visited before
    recent [dir]   files touched in the last $OPEN_RECENT_WINDOW, newest first

  \e[1mkeys\e[0m
    ctrl-o   pick a file and open it            ctrl-t   insert a path into the line
    ctrl-r   fuzzy shell history                alt-c    cd into a directory
    tab      multi-select (open several)        ctrl-/   toggle the preview pane
    ctrl-u/d scroll the preview                 ctrl-a   select all matches

  \e[1mtuning\e[0m
    OPEN_ROOT=$OPEN_ROOT            searched by every command without a dir argument
    OPEN_APP_DIRS=($OPEN_APP_DIRS)
    dotfiles are skipped for whole-\$HOME searches, kept for cwd ones (oc, s, ctrl-t);
    OPEN_HIDDEN=1 includes them everywhere
    edit ${OPEN_IGNORE/#$HOME/~} to hide noisy directories from results
"
}
