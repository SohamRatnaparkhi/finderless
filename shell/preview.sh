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
