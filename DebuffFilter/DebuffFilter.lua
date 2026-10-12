-- FuBar 顶部入口：直接使用同级插件 !Libs 提供的 Ace2 / FuBarPlugin-2.0。
-- DebuffFilter.toc 通过“## Dependencies: !Libs”保证这些库先于本文件加载。
DebuffFilter_FuBarEntry = AceLibrary("AceAddon-2.0"):new("FuBarPlugin-2.0")

DebuffFilter_FuBarEntry.name = "DebuffFilter"
DebuffFilter_FuBarEntry.hasIcon = "Interface\\Icons\\Spell_Holy_DispelMagic"
DebuffFilter_FuBarEntry.defaultPosition = "LEFT"
DebuffFilter_FuBarEntry.defaultMinimapPosition = 220
DebuffFilter_FuBarEntry.cannotDetachTooltip = true

function DebuffFilter_FuBarEntry:OnClick()
	if (arg1 == "LeftButton") then
		if (type(DebuffFilter_Manager_Toggle) == "function") then
			DebuffFilter_Manager_Toggle()
		elseif DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Buff监视：管理窗口尚未初始化，请执行 /reload。|r")
		end
	elseif (arg1 == "RightButton") then
		if (type(DebuffFilter_command) == "function") then
			DebuffFilter_command("status")
		end
	end
end

function DebuffFilter_FuBar_Status()
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Buff监视|r FuBar入口已创建：" .. tostring(DebuffFilter_FuBarEntry.name) .. "；库来源：!Libs")
	end
end

SlashCmdList["DFFUBAR"] = DebuffFilter_FuBar_Status
SLASH_DFFUBAR1 = "/dffubar"

-- v1.14.5: UI 字体统一继承客户端本地化字体。
-- 不再硬编码 FRIZQT__.TTF，避免中文客户端/中文字体环境中汉字变成空白。
local DebuffFilter_UIFontFile = nil

function DebuffFilter_GetUIFontFile()
	if (DebuffFilter_UIFontFile) then
		return DebuffFilter_UIFontFile;
	end

	-- CandyBar 也使用 GameFontHighlight:GetFont()；这里沿用客户端当前真正使用的字体文件。
	local fontObject = GameFontHighlight or GameFontNormal or GameFontNormalSmall;
	if (fontObject and fontObject.GetFont) then
		local fontFile = fontObject:GetFont();
		if (fontFile and fontFile ~= "") then
			DebuffFilter_UIFontFile = fontFile;
			return DebuffFilter_UIFontFile;
		end
	end

	-- 极端情况下保留原版字体作为兜底，避免因为字体对象异常导致 Lua 报错。
	DebuffFilter_UIFontFile = "Fonts\\FRIZQT__.TTF";
	return DebuffFilter_UIFontFile;
end

function DebuffFilter_SetUIFont(fontTarget, size, flags)
	if (not fontTarget or not fontTarget.SetFont) then return; end
	fontTarget:SetFont(DebuffFilter_GetUIFontFile(), size or 12, flags or "");
end

local DebuffFilter_DefaultSettings = {
	buffs = "yes",
	debuffs = "yes",
	scale = 1,
	buff_orientation = "rightleft",
	debuff_orientation = "leftright",
	time_orientation = "bottom",
	count = "no",
	tooltips = "yes",
	-- 仅过滤目标/多人四组；自身增益/减益不受影响。
	-- WoW 1.12 + SuperWoW 通过 UNIT_CASTEVENT 的 casterGUID 判断施法者。
	only_mine_auras = "no",
	debuff_timers = "yes",
	debuff_timer_custom = {},
	-- 自身 Buff / Debuff 总开关与两个独立显示开关。
	player_auras = "yes",
	player_debuffs = "yes",
	player_debuff_list = {},
	-- 当前目标 Buff：只显示当前选中目标，切换/取消目标后立即更新。
	current_target_buffs = "yes",
	current_target_buff_list = {},
	current_target_buff_duration_custom = {},
	-- 多人增益：保留扫描、GUID、持续时间数据、排序与标准锚点。
	target_buffs = "yes",
	target_buff_list = {
		["真言术：盾"] = 1,
	},
	target_buff_duration_custom = {},
	-- 多人减益：保留扫描、GUID、持续时间数据、排序与标准锚点。
	multi_target_debuffs = "yes",
	multi_target_debuff_list = {},
	multi_target_debuff_duration_custom = {},
	-- 六类光环区域可独立选择：icon=图标框，bar=计时条，off=关闭。
	aura_display_modes = {
		player_buff="icon", player_debuff="icon", target_buff="icon",
		target_debuff="icon", multi_buff="icon", multi_debuff="icon",
	},
	-- v1.13.0 使用用户提供的 CandyBar-2.2 双 StatusBar 逻辑。
	timer_bar_schema = 3,
	timer_bar_settings = {
		texture="LiteStep",
		bar_color={0.50,0.50,0.50,1},
		background_color={0.00,0.50,0.50,1},
		text_color="白色",
		background_alpha=1.00,
		width=200, height=20, scale=1.00, spacing=2,
		icon_position="LEFT", grow_up="no", reverse="no",
		text_template="$s  $t", text_size=10, ghost=0,
		show_icon="yes", show_text="yes", show_time="yes",
		fade_on_remove="yes", fade_on_death="yes",
	},
	-- 目标技能监测总开关。关闭后不记录施法间隔、不显示目标技能图标；已学习数据保留。
	target_spell_monitoring = "yes",
	-- 永久学习结果按“怪物名字 -> 技能ID”分类。
	-- 每项分别保存：开战到首次施法时间、施法后的循环周期，以及各自最近10条滚动样本。
	-- 怪物GUID、当前战斗起点和当前倒计时只保存在内存。
	target_spell_monsters = {},
	-- 用递增序号标记最近使用记录，配合可配置硬上限删除最久未使用的数据。
	target_spell_access_seq = 0,
	-- 最多永久保存多少个“怪物名字 + 技能ID”组合，管理窗口可修改。
	target_spell_max_saved_profiles = 1000,
	-- 敌人技能全局黑名单：key=技能ID字符串；命中后完全跳过敌人技能监视。
	target_spell_blacklist = {},
	-- 点击目标技能图标时使用的聊天频道：SAY / PARTY / RAID / GUILD。
	target_spell_announce_channel = "SAY",
	buff_position = { point="LEFT", relativeTo="PlayerFrame", relativePoint="RIGHT", x=-35, y=90 },
	debuff_position = { point="LEFT", relativeTo="TargetFrame", relativePoint="RIGHT", x=-35, y=90 },
	-- 技能监视框与目标Debuff框独立保存位置；默认视觉上位于目标Debuff上方。
	target_spell_position = { point="LEFT", relativeTo="TargetFrame", relativePoint="RIGHT", x=-35, y=140 },
	manager_position = { point="CENTER", relativeTo="UIParent", relativePoint="CENTER", x=0, y=10 },
	buff_list = {
		["盾墙"] = 1,
		["冲动"] = 1,
		["剑刃乱舞"] = 1,
		["神圣力量"] = 1,
	},
	debuff_list = {
		["破甲攻击"] = 1,
		["十字军打击"] = 1,
		["护甲粉碎"] = 1,
		["精灵之火（野性）"] = 1,
		["精灵之火"] = 1,
		["法术易伤"] = 1,
		["烈焰打击"] = 1,
		["痛苦诅咒"] = 1,
		["点燃"] = 1,
		["鲁莽诅咒"] = 1,
		["元素诅咒"] = 1,
		["暗影诅咒"] = 1,
		["暗影易伤"] = 1,
		["暗影之波"] = 1,
		["破甲"] = 1,
		["腐蚀毒药"] = 1,
	},
}

-- 对默认配置进行深复制，避免删除监视项目时连同“默认表”一起被修改。
local function DebuffFilter_CopyTable(source)
	if (type(source) ~= "table") then
		return source;
	end

	local result = {};
	for key, value in source do
		if (type(value) == "table") then
			result[key] = DebuffFilter_CopyTable(value);
		else
			result[key] = value;
		end
	end
	return result;
end

-- 框体拖动恢复为 v1.7.3 的原始逻辑。
-- 拖动开始只调用 StartMoving，松开只调用 StopMovingOrSizing。
-- 不在拖动、松开、PLAYER_LOGOUT 或 /reload 阶段读取框体坐标，
-- 位置由 WoW 1.12 客户端自身的布局缓存处理。
local function DebuffFilter_ResetOneFramePosition(frameName, point, relativeTo, relativePoint, x, y)
	local frame = getglobal(frameName);
	if (not frame) then return; end
	if (frame.SetUserPlaced) then frame:SetUserPlaced(false); end
	frame:ClearAllPoints();
	frame:SetPoint(point, relativeTo, relativePoint, x, y);
end

-- pfUI 使用插件目录名判断。该判断只决定默认锚点和系统光环按钮挂接分支。
function DebuffFilter_IsPfUIActive()
	if (type(IsAddOnLoaded) == "function" and IsAddOnLoaded("pfUI")) then
		return true;
	end
	return false;
end

local function DebuffFilter_CreateDefaultAnchor(name)
	local frame = getglobal(name);
	if (frame) then return frame; end
	frame = CreateFrame("Frame", name, UIParent);
	frame:SetWidth(1);
	frame:SetHeight(1);
	return frame;
end

DebuffFilter_BuffDefaultAnchor = DebuffFilter_CreateDefaultAnchor("DebuffFilter_BuffDefaultAnchor");
DebuffFilter_DebuffDefaultAnchor = DebuffFilter_CreateDefaultAnchor("DebuffFilter_DebuffDefaultAnchor");
DebuffFilter_TargetSpellDefaultAnchor = DebuffFilter_CreateDefaultAnchor("DebuffFilter_TargetSpellDefaultAnchor");

-- 只移动三个“默认锚点”，不读取实际监视框坐标。
-- 玩家拖动后的框体仍交给 WoW 1.12 自身布局缓存处理。
function DebuffFilter_UpdateDefaultAnchors()
	local usePfUI = DebuffFilter_IsPfUIActive();

	DebuffFilter_BuffDefaultAnchor:ClearAllPoints();
	DebuffFilter_DebuffDefaultAnchor:ClearAllPoints();
	DebuffFilter_TargetSpellDefaultAnchor:ClearAllPoints();

	if (usePfUI) then
		DebuffFilter_BuffDefaultAnchor:SetPoint("CENTER", UIParent, "CENTER", -220, -20);
		DebuffFilter_DebuffDefaultAnchor:SetPoint("CENTER", UIParent, "CENTER", 220, -20);
		DebuffFilter_TargetSpellDefaultAnchor:SetPoint("CENTER", UIParent, "CENTER", 220, 50);
	else
		DebuffFilter_BuffDefaultAnchor:SetPoint("LEFT", PlayerFrame, "RIGHT", -35, 90);
		DebuffFilter_DebuffDefaultAnchor:SetPoint("LEFT", TargetFrame, "RIGHT", -35, 90);
		DebuffFilter_TargetSpellDefaultAnchor:SetPoint("LEFT", TargetFrame, "RIGHT", -35, 140);
	end
end

DebuffFilter_UpdateDefaultAnchors();

local function DebuffFilter_ResetNativeFramePositions()
	DebuffFilter_UpdateDefaultAnchors();
	DebuffFilter_ResetOneFramePosition("DebuffFilter_BuffFrame", "CENTER", "DebuffFilter_BuffDefaultAnchor", "CENTER", 0, 0);
	DebuffFilter_ResetOneFramePosition("DebuffFilter_DebuffFrame", "CENTER", "DebuffFilter_DebuffDefaultAnchor", "CENTER", 0, 0);
	DebuffFilter_ResetOneFramePosition("DebuffFilter_TargetSpellFrame", "CENTER", "DebuffFilter_TargetSpellDefaultAnchor", "CENTER", 0, 0);
	DebuffFilter_ResetOneFramePosition("DebuffFilter_ManagerFrame", "CENTER", "UIParent", "CENTER", 0, 10);
end

DebuffFilter = DebuffFilter or {};

DebuffFilter.backdrop = nil;
DebuffFilter.targetUpdate = 0;
DebuffFilter.timerTextUpdate = 0;
DebuffFilter.comboUpdate = 0;
DebuffFilter.playerGUID = nil;
DebuffFilter.currentTargetKey = nil;
DebuffFilter.lastComboPoints = 0;
DebuffFilter.lastComboTarget = nil;
DebuffFilter.lastComboTime = 0;
DebuffFilter.targetStates = {};
DebuffFilter.targetTimers = {};
DebuffFilter.pendingCasts = {};
-- 目标 Debuff 最近一次施放来源。UnitDebuff 在 SuperWoW 中只额外返回 auraID，
-- 不返回 caster，因此使用 UNIT_CASTEVENT(casterGUID,targetGUID,CAST,spellID) 建立来源映射。
DebuffFilter.targetDebuffOwners = {};
DebuffFilter.targetDebuffHookUpdate = 0;
DebuffFilter.targetCtrlLeftWasDown = false;
DebuffFilter.lastTargetQuickAddIndex = nil;
DebuffFilter.lastTargetQuickAddTime = 0;

-- 目标怪物技能双阶段监视。
-- 第一阶段：观察怪物由非战斗进入战斗，到该技能第一次START的时间。
-- 第二阶段：按同一技能相邻两次START计算循环周期，读条时间属于完整周期的一部分。
-- 两套学习各自滚动保留最近10条样本，并共用同一个技能图标和倒计时文字位置。
-- 已学习技能每次START都会立即切换为循环倒计时，即使随后被打断也继续计时。
-- 怪物GUID、开战时间和当前倒计时只用于本次登录期间。
-- UNIT_CASTEVENT 会后台接收附近所有敌对NPC的施法；界面始终只显示当前目标。
-- 若开启姓名板，还会周期扫描姓名板GUID，观察周围怪物的非战斗 -> 战斗转换，用于首轮倒计时。
DebuffFilter.targetSpellDisplayCache = {};
DebuffFilter.targetSpellRuntime = {};
DebuffFilter.targetSpellCurrentGUID = nil;
DebuffFilter.targetSpellUpdate = 0;
DebuffFilter.targetSpellNearbyScanUpdate = 0;
DebuffFilter.targetSpellMaxSamples = 10;
DebuffFilter.targetSpellMaxSavedProfiles = 1000; -- 默认值；实际运行值读取当前角色配置。
DebuffFilter.targetSpellMaxRuntimeTargets = 60;
DebuffFilter.targetSpellRuntimeExpire = 1800;
DebuffFilter.targetSpellTimingMode = "START_TO_START_ADAPTIVE_V2";
DebuffFilter.targetSpellInitialTimingMode = "COMBAT_TO_FIRST_START_ADAPTIVE_V1";
DebuffFilter.targetSpellCastDebug = false;

-- 目标 Debuff 预设持续时间。
-- 固定持续时间与连击点持续时间表；
-- 破甲攻击、精灵之火、点燃为常用经典技能预设，可用 /dfilter dtime 覆盖。
DebuffFilter.DebuffRules = {
	["致盲"] = { base=10 },
	["偷袭"] = { base=4 },
	["破甲"] = { base=30 },
	["绞喉"] = { base=18 },
	["凿击"] = { base=4 },
	["出血"] = { base=15 },
	["脚踢 - 沉默"] = { base=2 },
	["肾击"] = { base=1, combo=1 },
	["割裂"] = { base=8, combo=2 },
	["闷棍"] = { base=45 },
	["致命毒药"] = { base=12 },
	["致伤毒药"] = { base=15 },
	["致残毒药"] = { base=12 },
	["破甲攻击"] = { base=30 },
	["精灵之火"] = { base=40 },
	["精灵之火（野性）"] = { base=40 },
	["点燃"] = { base=4 },
}

-- 施法名与实际光环名不一致时的别名。
DebuffFilter.CastAuraAliases = {
	["脚踢"] = { ["脚踢 - 沉默"] = 1 },
}

-- 乌龟服部分中文 Aura 名称可能带不可见字符（例如 U+200B 零宽空格）。
-- 聊天框输入的“闷棍”和 Tooltip 实际返回的“​​闷棍”肉眼相同，但直接比较会失败。
local function DebuffFilter_NormalizeName(name)
	if (not name) then
		return nil;
	end

	name = tostring(name);
	name = string.gsub(name, "\226\128\139", ""); -- UTF-8 U+200B
	name = string.gsub(name, "\239\187\191", ""); -- UTF-8 BOM
	name = string.gsub(name, "\194\160", " ");      -- UTF-8 NBSP
	name = string.gsub(name, "^%s+", "");
	name = string.gsub(name, "%s+$", "");
	return name;
end


local DebuffFilter_FindConfiguredName;

-- 读取当前目标指定序号的 Debuff 名称。
-- WoW 1.12 的 UnitDebuff 不直接返回名称，因此继续使用隐藏 Tooltip 获取。
local function DebuffFilter_GetTargetDebuffNameByIndex(index)
	index = tonumber(index);
	if (not index or index < 1 or not UnitExists("target")) then
		return nil;
	end

	local texture = UnitDebuff("target", index);
	if (not texture) then
		return nil;
	end

	DebuffFilter_Tooltip:SetOwner(UIParent, "ANCHOR_NONE");
	DebuffFilter_Tooltip:ClearLines();
	DebuffFilter_Tooltip:SetUnitDebuff("target", index);
	return DebuffFilter_NormalizeName(DebuffFilter_TooltipTextLeft1:GetText());
end

-- 默认目标框一般使用 TargetFrameDebuff1、TargetFrameDebuff2……，
-- 某些旧式 UI 会把按钮 ID 设为 0，因此同时从按钮名称末尾提取序号。
local function DebuffFilter_GetSystemTargetDebuffIndex(button)
	if (not button) then
		return nil;
	end

	local index = nil;
	if (button.GetID) then
		index = tonumber(button:GetID());
	end

	if (index and index >= 1 and UnitDebuff("target", index)) then
		return index;
	end

	local buttonName = button.GetName and button:GetName() or nil;
	if (buttonName) then
		local _, _, numberText = string.find(buttonName, "(%d+)$");
		index = tonumber(numberText);
		if (index and index >= 1 and UnitDebuff("target", index)) then
			return index;
		end
	end

	-- 兼容少数从 0 开始编号的自定义目标框。
	if (index and index >= 0 and UnitDebuff("target", index + 1)) then
		return index + 1;
	end

	return nil;
end

local function DebuffFilter_AddTargetDebuffFromSystemButton(button, forcedIndex)
	if (not DebuffFilter_Config or not DebuffFilter_Player or not DebuffFilter_Config[DebuffFilter_Player]) then
		return;
	end

	local index = tonumber(forcedIndex) or DebuffFilter_GetSystemTargetDebuffIndex(button);
	if (not index) then
		DebuffFilter_Print("无法识别这个目标 Debuff 的序号。");
		return;
	end

	local debuffName = DebuffFilter_GetTargetDebuffNameByIndex(index);
	if (not debuffName or debuffName == "") then
		DebuffFilter_Print("无法读取这个目标 Debuff 的名称。");
		return;
	end

	-- 同一次点击可能同时被按钮脚本和全局鼠标检测捕获，避免重复提示。
	local now = GetTime();
	if (DebuffFilter.lastTargetQuickAddIndex == index and (now - (DebuffFilter.lastTargetQuickAddTime or 0)) < 0.25) then
		return;
	end
	DebuffFilter.lastTargetQuickAddIndex = index;
	DebuffFilter.lastTargetQuickAddTime = now;

	local list = DebuffFilter_Config[DebuffFilter_Player]["debuff_list"];
	local configuredName = DebuffFilter_FindConfiguredName(list, debuffName);
	if (configuredName) then
		DebuffFilter_Print("目标 Debuff 已在监视列表中：\"|cff00ccff" .. debuffName .. "|r\"");
		return;
	end

	list[debuffName] = 1;
	DebuffFilter_DebuffFrame_Update();
	DebuffFilter_Print("已通过目标头像添加目标 Debuff：\"|cff00ccff" .. debuffName .. "|r\"");
end

-- 保留目标框按钮原有的鼠标脚本；Ctrl+左键只额外执行“添加监视”。
function DebuffFilter_SystemTargetDebuff_OnMouseDown()
	-- WoW 1.12 的 SetScript 鼠标回调主要通过全局 arg1 传递按键。
	-- 这里不能把 arg1 写成形参，否则部分客户端中形参会是 nil，
	-- 从而导致 TargetFrameDebuff1 明明被点击却完全没有反应。
	local mouseButton = arg1;
	local button = this;

	if (mouseButton == "LeftButton" and IsControlKeyDown()) then
		DebuffFilter_AddTargetDebuffFromSystemButton(button);
	end

	if (button and button.DebuffFilter_OldOnMouseDown) then
		button.DebuffFilter_OldOnMouseDown(mouseButton);
	end
end

local function DebuffFilter_HookOneSystemTargetDebuffButton(button)
	if (not button or not button.GetScript or not button.SetScript) then
		return;
	end

	-- 其他目标框插件可能在我们之后重新设置 OnMouseDown。
	-- 每次检查当前脚本，发现被覆盖就重新挂接，而不是只看一次性标记。
	local currentScript = button:GetScript("OnMouseDown");
	if (currentScript ~= DebuffFilter_SystemTargetDebuff_OnMouseDown) then
		button.DebuffFilter_OldOnMouseDown = currentScript;
		button:SetScript("OnMouseDown", DebuffFilter_SystemTargetDebuff_OnMouseDown);
	end
	button.DebuffFilter_TargetDebuffHooked = 1;
end

local function DebuffFilter_HookSystemTargetDebuffButtons()
	-- 用户指定：pfUI 下跳过目标 Debuff 原始图标快捷键。
	if (DebuffFilter_IsPfUIActive()) then return; end
	-- 无 pfUI 时完整保留 v1.9.7.7 默认目标框与常见旧式目标框命名。
	local prefixes = {
		"TargetFrameDebuff",
		"TargetDebuff",
		"TargetFrameDebuffButton",
		"TargetDebuffButton",
		"pfTargetDebuff",
		"LunaTargetFrameDebuff",
	};

	for prefixIndex = 1, table.getn(prefixes), 1 do
		local prefix = prefixes[prefixIndex];
		for buttonIndex = 1, 32, 1 do
			DebuffFilter_HookOneSystemTargetDebuffButton(getglobal(prefix .. buttonIndex));
		end
	end
end


-- ============================================================
-- pfUI 自身 Buff 图标 Ctrl+左键快捷添加
-- pfUI 真实按钮名：pfBuffFrameBuff1、pfBuffFrameBuff2……
-- 无 pfUI 时不执行本段，完整保留 v1.9.7.7 原生逻辑。
-- ============================================================
local function DebuffFilter_GetPfBuffDisplayIndex(button)
	if (not button) then return nil; end
	local buttonName = button.GetName and button:GetName() or nil;
	if (buttonName) then
		local _, _, numberText = string.find(buttonName, "^pfBuffFrameBuff(%d+)$");
		local number = tonumber(numberText);
		if (number and number >= 1) then return number; end
	end
	local id = button.GetID and tonumber(button:GetID()) or nil;
	if (id and id >= 1) then return id; end
	return nil;
end

local function DebuffFilter_GetHelpfulBuffNameByDisplayIndex(displayIndex)
	displayIndex = tonumber(displayIndex);
	if (not displayIndex or displayIndex < 1) then return nil; end
	local buffIndex = GetPlayerBuff(displayIndex - 1, "HELPFUL");
	if (not buffIndex or buffIndex < 0) then return nil; end
	DebuffFilter_Tooltip:SetOwner(UIParent, "ANCHOR_NONE");
	DebuffFilter_Tooltip:ClearLines();
	DebuffFilter_Tooltip:SetPlayerBuff(buffIndex);
	return DebuffFilter_NormalizeName(DebuffFilter_TooltipTextLeft1:GetText());
end

local function DebuffFilter_AddPlayerBuffFromPfUIButton(button)
	if (not DebuffFilter_Config or not DebuffFilter_Player or not DebuffFilter_Config[DebuffFilter_Player]) then return; end
	local displayIndex = DebuffFilter_GetPfBuffDisplayIndex(button);
	local buffName = DebuffFilter_GetHelpfulBuffNameByDisplayIndex(displayIndex);
	if (not buffName) then
		DebuffFilter_Print("无法读取这个 pfUI 自身 Buff 的名称。");
		return;
	end
	local list = DebuffFilter_Config[DebuffFilter_Player]["buff_list"];
	if (list[buffName] == 1) then
		DebuffFilter_Print("自身 Buff 已在监视列表中：|cff00ccff" .. buffName .. "|r");
		return;
	end
	list[buffName] = 1;
	DebuffFilter_BuffFrame_Update();
	DebuffFilter_Print("已通过 pfUI 图标添加自身 Buff：|cff00ccff" .. buffName .. "|r");
end

function DebuffFilter_PfBuff_OnMouseDown()
	local mouseButton = arg1;
	local button = this;
	if (mouseButton == "LeftButton" and IsControlKeyDown()) then
		DebuffFilter_AddPlayerBuffFromPfUIButton(button);
	end
	if (button and button.DebuffFilter_PfBuffOldOnMouseDown) then
		button.DebuffFilter_PfBuffOldOnMouseDown(mouseButton);
	end
end

local function DebuffFilter_HookOnePfBuffButton(button)
	if (not button or not button.GetScript or not button.SetScript) then return; end
	local current = button:GetScript("OnMouseDown");
	if (current ~= DebuffFilter_PfBuff_OnMouseDown) then
		button.DebuffFilter_PfBuffOldOnMouseDown = current;
		button:SetScript("OnMouseDown", DebuffFilter_PfBuff_OnMouseDown);
	end
end

local function DebuffFilter_HookPfBuffButtons()
	if (not DebuffFilter_IsPfUIActive()) then return; end
	for index = 1, 40, 1 do
		DebuffFilter_HookOnePfBuffButton(getglobal("pfBuffFrameBuff" .. tostring(index)));
	end
end


-- 判断鼠标焦点是否位于目标框的 Debuff 区域。
-- 用于兼容完全重写按钮脚本、或按钮名称不在常见列表中的目标框插件。
local function DebuffFilter_IsTargetDebuffMouseFrame(frame)
	local current = frame;
	local sawTarget = false;
	local sawDebuff = false;
	local depth = 0;

	while (current and depth < 8) do
		if (current == TargetFrame) then
			sawTarget = true;
		end

		local currentName = current.GetName and current:GetName() or nil;
		if (currentName) then
			local lowerName = string.lower(currentName);
			if (string.find(lowerName, "target")) then
				sawTarget = true;
			end
			if (string.find(lowerName, "debuff")) then
				sawDebuff = true;
			end
			if (string.find(currentName, "^DebuffFilter_")) then
				return false, false;
			end
		end

		current = current.GetParent and current:GetParent() or nil;
		depth = depth + 1;
	end

	return sawTarget, sawDebuff;
end

local function DebuffFilter_FrameContainsTexture(frame, wantedTexture)
	if (not frame or not wantedTexture) then
		return false;
	end

	if (frame.GetNormalTexture) then
		local normal = frame:GetNormalTexture();
		if (normal and normal.GetTexture and normal:GetTexture() == wantedTexture) then
			return true;
		end
	end

	if (frame.GetRegions) then
		local regions = { frame:GetRegions() };
		for i = 1, table.getn(regions), 1 do
			local region = regions[i];
			if (region and region.GetTexture and region:GetTexture() == wantedTexture) then
				return true;
			end
		end
	end

	return false;
end

local function DebuffFilter_GetTargetDebuffIndexFromMouseFocus()
	if (type(GetMouseFocus) ~= "function") then
		return nil;
	end

	local focus = GetMouseFocus();
	if (not focus) then
		return nil;
	end

	local targetContext, debuffContext = DebuffFilter_IsTargetDebuffMouseFrame(focus);
	if (not targetContext) then
		return nil;
	end

	-- 名称链明确包含 Debuff 时，优先使用按钮 ID 或名称末尾数字。
	local current = focus;
	local depth = 0;
	if (debuffContext) then
		while (current and depth < 5) do
			local index = DebuffFilter_GetSystemTargetDebuffIndex(current);
			if (index) then
				return index;
			end
			current = current.GetParent and current:GetParent() or nil;
			depth = depth + 1;
		end
	end

	-- 再按鼠标焦点内的图标纹理与当前目标 Debuff 逐个比对。
	for index = 1, 32, 1 do
		local texture = UnitDebuff("target", index);
		if (not texture) then
			break;
		end

		current = focus;
		depth = 0;
		while (current and depth < 4) do
			if (DebuffFilter_FrameContainsTexture(current, texture)) then
				return index;
			end
			current = current.GetParent and current:GetParent() or nil;
			depth = depth + 1;
		end
	end

	return nil;
end

local function DebuffFilter_CheckTargetDebuffCtrlClick()
	-- pfUI 下不使用目标 Debuff 原始图标快捷添加。
	if (DebuffFilter_IsPfUIActive()) then return; end
	if (type(IsMouseButtonDown) ~= "function") then
		return;
	end

	local leftDown = IsMouseButtonDown("LeftButton") and true or false;
	if (leftDown and not DebuffFilter.targetCtrlLeftWasDown and IsControlKeyDown()) then
		local index = DebuffFilter_GetTargetDebuffIndexFromMouseFocus();
		if (index) then
			DebuffFilter_AddTargetDebuffFromSystemButton(nil, index);
		end
	end
	DebuffFilter.targetCtrlLeftWasDown = leftDown;
end

DebuffFilter_FindConfiguredName = function(list, name)
	if (not list or not name) then
		return nil;
	end

	local normalized = DebuffFilter_NormalizeName(name);
	if (list[normalized]) then
		return normalized;
	end

	for configuredName in list do
		if (DebuffFilter_NormalizeName(configuredName) == normalized) then
			return configuredName;
		end
	end

	return nil;
end

local function DebuffFilter_GetUnitKey(unit)
	local exists, guid = UnitExists(unit);
	if (not exists) then
		return nil;
	end

	if (guid) then
		return tostring(guid);
	end

	local name = UnitName(unit);
	if (name) then
		return "name:" .. name;
	end

	return nil;
end

local function DebuffFilter_GetDuration(debuffName, comboPoints)
	debuffName = DebuffFilter_NormalizeName(debuffName);
	if (not DebuffFilter_Config or not DebuffFilter_Player or not DebuffFilter_Config[DebuffFilter_Player]) then
		return nil;
	end

	local custom = DebuffFilter_Config[DebuffFilter_Player]["debuff_timer_custom"];
	if (custom and custom[debuffName]) then
		local customTime = tonumber(custom[debuffName]);
		if (customTime and customTime > 0) then
			return customTime;
		end
		return nil;
	end

	local rule = DebuffFilter.DebuffRules[debuffName];
	if (not rule) then
		return nil;
	end

	local duration = tonumber(rule.base) or 0;
	if (rule.combo) then
		local cp = tonumber(comboPoints) or 1;
		if (cp < 1) then cp = 1; end
		if (cp > 5) then cp = 5; end
		duration = duration + (cp - 1) * rule.combo;
	end

	if (duration > 0) then
		return duration;
	end

	return nil;
end

local function DebuffFilter_GetRecentComboPoints(targetKey)
	if (targetKey and DebuffFilter.lastComboTarget == targetKey and (GetTime() - DebuffFilter.lastComboTime) <= 2.0) then
		if (DebuffFilter.lastComboPoints and DebuffFilter.lastComboPoints > 0) then
			return DebuffFilter.lastComboPoints;
		end
	end
	return 1;
end

local function DebuffFilter_StartDebuffTimer(targetKey, debuffName, comboPoints, reason)
	if (DebuffFilter_Config[DebuffFilter_Player]["debuff_timers"] == "no") then
		return;
	end

	local duration = DebuffFilter_GetDuration(debuffName, comboPoints);
	if (not duration) then
		return;
	end

	if (not DebuffFilter.targetTimers[targetKey]) then
		DebuffFilter.targetTimers[targetKey] = {};
	end

	DebuffFilter.targetTimers[targetKey][debuffName] = {
		startTime = GetTime(),
		endTime = GetTime() + duration,
		duration = duration,
		reason = reason,
	};
end

local function DebuffFilter_CastMatchesDebuff(pending, debuffName, auraID)
	if (not pending) then
		return false;
	end

	debuffName = DebuffFilter_NormalizeName(debuffName);
	local pendingName = DebuffFilter_NormalizeName(pending.spellName);

	if (pendingName and pendingName == debuffName) then
		return true;
	end

	if (pendingName and DebuffFilter.CastAuraAliases[pendingName] and DebuffFilter.CastAuraAliases[pendingName][debuffName]) then
		return true;
	end

	if (pending.spellID and auraID and tonumber(pending.spellID) == tonumber(auraID)) then
		return true;
	end

	return false;
end

local function DebuffFilter_GetPendingCast(targetKey, debuffName, auraID)
	local pending = DebuffFilter.pendingCasts[targetKey];
	if (not pending) then
		return nil;
	end

	if ((GetTime() - pending.time) > 2.0) then
		DebuffFilter.pendingCasts[targetKey] = nil;
		return nil;
	end

	if (not pending.used) then
		pending.used = {};
	end

	if (pending.used[debuffName]) then
		return nil;
	end

	if (DebuffFilter_CastMatchesDebuff(pending, debuffName, auraID)) then
		pending.used[debuffName] = 1;
		return pending;
	end

	return nil;
end

local function DebuffFilter_FormatRemaining(seconds)
	if (not seconds or seconds <= 0) then
		return "";
	end

	if (seconds < 10) then
		return string.format("%.1f", seconds);
	end

	return SecondsToTimeAbbrev(math.ceil(seconds));
end

local function DebuffFilter_RecordPlayerCast()
	if (arg3 ~= "CAST") then
		return;
	end

	if (not DebuffFilter.playerGUID) then
		local exists, guid = UnitExists("player");
		if (exists and guid) then DebuffFilter.playerGUID = tostring(guid); end
	end

	if (not DebuffFilter.playerGUID or tostring(arg1) ~= DebuffFilter.playerGUID) then
		return;
	end

	local targetKey = nil;
	if (arg2) then targetKey = tostring(arg2); end
	if (not targetKey or targetKey == "0" or targetKey == "nil") then
		targetKey = DebuffFilter_GetUnitKey("target");
	end
	if (not targetKey) then return; end

	local spellName = nil;
	if (type(GetSpellRecField) == "function" and arg4) then
		spellName = DebuffFilter_NormalizeName(GetSpellRecField(arg4, "name"));
	end

	DebuffFilter.pendingCasts[targetKey] = {
		time = GetTime(),
		spellID = arg4,
		spellName = spellName,
		comboPoints = DebuffFilter_GetRecentComboPoints(targetKey),
		used = {},
	};
end


-- “只显示我施加的 Buff / Debuff”只影响目标/多人四组。
-- SuperWoW 的 UnitBuff/UnitDebuff 只提供 auraID，不提供 caster；
-- 所以这里用 UNIT_CASTEVENT 的 casterGUID + targetGUID + spellID 记录最近一次施放来源。
function DebuffFilter_IsOnlyMineAurasEnabled()
	local config = DebuffFilter_Config and DebuffFilter_Player and DebuffFilter_Config[DebuffFilter_Player];
	return config and config["only_mine_auras"] == "yes";
end

function DebuffFilter_IsPlayerCasterGUID(casterGUID)
	if (not casterGUID) then return false; end
	if (not DebuffFilter.playerGUID) then
		local exists, guid = UnitExists("player");
		if (exists and guid) then DebuffFilter.playerGUID = tostring(guid); end
	end
	return DebuffFilter.playerGUID and tostring(casterGUID) == tostring(DebuffFilter.playerGUID) or false;
end

local function DebuffFilter_RecordTargetDebuffOwnerCast()
	-- 性能保护：该来源表仅服务“只显示我施加的光环”。关闭过滤时完全不处理战斗施法事件。
	if (not DebuffFilter_IsOnlyMineAurasEnabled()) then return; end
	local state = arg3 and string.upper(tostring(arg3)) or nil;
	if (state ~= "CAST" and state ~= "SUCCESS" and state ~= "STOP" and state ~= "CHANNEL_STOP") then return; end

	-- 过滤目标只需要确认“我自己的施法”。其他玩家/NPC的高频施法不再解析技能名、建表。
	local isMine = DebuffFilter_IsPlayerCasterGUID(arg1);
	if (not isMine) then return; end
	local targetKey = arg2 and tostring(arg2) or nil;
	if (not targetKey or targetKey == "" or targetKey == "0" or targetKey == "nil") then
		-- 只有自己的施法才允许回退当前目标，避免把别人的无目标事件误记到当前目标。
		if (isMine) then targetKey = DebuffFilter_GetUnitKey("target"); end
	end
	if (not targetKey) then return; end

	local spellID = tonumber(arg4) or arg4;
	if (not spellID) then return; end
	local spellName = nil;
	if (type(GetSpellRecField) == "function") then
		local ok, name = pcall(GetSpellRecField, spellID, "name");
		if (ok and name) then spellName = DebuffFilter_NormalizeName(name); end
	end
	if (not spellName and type(SpellInfo) == "function") then
		local ok, name = pcall(SpellInfo, spellID);
		if (ok and name) then spellName = DebuffFilter_NormalizeName(name); end
	end
	if (not spellName) then return; end

	local bucket = DebuffFilter.targetDebuffOwners[targetKey];
	if (not bucket) then
		bucket = { names={}, ids={} };
		DebuffFilter.targetDebuffOwners[targetKey] = bucket;
	end
	if (type(bucket.names) ~= "table") then bucket.names = {}; end
	if (type(bucket.ids) ~= "table") then bucket.ids = {}; end
	local record = { mine=true, caster=tostring(arg1 or ""), spellID=spellID, time=GetTime() };
	bucket.names[spellName] = record;
	bucket.ids[tostring(spellID)] = record;

	local aliases = DebuffFilter.CastAuraAliases and DebuffFilter.CastAuraAliases[spellName];
	if (type(aliases) == "table") then
		for auraName in aliases do
			local normalized = DebuffFilter_NormalizeName(auraName);
			if (normalized) then bucket.names[normalized] = record; end
		end
	end
end

function DebuffFilter_IsTargetDebuffMine(targetKey, debuffName, auraID)
	if (not targetKey) then return false; end
	local bucket = DebuffFilter.targetDebuffOwners and DebuffFilter.targetDebuffOwners[tostring(targetKey)] or nil;
	if (not bucket) then return false; end
	local normalized = DebuffFilter_NormalizeName(debuffName);
	local record = normalized and bucket.names and bucket.names[normalized] or nil;
	if (not record and auraID and bucket.ids) then record = bucket.ids[tostring(auraID)]; end
	if (not record) then return false; end
	-- 防止跨很长时间的旧施法记录误判；正常长 Buff/DeBuff 的状态由各自模块扫描持续保活。
	if (record.time and GetTime() - record.time > 7200) then return false; end
	return record.mine and true or false;
end

DebuffFilter.FrameOrientation = {
	leftright = { point="LEFT", relpoint="RIGHT", x=1, y=0, count_y=0, next_orient="topbottom", next_time="left" },
	topbottom = { point="TOP", relpoint="BOTTOM", x=0, y=-1, count_y=8, next_orient="rightleft", next_time="bottom" },
	rightleft = { point="RIGHT", relpoint="LEFT", x=-1, y=0, count_y=0, next_orient="bottomtop", next_time="right" },
	bottomtop = { point="BOTTOM", relpoint="TOP", x=0, y=1, count_y=-8, next_orient="leftright", next_time="bottom" },
}

DebuffFilter.TimeOrientation = {
	bottom = { next_time = "top" },
	top = { next_time = "bottom" },
	left = { next_time = "right" },
	right = { next_time = "left" },
}

DebuffFilter.Frames = {
	buffs = { frame="DebuffFilter_BuffFrame", orient_key="buff_orientation", list="buff_list", name="buff", target="", add_cmd="add", del_cmd="del", list_cmd="list", button="DebuffFilter_BuffButton", start=0, num=1, relnum=2, x=4, y=4 },
	debuffs = { frame="DebuffFilter_DebuffFrame", orient_key="debuff_orientation", list="debuff_list", name="target debuff", target="hostile", add_cmd="dadd", del_cmd="ddel", list_cmd="dlist", button="DebuffFilter_DebuffButton", start=0, num=1, relnum=2, x=4, y=4 },
}

DebuffFilter_Targets = {
	hostile = "target",
	friendly = "targettarget",
}


function DebuffFilter_DebuffButton_OnEnter()
	if (DebuffFilter_Config[DebuffFilter_Player]["tooltips"] == "yes" and this.debuffIndex) then
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
		GameTooltip:SetUnitDebuff("target", this.debuffIndex);
	end
end


-- 获取 SuperWoW 技能记录中的名称和图标。
-- SuperWoW 的正确接口是 SpellInfo(spellID)，第三个返回值为技能贴图路径。
-- GetSpellInfo / GetSpellTexture 仅作为其他环境的兼容回退。
local function DebuffFilter_GetSpellDisplayInfo(spellID)
	local spellName = nil;
	local spellIcon = nil;

	if (type(SpellInfo) == "function") then
		local ok, name, rank, icon = pcall(SpellInfo, spellID);
		if (ok) then
			spellName = DebuffFilter_NormalizeName(name);
			spellIcon = icon;
		end
	end

	if ((not spellName or spellName == "" or not spellIcon or spellIcon == "") and type(GetSpellInfo) == "function") then
		local ok, name, rank, icon = pcall(GetSpellInfo, spellID);
		if (ok) then
			if (not spellName or spellName == "") then
				spellName = DebuffFilter_NormalizeName(name);
			end
			if (not spellIcon or spellIcon == "") then
				spellIcon = icon;
			end
		end
	end

	if ((not spellName or spellName == "") and type(GetSpellRecField) == "function") then
		local ok, name = pcall(GetSpellRecField, spellID, "name");
		if (ok) then
			spellName = DebuffFilter_NormalizeName(name);
		end
	end

	-- 原版 GetSpellTexture 的数字参数通常是法术书栏位，不是技能ID；这里只作为最后兼容回退。
	if ((not spellIcon or spellIcon == "") and type(GetSpellTexture) == "function") then
		local ok, icon = pcall(GetSpellTexture, spellID);
		if (ok) then spellIcon = icon; end
	end

	if (not spellName or spellName == "") then
		spellName = "技能 #" .. tostring(spellID or "?");
	end
	if (not spellIcon or spellIcon == "") then
		spellIcon = "Interface\\Icons\\INV_Misc_QuestionMark";
	end

	return spellName, spellIcon;
end

local DebuffFilter_TargetSpellChannelNames = {
	SAY = "说",
	PARTY = "小队",
	RAID = "团队",
	GUILD = "公会",
};

local function DebuffFilter_IsTargetSpellMonitoringEnabled()
	local config = DebuffFilter_Config and DebuffFilter_Config[DebuffFilter_Player];
	return config and config["target_spell_monitoring"] ~= "no";
end

function DebuffFilter_IsTargetSpellBlacklisted(spellID)
	if (spellID == nil) then return false; end
	local config = DebuffFilter_Config and DebuffFilter_Config[DebuffFilter_Player];
	if (not config or type(config["target_spell_blacklist"]) ~= "table") then return false; end
	return config["target_spell_blacklist"][tostring(spellID)] ~= nil;
end

local function DebuffFilter_AddTargetSpellBlacklistByValues(spellID, spellName)
	local numericID = tonumber(spellID);
	if (not numericID or numericID <= 0 or numericID ~= math.floor(numericID)) then
		DebuffFilter_Print("无法加入黑名单：请输入有效的技能ID。");
		return false;
	end

	local config = DebuffFilter_Config and DebuffFilter_Config[DebuffFilter_Player];
	if (not config) then return false; end
	if (type(config["target_spell_blacklist"]) ~= "table") then config["target_spell_blacklist"] = {}; end

	local spellKey = tostring(numericID);
	if (config["target_spell_blacklist"][spellKey] ~= nil) then
		DebuffFilter_Print("该技能已在敌人技能黑名单中：" .. spellKey);
		return false;
	end

	if (not spellName or spellName == "") then
		spellName = DebuffFilter_GetSpellDisplayInfo(numericID);
	end
	config["target_spell_blacklist"][spellKey] = {
		spellID = numericID,
		name = spellName or ("技能 #" .. spellKey),
	};

	-- 黑名单只负责过滤，不删除已经学习好的永久首轮/循环资料。
	-- 立刻清掉本次登录中的临时状态，避免当前图标继续显示。
	for _, runtime in DebuffFilter.targetSpellRuntime do
		if (runtime and type(runtime.skills) == "table") then runtime.skills[spellKey] = nil; end
	end
	if (type(DebuffFilter_TargetSpellFrame_Update) == "function") then DebuffFilter_TargetSpellFrame_Update(); end
	if (DebuffFilter_MoonUI and type(DebuffFilter_MoonUI.RefreshSpellBlacklist) == "function") then
		DebuffFilter_MoonUI.RefreshSpellBlacklist();
	end
	DebuffFilter_Print("已加入敌人技能黑名单：" .. tostring(spellName or ("技能 #" .. spellKey)) .. "（" .. spellKey .. "）");
	return true;
end

function DebuffFilter_AddTargetSpellBlacklist(state)
	if (not state or state.spellID == nil) then
		DebuffFilter_Print("无法加入黑名单：当前技能资料不完整。");
		return false;
	end
	return DebuffFilter_AddTargetSpellBlacklistByValues(state.spellID, state.name);
end

-- 黑名单设置页手动输入技能ID时使用；与Alt+左键共用同一套保存和过滤逻辑。
function DebuffFilter_AddTargetSpellBlacklistByID(spellID)
	return DebuffFilter_AddTargetSpellBlacklistByValues(spellID, nil);
end

function DebuffFilter_RemoveTargetSpellBlacklist(spellID)
	if (spellID == nil) then return false; end
	local config = DebuffFilter_Config and DebuffFilter_Config[DebuffFilter_Player];
	if (not config or type(config["target_spell_blacklist"]) ~= "table") then return false; end
	local spellKey = tostring(spellID);
	local entry = config["target_spell_blacklist"][spellKey];
	if (not entry) then return false; end
	config["target_spell_blacklist"][spellKey] = nil;
	if (DebuffFilter_MoonUI and type(DebuffFilter_MoonUI.RefreshSpellBlacklist) == "function") then
		DebuffFilter_MoonUI.RefreshSpellBlacklist();
	end
	if (type(DebuffFilter_TargetSpellFrame_Update) == "function") then DebuffFilter_TargetSpellFrame_Update(); end
	local spellName = type(entry) == "table" and entry.name or nil;
	DebuffFilter_Print("已解除敌人技能黑名单：" .. tostring(spellName or ("技能 #" .. spellKey)) .. "（" .. spellKey .. "）");
	return true;
end

local function DebuffFilter_GetMonsterNameFromUnit(unit)
	if (not unit) then return nil; end
	local ok, name = pcall(UnitName, unit);
	if (not ok) then return nil; end
	name = DebuffFilter_NormalizeName(name);
	if (not name or name == "") then return nil; end
	return name;
end

local function DebuffFilter_GetCurrentTargetMonsterName()
	return DebuffFilter_GetMonsterNameFromUnit("target");
end

-- SuperWoW允许所有Unit函数直接使用GUID。这里统一判断当前目标或后台施法者是否为敌对NPC。
local function DebuffFilter_IsHostileNPCUnit(unit)
	if (not unit) then return false; end
	local ok, exists = pcall(UnitExists, unit);
	if (not ok or not exists) then return false; end

	if (type(UnitIsPlayer) == "function") then
		local playerOK, isPlayer = pcall(UnitIsPlayer, unit);
		if (playerOK and isPlayer) then return false; end
	end
	if (type(UnitPlayerControlled) == "function") then
		local controlledOK, controlled = pcall(UnitPlayerControlled, unit);
		if (controlledOK and controlled) then return false; end
	end

	if (type(UnitCanAttack) == "function") then
		local attackOK, canAttack = pcall(UnitCanAttack, "player", unit);
		if (attackOK and canAttack) then return true; end
	end
	if (type(UnitReaction) == "function") then
		local reactionOK, reaction = pcall(UnitReaction, "player", unit);
		if (reactionOK and reaction and reaction <= 4) then return true; end
	end
	return false;
end

local function DebuffFilter_IsUnitDead(unit)
	if (not unit) then return false; end
	if (type(UnitIsDeadOrGhost) == "function") then
		local ok, dead = pcall(UnitIsDeadOrGhost, unit);
		if (ok and dead) then return true; end
	end
	if (type(UnitIsDead) == "function") then
		local ok, dead = pcall(UnitIsDead, unit);
		if (ok and dead) then return true; end
	end
	if (type(UnitHealth) == "function" and type(UnitHealthMax) == "function") then
		local healthOK, health = pcall(UnitHealth, unit);
		local maxOK, maxHealth = pcall(UnitHealthMax, unit);
		-- 只有最大生命值确实可读时，才把0生命当作死亡，避免未缓存GUID返回0造成误清理。
		if (healthOK and maxOK and tonumber(maxHealth) and tonumber(maxHealth) > 0 and tonumber(health) and tonumber(health) <= 0) then return true; end
	end
	return false;
end

local function DebuffFilter_IsValidTargetMonster()
	if (not DebuffFilter_IsHostileNPCUnit("target")) then return false; end
	if (DebuffFilter_IsUnitDead("target")) then return false; end
	return true;
end

local function DebuffFilter_GetTargetSpellRemaining(state)
	if (not state or not state.castTime) then return nil; end
	local elapsed = GetTime() - state.castTime;
	if (state.interval ~= nil and tonumber(state.interval) and tonumber(state.interval) >= 0) then
		local remaining = tonumber(state.interval) - elapsed;
		if (remaining < 0) then remaining = 0; end
		return remaining, elapsed;
	end
	return nil, elapsed;
end

local function DebuffFilter_AnnounceTargetSpell(state)
	if (not state) then return; end
	local config = DebuffFilter_Config and DebuffFilter_Config[DebuffFilter_Player];
	if (not config) then return; end

	local channel = config["target_spell_announce_channel"] or "SAY";
	if (not DebuffFilter_TargetSpellChannelNames[channel]) then channel = "SAY"; end

	if (channel == "PARTY") then
		local partyCount = type(GetNumPartyMembers) == "function" and GetNumPartyMembers() or 0;
		local raidCount = type(GetNumRaidMembers) == "function" and GetNumRaidMembers() or 0;
		if (partyCount <= 0 and raidCount <= 0) then DebuffFilter_Print("当前不在小队中，无法播报到小队频道。"); return; end
	elseif (channel == "RAID") then
		local raidCount = type(GetNumRaidMembers) == "function" and GetNumRaidMembers() or 0;
		if (raidCount <= 0) then DebuffFilter_Print("当前不在团队中，无法播报到团队频道。"); return; end
	elseif (channel == "GUILD" and type(IsInGuild) == "function" and not IsInGuild()) then
		DebuffFilter_Print("当前没有公会，无法播报到公会频道。"); return;
	end

	local remaining = DebuffFilter_GetTargetSpellRemaining(state);
	local text;
	if (state.timerMode == "initial_learning") then
		text = "[技能监视] " .. state.name .. "：正在学习进入战斗后的首次施法时间。";
	elseif (state.timerMode == "initial") then
		if (remaining and remaining > 0) then
			text = "[技能监视] " .. state.name .. "：首轮预计 " .. string.format("%.1f", remaining) .. " 秒后就绪。";
		else
			text = "[技能监视] " .. state.name .. "：首轮技能已就绪，可能随时施放。";
		end
	elseif (state.readyBeforeCast and not state.castTime) then
		text = "[技能监视] " .. state.name .. "：当前显示就绪；进入战斗后将使用首轮时间，施法后切换循环周期。";
	elseif (state.timerMode == "cycle" and state.interval ~= nil and remaining ~= nil) then
		if (remaining > 0) then
			text = "[技能监视] " .. state.name .. "：循环周期 " .. string.format("%.1f", state.interval) .. " 秒，预计 " .. string.format("%.1f", remaining) .. " 秒后就绪。";
		else
			text = "[技能监视] " .. state.name .. "：循环技能已就绪，可能随时施放。";
		end
	else
		text = "[技能监视] " .. state.name .. "：正在学习技能循环周期。";
	end

	local ok = pcall(SendChatMessage, text, channel);
	if (not ok) then DebuffFilter_Print("技能播报失败，当前频道：" .. (DebuffFilter_TargetSpellChannelNames[channel] or channel)); end
end

local function DebuffFilter_TargetSpellButton_OnEnter()
	local state = this.spellState;
	if (not state) then return; end

	local remaining = DebuffFilter_GetTargetSpellRemaining(state);
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
	GameTooltip:AddLine(state.name or ("技能 #" .. tostring(state.spellID or "?")), 1, 0.82, 0);
	if (state.monsterName and state.monsterName ~= "") then GameTooltip:AddLine("怪物：" .. state.monsterName, 1, 1, 1); end
	GameTooltip:AddLine("技能ID：" .. tostring(state.spellID or "?"), 1, 1, 1);

	if (state.initialInterval ~= nil) then
		GameTooltip:AddLine("进战斗首次时间：" .. string.format("%.1f 秒", state.initialInterval), 0.3, 0.85, 1);
	else
		GameTooltip:AddLine("进战斗首次时间：学习中", 0.3, 0.85, 1);
	end
	if (state.cycleInterval ~= nil) then
		GameTooltip:AddLine("施法后循环周期：" .. string.format("%.1f 秒", state.cycleInterval), 0.3, 1, 0.3);
	else
		GameTooltip:AddLine("施法后循环周期：学习中", 0.3, 1, 0.3);
	end

	if (state.timerMode == "initial_learning") then
		GameTooltip:AddLine("当前阶段：正在观察开战后的第一次施法", 0.3, 0.85, 1);
	elseif (state.timerMode == "initial") then
		if (remaining and remaining > 0) then
			GameTooltip:AddLine("当前阶段：首轮倒计时 " .. string.format("%.1f 秒", remaining), 0.3, 0.85, 1);
		else
			GameTooltip:AddLine("当前阶段：首轮已就绪", 1, 0.2, 0.2);
		end
	elseif (state.timerMode == "cycle") then
		if (state.cycleInterval == nil) then
			GameTooltip:AddLine("当前阶段：正在学习循环周期", 0.3, 0.85, 1);
		elseif (remaining and remaining > 0) then
			GameTooltip:AddLine("当前阶段：循环倒计时 " .. string.format("%.1f 秒", remaining), 1, 0.82, 0);
		else
			GameTooltip:AddLine("当前阶段：循环技能已就绪", 1, 0.2, 0.2);
		end
	else
		GameTooltip:AddLine("当前阶段：等待进入战斗或技能施放", 0.8, 0.8, 0.8);
	end

	GameTooltip:AddLine("首轮与循环各自滚动保留最近10条样本，共用一个图标。", 0.6, 0.8, 1, 1);
	local config = DebuffFilter_Config and DebuffFilter_Config[DebuffFilter_Player];
	local channel = config and config["target_spell_announce_channel"] or "SAY";
	GameTooltip:AddLine("左键播报到：" .. (DebuffFilter_TargetSpellChannelNames[channel] or "说"), 0.4, 1, 0.4);
	GameTooltip:AddLine("Alt+左键：加入敌人技能黑名单，之后完全跳过该技能监视。", 1, 0.45, 0.20);
	GameTooltip:AddLine("Ctrl+左键：删除当前怪物该技能的全部首轮、循环和临时记录。", 1, 0.25, 0.25);
	GameTooltip:AddLine("Shift+左键拖动：独立移动技能监视框。", 0.4, 1, 1);
	GameTooltip:AddLine("右键：整理循环周期样本，只保留当前主要周期组。", 1, 0.65, 0.2);
	GameTooltip:AddLine("蓝色数字=开战首轮；金色数字=施法后循环；红色0=已就绪。", 0.75, 0.75, 0.75, 1);
	GameTooltip:Show();
end

local function DebuffFilter_TargetSpellButton_OnLeave()
	GameTooltip:Hide();
end

local function DebuffFilter_TargetSpellButton_OnClick()
	-- Shift+左键用于拖动；短时间吞掉拖动松开产生的Click，避免误播报。
	if (this.targetSpellSkipClickUntil) then
		if (GetTime() <= this.targetSpellSkipClickUntil) then return; end
		this.targetSpellSkipClickUntil = nil;
	end
	if (arg1 == "LeftButton" and type(IsShiftKeyDown) == "function" and IsShiftKeyDown()) then return; end
	if (not this.spellState) then return; end
	if (arg1 == "LeftButton") then
		-- Alt+左键直接加入全局技能黑名单；优先于Ctrl删除和普通播报。
		if (type(IsAltKeyDown) == "function" and IsAltKeyDown()) then
			DebuffFilter_AddTargetSpellBlacklist(this.spellState);
		-- Ctrl+左键：删除当前“怪物名字 + 技能ID”的全部永久与临时记录。
		elseif (type(IsControlKeyDown) == "function" and IsControlKeyDown()) then
			if (type(DebuffFilter_DeleteTargetSpellRecord) == "function") then
				DebuffFilter_DeleteTargetSpellRecord(this.spellState);
			end
		else
			DebuffFilter_AnnounceTargetSpell(this.spellState);
		end
	elseif (arg1 == "RightButton" and type(DebuffFilter_CleanTargetSpellSamples) == "function") then
		DebuffFilter_CleanTargetSpellSamples(this.spellState);
	end
end

local function DebuffFilter_TargetSpellButton_OnMouseDown()
	if (arg1 == "LeftButton" and type(IsShiftKeyDown) == "function" and IsShiftKeyDown()) then
		local parent = this:GetParent();
		if (parent) then
			this.targetSpellDragging = 1;
			parent:StartMoving();
		end
	end
end

local function DebuffFilter_TargetSpellButton_OnMouseUp()
	if (arg1 == "LeftButton" and this.targetSpellDragging) then
		local parent = this:GetParent();
		if (parent) then
			parent:StopMovingOrSizing();
		end
		this.targetSpellDragging = nil;
		this.targetSpellSkipClickUntil = GetTime() + 0.25;
	end
end

function DebuffFilter_CreateTargetSpellFrame()
	if (getglobal("DebuffFilter_TargetSpellFrame")) then return; end

	local frame = CreateFrame("Frame", "DebuffFilter_TargetSpellFrame", DebuffFilterFrame);
	frame:SetWidth(30);
	frame:SetHeight(30);
	-- 与目标 Debuff 框完全独立，默认位置由 pfUI/原生分支锚点决定。
	frame:SetPoint("CENTER", "DebuffFilter_TargetSpellDefaultAnchor", "CENTER", 0, 0);
	frame:SetMovable(1);
	frame:Hide();

	local backdrop = CreateFrame("Button", "DebuffFilter_TargetSpellFrameBackdrop", frame, "DebuffFilter_BackdropTemplate");
	backdrop:SetPoint("CENTER", frame, "CENTER", 0, 0);
	backdrop:Hide();
	local label = backdrop:CreateFontString(nil, "ARTWORK", "GameFontNormal");
	label:SetWidth(90);
	label:SetHeight(12);
	label:SetPoint("TOP", backdrop, "TOP", 0, 15);
	label:SetText("敌人技能");

	for i = 0, 15, 1 do
		local name = "DebuffFilter_TargetSpellButton" .. i;
		local button = CreateFrame("Button", name, frame);
		button:SetWidth(30);
		button:SetHeight(30);
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp");
		button:Hide();
		button:SetScript("OnEnter", DebuffFilter_TargetSpellButton_OnEnter);
		button:SetScript("OnLeave", DebuffFilter_TargetSpellButton_OnLeave);
		button:SetScript("OnMouseDown", DebuffFilter_TargetSpellButton_OnMouseDown);
		button:SetScript("OnMouseUp", DebuffFilter_TargetSpellButton_OnMouseUp);
		button:SetScript("OnClick", DebuffFilter_TargetSpellButton_OnClick);

		if (i == 0) then
			button:SetPoint("LEFT", frame, "LEFT", 0, 0);
		else
			button:SetPoint("LEFT", "DebuffFilter_TargetSpellButton" .. (i - 1), "RIGHT", 4, 0);
		end

		local icon = button:CreateTexture(name .. "Icon", "ARTWORK");
		icon:SetAllPoints(button);
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);

		local border = button:CreateTexture(nil, "OVERLAY");
		border:SetTexture("Interface\\Buttons\\UI-Quickslot2");
		border:SetPoint("CENTER", button, "CENTER", 0, 0);
		border:SetWidth(54);
		border:SetHeight(54);

		local interval = button:CreateFontString(name .. "Interval", "OVERLAY");
		interval:SetPoint("TOP", button, "BOTTOM", 0, 1);
		DebuffFilter_SetUIFont(interval, 11, "OUTLINE");
		interval:SetTextColor(1, 0.82, 0);
		interval:SetText("");
	end
end

local function DebuffFilter_HideTargetSpellButtons()
	local frame = getglobal("DebuffFilter_TargetSpellFrame");
	if (not frame) then return; end
	for i = 0, 15, 1 do
		local buttonName = "DebuffFilter_TargetSpellButton" .. i;
		local button = getglobal(buttonName);
		button.spellState = nil;
		getglobal(buttonName .. "Interval"):SetText("");
		button:Hide();
	end
	local backdrop = getglobal("DebuffFilter_TargetSpellFrameBackdrop");
	if (backdrop) then
		if (DebuffFilter.backdrop == 1) then backdrop:Show(); else backdrop:Hide(); end
	end
	if (DebuffFilter.backdrop == 1) then frame:Show(); else frame:Hide(); end
end

local function DebuffFilter_IsCurrentTargetDeadMonster()
	if (not DebuffFilter_IsHostileNPCUnit("target")) then return false; end
	return DebuffFilter_IsUnitDead("target");
end

local function DebuffFilter_GetTargetSpellRuntime(guid, create, monsterName)
	if (not guid) then return nil; end
	guid = tostring(guid);
	local runtime = DebuffFilter.targetSpellRuntime[guid];
	if (not runtime and create) then
		runtime = { skills={}, order=0, lastSeen=GetTime(), monsterName=monsterName, combatState=nil, combatObserved=false, combatStartedAt=nil };
		DebuffFilter.targetSpellRuntime[guid] = runtime;
	elseif (runtime and monsterName and monsterName ~= "") then
		runtime.monsterName = monsterName;
	end
	return runtime;
end

local function DebuffFilter_CleanupTargetSpellRuntime()
	local now = GetTime();
	local count = 0;
	local oldestGUID = nil;
	local oldestTime = now;
	for guid, runtime in DebuffFilter.targetSpellRuntime do
		local seen = runtime and runtime.lastSeen or 0;
		if (guid ~= DebuffFilter.targetSpellCurrentGUID and now - seen > DebuffFilter.targetSpellRuntimeExpire) then
			DebuffFilter.targetSpellRuntime[guid] = nil;
		else
			count = count + 1;
			if (guid ~= DebuffFilter.targetSpellCurrentGUID and seen < oldestTime) then
				oldestTime = seen;
				oldestGUID = guid;
			end
		end
	end
	while (count > DebuffFilter.targetSpellMaxRuntimeTargets and oldestGUID) do
		DebuffFilter.targetSpellRuntime[oldestGUID] = nil;
		count = count - 1;
		oldestGUID = nil;
		oldestTime = now;
		for guid, runtime in DebuffFilter.targetSpellRuntime do
			local seen = runtime and runtime.lastSeen or 0;
			if (guid ~= DebuffFilter.targetSpellCurrentGUID and seen < oldestTime) then
				oldestTime = seen;
				oldestGUID = guid;
			end
		end
	end
end

local function DebuffFilter_ClearTargetSpellRuntime(guid)
	local wasCurrent = false;
	if (guid) then
		guid = tostring(guid);
		wasCurrent = DebuffFilter.targetSpellCurrentGUID == guid;
		DebuffFilter.targetSpellRuntime[guid] = nil;
		if (wasCurrent) then DebuffFilter.targetSpellCurrentGUID = nil; end
	end
	-- 后台怪物死亡只删除它自己的GUID状态，不应把当前目标图标一起隐藏。
	if (wasCurrent or not guid) then DebuffFilter_HideTargetSpellButtons(); end
end

-- 重新进入世界或恢复初始设置时，清空全部临时GUID状态。
-- 已学习的“怪物名字 + 技能ID”、最近10条滚动样本和稳定周期仍由SavedVariables单独管理。
local function DebuffFilter_ClearTargetSpellSession()
	DebuffFilter.targetSpellRuntime = {};
	DebuffFilter.targetSpellCurrentGUID = nil;
	DebuffFilter_HideTargetSpellButtons();
end

local function DebuffFilter_ResetTargetSpellScreenForTarget()
	DebuffFilter_ClearTargetSpellSession();
end

-- 所有实测间隔先归入0.5秒档位，减少事件精度和网络抖动造成的小数噪声。
local function DebuffFilter_BucketSpellInterval(interval)
	interval = tonumber(interval);
	if (not interval) then return nil; end
	return math.floor(interval * 2 + 0.5) / 2;
end

-- 周期越长允许的自然抖动越大：最少0.5秒，最多1.5秒。
local function DebuffFilter_GetSpellIntervalTolerance(interval)
	local base = tonumber(interval) or 0;
	local tolerance = base * 0.10;
	if (tolerance < 0.5) then tolerance = 0.5; end
	if (tolerance > 1.5) then tolerance = 1.5; end
	return tolerance;
end

local function DebuffFilter_IsCompatibleSpellTimingMode(mode)
	return mode == nil
		or mode == "SUCCESS_START_TO_SUCCESS_START"
		or mode == DebuffFilter.targetSpellTimingMode;
end

local function DebuffFilter_GetMedianSpellInterval(values)
	if (type(values) ~= "table" or table.getn(values) <= 0) then return nil; end
	local sorted = {};
	for _, value in values do
		table.insert(sorted, tonumber(value));
	end
	table.sort(sorted);
	local count = table.getn(sorted);
	local middle = math.floor((count + 1) / 2);
	if (math.mod(count, 2) == 1) then
		return DebuffFilter_BucketSpellInterval(sorted[middle]);
	end
	return DebuffFilter_BucketSpellInterval((sorted[middle] + sorted[middle + 1]) / 2);
end

-- 评估某个候选基础周期。
-- 直接命中权重最高；2倍、3倍周期只提供较弱支持，用于识别漏施法或延迟到下一轮的情况。
local function DebuffFilter_EvaluateSpellIntervalCandidate(samples, candidate)
	candidate = DebuffFilter_BucketSpellInterval(candidate);
	if (not candidate or candidate < 0.5 or candidate > 600) then return nil; end

	local tolerance = DebuffFilter_GetSpellIntervalTolerance(candidate);
	local directValues = {};
	local directCount = 0;
	local multipleCount = 0;

	for _, rawSample in samples do
		local sample = DebuffFilter_BucketSpellInterval(rawSample);
		if (sample and sample >= 0.5 and sample <= 600) then
			local ratio = sample / candidate;
			local multiple = math.floor(ratio + 0.5);
			if (multiple >= 1 and multiple <= 3) then
				local allowed = tolerance * multiple;
				if (math.abs(sample - candidate * multiple) <= allowed) then
					if (multiple == 1) then
						directCount = directCount + 1;
						table.insert(directValues, sample);
					else
						multipleCount = multipleCount + 1;
					end
				end
			end
		end
	end

	local representative = DebuffFilter_GetMedianSpellInterval(directValues) or candidate;
	return {
		candidate = candidate,
		interval = representative,
		directCount = directCount,
		multipleCount = multipleCount,
		supportCount = directCount + multipleCount,
		score = directCount * 4 + multipleCount,
	};
end

local function DebuffFilter_BuildSpellIntervalCandidates(samples)
	local candidates = {};
	local seen = {};
	if (type(samples) ~= "table") then return candidates; end

	for _, rawSample in samples do
		local sample = DebuffFilter_BucketSpellInterval(rawSample);
		if (sample and sample >= 0.5 and sample <= 600) then
			for divisor = 1, 3, 1 do
				local candidate = DebuffFilter_BucketSpellInterval(sample / divisor);
				if (candidate and candidate >= 0.5 and candidate <= 600) then
					local key = string.format("%.1f", candidate);
					if (not seen[key]) then
						seen[key] = true;
						table.insert(candidates, candidate);
					end
				end
			end
		end
	end
	return candidates;
end

-- 智能选择稳定周期：
-- 1. 相近时间自动归组；2. 2倍/3倍样本可反向支持基础周期；
-- 3. 少数短重试、击晕延迟不会覆盖当前周期；4. 新周期持续占优才切换。
local function DebuffFilter_SelectAdaptiveSpellInterval(samples, currentInterval)
	if (type(samples) ~= "table" or table.getn(samples) <= 0) then return nil, 0, 0; end
	currentInterval = DebuffFilter_BucketSpellInterval(currentInterval);

	local candidates = DebuffFilter_BuildSpellIntervalCandidates(samples);
	local best = nil;
	for _, candidate in candidates do
		local info = DebuffFilter_EvaluateSpellIntervalCandidate(samples, candidate);
		-- 候选基础周期必须至少有一次直接样本，不能只靠倍数凭空推导。
		if (info and info.directCount > 0) then
			local choose = false;
			if (not best or info.score > best.score) then
				choose = true;
			elseif (best and info.score == best.score) then
				if (info.directCount > best.directCount) then
					choose = true;
				elseif (info.directCount == best.directCount and currentInterval) then
					local infoNearCurrent = math.abs(info.interval - currentInterval) <= DebuffFilter_GetSpellIntervalTolerance(currentInterval);
					local bestNearCurrent = math.abs(best.interval - currentInterval) <= DebuffFilter_GetSpellIntervalTolerance(currentInterval);
					if (infoNearCurrent and not bestNearCurrent) then choose = true; end
				end
			end
			if (choose) then best = info; end
		end
	end
	if (not best) then return currentInterval, 0, 0; end

	-- 没有旧周期时，第一条有效样本即可作为临时周期，后续滚动样本再修正。
	if (not currentInterval) then
		return best.interval, math.min(10, best.supportCount), best.directCount;
	end

	local currentInfo = DebuffFilter_EvaluateSpellIntervalCandidate(samples, currentInterval);
	local currentScore = currentInfo and currentInfo.score or 0;
	local currentDirect = currentInfo and currentInfo.directCount or 0;
	local sameGroup = math.abs(best.interval - currentInterval) <= DebuffFilter_GetSpellIntervalTolerance(currentInterval);

	if (sameGroup) then
		-- 同一周期组内保持当前值，避免4.5/5.0来回跳动。
		return currentInterval, math.min(10, currentInfo and currentInfo.supportCount or best.supportCount), currentDirect;
	end

	local switch = false;
	local shortRetryCandidate = best.interval < currentInterval * 0.60;
	local delayedCandidate = best.interval > currentInterval * 1.25;
	if (shortRetryCandidate) then
		-- 明显更短的周期通常是打断后重试；必须在10条中形成强多数才允许替换。
		if (best.directCount >= 6 and best.score >= currentScore + 4) then switch = true; end
	elseif (delayedCandidate) then
		-- 明显更长的周期通常来自击晕、沉默、走位或漏掉一次施法；要求更强多数。
		if (best.directCount >= 7 and (currentDirect <= 3 or best.score >= currentScore + 8)) then
			switch = true;
		end
	else
		-- 普通新周期至少需要3条直接样本，并且明显胜过当前周期。
		if (best.directCount >= 3 and (best.score >= currentScore + 3 or currentDirect == 0)) then
			switch = true;
		end
	end

	if (switch) then
		return best.interval, math.min(10, best.supportCount), best.directCount;
	end
	return currentInterval, math.min(10, currentInfo and currentInfo.supportCount or 0), currentDirect;
end

-- 保留旧函数名供其他代码调用；现在内部已经是自适应模型，不再是简单众数。
local function DebuffFilter_SelectDominantSpellInterval(samples, currentInterval)
	local interval, confidence, directCount = DebuffFilter_SelectAdaptiveSpellInterval(samples, currentInterval);
	return interval, directCount, confidence;
end

-- 找出最近10条循环样本中的主周期和次要周期。这里只负责统计证据，不直接改写已锁定周期。
local function DebuffFilter_FindBestSpellIntervalGroups(samples, currentInterval)
	local candidates = DebuffFilter_BuildSpellIntervalCandidates(samples);
	local infos = {};
	local function IsBetter(left, right)
		if (not right) then return true; end
		if (left.directCount ~= right.directCount) then return left.directCount > right.directCount; end
		if (left.score ~= right.score) then return left.score > right.score; end
		if (currentInterval) then
			local tolerance = DebuffFilter_GetSpellIntervalTolerance(currentInterval);
			local leftNear = math.abs(left.interval - currentInterval) <= tolerance;
			local rightNear = math.abs(right.interval - currentInterval) <= tolerance;
			if (leftNear ~= rightNear) then return leftNear; end
		end
		return left.interval < right.interval;
	end
	for _, candidate in candidates do
		local info = DebuffFilter_EvaluateSpellIntervalCandidate(samples, candidate);
		if (info and info.directCount > 0) then table.insert(infos, info); end
	end

	local best = nil;
	for _, info in infos do
		if (IsBetter(info, best)) then best = info; end
	end
	if (not best) then return nil, nil; end

	local second = nil;
	for _, info in infos do
		local sameBestGroup = math.abs(info.interval - best.interval) <= DebuffFilter_GetSpellIntervalTolerance(best.interval);
		if (not sameBestGroup and IsBetter(info, second)) then second = info; end
	end
	return best, second;
end

local function DebuffFilter_IsSameSpellIntervalGroup(left, right)
	left = DebuffFilter_BucketSpellInterval(left);
	right = DebuffFilter_BucketSpellInterval(right);
	if (not left or not right) then return false; end
	return math.abs(left - right) <= DebuffFilter_GetSpellIntervalTolerance(right);
end

-- 稳定周期锁定模型：
-- 1. samples 永远只保留最近10条；2. interval 是独立的正式周期；
-- 3. 新周期至少5票、比旧周期多2票，并连续两次滚动判断都成立，才替换正式周期。
local function DebuffFilter_UpdateLockedSpellInterval(profile)
	if (not profile or type(profile.samples) ~= "table") then return nil, 0; end
	local sampleCount = table.getn(profile.samples);
	if (sampleCount <= 0) then return profile.interval, 0; end

	local currentInterval = DebuffFilter_BucketSpellInterval(profile.interval);
	local best, second = DebuffFilter_FindBestSpellIntervalGroups(profile.samples, currentInterval);
	if (not best) then return currentInterval, 0; end

	local locked = profile.interval_locked == "yes";
	if (not currentInterval) then
		currentInterval = best.interval;
		profile.interval = currentInterval;
	end

	if (not locked) then
		-- 尚未锁定时允许临时周期跟随当前主组，保证第二个样本后即可使用倒计时。
		profile.interval = best.interval;
		currentInterval = best.interval;
		local secondCount = second and second.directCount or 0;
		if (best.directCount >= 5 and best.directCount >= secondCount + 2) then
			profile.interval_locked = "yes";
			profile.candidate_interval = nil;
			profile.candidate_confirm = 0;
		end
		profile.confidence = math.min(10, best.directCount);
		return profile.interval, profile.confidence;
	end

	local currentInfo = DebuffFilter_EvaluateSpellIntervalCandidate(profile.samples, currentInterval);
	local currentCount = currentInfo and currentInfo.directCount or 0;
	if (DebuffFilter_IsSameSpellIntervalGroup(best.interval, currentInterval)) then
		profile.candidate_interval = nil;
		profile.candidate_confirm = 0;
		profile.confidence = math.min(10, currentCount);
		return currentInterval, profile.confidence;
	end

	local qualifies = best.directCount >= 5 and best.directCount >= currentCount + 2;
	if (qualifies) then
		if (DebuffFilter_IsSameSpellIntervalGroup(profile.candidate_interval, best.interval)) then
			profile.candidate_confirm = (tonumber(profile.candidate_confirm) or 0) + 1;
		else
			profile.candidate_interval = best.interval;
			profile.candidate_confirm = 1;
		end
		if ((tonumber(profile.candidate_confirm) or 0) >= 2) then
			profile.interval = best.interval;
			profile.interval_locked = "yes";
			profile.candidate_interval = nil;
			profile.candidate_confirm = 0;
			profile.confidence = math.min(10, best.directCount);
			return profile.interval, profile.confidence;
		end
	else
		profile.candidate_interval = nil;
		profile.candidate_confirm = 0;
	end

	profile.interval = currentInterval;
	profile.confidence = math.min(10, currentCount);
	return profile.interval, profile.confidence;
end


-- “进入战斗 -> 第一次施法”允许0秒（开战立即施放），因此使用独立的0.5秒分档和稳定选择逻辑。
local function DebuffFilter_BucketInitialSpellInterval(interval)
	interval = tonumber(interval);
	if (not interval or interval < 0 or interval > 600) then return nil; end
	local bucket = math.floor(interval * 2 + 0.5) / 2;
	if (bucket < 0) then bucket = 0; end
	return bucket;
end

local function DebuffFilter_GetInitialIntervalTolerance(interval)
	local value = tonumber(interval) or 0;
	if (value <= 0.5) then return 0.5; end
	return DebuffFilter_GetSpellIntervalTolerance(value);
end

local function DebuffFilter_EvaluateInitialIntervalCandidate(samples, candidate)
	candidate = DebuffFilter_BucketInitialSpellInterval(candidate);
	if (candidate == nil) then return nil; end
	local tolerance = DebuffFilter_GetInitialIntervalTolerance(candidate);
	local direct = {};
	for _, rawSample in samples do
		local sample = DebuffFilter_BucketInitialSpellInterval(rawSample);
		if (sample ~= nil and math.abs(sample - candidate) <= tolerance) then
			table.insert(direct, sample);
		end
	end
	local representative;
	if (table.getn(direct) > 0) then
		table.sort(direct);
		local count = table.getn(direct);
		local middle = math.floor((count + 1) / 2);
		if (math.mod(count, 2) == 1) then
			representative = direct[middle];
		else
			representative = (direct[middle] + direct[middle + 1]) / 2;
		end
		representative = DebuffFilter_BucketInitialSpellInterval(representative);
	end
	return { interval=representative or candidate, directCount=table.getn(direct) };
end

local function DebuffFilter_SelectAdaptiveInitialInterval(samples, currentInterval)
	if (type(samples) ~= "table" or table.getn(samples) <= 0) then return nil, 0; end
	currentInterval = DebuffFilter_BucketInitialSpellInterval(currentInterval);
	local seen = {};
	local best = nil;
	for _, rawSample in samples do
		local candidate = DebuffFilter_BucketInitialSpellInterval(rawSample);
		if (candidate ~= nil) then
			local key = string.format("%.1f", candidate);
			if (not seen[key]) then
				seen[key] = true;
				local info = DebuffFilter_EvaluateInitialIntervalCandidate(samples, candidate);
				if (info) then
					local choose = false;
					if (not best or info.directCount > best.directCount) then
						choose = true;
					elseif (best and info.directCount == best.directCount and currentInterval ~= nil) then
						local currentTolerance = DebuffFilter_GetInitialIntervalTolerance(currentInterval);
						local infoNear = math.abs(info.interval - currentInterval) <= currentTolerance;
						local bestNear = math.abs(best.interval - currentInterval) <= currentTolerance;
						if (infoNear and not bestNear) then choose = true; end
					end
					if (choose) then best = info; end
				end
			end
		end
	end
	if (not best) then return currentInterval, 0; end
	if (currentInterval == nil) then return best.interval, best.directCount; end

	local currentInfo = DebuffFilter_EvaluateInitialIntervalCandidate(samples, currentInterval);
	local currentCount = currentInfo and currentInfo.directCount or 0;
	local sameGroup = math.abs(best.interval - currentInterval) <= DebuffFilter_GetInitialIntervalTolerance(currentInterval);
	if (sameGroup) then return currentInterval, currentCount; end

	-- 首轮时间容易受到拉怪距离、仇恨建立和走位影响；至少3条并真正超过旧组才切换。
	if (best.directCount >= 3 and best.directCount > currentCount) then
		return best.interval, best.directCount;
	end
	return currentInterval, currentCount;
end

local function DebuffFilter_FindBestInitialIntervalGroups(samples, currentInterval)
	local seen = {};
	local infos = {};
	local function IsBetter(left, right)
		if (not right) then return true; end
		if (left.directCount ~= right.directCount) then return left.directCount > right.directCount; end
		if (currentInterval ~= nil) then
			local tolerance = DebuffFilter_GetInitialIntervalTolerance(currentInterval);
			local leftNear = math.abs(left.interval - currentInterval) <= tolerance;
			local rightNear = math.abs(right.interval - currentInterval) <= tolerance;
			if (leftNear ~= rightNear) then return leftNear; end
		end
		return left.interval < right.interval;
	end
	for _, rawSample in samples do
		local candidate = DebuffFilter_BucketInitialSpellInterval(rawSample);
		if (candidate ~= nil) then
			local key = string.format("%.1f", candidate);
			if (not seen[key]) then
				seen[key] = true;
				local info = DebuffFilter_EvaluateInitialIntervalCandidate(samples, candidate);
				if (info) then table.insert(infos, info); end
			end
		end
	end

	local best = nil;
	for _, info in infos do
		if (IsBetter(info, best)) then best = info; end
	end
	if (not best) then return nil, nil; end

	local second = nil;
	for _, info in infos do
		local sameBestGroup = math.abs(info.interval - best.interval) <= DebuffFilter_GetInitialIntervalTolerance(best.interval);
		if (not sameBestGroup and IsBetter(info, second)) then second = info; end
	end
	return best, second;
end

local function DebuffFilter_IsSameInitialIntervalGroup(left, right)
	left = DebuffFilter_BucketInitialSpellInterval(left);
	right = DebuffFilter_BucketInitialSpellInterval(right);
	if (left == nil or right == nil) then return false; end
	return math.abs(left - right) <= DebuffFilter_GetInitialIntervalTolerance(right);
end

-- 首轮时间也使用独立锁定值，避免拉怪距离或偶发走位让“进战斗首次施法时间”频繁变化。
local function DebuffFilter_UpdateLockedInitialInterval(profile)
	if (not profile or type(profile.initial_samples) ~= "table") then return nil, 0; end
	if (table.getn(profile.initial_samples) <= 0) then return profile.initial_interval, 0; end

	local currentInterval = DebuffFilter_BucketInitialSpellInterval(profile.initial_interval);
	local best, second = DebuffFilter_FindBestInitialIntervalGroups(profile.initial_samples, currentInterval);
	if (not best) then return currentInterval, 0; end

	local locked = profile.initial_interval_locked == "yes";
	if (currentInterval == nil) then
		currentInterval = best.interval;
		profile.initial_interval = currentInterval;
	end

	if (not locked) then
		profile.initial_interval = best.interval;
		currentInterval = best.interval;
		local secondCount = second and second.directCount or 0;
		if (best.directCount >= 5 and best.directCount >= secondCount + 2) then
			profile.initial_interval_locked = "yes";
			profile.initial_candidate_interval = nil;
			profile.initial_candidate_confirm = 0;
		end
		profile.initial_confidence = math.min(10, best.directCount);
		return profile.initial_interval, profile.initial_confidence;
	end

	local currentInfo = DebuffFilter_EvaluateInitialIntervalCandidate(profile.initial_samples, currentInterval);
	local currentCount = currentInfo and currentInfo.directCount or 0;
	if (DebuffFilter_IsSameInitialIntervalGroup(best.interval, currentInterval)) then
		profile.initial_candidate_interval = nil;
		profile.initial_candidate_confirm = 0;
		profile.initial_confidence = math.min(10, currentCount);
		return currentInterval, profile.initial_confidence;
	end

	local qualifies = best.directCount >= 5 and best.directCount >= currentCount + 2;
	if (qualifies) then
		if (DebuffFilter_IsSameInitialIntervalGroup(profile.initial_candidate_interval, best.interval)) then
			profile.initial_candidate_confirm = (tonumber(profile.initial_candidate_confirm) or 0) + 1;
		else
			profile.initial_candidate_interval = best.interval;
			profile.initial_candidate_confirm = 1;
		end
		if ((tonumber(profile.initial_candidate_confirm) or 0) >= 2) then
			profile.initial_interval = best.interval;
			profile.initial_interval_locked = "yes";
			profile.initial_candidate_interval = nil;
			profile.initial_candidate_confirm = 0;
			profile.initial_confidence = math.min(10, best.directCount);
			return profile.initial_interval, profile.initial_confidence;
		end
	else
		profile.initial_candidate_interval = nil;
		profile.initial_candidate_confirm = 0;
	end

	profile.initial_interval = currentInterval;
	profile.initial_confidence = math.min(10, currentCount);
	return profile.initial_interval, profile.initial_confidence;
end

local function DebuffFilter_TouchMonsterSpellProfile(config, profile)
	if (not config or not profile) then return; end
	local seq = (tonumber(config["target_spell_access_seq"]) or 0) + 1;
	config["target_spell_access_seq"] = seq;
	profile.last_seen_seq = seq;
end

local function DebuffFilter_GetMaxSavedMonsterSpellProfiles(config)
	local value = math.floor(tonumber(config and config["target_spell_max_saved_profiles"]) or tonumber(DebuffFilter.targetSpellMaxSavedProfiles) or 1000);
	if (value < 1) then value = 1; end
	if (value > 10000) then value = 10000; end
	return value;
end

-- SavedVariables硬上限由管理窗口配置，默认1000个“怪物名字 + 技能ID”组合。
-- 超出后删除最久没有实际记录施法的条目，防止文件无限增长。
local function DebuffFilter_TrimSavedMonsterSpellProfiles(config)
	if (not config or type(config["target_spell_monsters"]) ~= "table") then return; end
	local entries = {};
	for monsterName, spellTable in config["target_spell_monsters"] do
		if (type(spellTable) == "table") then
			for spellKey, profile in spellTable do
				if (type(profile) == "table") then
					table.insert(entries, {
						monsterName = monsterName,
						spellKey = spellKey,
						seq = tonumber(profile.last_seen_seq) or 0,
					});
				end
			end
		end
	end

	local count = table.getn(entries);
	local maxProfiles = DebuffFilter_GetMaxSavedMonsterSpellProfiles(config);
	if (count <= maxProfiles) then return; end
	table.sort(entries, function(a, b)
		if (a.seq == b.seq) then
			return tostring(a.monsterName) .. tostring(a.spellKey) < tostring(b.monsterName) .. tostring(b.spellKey);
		end
		return a.seq < b.seq;
	end);

	local removeCount = count - maxProfiles;
	for i = 1, removeCount, 1 do
		local entry = entries[i];
		local spellTable = config["target_spell_monsters"][entry.monsterName];
		if (type(spellTable) == "table") then
			spellTable[entry.spellKey] = nil;
			if (not next(spellTable)) then
				config["target_spell_monsters"][entry.monsterName] = nil;
			end
		end
	end
end

local function DebuffFilter_GetMonsterSpellProfile(config, monsterName, spellKey, create)
	if (not config or not monsterName or monsterName == "" or not spellKey) then return nil; end
	config["target_spell_monsters"] = config["target_spell_monsters"] or {};
	local monsterData = config["target_spell_monsters"][monsterName];
	if (type(monsterData) ~= "table" and create) then
		monsterData = {};
		config["target_spell_monsters"][monsterName] = monsterData;
	end
	if (type(monsterData) ~= "table") then return nil; end

	local profile = monsterData[spellKey];
	local created = false;
	if (type(profile) ~= "table" and create) then
		profile = {
			interval=nil,
			interval_locked="no",
			candidate_interval=nil,
			candidate_confirm=0,
			confidence=0,
			samples={},
			timing_mode=DebuffFilter.targetSpellTimingMode,
			initial_interval=nil,
			initial_interval_locked="no",
			initial_candidate_interval=nil,
			initial_candidate_confirm=0,
			initial_confidence=0,
			initial_samples={},
			initial_timing_mode=DebuffFilter.targetSpellInitialTimingMode,
			last_seen_seq=0,
		};
		monsterData[spellKey] = profile;
		created = true;
	end
	if (type(profile) ~= "table") then return nil; end

	-- v1.9.1成功START到成功START的数据与新口径兼容，可以继续作为历史样本。
	-- v1.9.0完成到下一次开始少算读条时间，必须清空重学。
	if (profile.timing_mode == "CAST_END_TO_NEXT_START" or not DebuffFilter_IsCompatibleSpellTimingMode(profile.timing_mode)) then
		profile.interval = nil;
		profile.interval_locked = "no";
		profile.candidate_interval = nil;
		profile.candidate_confirm = 0;
		profile.confidence = 0;
		profile.samples = {};
	end
	profile.timing_mode = DebuffFilter.targetSpellTimingMode;
	if (type(profile.samples) ~= "table") then profile.samples = {}; end
	profile.interval = DebuffFilter_BucketSpellInterval(profile.interval);
	if (profile.interval_locked ~= "yes" and profile.interval_locked ~= "no") then
		-- 旧版本已经存在的正式周期直接视为锁定值，避免升级后立即跳动。
		profile.interval_locked = profile.interval and "yes" or "no";
	end
	profile.candidate_interval = DebuffFilter_BucketSpellInterval(profile.candidate_interval);
	profile.candidate_confirm = tonumber(profile.candidate_confirm) or 0;
	profile.confidence = tonumber(profile.confidence) or 0;

	if (profile.initial_timing_mode ~= nil and profile.initial_timing_mode ~= DebuffFilter.targetSpellInitialTimingMode) then
		profile.initial_interval = nil;
		profile.initial_interval_locked = "no";
		profile.initial_candidate_interval = nil;
		profile.initial_candidate_confirm = 0;
		profile.initial_confidence = 0;
		profile.initial_samples = {};
	end
	profile.initial_timing_mode = DebuffFilter.targetSpellInitialTimingMode;
	if (type(profile.initial_samples) ~= "table") then profile.initial_samples = {}; end
	profile.initial_interval = DebuffFilter_BucketInitialSpellInterval(profile.initial_interval);
	if (profile.initial_interval_locked ~= "yes" and profile.initial_interval_locked ~= "no") then
		profile.initial_interval_locked = profile.initial_interval ~= nil and "yes" or "no";
	end
	profile.initial_candidate_interval = DebuffFilter_BucketInitialSpellInterval(profile.initial_candidate_interval);
	profile.initial_candidate_confirm = tonumber(profile.initial_candidate_confirm) or 0;
	profile.initial_confidence = tonumber(profile.initial_confidence) or 0;
	profile.last_seen_seq = tonumber(profile.last_seen_seq) or 0;

	if (created) then
		DebuffFilter_TouchMonsterSpellProfile(config, profile);
		DebuffFilter_TrimSavedMonsterSpellProfiles(config);
	end
	return profile;
end

local function DebuffFilter_AddSpellIntervalSample(config, monsterName, spellKey, interval)
	local bucket = DebuffFilter_BucketSpellInterval(interval);
	if (not bucket or bucket < 0.5 or bucket > 600) then return nil, 0, 0; end

	local profile = DebuffFilter_GetMonsterSpellProfile(config, monsterName, spellKey, true);
	if (not profile) then return nil, 0, 0; end
	local samples = profile.samples;

	table.insert(samples, bucket);
	while (table.getn(samples) > DebuffFilter.targetSpellMaxSamples) do
		table.remove(samples, 1);
	end

	local selected, confidence = DebuffFilter_UpdateLockedSpellInterval(profile);
	if (selected) then profile.interval = selected; end
	profile.confidence = confidence or 0;
	DebuffFilter_TouchMonsterSpellProfile(config, profile);
	return profile.interval, table.getn(samples), profile.confidence;
end


local function DebuffFilter_AddInitialSpellIntervalSample(config, monsterName, spellKey, interval)
	local bucket = DebuffFilter_BucketInitialSpellInterval(interval);
	if (bucket == nil) then return nil, 0, 0; end
	local profile = DebuffFilter_GetMonsterSpellProfile(config, monsterName, spellKey, true);
	if (not profile) then return nil, 0, 0; end
	local samples = profile.initial_samples;
	table.insert(samples, bucket);
	while (table.getn(samples) > DebuffFilter.targetSpellMaxSamples) do
		table.remove(samples, 1);
	end
	local selected, confidence = DebuffFilter_UpdateLockedInitialInterval(profile);
	if (selected ~= nil) then profile.initial_interval = selected; end
	profile.initial_confidence = confidence or 0;
	DebuffFilter_TouchMonsterSpellProfile(config, profile);
	return profile.initial_interval, table.getn(samples), profile.initial_confidence;
end

-- 判断单位是否处于战斗状态。只有亲眼观察到“非战斗 -> 战斗”转换，才学习首轮时间。
local function DebuffFilter_IsUnitInCombat(unit)
	if (not unit or not UnitExists(unit) or type(UnitAffectingCombat) ~= "function") then return false; end
	local ok, value = pcall(UnitAffectingCombat, unit);
	return ok and value and true or false;
end

local function DebuffFilter_StartObservedMonsterCombat(runtime, config, monsterName, now)
	if (not runtime) then return; end
	runtime.combatState = true;
	runtime.combatObserved = true;
	runtime.combatStartedAt = now;
	runtime.lastSeen = now;

	for spellKey, state in runtime.skills do
		local profile = DebuffFilter_GetMonsterSpellProfile(config, monsterName, spellKey, false);
		if (state and profile) then
			state.cycleInterval = tonumber(profile.interval);
			state.initialInterval = DebuffFilter_BucketInitialSpellInterval(profile.initial_interval);
			state.initialConfidence = tonumber(profile.initial_confidence) or 0;
			state.initialSampleCount = type(profile.initial_samples) == "table" and table.getn(profile.initial_samples) or 0;
			state.firstCastSeenInCombat = false;
			state.lastObservedStart = nil;
			state.pendingStart = nil;
			state.casting = false;
			state.readyBeforeCast = false;
			if (state.initialInterval ~= nil) then
				state.interval = state.initialInterval;
				state.castTime = now;
				state.timerMode = "initial";
			else
				state.interval = nil;
				state.castTime = nil;
				state.timerMode = "initial_learning";
			end
		end
	end
end

local function DebuffFilter_EndObservedMonsterCombat(runtime, config, monsterName, now)
	if (not runtime) then return; end
	runtime.combatState = false;
	runtime.combatObserved = false;
	runtime.combatStartedAt = nil;
	runtime.lastSeen = now;
	for spellKey, state in runtime.skills do
		local profile = DebuffFilter_GetMonsterSpellProfile(config, monsterName, spellKey, false);
		if (state) then
			state.cycleInterval = profile and tonumber(profile.interval) or state.cycleInterval;
			state.initialInterval = profile and DebuffFilter_BucketInitialSpellInterval(profile.initial_interval) or state.initialInterval;
			state.interval = state.cycleInterval;
			state.castTime = nil;
			state.lastObservedStart = nil;
			state.pendingStart = nil;
			state.casting = false;
			state.firstCastSeenInCombat = false;
			state.readyBeforeCast = true;
			state.timerMode = "ready";
		end
	end
end

local function DebuffFilter_UpdateTargetSpellCombatState(runtime, config, monsterName, unit)
	if (not runtime) then return; end
	local now = GetTime();
	local inCombat = DebuffFilter_IsUnitInCombat(unit);
	if (runtime.combatState == nil) then
		-- 第一次看到目标时只建立基线。若它已经在战斗中，不猜测开战时间。
		runtime.combatState = inCombat;
		runtime.combatObserved = false;
		runtime.combatStartedAt = nil;
		return;
	end
	if (not runtime.combatState and inCombat) then
		DebuffFilter_StartObservedMonsterCombat(runtime, config, monsterName, now);
	elseif (runtime.combatState and not inCombat) then
		DebuffFilter_EndObservedMonsterCombat(runtime, config, monsterName, now);
	end
end

-- 将SavedVariables中“同名怪物 + 技能ID”的已学习技能装入当前GUID临时状态。
-- 非战斗时显示0.0就绪；亲眼观察到进战斗后，同一图标先显示首轮倒计时，再切换循环倒计时。
local function DebuffFilter_LoadSavedMonsterSkillsIntoRuntime(config, runtime, monsterName)
	if (not config or not runtime or not monsterName or monsterName == "") then return false; end
	local allMonsters = config["target_spell_monsters"];
	local monsterData = type(allMonsters) == "table" and allMonsters[monsterName] or nil;
	if (type(monsterData) ~= "table") then return false; end

	local spellKeys = {};
	for spellKey, profile in monsterData do
		if (type(profile) == "table" and not DebuffFilter_IsTargetSpellBlacklisted(spellKey)) then
			table.insert(spellKeys, tostring(spellKey));
		end
	end
	table.sort(spellKeys, function(a, b)
		local na = tonumber(a);
		local nb = tonumber(b);
		if (na and nb) then return na < nb; end
		return tostring(a) < tostring(b);
	end);

	local found = false;
	for _, spellKey in spellKeys do
		local profile = DebuffFilter_GetMonsterSpellProfile(config, monsterName, spellKey, false);
		if (profile) then
			found = true;
			local cycleInterval = tonumber(profile.interval);
			local initialInterval = DebuffFilter_BucketInitialSpellInterval(profile.initial_interval);
			local state = runtime.skills[spellKey];
			if (not state) then
				runtime.order = (runtime.order or 0) + 1;
				state = {
					castTime = nil,
					lastObservedStart = nil,
					pendingStart = nil,
					casting = false,
					interval = cycleInterval,
					cycleInterval = cycleInterval,
					initialInterval = initialInterval,
					confidence = tonumber(profile.confidence) or 0,
					sampleCount = type(profile.samples) == "table" and table.getn(profile.samples) or 0,
					initialConfidence = tonumber(profile.initial_confidence) or 0,
					initialSampleCount = type(profile.initial_samples) == "table" and table.getn(profile.initial_samples) or 0,
					monsterName = monsterName,
					order = runtime.order,
					readyBeforeCast = true,
					timerMode = "ready",
					firstCastSeenInCombat = false,
				};
				if (runtime.combatObserved and runtime.combatState and runtime.combatStartedAt) then
					state.readyBeforeCast = false;
					if (initialInterval ~= nil) then
						state.interval = initialInterval;
						state.castTime = runtime.combatStartedAt;
						state.timerMode = "initial";
					else
						state.interval = nil;
						state.castTime = nil;
						state.timerMode = "initial_learning";
					end
				end
				runtime.skills[spellKey] = state;
			else
				state.cycleInterval = cycleInterval;
				state.initialInterval = initialInterval;
				state.sampleCount = type(profile.samples) == "table" and table.getn(profile.samples) or 0;
				state.confidence = tonumber(profile.confidence) or state.confidence or 0;
				state.initialSampleCount = type(profile.initial_samples) == "table" and table.getn(profile.initial_samples) or 0;
				state.initialConfidence = tonumber(profile.initial_confidence) or state.initialConfidence or 0;
				state.monsterName = monsterName;
				-- 只更新资料，不覆盖正在运行的首轮或循环倒计时。
				if (state.timerMode == "ready" or state.timerMode == nil) then
					state.interval = cycleInterval;
					state.readyBeforeCast = true;
					state.timerMode = "ready";
				end
			end
		end
	end
	return found;
end

-- 从可见姓名板取得单位GUID。SuperWoW只在姓名板框体的GetName(1)返回附着单位GUID；
-- 对其他WorldFrame子框取得的普通名字会被UnitExists校验过滤掉。
local function DebuffFilter_GetNameplateUnitGUID(frame)
	if (not frame or type(frame.GetName) ~= "function") then return nil; end
	if (type(frame.IsShown) == "function") then
		local shownOK, shown = pcall(frame.IsShown, frame);
		if (not shownOK or not shown) then return nil; end
	end
	local ok, guid = pcall(frame.GetName, frame, 1);
	if (not ok or not guid or guid == "") then return nil; end
	local existsOK, exists = pcall(UnitExists, guid);
	if (not existsOK or not exists) then return nil; end
	return tostring(guid);
end

-- 后台观察所有可见姓名板怪物的战斗转换。
-- 姓名板未开启时，附近怪物的施法仍会由UNIT_CASTEVENT后台记录；只是无法提前学习它的开战首轮时间。
local function DebuffFilter_ScanNearbyMonsterCombat()
	if (not DebuffFilter_IsTargetSpellMonitoringEnabled()) then return; end
	if (not WorldFrame or type(WorldFrame.GetChildren) ~= "function") then return; end
	local config = DebuffFilter_Config and DebuffFilter_Config[DebuffFilter_Player];
	if (not config) then return; end

	local children = { WorldFrame:GetChildren() };
	local childCount = table.getn(children);
	local now = GetTime();
	for i = 1, childCount, 1 do
		local guid = DebuffFilter_GetNameplateUnitGUID(children[i]);
		if (guid and DebuffFilter_IsHostileNPCUnit(guid)) then
			if (DebuffFilter_IsUnitDead(guid)) then
				DebuffFilter_ClearTargetSpellRuntime(guid);
			else
				local monsterName = DebuffFilter_GetMonsterNameFromUnit(guid);
				if (monsterName) then
					local runtime = DebuffFilter_GetTargetSpellRuntime(guid, true, monsterName);
					DebuffFilter_LoadSavedMonsterSkillsIntoRuntime(config, runtime, monsterName);
					DebuffFilter_UpdateTargetSpellCombatState(runtime, config, monsterName, guid);
					runtime.lastSeen = now;
				end
			end
		end
	end
	DebuffFilter_CleanupTargetSpellRuntime();
end

-- 右键整理当前“怪物名字 + 技能ID”的后台样本。
-- 按自适应模型确认当前基础周期，只保留直接属于该周期组的样本；倍数、延迟和短重试全部清除。
function DebuffFilter_CleanTargetSpellSamples(state)
	if (not state or not state.monsterName or not state.spellID) then
		DebuffFilter_Print("无法整理：当前技能资料不完整。");
		return;
	end

	local config = DebuffFilter_Config and DebuffFilter_Config[DebuffFilter_Player];
	if (not config) then return; end
	local monsterName = DebuffFilter_NormalizeName(state.monsterName);
	local spellKey = tostring(state.spellID);
	local profile = DebuffFilter_GetMonsterSpellProfile(config, monsterName, spellKey, false);
	if (not profile or type(profile.samples) ~= "table" or table.getn(profile.samples) <= 0) then
		DebuffFilter_Print("没有可整理的周期样本：" .. tostring(monsterName) .. " / " .. tostring(state.name or ("技能 #" .. spellKey)));
		return;
	end

	local selected = DebuffFilter_SelectAdaptiveSpellInterval(profile.samples, profile.interval);
	selected = DebuffFilter_BucketSpellInterval(selected or profile.interval);
	if (not selected) then
		DebuffFilter_Print("没有找到有效的主要周期记录。");
		return;
	end

	local tolerance = DebuffFilter_GetSpellIntervalTolerance(selected);
	local oldCount = table.getn(profile.samples);
	local kept = {};
	for _, sample in profile.samples do
		local bucket = DebuffFilter_BucketSpellInterval(sample);
		if (bucket and math.abs(bucket - selected) <= tolerance) then
			-- 归一成唯一周期，避免4.5/5.0这类同组记录继续分散。
			table.insert(kept, selected);
		end
	end

	if (table.getn(kept) <= 0) then
		DebuffFilter_Print("当前没有可直接保留的主要周期样本。");
		return;
	end

	profile.samples = kept;
	profile.interval = selected;
	profile.interval_locked = "yes";
	profile.candidate_interval = nil;
	profile.candidate_confirm = 0;
	profile.confidence = math.min(10, table.getn(kept));
	DebuffFilter_TouchMonsterSpellProfile(config, profile);
	local keptCount = table.getn(kept);
	local removedCount = oldCount - keptCount;

	-- 同步本次登录内所有同名怪物的相同技能状态，不重置当前倒计时起点。
	for guid, runtime in DebuffFilter.targetSpellRuntime do
		if (runtime and runtime.monsterName == monsterName and runtime.skills) then
			local runtimeState = runtime.skills[spellKey];
			if (runtimeState) then
				runtimeState.cycleInterval = selected;
				if (runtimeState.timerMode == "cycle") then runtimeState.interval = selected; end
				runtimeState.confidence = profile.confidence;
				runtimeState.sampleCount = keptCount;
			end
		end
	end
	state.cycleInterval = selected;
	if (state.timerMode == "cycle") then state.interval = selected; end
	state.confidence = profile.confidence;
	state.sampleCount = keptCount;

	DebuffFilter_TargetSpellFrame_Update();
	DebuffFilter_Print("已整理 " .. tostring(monsterName) .. " / " .. tostring(state.name or ("技能 #" .. spellKey))
		.. "：保留 " .. tostring(keptCount) .. " 条 " .. string.format("%.1f", selected)
		.. " 秒主周期记录，清除 " .. tostring(removedCount) .. " 条延迟、倍数或重试记录。");
end

-- Ctrl+左键删除当前“怪物名字 + 技能ID”的全部记录。
-- 只删除当前怪物对应技能，不影响其他怪物即使使用相同技能ID时的独立周期资料。
function DebuffFilter_DeleteTargetSpellRecord(state)
	if (not state or not state.monsterName or not state.spellID) then
		DebuffFilter_Print("无法删除：当前技能资料不完整。");
		return;
	end

	local config = DebuffFilter_Config and DebuffFilter_Config[DebuffFilter_Player];
	if (not config) then return; end

	local monsterName = DebuffFilter_NormalizeName(state.monsterName);
	local spellKey = tostring(state.spellID);
	local skillName = tostring(state.name or ("技能 #" .. spellKey));
	local removedSaved = false;
	local allMonsters = config["target_spell_monsters"];
	if (type(allMonsters) == "table") then
		local monsterData = allMonsters[monsterName];
		if (type(monsterData) == "table" and monsterData[spellKey] ~= nil) then
			monsterData[spellKey] = nil;
			removedSaved = true;
			if (not next(monsterData)) then
				allMonsters[monsterName] = nil;
			end
		end
	end

	-- 清除本次登录中所有同名怪物GUID下的该技能状态，防止切目标后又恢复旧倒计时。
	local removedRuntime = 0;
	for guid, runtime in DebuffFilter.targetSpellRuntime do
		if (runtime and runtime.monsterName == monsterName and type(runtime.skills) == "table" and runtime.skills[spellKey]) then
			runtime.skills[spellKey] = nil;
			removedRuntime = removedRuntime + 1;
		end
	end

	-- 图标信息只是临时缓存；一并清除，未来重新学习时重新读取真实技能信息。
	DebuffFilter.targetSpellDisplayCache[spellKey] = nil;
	GameTooltip:Hide();
	DebuffFilter_TargetSpellFrame_Update();

	if (removedSaved or removedRuntime > 0) then
		DebuffFilter_Print("已删除 " .. tostring(monsterName) .. " / " .. skillName
			.. " 的全部记录：首轮时间、循环周期、两套最近10条样本和本次登录临时倒计时均已清除。");
	else
		DebuffFilter_Print("没有找到可删除的记录：" .. tostring(monsterName) .. " / " .. skillName .. "。");
	end
end

local function DebuffFilter_GetTargetSpellDisplayState(runtime, spellKey)
	if (not runtime or not runtime.skills) then return nil; end
	local state = runtime.skills[spellKey];
	if (not state) then return nil; end

	local cached = DebuffFilter.targetSpellDisplayCache[spellKey];
	if (not cached) then
		local numericID = tonumber(spellKey) or spellKey;
		local spellName, spellIcon = DebuffFilter_GetSpellDisplayInfo(numericID);
		cached = { spellID=numericID, name=spellName, icon=spellIcon };
		DebuffFilter.targetSpellDisplayCache[spellKey] = cached;
	end
	state.spellID = cached.spellID;
	state.name = cached.name;
	state.icon = cached.icon;
	state.monsterName = runtime.monsterName;
	return state;
end

function DebuffFilter_TargetSpellFrame_Update()
	local frame = getglobal("DebuffFilter_TargetSpellFrame");
	if (not frame) then return; end

	if (not DebuffFilter_IsTargetSpellMonitoringEnabled()) then
		DebuffFilter.targetSpellCurrentGUID = nil;
		DebuffFilter_HideTargetSpellButtons();
		return;
	end

	-- 当前选中的怪物死亡：删除该GUID临时状态并隐藏。
	if (DebuffFilter_IsCurrentTargetDeadMonster()) then
		local deadGUID = DebuffFilter_GetUnitKey("target") or DebuffFilter.targetSpellCurrentGUID;
		DebuffFilter_ClearTargetSpellRuntime(deadGUID);
		return;
	end

	-- 切目标、无目标、友方或玩家目标：只隐藏，不删除其他怪物的临时GUID状态。
	if (not DebuffFilter_IsValidTargetMonster()) then
		DebuffFilter.targetSpellCurrentGUID = nil;
		DebuffFilter_HideTargetSpellButtons();
		return;
	end

	local targetGUID = DebuffFilter_GetUnitKey("target");
	if (not targetGUID) then
		DebuffFilter.targetSpellCurrentGUID = nil;
		DebuffFilter_HideTargetSpellButtons();
		return;
	end
	targetGUID = tostring(targetGUID);
	DebuffFilter.targetSpellCurrentGUID = targetGUID;
	local targetMonsterName = DebuffFilter_GetCurrentTargetMonsterName();
	local config = DebuffFilter_Config and DebuffFilter_Config[DebuffFilter_Player];
	if (not config or not targetMonsterName) then
		DebuffFilter_HideTargetSpellButtons();
		return;
	end

	-- 当前有效怪物始终建立临时GUID状态，才能亲眼观察“非战斗 -> 战斗”的准确时刻。
	local runtime = DebuffFilter_GetTargetSpellRuntime(targetGUID, true, targetMonsterName);
	local savedMonsterData = config["target_spell_monsters"] and config["target_spell_monsters"][targetMonsterName];
	if (type(savedMonsterData) == "table") then
		DebuffFilter_LoadSavedMonsterSkillsIntoRuntime(config, runtime, targetMonsterName);
	end
	DebuffFilter_UpdateTargetSpellCombatState(runtime, config, targetMonsterName, "target");
	if (not runtime or not runtime.skills) then
		DebuffFilter_HideTargetSpellButtons();
		return;
	end
	runtime.lastSeen = GetTime();

	local visibleStates = {};
	for spellKey, active in runtime.skills do
		if (not DebuffFilter_IsTargetSpellBlacklisted(spellKey)
			and active and (active.castTime or active.readyBeforeCast or active.timerMode == "initial_learning")) then
			local state = DebuffFilter_GetTargetSpellDisplayState(runtime, spellKey);
			if (state) then table.insert(visibleStates, state); end
		end
	end

	table.sort(visibleStates, function(a, b)
		return (tonumber(a.order) or 999999) < (tonumber(b.order) or 999999);
	end);

	local shown = math.min(table.getn(visibleStates), 16);
	for i = 0, 15, 1 do
		local buttonName = "DebuffFilter_TargetSpellButton" .. i;
		local button = getglobal(buttonName);
		local state = visibleStates[i + 1];
		if (state and i < shown) then
			local remaining = DebuffFilter_GetTargetSpellRemaining(state);
			button.spellState = state;
			getglobal(buttonName .. "Icon"):SetTexture(state.icon);
			local text = getglobal(buttonName .. "Interval");
			if (state.timerMode == "initial_learning") then
				-- 已知技能但尚未学会“开战到首次施法”时间，只显示首轮学习状态。
				DebuffFilter_SetUIFont(text, 9, "OUTLINE");
				text:SetTextColor(0.3, 0.85, 1);
				text:SetText("首轮中");
			elseif (state.readyBeforeCast and not state.castTime) then
				DebuffFilter_SetUIFont(text, 11, "OUTLINE");
				text:SetTextColor(1, 0.1, 0.1);
				text:SetText("0.0");
			elseif (state.interval ~= nil and remaining ~= nil) then
				DebuffFilter_SetUIFont(text, 11, "OUTLINE");
				if (remaining <= 0) then
					text:SetTextColor(1, 0.1, 0.1);
					text:SetText("0.0");
				elseif (state.timerMode == "initial") then
					-- 蓝色：进战斗后的首次技能倒计时。
					text:SetTextColor(0.3, 0.85, 1);
					text:SetText(string.format("%.1f", remaining));
				else
					-- 金色：技能使用后的循环倒计时。
					text:SetTextColor(1, 0.82, 0);
					text:SetText(string.format("%.1f", remaining));
				end
			else
				-- 新技能第一次施法后，只显示循环周期学习状态。
				DebuffFilter_SetUIFont(text, 9, "OUTLINE");
				text:SetTextColor(0.3, 0.85, 1);
				text:SetText("学习中");
			end
			button:Show();
		else
			button.spellState = nil;
			getglobal(buttonName .. "Interval"):SetText("");
			button:Hide();
		end
	end

	local backdrop = getglobal("DebuffFilter_TargetSpellFrameBackdrop");
	if (backdrop) then
		if (DebuffFilter.backdrop == 1) then backdrop:Show(); else backdrop:Hide(); end
	end
	if (shown > 0 or DebuffFilter.backdrop == 1) then frame:Show(); else frame:Hide(); end
end

-- 兼容不同 SuperWoW / SuperWoWhook 版本的施法状态文本。
-- 标准状态仍是 START / CAST / FAIL；这里只把常见变体统一后再进入学习逻辑。
local function DebuffFilter_NormalizeTargetCastState(rawState)
	if (rawState == nil) then return nil; end
	local state = string.upper(tostring(rawState));
	if (string.find(state, "FAIL") or string.find(state, "INTERRUPT")) then
		return "FAIL";
	end
	if (string.find(state, "START") or state == "CHANNEL" or state == "CHANNELING") then
		return "START";
	end
	if (state == "CAST" or state == "SUCCESS" or state == "STOP" or state == "CHANNEL_STOP") then
		return "CAST";
	end
	return state;
end

-- 某些客户端环境中，UNIT_CASTEVENT 的施法者GUID与 UnitExists 返回值格式可能不同。
-- 优先直接比较GUID，再尝试 SuperWoW 支持的 UnitIsUnit(GUID, unit) 比较。
local function DebuffFilter_IsSameUnitReference(unit, casterGUID)
	if (not unit or not casterGUID or not UnitExists(unit)) then return false; end
	local unitGUID = DebuffFilter_GetUnitKey(unit);
	if (unitGUID and tostring(unitGUID) == tostring(casterGUID)) then return true; end
	if (type(UnitIsUnit) == "function") then
		local ok, same = pcall(UnitIsUnit, unit, casterGUID);
		if (ok and same) then return true; end
		ok, same = pcall(UnitIsUnit, casterGUID, unit);
		if (ok and same) then return true; end
	end
	return false;
end

-- 标准 SuperWoW 把技能ID放在 arg4。少数版本或兼容层可能把它后移，
-- 因此仅在 arg4 无法解析时，从后续参数中寻找能够查到技能名称的有效ID。
local function DebuffFilter_ResolveCastEventSpellID()
	local candidates = { arg4, arg5, arg6, arg7 };
	for _, rawValue in candidates do
		local numericID = tonumber(rawValue);
		if (numericID and numericID > 0) then
			local valid = false;
			if (type(GetSpellRecField) == "function") then
				local ok, name = pcall(GetSpellRecField, numericID, "name");
				if (ok and name and name ~= "") then valid = true; end
			end
			if (not valid and type(SpellInfo) == "function") then
				local ok, name = pcall(SpellInfo, numericID);
				if (ok and name and name ~= "") then valid = true; end
			end
			if (valid) then return numericID; end
		end
	end
	return tonumber(arg4) or arg4;
end

-- 目标技能双阶段学习与显示：
-- 1. 亲眼观察非战斗 -> 战斗后，记录开战到该技能第一次START的首轮时间。
-- 2. 同一GUID、同一技能相邻两次START形成循环周期，读条时间自然包含在内。
-- CAST：有START时只表示读条完成；没有START时按瞬发技能的开始点处理。
-- FAIL：不撤销START触发的循环倒计时，也不删除该开始点；短时间重试由智能模型降权。
-- 首轮和循环各自滚动保留最近10条样本，共用一个技能图标。
local function DebuffFilter_PrintTargetCastDebug()
	if (not DebuffFilter.targetSpellCastDebug) then return; end
	local targetGUID = DebuffFilter_GetUnitKey("target");
	DEFAULT_CHAT_FRAME:AddMessage(
		"|cff66ccffDF施法事件|r state=" .. tostring(arg3) ..
		" caster=" .. tostring(arg1) ..
		" casterName=" .. tostring(DebuffFilter_GetMonsterNameFromUnit(arg1)) ..
		" targetGUID=" .. tostring(targetGUID) ..
		" a4=" .. tostring(arg4) ..
		" a5=" .. tostring(arg5) ..
		" a6=" .. tostring(arg6) ..
		" a7=" .. tostring(arg7)
	);
end

local function DebuffFilter_RecordTargetSpellCast()
	DebuffFilter_PrintTargetCastDebug();
	if (not DebuffFilter_IsTargetSpellMonitoringEnabled()) then return; end

	local castState = DebuffFilter_NormalizeTargetCastState(arg3);
	if (castState ~= "START" and castState ~= "CAST" and castState ~= "FAIL") then return; end

	local casterGUID = arg1 and tostring(arg1) or nil;
	if (not casterGUID) then return; end

	local currentTargetGUID = nil;
	local currentMonsterName = nil;
	if (DebuffFilter_IsValidTargetMonster()) then
		local key = DebuffFilter_GetUnitKey("target");
		if (key) then currentTargetGUID = tostring(key); end
		currentMonsterName = DebuffFilter_GetCurrentTargetMonsterName();
	end

	local isCurrentTarget = currentTargetGUID and DebuffFilter_IsSameUnitReference("target", casterGUID);
	local runtimeGUID = isCurrentTarget and currentTargetGUID or casterGUID;

	-- 不再只接受当前目标。SuperWoW的UNIT_CASTEVENT会提供周围施法者GUID，
	-- 只要它是敌对NPC，就为该GUID建立独立后台状态。
	if (not DebuffFilter_IsHostileNPCUnit(runtimeGUID)) then return; end
	local monsterName = isCurrentTarget and currentMonsterName or DebuffFilter_GetMonsterNameFromUnit(runtimeGUID);
	monsterName = DebuffFilter_NormalizeName(monsterName);
	if (not monsterName or monsterName == "") then return; end

	-- 保留v1.14.4的性能顺序：先确认敌对NPC，再解析技能ID。
	-- 黑名单命中后不建立怪物runtime、不加载学习资料、不创建图标/计时。
	local spellID = DebuffFilter_ResolveCastEventSpellID();
	local spellKey = spellID and tostring(spellID) or nil;
	if (spellKey and DebuffFilter_IsTargetSpellBlacklisted(spellKey)) then return; end

	local runtime = DebuffFilter_GetTargetSpellRuntime(runtimeGUID, true, monsterName);
	if (not runtime) then return; end
	runtime.monsterName = monsterName;

	local now = GetTime();
	local config = DebuffFilter_Config and DebuffFilter_Config[DebuffFilter_Player];
	if (not config) then return; end
	DebuffFilter_LoadSavedMonsterSkillsIntoRuntime(config, runtime, monsterName);
	-- START本身可能正好触发进战斗；GUID可直接作为Unit参数。
	DebuffFilter_UpdateTargetSpellCombatState(runtime, config, monsterName, isCurrentTarget and "target" or runtimeGUID);
	DebuffFilter_CleanupTargetSpellRuntime();

	-- 某些FAIL事件没有技能ID：只结束当前读条标记，倒计时和最近START基准都保留。
	if (castState == "FAIL" and not spellKey) then
		for _, failState in runtime.skills do
			if (failState and failState.casting) then
				failState.pendingStart = nil;
				failState.casting = false;
			end
		end
		runtime.lastSeen = now;
		if (isCurrentTarget) then DebuffFilter_TargetSpellFrame_Update(); end
		return;
	end
	if (not spellKey) then return; end

	-- 第一次看到技能ID就建立SavedVariables条目，未来同名怪物进入战斗即可预读首轮和循环时间。
	local profile = DebuffFilter_GetMonsterSpellProfile(config, monsterName, spellKey, true);
	if (not profile) then return; end
	local learnedInterval = tonumber(profile.interval);
	local initialInterval = DebuffFilter_BucketInitialSpellInterval(profile.initial_interval);
	local sampleCount = type(profile.samples) == "table" and table.getn(profile.samples) or 0;
	local initialSampleCount = type(profile.initial_samples) == "table" and table.getn(profile.initial_samples) or 0;

	local state = runtime.skills[spellKey];
	if (not state) then
		runtime.order = (runtime.order or 0) + 1;
		state = {
			castTime = nil,
			lastObservedStart = nil,
			pendingStart = nil,
			casting = false,
			interval = learnedInterval,
			cycleInterval = learnedInterval,
			initialInterval = initialInterval,
			confidence = tonumber(profile.confidence) or 0,
			sampleCount = sampleCount,
			initialConfidence = tonumber(profile.initial_confidence) or 0,
			initialSampleCount = initialSampleCount,
			monsterName = monsterName,
			order = runtime.order,
			readyBeforeCast = false,
			timerMode = "cycle",
			firstCastSeenInCombat = false,
		};
		runtime.skills[spellKey] = state;
	else
		state.cycleInterval = learnedInterval;
		state.initialInterval = initialInterval;
		state.confidence = tonumber(profile.confidence) or state.confidence or 0;
		state.sampleCount = sampleCount;
		state.initialConfidence = tonumber(profile.initial_confidence) or state.initialConfidence or 0;
		state.initialSampleCount = initialSampleCount;
		state.monsterName = monsterName;
	end

	local observedStart = false;
	if (castState == "START") then
		-- 过滤同一事件的极短重复通知，避免产生0秒循环样本或重复重置倒计时。
		if (not state.lastObservedStart or now - state.lastObservedStart >= 0.25) then observedStart = true; end
	elseif (castState == "CAST") then
		if (state.casting and state.pendingStart) then
			-- 正常读条完成：START已经负责记录、切换阶段和启动循环倒计时。
			state.pendingStart = nil;
			state.casting = false;
		else
			-- 瞬发技能或客户端漏发START：CAST本身作为开始点。
			if (not state.lastObservedStart or now - state.lastObservedStart >= 0.25) then observedStart = true; end
		end
	elseif (castState == "FAIL") then
		-- 打断/失败不撤销已经开始的循环倒计时，也不删除START基准。
		state.pendingStart = nil;
		state.casting = false;
		runtime.lastSeen = now;
	end

	if (observedStart) then
		local anySampleStored = false;

		-- 第一套逻辑：只有亲眼观察到当前GUID由非战斗进入战斗，才记录“开战 -> 首次START”。
		if (runtime.combatObserved and runtime.combatStartedAt and not state.firstCastSeenInCombat) then
			local firstDelay = now - runtime.combatStartedAt;
			if (firstDelay < 0) then firstDelay = 0; end
			local selectedInitial, initialCount, initialConfidence = DebuffFilter_AddInitialSpellIntervalSample(config, monsterName, spellKey, firstDelay);
			state.initialInterval = selectedInitial;
			state.initialSampleCount = initialCount or state.initialSampleCount or 0;
			state.initialConfidence = initialConfidence or state.initialConfidence or 0;
			state.firstCastSeenInCombat = true;
			anySampleStored = true;
		end

		-- 第二套逻辑：同一GUID、同一技能相邻两次START形成完整循环周期，读条时间包含在内。
		local previousStart = state.lastObservedStart;
		if (previousStart) then
			local measuredInterval = now - previousStart;
			if (measuredInterval >= 0.5 and measuredInterval <= 600) then
				local selected, count, confidence = DebuffFilter_AddSpellIntervalSample(config, monsterName, spellKey, measuredInterval);
				learnedInterval = selected or learnedInterval;
				sampleCount = count or sampleCount;
				state.confidence = confidence or state.confidence or 0;
				anySampleStored = true;
			end
		end
		if (not anySampleStored) then
			DebuffFilter_TouchMonsterSpellProfile(config, profile);
		end

		state.lastObservedStart = now;
		state.pendingStart = castState == "START" and now or nil;
		state.casting = castState == "START";
		state.castTime = now;
		state.cycleInterval = learnedInterval or tonumber(profile.interval);
		state.interval = state.cycleInterval;
		state.sampleCount = sampleCount;
		state.readyBeforeCast = false;
		state.timerMode = "cycle";
		runtime.lastSeen = now;
	end

	if (isCurrentTarget) then
		DebuffFilter.targetSpellCurrentGUID = runtimeGUID;
		DebuffFilter_TargetSpellFrame_Update();
	end
end

function DebuffFilter_CreateDebuffFrame()
	if (getglobal("DebuffFilter_DebuffFrame")) then
		return;
	end

	local frame = CreateFrame("Frame", "DebuffFilter_DebuffFrame", DebuffFilterFrame);
	frame:SetWidth(30);
	frame:SetHeight(30);
	-- 默认位置由 pfUI/原生分支锚点决定；实际框体仍可独立拖动。
	frame:SetPoint("CENTER", "DebuffFilter_DebuffDefaultAnchor", "CENTER", 0, 0);
	frame:SetMovable(1);

	local count = frame:CreateFontString("DebuffFilter_DebuffFrameCount", "OVERLAY", "GameFontNormal");
	count:SetWidth(30);
	count:SetHeight(12);
	count:SetPoint("RIGHT", frame, "LEFT", 0, 0);
	count:Hide();

	local backdrop = CreateFrame("Button", "DebuffFilter_DebuffFrameBackdrop", frame, "DebuffFilter_BackdropTemplate");
	backdrop:SetPoint("CENTER", frame, "CENTER", 0, 0);
	backdrop:Hide();

	local label = backdrop:CreateFontString(nil, "ARTWORK", "GameFontNormal");
	label:SetWidth(90);
	label:SetHeight(12);
	label:SetPoint("TOP", backdrop, "TOP", 0, 15);
	label:SetText("目标减益");

	for i = 0, 31, 1 do
		local name = "DebuffFilter_DebuffButton" .. i;
		local button = CreateFrame("Button", name, frame, "DebuffFilter_BuffButtonTemplate");
		button:SetID(i);
		button.filterType = "debuff";
		button:Hide();
		button:SetScript("OnUpdate", nil);
		button:SetScript("OnEnter", DebuffFilter_DebuffButton_OnEnter);

		if (i == 0) then
			button:SetPoint("LEFT", frame, "LEFT", 0, 0);
		else
			button:SetPoint("LEFT", "DebuffFilter_DebuffButton" .. (i - 1), "RIGHT", 4, 0);
		end
	end
end

function DebuffFilter_Target_OnUpdate(elapsed)
	-- WoW 1.12 的 SetScript 回调通常通过全局 arg1 传入帧间隔，
	-- 不一定会把 elapsed 作为函数参数传入。两种方式都兼容。
	elapsed = tonumber(elapsed) or tonumber(arg1) or 0;

	-- 无 pfUI：保留 v1.9.7.7 目标 Debuff 快捷添加。
	-- 有 pfUI：跳过目标 Debuff，只周期维护 pfUI 自身 Buff 按钮挂接。
	DebuffFilter_CheckTargetDebuffCtrlClick();

	DebuffFilter.targetDebuffHookUpdate = DebuffFilter.targetDebuffHookUpdate + elapsed;
	if (DebuffFilter.targetDebuffHookUpdate >= 1.0) then
		DebuffFilter.targetDebuffHookUpdate = 0;
		if (DebuffFilter_IsPfUIActive()) then
			DebuffFilter_HookPfBuffButtons();
		else
			DebuffFilter_HookSystemTargetDebuffButtons();
		end
	end

	if (not DebuffFilter_Config or not DebuffFilter_Player or not DebuffFilter_Config[DebuffFilter_Player]) then
		return;
	end

	DebuffFilter.comboUpdate = DebuffFilter.comboUpdate + elapsed;
	if (DebuffFilter.comboUpdate >= 0.05) then
		DebuffFilter.comboUpdate = 0;
		local targetKey = DebuffFilter_GetUnitKey("target");
		if (targetKey and type(GetComboPoints) == "function") then
			local cp = GetComboPoints() or 0;
			if (cp > 0) then
				DebuffFilter.lastComboPoints = cp;
				DebuffFilter.lastComboTarget = targetKey;
				DebuffFilter.lastComboTime = GetTime();
			end
		end
	end

	DebuffFilter.targetUpdate = DebuffFilter.targetUpdate + elapsed;
	if (DebuffFilter.targetUpdate >= 0.2) then
		DebuffFilter.targetUpdate = 0;
		DebuffFilter_DebuffFrame_Update();
	end

	-- 技能监测关闭时彻底停掉姓名板扫描与技能框10Hz刷新，而不是每次进来再做一次“空返回/Hide”。
	if (DebuffFilter_IsTargetSpellMonitoringEnabled()) then
		DebuffFilter.targetSpellNearbyScanUpdate = DebuffFilter.targetSpellNearbyScanUpdate + elapsed;
		if (DebuffFilter.targetSpellNearbyScanUpdate >= 0.5) then
			DebuffFilter.targetSpellNearbyScanUpdate = 0;
			DebuffFilter_ScanNearbyMonsterCombat();
		end

		DebuffFilter.targetSpellUpdate = DebuffFilter.targetSpellUpdate + elapsed;
		if (DebuffFilter.targetSpellUpdate >= 0.1) then
			DebuffFilter.targetSpellUpdate = 0;
			DebuffFilter_TargetSpellFrame_Update();
		end
	else
		DebuffFilter.targetSpellNearbyScanUpdate = 0;
		DebuffFilter.targetSpellUpdate = 0;
	end

	DebuffFilter.timerTextUpdate = DebuffFilter.timerTextUpdate + elapsed;
	if (DebuffFilter.timerTextUpdate >= 0.1) then
		DebuffFilter.timerTextUpdate = 0;
		for i = 0, 31, 1 do
			local buttonName = "DebuffFilter_DebuffButton" .. i;
			local button = getglobal(buttonName);
			if (button and button:IsVisible()) then
				local timerText = getglobal(buttonName .. "Duration");
				if (button.timerEnd and DebuffFilter_Config[DebuffFilter_Player]["debuff_timers"] ~= "no") then
					local remaining = button.timerEnd - GetTime();
					if (remaining <= 11) then
						timerText:SetTextColor(1, 0, 0);
					else
						timerText:SetTextColor(1, 0.82, 0);
					end
					timerText:SetText(DebuffFilter_FormatRemaining(remaining));
				else
					timerText:SetText("");
				end
			end
		end
	end
end

local function DebuffFilter_Initialize()
	DebuffFilter_UpdateDefaultAnchors();
	DebuffFilter_CreateDebuffFrame();
	DebuffFilter_CreateTargetSpellFrame();
	if (DebuffFilter_IsPfUIActive()) then
		DebuffFilter_HookPfBuffButtons();
	else
		DebuffFilter_HookSystemTargetDebuffButtons();
	end

	if (not DebuffFilter_Config) then
		DebuffFilter_Config = {};
	end

	if (not DebuffFilter_Config[DebuffFilter_Player]) then
		DebuffFilter_Config[DebuffFilter_Player] = {};
	end

	for key, defaultValue in DebuffFilter_DefaultSettings do
		if (DebuffFilter_Config[DebuffFilter_Player][key] == nil) then
			DebuffFilter_Config[DebuffFilter_Player][key] = DebuffFilter_CopyTable(defaultValue);
		end
	end


	local configuredMaxProfiles = math.floor(tonumber(DebuffFilter_Config[DebuffFilter_Player]["target_spell_max_saved_profiles"]) or 1000);
	if (configuredMaxProfiles < 1) then configuredMaxProfiles = 1; end
	if (configuredMaxProfiles > 10000) then configuredMaxProfiles = 10000; end
	DebuffFilter_Config[DebuffFilter_Player]["target_spell_max_saved_profiles"] = configuredMaxProfiles;
	DebuffFilter.targetSpellMaxSavedProfiles = configuredMaxProfiles;

	-- 统一已有配置中的不可见字符，避免“看起来同名、实际字符串不同”。
	local normalizedDebuffs = {};
	for configuredName, enabled in DebuffFilter_Config[DebuffFilter_Player]["debuff_list"] do
		local normalizedName = DebuffFilter_NormalizeName(configuredName);
		if (normalizedName and normalizedName ~= "") then
			normalizedDebuffs[normalizedName] = enabled;
		end
	end
	DebuffFilter_Config[DebuffFilter_Player]["debuff_list"] = normalizedDebuffs;

	local normalizedTimes = {};
	for configuredName, seconds in DebuffFilter_Config[DebuffFilter_Player]["debuff_timer_custom"] do
		local normalizedName = DebuffFilter_NormalizeName(configuredName);
		if (normalizedName and normalizedName ~= "") then
			normalizedTimes[normalizedName] = seconds;
		end
	end
	DebuffFilter_Config[DebuffFilter_Player]["debuff_timer_custom"] = normalizedTimes;

	-- 目标技能学习数据按“怪物名字 -> 技能ID”保存。
	-- 循环周期保留v1.9.2后的START到START自适应样本；新增首轮“进战斗到首次START”独立样本。
	-- 两套数据各自最多10条，旧版本没有首轮字段时保持为空，进入战斗后逐步学习。
	local normalizedMonsters = {};
	local oldMonsters = DebuffFilter_Config[DebuffFilter_Player]["target_spell_monsters"];
	if (type(oldMonsters) == "table") then
		for rawMonsterName, spellTable in oldMonsters do
			local monsterName = DebuffFilter_NormalizeName(rawMonsterName);
			if (monsterName and monsterName ~= "" and type(spellTable) == "table") then
				local cleanSpells = {};
				for spellID, profile in spellTable do
					local numericID = tonumber(spellID);
					if (numericID and type(profile) == "table") then
						local cleanSamples = {};
						local storedInterval = nil;
						local compatibleTiming = DebuffFilter_IsCompatibleSpellTimingMode(profile.timing_mode);
						if (compatibleTiming) then
							if (type(profile.samples) == "table") then
								for _, seconds in profile.samples do
									local bucket = DebuffFilter_BucketSpellInterval(seconds);
									if (bucket and bucket >= 0.5 and bucket <= 600) then
										table.insert(cleanSamples, bucket);
										while (table.getn(cleanSamples) > DebuffFilter.targetSpellMaxSamples) do
											table.remove(cleanSamples, 1);
										end
									end
								end
							end
							storedInterval = DebuffFilter_BucketSpellInterval(profile.interval);
							if (table.getn(cleanSamples) > 0) then
								storedInterval = DebuffFilter_SelectAdaptiveSpellInterval(cleanSamples, storedInterval);
							end
						end
						local selectedInterval = storedInterval;
						local confidence = tonumber(profile.confidence) or 0;
						if (not selectedInterval and table.getn(cleanSamples) > 0) then
							selectedInterval, confidence = DebuffFilter_SelectAdaptiveSpellInterval(cleanSamples, nil);
						end

						local cleanInitialSamples = {};
						local storedInitial = nil;
						local compatibleInitial = profile.initial_timing_mode == nil or profile.initial_timing_mode == DebuffFilter.targetSpellInitialTimingMode;
						if (compatibleInitial) then
							if (type(profile.initial_samples) == "table") then
								for _, seconds in profile.initial_samples do
									local bucket = DebuffFilter_BucketInitialSpellInterval(seconds);
									if (bucket ~= nil) then
										table.insert(cleanInitialSamples, bucket);
										while (table.getn(cleanInitialSamples) > DebuffFilter.targetSpellMaxSamples) do table.remove(cleanInitialSamples, 1); end
									end
								end
							end
							storedInitial = DebuffFilter_BucketInitialSpellInterval(profile.initial_interval);
						end
						local selectedInitial = storedInitial;
						local initialConfidence = tonumber(profile.initial_confidence) or 0;
						if (selectedInitial == nil and table.getn(cleanInitialSamples) > 0) then
							selectedInitial, initialConfidence = DebuffFilter_SelectAdaptiveInitialInterval(cleanInitialSamples, nil);
						end

						cleanSpells[tostring(numericID)] = {
							interval=selectedInterval or storedInterval,
							interval_locked=(profile.interval_locked == "no" and "no" or ((selectedInterval or storedInterval) and "yes" or "no")),
							candidate_interval=DebuffFilter_BucketSpellInterval(profile.candidate_interval),
							candidate_confirm=tonumber(profile.candidate_confirm) or 0,
							confidence=confidence or tonumber(profile.confidence) or 0,
							samples=cleanSamples,
							timing_mode=DebuffFilter.targetSpellTimingMode,
							initial_interval=selectedInitial,
							initial_interval_locked=(profile.initial_interval_locked == "no" and "no" or (selectedInitial ~= nil and "yes" or "no")),
							initial_candidate_interval=DebuffFilter_BucketInitialSpellInterval(profile.initial_candidate_interval),
							initial_candidate_confirm=tonumber(profile.initial_candidate_confirm) or 0,
							initial_confidence=initialConfidence or tonumber(profile.initial_confidence) or 0,
							initial_samples=cleanInitialSamples,
							initial_timing_mode=DebuffFilter.targetSpellInitialTimingMode,
							last_seen_seq=tonumber(profile.last_seen_seq) or 0,
						};
					end
				end
				if (next(cleanSpells)) then normalizedMonsters[monsterName] = cleanSpells; end
			end
		end
	end
	DebuffFilter_Config[DebuffFilter_Player]["target_spell_monsters"] = normalizedMonsters;

	-- 统一敌人技能黑名单格式：始终按技能ID字符串保存，并保留技能名供设置页搜索。
	local normalizedBlacklist = {};
	local oldBlacklist = DebuffFilter_Config[DebuffFilter_Player]["target_spell_blacklist"];
	if (type(oldBlacklist) == "table") then
		for rawSpellID, entry in oldBlacklist do
			local numericID = tonumber(rawSpellID);
			if (numericID) then
				local spellKey = tostring(numericID);
				local spellName = type(entry) == "table" and entry.name or nil;
				if (not spellName or spellName == "") then
					spellName = DebuffFilter_GetSpellDisplayInfo(numericID);
				end
				normalizedBlacklist[spellKey] = { spellID=numericID, name=spellName or ("技能 #" .. spellKey) };
			end
		end
	end
	DebuffFilter_Config[DebuffFilter_Player]["target_spell_blacklist"] = normalizedBlacklist;

	DebuffFilter_Config[DebuffFilter_Player]["target_spell_access_seq"] = tonumber(DebuffFilter_Config[DebuffFilter_Player]["target_spell_access_seq"]) or 0;
	DebuffFilter_TrimSavedMonsterSpellProfiles(DebuffFilter_Config[DebuffFilter_Player]);
	-- 清除v1.8.5及更早的技能ID全局表，避免同一技能在不同怪物之间误用时间。
	DebuffFilter_Config[DebuffFilter_Player]["target_spell_samples"] = nil;
	DebuffFilter_Config[DebuffFilter_Player]["target_spell_intervals"] = nil;

	if (DebuffFilter_Config[DebuffFilter_Player]["target_spell_monitoring"] ~= "no") then
		DebuffFilter_Config[DebuffFilter_Player]["target_spell_monitoring"] = "yes";
	end

	local announceChannel = DebuffFilter_Config[DebuffFilter_Player]["target_spell_announce_channel"];
	if (announceChannel ~= "SAY" and announceChannel ~= "PARTY" and announceChannel ~= "RAID" and announceChannel ~= "GUILD") then
		DebuffFilter_Config[DebuffFilter_Player]["target_spell_announce_channel"] = "SAY";
	end

	for i in DebuffFilter.Frames do
		local frame = DebuffFilter.Frames[i]["frame"];
		local orient_key = DebuffFilter.Frames[i]["orient_key"];

		if (DebuffFilter_Config[DebuffFilter_Player][i] == "no") then
			getglobal(frame):Hide();
		end

		DebuffFilter_FrameOrientation(DebuffFilter_Config[DebuffFilter_Player][orient_key], frame);
	end

	DebuffFilter_TimeOrientation(DebuffFilter_Config[DebuffFilter_Player]["time_orientation"]);

	SlashCmdList["DFILTER"] = DebuffFilter_command;
	SLASH_DFILTER1 = "/dfilter";
	SLASH_DFILTER2 = "/dfui";
end

function DebuffFilter_OnMouseDown(arg1)
	if (arg1 == "LeftButton" and IsShiftKeyDown()) then
		this.DebuffFilterDragging = 1;
		this:GetParent():StartMoving();
	elseif (arg1 == "RightButton" and IsShiftKeyDown()) then
		local frame, name, orient_key, orientation, time_orientation;
		
		frame = this:GetParent():GetName();

		for i in DebuffFilter.Frames do
			if (DebuffFilter.Frames[i]["frame"] == frame) then
				name = DebuffFilter.Frames[i]["name"];
				orient_key = DebuffFilter.Frames[i]["orient_key"];
				orientation = DebuffFilter_Config[DebuffFilter_Player][orient_key];
				break;
			end
		end

		-- 自身 Debuff 与目标技能移动框没有方向切换配置；Shift+右键直接忽略。
		if (not orient_key or not orientation) then return; end

		for i in DebuffFilter.FrameOrientation do
			if (i == orientation) then
				local next_orient = DebuffFilter.FrameOrientation[i]["next_orient"];

				DebuffFilter_Config[DebuffFilter_Player][orient_key] = next_orient;
				DebuffFilter_FrameOrientation(next_orient, frame);
				DebuffFilter_Print(name .. " orientation: " .. DebuffFilter.FrameOrientation[i]["next_orient"]);

				time_orientation = DebuffFilter.FrameOrientation[i]["next_time"];

				break;
			end
		end

		if (frame == "DebuffFilter_BuffFrame") then
			DebuffFilter_Config[DebuffFilter_Player]["time_orientation"] = time_orientation;
			DebuffFilter_TimeOrientation(time_orientation);
		end

	elseif (arg1 == "RightButton" and IsControlKeyDown()) then
		if (this:GetParent():GetName() == "DebuffFilter_BuffFrame") then
			local time_orientation = DebuffFilter_Config[DebuffFilter_Player]["time_orientation"];

			local next_time = DebuffFilter.TimeOrientation[time_orientation]["next_time"];
			DebuffFilter_Config[DebuffFilter_Player]["time_orientation"] = next_time;
			DebuffFilter_TimeOrientation(next_time);
			DebuffFilter_Print("buff time orientation: " .. next_time);
		end
	elseif (arg1 == "LeftButton" and IsControlKeyDown()) then
		local filterName = this.filterName;
		if (filterName) then
			if (this.filterType == "debuff") then
				DebuffFilter_command("ddel " .. filterName);
			else
				DebuffFilter_command("del " .. filterName);
			end
		end
	end
end

function DebuffFilter_OnMouseUp(arg1)
	if (arg1 == "LeftButton" and this.DebuffFilterDragging) then
		this:GetParent():StopMovingOrSizing();
		this.DebuffFilterDragging = nil;
	end
end

function DebuffFilter_OnLoad()
	DebuffFilter_Player = (UnitName("player").." - "..GetRealmName());
	this:RegisterEvent("VARIABLES_LOADED");
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	this:RegisterEvent("PLAYER_AURAS_CHANGED");
	this:RegisterEvent("UNIT_AURA");
	this:RegisterEvent("PLAYER_TARGET_CHANGED");
	this:RegisterEvent("UNIT_HEALTH");
	this:RegisterEvent("UNIT_CASTEVENT");
	local exists, guid = UnitExists("player");
	if (exists and guid) then DebuffFilter.playerGUID = tostring(guid); end
	this:SetScript("OnUpdate", function() DebuffFilter_Target_OnUpdate(arg1); end);
end

function DebuffFilter_BuffFrame_Update()
	if (DebuffFilter_Config[DebuffFilter_Player]["buffs"] == "no") then
		return;
	end

	local count = 0;
	local width = 0;

	for i = 0, 31, 1 do
		local name = "DebuffFilter_BuffButton" .. i;
		local button = getglobal(name);
		local buffindex, untilcancelled = GetPlayerBuff(i, "HELPFUL");
		local bufftext = getglobal(name .. "Count");
		local bufftime = getglobal(name .. "Duration");
		
		if (buffindex >= 0) then
			count = count + 1;
			DebuffFilter_BuffFrameCount:SetText(count);

			DebuffFilter_Tooltip:ClearLines();
			DebuffFilter_Tooltip:SetPlayerBuff(buffindex);

			if (DebuffFilter_Config[DebuffFilter_Player]["buff_list"][DebuffFilter_TooltipTextLeft1:GetText()] == 1) then
				button.filterType = "buff";
				button.filterName = DebuffFilter_TooltipTextLeft1:GetText();
				getglobal(name .. "Icon"):SetTexture(GetPlayerBuffTexture(buffindex));

				local buffapplications = GetPlayerBuffApplications(buffindex);
				local bufftimeleft = GetPlayerBuffTimeLeft(buffindex);

				if (buffapplications > 1) then
					bufftext:SetText(buffapplications);
				else
					bufftext:SetText("");
				end

				if (untilcancelled ~= 1) then
					if (11 >= bufftimeleft) then
						bufftime:SetTextColor(1, 0, 0);
					else
						bufftime:SetTextColor(1, 0.82, 0);
					end

					bufftime:SetText(SecondsToTimeAbbrev(bufftimeleft));
				else
					bufftime:SetText("N/A");
				end

				button:SetWidth(30);
				button:SetHeight(30);
				button:Show();

				width = width + 1;

				if (DebuffFilter_Config[DebuffFilter_Player]["count"] == "yes") then
					DebuffFilter_BuffFrameCount:Show();
				end
			else
				button.filterName = nil;
				button:Hide();
				bufftext:SetText("");
				bufftime:SetText("");
				button:SetWidth(-4);
				button:SetHeight(-4);
			end
		else
			button.filterName = nil;
			button:Hide();
			bufftext:SetText("");
			bufftime:SetText("");
			button:SetWidth(-4);
			button:SetHeight(-4);
		end
	end

	if (width == 0) then
		DebuffFilter_BuffFrameCount:Hide();
	end
end


function DebuffFilter_DebuffFrame_Update()
	if (not DebuffFilter_Config or not DebuffFilter_Config[DebuffFilter_Player]) then
		return;
	end

	if (DebuffFilter_Config[DebuffFilter_Player]["debuffs"] == "no") then
		return;
	end

	local shown = 0;
	local count = 0;
	local targetKey = DebuffFilter_GetUnitKey("target");
	DebuffFilter.currentTargetKey = targetKey;

	if (targetKey and UnitExists("target") and not UnitIsDead("target")) then
		if (not DebuffFilter.targetStates[targetKey]) then
			DebuffFilter.targetStates[targetKey] = {};
		end
		if (not DebuffFilter.targetTimers[targetKey]) then
			DebuffFilter.targetTimers[targetKey] = {};
		end

		local targetState = DebuffFilter.targetStates[targetKey];
		local targetTimers = DebuffFilter.targetTimers[targetKey];
		local seen = {};

		for i = 1, 32, 1 do
			local texture, applications, dispelType, auraID = UnitDebuff("target", i);
			if (not texture) then
				break;
			end

			DebuffFilter_Tooltip:SetOwner(UIParent, "ANCHOR_NONE");
			DebuffFilter_Tooltip:ClearLines();
			DebuffFilter_Tooltip:SetUnitDebuff("target", i);

			local rawDebuffName = DebuffFilter_TooltipTextLeft1:GetText();
			local debuffName = DebuffFilter_NormalizeName(rawDebuffName);
			if (debuffName and debuffName ~= "") then
				local stacks = tonumber(applications) or 0;
				local old = targetState[debuffName];
				local pending = DebuffFilter_GetPendingCast(targetKey, debuffName, auraID);
				local comboPoints = pending and pending.comboPoints or DebuffFilter_GetRecentComboPoints(targetKey);

				-- 首次发现开始计时；叠层发生变化时重新计算；
				-- SuperWoW 捕获到同技能再次施放时，即使层数不变也刷新。
				if (not old) then
					DebuffFilter_StartDebuffTimer(targetKey, debuffName, comboPoints, "first-seen");
				elseif (old.stacks ~= stacks) then
					DebuffFilter_StartDebuffTimer(targetKey, debuffName, comboPoints, "stack-change");
				elseif (pending) then
					DebuffFilter_StartDebuffTimer(targetKey, debuffName, comboPoints, "recast");
				end

				targetState[debuffName] = {
					stacks = stacks,
					auraID = auraID,
					lastSeen = GetTime(),
				};
				seen[debuffName] = 1;

				local configuredName = DebuffFilter_FindConfiguredName(DebuffFilter_Config[DebuffFilter_Player]["debuff_list"], debuffName);
				local sourceAllowed = (not DebuffFilter_IsOnlyMineAurasEnabled()) or DebuffFilter_IsTargetDebuffMine(targetKey, debuffName, auraID);
				if (configuredName and sourceAllowed and DebuffFilter_Config[DebuffFilter_Player]["debuff_list"][configuredName] == 1 and shown < 32) then
					local buttonName = "DebuffFilter_DebuffButton" .. shown;
					local button = getglobal(buttonName);
					local debufftext = getglobal(buttonName .. "Count");
					local debufftime = getglobal(buttonName .. "Duration");

					button.debuffIndex = i;
					button.filterType = "debuff";
					button.filterName = debuffName;
					button.auraID = auraID;
					getglobal(buttonName .. "Icon"):SetTexture(texture);
					getglobal(buttonName .. "Icon"):SetAlpha(1);

					if (stacks > 1) then
						debufftext:SetText(stacks);
					else
						debufftext:SetText("");
					end

					local timer = targetTimers[debuffName];
					if (timer and DebuffFilter_Config[DebuffFilter_Player]["debuff_timers"] ~= "no") then
						button.timerEnd = timer.endTime;
						local remaining = timer.endTime - GetTime();
						if (remaining <= 11) then
							debufftime:SetTextColor(1, 0, 0);
						else
							debufftime:SetTextColor(1, 0.82, 0);
						end
						debufftime:SetText(DebuffFilter_FormatRemaining(remaining));
					else
						button.timerEnd = nil;
						debufftime:SetText("");
					end

					button:SetWidth(30);
					button:SetHeight(30);
					button:Show();

					shown = shown + 1;
					count = count + 1;
				end
			end
		end

		-- 当前目标身上已经消失的 Debuff 立即清理，不让预测时间继续跑。
		for debuffName in targetState do
			if (not seen[debuffName]) then
				targetState[debuffName] = nil;
				targetTimers[debuffName] = nil;
			end
		end
	end

	for i = shown, 31, 1 do
		local buttonName = "DebuffFilter_DebuffButton" .. i;
		local button = getglobal(buttonName);
		button.debuffIndex = nil;
		button.filterName = nil;
		button.auraID = nil;
		button.timerEnd = nil;
		button:Hide();
		getglobal(buttonName .. "Count"):SetText("");
		getglobal(buttonName .. "Duration"):SetText("");
		button:SetWidth(-4);
		button:SetHeight(-4);
	end

	DebuffFilter_DebuffFrameCount:SetText(count);
	if (count > 0 and DebuffFilter_Config[DebuffFilter_Player]["count"] == "yes") then
		DebuffFilter_DebuffFrameCount:Show();
	else
		DebuffFilter_DebuffFrameCount:Hide();
	end
end

function DebuffFilter_OnEvent(event)
	if (event == "VARIABLES_LOADED") then
		this:UnregisterEvent("VARIABLES_LOADED");
		DebuffFilter_UpdateDefaultAnchors();
		DebuffFilter_Initialize();
	elseif (event == "PLAYER_ENTERING_WORLD") then
		this:UnregisterEvent("PLAYER_ENTERING_WORLD");
		if (DebuffFilter_IsPfUIActive()) then
			DebuffFilter_HookPfBuffButtons();
		else
			DebuffFilter_HookSystemTargetDebuffButtons();
		end
		DebuffFilterFrame:SetScale(DebuffFilter_Config[DebuffFilter_Player]["scale"] * UIParent:GetScale());
			DebuffFilter_BuffFrame_Update();
		DebuffFilter_DebuffFrame_Update();
		DebuffFilter_ResetTargetSpellScreenForTarget();
	elseif (event == "PLAYER_AURAS_CHANGED") then
		DebuffFilter_BuffFrame_Update();
	elseif (event == "UNIT_AURA") then
		DebuffFilter_DebuffFrame_Update();
	elseif (event == "PLAYER_TARGET_CHANGED") then
		DebuffFilter_DebuffFrame_Update();
		-- 切换目标时只切换当前显示。相同临时GUID的状态仍保存在内存，切回后自动恢复。
		DebuffFilter_TargetSpellFrame_Update();
	elseif (event == "UNIT_HEALTH") then
		if (arg1 == "target" and DebuffFilter_IsCurrentTargetDeadMonster()) then
			local deadGUID = DebuffFilter_GetUnitKey("target") or DebuffFilter.targetSpellCurrentGUID;
			DebuffFilter_ClearTargetSpellRuntime(deadGUID);
		end
	elseif (event == "UNIT_CASTEVENT") then
		-- 两个昂贵分支先按总开关截断，避免“技能监测关闭”后仍解析周围所有施法事件。
		if (DebuffFilter_IsOnlyMineAurasEnabled()) then DebuffFilter_RecordTargetDebuffOwnerCast(); end
		DebuffFilter_RecordPlayerCast();
		if (DebuffFilter_IsTargetSpellMonitoringEnabled()) then DebuffFilter_RecordTargetSpellCast(); end
	end
end

function DebuffFilter_BuffButton_OnUpdate(elapsed)
	this.update = this.update + elapsed;
	if (this.update >= 1) then
		this.update = this.update - 1;
		local buffindex, untilcancelled = GetPlayerBuff(this:GetID(), "HELPFUL");
		local buffapplications = GetPlayerBuffApplications(buffindex);
		local bufftimeleft = GetPlayerBuffTimeLeft(buffindex);
		local bufftext = getglobal(this:GetName() .. "Count");
		local bufftime = getglobal(this:GetName() .. "Duration");

		if (buffapplications > 1) then
			bufftext:SetText(buffapplications);
		else
			bufftext:SetText("");
		end

		if (untilcancelled == 1) then
			bufftime:SetText("N/A");
			return;
		end

		if (11 >= bufftimeleft) then
			bufftime:SetTextColor(1, 0, 0);
		else
			bufftime:SetTextColor(1, 0.82, 0);
		end

		bufftime:SetText(SecondsToTimeAbbrev(bufftimeleft));
	end
end

function DebuffFilter_FrameOrientation(orientation, frame)
	local name, start, num, relnum, xtemp, ytemp, countframe, point, relpoint, x, y;

	for i in DebuffFilter.Frames do
		if (DebuffFilter.Frames[i]["frame"] == frame) then
			name = DebuffFilter.Frames[i]["button"];
			start = getglobal(name .. DebuffFilter.Frames[i]["start"]);
			num = DebuffFilter.Frames[i]["num"];
			relnum = DebuffFilter.Frames[i]["relnum"];
			xtemp = DebuffFilter.Frames[i]["x"];
			ytemp = DebuffFilter.Frames[i]["y"];

			break;
		end
	end

	countframe = getglobal(frame .. "Count");

	start:ClearAllPoints();
	countframe:ClearAllPoints();

	for i in DebuffFilter.FrameOrientation do
		if (i == orientation) then
			point, relpoint = DebuffFilter.FrameOrientation[i]["point"], DebuffFilter.FrameOrientation[i]["relpoint"];
			x, y = xtemp * DebuffFilter.FrameOrientation[i]["x"], ytemp * DebuffFilter.FrameOrientation[i]["y"];
			start:SetPoint(DebuffFilter.FrameOrientation[i]["point"], frame, DebuffFilter.FrameOrientation[i]["point"], 0, 0);
			countframe:SetPoint(relpoint, frame, point, 0, DebuffFilter.FrameOrientation[i]["count_y"]);

			break;
		end
	end

	for i = 2, 32, 1 do
		local button, relbutton;

		button = getglobal(name .. i-num);
		relbutton = name .. (i-relnum);
		
		button:ClearAllPoints();
		button:SetPoint(point, relbutton, relpoint, x, y);
	end
end

function DebuffFilter_TimeOrientation(orientation)
	for i = 0, 31, 1 do
		local name = "DebuffFilter_BuffButton" .. i;
		local bufftime = getglobal(name .. "Duration");

		bufftime:ClearAllPoints();

		if (orientation == "bottom") then
			bufftime:SetPoint("TOP", name, "BOTTOM", 0, 0);
		elseif (orientation == "top") then
			bufftime:SetPoint("BOTTOM", name, "TOP", 0, 2);
		elseif (orientation == "left") then
			bufftime:SetPoint("RIGHT", name, "LEFT", -4, 0);
		elseif (orientation == "right") then
			bufftime:SetPoint("LEFT", name, "RIGHT", 4, 0);
		end
	end
end

function DebuffFilter_Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Buff监视|r " .. msg);
end

-- 七个独立移动框统一显示/隐藏。
-- 只控制框体显示和 StartMoving/StopMovingOrSizing，不读取坐标。
function DebuffFilter_SetMoveFramesVisible(visible)
	-- 目标增益、多人增益与多人减益锚点均由 Lua 创建。
	-- 在显示移动框时主动创建，避免初始化事件顺序导致框体一直不存在。
	if (visible and type(DebuffFilter_CreateTargetBuffFrame) == "function") then
		DebuffFilter_CreateTargetBuffFrame();
	end
	if (visible and type(DebuffFilter_CreateCurrentTargetBuffFrame) == "function") then
		DebuffFilter_CreateCurrentTargetBuffFrame();
	end
	if (visible and type(DebuffFilter_CreateMultiTargetDebuffFrame) == "function") then
		DebuffFilter_CreateMultiTargetDebuffFrame();
	end
	local frameNames = {
		"DebuffFilter_BuffFrame",
		"DebuffFilter_PlayerDebuffFrame",
		"DebuffFilter_DebuffFrame",
		"DebuffFilter_TargetSpellFrame",
		"DebuffFilter_CurrentTargetBuffFrame",
		"DebuffFilter_TargetBuffFrame",
		"DebuffFilter_MultiTargetDebuffFrame",
	};
	for index = 1, table.getn(frameNames), 1 do
		local frame = getglobal(frameNames[index]);
		local backdrop = getglobal(frameNames[index] .. "Backdrop");
		if (backdrop) then
			if (visible) then backdrop:Show(); else backdrop:Hide(); end
		end
		if (visible and frame) then frame:Show(); end
	end
	if (visible and type(DebuffFilter_CurrentTargetBuffFrame_Update) == "function") then
		DebuffFilter_CurrentTargetBuffFrame_Update();
	end
	if (visible and type(DebuffFilter_TargetBuffFrame_Update) == "function") then
		DebuffFilter_TargetBuffFrame_Update();
	end
	if (visible and type(DebuffFilter_MultiTargetDebuffFrame_Update) == "function") then
		DebuffFilter_MultiTargetDebuffFrame_Update();
	end
end

function DebuffFilter_command(arg1)
	arg1 = arg1 or "";
	local cleanArg = string.gsub(arg1, "^%s+", "");
	cleanArg = string.gsub(cleanArg, "%s+$", "");
	local cleanLower = string.lower(cleanArg);

	-- 主程序直接处理窗口入口，确保 /dfilter 与 /dfui 始终是有效命令。
	if (cleanLower == "" or cleanLower == "ui" or cleanLower == "config" or cleanLower == "options") then
		if (DebuffFilter_Manager_Toggle) then
			DebuffFilter_Manager_Toggle();
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Buff监视：内置管理窗口尚未就绪，请执行 /reload 后重试。|r");
		end
		return;
	end

	local i, j, cmd, param = string.find(cleanArg, "^([^ ]+) (.+)$");
	if (not cmd) then
		cmd = arg1;
	end

	cmd = string.lower(cmd);

	if (cmd == "adddebuff") then cmd = "dadd"; end
	if (cmd == "deldebuff") then cmd = "ddel"; end
	if (cmd == "listdebuff") then cmd = "dlist"; end

	if (cmd == "castdebug") then
		DebuffFilter.targetSpellCastDebug = not DebuffFilter.targetSpellCastDebug;
		DebuffFilter_Print("目标技能施法事件调试：" .. (DebuffFilter.targetSpellCastDebug and "开启" or "关闭") .. "。");
		if (DebuffFilter.targetSpellCastDebug) then
			DebuffFilter_Print("请让目标怪物施放一次未发现的技能，再截图聊天栏中的 DF施法事件。测试后再次输入 /dfilter castdebug 关闭。");
		end
		return;
	elseif (cmd == "dscan") then
		if (not UnitExists("target")) then
			DebuffFilter_Print("当前没有目标。");
			return;
		end

		DebuffFilter_Print("当前目标 Debuff 扫描结果：");
		local found = 0;
		for scanIndex = 1, 16, 1 do
			local texture, stacks, dispelType, auraID = UnitDebuff("target", scanIndex);
			if (not texture) then
				break;
			end

			DebuffFilter_Tooltip:SetOwner(UIParent, "ANCHOR_NONE");
			DebuffFilter_Tooltip:ClearLines();
			DebuffFilter_Tooltip:SetUnitDebuff("target", scanIndex);
			local rawName = DebuffFilter_TooltipTextLeft1:GetText();
			local normalizedName = DebuffFilter_NormalizeName(rawName) or "未知";
			DEFAULT_CHAT_FRAME:AddMessage(scanIndex .. ". |cff00ccff[" .. normalizedName .. "]|r 层数=" .. (stacks or 0) .. " ID=" .. (auraID or "nil"));
			found = found + 1;
		end

		if (found == 0) then
			DebuffFilter_Print("接口没有扫描到任何目标 Debuff。");
		end
	elseif (cmd == "timers") then
		if (DebuffFilter_Config[DebuffFilter_Player]["debuff_timers"] == "yes") then
			DebuffFilter_Config[DebuffFilter_Player]["debuff_timers"] = "no";
			DebuffFilter_Print("目标 Debuff 倒计时已关闭。");
		else
			DebuffFilter_Config[DebuffFilter_Player]["debuff_timers"] = "yes";
			DebuffFilter_Print("目标 Debuff 倒计时已开启。");
		end
		DebuffFilter_DebuffFrame_Update();
	elseif (cmd == "dtime" and param) then
		local _, _, debuffName, seconds = string.find(param, "^(.+)%s+(%d+%.?%d*)$");
		debuffName = DebuffFilter_NormalizeName(debuffName);
		if (debuffName and seconds and tonumber(seconds) and tonumber(seconds) > 0) then
			DebuffFilter_Config[DebuffFilter_Player]["debuff_timer_custom"][debuffName] = tonumber(seconds);
			DebuffFilter_Print("已设置目标 Debuff 时间：|cff00ccff" .. debuffName .. "|r = " .. seconds .. " 秒");
		else
			DebuffFilter_Print("格式：/dfilter dtime Debuff名称 秒数");
		end
	elseif (cmd == "dtimeoff" and param) then
		param = DebuffFilter_NormalizeName(param);
		DebuffFilter_Config[DebuffFilter_Player]["debuff_timer_custom"][param] = nil;
		DebuffFilter_Print("已移除自定义时间：|cff00ccff" .. param .. "|r（恢复内置规则或不显示时间）");
	elseif (cmd == "dtimes") then
		DebuffFilter_Print("目标 Debuff 计时规则：");
		for debuffName, rule in DebuffFilter.DebuffRules do
			local custom = DebuffFilter_Config[DebuffFilter_Player]["debuff_timer_custom"][debuffName];
			local displayTime = custom or rule.base;
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff" .. debuffName .. "|r: " .. displayTime .. " 秒" .. (rule.combo and "（连击点动态）" or ""));
		end
		for debuffName, seconds in DebuffFilter_Config[DebuffFilter_Player]["debuff_timer_custom"] do
			if (not DebuffFilter.DebuffRules[debuffName]) then
				DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff" .. debuffName .. "|r: " .. seconds .. " 秒（自定义）");
			end
		end
	elseif (cmd == "buffs" or cmd == "debuffs") then
		if (DebuffFilter_Config[DebuffFilter_Player][cmd] == "yes") then
			DebuffFilter_Config[DebuffFilter_Player][cmd] = "no";
			getglobal(DebuffFilter.Frames[cmd]["frame"]):Hide();
			DebuffFilter_Print(DebuffFilter.Frames[cmd]["name"] .. " filtering disabled.");
		else
			DebuffFilter_Config[DebuffFilter_Player][cmd] = "yes";
			getglobal(DebuffFilter.Frames[cmd]["frame"]):Show();
			getglobal(DebuffFilter.Frames[cmd]["frame"] .. "_Update")();
			DebuffFilter_Print(DebuffFilter.Frames[cmd]["name"] .. " filtering enabled.");
		end
	elseif (cmd == "scale") then
		if tonumber(param) and (tonumber(param) >= 0.5) and (tonumber(param) <=3.0) then
			DebuffFilter_Config[DebuffFilter_Player]["scale"] = tonumber(param);
			DebuffFilterFrame:SetScale(DebuffFilter_Config[DebuffFilter_Player]["scale"] * UIParent:GetScale());
			DebuffFilter_Print("scale set to " .. DebuffFilter_Config[DebuffFilter_Player]["scale"] .. ".");
		else
			DebuffFilter_Print("please choose a number between 0.5 and 3.  Current scale: " .. DebuffFilter_Config[DebuffFilter_Player]["scale"] .. ".");
		end
	elseif (cmd == "backdrop") then
		if (DebuffFilter.backdrop == 1) then
			DebuffFilter.backdrop = 0;
			DebuffFilter_SetMoveFramesVisible(false);
			DebuffFilter_BuffFrame_Update();
			DebuffFilter_DebuffFrame_Update();
			if (type(DebuffFilter_CurrentTargetBuffFrame_Update) == "function") then DebuffFilter_CurrentTargetBuffFrame_Update(); end
			if (type(DebuffFilter_TargetBuffFrame_Update) == "function") then DebuffFilter_TargetBuffFrame_Update(); end
			DebuffFilter_TargetSpellFrame_Update();
			DebuffFilter_Print("now hiding backdrop.");
		else
			DebuffFilter.backdrop = 1;
			DebuffFilter_SetMoveFramesVisible(true);
			DebuffFilter_Print("now showing backdrop.");
		end
	elseif (cmd == "count") then
		if (DebuffFilter_Config[DebuffFilter_Player]["count"] == "yes") then
			DebuffFilter_Config[DebuffFilter_Player]["count"] = "no";
			for i in DebuffFilter.Frames do
				getglobal(DebuffFilter.Frames[i]["frame"] .. "Count"):Hide();
			end
			DebuffFilter_Print("no longer showing debuff/buff count.");
		else
			DebuffFilter_Config[DebuffFilter_Player]["count"] = "yes";
			DebuffFilter_Print("now showing debuff/buff count.");
		end
		if (type(DebuffFilter_CurrentTargetBuffFrame_Update) == "function") then DebuffFilter_CurrentTargetBuffFrame_Update(); end
	elseif (cmd == "tooltips") then
		if (DebuffFilter_Config[DebuffFilter_Player]["tooltips"] == "yes") then
			DebuffFilter_Config[DebuffFilter_Player]["tooltips"] = "no";
			DebuffFilter_Print("tooltips disabled.");
		else
			DebuffFilter_Config[DebuffFilter_Player]["tooltips"] = "yes";
			DebuffFilter_Print("tooltips enabled.");
		end
	elseif (cmd == "add" or cmd == "dadd") and param then
		if (cmd == "dadd") then param = DebuffFilter_NormalizeName(param); end
		for i in DebuffFilter.Frames do
			if (DebuffFilter.Frames[i]["add_cmd"] == cmd) then
				DebuffFilter_Config[DebuffFilter_Player][DebuffFilter.Frames[i]["list"]][param] = 1;
				getglobal(DebuffFilter.Frames[i]["frame"] .. "_Update")();
				DebuffFilter_Print("已监视" .. DebuffFilter.Frames[i]["name"] .. ": \"|cff00ccff" .. param .. "|r\"");

				break;
			end
		end
	elseif (cmd == "del" or cmd == "ddel") and param then
		if (cmd == "ddel") then param = DebuffFilter_NormalizeName(param); end
		for i in DebuffFilter.Frames do
			if (DebuffFilter.Frames[i]["del_cmd"] == cmd) then
				if (DebuffFilter_Config[DebuffFilter_Player][DebuffFilter.Frames[i]["list"]][param]) then
					DebuffFilter_Config[DebuffFilter_Player][DebuffFilter.Frames[i]["list"]][param] = nil;
					getglobal(DebuffFilter.Frames[i]["frame"] .. "_Update")();
					DebuffFilter_Print("不再监视" .. DebuffFilter.Frames[i]["name"] .. ": \"|cff00ccff" .. param .. "|r\"");
				else
					DebuffFilter_Print("未发现 " .. DebuffFilter.Frames[i]["name"] .. ": \"|cff00ccff" .. param .. "|r\"");
				end

				break;
			end
		end
	elseif (cmd == "list" or cmd == "dlist") then
		for i in DebuffFilter.Frames do
			if (DebuffFilter.Frames[i]["list_cmd"] == cmd) then
				DebuffFilter_Print("currently monitored " .. DebuffFilter.Frames[i]["name"] .. "s:");
				for ii in DebuffFilter_Config[DebuffFilter_Player][DebuffFilter.Frames[i]["list"]] do
					DEFAULT_CHAT_FRAME:AddMessage("\"|cff00ccff" .. ii .. "|r\"");
				end

				break;
			end
		end
	elseif (cmd == "reset") then
		if (StaticPopup_Show and StaticPopupDialogs and StaticPopupDialogs["DEBUFF_FILTER_RESET_CONFIRM"]) then
			StaticPopup_Show("DEBUFF_FILTER_RESET_CONFIRM");
		elseif (type(DebuffFilter_ResetCurrentCharacter) == "function") then
			DebuffFilter_ResetCurrentCharacter();
		end
	elseif (cmd == "status") then
		DebuffFilter_Print("current settings:");
		DebuffFilter_Print("current scale: |cff00ccff" .. DebuffFilter_Config[DebuffFilter_Player]["scale"] .. "|r");
		DebuffFilter_Print("current player buff orientation: |cff00ccff" .. DebuffFilter_Config[DebuffFilter_Player]["buff_orientation"] .. "|r");
		DebuffFilter_Print("current time orientation: |cff00ccff" .. DebuffFilter_Config[DebuffFilter_Player]["time_orientation"] .. "|r");
		DebuffFilter_Print("show debuff/buff count: |cff00ccff" .. DebuffFilter_Config[DebuffFilter_Player]["count"] .. "|r");
		DebuffFilter_Print("show tooltips: |cff00ccff" .. DebuffFilter_Config[DebuffFilter_Player]["tooltips"] .. "|r");
		DebuffFilter_Print("player buff filtering: |cff00ccff" .. DebuffFilter_Config[DebuffFilter_Player]["buffs"] .. "|r");
		DebuffFilter_Print("target debuff filtering: |cff00ccff" .. DebuffFilter_Config[DebuffFilter_Player]["debuffs"] .. "|r");
		DebuffFilter_Print("target debuff timers: |cff00ccff" .. DebuffFilter_Config[DebuffFilter_Player]["debuff_timers"] .. "|r");
		DebuffFilter_Print("current-target buff filtering: |cff00ccff" .. DebuffFilter_Config[DebuffFilter_Player]["current_target_buffs"] .. "|r");
		DebuffFilter_Print("multi-target buff list: |cff00ccff" .. DebuffFilter_Config[DebuffFilter_Player]["target_buffs"] .. "|r");
		DebuffFilter_Print("multi-target debuff list: |cff00ccff" .. DebuffFilter_Config[DebuffFilter_Player]["multi_target_debuffs"] .. "|r");
		DebuffFilter_Print("only my target/multi auras: |cff00ccff" .. tostring(DebuffFilter_Config[DebuffFilter_Player]["only_mine_auras"] or "no") .. "|r");
		DebuffFilter_Print("SuperWoW GUID: |cff00ccff" .. (DebuffFilter.playerGUID and "available" or "not detected") .. "|r");
	else
		DEFAULT_CHAT_FRAME:AddMessage("Debuff 过滤器命令:");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffbuffs|r: 开关自身 Buff 监视");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffdebuffs|r: 开关目标 Debuff 监视");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffscale [0.5-3.0]|r: 图标大小");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffbackdrop|r: 切换背景帮助移动 buff 框架");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffcount|r: 切换buff 计数显示");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccfftooltips|r: 切换提示和关闭");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffstatus|r: 显示当前设置");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffreset|r: 恢复当前角色的全部初始设置");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter <|cff00ccffadd|r > |cff00ccff[|cff00ff00buff|cff00ccff]|r: 添加一个buff监控");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter <|cff00ccffdel|r > |cff00ccff[|cff00ff00buff|cff00ccff]|r: 清除一个buff监控");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccfflist|r : 查看自身 Buff 监视列表.");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffdadd [Debuff名称]|r: 添加目标 Debuff 监视");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffddel [Debuff名称]|r: 删除目标 Debuff 监视");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffdlist|r: 查看目标 Debuff 监视列表");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffdscan|r: 扫描并打印当前目标实际 Debuff 名称和ID");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffctbadd / ctbdel / ctblist|r: 管理当前目标 Buff 监视列表");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffctbtime 名称 秒数|r: 设置当前目标 Buff 持续时间");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffctbscan|r: 扫描目标增益");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccfftbadd / tbdel / tblist|r: 管理多人目标 Buff 监视列表");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccfftbtime 名称 秒数|r: 设置多人增益持续时间");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffmtdadd / mtddel / mtdlist|r: 管理多人减益追踪列表");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffmtdtime 名称 秒数|r: 设置多人减益持续时间");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffmtdscan|r: 扫描目标减益并加入多人减益候选");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffcastdebug|r: 开关目标技能施法事件参数调试");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccfftimers|r: 开关目标 Debuff 预测倒计时");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffdtime [名称] [秒]|r: 设置自定义持续时间");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffdtimeoff [名称]|r: 删除自定义持续时间");
		DEFAULT_CHAT_FRAME:AddMessage("/dfilter |cff00ccffdtimes|r: 查看内置和自定义时间规则");
		DEFAULT_CHAT_FRAME:AddMessage("Ctrl+左键点目标头像下的 Debuff：添加目标减益；点插件图标：取消监视。");
		DEFAULT_CHAT_FRAME:AddMessage("Shift+左键拖动对应框架；Shift+右键改变排列方向。");
		DEFAULT_CHAT_FRAME:AddMessage("目标时间为预测值：首次出现、叠层变化或 SuperWoW 检测到重新施放时重算。");
	end
end
-- ============================================================
-- 内置图形化管理窗口
-- 参考 Turtle WoW / WoW 1.12 已验证可用的旧式 UI 写法：
-- CreateFrame + Tooltip Backdrop + UIPanelButtonTemplate +
-- UICheckButtonTemplate + UIDropDownMenuTemplate。
-- 管理窗口直接并入主程序，不再依赖独立 Manager.lua 文件。
-- ============================================================

local DebuffFilter_ManagerState = {
	mode = "debuff",
	selectedName = nil,
	monitoredItems = {},
	scanItems = {},
	debuffOnlyControls = {},
};

local function DFM_NormalizeName(name)
	if (not name) then return nil; end
	name = tostring(name);
	name = string.gsub(name, "\226\128\139", ""); -- U+200B
	name = string.gsub(name, "\239\187\191", ""); -- BOM
	name = string.gsub(name, "\194\160", " ");    -- NBSP
	name = string.gsub(name, "^%s+", "");
	name = string.gsub(name, "%s+$", "");
	if (name == "") then return nil; end
	return name;
end

local function DFM_SetDropDownText(dropdown, value)
	if (not dropdown) then return; end
	local textRegion = getglobal(dropdown:GetName() .. "Text");
	if (textRegion) then
		textRegion:SetText(value or "");
	end
end

local function DFM_SetStatus(message, isError)
	local status = getglobal("DebuffFilter_ManagerStatus");
	if (not status) then return; end
	status:SetText(message or "");
	if (isError) then
		status:SetTextColor(1, 0.25, 0.25);
	else
		status:SetTextColor(0.2, 1, 0.2);
	end
end

local function DFM_GetModeInfo()
	if (DebuffFilter_ManagerState.mode == "buff") then
		return "buff_list", "我的增益";
	elseif (DebuffFilter_ManagerState.mode == "playerdebuff") then
		return "player_debuff_list", "我的减益";
	elseif (DebuffFilter_ManagerState.mode == "currenttargetbuff") then
		return "current_target_buff_list", "目标增益";
	elseif (DebuffFilter_ManagerState.mode == "targetbuff") then
		return "target_buff_list", "多人增益";
	elseif (DebuffFilter_ManagerState.mode == "multidebuff") then
		return "multi_target_debuff_list", "多人减益";
	end
	return "debuff_list", "目标减益";
end

local function DFM_GetInputName()
	local edit = getglobal("DebuffFilter_ManagerNameEdit");
	if (not edit) then return nil; end
	local value = edit:GetText();
	return DFM_NormalizeName(value);
end

local function DFM_FillDuration(name)
	local edit = getglobal("DebuffFilter_ManagerDurationEdit");
	if (not edit) then return; end
	if ((DebuffFilter_ManagerState.mode ~= "debuff" and DebuffFilter_ManagerState.mode ~= "currenttargetbuff" and DebuffFilter_ManagerState.mode ~= "targetbuff" and DebuffFilter_ManagerState.mode ~= "multidebuff") or not name) then
		edit:SetText("");
		return;
	end

	local config = DebuffFilter_Config[DebuffFilter_Player];
	local custom;
	local rule;
	if (DebuffFilter_ManagerState.mode == "currenttargetbuff") then
		-- 当前目标 Buff 输入框只显示手工填写值；留空表示使用战斗记录计时。
		custom = config["current_target_buff_duration_custom"] and config["current_target_buff_duration_custom"][name];
		if (custom) then
			edit:SetText(tostring(custom));
		else
			edit:SetText("");
		end
		return;
	elseif (DebuffFilter_ManagerState.mode == "targetbuff") then
		-- 多人增益输入框只显示手工填写值；留空表示使用战斗记录计时。
		custom = config["target_buff_duration_custom"] and config["target_buff_duration_custom"][name];
		if (custom) then
			edit:SetText(tostring(custom));
		else
			edit:SetText("");
		end
		return;
	elseif (DebuffFilter_ManagerState.mode == "multidebuff") then
		custom = config["multi_target_debuff_duration_custom"] and config["multi_target_debuff_duration_custom"][name];
		if (custom) then edit:SetText(tostring(custom)); else edit:SetText(""); end
		return;
	else
		custom = config["debuff_timer_custom"][name];
		rule = DebuffFilter.DebuffRules and DebuffFilter.DebuffRules[name];
	end
	if (custom) then
		edit:SetText(tostring(custom));
		return;
	end
	if (rule and rule.base) then
		edit:SetText(tostring(rule.base));
	else
		edit:SetText("");
	end
end

local function DFM_RefreshMonitored()
	if (not DebuffFilter_Config or not DebuffFilter_Config[DebuffFilter_Player]) then return; end
	local listKey = DFM_GetModeInfo();
	local list = DebuffFilter_Config[DebuffFilter_Player][listKey];
	local items = {};
	for name, enabled in list do
		if (enabled == 1) then
			table.insert(items, name);
		end
	end
	table.sort(items, function(a, b) return tostring(a) < tostring(b); end);
	DebuffFilter_ManagerState.monitoredItems = items;

	local dropdown = getglobal("DebuffFilter_ManagerListDropDown");
	if (DebuffFilter_ManagerState.selectedName and list[DebuffFilter_ManagerState.selectedName]) then
		DFM_SetDropDownText(dropdown, DebuffFilter_ManagerState.selectedName);
	elseif (table.getn(items) > 0) then
		DebuffFilter_ManagerState.selectedName = nil;
		DFM_SetDropDownText(dropdown, "请选择已监视项目");
	else
		DebuffFilter_ManagerState.selectedName = nil;
		DFM_SetDropDownText(dropdown, "（列表为空）");
	end
end

local function DFM_ListDropDownInitialize()
	local items = DebuffFilter_ManagerState.monitoredItems or {};
	for index = 1, table.getn(items) do
		local itemName = items[index];
		local info = {};
		info.text = itemName;
		info.value = itemName;
		info.checked = (DebuffFilter_ManagerState.selectedName == itemName);
		info.func = (function(selectedName)
			return function()
				DebuffFilter_ManagerState.selectedName = selectedName;
				DFM_SetDropDownText(getglobal("DebuffFilter_ManagerListDropDown"), selectedName);
				getglobal("DebuffFilter_ManagerNameEdit"):SetText(selectedName);
				DFM_FillDuration(selectedName);
			end
		end)(itemName);
		UIDropDownMenu_AddButton(info, 1);
	end
end

local function DFM_ScanDropDownInitialize()
	local items = DebuffFilter_ManagerState.scanItems or {};
	for index = 1, table.getn(items) do
		local entry = items[index];
		local info = {};
		info.text = entry.text;
		info.value = entry.name;
		info.checked = nil;
		info.func = (function(selectedName, selectedText)
			return function()
				getglobal("DebuffFilter_ManagerNameEdit"):SetText(selectedName);
				DFM_SetDropDownText(getglobal("DebuffFilter_ManagerScanDropDown"), selectedText);
				DFM_FillDuration(selectedName);
				if (DebuffFilter_ManagerState.mode == "buff") then
					DFM_SetStatus("已选择当前自身增益：" .. selectedName);
				elseif (DebuffFilter_ManagerState.mode == "playerdebuff") then
					DFM_SetStatus("已选择当前自身 Debuff：" .. selectedName);
				elseif (DebuffFilter_ManagerState.mode == "currenttargetbuff") then
					DFM_SetStatus("已选择当前目标 Buff：" .. selectedName);
				elseif (DebuffFilter_ManagerState.mode == "targetbuff") then
					DFM_SetStatus("已选择多人增益：" .. selectedName);
				elseif (DebuffFilter_ManagerState.mode == "multidebuff") then
					DFM_SetStatus("已选择多人减益：" .. selectedName);
				else
					DFM_SetStatus("已选择当前目标 Debuff：" .. selectedName);
				end
			end
		end)(entry.name, entry.text);
		UIDropDownMenu_AddButton(info, 1);
	end
end

local function DFM_ScanTarget()
	local dropdown = getglobal("DebuffFilter_ManagerScanDropDown");
	DebuffFilter_ManagerState.scanItems = {};

	local unit = "target";
	local isPlayerBuff = DebuffFilter_ManagerState.mode == "buff";
	local isPlayerDebuff = DebuffFilter_ManagerState.mode == "playerdebuff";
	local isCurrentTargetBuff = DebuffFilter_ManagerState.mode == "currenttargetbuff";
	local isMultiTargetDebuff = DebuffFilter_ManagerState.mode == "multidebuff";
	local isTargetBuff = isCurrentTargetBuff or DebuffFilter_ManagerState.mode == "targetbuff";
	if (isPlayerBuff or isPlayerDebuff) then unit = "player"; end

	if (unit == "target" and not UnitExists("target")) then
		DFM_SetDropDownText(dropdown, "（当前没有目标）");
		DFM_SetStatus("当前没有可扫描的目标。", true);
		return;
	end

	local unique = {};
	for index = 1, 32, 1 do
		local texture, stacks, dispelType, auraID;
		local playerBuffIndex = nil;
		if (isPlayerBuff) then
			playerBuffIndex = GetPlayerBuff(index - 1, "HELPFUL");
			if (not playerBuffIndex or playerBuffIndex < 0) then break; end
			texture = GetPlayerBuffTexture(playerBuffIndex);
			stacks = GetPlayerBuffApplications(playerBuffIndex);
			auraID = playerBuffIndex;
		elseif (isTargetBuff) then
			texture, stacks, dispelType, auraID = UnitBuff(unit, index);
		else
			texture, stacks, dispelType, auraID = UnitDebuff(unit, index);
		end
		if (not texture) then break; end

		DebuffFilter_Tooltip:SetOwner(UIParent, "ANCHOR_NONE");
		DebuffFilter_Tooltip:ClearLines();
		if (isPlayerBuff) then
			DebuffFilter_Tooltip:SetPlayerBuff(playerBuffIndex);
		elseif (isTargetBuff) then
			DebuffFilter_Tooltip:SetUnitBuff(unit, index);
		else
			DebuffFilter_Tooltip:SetUnitDebuff(unit, index);
		end
		local name = DFM_NormalizeName(DebuffFilter_TooltipTextLeft1:GetText());
		if (name and not unique[name]) then
			local suffix = "";
			if (tonumber(stacks) and tonumber(stacks) > 1) then
				suffix = suffix .. "  " .. tostring(stacks) .. "层";
			end
			if (dispelType) then suffix = suffix .. "  " .. tostring(dispelType); end
			if (auraID) then suffix = suffix .. "  ID:" .. tostring(auraID); end
			table.insert(DebuffFilter_ManagerState.scanItems, { name=name, text=name .. suffix });
			unique[name] = 1;
		end
	end

	table.sort(DebuffFilter_ManagerState.scanItems, function(a, b) return a.name < b.name; end);
	if (table.getn(DebuffFilter_ManagerState.scanItems) > 0) then
		if (isPlayerBuff) then
			DFM_SetDropDownText(dropdown, "请选择当前自身增益");
			DFM_SetStatus("已扫描到 " .. table.getn(DebuffFilter_ManagerState.scanItems) .. " 个自身增益。");
		elseif (isPlayerDebuff) then
			DFM_SetDropDownText(dropdown, "请选择当前自身 Debuff");
			DFM_SetStatus("已扫描到 " .. table.getn(DebuffFilter_ManagerState.scanItems) .. " 个自身 Debuff。");
		elseif (isTargetBuff) then
			DFM_SetDropDownText(dropdown, "请选择目标增益");
			if (isCurrentTargetBuff) then
				DFM_SetStatus("已扫描到 " .. table.getn(DebuffFilter_ManagerState.scanItems) .. " 个当前目标 Buff。");
			else
				DFM_SetStatus("已扫描到 " .. table.getn(DebuffFilter_ManagerState.scanItems) .. " 个目标 Buff，可加入多人列表。");
			end
		elseif (isMultiTargetDebuff) then
			DFM_SetDropDownText(dropdown, "请选择当前目标 Debuff");
			DFM_SetStatus("已扫描到 " .. table.getn(DebuffFilter_ManagerState.scanItems) .. " 个目标 Debuff，可加入多人减益追踪。");
		else
			DFM_SetDropDownText(dropdown, "请选择当前目标 Debuff");
			DFM_SetStatus("已扫描到 " .. table.getn(DebuffFilter_ManagerState.scanItems) .. " 个目标 Debuff。");
		end
	else
		if (isPlayerBuff) then
			DFM_SetDropDownText(dropdown, "（自身没有增益）");
			DFM_SetStatus("接口没有扫描到自身增益。", true);
		elseif (isPlayerDebuff) then
			DFM_SetDropDownText(dropdown, "（自身没有 Debuff）");
			DFM_SetStatus("接口没有扫描到自身 Debuff。", true);
		elseif (isTargetBuff) then
			DFM_SetDropDownText(dropdown, "（目标没有 Buff）");
			DFM_SetStatus("接口没有扫描到目标 Buff。", true);
		else
			DFM_SetDropDownText(dropdown, "（目标没有 Debuff）");
			DFM_SetStatus("接口没有扫描到目标 Debuff。", true);
		end
	end
end

function DebuffFilter_Manager_SelectMode(mode)
	if (mode ~= "buff" and mode ~= "playerdebuff" and mode ~= "currenttargetbuff" and mode ~= "targetbuff" and mode ~= "multidebuff") then mode = "debuff"; end
	DebuffFilter_ManagerState.mode = mode;
	DebuffFilter_ManagerState.selectedName = nil;
	local modeText = "目标减益";
	if (mode == "buff") then modeText = "我的增益"; end
	if (mode == "playerdebuff") then modeText = "我的减益"; end
	if (mode == "currenttargetbuff") then modeText = "目标增益"; end
	if (mode == "targetbuff") then modeText = "多人增益"; end
	if (mode == "multidebuff") then modeText = "多人减益"; end
	DFM_SetDropDownText(getglobal("DebuffFilter_ManagerModeDropDown"), modeText);
	getglobal("DebuffFilter_ManagerNameEdit"):SetText("");

	for index = 1, table.getn(DebuffFilter_ManagerState.debuffOnlyControls) do
		if (mode == "debuff" or mode == "currenttargetbuff" or mode == "targetbuff" or mode == "multidebuff") then
			DebuffFilter_ManagerState.debuffOnlyControls[index]:Show();
		else
			DebuffFilter_ManagerState.debuffOnlyControls[index]:Hide();
		end
	end

	local scanLabel = getglobal("DebuffFilter_ManagerScanLabel");
	local scanButton = getglobal("DebuffFilter_ManagerScanButton");
	local scanDrop = getglobal("DebuffFilter_ManagerScanDropDown");
	local durationLabel = getglobal("DebuffFilter_ManagerDurationLabel");
	if (durationLabel) then
		if (mode == "currenttargetbuff" or mode == "targetbuff" or mode == "multidebuff") then durationLabel:SetText("持续时间"); else durationLabel:SetText("预测时间"); end
	end
	if (mode == "buff") then
		if (scanLabel) then scanLabel:SetText("当前自身"); scanLabel:Show(); end
		if (scanButton) then scanButton:SetText("扫描自身"); scanButton:Show(); end
		if (scanDrop) then scanDrop:Show(); DFM_SetDropDownText(scanDrop, "请选择当前自身增益"); end
	elseif (mode == "playerdebuff") then
		if (scanLabel) then scanLabel:SetText("当前自身"); scanLabel:Show(); end
		if (scanButton) then scanButton:SetText("扫描自身"); scanButton:Show(); end
		if (scanDrop) then scanDrop:Show(); DFM_SetDropDownText(scanDrop, "请选择当前自身 Debuff"); end
	elseif (mode == "debuff") then
		if (scanLabel) then scanLabel:SetText("当前目标"); scanLabel:Show(); end
		if (scanButton) then scanButton:SetText("扫描目标"); scanButton:Show(); end
		if (scanDrop) then scanDrop:Show(); DFM_SetDropDownText(scanDrop, "请选择当前目标 Debuff"); end
	elseif (mode == "currenttargetbuff" or mode == "targetbuff") then
		if (scanLabel) then scanLabel:SetText("当前目标"); scanLabel:Show(); end
		if (scanButton) then scanButton:SetText("扫描目标"); scanButton:Show(); end
		if (scanDrop) then scanDrop:Show(); DFM_SetDropDownText(scanDrop, "请选择目标增益"); end
	elseif (mode == "multidebuff") then
		if (scanLabel) then scanLabel:SetText("当前目标"); scanLabel:Show(); end
		if (scanButton) then scanButton:SetText("扫描目标"); scanButton:Show(); end
		if (scanDrop) then scanDrop:Show(); DFM_SetDropDownText(scanDrop, "请选择当前目标 Debuff"); end
	else
		if (scanLabel) then scanLabel:Hide(); end
		if (scanButton) then scanButton:Hide(); end
		if (scanDrop) then scanDrop:Hide(); end
	end

	DFM_RefreshMonitored();
	DFM_FillDuration(nil);
	DFM_SetStatus("当前管理：" .. modeText);
end

local function DFM_ModeDropDownInitialize()
	local modeItems = {
		{ text="目标减益", value="debuff" },
		{ text="目标增益", value="currenttargetbuff" },
		{ text="多人增益", value="targetbuff" },
		{ text="多人减益", value="multidebuff" },
		{ text="我的增益", value="buff" },
		{ text="我的减益", value="playerdebuff" },
	};
	for index = 1, table.getn(modeItems) do
		local entry = modeItems[index];
		local info = {};
		info.text = entry.text;
		info.value = entry.value;
		info.checked = (DebuffFilter_ManagerState.mode == entry.value);
		info.func = (function(selectedMode)
			return function()
				DebuffFilter_Manager_SelectMode(selectedMode);
			end
		end)(entry.value);
		UIDropDownMenu_AddButton(info, 1);
	end
end

local function DFM_AnnounceChannelDropDownInitialize()
	local channels = {
		{ text="说", value="SAY" },
		{ text="小队", value="PARTY" },
		{ text="团队", value="RAID" },
		{ text="公会", value="GUILD" },
	};
	local current = DebuffFilter_Config[DebuffFilter_Player]["target_spell_announce_channel"] or "SAY";
	for index = 1, table.getn(channels) do
		local entry = channels[index];
		local info = {};
		info.text = entry.text;
		info.value = entry.value;
		info.checked = (current == entry.value);
		info.func = (function(channelValue, channelText)
			return function()
				DebuffFilter_Config[DebuffFilter_Player]["target_spell_announce_channel"] = channelValue;
				DFM_SetDropDownText(getglobal("DebuffFilter_ManagerAnnounceDropDown"), channelText);
				DFM_SetStatus("技能图标点击播报频道已设置为：" .. channelText .. "。");
			end
		end)(entry.value, entry.text);
		UIDropDownMenu_AddButton(info, 1);
	end
end

local function DFM_ScaleDropDownInitialize()
	local scales = { 0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3 };
	for index = 1, table.getn(scales) do
		local scaleValue = scales[index];
		local info = {};
		info.text = tostring(scaleValue);
		info.value = scaleValue;
		info.checked = (tonumber(DebuffFilter_Config[DebuffFilter_Player]["scale"]) == scaleValue);
		info.func = (function(selectedScale)
			return function()
				DebuffFilter_Config[DebuffFilter_Player]["scale"] = selectedScale;
				DebuffFilterFrame:SetScale(selectedScale * UIParent:GetScale());
				DFM_SetDropDownText(getglobal("DebuffFilter_ManagerScaleDropDown"), tostring(selectedScale));
				DFM_SetStatus("图标缩放已设置为 " .. tostring(selectedScale) .. "。");
			end
		end)(scaleValue);
		UIDropDownMenu_AddButton(info, 1);
	end
end

local function DFM_Add()
	local name = DFM_GetInputName();
	if (not name) then
		DFM_SetStatus("请先输入要监视的名称。", true);
		return;
	end
	local listKey, typeText = DFM_GetModeInfo();
	local list = DebuffFilter_Config[DebuffFilter_Player][listKey];
	local existed = list[name] == 1;
	list[name] = 1;
	DebuffFilter_ManagerState.selectedName = name;
	DFM_RefreshMonitored();
	if (DebuffFilter_ManagerState.mode == "debuff") then
		DebuffFilter_DebuffFrame_Update();
	elseif (DebuffFilter_ManagerState.mode == "currenttargetbuff") then
		if (type(DebuffFilter_CurrentTargetBuff_Rescan) == "function") then DebuffFilter_CurrentTargetBuff_Rescan(); end
	elseif (DebuffFilter_ManagerState.mode == "targetbuff") then
		if (type(DebuffFilter_TargetBuff_Rescan) == "function") then DebuffFilter_TargetBuff_Rescan(); end
	elseif (DebuffFilter_ManagerState.mode == "multidebuff") then
		if (type(DebuffFilter_MultiTargetDebuff_Rescan) == "function") then DebuffFilter_MultiTargetDebuff_Rescan(); end
	elseif (DebuffFilter_ManagerState.mode == "playerdebuff") then
		if (DebuffFilter_Extension and type(DebuffFilter_Extension.UpdatePlayerDebuffs) == "function") then DebuffFilter_Extension.UpdatePlayerDebuffs(true); end
	else
		DebuffFilter_BuffFrame_Update();
	end
	if (existed) then
		DFM_SetStatus(typeText .. "“" .. name .. "”已经在监视列表中。", true);
	else
		DFM_SetStatus("已添加" .. typeText .. "：" .. name);
	end
end

local function DFM_Delete()
	local name = DebuffFilter_ManagerState.selectedName or DFM_GetInputName();
	if (not name) then
		DFM_SetStatus("请先从已监视列表选择要删除的项目。", true);
		return;
	end
	local listKey, typeText = DFM_GetModeInfo();
	local list = DebuffFilter_Config[DebuffFilter_Player][listKey];
	if (not list[name]) then
		DFM_SetStatus("监视列表中没有“" .. name .. "”。", true);
		return;
	end
	list[name] = nil;
	DebuffFilter_ManagerState.selectedName = nil;
	getglobal("DebuffFilter_ManagerNameEdit"):SetText("");
	DFM_RefreshMonitored();
	if (DebuffFilter_ManagerState.mode == "debuff") then
		DebuffFilter_DebuffFrame_Update();
	elseif (DebuffFilter_ManagerState.mode == "currenttargetbuff") then
		if (type(DebuffFilter_CurrentTargetBuff_Rescan) == "function") then DebuffFilter_CurrentTargetBuff_Rescan(); end
	elseif (DebuffFilter_ManagerState.mode == "targetbuff") then
		if (type(DebuffFilter_TargetBuff_Rescan) == "function") then DebuffFilter_TargetBuff_Rescan(); end
	elseif (DebuffFilter_ManagerState.mode == "multidebuff") then
		if (type(DebuffFilter_MultiTargetDebuff_Rescan) == "function") then DebuffFilter_MultiTargetDebuff_Rescan(); end
	elseif (DebuffFilter_ManagerState.mode == "playerdebuff") then
		if (DebuffFilter_Extension and type(DebuffFilter_Extension.UpdatePlayerDebuffs) == "function") then DebuffFilter_Extension.UpdatePlayerDebuffs(true); end
	else
		DebuffFilter_BuffFrame_Update();
	end
	DFM_SetStatus("已删除" .. typeText .. "：" .. name);
end

local function DFM_SetDuration()
	local name = DFM_GetInputName() or DebuffFilter_ManagerState.selectedName;
	local durationEdit = getglobal("DebuffFilter_ManagerDurationEdit");
	local durationText = durationEdit and durationEdit:GetText() or "";
	local seconds = tonumber(durationText);
	if (not name) then
		DFM_SetStatus("请先输入或选择一个目标 Debuff / Buff。", true);
		return;
	end
	if (DebuffFilter_ManagerState.mode == "currenttargetbuff") then
		-- 当前目标 Buff 留空等同于不设置手工时间，自动改用战斗记录计时。
		if (not seconds or seconds <= 0) then
			DebuffFilter_Config[DebuffFilter_Player]["current_target_buff_duration_custom"][name] = nil;
			if (durationEdit) then durationEdit:SetText(""); end
			if (type(DebuffFilter_CurrentTargetBuff_ApplyDurationRule) == "function") then DebuffFilter_CurrentTargetBuff_ApplyDurationRule(name); end
			DFM_SetStatus("当前目标 Buff“" .. name .. "”未填写时间，已使用战斗记录计时。");
			return;
		end
		DebuffFilter_Config[DebuffFilter_Player]["current_target_buff_duration_custom"][name] = seconds;
		if (type(DebuffFilter_CurrentTargetBuff_ApplyDurationRule) == "function") then DebuffFilter_CurrentTargetBuff_ApplyDurationRule(name); end
		DFM_SetStatus("已设置当前目标 Buff“" .. name .. "”的手工持续时间为 " .. tostring(seconds) .. " 秒；手工时间优先。");
	elseif (DebuffFilter_ManagerState.mode == "targetbuff") then
		-- 多人目标 Buff 留空等同于不设置手工时间，自动改用战斗记录计时。
		if (not seconds or seconds <= 0) then
			DebuffFilter_Config[DebuffFilter_Player]["target_buff_duration_custom"][name] = nil;
			if (durationEdit) then durationEdit:SetText(""); end
			if (type(DebuffFilter_TargetBuff_ApplyDurationRule) == "function") then DebuffFilter_TargetBuff_ApplyDurationRule(name); end
			DFM_SetStatus("目标 Buff“" .. name .. "”未填写时间，已使用战斗记录计时。");
			return;
		end
		DebuffFilter_Config[DebuffFilter_Player]["target_buff_duration_custom"][name] = seconds;
		if (type(DebuffFilter_TargetBuff_ApplyDurationRule) == "function") then DebuffFilter_TargetBuff_ApplyDurationRule(name); end
		DFM_SetStatus("已设置多人增益“" .. name .. "”的手工持续时间为 " .. tostring(seconds) .. " 秒；手工时间优先。");
	elseif (DebuffFilter_ManagerState.mode == "multidebuff") then
		if (not seconds or seconds <= 0) then
			DebuffFilter_Config[DebuffFilter_Player]["multi_target_debuff_duration_custom"][name] = nil;
			if (durationEdit) then durationEdit:SetText(""); end
			if (type(DebuffFilter_MultiTargetDebuff_ApplyDurationRule) == "function") then DebuffFilter_MultiTargetDebuff_ApplyDurationRule(name); end
			DFM_SetStatus("多人减益“" .. name .. "”未填写时间，已使用战斗记录计时。");
			return;
		end
		DebuffFilter_Config[DebuffFilter_Player]["multi_target_debuff_duration_custom"][name] = seconds;
		if (type(DebuffFilter_MultiTargetDebuff_ApplyDurationRule) == "function") then DebuffFilter_MultiTargetDebuff_ApplyDurationRule(name); end
		DFM_SetStatus("已设置多人减益“" .. name .. "”的手工持续时间为 " .. tostring(seconds) .. " 秒；手工时间优先。");
	else
		if (not seconds or seconds <= 0) then
			DFM_SetStatus("持续时间必须是大于0的秒数。", true);
			return;
		end
		DebuffFilter_Config[DebuffFilter_Player]["debuff_timer_custom"][name] = seconds;
		DFM_SetStatus("已设置“" .. name .. "”的预测持续时间为 " .. tostring(seconds) .. " 秒。");
	end
end

local function DFM_ClearDuration()
	local name = DFM_GetInputName() or DebuffFilter_ManagerState.selectedName;
	if (not name) then
		DFM_SetStatus("请先输入或选择一个目标 Debuff / Buff。", true);
		return;
	end
	if (DebuffFilter_ManagerState.mode == "currenttargetbuff") then
		DebuffFilter_Config[DebuffFilter_Player]["current_target_buff_duration_custom"][name] = nil;
		DFM_FillDuration(name);
		if (type(DebuffFilter_CurrentTargetBuff_ApplyDurationRule) == "function") then DebuffFilter_CurrentTargetBuff_ApplyDurationRule(name); end
		DFM_SetStatus("当前目标 Buff“" .. name .. "”已改为战斗记录计时；下次施放时开始倒计时。");
	elseif (DebuffFilter_ManagerState.mode == "targetbuff") then
		DebuffFilter_Config[DebuffFilter_Player]["target_buff_duration_custom"][name] = nil;
		DFM_FillDuration(name);
		if (type(DebuffFilter_TargetBuff_ApplyDurationRule) == "function") then DebuffFilter_TargetBuff_ApplyDurationRule(name); end
		DFM_SetStatus("多人增益“" .. name .. "”已改为战斗记录计时；下次施放时开始倒计时。");
	elseif (DebuffFilter_ManagerState.mode == "multidebuff") then
		DebuffFilter_Config[DebuffFilter_Player]["multi_target_debuff_duration_custom"][name] = nil;
		DFM_FillDuration(name);
		if (type(DebuffFilter_MultiTargetDebuff_ApplyDurationRule) == "function") then DebuffFilter_MultiTargetDebuff_ApplyDurationRule(name); end
		DFM_SetStatus("多人减益“" .. name .. "”已改为战斗记录计时；下次施放时开始倒计时。");
	else
		DebuffFilter_Config[DebuffFilter_Player]["debuff_timer_custom"][name] = nil;
		DFM_FillDuration(name);
		if (DebuffFilter.DebuffRules and DebuffFilter.DebuffRules[name]) then
			DFM_SetStatus("已恢复“" .. name .. "”的内置时间规则。");
		else
			DFM_SetStatus("已删除“" .. name .. "”的自定义时间。");
		end
	end
end

local function DFM_SetMaxSavedProfiles()
	local edit = getglobal("DebuffFilter_ManagerMaxSavedEdit");
	local config = DebuffFilter_Config and DebuffFilter_Config[DebuffFilter_Player];
	if (not edit or not config) then return; end
	local value = math.floor(tonumber(edit:GetText()) or 0);
	if (value < 1 or value > 10000) then
		edit:SetText(tostring(DebuffFilter_GetMaxSavedMonsterSpellProfiles(config)));
		DFM_SetStatus("最大储存记录必须是1到10000之间的整数。", true);
		return;
	end
	config["target_spell_max_saved_profiles"] = value;
	DebuffFilter.targetSpellMaxSavedProfiles = value;
	DebuffFilter_TrimSavedMonsterSpellProfiles(config);
	edit:SetText(tostring(value));
	edit:ClearFocus();
	DFM_SetStatus("目标技能永久记录上限已设置为 " .. tostring(value) .. " 条；超过部分已按最久未使用顺序清理。");
end

local function DFM_SettingChanged(setting, checkbox)
	DebuffFilter_Config[DebuffFilter_Player][setting] = checkbox:GetChecked() and "yes" or "no";
	if (setting == "player_auras") then
		DebuffFilter_BuffFrame_Update();
		if (DebuffFilter_Extension and type(DebuffFilter_Extension.UpdatePlayerDebuffs) == "function") then DebuffFilter_Extension.UpdatePlayerDebuffs(true); end
	elseif (setting == "buffs") then
		if (checkbox:GetChecked()) then
			DebuffFilter_BuffFrame:Show();
			DebuffFilter_BuffFrame_Update();
		else
			DebuffFilter_BuffFrame:Hide();
		end
	elseif (setting == "player_debuffs") then
		if (DebuffFilter_Extension and type(DebuffFilter_Extension.UpdatePlayerDebuffs) == "function") then DebuffFilter_Extension.UpdatePlayerDebuffs(true); end
	elseif (setting == "debuffs") then
		if (checkbox:GetChecked()) then
			DebuffFilter_DebuffFrame:Show();
			DebuffFilter_DebuffFrame_Update();
		else
			DebuffFilter_DebuffFrame:Hide();
		end
	elseif (setting == "debuff_timers") then
		DebuffFilter_DebuffFrame_Update();
	elseif (setting == "current_target_buffs") then
		if (type(DebuffFilter_CurrentTargetBuff_Rescan) == "function") then DebuffFilter_CurrentTargetBuff_Rescan(); end
	elseif (setting == "target_buffs") then
		if (type(DebuffFilter_TargetBuff_Rescan) == "function") then DebuffFilter_TargetBuff_Rescan(); end
	elseif (setting == "multi_target_debuffs") then
		if (type(DebuffFilter_MultiTargetDebuff_Rescan) == "function") then DebuffFilter_MultiTargetDebuff_Rescan(); end
	elseif (setting == "only_mine_auras") then
		DebuffFilter_DebuffFrame_Update();
		if (type(DebuffFilter_CurrentTargetBuff_Rescan) == "function") then DebuffFilter_CurrentTargetBuff_Rescan(); end
		if (type(DebuffFilter_TargetBuff_Rescan) == "function") then DebuffFilter_TargetBuff_Rescan(); end
		if (type(DebuffFilter_MultiTargetDebuff_Rescan) == "function") then DebuffFilter_MultiTargetDebuff_Rescan(); end
		if (type(DebuffFilter_TimerBars_Refresh) == "function") then DebuffFilter_TimerBars_Refresh(); end
		if (checkbox:GetChecked()) then
			DFM_SetStatus("已开启：目标/多人 Buff、Debuff 只显示本次登录已确认由你施加的效果。");
		else
			DFM_SetStatus("已关闭施法者过滤：恢复显示监视列表中的全部来源效果。");
		end
		return;
	elseif (setting == "target_spell_monitoring") then
		-- 关闭时立即停止记录并清空本次登录的临时GUID状态；永久学习数据保留。
		DebuffFilter_ClearTargetSpellSession();
		if (checkbox:GetChecked()) then
			DFM_SetStatus("目标技能监测已开启：进战斗先显示首轮倒计时，施法后切换循环倒计时。");
		else
			DFM_SetStatus("目标技能间隔监测已关闭；不会记录施法间隔，也不会显示技能图标。");
		end
		return;
	elseif (setting == "count") then
		DebuffFilter_BuffFrame_Update();
		DebuffFilter_DebuffFrame_Update();
		if (type(DebuffFilter_CurrentTargetBuffFrame_Update) == "function") then DebuffFilter_CurrentTargetBuffFrame_Update(); end
		if (DebuffFilter_Extension and type(DebuffFilter_Extension.UpdatePlayerDebuffs) == "function") then DebuffFilter_Extension.UpdatePlayerDebuffs(true); end
	end
	DFM_SetStatus("设置已更新。");
end

local function DFM_RefreshChecks()
	local map = {
		DebuffFilter_ManagerPlayerAurasCheck = "player_auras",
		DebuffFilter_ManagerBuffCheck = "buffs",
		DebuffFilter_ManagerPlayerDebuffCheck = "player_debuffs",
		DebuffFilter_ManagerDebuffCheck = "debuffs",
		DebuffFilter_ManagerCurrentTargetBuffCheck = "current_target_buffs",
		DebuffFilter_ManagerTimerCheck = "debuff_timers",
		DebuffFilter_ManagerTooltipCheck = "tooltips",
		DebuffFilter_ManagerCountCheck = "count",
		DebuffFilter_ManagerTargetBuffCheck = "target_buffs",
		DebuffFilter_ManagerMultiTargetDebuffCheck = "multi_target_debuffs",
		DebuffFilter_ManagerOnlyMineAurasCheck = "only_mine_auras",
		DebuffFilter_ManagerSpellMonitorCheck = "target_spell_monitoring",
	};
	for frameName, setting in map do
		local checkbox = getglobal(frameName);
		if (checkbox) then
			checkbox:SetChecked(DebuffFilter_Config[DebuffFilter_Player][setting] == "yes");
		end
	end
	DFM_SetDropDownText(getglobal("DebuffFilter_ManagerScaleDropDown"), tostring(DebuffFilter_Config[DebuffFilter_Player]["scale"]));
	local channel = DebuffFilter_Config[DebuffFilter_Player]["target_spell_announce_channel"] or "SAY";
	DFM_SetDropDownText(getglobal("DebuffFilter_ManagerAnnounceDropDown"), DebuffFilter_TargetSpellChannelNames[channel] or "说");
	local maxEdit = getglobal("DebuffFilter_ManagerMaxSavedEdit");
	if (maxEdit) then
		maxEdit:SetText(tostring(DebuffFilter_GetMaxSavedMonsterSpellProfiles(DebuffFilter_Config[DebuffFilter_Player])));
	end
end

function DebuffFilter_ResetCurrentCharacter()
	if (not DebuffFilter_Player) then
		DebuffFilter_Print("当前角色信息尚未初始化，无法恢复设置。");
		return;
	end

	DebuffFilter_Config = DebuffFilter_Config or {};
	DebuffFilter_Config[DebuffFilter_Player] = DebuffFilter_CopyTable(DebuffFilter_DefaultSettings);

	DebuffFilter.targetStates = {};
	DebuffFilter.targetTimers = {};
	DebuffFilter.pendingCasts = {};
	DebuffFilter.targetSpellDisplayCache = {};
	DebuffFilter.targetSpellRuntime = {};
	DebuffFilter.targetSpellCurrentGUID = nil;
	DebuffFilter.currentTargetKey = nil;
	DebuffFilter.lastComboPoints = 0;
	DebuffFilter.lastComboTarget = nil;
	DebuffFilter.lastComboTime = 0;
	DebuffFilter.backdrop = 0;
	DebuffFilter.targetSpellMaxSavedProfiles = DebuffFilter_DefaultSettings.target_spell_max_saved_profiles;

	if (DebuffFilterFrame) then
		DebuffFilterFrame:SetScale(DebuffFilter_DefaultSettings.scale * UIParent:GetScale());
	end

	DebuffFilter_FrameOrientation(DebuffFilter_DefaultSettings.buff_orientation, "DebuffFilter_BuffFrame");
	DebuffFilter_FrameOrientation(DebuffFilter_DefaultSettings.debuff_orientation, "DebuffFilter_DebuffFrame");
	DebuffFilter_TimeOrientation(DebuffFilter_DefaultSettings.time_orientation);
	DebuffFilter_ResetNativeFramePositions();

	if (DebuffFilter_BuffFrameBackdrop) then DebuffFilter_BuffFrameBackdrop:Hide(); end
	if (DebuffFilter_DebuffFrameBackdrop) then DebuffFilter_DebuffFrameBackdrop:Hide(); end
	if (DebuffFilter_BuffFrame) then DebuffFilter_BuffFrame:Show(); end
	if (DebuffFilter_DebuffFrame) then DebuffFilter_DebuffFrame:Show(); end

	DebuffFilter_BuffFrame_Update();
	DebuffFilter_DebuffFrame_Update();
	if (type(DebuffFilter_CurrentTargetBuffFrame_Update) == "function") then DebuffFilter_CurrentTargetBuffFrame_Update(); end
	if (type(DebuffFilter_TargetBuffFrame_Update) == "function") then DebuffFilter_TargetBuffFrame_Update(); end
	if (type(DebuffFilter_MultiTargetDebuffFrame_Update) == "function") then DebuffFilter_MultiTargetDebuffFrame_Update(); end
	DebuffFilter_TargetSpellFrame_Update();

	DebuffFilter_ManagerState.mode = "debuff";
	DebuffFilter_ManagerState.selectedName = nil;
	DebuffFilter_ManagerState.monitoredItems = {};
	DebuffFilter_ManagerState.scanItems = {};

	if (getglobal("DebuffFilter_ManagerFrame")) then
		DFM_RefreshChecks();
		DebuffFilter_Manager_SelectMode("debuff");
		DFM_SetStatus("当前角色已恢复初始设置；/reload 或退出游戏后写入角色 SavedVariables。");
	end

	DebuffFilter_Print("当前角色的监视列表、时间规则、缩放、方向和框体位置已恢复初始设置。配置会在 /reload 或退出游戏时写入角色 SavedVariables。");
end

StaticPopupDialogs["DEBUFF_FILTER_RESET_CONFIRM"] = {
	text = "确定恢复当前角色的全部初始设置吗？\n监视列表、技能首轮与循环学习数据、播报频道、自定义时间、缩放、排列方向和框体位置都会被重置。",
	button1 = "确定",
	button2 = "取消",
	OnAccept = function()
		DebuffFilter_ResetCurrentCharacter();
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
};

local function DFM_CreateButton(parent, name, text, width, x, y, onclick)
	local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate");
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
	button:SetWidth(width);
	button:SetHeight(24);
	DebuffFilter_SetUIFont(button, 12);
	button:SetText(text);
	button:SetScript("OnClick", onclick);
	return button;
end

local function DFM_CreateLabel(parent, name, text, x, y, width)
	local label = parent:CreateFontString(name, "OVERLAY", "GameFontNormalSmall");
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
	label:SetWidth(width or 100);
	DebuffFilter_SetUIFont(label, 12, "OUTLINE");
	label:SetJustifyH("LEFT");
	label:SetText(text);
	return label;
end

local function DFM_AttachTooltip(widget, title, lines)
	widget:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
		GameTooltip:AddLine(title, 1, 0.82, 0);
		if (type(lines) == "table") then
			for i = 1, table.getn(lines), 1 do
				GameTooltip:AddLine(lines[i], 1, 1, 1, 1);
			end
		elseif (lines) then
			GameTooltip:AddLine(lines, 1, 1, 1, 1);
		end
		GameTooltip:Show();
	end);
	widget:SetScript("OnLeave", function() GameTooltip:Hide(); end);
end

local function DFM_CreateCheck(parent, name, text, x, y, setting, tooltipTitle, tooltipLines)
	local check = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate");
	check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
	check:SetScale(0.8);
	local label = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	label:SetPoint("LEFT", check, "LEFT", 34, 1);
	DebuffFilter_SetUIFont(label, 14, "OUTLINE");
	label:SetTextColor(1, 1, 1);
	label:SetText(text);
	check:SetHitRectInsets(0, -155, 0, 0);
	check:SetScript("OnClick", (function(settingName, checkFrame)
		return function()
			DFM_SettingChanged(settingName, checkFrame);
		end
	end)(setting, check));
	if (tooltipTitle) then
		DFM_AttachTooltip(check, tooltipTitle, tooltipLines);
	end
	return check;
end

local function DFM_AttachSimpleTooltip(widget, title, line1, line2)
	if (not widget or not widget.SetScript) then
		-- FontString 在 WoW 1.12 中不能直接接收鼠标脚本。
		-- 不再创建锚定到 FontString 的透明按钮，避免拖动父窗口时触发客户端崩溃。
		return;
	end

	if (widget.SetHitRectInsets) then
		widget:SetHitRectInsets(0, -185, 0, 0);
	end

	widget:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
		GameTooltip:AddLine(title or "说明", 1, 0.82, 0);
		if (line1) then
			GameTooltip:AddLine(line1, 1, 1, 1, 1);
		end
		if (line2) then
			GameTooltip:AddLine(line2, 0.75, 0.75, 0.75, 1);
		end
		GameTooltip:Show();
	end);
	widget:SetScript("OnLeave", function() GameTooltip:Hide(); end);
end

local function DFM_CreateManagerFrame()
	if (getglobal("DebuffFilter_ManagerFrame")) then return; end

	local frame = CreateFrame("Frame", "DebuffFilter_ManagerFrame", UIParent);
	frame:Hide();
	frame:SetWidth(650);
	frame:SetHeight(930);
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10);
	frame:SetFrameLevel(100);
	frame:SetFrameStrata("DIALOG");
	frame:SetScale(0.82);
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left=4, right=4, top=4, bottom=4 }
	});
	frame:SetBackdropColor(0.04, 0.04, 0.09, 1.0);
	frame:EnableMouse(true);
	frame:SetMovable(true);
	frame:RegisterForDrag("LeftButton");
	frame:SetScript("OnDragStart", function() DebuffFilter_ManagerFrame:StartMoving(); end);
	-- 管理窗口拖动恢复v1.7.3的稳定逻辑：松开时只停止移动，不在同一鼠标事件中读写位置。
	frame:SetScript("OnDragStop", function()
		DebuffFilter_ManagerFrame:StopMovingOrSizing();
	end);

	-- 允许按 ESC 关闭，与参考 UI 的做法一致。
	tinsert(UISpecialFrames, "DebuffFilter_ManagerFrame");

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	title:SetPoint("TOP", frame, "TOP", 0, -12);
	DebuffFilter_SetUIFont(title, 14, "OUTLINE");
	title:SetText("|cFFFFD100Buff / Debuff 监视管理|r  |cff66ccff来自太阳神殿-Basin of Stars|r");

	local version = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	version:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -13);
	DebuffFilter_SetUIFont(version, 11);
	version:SetText("DebuffFilter v1.14.5");

	local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
	closeButton:SetWidth(32);
	closeButton:SetHeight(32);
	closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -2);

	local divider = frame:CreateTexture(nil, "ARTWORK");
	divider:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border");
	divider:SetTexCoord(0.81, 0.94, 0.5, 1);
	divider:SetVertexColor(0.5, 0.5, 0.5);
	divider:SetWidth(635);
	divider:SetHeight(4);
	divider:SetPoint("TOP", frame, "TOP", 0, -32);

	DFM_CreateLabel(frame, nil, "管理类别", 30, -68, 75);
	local modeDrop = CreateFrame("Button", "DebuffFilter_ManagerModeDropDown", frame, "UIDropDownMenuTemplate");
	modeDrop:SetPoint("TOPLEFT", frame, "TOPLEFT", 105, -53);
	UIDropDownMenu_SetWidth(160, modeDrop);
	UIDropDownMenu_Initialize(modeDrop, DFM_ModeDropDownInitialize);

	DFM_CreateLabel(frame, nil, "名称", 30, -123, 55);
	local nameEdit = CreateFrame("EditBox", "DebuffFilter_ManagerNameEdit", frame, "InputBoxTemplate");
	nameEdit:SetWidth(345);
	nameEdit:SetHeight(24);
	nameEdit:SetPoint("TOPLEFT", frame, "TOPLEFT", 105, -113);
	nameEdit:SetAutoFocus(false);
	nameEdit:SetMaxLetters(80);
	nameEdit:SetScript("OnEscapePressed", function() DebuffFilter_ManagerNameEdit:ClearFocus(); end);
	nameEdit:SetScript("OnEnterPressed", function() DebuffFilter_ManagerNameEdit:ClearFocus(); DFM_Add(); end);
	DFM_CreateButton(frame, "DebuffFilter_ManagerAddButton", "添加监视", 115, 500, -114, DFM_Add);

	DFM_CreateLabel(frame, nil, "已监视", 30, -178, 65);
	local listDrop = CreateFrame("Button", "DebuffFilter_ManagerListDropDown", frame, "UIDropDownMenuTemplate");
	listDrop:SetPoint("TOPLEFT", frame, "TOPLEFT", 105, -163);
	UIDropDownMenu_SetWidth(330, listDrop);
	UIDropDownMenu_Initialize(listDrop, DFM_ListDropDownInitialize);
	DFM_CreateButton(frame, "DebuffFilter_ManagerDeleteButton", "删除所选", 115, 500, -169, DFM_Delete);

	local scanLabel = DFM_CreateLabel(frame, "DebuffFilter_ManagerScanLabel", "当前目标", 30, -233, 65);
	local scanDrop = CreateFrame("Button", "DebuffFilter_ManagerScanDropDown", frame, "UIDropDownMenuTemplate");
	scanDrop:SetPoint("TOPLEFT", frame, "TOPLEFT", 105, -218);
	UIDropDownMenu_SetWidth(330, scanDrop);
	UIDropDownMenu_Initialize(scanDrop, DFM_ScanDropDownInitialize);
	local scanButton = DFM_CreateButton(frame, "DebuffFilter_ManagerScanButton", "扫描目标", 115, 500, -224, DFM_ScanTarget);

	local durationLabel = DFM_CreateLabel(frame, "DebuffFilter_ManagerDurationLabel", "预测时间", 30, -288, 65);
	local durationEdit = CreateFrame("EditBox", "DebuffFilter_ManagerDurationEdit", frame, "InputBoxTemplate");
	durationEdit:SetWidth(85);
	durationEdit:SetHeight(24);
	durationEdit:SetPoint("TOPLEFT", frame, "TOPLEFT", 105, -278);
	durationEdit:SetAutoFocus(false);
	durationEdit:SetMaxLetters(6);
	durationEdit:SetScript("OnEscapePressed", function() DebuffFilter_ManagerDurationEdit:ClearFocus(); end);
	durationEdit:SetScript("OnEnterPressed", function() DebuffFilter_ManagerDurationEdit:ClearFocus(); DFM_SetDuration(); end);
	local secondsLabel = DFM_CreateLabel(frame, "DebuffFilter_ManagerSecondsLabel", "秒", 195, -288, 25);
	local durationSet = DFM_CreateButton(frame, "DebuffFilter_ManagerDurationSet", "设置时间", 110, 235, -279, DFM_SetDuration);
	local durationClear = DFM_CreateButton(frame, "DebuffFilter_ManagerDurationClear", "恢复默认", 110, 360, -279, DFM_ClearDuration);

	DebuffFilter_ManagerState.debuffOnlyControls = { scanLabel, scanDrop, scanButton, durationLabel, durationEdit, secondsLabel, durationSet, durationClear };

	local optionLine = frame:CreateTexture(nil, "ARTWORK");
	optionLine:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border");
	optionLine:SetTexCoord(0.81, 0.94, 0.5, 1);
	optionLine:SetVertexColor(0.35, 0.35, 0.35);
	optionLine:SetWidth(605);
	optionLine:SetHeight(3);
	optionLine:SetPoint("TOP", frame, "TOP", 0, -340);

	-- 自身 Buff / Debuff 使用总开关，并保留两组独立显示开关。
	local playerAurasCheck = DFM_CreateCheck(frame, "DebuffFilter_ManagerPlayerAurasCheck", "启用我的增益 / 减益", 35, -375, "player_auras");
	local debuffCheck = DFM_CreateCheck(frame, "DebuffFilter_ManagerDebuffCheck", "启用目标减益", 300, -375, "debuffs");

	local buffCheck = DFM_CreateCheck(frame, "DebuffFilter_ManagerBuffCheck", "显示我的增益", 35, -422, "buffs");
	local playerDebuffCheck = DFM_CreateCheck(frame, "DebuffFilter_ManagerPlayerDebuffCheck", "显示我的减益", 300, -422, "player_debuffs");

	local timerCheck = DFM_CreateCheck(frame, "DebuffFilter_ManagerTimerCheck", "目标 Debuff 图标下显示预计秒数", 35, -469, "debuff_timers");
	local tooltipCheck = DFM_CreateCheck(frame, "DebuffFilter_ManagerTooltipCheck", "鼠标提示", 300, -469, "tooltips");

	local countCheck = DFM_CreateCheck(frame, "DebuffFilter_ManagerCountCheck", "显示数量", 35, -516, "count");
	DFM_CreateLabel(frame, nil, "图标缩放", 300, -514, 75);
	local scaleDrop = CreateFrame("Button", "DebuffFilter_ManagerScaleDropDown", frame, "UIDropDownMenuTemplate");
	scaleDrop:SetPoint("TOPLEFT", frame, "TOPLEFT", 375, -500);
	UIDropDownMenu_SetWidth(65, scaleDrop);
	UIDropDownMenu_Initialize(scaleDrop, DFM_ScaleDropDownInitialize);

	DFM_AttachSimpleTooltip(playerAurasCheck, "启用我的增益 / 减益", "这是自身光环监视总开关。关闭后自身 Buff 与自身 Debuff 两组都会停止显示。", "目标增益、目标减益、多人追踪与敌人技能监视不受影响。");
	DFM_AttachSimpleTooltip(buffCheck, "显示我的增益", "开启后显示监视列表中的自身 Buff。", "由“启用我的增益 / 减益”总开关共同控制。");
	DFM_AttachSimpleTooltip(playerDebuffCheck, "显示我的减益", "开启后显示监视列表中的自身 Debuff；图标上方显示类型、下方显示真实剩余时间。", "可在“自身 → 我的减益”页面添加、删除或扫描。");
	DFM_AttachSimpleTooltip(debuffCheck, "启用目标减益", "开启后显示并监视当前目标身上的 Debuff。关闭后目标 Debuff 监视框会停止更新与显示。", "可配合 Ctrl+左键点击目标头像下的 Debuff 快速添加。");
	DFM_AttachSimpleTooltip(timerCheck, "目标 Debuff 图标下显示预计秒数", "开启后，在目标 Debuff 图标下显示预计剩余秒数。关闭后图标仍会显示，只隐藏秒数。", "自身 Debuff 使用客户端真实剩余时间，不受此选项控制。");
	DFM_AttachSimpleTooltip(tooltipCheck, "鼠标提示", "开启后，鼠标移到插件图标上会显示 Buff / Debuff 名称与信息。关闭后不弹出提示。", "若你觉得鼠标提示挡视线，可以关闭。");
	DFM_AttachSimpleTooltip(countCheck, "显示数量", "开启后，在插件图标角落显示层数或数量。关闭后只显示图标本身。", "适合监视可叠层的 Buff / Debuff。");

	local currentTargetBuffCheck = DFM_CreateCheck(frame, "DebuffFilter_ManagerCurrentTargetBuffCheck", "启用目标增益", 35, -563, "current_target_buffs");
	DFM_AttachSimpleTooltip(currentTargetBuffCheck, "目标增益", "只显示当前选中目标身上已加入监视列表的 Buff。", "切换目标立即刷新；取消目标后图标自动消失。");

	local targetBuffCheck = DFM_CreateCheck(frame, "DebuffFilter_ManagerTargetBuffCheck", "启用多人增益追踪", 300, -563, "target_buffs");
	DFM_AttachSimpleTooltip(targetBuffCheck, "多人增益追踪", "扫描自己、小队与团队成员，并保留玩家名、技能名、图标与计时数据。", "旧动态文字列表已删除；扫描、排序、持续时间和清理逻辑仍保留。");

	local multiTargetDebuffCheck = DFM_CreateCheck(frame, "DebuffFilter_ManagerMultiTargetDebuffCheck", "启用多人减益追踪", 35, -610, "multi_target_debuffs");
	DFM_AttachSimpleTooltip(multiTargetDebuffCheck, "多人减益追踪", "扫描自己、小队与团队成员，并保留玩家名、技能名、图标与计时数据。", "整理版已删除旧动态列表渲染；减益消失或被驱散后的数据清理逻辑仍保留。");

	local onlyMineAurasCheck = DFM_CreateCheck(frame, "DebuffFilter_ManagerOnlyMineAurasCheck", "只显示我施加的 Buff / Debuff", 300, -775, "only_mine_auras");
	DFM_AttachSimpleTooltip(onlyMineAurasCheck, "只显示我施加的 Buff / Debuff", "开启后仅过滤：目标增益、目标减益、多人增益、多人减益；我的增益/减益不受影响。", "WoW 1.12 的 UnitBuff/UnitDebuff 不返回施法者，因此依赖 SuperWoW UNIT_CASTEVENT；开启后，本次登录尚未观察到来源的旧光环会先隐藏，重新施放后即可识别。");

	local spellMonitorCheck = DFM_CreateCheck(frame, "DebuffFilter_ManagerSpellMonitorCheck", "启用周围敌人技能监测", 35, -657, "target_spell_monitoring");
	DFM_AttachSimpleTooltip(spellMonitorCheck, "周围敌人技能后台监测", "开启后后台记录附近所有敌对NPC的施法，并按怪物GUID分别运行首轮和循环倒计时；界面始终只显示当前目标。", "关闭后不记录、不显示；已经保存的怪物名字、技能ID、首轮时间和循环周期不会删除。");

	DFM_CreateLabel(frame, nil, "最大储存记录", 330, -608, 105);
	local maxSavedEdit = CreateFrame("EditBox", "DebuffFilter_ManagerMaxSavedEdit", frame, "InputBoxTemplate");
	maxSavedEdit:SetWidth(72);
	maxSavedEdit:SetHeight(24);
	maxSavedEdit:SetPoint("TOPLEFT", frame, "TOPLEFT", 435, -598);
	maxSavedEdit:SetAutoFocus(false);
	maxSavedEdit:SetMaxLetters(5);
	maxSavedEdit:SetScript("OnEscapePressed", function()
		DebuffFilter_ManagerMaxSavedEdit:SetText(tostring(DebuffFilter_GetMaxSavedMonsterSpellProfiles(DebuffFilter_Config[DebuffFilter_Player])));
		DebuffFilter_ManagerMaxSavedEdit:ClearFocus();
	end);
	maxSavedEdit:SetScript("OnEnterPressed", function() DFM_SetMaxSavedProfiles(); end);
	DFM_CreateLabel(frame, nil, "条", 512, -608, 22);
	local maxSavedSet = DFM_CreateButton(frame, "DebuffFilter_ManagerMaxSavedSet", "应用", 65, 545, -599, DFM_SetMaxSavedProfiles);
	DFM_AttachSimpleTooltip(maxSavedEdit, "目标技能最大储存记录", "限制SavedVariables中永久保存的“怪物名字 + 技能ID”组合数量，默认1000。", "可输入1到10000；降低上限后会立即删除最久未使用的超额记录。");
	DFM_AttachSimpleTooltip(maxSavedSet, "应用储存上限", "保存输入框中的记录上限，并立即执行超额清理。", "每个技能的首轮样本和循环样本仍各自最多保留最近10条。");

	DFM_CreateLabel(frame, nil, "技能播报频道", 35, -652, 100);
	local announceDrop = CreateFrame("Button", "DebuffFilter_ManagerAnnounceDropDown", frame, "UIDropDownMenuTemplate");
	announceDrop:SetPoint("TOPLEFT", frame, "TOPLEFT", 135, -638);
	UIDropDownMenu_SetWidth(105, announceDrop);
	UIDropDownMenu_Initialize(announceDrop, DFM_AnnounceChannelDropDownInitialize);
	local announceHint = DFM_CreateLabel(frame, nil, "左键点击目标技能图标即可播报", 300, -652, 290);
	DFM_AttachSimpleTooltip(announceDrop, "技能播报频道", "选择点击目标技能图标时发送到哪个聊天频道：说、小队、团队或公会。", "这里只设置频道；不会自动播报，必须由你左键点击技能图标。");

	DFM_CreateButton(frame, "DebuffFilter_ManagerBackdrop", "显示/隐藏移动框", 150, 30, -694, function() DebuffFilter_command("backdrop"); end);
	DFM_CreateButton(frame, "DebuffFilter_ManagerRefresh", "刷新显示", 105, 195, -694, function() DebuffFilter_BuffFrame_Update(); DebuffFilter_DebuffFrame_Update(); if (type(DebuffFilter_CurrentTargetBuff_Rescan) == "function") then DebuffFilter_CurrentTargetBuff_Rescan(); end if (type(DebuffFilter_TargetBuff_Rescan) == "function") then DebuffFilter_TargetBuff_Rescan(); end if (type(DebuffFilter_MultiTargetDebuff_Rescan) == "function") then DebuffFilter_MultiTargetDebuff_Rescan(); end DebuffFilter_TargetSpellFrame_Update(); if (DebuffFilter_Extension and type(DebuffFilter_Extension.UpdatePlayerDebuffs) == "function") then DebuffFilter_Extension.UpdatePlayerDebuffs(true); end DFM_SetStatus("显示已刷新。"); end);
	DFM_CreateButton(frame, "DebuffFilter_ManagerChatHelp", "聊天栏完整命令", 145, 315, -694, function() DebuffFilter_command("help"); end);
	DFM_CreateButton(frame, "DebuffFilter_ManagerClose", "关闭", 90, 475, -694, function() DebuffFilter_ManagerFrame:Hide(); end);

	local resetButton = DFM_CreateButton(frame, "DebuffFilter_ManagerReset", "恢复初始设置", 150, 30, -732, function() StaticPopup_Show("DEBUFF_FILTER_RESET_CONFIRM"); end);
	DFM_AttachSimpleTooltip(resetButton, "恢复初始设置", "恢复当前角色的默认监视列表、选项、缩放、排列方向和框体位置。", "操作前会要求确认；配置在 /reload 或退出游戏时写入角色 SavedVariables。");

	local status = frame:CreateFontString("DebuffFilter_ManagerStatus", "OVERLAY", "GameFontNormalSmall");
	status:SetPoint("TOPLEFT", frame, "TOPLEFT", 195, -732);
	status:SetWidth(425);
	status:SetHeight(30);
	DebuffFilter_SetUIFont(status, 12, "OUTLINE");
	status:SetJustifyH("LEFT");
	status:SetJustifyV("TOP");

	local helpLine = frame:CreateTexture(nil, "ARTWORK");
	helpLine:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border");
	helpLine:SetTexCoord(0.81, 0.94, 0.5, 1);
	helpLine:SetVertexColor(0.4, 0.4, 0.4);
	helpLine:SetWidth(605);
	helpLine:SetHeight(3);
	helpLine:SetPoint("TOP", frame, "TOP", 0, -772);

	local helpTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	helpTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -790);
	DebuffFilter_SetUIFont(helpTitle, 13, "OUTLINE");
	helpTitle:SetText("|cFFFFD100常用命令说明|r");

	local help = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	help:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -812);
	help:SetWidth(590);
	help:SetHeight(96);
	DebuffFilter_SetUIFont(help, 11, "OUTLINE");
	help:SetJustifyH("LEFT");
	help:SetJustifyV("TOP");
	help:SetText(
		"/dfilter 或 /dfui：打开/关闭本窗口    /dfilter help：完整命令\n" ..
		"/dfilter dadd 名称：添加目标 Debuff    /dfilter ddel 名称：删除\n" ..
		"/dfilter tbadd 名称：添加多人目标 Buff    /dfilter tbtime 名称 秒：设置持续时间\n" ..
		"Ctrl+左键点目标头像附近的 Debuff：快捷添加目标 Debuff\n" ..
		"Ctrl+左键点系统玩家 Debuff：快捷添加/移除自身 Debuff\n" ..
		"Shift+左键拖动自身Buff、自身Debuff、目标Debuff、当前目标Buff、多人目标Buff或技能监视：独立移动位置\n" ..
		"/dfilter dtime 名称 秒数：设置预测时间    /dfilter dscan：扫描目标\n" ..
		"/dfilter add 名称：添加自身 Buff    /dfilter reset：恢复当前角色初始设置"
	);

	frame:SetScript("OnShow", function()
		DFM_RefreshChecks();
		DebuffFilter_Manager_SelectMode(DebuffFilter_ManagerState.mode or "debuff");
		if (DebuffFilter_ManagerState.mode == "buff" or DebuffFilter_ManagerState.mode == "debuff" or DebuffFilter_ManagerState.mode == "playerdebuff" or DebuffFilter_ManagerState.mode == "currenttargetbuff" or DebuffFilter_ManagerState.mode == "targetbuff" or DebuffFilter_ManagerState.mode == "multidebuff") then DFM_ScanTarget(); end
	end);
end

function DebuffFilter_Manager_Toggle()
	if (not DebuffFilter_Player or not DebuffFilter_Config or not DebuffFilter_Config[DebuffFilter_Player]) then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Buff监视：配置尚未初始化，请稍后再试或执行 /reload。|r");
		return;
	end

	if (not getglobal("DebuffFilter_ManagerFrame")) then
		DFM_CreateManagerFrame();
	end

	local manager = getglobal("DebuffFilter_ManagerFrame");
	if (not manager) then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Buff监视：内置管理窗口创建失败。|r");
		return;
	end

	if (manager:IsVisible()) then
		manager:Hide();
	else
		manager:Show();
		manager:Raise();
	end
end

DebuffFilter_ManagerLoaded = 1;
