# bgcolor / bgstyle

Per-pane terminal background (and foreground+background "style") switcher.
Mostly built for telling apart split panes/tabs at a glance when you have several
terminals open side by side — each one can carry its own color, set manually or
picked automatically when it opens.

```
bgcolor ls              list available colors with a live swatch preview
bgcolor set NAME        set this pane's background to NAME (or a #rrggbb hex)
bgcolor rd              pick and set a random color, never repeating the
                        current one (also excludes white/cream)
bgcolor reset           restore this pane's default background

bgstyle ls              list available retro/OS-shell styles (powershell, cmd,
                        dos, amber, green, matrix, c64, neon...) with a preview
bgstyle set NAME        set this pane's background+foreground to NAME's pair
bgstyle rd              pick and set a random style, never repeating the current one
bgstyle reset           restore this pane's default background+foreground
```

Every new interactive shell also gets a random `bgcolor` automatically — reset it
or pick a different one any time (`bgcolor rd`), it never touches any other pane
or window.

## How it works

Sets the color via [`OSC 10`/`OSC 11`](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html)
terminal escape sequences (foreground/background color of the *current* terminal
session). This is a terminal feature, not a shell feature — the shell scripts here
just print the right escape codes. Any terminal that understands OSC 10/11 will
work: confirmed on **Windows Terminal** (per-pane, which is the whole point of this
tool), and this is standard behavior on most others too (iTerm2, GNOME
Terminal/VTE, Kitty, WezTerm, foot, Alacritty, ...).

No dependencies, no config files, no external processes in the hot path — it's
pure shell builtins, so sourcing it costs a fraction of a millisecond.

## Which file do I want?

| Your shell | Use |
|---|---|
| zsh | `bgcolor.zsh` |
| bash | `bgcolor.bash` |

Not sure which shell you're in? `echo $SHELL` shows your *login* shell, but if
you're not sure what's actually running right now, `echo $0` or `ps -p $$ -o comm=`
is more reliable. Plain WSL Ubuntu ships with **bash** by default — zsh is a
separate `sudo apt install zsh` away if you'd rather have that instead (with
nothing else — no framework required, this doesn't need oh-my-zsh or
Powerlevel10k or anything like it).

Both files implement the exact same commands and behave identically day to day —
pick whichever matches your shell.

## Install

**zsh:**
```sh
curl -fsSL -o ~/.config/bgcolor.zsh \
  https://raw.githubusercontent.com/Narticleo/cc-panecolor-share/main/bgcolor.zsh
echo '[[ -f ~/.config/bgcolor.zsh ]] && source ~/.config/bgcolor.zsh' >> ~/.zshrc
```

**bash:**
```sh
curl -fsSL -o ~/.config/bgcolor.bash \
  https://raw.githubusercontent.com/Narticleo/cc-panecolor-share/main/bgcolor.bash
echo '[[ -f ~/.config/bgcolor.bash ]] && source ~/.config/bgcolor.bash' >> ~/.bashrc
```

Open a new pane/tab (or `source` the file you just added) and try `bgcolor ls`.

## Notes on different environments

- **tmux**: OSC 10/11 needs `set -g allow-passthrough on` (tmux 3.3+) to reach the
  real terminal from inside a tmux pane — without it, the color-setting commands
  are silently swallowed by tmux. Not needed if you're not using tmux.
- **SSH**: works fine over a plain SSH session — the escape codes are interpreted
  by *your local* terminal regardless of how many hops away the shell actually is,
  as long as nothing in between (like tmux, see above) is eating them.
- **The auto-random-color-on-open behavior can lag by one prompt** in a shell with
  a prompt framework that manipulates stdout during startup (Powerlevel10k's
  "instant prompt" is the known case: it temporarily redirects fd 1 away from the
  real terminal while still sourcing `.zshrc`, so the color can't apply until the
  framework hands the real terminal back — which happens right after your first
  keystroke). In a plain shell with no such framework (e.g. vanilla bash, or zsh
  without a prompt framework), the color shows up immediately, before you've typed
  anything.
- **Windows Terminal specifically**: this is the terminal this was built and tested
  against — per-pane OSC 10/11 works correctly, which is what makes "each split
  pane gets its own color" possible in the first place. Native OS-level terminals
  that don't do their own pane-splitting (i.e. you're relying on tmux for splits
  instead) fall under the tmux note above.

## Customizing the palette

Both files define two associative arrays you can freely edit — `BGCOLOR_PALETTE`
(name → hex, for `bgcolor`) and `BGSTYLE_BG` / `BGSTYLE_FG` (name → hex pairs, for
`bgstyle`). Add, remove, or recolor entries directly; no other code needs to change.
