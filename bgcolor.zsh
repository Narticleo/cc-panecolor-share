# bgcolor / bgstyle — per-pane terminal background (and fg+bg "style") switcher.
#
# Works via OSC 10/11 escape sequences (set foreground/background color of the
# CURRENT terminal pane), which Windows Terminal applies per-pane. Pure zsh
# builtins only (no forked processes), so sourcing this costs ~0 shell startup
# time. `bgcolor ls` / `bgstyle ls` do spawn `sort`, but only on demand.
#
# Usage:
#   bgcolor ls              list available colors with a live swatch preview
#   bgcolor set NAME        set this pane's background to NAME (or a #rrggbb hex)
#   bgcolor rd              pick and set a random color, never repeating the
#                           current one (excludes white/cream too)
#   bgcolor reset           restore this pane's default background
#   bgstyle ls              list available retro/OS-shell styles (powershell, cmd,
#                           dos, amber, green, matrix, c64...) with a live preview
#   bgstyle set NAME        set this pane's background+foreground to NAME's pair
#   bgstyle rd              pick and set a random style, never repeating the current one
#   bgstyle reset           restore this pane's default background+foreground
#
# Every new interactive pane also gets a random bgcolor automatically on open (see
# bottom of file) — reset/change it any time, it never affects other panes.

typeset -gA BGCOLOR_PALETTE=(
  slate     "#1e222a"
  charcoal  "#161821"
  graphite  "#202020"
  navy      "#0f1c2e"
  ocean     "#0b2530"
  teal      "#0d2b2b"
  forest    "#10241a"
  olive     "#232616"
  mustard   "#2a2410"
  amber     "#2b2011"
  brick     "#2c1810"
  maroon    "#26141a"
  wine      "#2a1420"
  rose      "#301a24"
  plum      "#241a2e"
  violet    "#231a33"
  indigo    "#1a1a33"
  sky       "#12283a"
  steel     "#1c242c"
  black     "#000000"
  cream     "#f5f0dc"
  white     "#f5f5f0"
)

# "style" = retro terminal / OS-shell looks (bg+fg pair), not editor color schemes.
typeset -gA BGSTYLE_BG=(
  powershell  "#012456"
  cmd         "#0c0c0c"
  dos         "#0000aa"
  amber       "#1a1207"
  green       "#0a0a0a"
  matrix      "#000000"
  c64         "#40318d"
  neon        "#0d0221"
)
typeset -gA BGSTYLE_FG=(
  powershell  "#eeeeee"
  cmd         "#cccccc"
  dos         "#aaaaaa"
  amber       "#ffb000"
  green       "#33ff33"
  matrix      "#00ff41"
  c64         "#7c70da"
  neon        "#ff2ec4"
)

# print a hex color as a truecolor background swatch: $1=hex $2=label
_bgcolor_swatch() {
  local hex=$1 label=$2 r g b
  r=$((16#${hex[2,3]})); g=$((16#${hex[4,5]})); b=$((16#${hex[6,7]}))
  printf '\033[48;2;%d;%d;%dm  \033[0m %-11s %s\n' "$r" "$g" "$b" "$label" "$hex"
}

# print a bg+fg pair as a live "Aa" sample rendered in the actual style: $1=bg $2=fg $3=label
_bgstyle_swatch() {
  local bg=$1 fg=$2 label=$3 br bg_g bg_b fr fg_g fg_b
  br=$((16#${bg[2,3]})); bg_g=$((16#${bg[4,5]})); bg_b=$((16#${bg[6,7]}))
  fr=$((16#${fg[2,3]})); fg_g=$((16#${fg[4,5]})); fg_b=$((16#${fg[6,7]}))
  printf '\033[48;2;%d;%d;%dm\033[38;2;%d;%d;%dm Aa \033[0m %-11s bg=%s fg=%s\n' \
    "$br" "$bg_g" "$bg_b" "$fr" "$fg_g" "$fg_b" "$label" "$bg" "$fg"
}

_bgcolor_resolve() {
  local name=$1
  if [[ -n "${BGCOLOR_PALETTE[$name]}" ]]; then
    print -r -- "${BGCOLOR_PALETTE[$name]}"
  elif [[ "$name" == '#'?????? ]]; then
    print -r -- "$name"
  fi
}

bgcolor() {
  local sub=$1
  case "$sub" in
    ls|list|"")
      local name
      for name in ${(k)BGCOLOR_PALETTE}; do
        _bgcolor_swatch "${BGCOLOR_PALETTE[$name]}" "$name"
      done | sort -k2
      ;;
    set)
      local hex=$(_bgcolor_resolve "$2")
      if [[ -z "$hex" ]]; then
        print -u2 "bgcolor: unknown color '$2' (try: bgcolor ls, or a #rrggbb hex)"
        return 1
      fi
      printf '\033]11;%s\007' "$hex"
      typeset -g BGCOLOR_CURRENT=$hex
      ;;
    rd)
      local -a pool
      pool=(${(k)BGCOLOR_PALETTE:#(white|cream)})
      # exclude the current color by hex (names don't map 1:1 to hex, since a
      # hex was possibly set directly), falling back to the full pool if that
      # would empty it out (e.g. only one non-white/cream entry left)
      if [[ -n "$BGCOLOR_CURRENT" ]]; then
        local -a filtered=()
        local name
        for name in $pool; do
          [[ "${BGCOLOR_PALETTE[$name]}" == "$BGCOLOR_CURRENT" ]] && continue
          filtered+=("$name")
        done
        (( ${#filtered} > 0 )) && pool=($filtered)
      fi
      bgcolor set "${pool[$(( RANDOM % ${#pool} + 1 ))]}"
      ;;
    reset)
      printf '\033]111\007'
      unset BGCOLOR_CURRENT
      ;;
    *)
      print -u2 "usage: bgcolor [ls|set NAME|rd|reset]"
      return 1
      ;;
  esac
}

bgstyle() {
  local sub=$1
  case "$sub" in
    ls|list|"")
      local name
      for name in ${(k)BGSTYLE_BG}; do
        _bgstyle_swatch "${BGSTYLE_BG[$name]}" "${BGSTYLE_FG[$name]}" "$name"
      done | sort -k2
      ;;
    set)
      local name=$2 bg=${BGSTYLE_BG[$2]} fg=${BGSTYLE_FG[$2]}
      if [[ -z "$bg" ]]; then
        print -u2 "bgstyle: unknown style '$2' (try: bgstyle ls)"
        return 1
      fi
      printf '\033]11;%s\007' "$bg"
      printf '\033]10;%s\007' "$fg"
      typeset -g BGSTYLE_CURRENT=$name
      ;;
    rd)
      local -a pool
      pool=(${(k)BGSTYLE_BG:#$BGSTYLE_CURRENT})
      (( ${#pool} == 0 )) && pool=(${(k)BGSTYLE_BG})
      bgstyle set "${pool[$(( RANDOM % ${#pool} + 1 ))]}"
      ;;
    reset)
      printf '\033]111\007'
      printf '\033]110\007'
      unset BGSTYLE_CURRENT
      ;;
    *)
      print -u2 "usage: bgstyle [ls|set NAME|rd|reset]"
      return 1
      ;;
  esac
}

# Auto-assign a random bgcolor to each brand-new interactive pane (only — a nested
# shell in the SAME pane, e.g. `zsh`/`sudo -s`/ssh-and-back, is skipped via the
# exported guard var). Since this only ever sends this pane's own OSC 11, it never
# touches, and is never inherited by, any other pane/window. White/cream are excluded
# from the random pool (kept for manual `bgcolor set`) since a light flash reads
# worse by default. Pure builtins, no forked process — negligible startup cost.
#
# Fired from `precmd`, not inline here: Powerlevel10k's instant-prompt feature
# temporarily redirects fd 1 (stdout) away from the real terminal into a cache file
# for the whole rest of .zshrc's execution (see p10k.zsh's
# `exec ... 1>$__p9k_instant_prompt_output`). It only hands fd 1 back to the real
# terminal while actually expanding/drawing the first prompt (`_p9k_on_expand` ->
# `_p9k_clear_instant_prompt`) — which happens AFTER precmd hooks have already run
# for that cycle. So even inside the first precmd, `[[ -t 1 ]]` can still read false;
# retry on precmd instead of self-removing until it actually succeeds (fd 1 is back
# by the 2nd precmd cycle, i.e. right after the first prompt has been shown).
# Delegates to `bgcolor rd` (same random-pick logic, minus white/cream).
_bgcolor_autopick() {
  [[ -t 1 ]] || return
  add-zsh-hook -d precmd _bgcolor_autopick
  bgcolor rd
}
if [[ -o interactive ]] && [[ -z "$BGCOLOR_AUTO_DONE" ]]; then
  export BGCOLOR_AUTO_DONE=1
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _bgcolor_autopick
fi
