-- DebuffFilter v1.13.0 private CandyBar timer subsystem.
--
-- Renderer and runtime are migrated from the user-supplied CandyBar-2.2 used by
-- Chronometer 1.18: double StatusBar background/progress layers, grouped stacking,
-- time updates, sorting, reverse fill, textures, scaling, fade/ghost and completion.
-- Aura discovery remains DebuffFilter's responsibility.
--
-- The library is registered as DebuffFilterCandyBar-2.2, so it does not share
-- handlers, groups, defaults or frame pools with Chronometer.  Timer bars have no
-- right-click or temporary-hide action.  Movement uses only existing DebuffFilter
-- anchors and StartMoving/StopMovingOrSizing.

DebuffFilter_TimerBars = DebuffFilter_TimerBars or {};
local DFTimer = DebuffFilter_TimerBars;

DFTimer.version = "1.14.5";
DFTimer.updateElapsed = 0;
DFTimer.updateInterval = 0.20;
DFTimer.maxMultiIcons = 32;
DFTimer.multiIconPools = {};
DFTimer.durationMemory = {};
DFTimer.activeBars = {};
DFTimer.expired = {};
DFTimer.orderSignatures = {};
DFTimer.entryByKey = {};
DFTimer.testUntil = nil;
DFTimer.testGroup = nil;
DFTimer.testEntries = nil;
DFTimer.candy = nil;
DFTimer.paint = nil;
DFTimer.candyError = nil;
DFTimer.warnedCandy = nil;
DFTimer.iconShineList = {};
DFTimer.iconShinesByGroup = {};
DFTimer.shineElapsed = 0;
DFTimer.shineClock = 0;
DFTimer.shineInterval = 0.06;
DFTimer.shineActiveCount = 0;

DFTimer.groupOrder = {
    "player_buff", "player_debuff", "target_buff", "target_debuff", "multi_buff", "multi_debuff",
};

DFTimer.groupInfo = {
    player_buff = { label="我的增益", frame="DebuffFilter_BuffFrame", backdrop="DebuffFilter_BuffFrameBackdrop", count="DebuffFilter_BuffFrameCount", commandDelete="del" },
    player_debuff = { label="我的减益", frame="DebuffFilter_PlayerDebuffFrame", backdrop="DebuffFilter_PlayerDebuffFrameBackdrop", count="DebuffFilter_PlayerDebuffFrameCount", commandDelete="pdel" },
    target_buff = { label="目标增益", frame="DebuffFilter_CurrentTargetBuffFrame", backdrop="DebuffFilter_CurrentTargetBuffFrameBackdrop", count="DebuffFilter_CurrentTargetBuffFrameCount", commandDelete="ctbdel" },
    target_debuff = { label="目标减益", frame="DebuffFilter_DebuffFrame", backdrop="DebuffFilter_DebuffFrameBackdrop", count="DebuffFilter_DebuffFrameCount", commandDelete="ddel" },
    multi_buff = { label="多人增益", frame="DebuffFilter_TargetBuffFrame", backdrop="DebuffFilter_TargetBuffFrameBackdrop", count=nil, commandDelete="tbdel" },
    multi_debuff = { label="多人减益", frame="DebuffFilter_MultiTargetDebuffFrame", backdrop="DebuffFilter_MultiTargetDebuffFrameBackdrop", count=nil, commandDelete="mtddel" },
    test = { label="计时条测试", frame="DebuffFilter_TimerTestAnchor", backdrop=nil, count=nil, commandDelete=nil },
};

DFTimer.textureOrderLegacy = {
    { text="Default", value="Default" },
    { text="Frost", value="Frost" },
    { text="Banto", value="banto" }, { text="Smooth", value="smooth" }, { text="Perl", value="perl" },
    { text="Glaze", value="glaze" }, { text="Cilo", value="cilo" }, { text="Charcoal", value="Charcoal" },
    { text="Diagonal", value="Diagonal" }, { text="Fifths", value="Fifths" }, { text="Smoothv2", value="Smoothv2" },
    { text="Healbot", value="Healbot" }, { text="LiteStep", value="LiteStep" }, { text="LiteStepLite", value="LiteStepLite" },
    { text="Rocks", value="Rocks" }, { text="Runes", value="Runes" }, { text="Xeon", value="Xeon" },
};
DFTimer.textureOrderCustom = {
    { text="大爱心", value="DF_LargeHeart" }, { text="大爪印", value="DF_LargePaw" },
    { text="大兔子", value="DF_LargeRabbit" }, { text="大猫咪", value="DF_LargeCat" },
    { text="大熊", value="DF_LargeBear" }, { text="大机器人", value="DF_LargeRobot" },
    { text="大齿轮", value="DF_LargeGears" }, { text="大月星", value="DF_LargeMoonStar" },
    { text="萌宠组合", value="DF_LargeAnimals" }, { text="科技终端", value="DF_LargeCuteTech" },
};
DFTimer.textureOrder = {};
do
    local index;
    for index = 1, table.getn(DFTimer.textureOrderLegacy), 1 do table.insert(DFTimer.textureOrder, DFTimer.textureOrderLegacy[index]); end
    for index = 1, table.getn(DFTimer.textureOrderCustom), 1 do table.insert(DFTimer.textureOrder, DFTimer.textureOrderCustom[index]); end
end
DFTimer.texturePaths = {
    Default="Interface\\TargetingFrame\\UI-StatusBar",
    Frost="Interface\\AddOns\\DebuffFilter\\Textures\\Frost",
    banto="Interface\\AddOns\\DebuffFilter\\Textures\\banto",
    smooth="Interface\\AddOns\\DebuffFilter\\Textures\\smooth",
    perl="Interface\\AddOns\\DebuffFilter\\Textures\\perl",
    glaze="Interface\\AddOns\\DebuffFilter\\Textures\\glaze",
    cilo="Interface\\AddOns\\DebuffFilter\\Textures\\cilo",
    Charcoal="Interface\\AddOns\\DebuffFilter\\Textures\\Charcoal",
    Diagonal="Interface\\AddOns\\DebuffFilter\\Textures\\Diagonal",
    Fifths="Interface\\AddOns\\DebuffFilter\\Textures\\Fifths",
    Smoothv2="Interface\\AddOns\\DebuffFilter\\Textures\\Smoothv2",
    Healbot="Interface\\AddOns\\DebuffFilter\\Textures\\Healbot",
    LiteStep="Interface\\AddOns\\DebuffFilter\\Textures\\LiteStep",
    LiteStepLite="Interface\\AddOns\\DebuffFilter\\Textures\\LiteStepLite",
    Rocks="Interface\\AddOns\\DebuffFilter\\Textures\\Rocks",
    Runes="Interface\\AddOns\\DebuffFilter\\Textures\\Runes",
    Xeon="Interface\\AddOns\\DebuffFilter\\Textures\\Xeon",
    DF_LargeHeart="Interface\\AddOns\\DebuffFilter\\Textures\\DF_LargeHeart",
    DF_LargePaw="Interface\\AddOns\\DebuffFilter\\Textures\\DF_LargePaw",
    DF_LargeRabbit="Interface\\AddOns\\DebuffFilter\\Textures\\DF_LargeRabbit",
    DF_LargeCat="Interface\\AddOns\\DebuffFilter\\Textures\\DF_LargeCat",
    DF_LargeBear="Interface\\AddOns\\DebuffFilter\\Textures\\DF_LargeBear",
    DF_LargeRobot="Interface\\AddOns\\DebuffFilter\\Textures\\DF_LargeRobot",
    DF_LargeGears="Interface\\AddOns\\DebuffFilter\\Textures\\DF_LargeGears",
    DF_LargeMoonStar="Interface\\AddOns\\DebuffFilter\\Textures\\DF_LargeMoonStar",
    DF_LargeAnimals="Interface\\AddOns\\DebuffFilter\\Textures\\DF_LargeAnimals",
    DF_LargeCuteTech="Interface\\AddOns\\DebuffFilter\\Textures\\DF_LargeCuteTech",
};

DFTimer.colorOrder = { "科技蓝", "青色", "绿色", "金色", "橙色", "红色", "紫色", "灰色", "白色", "黑色" };
DFTimer.colorPresets = {
    ["科技蓝"]={0.10,0.52,0.88,1}, ["青色"]={0.05,0.72,0.78,1}, ["绿色"]={0.10,0.72,0.34,1},
    ["金色"]={0.92,0.72,0.16,1}, ["橙色"]={0.94,0.42,0.10,1}, ["红色"]={0.86,0.16,0.18,1},
    ["紫色"]={0.58,0.26,0.82,1}, ["灰色"]={0.46,0.50,0.56,1}, ["白色"]={0.92,0.96,1,1}, ["黑色"]={0.02,0.03,0.05,1},
};

local TIMER_SCHEMA = 5;

local DEFAULT_MODES = { player_buff="icon", player_debuff="icon", target_buff="icon", target_debuff="icon", multi_buff="icon", multi_debuff="icon" };
local DEFAULT_STYLE = {
    -- Default appearance: gray progress, teal background, white text, LiteStep texture.
    texture="LiteStep", bar_color={0.50,0.50,0.50,1}, background_color={0.00,0.50,0.50,1}, text_color="白色", background_alpha=1.00,
    width=200, height=20, scale=1.00, spacing=2, icon_position="LEFT", grow_up="no", reverse="no",
    text_template="$s  $t", text_size=10, ghost=0, show_icon="yes", show_text="yes", show_time="yes",
    fade_on_remove="yes", fade_on_death="yes", random_bar_color="no",
};

local function DFT_CopyTable(source)
	if (type(source) ~= "table") then return source; end
	local result = {};
	local key, value;
	for key, value in source do
		if (type(value) == "table") then result[key] = DFT_CopyTable(value); else result[key] = value; end
	end
	return result;
end

local function DFT_NormalizeName(name)
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

local function DFT_GetConfig()
	if (not DebuffFilter_Config or not DebuffFilter_Player) then return nil; end
	return DebuffFilter_Config[DebuffFilter_Player];
end

local function DFT_Clamp(value, minimum, maximum, fallback)
	value = tonumber(value);
	if (not value) then value = fallback; end
	if (value < minimum) then value = minimum; end
	if (value > maximum) then value = maximum; end
	return value;
end

local function DFT_EnsureStyleValues(style)
	if (type(style) ~= "table") then style = DFT_CopyTable(DEFAULT_STYLE); end
	local key, value;
	for key, value in DEFAULT_STYLE do if (style[key] == nil) then style[key] = DFT_CopyTable(value); end end
	if (not DFTimer.texturePaths[style.texture]) then style.texture = DEFAULT_STYLE.texture; end
	if (type(style.bar_color) ~= "table" and not DFTimer.colorPresets[style.bar_color]) then style.bar_color = DFT_CopyTable(DEFAULT_STYLE.bar_color); end
	if (type(style.background_color) ~= "table" and not DFTimer.colorPresets[style.background_color]) then style.background_color = DFT_CopyTable(DEFAULT_STYLE.background_color); end
	if (type(style.text_color) ~= "table" and not DFTimer.colorPresets[style.text_color]) then style.text_color = DEFAULT_STYLE.text_color; end
	style.width = DFT_Clamp(style.width, 50, 300, DEFAULT_STYLE.width);
	style.height = DFT_Clamp(style.height, 8, 30, DEFAULT_STYLE.height);
	style.scale = DFT_Clamp(style.scale, 0.50, 1.50, DEFAULT_STYLE.scale);
	style.spacing = DFT_Clamp(style.spacing, 0, 15, DEFAULT_STYLE.spacing);
	style.text_size = DFT_Clamp(style.text_size, 8, 20, DEFAULT_STYLE.text_size);
	style.ghost = DFT_Clamp(style.ghost, 0, 30, DEFAULT_STYLE.ghost);
	style.background_alpha = DFT_Clamp(style.background_alpha, 0, 1, DEFAULT_STYLE.background_alpha);
	style.icon_position = "LEFT";
	if (style.text_template == nil or tostring(style.text_template) == "") then style.text_template = DEFAULT_STYLE.text_template; end
	return style;
end

local function DFT_EnsureConfig()
	local config = DFT_GetConfig();
	if (not config) then return nil; end
	if (type(config["aura_display_modes"]) ~= "table") then config["aura_display_modes"] = DFT_CopyTable(DEFAULT_MODES); end
	local index;
	for index = 1, table.getn(DFTimer.groupOrder), 1 do
		local group = DFTimer.groupOrder[index];
		local mode = config["aura_display_modes"][group];
		if (mode ~= "icon" and mode ~= "bar" and mode ~= "off") then config["aura_display_modes"][group] = DEFAULT_MODES[group]; end
	end
	if (type(config["aura_icon_shine"]) ~= "table") then config["aura_icon_shine"] = {}; end
	for index = 1, table.getn(DFTimer.groupOrder), 1 do
		local shineGroup = DFTimer.groupOrder[index];
		if (config["aura_icon_shine"][shineGroup] ~= "yes" and config["aura_icon_shine"][shineGroup] ~= "no") then
			config["aura_icon_shine"][shineGroup] = "no";
		end
	end
	-- v1.13.4 keeps six independent timer-bar appearance profiles while keeping
	-- a representative "全部" style block for the UI.
	local seedStyle = type(config["timer_bar_settings"]) == "table" and DFT_CopyTable(config["timer_bar_settings"]) or DFT_CopyTable(DEFAULT_STYLE);
	if (config["timer_bar_schema"] ~= TIMER_SCHEMA) then
		config["timer_bar_settings"] = DFT_EnsureStyleValues(seedStyle);
		config["timer_bar_group_styles"] = {};
		for index = 1, table.getn(DFTimer.groupOrder), 1 do
			config["timer_bar_group_styles"][DFTimer.groupOrder[index]] = DFT_CopyTable(config["timer_bar_settings"]);
		end
		config["timer_bar_schema"] = TIMER_SCHEMA;
	else
		config["timer_bar_settings"] = DFT_EnsureStyleValues(config["timer_bar_settings"]);
		if (type(config["timer_bar_group_styles"]) ~= "table") then config["timer_bar_group_styles"] = {}; end
		for index = 1, table.getn(DFTimer.groupOrder), 1 do
			local group = DFTimer.groupOrder[index];
			local groupStyle = config["timer_bar_group_styles"][group];
			if (type(groupStyle) ~= "table") then groupStyle = DFT_CopyTable(config["timer_bar_settings"]); end
			config["timer_bar_group_styles"][group] = DFT_EnsureStyleValues(groupStyle);
		end
	end
	config["timer_bar_settings"] = DFT_EnsureStyleValues(config["timer_bar_settings"]);
	return config;
end

local function DFT_GetStyleForGroup(group)
	local config = DFT_EnsureConfig();
	if (not config) then return DEFAULT_STYLE; end
	if (group and type(config["timer_bar_group_styles"]) == "table" and type(config["timer_bar_group_styles"][group]) == "table") then
		return config["timer_bar_group_styles"][group];
	end
	return config["timer_bar_settings"] or DEFAULT_STYLE;
end

function DebuffFilter_TimerBars_GetConfig()
	return DFT_EnsureConfig();
end

function DebuffFilter_GetAuraDisplayMode(group)
	local config = DFT_EnsureConfig();
	if (not config or not DEFAULT_MODES[group]) then return "icon"; end
	return config["aura_display_modes"][group] or "icon";
end

function DebuffFilter_SetAuraDisplayMode(group, mode)
	local config = DFT_EnsureConfig();
	if (not config or not DEFAULT_MODES[group]) then return false; end
	if (mode ~= "icon" and mode ~= "bar" and mode ~= "off") then return false; end
	config["aura_display_modes"][group] = mode;
	DFTimer.RefreshAll(true);
	return true;
end

function DebuffFilter_GetAuraIconShine(group)
	local config = DFT_EnsureConfig();
	if (not config or not DEFAULT_MODES[group]) then return false; end
	return config["aura_icon_shine"] and config["aura_icon_shine"][group] == "yes";
end

function DebuffFilter_SetAuraIconShine(group, enabled)
	local config = DFT_EnsureConfig();
	if (not config or not DEFAULT_MODES[group]) then return false; end
	config["aura_icon_shine"][group] = enabled and "yes" or "no";
	if (type(DebuffFilter_TimerBars_RefreshIconShine) == "function") then DebuffFilter_TimerBars_RefreshIconShine(group); end
	return true;
end

function DebuffFilter_TimerBars_GetOption(key)
	local config = DFT_EnsureConfig();
	if (not config) then return nil; end
	return config["timer_bar_settings"][key];
end

function DebuffFilter_TimerBars_SetOption(key, value)
	local config = DFT_EnsureConfig();
	if (not config or DEFAULT_STYLE[key] == nil) then return false; end
	local storedValue = type(value) == "table" and DFT_CopyTable(value) or value;
	config["timer_bar_settings"][key] = storedValue;
	local index;
	for index = 1, table.getn(DFTimer.groupOrder), 1 do
		local group = DFTimer.groupOrder[index];
		if (type(config["timer_bar_group_styles"]) == "table" and type(config["timer_bar_group_styles"][group]) == "table") then
			config["timer_bar_group_styles"][group][key] = type(value) == "table" and DFT_CopyTable(value) or value;
		end
	end
	DFT_EnsureConfig();
	DFTimer.RefreshAll(true);
	return true;
end

function DebuffFilter_TimerBars_GetTextureNames()
	return DFTimer.textureOrder;
end

function DebuffFilter_TimerBars_GetLegacyTextureNames()
	return DFTimer.textureOrderLegacy;
end

function DebuffFilter_TimerBars_GetCustomTextureNames()
	return DFTimer.textureOrderCustom;
end

function DebuffFilter_TimerBars_GetStyleTargets()
	return {
		{ text="全部", value="all" },
		{ text="我的增益", value="player_buff" },
		{ text="我的减益", value="player_debuff" },
		{ text="目标增益", value="target_buff" },
		{ text="目标减益", value="target_debuff" },
		{ text="多人增益", value="multi_buff" },
		{ text="多人减益", value="multi_debuff" },
	};
end

function DebuffFilter_TimerBars_GetTextureDisplayName(value)
    local index, entry;
    for index = 1, table.getn(DFTimer.textureOrder or {}), 1 do
        entry = DFTimer.textureOrder[index];
        if (type(entry) == "table" and entry.value == value) then return entry.text or tostring(value); end
        if (entry == value) then return tostring(value); end
    end
    return tostring(value or "");
end

function DebuffFilter_TimerBars_GetColorNames()
	return DFTimer.colorOrder;
end

local function DFT_FindConfiguredName(list, rawName)
	if (type(list) ~= "table") then return nil; end
	local normalized = DFT_NormalizeName(rawName);
	if (not normalized) then return nil; end
	if (list[normalized] == 1) then return normalized; end
	local configuredName, enabled;
	for configuredName, enabled in list do
		if (enabled == 1 and DFT_NormalizeName(configuredName) == normalized) then return configuredName; end
	end
	return nil;
end

local function DFT_GetUnitKey(unit)
	local ok, exists, guid = pcall(UnitExists, unit);
	if (not ok or not exists) then return nil; end
	if (guid) then return tostring(guid); end
	local name = UnitName(unit);
	if (name) then return "name:" .. tostring(name); end
	return nil;
end

local function DFT_GetPlayerBuffName(buffIndex)
	if (not DebuffFilter_Tooltip or not DebuffFilter_TooltipTextLeft1) then return nil; end
	DebuffFilter_Tooltip:SetOwner(UIParent, "ANCHOR_NONE");
	DebuffFilter_Tooltip:ClearLines();
	DebuffFilter_Tooltip:SetPlayerBuff(buffIndex);
	return DFT_NormalizeName(DebuffFilter_TooltipTextLeft1:GetText());
end

local function DFT_GetUnitAuraName(unit, index, helpful)
	if (not DebuffFilter_Tooltip or not DebuffFilter_TooltipTextLeft1) then return nil; end
	local ok = pcall(function()
		DebuffFilter_Tooltip:SetOwner(UIParent, "ANCHOR_NONE");
		DebuffFilter_Tooltip:ClearLines();
		if (helpful) then DebuffFilter_Tooltip:SetUnitBuff(unit, index); else DebuffFilter_Tooltip:SetUnitDebuff(unit, index); end
	end);
	if (not ok) then return nil; end
	return DFT_NormalizeName(DebuffFilter_TooltipTextLeft1:GetText());
end

local function DFT_RememberDuration(group, key, remaining)
	remaining = tonumber(remaining);
	if (not remaining or remaining <= 0) then return nil; end
	if (not DFTimer.durationMemory[group]) then DFTimer.durationMemory[group] = {}; end
	local remembered = tonumber(DFTimer.durationMemory[group][key]) or 0;
	if (remaining > remembered) then remembered = remaining; DFTimer.durationMemory[group][key] = remembered; end
	return remembered;
end

local function DFT_FormatTime(seconds)
	seconds = tonumber(seconds);
	if (not seconds or seconds < 0) then return "--"; end
	if (seconds < 10) then return string.format("%.1f", seconds); end
	if (seconds < 60) then return tostring(math.ceil(seconds)); end
	return SecondsToTimeAbbrev(math.ceil(seconds));
end

local function DFT_SortEntries(entries)
	table.sort(entries, function(a, b)
		if (a.ghost and not b.ghost) then return false; end
		if (not a.ghost and b.ghost) then return true; end
		if (a.remaining and b.remaining) then
			if (math.abs(a.remaining - b.remaining) > 0.05) then return a.remaining < b.remaining; end
		elseif (a.remaining and not b.remaining) then return true;
		elseif (not a.remaining and b.remaining) then return false; end
		local at = tostring(a.targetName or "");
		local bt = tostring(b.targetName or "");
		if (at ~= bt) then return at < bt; end
		return tostring(a.spellName or "") < tostring(b.spellName or "");
	end);
	return entries;
end

local function DFT_GetPlayerBuffEntries()
	local entries = {};
	local config = DFT_EnsureConfig();
	if (not config or config["player_auras"] == "no" or config["buffs"] == "no") then return entries; end
	local slot;
	for slot = 0, 31, 1 do
		local buffIndex, untilCancelled = GetPlayerBuff(slot, "HELPFUL");
		if (buffIndex and buffIndex >= 0) then
			local rawName = DFT_GetPlayerBuffName(buffIndex);
			local configuredName = DFT_FindConfiguredName(config["buff_list"], rawName);
			if (configuredName) then
				local remaining = nil;
				if (untilCancelled ~= 1) then remaining = tonumber(GetPlayerBuffTimeLeft(buffIndex)); end
				local key = "player_buff|" .. tostring(configuredName);
				local duration = DFT_RememberDuration("player_buff", key, remaining);
				table.insert(entries, {
					key=key, group="player_buff", spellName=configuredName, targetName="",
					icon=GetPlayerBuffTexture(buffIndex), stacks=tonumber(GetPlayerBuffApplications(buffIndex)) or 0,
					remaining=remaining, duration=duration, endTime=remaining and (GetTime() + remaining) or nil,
					auraIndex=buffIndex, tooltipType="playerbuff",
				});
			end
		end
	end
	return DFT_SortEntries(entries);
end

local function DFT_BuildPlayerHarmfulTimes()
	local result = {};
	local slot;
	for slot = 0, 31, 1 do
		local buffIndex, untilCancelled = GetPlayerBuff(slot, "HARMFUL");
		if (buffIndex and buffIndex >= 0) then
			local name = DFT_GetPlayerBuffName(buffIndex);
			if (name) then
				local remaining = nil;
				if (untilCancelled ~= 1) then remaining = tonumber(GetPlayerBuffTimeLeft(buffIndex)); end
				result[name] = { remaining=remaining, buffIndex=buffIndex, untilCancelled=untilCancelled };
			end
		end
	end
	return result;
end

local function DFT_GetPlayerDebuffEntries()
	local entries = {};
	local config = DFT_EnsureConfig();
	if (not config or config["player_auras"] == "no" or config["player_debuffs"] == "no") then return entries; end
	local harmful = DFT_BuildPlayerHarmfulTimes();
	local index;
	for index = 1, 32, 1 do
		local texture, stacks, dispelType, auraID = UnitDebuff("player", index);
		if (not texture) then break; end
		local rawName = DFT_GetUnitAuraName("player", index, false);
		local configuredName = DFT_FindConfiguredName(config["player_debuff_list"], rawName);
		if (configuredName) then
			local timeInfo = harmful[DFT_NormalizeName(rawName) or configuredName];
			local remaining = timeInfo and timeInfo.remaining or nil;
			local key = "player_debuff|" .. tostring(auraID or configuredName);
			local duration = DFT_RememberDuration("player_debuff", key, remaining);
			table.insert(entries, {
				key=key, group="player_debuff", spellName=configuredName, targetName="",
				icon=texture, stacks=tonumber(stacks) or 0, dispelType=dispelType,
				remaining=remaining, duration=duration, endTime=remaining and (GetTime() + remaining) or nil,
				auraIndex=index, tooltipType="unitdebuff", tooltipUnit="player",
			});
		end
	end
	return DFT_SortEntries(entries);
end

local function DFT_GetTargetBuffEntries()
	local entries = {};
	local config = DFT_EnsureConfig();
	if (not config or config["current_target_buffs"] == "no" or not UnitExists("target") or UnitIsDead("target")) then return entries; end
	local guid = DFT_GetUnitKey("target");
	local targetName = UnitName("target") or "目标";
	local now = GetTime();
	local index;
	for index = 1, 32, 1 do
		local texture, stacks, dispelType, auraID = UnitBuff("target", index);
		if (not texture) then break; end
		local rawName = DFT_GetUnitAuraName("target", index, true);
		local configuredName = DFT_FindConfiguredName(config["current_target_buff_list"], rawName);
		if (configuredName) then
			local stateKey = tostring(guid or "unknown") .. "|" .. tostring(configuredName);
			local duration = type(DebuffFilter_GetCurrentTargetBuffDuration) == "function" and DebuffFilter_GetCurrentTargetBuffDuration(configuredName) or nil;
			local record = DebuffFilter_CurrentTargetBuff and DebuffFilter_CurrentTargetBuff.castRecords and DebuffFilter_CurrentTargetBuff.castRecords[stateKey] or nil;
			local sourceAllowed = config["only_mine_auras"] ~= "yes" or (record and record.isMine);
			if (sourceAllowed) then
			local endTime = record and record.endTime or nil;
			if (not endTime and duration and DebuffFilter_CurrentTargetBuff and DebuffFilter_CurrentTargetBuff.firstSeen) then
				local firstSeen = DebuffFilter_CurrentTargetBuff.firstSeen[stateKey];
				if (firstSeen) then endTime = firstSeen + duration; end
			end
			local remaining = endTime and (endTime - now) or nil;
			if (remaining and remaining < 0) then remaining = 0; end
			table.insert(entries, {
				key="target_buff|" .. stateKey, group="target_buff", spellName=configuredName, targetName=targetName,
				icon=texture, stacks=tonumber(stacks) or 0, remaining=remaining, duration=duration,
				endTime=endTime, auraIndex=index, tooltipType="unitbuff", tooltipUnit="target",
			});
			end
		end
	end
	return DFT_SortEntries(entries);
end

local function DFT_GetTargetDebuffEntries()
	local entries = {};
	local config = DFT_EnsureConfig();
	if (not config or config["debuffs"] == "no" or not UnitExists("target") or UnitIsDead("target")) then return entries; end
	local targetKey = DebuffFilter.currentTargetKey or DFT_GetUnitKey("target");
	local targetName = UnitName("target") or "目标";
	local now = GetTime();
	local index;
	for index = 1, 32, 1 do
		local texture, stacks, dispelType, auraID = UnitDebuff("target", index);
		if (not texture) then break; end
		local rawName = DFT_GetUnitAuraName("target", index, false);
		local configuredName = DFT_FindConfiguredName(config["debuff_list"], rawName);
		local sourceAllowed = config["only_mine_auras"] ~= "yes" or (type(DebuffFilter_IsTargetDebuffMine) == "function" and DebuffFilter_IsTargetDebuffMine(targetKey, rawName, auraID));
		if (configuredName and sourceAllowed) then
			local timer = targetKey and DebuffFilter.targetTimers and DebuffFilter.targetTimers[targetKey] and DebuffFilter.targetTimers[targetKey][configuredName] or nil;
			local remaining = timer and timer.endTime and (timer.endTime - now) or nil;
			if (remaining and remaining < 0) then remaining = 0; end
			table.insert(entries, {
				key="target_debuff|" .. tostring(targetKey or "unknown") .. "|" .. tostring(configuredName),
				group="target_debuff", spellName=configuredName, targetName=targetName,
				icon=texture, stacks=tonumber(stacks) or 0, remaining=remaining,
				duration=timer and timer.duration or nil, endTime=timer and timer.endTime or nil,
				auraIndex=index, tooltipType="unitdebuff", tooltipUnit="target",
			});
		end
	end
	return DFT_SortEntries(entries);
end

local function DFT_CopyMultiEntries(group, source)
	local entries = {};
	local index;
	for index = 1, table.getn(source or {}), 1 do
		local state = source[index];
		local spellName = state.buffName or state.debuffName or state.spellName;
		if (spellName) then
			table.insert(entries, {
				key=group .. "|" .. tostring(state.key or (tostring(state.guid) .. "|" .. tostring(spellName))),
				group=group, spellName=spellName, targetName=state.unitName or state.guid or "成员",
				icon=state.icon, stacks=tonumber(state.stacks) or 0, remaining=state.remaining,
				duration=state.duration, endTime=state.endTime, guid=state.guid, unit=state.unit,
				timerSource=state.timerSource,
			});
		end
	end
	return DFT_SortEntries(entries);
end

local function DFT_GetEntries(group)
	if (group == "player_buff") then return DFT_GetPlayerBuffEntries(); end
	if (group == "player_debuff") then return DFT_GetPlayerDebuffEntries(); end
	if (group == "target_buff") then return DFT_GetTargetBuffEntries(); end
	if (group == "target_debuff") then return DFT_GetTargetDebuffEntries(); end
	if (group == "multi_buff") then
		local source = type(DebuffFilter_GetMultiTargetBuffTimerEntries) == "function" and DebuffFilter_GetMultiTargetBuffTimerEntries() or {};
		return DFT_CopyMultiEntries(group, source);
	end
	if (group == "multi_debuff") then
		local source = type(DebuffFilter_GetMultiTargetDebuffTimerEntries) == "function" and DebuffFilter_GetMultiTargetDebuffTimerEntries() or {};
		return DFT_CopyMultiEntries(group, source);
	end
	return {};
end

function DebuffFilter_TimerBars_GetEntries(group)
	return DFT_GetEntries(group);
end
local function DFT_EnsureAnchor(group)
	local info = DFTimer.groupInfo[group];
	if (not info) then return nil; end
	local frame = getglobal(info.frame);
	if (group == "test" and not frame) then
		frame = CreateFrame("Frame", "DebuffFilter_TimerTestAnchor", UIParent);
		frame:SetWidth(200);
		frame:SetHeight(1);
		frame:SetPoint("CENTER", UIParent, "CENTER", 300, 80);
		frame:SetFrameStrata("HIGH");
		frame:Show();
	end
	if (not frame) then
		-- 自身减益框由 DebuffFilterExtension 在 PLAYER_ENTERING_WORLD 创建。
		-- 此处不能反向调用其 UpdatePlayerDebuffs，否则在框尚未创建时会递归。
		if (group == "target_buff" and type(DebuffFilter_CreateCurrentTargetBuffFrame) == "function") then
			DebuffFilter_CreateCurrentTargetBuffFrame();
		elseif (group == "multi_buff" and type(DebuffFilter_CreateTargetBuffFrame) == "function") then
			DebuffFilter_CreateTargetBuffFrame();
		elseif (group == "multi_debuff" and type(DebuffFilter_CreateMultiTargetDebuffFrame) == "function") then
			DebuffFilter_CreateMultiTargetDebuffFrame();
		end
		frame = getglobal(info.frame);
	end
	if (frame) then
		frame:SetMovable(1);
		local backdrop = info.backdrop and getglobal(info.backdrop) or nil;
		if (backdrop and not backdrop.DFTimerDragHooked) then
			backdrop.DFTimerDragHooked = 1;
			backdrop:SetScript("OnMouseDown", function()
				if (arg1 == "LeftButton" and IsShiftKeyDown()) then
					this.DFTimerDragging = 1;
					this:GetParent():StartMoving();
				end
			end);
			backdrop:SetScript("OnMouseUp", function()
				if (arg1 == "LeftButton" and this.DFTimerDragging) then
					this:GetParent():StopMovingOrSizing();
					if (this:GetParent().SetUserPlaced) then this:GetParent():SetUserPlaced(true); end
					this.DFTimerDragging = nil;
				end
			end);
			backdrop:SetScript("OnHide", function() this:GetParent():StopMovingOrSizing(); end);
		end
	end
	return frame;
end

local function DFT_RemoveMonitoredEntry(entry)
	if (not entry or not entry.group or not entry.spellName) then return; end
	local info = DFTimer.groupInfo[entry.group];
	if (not info or not info.commandDelete or type(DebuffFilter_command) ~= "function") then return; end
	if (entry.group == "player_debuff") then
		local config = DFT_EnsureConfig();
		if (config and config["player_debuff_list"]) then
			config["player_debuff_list"][entry.spellName] = nil;
			if (DebuffFilter_Extension and DebuffFilter_Extension.playerDebuffStates) then DebuffFilter_Extension.playerDebuffStates = {}; end
			if (DebuffFilter_Extension and type(DebuffFilter_Extension.UpdatePlayerDebuffs) == "function") then DebuffFilter_Extension.UpdatePlayerDebuffs(true); end
		end
		return;
	end
	DebuffFilter_command(info.commandDelete .. " " .. tostring(entry.spellName));
end

local function DFT_ShowEntryTooltip(widget)
	local entry = widget and widget.entry or nil;
	if (not entry) then return; end
	local config = DFT_EnsureConfig();
	if (config and config["tooltips"] == "no") then return; end
	if (entry.tooltipType == "playerbuff" and entry.auraIndex) then
		GameTooltip:SetOwner(widget, "ANCHOR_RIGHT");
		GameTooltip:SetPlayerBuff(entry.auraIndex);
	elseif (entry.tooltipType == "unitbuff" and entry.auraIndex and entry.tooltipUnit and UnitExists(entry.tooltipUnit)) then
		GameTooltip:SetOwner(widget, "ANCHOR_RIGHT");
		GameTooltip:SetUnitBuff(entry.tooltipUnit, entry.auraIndex);
	elseif (entry.tooltipType == "unitdebuff" and entry.auraIndex and entry.tooltipUnit and UnitExists(entry.tooltipUnit)) then
		GameTooltip:SetOwner(widget, "ANCHOR_RIGHT");
		GameTooltip:SetUnitDebuff(entry.tooltipUnit, entry.auraIndex);
	else
		GameTooltip:SetOwner(widget, "ANCHOR_RIGHT");
		GameTooltip:AddLine(tostring(entry.spellName or "计时条"), 0.25, 0.80, 1.00);
		if (entry.targetName and entry.targetName ~= "") then GameTooltip:AddLine("目标：" .. tostring(entry.targetName), 0.90, 0.95, 1.00); end
		GameTooltip:AddLine("剩余：" .. DFT_FormatTime(entry.remaining), 1.00, 0.82, 0.10);
	end
	if (entry.timerSource == "custom") then GameTooltip:AddLine("计时来源：手工持续时间", 0.55, 0.85, 1.00); end
	GameTooltip:AddLine("Ctrl+左键：从监视名单删除", 0.72, 0.78, 0.86);
	GameTooltip:AddLine("Shift+左键：移动本组锚点", 0.72, 0.78, 0.86);
	GameTooltip:Show();
end



local function DFT_Widget_OnMouseDown()
    if (arg1 == "LeftButton" and IsShiftKeyDown()) then
        this.DFTimerDragging = 1;
        local anchor = this.DFTimerAnchor;
        if (anchor) then anchor:StartMoving(); end
    end
end

local function DFT_Widget_OnMouseUp()
    if (arg1 == "LeftButton" and this.DFTimerDragging) then
        local anchor = this.DFTimerAnchor;
        if (anchor) then anchor:StopMovingOrSizing(); if (anchor.SetUserPlaced) then anchor:SetUserPlaced(true); end end
        this.DFTimerDragging = nil;
        this.DFTimerSkipClickUntil = GetTime() + 0.20;
    end
end

local function DFT_Widget_OnClick()
    if (this.DFTimerSkipClickUntil and GetTime() < this.DFTimerSkipClickUntil) then return; end
    if (arg1 == "LeftButton" and IsControlKeyDown()) then DFT_RemoveMonitoredEntry(this.entry); end
end


local DFT_SetAnchorOnlyVisibility;
local DFCB_StopGroup;

local function DFT_GetColor(value, fallbackValue)
    if (type(value) == "table") then
        return { tonumber(value[1]) or 1, tonumber(value[2]) or 1, tonumber(value[3]) or 1, tonumber(value[4]) or 1 };
    end
    if (type(value) == "string" and DFTimer.colorPresets[value]) then return DFTimer.colorPresets[value]; end
    if (type(fallbackValue) == "table") then
        return { tonumber(fallbackValue[1]) or 1, tonumber(fallbackValue[2]) or 1, tonumber(fallbackValue[3]) or 1, tonumber(fallbackValue[4]) or 1 };
    end
    if (type(fallbackValue) == "string" and DFTimer.colorPresets[fallbackValue]) then return DFTimer.colorPresets[fallbackValue]; end
    return {1,1,1,1};
end

local function DFT_FormatBarText(entry, template)
    local text = tostring(template or "$s  $t");
    text = string.gsub(text, "%$s", tostring(entry.spellName or ""));
    text = string.gsub(text, "%$t", tostring(entry.targetName or ""));
    text = string.gsub(text, "%s+", " ");
    text = string.gsub(text, "^%s+", "");
    text = string.gsub(text, "%s+$", "");
    text = string.gsub(text, "[%-%|·]+%s*$", "");
    return text;
end

local function DFCB_GetEngine()
    if (DFTimer.candy) then return DFTimer.candy; end
    if (DFTimer.candyError) then return nil; end

    -- AceLibrary in Ace2 is commonly a callable table, not a plain Lua function.
    -- AceLibrary is callable in this Ace2 environment. Requiring a plain function incorrectly
    -- reports a working Ace2 installation as missing, and pcall(AceLibrary, ...) also
    -- rejects callable tables.  Always invoke it through a closure instead.
    local ace = AceLibrary;
    if (not ace) then DFTimer.candyError = "AceLibrary 未加载"; return nil; end

    local okAddon, addonLib = pcall(function() return ace("AceAddon-2.0"); end);
    if (not okAddon or not addonLib or type(addonLib.new) ~= "function") then
        DFTimer.candyError = "AceAddon-2.0 不可用：" .. tostring(addonLib or "未知错误");
        return nil;
    end

    -- Embed the private CandyBar copy into one AceAddon object.
    local okCandy, candy = pcall(function() return addonLib:new("AceEvent-2.0", "DebuffFilterCandyBar-2.2"); end);
    if (not okCandy or not candy) then
        DFTimer.candyError = "DebuffFilterCandyBar-2.2 初始化失败：" .. tostring(candy or "未知错误");
        return nil;
    end
    DFTimer.candy = candy;

    local okPaint, paint = pcall(function() return ace("PaintChips-2.0"); end);
    if (okPaint and paint) then DFTimer.paint = paint; end
    return DFTimer.candy;
end

function DebuffFilter_TimerBars_IsCandyAvailable()
    return DFCB_GetEngine() and true or false, DFTimer.candyError;
end

local function DFCB_ClampColorPart(value, fallback)
    local number = tonumber(value);
    if (not number) then number = fallback or 0; end
    if (number < 0) then number = 0; elseif (number > 1) then number = 1; end
    return number;
end

local function DFCB_GetRGB(value, fallbackName)
    local color = DFT_GetColor(value, fallbackName);
    return {
        DFCB_ClampColorPart(color[1], 1),
        DFCB_ClampColorPart(color[2], 1),
        DFCB_ClampColorPart(color[3], 1),
        DFCB_ClampColorPart(color[4], 1),
    };
end

local function DFCB_ColorName(slot, value, fallbackName)
    local color = DFCB_GetRGB(value, fallbackName);
    -- PaintChips-2.0 never overwrites an existing registered name.  Reusing a fixed
    -- name therefore freezes the first selected color for the entire UI session.
    -- Use the RGB bytes in the name so every distinct picker color has its own entry.
    local r = math.floor(color[1] * 255 + 0.5);
    local g = math.floor(color[2] * 255 + 0.5);
    local b = math.floor(color[3] * 255 + 0.5);
    local name = "DebuffFilter_" .. tostring(slot) .. "_" .. tostring(r) .. "_" .. tostring(g) .. "_" .. tostring(b);
    if (DFTimer.paint and type(DFTimer.paint.RegisterColor) == "function") then
        DFTimer.paint:RegisterColor(name, color[1], color[2], color[3]);
        return name;
    end
    if (slot == "text") then return "white"; end
    if (slot == "background") then return "black"; end
    return "gray";
end

local function DFCB_HashText(text)
    text = tostring(text or "");
    local hash = 0;
    local index;
    for index = 1, string.len(text), 1 do
        hash = math.mod(hash * 131 + string.byte(text, index), 2147483647);
    end
    return hash;
end

local function DFCB_RandomBarColorName(entry)
    local seedText = DFT_NormalizeName(entry and entry.spellName) or (entry and entry.spellName) or (entry and entry.key) or "bar";
    local seed = DFCB_HashText(seedText);
    local r = 0.35 + math.mod(seed, 100) / 100 * 0.55;
    local g = 0.35 + math.mod(math.floor(seed / 7), 100) / 100 * 0.55;
    local b = 0.35 + math.mod(math.floor(seed / 13), 100) / 100 * 0.55;
    local name = "DebuffFilter_randombar_" .. tostring(math.floor(r * 255 + 0.5)) .. "_" .. tostring(math.floor(g * 255 + 0.5)) .. "_" .. tostring(math.floor(b * 255 + 0.5));
    if (DFTimer.paint and type(DFTimer.paint.RegisterColor) == "function") then
        DFTimer.paint:RegisterColor(name, r, g, b);
        return name;
    end
    return DFCB_ColorName("bar", { r, g, b, 1 }, DEFAULT_STYLE.bar_color);
end

local function DFCB_SelectBarColor(entry, style)
    if (style and style.random_bar_color == "yes") then return DFCB_RandomBarColorName(entry); end
    return DFCB_ColorName("bar", style and style.bar_color or DEFAULT_STYLE.bar_color, DEFAULT_STYLE.bar_color);
end

local function DFCB_GroupName(group)
    return "DebuffFilter_TimerGroup_" .. tostring(group);
end

local function DFCB_BarId(group, key)
    -- Keep localized keys intact; replacing UTF-8 spell names with underscores can cause collisions.
    return "DFCB:" .. tostring(group) .. ":" .. tostring(key or "unknown");
end

local function DFCB_TimeFormat(seconds, unknown, showTime)
    if (not showTime) then return ""; end
    if (unknown) then return "--"; end
    return DFT_FormatTime(seconds);
end

local function DFCB_EnsureTables(group)
    if (not DFTimer.activeBars[group]) then DFTimer.activeBars[group] = {}; end
    if (not DFTimer.expired[group]) then DFTimer.expired[group] = {}; end
    if (not DFTimer.entryByKey[group]) then DFTimer.entryByKey[group] = {}; end
end

local function DFCB_EnsureGroup(group, style)
    local candy = DFCB_GetEngine();
    local anchor = DFT_EnsureAnchor(group);
    if (not candy or not anchor) then return nil; end
    local groupName = DFCB_GroupName(group);
    local registered = false;
    if (type(candy.IsCandyBarGroupRegistered) == "function") then registered = candy:IsCandyBarGroupRegistered(groupName); end
    if (not registered) then candy:RegisterCandyBarGroup(groupName, tonumber(style.spacing) or 0, true); end
    if (group == "test") then
        candy:SetCandyBarGroupPoint(groupName, "TOP", anchor, "BOTTOM", 0, 0);
    else
        candy:SetCandyBarGroupPoint(groupName, "TOPLEFT", anchor, "BOTTOMLEFT", 0, 0);
    end
    candy:SetCandyBarGroupGrowth(groupName, style.grow_up == "yes");
    -- This CandyBar-2.2 build exposes UpdateCandyBarSpacing.
    candy:UpdateCandyBarSpacing(groupName, tonumber(style.spacing) or 0);
    if (type(candy.UpdateCandyBarGroup) == "function") then candy:UpdateCandyBarGroup(groupName); end
    return anchor;
end

local function DFCB_ColorSignature(value)
    if (type(value) == "table") then
        return tostring(value[1] or "") .. "," .. tostring(value[2] or "") .. "," .. tostring(value[3] or "") .. "," .. tostring(value[4] or "");
    end
    return tostring(value or "");
end

local function DFCB_StyleSignature(entry, style, unknown)
    return table.concat({
        tostring(style.texture or ""), DFCB_ColorSignature(style.bar_color), DFCB_ColorSignature(style.background_color),
        DFCB_ColorSignature(style.text_color), tostring(style.background_alpha or ""), tostring(style.width or ""),
        tostring(style.height or ""), tostring(style.scale or ""), tostring(style.text_size or ""),
        tostring(style.reverse or ""), tostring(style.show_text or ""), tostring(style.show_icon or ""),
        tostring(style.show_time or ""), tostring(style.random_bar_color or ""), tostring(unknown and 1 or 0),
        tostring(entry.icon or ""), DFT_FormatBarText(entry, style.text_template),
    }, "|");
end

local function DFCB_ApplyBackground(id, style)
    local candy = DFCB_GetEngine();
    if (not candy or not id or not style) then return; end
    local bgRGB = DFCB_GetRGB(style.background_color, DEFAULT_STYLE.background_color);
    local alpha = tonumber(style.background_alpha) or bgRGB[4] or 1;
    if (alpha < 0) then alpha = 0; elseif (alpha > 1) then alpha = 1; end
    -- This writes directly to CandyBar's lower, fixed-full statusbarbg.
    candy:SetCandyBarBackgroundColorRGB(id, bgRGB[1], bgRGB[2], bgRGB[3], alpha);
end

local function DFCB_ApplyStyle(id, entry, style, unknown)
    local candy = DFCB_GetEngine(); if (not candy) then return; end
    local barColor = DFCB_SelectBarColor(entry, style);
    local textColor = DFCB_ColorName("text", style.text_color, DEFAULT_STYLE.text_color);
    candy:SetCandyBarTexture(id, DFTimer.texturePaths[style.texture] or DFTimer.texturePaths.Default);
    candy:SetCandyBarWidth(id, tonumber(style.width) or 200);
    candy:SetCandyBarHeight(id, tonumber(style.height) or 20);
    candy:SetCandyBarScale(id, tonumber(style.scale) or 1);
    candy:SetCandyBarFontSize(id, tonumber(style.text_size) or 10);
    candy:SetCandyBarColor(id, barColor);
    DFCB_ApplyBackground(id, style);
    candy:SetCandyBarTextColor(id, textColor);
    if (type(candy.SetCandyBarTimerTextColor) == "function") then candy:SetCandyBarTimerTextColor(id, textColor); end
    candy:SetCandyBarReversed(id, style.reverse == "yes");
    candy:SetCandyBarText(id, style.show_text == "no" and "" or DFT_FormatBarText(entry, style.text_template));
    if (style.show_icon == "no") then
        -- This CandyBar build rejects nil in SetCandyBarIcon.
        candy:SetCandyBarIcon(id, "Interface\\AddOns\\DebuffFilter\\Textures\\Transparent");
    else
        -- This CandyBar-2.2 build fixes icons on the left.
        candy:SetCandyBarIcon(id, entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark");
    end
    candy:SetCandyBarTimeFormat(id, DFCB_TimeFormat, unknown and true or false, style.show_time ~= "no");
end

local function DFCB_BarDragStart()
    if (arg1 ~= "LeftButton" or not IsControlKeyDown()) then return; end
    local anchor = this and this.DFTimerAnchor or nil;
    if (not anchor) then return; end
    this.DFTimerDragging = 1;
    anchor:StartMoving();
end

local function DFCB_BarDragStop()
    if (arg1 ~= "LeftButton" or not this or not this.DFTimerDragging) then return; end
    local anchor = this.DFTimerAnchor;
    if (anchor) then
        anchor:StopMovingOrSizing();
        if (anchor.SetUserPlaced) then anchor:SetUserPlaced(true); end
    end
    this.DFTimerDragging = nil;
end

local function DFCB_EnableBarDragging(id, group)
    local candy = DFCB_GetEngine();
    local anchor = DFT_EnsureAnchor(group);
    if (not candy or not anchor or not candy.var or not candy.var.handlers) then return; end
    local handler = candy.var.handlers[id];
    local frame = handler and handler.frame or nil;
    if (not frame) then return; end

    -- CandyBar deliberately disables mouse input whenever a pooled bar frame is
    -- acquired. Re-enable it here after StartCandyBar, and point drag events at
    -- the existing DebuffFilter anchor for this aura group.
    frame.DFTimerAnchor = anchor;
    frame:EnableMouse(true);
    frame:SetScript("OnMouseDown", DFCB_BarDragStart);
    frame:SetScript("OnMouseUp", DFCB_BarDragStop);

    if (frame.icon) then
        frame.icon.DFTimerAnchor = anchor;
        frame.icon:EnableMouse(true);
        frame.icon:SetScript("OnMouseDown", DFCB_BarDragStart);
        frame.icon:SetScript("OnMouseUp", DFCB_BarDragStop);
    end
end

local function DFCB_Unregister(id)
    local candy = DFCB_GetEngine(); if (not candy or not id) then return; end
    if (type(candy.IsCandyBarRegistered) ~= "function" or candy:IsCandyBarRegistered(id)) then
        candy:SetCandyBarFade(id, 0, false);
        candy:StopCandyBar(id);
        if (type(candy.UnregisterCandyBar) == "function") then candy:UnregisterCandyBar(id); end
    end
end

local function DFCB_StopOne(group, key, useFade)
    DFCB_EnsureTables(group);
    local record = DFTimer.activeBars[group][key]; if (not record) then return; end
    local candy = DFCB_GetEngine();
    if (candy) then
        if (useFade) then
            local style = DFT_GetStyleForGroup(group) or DEFAULT_STYLE;
            local fade = tonumber(style.ghost) or 0; if (fade <= 0) then fade = 0.5; end
            candy:SetCandyBarFade(record.id, fade, true);
            candy:StopCandyBar(record.id);
        else
            DFCB_Unregister(record.id);
        end
    end
    DFTimer.activeBars[group][key] = nil;
    DFTimer.entryByKey[group][key] = nil;
end

DFCB_StopGroup = function(group, useFade)
    DFCB_EnsureTables(group);
    local keys = {}; local key;
    for key in DFTimer.activeBars[group] do table.insert(keys, key); end
    local index; for index = 1, table.getn(keys), 1 do DFCB_StopOne(group, keys[index], useFade); end
    DFTimer.orderSignatures[group] = nil;
end

local function DFCB_Completion(group, key)
    DFCB_EnsureTables(group);
    DFTimer.activeBars[group][key] = nil;
    DFTimer.entryByKey[group][key] = nil;
    if (string.find(tostring(key), "^__test") == nil) then DFTimer.expired[group][key] = 1; end
end

local function DFCB_StartOne(group, entry, style)
    local candy = DFCB_GetEngine(); if (not candy) then return; end
    DFCB_EnsureTables(group);
    local key = tostring(entry.key);
    local id = DFCB_BarId(group, key);
    local remaining = tonumber(entry.remaining);
    local duration = tonumber(entry.duration);
    local unknown = not remaining;
    if (duration and remaining and duration < remaining) then duration = remaining; end
    if (not duration or duration <= 0) then duration = remaining or 86400; end
    if (duration <= 0) then duration = 1; end
    local initialLeft = remaining or duration;
    local barColor = DFCB_SelectBarColor(entry, style);
    candy:RegisterCandyBar(id, duration, DFT_FormatBarText(entry, style.text_template), entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark", barColor);
    candy:RegisterCandyBarWithGroup(id, DFCB_GroupName(group));
    DFCB_ApplyStyle(id, entry, style, unknown);
    candy:SetCandyBarFade(id, tonumber(style.ghost) or 0, true);
    candy:SetCandyBarCompletion(id, DFCB_Completion, group, key);
    candy:StartCandyBar(id, true);
    candy:SetCandyBarTimeLeft(id, initialLeft);
    DFCB_EnableBarDragging(id, group);
    -- StartCandyBar can reacquire a pooled frame; force the selected RGB onto
    -- the newly acquired lower StatusBar once more.
    DFCB_ApplyBackground(id, style);
    -- CandyBar can reacquire its pooled frame on Start; restore only the supported icon path.
    if (style.show_icon == "no") then
        candy:SetCandyBarIcon(id, "Interface\\AddOns\\DebuffFilter\\Textures\\Transparent");
    else
        candy:SetCandyBarIcon(id, entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark");
    end
    DFTimer.activeBars[group][key] = {
        id=id, duration=duration, endTime=entry.endTime, unknown=unknown,
        styleSignature=DFCB_StyleSignature(entry, style, unknown),
    };
    DFTimer.entryByKey[group][key] = entry;
end

local function DFCB_UpdateOne(group, entry, style)
    DFCB_EnsureTables(group);
    local key = tostring(entry.key);
    local record = DFTimer.activeBars[group][key];
    if (not record) then DFCB_StartOne(group, entry, style); return; end
    local candy = DFCB_GetEngine(); if (not candy) then return; end
    local remaining = tonumber(entry.remaining);
    local duration = tonumber(entry.duration);
    if (duration and remaining and duration < remaining) then duration = remaining; end
    if (not duration or duration <= 0) then duration = remaining or 86400; end
    local unknown = not remaining;
    DFTimer.entryByKey[group][key] = entry;
    local styleSignature = DFCB_StyleSignature(entry, style, unknown);
    if (record.styleSignature ~= styleSignature) then
        DFCB_ApplyStyle(record.id, entry, style, unknown);
        record.styleSignature = styleSignature;
    end
    -- Keep background live even when the color picker changes while the bar is running.
    DFCB_ApplyBackground(record.id, style);
    local changed = false;
    if (math.abs((tonumber(record.duration) or 0) - duration) > 0.5) then changed = true; end
    if (entry.endTime and record.endTime and math.abs(entry.endTime - record.endTime) > 0.75) then changed = true; end
    if ((entry.endTime and not record.endTime) or (record.endTime and not entry.endTime)) then changed = true; end
    if (changed) then
        candy:SetCandyBarTime(record.id, duration);
        candy:SetCandyBarTimeLeft(record.id, remaining or duration);
        record.duration = duration; record.endTime = entry.endTime; record.unknown = unknown;
        DFTimer.expired[group][key] = nil;
    end
end

local function DFCB_OrderSignature(entries)
    local text = ""; local index;
    for index = 1, table.getn(entries), 1 do text = text .. "|" .. tostring(entries[index].key); end
    return text;
end

local function DFCB_GetTestEntries(group)
    if (not DFTimer.testEntries) then return {}; end
    return DFTimer.testEntries;
end

local function DFCB_RenderGroup(group, entries)
    local config = DFT_EnsureConfig(); if (not config) then return; end
    local style = DFT_GetStyleForGroup(group);
    local anchor = DFCB_EnsureGroup(group, style);
    if (not anchor) then
        if (not DFTimer.warnedCandy and DFTimer.candyError and type(DebuffFilter_Print) == "function") then
            DFTimer.warnedCandy = 1; DebuffFilter_Print("原版计时条无法启动：" .. tostring(DFTimer.candyError));
        end
        DFT_SetAnchorOnlyVisibility(group, false); return;
    end
    DFCB_EnsureTables(group);
    local present = {}; local renderable = {}; local index;
    for index = 1, table.getn(entries), 1 do
        local entry = entries[index]; local key = tostring(entry.key); present[key] = 1;
        if (not DFTimer.expired[group][key]) then table.insert(renderable, entry); end
    end
    local key;
    for key in DFTimer.expired[group] do if (not present[key]) then DFTimer.expired[group][key] = nil; end end
    local signature = DFCB_OrderSignature(renderable);
    if (DFTimer.orderSignatures[group] and DFTimer.orderSignatures[group] ~= signature) then DFCB_StopGroup(group, false); DFCB_EnsureTables(group); end
    DFTimer.orderSignatures[group] = signature;
    local activeKeys = {};
    for index = 1, table.getn(renderable), 1 do
        local entry = renderable[index]; activeKeys[tostring(entry.key)] = 1; DFCB_UpdateOne(group, entry, style);
    end
    local stale = {};
    for key in DFTimer.activeBars[group] do if (not activeKeys[key]) then table.insert(stale, key); end end
    local death = (group == "target_buff" or group == "target_debuff") and UnitExists("target") and UnitIsDead("target");
    local fade = (death and style.fade_on_death == "yes") or ((not death) and style.fade_on_remove == "yes");
    for index = 1, table.getn(stale), 1 do DFCB_StopOne(group, stale[index], fade); end
    local info = DFTimer.groupInfo[group]; local backdrop = info and info.backdrop and getglobal(info.backdrop) or nil;
    local moveVisible = DebuffFilter and DebuffFilter.backdrop == 1;
    if (backdrop) then if (moveVisible) then backdrop:Show(); else backdrop:Hide(); end end
    if (table.getn(renderable) > 0 or moveVisible) then anchor:Show(); else anchor:Hide(); end
end

-- WoW 1.12-compatible icon shine: ONLY four platinum/gold moving highlights.
-- No static border, outer glow, or breathing effect.
-- Performance target: ONE global throttled driver, no per-icon OnUpdate.
-- Hidden icons and non-icon display modes do not animate.
local DFT_ICON_PREFIXES = {
    player_buff={ prefix="DebuffFilter_BuffButton", first=0, last=31 },
    player_debuff={ prefix="DebuffFilter_PlayerDebuffButton", first=0, last=15 },
    target_buff={ prefix="DebuffFilter_CurrentTargetBuffButton", first=0, last=31 },
    target_debuff={ prefix="DebuffFilter_DebuffButton", first=0, last=31 },
};

local function DFT_IconShineEnabled(group)
    return DebuffFilter_GetAuraDisplayMode(group) == "icon" and DebuffFilter_GetAuraIconShine(group);
end

local function DFT_AnyIconShineEnabled()
    local index;
    for index = 1, table.getn(DFTimer.groupOrder), 1 do
        if (DFT_IconShineEnabled(DFTimer.groupOrder[index])) then return true; end
    end
    return false;
end

local function DFT_IconShineMoveSpark(texture, parent, phase, width, height)
    phase = phase - math.floor(phase);
    local segment = phase * 4;
    local x, y;
    if (segment < 1) then
        x = segment * width; y = 0;
    elseif (segment < 2) then
        x = width; y = (segment - 1) * height;
    elseif (segment < 3) then
        x = (3 - segment) * width; y = height;
    else
        x = 0; y = (4 - segment) * height;
    end
    texture:ClearAllPoints();
    texture:SetPoint("CENTER", parent, "TOPLEFT", x, -y);
end

local function DFT_IconShineRegister(shine, group)
    table.insert(DFTimer.iconShineList, shine);
    if (not DFTimer.iconShinesByGroup[group]) then DFTimer.iconShinesByGroup[group] = {}; end
    table.insert(DFTimer.iconShinesByGroup[group], shine);
end

local function DFT_IconShineAttach(button, group)
    if (not button or button.DFIconShine) then return; end
    if (not DFT_IconShineEnabled(group) or not button:IsVisible()) then return; end

    local shine = CreateFrame("Frame", nil, button);
    shine:SetPoint("TOPLEFT", button, "TOPLEFT", -4, 4);
    shine:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, -4);
    if (shine.SetFrameLevel and button.GetFrameLevel) then shine:SetFrameLevel(button:GetFrameLevel() + 6); end
    shine.group = group;
    shine.phaseOffset = math.mod(table.getn(DFTimer.iconShineList) * 0.137, 1);

    -- Four small star highlights.  star4 exists in the 1.12 client and gives a much
    -- more natural magical glint than solid-color squares.
    shine.sparks = {};
    local i;
    for i = 1, 4, 1 do
        local spark = shine:CreateTexture(nil, "OVERLAY");
        spark:SetTexture("Interface\\Cooldown\\star4");
        spark:SetWidth(i == 1 and 10 or 7);
        spark:SetHeight(i == 1 and 10 or 7);
        if (i == 1) then
            spark:SetVertexColor(1.00, 0.98, 0.72, 1.00);
        elseif (i == 2) then
            spark:SetVertexColor(1.00, 0.82, 0.22, 1.00);
        else
            spark:SetVertexColor(1.00, 0.62, 0.08, 1.00);
        end
        if (spark.SetBlendMode) then spark:SetBlendMode("ADD"); end
        shine.sparks[i] = spark;
    end

    button.DFIconShine = shine;
    DFT_IconShineRegister(shine, group);
    shine:Show();
end

local function DFT_IconShineRefreshButton(button, group)
    if (not button) then return; end
    local enabled = DFT_IconShineEnabled(group);
    if (enabled and button:IsVisible()) then
        if (not button.DFIconShine) then DFT_IconShineAttach(button, group); end
        if (button.DFIconShine) then button.DFIconShine:Show(); end
    elseif (button.DFIconShine) then
        button.DFIconShine:Hide();
    end
end

local function DFT_IconShineHideGroup(group)
    local list = DFTimer.iconShinesByGroup[group];
    if (not list) then return; end
    local index;
    for index = 1, table.getn(list), 1 do
        if (list[index]) then list[index]:Hide(); end
    end
end

function DebuffFilter_TimerBars_RefreshIconShine(group)
    local g, info, index;
    if (group) then
        if (not DFT_IconShineEnabled(group)) then
            DFT_IconShineHideGroup(group);
            return;
        end
        info = DFT_ICON_PREFIXES[group];
        if (info) then
            for index = info.first, info.last, 1 do
                local button = getglobal(info.prefix .. tostring(index));
                if (button and (button:IsVisible() or button.DFIconShine)) then DFT_IconShineRefreshButton(button, group); end
            end
        else
            local pool = DFTimer.multiIconPools[group];
            if (pool) then
                for index = 1, table.getn(pool), 1 do
                    local button = pool[index];
                    if (button and (button:IsVisible() or button.DFIconShine)) then DFT_IconShineRefreshButton(button, group); end
                end
            end
        end
        return;
    end

    for index = 1, table.getn(DFTimer.groupOrder), 1 do
        g = DFTimer.groupOrder[index];
        DebuffFilter_TimerBars_RefreshIconShine(g);
    end
end

local function DFT_IconShineTick(delta)
    DFTimer.shineClock = (DFTimer.shineClock or 0) + (delta or 0);
    local clock = DFTimer.shineClock;
    local basePhase = clock * 0.31;
    local active = 0;
    local index;
    for index = 1, table.getn(DFTimer.iconShineList), 1 do
        local shine = DFTimer.iconShineList[index];
        if (shine and shine:IsVisible()) then
            local parent = shine:GetParent();
            if (parent and parent:IsVisible() and DFT_IconShineEnabled(shine.group)) then
                active = active + 1;
                local w = shine:GetWidth(); local h = shine:GetHeight();
                if (not w or w <= 0) then w = 38; end
                if (not h or h <= 0) then h = 38; end
                local phase = basePhase + (shine.phaseOffset or 0);
                DFT_IconShineMoveSpark(shine.sparks[1], shine, phase, w, h);
                DFT_IconShineMoveSpark(shine.sparks[2], shine, phase + 0.25, w, h);
                DFT_IconShineMoveSpark(shine.sparks[3], shine, phase + 0.50, w, h);
                DFT_IconShineMoveSpark(shine.sparks[4], shine, phase + 0.75, w, h);
                shine.sparks[1]:SetAlpha(1.00);
                shine.sparks[2]:SetAlpha(1.00);
                shine.sparks[3]:SetAlpha(0.93);
                shine.sparks[4]:SetAlpha(0.72);
            else
                shine:Hide();
            end
        end
    end
    DFTimer.shineActiveCount = active;
end

local function DFT_CreateMultiIcon(group, index, anchor)
	local name = "DebuffFilter_MultiAuraIcon_" .. tostring(group) .. "_" .. tostring(index);
	local button = CreateFrame("Button", name, anchor);
	button:SetWidth(30); button:SetHeight(30);
	button:RegisterForClicks("LeftButtonUp");
	button.DFTimerAnchor = anchor;
	button:SetScript("OnMouseDown", DFT_Widget_OnMouseDown);
	button:SetScript("OnMouseUp", DFT_Widget_OnMouseUp);
	button:SetScript("OnClick", DFT_Widget_OnClick);
	button:SetScript("OnEnter", function() DFT_ShowEntryTooltip(this); end);
	button:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	button.icon = button:CreateTexture(name .. "Icon", "ARTWORK");
	button.icon:SetAllPoints(button); button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
	button.border = button:CreateTexture(name .. "Border", "OVERLAY");
	button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2");
	button.border:SetPoint("CENTER", button, "CENTER", 0, 0); button.border:SetWidth(54); button.border:SetHeight(54);
	button.stack = button:CreateFontString(name .. "Stack", "OVERLAY", "NumberFontNormalSmall");
	button.stack:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1);
	button.time = button:CreateFontString(name .. "Time", "OVERLAY", "GameFontNormalSmall");
	button.time:SetPoint("TOP", button, "BOTTOM", 0, 1); DebuffFilter_SetUIFont(button.time, 10, "OUTLINE");
	button:Hide();
	return button;
end

local function DFT_GetMultiIcon(group, index, anchor)
	if (not DFTimer.multiIconPools[group]) then DFTimer.multiIconPools[group] = {}; end
	local pool = DFTimer.multiIconPools[group];
	if (not pool[index]) then pool[index] = DFT_CreateMultiIcon(group, index, anchor); end
	return pool[index];
end

local function DFT_HideMultiIcons(group, fromIndex)
	local pool = DFTimer.multiIconPools[group];
	if (not pool) then return; end
	local index;
	for index = fromIndex or 1, table.getn(pool), 1 do if (pool[index]) then pool[index].entry=nil; pool[index]:Hide(); end end
end

local function DFT_RenderMultiIcons(group, entries)
	local anchor = DFT_EnsureAnchor(group);
	if (not anchor) then return; end
	local config = DFT_EnsureConfig();
	local scale = config and tonumber(config["scale"]) or 1;
	if (not scale) then scale = 1; end
	local size = math.floor(30 * scale + 0.5);
	local limit = table.getn(entries);
	if (limit > DFTimer.maxMultiIcons) then limit = DFTimer.maxMultiIcons; end
	local previous = nil;
	local index;
	for index = 1, limit, 1 do
		local button = DFT_GetMultiIcon(group, index, anchor);
		button:ClearAllPoints();
		button:SetWidth(size); button:SetHeight(size);
		if (not previous) then button:SetPoint("LEFT", anchor, "LEFT", 0, 0); else button:SetPoint("LEFT", previous, "RIGHT", 4, 0); end
		button.entry = entries[index];
		button.icon:SetTexture(entries[index].icon or "Interface\\Icons\\INV_Misc_QuestionMark");
		if (tonumber(entries[index].stacks) and tonumber(entries[index].stacks) > 1) then button.stack:SetText(tostring(entries[index].stacks)); else button.stack:SetText(""); end
		button.time:SetText(DFT_FormatTime(entries[index].remaining));
		button:Show();
		previous = button;
	end
	DFT_HideMultiIcons(group, limit + 1);
	local info = DFTimer.groupInfo[group];
	local backdrop = info and info.backdrop and getglobal(info.backdrop) or nil;
	local moveVisible = DebuffFilter and DebuffFilter.backdrop == 1;
	if (backdrop) then if (moveVisible) then backdrop:Show(); else backdrop:Hide(); end end
	if (limit > 0 or moveVisible) then anchor:Show(); else anchor:Hide(); end
end

local function DFT_HideOriginalIcons(group)
	local prefix = nil;
	local maximum = 0;
	local info = DFTimer.groupInfo[group];
	if (group == "player_buff") then prefix="DebuffFilter_BuffButton"; maximum=31;
	elseif (group == "player_debuff") then prefix="DebuffFilter_PlayerDebuffButton"; maximum=15;
	elseif (group == "target_buff") then prefix="DebuffFilter_CurrentTargetBuffButton"; maximum=31;
	elseif (group == "target_debuff") then prefix="DebuffFilter_DebuffButton"; maximum=31; end
	if (prefix) then
		local index;
		for index = 0, maximum, 1 do local button = getglobal(prefix .. tostring(index)); if (button) then button:Hide(); end end
	end
	if (info and info.count) then local count = getglobal(info.count); if (count) then count:Hide(); end end
end

DFT_SetAnchorOnlyVisibility = function(group, visible)
	local info = DFTimer.groupInfo[group];
	local anchor = DFT_EnsureAnchor(group);
	if (not info or not anchor) then return; end
	local backdrop = info.backdrop and getglobal(info.backdrop) or nil;
	local moveVisible = DebuffFilter and DebuffFilter.backdrop == 1;
	if (backdrop) then if (moveVisible) then backdrop:Show(); else backdrop:Hide(); end end
	if (visible or moveVisible) then anchor:Show(); else anchor:Hide(); end
end

function DFTimer.UpdateGroup(group)
    local mode = DebuffFilter_GetAuraDisplayMode(group);
    local testActive = DFTimer.testGroup == group and DFTimer.testUntil and GetTime() < DFTimer.testUntil;
    if (testActive) then mode = "bar"; end

    -- 性能关键：以前无论图标/计时条/关闭，都先扫描一遍六组光环。
    -- 现在只有真正需要数据的“计时条”和两组多人图标才取 entries。
    local entries = nil;
    if (testActive) then
        entries = DFCB_GetTestEntries(group);
    elseif (mode == "bar" or (mode == "icon" and (group == "multi_buff" or group == "multi_debuff"))) then
        entries = DFT_GetEntries(group);
    end

    if (mode == "bar") then
        DFT_HideOriginalIcons(group); DFT_HideMultiIcons(group, 1); DFCB_RenderGroup(group, entries or {});
    elseif (mode == "icon") then
        DFCB_StopGroup(group, false);
        if (group == "multi_buff" or group == "multi_debuff") then DFT_RenderMultiIcons(group, entries or {}); end
    else
        DFT_HideOriginalIcons(group); DFCB_StopGroup(group, false); DFT_HideMultiIcons(group, 1); DFT_SetAnchorOnlyVisibility(group, false);
    end
    -- 未启用流光时不再每0.2秒重复遍历已创建的流光框。
    if (DFT_IconShineEnabled(group)) then DebuffFilter_TimerBars_RefreshIconShine(group); end
end

function DFTimer.RefreshAll(refreshIconSources)
    local index; for index = 1, table.getn(DFTimer.groupOrder), 1 do DFTimer.UpdateGroup(DFTimer.groupOrder[index]); end
    if (refreshIconSources) then
        if (DebuffFilter_GetAuraDisplayMode("player_buff") == "icon" and type(DebuffFilter_BuffFrame_Update) == "function") then DebuffFilter_BuffFrame_Update(); end
        if (DebuffFilter_GetAuraDisplayMode("player_debuff") == "icon" and DebuffFilter_Extension and type(DebuffFilter_Extension.UpdatePlayerDebuffs) == "function") then DebuffFilter_Extension.UpdatePlayerDebuffs(true); end
        if (DebuffFilter_GetAuraDisplayMode("target_buff") == "icon" and type(DebuffFilter_CurrentTargetBuffFrame_Update) == "function") then DebuffFilter_CurrentTargetBuffFrame_Update(); end
        if (DebuffFilter_GetAuraDisplayMode("target_debuff") == "icon" and type(DebuffFilter_DebuffFrame_Update) == "function") then DebuffFilter_DebuffFrame_Update(); end
    end
end

local function DFT_NeedsPeriodicRefresh()
    if (DFTimer.testUntil) then return true; end
    local index;
    for index = 1, table.getn(DFTimer.groupOrder), 1 do
        local group = DFTimer.groupOrder[index];
        local mode = DebuffFilter_GetAuraDisplayMode(group);
        if (mode == "bar") then return true; end
        if (mode == "icon" and (group == "multi_buff" or group == "multi_debuff")) then return true; end
        if (DFT_IconShineEnabled(group)) then return true; end
    end
    return false;
end

function DebuffFilter_TimerBars_Refresh() DFTimer.RefreshAll(true); end

function DebuffFilter_TimerBars_RunTest()
    -- Use a dedicated on-screen test group, independent of the six aura modes and anchors.
    if (not DFTimer.candy) then DFTimer.candyError = nil; end
    local candy = DFCB_GetEngine();
    if (not candy) then
        return false, "测试计时条未启动：" .. tostring(DFTimer.candyError or "DebuffFilterCandyBar-2.2 不可用");
    end
    local config = DFT_EnsureConfig();
    if (not config or not config["timer_bar_settings"]) then
        return false, "测试计时条未启动：设置尚未初始化。";
    end
    local selected = "test";
    DFCB_StopGroup(selected, false);
    DFCB_EnsureTables(selected);
    DFTimer.expired[selected] = {};
    DFTimer.orderSignatures[selected] = nil;
    DFTimer.testGroup = selected;
    DFTimer.testUntil = GetTime() + 12;
    DFTimer.testEntries = {};
    local index;
    for index = 1, 5, 1 do
        local duration = 2 + index * 1.7;
        table.insert(DFTimer.testEntries, {
            key="__test" .. tostring(index), group=selected, spellName="测试" .. tostring(index),
            targetName="测试", icon="Interface\\Icons\\Spell_Shadow_ManaBurn", stacks=0,
            remaining=duration, duration=duration, endTime=GetTime() + duration,
        });
    end
    local okRender, renderError = pcall(function() DFCB_RenderGroup(selected, DFTimer.testEntries); end);
    if (not okRender) then
        DFCB_StopGroup(selected, false);
        DFTimer.testUntil = nil; DFTimer.testGroup = nil; DFTimer.testEntries = nil;
        DFTimer.candyError = "CandyBar 运行失败：" .. tostring(renderError);
        return false, "测试计时条未启动：" .. tostring(DFTimer.candyError);
    end
    local shown = 0; local key;
    for key in DFTimer.activeBars[selected] do shown = shown + 1; end
    if (shown <= 0) then return false, "测试计时条未启动：CandyBar 没有创建任何条。"; end
    return true, "已显示 5 根 DebuffFilter 独立 CandyBar 测试条。";
end

-- Wrap the six existing render-update functions.  Scanners and timer state continue running;
-- only the visual renderer is switched according to icon / bar / off.
local DFT_OldBuffUpdate = DebuffFilter_BuffFrame_Update;
if (type(DFT_OldBuffUpdate) == "function") then
	function DebuffFilter_BuffFrame_Update()
		DFT_OldBuffUpdate();
		if (DebuffFilter_GetAuraDisplayMode("player_buff") ~= "icon") then DFT_HideOriginalIcons("player_buff"); DFTimer.UpdateGroup("player_buff"); end
		DebuffFilter_TimerBars_RefreshIconShine("player_buff");
	end
end

local DFT_OldTargetDebuffUpdate = DebuffFilter_DebuffFrame_Update;
if (type(DFT_OldTargetDebuffUpdate) == "function") then
	function DebuffFilter_DebuffFrame_Update()
		-- The legacy update also maintains targetStates/targetTimers. Always run it even when
		-- its icons are not the selected renderer.
		DFT_OldTargetDebuffUpdate();
		if (DebuffFilter_GetAuraDisplayMode("target_debuff") ~= "icon") then DFT_HideOriginalIcons("target_debuff"); DFTimer.UpdateGroup("target_debuff"); end
		DebuffFilter_TimerBars_RefreshIconShine("target_debuff");
	end
end

if (DebuffFilter_Extension and type(DebuffFilter_Extension.UpdatePlayerDebuffs) == "function") then
	local DFT_OldPlayerDebuffUpdate = DebuffFilter_Extension.UpdatePlayerDebuffs;
	function DebuffFilter_Extension.UpdatePlayerDebuffs(suppressMessages)
		DFT_OldPlayerDebuffUpdate(suppressMessages);
		if (DebuffFilter_GetAuraDisplayMode("player_debuff") ~= "icon") then DFT_HideOriginalIcons("player_debuff"); DFTimer.UpdateGroup("player_debuff"); end
		DebuffFilter_TimerBars_RefreshIconShine("player_debuff");
	end
end

local DFT_OldCurrentTargetBuffUpdate = DebuffFilter_CurrentTargetBuffFrame_Update;
if (type(DFT_OldCurrentTargetBuffUpdate) == "function") then
	function DebuffFilter_CurrentTargetBuffFrame_Update()
		-- The legacy update maintains cast/first-seen timing records. Keep it active in every mode.
		DFT_OldCurrentTargetBuffUpdate();
		if (DebuffFilter_GetAuraDisplayMode("target_buff") ~= "icon") then DFT_HideOriginalIcons("target_buff"); DFTimer.UpdateGroup("target_buff"); end
		DebuffFilter_TimerBars_RefreshIconShine("target_buff");
	end
end

local DFT_OldTargetBuffFrameUpdate = DebuffFilter_TargetBuffFrame_Update;
if (type(DFT_OldTargetBuffFrameUpdate) == "function") then
	function DebuffFilter_TargetBuffFrame_Update()
		DFT_OldTargetBuffFrameUpdate();
		DFTimer.UpdateGroup("multi_buff");
	end
end

local DFT_OldMultiTargetDebuffFrameUpdate = DebuffFilter_MultiTargetDebuffFrame_Update;
if (type(DFT_OldMultiTargetDebuffFrameUpdate) == "function") then
	function DebuffFilter_MultiTargetDebuffFrame_Update()
		DFT_OldMultiTargetDebuffFrameUpdate();
		DFTimer.UpdateGroup("multi_debuff");
	end
end

local DFT_OldSetMoveFramesVisible = DebuffFilter_SetMoveFramesVisible;
if (type(DFT_OldSetMoveFramesVisible) == "function") then
	function DebuffFilter_SetMoveFramesVisible(visible)
		DFT_OldSetMoveFramesVisible(visible);
		DFTimer.RefreshAll(false);
	end
end

local DFT_OldReset = DebuffFilter_ResetCurrentCharacter;
if (type(DFT_OldReset) == "function") then
	function DebuffFilter_ResetCurrentCharacter()
		DFT_OldReset();
		local config = DFT_EnsureConfig();
		if (config) then
			config["aura_display_modes"] = DFT_CopyTable(DEFAULT_MODES);
			config["aura_icon_shine"] = { player_buff="no", player_debuff="no", target_buff="no", target_debuff="no", multi_buff="no", multi_debuff="no" };
			config["timer_bar_settings"] = DFT_CopyTable(DEFAULT_STYLE);
			config["timer_bar_group_styles"] = {};
			local index;
			for index = 1, table.getn(DFTimer.groupOrder), 1 do
				config["timer_bar_group_styles"][DFTimer.groupOrder[index]] = DFT_CopyTable(DEFAULT_STYLE);
			end
			config["timer_bar_schema"] = TIMER_SCHEMA;
		end
		DFTimer.activeBars = {}; DFTimer.expired = {}; DFTimer.orderSignatures = {};
		DFTimer.durationMemory = {};
		DFTimer.RefreshAll(true);
	end
end

local DFT_OldCommand = DebuffFilter_command;
if (type(DFT_OldCommand) == "function") then
	function DebuffFilter_command(message)
		local text = tostring(message or "");
		text = string.gsub(text, "^%s+", "");
		text = string.gsub(text, "%s+$", "");
		local _, _, command, parameter = string.find(text, "^(%S+)%s*(.-)$");
		command = string.lower(command or "");
		if (command == "bartest") then DebuffFilter_TimerBars_RunTest(); return; end
		if (command == "barrefresh") then DFTimer.RefreshAll(true); if (type(DebuffFilter_Print) == "function") then DebuffFilter_Print("计时条已刷新。"); end return; end
		if (command == "barmode") then
			local _, _, group, mode = string.find(parameter or "", "^(%S+)%s+(%S+)$");
			if (group and mode and DebuffFilter_SetAuraDisplayMode(group, string.lower(mode))) then
				if (type(DebuffFilter_Print) == "function") then DebuffFilter_Print(tostring(group) .. " 显示模式=" .. tostring(mode)); end
			else
				if (type(DebuffFilter_Print) == "function") then DebuffFilter_Print("格式：/dfilter barmode player_buff icon|bar|off"); end
			end
			return;
		end
		DFT_OldCommand(message);
	end
end

local DFT_EventFrame = CreateFrame("Frame", "DebuffFilter_TimerBarsEventFrame", UIParent);
DFT_EventFrame:RegisterEvent("VARIABLES_LOADED");
DFT_EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
DFT_EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED");
DFT_EventFrame:RegisterEvent("PLAYER_AURAS_CHANGED");
DFT_EventFrame:RegisterEvent("UNIT_AURA");
DFT_EventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED");
DFT_EventFrame:RegisterEvent("RAID_ROSTER_UPDATE");
DFT_EventFrame:SetScript("OnEvent", function()
	if (event == "VARIABLES_LOADED" or event == "PLAYER_ENTERING_WORLD") then DFT_EnsureConfig(); DebuffFilter_TimerBars_RefreshIconShine(); end
	DFTimer.RefreshAll(false);
end);

DFT_EventFrame:SetScript("OnUpdate", function()
	local elapsed = tonumber(arg1) or 0;
	DFTimer.shineElapsed = (DFTimer.shineElapsed or 0) + elapsed;
	local shineInterval = ((DFTimer.shineActiveCount or 0) > 20) and 0.10 or (DFTimer.shineInterval or 0.06);
	if (DFTimer.shineElapsed >= shineInterval) then
		local shineDelta = DFTimer.shineElapsed;
		DFTimer.shineElapsed = 0;
		if (DFT_AnyIconShineEnabled()) then
			DFT_IconShineTick(shineDelta);
		else
			DFTimer.shineActiveCount = 0;
		end
	end
	DFTimer.updateElapsed = DFTimer.updateElapsed + elapsed;
	if (DFTimer.testUntil and GetTime() >= DFTimer.testUntil) then
		local oldTestGroup = DFTimer.testGroup;
		DFTimer.testUntil = nil;
		DFTimer.testGroup = nil;
		DFTimer.testEntries = nil;
		if (oldTestGroup) then DFCB_StopGroup(oldTestGroup, false); end
		DFTimer.RefreshAll(true);
	end
	if (DFTimer.updateElapsed >= DFTimer.updateInterval) then
		DFTimer.updateElapsed = 0;
		-- 全部是普通图标、没有流光/多人图标/计时条时，TimerBars进入真正空闲，不再后台轮询六组。
		if (DFT_NeedsPeriodicRefresh()) then DFTimer.RefreshAll(false); end
	end
end);