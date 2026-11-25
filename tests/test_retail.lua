-- WoW Retail (Midnight). Daylight UI loads only on this client.

local stub = require("stub")

T.test("client: this addon is Retail-only", function()
    local DUI = stub.Load()
    T.truthy(DUI.Client.Retail())
    T.falsy(DUI.Client.Forever())
    T.truthy(DUI.Client.Modern())
    stub.units.party1 = { name = "Bone", lastName = "Stormrage", isPlayer = true }
    T.eq(DUI.UnitName("party1"), "Bone", "UnitFullName's second value is a realm, never joined")
end)

T.test("quests: Wowhead links use Retail's path", function()
    stub.Load({ quests = true })
    T.eq(stub.quests.Clicks.WowheadBase(), "https://www.wowhead.com/quest=")
end)

T.test("cooldown card: proc glow rows are offered", function()
    local function row(AB, key)
        for _, r in ipairs(AB.CdmCard.ROWS.show) do
            if r.item and r.item.key == key then return r end
        end
    end
    stub.Load({ actionbars = true })
    T.truthy(row(stub.actionbars, "cdm.card.glow"), "Glow on proc")
    T.truthy(row(stub.actionbars, "cdm.card.glowColor"))
end)

T.test("damage numbers: a client that only has the older CVar names writes those", function()
    local cvars = {
        WorldTextScale = "1",
        floatingCombatTextCombatDamageDirectionalScale = "0",
        floatingCombatTextCombatDamageDirectionalOffset = "1",
    }
    _G.GetCVar = function(k) return cvars[k] end
    _G.SetCVar = function(k, v) cvars[k] = tostring(v) end
    _G.C_CVar = _G.C_CVar or {}
    _G.C_CVar.GetCVarDefault = function(k) return cvars[k] end
    local DUI = stub.Load()
    local DT = DUI.DamageText
    T.eq(DT.CVar("size"), "WorldTextScale")
    T.eq(DT.Has("size"), true)
    DUI:Set("general", "damage.size", 1.4)
    stub.RunTimers()
    T.near(tonumber(cvars.WorldTextScale), 1.4, 0.001)
    T.isnil(cvars.WorldTextScale_v2, "the _v2 name is not invented when only the older one exists")
    _G.GetCVar, _G.SetCVar = nil, nil
    if _G.C_CVar then _G.C_CVar.GetCVarDefault = nil end
end)

T.test("talents: the tree's own spacing is measured instead of a fixed classic grid", function()
    local DUI = stub.Load()
    _G.C_ClassTalents = { GetActiveConfigID = function() return 5 end }
    _G.C_Spell = { GetSpellName = function() return "Fireball" end, GetSpellTexture = function() return 1, 1 end }
    _G.C_Traits = {
        GetConfigInfo = function() return { treeIDs = { 9 } } end,
        GetStagedChanges = function() return {}, {}, {} end,
        GetTreeNodes = function() return { 1, 2 } end,
        GetNodeInfo = function(_, id)
            local far = id == 2
            return { posX = far and 6000 or 0, posY = far and 6000 or 0, isVisible = true, entryIDs = { 100 + id },
                ranksPurchased = 0, maxRanks = 1, activeRank = 0, canPurchaseRank = true,
                meetsEdgeRequirements = true, visibleEdges = {}, conditionIDs = {}, groupIDs = {} }
        end,
        GetEntryInfo = function() return { definitionID = 1 } end,
        GetDefinitionInfo = function() return { spellID = 1 } end,
        GetTreeCurrencyInfo = function() return { { quantity = 1, traitCurrencyID = 1 } } end,
    }
    local ok, err = pcall(function()
        local d = DUI.Book.TalentData.Read()
        T.eq(#d.trees, 1, "one tree when the client has no classic display groups")
        T.eq(#d.trees[1].nodes, 2, "a node far off a classic tile still fits")
        T.eq(d.trees[1].nodes[1].col, 0)
        T.eq(d.trees[1].nodes[2].col, 1)
    end)
    _G.C_Traits, _G.C_ClassTalents, _G.C_Spell = nil, nil, nil
    if not ok then error(err, 0) end
end)

T.test("pet happiness: options stay hidden without the classic happiness API", function()
    local DUI = stub.Load({ module = true })
    local page = DUI.Options.GetPage("UnitFrames.pet")
    local seen = false
    for _, g in ipairs(page.groups) do
        for _, item in ipairs(g.items) do
            if item.key == "pet.happiness" then
                seen = true
                local hide = item.hidden
                T.truthy(type(hide) == "function" and hide(), "hidden while C_PetInfo.GetPetHappiness is missing")
            end
        end
    end
    T.truthy(seen, "the row is still in the page so a classic API can show it")
end)

T.test("pet happiness: no widget and no UNIT_HAPPINESS without the classic API", function()
    local _, ns = stub.Load({ module = true })
    T.falsy(ns.Happiness.Supported())
    T.isnil(ns.happiness, "the pet frame never creates one")
    T.isnil(ns.Happiness.Create(CreateFrame("Button")), "Create refuses without the API")
    T.eq(#stub.errors, 0, "no RegisterEvent of an unknown name")
end)

T.test("stable: Retail's StableFrame is the skinned window", function()
    stub.Load({ skins = true })
    local found
    for _, name in ipairs(stub.skins.Engine.WINDOWS) do
        if name == "StableFrame" then found = true end
        T.falsy(name == "PetStableFrame", "no Camelot stable frame")
    end
    T.truthy(found, "StableFrame is registered")
end)
