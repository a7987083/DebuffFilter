-- DebuffFilter current-target Buff monitor.
-- Displays only configured Buffs on the currently selected target.
-- Changing or clearing the target refreshes immediately; no target means no icons.
-- This module never reads frame coordinates and never saves positions on mouse-up/logout.

DebuffFilter_CurrentTargetBuff = DebuffFilter_CurrentTargetBuff or {};
local DFCTB = DebuffFilter_CurrentTargetBuff;

DFCTB.version = "1.14.5";
DFCTB.updateElapsed = 0;
DFCTB.updateInterval = 0.15;
DFCTB.maxButtons = 32;
DFCTB.castRecords = {};
DFCTB.firstSeen = {};

-- Shared target-Buff duration rules. Manual values always take priority.
DebuffFilter.TargetBuffRules = DebuffFilter.TargetBuffRules or {};
if (not DebuffFilter.TargetBuffRules["真言术：盾"]) then
	DebuffFilter.TargetBuffRules["真言术：盾"] = { base=30 };
end
if (not DebuffFilter.TargetBuffRules["恢复"]) then
	DebuffFilter.TargetBuffRules["恢复"] = { base=15 };
end

local function DFCTB_NormalizeName(name)
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

local function DFCTB_GetConfig()
	if (not DebuffFilter_Config or not DebuffFilter_Player) then return nil; end
	return DebuffFilter_Config[DebuffFilter_Player];
end

local function DFCTB_EnsureConfig()
	local config = DFCTB_GetConfig();
	if (not config) then return nil; end
	if (config["current_target_buffs"] == nil) then config["current_target_buffs"] = "yes"; end
	if (type(config["current_target_buff_list"]) ~= "table") then config["current_target_buff_list"] = {}; end
	if (type(config["current_target_buff_duration_custom"]) ~= "table") then config["current_target_buff_duration_custom"] = {}; end
	return config;
end

local function DFCTB_IsEnabled()
	local config = DFCTB_EnsureConfig();
	return config and config["current_target_buffs"] ~= "no";
end

local function DFCTB_Print(message)
	if (type(DebuffFilter_Print) == "function") then
		DebuffFilter_Print(message);
	elseif (DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Buff监视|r " .. tostring(message));
	end
end

local function DFCTB_FindConfiguredName(name)
	local config = DFCTB_EnsureConfig();
	if (not config or not name) then return nil; end
	if (type(DebuffFilter_FindConfiguredName) == "function") then
		return DebuffFilter_FindConfiguredName(config["current_target_buff_list"], name);
	end
	local normalized = DFCTB_NormalizeName(name);
	if (config["current_target_buff_list"][normalized]) then return normalized; end
	for configuredName in config["current_target_buff_list"] do
		if (DFCTB_NormalizeName(configuredName) == normalized) then return configuredName; end
	end
	return nil;
end

local function DFCTB_GetDurationInfo(buffName)
	buffName = DFCTB_NormalizeName(buffName);
	local config = DFCTB_EnsureConfig();
	if (not config or not buffName) then return nil, "unknown"; end
	local custom = config["current_target_buff_duration_custom"][buffName];
	if (custom and tonumber(custom) and tonumber(custom) > 0) then
		return tonumber(custom), "custom";
	end
	local rule = DebuffFilter.TargetBuffRules and DebuffFilter.TargetBuffRules[buffName];
	if (rule and tonumber(rule.base) and tonumber(rule.base) > 0) then
		return tonumber(rule.base), "combat";
	end
	return nil, "combat";
end

function DebuffFilter_GetCurrentTargetBuffDuration(buffName)
	local duration = DFCTB_GetDurationInfo(buffName);
	return duration;
end

local function DFCTB_GetUnitGUID(unit)
	local ok, exists, guid = pcall(UnitExists, unit);
	if (not ok or not exists) then return nil; end
	if (guid) then return tostring(guid); end
	local name = UnitName(unit);
	if (name) then return "name:" .. tostring(name); end
	return nil;
end

local function DFCTB_GetBuffName(unit, index)
	if (not DebuffFilter_Tooltip or not DebuffFilter_TooltipTextLeft1) then return nil; end
	local ok = pcall(function()
		DebuffFilter_Tooltip:SetOwner(UIParent, "ANCHOR_NONE");
		DebuffFilter_Tooltip:ClearLines();
		DebuffFilter_Tooltip:SetUnitBuff(unit, index);
	end);
	if (not ok) then return nil; end
	return DFCTB_NormalizeName(DebuffFilter_TooltipTextLeft1:GetText());
end

local function DFCTB_GetSpellDisplayInfo(spellID)
	local numericID = tonumber(spellID);
	local spellName = nil;
	local spellIcon = nil;
	if (numericID and type(SpellInfo) == "function") then
		local ok, name, rank, icon = pcall(SpellInfo, numericID);
		if (ok) then
			spellName = DFCTB_NormalizeName(name);
			spellIcon = icon;
		end
	end
	if ((not spellName or not spellIcon) and numericID and type(GetSpellRecField) == "function") then
		local okName, name = pcall(GetSpellRecField, numericID, "name");
		if (okName and name) then spellName = DFCTB_NormalizeName(name); end
	end
	return spellName, spellIcon;
end

local function DFCTB_NormalizeCastState(rawState)
	if (rawState == nil) then return nil; end
	local state = string.upper(tostring(rawState));
	if (state == "CAST" or state == "SUCCESS" or state == "STOP" or state == "CHANNEL_STOP") then return "CAST"; end
	if (string.find(state, "FAIL") or string.find(state, "INTERRUPT")) then return "FAIL"; end
	if (string.find(state, "START") or state == "CHANNEL" or state == "CHANNELING") then return "START"; end
	return state;
end

local function DFCTB_ResolveSpellID()
	local candidates = { arg4, arg5, arg6, arg7 };
	local index;
	for index = 1, table.getn(candidates), 1 do
		local numericID = tonumber(candidates[index]);
		if (numericID and numericID > 0) then
			local spellName = DFCTB_GetSpellDisplayInfo(numericID);
			if (spellName) then return numericID; end
		end
	end
	return tonumber(arg4) or arg4;
end

local function DFCTB_StateKey(guid, buffName)
	return tostring(guid or "unknown") .. "|" .. tostring(buffName or "unknown");
end

local function DFCTB_RecordCast()
	if (not DFCTB_IsEnabled()) then return; end
	if (DFCTB_NormalizeCastState(arg3) ~= "CAST") then return; end
	local targetGUID = arg2 and tostring(arg2) or nil;
	if (not targetGUID or targetGUID == "" or targetGUID == "0") then return; end
	-- 当前目标Buff模块只需要当前目标收到的施法；先按GUID丢弃绝大多数团队/怪物事件，再解析技能ID。
	local currentGUID = DFCTB_GetUnitGUID("target");
	if (not currentGUID or tostring(currentGUID) ~= targetGUID) then return; end
	local config = DFCTB_EnsureConfig();
	if (config and config["only_mine_auras"] == "yes" and type(DebuffFilter_IsPlayerCasterGUID) == "function" and not DebuffFilter_IsPlayerCasterGUID(arg1)) then return; end
	local spellID = DFCTB_ResolveSpellID();
	local spellName, spellIcon = DFCTB_GetSpellDisplayInfo(spellID);
	local configuredName = DFCTB_FindConfiguredName(spellName);
	if (not configuredName) then return; end
	local duration, timerSource = DFCTB_GetDurationInfo(configuredName);
	local now = GetTime();
	local key = DFCTB_StateKey(targetGUID, configuredName);
	DFCTB.castRecords[key] = {
		guid = targetGUID,
		isMine = type(DebuffFilter_IsPlayerCasterGUID) == "function" and DebuffFilter_IsPlayerCasterGUID(arg1) or false,
		buffName = configuredName,
		spellID = spellID,
		icon = spellIcon,
		castTime = now,
		duration = duration,
		endTime = duration and (now + duration) or nil,
		timerSource = timerSource,
		lastActivity = now,
	};
end

local function DFCTB_PruneRecords()
	local now = GetTime();
	local remove = {};
	for key, record in DFCTB.castRecords do
		if ((record.lastActivity or record.castTime or 0) < now - 600) then table.insert(remove, key); end
	end
	local index;
	for index = 1, table.getn(remove), 1 do DFCTB.castRecords[remove[index]] = nil; end
end

local function DFCTB_Button_OnEnter()
	local config = DFCTB_EnsureConfig();
	if (config and config["tooltips"] == "no") then return; end
	local index = this.buffIndex;
	if (not index or not UnitExists("target")) then return; end
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
	GameTooltip:SetUnitBuff("target", index);
	if (this.timerSource == "custom") then
		GameTooltip:AddLine("计时来源：手工持续时间（优先）", 0.55, 0.85, 1);
	elseif (this.timerEnd) then
		GameTooltip:AddLine("计时来源：SuperWoW 施放记录", 0.55, 0.85, 1);
	end
	GameTooltip:Show();
end

local function DFCTB_Button_OnLeave()
	GameTooltip:Hide();
end

local function DFCTB_Button_OnMouseDown()
	if (arg1 == "LeftButton" and IsShiftKeyDown()) then
		this.DFCTBDragging = 1;
		this:GetParent():StartMoving();
	elseif (arg1 == "LeftButton" and IsControlKeyDown() and this.filterName) then
		DebuffFilter_command("ctbdel " .. tostring(this.filterName));
	end
end

local function DFCTB_Button_OnMouseUp()
	if (arg1 == "LeftButton" and this.DFCTBDragging) then
		this:GetParent():StopMovingOrSizing();
		this.DFCTBDragging = nil;
	end
end

local function DFCTB_SetDefaultPosition(frame)
	if (not frame) then return; end
	if (frame.SetUserPlaced) then frame:SetUserPlaced(false); end
	frame:ClearAllPoints();
	if (type(DebuffFilter_IsPfUIActive) == "function" and DebuffFilter_IsPfUIActive()) then
		frame:SetPoint("CENTER", UIParent, "CENTER", 220, -90);
	else
		frame:SetPoint("LEFT", TargetFrame, "RIGHT", -35, 40);
	end
end

function DebuffFilter_CreateCurrentTargetBuffFrame()
	local existing = getglobal("DebuffFilter_CurrentTargetBuffFrame");
	if (existing) then return existing; end

	local parent = DebuffFilterFrame or UIParent;
	local frame = CreateFrame("Frame", "DebuffFilter_CurrentTargetBuffFrame", parent);
	frame:SetWidth(30);
	frame:SetHeight(30);
	frame:SetMovable(1);
	DFCTB_SetDefaultPosition(frame);
	frame:Hide();

	local count = frame:CreateFontString("DebuffFilter_CurrentTargetBuffFrameCount", "OVERLAY", "GameFontNormal");
	count:SetWidth(30);
	count:SetHeight(12);
	count:SetPoint("RIGHT", frame, "LEFT", 0, 0);
	count:Hide();

	local backdrop = CreateFrame("Button", "DebuffFilter_CurrentTargetBuffFrameBackdrop", frame, "DebuffFilter_BackdropTemplate");
	backdrop:SetPoint("CENTER", frame, "CENTER", 0, 0);
	backdrop:SetScript("OnMouseDown", DFCTB_Button_OnMouseDown);
	backdrop:SetScript("OnMouseUp", DFCTB_Button_OnMouseUp);
	backdrop:SetScript("OnHide", function() frame:StopMovingOrSizing(); end);
	backdrop:Hide();
	local label = backdrop:CreateFontString(nil, "ARTWORK", "GameFontNormal");
	label:SetWidth(100);
	label:SetHeight(12);
	label:SetPoint("TOP", backdrop, "TOP", 0, 15);
	label:SetText("目标增益");

	local index;
	for index = 0, DFCTB.maxButtons - 1, 1 do
		local name = "DebuffFilter_CurrentTargetBuffButton" .. tostring(index);
		local button = CreateFrame("Button", name, frame, "DebuffFilter_BuffButtonTemplate");
		button:SetID(index);
		button.filterType = "currenttargetbuff";
		button:SetScript("OnUpdate", nil);
		button:SetScript("OnEnter", DFCTB_Button_OnEnter);
		button:SetScript("OnLeave", DFCTB_Button_OnLeave);
		button:SetScript("OnMouseDown", DFCTB_Button_OnMouseDown);
		button:SetScript("OnMouseUp", DFCTB_Button_OnMouseUp);
		button:Hide();
		if (index == 0) then
			button:SetPoint("LEFT", frame, "LEFT", 0, 0);
		else
			button:SetPoint("LEFT", "DebuffFilter_CurrentTargetBuffButton" .. tostring(index - 1), "RIGHT", 4, 0);
		end
	end
	return frame;
end

local function DFCTB_HideButtons(fromIndex)
	local index;
	for index = fromIndex or 0, DFCTB.maxButtons - 1, 1 do
		local buttonName = "DebuffFilter_CurrentTargetBuffButton" .. tostring(index);
		local button = getglobal(buttonName);
		if (button) then
			button.buffIndex = nil;
			button.filterName = nil;
			button.timerEnd = nil;
			button.timerSource = nil;
			button:Hide();
			getglobal(buttonName .. "Count"):SetText("");
			getglobal(buttonName .. "Duration"):SetText("");
			button:SetWidth(-4);
			button:SetHeight(-4);
		end
	end
end

function DebuffFilter_CurrentTargetBuffFrame_Update()
	local frame = DebuffFilter_CreateCurrentTargetBuffFrame();
	local backdrop = getglobal("DebuffFilter_CurrentTargetBuffFrameBackdrop");
	local countText = getglobal("DebuffFilter_CurrentTargetBuffFrameCount");
	local config = DFCTB_EnsureConfig();
	if (not config) then return; end

	if (not DFCTB_IsEnabled()) then
		DFCTB_HideButtons(0);
		if (countText) then countText:Hide(); end
		if (backdrop) then if (DebuffFilter.backdrop == 1) then backdrop:Show(); else backdrop:Hide(); end end
		if (DebuffFilter.backdrop == 1) then frame:Show(); else frame:Hide(); end
		return;
	end

	if (not UnitExists("target") or UnitIsDead("target")) then
		DFCTB_HideButtons(0);
		if (countText) then countText:Hide(); end
		if (backdrop) then if (DebuffFilter.backdrop == 1) then backdrop:Show(); else backdrop:Hide(); end end
		if (DebuffFilter.backdrop == 1) then frame:Show(); else frame:Hide(); end
		return;
	end

	local targetGUID = DFCTB_GetUnitGUID("target");
	local now = GetTime();
	local shown = 0;
	local seenKeys = {};
	local auraIndex;
	for auraIndex = 1, 32, 1 do
		local texture, stacks, dispelType, auraID = UnitBuff("target", auraIndex);
		if (not texture) then break; end
		local rawName = DFCTB_GetBuffName("target", auraIndex);
		local configuredName = DFCTB_FindConfiguredName(rawName);
		if (configuredName and shown < DFCTB.maxButtons) then
			local key = DFCTB_StateKey(targetGUID, configuredName);
			local record = DFCTB.castRecords[key];
			local onlyMine = config["only_mine_auras"] == "yes";
			if (not onlyMine or (record and record.isMine)) then
			seenKeys[key] = 1;
			local duration, durationSource = DFCTB_GetDurationInfo(configuredName);
			if (record) then record.lastActivity = now; end
			local timerEnd = nil;
			local timerSource = nil;
			if (record and duration) then
				timerEnd = (record.castTime or now) + duration;
				timerSource = durationSource;
				record.duration = duration;
				record.endTime = timerEnd;
				record.timerSource = durationSource;
				record.lastActivity = now;
			elseif (durationSource == "custom" and duration) then
				if (not DFCTB.firstSeen[key]) then DFCTB.firstSeen[key] = now; end
				timerEnd = DFCTB.firstSeen[key] + duration;
				timerSource = "custom";
			end

			local buttonName = "DebuffFilter_CurrentTargetBuffButton" .. tostring(shown);
			local button = getglobal(buttonName);
			button.buffIndex = auraIndex;
			button.filterName = configuredName;
			button.auraID = auraID;
			button.timerEnd = timerEnd;
			button.timerSource = timerSource;
			getglobal(buttonName .. "Icon"):SetTexture(texture);
			getglobal(buttonName .. "Icon"):SetAlpha(1);
			local stackText = getglobal(buttonName .. "Count");
			if (tonumber(stacks) and tonumber(stacks) > 1) then stackText:SetText(tostring(stacks)); else stackText:SetText(""); end
			local timeText = getglobal(buttonName .. "Duration");
			if (timerEnd) then
				local remaining = timerEnd - now;
				if (remaining < 0) then remaining = 0; end
				if (remaining <= 11) then timeText:SetTextColor(1, 0, 0); else timeText:SetTextColor(1, 0.82, 0); end
				if (type(DebuffFilter_FormatRemaining) == "function") then
					timeText:SetText(DebuffFilter_FormatRemaining(remaining));
				else
					timeText:SetText(string.format("%.1f", remaining));
				end
			else
				timeText:SetText("");
			end
			button:SetWidth(30);
			button:SetHeight(30);
			button:Show();
			shown = shown + 1;
			end
		end
	end

	local prefix = tostring(targetGUID or "unknown") .. "|";
	local removeFirstSeen = {};
	for key in DFCTB.firstSeen do
		if (string.sub(tostring(key), 1, string.len(prefix)) == prefix and not seenKeys[key]) then
			table.insert(removeFirstSeen, key);
		end
	end
	local removeIndex;
	for removeIndex = 1, table.getn(removeFirstSeen), 1 do DFCTB.firstSeen[removeFirstSeen[removeIndex]] = nil; end

	-- 当前目标上的 Buff 已经消失时，清理旧施法记录；刚收到 CAST 的短暂同步窗口除外。
	local removeRecords = {};
	for key, record in DFCTB.castRecords do
		if (string.sub(tostring(key), 1, string.len(prefix)) == prefix and not seenKeys[key]) then
			if ((now - (record.castTime or 0)) > 1.50) then table.insert(removeRecords, key); end
		end
	end
	for removeIndex = 1, table.getn(removeRecords), 1 do DFCTB.castRecords[removeRecords[removeIndex]] = nil; end

	DFCTB_HideButtons(shown);
	if (countText) then
		countText:SetText(tostring(shown));
		if (shown > 0 and config["count"] == "yes") then countText:Show(); else countText:Hide(); end
	end
	if (backdrop) then if (DebuffFilter.backdrop == 1) then backdrop:Show(); else backdrop:Hide(); end end
	if (shown > 0 or DebuffFilter.backdrop == 1) then frame:Show(); else frame:Hide(); end
end

function DebuffFilter_CurrentTargetBuff_Rescan()
	DebuffFilter_CurrentTargetBuffFrame_Update();
end

function DebuffFilter_CurrentTargetBuff_ApplyDurationRule(buffName)
	buffName = DFCTB_NormalizeName(buffName);
	if (not buffName) then return; end
	local duration, timerSource = DFCTB_GetDurationInfo(buffName);
	for key, record in DFCTB.castRecords do
		if (DFCTB_NormalizeName(record.buffName) == buffName) then
			record.duration = duration;
			record.timerSource = timerSource;
			record.endTime = duration and ((record.castTime or GetTime()) + duration) or nil;
		end
	end
	DebuffFilter_CurrentTargetBuffFrame_Update();
end

local function DFCTB_PrintList()
	local config = DFCTB_EnsureConfig();
	if (not config) then return; end
	DFCTB_Print("当前目标 Buff 监视列表：");
	local count = 0;
	for buffName, enabled in config["current_target_buff_list"] do
		if (enabled == 1) then
			count = count + 1;
			local duration, source = DFCTB_GetDurationInfo(buffName);
			local sourceText = source == "custom" and "手工" or "战斗记录";
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff" .. tostring(buffName) .. "|r  " .. sourceText .. "=" .. (duration and tostring(duration) .. "秒" or "--"));
		end
	end
	if (count == 0) then DFCTB_Print("（列表为空）"); end
end

local function DFCTB_ScanTargetPrint()
	if (not UnitExists("target")) then DFCTB_Print("当前没有目标。"); return; end
	local count = 0;
	local index;
	for index = 1, 32, 1 do
		local texture, stacks, dispelType, auraID = UnitBuff("target", index);
		if (not texture) then break; end
		local name = DFCTB_GetBuffName("target", index) or "<无法读取名称>";
		count = count + 1;
		DEFAULT_CHAT_FRAME:AddMessage(tostring(index) .. ". |cff00ccff" .. tostring(name) .. "|r 层数=" .. tostring(stacks or 0) .. " ID=" .. tostring(auraID or "nil"));
	end
	if (count == 0) then DFCTB_Print("接口没有扫描到当前目标 Buff。"); end
end

local DFCTB_OldCommand = DebuffFilter_command;
if (type(DFCTB_OldCommand) == "function") then
	function DebuffFilter_command(message)
		local text = tostring(message or "");
		text = string.gsub(text, "^%s+", "");
		text = string.gsub(text, "%s+$", "");
		local _, _, command, parameter = string.find(text, "^(%S+)%s*(.-)$");
		command = string.lower(command or "");
		parameter = DFCTB_NormalizeName(parameter);
		local config = DFCTB_EnsureConfig();

		if (command == "ctbadd" and parameter) then
			config["current_target_buff_list"][parameter] = 1;
			DFCTB_Print("已添加当前目标 Buff 监视：|cff00ccff" .. parameter .. "|r");
			DebuffFilter_CurrentTargetBuffFrame_Update();
			return;
		elseif (command == "ctbdel" and parameter) then
			config["current_target_buff_list"][parameter] = nil;
			DFCTB_Print("已删除当前目标 Buff 监视：|cff00ccff" .. parameter .. "|r");
			DebuffFilter_CurrentTargetBuffFrame_Update();
			return;
		elseif (command == "ctblist") then
			DFCTB_PrintList();
			return;
		elseif (command == "ctbscan") then
			DFCTB_ScanTargetPrint();
			return;
		elseif (command == "ctbtime" and parameter) then
			local _, _, buffName, seconds = string.find(parameter, "^(.+)%s+(%d+%.?%d*)$");
			buffName = DFCTB_NormalizeName(buffName);
			seconds = tonumber(seconds);
			if (buffName and seconds and seconds > 0) then
				config["current_target_buff_duration_custom"][buffName] = seconds;
				DebuffFilter_CurrentTargetBuff_ApplyDurationRule(buffName);
				DFCTB_Print("已设置当前目标 Buff 手工时间：|cff00ccff" .. buffName .. "|r = " .. tostring(seconds) .. " 秒");
			else
				DFCTB_Print("格式：/dfilter ctbtime Buff名称 秒数");
			end
			return;
		elseif (command == "ctbtimeoff" and parameter) then
			config["current_target_buff_duration_custom"][parameter] = nil;
			DFCTB.firstSeen = {};
			DebuffFilter_CurrentTargetBuff_ApplyDurationRule(parameter);
			DFCTB_Print("当前目标 Buff 已改为战斗记录计时：|cff00ccff" .. parameter .. "|r");
			return;
		elseif (command == "currenttargetbuffs") then
			if (config["current_target_buffs"] == "no") then config["current_target_buffs"] = "yes"; else config["current_target_buffs"] = "no"; end
			DFCTB_Print("当前目标 Buff 监视：" .. (config["current_target_buffs"] == "yes" and "开启" or "关闭"));
			DebuffFilter_CurrentTargetBuffFrame_Update();
			return;
		end
		DFCTB_OldCommand(message);
	end
end

local DFCTB_OldReset = DebuffFilter_ResetCurrentCharacter;
if (type(DFCTB_OldReset) == "function") then
	function DebuffFilter_ResetCurrentCharacter()
		DFCTB_OldReset();
		DFCTB.castRecords = {};
		DFCTB.firstSeen = {};
		local frame = DebuffFilter_CreateCurrentTargetBuffFrame();
		DFCTB_SetDefaultPosition(frame);
		DebuffFilter_CurrentTargetBuffFrame_Update();
	end
end

local DFCTB_EventFrame = CreateFrame("Frame", "DebuffFilter_CurrentTargetBuffEventFrame", UIParent);
DFCTB_EventFrame:RegisterEvent("VARIABLES_LOADED");
DFCTB_EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
DFCTB_EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED");
DFCTB_EventFrame:RegisterEvent("UNIT_AURA");
DFCTB_EventFrame:RegisterEvent("UNIT_CASTEVENT");
DFCTB_EventFrame:SetScript("OnEvent", function()
	if (event == "VARIABLES_LOADED" or event == "PLAYER_ENTERING_WORLD") then
		DFCTB_EnsureConfig();
		DebuffFilter_CreateCurrentTargetBuffFrame();
		DebuffFilter_CurrentTargetBuffFrame_Update();
	elseif (event == "UNIT_CASTEVENT") then
		DFCTB_RecordCast();
	elseif (event == "PLAYER_TARGET_CHANGED" or event == "UNIT_AURA") then
		DebuffFilter_CurrentTargetBuffFrame_Update();
	end
end);

DFCTB_EventFrame:SetScript("OnUpdate", function()
	local elapsed = tonumber(arg1) or 0;
	DFCTB.updateElapsed = DFCTB.updateElapsed + elapsed;
	if (DFCTB.updateElapsed >= DFCTB.updateInterval) then
		DFCTB.updateElapsed = 0;
		DFCTB_PruneRecords();
		DebuffFilter_CurrentTargetBuffFrame_Update();
	end
end);
