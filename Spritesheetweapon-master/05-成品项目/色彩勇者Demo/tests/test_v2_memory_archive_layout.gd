extends SceneTree

const MAIN_SCENE = preload("res://scenes/Main.tscn")
const SPECTRUM_CARD = preload("res://scripts/SpectrumCard.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main: Control = MAIN_SCENE.instantiate() as Control
	root.add_child(main)
	await process_frame
	main.show_memory_archive(false)
	await process_frame
	await process_frame

	var summary_grid: GridContainer = main.find_child("MemorySetSummaryGrid", true, false) as GridContainer
	_expect(summary_grid != null, "记忆档案必须创建记忆组摘要网格。")
	if summary_grid != null:
		_expect(summary_grid.size.x >= 900.0, "记忆组摘要网格必须占满可用横向空间。")
		for child in summary_grid.get_children():
			if child is Label:
				_expect(child.size.x >= 250.0, "记忆组摘要不得被压成单字符竖排。")

	var spectrum_card: PanelContainer = SPECTRUM_CARD.new()
	root.add_child(spectrum_card)
	spectrum_card.setup({
		"id": "layout_test",
		"instance_id": "layout_test_1",
		"name": "凝霜格",
		"color": "blue",
		"rarity": "rare",
		"condition": "本回合蓝色累计 6",
		"progress": "蓝 0/6",
		"effect": "获得 14 护盾",
	})
	_expect(spectrum_card.effect_label.text.contains("基础 13 伤害"), "色谱卡必须显示稀有度基础谱式伤害。")
	_expect(spectrum_card.effect_label.text.contains("获得 14 护盾"), "色谱卡必须同时显示卡牌附加效果。")
	spectrum_card.free()

	var game_manager: Node = root.get_node("GameManager")
	game_manager.reset_run()
	game_manager.configure_starting_archetype("red")
	game_manager.apply_vow("vow_witness")
	for memory_id in ["M04", "M05", "M06"]:
		if not game_manager.unlocked_memory_ids.has(memory_id):
			game_manager.unlocked_memory_ids.append(memory_id)
	main.show_route_pool_selection()
	await process_frame
	var previous_templates: Dictionary = game_manager.map_template_ids.duplicate(true)
	main._commit_route_pool_choice("invalid_pool")
	_expect(not main.route_pool_choice_committed, "无效路线池不得锁死路线选择。")
	_expect(game_manager.map_template_ids == previous_templates, "无效路线池必须回退到提交前的三章路线。")

	_expect(game_manager.select_map_template_pool("archive"), "已解锁档案路线后必须能够切换到失色档案馆地图池。")
	var archive_node_ids: Array[String] = main._chapter_map_node_ids("C1")
	for required_id in ["C1-00", "C1-01", "C1-02R", "C1-03R", "C1-04R", "C1-04S", "C1-05R", "C1-06R", "C1-07", "C1-08"]:
		_expect(archive_node_ids.has(required_id), "档案地图必须显示当前模板可达节点 %s。" % required_id)
	for unreachable_id in ["C1-02A", "C1-03A", "C1-03B", "C1-05D"]:
		_expect(not archive_node_ids.has(unreachable_id), "档案地图不得混入其他路线池的不可达节点 %s。" % unreachable_id)

	if failures.is_empty():
		print("V2 UI runtime tests passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
