--[[
Warband Weekly Todo: An Ace3-based addon.
Tracks specific currencies (IDs 3107 - 3110) across characters,
saving each currency’s quantity and icon to a global DB.
Displays the data in a table with columns for each currency.
]]--

-- Create a new addon with AceConsole and AceEvent support.
local WarbandWeeklyTodo = LibStub("AceAddon-3.0"):NewAddon("WarbandWeeklyTodo", "AceConsole-3.0", "AceEvent-3.0")

-- Define the currency IDs to track.
local currencyIDs = {3107, 3108, 3109, 3110, 3028}
-- Define the quest IDs to check for completion.
local questIDs = {83333, 76586}
-- Define icons for delve reward tiers
local delveIcons = {
    rank1 = "|A:Professions-ChatIcon-Quality-Tier1:20:20|a",
    rank2 = "|A:Professions-ChatIcon-Quality-Tier2:20:20|a",
    rank3 = "|A:Professions-ChatIcon-Quality-Tier3:20:20|a",
    rank4 = "|A:Professions-ChatIcon-Quality-Tier4:20:20|a",
    rank5 = "|A:Professions-ChatIcon-Quality-Tier5:20:20|a",
    none = "|A:xmarksthespot:20:20|a",
}

-- Default settings: global table for shared character data and profile for settings.
local defaults = {
    global = {
        characters = {}  -- Data shared across all characters.
    },
    profile = {
        minimap = {
            hide = false,
        }
    }
}

-- Icon configuration for LibDBIcon-1.0.
local iconData = {
    text = "WWTodo",
    icon = "Interface\\Icons\\INV_Misc_QuestionMark", -- Replace with your own icon if desired.
    OnClick = function(clickedframe, button)
        WarbandWeeklyTodo:ShowWindow()
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Warband Weekly Todo")
        tooltip:AddLine("Click to view stored data")
    end,
}

function WarbandWeeklyTodo:OnInitialize()
    -- Create the AceDB database. Global table stores character data.
    self.db = LibStub("AceDB-3.0"):New("WarbandWeeklyTodoDB", defaults)

    -- Register for PLAYER_LOGIN event to update currency and quest data.
    self:RegisterEvent("PLAYER_LOGIN", "OnPlayerLogin")

    -- Register the minimap icon.
    self.icon = LibStub("LibDBIcon-1.0")
    self.icon:Register("WarbandWeeklyTodo", iconData, self.db.profile.minimap)
end

function WarbandWeeklyTodo:OnPlayerLogin()
    -- Get a unique key for the character.
    local name = UnitName("player")
    local realm = GetRealmName()
    local key = realm .. " - " .. name

    -- Prepare a table to store currency data.
    local currencies = {}
    for _, id in ipairs(currencyIDs) do
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
        if info then
            currencies[id] = { quantity = info.quantity, icon = info.iconFileID, name = info.name }
        else
            currencies[id] = { quantity = 0, icon = "", name = "Unknown" }
        end
    end

    -- Prepare a table to store quest completion flags.
    local quests = {}
    for _, qid in ipairs(questIDs) do
        -- C_QuestLog.IsQuestFlaggedCompleted returns a boolean.
        quests[qid] = C_QuestLog.IsQuestFlaggedCompleted(qid) or false
    end

    -- Check for delve rewards from the Great Vault
    local delveRewards = {
        { level = 0, hasReward = false }, -- First slot (top 2 delves)
        { level = 0, hasReward = false }, -- Second slot (top 4 delves)
        { level = 0, hasReward = false }  -- Third slot (top 8 delves)
    }

    if C_WeeklyRewards then
        local activities = C_WeeklyRewards.GetActivities()
        if activities then
            for _, activity in pairs(activities) do
                if activity.type == 6 then  -- Type 6 corresponds to Delves
                    -- The index in the activities table corresponds to the reward slot
                    -- We need to map it to our delveRewards array (1-3)
                    local slotIndex = activity.index
                    if slotIndex >= 1 and slotIndex <= 3 then
                        delveRewards[slotIndex].hasReward = true
                        delveRewards[slotIndex].level = activity.level
                    end
                end
            end
        end
    end

    -- Save all data globally.
    self.db.global.characters[key] = {
        currencies = currencies,
        quests = quests,
        delveRewards = delveRewards
    }

    self:Print("Saved data for " .. key)
end

function display_value(value)
    if value == nil then
        return "?"
    else
        return tostring(value)
    end
end
-- Function to determine the quality icon for delve rewards
local function GetDelveQualityIcon(value)
    if value >= 8 then
        return delveIcons.rank5 -- Hero 3/6 and above
    elseif value == 7 then
        return delveIcons.rank4 -- Hero 1/6
    elseif value == 6 or value == 5 then
        return delveIcons.rank3 -- Champion 3/8 or 4/8
    elseif value == 4 or value == 3 then
        return delveIcons.rank2 -- Champion 1/8 or Veteran 2/8
    elseif value == 2 then
        return delveIcons.rank1 -- Veteran 1/8
    else
        return delveIcons.none
    end
end

-- Function to create and show a window with stored data in a table format.
function WarbandWeeklyTodo:ShowWindow()
    local AceGUI = LibStub("AceGUI-3.0")

    -- Create the main frame.
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Warband Weekly Todo - Data")
    frame:SetStatusText("Data across all characters")
    frame:SetLayout("Flow")
    frame:SetWidth(800)
    frame:SetHeight(400)

    -- Create a header row group.
    local headerGroup = AceGUI:Create("SimpleGroup")
    headerGroup:SetFullWidth(true)
    headerGroup:SetLayout("Flow")

    -- Header for the character name.
    local headerChar = AceGUI:Create("Label")
    headerChar:SetText("Character")
    headerChar:SetWidth(80)
    headerGroup:AddChild(headerChar)

    -- Create headers for each currency.
    for _, id in ipairs(currencyIDs) do
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id) or { name = tostring(id), icon = "" }
        local headerCur = AceGUI:Create("Label")
        headerCur:SetImage(info.iconFileID)
        headerCur:SetImageSize(20,20)
        headerCur:SetWidth(30)
        headerGroup:AddChild(headerCur)
    end

    -- Headers for quest columns using quest titles.
    for _, qid in ipairs(questIDs) do
        -- local questIDs = {83333, 76586}
        local questTitle = (C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid)) or tostring(qid)
        local questHeader = AceGUI:Create("Label")
        if qid == 76586 then
            questHeader:SetImage("Interface\\Icons\\inv_radiant_remnant")
        end
        if qid == 83333 then
            questHeader:SetImage("Interface\\Icons\\inv_10_engineering_manufacturedparts_gear_uprez")
        end
        questHeader:SetImageSize(20,20)
        questHeader:SetWidth(30)
        headerGroup:AddChild(questHeader)
    end

    -- Header for delve rewards
    local delveHeader = AceGUI:Create("Label")
    delveHeader:SetText("Delves")
    delveHeader:SetImageSize(20,20)
    delveHeader:SetWidth(90) -- Wider to accommodate three icons
    headerGroup:AddChild(delveHeader)

    frame:AddChild(headerGroup)

    -- Data Rows: one row per character.
    for key, data in pairs(self.db.global.characters) do
        local rowGroup = AceGUI:Create("SimpleGroup")
        rowGroup:SetFullWidth(true)
        rowGroup:SetLayout("Flow")

        -- Character name column.
        local charLabel = AceGUI:Create("Label")
        realm, name = string.match(key, "(.*) %- (.*)")
        charLabel:SetText(name)
        charLabel:SetWidth(80)
        rowGroup:AddChild(charLabel)

        -- Columns for each currency.
        for _, id in ipairs(currencyIDs) do
            local cur = data.currencies and data.currencies[id]
            local label = AceGUI:Create("Label")
            label:SetText(display_value((cur and cur.quantity or nil)))
            label:SetWidth(30)
            rowGroup:AddChild(label)
        end

        -- Quest cells.
        for _, qid in ipairs(questIDs) do
            local questLabel = AceGUI:Create("Label")
            -- Use a check mark for complete, cross for incomplete.
            local completed = data.quests and data.quests[qid]
            questLabel:SetText(completed and "OK" or "X")
            questLabel:SetWidth(30)
            rowGroup:AddChild(questLabel)
        end

        -- Delve reward cells - display all three slots
        local delveLabel = AceGUI:Create("Label")
        local delveText = ""

        -- Check if we're using the old or new data structure
        if data.delveRewards then
            -- New structure with three slots
            for i = 1, 3 do
                if data.delveRewards[i] and data.delveRewards[i].hasReward then
                    delveText = delveText .. GetDelveQualityIcon(data.delveRewards[i].level)
                else
                    delveText = delveText .. delveIcons.none
                end
            end
        else
            -- No delve data at all
            delveText = delveIcons.none .. delveIcons.none .. delveIcons.none
        end

        delveLabel:SetText(delveText)
        delveLabel:SetWidth(90) -- Wider to accommodate three icons
        rowGroup:AddChild(delveLabel)

        frame:AddChild(rowGroup)
    end
end

-- Optional: Allow the minimap icon to be toggled via a chat command.
function WarbandWeeklyTodo:ChatCommand(input)
    if input:trim() == "toggle" then
        local hidden = self.db.profile.minimap.hide
        self.db.profile.minimap.hide = not hidden
        if self.db.profile.minimap.hide then
            self.icon:Hide("WarbandWeeklyTodo")
        else
            self.icon:Show("WarbandWeeklyTodo")
        end
        self:Print("Minimap icon " .. (self.db.profile.minimap.hide and "hidden" or "shown"))
    else
        self:ShowWindow()
    end
end

function WarbandWeeklyTodo:OnEnable()
    self:RegisterChatCommand("wwtodo", "ChatCommand")
end
