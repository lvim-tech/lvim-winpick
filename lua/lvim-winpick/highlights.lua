-- lvim-winpick.highlights: the letter-badge highlight groups, self-themed from the palette.
-- Two groups, both the "soft coloured block" canon (accent fg on a 0.3 bg-tint of the same
-- accent), so a badge reads as a solid tinted square the eye lands on:
--   LvimWinPickHint        — the normal badge (blue).
--   LvimWinPickHintCurrent — the current window's badge when `include_current` (yellow).
-- build() must be a function so each call reads the live palette; bound via
-- lvim-utils.highlight.bind in init so the groups re-derive on ColorScheme / palette sync.
-- The backdrop dim uses lvim-utils.dim (no groups defined here).
--
---@module "lvim-winpick.highlights"

local c = require("lvim-utils.colors")
local hl = require("lvim-utils.highlight")

local M = {}

--- Blend an accent toward the editor bg — the shared "mtint" convention.
---@param accent string
---@param t number
---@return string
local function mtint(accent, t)
    return hl.blend(accent, c.bg, t)
end

--- The badge highlight groups from the live palette.
---@return table<string, table>
function M.build()
    return {
        LvimWinPickHint = { fg = c.blue, bg = mtint(c.blue, 0.3), bold = true },
        LvimWinPickHintCurrent = { fg = c.yellow, bg = mtint(c.yellow, 0.3), bold = true },
    }
end

return M
