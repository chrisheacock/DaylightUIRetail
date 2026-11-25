-- The professions book (system pack) and the stable (NPC pack). Each is
-- Engine.Window plus its own art. The spellbook, talents and profession window
-- have their own Daylight UI windows, so no skin here.

local _, ns = ...
local Engine = ns.Engine


-- A profession panel on the overview page (name, spells, skill bar): art
-- removed, row look, the Daylight font.
local function professionPanel(Kit, panel)
    if not Kit.ShellOf(panel) then
        Kit.Strip(panel)
        Kit.Shell(panel, "row")
    end
    for _, r in ipairs({ panel:GetRegions() }) do
        if Kit.Kind(r) == "FontString" then Kit.Font(r) end
    end
    -- The skill bar's expansion picker (Classic/Outland/... skill lines).
    -- Left alone: Retail uses it to switch expansions.
end

local function professionPanels(Kit, frame, depth)
    if type(frame) ~= "table" or not frame.GetChildren or depth > 6 then return end
    if frame.IsForbidden and frame:IsForbidden() then return end
    if Kit.Kind(frame.ProfessionName) == "FontString" and Kit.Kind(frame.Background) == "Texture" then
        professionPanel(Kit, frame)
        return
    end
    for _, c in ipairs({ frame:GetChildren() }) do professionPanels(Kit, c, depth + 1) end
end

-- The professions book: each profession panel gets the row look and the Daylight font.
-- Its skill bars are drawn their own way and left alone.
local PROFESSION_PANELS = { "PrimaryProfession1", "PrimaryProfession2",
                            "SecondaryProfession1", "SecondaryProfession2", "SecondaryProfession3" }
local barPaths = {}
for _, key in ipairs(PROFESSION_PANELS) do
    barPaths[#barPaths + 1] = ".ProfessionsContentFrame." .. key .. ".StatusBar"
end

Engine.Window({ key = "professionsbook", pack = "system", addon = "Blizzard_ProfessionsBook", frame = "ProfessionsBookFrame",
    watch = true, auto = { skip = barPaths },
    after = function(Kit, f) professionPanels(Kit, f.ProfessionsContentFrame, 0) end })

-- The game's profession window, for players who pick it over Daylight UI's (or
-- while Daylight UI's lends it out: the guild's crafters, an NPC's crafting). Too
-- much its own for the whole template: only its controls go through it (close,
-- scroll bars, dropdowns, search boxes), the rest by name. Its skill bars keep
-- their own look. Never walked while Daylight UI's window covers it, nor while
-- DaylightMogul's does.
local function professionsCovered()
    if DaylightUI.craftMogul == true then return true end
    local W = DaylightUI.Craft and DaylightUI.Craft.Window
    return type(W) == "table" and type(W.Covers) == "function" and W.Covers() == true
end

local professions = Engine.Window({ key = "professions", pack = "system", addon = "Blizzard_Professions", frame = "ProfessionsFrame",
    watch = true, auto = { controlsOnly = true, rows = false }, skip = professionsCovered,
    after = function(Kit, f)
        Kit.SideTab(f.ProfessionsOverviewTab, nil, Kit.SIDE_TAB_CROP)
        for i = 1, 7 do Kit.SideTab(f["Professions" .. i .. "Tab"], nil, Kit.SIDE_TAB_CROP) end
        professionPanels(Kit, f.BookPage, 0)
        local page = f.CraftingPage
        if type(page) == "table" then
            Kit.Strip(page)
            for _, key in ipairs({ "CreateButton", "CreateAllButton", "ViewGuildCraftersButton" }) do Kit.Button(page[key]) end
            local list = page.RecipeList
            if type(list) == "table" then
                Kit.Inset(list)
                Kit.Hide(list.BackgroundNineSlice)
            end
            local form = page.SchematicForm
            if type(form) == "table" then
                Kit.Inset(form)
                Kit.Hide(form.NineSlice)
                if type(form.OutputIcon) == "table" then Kit.Item(form.OutputIcon) end
            end
        end
    end })

-- The game re-checks its side tabs when a profession opens or a skill changes,
-- with the window already open.
local function professionsAgain()
    local f = _G.ProfessionsFrame
    if type(f) ~= "table" or not f:IsShown() or professionsCovered() then return end
    if professions.again then professions.again() else Engine.Try(professions) end
    ns.Kit.RepaintSoon()
end
DaylightUI.RegisterEvent("TRADE_SKILL_SHOW", professionsAgain)
DaylightUI.RegisterEvent("SKILL_LINES_CHANGED", professionsAgain)

-- The hunter's stable on Retail (Blizzard_StableUI): StableFrame with a pet
-- model, an active-pet footer, and a scrollable stabled list. Atlas chrome is
-- stripped; buttons and text take the Daylight look. Nothing hooks the game's
-- methods: EventRegistry and OnShow say when to repaint list rows.
local stableRowHooked = setmetatable({}, { __mode = "k" })

local function stableActiveButton(Kit, btn)
    if type(btn) ~= "table" then return end
    Kit.Hide(btn.Background)
    Kit.Hide(btn.Border)
    Kit.Hide(btn.Highlight)
    Kit.Item(btn)
    if btn.Lock then Kit.Light(btn.Lock, DaylightUI.Style.INK.LABEL) end
end

local function stableListRow(Kit, row)
    if type(row) ~= "table" then return end
    Kit.Hide(row.Background)
    Kit.Hide(row.Selected)
    Kit.Hide(row.Highlight)
    Kit.Row(row, "art", row.Selected, false)
    local portrait = row.Portrait
    if type(portrait) == "table" then Kit.Hide(portrait.Border) end
    Kit.Font(row.Name, DaylightUI.Style.SIZE.body)
    Kit.Light(row.Name, DaylightUI.Style.INK.TITLE)
    Kit.Font(row.Type, DaylightUI.Style.SIZE.small)
    Kit.Light(row.Type, DaylightUI.Style.INK.TEXT)
    if not stableRowHooked[row] and row.HookScript then
        stableRowHooked[row] = true
        row:HookScript("OnMouseUp", Kit.RepaintSoon)
    end
end

local function stableListRows(Kit, list)
    if type(list) ~= "table" then return end
    local box = list.ScrollBox
    if type(box) == "table" and box.ForEachFrame then
        Kit.EachRow(box, function(row) stableListRow(Kit, row) end, "stable")
    end
end

local function paintStable(Kit, f)
    local ink = DaylightUI.Style.INK
    Kit.Hide(f.Topper)
    Kit.Button(f.StableTogglePetButton)
    Kit.Button(f.ReleasePetButton)
    local scene = f.PetModelScene
    if type(scene) == "table" then
        Kit.Hide(scene.Background)
        Kit.Hide(scene.PetShadow)
        Kit.Strip(scene.Inset)
        Kit.Hide(scene.PetModelSceneShadow)
        local controls = scene.ControlFrame
        if type(controls) == "table" then
            for _, key in ipairs({ "zoomInButton", "zoomOutButton", "rotateLeftButton", "rotateRightButton", "resetButton" }) do
                Kit.IconButton(controls[key])
            end
        end
        local info = scene.PetInfo
        if type(info) == "table" then
            Kit.Font(info.Type, DaylightUI.Style.SIZE.body)
            Kit.Light(info.Type, ink.TEXT)
            Kit.Font(info.Exotic, DaylightUI.Style.SIZE.body)
            Kit.Light(info.Exotic, ink.LABEL)
            local box = info.NameBox
            if type(box) == "table" then
                Kit.Font(box.Name, DaylightUI.Style.SIZE.head)
                Kit.Light(box.Name, ink.TITLE)
                Kit.IconButton(box.EditButton)
            end
        end
        local abilities = scene.AbilitiesList
        if type(abilities) == "table" then
            Kit.Font(abilities.ListHeader, DaylightUI.Style.SIZE.small)
            Kit.Light(abilities.ListHeader, ink.LABEL)
        end
    end
    local active = f.ActivePetList
    if type(active) == "table" then
        Kit.Hide(active.ActivePetListBG)
        Kit.Hide(active.ActivePetListBGBar)
        Kit.Font(active.ListName, DaylightUI.Style.SIZE.body)
        Kit.Light(active.ListName, ink.LABEL)
        for _, btn in ipairs(active.PetButtons or {}) do stableActiveButton(Kit, btn) end
        stableActiveButton(Kit, active.BeastMasterSecondaryPetButton)
        if type(active.Divider) == "table" then Kit.Hide(active.Divider.Bar) end
    end
    local list = f.StabledPetList
    if type(list) == "table" then
        Kit.Hide(list.Backgroud)
        Kit.Strip(list.Inset)
        Kit.Font(list.ListName, DaylightUI.Style.SIZE.title)
        Kit.Light(list.ListName, ink.TITLE)
        if type(list.ListCounter) == "table" then
            Kit.Strip(list.ListCounter)
            Kit.Font(list.ListCounter.Count, DaylightUI.Style.SIZE.small)
            Kit.Light(list.ListCounter.Count, ink.TEXT)
        end
        local filter = list.FilterBar
        if type(filter) == "table" then
            Kit.Hide(filter.Background)
            Kit.EditBox(filter.SearchBox)
        end
        Kit.ScrollBar(list.ScrollBar)
        stableListRows(Kit, list)
    end
end

local stableWatched = false
local function watchStable(f)
    if stableWatched then return end
    stableWatched = true
    local function soon()
        local Kit = ns.Kit
        if type(f) ~= "table" or not (f.IsShown and f:IsShown()) then return end
        DaylightUI.SafeCall(stableListRows, Kit, f.StabledPetList)
        Kit.RepaintSoon()
    end
    f:HookScript("OnShow", soon)
    local R = _G.EventRegistry
    if type(R) == "table" and R.RegisterCallback then
        for _, e in ipairs({ "StableFrameMixin.PetSelected", "StableFrameMixin.PetSwapRequested" }) do
            DaylightUI.SafeCall(R.RegisterCallback, R, e, soon, "DaylightUI.stable")
        end
    end
    for _, e in ipairs({ "PET_STABLE_UPDATE", "PET_STABLE_SHOW" }) do
        DaylightUI.RegisterEvent(e, soon)
    end
end

Engine.Window({ key = "stable", pack = "npc", addon = "Blizzard_StableUI", frame = "StableFrame", watch = true,
    after = function(Kit, f)
        paintStable(Kit, f)
        watchStable(f)
    end })
