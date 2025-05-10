---@diagnostic disable: undefined-global
local AceGUI = LibStub("AceGUI-3.0")

-- Define slot headers at module level
local SLOT_HEADERS = {
    [1] = "Hed", -- Head
    [2] = "Nek", -- Neck
    [3] = "Shl", -- Shoulder
    [5] = "Cst", -- Chest
    [6] = "Wst", -- Waist
    [7] = "Lgs", -- Legs
    [8] = "Fet", -- Feet
    [9] = "Wrs", -- Wrist
    [10] = "Hnd", -- Hands
    [11] = "Fg1", -- Finger1
    [12] = "Fg2", -- Finger2
    [13] = "Tr1", -- Trinket1
    [14] = "Tr2", -- Trinket2
    [15] = "Bck", -- Back
    [16] = "Mh", -- MainHand
    [17] = "Oh", -- OffHand
    [18] = "Rng" -- Ranged
}

-- Store the active window reference
local activeWindow = nil

_G.WWWindow = {
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
        nameHeader:SetWidth(80)
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
            label:SetWidth(30) -- Reduced width since we only show the icon
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

            questLabel:SetWidth(30)
            headerGroup:AddChild(questLabel)
        end

        -- Delve rewards header
        local delveHeader = AceGUI:Create("Label")
        if not delveHeader then
            print("Error: Failed to create delve header")
            return nil
        end
        delveHeader:SetText("Delve Rewards")
        delveHeader:SetWidth(90)
        headerGroup:AddChild(delveHeader)

        -- Item slot headers (excluding shirt and tabard)
        for slotID, slotName in pairs(SLOT_HEADERS) do
            local slotLabel = AceGUI:Create("Label")
            if not slotLabel then
                print("Error: Failed to create slot label for:", slotName)
                return nil
            end
            slotLabel:SetText(slotName)
            slotLabel:SetWidth(25) -- Reduced width for shorter names
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
        charLabel:SetWidth(80)
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
            label:SetWidth(30)
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
            questLabel:SetWidth(30)
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
        delveLabel:SetWidth(90)
        rowGroup:AddChild(delveLabel)

        -- Item slot status
        for slotID, slotName in pairs(SLOT_HEADERS) do
            local slotLabel = AceGUI:Create("Label")
            if not slotLabel then
                print("Error: Failed to create slot status label for:", slotName)
                return nil
            end

            -- Check if this slot has an upgradeable item
            local hasUpgrade = false
            if data.equipmentUpgrades and data.equipmentUpgrades.items then
                for _, item in ipairs(data.equipmentUpgrades.items) do
                    if item.slotName == slotName then
                        -- Check if we have enough crests for the upgrade
                        local hasEnoughCrests = true
                        if item.requiredCrest ~= "None" then
                            local crestCost = data.equipmentUpgrades.crestCosts[item.requiredCrest]
                            local currencyInfo = data.currencies[crestCost.currencyID]
                            if not currencyInfo or currencyInfo.quantity < crestCost.count then
                                hasEnoughCrests = false
                            end
                        end
                        if hasEnoughCrests then
                            hasUpgrade = true
                        end
                        break
                    end
                end
            end

            slotLabel:SetText(hasUpgrade and "^" or "")
            slotLabel:SetWidth(25) -- Reduced width for shorter names
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
        frame:SetWidth(920)
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
