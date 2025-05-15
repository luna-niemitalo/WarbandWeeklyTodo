---@diagnostic disable: undefined-global
local AceGUI = LibStub("AceGUI-3.0")

-- Define column widths
local COLUMN_WIDTHS = {
    CHARACTER = 80,
    CURRENCY = 25,
    QUEST = 25,
    DELVE = 80,
    ITEM_SLOT = 25
}

local CATEGORY_ICONS_2 = {
    NONE = "|TInterface\\Icons\\INV_Misc_QuestionMark:0:0:0:0:64:64:4:60:4:60|t",
    POTATO = "|TInterface\\Icons\\INV_Cooking_80_BrownPotato:0:0:0:0:64:64:4:60:4:60|t",
    TIER1 = "|A:Professions-ChatIcon-Quality-Tier1:0:0|a",
    TIER2 = "|A:Professions-ChatIcon-Quality-Tier2:0:0|a",
    TIER3 = "|A:Professions-ChatIcon-Quality-Tier3:0:0|a",
    TIER4 = "|A:Professions-ChatIcon-Quality-Tier4:0:0|a",
    TIER5 = "|A:Professions-ChatIcon-Quality-Tier5:0:0|a",
    }

-- Define slot headers at module level
local SLOT_HEADERS = {
    { id = 1, short = "Hed", full = "Head" },
    { id = 2, short = "Nek", full = "Neck" },
    { id = 3, short = "Shl", full = "Shoulder" },
    { id = 5, short = "Cst", full = "Chest" },
    { id = 6, short = "Wst", full = "Waist" },
    { id = 7, short = "Lgs", full = "Legs" },
    { id = 8, short = "Fet", full = "Feet" },
    { id = 9, short = "Wrs", full = "Wrist" },
    { id = 10, short = "Hnd", full = "Hands" },
    { id = 11, short = "Fg1", full = "Finger1" },
    { id = 12, short = "Fg2", full = "Finger2" },
    { id = 13, short = "Tr1", full = "Trinket1" },
    { id = 14, short = "Tr2", full = "Trinket2" },
    { id = 15, short = "Bck", full = "Back" },
    { id = 16, short = "Mh", full = "MainHand" },
    { id = 17, short = "Oh", full = "OffHand" },
    { id = 18, short = "Rng", full = "Ranged" }
}

-- Store the active window reference
local activeWindow = nil

_G.WWWindow = {
    -- Add new function to get category icon based on item level
    GetCategoryIcon = function(itemLevel)
        if not itemLevel then return CATEGORY_ICONS_2.NONE end
        
        -- Using the thresholds from the provided code
        if itemLevel >= 671 then
            return CATEGORY_ICONS_2.TIER5
        elseif itemLevel >= 658 then
            return CATEGORY_ICONS_2.TIER4
        elseif itemLevel >= 645 then
            return CATEGORY_ICONS_2.TIER3
        elseif itemLevel >= 632 then
            return CATEGORY_ICONS_2.TIER2
        elseif itemLevel >= 623 then
            return CATEGORY_ICONS_2.TIER1
        else
            return CATEGORY_ICONS_2.POTATO
        end
    end,
    GetUpgrade = function(itemLevel, currencies)
        if not itemLevel or not currencies then return false end

        -- Check if currencies exist
        local weatheredCount = currencies[3107] and currencies[3107].quantity or 0
        local carvedCount = currencies[3108] and currencies[3108].quantity or 0
        local runedCount = currencies[3109] and currencies[3109].quantity or 0
        local gildedCount = currencies[3110] and currencies[3110].quantity or 0

        -- Check based on item level ranges
        if itemLevel >= 658 and itemLevel < 671 and gildedCount >= 15 then
            return true
        elseif itemLevel >= 645 and itemLevel < 658 and runedCount >= 10 then
            return true
        elseif itemLevel >= 632 and itemLevel < 645 and carvedCount >= 10 then
            return true
        elseif itemLevel >= 623 and itemLevel < 632 and weatheredCount >= 10 then
            return true
        end

        return false
    end,


    CreateHeaderRow = function(currencyIDs, questIDs)
        local headerGroup = AceGUI:Create("SimpleGroup")
        if not headerGroup then
            print("Error: Failed to create header group")
            return nil
        end
        headerGroup:SetFullWidth(true)
        headerGroup:SetLayout("Flow")

        -- Character name header
        local nameHeader = AceGUI:Create("Label")
        if not nameHeader then
            print("Error: Failed to create name header")
            return nil
        end
        nameHeader:SetText("Character")
        nameHeader:SetWidth(COLUMN_WIDTHS.CHARACTER)
        headerGroup:AddChild(nameHeader)

        -- Currency headers
        for _, id in ipairs(currencyIDs) do
            local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
            local label = AceGUI:Create("Label")
            if not label then
                print("Error: Failed to create currency label for ID:", id)
                return nil
            end
            -- Show only the currency icon
            local iconText = info and info.iconFileID and "|T" .. info.iconFileID .. ":20:20:0:0:64:64:4:60:4:60|t" or "?"
            label:SetText(iconText)
            label:SetWidth(COLUMN_WIDTHS.CURRENCY)
            headerGroup:AddChild(label)
        end

        -- Quest headers
        for _, qid in ipairs(questIDs) do
            local questLabel = AceGUI:Create("Label")
            if not questLabel then
                print("Error: Failed to create quest label for ID:", qid)
                return nil
            end
            if qid == 76586 then
                questLabel:SetImage("Interface\\Icons\\inv_radiant_remnant")
            end
            if qid == 83333 then
                questLabel:SetImage("Interface\\Icons\\inv_10_engineering_manufacturedparts_gear_uprez")
            end

            questLabel:SetWidth(COLUMN_WIDTHS.QUEST)
            headerGroup:AddChild(questLabel)
        end

        -- Delve rewards header
        local delveHeader = AceGUI:Create("Label")
        if not delveHeader then
            print("Error: Failed to create delve header")
            return nil
        end
        delveHeader:SetText("Delve Rewards")
        delveHeader:SetWidth(COLUMN_WIDTHS.DELVE)
        headerGroup:AddChild(delveHeader)

        -- Item slot headers (excluding shirt and tabard)
        for _, slotInfo in ipairs(SLOT_HEADERS) do
            local slotLabel = AceGUI:Create("Label")
            if not slotLabel then
                print("Error: Failed to create slot label for:", slotInfo.short)
                return nil
            end
            slotLabel:SetText(slotInfo.short)
            slotLabel:SetWidth(COLUMN_WIDTHS.ITEM_SLOT)
            headerGroup:AddChild(slotLabel)
        end

        return headerGroup
    end,

    CreateCharacterRow = function(key, data, currencyIDs, questIDs, delveIcons)
        local rowGroup = AceGUI:Create("SimpleGroup")
        if not rowGroup then
            print("Error: Failed to create row group for character:", key)
            return nil
        end
        rowGroup:SetFullWidth(true)
        rowGroup:SetLayout("Flow")

        -- Character name
        local realm, name = string.match(key, "(.*) %- (.*)")
        local charLabel = AceGUI:Create("Label")
        if not charLabel then
            print("Error: Failed to create character label for:", key)
            return nil
        end
        charLabel:SetText(name)
        charLabel:SetWidth(COLUMN_WIDTHS.CHARACTER)
        rowGroup:AddChild(charLabel)

        -- Currency values
        for _, id in ipairs(currencyIDs) do
            local cur = data.currencies and data.currencies[id]
            local label = AceGUI:Create("Label")
            if not label then
                print("Error: Failed to create currency value label for ID:", id)
                return nil
            end
            label:SetText(cur and cur.quantity or "?")
            label:SetWidth(COLUMN_WIDTHS.CURRENCY)
            rowGroup:AddChild(label)
        end

        -- Quest completion status
        for _, qid in ipairs(questIDs) do
            local questLabel = AceGUI:Create("Label")
            if not questLabel then
                print("Error: Failed to create quest status label for ID:", qid)
                return nil
            end
            local completed = data.quests and data.quests[qid]
            questLabel:SetText(completed and "OK" or "X")
            questLabel:SetWidth(COLUMN_WIDTHS.QUEST)
            rowGroup:AddChild(questLabel)
        end

        -- Delve rewards
        local delveLabel = AceGUI:Create("Label")
        if not delveLabel then
            print("Error: Failed to create delve rewards label")
            return nil
        end
        local delveText = ""

        if data.delveRewards then
            for i = 1, 3 do
                if data.delveRewards[i] and data.delveRewards[i].hasReward then
                    delveText = delveText .. _G.WWWindow.GetDelveQualityIcon(data.delveRewards[i].level, delveIcons)
                else
                    delveText = delveText .. delveIcons.none
                end
            end
        else
            delveText = delveIcons.none .. delveIcons.none .. delveIcons.none
        end

        delveLabel:SetText(delveText)
        delveLabel:SetWidth(COLUMN_WIDTHS.DELVE)
        rowGroup:AddChild(delveLabel)

        -- Item slot status
        for _, slotInfo in ipairs(SLOT_HEADERS) do
            local slotLabel = AceGUI:Create("Label")
            if not slotLabel then
                print("Error: Failed to create slot status label for:", slotInfo.short)
                return nil
            end

            -- Get item level for this slot
            local itemLevel = ""
            -- Check if this slot has an upgradeable item
            local hasUpgrade = false
            if data.equipment and data.equipment[slotInfo.id] then
                local item = data.equipment[slotInfo.id]
                if item.itemLevel then
                    itemLevel = _G.WWWindow.GetCategoryIcon(item.itemLevel)
                    hasUpgrade = _G.WWWindow.GetUpgrade(item.itemLevel, data.currencies)
                end
            end




            -- Combine category icon and upgrade indicator
            local displayText = itemLevel
            if hasUpgrade then
                displayText = displayText .. " |TInterface\\Buttons\\Arrow-Up-Up:0:0:0:0:64:64:4:60:4:60|t"
            end
            -- Add padding for empty slots to maintain alignment
            if displayText == "" then
                displayText = CATEGORY_ICONS_2.NONE
            end
            slotLabel:SetText(displayText)
            slotLabel:SetWidth(COLUMN_WIDTHS.ITEM_SLOT)
            rowGroup:AddChild(slotLabel)
        end

        return rowGroup
    end,

    GetDelveQualityIcon = function(value, delveIcons)
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
    end,

    ShowWindow = function(addon, currencyIDs, questIDs, delveIcons)
        -- Check if AceGUI is properly loaded
        if not AceGUI then
            print("Error: AceGUI library not found")
            return
        end

        -- If a window already exists, bring it to front and return
        if activeWindow then
            activeWindow:Show()
            activeWindow:SetStatusText("Data across all characters")
            return
        end
        
        -- Create the main frame
        local frame = AceGUI:Create("Frame")
        if not frame then
            print("Error: Failed to create main frame")
            return
        end

        -- Store the window reference
        activeWindow = frame
        
        frame:SetTitle("Warband Weekly Todo - Data")
        frame:SetStatusText("Data across all characters")
        frame:SetLayout("Flow")
        frame:SetWidth(840)
        frame:SetHeight(400)

        -- Add header row
        local header = _G.WWWindow.CreateHeaderRow(currencyIDs, questIDs)
        if header then
            frame:AddChild(header)
        else
            print("Error: Failed to create header row")
        end

        -- Add character rows
        local characterCount = 0
        for key, data in pairs(addon.db.global.characters) do
            local row = _G.WWWindow.CreateCharacterRow(key, data, currencyIDs, questIDs, delveIcons)
            if row then
                frame:AddChild(row)
                characterCount = characterCount + 1
            else
                print("Error: Failed to create row for character:", key)
            end
        end

        -- Set up close callback to clear the window reference
        frame:SetCallback("OnClose", function(widget)
            AceGUI:Release(widget)
            activeWindow = nil
        end)
    end
}
