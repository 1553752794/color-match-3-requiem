extends SceneTree

const BoardScript = preload("res://scripts/Board.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var board: Variant = BoardScript.new()
	board.grid = [
		["red", "red", "blue", "red", "gold", "gray"],
		["blue", "gold", "red", "gray", "blue", "gold"],
		["gold", "blue", "gold", "gray", "gold", "red"],
		["gray", "gold", "blue", "red", "blue", "gray"],
		["blue", "gray", "gold", "blue", "red", "gold"],
		["gold", "red", "blue", "gold", "gray", "blue"],
	]
	var four_preview: Dictionary = board.preview_swap(Vector2i(2, 0), Vector2i(2, 1))
	_expect(four_preview.get("valid", false), "four-match setup must be a valid preview.")
	_expect(_event_shape(four_preview) == "line_4", "four-match preview must expose line_4.")
	_expect(_event_text(four_preview).contains("四连"), "four-match preview must expose readable text.")

	board.grid = [
		["red", "red", "red", "blue", "red", "gold"],
		["blue", "gold", "red", "red", "blue", "gray"],
		["gold", "blue", "gold", "gray", "gold", "red"],
		["gray", "gold", "blue", "red", "blue", "gray"],
		["blue", "gray", "gold", "blue", "red", "gold"],
		["gold", "red", "blue", "gold", "gray", "blue"],
	]
	var five_preview: Dictionary = board.preview_swap(Vector2i(3, 0), Vector2i(3, 1))
	_expect(five_preview.get("valid", false), "five-match setup must be a valid preview.")
	_expect(_event_shape(five_preview) == "line_5", "five-match preview must expose line_5.")
	_expect(_event_text(five_preview).contains("五连"), "five-match preview must expose readable text.")
	_expect(board._classify_match_shape([
		Vector2i(1, 1), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 2)
	]) == "cross", "plus-shaped five match must expose cross.")
	_expect(board._classify_match_shape([
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)
	]) == "l_shape", "corner-shaped five match must expose l_shape.")
	board.free()

	if failures.is_empty():
		print("V2.4 special match tests passed: 8")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _event_shape(preview: Dictionary) -> String:
	var events: Array = preview.get("clear_events", [])
	return String(events[0].get("shape", "")) if not events.is_empty() else ""

func _event_text(preview: Dictionary) -> String:
	var events: Array = preview.get("clear_events", [])
	return String(events[0].get("shape_text", "")) if not events.is_empty() else ""

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
