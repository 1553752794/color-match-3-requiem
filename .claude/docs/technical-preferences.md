# 技术偏好

<!-- 由 /setup-engine 填充。随用户在开发过程中的决策而更新。 -->
<!-- 所有代理参考此文件以获取项目特定的标准和约定。 -->

## 引擎与语言

- **Engine（引擎）**: Godot 4.6
- **Language（语言）**: GDScript
- **Rendering（渲染）**: GL Compatibility（当前 `project.godot` 设置）
- **Physics（物理）**: 2D Godot Physics；当前 Demo 无复杂物理系统

## 命名约定（Naming Conventions）

- **Classes（类）**: PascalCase（如 `BattleManager`）
- **Variables（变量）**: snake_case（如 `current_enemy`）
- **Signals/Events（信号/事件）**: snake_case，优先描述已经发生的事件（如 `health_changed`）
- **Files（文件）**: 现有脚本沿用 PascalCase（如 `GameManager.gd`、`Board.gd`）；新增文件优先与场景/类名保持一致
- **Scenes/Prefabs（场景/预制体）**: PascalCase，与根节点职责匹配
- **Constants（常量）**: UPPER_SNAKE_CASE

## 性能预算（Performance Budgets）

- **Target Framerate（目标帧率）**: 60 FPS
- **Frame Budget（帧预算）**: 16.6ms
- **Draw Calls（绘制调用）**: MVP 阶段保持轻量，新增特效前用 Godot profiler 检查
- **Memory Ceiling（内存上限）**: 暂无硬限制；保持离线单机 Demo 可在普通 PC 上流畅运行

## 测试

- **Framework（框架）**: 尚未接入；如开始自动化测试，优先考虑 GUT
- **Minimum Coverage（最低覆盖率）**: MVP 阶段不设百分比门槛，优先覆盖核心棋盘/战斗结算
- **Required Tests（必需测试）**: 匹配检测、掉落补齐、连消倍率、颜色权重、技能消耗、战斗状态结算

## 禁用模式（Forbidden Patterns）

<!-- 添加不应出现在本项目代码库中的模式 -->
- 在 `_process()` 中连接信号
- 为跨系统调用添加长链 `get_node("../../...")`
- 将平衡数值继续硬编码到多个脚本中而不做集中管理
- 新增功能时绕过 `GameManager` 中已有的局内状态统计

## 允许的库 / 插件（Allowed Libraries / Addons）

<!-- 在此添加已批准的第三方依赖 -->
- 当前 Demo 无外部下载依赖
- 可评估：GUT（Godot 单元测试）

## 架构决策日志（Architecture Decisions Log）

<!-- 快速参考，链接至 docs/architecture/ 中的完整 ADR -->
- [尚无 ADR — 使用 /architecture-decision 创建]
