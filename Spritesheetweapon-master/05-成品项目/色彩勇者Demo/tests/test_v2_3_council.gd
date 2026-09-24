extends SceneTree

const COUNCIL_SCRIPT = preload("res://scripts/StrategyCouncil.gd")

var failures: Array[String] = []
var passed: int = 0

class FakeProjects extends RefCounted:
	var entries: Array[Dictionary] = [
		{"id": "forge", "name": "熔彩工坊", "color": "red", "description": "建设章节工坊。", "coin_cost": 30, "pigment_cost": 1, "target": 2, "effects": {"spectrum_base_damage": 3}},
		{"id": "sanctuary", "name": "净色花园", "color": "blue", "description": "建设章节花园。", "coin_cost": 30, "pigment_cost": 1, "target": 2, "effects": {"first_turn_shield": 4}}
	]

	func options() -> Array[Dictionary]:
		return entries.duplicate(true)

	func status(chapter: String) -> Dictionary:
		if chapter == "C1":
			return {"id": "archive", "name": "修复档案塔", "progress": 1, "target": 3, "completed": false}
		return {}

class FakeManager extends Node:
	var chapter_policies: Dictionary = {"C1": "red_accord"}
	var projects: RefCounted = FakeProjects.new()

	func get_strategy_chapter_id() -> String:
		return "C1"

	func can_choose_policy() -> bool:
		return true

	func get_policy_options() -> Array[Dictionary]:
		return [
			{"id": "order", "name": "守序协议", "color": "blue", "summary": "让章节路线更稳定。"},
			{"id": "witness", "name": "见证协议", "color": "gold", "summary": "提高档案与资源机会。"},
			{"id": "risk", "name": "破谱协议", "color": "red", "summary": "承担风险换取更强回报。"},
			{"id": "archive", "name": "档案协议", "color": "green", "summary": "把章节线索集中到档案项目。"}
		]

	func get_selected_policy() -> Dictionary:
		return {"id": "red_accord", "name": "红焰协定", "color": "red", "summary": "红色更容易出现。"}

	func can_start_project(project_id: String) -> bool:
			return project_id == "forge"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: FakeManager = FakeManager.new()
	root.add_child(manager)
	var council: Control = COUNCIL_SCRIPT.new()
	root.add_child(council)
	council.build(manager)
	await process_frame
	_check(council.find_child("CouncilTitle", true, false) != null, "must show council title")
	_check(council.find_child("CouncilBack", true, false) != null, "must expose CouncilBack")
	_check(council.find_child("Policy_order", true, false) != null, "must create policy button by id")
	_check(council.find_child("Project_forge", true, false) != null, "must create project button by id")
	_check(council.find_child("Project_sanctuary", true, false).disabled, "project button must use can_start_project")
	_check(council.find_child("History_C1", true, false) != null, "must show chapter history")
	_check(council.find_child("Progress_C1", true, false) != null, "must show C1 project progress")
	_check(council.find_child("Progress_C2", true, false) != null, "must show C2 project progress")
	_check((council.find_child("History_C1", true, false) as Label).text.contains("红焰协定"), "history must resolve policy id through StrategyRules")
	_check((council.find_child("ProjectCost_forge", true, false) as Label).text.contains("金币"), "project must show explicit cost")
	_check((council.find_child("ProjectCard_forge", true, false).find_child("Label", true, false) == null), "project effects must not call effect_total for display")
	_check(council.find_child("CouncilBackdrop", true, false) != null, "must show archive backdrop")
	var backdrop: TextureRect = council.find_child("CouncilBackdrop", true, false) as TextureRect
	_check(backdrop != null and backdrop.texture != null, "archive backdrop texture must be non-empty")
	for project_id in ["forge", "sanctuary"]:
		var project_art: TextureRect = council.find_child("ProjectArt_%s" % project_id, true, false) as TextureRect
		_check(project_art != null, "project %s must expose building art" % project_id)
		_check(project_art != null and project_art.texture != null, "project %s art must have a texture" % project_id)
		_check(project_art != null and project_art.custom_minimum_size.y >= 64.0, "project %s art needs stable height" % project_id)
	_check(council.size.x >= 1.0, "council must be a Control")
	var policy_ids: Array[String] = []
	council.policy_selected.connect(func(policy_id: String) -> void: policy_ids.append(policy_id))
	var policy_button: Button = council.find_child("Policy_order", true, false) as Button
	policy_button.pressed.emit()
	_check(policy_ids == ["order"], "policy button must emit policy id")
	var back_count: Array[int] = [0]
	council.back_requested.connect(func() -> void: back_count[0] += 1)
	var back_button: Button = council.find_child("CouncilBack", true, false) as Button
	back_button.pressed.emit()
	_check(back_count == [1], "back button must emit once")
	await _check_viewport(manager, council, Vector2i(1280, 720), "1280x720")
	await _check_viewport(manager, council, Vector2i(1600, 900), "1600x900")
	for failure in failures:
		push_error(failure)
	print("V2.3 council: %d passed, %d failures" % [passed, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)

func _check_viewport(manager: FakeManager, council: Control, viewport_size: Vector2i, label: String) -> void:
	root.size = viewport_size
	council.size = viewport_size
	council.build(manager)
	await process_frame
	await process_frame
	var policy_grid: GridContainer = council.find_child("PolicyGrid", true, false) as GridContainer
	var project_grid: GridContainer = council.find_child("ProjectGrid", true, false) as GridContainer
	_check(policy_grid != null and policy_grid.columns == 4, label + ": policy grid must remain four columns")
	_check(project_grid != null and project_grid.columns == 3, label + ": project grid must remain three columns")
	if policy_grid != null and policy_grid.get_child_count() > 1:
		var policy_width: float = (policy_grid.get_child(0) as Control).size.x
		for child in policy_grid.get_children():
			_check(absf((child as Control).size.x - policy_width) <= 1.0, label + ": policy cards must have equal widths")
	if project_grid != null and project_grid.get_child_count() > 1:
		var project_width: float = (project_grid.get_child(0) as Control).size.x
		for child in project_grid.get_children():
			_check(absf((child as Control).size.x - project_width) <= 1.0, label + ": project cards must have equal widths")
	for section_name in ["PolicySection", "ProjectSection", "ProgressSection"]:
		var section: Control = council.find_child(section_name, true, false) as Control
		_check(section != null and not section is PanelContainer, label + ": sections must not be outer panels")
	for label_node in council.find_children("*", "Label", true, false):
		var text_label: Label = label_node as Label
		_check(text_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, label + ": labels must autowrap")
	var viewport_texture: ViewportTexture = root.get_texture()
	if viewport_texture != null and DisplayServer.get_name() not in ["headless", "dummy"]:
		var image: Image = viewport_texture.get_image()
		var output_path: String = "C:/Users/15537/.codex/visualizations/council_%s.png" % label
		_check(image != null and image.save_png(output_path) == OK, label + ": screenshot must save")
