-- lvim-winpick.hints: the per-window letter badges.
-- Each candidate window gets one small NON-focusable float (a coloured block with the
-- assignment letter), positioned centre or top-left inside that window. These are pure
-- transient overlays — no navigation, no sectors (same class as the keys-helper hints), so
-- they are plain `nvim_open_win` floats, NOT surface panels. The caller blocks in
-- getcharstr right after `show()`, so an explicit redraw is required (getcharstr does not
-- pump one) — the caller owns that redraw.
--
---@module "lvim-winpick.hints"

local api = vim.api

local M = {}

-- Badge geometry: a 3×5 block reads as a solid coloured square with the letter centred.
local BADGE_W, BADGE_H = 5, 3

--- Compute the badge's (row, col) INSIDE `win` for the chosen position.
---@param win integer
---@param position "center"|"top_left"
---@return integer row, integer col
local function badge_pos(win, position)
    if position == "top_left" then
        return 0, 0
    end
    local w = api.nvim_win_get_width(win)
    local h = api.nvim_win_get_height(win)
    local row = math.max(0, math.floor(h / 2) - math.floor(BADGE_H / 2))
    local col = math.max(0, math.floor(w / 2) - math.floor(BADGE_W / 2))
    return row, col
end

---@class LvimWinPickBadge
---@field buf integer
---@field win integer

--- Open a badge float over each assignment. `assignments` is a list of
--- `{ win, char, current }`; `current` picks the yellow group.
---@param assignments { win: integer, char: string, current: boolean }[]
---@param opts { hint_position: "center"|"top_left" }
---@return LvimWinPickBadge[]
function M.show(assignments, opts)
    local badges = {}
    for _, a in ipairs(assignments) do
        if api.nvim_win_is_valid(a.win) then
            local letter = a.char:upper()
            local mid = "  " .. letter .. "  "
            local buf = api.nvim_create_buf(false, true)
            api.nvim_buf_set_lines(buf, 0, -1, false, { "     ", mid, "     " })
            vim.bo[buf].bufhidden = "wipe"
            local row, col = badge_pos(a.win, opts.hint_position)
            local ok, win = pcall(api.nvim_open_win, buf, false, {
                relative = "win",
                win = a.win,
                width = BADGE_W,
                height = BADGE_H,
                row = row,
                col = col,
                focusable = false,
                style = "minimal",
                noautocmd = true,
                zindex = 300,
            })
            if ok then
                local group = a.current and "LvimWinPickHintCurrent" or "LvimWinPickHint"
                api.nvim_set_option_value("winhighlight", ("Normal:%s,NormalNC:%s"):format(group, group), { win = win })
                badges[#badges + 1] = { buf = buf, win = win }
            else
                pcall(api.nvim_buf_delete, buf, { force = true })
            end
        end
    end
    return badges
end

--- Close every badge float (and wipe its scratch buffer).
---@param badges LvimWinPickBadge[]
function M.hide(badges)
    for _, b in ipairs(badges) do
        if b.win and api.nvim_win_is_valid(b.win) then
            pcall(api.nvim_win_close, b.win, true)
        end
        if b.buf and api.nvim_buf_is_valid(b.buf) then
            pcall(api.nvim_buf_delete, b.buf, { force = true })
        end
    end
end

return M
