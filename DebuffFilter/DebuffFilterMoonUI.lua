-- DebuffFilter MoonMarker-style management UI.
-- This module only reorganizes and skins the existing manager controls.
-- It does not replace aura scanning, timing, SavedVariables, or seven monitor frames.

DebuffFilter_MoonUI = DebuffFilter_MoonUI or {}
local MoonUI = DebuffFilter_MoonUI

local LegacyManagerToggle = DebuffFilter_Manager_Toggle
local UI_APPLIED = false
local CURRENT_TAB = "monitor"
local TAB_BUTTONS = {}
local MONITOR_TAB_BUTTONS = {}
local MONITOR_GROUP_BUTTONS = {}
local MONITOR_SUB_BUTTONS = {}
local CURRENT_MONITOR_GROUP = "target"
local CURRENT_MONITOR_MODE = "debuff"
local MONITOR_PAGE_TITLE = nil
local MONITOR_PAGE_DESC = nil
local CURRENT_TIMER_PAGE = "modes"
local TIMER_SUB_BUTTONS = {}
local TIMER_PAGE_OBJECTS = { modes={}, appearance={}, behavior={} }
local TIMER_MODE_BUTTONS = {}
local TIMER_SHINE_BUTTONS = {}
local TIMER_STYLE_EDITS = {}
local TIMER_STYLE_DROPS = {}
local TIMER_STYLE_CHECKS = {}
local TIMER_COLOR_BUTTONS = {}
local CURRENT_TIMER_STYLE_TARGET = "all"
local CURRENT_SPELL_PAGE = "settings"
local SPELL_SUB_BUTTONS = {}
local SPELL_PAGE_OBJECTS = { settings={}, blacklist={} }
local SPELL_BLACKLIST_ROWS = {}
local SPELL_BLACKLIST_SEARCH = nil
local SPELL_BLACKLIST_COUNT = nil
local SPELL_BLACKLIST_PAGE_LABEL = nil
local SPELL_BLACKLIST_PAGE = 1
local SPELL_BLACKLIST_PAGE_SIZE = 6
local GROUPS = {
    monitor = {},
    display = {},
    timer = {},
    spell = {},
    help = {},
    common = {},
}

local COLOR_BG = { 0.02, 0.03, 0.06, 0.96 }
local COLOR_PANEL = { 0.035, 0.06, 0.11, 0.92 }
local COLOR_BORDER = { 0.15, 0.34, 0.58, 0.72 }
local COLOR_BLUE = { 0.10, 0.28, 0.50, 0.96 }
local COLOR_BLUE_ACTIVE = { 0.08, 0.48, 0.78, 0.98 }
local COLOR_GREEN = { 0.08, 0.48, 0.28, 0.96 }
local COLOR_RED = { 0.54, 0.12, 0.16, 0.96 }
local COLOR_AMBER = { 0.56, 0.36, 0.08, 0.96 }

local function AddToGroup(groupName, object)
    if (not object) then return; end
    table.insert(GROUPS[groupName], object)
end

local function ShowObject(object)
    if (object and object.Show) then object:Show(); end
end

local function HideObject(object)
    if (object and object.Hide) then object:Hide(); end
end

local function SetObjectPoint(object, point, relativeTo, relativePoint, x, y)
    if (not object) then return; end
    object:ClearAllPoints();
    object:SetPoint(point, relativeTo, relativePoint, x, y);
end

local function MakeTexture(parent, layer, r, g, b, a)
    local texture = parent:CreateTexture(nil, layer);
    texture:SetTexture(r, g, b, a);
    return texture;
end

local function MakeLabel(parent, name, text, x, y, width, size, colorR, colorG, colorB)
    local label = parent:CreateFontString(name, "OVERLAY", "GameFontNormalSmall");
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
    label:SetWidth(width or 120);
    label:SetHeight(18);
    DebuffFilter_SetUIFont(label, size or 12, "OUTLINE");
    label:SetJustifyH("LEFT");
    label:SetJustifyV("MIDDLE");
    label:SetTextColor(colorR or 0.78, colorG or 0.90, colorB or 1.00);
    label:SetText(text or "");
    return label;
end

local function StyleButton(button, color, textColor)
    if (not button) then return; end
    if (button.SetNormalTexture) then button:SetNormalTexture(nil); end
    if (button.SetPushedTexture) then button:SetPushedTexture(nil); end
    if (button.SetDisabledTexture) then button:SetDisabledTexture(nil); end
    if (button.SetHighlightTexture) then button:SetHighlightTexture(nil); end

    if (not button.DFMoonBackground) then
        button.DFMoonBackground = MakeTexture(button, "BACKGROUND", color[1], color[2], color[3], color[4]);
        button.DFMoonBackground:SetAllPoints(button);
        button.DFMoonBorder = MakeTexture(button, "BORDER", 0.20, 0.48, 0.78, 0.48);
        button.DFMoonBorder:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1);
        button.DFMoonBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1);
    else
        button.DFMoonBackground:SetTexture(color[1], color[2], color[3], color[4]);
    end

    local fontString = button.GetFontString and button:GetFontString() or nil;
    if (fontString) then
        DebuffFilter_SetUIFont(fontString, 12, "OUTLINE");
        fontString:SetTextColor(textColor and textColor[1] or 0.92,
            textColor and textColor[2] or 0.97,
            textColor and textColor[3] or 1.00);
    end
end

local function StyleEditBox(edit)
    if (not edit) then return; end
    edit:SetTextColor(0.84, 0.94, 1.00);
    DebuffFilter_SetUIFont(edit, 12, "OUTLINE");
    edit:SetHeight(24);

    local name = edit.GetName and edit:GetName() or nil;
    if (name) then
        local left = getglobal(name .. "Left");
        local mid = getglobal(name .. "Mid");
        local right = getglobal(name .. "Right");
        if (left) then left:Hide(); end
        if (mid) then mid:Hide(); end
        if (right) then right:Hide(); end
    end

    if (not edit.DFMoonUnderlay) then
        edit.DFMoonUnderlay = MakeTexture(edit, "BACKGROUND", 0.010, 0.025, 0.055, 0.98);
        edit.DFMoonUnderlay:SetPoint("TOPLEFT", edit, "TOPLEFT", -4, 2);
        edit.DFMoonUnderlay:SetPoint("BOTTOMRIGHT", edit, "BOTTOMRIGHT", 4, -2);
        edit.DFMoonBorder = MakeTexture(edit, "BORDER", 0.13, 0.42, 0.68, 0.62);
        edit.DFMoonBorder:SetPoint("TOPLEFT", edit, "TOPLEFT", -3, 1);
        edit.DFMoonBorder:SetPoint("BOTTOMRIGHT", edit, "BOTTOMRIGHT", 3, -1);
    end
end

local function StyleDropDown(dropdown)
    if (not dropdown) then return; end
    local name = dropdown:GetName();
    local text = name and getglobal(name .. "Text") or nil;
    local left = name and getglobal(name .. "Left") or nil;
    local middle = name and getglobal(name .. "Middle") or nil;
    local right = name and getglobal(name .. "Right") or nil;
    local arrow = name and getglobal(name .. "Button") or nil;

    if (left) then left:Hide(); end
    if (middle) then middle:Hide(); end
    if (right) then right:Hide(); end

    if (text) then
        text:ClearAllPoints();
        text:SetPoint("LEFT", dropdown, "LEFT", 23, 1);
        text:SetPoint("RIGHT", dropdown, "RIGHT", -38, 1);
        DebuffFilter_SetUIFont(text, 12, "OUTLINE");
        text:SetTextColor(0.82, 0.93, 1.00);
        text:SetJustifyH("LEFT");
    end

    if (arrow) then
        arrow:ClearAllPoints();
        arrow:SetPoint("RIGHT", dropdown, "RIGHT", -18, 0);
        arrow:SetWidth(22);
        arrow:SetHeight(22);
    end

    if (not dropdown.DFMoonUnderlay) then
        dropdown.DFMoonUnderlay = MakeTexture(dropdown, "BACKGROUND", 0.010, 0.025, 0.055, 0.98);
        dropdown.DFMoonUnderlay:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 16, -3);
        dropdown.DFMoonUnderlay:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -16, 3);
        dropdown.DFMoonBorder = MakeTexture(dropdown, "BORDER", 0.13, 0.42, 0.68, 0.62);
        dropdown.DFMoonBorder:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 17, -4);
        dropdown.DFMoonBorder:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -17, 4);
    end
end

local function StyleCheck(check)
    if (not check) then return; end
    check:SetScale(0.86);
    local regions = { check:GetRegions() };
    local count = table.getn(regions);
    local index;
    for index = 1, count, 1 do
        local region = regions[index];
        if (region and region.GetObjectType and region:GetObjectType() == "FontString") then
            DebuffFilter_SetUIFont(region, 13, "OUTLINE");
            region:SetTextColor(0.86, 0.94, 1.00);
        end
    end
end

local function SkinMonitorBackdrop(frameName)
    local backdrop = getglobal(frameName);
    if (not backdrop) then return; end
    if (backdrop.SetBackdropColor) then backdrop:SetBackdropColor(0.02, 0.03, 0.06, 0.82); end
    if (backdrop.SetBackdropBorderColor) then backdrop:SetBackdropBorderColor(0.12, 0.48, 0.80, 0.92); end
    local regions = { backdrop:GetRegions() };
    local count = table.getn(regions);
    local index;
    for index = 1, count, 1 do
        local region = regions[index];
        if (region and region.GetObjectType and region:GetObjectType() == "FontString") then
            region:SetTextColor(0.38, 0.82, 1.00);
            DebuffFilter_SetUIFont(region, 12, "OUTLINE");
        end
    end
end

function MoonUI.SkinMonitorFrames()
    SkinMonitorBackdrop("DebuffFilter_BuffFrameBackdrop");
    SkinMonitorBackdrop("DebuffFilter_PlayerDebuffFrameBackdrop");
    SkinMonitorBackdrop("DebuffFilter_DebuffFrameBackdrop");
    SkinMonitorBackdrop("DebuffFilter_CurrentTargetBuffFrameBackdrop");
    SkinMonitorBackdrop("DebuffFilter_TargetSpellFrameBackdrop");
    SkinMonitorBackdrop("DebuffFilter_TargetBuffFrameBackdrop");
    SkinMonitorBackdrop("DebuffFilter_MultiTargetDebuffFrameBackdrop");
end

local function HideLegacyFrameRegions(frame)
    local regions = { frame:GetRegions() };
    local count = table.getn(regions);
    local index;
    for index = 1, count, 1 do
        local region = regions[index];
        if (region and region.GetObjectType) then
            local objectType = region:GetObjectType();
            local objectName = region.GetName and region:GetName() or nil;
            if (objectType == "Texture") then
                region:Hide();
            elseif (objectType == "FontString") then
                if (objectName ~= "DebuffFilter_ManagerStatus"
                    and objectName ~= "DebuffFilter_ManagerScanLabel"
                    and objectName ~= "DebuffFilter_ManagerDurationLabel"
                    and objectName ~= "DebuffFilter_ManagerSecondsLabel") then
                    region:Hide();
                end
            end
        end
    end

    local children = { frame:GetChildren() };
    count = table.getn(children);
    for index = 1, count, 1 do
        local child = children[index];
        if (child and child.GetObjectType and child:GetObjectType() == "Button"
            and (not child.GetName or not child:GetName())) then
            child:Hide();
        end
    end
end

local function MakeTab(frame, key, label, index)
    local button = CreateFrame("Button", "DebuffFilter_MoonTab" .. index, frame);
    button:SetWidth(124);
    button:SetHeight(28);
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 20 + (index - 1) * 130, -45);
    button.DFMoonBackground = MakeTexture(button, "BACKGROUND", COLOR_BLUE[1], COLOR_BLUE[2], COLOR_BLUE[3], COLOR_BLUE[4]);
    button.DFMoonBackground:SetAllPoints(button);
    button.DFMoonBorder = MakeTexture(button, "BORDER", 0.18, 0.42, 0.68, 0.52);
    button.DFMoonBorder:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1);
    button.DFMoonBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1);
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    button.text:SetPoint("CENTER", button, "CENTER", 0, 0);
    DebuffFilter_SetUIFont(button.text, 12, "OUTLINE");
    button.text:SetTextColor(0.84, 0.94, 1.00);
    button.text:SetText(label);
    button:SetScript("OnClick", function() MoonUI.SetTab(key); end);
    TAB_BUTTONS[key] = button;
    return button;
end

local MONITOR_MODE_INFO = {
    buff = {
        group = "self",
        title = "我的增益",
        desc = "监视自己身上的指定增益效果，支持手工添加、删除和扫描自身。",
    },
    playerdebuff = {
        group = "self",
        title = "我的减益",
        desc = "监视自己身上的指定减益效果，可扫描当前自身减益。",
    },
    currenttargetbuff = {
        group = "target",
        title = "目标增益",
        desc = "只显示当前选中目标身上的指定增益；切换或取消目标后立即刷新。",
    },
    debuff = {
        group = "target",
        title = "目标减益",
        desc = "监视当前目标身上的指定减益，友方与敌方目标均可显示。",
    },
    targetbuff = {
        group = "team",
        title = "多人增益",
        desc = "追踪自己、小队和团队成员的指定增益；可独立使用普通图标或计时条。",
    },
    multidebuff = {
        group = "team",
        title = "多人减益",
        desc = "采集自己、小队和团队成员的指定减益数据；消失或驱散后自动清理。",
    },
}

local MONITOR_GROUP_INFO = {
    self = { label="自身", modes={ "buff", "playerdebuff" } },
    target = { label="当前目标", modes={ "currenttargetbuff", "debuff" } },
    team = { label="队伍／团队", modes={ "targetbuff", "multidebuff" } },
}

local function RefreshMonitorButtons()
    local key, button;
    for key, button in MONITOR_GROUP_BUTTONS do
        if (button and button.DFMoonBackground) then
            if (key == CURRENT_MONITOR_GROUP) then
                button.DFMoonBackground:SetTexture(COLOR_BLUE_ACTIVE[1], COLOR_BLUE_ACTIVE[2], COLOR_BLUE_ACTIVE[3], COLOR_BLUE_ACTIVE[4]);
                button.text:SetTextColor(1.00, 1.00, 1.00);
            else
                button.DFMoonBackground:SetTexture(COLOR_BLUE[1], COLOR_BLUE[2], COLOR_BLUE[3], COLOR_BLUE[4]);
                button.text:SetTextColor(0.70, 0.84, 0.96);
            end
        end
    end
    local index;
    for index = 1, 2, 1 do
        button = MONITOR_SUB_BUTTONS[index];
        if (button and button.DFMoonBackground) then
            if (button.mode == CURRENT_MONITOR_MODE) then
                button.DFMoonBackground:SetTexture(COLOR_BLUE_ACTIVE[1], COLOR_BLUE_ACTIVE[2], COLOR_BLUE_ACTIVE[3], COLOR_BLUE_ACTIVE[4]);
                button.text:SetTextColor(1.00, 1.00, 1.00);
            else
                button.DFMoonBackground:SetTexture(COLOR_BLUE[1], COLOR_BLUE[2], COLOR_BLUE[3], COLOR_BLUE[4]);
                button.text:SetTextColor(0.70, 0.84, 0.96);
            end
        end
    end
end

local function UpdateMonitorSubButtons(groupName)
    local group = MONITOR_GROUP_INFO[groupName];
    if (not group) then return; end
    local index;
    for index = 1, 2, 1 do
        local button = MONITOR_SUB_BUTTONS[index];
        local mode = group.modes[index];
        if (button and mode and MONITOR_MODE_INFO[mode]) then
            button.mode = mode;
            button.text:SetText(MONITOR_MODE_INFO[mode].title);
            button:Show();
        elseif (button) then
            button.mode = nil;
            button:Hide();
        end
    end
end

function MoonUI.SetMonitorMode(mode)
    if (not MONITOR_MODE_INFO[mode]) then mode = "debuff"; end
    local info = MONITOR_MODE_INFO[mode];
    CURRENT_MONITOR_MODE = mode;
    CURRENT_MONITOR_GROUP = info.group;
    UpdateMonitorSubButtons(CURRENT_MONITOR_GROUP);
    if (type(DebuffFilter_Manager_SelectMode) == "function") then
        DebuffFilter_Manager_SelectMode(mode);
    end
    if (MONITOR_PAGE_TITLE) then MONITOR_PAGE_TITLE:SetText(info.title); end
    if (MONITOR_PAGE_DESC) then MONITOR_PAGE_DESC:SetText(info.desc); end
    RefreshMonitorButtons();
end

function MoonUI.SetMonitorGroup(groupName)
    local group = MONITOR_GROUP_INFO[groupName];
    if (not group) then groupName = "target"; group = MONITOR_GROUP_INFO[groupName]; end
    CURRENT_MONITOR_GROUP = groupName;
    local mode = CURRENT_MONITOR_MODE;
    if (not MONITOR_MODE_INFO[mode] or MONITOR_MODE_INFO[mode].group ~= groupName) then
        mode = group.modes[1];
    end
    MoonUI.SetMonitorMode(mode);
end

local function MakeMonitorGroupButton(frame, groupName, label, index)
    local button = CreateFrame("Button", "DebuffFilter_MoonMonitorGroup" .. index, frame);
    button:SetWidth(132);
    button:SetHeight(36);
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 35, -132 - (index - 1) * 48);
    button.DFMoonBackground = MakeTexture(button, "BACKGROUND", COLOR_BLUE[1], COLOR_BLUE[2], COLOR_BLUE[3], COLOR_BLUE[4]);
    button.DFMoonBackground:SetAllPoints(button);
    button.DFMoonBorder = MakeTexture(button, "BORDER", 0.18, 0.42, 0.68, 0.52);
    button.DFMoonBorder:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1);
    button.DFMoonBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1);
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    button.text:SetPoint("CENTER", button, "CENTER", 0, 0);
    DebuffFilter_SetUIFont(button.text, 12, "OUTLINE");
    button.text:SetTextColor(0.76, 0.90, 1.00);
    button.text:SetText(label);
    button:SetScript("OnClick", function() MoonUI.SetMonitorGroup(groupName); end);
    MONITOR_GROUP_BUTTONS[groupName] = button;
    AddToGroup("monitor", button);
    return button;
end

local function MakeMonitorSubButton(frame, index)
    local button = CreateFrame("Button", "DebuffFilter_MoonMonitorSub" .. index, frame);
    button:SetWidth(150);
    button:SetHeight(29);
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 198 + (index - 1) * 160, -101);
    button.DFMoonBackground = MakeTexture(button, "BACKGROUND", COLOR_BLUE[1], COLOR_BLUE[2], COLOR_BLUE[3], COLOR_BLUE[4]);
    button.DFMoonBackground:SetAllPoints(button);
    button.DFMoonBorder = MakeTexture(button, "BORDER", 0.18, 0.42, 0.68, 0.52);
    button.DFMoonBorder:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1);
    button.DFMoonBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1);
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    button.text:SetPoint("CENTER", button, "CENTER", 0, 0);
    DebuffFilter_SetUIFont(button.text, 12, "OUTLINE");
    button.text:SetTextColor(0.76, 0.90, 1.00);
    button:SetScript("OnClick", function()
        if (this.mode) then MoonUI.SetMonitorMode(this.mode); end
    end);
    MONITOR_SUB_BUTTONS[index] = button;
    AddToGroup("monitor", button);
    return button;
end

local function RefreshTabButtons()
    local key, button;
    for key, button in TAB_BUTTONS do
        if (button and button.DFMoonBackground) then
            if (key == CURRENT_TAB) then
                button.DFMoonBackground:SetTexture(COLOR_BLUE_ACTIVE[1], COLOR_BLUE_ACTIVE[2], COLOR_BLUE_ACTIVE[3], COLOR_BLUE_ACTIVE[4]);
                button.text:SetTextColor(1.00, 1.00, 1.00);
            else
                button.DFMoonBackground:SetTexture(COLOR_BLUE[1], COLOR_BLUE[2], COLOR_BLUE[3], COLOR_BLUE[4]);
                button.text:SetTextColor(0.72, 0.86, 0.96);
            end
        end
    end
end

local function HideAllPageGroups()
    local groupName, group;
    for groupName, group in GROUPS do
        if (groupName ~= "common") then
            local index;
            for index = 1, table.getn(group), 1 do HideObject(group[index]); end
        end
    end
end

local function RestoreMonitorMode()
    local mode = CURRENT_MONITOR_MODE or "debuff";
    MoonUI.SetMonitorMode(mode);
end

function MoonUI.SetTab(tabName)
    if (not GROUPS[tabName]) then tabName = "monitor"; end
    CURRENT_TAB = tabName;
    HideAllPageGroups();

    local group = GROUPS[tabName];
    local index;
    for index = 1, table.getn(group), 1 do ShowObject(group[index]); end

    if (tabName == "monitor") then RestoreMonitorMode(); end
    if (tabName == "timer" and type(MoonUI.SetTimerPage) == "function") then MoonUI.SetTimerPage(CURRENT_TIMER_PAGE); end
    if (tabName == "spell" and type(MoonUI.SetSpellPage) == "function") then MoonUI.SetSpellPage(CURRENT_SPELL_PAGE); end
    RefreshTabButtons();
end

local function PositionMonitorControls(frame)
    local modeDrop = getglobal("DebuffFilter_ManagerModeDropDown");
    local nameEdit = getglobal("DebuffFilter_ManagerNameEdit");
    local addButton = getglobal("DebuffFilter_ManagerAddButton");
    local listDrop = getglobal("DebuffFilter_ManagerListDropDown");
    local deleteButton = getglobal("DebuffFilter_ManagerDeleteButton");
    local scanLabel = getglobal("DebuffFilter_ManagerScanLabel");
    local scanDrop = getglobal("DebuffFilter_ManagerScanDropDown");
    local scanButton = getglobal("DebuffFilter_ManagerScanButton");
    local durationLabel = getglobal("DebuffFilter_ManagerDurationLabel");
    local durationEdit = getglobal("DebuffFilter_ManagerDurationEdit");
    local secondsLabel = getglobal("DebuffFilter_ManagerSecondsLabel");
    local durationSet = getglobal("DebuffFilter_ManagerDurationSet");
    local durationClear = getglobal("DebuffFilter_ManagerDurationClear");

    if (modeDrop) then modeDrop:Hide(); end

    local section = MakeLabel(frame, "DebuffFilter_MoonMonitorSection", "监视对象", 35, -98, 132, 13, 0.28, 0.78, 1.00);
    section:SetJustifyH("CENTER");
    MakeMonitorGroupButton(frame, "self", "自身", 1);
    MakeMonitorGroupButton(frame, "target", "当前目标", 2);
    MakeMonitorGroupButton(frame, "team", "队伍／团队", 3);
    MakeMonitorSubButton(frame, 1);
    MakeMonitorSubButton(frame, 2);

    MONITOR_PAGE_TITLE = MakeLabel(frame, "DebuffFilter_MoonMonitorTitle", "目标减益", 198, -143, 300, 15, 0.28, 0.78, 1.00);
    MONITOR_PAGE_DESC = MakeLabel(frame, "DebuffFilter_MoonMonitorDesc", "", 198, -167, 448, 11, 0.58, 0.74, 0.88);
    MONITOR_PAGE_DESC:SetHeight(28);
    MONITOR_PAGE_DESC:SetJustifyV("TOP");

    local nameLabel = MakeLabel(frame, nil, "技能名称", 198, -211, 78, 12);
    local listLabel = MakeLabel(frame, nil, "已监视", 198, -260, 78, 12);

    SetObjectPoint(nameEdit, "TOPLEFT", frame, "TOPLEFT", 282, -199);
    nameEdit:SetWidth(235);
    nameEdit:SetHeight(24);
    SetObjectPoint(addButton, "TOPLEFT", frame, "TOPLEFT", 540, -199);
    addButton:SetWidth(105);
    addButton:SetHeight(25);

    SetObjectPoint(listDrop, "TOPLEFT", frame, "TOPLEFT", 266, -244);
    listDrop:SetWidth(270);
    listDrop:SetHeight(30);
    UIDropDownMenu_SetWidth(238, listDrop);
    SetObjectPoint(deleteButton, "TOPLEFT", frame, "TOPLEFT", 540, -248);
    deleteButton:SetWidth(105);
    deleteButton:SetHeight(25);

    SetObjectPoint(scanLabel, "TOPLEFT", frame, "TOPLEFT", 198, -309);
    scanLabel:SetWidth(78);
    DebuffFilter_SetUIFont(scanLabel, 12, "OUTLINE");
    scanLabel:SetTextColor(0.78, 0.90, 1.00);
    SetObjectPoint(scanDrop, "TOPLEFT", frame, "TOPLEFT", 266, -293);
    scanDrop:SetWidth(270);
    scanDrop:SetHeight(30);
    UIDropDownMenu_SetWidth(238, scanDrop);
    SetObjectPoint(scanButton, "TOPLEFT", frame, "TOPLEFT", 540, -297);
    scanButton:SetWidth(105);
    scanButton:SetHeight(25);

    SetObjectPoint(durationLabel, "TOPLEFT", frame, "TOPLEFT", 198, -365);
    durationLabel:SetWidth(78);
    DebuffFilter_SetUIFont(durationLabel, 12, "OUTLINE");
    durationLabel:SetTextColor(0.78, 0.90, 1.00);
    SetObjectPoint(durationEdit, "TOPLEFT", frame, "TOPLEFT", 282, -353);
    durationEdit:SetWidth(76);
    durationEdit:SetHeight(24);
    SetObjectPoint(secondsLabel, "TOPLEFT", frame, "TOPLEFT", 365, -365);
    DebuffFilter_SetUIFont(secondsLabel, 12, "OUTLINE");
    secondsLabel:SetTextColor(0.78, 0.90, 1.00);
    SetObjectPoint(durationSet, "TOPLEFT", frame, "TOPLEFT", 398, -353);
    durationSet:SetWidth(102);
    durationSet:SetHeight(25);
    SetObjectPoint(durationClear, "TOPLEFT", frame, "TOPLEFT", 512, -353);
    durationClear:SetWidth(112);
    durationClear:SetHeight(25);

    StyleDropDown(listDrop);
    StyleDropDown(scanDrop);
    StyleEditBox(nameEdit);
    StyleEditBox(durationEdit);
    StyleButton(addButton, COLOR_GREEN);
    StyleButton(deleteButton, COLOR_RED);
    StyleButton(scanButton, COLOR_BLUE_ACTIVE);
    StyleButton(durationSet, COLOR_GREEN);
    StyleButton(durationClear, COLOR_AMBER);

    AddToGroup("monitor", section);
    AddToGroup("monitor", MONITOR_PAGE_TITLE);
    AddToGroup("monitor", MONITOR_PAGE_DESC);
    AddToGroup("monitor", nameLabel);
    AddToGroup("monitor", listLabel);
    AddToGroup("monitor", nameEdit);
    AddToGroup("monitor", addButton);
    AddToGroup("monitor", listDrop);
    AddToGroup("monitor", deleteButton);
    AddToGroup("monitor", scanLabel);
    AddToGroup("monitor", scanDrop);
    AddToGroup("monitor", scanButton);
    AddToGroup("monitor", durationLabel);
    AddToGroup("monitor", durationEdit);
    AddToGroup("monitor", secondsLabel);
    AddToGroup("monitor", durationSet);
    AddToGroup("monitor", durationClear);
end

local function PositionDisplayControls(frame)
    local playerAuras = getglobal("DebuffFilter_ManagerPlayerAurasCheck");
    local targetDebuffs = getglobal("DebuffFilter_ManagerDebuffCheck");
    local currentTargetBuffs = getglobal("DebuffFilter_ManagerCurrentTargetBuffCheck");
    local buffs = getglobal("DebuffFilter_ManagerBuffCheck");
    local playerDebuffs = getglobal("DebuffFilter_ManagerPlayerDebuffCheck");
    local timers = getglobal("DebuffFilter_ManagerTimerCheck");
    local tooltips = getglobal("DebuffFilter_ManagerTooltipCheck");
    local count = getglobal("DebuffFilter_ManagerCountCheck");
    local targetBuffs = getglobal("DebuffFilter_ManagerTargetBuffCheck");
    local multiTargetDebuffs = getglobal("DebuffFilter_ManagerMultiTargetDebuffCheck");
    local onlyMineAuras = getglobal("DebuffFilter_ManagerOnlyMineAurasCheck");
    local scaleDrop = getglobal("DebuffFilter_ManagerScaleDropDown");

    local title = MakeLabel(frame, "DebuffFilter_MoonDisplayTitle", "显示与监视开关", 38, -94, 240, 14, 0.28, 0.78, 1.00);
    local scaleLabel = MakeLabel(frame, nil, "图标缩放", 352, -352, 80, 12);
    local hint = MakeLabel(frame, nil,
        "“只显示我施加”仅过滤目标/多人四组；自身增益与自身减益保持原逻辑。",
        42, -420, 600, 11, 0.58, 0.72, 0.84);

    SetObjectPoint(playerAuras, "TOPLEFT", frame, "TOPLEFT", 42, -142);
    SetObjectPoint(buffs, "TOPLEFT", frame, "TOPLEFT", 42, -190);
    SetObjectPoint(playerDebuffs, "TOPLEFT", frame, "TOPLEFT", 42, -238);

    SetObjectPoint(targetDebuffs, "TOPLEFT", frame, "TOPLEFT", 352, -142);
    SetObjectPoint(currentTargetBuffs, "TOPLEFT", frame, "TOPLEFT", 352, -184);
    SetObjectPoint(targetBuffs, "TOPLEFT", frame, "TOPLEFT", 352, -226);
    SetObjectPoint(multiTargetDebuffs, "TOPLEFT", frame, "TOPLEFT", 352, -268);
    SetObjectPoint(timers, "TOPLEFT", frame, "TOPLEFT", 352, -310);
    SetObjectPoint(tooltips, "TOPLEFT", frame, "TOPLEFT", 42, -286);
    SetObjectPoint(count, "TOPLEFT", frame, "TOPLEFT", 42, -328);
    SetObjectPoint(onlyMineAuras, "TOPLEFT", frame, "TOPLEFT", 42, -374);
    SetObjectPoint(scaleDrop, "TOPLEFT", frame, "TOPLEFT", 430, -336);
    UIDropDownMenu_SetWidth(90, scaleDrop);

    StyleCheck(playerAuras);
    StyleCheck(targetDebuffs);
    StyleCheck(currentTargetBuffs);
    StyleCheck(buffs);
    StyleCheck(playerDebuffs);
    StyleCheck(timers);
    StyleCheck(tooltips);
    StyleCheck(count);
    StyleCheck(targetBuffs);
    StyleCheck(multiTargetDebuffs);
    StyleCheck(onlyMineAuras);
    StyleDropDown(scaleDrop);

    AddToGroup("display", title);
    AddToGroup("display", scaleLabel);
    AddToGroup("display", hint);
    AddToGroup("display", playerAuras);
    AddToGroup("display", targetDebuffs);
    AddToGroup("display", currentTargetBuffs);
    AddToGroup("display", buffs);
    AddToGroup("display", playerDebuffs);
    AddToGroup("display", timers);
    AddToGroup("display", tooltips);
    AddToGroup("display", count);
    AddToGroup("display", targetBuffs);
    AddToGroup("display", multiTargetDebuffs);
    AddToGroup("display", onlyMineAuras);
    AddToGroup("display", scaleDrop);
end

local function TimerAddPageObject(pageName, object)
    if (not object) then return; end
    if (not TIMER_PAGE_OBJECTS[pageName]) then TIMER_PAGE_OBJECTS[pageName] = {}; end
    table.insert(TIMER_PAGE_OBJECTS[pageName], object);
    AddToGroup("timer", object);
end

local function TimerSetStatus(message, isError)
    local status = getglobal("DebuffFilter_ManagerStatus");
    if (not status) then return; end
    status:SetText(message or "");
    if (isError) then status:SetTextColor(1.00, 0.25, 0.25); else status:SetTextColor(0.20, 1.00, 0.45); end
end

local function TimerResolveColor(value, fallbackName)
    if (type(value) == "table") then
        return tonumber(value[1]) or 1, tonumber(value[2]) or 1, tonumber(value[3]) or 1;
    end
    if (DebuffFilter_TimerBars and DebuffFilter_TimerBars.colorPresets) then
        local color = DebuffFilter_TimerBars.colorPresets[value] or DebuffFilter_TimerBars.colorPresets[fallbackName];
        if (color) then return color[1], color[2], color[3]; end
    end
    return 1, 1, 1;
end

local function TimerRefreshModeButtons()
    local group, buttons;
    for group, buttons in TIMER_MODE_BUTTONS do
        local current = type(DebuffFilter_GetAuraDisplayMode) == "function" and DebuffFilter_GetAuraDisplayMode(group) or "icon";
        local mode, button;
        for mode, button in buttons do
            if (button and button.DFMoonBackground) then
                if (mode == current) then
                    button.DFMoonBackground:SetTexture(COLOR_BLUE_ACTIVE[1], COLOR_BLUE_ACTIVE[2], COLOR_BLUE_ACTIVE[3], COLOR_BLUE_ACTIVE[4]);
                    button.text:SetTextColor(1, 1, 1);
                else
                    button.DFMoonBackground:SetTexture(COLOR_BLUE[1], COLOR_BLUE[2], COLOR_BLUE[3], COLOR_BLUE[4]);
                    button.text:SetTextColor(0.72, 0.86, 0.96);
                end
            end
        end
        local shine = TIMER_SHINE_BUTTONS[group];
        if (shine) then
            local enabled = type(DebuffFilter_GetAuraIconShine) == "function" and DebuffFilter_GetAuraIconShine(group);
            shine.text:SetText(enabled and "流光：开" or "流光：关");
            if (shine.DFMoonBackground) then
                local color = enabled and COLOR_GREEN or COLOR_RED;
                shine.DFMoonBackground:SetTexture(color[1], color[2], color[3], color[4]);
            end
            if (CURRENT_TAB == "timer" and CURRENT_TIMER_PAGE == "modes" and current == "icon") then shine:Show(); else shine:Hide(); end
        end
    end
end

local function TimerSetMode(group, mode)
    if (type(DebuffFilter_SetAuraDisplayMode) ~= "function") then
        TimerSetStatus("计时条模块尚未初始化。", true);
        return;
    end
    if (DebuffFilter_SetAuraDisplayMode(group, mode)) then
        local label = DebuffFilter_TimerBars and DebuffFilter_TimerBars.groupInfo and DebuffFilter_TimerBars.groupInfo[group] and DebuffFilter_TimerBars.groupInfo[group].label or group;
        local modeText = mode == "bar" and "计时条" or (mode == "off" and "关闭" or "图标框");
        TimerSetStatus(tostring(label) .. " 已切换为：" .. modeText);
        TimerRefreshModeButtons();
    end
end

local function TimerCreateShineButton(frame, group, x, y)
    local safeGroup = string.gsub(group, "_", "");
    local button = CreateFrame("Button", "DebuffFilter_TimerShine_" .. safeGroup, frame);
    button:SetWidth(80);
    button:SetHeight(27);
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y);
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    button.text:SetPoint("CENTER", button, "CENTER", 0, 0);
    DebuffFilter_SetUIFont(button.text, 10, "OUTLINE");
    button.text:SetText("流光：关");
    button:SetScript("OnClick", function()
        if (type(DebuffFilter_SetAuraIconShine) ~= "function") then TimerSetStatus("图标流光模块尚未初始化。", true); return; end
        local enabled = type(DebuffFilter_GetAuraIconShine) == "function" and DebuffFilter_GetAuraIconShine(group);
        DebuffFilter_SetAuraIconShine(group, not enabled);
        local label = DebuffFilter_TimerBars and DebuffFilter_TimerBars.groupInfo and DebuffFilter_TimerBars.groupInfo[group] and DebuffFilter_TimerBars.groupInfo[group].label or group;
        TimerSetStatus(tostring(label) .. " 图标流光：" .. (enabled and "关闭" or "开启"));
        TimerRefreshModeButtons();
    end);
    StyleButton(button, COLOR_RED);
    TIMER_SHINE_BUTTONS[group] = button;
    TimerAddPageObject("modes", button);
    return button;
end

local function TimerCreateModeButton(frame, group, mode, text, x, y)
    local safeGroup = string.gsub(group, "_", "");
    local button = CreateFrame("Button", "DebuffFilter_TimerMode_" .. safeGroup .. "_" .. mode, frame);
    button:SetWidth(105);
    button:SetHeight(27);
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y);
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    button.text:SetPoint("CENTER", button, "CENTER", 0, 0);
    DebuffFilter_SetUIFont(button.text, 11, "OUTLINE");
    button.text:SetText(text);
    button:SetScript("OnClick", function() TimerSetMode(group, mode); end);
    StyleButton(button, COLOR_BLUE);
    if (not TIMER_MODE_BUTTONS[group]) then TIMER_MODE_BUTTONS[group] = {}; end
    TIMER_MODE_BUTTONS[group][mode] = button;
    TimerAddPageObject("modes", button);
    return button;
end

local function TimerCreateEdit(frame, name, x, y, width)
    local edit = CreateFrame("EditBox", name, frame, "InputBoxTemplate");
    edit:SetWidth(width);
    edit:SetHeight(24);
    edit:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y);
    edit:SetAutoFocus(false);
    edit:SetMaxLetters(48);
    edit:SetScript("OnEscapePressed", function() this:ClearFocus(); end);
    edit:SetScript("OnEnterPressed", function() this:ClearFocus(); TimerApplyStyle(); end);
    StyleEditBox(edit);
    return edit;
end

local function TimerSetDropText(dropdown, text)
    if (not dropdown) then return; end
    local region = getglobal(dropdown:GetName() .. "Text");
    if (region) then region:SetText(text or ""); end
end

local function TimerCreateDropDown(frame, name, x, y, width, items, onSelect)
    local dropdown = CreateFrame("Button", name, frame, "UIDropDownMenuTemplate");
    dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y);
    dropdown:SetWidth(width + 32);
    dropdown:SetHeight(30);
    UIDropDownMenu_SetWidth(width, dropdown);
    dropdown.DFTimerItems = items;
    dropdown.DFTimerOnSelect = onSelect;
    UIDropDownMenu_Initialize(dropdown, function()
        local index;
        for index = 1, table.getn(dropdown.DFTimerItems or {}), 1 do
            local entry = dropdown.DFTimerItems[index];
            local info = {};
            if (type(entry) == "table") then
                info.text = entry.text;
                info.value = entry.value;
            else
                info.text = tostring(entry);
                info.value = entry;
            end
            info.func = (function(selectedValue, selectedText)
                return function()
                    TimerSetDropText(dropdown, selectedText);
                    if (dropdown.DFTimerOnSelect) then dropdown.DFTimerOnSelect(selectedValue); end
                end
            end)(info.value, info.text);
            UIDropDownMenu_AddButton(info, 1);
        end
    end);
    StyleDropDown(dropdown);
    return dropdown;
end

local function TimerCopyTable(source)
    if (type(source) ~= "table") then return source; end
    local result = {};
    local key, value;
    for key, value in source do
        if (type(value) == "table") then result[key] = TimerCopyTable(value); else result[key] = value; end
    end
    return result;
end

local function TimerGetConfig()
    return type(DebuffFilter_TimerBars_GetConfig) == "function" and DebuffFilter_TimerBars_GetConfig() or nil;
end

local function TimerGetAllStyleTargets()
    return { "player_buff", "player_debuff", "target_buff", "target_debuff", "multi_buff", "multi_debuff" };
end

local function TimerGetStyleTargetItems()
    if (type(DebuffFilter_TimerBars_GetStyleTargets) == "function") then return DebuffFilter_TimerBars_GetStyleTargets(); end
    return {
        { text="全部", value="all" },
        { text="我的增益", value="player_buff" }, { text="我的减益", value="player_debuff" },
        { text="目标增益", value="target_buff" }, { text="目标减益", value="target_debuff" },
        { text="多人增益", value="multi_buff" }, { text="多人减益", value="multi_debuff" },
    };
end

local function TimerGetStyleTargetLabel(value)
    local items = TimerGetStyleTargetItems();
    local index;
    for index = 1, table.getn(items), 1 do
        if (items[index].value == value) then return items[index].text; end
    end
    return "全部";
end

local function TimerGetSelectedStyleTargets()
    if (CURRENT_TIMER_STYLE_TARGET and CURRENT_TIMER_STYLE_TARGET ~= "all") then return { CURRENT_TIMER_STYLE_TARGET }; end
    return TimerGetAllStyleTargets();
end

local function TimerSyncGlobalStyleFromGroup(group)
    local config = TimerGetConfig();
    if (not config or type(config["timer_bar_group_styles"]) ~= "table") then return; end
    local style = config["timer_bar_group_styles"][group];
    if (type(style) ~= "table") then return; end
    config["timer_bar_settings"] = TimerCopyTable(style);
end

local function TimerGetStyle()
    local config = TimerGetConfig();
    if (not config) then return nil; end
    if (CURRENT_TIMER_STYLE_TARGET == "all") then return config["timer_bar_settings"] or nil; end
    if (type(config["timer_bar_group_styles"]) == "table" and type(config["timer_bar_group_styles"][CURRENT_TIMER_STYLE_TARGET]) == "table") then
        return config["timer_bar_group_styles"][CURRENT_TIMER_STYLE_TARGET];
    end
    return config["timer_bar_settings"] or nil;
end

local function TimerSetStyleValue(key, value)
    local config = TimerGetConfig();
    if (not config) then return; end
    local store = type(config["timer_bar_group_styles"]) == "table" and config["timer_bar_group_styles"] or nil;
    local targets = TimerGetSelectedStyleTargets();
    local index;
    for index = 1, table.getn(targets), 1 do
        local group = targets[index];
        if (store and type(store[group]) == "table") then
            store[group][key] = type(value) == "table" and TimerCopyTable(value) or value;
        end
    end
    if (CURRENT_TIMER_STYLE_TARGET == "all") then
        if (type(config["timer_bar_settings"]) ~= "table") then config["timer_bar_settings"] = {}; end
        config["timer_bar_settings"][key] = type(value) == "table" and TimerCopyTable(value) or value;
    end
end

local function TimerIsCustomTexture(value)
    return string.find(tostring(value or ""), "^DF_Large") ~= nil;
end

local function TimerRefreshColorButton(button, key, fallbackName)
    if (not button or not button.swatch) then return; end
    local style = TimerGetStyle();
    local r, g, b = TimerResolveColor(style and style[key], fallbackName);
    button.swatch:SetTexture(r, g, b, 1);
end

local function TimerOpenColorPicker(key, button, fallbackName)
    local style = TimerGetStyle();
    if (not style or not ColorPickerFrame) then return; end
    local oldR, oldG, oldB = TimerResolveColor(style[key], fallbackName);
    local oldValue = { oldR, oldG, oldB, 1 };
    ColorPickerFrame.hasOpacity = false;
    ColorPickerFrame.opacity = 0;
    ColorPickerFrame.previousValues = oldValue;
    ColorPickerFrame.func = function()
        local r, g, b = ColorPickerFrame:GetColorRGB();
        TimerSetStyleValue(key, { r, g, b, 1 });
        TimerRefreshColorButton(button, key, fallbackName);
        if (type(DebuffFilter_TimerBars_Refresh) == "function") then DebuffFilter_TimerBars_Refresh(); end
    end;
    ColorPickerFrame.cancelFunc = function()
        TimerSetStyleValue(key, { oldValue[1], oldValue[2], oldValue[3], oldValue[4] });
        TimerRefreshColorButton(button, key, fallbackName);
        if (type(DebuffFilter_TimerBars_Refresh) == "function") then DebuffFilter_TimerBars_Refresh(); end
    end;
    ColorPickerFrame:SetColorRGB(oldR, oldG, oldB);
    ColorPickerFrame:Show();
end

local function TimerCreateColorButton(frame, name, text, key, fallbackName, x, y)
    local button = CreateFrame("Button", name, frame);
    button:SetWidth(170);
    button:SetHeight(28);
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y);
    button.swatch = button:CreateTexture(nil, "ARTWORK");
    button.swatch:SetPoint("LEFT", button, "LEFT", 8, 0);
    button.swatch:SetWidth(24);
    button.swatch:SetHeight(16);
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    button.text:SetPoint("LEFT", button, "LEFT", 42, 0);
    DebuffFilter_SetUIFont(button.text, 11, "OUTLINE");
    button.text:SetText(text);
    button:SetScript("OnClick", function() TimerOpenColorPicker(key, button, fallbackName); end);
    StyleButton(button, COLOR_BLUE);
    TIMER_COLOR_BUTTONS[key] = button;
    return button;
end

local function TimerCreateCheck(frame, name, text, key, x, y, width)
    -- Custom compact on/off control.  No UICheckButtonTemplate is used, so the
    -- classic-client checked texture can never stretch into a giant yellow mark.
    local container = CreateFrame("Frame", name .. "Container", frame);
    container:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y);
    container:SetWidth(width or 190);
    container:SetHeight(24);

    local toggle = CreateFrame("Button", name, container);
    toggle:SetPoint("LEFT", container, "LEFT", 0, 0);
    toggle:SetWidth(48);
    toggle:SetHeight(22);
    toggle.text = toggle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    toggle.text:SetPoint("CENTER", toggle, "CENTER", 0, 0);
    DebuffFilter_SetUIFont(toggle.text, 11, "OUTLINE");
    StyleButton(toggle, COLOR_BLUE);

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    label:SetPoint("LEFT", toggle, "RIGHT", 8, 0);
    label:SetWidth((width or 190) - 58);
    label:SetHeight(22);
    label:SetJustifyH("LEFT");
    label:SetJustifyV("MIDDLE");
    DebuffFilter_SetUIFont(label, 11, "OUTLINE");
    label:SetTextColor(0.86, 0.94, 1.00);
    label:SetText(text);

    toggle.DFTimerKey = key;
    function toggle:DFTimerSetState(enabled)
        self.DFTimerEnabled = enabled and true or false;
        if (self.DFTimerEnabled) then
            self.text:SetText("开");
            self.DFMoonBackground:SetTexture(COLOR_GREEN[1], COLOR_GREEN[2], COLOR_GREEN[3], COLOR_GREEN[4]);
        else
            self.text:SetText("关");
            self.DFMoonBackground:SetTexture(COLOR_RED[1], COLOR_RED[2], COLOR_RED[3], COLOR_RED[4]);
        end
    end
    toggle:SetScript("OnClick", function()
        local style = TimerGetStyle();
        if (not style) then return; end
        local enabled = style[this.DFTimerKey] ~= "yes";
        TimerSetStyleValue(this.DFTimerKey, enabled and "yes" or "no");
        this:DFTimerSetState(enabled);
        if (type(DebuffFilter_TimerBars_Refresh) == "function") then DebuffFilter_TimerBars_Refresh(); end
    end);
    TIMER_STYLE_CHECKS[key] = toggle;
    return container;
end

function TimerApplyStyle()
    local style = TimerGetStyle();
    if (not style) then TimerSetStatus("计时条设置尚未初始化。", true); return; end
    local numberKeys = { "width", "height", "scale", "spacing", "text_size", "ghost", "background_alpha" };
    local index;
    for index = 1, table.getn(numberKeys), 1 do
        local key = numberKeys[index];
        local edit = TIMER_STYLE_EDITS[key];
        if (edit) then
            local value = tonumber(edit:GetText());
            if (value) then TimerSetStyleValue(key, value); end
        end
    end
    if (TIMER_STYLE_EDITS.text_template) then
        local value = TIMER_STYLE_EDITS.text_template:GetText();
        if (value and value ~= "") then TimerSetStyleValue("text_template", value); end
    end
    if (type(DebuffFilter_TimerBars_GetConfig) == "function") then DebuffFilter_TimerBars_GetConfig(); end
    if (type(DebuffFilter_TimerBars_Refresh) == "function") then DebuffFilter_TimerBars_Refresh(); end
    TimerRefreshStyleControls();
    TimerSetStatus("计时条样式已应用到【" .. TimerGetStyleTargetLabel(CURRENT_TIMER_STYLE_TARGET) .. "】。$s=技能名，$t=目标名。");
end

function TimerRefreshStyleControls()
    local style = TimerGetStyle();
    if (not style) then return; end
    local key, edit;
    for key, edit in TIMER_STYLE_EDITS do
        if (key == "text_template") then edit:SetText(tostring(style[key] or "$s  $t")); else edit:SetText(tostring(style[key] or "")); end
    end
    local displayName = type(DebuffFilter_TimerBars_GetTextureDisplayName) == "function" and DebuffFilter_TimerBars_GetTextureDisplayName(style.texture) or tostring(style.texture);
    if (TIMER_STYLE_DROPS.texture_legacy) then TimerSetDropText(TIMER_STYLE_DROPS.texture_legacy, TimerIsCustomTexture(style.texture) and "旧纹理" or displayName); end
    if (TIMER_STYLE_DROPS.texture_custom) then TimerSetDropText(TIMER_STYLE_DROPS.texture_custom, TimerIsCustomTexture(style.texture) and displayName or "新纹理"); end
    if (TIMER_STYLE_DROPS.grow_up) then TimerSetDropText(TIMER_STYLE_DROPS.grow_up, style.grow_up == "yes" and "向上堆叠" or "向下堆叠"); end
    if (TIMER_STYLE_DROPS.apply_target) then TimerSetDropText(TIMER_STYLE_DROPS.apply_target, TimerGetStyleTargetLabel(CURRENT_TIMER_STYLE_TARGET)); end
    for key, edit in TIMER_STYLE_CHECKS do if (edit.DFTimerSetState) then edit:DFTimerSetState(style[key] == "yes"); end end
    TimerRefreshColorButton(TIMER_COLOR_BUTTONS.bar_color, "bar_color", "灰色");
    TimerRefreshColorButton(TIMER_COLOR_BUTTONS.background_color, "background_color", "青色");
    TimerRefreshColorButton(TIMER_COLOR_BUTTONS.text_color, "text_color", "白色");
end

local function TimerRefreshSubButtons()
    local pageName, button;
    for pageName, button in TIMER_SUB_BUTTONS do
        if (button and button.DFMoonBackground) then
            if (pageName == CURRENT_TIMER_PAGE) then
                button.DFMoonBackground:SetTexture(COLOR_BLUE_ACTIVE[1], COLOR_BLUE_ACTIVE[2], COLOR_BLUE_ACTIVE[3], COLOR_BLUE_ACTIVE[4]);
                button.text:SetTextColor(1, 1, 1);
            else
                button.DFMoonBackground:SetTexture(COLOR_BLUE[1], COLOR_BLUE[2], COLOR_BLUE[3], COLOR_BLUE[4]);
                button.text:SetTextColor(0.72, 0.86, 0.96);
            end
        end
    end
end

function MoonUI.SetTimerPage(pageName)
    if (not TIMER_PAGE_OBJECTS[pageName]) then pageName = "modes"; end
    CURRENT_TIMER_PAGE = pageName;
    local currentName, objects, index;
    for currentName, objects in TIMER_PAGE_OBJECTS do
        for index = 1, table.getn(objects), 1 do
            if (CURRENT_TAB == "timer" and currentName == pageName) then ShowObject(objects[index]); else HideObject(objects[index]); end
        end
    end
    TimerRefreshSubButtons();
    TimerRefreshModeButtons();
    TimerRefreshStyleControls();
end

local function TimerCreateSubButton(frame, pageName, text, x)
    local button = CreateFrame("Button", "DebuffFilter_TimerSub_" .. pageName, frame);
    button:SetWidth(130);
    button:SetHeight(28);
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -96);
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    button.text:SetPoint("CENTER", button, "CENTER", 0, 0);
    DebuffFilter_SetUIFont(button.text, 11, "OUTLINE");
    button.text:SetText(text);
    button:SetScript("OnClick", function() MoonUI.SetTimerPage(pageName); end);
    StyleButton(button, COLOR_BLUE);
    TIMER_SUB_BUTTONS[pageName] = button;
    AddToGroup("timer", button);
    return button;
end

local function PositionTimerControls(frame)
    TimerCreateSubButton(frame, "modes", "显示分配", 35);
    TimerCreateSubButton(frame, "appearance", "外观样式", 175);
    TimerCreateSubButton(frame, "behavior", "行为设置", 315);

    -- Page 1: six independent output modes.
    local modeTitle = MakeLabel(frame, "DebuffFilter_TimerModeTitle", "六个光环区域独立选择显示方式", 42, -139, 430, 14, 0.28, 0.78, 1.00);
    local modeHint = MakeLabel(frame, nil, "六个光环区域可分别使用图标、计时条或关闭显示。", 42, -164, 610, 11, 0.58, 0.74, 0.88);
    TimerAddPageObject("modes", modeTitle);
    TimerAddPageObject("modes", modeHint);

    local rows = {
        { "player_buff", "我的增益" },
        { "player_debuff", "我的减益" },
        { "target_buff", "目标增益" },
        { "target_debuff", "目标减益" },
        { "multi_buff", "多人增益" },
        { "multi_debuff", "多人减益" },
    };
    local index;
    for index = 1, table.getn(rows), 1 do
        local y = -191 - (index - 1) * 39;
        local rowLabel = MakeLabel(frame, nil, rows[index][2], 50, y - 4, 105, 12, 0.82, 0.93, 1.00);
        TimerAddPageObject("modes", rowLabel);
        TimerCreateShineButton(frame, rows[index][1], 165, y);
        TimerCreateModeButton(frame, rows[index][1], "icon", "图标框", 255, y);
        TimerCreateModeButton(frame, rows[index][1], "bar", "计时条", 375, y);
        TimerCreateModeButton(frame, rows[index][1], "off", "关闭", 495, y);
    end
    local modeNote = MakeLabel(frame, nil, "多人增益／减益的图标模式为普通横向图标；不会恢复旧动态文字列表。", 42, -432, 610, 11, 0.58, 0.74, 0.88);
    TimerAddPageObject("modes", modeNote);

    -- Page 2: appearance.  Every row has its own vertical band to avoid template overlap.
    local styleTitle = MakeLabel(frame, "DebuffFilter_TimerStyleTitle", "CandyBar 双 StatusBar · 外观设置", 42, -139, 560, 14, 0.28, 0.78, 1.00);
    TimerAddPageObject("appearance", styleTitle);

    local legacyTextureItems = type(DebuffFilter_TimerBars_GetLegacyTextureNames) == "function" and DebuffFilter_TimerBars_GetLegacyTextureNames() or (type(DebuffFilter_TimerBars_GetTextureNames) == "function" and DebuffFilter_TimerBars_GetTextureNames() or { "Default", "Frost" });
    local customTextureItems = type(DebuffFilter_TimerBars_GetCustomTextureNames) == "function" and DebuffFilter_TimerBars_GetCustomTextureNames() or {};
    local textureDropLegacy = TimerCreateDropDown(frame, "DebuffFilter_TimerTextureLegacyDrop", 56, -159, 92, legacyTextureItems, function(value)
        TimerSetStyleValue("texture", value);
        if (type(DebuffFilter_TimerBars_Refresh) == "function") then DebuffFilter_TimerBars_Refresh(); end
        TimerRefreshStyleControls();
    end); TIMER_STYLE_DROPS.texture_legacy = textureDropLegacy; TimerAddPageObject("appearance", textureDropLegacy);
    local textureDropCustom = TimerCreateDropDown(frame, "DebuffFilter_TimerTextureCustomDrop", 186, -159, 92, customTextureItems, function(value)
        TimerSetStyleValue("texture", value);
        if (type(DebuffFilter_TimerBars_Refresh) == "function") then DebuffFilter_TimerBars_Refresh(); end
        TimerRefreshStyleControls();
    end); TIMER_STYLE_DROPS.texture_custom = textureDropCustom; TimerAddPageObject("appearance", textureDropCustom);

    local growDrop = TimerCreateDropDown(frame, "DebuffFilter_TimerGrowDrop", 360, -159, 120,
        { {text="向下堆叠", value="no"}, {text="向上堆叠", value="yes"} }, function(value)
            TimerSetStyleValue("grow_up", value);
            if (type(DebuffFilter_TimerBars_Refresh) == "function") then DebuffFilter_TimerBars_Refresh(); end
            TimerRefreshStyleControls();
        end); TIMER_STYLE_DROPS.grow_up = growDrop; TimerAddPageObject("appearance", growDrop);

    local barColor = TimerCreateColorButton(frame, "DebuffFilter_TimerBarColor", "进度颜色", "bar_color", "灰色", 42, -211);
    local bgColor = TimerCreateColorButton(frame, "DebuffFilter_TimerBgColor", "背景颜色", "background_color", "青色", 235, -211);
    local textColor = TimerCreateColorButton(frame, "DebuffFilter_TimerTextColor", "文字颜色", "text_color", "白色", 428, -211);
    local randomTop = TimerCreateCheck(frame, "DebuffFilter_TimerCheck_random_bar_color", "顶部颜色随机（按技能固定）", "random_bar_color", 42, -247, 220);
    TimerAddPageObject("appearance", barColor); TimerAddPageObject("appearance", bgColor); TimerAddPageObject("appearance", textColor); TimerAddPageObject("appearance", randomTop);

    local numeric = {
        { key="width", label="宽度", x=42, width=82 },
        { key="height", label="高度", x=155, width=82 },
        { key="scale", label="缩放", x=268, width=82 },
        { key="spacing", label="间距", x=381, width=82 },
        { key="text_size", label="字号", x=494, width=82 },
    };
    for index = 1, table.getn(numeric), 1 do
        local item = numeric[index];
        local label = MakeLabel(frame, nil, item.label, item.x, -290, item.width, 11);
        local edit = TimerCreateEdit(frame, "DebuffFilter_TimerEdit_" .. item.key, item.x, -311, item.width);
        TIMER_STYLE_EDITS[item.key] = edit;
        TimerAddPageObject("appearance", label); TimerAddPageObject("appearance", edit);
    end

    local ghostLabel = MakeLabel(frame, nil, "残影秒数", 42, -358, 82, 11);
    local ghostEdit = TimerCreateEdit(frame, "DebuffFilter_TimerEdit_ghost", 42, -379, 82); TIMER_STYLE_EDITS.ghost = ghostEdit;
    local alphaLabel = MakeLabel(frame, nil, "背景透明度", 155, -358, 88, 11);
    local alphaEdit = TimerCreateEdit(frame, "DebuffFilter_TimerEdit_background_alpha", 155, -379, 82); TIMER_STYLE_EDITS.background_alpha = alphaEdit;
    local templateLabel = MakeLabel(frame, nil, "文字格式（$s 技能名，$t 目标名）", 268, -358, 320, 11);
    local templateEdit = TimerCreateEdit(frame, "DebuffFilter_TimerEdit_text_template", 268, -379, 330); TIMER_STYLE_EDITS.text_template = templateEdit;
    TimerAddPageObject("appearance", ghostLabel); TimerAddPageObject("appearance", ghostEdit); TimerAddPageObject("appearance", alphaLabel);
    TimerAddPageObject("appearance", alphaEdit); TimerAddPageObject("appearance", templateLabel); TimerAddPageObject("appearance", templateEdit);

    local applyTargetLabel = MakeLabel(frame, nil, "应用到", 228, -425, 54, 11);
    local applyTargetDrop = TimerCreateDropDown(frame, "DebuffFilter_TimerApplyTargetDrop", 274, -422, 108, TimerGetStyleTargetItems(), function(value)
        if (value == "all") then
            if (CURRENT_TIMER_STYLE_TARGET and CURRENT_TIMER_STYLE_TARGET ~= "all") then TimerSyncGlobalStyleFromGroup(CURRENT_TIMER_STYLE_TARGET); end
            CURRENT_TIMER_STYLE_TARGET = "all";
        else
            CURRENT_TIMER_STYLE_TARGET = value;
        end
        TimerRefreshStyleControls();
    end);
    TIMER_STYLE_DROPS.apply_target = applyTargetDrop;
    local apply = CreateFrame("Button", "DebuffFilter_TimerApply", frame);
    apply:SetWidth(118); apply:SetHeight(27); apply:SetPoint("TOPLEFT", frame, "TOPLEFT", 410, -439);
    apply:SetText("应用并刷新"); apply:SetScript("OnClick", TimerApplyStyle); StyleButton(apply, COLOR_GREEN);
    local test = CreateFrame("Button", "DebuffFilter_TimerTest", frame);
    test:SetWidth(118); test:SetHeight(27); test:SetPoint("TOPLEFT", frame, "TOPLEFT", 540, -439); test:SetText("测试计时条");
    test:SetScript("OnClick", function()
        if (CURRENT_TIMER_STYLE_TARGET and CURRENT_TIMER_STYLE_TARGET ~= "all") then TimerSyncGlobalStyleFromGroup(CURRENT_TIMER_STYLE_TARGET); end
        if (type(DebuffFilter_TimerBars_RunTest) ~= "function") then TimerSetStatus("测试计时条未启动：模块尚未加载。", true); return; end
        local ok, message = DebuffFilter_TimerBars_RunTest();
        TimerSetStatus(message or (ok and "测试计时条已显示。" or "测试计时条启动失败。"), not ok);
    end); StyleButton(test, COLOR_BLUE_ACTIVE);
    TimerAddPageObject("appearance", applyTargetLabel); TimerAddPageObject("appearance", applyTargetDrop); TimerAddPageObject("appearance", apply); TimerAddPageObject("appearance", test);

    -- Page 3: behavior uses compact custom on/off buttons instead of check textures.
    local behaviorTitle = MakeLabel(frame, "DebuffFilter_TimerBehaviorTitle", "计时条行为", 42, -139, 560, 14, 0.28, 0.78, 1.00);
    local behaviorHint = MakeLabel(frame, nil, "所有计时条均无右键隐藏功能；效果消失由扫描数据自动停止。", 42, -164, 610, 11, 0.58, 0.74, 0.88);
    TimerAddPageObject("behavior", behaviorTitle); TimerAddPageObject("behavior", behaviorHint);

    local reverse = TimerCreateCheck(frame, "DebuffFilter_TimerCheck_reverse", "反向填充", "reverse", 50, -205, 220);
    local showIcon = TimerCreateCheck(frame, "DebuffFilter_TimerCheck_show_icon", "显示技能图标", "show_icon", 360, -205, 220);
    local showText = TimerCreateCheck(frame, "DebuffFilter_TimerCheck_show_text", "显示技能／目标文字", "show_text", 50, -255, 220);
    local showTime = TimerCreateCheck(frame, "DebuffFilter_TimerCheck_show_time", "显示剩余时间", "show_time", 360, -255, 220);
    local fadeRemove = TimerCreateCheck(frame, "DebuffFilter_TimerCheck_fade_on_remove", "效果消失后渐隐", "fade_on_remove", 50, -305, 220);
    local fadeDeath = TimerCreateCheck(frame, "DebuffFilter_TimerCheck_fade_on_death", "目标死亡后渐隐", "fade_on_death", 360, -305, 220);
    TimerAddPageObject("behavior", reverse); TimerAddPageObject("behavior", showIcon); TimerAddPageObject("behavior", showText);
    TimerAddPageObject("behavior", showTime); TimerAddPageObject("behavior", fadeRemove); TimerAddPageObject("behavior", fadeDeath);

    local structure = MakeLabel(frame, nil,
        "绘制层级：底层 statusbarbg 固定满值显示背景色；中层 statusbar 负责倒计时；技能文字与时间位于最上层 OVERLAY。",
        50, -365, 590, 11, 0.62, 0.82, 0.94);
    structure:SetHeight(42); structure:SetJustifyV("TOP"); TimerAddPageObject("behavior", structure);

    MoonUI.SetTimerPage(CURRENT_TIMER_PAGE);
end


local function SpellAddPageObject(pageName, object)
    if (not object) then return; end
    if (not SPELL_PAGE_OBJECTS[pageName]) then SPELL_PAGE_OBJECTS[pageName] = {}; end
    table.insert(SPELL_PAGE_OBJECTS[pageName], object);
    AddToGroup("spell", object);
end

local function RefreshSpellSubButtons()
    local pageName, button;
    for pageName, button in SPELL_SUB_BUTTONS do
        if (button and button.DFMoonBackground) then
            if (pageName == CURRENT_SPELL_PAGE) then
                button.DFMoonBackground:SetTexture(COLOR_BLUE_ACTIVE[1], COLOR_BLUE_ACTIVE[2], COLOR_BLUE_ACTIVE[3], COLOR_BLUE_ACTIVE[4]);
                button.text:SetTextColor(1.00, 1.00, 1.00);
            else
                button.DFMoonBackground:SetTexture(COLOR_BLUE[1], COLOR_BLUE[2], COLOR_BLUE[3], COLOR_BLUE[4]);
                button.text:SetTextColor(0.70, 0.84, 0.96);
            end
        end
    end
end

local function MakeSpellSubButton(frame, pageName, label, index)
    local button = CreateFrame("Button", "DebuffFilter_MoonSpellSub" .. index, frame);
    button:SetWidth(132);
    button:SetHeight(29);
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 42 + (index - 1) * 142, -96);
    button.DFMoonBackground = MakeTexture(button, "BACKGROUND", COLOR_BLUE[1], COLOR_BLUE[2], COLOR_BLUE[3], COLOR_BLUE[4]);
    button.DFMoonBackground:SetAllPoints(button);
    button.DFMoonBorder = MakeTexture(button, "BORDER", 0.18, 0.42, 0.68, 0.52);
    button.DFMoonBorder:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1);
    button.DFMoonBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1);
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    button.text:SetPoint("CENTER", button, "CENTER", 0, 0);
    DebuffFilter_SetUIFont(button.text, 12, "OUTLINE");
    button.text:SetText(label);
    button.text:SetTextColor(0.76, 0.90, 1.00);
    button:SetScript("OnClick", function() MoonUI.SetSpellPage(pageName); end);
    SPELL_SUB_BUTTONS[pageName] = button;
    AddToGroup("spell", button);
    return button;
end

local function SpellBlacklistMatches(name, spellKey, needle)
    if (not needle or needle == "") then return true; end
    local loweredNeedle = string.lower(tostring(needle));
    local loweredName = string.lower(tostring(name or ""));
    if (string.find(loweredName, loweredNeedle, 1, true)) then return true; end
    if (string.find(tostring(spellKey or ""), loweredNeedle, 1, true)) then return true; end
    return false;
end

local function GetSpellBlacklistEntries()
    local entries = {};
    local total = 0;
    local config = DebuffFilter_Config and DebuffFilter_Config[DebuffFilter_Player];
    local blacklist = config and config["target_spell_blacklist"];
    local needle = SPELL_BLACKLIST_SEARCH and SPELL_BLACKLIST_SEARCH:GetText() or "";
    if (type(blacklist) == "table") then
        local spellKey, entry;
        for spellKey, entry in blacklist do
            total = total + 1;
            local name = type(entry) == "table" and entry.name or nil;
            if (not name or name == "") then name = "技能 #" .. tostring(spellKey); end
            if (SpellBlacklistMatches(name, spellKey, needle)) then
                table.insert(entries, { key=tostring(spellKey), name=tostring(name) });
            end
        end
    end
    table.sort(entries, function(a, b)
        local an = string.lower(a.name or "");
        local bn = string.lower(b.name or "");
        if (an == bn) then
            local ai = tonumber(a.key);
            local bi = tonumber(b.key);
            if (ai and bi) then return ai < bi; end
            return tostring(a.key) < tostring(b.key);
        end
        return an < bn;
    end);
    return entries, total;
end

function MoonUI.RefreshSpellBlacklist()
    if (not SPELL_BLACKLIST_SEARCH) then return; end
    local entries, total = GetSpellBlacklistEntries();
    local filtered = table.getn(entries);
    local pages = math.max(1, math.ceil(filtered / SPELL_BLACKLIST_PAGE_SIZE));
    if (SPELL_BLACKLIST_PAGE > pages) then SPELL_BLACKLIST_PAGE = pages; end
    if (SPELL_BLACKLIST_PAGE < 1) then SPELL_BLACKLIST_PAGE = 1; end

    local needle = SPELL_BLACKLIST_SEARCH:GetText() or "";
    if (SPELL_BLACKLIST_COUNT) then
        if (needle ~= "") then
            SPELL_BLACKLIST_COUNT:SetText("搜索结果 " .. tostring(filtered) .. " / 黑名单 " .. tostring(total));
        else
            SPELL_BLACKLIST_COUNT:SetText("黑名单共 " .. tostring(total) .. " 条");
        end
    end
    if (SPELL_BLACKLIST_PAGE_LABEL) then
        SPELL_BLACKLIST_PAGE_LABEL:SetText(tostring(SPELL_BLACKLIST_PAGE) .. " / " .. tostring(pages));
    end

    local first = (SPELL_BLACKLIST_PAGE - 1) * SPELL_BLACKLIST_PAGE_SIZE + 1;
    local index;
    for index = 1, SPELL_BLACKLIST_PAGE_SIZE, 1 do
        local row = SPELL_BLACKLIST_ROWS[index];
        local entry = entries[first + index - 1];
        if (row and entry) then
            row.spellID = entry.key;
            row.label:SetText(entry.name .. "   |cff72c8ffID " .. entry.key .. "|r");
            row:Show();
        elseif (row) then
            row.spellID = nil;
            row:Hide();
        end
    end
end

function MoonUI.SetSpellPage(pageName)
    if (not SPELL_PAGE_OBJECTS[pageName]) then pageName = "settings"; end
    CURRENT_SPELL_PAGE = pageName;

    local name, objects, index;
    for name, objects in SPELL_PAGE_OBJECTS do
        for index = 1, table.getn(objects), 1 do HideObject(objects[index]); end
    end

    if (CURRENT_TAB == "spell") then
        objects = SPELL_PAGE_OBJECTS[CURRENT_SPELL_PAGE];
        for index = 1, table.getn(objects), 1 do ShowObject(objects[index]); end
    end

    RefreshSpellSubButtons();
    if (pageName == "blacklist") then MoonUI.RefreshSpellBlacklist(); end
end

local function CreateSpellBlacklistPage(frame)
    local title = MakeLabel(frame, "DebuffFilter_MoonSpellBlacklistTitle", "技能黑名单", 42, -144, 240, 14, 0.28, 0.78, 1.00);
    local desc = MakeLabel(frame, nil,
        "Alt+左键敌人技能图标可快速加入；也可以手动输入技能ID。黑名单命中后完全跳过该技能监视。",
        42, -169, 600, 11, 0.62, 0.78, 0.90);
    desc:SetHeight(30);
    desc:SetJustifyV("TOP");

    local addLabel = MakeLabel(frame, nil, "添加ID", 42, -211, 55, 12);
    local addEdit = CreateFrame("EditBox", "DebuffFilter_MoonSpellBlacklistAddID", frame, "InputBoxTemplate");
    addEdit:SetPoint("TOPLEFT", frame, "TOPLEFT", 102, -199);
    addEdit:SetWidth(220);
    addEdit:SetHeight(24);
    addEdit:SetAutoFocus(false);
    addEdit:SetText("");
    StyleEditBox(addEdit);

    local addButton = CreateFrame("Button", "DebuffFilter_MoonSpellBlacklistAddButton", frame);
    addButton:SetWidth(92);
    addButton:SetHeight(24);
    addButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 334, -199);
    addButton.text = addButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    addButton.text:SetPoint("CENTER", addButton, "CENTER", 0, 0);
    DebuffFilter_SetUIFont(addButton.text, 11, "OUTLINE");
    addButton.text:SetText("加入黑名单");
    StyleButton(addButton, COLOR_RED);

    local function SubmitManualBlacklistID()
        local spellID = addEdit:GetText();
        if (type(DebuffFilter_AddTargetSpellBlacklistByID) == "function") then
            if (DebuffFilter_AddTargetSpellBlacklistByID(spellID)) then
                addEdit:SetText("");
                SPELL_BLACKLIST_PAGE = 1;
                MoonUI.RefreshSpellBlacklist();
            end
        end
        addEdit:ClearFocus();
    end
    addButton:SetScript("OnClick", function() SubmitManualBlacklistID(); end);
    addEdit:SetScript("OnEscapePressed", function() this:ClearFocus(); end);
    addEdit:SetScript("OnEnterPressed", function() SubmitManualBlacklistID(); end);

    local searchLabel = MakeLabel(frame, nil, "搜索", 42, -251, 55, 12);
    local search = CreateFrame("EditBox", "DebuffFilter_MoonSpellBlacklistSearch", frame, "InputBoxTemplate");
    search:SetPoint("TOPLEFT", frame, "TOPLEFT", 102, -239);
    search:SetWidth(315);
    search:SetHeight(24);
    search:SetAutoFocus(false);
    search:SetText("");
    StyleEditBox(search);
    search:SetScript("OnTextChanged", function()
        SPELL_BLACKLIST_PAGE = 1;
        MoonUI.RefreshSpellBlacklist();
    end);
    search:SetScript("OnEscapePressed", function() this:ClearFocus(); end);
    search:SetScript("OnEnterPressed", function() this:ClearFocus(); end);
    SPELL_BLACKLIST_SEARCH = search;

    local countLabel = MakeLabel(frame, nil, "黑名单共 0 条", 436, -251, 190, 11, 0.58, 0.74, 0.88);
    countLabel:SetJustifyH("RIGHT");
    SPELL_BLACKLIST_COUNT = countLabel;

    local index;
    for index = 1, SPELL_BLACKLIST_PAGE_SIZE, 1 do
        local row = CreateFrame("Frame", "DebuffFilter_MoonSpellBlacklistRow" .. index, frame);
        row:SetWidth(584);
        row:SetHeight(28);
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 42, -279 - (index - 1) * 32);
        row.bg = MakeTexture(row, "BACKGROUND", 0.025, 0.065, 0.115, 0.92);
        row.bg:SetAllPoints(row);
        row.border = MakeTexture(row, "BORDER", 0.10, 0.30, 0.50, 0.48);
        row.border:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1);
        row.border:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1);

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
        row.label:SetPoint("LEFT", row, "LEFT", 10, 0);
        row.label:SetWidth(450);
        row.label:SetHeight(22);
        row.label:SetJustifyH("LEFT");
        DebuffFilter_SetUIFont(row.label, 11, "OUTLINE");
        row.label:SetTextColor(0.84, 0.94, 1.00);

        row.remove = CreateFrame("Button", "DebuffFilter_MoonSpellBlacklistRemove" .. index, row);
        row.remove:SetWidth(88);
        row.remove:SetHeight(22);
        row.remove:SetPoint("RIGHT", row, "RIGHT", -4, 0);
        row.remove.text = row.remove:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
        row.remove.text:SetPoint("CENTER", row.remove, "CENTER", 0, 0);
        DebuffFilter_SetUIFont(row.remove.text, 11, "OUTLINE");
        row.remove.text:SetText("解除");
        row.remove:SetScript("OnClick", function()
            local parent = this:GetParent();
            if (parent and parent.spellID and type(DebuffFilter_RemoveTargetSpellBlacklist) == "function") then
                DebuffFilter_RemoveTargetSpellBlacklist(parent.spellID);
            end
        end);
        StyleButton(row.remove, COLOR_RED);
        row:Hide();
        SPELL_BLACKLIST_ROWS[index] = row;
    end

    local prev = CreateFrame("Button", "DebuffFilter_MoonSpellBlacklistPrev", frame);
    prev:SetWidth(92); prev:SetHeight(24);
    prev:SetPoint("TOPLEFT", frame, "TOPLEFT", 214, -475);
    prev.text = prev:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    prev.text:SetPoint("CENTER", prev, "CENTER", 0, 0);
    DebuffFilter_SetUIFont(prev.text, 11, "OUTLINE");
    prev.text:SetText("上一页");
    prev:SetScript("OnClick", function()
        if (SPELL_BLACKLIST_PAGE > 1) then SPELL_BLACKLIST_PAGE = SPELL_BLACKLIST_PAGE - 1; end
        MoonUI.RefreshSpellBlacklist();
    end);
    StyleButton(prev, COLOR_BLUE);

    local pageLabel = MakeLabel(frame, nil, "1 / 1", 310, -478, 70, 11, 0.72, 0.86, 0.96);
    pageLabel:SetJustifyH("CENTER");
    SPELL_BLACKLIST_PAGE_LABEL = pageLabel;

    local nextButton = CreateFrame("Button", "DebuffFilter_MoonSpellBlacklistNext", frame);
    nextButton:SetWidth(92); nextButton:SetHeight(24);
    nextButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 384, -475);
    nextButton.text = nextButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    nextButton.text:SetPoint("CENTER", nextButton, "CENTER", 0, 0);
    DebuffFilter_SetUIFont(nextButton.text, 11, "OUTLINE");
    nextButton.text:SetText("下一页");
    nextButton:SetScript("OnClick", function()
        SPELL_BLACKLIST_PAGE = SPELL_BLACKLIST_PAGE + 1;
        MoonUI.RefreshSpellBlacklist();
    end);
    StyleButton(nextButton, COLOR_BLUE);

    SpellAddPageObject("blacklist", title);
    SpellAddPageObject("blacklist", desc);
    SpellAddPageObject("blacklist", addLabel);
    SpellAddPageObject("blacklist", addEdit);
    SpellAddPageObject("blacklist", addButton);
    SpellAddPageObject("blacklist", searchLabel);
    SpellAddPageObject("blacklist", search);
    SpellAddPageObject("blacklist", countLabel);
    for index = 1, SPELL_BLACKLIST_PAGE_SIZE, 1 do SpellAddPageObject("blacklist", SPELL_BLACKLIST_ROWS[index]); end
    SpellAddPageObject("blacklist", prev);
    SpellAddPageObject("blacklist", pageLabel);
    SpellAddPageObject("blacklist", nextButton);
end

local function PositionSpellControls(frame)
    local monitor = getglobal("DebuffFilter_ManagerSpellMonitorCheck");
    local maxEdit = getglobal("DebuffFilter_ManagerMaxSavedEdit");
    local maxSet = getglobal("DebuffFilter_ManagerMaxSavedSet");
    local announceDrop = getglobal("DebuffFilter_ManagerAnnounceDropDown");

    MakeSpellSubButton(frame, "settings", "监视设置", 1);
    MakeSpellSubButton(frame, "blacklist", "黑名单", 2);

    local title = MakeLabel(frame, "DebuffFilter_MoonSpellTitle", "敌人技能监视", 42, -144, 240, 14, 0.28, 0.78, 1.00);
    local maxLabel = MakeLabel(frame, nil, "最大永久记录", 42, -239, 105, 12);
    local unitLabel = MakeLabel(frame, nil, "条", 235, -239, 30, 12);
    local announceLabel = MakeLabel(frame, nil, "点击播报频道", 42, -301, 110, 12);
    local explain = MakeLabel(frame, nil,
        "后台按怪物 GUID 学习首轮时间和循环周期；屏幕只显示当前目标。\n" ..
        "技能图标：左键播报，Alt+左键加入黑名单，右键清理样本，Ctrl+左键删除技能记录。",
        42, -361, 600, 11, 0.62, 0.78, 0.90);
    explain:SetHeight(52);
    explain:SetJustifyV("TOP");

    SetObjectPoint(monitor, "TOPLEFT", frame, "TOPLEFT", 42, -181);
    SetObjectPoint(maxEdit, "TOPLEFT", frame, "TOPLEFT", 152, -227);
    maxEdit:SetWidth(72);
    maxEdit:SetHeight(24);
    SetObjectPoint(maxSet, "TOPLEFT", frame, "TOPLEFT", 270, -227);
    maxSet:SetWidth(85);
    maxSet:SetHeight(25);
    SetObjectPoint(announceDrop, "TOPLEFT", frame, "TOPLEFT", 152, -285);
    UIDropDownMenu_SetWidth(120, announceDrop);

    StyleCheck(monitor);
    StyleEditBox(maxEdit);
    StyleButton(maxSet, COLOR_GREEN);
    StyleDropDown(announceDrop);

    SpellAddPageObject("settings", title);
    SpellAddPageObject("settings", maxLabel);
    SpellAddPageObject("settings", unitLabel);
    SpellAddPageObject("settings", announceLabel);
    SpellAddPageObject("settings", explain);
    SpellAddPageObject("settings", monitor);
    SpellAddPageObject("settings", maxEdit);
    SpellAddPageObject("settings", maxSet);
    SpellAddPageObject("settings", announceDrop);

    CreateSpellBlacklistPage(frame);
    MoonUI.SetSpellPage(CURRENT_SPELL_PAGE);
end

local function PositionHelpControls(frame)
    local title = MakeLabel(frame, "DebuffFilter_MoonHelpTitle", "功能与操作速查", 38, -94, 240, 14, 0.28, 0.78, 1.00);
    local left = MakeLabel(frame, nil,
        "七个监视区域\n" ..
        "• 我的增益 / 我的减益\n" ..
        "• 目标增益 / 目标减益\n" ..
        "• 多人增益 / 多人减益\n" ..
        "• 敌人技能监视\n\n" ..
        "多人追踪范围\n" ..
        "• 自己、小队与团队成员\n" ..
        "• 保留玩家名、技能名、图标与剩余时间\n" ..
        "• 旧动态文字列表已删除；可在计时条页选择普通图标或计时条",
        42, -136, 285, 11, 0.78, 0.90, 1.00);
    left:SetHeight(245);
    left:SetJustifyV("TOP");

    local right = MakeLabel(frame, nil,
        "计时与操作\n" ..
        "• 手工持续时间始终优先\n" ..
        "• 未填时间：使用 SuperWoW 施法记录\n" ..
        "• 无法确认起点时显示 --\n" ..
        "• Shift+左键：拖动对应监视区域\n\n" ..
        "常用命令\n" ..
        "/dfilter dscan：扫描目标减益\n" ..
        "/dfilter ctbscan：扫描目标增益\n" ..
        "/dfilter tbscan：扫描多人增益\n" ..
        "/dfilter mtdscan：扫描多人减益\n" ..
        "/dfilter bartest：测试计时条",
        360, -136, 285, 11, 0.78, 0.90, 1.00);
    right:SetHeight(245);
    right:SetJustifyV("TOP");

    local note = MakeLabel(frame, nil,
        "pfUI 下跳过目标头像原始 Debuff 快捷添加；管理窗口扫描与手工添加不受影响。",
        42, -393, 600, 11, 0.58, 0.72, 0.84);

    AddToGroup("help", title);
    AddToGroup("help", left);
    AddToGroup("help", right);
    AddToGroup("help", note);
end

local function PositionCommonControls(frame)
    local backdropButton = getglobal("DebuffFilter_ManagerBackdrop");
    local refreshButton = getglobal("DebuffFilter_ManagerRefresh");
    local chatButton = getglobal("DebuffFilter_ManagerChatHelp");
    local closeButton = getglobal("DebuffFilter_ManagerClose");
    local resetButton = getglobal("DebuffFilter_ManagerReset");
    local status = getglobal("DebuffFilter_ManagerStatus");

    SetObjectPoint(backdropButton, "TOPLEFT", frame, "TOPLEFT", 24, -504);
    backdropButton:SetWidth(126);
    backdropButton:SetHeight(26);
    backdropButton:SetText("移动框");
    SetObjectPoint(refreshButton, "TOPLEFT", frame, "TOPLEFT", 160, -504);
    refreshButton:SetWidth(100);
    refreshButton:SetHeight(26);
    SetObjectPoint(chatButton, "TOPLEFT", frame, "TOPLEFT", 270, -504);
    chatButton:SetWidth(120);
    chatButton:SetHeight(26);
    chatButton:SetText("聊天命令");
    SetObjectPoint(resetButton, "TOPLEFT", frame, "TOPLEFT", 400, -504);
    resetButton:SetWidth(126);
    resetButton:SetHeight(26);
    resetButton:SetText("恢复初始");
    SetObjectPoint(closeButton, "TOPLEFT", frame, "TOPLEFT", 536, -504);
    closeButton:SetWidth(120);
    closeButton:SetHeight(26);

    StyleButton(backdropButton, COLOR_BLUE_ACTIVE);
    StyleButton(refreshButton, COLOR_GREEN);
    StyleButton(chatButton, COLOR_BLUE);
    StyleButton(resetButton, COLOR_AMBER);
    StyleButton(closeButton, COLOR_RED);

    SetObjectPoint(status, "TOPLEFT", frame, "TOPLEFT", 28, -549);
    status:SetWidth(630);
    status:SetHeight(22);
    DebuffFilter_SetUIFont(status, 11, "OUTLINE");
    status:SetJustifyH("LEFT");
    status:SetJustifyV("MIDDLE");

    AddToGroup("common", backdropButton);
    AddToGroup("common", refreshButton);
    AddToGroup("common", chatButton);
    AddToGroup("common", resetButton);
    AddToGroup("common", closeButton);
    AddToGroup("common", status);
end

local function ApplyMoonMarkerUI(frame)
    if (UI_APPLIED or not frame) then return; end
    UI_APPLIED = true;

    frame:SetScale(1.00);
    frame:SetWidth(700);
    frame:SetHeight(590);
    frame:ClearAllPoints();
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10);
    frame:SetFrameStrata("DIALOG");
    frame:SetFrameLevel(100);
    if (frame.SetClampedToScreen) then frame:SetClampedToScreen(true); end
    if (frame.SetBackdropColor) then frame:SetBackdropColor(0, 0, 0, 0); end
    if (frame.SetBackdropBorderColor) then frame:SetBackdropBorderColor(0, 0, 0, 0); end

    HideLegacyFrameRegions(frame);

    frame.DFMoonBackground = MakeTexture(frame, "BACKGROUND", COLOR_BG[1], COLOR_BG[2], COLOR_BG[3], COLOR_BG[4]);
    frame.DFMoonBackground:SetAllPoints(frame);
    frame.DFMoonBorder = MakeTexture(frame, "BORDER", COLOR_BORDER[1], COLOR_BORDER[2], COLOR_BORDER[3], COLOR_BORDER[4]);
    frame.DFMoonBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1);
    frame.DFMoonBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1);

    frame.DFMoonHeader = MakeTexture(frame, "ARTWORK", 0.035, 0.10, 0.18, 0.96);
    frame.DFMoonHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2);
    frame.DFMoonHeader:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2);
    frame.DFMoonHeader:SetHeight(37);

    frame.DFMoonContent = MakeTexture(frame, "BACKGROUND", COLOR_PANEL[1], COLOR_PANEL[2], COLOR_PANEL[3], COLOR_PANEL[4]);
    frame.DFMoonContent:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -82);
    frame.DFMoonContent:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 104);

    frame.DFMoonStatusBackground = MakeTexture(frame, "BACKGROUND", 0.015, 0.04, 0.075, 0.98);
    frame.DFMoonStatusBackground:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -540);
    frame.DFMoonStatusBackground:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 16);

    local title = MakeLabel(frame, "DebuffFilter_MoonTitle", "DebuffFilter · 光环监视系统", 18, -10, 300, 15, 0.36, 0.84, 1.00);
    local version = MakeLabel(frame, "DebuffFilter_MoonVersion", "v1.14.8 · 黑名单手动添加", 304, -11, 190, 11, 0.58, 0.72, 0.84);
    version:SetJustifyH("CENTER");
    local guild = MakeLabel(frame, "DebuffFilter_MoonGuild", "太阳神殿", 545, -10, 112, 12, 0.36, 0.84, 1.00);
    guild:SetJustifyH("RIGHT");

    local topClose = CreateFrame("Button", "DebuffFilter_MoonTopClose", frame);
    topClose:SetWidth(25);
    topClose:SetHeight(23);
    topClose:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -7);
    topClose.text = topClose:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    topClose.text:SetPoint("CENTER", topClose, "CENTER", 0, 1);
    DebuffFilter_SetUIFont(topClose.text, 16, "OUTLINE");
    topClose.text:SetText("×");
    topClose:SetScript("OnClick", function() frame:Hide(); end);
    StyleButton(topClose, COLOR_RED);

    MakeTab(frame, "monitor", "光环监视", 1);
    MakeTab(frame, "display", "设置", 2);
    MakeTab(frame, "timer", "计时条", 3);
    MakeTab(frame, "spell", "敌人技能", 4);
    MakeTab(frame, "help", "使用说明", 5);

    PositionMonitorControls(frame);
    PositionDisplayControls(frame);
    PositionTimerControls(frame);
    PositionSpellControls(frame);
    PositionHelpControls(frame);
    PositionCommonControls(frame);
    MoonUI.SetMonitorMode(CURRENT_MONITOR_MODE);

    AddToGroup("common", title);
    AddToGroup("common", version);
    AddToGroup("common", guild);
    AddToGroup("common", topClose);

    frame.DFMoonLegacyOnShow = frame:GetScript("OnShow");
    frame:SetScript("OnShow", function()
        if (frame.DFMoonLegacyOnShow) then frame.DFMoonLegacyOnShow(); end
        MoonUI.SkinMonitorFrames();
        MoonUI.SetTab(CURRENT_TAB or "monitor");
    end);

    MoonUI.SkinMonitorFrames();
    MoonUI.SetTab("monitor");
end

local function EnsureManagerFrame()
    local frame = getglobal("DebuffFilter_ManagerFrame");
    if (frame) then return frame; end
    if (type(LegacyManagerToggle) == "function") then
        LegacyManagerToggle();
        frame = getglobal("DebuffFilter_ManagerFrame");
        if (frame and frame:IsShown()) then frame:Hide(); end
    end
    return frame;
end

function DebuffFilter_Manager_Toggle()
    local frame = EnsureManagerFrame();
    if (not frame) then return; end
    ApplyMoonMarkerUI(frame);
    if (frame:IsShown()) then
        frame:Hide();
    else
        frame:Show();
        frame:Raise();
        MoonUI.SetTab(CURRENT_TAB or "monitor");
    end
end

local eventFrame = CreateFrame("Frame", "DebuffFilter_MoonUIEventFrame", UIParent);
eventFrame:RegisterEvent("PLAYER_LOGIN");
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
eventFrame:SetScript("OnEvent", function()
    MoonUI.SkinMonitorFrames();
end);
