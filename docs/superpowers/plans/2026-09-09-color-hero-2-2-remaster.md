# 色彩勇者 2.2 重制实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保持 2.1.0 核心规则和存档兼容的前提下，完成色彩勇者 2.2 的体验、视觉和发布重制。

**Architecture:** 沿用现有 `Main.gd`、`BattleManager.gd`、`Board.gd` 和管理器边界；新增轻量的体验状态/反馈事件接口，尽量让 UI 订阅现有信号而不是重写战斗逻辑。视觉素材通过 Infinite Canvas 生成或整理后，以项目资源引用接入 Godot。

**Tech Stack:** Godot 4.6.3、GDScript、PowerShell、现有 Godot headless 测试脚本、Infinite Canvas。

**Spec:** `docs/superpowers/specs/2026-09-09-color-hero-2-2-remaster-design.md`

## Global Constraints

- 保持“纯三消 + 色谱即时结算”，不恢复 1.x 瞄准/发射第二阶段。
- 保持 `Main.tscn`、`GameManager`、`SaveManager`、`SettingsManager` 的现有入口和存档兼容。
- 不编辑 `.godot/imported` 生成元数据。
- 不引入第三方运行时依赖。
- 所有 GDScript 公共函数和变量保持静态类型。
- 每个任务都必须运行对应专项测试，再运行全量 `tools/run_all_tests.ps1`。

---

### Task 1: 建立 2.2 版本与真实启动烟测

**Files:**
- Modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/project.godot`
- Modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/README.md`
- Modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/VERSION_HISTORY.md`
- Create: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/tests/test_v2_2_smoke_contract.gd`

- [ ] 确认启动、主场景和版本号契约。
- [ ] 添加 2.2 烟测测试，至少验证主场景、自动加载和版本号。
- [ ] 使用 Godot headless 编辑器解析并运行专项测试。
- [ ] 启动安全脚本，确认进程可正常创建并退出。

### Task 2: 首局引导状态

**Files:**
- Modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/scripts/SettingsManager.gd`
- Modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/scripts/Main.gd`
- Create: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/tests/test_v2_2_onboarding.gd`

**Interfaces:**
- `SettingsManager.has_seen_onboarding_hint(hint_id: String) -> bool`
- `SettingsManager.mark_onboarding_hint_seen(hint_id: String) -> void`
- `Main._show_onboarding_hint(hint_id: String, text: String) -> void`

- [ ] 先写首局提示状态的失败测试，覆盖未知 key、重复写入和存档往返。
- [ ] 在 SettingsManager 中增加受白名单约束的提示状态。
- [ ] 在角色、誓约和首次战斗节点接入短提示。
- [ ] 验证提示不会改变 Run Save v4 数据。

### Task 3: 战斗反馈事件与 HUD 重制

**Files:**
- Modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/scripts/Board.gd`
- Modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/scripts/BattleManager.gd`
- Modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/scripts/Main.gd`
- Create: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/tests/test_v2_2_combat_feedback.gd`

**Interfaces:**
- `BattleManager.combat_feedback_emitted(feedback: Dictionary)`
- Feedback dictionary keys: `kind`, `title`, `detail`, `color`, `duration`.

- [ ] 先写反馈事件契约测试，覆盖有效交换、色谱完成、共鸣、敌人行动和胜负。
- [ ] 在 BattleManager 中发出类型化反馈信号，不改变伤害和奖励结果。
- [ ] 在 Main 中增加单一反馈层，按优先级合并短消息，避免多层弹窗。
- [ ] 在 Board 中只补充必要的选中/消除视觉钩子，不把 UI 逻辑塞进棋盘。
- [ ] 验证普通消除仍不直接造成敌人 HP 伤害。

### Task 4: 地图和奖励展示迭代

**Files:**
- Modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/scripts/MapCanvas.gd`
- Modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/scripts/Main.gd`
- Modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/tests/test_v2_ui_contract.gd`

- [ ] 先扩展 UI 契约测试，覆盖当前节点、可达节点、地图池和奖励状态层级。
- [ ] 调整地图页信息密度和节点状态表现。
- [ ] 调整奖励页的“获得/跳过/继续”优先级与按钮状态。
- [ ] 验证 archive 路线仍可达，且旧存档恢复逻辑不变。

### Task 5: Infinite Canvas 视觉方向和素材接入

**Files:**
- Create or modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/assets/ui_2_2/*`
- Modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/scenes/Main.tscn`
- Modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/scripts/GameTheme.gd`

- [ ] 读取当前 Infinite Canvas 状态，建立 2.2 视觉方向板和 HUD 参考布局。
- [ ] 生成或整理背景、棋盘格、按钮状态和反馈素材。
- [ ] 将素材复制到项目资源目录，并保持原始比例和可验证命名。
- [ ] 通过 GameTheme 统一颜色、边框、字体层级和高亮色。
- [ ] 运行 1280x720、1600x900 截图检查，确认没有裁切或重叠。

### Task 6: 发布验证与 2.2.0 导出

**Files:**
- Modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/export_presets.cfg`
- Modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/tools/start_game_safe.ps1`
- Modify: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/tools/verify_release_pack.ps1`

- [ ] 运行全量 2.2 测试和编辑器冷解析。
- [ ] 导出 `build/windows/ColorHero-Match3Requiem-2.2.0.exe`。
- [ ] 检查 PCK/ZIP 中必需文件和禁止泄漏文件。
- [ ] 启动导出包进行一次安全烟测。
- [ ] 汇总变更、已修复问题和剩余风险。
