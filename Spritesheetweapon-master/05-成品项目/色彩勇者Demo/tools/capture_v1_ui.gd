extends SceneTree

const MAIN_SCENE = preload("res://scenes/Main.tscn")

var output_dir: String = ""
var main: Control
var game_manager: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("V1 UI capture started")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	output_dir = args[0] if not args.is_empty() else OS.get_user_data_dir().path_join("v1_ui_qa")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1280, 720)
	main = MAIN_SCENE.instantiate() as Control
	root.add_child(main)
	print("Main scene instantiated")
	game_manager = root.get_node("GameManager")
	await _settle()
	await _capture("01_main_menu.png")
	print("Captured main menu")

	game_manager.reset_run()
	main.show_start_node()
	await _capture("02_ascension_select.png")
	print("Captured ascension select")

	await _capture_chapter_map("C1", "03_chapter1_map.png")
	await _capture_boss("C1-08", "04_chapter1_boss.png")
	await _capture_chapter_map("C2", "05_chapter2_map.png")
	await _capture_boss("C2-08", "06_chapter2_boss.png")
	await _capture_chapter_map("C3", "07_chapter3_map.png")
	await _capture_boss("C3-08", "08_chapter3_boss.png")
	print("V1 UI captures written to %s" % output_dir)
	quit(0)

func _capture_chapter_map(chapter_key: String, filename: String) -> void:
	game_manager.reset_run()
	game_manager.configure_starting_archetype("red")
	if chapter_key == "C1":
		game_manager.current_node_id = "C1-00"
		game_manager.visited_nodes["C1-00"] = true
		game_manager.current_options.assign(["C1-01"])
	else:
		var previous_boss: String = "C1-08" if chapter_key == "C2" else "C2-08"
		game_manager.current_node_id = previous_boss
		game_manager.visited_nodes[previous_boss] = true
		game_manager.current_options.assign(["%s-01" % chapter_key])
	main.show_map()
	await _capture(filename)

func _capture_boss(node_id: String, filename: String) -> void:
	game_manager.reset_run()
	game_manager.configure_starting_archetype("red")
	game_manager.current_node_id = node_id
	game_manager.add_relic("gate_badge")
	if node_id == "C3-08":
		game_manager.add_relic("finale_crown")
		game_manager.color_usage = {"gray": 3, "red": 12, "blue": 11, "gold": 10}
	main.show_battle()
	await _capture(filename)

func _capture(filename: String) -> void:
	await _settle()
	var image: Image = root.get_texture().get_image()
	if image == null:
		push_error("Viewport capture is unavailable with the active display driver.")
		quit(2)
		return
	var error: Error = image.save_png(output_dir.path_join(filename))
	if error != OK:
		push_error("Failed to save %s: %s" % [filename, error_string(error)])

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.08).timeout
