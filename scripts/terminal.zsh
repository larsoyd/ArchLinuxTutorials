#!/usr/bin/env zsh
emulate -L zsh
set -euo pipefail

mkdir -p ~/.config/kitty ~/.config/fastfetch

timestamp="$(date +%Y%m%d-%H%M%S)"

[[ -f ~/.config/kitty/kitty.conf ]] && cp ~/.config/kitty/kitty.conf ~/.config/kitty/kitty.conf.bak-$timestamp
[[ -f ~/.config/fastfetch/config.jsonc ]] && cp ~/.config/fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc.bak-$timestamp

cat > ~/.config/kitty/titus-nord.conf <<'EOF'
# Titus-ish Nord / Nordic look for kitty
# Palette: Nord Polar Night + Frost

font_family      MesloLGS Nerd Font Mono
bold_font        MesloLGS Nerd Font Mono Bold
italic_font      MesloLGS Nerd Font Mono Italic
bold_italic_font MesloLGS Nerd Font Mono Bold Italic
font_size        14.0

background #2E3440
foreground #D8DEE9
selection_background #4C566A
selection_foreground #ECEFF4

cursor #D8DEE9
cursor_text_color #2E3440
cursor_shape block

background_opacity 0.92
dynamic_background_opacity yes
background_blur 24

window_padding_width 14
confirm_os_window_close 0

# Nord colors
color0  #3B4252
color1  #BF616A
color2  #A3BE8C
color3  #EBCB8B
color4  #81A1C1
color5  #B48EAD
color6  #88C0D0
color7  #E5E9F0
color8  #4C566A
color9  #BF616A
color10 #A3BE8C
color11 #EBCB8B
color12 #81A1C1
color13 #B48EAD
color14 #8FBCBB
color15 #ECEFF4

active_tab_foreground   #2E3440
active_tab_background   #88C0D0
inactive_tab_foreground #D8DEE9
inactive_tab_background #3B4252
tab_bar_background      #2E3440
EOF

grep -qxF 'include titus-nord.conf' ~/.config/kitty/kitty.conf 2>/dev/null || print -r 'include titus-nord.conf' >> ~/.config/kitty/kitty.conf

cat > ~/.config/fastfetch/config.jsonc <<'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",

  "logo": {
    "type": "builtin",
    "source": "arch",
    "padding": {
      "top": 4,
      "left": 2,
      "right": 5
    },
    "color": {
      "1": "38;2;136;192;208",
      "2": "38;2;129;161;193"
    }
  },

  "display": {
    "separator": " ",
    "key": {
      "width": 18,
      "type": "string"
    },
    "color": {
      "keys": "38;2;180;142;173",
      "title": "38;2;136;192;208",
      "output": "38;2;216;222;233",
      "separator": "38;2;94;129;172"
    },
    "percent": {
      "type": 9,
      "color": {
        "green": "38;2;163;190;140",
        "yellow": "38;2;235;203;139",
        "red": "38;2;191;97;106"
      }
    },
    "bar": {
      "width": 12,
      "char": {
        "elapsed": "━",
        "total": "─"
      }
    }
  },

  "modules": [
    {
      "type": "custom",
      "format": "\u001b[38;2;76;86;106m╭──────────────────────── Hardware ───────────────────────╮"
    },
    {
      "type": "cpu",
      "key": "│ 󰻠 CPU :",
      "keyColor": "38;2;163;190;140"
    },
    {
      "type": "gpu",
      "key": "│ 󰍛 GPU :",
      "keyColor": "38;2;163;190;140"
    },
    {
      "type": "display",
      "key": "│ 󰍹 Display :",
      "keyColor": "38;2;163;190;140"
    },
    {
      "type": "disk",
      "key": "│ 󰋊 Disk :",
      "keyColor": "38;2;163;190;140"
    },
    {
      "type": "memory",
      "key": "│  Memory :",
      "keyColor": "38;2;163;190;140"
    },
    {
      "type": "swap",
      "key": "│ 󰓡 Swap :",
      "keyColor": "38;2;163;190;140"
    },
    {
      "type": "custom",
      "format": "\u001b[38;2;76;86;106m╰──────────────────────────────────────────────────────────╯"
    },

    "break",

    {
      "type": "custom",
      "format": "\u001b[38;2;76;86;106m╭──────────────────────── Software ───────────────────────╮"
    },
    {
      "type": "os",
      "key": "│  OS :",
      "keyColor": "38;2;235;203;139"
    },
    {
      "type": "kernel",
      "key": "│  Kernel :",
      "keyColor": "38;2;235;203;139"
    },
    {
      "type": "packages",
      "key": "│ 󰏖 Packages :",
      "keyColor": "38;2;235;203;139"
    },
    {
      "type": "shell",
      "key": "│  Shell :",
      "keyColor": "38;2;235;203;139"
    },
    {
      "type": "de",
      "key": "│ 󰧨 DE :",
      "keyColor": "38;2;136;192;208"
    },
    {
      "type": "wm",
      "key": "│ 󱂬 WM :",
      "keyColor": "38;2;136;192;208"
    },
    {
      "type": "theme",
      "key": "│ 󰉼 Theme :",
      "keyColor": "38;2;136;192;208"
    },
    {
      "type": "icons",
      "key": "│ 󰀻 Icons :",
      "keyColor": "38;2;136;192;208"
    },
    {
      "type": "font",
      "key": "│  Font :",
      "keyColor": "38;2;136;192;208"
    },
    {
      "type": "cursor",
      "key": "│ 󰇀 Cursor :",
      "keyColor": "38;2;136;192;208"
    },
    {
      "type": "terminal",
      "key": "│  Terminal :",
      "keyColor": "38;2;136;192;208"
    },
    {
      "type": "terminalfont",
      "key": "│ 󰛖 TermFont :",
      "keyColor": "38;2;136;192;208"
    },
    {
      "type": "custom",
      "format": "\u001b[38;2;76;86;106m╰──────────────────────────────────────────────────────────╯"
    },

    "break",

    {
      "type": "custom",
      "format": "\u001b[38;2;76;86;106m╭────────────────────── Uptime / Age ─────────────────────╮"
    },
    {
      "type": "command",
      "key": "│ OS Age :",
      "keyColor": "38;2;180;142;173",
      "text": "zsh -fc 'print -- $(( ($(date +%s) - $(stat -c %W /)) / 86400 )) days'"
    },
    {
      "type": "uptime",
      "key": "│ Uptime :",
      "keyColor": "38;2;180;142;173"
    },
    {
      "type": "custom",
      "format": "\u001b[38;2;76;86;106m╰──────────────────────────────────────────────────────────╯"
    },

    "break",
    "colors"
  ]
}
EOF

print -P "%F{green}Done.%f Restart kitty or press Ctrl+Shift+F5, then run: %F{cyan}fastfetch%f"
