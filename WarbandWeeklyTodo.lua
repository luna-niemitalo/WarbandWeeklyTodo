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

    -- Define upgrade tracks based on War Within system
    local UPGRADE_TRACKS = {
        -- Explorer track
        { level = 597, track = "Explorer 1", crest = "None" },
        { level = 600, track = "Explorer 2", crest = "None" },
        { level = 603, track = "Explorer 3", crest = "None" },
        { level = 606, track = "Explorer 4", crest = "None" },
        -- Explorer/Adventurer overlap
        { level = 610, track = "Explorer 5, Adventurer 1", crest = "None" },
        { level = 613, track = "Explorer 6, Adventurer 2", crest = "None" },
        { level = 616, track = "Explorer 7, Adventurer 3", crest = "None" },
        { level = 619, track = "Explorer 8, Adventurer 4", crest = "None" },
        -- Adventurer/Veteran overlap
        { level = 623, track = "Adventurer 5, Veteran 1", crest = "Weathered" },
        { level = 626, track = "Adventurer 6, Veteran 2", crest = "Weathered" },
        { level = 629, track = "Adventurer 7, Veteran 3", crest = "Weathered" },
        { level = 632, track = "Adventurer 8, Veteran 4", crest = "Weathered" },
        -- Veteran/Champion overlap
        { level = 636, track = "Veteran 5, Champion 1", crest = "Carved" },
        { level = 639, track = "Veteran 6, Champion 2", crest = "Carved" },
        { level = 642, track = "Veteran 7, Champion 3", crest = "Carved" },
        { level = 645, track = "Veteran 8, Champion 4", crest = "Carved" },
        -- Champion/Hero overlap
        { level = 649, track = "Champion 5, Hero 1", crest = "Runed" },
        { level = 652, track = "Champion 6, Hero 2", crest = "Runed" },
        { level = 655, track = "Champion 7, Hero 3", crest = "Runed" },
        { level = 658, track = "Champion 8, Hero 4", crest = "Runed" },
        -- Hero/Myth overlap
        { level = 662, track = "Hero 5, Myth 1", crest = "Gilded" },
        { level = 665, track = "Hero 6, Myth 2", crest = "Gilded" },
        -- Myth track
        { level = 668, track = "Myth 3", crest = "Gilded" },
        { level = 672, track = "Myth 4", crest = "Gilded" },
        { level = 675, track = "Myth 5", crest = "Gilded" },
        { level = 678, track = "Myth 6", crest = "Gilded" }
    }

    -- Get equipment upgrade data
    local upgradeableItems = {}
    local crestCosts = {
        ["Weathered"] = { count = 0, currencyID = 3107 },
        ["Carved"] = { count = 0, currencyID = 3108 },
        ["Runed"] = { count = 0, currencyID = 3109 },
        ["Gilded"] = { count = 0, currencyID = 3110 }
    }

    for slotID, slotName in pairs(INVENTORY_SLOT_NAMES) do
        local itemLink = GetInventoryItemLink("player", slotID)
        if itemLink then
            local actualItemLevel = GetDetailedItemLevelInfo(itemLink)
            local canUpgrade = false
            
            if C_ItemUpgrade then
                local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID)
                if itemLocation and itemLocation:IsValid() then
                    canUpgrade = C_ItemUpgrade.CanUpgradeItem(itemLocation)
                end
            end

            if canUpgrade then
                -- Find the current and next upgrade tracks
                local currentTrack = nil
                local nextTrack = nil
                
                for i, track in ipairs(UPGRADE_TRACKS) do
                    if actualItemLevel == track.level then
                        currentTrack = track
                        if i < #UPGRADE_TRACKS then
                            nextTrack = UPGRADE_TRACKS[i + 1]
                        end
                        break
                    elseif actualItemLevel < track.level then
                        nextTrack = track
                        break
                    end
                end

                if nextTrack then
                    table.insert(upgradeableItems, {
                        slotName = slotName,
                        itemLink = itemLink,
                        currentLevel = actualItemLevel,
                        nextLevel = nextTrack.level,
                        requiredCrest = nextTrack.crest,
                        currentTrack = currentTrack and currentTrack.track or "Unknown",
                        nextTrack = nextTrack.track
                    })

                    -- Add to crest costs if needed
                    if nextTrack.crest ~= "None" then
                        crestCosts[nextTrack.crest].count = crestCosts[nextTrack.crest].count + 15
                    end
                end
            end
        end
    end

    -- Save all data globally.
    self.db.global.characters[key] = {
        currencies = currencies,
        quests = quests,
        delveRewards = delveRewards,
        equipmentUpgrades = {
            items = upgradeableItems,
            crestCosts = crestCosts
        }
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
