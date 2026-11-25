-- WoW Retail (Midnight) against the same files. The suite's client, with nothing
-- set, stands in for WoW: Forever. A test that wants Retail sets the project
-- and the interface number before the files load.

local stub = require("stub")

local function asRetail()
    _G.WOW_PROJECT_MAINLINE = 1
    _G.WOW_PROJECT_ID = 1
    _G.GetBuildInfo = function() return "12.1.5", "120105", "Nov 3 2026", 120105 end
end

T.test("client: nothing set is WoW: Forever, the client these tests stand in for", function()
    local DUI = stub.Load()
    T.truthy(DUI.Client.Forever())
    T.falsy(DUI.Client.Retail())
    T.truthy(DUI.Client.Modern())
    stub.units.party1 = { name = "Bone", lastName = "Money", isPlayer = true }
    T.eq(DUI.UnitName("party1"), "Bone Money", "a surname, not a realm")
end)

T.test("client: Midnight is Retail, and a realm is not a surname", function()
    local DUI = stub.Load({ before = asRetail })
    T.truthy(DUI.Client.Retail())
    T.falsy(DUI.Client.Forever())
    stub.units.party1 = { name = "Bone", lastName = "Stormrage", isPlayer = true }
    T.eq(DUI.UnitName("party1"), "Bone", "the second name is the realm")
    -- An early Forever build reported the retail project id. The interface number still says Forever.
    _G.GetBuildInfo = function() return "1.60.1", "16001", "", 16001 end
    T.truthy(DUI.Client.Forever(), "interface 16001 is Forever even when the project id is retail's")
    T.falsy(DUI.Client.Retail())
end)

T.test("quests: the Wowhead link is Retail's on Retail and Forever's on Forever", function()
    local DUI = stub.Load({ quests = true, before = asRetail })
    T.eq(stub.quests.Clicks.WowheadBase(), "https://www.wowhead.com/quest=")
    DUI = stub.Load({ quests = true })
    T.eq(stub.quests.Clicks.WowheadBase(), "https://www.wowhead.com/forever/quest=")
end)

T.test("cooldown card: Retail offers a proc glow, Forever does not", function()
    local function row(AB, key)
        for _, r in ipairs(AB.CdmCard.ROWS.show) do
            if r.item and r.item.key == key then return r end
        end
    end
    stub.Load({ actionbars = true, before = asRetail })
    T.truthy(row(stub.actionbars, "cdm.card.glow"), "Glow on proc")
    T.truthy(row(stub.actionbars, "cdm.card.glowColor"))
    stub.Load({ actionbars = true })
    T.isnil(row(stub.actionbars, "cdm.card.glow"), "Forever fires no spell alerts")
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
    local DUI = stub.Load({ before = asRetail })
    local DT = DUI.DamageText
    T.eq(DT.CVar("size"), "WorldTextScale")
    T.eq(DT.Has("size"), true)
    DUI:Set("general", "damage.size", 1.4)
    stub.RunTimers()
    T.near(tonumber(cvars.WorldTextScale), 1.4, 0.001)
    T.isnil(cvars.WorldTextScale_v2, "Forever's name is not invented")
    _G.GetCVar, _G.SetCVar = nil, nil
    if _G.C_CVar then _G.C_CVar.GetCVarDefault = nil end
end)

T.test("talents: Retail measures the tree's own spacing instead of the classic 600 grid", function()
    local DUI = stub.Load({ before = asRetail })
    _G.C_ClassTalents = { GetActiveConfigID = function() return 5 end }
    _G.C_Spell = { GetSpellName = function() return "Fireball" end, GetSpellTexture = function() return 1, 1 end }
    _G.C_Traits = {
        GetConfigInfo = function() return { treeIDs = { 9 } } end,
        GetStagedChanges = function() return {}, {}, {} end,
        GetTreeNodes = function() return { 1, 2 } end,
        GetNodeInfo = function(_, id)
            -- Far off the classic 600 grid on both axes, so the measured step
            -- is the tree's own gap and the node still lands on the board.
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
        T.eq(#d.trees[1].nodes, 2, "a node ten classic tiles out still fits")
        T.eq(d.trees[1].nodes[1].col, 0)
        T.eq(d.trees[1].nodes[2].col, 1)
    end)
    _G.C_Traits, _G.C_ClassTalents, _G.C_Spell = nil, nil, nil
    if not ok then error(err, 0) end
end)
