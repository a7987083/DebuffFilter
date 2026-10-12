-- DebuffFilter v1.13.0
-- 多人增益数据采集与标准锚点。
-- 旧的动态文字列表渲染器已按用户要求删除；扫描、GUID状态、排序、剩余时间与玩家名称数据完整保留。
-- 多人增益显示数据由 DebuffFilter_GetMultiTargetBuffTimerEntries() 提供。
-- 本文件不读取框体坐标，不在拖动、松开鼠标或 PLAYER_LOGOUT 中保存位置。

DebuffFilter_TargetBuff = DebuffFilter_TargetBuff or {};
local DFTB = DebuffFilter_TargetBuff;

DFTB.version = "1.14.5";
DFTB.states = {};
DFTB.scanElapsed = 0;
DFTB.forceScan = true;
DFTB.scanInterval = 2.00;
DFTB.dirtyInterval = 0.15;
DFTB.dirtyElapsed = 0;
DFTB.dirtyUnits = {};
DFTB.unitCache = {};
DFTB.castGrace = 1.25;
DFTB.unknownExpire = 3;
DFTB.hasSuperWoW = SUPERWOW_STRING and true or false;

DebuffFilter.TargetBuffRules = DebuffFilter.TargetBuffRules or {
	["真言术：盾"] = { base=30 },
};

local function DFTB_NormalizeName(name)
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

local function DFTB_GetConfig()
	if (not DebuffFilter_Config or not DebuffFilter_Player) then return nil; end
	return DebuffFilter_Config[DebuffFilter_Player];
end

local function DFTB_EnsureConfig()
	local config = DFTB_GetConfig();
	if (not config) then return nil; end
	if (config["target_buffs"] == nil) then config["target_buffs"] = "yes"; end
	if (type(config["target_buff_list"]) ~= "table") then
		config["target_buff_list"] = { ["真言术：盾"] = 1 };
	end
	if (type(config["target_buff_duration_custom"]) ~= "table") then
		config["target_buff_duration_custom"] = {};
	end
	return config;
end

local function DFTB_IsEnabled()
	local config = DFTB_EnsureConfig();
	return config and config["target_buffs"] ~= "no";
end

local function DFTB_Print(message)
	if (type(DebuffFilter_Print) == "function") then
		DebuffFilter_Print(message);
	elseif (DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Buff监视|r " .. tostring(message));
	end
end

local function DFTB_GetDurationInfo(buffName)
	buffName = DFTB_NormalizeName(buffName);
	if (not buffName) then return nil, "unknown"; end
	local config = DFTB_EnsureConfig();
	if (not config) then return nil, "unknown"; end

	-- 手工填写始终优先；没有填写时，才使用战斗记录施放起点 + 内置持续时间规则。
	local custom = config["target_buff_duration_custom"][buffName];
	if (custom and tonumber(custom) and tonumber(custom) > 0) then
		return tonumber(custom), "custom";
	end

	local rule = DebuffFilter.TargetBuffRules and DebuffFilter.TargetBuffRules[buffName];
	if (rule and tonumber(rule.base) and tonumber(rule.base) > 0) then
		return tonumber(rule.base), "combat";
	end
	return nil, "combat";
end

function DebuffFilter_GetTargetBuffDuration(buffName)
	local duration = DFTB_GetDurationInfo(buffName);
	return duration;
end

local function DFTB_FindConfiguredName(name)
	local config = DFTB_EnsureConfig();
	if (not config or not name) then return nil; end
	if (type(DebuffFilter_FindConfiguredName) == "function") then
		return DebuffFilter_FindConfiguredName(config["target_buff_list"], name);
	end
	local normalized = DFTB_NormalizeName(name);
	if (config["target_buff_list"][normalized]) then return normalized; end
	for configuredName in config["target_buff_list"] do
		if (DFTB_NormalizeName(configuredName) == normalized) then return configuredName; end
	end
	return nil;
end

local function DFTB_GetUnitGUID(unit)
	if (not unit) then return nil; end
	local ok, exists, guid = pcall(UnitExists, unit);
	if (not ok or not exists) then return nil; end
	if (guid) then return tostring(guid); end
	local name = nil;
	local nameOK, rawName = pcall(UnitName, unit);
	if (nameOK) then name = DFTB_NormalizeName(rawName); end
	if (name) then return "name:" .. name; end
	return nil;
end

local function DFTB_GetUnitName(unit)
	if (not unit) then return nil; end
	local ok, name = pcall(UnitName, unit);
	if (not ok) then return nil; end
	return DFTB_NormalizeName(name);
end

local function DFTB_GetBuffName(unit, index)
	if (not DebuffFilter_Tooltip or not DebuffFilter_TooltipTextLeft1) then return nil; end
	local ok = pcall(function()
		DebuffFilter_Tooltip:SetOwner(UIParent, "ANCHOR_NONE");
		DebuffFilter_Tooltip:ClearLines();
		DebuffFilter_Tooltip:SetUnitBuff(unit, index);
	end);
	if (not ok) then return nil; end
	return DFTB_NormalizeName(DebuffFilter_TooltipTextLeft1:GetText());
end

local function DFTB_GetSpellDisplayInfo(spellID)
	local spellName = nil;
	local spellIcon = nil;
	local numericID = tonumber(spellID);
	if (numericID and type(SpellInfo) == "function") then
		local ok, name, rank, icon = pcall(SpellInfo, numericID);
		if (ok) then
			spellName = DFTB_NormalizeName(name);
			spellIcon = icon;
		end
	end
	if ((not spellName or not spellIcon) and numericID and type(GetSpellRecField) == "function") then
		local ok, name = pcall(GetSpellRecField, numericID, "name");
		if (ok and name) then spellName = DFTB_NormalizeName(name); end
	end
	if (not spellIcon or spellIcon == "") then
		spellIcon = "Interface\\Icons\\INV_Misc_QuestionMark";
	end
	return spellName, spellIcon;
end

local function DFTB_NormalizeCastState(rawState)
	if (rawState == nil) then return nil; end
	local state = string.upper(tostring(rawState));
	if (state == "CAST" or state == "SUCCESS" or state == "STOP" or state == "CHANNEL_STOP") then return "CAST"; end
	if (string.find(state, "FAIL") or string.find(state, "INTERRUPT")) then return "FAIL"; end
	if (string.find(state, "START") or state == "CHANNEL" or state == "CHANNELING") then return "START"; end
	return state;
end

local function DFTB_ResolveSpellID()
	local candidates = { arg4, arg5, arg6, arg7 };
	for _, rawValue in candidates do
		local numericID = tonumber(rawValue);
		if (numericID and numericID > 0) then
			local name = DFTB_GetSpellDisplayInfo(numericID);
			if (name) then return numericID; end
		end
	end
	return tonumber(arg4) or arg4;
end

local function DFTB_StateKey(guid, buffName)
	return tostring(guid or "unknown") .. "|" .. tostring(buffName or "unknown");
end

local function DFTB_GetOrCreateState(guid, buffName)
	if (not guid or not buffName) then return nil; end
	local key = DFTB_StateKey(guid, buffName);
	local state = DFTB.states[key];
	if (not state) then
		state = {
			key = key,
			guid = tostring(guid),
			buffName = buffName,
			created = GetTime(),
			lastSeen = nil,
			lastActivity = GetTime(),
			confirmed = false,
			knownTime = false,
		};
		DFTB.states[key] = state;
	end
	return state;
end

local function DFTB_RemoveState(key)
	if (key) then DFTB.states[key] = nil; end
end

local function DFTB_IsUnitPlayerLike(unit)
	if (not unit) then return false; end
	if (type(UnitIsPlayer) == "function") then
		local ok, isPlayer = pcall(UnitIsPlayer, unit);
		if (ok and isPlayer) then return true; end
	end
	if (type(UnitPlayerControlled) == "function") then
		local ok, controlled = pcall(UnitPlayerControlled, unit);
		if (ok and controlled) then return true; end
	end
	return false;
end

local function DFTB_ScanOneUnit(unit, scannedGUIDs, seenKeys)
	if (not unit) then return; end
	local guid = DFTB_GetUnitGUID(unit);
	if (not guid) then return; end
	if (scannedGUIDs[guid]) then return; end
	scannedGUIDs[guid] = 1;

	local unitName = DFTB_GetUnitName(unit);
	DFTB.unitCache[tostring(guid)] = { unit=unit, name=unitName };
	local now = GetTime();
	for index = 1, 32, 1 do
		local ok, texture, stacks, dispelType, auraID = pcall(UnitBuff, unit, index);
		if (not ok or not texture) then break; end
		local rawName = DFTB_GetBuffName(unit, index);
		local configuredName = DFTB_FindConfiguredName(rawName);
		if (configuredName) then
			local state = DFTB_GetOrCreateState(guid, configuredName);
			if (state) then
				state.unitName = unitName or state.unitName or tostring(guid);
				state.unit = unit;
				state.icon = texture or state.icon;
				state.stacks = tonumber(stacks) or 0;
				state.auraID = auraID or state.auraID;
				state.confirmed = true;
				state.lastSeen = now;
				state.lastActivity = now;
				seenKeys[state.key] = 1;
			end
		end
	end
end

local function DFTB_AddUnit(units, seen, unit)
	if (not unit or seen[unit]) then return; end
	local ok, exists = pcall(UnitExists, unit);
	if (ok and exists) then
		table.insert(units, unit);
		seen[unit] = 1;
	end
end

local function DFTB_CollectUnits()
	local units = {};
	local seen = {};
	DFTB_AddUnit(units, seen, "player");

	local raidCount = 0;
	if (type(GetNumRaidMembers) == "function") then raidCount = GetNumRaidMembers() or 0; end
	if (raidCount > 0) then
		for index = 1, raidCount, 1 do DFTB_AddUnit(units, seen, "raid" .. tostring(index)); end
	else
		local partyCount = 0;
		if (type(GetNumPartyMembers) == "function") then partyCount = GetNumPartyMembers() or 0; end
		for index = 1, partyCount, 1 do DFTB_AddUnit(units, seen, "party" .. tostring(index)); end
	end

	DFTB_AddUnit(units, seen, "target");
	DFTB_AddUnit(units, seen, "targettarget");
	DFTB_AddUnit(units, seen, "mouseover");
	return units;
end

local function DFTB_FindUnitByGUID(guid)
	if (not guid) then return nil, nil; end
	local wanted = tostring(guid);
	local cached = DFTB.unitCache and DFTB.unitCache[wanted] or nil;
	if (cached and cached.unit) then return cached.unit, cached.name; end
	local units = DFTB_CollectUnits();
	for index = 1, table.getn(units), 1 do
		local unit = units[index];
		local unitGUID = DFTB_GetUnitGUID(unit);
		if (unitGUID and tostring(unitGUID) == wanted) then
			local unitName = DFTB_GetUnitName(unit);
			DFTB.unitCache[wanted] = { unit=unit, name=unitName };
			return unit, unitName;
		end
	end
	return nil, nil;
end

local function DFTB_CleanupStates(scannedGUIDs, seenKeys)
	local now = GetTime();
	local remove = {};
	for key, state in DFTB.states do
		local monitored = DFTB_FindConfiguredName(state.buffName);
		if (not monitored) then
			table.insert(remove, key);
		elseif (state.endTime and now >= state.endTime + 0.20) then
			table.insert(remove, key);
		elseif (scannedGUIDs[state.guid] and not seenKeys[key] and now >= (state.graceUntil or 0)) then
			table.insert(remove, key);
		elseif (not state.endTime and now - (state.lastSeen or state.lastActivity or state.created or now) > DFTB.unknownExpire) then
			-- 未观察到本次施放、只靠扫描发现的旧 Buff；单位不再可扫描时短暂保留后移除。
			table.insert(remove, key);
		end
	end
	for index = 1, table.getn(remove), 1 do DFTB_RemoveState(remove[index]); end
end

local function DFTB_ScanAll()
	local config = DFTB_EnsureConfig();
	if (not config or config["target_buffs"] == "no") then return; end
	DFTB.unitCache = {};
	local scannedGUIDs = {};
	local seenKeys = {};
	local units = DFTB_CollectUnits();
	for index = 1, table.getn(units), 1 do
		DFTB_ScanOneUnit(units[index], scannedGUIDs, seenKeys);
	end

	-- SuperWoW 可直接把 GUID 作为 Unit 参数。对施法事件记录到、但不在当前小队/团队单位列表中的目标继续确认。
	local extraGUIDs = {};
	for key, state in DFTB.states do
		if (state.guid and not scannedGUIDs[state.guid]) then extraGUIDs[state.guid] = 1; end
	end
	for guid in extraGUIDs do
		DFTB_ScanOneUnit(guid, scannedGUIDs, seenKeys);
	end

	DFTB_CleanupStates(scannedGUIDs, seenKeys);
end

local function DFTB_MarkDirtyUnit(unit)
	if (not unit or unit == "") then return; end
	DFTB.dirtyUnits[tostring(unit)] = 1;
end

local function DFTB_ScanDirtyUnits()
	local config = DFTB_EnsureConfig();
	if (not config or config["target_buffs"] == "no") then DFTB.dirtyUnits = {}; return; end
	local dirty = DFTB.dirtyUnits;
	DFTB.dirtyUnits = {};
	local scannedGUIDs = {};
	local seenKeys = {};
	for unit in dirty do DFTB_ScanOneUnit(unit, scannedGUIDs, seenKeys); end
	DFTB_CleanupStates(scannedGUIDs, seenKeys);
end

local function DFTB_RecordCast()
	if (not DFTB_IsEnabled()) then return; end
	local castState = DFTB_NormalizeCastState(arg3);
	if (castState ~= "CAST") then return; end

	-- 先判断施法目标是否属于多人增益追踪范围，避免对所有战斗事件调用 SpellInfo/GetSpellRecField。
	local targetGUID = arg2 and tostring(arg2) or nil;
	if (not targetGUID or targetGUID == "0" or targetGUID == "nil") then return; end
	local matchedUnit, matchedName = DFTB_FindUnitByGUID(targetGUID);
	local directName = DFTB_GetUnitName(targetGUID);
	if (not DFTB_IsUnitPlayerLike(targetGUID) and not matchedUnit and not directName) then return; end
	local config = DFTB_EnsureConfig();
	if (config and config["only_mine_auras"] == "yes" and type(DebuffFilter_IsPlayerCasterGUID) == "function" and not DebuffFilter_IsPlayerCasterGUID(arg1)) then return; end

	local spellID = DFTB_ResolveSpellID();
	if (not spellID) then return; end
	local spellName, spellIcon = DFTB_GetSpellDisplayInfo(spellID);
	local configuredName = DFTB_FindConfiguredName(spellName);
	if (not configuredName) then return; end

	local now = GetTime();
	local state = DFTB_GetOrCreateState(targetGUID, configuredName);
	if (not state) then return; end
	state.unit = matchedUnit or state.unit;
	state.unitName = matchedName or directName or state.unitName or tostring(targetGUID);
	state.spellID = tonumber(spellID) or spellID;
	state.auraID = state.auraID or state.spellID;
	state.icon = spellIcon or state.icon;
	state.lastActivity = now;
	state.castTime = now;
	state.isMine = type(DebuffFilter_IsPlayerCasterGUID) == "function" and DebuffFilter_IsPlayerCasterGUID(arg1) or false;
	state.graceUntil = now + DFTB.castGrace;
	state.knownTime = false;
	local duration, timerSource = DFTB_GetDurationInfo(configuredName);
	state.timerSource = timerSource;
	if (duration) then
		state.duration = duration;
		state.endTime = now + duration;
		state.knownTime = true;
	else
		state.duration = nil;
		state.endTime = nil;
	end
	DFTB_MarkDirtyUnit(targetGUID);
end

-- 标准移动锚点：不再创建动态行、文字列或图标列表。
function DebuffFilter_CreateTargetBuffFrame()
	local existing = getglobal("DebuffFilter_TargetBuffFrame");
	if (existing) then return existing; end

	local frame = CreateFrame("Frame", "DebuffFilter_TargetBuffFrame", UIParent);
	frame:SetWidth(30);
	frame:SetHeight(30);
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 210);
	frame:SetMovable(1);
	frame:SetFrameStrata("HIGH");
	frame:SetFrameLevel(20);
	frame:Hide();

	local backdrop = CreateFrame("Button", "DebuffFilter_TargetBuffFrameBackdrop", frame, "DebuffFilter_BackdropTemplate");
	backdrop:SetPoint("CENTER", frame, "CENTER", 0, 0);
	backdrop:Hide();

	local title = backdrop:CreateFontString("DebuffFilter_TargetBuffFrameTitle", "ARTWORK", "GameFontNormal");
	title:SetWidth(90);
	title:SetHeight(12);
	title:SetPoint("TOP", backdrop, "TOP", 0, 15);
	title:SetText("多人增益");
	return frame;
end

-- 保留原动态列表的数据整理逻辑，但不再渲染。
-- 排序：已知剩余时间优先且从短到长；其次按玩家名、技能名。
local function DFTB_BuildTimerEntries()
	local entries = {};
	local now = GetTime();
	local remove = {};
	local config = DFTB_EnsureConfig();
	local onlyMine = config and config["only_mine_auras"] == "yes";
	for key, state in DFTB.states do
		if (state.endTime and now >= state.endTime + 0.20) then
			table.insert(remove, key);
		elseif (DFTB_FindConfiguredName(state.buffName) and (not onlyMine or state.isMine)) then
			state.remaining = nil;
			if (state.endTime) then
				state.remaining = state.endTime - now;
				if (state.remaining < 0) then state.remaining = 0; end
			end
			table.insert(entries, state);
		end
	end
	for index = 1, table.getn(remove), 1 do DFTB_RemoveState(remove[index]); end
	table.sort(entries, function(a, b)
		if (a.remaining and b.remaining) then
			if (math.abs(a.remaining - b.remaining) > 0.05) then return a.remaining < b.remaining; end
		elseif (a.remaining and not b.remaining) then
			return true;
		elseif (not a.remaining and b.remaining) then
			return false;
		end
		local an = tostring(a.unitName or a.guid or "");
		local bn = tostring(b.unitName or b.guid or "");
		if (an ~= bn) then return an < bn; end
		return tostring(a.buffName or "") < tostring(b.buffName or "");
	end);
	return entries;
end

-- 显示层数据接口。返回已经清理、计算 remaining 并排序后的状态数组。
function DebuffFilter_GetMultiTargetBuffTimerEntries()
	if (not DFTB_IsEnabled()) then return {}; end
	return DFTB_BuildTimerEntries();
end

-- 兼容模块命名的别名。
function DebuffFilter_TargetBuff_GetTimerEntries()
	return DebuffFilter_GetMultiTargetBuffTimerEntries();
end

function DebuffFilter_GetMultiTargetBuffStates()
	return DFTB.states;
end

-- 数据模块只维护扫描状态、排序数据与标准锚点可见状态。
function DebuffFilter_TargetBuffFrame_Update()
	local frame = DebuffFilter_CreateTargetBuffFrame();
	local backdrop = getglobal("DebuffFilter_TargetBuffFrameBackdrop");
	local moveVisible = DebuffFilter and DebuffFilter.backdrop == 1;
	if (backdrop) then
		if (moveVisible) then backdrop:Show(); else backdrop:Hide(); end
	end
	if (moveVisible or DFTB_IsEnabled()) then frame:Show(); else frame:Hide(); end
end

function DebuffFilter_TargetBuff_Rescan()
	DFTB.forceScan = true;
	DFTB_ScanAll();
	DebuffFilter_TargetBuffFrame_Update();
end

function DebuffFilter_TargetBuff_ApplyDurationRule(buffName)
	buffName = DFTB_NormalizeName(buffName);
	if (not buffName) then return; end
	local duration, timerSource = DFTB_GetDurationInfo(buffName);
	for key, state in DFTB.states do
		if (DFTB_NormalizeName(state.buffName) == buffName and state.castTime) then
			state.timerSource = timerSource;
			if (duration) then
				state.duration = duration;
				state.endTime = state.castTime + duration;
				state.knownTime = true;
			else
				state.duration = nil;
				state.endTime = nil;
				state.knownTime = false;
			end
		end
	end
	DebuffFilter_TargetBuffFrame_Update();
end

local function DFTB_PrintList()
	local config = DFTB_EnsureConfig();
	if (not config) then return; end
	DFTB_Print("多人增益监视名单：");
	local count = 0;
	for buffName, enabled in config["target_buff_list"] do
		if (enabled == 1) then
			count = count + 1;
			local duration, timerSource = DFTB_GetDurationInfo(buffName);
			local sourceText = "战斗记录";
			if (timerSource == "custom") then sourceText = "手工填写（优先）"; end
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff" .. tostring(buffName) .. "|r  " .. sourceText .. "=" .. (duration and tostring(duration) .. "秒" or "--"));
		end
	end
	if (count == 0) then DFTB_Print("（列表为空）"); end
end

local function DFTB_ScanCurrentTargetPrint()
	if (not UnitExists("target")) then DFTB_Print("当前没有目标。"); return; end
	local count = 0;
	for index = 1, 32, 1 do
		local texture, stacks, dispelType, auraID = UnitBuff("target", index);
		if (not texture) then break; end
		local name = DFTB_GetBuffName("target", index) or "<无法读取名称>";
		count = count + 1;
		DEFAULT_CHAT_FRAME:AddMessage(tostring(index) .. ". |cff00ccff" .. tostring(name) .. "|r 层数=" .. tostring(stacks or 0) .. " ID=" .. tostring(auraID or "nil"));
	end
	if (count == 0) then DFTB_Print("接口没有扫描到当前目标 Buff。"); end
end

local DFTB_OldCommand = DebuffFilter_command;
if (type(DFTB_OldCommand) == "function") then
	function DebuffFilter_command(message)
		local text = tostring(message or "");
		text = string.gsub(text, "^%s+", "");
		text = string.gsub(text, "%s+$", "");
		local _, _, command, parameter = string.find(text, "^(%S+)%s*(.-)$");
		command = string.lower(command or "");
		parameter = DFTB_NormalizeName(parameter);
		local config = DFTB_EnsureConfig();

		if (command == "tbadd" and parameter) then
			config["target_buff_list"][parameter] = 1;
			DFTB_Print("已添加多人增益追踪：|cff00ccff" .. parameter .. "|r");
			DebuffFilter_TargetBuff_Rescan();
			return;
		elseif (command == "tbdel" and parameter) then
			config["target_buff_list"][parameter] = nil;
			local remove = {};
			for key, state in DFTB.states do if (DFTB_NormalizeName(state.buffName) == DFTB_NormalizeName(parameter)) then table.insert(remove, key); end end
			for index = 1, table.getn(remove), 1 do DFTB_RemoveState(remove[index]); end
			DFTB_Print("已删除多人增益追踪：|cff00ccff" .. parameter .. "|r");
			DebuffFilter_TargetBuffFrame_Update();
			return;
		elseif (command == "tblist") then
			DFTB_PrintList();
			return;
		elseif (command == "tbscan") then
			DFTB_ScanCurrentTargetPrint();
			return;
		elseif (command == "tbtime" and parameter) then
			local _, _, buffName, seconds = string.find(parameter, "^(.+)%s+(%d+%.?%d*)$");
			buffName = DFTB_NormalizeName(buffName);
			seconds = tonumber(seconds);
			if (buffName and seconds and seconds > 0) then
				config["target_buff_duration_custom"][buffName] = seconds;
				DebuffFilter_TargetBuff_ApplyDurationRule(buffName);
				DFTB_Print("已设置目标 Buff 手工时间（优先）：|cff00ccff" .. buffName .. "|r = " .. tostring(seconds) .. " 秒");
			else
				DFTB_Print("格式：/dfilter tbtime Buff名称 秒数");
			end
			return;
		elseif (command == "tbtimeoff" and parameter) then
			config["target_buff_duration_custom"][parameter] = nil;
			DebuffFilter_TargetBuff_ApplyDurationRule(parameter);
			DFTB_Print("已改为战斗记录计时：|cff00ccff" .. parameter .. "|r");
			return;
		elseif (command == "targetbuffs") then
			if (config["target_buffs"] == "no") then config["target_buffs"] = "yes"; else config["target_buffs"] = "no"; end
			DFTB_Print("多人增益追踪：" .. (config["target_buffs"] == "yes" and "开启" or "关闭"));
			DebuffFilter_TargetBuff_Rescan();
			return;
		elseif (command == "tbframe") then
			local frame = DebuffFilter_CreateTargetBuffFrame();
			DebuffFilter.backdrop = 1;
			DebuffFilter_TargetBuffFrame_Update();
			if (frame) then frame:Show(); end
			local moveBackdrop = getglobal("DebuffFilter_TargetBuffFrameBackdrop");
			if (moveBackdrop) then moveBackdrop:Show(); end
			DFTB_Print("已强制显示多人增益移动框。");
			return;
		end
		DFTB_OldCommand(message);
	end
end

local DFTB_OldReset = DebuffFilter_ResetCurrentCharacter;
if (type(DFTB_OldReset) == "function") then
	function DebuffFilter_ResetCurrentCharacter()
		DFTB_OldReset();
		DFTB.states = {};
		local frame = DebuffFilter_CreateTargetBuffFrame();
		if (frame) then
			if (frame.SetUserPlaced) then frame:SetUserPlaced(false); end
			frame:ClearAllPoints();
			frame:SetPoint("CENTER", UIParent, "CENTER", 0, 210);
		end
		DebuffFilter_TargetBuff_Rescan();
	end
end

local DFTB_EventFrame = CreateFrame("Frame", "DebuffFilter_TargetBuffEventFrame", UIParent);
DFTB_EventFrame:RegisterEvent("VARIABLES_LOADED");
DFTB_EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
DFTB_EventFrame:RegisterEvent("UNIT_AURA");
DFTB_EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED");
DFTB_EventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED");
DFTB_EventFrame:RegisterEvent("RAID_ROSTER_UPDATE");
DFTB_EventFrame:RegisterEvent("UNIT_NAME_UPDATE");
DFTB_EventFrame:RegisterEvent("UNIT_CASTEVENT");
DFTB_EventFrame:SetScript("OnEvent", function()
	if (event == "VARIABLES_LOADED") then
		DFTB_EnsureConfig();
		DebuffFilter_CreateTargetBuffFrame();
		DFTB.forceScan = true;
		DebuffFilter_TargetBuffFrame_Update();
	elseif (event == "PLAYER_ENTERING_WORLD") then
		DFTB.hasSuperWoW = SUPERWOW_STRING and true or false;
		DFTB_EnsureConfig();
		DebuffFilter_CreateTargetBuffFrame();
		DFTB.forceScan = false;
		DFTB_ScanAll();
		DebuffFilter_TargetBuffFrame_Update();
	elseif (event == "UNIT_CASTEVENT") then
		DFTB_RecordCast();
	elseif (event == "UNIT_AURA") then
		if (arg1) then DFTB_MarkDirtyUnit(arg1); else DFTB.forceScan = true; end
	elseif (event == "PLAYER_TARGET_CHANGED") then
		DFTB_MarkDirtyUnit("target"); DFTB_MarkDirtyUnit("targettarget"); DFTB_MarkDirtyUnit("mouseover");
	elseif (event == "UNIT_NAME_UPDATE") then
		if (arg1) then DFTB_MarkDirtyUnit(arg1); else DFTB.forceScan = true; end
	elseif (event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE") then
		DFTB.forceScan = true;
	end
end);

DFTB_EventFrame:SetScript("OnUpdate", function()
	local elapsed = tonumber(arg1) or 0;
	DFTB.scanElapsed = DFTB.scanElapsed + elapsed;
	DFTB.dirtyElapsed = DFTB.dirtyElapsed + elapsed;
	-- 高频 UNIT_AURA 只扫描发生变化的单位；不再触发整团全量扫描。
	if (DFTB.dirtyElapsed >= DFTB.dirtyInterval and next(DFTB.dirtyUnits)) then
		DFTB.dirtyElapsed = 0;
		DFTB_ScanDirtyUnits();
	end
	-- 全量扫描只做低频兜底；队伍结构变化也至少合并0.5秒再执行。
	if (DFTB.scanElapsed >= DFTB.scanInterval or (DFTB.forceScan and DFTB.scanElapsed >= 0.50)) then
		DFTB.scanElapsed = 0;
		DFTB.forceScan = false;
		DFTB_ScanAll();
	end
end);

SLASH_DFTARGETBUFF1 = "/dftb";
SlashCmdList["DFTARGETBUFF"] = function(message)
	local text = DFTB_NormalizeName(message);
	if (not text) then
		if (type(DebuffFilter_Manager_Toggle) == "function") then DebuffFilter_Manager_Toggle(); end
	else
		DebuffFilter_command(text);
	end
end;
