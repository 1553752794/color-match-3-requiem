extends SceneTree

const MAIN_SCENE = preload("res://scenes/Main.tscn")

var output_dir: String
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	output_dir = args[0] if not args.is_empty() else OS.get_user_data_dir().path_join("council-captures")
	var width: int = int(args[1]) if args.size() > 1 else 1280
	var height: int = int(args[2]) if args.size() > 2 else 720
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	root.size = Vector2i(width, height)
	var main: Control = MAIN_SCENE.instantiate() as Control
	root.add_child(main)
	var manager: Node = root.get_node("GameManager")
	manager.reset_run()
	manager.apply_start_choice("red")
	manager.apply_vow("vow_witness")
	if not manager.apply_policy("red_accord"):
		failures.append("Opening policy was not selected.")
	manager.coins = 90
	manager.pigment = 3
	manager.run_phase = "map"
	main.show_strategy_council()
	await _capture(main, "01_available")
	var button: Button = main.current_screen.find_child("Project_forge", true, false) as Button
	button.pressed.emit()
	if manager.projects.status("C1").get("id", "") != "forge" or manager.coins != 60 or manager.pigment != 2:
		failures.append("Project click did not atomically open the forge.")
	manager.projects.advance("C1-01", "combat")
	main.show_strategy_council()
	await _capture(main, "02_building")
	manager.projects.advance("C1-04A", "elite")
	main.show_strategy_council()
	await _capture(main, "03_complete")
	var back: Button = main.current_screen.find_child("CouncilBack", true, false) as Button
	back.pressed.emit()
	if manager.run_phase != "map":
		failures.append("Council back did not return to map.")
	for failure in failures:
		push_error(failure)
	print("Council captures: %s at %dx%d; failures=%d" % [output_dir, width, height, failures.size()])
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _capture(main: Control, state: String) -> void:
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	for position in ["top", "bottom"]:
		var scroll: ScrollContainer = main.current_screen.find_child("CouncilScroll", true, false) as ScrollContainer
		scroll.scroll_vertical = 0 if position == "top" else int(scroll.get_v_scroll_bar().max_value)
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var error: Error = image.save_png(ProjectSettings.globalize_path(output_dir).path_join("%s_%s.png" % [state, position]))
		if error != OK:
			failures.append("Failed to save %s/%s: %s" % [state, position, error_string(error)])
