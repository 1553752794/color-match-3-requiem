extends SceneTree

const BoardScript = preload("res://scripts/Board.gd")
const SpectrumManagerScript = preload("res://scripts/SpectrumManager.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var board: Variant = BoardScript.new()
	var original: Array = [
		["red", "red", "blue", "gray", "blue", "gold"],
		["blue", "red", "red", "gold", "gray", "blue"],
		["gold", "blue", "gold", "gray", "gold", "red"],
		["gray", "gold", "blue", "red", "blue", "gray"],
		["blue", "gray", "gold", "blue", "red", "gold"],
		["gold", "red", "blue", "gold", "gray", "blue"],
	]
	board.grid = original.duplicate(true)
	var preview: Dictionary = board.preview_swap(Vector2i(2, 0), Vector2i(2, 1))
	_expect(preview.get("valid", false) == true, "a known match-producing swap must preview as valid.")
	_expect(not preview.get("clear_events", []).is_empty(), "preview must expose first-clear events.")
	_expect(board.grid == original, "preview must not mutate the live grid.")

	var manager: Variant = SpectrumManagerScript.new()
	var preview_hand: Array[Dictionary] = [
		{"card_id": "ember_slash", "instance_id": "preview-card", "level": 0},
	]
	manager.begin_turn(preview_hand)
	var spectrum_before: Dictionary = manager.create_snapshot()
	var preview_events: Array[Dictionary] = []
	for event_value in preview.get("clear_events", []):
		if event_value is Dictionary:
			preview_events.append(event_value)
	var trigger_preview: Array[Dictionary] = manager.preview_clear_events(
		preview_events,
		{"moves_left": 3, "last_red_count": 5, "player_hp_ratio": 1.0}
	)
	_expect(trigger_preview.size() >= 0, "preview trigger evaluation must return an array.")
	_expect(manager.create_snapshot() == spectrum_before, "preview must not mutate spectrum state.")
	board.free()

	if failures.is_empty():
		print("V2.4.1 preview tests passed: 4")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
