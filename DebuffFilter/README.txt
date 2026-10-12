DebuffFilter v1.14.8 - 敌人技能黑名单手动添加

- “敌人技能 -> 黑名单”新增技能ID输入框与“加入黑名单”按钮。
- 输入技能ID后可点击按钮或直接按 Enter 添加；添加成功后自动清空输入框。
- 手动添加与 Alt+左键共用同一套 SavedVariables 黑名单和完全跳过监视逻辑。
- 黑名单搜索、解除、分页继续保留；为给手动添加区留空间，每页显示 6 条。
- 保留 v1.14.7 FuBar 首次打开修复与 v1.14.4 战斗性能热修逻辑。

DebuffFilter v1.14.7 - FuBar 首次打开修复

- 修复 v1.14.6 第一次点击 FuBar 打开设置时 PositionHelpControls 为 nil 的报错。
- 恢复帮助页 PositionHelpControls 与底部通用按钮 PositionCommonControls。
- 保留 v1.14.6 敌人技能黑名单、Alt+左键拉黑、SavedVariables 与完全跳过监视逻辑。
- 不改动 v1.14.4 战斗性能热修逻辑。

DebuffFilter v1.14.6 - 敌人技能黑名单
- 敌人技能图标支持 Alt+左键直接加入全局技能黑名单。
- 黑名单保存在角色 SavedVariables：DebuffFilter_Config.target_spell_blacklist。
- 命中黑名单后从敌人技能监视最前段直接跳过，不建立 runtime、不加载学习资料、不创建图标/计时。
- 已经学习好的怪物首轮/循环永久资料不删除；解除黑名单后可继续使用。
- “敌人技能”页新增二级菜单“监视设置 / 黑名单”。
- 黑名单页提供技能名 / SpellID 搜索、列表分页与“解除”按钮。
- 不改 v1.14.4 的战斗性能优化与 v1.14.5 的中文字体兼容修复。

DebuffFilter v1.14.5 - 中文字体兼容修复
- 修复 MoonUI 顶部页签、左侧菜单、按钮、复选项、说明文字等中文全部不显示的问题。
- 删除插件 UI 对 Fonts\\FRIZQT__.TTF 的硬编码，改为继承客户端 GameFontHighlight 当前字体文件。
- 同步修复目标技能“首轮中/学习中”、自身减益类型文字、计时数字等插件自建字体区域。
- 不修改 v1.14.4 的 dirty-unit 0.15 秒合并扫描、2 秒全量兜底、TimerBars idle、OnlyMine 与流光性能逻辑。
- DebuffFilter.toc 版本号同步更新为 1.14.5。

DebuffFilter v1.14.4 - 战斗性能热修
- “周围敌人技能监测”关闭后，姓名板扫描、技能框10Hz刷新和技能施法解析真正停止。
- “只显示我施加的 Buff / Debuff”关闭时，不再处理来源追踪；开启时只解析玩家自己的施法。
- 当前目标Buff、多人Buff、多人Debuff的 UNIT_CASTEVENT 先按目标GUID过滤，再解析技能。
- 修复核心卡顿：UNIT_AURA 不再让“多人增益/多人减益”立刻整团全量扫描；改为0.15秒合并后只扫描变化单位，全团扫描降为2秒兜底。
- TimerBars 不再在“图标框/关闭”模式下无条件每0.2秒重扫六组光环；完全不需要计时条/多人图标/流光时进入空闲。

DebuffFilter v1.13.3

一、计时条来源
- 计时条底层使用用户提供的 CandyBar-2.2.lua。
- 保留原始双 StatusBar、分组、排序、倒计时、反向填充、纹理、缩放、间距、渐隐和完成回调逻辑。
- 库名改为 DebuffFilterCandyBar-2.2，仅用于隔离运行状态；原作者声明保留在源码头部。
- 不加载 Chronometer 插件本体，也不共享 Chronometer 的 CandyBar 处理器、分组、默认设置和框体池。

二、双 StatusBar 结构
- statusbarbg：底层，固定 100%，显示背景颜色与背景透明度。
- statusbar：中层，按剩余时间变化。
- timertext / text：前景 StatusBar 的 OVERLAY 层。

三、显示模式
管理窗口顶部“计时条”页可分别设置：
- 我的增益
- 我的减益
- 目标增益
- 目标减益
- 多人增益
- 多人减益
每组均可选择：图标框 / 计时条 / 关闭。

四、右键
- 计时条没有右键隐藏、右键删除或临时关闭功能。
- 多人图标也只注册左键。

五、依赖
- 仍依赖同级 !Libs 提供 AceLibrary、AceOO-2.0、AceEvent-2.0、PaintChips-2.0。
- 不依赖 Chronometer 插件。

六、安装
完整删除旧 DebuffFilter 文件夹，再放入此版本。
首次载入会重置旧实验计时条的样式字段，但不会删除六类监视名单或持续时间规则。


DebuffFilter v1.13.1 - 大图案状态条纹理
新增 10 张 256x32、32 位 RGBA TGA：大爱心、大爪印、大兔子、大猫咪、大熊、大机器人、大齿轮、大月星、萌宠组合、科技终端。
全部为灰白中性色，可同时作为 CandyBar 前景与背景纹理进行 RGB 染色。设置路径：/df -> 计时条 -> 外观样式 -> 条纹理。
