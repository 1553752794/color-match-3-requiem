extends SceneTree

const MainScene = preload("res://scenes/Main.tscn")

var failures: Array[String] = []
var checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: Node = root.get_node("GameManager")
	manager.reset_run()
	manager.configure_starting_archetype("red")
	manager.current_node_id = "C1-07"
	manager.run_phase = "camp"
	manager.coins = 24
	manager.pigment = 0
	manager.visited_nodes.clear()
	manager.current_options.clear()

	var main: Control = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.show_camp()
	await process_frame

	var refine: Button = _find_button(main.current_screen, "花 25 金币")
	_expect(refine != null, "camp must expose the refine action")
	if refine != null:
		refine.pressed.emit()
		await process_frame
		var toast_continue: Button = _find_button(main.current_screen, "继续")
		_expect(toast_continue != null, "failed camp action must show a continuation toast")
		if toast_continue != null:
			toast_continue.pressed.emit()
			await process_frame
			_expect(_find_button(main.current_screen, "花 25 金币") != null, "failed camp action must reopen camp")
			_expect(not manager.visited_nodes.has("C1-07"), "failed camp action must not settle the node")

	manager.reset_run()
	manager.configure_starting_archetype("red")
	manager.current_node_id = "C1-07"
	manager.run_phase = "camp"
	manager.player_hp = 50
	manager.player_max_hp = 100
	manager.visited_nodes.clear()
	main.show_camp()
	await process_frame
	var heal: Button = _find_button(main.current_screen, "治疗")
	_expect(heal != null, "camp must expose the heal action")
	if heal != null:
		heal.pressed.emit()
		heal.pressed.emit()
		await process_frame
		var success_continue: Button = _find_button(main.current_screen, "继续")
		_expect(success_continue != null, "successful camp action must show a continuation toast")
		_expect(manager.visited_nodes.has("C1-07"), "successful camp action must settle the node once")
		_expect(manager.player_hp == 74, "repeated queued camp clicks must not apply the action twice")
		if success_continue != null:
			success_continue.pressed.emit()
			await process_frame
			_expect(_find_button(main.current_screen, "前往") != null or manager.run_phase == "map", "successful camp action must return to map")

	main.queue_free()
	for failure in failures:
		push_error(failure)
	print("V2.3 camp UI: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)

func _find_button(root_node: Node, text_fragment: String) -> Button:
	for node in root_node.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button != null and button.text.contains(text_fragment):
			return button
	return null

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition and not failures.has(message):
		failures.append(message)
