#!/bin/sh
# fzf preview renderer. Prints something useful for whatever $1 happens to be:
# text through bat, PDFs through pdftotext, images through chafa, archives as a
# listing, everything else as Spotlight metadata. Kept as a standalone script
# because fzf runs previews in a bare subshell that never sees zsh functions.

f=$1
[ -n "$f" ] || exit 0
[ -e "$f" ] || exit 0

cols=${FZF_PREVIEW_COLUMNS:-80}
lines=${FZF_PREVIEW_LINES:-30}

# App bundles are directories, so they have to be handled before the generic
# directory listing or you get a preview of Contents/ instead of the app.
case "$f" in
  *.app|*.app/)
    plist="${f%/}/Contents/Info.plist"
    printf '\033[1m%s\033[0m\n\n' "$(basename "${f%/}" .app)"
    if [ -f "$plist" ]; then
      for key in CFBundleShortVersionString CFBundleIdentifier LSMinimumSystemVersion; do
        val=$(plutil -extract "$key" raw -o - "$plist" 2>/dev/null) \
          && [ -n "$val" ] && printf '%-24s %s\n' "$key" "$val"
      done
    fi
    printf '%-24s %s\n' path "${f%/}"
    mdls -name kMDItemLastUsedDate -name kMDItemFSSize -- "${f%/}" 2>/dev/null \
      | sed 's/^kMDItem/  /'
    exit 0
    ;;
esac

if [ -d "$f" ]; then
  eza -la --icons --color=always --group-directories-first -- "$f" 2>/dev/null \
    || ls -la -- "$f"
  exit 0
fi

case "$(printf '%s' "$f" | tr '[:upper:]' '[:lower:]')" in
  *.pdf)
    pdfinfo -- "$f" 2>/dev/null | sed -n '1,7p'
    echo
    pdftotext -f 1 -l 4 -nopgbrk -- "$f" - 2>/dev/null | sed -n "1,$((lines * 4))p"
    ;;
  *.png|*.jpg|*.jpeg|*.gif|*.webp|*.bmp|*.tif|*.tiff|*.heic|*.ico)
    chafa -f symbols --animate off -s "${cols}x$((lines - 1))" -- "$f" 2>/dev/null \
      || file -b -- "$f"
    ;;
  *.svg)
    chafa -f symbols -s "${cols}x$((lines - 1))" -- "$f" 2>/dev/null \
      || bat --style=plain --color=always --line-range=:100 -- "$f"
    ;;
  *.zip|*.jar|*.whl|*.epub|*.docx|*.xlsx|*.pptx)
    unzip -l -- "$f" 2>/dev/null | sed -n "1,$((lines * 2))p" || file -b -- "$f"
    ;;
  *.tar|*.tgz|*.tar.gz|*.tar.bz2|*.tar.xz|*.tbz)
    tar -tf "$f" 2>/dev/null | sed -n "1,$((lines * 2))p"
    ;;
  *.mp4|*.mov|*.mkv|*.avi|*.webm|*.mp3|*.m4a|*.wav|*.flac|*.aac)
    mdls -name kMDItemDurationSeconds -name kMDItemPixelHeight \
         -name kMDItemPixelWidth -name kMDItemFSSize -- "$f" 2>/dev/null
    ;;
  *)
    case "$(file -b --mime-type -- "$f" 2>/dev/null)" in
      text/*|application/json|application/xml|application/javascript|application/x-sh|*+json|*+xml)
        bat --style=numbers --color=always --line-range=":$((lines * 3))" -- "$f"
        ;;
      *)
        file -b -- "$f"
        echo
        mdls -name kMDItemDisplayName -name kMDItemContentType \
             -name kMDItemFSSize -name kMDItemContentModificationDate \
             -- "$f" 2>/dev/null
        ;;
    esac
    ;;
esac
