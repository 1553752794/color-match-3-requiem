# Claude Code Game Studios -- 游戏工作室代理架构

通过 48 个协同的 Claude Code 子代理管理独立游戏开发。
每个代理负责特定领域，强制关注点分离和质量控制。

## 技术栈

- **项目**：色彩勇者：三消镇魂曲 MVP Demo
- **主项目路径**：`Spritesheetweapon-master/05-成品项目/色彩勇者Demo/`
- **引擎**：Godot 4.6（项目配置仍可兼容 Godot 4.5 说明文档）
- **语言**：GDScript
- **版本控制**：当前根目录存在空 `.git` 目录，但尚未形成有效 Git 工作树
- **构建系统**：Godot 导出模板
- **资产管线**：Godot 导入系统；像素角色、UI 和音频资源已随项目提交

> **注意**：Godot、Unity 和 Unreal 都有专属的引擎专家代理，
> 配备专门的子专家。请使用与你引擎匹配的代理集。

## 当前游戏概况

- 玩法定位：休闲三消 + RPG 回合制战斗，单机 MVP Demo。
- 入口场景：`res://scenes/Main.tscn`
- Autoload：`GameManager` -> `res://scripts/GameManager.gd`
- 核心脚本：`Board.gd` 负责棋盘三消，`BattleManager.gd` 负责战斗和技能结算，`Main.gd` 负责菜单、地图、战斗、奖励和结算 UI。
- 已实现内容：主菜单、三节点路线、普通/精英/Boss 战、7x7 棋盘、连消、燃烧/冻结/护盾、金币、三种颜色技能、胜利奖励和结算倾向。
- 近期扩展方向：8 色系统、商店/遗物/事件、多路线地图、敌人意图与抗性、UI 场景拆分、粒子/音效混音、存档与局外成长。

## 项目结构

@.claude/docs/directory-structure.md

## 引擎版本参考

@docs/engine-reference/godot/VERSION.md

## 技术偏好

@.claude/docs/technical-preferences.md

## 协调规则

@.claude/docs/coordination-rules.md

## 协作协议

**用户驱动的协作，而非自主执行。**
每个任务遵循：**提问 -> 选项 -> 决定 -> 草稿 -> 审批**

- 代理在使用 Write/Edit 工具之前必须询问"可以将此内容写入 [文件路径] 吗？"
- 代理必须在请求审批之前展示草稿或摘要
- 多文件变更需要明确批准整个变更集
- 没有用户指示，不得进行任何提交

完整协议和示例请参见 `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`。

> **第一次使用？** 如果项目没有配置引擎且没有游戏概念，
> 运行 `/start` 开始引导式入门流程。

## 编码标准

@.claude/docs/coding-standards.md

## 上下文管理

@.claude/docs/context-management.md
