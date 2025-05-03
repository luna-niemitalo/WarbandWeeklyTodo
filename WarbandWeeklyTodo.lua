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
        print("Minimap icon clicked")
        WarbandWeeklyTodo:ShowWindow()
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Warband Weekly Todo")
        tooltip:AddLine("Click to view stored data")
    end,
}

function WarbandWeeklyTodo:OnInitialize()
    print("WarbandWeeklyTodo:OnInitialize")
    -- Create the AceDB database. Global table stores character data.
    self.db = LibStub("AceDB-3.0"):New("WarbandWeeklyTodoDB", defaults)

    -- Register for PLAYER_LOGIN event to update currency and quest data.
    self:RegisterEvent("PLAYER_LOGIN", "OnPlayerLogin")

    -- Register the minimap icon.
    self.icon = LibStub("LibDBIcon-1.0")
    self.icon:Register("WarbandWeeklyTodo", iconData, self.db.profile.minimap)

    -- Register chat command
    self:RegisterChatCommand("wwtodo", "ChatCommand")
    
    -- Debug print all available modules
    print("Available modules during initialization:")
    for name, module in self:IterateModules() do
        print("-", name)
    end
end

-- Function to update character data
function WarbandWeeklyTodo:UpdateCharacterData()
    print("WarbandWeeklyTodo:UpdateCharacterData")
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

    -- Save all data globally.
    self.db.global.characters[key] = {
        currencies = currencies,
        quests = quests,
        delveRewards = delveRewards
    }

    self:Print("Updated data for " .. key)
end

function WarbandWeeklyTodo:OnPlayerLogin()
    print("WarbandWeeklyTodo:OnPlayerLogin")
    self:UpdateCharacterData()
end

-- Main window creation function
function WarbandWeeklyTodo:ShowWindow()
    print("WarbandWeeklyTodo:ShowWindow called")
    
    -- Update data before showing the window
    self:UpdateCharacterData()
    
    -- Debug print all available modules
    print("Available modules:")
    for name, module in self:IterateModules() do
        print("-", name)
    end
    
    if _G.WWWindow then
        print("Window module found")
        _G.WWWindow.ShowWindow(self, currencyIDs, questIDs, delveIcons)
    else
        print("Error: Window module not found")
    end
end

-- Optional: Allow the minimap icon to be toggled via a chat command.
function WarbandWeeklyTodo:ChatCommand(input)
    print("ChatCommand called with input:", input)
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
    print("WarbandWeeklyTodo:OnEnable")
    -- Additional enable code if needed
end
