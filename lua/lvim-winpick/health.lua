-- lvim-winpick: :checkhealth lvim-winpick.
-- Reports the things that make a window picker misbehave: the lvim-utils dependency (palette +
-- dim backdrop), an empty/duplicate assignment alphabet (would leave windows unpickable), and
-- the getcharstr keyboard path the modal wait depends on. Read-only.
--
---@module "lvim-winpick.health"

local config = require("lvim-winpick.config")

local M = {}

--- Report the hard dependency and the badge/backdrop building blocks.
---@param health table
local function check_deps(health)
    if pcall(require, "lvim-utils.colors") then
        health.ok("lvim-utils found (palette + dim backdrop)")
    else
        health.error("lvim-utils not found — badges and the dim backdrop are unavailable")
    end
end

--- Validate the assignment alphabet: non-empty and without duplicate letters (a duplicate
--- would make the second window carrying it unreachable).
---@param health table
local function check_chars(health)
    local chars = config.chars or ""
    if #chars == 0 then
        health.error("config.chars is empty — no window can be assigned a letter")
        return
    end
    local seen, dups = {}, {}
    for i = 1, #chars do
        local ch = chars:sub(i, i):lower()
        if seen[ch] then
            dups[#dups + 1] = ch
        end
        seen[ch] = true
    end
    if #dups == 0 then
        health.ok(("assignment alphabet OK (%d letters)"):format(#chars))
    else
        health.warn("duplicate letters in config.chars: " .. table.concat(dups, " "))
    end
end

--- Sanity-check the config value domains.
---@param health table
local function check_config(health)
    if config.hint_position == "center" or config.hint_position == "top_left" then
        health.ok(("hint_position = %q"):format(config.hint_position))
    else
        health.error(("hint_position = %q is invalid (center|top_left)"):format(tostring(config.hint_position)))
    end
    if type(config.dim_amount) ~= "number" or config.dim_amount < 0 or config.dim_amount > 1 then
        health.warn(("dim_amount = %s should be a number in 0..1"):format(tostring(config.dim_amount)))
    end
end

--- Entry point for `:checkhealth lvim-winpick`.
---@return nil
function M.check()
    local health = vim.health
    health.start("lvim-winpick")
    check_deps(health)
    check_config(health)
    check_chars(health)
    health.info("the pick prompt reads one key via getcharstr; <Esc>/<C-c> (or any unassigned key) cancels")
end

return M
