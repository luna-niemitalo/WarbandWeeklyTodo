---@diagnostic disable: undefined-global
--[[
Warband Weekly Todo: An Ace3-based addon.
Tracks specific currencies (IDs 3107 - 3110) across characters,
saving each currency's quantity and icon to a global DB.
Displays the data in a table with columns for each currency.
]]--

-- Create a new addon with AceConsole and AceEvent support.
local WarbandWeeklyTodo = LibStub("AceAddon-3.0"):NewAddon("WarbandWeeklyTodo", "AceConsole-3.0", "AceEvent-3.0")

print("WarbandWeeklyTodo addon loaded")

-- Define the currency IDs to track.
local currencyIDs = {3107, 3108, 3109, 3110, 3028}
-- Define the quest IDs to check for completion.
local questIDs = {83333, 76586, 91173}
-- Define icons for delve reward tiers
local delveIcons = {
    rank1 = "|A:Professions-ChatIcon-Quality-Tier1:20:20|a",
    rank2 = "|A:Professions-ChatIcon-Quality-Tier2:20:20|a",
    rank3 = "|A:Professions-ChatIcon-Quality-Tier3:20:20|a",
    rank4 = "|A:Professions-ChatIcon-Quality-Tier4:20:20|a",
    rank5 = "|A:Professions-ChatIcon-Quality-Tier5:20:20|a",
    none = "|A:xmarksthespot:20:20|a",
}

-- Define inventory slot names for better readability
local INVENTORY_SLOT_NAMES = {
    [1] = "Head",
    [2] = "Neck",
    [3] = "Shoulder",
    [4] = "Shirt",
    [5] = "Chest",
    [6] = "Waist",
    [7] = "Legs",
    [8] = "Feet",
    [9] = "Wrist",
    [10] = "Hands",
    [11] = "Finger1",
    [12] = "Finger2",
    [13] = "Trinket1",
    [14] = "Trinket2",
    [15] = "Back",
    [16] = "MainHand",
    [17] = "OffHand",
    [18] = "Ranged",
    [19] = "Tabard",
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

    -- Register chat command
    self:RegisterChatCommand("wwtodo", "ChatCommand")
end

-- Function to update character data
function WarbandWeeklyTodo:UpdateCharacterData()
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
                    local slotIndex = activity.index
                    if slotIndex >= 1 and slotIndex <= 3 then
                        delveRewards[slotIndex].hasReward = true
                        delveRewards[slotIndex].level = activity.level
                    end
                end
            end
        end
    end


    -- Store equipment data including item levels
    local equipment = {}


    for slotID, slotName in pairs(INVENTORY_SLOT_NAMES) do
        local itemLink = GetInventoryItemLink("player", slotID)
        if itemLink then
            local actualItemLevel = GetDetailedItemLevelInfo(itemLink)

            -- Store equipment data
            equipment[slotID] = {
                itemLevel = actualItemLevel,
                itemLink = itemLink
            }
        end
    end

    -- Save all data globally.
    self.db.global.characters[key] = {
        currencies = currencies,
        quests = quests,
        delveRewards = delveRewards,
        equipment = equipment,
    }

    self:Print("Updated data for " .. key)
end

function WarbandWeeklyTodo:OnPlayerLogin()
    -- Add a small delay to ensure all data is loaded
    C_Timer.After(1, function()
        self:UpdateCharacterData()
    end)
end

-- Main window creation function
function WarbandWeeklyTodo:ShowWindow()
    -- Update data before showing the window
    self:UpdateCharacterData()
    
    if _G.WWWindow then
        _G.WWWindow.ShowWindow(self, currencyIDs, questIDs, delveIcons)
    else
        print("Error: Window module not found")
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
    -- Additional enable code if needed
end
