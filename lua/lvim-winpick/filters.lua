-- lvim-winpick.filters: the window-eligibility pipeline.
-- Given the effective (config + per-call) options, return the list of windows on the current
-- tabpage that may be offered as pick targets. A window is eligible UNLESS a filter rejects
-- it: floating (when disallowed), an excluded 'buftype' / 'filetype', or the current window
-- (when `include_current` is off). `filter_func` is a final caller escape hatch.
--
---@module "lvim-winpick.filters"

local api = vim.api

local M = {}

--- Whether `win` is a floating window (has a non-empty `relative`).
---@param win integer
---@return boolean
local function is_floating(win)
    local ok, cfg = pcall(api.nvim_win_get_config, win)
    return ok and cfg.relative ~= nil and cfg.relative ~= ""
end

--- The eligible pick targets on the current tabpage under `opts`.
---@param opts table  effective options: { include_current, filters = { buftype, filetype, floating }, filter_func? }
---@return integer[]  window ids, in nvim window order
function M.eligible(opts)
    local filters = opts.filters or {}
    local deny_bt = {}
    for _, bt in ipairs(filters.buftype or {}) do
        deny_bt[bt] = true
    end
    local deny_ft = {}
    for _, ft in ipairs(filters.filetype or {}) do
        deny_ft[ft] = true
    end
    local allow_floating = filters.floating == true
    local current = api.nvim_get_current_win()

    local out = {}
    for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
        local keep = true
        if not opts.include_current and win == current then
            keep = false
        elseif not allow_floating and is_floating(win) then
            keep = false
        else
            local buf = api.nvim_win_get_buf(win)
            if deny_bt[vim.bo[buf].buftype] or deny_ft[vim.bo[buf].filetype] then
                keep = false
            end
        end
        if keep then
            out[#out + 1] = win
        end
    end

    -- Caller escape hatch: refine the list however it likes.
    if type(opts.filter_func) == "function" then
        local refined = opts.filter_func(out)
        if type(refined) == "table" then
            out = refined
        end
    end
    return out
end

return M
