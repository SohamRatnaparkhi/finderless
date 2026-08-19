# finderless

Find and open any file on macOS from the terminal, without Finder and without Spotlight.

[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE) ![platform: macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg) ![shell: zsh](https://img.shields.io/badge/shell-zsh-green.svg)

## The problem

The file you want is almost always one you can name. It is a PDF in `~/books`, in a folder about distributed systems, inside something else. Finder's search reliably fails to find it. Spotlight does find it, but hitting Cmd-Space to hunt down a file you can nearly spell means leaving the terminal, waiting on an index, and clicking through a result list.

None of the technology here is new. It is `fzf`, `fd`, `ripgrep`, `mdfind` and `zoxide`, which you very likely already have installed and have never actually wired together. finderless is the wiring: a thin zsh layer that turns opening a file into one short command.

```console
$ o books raft
  (fuzzy picker, ranked, with the PDF's first pages rendered in the preview pane)
  -> opens in Preview

$ oe open.zsh          # same idea, opens in your editor
$ s "raft election"    # live grep through file contents, lands on the matching line
$ w raft consensus     # web search in your default browser
$ a zed                # launch an app
$ cdf projects cortex  # cd anywhere under $HOME
```

## Install

```sh
git clone https://github.com/SohamRatnaparkhi/finderless.git
cd finderless
./install.sh
```

Requires macOS, zsh and Homebrew. The installer is idempotent, so re-run it after every `git pull`. It installs the formulae it needs, symlinks the config into `~/.config`, adds one `source` line to your `.zshrc`, and backs up anything it would otherwise overwrite as `<file>.bak.<timestamp>`.

Flags: `--no-deps` skips Homebrew, `--no-ghostty` leaves the terminal config alone, `--copy` copies files instead of symlinking them.

Then open a new shell and run `oh` for the cheatsheet.

## Commands

Every command takes an optional query, so `o books raft` goes straight to the shortlist and a bare `o` opens the picker. `Tab` multi-selects, so you can open several files at once.

| Command | What it does |
| --- | --- |
| `o [query]` | open a file from anywhere under `$HOME` in its default app |
| `oc [query]` | the same, scoped to the current directory tree |
| `od [query]` | documents only: pdf, epub, djvu, docx, pptx, xlsx, md, txt |
| `oe [query]` | open in Zed (or whichever editor is found first) |
| `ql [query]` | Quick Look preview, without launching an app |
| `rv [query]` | reveal in Finder, for the rare case you need it |
| `y [dir]` | the yazi file manager, and it `cd`s to wherever you quit |
| `a [query]` | launch an installed app: `a zed`, `a cursor`, `a ghostty` |
| `ow [query]` | open a file with an app you pick, instead of its default one |
| `w [query]` | search the web in your default browser, or open a URL |
| `s [text]` | live ripgrep through file contents, opens the editor at the matching line |
| `sp [text]` | Spotlight search across file contents disk-wide, opens the hit |
| `f [query]` | print the path, for example `cp "$(f raft)" .` |
| `fc [query]` | copy the path to the clipboard |
| `cdf [query]` | `cd` into any directory under `$HOME` |
| `z <query>` | zoxide: jump to a directory you have visited before |
| `recent [dir]` | files touched in the last 14 days, newest first |
| `oh` | print the cheatsheet |

## Keys

| Key | Action |
| --- | --- |
| `ctrl-o` | pick a file and open it, leaving the line you were typing intact |
| `ctrl-t` | insert a path at the cursor |
| `ctrl-r` | fuzzy shell history |
| `alt-c` | `cd` into a directory |
| `tab` | multi-select |
| `ctrl-/` | toggle the preview pane |
| `ctrl-u` / `ctrl-d` | scroll the preview |
| `ctrl-a` | select all matches |

## The preview pane

Previews are type-aware, because a file picker that cannot show you the file is just a list of names. PDFs are rendered to text with `pdftotext`, images drawn inline with `chafa`, code syntax-highlighted through `bat`, archives listed, app bundles reduced to name, version and bundle id, and anything else falls back to Spotlight metadata. It lives in `shell/preview.sh` as a standalone script rather than a shell function, because fzf runs previews in a bare subshell that never sees your zsh functions.

## Two decisions worth knowing about

**Whole-`$HOME` searches skip dotfiles.** On a working developer machine, the agent and editor state under `~` dwarfs everything you actually want to open. On the machine this was built for, `.go`, `.cursor`, `.devin` and `.windsurf` accounted for 310k of 349k files: the real documents were the remaining 11%. Excluding them takes a full scan from 1.27s to 0.25s and, more importantly, stops `od` from surfacing model checkpoints instead of books. Anything scoped to a directory you are standing in (`oc`, `s`, `ctrl-t`) still sees hidden files, so project dotfiles stay reachable. Set `OPEN_HIDDEN=1` to include them everywhere, and add your own noise to `fd/open-ignore`.

**Ghostty needs `macos-option-as-alt`, and cmd+v must stay a real paste.** Ghostty does not send Option as Alt by default, which silently kills `alt-c` and any `Opt+Backspace` word-motion bindings you have in zsh. The installer sets `macos-option-as-alt = left`, which leaves the right Option key free to type `ø`, `∑` and friends. It also pins `cmd+c` / `cmd+v` to copy and paste. tmux `extended-keys` makes Ghostty's default performable paste hand the key to the shell instead, and that CSI-u sequence can fire the finderless `ctrl-o` widget. Skip the Ghostty edits with `--no-ghostty`. Note that Ghostty reads `~/.config/ghostty/config`, with no file extension: a `config.ghostty` sitting next to it is ignored.

## What is in the box

| Path | Purpose |
| --- | --- |
| `shell/open.zsh` | the layer itself: commands, fzf configuration, key bindings |
| `shell/preview.sh` | the type-aware fzf preview renderer |
| `fd/open-ignore` | gitignore-syntax list of directories the search never walks |
| `ghostty/config` | makes the left option key send Alt, so `alt-c` actually fires |
| `install.sh` / `uninstall.sh` | setup and teardown |

Dependencies, all from Homebrew: `fzf` (0.48 or newer, for `fzf --zsh`), `fd`, `ripgrep`, `bat`, `eza`, `zoxide`, `yazi`, `poppler`, `chafa`.

## Tuning

| Variable | Default | Meaning |
| --- | --- | --- |
| `OPEN_ROOT` | `$HOME` | what the global commands search |
| `OPEN_EDITOR` | first of `zed`, `cursor`, `code`, `nvim`, `vim` found | editor for `oe` and `s` |
| `OPEN_RECENT_WINDOW` | `14d` | how far back `recent` looks |
| `OPEN_HIDDEN` | unset | set to `1` to include dotfiles in global searches |
| `OPEN_APP_DIRS` | `/Applications`, `/System/Applications`, `~/Applications` | where `a` and `ow` look for apps |
| `OPEN_SEARCH` | `https://www.google.com/search?q=%s` | search URL for `w`; `%s` is replaced with the query |

Set any of them before the `source` line in your `.zshrc`.

Apps are searched separately from files on purpose: an `.app` is a directory of thousands of files, so `fd/open-ignore` skips the bundles wholesale and `a` walks the application directories two levels deep instead. That is enough for `/System/Applications/Utilities`, and not enough to descend into bundle internals. `/System/Library/CoreServices` is left out because it is mostly internal agents like `WindowManagerShowDesktopEducation.app`; add it to `OPEN_APP_DIRS` if you want `Finder.app` in the list.

`w` is the browser omnibox. `w raft consensus` searches, `w rust-lang.org` opens the site, `w localhost:3000` hits the local server. A bare `w` is a picker over recent queries, same shape as a bare `o`. `open -u` hands the URL to whatever browser is the system default, which on macOS is a new tab if that browser is already running. Set `OPEN_SEARCH` if you want DuckDuckGo or Kagi instead of Google. `w -s github.com` forces a search when the heuristic would have opened the site. It shadows `/usr/bin/w` (who is logged in), which you will not miss on a laptop.

The layer costs about 10ms of shell startup. `fzf --zsh` and `zoxide init zsh` each fork a process, so their output is cached under `~/.cache/zsh-completions`; delete that directory after upgrading either tool.

## Uninstall

```sh
./uninstall.sh
```

Removes the symlinks and the `.zshrc` hook. Homebrew formulae and backup files are left alone on purpose.

## License

MIT. See [LICENSE](LICENSE).
