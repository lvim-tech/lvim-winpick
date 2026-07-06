-- lvim-winpick: the live configuration table.
-- Holds the defaults; setup() merges user overrides into it IN PLACE (via
-- lvim-utils.utils.merge), so every require("lvim-winpick.config") reader sees the effective
-- values. A per-call `pick(opts)` shallow-merges its own overrides on top for that one call
-- (filters merge key-wise), so a consumer can widen/narrow the eligible set without changing
-- the global config.
--
---@module "lvim-winpick.config"

---@class LvimWinPickFilters
---@field buftype  string[]  Excluded 'buftype' values (a window whose buffer has one is never offered)
---@field filetype string[]  Excluded 'filetype' values (lvim side panels + common trees seeded by default)
---@field floating boolean   When false (default) floating windows are excluded

---@class LvimWinPickConfig
---@field chars          string   Assignment letters, in order of preference (home-row first)
---@field autoselect_one boolean  With exactly one eligible window, return it immediately without any UI
---@field include_current boolean Offer the CURRENT window as a target too
---@field hint_position  "center"|"top_left"  Where the letter badge sits in each window
---@field dim            boolean  Dim the other windows while picking so the badges carry the screen
---@field dim_amount     number   Fraction the backdrop is muted toward the editor bg (0..1)
---@field filters        LvimWinPickFilters  Eligibility filters (merged with per-call overrides)

---@type LvimWinPickConfig
return {
    -- The letters assigned to windows, tried in this order. Home-row first so the common
    -- 2–4 window case is a single comfortable keystroke.
    chars = "fjdkslaghrueiwoqpvnc",
    -- Exactly one eligible window → return it with no prompt (the overwhelmingly common case
    -- for "open in another window" when only one other window exists).
    autoselect_one = true,
    -- Include the window you are IN as a pickable target. Off by default: "pick a window"
    -- usually means "a DIFFERENT window".
    include_current = false,
    -- Where the big letter badge is drawn inside each candidate window.
    hint_position = "center",
    -- Mute the non-badge content while picking (a backdrop) so the letters stand out. Uses
    -- lvim-utils.dim (the shared backdrop canon) — no custom dim groups.
    dim = true,
    dim_amount = 0.55,
    -- A window is eligible unless a filter rejects it. Seeded to skip the lvim side panels,
    -- common file trees, and non-file scratch/prompt/quickfix buffers.
    filters = {
        -- Deliberately NOT excluding "nofile": many pickable panels (a file tree, etc.) are
        -- nofile, and the specific lvim/side panels are excluded by `filetype` below instead.
        buftype = { "prompt", "quickfix", "terminal" },
        filetype = {
            "lvim-ui-frame",
            "lvim-utils-ui",
            "lvim-lsp-outline",
            "lvim-dashboard",
            "Fyler",
            "qf",
            "help",
        },
        floating = false,
    },
}
