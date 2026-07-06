# lvim-winpick

Interactive **"which window?"** for the **lvim-tech** set — overlay a letter badge on every
eligible window, press one key, and get the chosen window. Primarily an API for other plugins
(open-in-window, [lvim-winmove](https://github.com/lvim-tech/lvim-winmove)'s swap), plus a
`:LvimWinPick` command.

The prompt is a single modal keystroke (`getcharstr`, no timers). While picking, the other
windows' content is muted through a shared dim backdrop so the badges carry the screen — and the
badges + backdrop are always torn down on every exit path.

[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](https://github.com/lvim-tech/lvim-winpick/blob/main/LICENSE)

## Requirements

Requires **Neovim >= 0.10** and [lvim-utils](https://github.com/lvim-tech/lvim-utils) (the palette
+ the dim backdrop).

## Installation

### lvim-installer (recommended)

```vim
:LvimInstaller plugins
```

lvim-installer installs plugins through Neovim's built-in `vim.pack`, so no external plugin manager
is needed.

### Native (vim.pack)

```lua
vim.pack.add({
    { src = "https://github.com/lvim-tech/lvim-utils" },
    { src = "https://github.com/lvim-tech/lvim-winpick" },
})
require("lvim-winpick").setup({})
```

`setup()` is optional (the defaults work) — call it to change options, bind the badge highlights,
or register `:LvimWinPick`.

## Usage

```lua
local winpick = require("lvim-winpick")

local win = winpick.pick() -- the chosen window id, or nil (cancel / no candidate)
if win then
    vim.api.nvim_set_current_win(win)
end

-- Per-call option overrides (merged over the config; filters merge key-wise):
winpick.pick({ include_current = true })
winpick.pick({ filters = { filetype = { "help" } } })
winpick.pick({
    filter_func = function(wins)
        return wins
    end,
}) -- final escape hatch

winpick.jump() -- pick and jump (what :LvimWinPick runs)
```

`pick()` returns immediately with the sole window when only one is eligible (`autoselect_one`), and
`nil` when none is. `<Esc>`, `<C-c>`, or any unassigned key cancels.

```vim
:LvimWinPick
```

## Default configuration

```lua
require("lvim-winpick").setup({
    chars = "fjdkslaghrueiwoqpvnc", -- assignment letters, in order of preference
    autoselect_one = true, -- one eligible window → return it with no prompt
    include_current = false, -- offer the current window as a target too
    hint_position = "center", -- "center" | "top_left"
    dim = true, -- mute the other windows while picking
    dim_amount = 0.55, -- backdrop mute fraction toward the editor bg (0..1)
    filters = {
        buftype = { "nofile", "prompt", "quickfix", "terminal" },
        filetype = {
            "lvim-ui-frame",
            "lvim-utils-ui",
            "lvim-lsp-outline",
            "lvim-dashboard",
            "neo-tree",
            "Fyler",
            "qf",
            "help",
        },
        floating = false, -- false = floating windows are never offered
    },
})
```

## Highlights

Self-themed from lvim-utils and overwritable by a colorscheme or your own `setup`:

- `LvimWinPickHint` — the badge (blue accent on a soft blue block).
- `LvimWinPickHintCurrent` — the current window's badge when `include_current` (yellow).

## Health

```vim
:checkhealth lvim-winpick
```

Reports the lvim-utils dependency, the config value domains, and a duplicate check on the
assignment alphabet.
