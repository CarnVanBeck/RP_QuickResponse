-- Translations by key.
-- Each language file calls ns.RegisterLocale("<id>", { KEY = "text", ... }).
-- ns.L.KEY returns the text in the client's language, falls back to English (enUS),
-- and as a last resort returns the key itself, so a missing word is visible but never breaks.
local _, ns = ...

local locales = {}

function ns.RegisterLocale(id, strings)
    locales[id] = strings
end

ns.L = setmetatable({}, {
    __index = function(_, key)
        local current = locales[GetLocale()]
        local text = current and current[key]
        if text == nil then
            local base = locales.enUS
            text = base and base[key]
        end
        if text == nil then
            text = key
        end
        return text
    end,
})
