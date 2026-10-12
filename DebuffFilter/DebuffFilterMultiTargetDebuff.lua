-- DebuffFilter v1.13.0
-- 多人减益数据采集与标准锚点。
-- 旧的动态文字列表渲染器已按用户要求删除；扫描、GUID状态、排序、剩余时间与玩家名称数据完整保留。
-- 多人减益显示数据由 DebuffFilter_GetMultiTargetDebuffTimerEntries() 提供。
-- 本文件不读取框体坐标，不在拖动、松开鼠标或 PLAYER_LOGOUT 中保存位置。

DebuffFilter_MultiTargetDebuff = DebuffFilter_MultiTargetDebuff or {};
local DFMTD = DebuffFilter_MultiTargetDebuff;

DFMTD.version = "1.14.5";
DFMTD.states = {};
DFMTD.scanElapsed = 0;
DFMTD.forceScan = true;
DFMTD.scanInterval = 2.00;
DFMTD.dirtyInterval = 0.15;
DFMTD.dirtyElapsed = 0;
DFMTD.dirtyUnits = {};
DFMTD.unitCache = {};
DFMTD.castGrace = 1.25;
DFMTD.unknownExpire = 3;
DFMTD.hasSuperWoW = SUPERWOW_STRING and true or false;

DebuffFilter.MultiTargetDebuffRules = DebuffFilter.MultiTargetDebuffRules or {};

local function DFMTD_NormalizeName(name)
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

local function DFMTD_GetConfig()
	if (not DebuffFilter_Config or not DebuffFilter_Player) then return nil; end
	return DebuffFilter_Config[DebuffFilter_Player];
end

local function DFMTD_EnsureConfig()
	local config = DFMTD_GetConfig();
	if (not config) then return nil; end
	if (config["multi_target_debuffs"] == nil) then config["multi_target_debuffs"] = "yes"; end
	if (type(config["multi_target_debuff_list"]) ~= "table") then
		config["multi_target_debuff_list"] = {};
	end
	if (type(config["multi_target_debuff_duration_custom"]) ~= "table") then
		config["multi_target_debuff_duration_custom"] = {};
	end
	return config;
end

local function DFMTD_IsEnabled()
	local config = DFMTD_EnsureConfig();
	return config and config["multi_target_debuffs"] ~= "no";
end

local function DFMTD_Print(message)
	if (type(DebuffFilter_Print) == "function") then
		DebuffFilter_Print(message);
	elseif (DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00减益监视|r " .. tostring(message));
	end
end

local function DFMTD_GetDurationInfo(debuffName)
	debuffName = DFMTD_NormalizeName(debuffName);
	if (not debuffName) then return nil, "unknown"; end
	local config = DFMTD_EnsureConfig();
	if (not config) then return nil, "unknown"; end

	-- 手工填写始终优先；没有填写时，才使用战斗记录施放起点 + 内置持续时间规则。
	local custom = config["multi_target_debuff_duration_custom"][debuffName];
	if (custom and tonumber(custom) and tonumber(custom) > 0) then
		return tonumber(custom), "custom";
	end

	local rule = DebuffFilter.MultiTargetDebuffRules and DebuffFilter.MultiTargetDebuffRules[debuffName];
	if (rule and tonumber(rule.base) and tonumber(rule.base) > 0) then
		return tonumber(rule.base), "combat";
	end
	return nil, "combat";
end

function DebuffFilter_GetMultiTargetDebuffDuration(debuffName)
	local duration = DFMTD_GetDurationInfo(debuffName);
	return duration;
end

local function DFMTD_FindConfiguredName(name)
	local config = DFMTD_EnsureConfig();
	if (not config or not name) then return nil; end
	if (type(DebuffFilter_FindConfiguredName) == "function") then
		return DebuffFilter_FindConfiguredName(config["multi_target_debuff_list"], name);
	end
	local normalized = DFMTD_NormalizeName(name);
	if (config["multi_target_debuff_list"][normalized]) then return normalized; end
	for configuredName in config["multi_target_debuff_list"] do
		if (DFMTD_NormalizeName(configuredName) == normalized) then return configuredName; end
	end
	return nil;
end

local function DFMTD_GetUnitGUID(unit)
	if (not unit) then return nil; end
	local ok, exists, guid = pcall(UnitExists, unit);
	if (not ok or not exists) then return nil; end
	if (guid) then return tostring(guid); end
	local name = nil;
	local nameOK, rawName = pcall(UnitName, unit);
	if (nameOK) then name = DFMTD_NormalizeName(rawName); end
	if (name) then return "name:" .. name; end
	return nil;
end

local function DFMTD_GetUnitName(unit)
	if (not unit) then return nil; end
	local ok, name = pcall(UnitName, unit);
	if (not ok) then return nil; end
	return DFMTD_NormalizeName(name);
end

local function DFMTD_GetDebuffName(unit, index)
	if (not DebuffFilter_Tooltip or not DebuffFilter_TooltipTextLeft1) then return nil; end
	local ok = pcall(function()
		DebuffFilter_Tooltip:SetOwner(UIParent, "ANCHOR_NONE");
		DebuffFilter_Tooltip:ClearLines();
		DebuffFilter_Tooltip:SetUnitDebuff(unit, index);
	end);
	if (not ok) then return nil; end
	return DFMTD_NormalizeName(DebuffFilter_TooltipTextLeft1:GetText());
end

local function DFMTD_GetSpellDisplayInfo(spellID)
	local spellName = nil;
	local spellIcon = nil;
	local numericID = tonumber(spellID);
	if (numericID and type(SpellInfo) == "function") then
		local ok, name, rank, icon = pcall(SpellInfo, numericID);
		if (ok) then
			spellName = DFMTD_NormalizeName(name);
			spellIcon = icon;
		end
	end
	if ((not spellName or not spellIcon) and numericID and type(GetSpellRecField) == "function") then
		local ok, name = pcall(GetSpellRecField, numericID, "name");
		if (ok and name) then spellName = DFMTD_NormalizeName(name); end
	end
	if (not spellIcon or spellIcon == "") then
		spellIcon = "Interface\\Icons\\INV_Misc_QuestionMark";
	end
	return spellName, spellIcon;
end

local function DFMTD_NormalizeCastState(rawState)
	if (rawState == nil) then return nil; end
	local state = string.upper(tostring(rawState));
	if (state == "CAST" or state == "SUCCESS" or state == "STOP" or state == "CHANNEL_STOP") then return "CAST"; end
	if (string.find(state, "FAIL") or string.find(state, "INTERRUPT")) then return "FAIL"; end
	if (string.find(state, "START") or state == "CHANNEL" or state == "CHANNELING") then return "START"; end
	return state;
end

local function DFMTD_ResolveSpellID()
	local candidates = { arg4, arg5, arg6, arg7 };
	for _, rawValue in candidates do
		local numericID = tonumber(rawValue);
		if (numericID and numericID > 0) then
			local name = DFMTD_GetSpellDisplayInfo(numericID);
			if (name) then return numericID; end
		end
	end
	return tonumber(arg4) or arg4;
end

local function DFMTD_StateKey(guid, debuffName)
	return tostring(guid or "unknown") .. "|" .. tostring(debuffName or "unknown");
end

local function DFMTD_GetOrCreateState(guid, debuffName)
	if (not guid or not debuffName) then return nil; end
	local key = DFMTD_StateKey(guid, debuffName);
	local state = DFMTD.states[key];
	if (not state) then
		state = {
			key = key,
			guid = tostring(guid),
			debuffName = debuffName,
			created = GetTime(),
			lastSeen = nil,
			lastActivity = GetTime(),
			confirmed = false,
			knownTime = false,
		};
		DFMTD.states[key] = state;
	end
	return state;
end

local function DFMTD_RemoveState(key)
	if (key) then DFMTD.states[key] = nil; end
end

local function DFMTD_IsUnitPlayerLike(unit)
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

local function DFMTD_ScanOneUnit(unit, scannedGUIDs, seenKeys)
	if (not unit) then return; end
	local guid = DFMTD_GetUnitGUID(unit);
	if (not guid) then return; end
	if (scannedGUIDs[guid]) then return; end
	scannedGUIDs[guid] = 1;

	local unitName = DFMTD_GetUnitName(unit);
	DFMTD.unitCache[tostring(guid)] = { unit=unit, name=unitName };
	local now = GetTime();
	for index = 1, 32, 1 do
		local ok, texture, stacks, dispelType, auraID = pcall(UnitDebuff, unit, index);
		if (not ok or not texture) then break; end
		local rawName = DFMTD_GetDebuffName(unit, index);
		local configuredName = DFMTD_FindConfiguredName(rawName);
		if (configuredName) then
			local state = DFMTD_GetOrCreateState(guid, configuredName);
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

local function DFMTD_AddUnit(units, seen, unit)
	if (not unit or seen[unit]) then return; end
	local ok, exists = pcall(UnitExists, unit);
	if (ok and exists) then
		table.insert(units, unit);
		seen[unit] = 1;
	end
end

local function DFMTD_CollectUnits()
	local units = {};
	local seen = {};
	DFMTD_AddUnit(units, seen, "player");

	local raidCount = 0;
	if (type(GetNumRaidMembers) == "function") then raidCount = GetNumRaidMembers() or 0; end
	if (raidCount > 0) then
		for index = 1, raidCount, 1 do DFMTD_AddUnit(units, seen, "raid" .. tostring(index)); end
	else
		local partyCount = 0;
		if (type(GetNumPartyMembers) == "function") then partyCount = GetNumPartyMembers() or 0; end
		for index = 1, partyCount, 1 do DFMTD_AddUnit(units, seen, "party" .. tostring(index)); end
	end

	return units;
end

local function DFMTD_FindUnitByGUID(guid)
	if (not guid) then return nil, nil; end
	local wanted = tostring(guid);
	local cached = DFMTD.unitCache and DFMTD.unitCache[wanted] or nil;
	if (cached and cached.unit) then return cached.unit, cached.name; end
	local units = DFMTD_CollectUnits();
	for index = 1, table.getn(units), 1 do
		local unit = units[index];
		local unitGUID = DFMTD_GetUnitGUID(unit);
		if (unitGUID and tostring(unitGUID) == wanted) then
			local unitName = DFMTD_GetUnitName(unit);
			DFMTD.unitCache[wanted] = { unit=unit, name=unitName };
			return unit, unitName;
		end
	end
	return nil, nil;
end

local function DFMTD_CleanupStates(scannedGUIDs, seenKeys)
	local now = GetTime();
	local remove = {};
	for key, state in DFMTD.states do
		local monitored = DFMTD_FindConfiguredName(state.debuffName);
		if (not monitored) then
			table.insert(remove, key);
		elseif (state.endTime and now >= state.endTime + 0.20) then
			table.insert(remove, key);
		elseif (scannedGUIDs[state.guid] and not seenKeys[key] and now >= (state.graceUntil or 0)) then
			table.insert(remove, key);
		elseif (not state.endTime and now - (state.lastSeen or state.lastActivity or state.created or now) > DFMTD.unknownExpire) then
			-- 未观察到本次施放、只靠扫描发现的旧 Debuff；单位不再可扫描时短暂保留后移除。
			table.insert(remove, key);
		end
	end
	for index = 1, table.getn(remove), 1 do DFMTD_RemoveState(remove[index]); end
end

local function DFMTD_ScanAll()
	local config = DFMTD_EnsureConfig();
	if (not config or config["multi_target_debuffs"] == "no") then return; end
	DFMTD.unitCache = {};
	local scannedGUIDs = {};
	local seenKeys = {};
	local units = DFMTD_CollectUnits();
	for index = 1, table.getn(units), 1 do
		DFMTD_ScanOneUnit(units[index], scannedGUIDs, seenKeys);
	end


	DFMTD_CleanupStates(scannedGUIDs, seenKeys);
end

local function DFMTD_MarkDirtyUnit(unit)
	if (not unit or unit == "") then return; end
	DFMTD.dirtyUnits[tostring(unit)] = 1;
end

local function DFMTD_ScanDirtyUnits()
	local config = DFMTD_EnsureConfig();
	if (not config or config["multi_target_debuffs"] == "no") then DFMTD.dirtyUnits = {}; return; end
	local dirty = DFMTD.dirtyUnits;
	DFMTD.dirtyUnits = {};
	local scannedGUIDs = {};
	local seenKeys = {};
	for unit in dirty do DFMTD_ScanOneUnit(unit, scannedGUIDs, seenKeys); end
	DFMTD_CleanupStates(scannedGUIDs, seenKeys);
end

local function DFMTD_RecordCast()
	if (not DFMTD_IsEnabled()) then return; end
	local castState = DFMTD_NormalizeCastState(arg3);
	if (castState ~= "CAST") then return; end

	-- 先判断目标GUID是否在自己/小队/团队中，再解析技能；大幅减少战斗中的无关 UNIT_CASTEVENT 成本。
	local targetGUID = arg2 and tostring(arg2) or nil;
	if (not targetGUID or targetGUID == "0" or targetGUID == "nil") then return; end
	local matchedUnit, matchedName = DFMTD_FindUnitByGUID(targetGUID);
	if (not matchedUnit) then return; end
	local config = DFMTD_EnsureConfig();
	if (config and config["only_mine_auras"] == "yes" and type(DebuffFilter_IsPlayerCasterGUID) == "function" and not DebuffFilter_IsPlayerCasterGUID(arg1)) then return; end

	local spellID = DFMTD_ResolveSpellID();
	if (not spellID) then return; end
	local spellName, spellIcon = DFMTD_GetSpellDisplayInfo(spellID);
	local configuredName = DFMTD_FindConfiguredName(spellName);
	if (not configuredName) then return; end
	local directName = matchedName;

	local now = GetTime();
	local state = DFMTD_GetOrCreateState(targetGUID, configuredName);
	if (not state) then return; end
	state.unit = matchedUnit or state.unit;
	state.unitName = matchedName or directName or state.unitName or tostring(targetGUID);
	state.spellID = tonumber(spellID) or spellID;
	state.auraID = state.auraID or state.spellID;
	state.icon = spellIcon or state.icon;
	state.lastActivity = now;
	state.castTime = now;
	state.isMine = type(DebuffFilter_IsPlayerCasterGUID) == "function" and DebuffFilter_IsPlayerCasterGUID(arg1) or false;
	state.graceUntil = now + DFMTD.castGrace;
	state.knownTime = false;
	local duration, timerSource = DFMTD_GetDurationInfo(configuredName);
	state.timerSource = timerSource;
	if (duration) then
		state.duration = duration;
		state.endTime = now + duration;
		state.knownTime = true;
	else
		state.duration = nil;
		state.endTime = nil;
	end
	DFMTD_MarkDirtyUnit(targetGUID);
end

-- 标准移动锚点：不再创建动态行、文字列或图标列表。
function DebuffFilter_CreateMultiTargetDebuffFrame()
	local existing = getglobal("DebuffFilter_MultiTargetDebuffFrame");
	if (existing) then return existing; end

	local frame = CreateFrame("Frame", "DebuffFilter_MultiTargetDebuffFrame", UIParent);
	frame:SetWidth(30);
	frame:SetHeight(30);
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 140);
	frame:SetMovable(1);
	frame:SetFrameStrata("HIGH");
	frame:SetFrameLevel(20);
	frame:Hide();

	local backdrop = CreateFrame("Button", "DebuffFilter_MultiTargetDebuffFrameBackdrop", frame, "DebuffFilter_BackdropTemplate");
	backdrop:SetPoint("CENTER", frame, "CENTER", 0, 0);
	backdrop:Hide();

	local title = backdrop:CreateFontString("DebuffFilter_MultiTargetDebuffFrameTitle", "ARTWORK", "GameFontNormal");
	title:SetWidth(90);
	title:SetHeight(12);
	title:SetPoint("TOP", backdrop, "TOP", 0, 15);
	title:SetText("多人减益");
	return frame;
end

-- 保留原动态列表的数据整理逻辑，但不再渲染。
-- 排序：已知剩余时间优先且从短到长；其次按玩家名、技能名。
local function DFMTD_BuildTimerEntries()
	local entries = {};
	local now = GetTime();
	local remove = {};
	local config = DFMTD_EnsureConfig();
	local onlyMine = config and config["only_mine_auras"] == "yes";
	for key, state in DFMTD.states do
		if (state.endTime and now >= state.endTime + 0.20) then
			table.insert(remove, key);
		elseif (DFMTD_FindConfiguredName(state.debuffName) and (not onlyMine or state.isMine)) then
			state.remaining = nil;
			if (state.endTime) then
				state.remaining = state.endTime - now;
				if (state.remaining < 0) then state.remaining = 0; end
			end
			table.insert(entries, state);
		end
	end
	for index = 1, table.getn(remove), 1 do DFMTD_RemoveState(remove[index]); end
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
		return tostring(a.debuffName or "") < tostring(b.debuffName or "");
	end);
	return entries;
end

-- 显示层数据接口。返回已经清理、计算 remaining 并排序后的状态数组。
function DebuffFilter_GetMultiTargetDebuffTimerEntries()
	if (not DFMTD_IsEnabled()) then return {}; end
	return DFMTD_BuildTimerEntries();
end

function DebuffFilter_MultiTargetDebuff_GetTimerEntries()
	return DebuffFilter_GetMultiTargetDebuffTimerEntries();
end

function DebuffFilter_GetMultiTargetDebuffStates()
	return DFMTD.states;
end

-- 数据模块只维护扫描状态、排序数据与标准锚点可见状态。
function DebuffFilter_MultiTargetDebuffFrame_Update()
	local frame = DebuffFilter_CreateMultiTargetDebuffFrame();
	local backdrop = getglobal("DebuffFilter_MultiTargetDebuffFrameBackdrop");
	local moveVisible = DebuffFilter and DebuffFilter.backdrop == 1;
	if (backdrop) then
		if (moveVisible) then backdrop:Show(); else backdrop:Hide(); end
	end
	if (moveVisible or DFMTD_IsEnabled()) then frame:Show(); else frame:Hide(); end
end

function DebuffFilter_MultiTargetDebuff_Rescan()
	DFMTD.forceScan = true;
	DFMTD_ScanAll();
	DebuffFilter_MultiTargetDebuffFrame_Update();
end

function DebuffFilter_MultiTargetDebuff_ApplyDurationRule(debuffName)
	debuffName = DFMTD_NormalizeName(debuffName);
	if (not debuffName) then return; end
	local duration, timerSource = DFMTD_GetDurationInfo(debuffName);
	for key, state in DFMTD.states do
		if (DFMTD_NormalizeName(state.debuffName) == debuffName and state.castTime) then
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
	DebuffFilter_MultiTargetDebuffFrame_Update();
end

local function DFMTD_PrintList()
	local config = DFMTD_EnsureConfig();
	if (not config) then return; end
	DFMTD_Print("多人减益追踪列表：");
	local count = 0;
	for debuffName, enabled in config["multi_target_debuff_list"] do
		if (enabled == 1) then
			count = count + 1;
			local duration, timerSource = DFMTD_GetDurationInfo(debuffName);
			local sourceText = "战斗记录";
			if (timerSource == "custom") then sourceText = "手工填写（优先）"; end
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff" .. tostring(debuffName) .. "|r  " .. sourceText .. "=" .. (duration and tostring(duration) .. "秒" or "--"));
		end
	end
	if (count == 0) then DFMTD_Print("（列表为空）"); end
end

local function DFMTD_ScanCurrentTargetPrint()
	if (not UnitExists("target")) then DFMTD_Print("当前没有目标。请选中队伍或团队成员后扫描。"); return; end
	local count = 0;
	for index = 1, 32, 1 do
		local texture, stacks, dispelType, auraID = UnitDebuff("target", index);
		if (not texture) then break; end
		local name = DFMTD_GetDebuffName("target", index) or "<无法读取名称>";
		count = count + 1;
		DEFAULT_CHAT_FRAME:AddMessage(tostring(index) .. ". |cff00ccff" .. tostring(name) .. "|r 层数=" .. tostring(stacks or 0) .. " ID=" .. tostring(auraID or "nil"));
	end
	if (count == 0) then DFMTD_Print("接口没有扫描到当前目标 Debuff。"); end
end

local DFMTD_OldCommand = DebuffFilter_command;
if (type(DFMTD_OldCommand) == "function") then
	function DebuffFilter_command(message)
		local text = tostring(message or "");
		text = string.gsub(text, "^%s+", "");
		text = string.gsub(text, "%s+$", "");
		local _, _, command, parameter = string.find(text, "^(%S+)%s*(.-)$");
		command = string.lower(command or "");
		parameter = DFMTD_NormalizeName(parameter);
		local config = DFMTD_EnsureConfig();

		if (command == "mtdadd" and parameter) then
			config["multi_target_debuff_list"][parameter] = 1;
			DFMTD_Print("已添加多人减益追踪：|cff00ccff" .. parameter .. "|r");
			DebuffFilter_MultiTargetDebuff_Rescan();
			return;
		elseif (command == "mtddel" and parameter) then
			config["multi_target_debuff_list"][parameter] = nil;
			local remove = {};
			for key, state in DFMTD.states do if (DFMTD_NormalizeName(state.debuffName) == DFMTD_NormalizeName(parameter)) then table.insert(remove, key); end end
			for index = 1, table.getn(remove), 1 do DFMTD_RemoveState(remove[index]); end
			DFMTD_Print("已删除多人减益追踪：|cff00ccff" .. parameter .. "|r");
			DebuffFilter_MultiTargetDebuffFrame_Update();
			return;
		elseif (command == "mtdlist") then
			DFMTD_PrintList();
			return;
		elseif (command == "mtdscan") then
			DFMTD_ScanCurrentTargetPrint();
			return;
		elseif (command == "mtdtime" and parameter) then
			local _, _, debuffName, seconds = string.find(parameter, "^(.+)%s+(%d+%.?%d*)$");
			debuffName = DFMTD_NormalizeName(debuffName);
			seconds = tonumber(seconds);
			if (debuffName and seconds and seconds > 0) then
				config["multi_target_debuff_duration_custom"][debuffName] = seconds;
				DebuffFilter_MultiTargetDebuff_ApplyDurationRule(debuffName);
				DFMTD_Print("已设置多人减益手工时间（优先）：|cff00ccff" .. debuffName .. "|r = " .. tostring(seconds) .. " 秒");
			else
				DFMTD_Print("格式：/dfilter mtdtime Debuff名称 秒数");
			end
			return;
		elseif (command == "mtdtimeoff" and parameter) then
			config["multi_target_debuff_duration_custom"][parameter] = nil;
			DebuffFilter_MultiTargetDebuff_ApplyDurationRule(parameter);
			DFMTD_Print("已改为战斗记录计时：|cff00ccff" .. parameter .. "|r");
			return;
		elseif (command == "multidebuffs") then
			if (config["multi_target_debuffs"] == "no") then config["multi_target_debuffs"] = "yes"; else config["multi_target_debuffs"] = "no"; end
			DFMTD_Print("多人减益追踪：" .. (config["multi_target_debuffs"] == "yes" and "开启" or "关闭"));
			DebuffFilter_MultiTargetDebuff_Rescan();
			return;
		elseif (command == "mtdframe") then
			local frame = DebuffFilter_CreateMultiTargetDebuffFrame();
			DebuffFilter.backdrop = 1;
			DebuffFilter_MultiTargetDebuffFrame_Update();
			if (frame) then frame:Show(); end
			local moveBackdrop = getglobal("DebuffFilter_MultiTargetDebuffFrameBackdrop");
			if (moveBackdrop) then moveBackdrop:Show(); end
			DFMTD_Print("已强制显示多人减益移动框。");
			return;
		end
		DFMTD_OldCommand(message);
	end
end

local DFMTD_OldReset = DebuffFilter_ResetCurrentCharacter;
if (type(DFMTD_OldReset) == "function") then
	function DebuffFilter_ResetCurrentCharacter()
		DFMTD_OldReset();
		DFMTD.states = {};
		local frame = DebuffFilter_CreateMultiTargetDebuffFrame();
		if (frame) then
			if (frame.SetUserPlaced) then frame:SetUserPlaced(false); end
			frame:ClearAllPoints();
			frame:SetPoint("CENTER", UIParent, "CENTER", 0, 140);
		end
		DebuffFilter_MultiTargetDebuff_Rescan();
	end
end

local DFMTD_EventFrame = CreateFrame("Frame", "DebuffFilter_MultiTargetDebuffEventFrame", UIParent);
DFMTD_EventFrame:RegisterEvent("VARIABLES_LOADED");
DFMTD_EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
DFMTD_EventFrame:RegisterEvent("UNIT_AURA");
DFMTD_EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED");
DFMTD_EventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED");
DFMTD_EventFrame:RegisterEvent("RAID_ROSTER_UPDATE");
DFMTD_EventFrame:RegisterEvent("UNIT_NAME_UPDATE");
DFMTD_EventFrame:RegisterEvent("UNIT_CASTEVENT");
DFMTD_EventFrame:SetScript("OnEvent", function()
	if (event == "VARIABLES_LOADED") then
		DFMTD_EnsureConfig();
		DebuffFilter_CreateMultiTargetDebuffFrame();
		DFMTD.forceScan = true;
		DebuffFilter_MultiTargetDebuffFrame_Update();
	elseif (event == "PLAYER_ENTERING_WORLD") then
		DFMTD.hasSuperWoW = SUPERWOW_STRING and true or false;
		DFMTD_EnsureConfig();
		DebuffFilter_CreateMultiTargetDebuffFrame();
		DFMTD.forceScan = false;
		DFMTD_ScanAll();
		DebuffFilter_MultiTargetDebuffFrame_Update();
	elseif (event == "UNIT_CASTEVENT") then
		DFMTD_RecordCast();
	elseif (event == "UNIT_AURA") then
		if (arg1) then DFMTD_MarkDirtyUnit(arg1); else DFMTD.forceScan = true; end
	elseif (event == "UNIT_NAME_UPDATE") then
		if (arg1) then DFMTD_MarkDirtyUnit(arg1); else DFMTD.forceScan = true; end
	elseif (event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE") then
		DFMTD.forceScan = true;
	end
end);

DFMTD_EventFrame:SetScript("OnUpdate", function()
	local elapsed = tonumber(arg1) or 0;
	DFMTD.scanElapsed = DFMTD.scanElapsed + elapsed;
	DFMTD.dirtyElapsed = DFMTD.dirtyElapsed + elapsed;
	-- 高频 UNIT_AURA 只扫描变化单位，避免整团 Debuff 每帧重扫。
	if (DFMTD.dirtyElapsed >= DFMTD.dirtyInterval and next(DFMTD.dirtyUnits)) then
		DFMTD.dirtyElapsed = 0;
		DFMTD_ScanDirtyUnits();
	end
	if (DFMTD.scanElapsed >= DFMTD.scanInterval or (DFMTD.forceScan and DFMTD.scanElapsed >= 0.50)) then
		DFMTD.scanElapsed = 0;
		DFMTD.forceScan = false;
		DFMTD_ScanAll();
	end
end);

SLASH_DFMULTIDEBUFF1 = "/dfmtd";
SlashCmdList["DFMULTIDEBUFF"] = function(message)
	local text = DFMTD_NormalizeName(message);
	if (not text) then
		if (type(DebuffFilter_Manager_Toggle) == "function") then DebuffFilter_Manager_Toggle(); end
	else
		DebuffFilter_command(text);
	end
end;
