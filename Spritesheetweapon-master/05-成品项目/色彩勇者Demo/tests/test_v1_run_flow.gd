extends SceneTree

var failures: Array[String] = []
var game_manager: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	game_manager = root.get_node("GameManager")
	game_manager.reset_run()
	game_manager.map_template_ids = {"C1": "standard", "C2": "standard", "C3": "standard"}
	game_manager.set_ascension_level(5)
	_expect(game_manager.apply_start_choice("red").contains("烬歌"), "起始角色应成功结算。")

	_complete_combat("C1-01")
	_complete_event("C1-02B", "shrine", "resource")
	_complete_chest("C1-03B")
	_complete_utility("C1-04C")
	_complete_event("C1-05D", "pigment_well", "seal")
	_complete_combat("C1-06B")
	_complete_camp("C1-07")
	_complete_combat("C1-08")
	_expect(game_manager.relics.has("colorless_crown"), "第一章 Boss 应发放无色冠冕。")

	_complete_combat("C2-01")
	_complete_event("C2-02B", "frozen_archive", "melt")
	_complete_chest("C2-03B")
	_complete_utility("C2-04C")
	_complete_event("C2-05D", "caravan_debt", "borrow")
	_complete_combat("C2-06B")
	_complete_camp("C2-07")
	_complete_combat("C2-08")
	_expect(game_manager.pending_torn_banner_reward, "第二章 Boss 后应进入王旗奖励选择。")
	_expect(not game_manager.choose_node("C3-01"), "王旗选择完成前必须阻止跨章。")
	var copy_target: String = String(game_manager.deck[0].get("instance_id", ""))
	_expect(game_manager.apply_torn_banner_choice("copy", copy_target), "王旗复制奖励应成功结算。")

	_complete_combat("C3-01")
	_complete_event("C3-02B", "crimson_stage", "rest")
	_complete_chest("C3-03B")
	_complete_combat("C3-04B")
	_complete_event("C3-05A", "final_workshop", "temper")
	_expect(game_manager.relics.has("finale_crown"), "终幕工坊路线应能取得终幕花冠。")
	_complete_combat("C3-06A")
	_complete_camp("C3-07")
	_complete_combat("C3-08")

	_expect(game_manager.current_node_id == "C3-08", "整局终点应停留在最终 Boss 节点。")
	_expect(game_manager.visited_nodes.size() == 25, "完整路线应结算起点与三章各 8 层，共 25 个节点。")
	_expect(game_manager.get_available_node_ids().is_empty(), "最终 Boss 后不应再开放地图节点。")
	_expect(not game_manager.pending_torn_banner_reward, "最终 Boss 后不应生成无意义的王旗奖励。")
	_expect(not String(game_manager.get_ending_report(true).get("title", "")).is_empty(), "最终胜利应生成倾向结局报告。")

	if failures.is_empty():
		print("V1 full run flow passed: 25 nodes")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _complete_combat(node_id: String) -> void:
	if not _enter_node(node_id):
		return
	var encounter: Dictionary = game_manager.get_current_encounter()
	_expect(not encounter.is_empty(), "%s 应配置有效遭遇。" % node_id)
	var reward: Dictionary = game_manager.build_battle_reward(encounter)
	var is_boss: bool = String(reward.get("node_type", "")) == "boss"
	var claimed: bool = game_manager.claim_battle_reward("", not is_boss)
	_expect(claimed, "%s 战斗奖励应成功结算。" % node_id)

func _complete_event(node_id: String, event_id: String, choice_id: String) -> void:
	if not _enter_node(node_id):
		return
	var result: String = game_manager.apply_event_choice(event_id, choice_id)
	_expect(not result.contains("无效") and not result.contains("不足"), "%s 事件选项应成功结算。" % node_id)

func _complete_chest(node_id: String) -> void:
	if not _enter_node(node_id):
		return
	var choice: String = "gold" if not game_manager.get_chest_choices().is_empty() else ""
	_expect(not game_manager.apply_chest_reward(choice).is_empty(), "%s 宝箱应成功结算。" % node_id)

func _complete_camp(node_id: String) -> void:
	if not _enter_node(node_id):
		return
	game_manager.apply_camp_choice("scout")
	_expect(game_manager.visited_nodes.has(node_id), "%s 营火应成功结算。" % node_id)

func _complete_utility(node_id: String) -> void:
	if not _enter_node(node_id):
		return
	game_manager.complete_current_node()
	_expect(game_manager.visited_nodes.has(node_id), "%s 功能节点应成功离开。" % node_id)

func _enter_node(node_id: String) -> bool:
	var available: Array[String] = game_manager.current_options
	_expect(available.has(node_id), "%s 必须由上一节点合法开放。" % node_id)
	var entered: bool = game_manager.choose_node(node_id)
	_expect(entered, "%s 应允许通过合法边进入。" % node_id)
	return entered

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
