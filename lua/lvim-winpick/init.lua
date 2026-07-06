-- lvim-winpick: interactive "which window?" — overlay a letter badge on every eligible
-- window, block on a single keystroke, and return the chosen window id. It is primarily an
-- API for other plugins (open-in-window, lvim-winmove's swap) plus a `:LvimWinPick` command.
--
-- The wait is a canonical modal `getcharstr()` block (the keys-helper pattern — no timers):
-- badges are drawn, the screen is redrawn once (getcharstr does not pump a redraw itself),
-- and one key resolves it. While picking, the other windows' content is muted through
-- lvim-utils.dim so the badges carry the screen; the backdrop and badges are always torn down
-- (pcall-guarded) before returning, on every exit path.
--
--   local win = require("lvim-winpick").pick()                 -- nil on cancel / none
--   require("lvim-winpick").pick({ include_current = true })   -- per-call option override
--   :LvimWinPick                                                -- pick and jump to it
--
---@module "lvim-winpick"

local api = vim.api
local config = require("lvim-winpick.config")
local filters = require("lvim-winpick.filters")
local hints = require("lvim-winpick.hints")
local highlights = require("lvim-winpick.highlights")
local colors = require("lvim-utils.colors")
local dim = require("lvim-utils.dim")
local hl = require("lvim-utils.highlight")
local merge = require("lvim-utils.utils").merge

local M = {}

---@type boolean  one-time setup (highlight bind, command) done
local registered = false

local ESC, CTRL_C = "\27", "\3"

--- Effective options for one pick: a deep copy of the live config with `opts` merged on top
--- (so filters merge key-wise and the global config is never mutated by a per-call override).
---@param opts table?
---@return table
local function resolve_opts(opts)
    local eff = vim.deepcopy(config)
    if opts then
        merge(eff, opts)
    end
    return eff
end

--- Turn eligible windows into `{ win, char, current }` assignments, capped at the alphabet.
---@param wins integer[]
---@param chars string
---@return { win: integer, char: string, current: boolean }[] assignments, table<string, integer> map
local function assign(wins, chars)
    local assignments, map = {}, {}
    local current = api.nvim_get_current_win()
    local n = math.min(#wins, #chars)
    for i = 1, n do
        local ch = chars:sub(i, i):lower()
        assignments[i] = { win = wins[i], char = ch, current = wins[i] == current }
        map[ch] = wins[i]
    end
    return assignments, map
end

--- Pick a window interactively. Returns the chosen window id, or nil when cancelled, when no
--- window is eligible, or (with a single candidate and `autoselect_one`) the sole window
--- WITHOUT any UI.
---@param opts table?  per-call overrides (same shape as the config; filters merge key-wise)
---@return integer? winid
function M.pick(opts)
    local eff = resolve_opts(opts)
    local wins = filters.eligible(eff)
    if #wins == 0 then
        return nil
    end
    if #wins == 1 and eff.autoselect_one then
        return wins[1]
    end

    local assignments, map = assign(wins, eff.chars)

    -- Backdrop: mute every window's content so the badges stand out. Suspend the per-window
    -- dim manager first so the two don't fight over the same windows.
    local dimmed = {}
    if eff.dim then
        dim.suspend(true)
        local ns = dim.build(colors.bg, eff.dim_amount)
        for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
            dim.set(w, ns)
            dimmed[#dimmed + 1] = w
        end
    end

    local badges = hints.show(assignments, { hint_position = eff.hint_position })
    -- getcharstr does not redraw — paint the badges + backdrop before blocking.
    vim.cmd("redraw")

    local chosen = nil
    local ok, ch = pcall(vim.fn.getcharstr)
    if ok and ch ~= ESC and ch ~= CTRL_C then
        chosen = map[ch:lower()] -- a non-assigned key resolves to nil → cancel
    end

    -- Teardown, always: badges first, then restore every dimmed window and resume the manager.
    hints.hide(badges)
    for _, w in ipairs(dimmed) do
        dim.set(w, 0)
    end
    if eff.dim then
        dim.suspend(false)
    end
    vim.cmd("redraw")

    if chosen and api.nvim_win_is_valid(chosen) then
        return chosen
    end
    return nil
end

--- Pick a window and jump to it (the `:LvimWinPick` command / a direct keymap).
---@param opts table?
---@return nil
function M.jump(opts)
    local win = M.pick(opts)
    if win then
        api.nvim_set_current_win(win)
    end
end

--- Merge user options into the live config, bind the self-theming badge groups and register
--- `:LvimWinPick`. Optional — the defaults work without it.
---@param opts LvimWinPickConfig?
---@return nil
function M.setup(opts)
    if opts then
        merge(config, opts)
    end
    if registered then
        return
    end
    registered = true

    hl.setup()
    hl.bind(highlights.build)

    api.nvim_create_user_command("LvimWinPick", function()
        M.jump()
    end, { desc = "lvim-winpick: pick a window and jump to it" })
end

return M
