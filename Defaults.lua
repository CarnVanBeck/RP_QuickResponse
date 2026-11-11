-- The example categories a new player starts with, written in their language.
-- Each category has three lines; their words live in Locales/ under DEFAULT_<KEY>_<n>_SHORT/_FULL.
local _, ns = ...
local L = ns.L

local EXAMPLES = {
    { key = "GREETING", icon = "Spell_Holy_Renew" },
    { key = "FAREWELL", icon = "Ability_Rogue_Sprint" },
    { key = "SURPRISE", icon = "INV_Misc_QuestionMark" },
    { key = "CURSING", icon = "Ability_Warrior_BattleShout" },
}
local LINES_PER_EXAMPLE = 3

function ns.DefaultCategories()
    local categories = {}
    for _, example in ipairs(EXAMPLES) do
        local category = { name = L["DEFAULT_" .. example.key], icon = example.icon, entries = {} }
        for i = 1, LINES_PER_EXAMPLE do
            local key = "DEFAULT_" .. example.key .. "_" .. i
            category.entries[i] = { short = L[key .. "_SHORT"], full = L[key .. "_FULL"] }
        end
        categories[#categories + 1] = category
    end
    return categories
end
