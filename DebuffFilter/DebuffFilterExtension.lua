-- DebuffFilter v1.13.0 extension
-- 独立自身 Debuff 监视。
-- 已移除 v1.9.7.4-v1.9.7.6 新增的屏幕文字、BigWigs 风格计时条及“提示 / 播报”二级页面。
-- 本文件不依赖 BigWigs，不播放声音。

DebuffFilter_Extension = DebuffFilter_Extension or {};
local DFEX = DebuffFilter_Extension;

DFEX.version = "1.13.0";
DFEX.updateElapsed = 0;
DFEX.hookElapsed = 0;
DFEX.playerDebuffStates = {};
DFEX.playerDebuffInitialized = false;
DFEX.playerCtrlLeftWasDown = false;
DFEX.lastPlayerQuickIndex = nil;
DFEX.lastPlayerQuickTime = 0;

local function DFEX_Print(message)
	if (type(DebuffFilter_Print) == "function") then
		DebuffFilter_Print(message);
	elseif (DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffDebuffFilter|r " .. tostring(message));
	end
end

local function DFEX_NormalizeName(name)
	if (not name) then return nil; end
	name = tostring(name);
	name = string.gsub(name, "\226\128\139", "");
	name = string.gsub(name, "\239\187\191", "");
	name = string.gsub(name, "\194\160", " ");
	name = string.gsub(name, "^%s+", "");
	name = string.gsub(name, "%s+$", "");
	if (name == "") then return nil; end
	return name;
end

local function DFEX_GetConfig()
	if (not DebuffFilter_Config or not DebuffFilter_Player) then return nil; end
	return DebuffFilter_Config[DebuffFilter_Player];
end

local function DFEX_EnsureConfig()
	local config = DFEX_GetConfig();
	if (not config) then return nil; end
	if (config["player_auras"] == nil) then config["player_auras"] = "yes"; end
	if (config["player_debuffs"] == nil) then config["player_debuffs"] = "yes"; end
	if (type(config["player_debuff_list"]) ~= "table") then config["player_debuff_list"] = {}; end
	return config;
end

local function DFEX_IsYes(value)
	return value ~= "no";
end

local function DFEX_IsPfUIActive()
	if (type(DebuffFilter_IsPfUIActive) == "function") then
		return DebuffFilter_IsPfUIActive();
	end
	return type(IsAddOnLoaded) == "function" and IsAddOnLoaded("pfUI") and true or false;
end

local function DFEX_SetIndependentDefaultAnchor(frame)
	if (not frame) then return; end
	frame:ClearAllPoints();
	if (DFEX_IsPfUIActive()) then
		frame:SetPoint("CENTER", UIParent, "CENTER", -220, 50);
	else
		-- 与“我的增益”使用相同参照对象，但不是相对该监视框定位。
		frame:SetPoint("LEFT", PlayerFrame, "RIGHT", -35, 140);
	end
end

local function DFEX_MigrateIndependentAnchor(frame)
	local config = DFEX_EnsureConfig();
	if (not frame or not config) then return; end
	if (config["player_debuff_anchor_v1988"] == "yes") then return; end
	if (frame.SetUserPlaced) then frame:SetUserPlaced(false); end
	DFEX_SetIndependentDefaultAnchor(frame);
	if (frame.SetUserPlaced) then frame:SetUserPlaced(true); end
	config["player_debuff_anchor_v1988"] = "yes";
end

local function DFEX_FormatAuraTime(seconds)
	seconds = tonumber(seconds);
	if (not seconds or seconds < 0) then return ""; end
	if (seconds < 60) then return string.format("%.1f", seconds); end
	return SecondsToTimeAbbrev(math.ceil(seconds));
end

local function DFEX_GetPlayerDebuffName(index)
	if (not UnitDebuff("player", index)) then return nil; end
	if (not DebuffFilter_Tooltip or not DebuffFilter_TooltipTextLeft1) then return nil; end
	DebuffFilter_Tooltip:SetOwner(UIParent, "ANCHOR_NONE");
	DebuffFilter_Tooltip:ClearLines();
	DebuffFilter_Tooltip:SetUnitDebuff("player", index);
	return DFEX_NormalizeName(DebuffFilter_TooltipTextLeft1:GetText());
end

local function DFEX_FindHarmfulBuffInfo(debuffName)
	for slot = 0, 31, 1 do
		local buffIndex, untilCancelled = GetPlayerBuff(slot, "HARMFUL");
		if (buffIndex and buffIndex >= 0) then
			DebuffFilter_Tooltip:SetOwner(UIParent, "ANCHOR_NONE");
			DebuffFilter_Tooltip:ClearLines();
			DebuffFilter_Tooltip:SetPlayerBuff(buffIndex);
			local name = DFEX_NormalizeName(DebuffFilter_TooltipTextLeft1:GetText());
			if (name == debuffName) then
				return tonumber(GetPlayerBuffTimeLeft(buffIndex)), tonumber(GetPlayerBuffApplications(buffIndex)) or 0, untilCancelled, buffIndex;
			end
		end
	end
	return nil, 0, nil, nil;
end

local function DFEX_GetDispelTypeText(rawType)
	local value = rawType and string.lower(tostring(rawType)) or "";
	if (value == "magic" or value == "魔法") then return "魔法", 0.25, 0.65, 1; end
	if (value == "curse" or value == "诅咒") then return "诅咒", 0.72, 0.28, 0.9; end
	if (value == "disease" or value == "疾病") then return "疾病", 0.78, 0.58, 0.2; end
	if (value == "poison" or value == "中毒") then return "中毒", 0.2, 0.9, 0.25; end
	return "无", 0.72, 0.72, 0.72;
end

local function DFEX_PlayerDebuffButton_OnEnter()
	if (this.debuffIndex and DFEX_IsYes((DFEX_GetConfig() or {})["tooltips"])) then
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
		GameTooltip:SetUnitDebuff("player", this.debuffIndex);
	end
end

local function DFEX_PlayerDebuffButton_OnLeave()
	GameTooltip:Hide();
end

local function DFEX_PlayerDebuffButton_OnMouseDown()
	if (arg1 == "LeftButton" and IsShiftKeyDown()) then
		this.DFEXDragging = 1;
		this:GetParent():StartMoving();
	end
end

local function DFEX_PlayerDebuffButton_OnMouseUp()
	if (arg1 == "LeftButton" and this.DFEXDragging) then
		local parent = this:GetParent();
		parent:StopMovingOrSizing();
		if (parent.SetUserPlaced) then parent:SetUserPlaced(true); end
		this.DFEXDragging = nil;
		this.DFEXSkipClickUntil = GetTime() + 0.25;
	end
end

local function DFEX_PlayerDebuffButton_OnClick()
	if (this.DFEXSkipClickUntil and GetTime() < this.DFEXSkipClickUntil) then return; end
	if (arg1 == "LeftButton" and IsControlKeyDown() and this.debuffName) then
		local config = DFEX_EnsureConfig();
		if (config and config["player_debuff_list"][this.debuffName]) then
			config["player_debuff_list"][this.debuffName] = nil;
			DFEX_Print("已移除自身 Debuff 监视：|cff00ccff" .. tostring(this.debuffName) .. "|r");
			DFEX.playerDebuffStates[this.debuffKey or this.debuffName] = nil;
			DFEX.UpdatePlayerDebuffs(true);
		end
	end
end

local function DFEX_CreatePlayerDebuffFrame()
	local existing = getglobal("DebuffFilter_PlayerDebuffFrame");
	if (existing) then return existing; end
	local frame = CreateFrame("Frame", "DebuffFilter_PlayerDebuffFrame", DebuffFilterFrame or UIParent);
	frame:SetWidth(30); frame:SetHeight(30);
	DFEX_SetIndependentDefaultAnchor(frame);
	frame:SetMovable(1);
	if (frame.SetUserPlaced) then frame:SetUserPlaced(true); end
	frame:Hide();
	local backdrop = CreateFrame("Button", "DebuffFilter_PlayerDebuffFrameBackdrop", frame, "DebuffFilter_BackdropTemplate");
	backdrop:SetPoint("CENTER", frame, "CENTER", 0, 0); backdrop:Hide();
	local label = backdrop:CreateFontString(nil, "ARTWORK", "GameFontNormal");
	label:SetPoint("BOTTOM", backdrop, "TOP", 0, 4); label:SetText("我的减益");
	local countText = frame:CreateFontString("DebuffFilter_PlayerDebuffFrameCount", "OVERLAY", "GameFontNormal");
	countText:SetPoint("LEFT", frame, "RIGHT", 2, 0); countText:Hide();
	for index = 0, 15, 1 do
		local name = "DebuffFilter_PlayerDebuffButton" .. tostring(index);
		local button = CreateFrame("Button", name, frame);
		button:SetWidth(30); button:SetHeight(30); button:RegisterForClicks("LeftButtonUp"); button:Hide();
		-- 与自身 Buff 一致：默认从右向左排列。
		if (index == 0) then
			button:SetPoint("RIGHT", frame, "RIGHT", 0, 0);
		else
			button:SetPoint("RIGHT", "DebuffFilter_PlayerDebuffButton" .. tostring(index - 1), "LEFT", -4, 0);
		end
		local icon = button:CreateTexture(name .. "Icon", "ARTWORK");
		icon:SetAllPoints(button); icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
		local border = button:CreateTexture(nil, "OVERLAY");
		border:SetTexture("Interface\\Buttons\\UI-Quickslot2");
		border:SetPoint("CENTER", button, "CENTER", 0, 0); border:SetWidth(54); border:SetHeight(54);
		local typeText = button:CreateFontString(name .. "Type", "OVERLAY", "GameFontNormalSmall");
		typeText:SetPoint("BOTTOM", button, "TOP", 0, 1); DebuffFilter_SetUIFont(typeText, 10, "OUTLINE");
		local durationText = button:CreateFontString(name .. "Duration", "OVERLAY", "GameFontNormalSmall");
		durationText:SetPoint("TOP", button, "BOTTOM", 0, 1); DebuffFilter_SetUIFont(durationText, 11, "OUTLINE"); durationText:SetTextColor(1, 0.82, 0);
		local stackText = button:CreateFontString(name .. "Count", "OVERLAY", "NumberFontNormalSmall");
		stackText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1);
		button:SetScript("OnEnter", DFEX_PlayerDebuffButton_OnEnter);
		button:SetScript("OnLeave", DFEX_PlayerDebuffButton_OnLeave);
		button:SetScript("OnMouseDown", DFEX_PlayerDebuffButton_OnMouseDown);
		button:SetScript("OnMouseUp", DFEX_PlayerDebuffButton_OnMouseUp);
		button:SetScript("OnClick", DFEX_PlayerDebuffButton_OnClick);
	end
	return frame;
end

local function DFEX_HidePlayerDebuffButtons()
	local frame = getglobal("DebuffFilter_PlayerDebuffFrame");
	if (not frame) then return; end
	for index = 0, 15, 1 do
		local name = "DebuffFilter_PlayerDebuffButton" .. tostring(index);
		local button = getglobal(name);
		if (button) then
			button.debuffIndex = nil; button.debuffName = nil; button.debuffKey = nil; button:Hide();
			getglobal(name .. "Type"):SetText(""); getglobal(name .. "Duration"):SetText(""); getglobal(name .. "Count"):SetText("");
		end
	end
	local backdrop = getglobal("DebuffFilter_PlayerDebuffFrameBackdrop");
	if (backdrop) then
		if (DebuffFilter.backdrop == 1) then backdrop:Show(); else backdrop:Hide(); end
	end
	if (DebuffFilter.backdrop == 1) then frame:Show(); else frame:Hide(); end
end

function DFEX.UpdatePlayerDebuffs(suppressMessages)
	local config = DFEX_EnsureConfig();
	local frame = DFEX_CreatePlayerDebuffFrame();
	if (not config or not DFEX_IsYes(config["player_auras"]) or not DFEX_IsYes(config["player_debuffs"])) then
		DFEX_HidePlayerDebuffButtons();
		return;
	end
	local backdrop = getglobal("DebuffFilter_PlayerDebuffFrameBackdrop");
	if (backdrop) then
		if (DebuffFilter.backdrop == 1) then backdrop:Show(); else backdrop:Hide(); end
	end
	local shown = 0;
	local seen = {};
	local now = GetTime();
	for index = 1, 32, 1 do
		local texture, stacks, dispelType, auraID = UnitDebuff("player", index);
		if (not texture) then break; end
		local debuffName = DFEX_GetPlayerDebuffName(index);
		if (debuffName and config["player_debuff_list"][debuffName] == 1) then
			local key = auraID and tostring(auraID) or debuffName;
			local rawRemaining, harmfulStacks, untilCancelled = DFEX_FindHarmfulBuffInfo(debuffName);
			local stackCount = tonumber(stacks) or tonumber(harmfulStacks) or 0;
			local typeText, tr, tg, tb = DFEX_GetDispelTypeText(dispelType);
			local state = DFEX.playerDebuffStates[key];
			if (not state) then state = {}; DFEX.playerDebuffStates[key] = state; end
			state.name = debuffName; state.index = index; state.auraID = auraID; state.icon = texture;
			state.stacks = stackCount; state.dispelType = typeText; state.lastSeen = now; seen[key] = 1;
			local remaining = nil;
			if (untilCancelled ~= 1 and rawRemaining and rawRemaining > 0) then
				-- 每次扫描直接采用客户端当前真实剩余时间，避免额外预测造成约1秒偏差。
				remaining = rawRemaining;
			else
				state.expirationTime = nil; state.duration = nil;
			end
			if (shown < 16) then
				local buttonName = "DebuffFilter_PlayerDebuffButton" .. tostring(shown);
				local button = getglobal(buttonName);
				button.debuffIndex = index; button.debuffName = debuffName; button.debuffKey = key;
				getglobal(buttonName .. "Icon"):SetTexture(texture);
				local typeRegion = getglobal(buttonName .. "Type"); typeRegion:SetText(typeText); typeRegion:SetTextColor(tr, tg, tb);
				local durationRegion = getglobal(buttonName .. "Duration");
				if (remaining and remaining > 0) then
					if (remaining <= 10) then durationRegion:SetTextColor(1, 0.15, 0.15); else durationRegion:SetTextColor(1, 0.82, 0); end
					durationRegion:SetText(DFEX_FormatAuraTime(remaining));
				else
					durationRegion:SetText("N/A");
				end
				if (stackCount > 1) then getglobal(buttonName .. "Count"):SetText(stackCount); else getglobal(buttonName .. "Count"):SetText(""); end
				button:Show(); shown = shown + 1;
			end
		end
	end
	local removed = {};
	for key, state in pairs(DFEX.playerDebuffStates) do
		if (not seen[key]) then table.insert(removed, key); end
	end
	for index = 1, table.getn(removed), 1 do DFEX.playerDebuffStates[removed[index]] = nil; end
	for index = shown, 15, 1 do
		local name = "DebuffFilter_PlayerDebuffButton" .. tostring(index);
		local button = getglobal(name);
		button.debuffIndex = nil; button.debuffName = nil; button.debuffKey = nil; button:Hide();
		getglobal(name .. "Type"):SetText(""); getglobal(name .. "Duration"):SetText(""); getglobal(name .. "Count"):SetText("");
	end
	local countText = getglobal("DebuffFilter_PlayerDebuffFrameCount");
	if (shown > 0) then
		frame:Show(); countText:SetText(shown);
		if (config["count"] == "yes") then countText:Show(); else countText:Hide(); end
	else
		countText:Hide();
		if (DebuffFilter.backdrop == 1) then frame:Show(); else frame:Hide(); end
	end
	DFEX.playerDebuffInitialized = true;
end

-- ============================================================
-- 默认/第三方玩家 Debuff 图标 Ctrl+左键快速添加/移除
-- ============================================================
local function DFEX_GetPlayerDebuffIndexFromButton(button)
	if (not button) then return nil; end
	local candidates = {};
	local id = button.GetID and tonumber(button:GetID()) or nil;
	if (id) then
		table.insert(candidates, id); table.insert(candidates, id + 1);
		if (id > 1) then table.insert(candidates, id - 1); end
	end
	local buttonName = button.GetName and button:GetName() or nil;
	if (buttonName and DFEX_IsPfUIActive()) then
		local _, _, pfNumberText = string.find(buttonName, "^pfDebuffFrameBuff(%d+)$");
		local pfNumber = tonumber(pfNumberText);
		if (pfNumber and pfNumber >= 1 and UnitDebuff("player", pfNumber)) then return pfNumber; end
	end
	if (buttonName) then
		local _, _, numberText = string.find(buttonName, "(%d+)$");
		local number = tonumber(numberText);
		if (number) then
			table.insert(candidates, number); table.insert(candidates, number + 1);
			if (number > 1) then table.insert(candidates, number - 1); end
		end
	end
	for index = 1, table.getn(candidates), 1 do
		local auraIndex = candidates[index];
		if (auraIndex and auraIndex >= 1 and UnitDebuff("player", auraIndex)) then return auraIndex; end
	end
	return nil;
end

local function DFEX_NormalizeTexture(texture)
	if (not texture) then return nil; end
	local value = string.lower(tostring(texture));
	value = string.gsub(value, "/", "\\");
	value = string.gsub(value, "^interface\\", "");
	return value;
end

local function DFEX_TextureMatches(left, right)
	left = DFEX_NormalizeTexture(left); right = DFEX_NormalizeTexture(right);
	if (not left or not right) then return false; end
	if (left == right) then return true; end
	local leftBase = string.gsub(left, "^.*\\", "");
	local rightBase = string.gsub(right, "^.*\\", "");
	return leftBase ~= "" and leftBase == rightBase;
end

local function DFEX_FrameContainsTexture(frame, wantedTexture)
	if (not frame or not wantedTexture) then return false; end
	if (frame.GetNormalTexture) then
		local normal = frame:GetNormalTexture();
		if (normal and normal.GetTexture and DFEX_TextureMatches(normal:GetTexture(), wantedTexture)) then return true; end
	end
	if (frame.GetRegions) then
		local regions = { frame:GetRegions() };
		for index = 1, table.getn(regions), 1 do
			local region = regions[index];
			if (region and region.GetTexture and DFEX_TextureMatches(region:GetTexture(), wantedTexture)) then return true; end
		end
	end
	return false;
end

local function DFEX_GetTooltipDebuffName()
	if (not GameTooltip or not GameTooltip:IsVisible() or not GameTooltipTextLeft1) then return nil; end
	return DFEX_NormalizeName(GameTooltipTextLeft1:GetText());
end

local function DFEX_FindPlayerDebuffIndexByName(wantedName)
	wantedName = DFEX_NormalizeName(wantedName);
	if (not wantedName) then return nil; end
	for auraIndex = 1, 32, 1 do
		if (not UnitDebuff("player", auraIndex)) then break; end
		if (DFEX_GetPlayerDebuffName(auraIndex) == wantedName) then return auraIndex; end
	end
	return nil;
end

local function DFEX_GetPlayerDebuffIndexFromMouseFocus()
	if (type(GetMouseFocus) ~= "function") then return nil; end
	local focus = GetMouseFocus();
	if (not focus) then return nil; end
	local current = focus;
	local depth = 0;
	while (current and depth < 12) do
		local name = current.GetName and current:GetName() or nil;
		if (name and string.find(name, "^DebuffFilter_")) then return nil; end
		local direct = DFEX_GetPlayerDebuffIndexFromButton(current);
		if (direct) then return direct; end
		current = current.GetParent and current:GetParent() or nil;
		depth = depth + 1;
	end
	-- 第三方UI按钮名称可能完全不含 Debuff：按图标纹理与玩家当前Debuff逐一匹配。
	for auraIndex = 1, 32, 1 do
		local texture = UnitDebuff("player", auraIndex);
		if (not texture) then break; end
		current = focus; depth = 0;
		while (current and depth < 12) do
			if (DFEX_FrameContainsTexture(current, texture)) then return auraIndex; end
			current = current.GetParent and current:GetParent() or nil;
			depth = depth + 1;
		end
	end
	-- 最后使用第三方UI已经显示的系统Tooltip名称匹配。
	local tooltipName = DFEX_GetTooltipDebuffName();
	if (tooltipName) then return DFEX_FindPlayerDebuffIndexByName(tooltipName); end
	return nil;
end

local function DFEX_TogglePlayerDebuffByIndex(auraIndex)
	auraIndex = tonumber(auraIndex);
	if (not auraIndex) then return; end
	local now = GetTime();
	if (DFEX.lastPlayerQuickIndex == auraIndex and now - (DFEX.lastPlayerQuickTime or 0) < 0.25) then return; end
	DFEX.lastPlayerQuickIndex = auraIndex; DFEX.lastPlayerQuickTime = now;
	local name = DFEX_GetPlayerDebuffName(auraIndex);
	local config = DFEX_EnsureConfig();
	if (not name or not config) then
		DFEX_Print("无法读取这个自身 Debuff 的名称。可用 /dfplist 检查接口，或 /dfpdebug 检查鼠标焦点。");
		return;
	end
	if (config["player_debuff_list"][name] == 1) then
		config["player_debuff_list"][name] = nil;
		DFEX_Print("已移除自身 Debuff 监视：|cff00ccff" .. name .. "|r");
	else
		config["player_debuff_list"][name] = 1;
		DFEX_Print("已添加自身 Debuff 监视：|cff00ccff" .. name .. "|r");
	end
	DFEX.UpdatePlayerDebuffs(true);
end

function DFEX.SystemDebuff_OnMouseDown()
	local mouseButton = arg1;
	local button = this;
	if (mouseButton == "LeftButton" and IsControlKeyDown()) then
		local auraIndex = DFEX_GetPlayerDebuffIndexFromButton(button);
		if (not auraIndex) then auraIndex = DFEX_GetPlayerDebuffIndexFromMouseFocus(); end
		if (auraIndex) then DFEX_TogglePlayerDebuffByIndex(auraIndex); end
	end
	if (button and button.DFEX_OldOnMouseDown) then button.DFEX_OldOnMouseDown(mouseButton); end
end

local function DFEX_HookOneSystemDebuffButton(button)
	if (not button or not button.GetScript or not button.SetScript) then return; end
	local current = button:GetScript("OnMouseDown");
	if (current ~= DFEX.SystemDebuff_OnMouseDown) then
		button.DFEX_OldOnMouseDown = current;
		button:SetScript("OnMouseDown", DFEX.SystemDebuff_OnMouseDown);
	end
end

local function DFEX_HookSystemDebuffButtons()
	if (DFEX_IsPfUIActive()) then
		-- pfUI 真实按钮名：pfDebuffFrameBuff1、pfDebuffFrameBuff2……
		for index = 1, 40, 1 do
			DFEX_HookOneSystemDebuffButton(getglobal("pfDebuffFrameBuff" .. tostring(index)));
		end
		return;
	end

	-- 无 pfUI 时完整保留 v1.9.7.7 原有自身 Debuff 快捷键逻辑。
	local prefixes = {
		"DebuffButton", "PlayerFrameDebuff", "PlayerDebuff", "pfPlayerDebuff",
		"LunaPlayerFrameDebuff", "CT_DebuffButton", "XPerl_Player_Debuff",
		"ZPerl_Player_Debuff", "ag_PlayerFrameDebuff", "DUF_PlayerFrame_Debuff"
	};
	for prefixIndex = 1, table.getn(prefixes), 1 do
		for index = 1, 40, 1 do DFEX_HookOneSystemDebuffButton(getglobal(prefixes[prefixIndex] .. tostring(index))); end
	end
end

local function DFEX_CheckPlayerDebuffCtrlClick()
	-- pfUI 分支使用明确按钮名挂接，不再运行原生鼠标焦点兜底。
	if (DFEX_IsPfUIActive()) then return; end
	if (type(IsMouseButtonDown) ~= "function") then return; end
	local leftDown = IsMouseButtonDown("LeftButton") and true or false;
	if (leftDown and not DFEX.playerCtrlLeftWasDown and IsControlKeyDown()) then
		local auraIndex = DFEX_GetPlayerDebuffIndexFromMouseFocus();
		if (auraIndex) then DFEX_TogglePlayerDebuffByIndex(auraIndex); end
	end
	DFEX.playerCtrlLeftWasDown = leftDown;
end

-- ============================================================
-- 诊断：判断第三方Debuff框是否能被识别
-- ============================================================
local function DFEX_DebugMouseFocus()
	local focus = type(GetMouseFocus) == "function" and GetMouseFocus() or nil;
	DFEX_Print("鼠标焦点诊断开始。请把鼠标停在系统/第三方自身Debuff图标上再执行。");
	if (not focus) then DFEX_Print("GetMouseFocus() = nil"); return; end
	local current = focus;
	for depth = 1, 12, 1 do
		if (not current) then break; end
		local name = current.GetName and current:GetName() or "<匿名>";
		local id = current.GetID and current:GetID() or nil;
		local objectType = current.GetObjectType and current:GetObjectType() or "?";
		DFEX_Print(tostring(depth) .. ": " .. tostring(name) .. "  类型=" .. tostring(objectType) .. "  ID=" .. tostring(id));
		current = current.GetParent and current:GetParent() or nil;
	end
	local tooltipName = DFEX_GetTooltipDebuffName();
	DFEX_Print("Tooltip第一行=" .. tostring(tooltipName));
	local matched = DFEX_GetPlayerDebuffIndexFromMouseFocus();
	DFEX_Print("匹配到的玩家Debuff序号=" .. tostring(matched));
end

local function DFEX_ListPlayerDebuffs()
	DFEX_Print("UnitDebuff(player) 当前列表：");
	local count = 0;
	for index = 1, 32, 1 do
		local texture, stacks, dispelType, auraID = UnitDebuff("player", index);
		if (not texture) then break; end
		count = count + 1;
		local name = DFEX_GetPlayerDebuffName(index) or "<无法读取名称>";
		DFEX_Print(tostring(index) .. ": " .. name .. "  类型=" .. tostring(dispelType) .. "  ID=" .. tostring(auraID) .. "  图标=" .. tostring(texture));
	end
	if (count == 0) then DFEX_Print("接口当前没有读取到任何玩家Debuff。"); end
end

-- 与主程序连接：保留自身 Buff / Debuff 总开关。
local DFEX_OldBuffFrameUpdate = DebuffFilter_BuffFrame_Update;
if (type(DFEX_OldBuffFrameUpdate) == "function") then
	function DebuffFilter_BuffFrame_Update()
		local config = DFEX_EnsureConfig();
		if (config and (not DFEX_IsYes(config["player_auras"]) or not DFEX_IsYes(config["buffs"]))) then
			local frame = getglobal("DebuffFilter_BuffFrame");
			if (frame) then
				if (DebuffFilter.backdrop == 1) then frame:Show(); else frame:Hide(); end
			end
			return;
		end
		if (getglobal("DebuffFilter_BuffFrame") and config) then getglobal("DebuffFilter_BuffFrame"):Show(); end
		DFEX_OldBuffFrameUpdate();
	end
end

local DFEX_OldCommand = DebuffFilter_command;
if (type(DFEX_OldCommand) == "function") then
	function DebuffFilter_command(msg)
		DFEX_OldCommand(msg);
		local command = string.lower(tostring(msg or ""));
		local _, _, firstWord = string.find(command, "^(%S+)");
		if (firstWord == "backdrop") then DFEX.UpdatePlayerDebuffs(true); end
	end
end

local DFEX_OldResetCurrentCharacter = DebuffFilter_ResetCurrentCharacter;
if (type(DFEX_OldResetCurrentCharacter) == "function") then
	function DebuffFilter_ResetCurrentCharacter()
		DFEX_OldResetCurrentCharacter();
		local config = DFEX_EnsureConfig();
		if (config) then
			config["player_auras"] = "yes";
			config["player_debuffs"] = "yes";
			config["player_debuff_list"] = {};
		end
		local frame = getglobal("DebuffFilter_PlayerDebuffFrame");
		if (frame) then
			if (frame.SetUserPlaced) then frame:SetUserPlaced(false); end
			frame:ClearAllPoints();
			DFEX_SetIndependentDefaultAnchor(frame);
			local resetConfig = DFEX_EnsureConfig();
			if (resetConfig) then resetConfig["player_debuff_anchor_v1988"] = "yes"; end
		end
		DFEX.playerDebuffStates = {};
		DFEX.UpdatePlayerDebuffs(true);
	end
end

local DFEX_EventFrame = CreateFrame("Frame", "DebuffFilter_ExtensionEventFrame", UIParent);
DFEX_EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
DFEX_EventFrame:RegisterEvent("PLAYER_AURAS_CHANGED");
DFEX_EventFrame:RegisterEvent("UNIT_AURA");
DFEX_EventFrame:RegisterEvent("VARIABLES_LOADED");
DFEX_EventFrame:SetScript("OnEvent", function()
	if (event == "VARIABLES_LOADED") then
		DFEX_EnsureConfig();
	elseif (event == "PLAYER_ENTERING_WORLD") then
		DFEX_EnsureConfig();
		local playerDebuffFrame = DFEX_CreatePlayerDebuffFrame();
		DFEX_MigrateIndependentAnchor(playerDebuffFrame);
		DFEX.UpdatePlayerDebuffs(true);
		DFEX_HookSystemDebuffButtons();
	elseif (event == "PLAYER_AURAS_CHANGED") then
		DFEX.UpdatePlayerDebuffs(false);
	elseif (event == "UNIT_AURA") then
		if (arg1 == "player" or arg1 == nil) then DFEX.UpdatePlayerDebuffs(false); end
	end
end);

DFEX_EventFrame:SetScript("OnUpdate", function()
	local elapsed = tonumber(arg1) or 0;
	DFEX.updateElapsed = DFEX.updateElapsed + elapsed;
	DFEX.hookElapsed = DFEX.hookElapsed + elapsed;
	DFEX_CheckPlayerDebuffCtrlClick();
	if (DFEX.updateElapsed >= 0.20) then
		DFEX.updateElapsed = 0;
		if (DFEX_EnsureConfig()) then DFEX.UpdatePlayerDebuffs(false); end
	end
	if (DFEX.hookElapsed >= 0.75) then
		DFEX.hookElapsed = 0;
		DFEX_HookSystemDebuffButtons();
	end
end);

SLASH_DFPDEBUG1 = "/dfpdebug";
SlashCmdList["DFPDEBUG"] = DFEX_DebugMouseFocus;
SLASH_DFPLIST1 = "/dfplist";
SlashCmdList["DFPLIST"] = DFEX_ListPlayerDebuffs;
SLASH_DFPADD1 = "/dfpadd";
SlashCmdList["DFPADD"] = function(msg)
	local index = tonumber(msg);
	if (not index) then DFEX_Print("用法：/dfpadd 1  （数字是 /dfplist 显示的序号）"); return; end
	DFEX_TogglePlayerDebuffByIndex(index);
end;
