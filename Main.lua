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

AutoOpenAnything = LibStub("AceAddon-3.0"):NewAddon("AutoOpenAnything", "AceConsole-3.0", "AceEvent-3.0")
AutoOpenAnything.buttonFrames = {}
AutoOpenAnything.searching = ""
AutoOpenAnything.searchResults = {}
AutoOpenAnything.merchantShown = false
AutoOpenAnything.adventureMapShown = false
AutoOpenAnything.tooltip = CreateFrame("GameTooltip", "AutoOpenAnythingTooltip", UIParent, "GameTooltipTemplate")
AutoOpenAnything.allContainerItemIds = AutoOpenAnythingAllContainerItemIds
--read all container itemids and store them in a table for accessibility
AutoOpenAnything.allContainerItemIdsTable = {}
for index, value in ipairs(AutoOpenAnything.allContainerItemIds) do
    AutoOpenAnything.allContainerItemIdsTable[value] = true
end
AutoOpenAnything.allContainerItemNames = AutoOpenAnythingAllContainerItemNames
--read all container itemids and store them in a table for accessibility
AutoOpenAnything.allLockedContainerItemIdsTable = {}
AutoOpenAnything.allLockedContainerItemIds = AutoOpenAnythingAllLockedContainerItemIds
for index, value in ipairs(AutoOpenAnything.allLockedContainerItemIds) do
    AutoOpenAnything.allLockedContainerItemIdsTable[value] = true
end

local dbVersion = "0.3"
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

function AutoOpenAnything:OnInitialize()
    -- Code that you want to run when the addon is first loaded goes here.
    AutoOpenAnything:Print("DB Version: ", dbVersion)
    AutoOpenAnything.db = LibStub("AceDB-3.0"):New("AutoOpenAnythingDB", defaults, true)
    --LibStub("AceConfig-3.0"):RegisterOptionsTable("AutoOpenAnything", options, {"autoopenanything", "aoa"})
    AutoOpenAnything:RegisterChatCommand("autoopenanything", "SlashProcessorFunc")
    AutoOpenAnything:RegisterChatCommand("aoa", "SlashProcessorFunc")
    AutoOpenAnything:RegisterEvent("BAG_UPDATE_DELAYED")
    AutoOpenAnything:RegisterEvent("PLAYER_REGEN_ENABLED")
    AutoOpenAnything:RegisterEvent("MERCHANT_SHOW")
    AutoOpenAnything:RegisterEvent("MERCHANT_CLOSED")
    AutoOpenAnything:RegisterEvent("ADVENTURE_MAP_OPEN")
    AutoOpenAnything:RegisterEvent("ADVENTURE_MAP_CLOSE")

    local autoOpenAnythingLDB = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("AutoOpenAnything", {
        type = "launcher",
        icon = "Interface\\Icons\\Inv_misc_treasurechest04b",
        OnClick = function(clickedframe, button)
            --DEFAULT_CHAT_FRAME:AddMessage("Minimap icon clicked")
            if IsShiftKeyDown() then
                AutoOpenAnything.db.char[dbVersion].minimap.hide = true
                AutoOpenAnything:UpdateMinimapIcon()
                AutoOpenAnything.MainFrameUpdate()
    		elseif AutoOpenAnything.mainFrame and AutoOpenAnything.mainFrame:IsShown() then
                AutoOpenAnything.mainFrame:Hide()
            else
                AutoOpenAnything.ShowMainFrame()
            end
        end,
        OnTooltipShow = function(tt)
            addonname = GetAddOnMetadata(AutoOpenAnything:GetName(), "Title")
            addonversion = GetAddOnMetadata(AutoOpenAnything:GetName(), "Version")
            tt:AddLine(addonname .. " - " .. addonversion, 1, 1, 1, 1)
            tt:AddLine(" ", 1, 1, 0.2, 1)
            tt:AddLine("Shift-click to hide minimap button", 1, 1, 0.2, 1)
            tt:AddLine("Console: /aoa /autoopenanything", 1, 1, 0.2, 1)
        end
    })
    LibStub("LibDBIcon-1.0"):Register("AutoOpenAnything", autoOpenAnythingLDB, AutoOpenAnything.db.char[dbVersion].minimap)
    AutoOpenAnything:UpdateMinimapIcon()
end

function AutoOpenAnything:UpdateMinimapIcon()
    if AutoOpenAnything.db.char[dbVersion].minimap.hide then
        LibStub("LibDBIcon-1.0"):Hide(AutoOpenAnything:GetName())
    else
        LibStub("LibDBIcon-1.0"):Show(AutoOpenAnything:GetName())
    end
end

function AutoOpenAnything:SlashProcessorFunc(input)
    -- Process the slash command ('input' contains whatever follows the slash command)
    if input == "debug" or input == "dbg" then
        showDebugOutput = not showDebugOutput
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 AutoOpenAnything Debug output: "..tostring(showDebugOutput))
    else
        AutoOpenAnything:ShowMainFrame()
    end
end

function AutoOpenAnything:AutoOpenContainers()
    if (not UnitAffectingCombat("player") or not AutoOpenAnything.db.char[dbVersion].onlyOpenAfterCombat)
    and not AutoOpenAnything.merchantShown and not AutoOpenAnything.adventureMapShown then
        --DEFAULT_CHAT_FRAME:AddMessage("AutoOpenAnything:AutoOpenContainers()")
        for bag = 0, 4 do
            for slot = 0, C_Container.GetContainerNumSlots(bag) do
                local id = C_Container.GetContainerItemID(bag, slot)
                if id and AutoOpenAnything.allContainerItemIdsTable[id] and AutoOpenAnything.db.char[dbVersion].blacklist[id] == nil
                and (AutoOpenAnything.allLockedContainerItemIdsTable[id] == nil or not AutoOpenAnything.db.char[dbVersion].dontOpenLocked) then
                    C_Container.UseContainerItem(bag, slot)
                    if AutoOpenAnything.db.char[dbVersion].notifyInChat or showDebugOutput then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Opening : " .. GetContainerItemLink(bag, slot) .. " ID: " .. GetContainerItemID(bag, slot))
                    end
                    return
                end
            end
        end
    else
        if showDebugOutput then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 AutoOpenAnything - Skipping auto-open - inCombat: "..tostring(UnitAffectingCombat("player"))
            ..", merchantShown: "..tostring(AutoOpenAnything.merchantShown)..", adventureMapShown: "..tostring(AutoOpenAnything.adventureMapShown))
        end
    end
end

function AutoOpenAnything:BAG_UPDATE_DELAYED(event, message)
    AutoOpenAnything:AutoOpenContainers()
end

function AutoOpenAnything:PLAYER_REGEN_ENABLED(event, message)
    AutoOpenAnything:AutoOpenContainers()
end

function AutoOpenAnything:MERCHANT_SHOW(event, message)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 AutoOpenAnything Merchant now shown")
    end
    AutoOpenAnything.merchantShown = true
end

function AutoOpenAnything:MERCHANT_CLOSED(event, message)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 AutoOpenAnything Merchant no longer shown")
    end
    AutoOpenAnything.merchantShown = false
    AutoOpenAnything:AutoOpenContainers()
end

function AutoOpenAnything:ADVENTURE_MAP_OPEN(event, message)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 AutoOpenAnything Mission table now shown")
    end
    AutoOpenAnything.adventureMapShown = true
end

function AutoOpenAnything:ADVENTURE_MAP_CLOSE(event, message)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 AutoOpenAnything Mission table no longer shown")
    end
    AutoOpenAnything.adventureMapShown = false
    AutoOpenAnything:AutoOpenContainers()
end

function AutoOpenAnything.ShowMainFrame()
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 AutoOpenAnything Showing Main Window")
    end
    if AutoOpenAnything.mainFrame then
        if AutoOpenAnything.mainFrame:IsShown() then
            return
        end
        AutoOpenAnything.mainFrame:Show()
        return
    end
    ----------------------------------------------------------------
    -- Create the frame:
    local frame = CreateFrame("Frame", "AutoOpenAnythingMainFrame", UIParent, "BackdropTemplate")
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
    -- Add the frame as a global variable under the name `AutoOpenAnythingMainFrame`
    _G["AutoOpenAnythingMainFrame"] = frame
    -- Register the global variable `AutoOpenAnythingMainFrame` as a "special frame"
    -- so that it is closed when the escape key is pressed.
    tinsert(UISpecialFrames, "AutoOpenAnythingMainFrame")

    AutoOpenAnything.mainFrame = frame

    local titlebar = CreateFrame("Frame", "AutoOpenAnythingTitleBar", frame, "BackdropTemplate")
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
    title:SetJustifyV("CENTER")
    title:SetPoint("TOPLEFT", MARGIN, 0)
    title:SetFont(GameFontNormal:GetFont(), 16)
    addonname = GetAddOnMetadata(AutoOpenAnything:GetName(), "Title")
    addonversion = GetAddOnMetadata(AutoOpenAnything:GetName(), "Version")
    title:SetText(addonname.." - "..addonversion)
    title:SetTextColor(1, 1, 0.2)

    local close = CreateFrame("Button", nil, titlebar, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 1)
    close:SetScript("OnClick", AutoOpenAnything.OnClose)

    local search = CreateFrame("EditBox", "$parentSearch", frame, "InputBoxTemplate")
    frame.search = search
    search:SetWidth(SEARCH_BAR_WIDTH)
    search:SetHeight(SEARCH_BAR_HEIGHT)
    search:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", MARGIN + 6, -TITLE_BAR_HEIGHT - TOP_BAR_HEIGHT)
    search:SetAutoFocus(false)
    search:SetFontObject("ChatFontNormal")
    search:SetScript("OnTextChanged", AutoOpenAnything.OnTextChanged)
    search:SetScript("OnEnterPressed", AutoOpenAnything.OnEnterPressed)
    search:SetScript("OnEscapePressed", AutoOpenAnything.OnEscapePressed)
    search:SetScript("OnEditFocusLost", AutoOpenAnything.OnEditFocusLost)
    search:SetScript("OnEditFocusGained", AutoOpenAnything.OnEditFocusGained)
    search:SetText(SEARCH)

    local lockedCheckboxFrame = CreateFrame("Button", "AutoOpenAnythingLockedCheckboxFrame", frame)
    lockedCheckboxFrame:SetSize(frame:GetWidth() - SEARCH_BAR_WIDTH - 50, TITLE_BAR_HEIGHT)
    lockedCheckboxFrame:SetPoint("TOPRIGHT", 0, -TITLE_BAR_HEIGHT)
    lockedCheckboxFrame:SetScript("OnClick", AutoOpenAnything.OnLockedCheckboxClick)

    local label = lockedCheckboxFrame:CreateFontString(nil, "ARTWORK", "GameTooltipText") --AutoOpenAnythingCombatCheckboxFrame
    label:SetWidth(lockedCheckboxFrame:GetWidth() - MARGIN * 2 - 24)
    label:SetHeight(lockedCheckboxFrame:GetHeight())
    label:SetJustifyH("LEFT")
    label:SetJustifyV("CENTER")
    label:SetPoint("TOPLEFT", MARGIN, 0)
    label:SetFont(GameFontNormal:GetFont(), 12)
    label:SetText("Ignore locked containers")
    label:SetTextColor(0, 0, 0)


    local checked = CreateFrame("CheckButton", "AutoOpenAnythingLockedCheckbox", lockedCheckboxFrame, "ChatConfigCheckButtonTemplate") -- "InterfaceOptionsSmallCheckButtonTemplate"

    checked:SetScript("OnClick", AutoOpenAnything.OnLockedCheckboxClick)
    checked:SetWidth(24)
    checked:SetHeight(24)
    checked:SetPoint("RIGHT", -MARGIN, 0)
    checked:SetHitRectInsets(0, 0, 0, 0)
    checked:SetChecked(AutoOpenAnything.db.char[dbVersion].dontOpenLocked)
    AutoOpenAnything.lockedCheckbox = checked

    local combatCheckboxFrame = CreateFrame("Button", "AutoOpenAnythingCombatCheckboxFrame", frame)
    combatCheckboxFrame:SetSize(frame:GetWidth() - SEARCH_BAR_WIDTH - 50, TITLE_BAR_HEIGHT)
    combatCheckboxFrame:SetPoint("TOPRIGHT", 0, -TITLE_BAR_HEIGHT*2)
    combatCheckboxFrame:SetScript("OnClick", AutoOpenAnything.OnCombatCheckboxClick)

    local label = combatCheckboxFrame:CreateFontString(nil, "ARTWORK", "GameTooltipText") --AutoOpenAnythingCombatCheckboxFrame
    label:SetWidth(combatCheckboxFrame:GetWidth() - MARGIN * 2 - 24)
    label:SetHeight(combatCheckboxFrame:GetHeight())
    label:SetJustifyH("LEFT")
    label:SetJustifyV("CENTER")
    label:SetPoint("TOPLEFT", MARGIN, 0)
    label:SetFont(GameFontNormal:GetFont(), 12)
    label:SetText("Only open after combat")
    label:SetTextColor(0, 0, 0)

    local checked = CreateFrame("CheckButton", "AutoOpenAnythingCombatCheckbox", combatCheckboxFrame, "ChatConfigCheckButtonTemplate" ) --InterfaceOptionsSmallCheckButtonTemplate
    checked:SetScript("OnClick", AutoOpenAnything.OnCombatCheckboxClick)
    checked:SetWidth(24)
    checked:SetHeight(24)
    checked:SetPoint("RIGHT", -MARGIN, 0)
    checked:SetHitRectInsets(0, 0, 0, 0)
    checked:SetChecked(AutoOpenAnything.db.char[dbVersion].onlyOpenAfterCombat)
    AutoOpenAnything.combatCheckbox = checked

    local notifyCheckboxFrame = CreateFrame("Button", "AutoOpenAnythingNotifyCheckboxFrame", frame)
    notifyCheckboxFrame:SetSize(frame:GetWidth() - SEARCH_BAR_WIDTH - 50, TITLE_BAR_HEIGHT)
    notifyCheckboxFrame:SetPoint("TOPRIGHT", 0, -TITLE_BAR_HEIGHT*3)
    notifyCheckboxFrame:SetScript("OnClick", AutoOpenAnything.OnNotifyCheckboxClick)

    local label = notifyCheckboxFrame:CreateFontString(nil, "ARTWORK", "GameTooltipText") --AutoOpenAnythingNotifyCheckboxFrame
    label:SetWidth(notifyCheckboxFrame:GetWidth() - MARGIN * 2 - 24)
    label:SetHeight(notifyCheckboxFrame:GetHeight())
    label:SetJustifyH("LEFT")
    label:SetJustifyV("CENTER")
    label:SetPoint("TOPLEFT", MARGIN, 0)
    label:SetFont(GameFontNormal:GetFont(), 12)
    label:SetText("Notify in chat")
    label:SetTextColor(0, 0, 0)
    local checked = CreateFrame("CheckButton", "AutoOpenAnythingNotifyCheckbox", notifyCheckboxFrame, "ChatConfigCheckButtonTemplate") --InterfaceOptionsSmallCheckButtonTemplate
    checked:SetScript("OnClick", AutoOpenAnything.OnNotifyCheckboxClick)
    checked:SetWidth(24)
    checked:SetHeight(24)
    checked:SetPoint("RIGHT", -MARGIN, 0)
    checked:SetHitRectInsets(0, 0, 0, 0)
    checked:SetChecked(AutoOpenAnything.db.char[dbVersion].notifyInChat)
    AutoOpenAnything.notifyCheckbox = checked

    local minimapCheckboxFrame = CreateFrame("Button", "AutoOpenAnythingMinimapCheckboxFrame", frame)
    minimapCheckboxFrame:SetSize(frame:GetWidth() - SEARCH_BAR_WIDTH - 50, TITLE_BAR_HEIGHT)
    minimapCheckboxFrame:SetPoint("TOPRIGHT", 0, -TITLE_BAR_HEIGHT*4)
    minimapCheckboxFrame:SetScript("OnClick", AutoOpenAnything.OnMinimapCheckboxClick)
    local label = minimapCheckboxFrame:CreateFontString(nil, "ARTWORK", "GameTooltipText") --AutoOpenAnythingMinimapCheckboxFrame
    label:SetWidth(minimapCheckboxFrame:GetWidth() - MARGIN * 2 - 24)
    label:SetHeight(minimapCheckboxFrame:GetHeight())
    label:SetJustifyH("LEFT")
    label:SetJustifyV("CENTER")
    label:SetPoint("TOPLEFT", MARGIN, 0)
    label:SetFont(GameFontNormal:GetFont(), 12)
    label:SetText("Show minimap icon")
    label:SetTextColor(0, 0, 0)
    local checked = CreateFrame("CheckButton", "AutoOpenAnythingMinimapCheckbox", minimapCheckboxFrame, "ChatConfigCheckButtonTemplate") --InterfaceOptionsSmallCheckButtonTemplate
    checked:SetScript("OnClick", AutoOpenAnything.OnMinimapCheckboxClick)
    checked:SetWidth(24)
    checked:SetHeight(24)
    checked:SetPoint("RIGHT", -MARGIN, 0)
    checked:SetHitRectInsets(0, 0, 0, 0)
    checked:SetChecked(not AutoOpenAnything.db.char[dbVersion].minimap.hide)
    AutoOpenAnything.minimapCheckbox = checked

    AutoOpenAnything.scrollbar = CreateFrame("ScrollFrame", "AutoOpenAnythingScrollFrame", frame, "FauxScrollFrameTemplate")
    AutoOpenAnything.scrollbar:SetPoint("TOPLEFT", -1, -7 - TOP_BAR_HEIGHT - TITLE_BAR_HEIGHT)
    AutoOpenAnything.scrollbar:SetPoint("BOTTOMRIGHT", -31, 8)
    AutoOpenAnything.scrollbar:SetScript("OnShow", AutoOpenAnything.xScrollFrame_OnShow)
    AutoOpenAnything.scrollbar:SetScript("OnVerticalScroll", AutoOpenAnything.xScrollFrame_OnVerticalScroll)

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

    buttonGroup = CreateFrame("Frame", "AutoOpenAnythingButtonGroup", frame, "BackdropTemplate")
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

        local button = CreateFrame("Button", "AutoOpenAnythingButtonFrame"..i, buttonGroup)
        button:SetWidth(buttonGroup:GetWidth() - 24)
        button:SetHeight(ROW_HEIGHT)
        if ( i == 1 ) then
            button:SetPoint("TOPLEFT", MARGIN, -6)
        else
            button:SetPoint("TOP", AutoOpenAnything.buttonFrames[i-1], "BOTTOM")
        end

        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", AutoOpenAnything.OnClick)
        --button:SetScript("OnEnter", AutoOpenAnything.OnEnter)
        button:SetScript("OnLeave", AutoOpenAnything.OnLeave)

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
        checked:SetScript("OnClick", AutoOpenAnything.OnCheckboxClick)
        checked:SetWidth(24)
        checked:SetHeight(24)
        checked:SetPoint("RIGHT", -20, 0)
        checked:SetHitRectInsets(0, 0, 0, 0)
        checked:SetChecked(false)
        --DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 check5")

        AutoOpenAnything.buttonFrames[i] = button
    end

    frame:Show()
    --DEFAULT_CHAT_FRAME:AddMessage("[AutoOpenAnything][Debug] Update:  MainFrameUpdate")
    AutoOpenAnything.MainFrameUpdate()
end

function AutoOpenAnything.MainFrameUpdate()
    --DEFAULT_CHAT_FRAME:AddMessage("[AutoOpenAnything][Debug] MainFrameUpdate")
    local numItems
    if AutoOpenAnything.searching == "" or AutoOpenAnything.searching == SEARCH:lower() then
        numItems = #(AutoOpenAnything.allContainerItemIds)
    else
        numItems = #AutoOpenAnything.searchResults[AutoOpenAnything.searching]
    end
    --Todo: fix these db lookups
    AutoOpenAnything.lockedCheckbox:SetChecked(AutoOpenAnything.db.char[dbVersion].dontOpenLocked)
    AutoOpenAnything.combatCheckbox:SetChecked(AutoOpenAnything.db.char[dbVersion].onlyOpenAfterCombat)
    AutoOpenAnything.notifyCheckbox:SetChecked(AutoOpenAnything.db.char[dbVersion].notifyInChat)
    AutoOpenAnything.minimapCheckbox:SetChecked(not AutoOpenAnything.db.char[dbVersion].minimap.hide)

    FauxScrollFrame_Update(AutoOpenAnything.scrollbar, numItems, 10, ROW_HEIGHT, nil, nil, nil, nil, nil, nil, true)
    local invalidOffset = 0
    for i=1, 10, 1 do
        local offset = i + FauxScrollFrame_GetOffset(AutoOpenAnything.scrollbar)+invalidOffset
        local button = AutoOpenAnything.buttonFrames[i]
        button.hover = nil
        if ( offset <= numItems ) then
            local breakwhile = false
            local itemId
            while not breakwhile and offset <= numItems do
                if AutoOpenAnything.searching == "" or AutoOpenAnything.searching == SEARCH:lower() then
                    itemId = AutoOpenAnything.allContainerItemIds[offset]
                else
                    itemId = AutoOpenAnything.searchResults[AutoOpenAnything.searching][offset]
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
                --DEFAULT_CHAT_FRAME:AddMessage("[AutoOpenAnything][Debug] async loading itemId: " .. itemId .. ", offset:" .. offset)
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
                        --DEFAULT_CHAT_FRAME:AddMessage("[AutoOpenAnything][Debug] done async loading itemId: " .. itemId)
                        AutoOpenAnything.UpdateButton(button, itemId, offset)
                    else
                        --DEFAULT_CHAT_FRAME:AddMessage("[AutoOpenAnything][Debug] ERROR async loading itemId: " .. itemId)
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

function AutoOpenAnything.UpdateButton(button, itemId, offset)
    itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType,
    itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType,
    expacID, setID, isCraftingReagent = GetItemInfo(itemId)
    --DEFAULT_CHAT_FRAME:AddMessage("[AutoOpenAnything][Debug] displaying itemId: " .. itemId .. " name:" .. itemName)
    --DEFAULT_CHAT_FRAME:AddMessage("[AutoOpenAnything][Debug] UpdateButton searching: " .. AutoOpenAnything.searching)
    button.itemid = itemId
    button.itemname:SetText(itemName)
    button.iteminfo:SetText("ID["..itemId.."]")
    button.icon:SetTexture(itemTexture)
    button.itemlink = itemLink

    local r, g, b = 0.5, 0.5, 0.5
    if itemQuality then
        r, g, b = GetItemQualityColor(itemQuality)
        button.itemname:SetTextColor(r, g, b)
    end
    button.checked:SetChecked(true)
    if AutoOpenAnything.db.char[dbVersion].blacklist[button.itemid] then
        button.checked:SetChecked(false)
    end
    button.r = r
    button.g = g
    button.b = b

    button:Show()
end

function AutoOpenAnything.OnClose()
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 AutoOpenAnything Closing Main Window")
    end
    AutoOpenAnything.mainFrame:Hide()
end

function AutoOpenAnything.xScrollFrame_OnShow(self)
    --DEFAULT_CHAT_FRAME:AddMessage("[AutoOpenAnything][Debug] xScrollFrame_OnShow")
    AutoOpenAnything.MainFrameUpdate()
end

function AutoOpenAnything.xScrollFrame_OnVerticalScroll(self, offset)
    --DEFAULT_CHAT_FRAME:AddMessage("[AutoOpenAnything][Debug] OnVerticalScroll")
    local current_offset_n = FauxScrollFrame_GetOffset(self)
    local offset_n = (offset >= 0 and 1 or -1) * math.floor(math.abs(offset) / ROW_HEIGHT + 0.1)
    local changed_n = offset_n - current_offset_n
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, AutoOpenAnything.MainFrameUpdate)
end

function AutoOpenAnything.OnCheckboxClick(self, button)
    AutoOpenAnything.HandleOnClick(self:GetParent())
end

function AutoOpenAnything.OnLockedCheckboxClick(self, button)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 AutoOpenAnything dontOpenLocked: "..tostring(not AutoOpenAnything.db.char[dbVersion].dontOpenLocked))
    end
    AutoOpenAnything.db.char[dbVersion].dontOpenLocked = not AutoOpenAnything.db.char[dbVersion].dontOpenLocked
    AutoOpenAnything.MainFrameUpdate()
end

function AutoOpenAnything.OnCombatCheckboxClick(self, button)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 AutoOpenAnything onlyOpenAfterCombat: "..tostring(not AutoOpenAnything.db.char[dbVersion].onlyOpenAfterCombat))
    end
    AutoOpenAnything.db.char[dbVersion].onlyOpenAfterCombat = not AutoOpenAnything.db.char[dbVersion].onlyOpenAfterCombat
    AutoOpenAnything.MainFrameUpdate()
end

function AutoOpenAnything.OnNotifyCheckboxClick(self, button)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 AutoOpenAnything notifyInChat: "..tostring(not AutoOpenAnything.db.char[dbVersion].notifyInChat))
    end
    AutoOpenAnything.db.char[dbVersion].notifyInChat = not AutoOpenAnything.db.char[dbVersion].notifyInChat
    AutoOpenAnything.MainFrameUpdate()
end

function AutoOpenAnything.OnMinimapCheckboxClick(self, button)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 AutoOpenAnything minimap.hide: "..tostring(not AutoOpenAnything.db.char[dbVersion].minimap.hide))
    end
    AutoOpenAnything.db.char[dbVersion].minimap.hide = not AutoOpenAnything.db.char[dbVersion].minimap.hide
    AutoOpenAnything:UpdateMinimapIcon()
    AutoOpenAnything.MainFrameUpdate()
end

function AutoOpenAnything.OnEnter(self, button)
    --DEFAULT_CHAT_FRAME:AddMessage("[AutoOpenAnything][Debug] OnEnter "..self.itemid)
    self.highlight:SetVertexColor(self.r, self.g, self.b, 0.2)
    self.highlight:Show()
    AutoOpenAnything.tooltip:SetOwner(self, "ANCHOR_NONE")
    AutoOpenAnything.tooltip:SetPoint("RIGHT", self, "LEFT", -8, 0)
    AutoOpenAnything.tooltip:SetHyperlink(self.itemlink)
end

function AutoOpenAnything.OnLeave(self, button)
    self.highlight:Hide()
    AutoOpenAnything.tooltip:SetOwner(UIParent, "ANCHOR_NONE")
end

function AutoOpenAnything.OnClick(self, button)
    AutoOpenAnything.HandleOnClick(self)
end

function AutoOpenAnything.HandleOnClick(self)
    if showDebugOutput then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFff0ef3 AutoOpenAnything item '"..self.itemid.."' enabled: "..tostring(AutoOpenAnything.db.char[dbVersion].blacklist[self.itemid] ~= nil))
    end
    if AutoOpenAnything.db.char[dbVersion].blacklist[self.itemid] then
        AutoOpenAnything.db.char[dbVersion].blacklist[self.itemid] = nil
    else
        AutoOpenAnything.db.char[dbVersion].blacklist[self.itemid] = true
    end
    AutoOpenAnything.MainFrameUpdate()
end

function AutoOpenAnything.OnTextChanged(self)
    AutoOpenAnything.searching = self:GetText():trim():lower()
    if AutoOpenAnything.searching == "" or AutoOpenAnything.searching == SEARCH:lower() then
        AutoOpenAnything.MainFrameUpdate()
        return
    end

    --DEFAULT_CHAT_FRAME:AddMessage("[AutoOpenAnything][Debug] searching: "..AutoOpenAnything.searching)
    resultIndices = {}
    for index, value in ipairs(AutoOpenAnything.allContainerItemNames) do
        if value:lower():match(AutoOpenAnything.searching) then
            table.insert(resultIndices, AutoOpenAnything.allContainerItemIds[index])
        end
    end
    AutoOpenAnything.searchResults[AutoOpenAnything.searching] = resultIndices
    ---DEFAULT_CHAT_FRAME:AddMessage("[AutoOpenAnything][Debug] resultcount: "..#(AutoOpenAnything.searchResults[AutoOpenAnything.searching]))
    AutoOpenAnything.MainFrameUpdate()
end

function AutoOpenAnything.OnEnterPressed(self)
    self:ClearFocus()
end

function AutoOpenAnything.OnEscapePressed(self)
    self:ClearFocus()
    self:SetText(SEARCH)
    AutoOpenAnything.searching = ""
end

function AutoOpenAnything.OnEditFocusLost(self)
    self:HighlightText(0, 0)
    if ( strtrim(self:GetText()) == "" ) then
        self:SetText(SEARCH)
        AutoOpenAnything.searching = ""
    end
end

function AutoOpenAnything.OnEditFocusGained(self)
    self:HighlightText()
    if ( self:GetText():trim():lower() == SEARCH:lower() ) then
        self:SetText("")
    end
end
