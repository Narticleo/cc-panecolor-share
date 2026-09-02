# bgcolor / bgstyle — per-pane terminal background (and fg+bg "style") switcher.
# bash port — see bgcolor.zsh for the zsh version. Same behavior, same commands.
#
# Works via OSC 10/11 escape sequences (set foreground/background color of the
# CURRENT terminal pane). Requires bash 4+ (associative arrays) and a truecolor-
# capable terminal. Pure bash builtins (no forked processes), so sourcing this
# costs ~0 shell startup time. `bgcolor ls` / `bgstyle ls` spawn `sort`, but only
# on demand.
#
# Usage:
#   bgcolor ls              list available colors with a live swatch preview
#   bgcolor set NAME        set this pane's background to NAME (or a #rrggbb hex)
#   bgcolor reset           restore this pane's default background
#   bgstyle ls              list available retro/OS-shell styles (powershell, cmd,
#                           dos, amber, green, matrix, c64, neon...) with a preview
#   bgstyle set NAME        set this pane's background+foreground to NAME's pair
#   bgstyle reset           restore this pane's default background+foreground
#
# Every new interactive shell also gets a random bgcolor automatically on open (see
# bottom of file) — reset/change it any time, it never affects other panes/windows.

declare -gA BGCOLOR_PALETTE=(
  [slate]="#1e222a"
  [charcoal]="#161821"
  [graphite]="#202020"
  [navy]="#0f1c2e"
  [ocean]="#0b2530"
  [teal]="#0d2b2b"
  [forest]="#10241a"
  [olive]="#232616"
  [mustard]="#2a2410"
  [amber]="#2b2011"
  [brick]="#2c1810"
  [maroon]="#26141a"
  [wine]="#2a1420"
  [rose]="#301a24"
  [plum]="#241a2e"
  [violet]="#231a33"
  [indigo]="#1a1a33"
  [sky]="#12283a"
  [steel]="#1c242c"
  [black]="#000000"
  [cream]="#f5f0dc"
  [white]="#f5f5f0"
)

# "style" = retro terminal / OS-shell looks (bg+fg pair), not editor color schemes.
declare -gA BGSTYLE_BG=(
  [powershell]="#012456"
  [cmd]="#0c0c0c"
  [dos]="#0000aa"
  [amber]="#1a1207"
  [green]="#0a0a0a"
  [matrix]="#000000"
  [c64]="#40318d"
  [neon]="#0d0221"
)
declare -gA BGSTYLE_FG=(
  [powershell]="#eeeeee"
  [cmd]="#cccccc"
  [dos]="#aaaaaa"
  [amber]="#ffb000"
  [green]="#33ff33"
  [matrix]="#00ff41"
  [c64]="#7c70da"
  [neon]="#ff2ec4"
)

# print a hex color as a truecolor background swatch: $1=hex $2=label
_bgcolor_swatch() {
  local hex=$1 label=$2 r g b
  r=$((16#${hex:1:2})); g=$((16#${hex:3:2})); b=$((16#${hex:5:2}))
  printf '\033[48;2;%d;%d;%dm  \033[0m %-11s %s\n' "$r" "$g" "$b" "$label" "$hex"
}

# print a bg+fg pair as a live "Aa" sample rendered in the actual style: $1=bg $2=fg $3=label
_bgstyle_swatch() {
  local bg=$1 fg=$2 label=$3 br bg_g bg_b fr fg_g fg_b
  br=$((16#${bg:1:2})); bg_g=$((16#${bg:3:2})); bg_b=$((16#${bg:5:2}))
  fr=$((16#${fg:1:2})); fg_g=$((16#${fg:3:2})); fg_b=$((16#${fg:5:2}))
  printf '\033[48;2;%d;%d;%dm\033[38;2;%d;%d;%dm Aa \033[0m %-11s bg=%s fg=%s\n' \
    "$br" "$bg_g" "$bg_b" "$fr" "$fg_g" "$fg_b" "$label" "$bg" "$fg"
}

_bgcolor_resolve() {
  local name=$1
  if [[ -n "${BGCOLOR_PALETTE[$name]}" ]]; then
    printf '%s' "${BGCOLOR_PALETTE[$name]}"
  elif [[ "$name" =~ ^#[0-9a-fA-F]{6}$ ]]; then
    printf '%s' "$name"
  fi
}

bgcolor() {
  local sub=$1
  case "$sub" in
    ls|list|"")
      local name
      for name in "${!BGCOLOR_PALETTE[@]}"; do
        _bgcolor_swatch "${BGCOLOR_PALETTE[$name]}" "$name"
      done | sort -k2
      ;;
    set)
      local hex; hex=$(_bgcolor_resolve "$2")
      if [[ -z "$hex" ]]; then
        echo "bgcolor: unknown color '$2' (try: bgcolor ls, or a #rrggbb hex)" >&2
        return 1
      fi
      printf '\033]11;%s\007' "$hex"
      ;;
    reset)
      printf '\033]111\007'
      ;;
    *)
      echo "usage: bgcolor [ls|set NAME|reset]" >&2
      return 1
      ;;
  esac
}

bgstyle() {
  local sub=$1
  case "$sub" in
    ls|list|"")
      local name
      for name in "${!BGSTYLE_BG[@]}"; do
        _bgstyle_swatch "${BGSTYLE_BG[$name]}" "${BGSTYLE_FG[$name]}" "$name"
      done | sort -k2
      ;;
    set)
      local name=$2 bg=${BGSTYLE_BG[$2]} fg=${BGSTYLE_FG[$2]}
      if [[ -z "$bg" ]]; then
        echo "bgstyle: unknown style '$2' (try: bgstyle ls)" >&2
        return 1
      fi
      printf '\033]11;%s\007' "$bg"
      printf '\033]10;%s\007' "$fg"
      ;;
    reset)
      printf '\033]111\007'
      printf '\033]110\007'
      ;;
    *)
      echo "usage: bgstyle [ls|set NAME|reset]" >&2
      return 1
      ;;
  esac
}

# Auto-assign a random bgcolor to each new interactive shell. Fired from
# PROMPT_COMMAND (bash's per-prompt hook), not inline here, for the same reason the
# zsh version defers to precmd: some prompt frameworks (Powerlevel10k on zsh is the
# known case) temporarily redirect fd 1 away from the real terminal while rc files
# are still being sourced, so `[[ -t 1 ]]` can read false if checked too early. A
# plain bash setup with no such framework doesn't have this problem — the color
# will just show up immediately on the very first prompt instead of the second.
# Guarded by an internal flag rather than removing itself from PROMPT_COMMAND, so it
# becomes a single cheap variable check on every later prompt once it has run once.
_bgcolor_autopick() {
  [[ -n "$BGCOLOR_AUTO_PICKED" ]] && return
  [[ -t 1 ]] || return
  export BGCOLOR_AUTO_PICKED=1
  local -a pool=()
  local name
  for name in "${!BGCOLOR_PALETTE[@]}"; do
    [[ "$name" == white || "$name" == cream ]] && continue
    pool+=("$name")
  done
  bgcolor set "${pool[$(( RANDOM % ${#pool[@]} ))]}"
}
if [[ $- == *i* ]] && [[ -z "$BGCOLOR_AUTO_DONE" ]]; then
  export BGCOLOR_AUTO_DONE=1
  PROMPT_COMMAND="_bgcolor_autopick${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi
