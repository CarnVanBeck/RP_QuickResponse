-- A small stand-in for the WoW API, enough to load the addon and click through it offline.
-- Secure snippets (_onclick, _onshow, wrapped OnClick) really run, against the mock frames,
-- so the ring's secure behaviour in and out of combat can be checked.
local M = {}

M.inCombat = false
M.useKeyDown = false
M.posted = {}  -- macro texts the secure template ran
M.printed = {} -- addon chat output
M.bindings = {}

local Frame = {}
Frame.__index = function(self, key)
    local method = Frame[key]
    if method then
        return method
    end
    -- Child regions that Blizzard templates may or may not have: the addon checks for them.
    if key == "TitleText" or key == "Instructions" or key == "ScrollBar" then
        return nil
    end
    if type(key) == "string" and key:match("^%u") then
        return function() end -- a method not modelled is a no-op
    end
    return nil -- a plain field that was never set
end

local function new(kind, name, parent, template)
    local frame = setmetatable({
        kind = kind, name = name, parent = parent, template = template or "",
        attributes = {}, scripts = {}, hooks = {}, shown = true, children = {}, points = {},
        level = parent and (parent.level + 1) or 1,
    }, Frame)
    if parent then
        parent.children[#parent.children + 1] = frame
    end
    if name then
        _G[name] = frame
    end
    return frame
end

local function protected(frame)
    return frame.template:find("Secure", 1, true) ~= nil
end

local function guard(frame, what)
    if M.inCombat and protected(frame) and not M.inSnippet then
        error("blocked in combat: " .. what .. " on " .. tostring(frame.name or frame.kind), 3)
    end
end

-- Snippets run with the mock frame as `self` / `owner`.
local function RunSnippet(body, self, extra)
    local env = setmetatable({
        self = self, owner = extra and extra.owner, button = extra and extra.button,
        down = extra and extra.down, message = extra and extra.message,
        PlayerInCombat = function() return M.inCombat end,
    }, { __index = _G })
    local chunk = assert(loadstring(body))
    setfenv(chunk, env)
    local was = M.inSnippet
    M.inSnippet = true
    local a, b = chunk()
    M.inSnippet = was
    return a, b
end
M.RunSnippet = RunSnippet

function Frame:SetAttribute(key, value)
    guard(self, "SetAttribute")
    self.attributes[key] = value
end
function Frame:GetAttribute(key) return self.attributes[key] end
function Frame:SetFrameRef(label, frame) self.attributes["frameref-" .. label] = frame end
function Frame:GetFrameRef(label) return self.attributes["frameref-" .. label] end

function Frame:SetScript(event, fn) self.scripts[event] = fn; self.hooks[event] = nil end
function Frame:GetScript(event) return self.scripts[event] end
function Frame:HookScript(event, fn)
    self.hooks[event] = self.hooks[event] or {}
    table.insert(self.hooks[event], fn)
end
function Frame:Fire(event, ...)
    if self.scripts[event] then
        self.scripts[event](self, ...)
    end
    for _, fn in ipairs(self.hooks[event] or {}) do
        fn(self, ...)
    end
end

function Frame:IsShown() return self.shown end
function Frame:IsVisible()
    local frame = self
    while frame do
        if not frame.shown then
            return false
        end
        frame = frame.parent
    end
    return true
end
function Frame:Show()
    guard(self, "Show")
    if not self.shown then
        self.shown = true
        if self.attributes._onshow then RunSnippet(self.attributes._onshow, self) end
        local was = M.inSnippet
        M.inSnippet = false -- insecure hooks get no secure rights
        self:Fire("OnShow")
        M.inSnippet = was
    end
end
function Frame:Hide()
    guard(self, "Hide")
    if self.shown then
        self.shown = false
        if self.attributes._onhide then RunSnippet(self.attributes._onhide, self) end
        local was = M.inSnippet
        M.inSnippet = false
        self:Fire("OnHide")
        M.inSnippet = was
    end
end
function Frame:SetShown(on) if on then self:Show() else self:Hide() end end
function Frame:SetPoint(...) guard(self, "SetPoint"); self.points[#self.points + 1] = { ... } end
function Frame:ClearAllPoints() guard(self, "ClearAllPoints"); self.points = {} end
function Frame:SetSize(w, h) guard(self, "SetSize"); self.width, self.height = w, h end
function Frame:GetPoint() local p = self.points[1] or {} return p[1], p[2], p[3], p[4], p[5] end
function Frame:GetFrameLevel() return self.level end
function Frame:SetFrameLevel(level) self.level = level end
function Frame:GetFrameStrata() return "HIGH" end
function Frame:IsMouseOver() return self.mouseOver or false end
function Frame:SetText(text) self.text = text end
function Frame:GetText() return self.text or "" end
function Frame:GetUnboundedStringWidth() return #(self.text or "") * 6 end
function Frame:GetStringWidth() return #(self.text or "") * 6 end
function Frame:GetChecked() return self.checked end
function Frame:SetChecked(on) self.checked = on end
function Frame:GetVerticalScroll() return 0 end
function Frame:GetVerticalScrollRange() return 0 end
function Frame:GetHeight() return self.height or 0 end
function Frame:GetWidth() return self.width or 0 end
function Frame:GetCenter() return 0, 0 end
function Frame:GetEffectiveScale() return 1 end
function Frame:CreateTexture() return new("Texture", nil, self) end
function Frame:CreateFontString() return new("FontString", nil, self) end
function Frame:CreateMaskTexture() return new("MaskTexture", nil, self) end

-- A real click: PreClick, the wrapped pre snippet, the secure template's action, the post snippet,
-- PostClick, OnClick hooks. Mouse clicks send press and release, like a button registered for both.
function M.Click(frame, button)
    for _, down in ipairs({ true, false }) do
        frame:Fire("PreClick", button, down)
        local newButton, message
        if frame.wrap then
            newButton, message = RunSnippet(frame.wrap.pre, frame, { owner = frame.wrap.header, button = button, down = down })
        end
        local actsNow = (down and true or false) == M.useKeyDown
        if frame.template:find("SecureActionButtonTemplate", 1, true) and actsNow then
            local key = (newButton or button) == "LeftButton" and "type1" or "type2"
            if frame.attributes[key] == "macro" then
                M.posted[#M.posted + 1] = frame.attributes.macrotext
            end
        end
        if frame.template:find("SecureHandlerClickTemplate", 1, true) and not down then
            if frame.attributes._onclick then
                RunSnippet(frame.attributes._onclick, frame, { button = button, down = down })
            end
        end
        if frame.wrap and message ~= nil then
            RunSnippet(frame.wrap.post, frame, { owner = frame.wrap.header, message = message, button = button, down = down })
        end
        frame:Fire("PostClick", button, down)
        if not down then
            for _, fn in ipairs(frame.hooks.OnClick or {}) do fn(frame, button, down) end
            if frame.scripts.OnClick then frame.scripts.OnClick(frame, button, down) end
        end
    end
end

function M.PressBinding(key)
    local target = M.bindings[key]
    if target then
        M.Click(_G[target], "LeftButton")
    end
end

-- Globals ----------------------------------------------------------------------------------------

function M.Install(locale)
    M.roots, M.posted, M.printed, M.bindings, M.inCombat, M.useKeyDown = {}, {}, {}, {}, false, false
    _G.GetLocale = function() return locale or "enUS" end
    _G.CreateFrame = function(kind, name, parent, template) return new(kind, name, parent, template) end
    _G.UIParent = new("Frame", "UIParent")
    _G.Minimap = new("Frame", "Minimap", UIParent)
    _G.GameTooltip = new("GameTooltip", "GameTooltip", UIParent)
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) M.printed[#M.printed + 1] = text end }
    _G.InCombatLockdown = function() return M.inCombat end
    _G.GetCVarBool = function(name) return name == "ActionButtonUseKeyDown" and M.useKeyDown end
    _G.GetTime = function() return 1000 end
    _G.GetCursorPosition = function() return 0, 0 end
    _G.PlaySound = function() end
    _G.SOUNDKIT = {}
    _G.SetPortraitTexture = function() end
    _G.C_Timer = { NewTimer = function(_, fn) fn() return { Cancel = function() end } end }
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    _G.tinsert = table.insert
    _G.UISpecialFrames = {}
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Show = function() end
    _G.SlashCmdList = {}
    _G.YES, _G.NO = "Yes", "No"
    _G.RPQuickResponseDB = nil
    _G.SecureHandlerSetFrameRef = function(frame, label, ref) frame.attributes["frameref-" .. label] = ref end
    _G.SecureHandlerWrapScript = function(frame, _, header, pre, post)
        assert(not M.inCombat, "WrapScript in combat")
        frame.wrap = { header = header, pre = pre, post = post }
    end
    -- Bindings set from snippets.
    Frame.SetBindingClick = function(_, _, key, target) M.bindings[key] = target end
    Frame.ClearBindings = function() M.bindings = {} end
end

-- Loads the addon's files in .toc order, then fires ADDON_LOADED.
function M.LoadAddon(root, options)
    local ns = {}
    local toc = io.open(root .. "/RP_QuickResponse.toc"):read("*a")
    for file in toc:gmatch("\n([%w_/]+%.lua)") do
        local path = root .. "/" .. file
        if file == "IconData.lua" and options and options.iconData then
            path = options.iconData
        end
        assert(loadfile(path))("RP_QuickResponse", ns)
    end
    M.FireEvent("ADDON_LOADED", "RP_QuickResponse")
    return ns
end

-- The addon's own event frame is the first frame Core.lua creates: fire events at every frame.
function M.FireEvent(event, ...)
    local args = { ... }
    local function walk(frame)
        if frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, unpack(args)) end
        for _, child in ipairs(frame.children) do walk(child) end
    end
    for _, frame in ipairs(M.roots) do walk(frame) end
end

local originalNew = new
new = function(kind, name, parent, template)
    local frame = originalNew(kind, name, parent, template)
    if not parent then
        M.roots = M.roots or {}
        M.roots[#M.roots + 1] = frame
    end
    return frame
end

return M
