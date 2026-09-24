extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.reset_run()
	gm.configure_starting_archetype("red")
	gm.apply_vow("vow_order")
	gm.current_node_id = "C1-01"
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	main.show_battle()
	await process_frame
	await process_frame
	var ribbon: Node = main.current_screen.find_child("CombatFeedback", true, false)
	_expect(ribbon != null, "Battle must have one nonblocking feedback ribbon.")
	_expect(main.spectrum_row.size.x >= 750.0, "Three spectra must have sufficient width at 1280.")
	var return_button: Button = main.current_screen.find_child("BattleReturn", true, false)
	_expect(return_button != null, "Stable battles must expose a safe return action.")
	if return_button != null:
		main.board.busy = true
		var locked_screen: Control = main.current_screen
		return_button.pressed.emit()
		_expect(main.current_screen == locked_screen, "Cannot exit during a board resolution.")
		main.board.busy = false
	var original_screen: Control = main.current_screen
	# Repeated HUD updates must not leave queued-for-deletion cards in layout.
	main._refresh_spectrum_cards(main.last_state.get("cards", []))
	main._refresh_spectrum_cards(main.last_state.get("cards", []))
	_expect(main.spectrum_row.get_child_count() == main.last_state.get("cards", []).size(), "HUD refresh must replace cards synchronously.")
	main.show_main_menu()
	var backdrop: Control = main.current_screen.find_child("ChromaticHall", true, false)
	_expect(backdrop != null and backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Remastered backdrop must be present and noninteractive.")
	_expect(not original_screen.visible, "Old screen must stop painting and intercepting clicks immediately.")
	_expect(original_screen.process_mode == Node.PROCESS_MODE_DISABLED, "Old screen must stop handling deferred battle events.")
	var new_run: Button = main.current_screen.find_child("NewJourney", true, false)
	_expect(new_run != null, "Main menu must expose a stable new journey action.")
	if new_run != null:
		var before_node: String = gm.current_node_id
		new_run.pressed.emit()
		var confirmation: ConfirmationDialog = main.current_screen.find_child("ConfirmNewJourney", true, false)
		_expect(confirmation != null and confirmation.visible, "An existing run requires replacement confirmation.")
		_expect(gm.current_node_id == before_node, "Requesting a new journey must not erase progress before confirmation.")
		if confirmation != null:
			confirmation.canceled.emit()
			confirmation.hide()
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("V2.2 UI failures: %d" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
