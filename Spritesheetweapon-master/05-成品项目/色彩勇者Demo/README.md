# 色彩勇者：三消镇魂曲 - 断色回廊

Godot 4.6 单机策略构筑游戏。当前目标产品版本为 `2.3.0`，2.4 迭代内容正在接入，主场景为 `res://scenes/Main.tscn`，现行战斗架构为“纯三消 + 色谱卡牌 + 章节策略”。

2.0 的核心原则很明确：普通消除不直接扣除敌人 HP；消除负责产生色素并推进三张色谱，色谱达成后在当前操作链内立即结算伤害、护盾、控制、回复、经济或棋盘改造。战斗没有额外的攻击操作阶段。

## 核心玩法闭环

1. 从烬歌、凛镜、洛恩、弥砂、伊澜五名角色中选择一名，并设置 A0-A10 进阶难度。
2. 选择守序、破谱或见证誓约，确定本局构筑取向和三章默认地图池。
3. 在分支地图中进入战斗、精英、事件、商店、营火、宝箱、角色挑战与 Boss 节点。
4. 战斗中观察敌人意图，从 3 张色谱中选择目标，在 6×6 四色棋盘上完成最多 3 次有效交换。
5. 消除产出色素、触发颜色基础效果并推进色谱；色谱一旦达成，立即按卡面与修正规则结算。
6. 回合结束后敌人执行已公开意图。玩家通过牌组、遗物、角色技能、谱序共鸣和回想调整后续回合。
7. 战后获得金币、颜料、色谱、遗物或记忆，继续三章远征，并以角色、誓约、学派使用和记忆证据生成结局报告。

棋盘基础颜色只有红、蓝、金、灰四种。紫弦、翠生、白昼、黑曜与混色属于色谱学派，不增加棋子颜色。灰格占比超过 72% 时，每个下落链自动净化 2 格；无合法交换时重排且不消耗步数。

## 2.0 系统

## 2.4 战术验证迭代

2.4 保留 Save v4/Profile v1 和现有战斗规则，新增色谱构筑标签、目标色谱标记、首轮交换只读预览、奖励标签展示和流派统计。预览只表达当前交换可确定的首轮消除结果，不承诺预测随机补块产生的全部级联。

本轮暂不加入八色棋盘、完整特殊棋子、角色技能树、城市科技树或大规模新卡扩充。

### 五名角色

- **烬歌**：红焰爆发与燃烧，以生命压力换取高额单卡结算。
- **凛镜**：护盾、冻结与蓄力反制，依靠意图阅读建立优势。
- **洛恩**：金币、颜料和商店效率，把经济转化为牌组质量。
- **弥砂**：净化、破甲与灰蚀利用，在受污染棋盘上反向构筑。
- **伊澜**：多色条件、谱序与受限返奏，操作要求最高。

角色差异同时存在于最大 HP、起始牌组、被动、主动技、专属池和角色挑战中。

### 三项誓约与四类地图池

- **守序之誓**：固定 `standard` 均衡池，共鸣后获得少量护盾。
- **破谱之誓**：固定 `risk` 高风险池，以最大 HP 为代价强化输出。
- **见证之誓**：固定 `economy` 事件经营池，提高记忆发现和资源选择。
- **`archive` 档案池**：解码任意完整记忆组后出现的第四类章节模板，偏向档案事件、档案精英和记忆线索。

每章数据目录均有四类可复现地图模板。地图支持鼠标滚轮缩放、左键空白区或中键拖拽、按钮缩放和一键复位；三项誓约对应的默认模板与路线由 Seed 派生并写入局内状态。`archive` 在 Profile 完成任意一组非初始记忆后开放；默认发现的 M01-M03 仅承担入门叙事，不会直接解锁。未满足条件时会回退到誓约默认池，Run Save v4 会清洗伪造模板。

### 谱序共鸣

- 上一玩家回合最后达成的有效色谱为“引音”，下一回合第一张有效色谱为“应音”。
- 第一回合没有引音；从第二回合起每回合最多触发一次。
- 九学派映射为同频和声、紫弦折射、翠生回路、熔金脉冲、白昼三和、消色回声六类规则。
- 共鸣只修改应音色谱的当次结算，不创建独立攻击对象。
- HUD 显示引音、尾音、预计共鸣和本回合消费状态；结算记录共鸣率与六类触发次数。

### 记忆与碎片化叙事

- 正式档案为 **30 枚记忆 M01-M30**，组成 **10 组完整记忆**，每组固定 3 枚。
- 默认发现 M01-M03；重复发现转化为记忆墨。
- 每局最多装备 3 枚回想，提供受上限约束的开局、色谱、谱序、灰蚀、经济或战后效果。
- 30 枚记忆通过十组互相矛盾的证词揭示断色历史，并解锁档案地图、事件选项、Boss 干预和复调终局证据。
- 永久发现写入 Profile v1；局内装备、地图、节点奖励和事件链写入 Run Save v4。

## 内容规模

- 5 名角色、3 章、3 名 Boss、6 场角色挑战。
- 119 张色谱：116 张可收集色谱与 3 张事件诅咒。
- 72 件遗物。
- 54 个事件，其中 18 个为 2.0 碎片叙事事件。
- 30 枚记忆、10 组完整记忆、3 个回想槽。
- 每章 `standard`、`risk`、`economy`、`archive` 四类地图模板。
- A0-A10 逐级增加敌人、经济、灰蚀、锁格、封谱与抗性压力，并设置硬上限。

## 当前实现与发布边界

项目数据已包含 119 张色谱、72 件遗物、54 个事件、30 枚记忆、10 组记忆、79 个地图节点和三章四类地图模板；项目目标版本为 2.3.0，Run Save v4 与 Profile v1 已建立。第四类地图的目录、真实分支、模板修正、Profile 解锁条件和存档白名单均已接入。2.3 新增复兴议会、章节政策和路线建设项目。`production/gameplay-design/v2_0_*_spec.md` 是 2.0 规则基线，2.2 侧车规格与审计见 `production/gameplay-design/v2_2_remaster_spec.md` 和 `v2_2_audit_report.md`，2.3 规格见 `production/gameplay-design/v2_3_strategy_spec.md`。

仓库仍保留 1.2-1.5 的兼容模块与历史测试，用于旧档迁移和版本回归。它们的存在不代表对应机制仍属于当前 2.0。纯三消发布验收必须单独确认：普通消除伤害为 0、色谱即时结算、当前 UI 无第二操作层、档案池可达，以及新的统计与边界测试通过。

## 存档

- `user://run_save.json`：Run Save v4，保存角色、誓约、A0-A10、牌组、遗物、三章地图模板、路线、事件链、回想槽、奖励领取状态和单局统计。
- `user://profile_save.json`：Profile v1 当前保存 M01-M30 发现状态、最多 3 个回想装备和记忆墨；十组完成状态由已发现 ID 计算。
- v1-v3 局内存档按迁移链升级到 v4；未知 ID、非法地图模板、重复槽位和越界数值会被清洗或回退。
- 2.1 已加入战斗稳定检查点恢复：进程中断后可恢复棋盘、敌人、回合、手牌与战斗上下文；不提供任意时刻手动存档。
- 损坏的 Run Save 不得覆盖有效 Profile。

## 代码结构

- `scripts/GameData.gd`：色谱、遗物、事件、角色、敌人和三章地图数据。
- `scripts/GameManager.gd`：远征状态、地图、奖励、商店、事件、誓约、记忆与结局。
- `scripts/BattleManager.gd`：色素、色谱即时结算、谱序、主动技、敌人意图和胜负。
- `scripts/SpectrumManager.gd`：三张手牌的条件进度、达成队列与实例状态。
- `scripts/SpectrumResolution.gd`：色谱效果、修正、伤害和资源结算。
- `scripts/ResonanceSequence.gd`：跨回合引音、应音与六类共鸣。
- `scripts/Board.gd`：6×6 棋盘、匹配、下落、级联、污染、净化与重排。
- `scripts/NarrativeMemory.gd`：三项誓约、30 枚记忆、10 组档案与三槽边界。
- `scripts/SaveManager.gd`：Run Save v4、Profile v1、校验与旧档迁移。
- `scripts/RunStats.gd`：有效交换、色谱达成、共鸣、伤害、资源和结局统计。
- `scripts/Main.gd`：菜单、角色/誓约、档案、地图、战斗 HUD、奖励与结局界面。

## 启动

环境要求：Godot `4.6.x`。项目运行时使用 GDScript；主场景为 `res://scenes/Main.tscn`。

在本目录打开编辑器：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\start_editor_safe.ps1 -GodotCommand "D:\Godot_v4.6.3-stable_mono_win64\godot.cmd"
```

当前开发机的 Nahimic/Alienware Sound Center `DynamicSMProfileDaemonModule.dll` 存在循环 `0xc0000005` 崩溃，会干扰 Godot 进程退出并产生 Windows 错误弹窗。因此仓库内编辑器、测试、截图和导出命令默认使用 `--audio-driver Dummy`。这只影响开发自动化的声音输出，不会移除正式游戏中的音频资源；系统音效驱动修复后可向安全脚本传入 `-AudioDriver ""` 恢复默认驱动。

在编辑器中按 `F6` 运行主场景，或按 `F5` 运行项目。也可以直接启动：

```powershell
godot.cmd --audio-driver Dummy --path .
```

## 测试

配置与脚本解析：

```powershell
godot.cmd --audio-driver Dummy --headless --path . --editor --quit
```

2.0 核心与内容测试：

```powershell
godot.cmd --audio-driver Dummy --headless --path . --script res://tests/test_v2_core.gd
godot.cmd --audio-driver Dummy --headless --path . --script res://tests/test_v2_content.gd
godot.cmd --audio-driver Dummy --headless --path . --script res://tests/test_spectrum_resolution.gd
```

运行全部测试脚本（会把 `SCRIPT ERROR` 和引擎 `ERROR` 视为失败）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_all_tests.ps1
```

旧版本测试只证明兼容历史未被破坏，不能替代现行纯三消专项验收。当前共有 48 个测试脚本，最终结果以 `tools/run_all_tests.ps1` 当次输出为准。2.3 补充议会真实项目美术与收益展示、营地失败重试、重复操作防护和 Boss 后跨章政策读档回归。

## Windows 导出

编辑器中选择 `项目 -> 导出`，使用项目中对应的 Windows Release 预设。导出使用安装模板的正常用户目录；自动化运行测试使用独立存档目录。

```powershell
godot.cmd --audio-driver Dummy --headless --path . --export-release "Windows 2.3.0 Release" "build/windows/ColorHero-Match3Requiem-2.3.0.exe"
```

启动已导出的 Windows 包时，使用安全入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\start_game_safe.ps1
```

预设输出 `build/windows/ColorHero-Match3Requiem-2.3.0.exe`，目标为 Windows x86_64，PCK 内嵌。`tests/*`、`tools/*`、`build/*`、`artifacts/*`、`Godot/*`、候选素材库 `assets/external/*` 和未使用的 `assets/audio/bg.ogg` 不进入发布包。三张议会建筑使用 `assets/strategy/council/` 下的运行时副本。

## 已退役架构说明

以下仅用于识别旧文档、旧档和历史测试，不定义当前玩法：1.2-1.5 曾采用“棋谱生成谱弹，再进入瞄准与钉盘结算”的双阶段结构，并包含弹珠、钉点、主球与多球等术语。该架构在 2.0 已退役；现行规则以色谱达成后的即时结算为准。完整历史见 `VERSION_HISTORY.md` 的“已退役架构历史（1.2-1.5）”。
