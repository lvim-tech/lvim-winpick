-- Who may be picked, which letter they get, and what one keystroke resolves to.
--
-- The whole plugin is one blocking `getcharstr()`, which makes it testable without any
-- pretending: a key pushed into the typeahead buffer first is the key the block reads. So
-- `pick()` is exercised here end to end -- eligibility, letter assignment, the badge overlay
-- and the teardown -- rather than through its parts.

local winpick = require("lvim-winpick")
local filters = require("lvim-winpick.filters")
local hints = require("lvim-winpick.hints")
local config = require("lvim-winpick.config")

--- A tabpage holding `n` windows, the last one current. Returns them in the order
--- nvim_tabpage_list_wins reports, which is the order letters are assigned in.
---@param n integer
---@return integer[]
local function windows(n)
    vim.cmd("silent! only")
    for _ = 2, n do
        vim.cmd("vsplit")
    end
    return vim.api.nvim_tabpage_list_wins(0)
end

--- Push `key` into the typeahead, then pick: the blocking getcharstr reads it.
---@param key string
---@param opts table?
---@return integer|nil
local function pick_with(key, opts)
    vim.api.nvim_feedkeys(key, "t", false)
    return winpick.pick(opts)
end

describe("lvim-winpick: one keystroke resolves to one window")

it("the letters follow the configured order, over the eligible windows", function()
    local wins = windows(3)
    local current = vim.api.nvim_get_current_win()
    local eligible = vim.tbl_filter(function(w)
        return w ~= current
    end, wins)
    eq(2, #eligible, "precondition: the current window is not a target by default")

    -- config.chars starts "fjdksl…", so the first eligible window answers to f, the second to j.
    eq(eligible[1], pick_with("f"))
    eq(eligible[2], pick_with("j"))
end)

it("a key that was never assigned is a cancel, not a wrong window", function()
    windows(3)
    eq(nil, pick_with("z"))
end)

it("escape cancels", function()
    windows(3)
    eq(nil, pick_with("\27"))
    eq(nil, pick_with("\3"), "and so does CTRL-C")
end)

it("the current window becomes a target only when asked for", function()
    local wins = windows(3)
    local current = vim.api.nvim_get_current_win()
    eq(current, pick_with("f", { include_current = true }), "with it included, it is first in window order")
    eq(current, wins[1], "precondition for the line above: it is the first window listed")
end)

it("a per-call override does not leak into the live config", function()
    windows(2)
    local before = config.include_current
    pick_with("f", { include_current = true })
    eq(before, config.include_current, "pick(opts) merges onto a COPY of the config")
end)

it("a single eligible window is returned with no prompt at all", function()
    windows(2)
    -- Nothing is fed: autoselect_one must not reach getcharstr, or this would block forever.
    local wins = vim.api.nvim_tabpage_list_wins(0)
    local current = vim.api.nvim_get_current_win()
    local other = wins[1] == current and wins[2] or wins[1]
    eq(other, winpick.pick())
end)

it("no eligible window is nil, not a crash", function()
    vim.cmd("silent! only")
    eq(nil, winpick.pick(), "the only window is the current one, which is not a target")
end)

describe("lvim-winpick: who is eligible")

it("a floating window is excluded unless floats are allowed", function()
    windows(2)
    local buf = vim.api.nvim_create_buf(false, true)
    local float = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = 10,
        height = 3,
        row = 1,
        col = 1,
    })

    local without = filters.eligible({ include_current = true, filters = { floating = false } })
    local with = filters.eligible({ include_current = true, filters = { floating = true } })
    eq(false, vim.tbl_contains(without, float))
    eq(true, vim.tbl_contains(with, float))

    vim.api.nvim_win_close(float, true)
end)

it("an excluded buftype and an excluded filetype are both refused", function()
    windows(2)
    local wins = vim.api.nvim_tabpage_list_wins(0)
    local target = wins[1]

    vim.bo[vim.api.nvim_win_get_buf(target)].filetype = "lvim-winpick-spec-ft"
    local by_ft = filters.eligible({
        include_current = true,
        filters = { filetype = { "lvim-winpick-spec-ft" } },
    })
    eq(false, vim.tbl_contains(by_ft, target))

    vim.bo[vim.api.nvim_win_get_buf(target)].filetype = ""
    vim.bo[vim.api.nvim_win_get_buf(target)].buftype = "nofile"
    local by_bt = filters.eligible({ include_current = true, filters = { buftype = { "nofile" } } })
    eq(false, vim.tbl_contains(by_bt, target))
    vim.bo[vim.api.nvim_win_get_buf(target)].buftype = ""
end)

it("filter_func has the last word, and a non-list answer is ignored", function()
    windows(3)
    local all = filters.eligible({ include_current = true })
    truthy(#all >= 3)

    local one = filters.eligible({
        include_current = true,
        filter_func = function(wins)
            return { wins[1] }
        end,
    })
    eq({ all[1] }, one)

    local unchanged = filters.eligible({
        include_current = true,
        filter_func = function()
            return nil
        end,
    })
    eq(all, unchanged, "a filter_func that answers with nothing cannot empty the list")
end)

describe("lvim-winpick: the badge fits the window it sits in")

it("a badge is a 5x3 block with the letter centred and uppercased", function()
    local wins = windows(1)
    local badges = hints.show({ { win = wins[1], char = "f", current = false } }, { hint_position = "center" })
    eq(1, #badges)
    local lines = vim.api.nvim_buf_get_lines(badges[1].buf, 0, -1, false)
    eq({ "     ", "  F  ", "     " }, lines, "the letter is centred on the middle row, in upper case")
    local cfg = vim.api.nvim_win_get_config(badges[1].win)
    eq(5, cfg.width)
    eq(3, cfg.height)
    eq("win", cfg.relative, "a badge is positioned inside its own window, not on the editor")
    hints.hide(badges)
end)

it("a badge is clamped to a window narrower than itself", function()
    windows(2)
    local narrow = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_width(narrow, 3)
    eq(3, vim.api.nvim_win_get_width(narrow), "precondition: the window really is 3 columns")

    local badges = hints.show({ { win = narrow, char = "j", current = false } }, { hint_position = "center" })
    local lines = vim.api.nvim_buf_get_lines(badges[1].buf, 0, -1, false)
    eq({ "   ", " J ", "   " }, lines, "every row is exactly as wide as the badge, never wider")
    eq(3, vim.api.nvim_win_get_config(badges[1].win).width, "a badge may not spill past its window")
    hints.hide(badges)
end)

it("center and top_left put the badge in different places", function()
    local wins = windows(1)
    local centered = hints.show({ { win = wins[1], char = "f", current = false } }, { hint_position = "center" })
    local c = vim.api.nvim_win_get_config(centered[1].win)
    hints.hide(centered)

    local corner = hints.show({ { win = wins[1], char = "f", current = false } }, { hint_position = "top_left" })
    local t = vim.api.nvim_win_get_config(corner[1].win)
    hints.hide(corner)

    eq(0, t.row)
    eq(0, t.col)
    local width, height = vim.api.nvim_win_get_width(wins[1]), vim.api.nvim_win_get_height(wins[1])
    eq(math.max(0, math.floor(height / 2) - 1), c.row, "centred vertically on the window")
    eq(math.max(0, math.floor(width / 2) - 2), c.col, "centred horizontally on the window")
end)

it("hide closes every float and wipes every scratch buffer", function()
    local wins = windows(1)
    local badges = hints.show({ { win = wins[1], char = "f", current = false } }, { hint_position = "center" })
    hints.hide(badges)
    for _, b in ipairs(badges) do
        eq(false, vim.api.nvim_win_is_valid(b.win))
        eq(false, vim.api.nvim_buf_is_valid(b.buf))
    end
end)

it("a window that closed before the badges are drawn is skipped", function()
    windows(2)
    local doomed = vim.api.nvim_get_current_win()
    vim.cmd("close")
    eq(false, vim.api.nvim_win_is_valid(doomed), "precondition")
    eq({}, hints.show({ { win = doomed, char = "f", current = false } }, { hint_position = "center" }))
end)
