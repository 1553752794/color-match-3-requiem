extends SceneTree

const MAIN_SCENE = preload("res://scenes/Main.tscn")

var output_dir: String = ""
var main: Control
var game_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	output_dir = args[0] if not args.is_empty() else OS.get_user_data_dir().path_join("v2_ui_qa")
	var viewport_width: int = clampi(int(args[1]) if args.size() > 1 else 1280, 960, 2560)
	var viewport_height: int = clampi(int(args[2]) if args.size() > 2 else 720, 540, 1440)
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(viewport_width, viewport_height)
	main = MAIN_SCENE.instantiate() as Control
	root.add_child(main)
	game_manager = root.get_node("GameManager")
	await _capture("01_main_menu.png")

	game_manager.reset_run()
	main.show_start_node()
	await _capture("02_character_selection.png")

	game_manager.configure_starting_archetype("red")
	main.show_vow_selection()
	await _capture("03_vow_selection.png")

	game_manager.apply_vow("vow_witness")
	for memory_id in ["M04", "M05", "M06"]:
		if not game_manager.unlocked_memory_ids.has(memory_id):
			game_manager.unlocked_memory_ids.append(memory_id)
	main.show_route_pool_selection()
	await _capture("04_archive_route_choice.png")

	main.show_memory_archive(false)
	await _capture("05_memory_archive.png")

	game_manager.current_node_id = "C1-00"
	game_manager.visited_nodes["C1-00"] = true
	game_manager.current_options.assign(["C1-01"])
	main.show_map()
	await _capture("06_route_map.png")

	game_manager.current_node_id = "C1-08"
	game_manager.add_relic("gate_badge")
	main.show_battle()
	await _capture("07_combat_resonance.png")
	print("V2.3.0 UI captures written to %s at %dx%d" % [output_dir, viewport_width, viewport_height])
	quit(0)


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
