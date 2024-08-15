---@diagnostic disable: undefined-field, undefined-global
local FRAME_WIDTH = 400
local ROW_HEIGHT = 32   -- How tall is each row?
local MAX_ROWS = 10      -- How many rows can be shown at once?
local ROW_CONTAINER_MARGIN = 16
local TITLE_BAR_HEIGHT = 30
local TOP_BAR_HEIGHT = 120
local SEARCH_BAR_WIDTH = 150
local SEARCH_BAR_HEIGHT = 32
local MARGIN = 12

local showDebugOutput = false

OpenableBeGone = LibStub("AceAddon-3.0"):NewAddon("OpenableBeGone", "AceConsole-3.0", "AceEvent-3.0")
OpenableBeGone.buttonFrames = {}
OpenableBeGone.searching = ""
OpenableBeGone.searchResults = {}
OpenableBeGone.merchantShown = false
OpenableBeGone.adventureMapShown = false
OpenableBeGone.tooltip = CreateFrame("GameTooltip", "OpenableBeGoneTooltip", UIParent, "GameTooltipTemplate")
OpenableBeGone.allContainerItemIds = OpenableBeGoneAllContainerItemIds
--read all container itemids and store them in a table for accessibility
OpenableBeGone.allContainerItemIdsTable = {}
for index, value in ipairs(OpenableBeGone.allContainerItemIds) do
    OpenableBeGone.allContainerItemIdsTable[value] = true
end
OpenableBeGone.allContainerItemNames = OpenableBeGoneAllContainerItemNames
--read all container itemids and store them in a table for accessibility
OpenableBeGone.allLockedContainerItemIdsTable = {}
OpenableBeGone.allLockedContainerItemIds = OpenableBeGoneAllLockedContainerItemIds
for index, value in ipairs(OpenableBeGone.allLockedContainerItemIds) do
    OpenableBeGone.allLockedContainerItemIdsTable[value] = true
end

local dbVersion = "0.4"
-- declare defaults to be used in the DB
local defaults = {
    char = {}
}
defaults.char[dbVersion] = {
    minimap = {
        hide = false
    },
    blacklist = {},
    onlyOpenAfterCombat = true,
    notifyInChat = false,
    dontOpenLocked = true
}

function OpenableBeGone:OnInitialize()
    -- Code that you want to run when the addon is first loaded goes here.
    OpenableBeGone:Print("DB Version: ", dbVersion)
    OpenableBeGone.db = LibStub("AceDB-3.0"):New("OpenableBeGoneDB", defaults, true)
    --LibStub("AceConfig-3.0"):RegisterOptionsTable("OpenableBeGone", options, {"OpenableBeGone", "aoa"})
    OpenableBeGone:RegisterChatCommand("OpenableBeGone", "SlashProcessorFunc")
    OpenableBeGone:RegisterChatCommand("obg", "SlashProcessorFunc")
    OpenableBeGone:RegisterEvent("BAG_UPDATE_DELAYED")
    OpenableBeGone:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- OpenableBeGone:RegisterEvent("MERCHANT_SHOW")
    -- OpenableBeGone:RegisterEvent("MERCHANT_CLOSED")
    OpenableBeGone:RegisterEvent("ADVENTURE_MAP_OPEN")
    OpenableBeGone:RegisterEvent("ADVENTURE_MAP_CLOSE")

    local OpenableBeGoneLDB = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("OpenableBeGone", {
        type = "launcher",
        icon = "Interface\\Icons\\Inv_misc_treasurechest04b",
        OnClick = function(clickedframe, button)
            --DEFAULT_CHAT_FRAME:AddMessage("Minimap icon clicked")
            if IsShiftKeyDown() then
                OpenableBeGone.db.char[dbVersion].minimap.hide = true
                OpenableBeGone:UpdateMinimapIcon()
                OpenableBeGone.MainFrameUpdate()
    		elseif OpenableBeGone.mainFrame and OpenableBeGone.mainFrame:IsShown() then
                OpenableBeGone.mainFrame:Hide()
            else
                OpenableBeGone.ShowMainFrame()
            end
        end,
        OnTooltipShow = function(tt)
            addonname = C_AddOns.GetAddOnMetadata(OpenableBeGone:GetName(), "Title")
            addonversion = C_AddOns.GetAddOnMetadata(OpenableBeGone:GetName(), "Version")
            tt:AddLine(addonname .. " - " .. addonversion, 1, 1, 1, 1)
            tt:AddLine(" ", 1, 1, 0.2, 1)
            tt:AddLine("Shift-click to hide minimap button", 1, 1, 0.2, 1)
            tt:AddLine("Console: /aoa /OpenableBeGone", 1, 1, 0.2, 1)
        end
    })
    LibStub("LibDBIcon-1.0"):Register("OpenableBeGone", OpenableBeGoneLDB, OpenableBeGone.db.char[dbVersion].minimap)
    OpenableBeGone:UpdateMinimapIcon()
end

function OpenableBeGone:UpdateMinimapIcon()
    if OpenableBeGone.db.char[dbVersion].minimap.hide then
        LibStub("LibDBIcon-1.0"):Hide(OpenableBeGone:GetName())
    else
        LibStub("LibDBIcon-1.0"):Show(OpenableBeGone:GetName())
    end
end

function OpenableBeGone:SlashProcessorFunc(input)
    -- Process the slash command ('input' contains whatever follows the slash command)
    if input == "debug" or input == "dbg" then
        showDebugOutput = not showDebugOutput
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 OpenableBeGone Debug output: "..tostring(showDebugOutput))
    else
        OpenableBeGone:ShowMainFrame()
    end
end

function OpenableBeGone:AutoOpenContainers()
    if (not UnitAffectingCombat("player") or not OpenableBeGone.db.char[dbVersion].onlyOpenAfterCombat)
    and not OpenableBeGone.merchantShown and not OpenableBeGone.adventureMapShown then
        --DEFAULT_CHAT_FRAME:AddMessage("OpenableBeGone:AutoOpenContainers()")
        for bag = 0, 4 do
            for slot = 0, C_Container.GetContainerNumSlots(bag) do
                local id = C_Container.GetContainerItemID(bag, slot)
                if id and OpenableBeGone.allContainerItemIdsTable[id] and OpenableBeGone.db.char[dbVersion].blacklist[id] == nil
                and (OpenableBeGone.allLockedContainerItemIdsTable[id] == nil or not OpenableBeGone.db.char[dbVersion].dontOpenLocked) then
                    C_Container.UseContainerItem(bag, slot)
                    if OpenableBeGone.db.char[dbVersion].notifyInChat or showDebugOutput then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Opening : " .. C_Container.GetContainerItemLink(bag, slot) .. " ID: " .. C_Container.GetContainerItemID(bag, slot))
                    end
                    return
                end
            end
        end
    else
        if showDebugOutput then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 OpenableBeGone - Skipping auto-open - inCombat: "..tostring(UnitAffectingCombat("player"))
            ..", merchantShown: "..tostring(OpenableBeGone.merchantShown)..", adventureMapShown: "..tostring(OpenableBeGone.adventureMapShown))
        end
    end
end

function OpenableBeGone:BAG_UPDATE_DELAYED(event, message)
    OpenableBeGone:AutoOpenContainers()
end

function OpenableBeGone:PLAYER_REGEN_ENABLED(event, message)
    OpenableBeGone:AutoOpenContainers()
end

function OpenableBeGone:MERCHANT_SHOW(event, message)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 OpenableBeGone Merchant now shown")
    end
    OpenableBeGone.merchantShown = true
end

function OpenableBeGone:MERCHANT_CLOSED(event, message)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 OpenableBeGone Merchant no longer shown")
    end
    OpenableBeGone.merchantShown = false
    OpenableBeGone:AutoOpenContainers()
end

function OpenableBeGone:ADVENTURE_MAP_OPEN(event, message)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 OpenableBeGone Mission table now shown")
    end
    OpenableBeGone.adventureMapShown = true
end

function OpenableBeGone:ADVENTURE_MAP_CLOSE(event, message)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 OpenableBeGone Mission table no longer shown")
    end
    OpenableBeGone.adventureMapShown = false
    OpenableBeGone:AutoOpenContainers()
end

function OpenableBeGone.ShowMainFrame()
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 OpenableBeGone Showing Main Window")
    end
    if OpenableBeGone.mainFrame then
        if OpenableBeGone.mainFrame:IsShown() then
            return
        end
        OpenableBeGone.mainFrame:Show()
        return
    end
    ----------------------------------------------------------------
    -- Create the frame:
    local frame = CreateFrame("Frame", "OpenableBeGoneMainFrame", UIParent, "BackdropTemplate")
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetSize(FRAME_WIDTH, ROW_HEIGHT * MAX_ROWS + ROW_CONTAINER_MARGIN + TOP_BAR_HEIGHT + TITLE_BAR_HEIGHT)
    -- Give the frame a visible background and border:
    frame:SetBackdrop({
        bgFile = "Interface\\achievementframe\\ui-achievement-statsbackground", tile = false, tileSize = 128,
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    -- Add the frame as a global variable under the name `OpenableBeGoneMainFrame`
    _G["OpenableBeGoneMainFrame"] = frame
    -- Register the global variable `OpenableBeGoneMainFrame` as a "special frame"
    -- so that it is closed when the escape key is pressed.
    tinsert(UISpecialFrames, "OpenableBeGoneMainFrame")

    OpenableBeGone.mainFrame = frame

    local titlebar = CreateFrame("Frame", "OpenableBeGoneTitleBar", frame, "BackdropTemplate")
    titlebar:SetSize(frame:GetWidth(), TITLE_BAR_HEIGHT)
    titlebar:SetPoint("TOPLEFT", 0, 0)
    -- Give the frame a visible background and border:
    titlebar:SetBackdrop({
        bgFile = "Interface\\paperdollinfoframe\\ui-gearmanager-title-background", tile = false, tileSize = 128,
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    local title = titlebar:CreateFontString(nil,"ARTWORK", "GameFontNormal") -- parentItemInfo
    title:SetWidth(titlebar:GetWidth() - MARGIN * 2 - 24)
    title:SetHeight(titlebar:GetHeight())
    title:SetJustifyH("LEFT")
    title:SetJustifyV("MIDDLE")
    title:SetPoint("TOPLEFT", MARGIN, 0)
    title:SetFont(GameFontNormal:GetFont(), 16)
    addonname = C_AddOns.GetAddOnMetadata(OpenableBeGone:GetName(), "Title")
    addonversion = C_AddOns.GetAddOnMetadata(OpenableBeGone:GetName(), "Version")
    title:SetText(addonname.." - "..addonversion)
    title:SetTextColor(1, 1, 0.2)

    local close = CreateFrame("Button", nil, titlebar, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 1)
    close:SetScript("OnClick", OpenableBeGone.OnClose)

    local search = CreateFrame("EditBox", "$parentSearch", frame, "InputBoxTemplate")
    frame.search = search
    search:SetWidth(SEARCH_BAR_WIDTH)
    search:SetHeight(SEARCH_BAR_HEIGHT)
    search:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", MARGIN + 6, -TITLE_BAR_HEIGHT - TOP_BAR_HEIGHT)
    search:SetAutoFocus(false)
    search:SetFontObject("ChatFontNormal")
    search:SetScript("OnTextChanged", OpenableBeGone.OnTextChanged)
    search:SetScript("OnEnterPressed", OpenableBeGone.OnEnterPressed)
    search:SetScript("OnEscapePressed", OpenableBeGone.OnEscapePressed)
    search:SetScript("OnEditFocusLost", OpenableBeGone.OnEditFocusLost)
    search:SetScript("OnEditFocusGained", OpenableBeGone.OnEditFocusGained)
    search:SetText(SEARCH)

    local lockedCheckboxFrame = CreateFrame("Button", "OpenableBeGoneLockedCheckboxFrame", frame)
    lockedCheckboxFrame:SetSize(frame:GetWidth() - SEARCH_BAR_WIDTH - 50, TITLE_BAR_HEIGHT)
    lockedCheckboxFrame:SetPoint("TOPRIGHT", 0, -TITLE_BAR_HEIGHT)
    lockedCheckboxFrame:SetScript("OnClick", OpenableBeGone.OnLockedCheckboxClick)

    local label = lockedCheckboxFrame:CreateFontString(nil, "ARTWORK", "GameTooltipText") --OpenableBeGoneCombatCheckboxFrame
    label:SetWidth(lockedCheckboxFrame:GetWidth() - MARGIN * 2 - 24)
    label:SetHeight(lockedCheckboxFrame:GetHeight())
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetPoint("TOPLEFT", MARGIN, 0)
    label:SetFont(GameFontNormal:GetFont(), 12)
    label:SetText("Ignore locked containers")
    label:SetTextColor(0, 0, 0)


    local checked = CreateFrame("CheckButton", "OpenableBeGoneLockedCheckbox", lockedCheckboxFrame, "ChatConfigCheckButtonTemplate") -- "InterfaceOptionsSmallCheckButtonTemplate"

    checked:SetScript("OnClick", OpenableBeGone.OnLockedCheckboxClick)
    checked:SetWidth(24)
    checked:SetHeight(24)
    checked:SetPoint("RIGHT", -MARGIN, 0)
    checked:SetHitRectInsets(0, 0, 0, 0)
    checked:SetChecked(OpenableBeGone.db.char[dbVersion].dontOpenLocked)
    OpenableBeGone.lockedCheckbox = checked

    local combatCheckboxFrame = CreateFrame("Button", "OpenableBeGoneCombatCheckboxFrame", frame)
    combatCheckboxFrame:SetSize(frame:GetWidth() - SEARCH_BAR_WIDTH - 50, TITLE_BAR_HEIGHT)
    combatCheckboxFrame:SetPoint("TOPRIGHT", 0, -TITLE_BAR_HEIGHT*2)
    combatCheckboxFrame:SetScript("OnClick", OpenableBeGone.OnCombatCheckboxClick)

    local label = combatCheckboxFrame:CreateFontString(nil, "ARTWORK", "GameTooltipText") --OpenableBeGoneCombatCheckboxFrame
    label:SetWidth(combatCheckboxFrame:GetWidth() - MARGIN * 2 - 24)
    label:SetHeight(combatCheckboxFrame:GetHeight())
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetPoint("TOPLEFT", MARGIN, 0)
    label:SetFont(GameFontNormal:GetFont(), 12)
    label:SetText("Only open after combat")
    label:SetTextColor(0, 0, 0)

    local checked = CreateFrame("CheckButton", "OpenableBeGoneCombatCheckbox", combatCheckboxFrame, "ChatConfigCheckButtonTemplate" ) --InterfaceOptionsSmallCheckButtonTemplate
    checked:SetScript("OnClick", OpenableBeGone.OnCombatCheckboxClick)
    checked:SetWidth(24)
    checked:SetHeight(24)
    checked:SetPoint("RIGHT", -MARGIN, 0)
    checked:SetHitRectInsets(0, 0, 0, 0)
    checked:SetChecked(OpenableBeGone.db.char[dbVersion].onlyOpenAfterCombat)
    OpenableBeGone.combatCheckbox = checked

    local notifyCheckboxFrame = CreateFrame("Button", "OpenableBeGoneNotifyCheckboxFrame", frame)
    notifyCheckboxFrame:SetSize(frame:GetWidth() - SEARCH_BAR_WIDTH - 50, TITLE_BAR_HEIGHT)
    notifyCheckboxFrame:SetPoint("TOPRIGHT", 0, -TITLE_BAR_HEIGHT*3)
    notifyCheckboxFrame:SetScript("OnClick", OpenableBeGone.OnNotifyCheckboxClick)

    local label = notifyCheckboxFrame:CreateFontString(nil, "ARTWORK", "GameTooltipText") --OpenableBeGoneNotifyCheckboxFrame
    label:SetWidth(notifyCheckboxFrame:GetWidth() - MARGIN * 2 - 24)
    label:SetHeight(notifyCheckboxFrame:GetHeight())
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetPoint("TOPLEFT", MARGIN, 0)
    label:SetFont(GameFontNormal:GetFont(), 12)
    label:SetText("Notify in chat")
    label:SetTextColor(0, 0, 0)
    local checked = CreateFrame("CheckButton", "OpenableBeGoneNotifyCheckbox", notifyCheckboxFrame, "ChatConfigCheckButtonTemplate") --InterfaceOptionsSmallCheckButtonTemplate
    checked:SetScript("OnClick", OpenableBeGone.OnNotifyCheckboxClick)
    checked:SetWidth(24)
    checked:SetHeight(24)
    checked:SetPoint("RIGHT", -MARGIN, 0)
    checked:SetHitRectInsets(0, 0, 0, 0)
    checked:SetChecked(OpenableBeGone.db.char[dbVersion].notifyInChat)
    OpenableBeGone.notifyCheckbox = checked

    local minimapCheckboxFrame = CreateFrame("Button", "OpenableBeGoneMinimapCheckboxFrame", frame)
    minimapCheckboxFrame:SetSize(frame:GetWidth() - SEARCH_BAR_WIDTH - 50, TITLE_BAR_HEIGHT)
    minimapCheckboxFrame:SetPoint("TOPRIGHT", 0, -TITLE_BAR_HEIGHT*4)
    minimapCheckboxFrame:SetScript("OnClick", OpenableBeGone.OnMinimapCheckboxClick)
    local label = minimapCheckboxFrame:CreateFontString(nil, "ARTWORK", "GameTooltipText") --OpenableBeGoneMinimapCheckboxFrame
    label:SetWidth(minimapCheckboxFrame:GetWidth() - MARGIN * 2 - 24)
    label:SetHeight(minimapCheckboxFrame:GetHeight())
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetPoint("TOPLEFT", MARGIN, 0)
    label:SetFont(GameFontNormal:GetFont(), 12)
    label:SetText("Show minimap icon")
    label:SetTextColor(0, 0, 0)
    local checked = CreateFrame("CheckButton", "OpenableBeGoneMinimapCheckbox", minimapCheckboxFrame, "ChatConfigCheckButtonTemplate") --InterfaceOptionsSmallCheckButtonTemplate
    checked:SetScript("OnClick", OpenableBeGone.OnMinimapCheckboxClick)
    checked:SetWidth(24)
    checked:SetHeight(24)
    checked:SetPoint("RIGHT", -MARGIN, 0)
    checked:SetHitRectInsets(0, 0, 0, 0)
    checked:SetChecked(not OpenableBeGone.db.char[dbVersion].minimap.hide)
    OpenableBeGone.minimapCheckbox = checked

    OpenableBeGone.scrollbar = CreateFrame("ScrollFrame", "OpenableBeGoneScrollFrame", frame, "FauxScrollFrameTemplate")
    OpenableBeGone.scrollbar:SetPoint("TOPLEFT", -1, -7 - TOP_BAR_HEIGHT - TITLE_BAR_HEIGHT)
    OpenableBeGone.scrollbar:SetPoint("BOTTOMRIGHT", -31, 8)
    OpenableBeGone.scrollbar:SetScript("OnShow", OpenableBeGone.xScrollFrame_OnShow)
    OpenableBeGone.scrollbar:SetScript("OnVerticalScroll", OpenableBeGone.xScrollFrame_OnVerticalScroll)

    local top = frame:CreateTexture("$parentTop", "ARTWORK")
    frame.top = top
    top:SetWidth(28)
    top:SetHeight(256)
    top:SetPoint("TOPRIGHT", -3, -3 - TOP_BAR_HEIGHT - TITLE_BAR_HEIGHT)
    top:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
    top:SetTexCoord(0, 0.484375, 0, 1)

    local bottom = frame:CreateTexture("$parentBottom", "ARTWORK")
    frame.bottom = bottom
    bottom:SetWidth(28)
    bottom:SetHeight(108)
    bottom:SetPoint("BOTTOMRIGHT", -3, 3)
    bottom:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
    bottom:SetTexCoord(0.515625, 1, 0, 0.421875)

    buttonGroup = CreateFrame("Frame", "OpenableBeGoneButtonGroup", frame, "BackdropTemplate")
    buttonGroup:EnableMouse(true)
    buttonGroup:SetMovable(true)
    buttonGroup:SetSize(frame:GetWidth(), ROW_HEIGHT * MAX_ROWS + ROW_CONTAINER_MARGIN)
    buttonGroup:SetPoint("TOPLEFT", 0, - TOP_BAR_HEIGHT - TITLE_BAR_HEIGHT)
    -- Give the frame a visible background and border:
    buttonGroup:SetBackdrop({
        bgFile = "Interface\\dialogframe\\ui-dialogbox-background", tile = true, tileSize = 16,
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })

    for i=1, 10, 1 do

        local button = CreateFrame("Button", "OpenableBeGoneButtonFrame"..i, buttonGroup)
        button:SetWidth(buttonGroup:GetWidth() - 24)
        button:SetHeight(ROW_HEIGHT)
        if ( i == 1 ) then
            button:SetPoint("TOPLEFT", MARGIN, -6)
        else
            button:SetPoint("TOP", OpenableBeGone.buttonFrames[i-1], "BOTTOM")
        end

        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", OpenableBeGone.OnClick)
        --button:SetScript("OnEnter", OpenableBeGone.OnEnter)
        button:SetScript("OnLeave", OpenableBeGone.OnLeave)

        local highlight = button:CreateTexture("$parentHighlight", "BACKGROUND") -- better highlight
        button.highlight = highlight
        highlight:SetAllPoints()
        highlight:SetBlendMode("ADD")
        highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
        highlight:Hide()

        local itemname_fontsize = 15
        local iteminfo_fontsize = 12

        local itemname = button:CreateFontString(nil, "ARTWORK", "GameTooltipText") --$parentItemName

        button.itemname = itemname
        itemname:SetWidth(buttonGroup:GetWidth()-100)
        itemname:SetFont(GameFontHighlight:GetFont(), itemname_fontsize)
        itemname:SetPoint("TOPLEFT", 30.4, -1)
        itemname:SetJustifyH("LEFT")
        itemname:SetJustifyV("TOP")
        itemname:SetWordWrap(false)

        local iteminfo = button:CreateFontString("$parentItemInfo", "ARTWORK", "GameTooltipText") --$parentItemInfo
        button.iteminfo = iteminfo
        iteminfo:SetWidth(buttonGroup:GetWidth()-100)
        iteminfo:SetFont(GameFontNormal:GetFont(), iteminfo_fontsize)
        iteminfo:SetPoint("TOPLEFT", itemname, "BOTTOMLEFT", 10, 0)
        iteminfo:SetJustifyH("LEFT")
        iteminfo:SetJustifyV("TOP")
        iteminfo:SetTextColor(0.5, 0.5, 0.5)
        iteminfo:SetWordWrap(false)

        local icon = button:CreateTexture("$parentIcon", "BORDER")
        button.icon = icon
        icon:SetWidth(25.4)
        icon:SetHeight(25.4)
        icon:SetPoint("LEFT", 0, 0)
        icon:SetTexture("Interface\\Icons\\temp")

        --DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 check5")

        local checked = CreateFrame("CheckButton", "$parentChecked", button, "ChatConfigCheckButtonTemplate") --InterfaceOptionsSmallCheckButtonTemplate
        button.checked = checked
        checked:SetScript("OnClick", OpenableBeGone.OnCheckboxClick)
        checked:SetWidth(24)
        checked:SetHeight(24)
        checked:SetPoint("RIGHT", -20, 0)
        checked:SetHitRectInsets(0, 0, 0, 0)
        checked:SetChecked(false)
        --DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 check5")

        OpenableBeGone.buttonFrames[i] = button
    end

    frame:Show()
    --DEFAULT_CHAT_FRAME:AddMessage("[OpenableBeGone][Debug] Update:  MainFrameUpdate")
    OpenableBeGone.MainFrameUpdate()
end

function OpenableBeGone.MainFrameUpdate()
    --DEFAULT_CHAT_FRAME:AddMessage("[OpenableBeGone][Debug] MainFrameUpdate")
    local numItems
    if OpenableBeGone.searching == "" or OpenableBeGone.searching == SEARCH:lower() then
        numItems = #(OpenableBeGone.allContainerItemIds)
    else
        numItems = #OpenableBeGone.searchResults[OpenableBeGone.searching]
    end
    --Todo: fix these db lookups
    OpenableBeGone.lockedCheckbox:SetChecked(OpenableBeGone.db.char[dbVersion].dontOpenLocked)
    OpenableBeGone.combatCheckbox:SetChecked(OpenableBeGone.db.char[dbVersion].onlyOpenAfterCombat)
    OpenableBeGone.notifyCheckbox:SetChecked(OpenableBeGone.db.char[dbVersion].notifyInChat)
    OpenableBeGone.minimapCheckbox:SetChecked(not OpenableBeGone.db.char[dbVersion].minimap.hide)

    FauxScrollFrame_Update(OpenableBeGone.scrollbar, numItems, 10, ROW_HEIGHT, nil, nil, nil, nil, nil, nil, true)
    local invalidOffset = 0
    for i=1, 10, 1 do
        local offset = i + FauxScrollFrame_GetOffset(OpenableBeGone.scrollbar)+invalidOffset
        local button = OpenableBeGone.buttonFrames[i]
        button.hover = nil
        if ( offset <= numItems ) then
            local breakwhile = false
            local itemId
            while not breakwhile and offset <= numItems do
                if OpenableBeGone.searching == "" or OpenableBeGone.searching == SEARCH:lower() then
                    itemId = OpenableBeGone.allContainerItemIds[offset]
                else
                    itemId = OpenableBeGone.searchResults[OpenableBeGone.searching][offset]
                end
                local item = Item:CreateFromItemID(itemId)
                local itemIsValid = GetItemInfoInstant(itemId)
                if itemIsValid == nil or item:IsItemEmpty() then
                    invalidOffset = invalidOffset + 1
                    offset = offset + 1
                else
                    breakwhile = true
                end
            end
            if offset <= numItems then
                --DEFAULT_CHAT_FRAME:AddMessage("[OpenableBeGone][Debug] async loading itemId: " .. itemId .. ", offset:" .. offset)
                button.itemname:SetText("Loading...")
                button.iteminfo:SetText("ID["..itemId.."]")
                button.icon:SetTexture(nil)
                button.itemname:SetTextColor(0.5, 0.5, 0.5)
                local item = Item:CreateFromItemID(itemId)
                item:ContinueOnItemLoad(function()
                    itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType,
                    itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType,
                    expacID, setID, isCraftingReagent = GetItemInfo(itemId)
                    if itemName ~= nil then
                        --DEFAULT_CHAT_FRAME:AddMessage("[OpenableBeGone][Debug] done async loading itemId: " .. itemId)
                        OpenableBeGone.UpdateButton(button, itemId, offset)
                    else
                        --DEFAULT_CHAT_FRAME:AddMessage("[OpenableBeGone][Debug] ERROR async loading itemId: " .. itemId)
                    end
                end)
            else
                button:Hide()
            end
        else
            button:Hide()
        end
    end
end

function OpenableBeGone.UpdateButton(button, itemId, offset)
    itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType,
    itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType,
    expacID, setID, isCraftingReagent = GetItemInfo(itemId)
    --DEFAULT_CHAT_FRAME:AddMessage("[OpenableBeGone][Debug] displaying itemId: " .. itemId .. " name:" .. itemName)
    --DEFAULT_CHAT_FRAME:AddMessage("[OpenableBeGone][Debug] UpdateButton searching: " .. OpenableBeGone.searching)
    button.itemid = itemId
    button.itemname:SetText(itemName)
    button.iteminfo:SetText("ID["..itemId.."]")
    button.icon:SetTexture(itemTexture)
    button.itemlink = itemLink

    local r, g, b = 0.5, 0.5, 0.5
    if itemQuality then
        r, g, b = C_Item.GetItemQualityColor(itemQuality)
        button.itemname:SetTextColor(r, g, b)
    end
    button.checked:SetChecked(true)
    if OpenableBeGone.db.char[dbVersion].blacklist[button.itemid] then
        button.checked:SetChecked(false)
    end
    button.r = r
    button.g = g
    button.b = b

    button:Show()
end

function OpenableBeGone.OnClose()
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 OpenableBeGone Closing Main Window")
    end
    OpenableBeGone.mainFrame:Hide()
end

function OpenableBeGone.xScrollFrame_OnShow(self)
    --DEFAULT_CHAT_FRAME:AddMessage("[OpenableBeGone][Debug] xScrollFrame_OnShow")
    OpenableBeGone.MainFrameUpdate()
end

function OpenableBeGone.xScrollFrame_OnVerticalScroll(self, offset)
    --DEFAULT_CHAT_FRAME:AddMessage("[OpenableBeGone][Debug] OnVerticalScroll")
    local current_offset_n = FauxScrollFrame_GetOffset(self)
    local offset_n = (offset >= 0 and 1 or -1) * math.floor(math.abs(offset) / ROW_HEIGHT + 0.1)
    local changed_n = offset_n - current_offset_n
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, OpenableBeGone.MainFrameUpdate)
end

function OpenableBeGone.OnCheckboxClick(self, button)
    OpenableBeGone.HandleOnClick(self:GetParent())
end

function OpenableBeGone.OnLockedCheckboxClick(self, button)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 OpenableBeGone dontOpenLocked: "..tostring(not OpenableBeGone.db.char[dbVersion].dontOpenLocked))
    end
    OpenableBeGone.db.char[dbVersion].dontOpenLocked = not OpenableBeGone.db.char[dbVersion].dontOpenLocked
    OpenableBeGone.MainFrameUpdate()
end

function OpenableBeGone.OnCombatCheckboxClick(self, button)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 OpenableBeGone onlyOpenAfterCombat: "..tostring(not OpenableBeGone.db.char[dbVersion].onlyOpenAfterCombat))
    end
    OpenableBeGone.db.char[dbVersion].onlyOpenAfterCombat = not OpenableBeGone.db.char[dbVersion].onlyOpenAfterCombat
    OpenableBeGone.MainFrameUpdate()
end

function OpenableBeGone.OnNotifyCheckboxClick(self, button)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 OpenableBeGone notifyInChat: "..tostring(not OpenableBeGone.db.char[dbVersion].notifyInChat))
    end
    OpenableBeGone.db.char[dbVersion].notifyInChat = not OpenableBeGone.db.char[dbVersion].notifyInChat
    OpenableBeGone.MainFrameUpdate()
end

function OpenableBeGone.OnMinimapCheckboxClick(self, button)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 OpenableBeGone minimap.hide: "..tostring(not OpenableBeGone.db.char[dbVersion].minimap.hide))
    end
    OpenableBeGone.db.char[dbVersion].minimap.hide = not OpenableBeGone.db.char[dbVersion].minimap.hide
    OpenableBeGone:UpdateMinimapIcon()
    OpenableBeGone.MainFrameUpdate()
end

function OpenableBeGone.OnEnter(self, button)
    --DEFAULT_CHAT_FRAME:AddMessage("[OpenableBeGone][Debug] OnEnter "..self.itemid)
    self.highlight:SetVertexColor(self.r, self.g, self.b, 0.2)
    self.highlight:Show()
    OpenableBeGone.tooltip:SetOwner(self, "ANCHOR_NONE")
    OpenableBeGone.tooltip:SetPoint("RIGHT", self, "LEFT", -8, 0)
    OpenableBeGone.tooltip:SetHyperlink(self.itemlink)
end

function OpenableBeGone.OnLeave(self, button)
    self.highlight:Hide()
    OpenableBeGone.tooltip:SetOwner(UIParent, "ANCHOR_NONE")
end

function OpenableBeGone.OnClick(self, button)
    OpenableBeGone.HandleOnClick(self)
end

function OpenableBeGone.HandleOnClick(self)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 OpenableBeGone item '"..self.itemid.."' enabled: "..tostring(OpenableBeGone.db.char[dbVersion].blacklist[self.itemid] ~= nil))
    end
    if OpenableBeGone.db.char[dbVersion].blacklist[self.itemid] then
        OpenableBeGone.db.char[dbVersion].blacklist[self.itemid] = nil
    else
        OpenableBeGone.db.char[dbVersion].blacklist[self.itemid] = true
    end
    OpenableBeGone.MainFrameUpdate()
end

function OpenableBeGone.OnTextChanged(self)
    OpenableBeGone.searching = self:GetText():trim():lower()
    if OpenableBeGone.searching == "" or OpenableBeGone.searching == SEARCH:lower() then
        OpenableBeGone.MainFrameUpdate()
        return
    end

    --DEFAULT_CHAT_FRAME:AddMessage("[OpenableBeGone][Debug] searching: "..OpenableBeGone.searching)
    resultIndices = {}
    for index, value in ipairs(OpenableBeGone.allContainerItemNames) do
        if value:lower():match(OpenableBeGone.searching) then
            table.insert(resultIndices, OpenableBeGone.allContainerItemIds[index])
        end
    end
    OpenableBeGone.searchResults[OpenableBeGone.searching] = resultIndices
    ---DEFAULT_CHAT_FRAME:AddMessage("[OpenableBeGone][Debug] resultcount: "..#(OpenableBeGone.searchResults[OpenableBeGone.searching]))
    OpenableBeGone.MainFrameUpdate()
end

function OpenableBeGone.OnEnterPressed(self)
    self:ClearFocus()
end

function OpenableBeGone.OnEscapePressed(self)
    self:ClearFocus()
    self:SetText(SEARCH)
    OpenableBeGone.searching = ""
end

function OpenableBeGone.OnEditFocusLost(self)
    self:HighlightText(0, 0)
    if ( strtrim(self:GetText()) == "" ) then
        self:SetText(SEARCH)
        OpenableBeGone.searching = ""
    end
end

function OpenableBeGone.OnEditFocusGained(self)
    self:HighlightText()
    if ( self:GetText():trim():lower() == SEARCH:lower() ) then
        self:SetText("")
    end
end
