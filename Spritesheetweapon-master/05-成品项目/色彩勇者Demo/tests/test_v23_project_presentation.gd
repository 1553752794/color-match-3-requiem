extends SceneTree

const COUNCIL = preload("res://scripts/StrategyCouncil.gd")
const PROJECTS = preload("res://scripts/ChapterProjects.gd")

var failures: Array[String] = []
var passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: Node = root.get_node("GameManager")
	manager.reset_run()
	manager.apply_start_choice("red")
	_check(manager.apply_vow("vow_witness"), "actual opening accepts vow")
	_check(manager.apply_policy("red_accord"), "actual opening accepts policy")
	manager.run_phase = "map"
	manager.coins = 90
	manager.pigment = 3
	var council: Control = COUNCIL.new()
	root.add_child(council)
	var expected_benefits: Dictionary = {
		"forge": "色谱基础伤害 +3",
		"sanctuary": "每场开局护盾 +4",
		"exchange": "商店价格 -5%",
	}
	council.build(manager)
	await process_frame
	var textures: Array[Texture2D] = []
	for option in PROJECTS.new().options():
		var id: String = option["id"]
		var art: TextureRect = council.find_child("ProjectArt_" + id, true, false) as TextureRect
		_check(art != null and art.texture != null, id + ": real project has building texture")
		if art != null and art.texture != null:
			_check(not textures.has(art.texture), id + ": building is distinct")
			textures.append(art.texture)
			var image: Image = art.texture.get_image()
			_check(image != null and image.get_used_rect().has_area(), id + ": art is not blank")
			_check(art.mouse_filter == Control.MOUSE_FILTER_IGNORE, id + ": artwork cannot intercept input")
		_check(council._effects_text(option) == expected_benefits[id], id + ": benefit uses Chinese and correct units")
	_check(council._effects_text({"effects": {"future_effect": 2}}) == "future_effect +2", "unknown numeric effect remains readable")
	var fallback: Control = council._build_project_card({"id": "future_project", "name": "未来项目"})
	root.add_child(fallback)
	var fallback_art: TextureRect = fallback.find_child("ProjectArt_future_project", true, false) as TextureRect
	_check(fallback_art != null and fallback_art.texture == null, "unknown project keeps text fallback")
	fallback.queue_free()
	_check(manager.start_project("forge"), "can start actual project")
	manager.projects.advance("C1-01", "combat")
	council.build(manager)
	await process_frame
	_check(_button_text(council, "forge") == "建设中 1/2", "active project shows real progress")
	_check(_button_text(council, "sanctuary") == "本章已选其他项目", "alternative projects explain lock")
	manager.projects.advance("C1-04A", "elite")
	council.build(manager)
	await process_frame
	_check(_button_text(council, "forge") == "已完工", "completed project shows completion")
	_check((council.find_child("Project_forge", true, false) as Button).disabled, "completed project cannot be restarted")
	manager.projects = PROJECTS.new()
	manager.coins = 0
	council.build(manager)
	await process_frame
	_check(_button_text(council, "exchange") == "资源不足", "unaffordable project explains lock")
	for failure in failures:
		push_error(failure)
	print("V2.3 project presentation: %d passed, %d failed" % [passed, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _button_text(council: Control, id: String) -> String:
	var button: Button = council.find_child("Project_" + id, true, false) as Button
	return button.text if button != null else ""

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
