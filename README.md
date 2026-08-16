# finderless

Find and open any file on macOS from the terminal, without Finder and without Spotlight.

Type `o books raft` and the PDF opens. Type `o` alone and you get a fuzzy picker over everything under `$HOME` with a preview pane that renders PDFs, images, code and archives. Nothing here is new technology: it is a thin zsh layer over `fzf`, `fd`, `ripgrep`, `mdfind` and `zoxide`, wired together so that opening a file is one short command instead of a Finder expedition.

## Install

```sh
git clone https://github.com/SohamRatnaparkhi/finderless.git
cd finderless
./install.sh
```

The installer is idempotent, so re-run it after every `git pull`. It installs the Homebrew formulae it needs, symlinks the config into `~/.config`, adds one `source` line to your `.zshrc`, and backs up anything it would otherwise overwrite as `<file>.bak.<timestamp>`.

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

## What is in the box

| Path | Purpose |
| --- | --- |
| `shell/open.zsh` | the layer itself: commands, fzf configuration, key bindings |
| `shell/preview.sh` | the fzf preview renderer, kept standalone because fzf runs previews in a bare subshell that never sees zsh functions |
| `fd/open-ignore` | gitignore-syntax list of directories the search never walks |
| `ghostty/config` | makes the left option key send Alt, so `alt-c` actually fires |
| `install.sh` / `uninstall.sh` | setup and teardown |

Dependencies, all from Homebrew: `fzf` `fd` `ripgrep` `bat` `eza` `zoxide` `yazi` `poppler` `chafa`.

## Two decisions worth knowing about

**Whole-`$HOME` searches skip dotfiles.** On a working developer machine the agent and editor state under `~` dwarfs everything you actually want to open: on the machine this was built for, `.go`, `.cursor`, `.devin` and `.windsurf` accounted for 310k of 349k files. Excluding them takes a full scan from 1.27s to 0.25s and, more importantly, stops `od` from returning model checkpoints instead of your books. Directory-scoped commands (`oc`, `s`, `ctrl-t`) still see hidden files, so project dotfiles stay reachable. Set `OPEN_HIDDEN=1` to include them everywhere, and add your own noise to `fd/open-ignore`.

**Ghostty needs `macos-option-as-alt`.** Ghostty does not send Option as Alt by default, which silently kills `alt-c` and any `Opt+Backspace` word-motion bindings you have in zsh. The installer sets `macos-option-as-alt = left`, which leaves the right Option key free to type `ø`, `∑` and friends. Skip it with `--no-ghostty`. Note that Ghostty reads `~/.config/ghostty/config`, with no file extension: a `config.ghostty` sitting next to it is ignored.

## Tuning

| Variable | Default | Meaning |
| --- | --- | --- |
| `OPEN_ROOT` | `$HOME` | what the global commands search |
| `OPEN_EDITOR` | first of `zed`, `cursor`, `code`, `nvim`, `vim` found | editor for `oe` and `s` |
| `OPEN_RECENT_WINDOW` | `14d` | how far back `recent` looks |
| `OPEN_HIDDEN` | unset | set to `1` to include dotfiles in global searches |
| `OPEN_APP_DIRS` | `/Applications`, `/System/Applications`, `~/Applications` | where `a` and `ow` look for apps |

Apps are searched separately from files on purpose: an `.app` is a directory of thousands of files, so `fd/open-ignore` skips the bundles wholesale and `a` walks the application directories two levels deep instead (enough for `/System/Applications/Utilities`, not enough to descend into bundle internals). `/System/Library/CoreServices` is left out because it is mostly internal agents like `WindowManagerShowDesktopEducation.app`; add it to `OPEN_APP_DIRS` if you want `Finder.app` in the list.

Set any of them before the `source` line in your `.zshrc`.

The layer costs about 10ms of shell startup. `fzf --zsh` and `zoxide init zsh` each fork a process, so their output is cached under `~/.cache/zsh-completions`; delete that directory after upgrading either tool.

## Uninstall

```sh
./uninstall.sh
```

Removes the symlinks and the `.zshrc` hook. Homebrew formulae and backup files are left alone on purpose.

## License

MIT. See [LICENSE](LICENSE).
