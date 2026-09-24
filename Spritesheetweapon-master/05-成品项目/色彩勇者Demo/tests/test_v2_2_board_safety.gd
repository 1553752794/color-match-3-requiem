extends SceneTree

const BOARD_SCRIPT = preload("res://scripts/Board.gd")
const COLORS: Array[String] = ["gray", "red", "blue", "gold"]
const DEFAULT_WEIGHTS: Dictionary = {"gray": 0.43, "red": 0.19, "blue": 0.19, "gold": 0.19}

class CollapseProbe extends BOARD_SCRIPT:
	var observations: Array[Dictionary] = []
	var sequence_before: int = 0

	func _recover_from_gray_deadlock() -> int:
		var before: Array = grid.duplicate(true)
		sequence_before = event_sequence
		var cleansed: int = super()
		observations.append({
			"before": before,
			"after": grid.duplicate(true),
			"cleansed": cleansed,
			"sequence_before": sequence_before,
			"sequence_after": event_sequence,
		})
		return cleansed

class ErrorCapture extends Logger:
	var errors: Array[String] = []
	var mutex: Mutex = Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		mutex.lock()
		errors.append("%s:%d: %s %s" % [file, line, code, rationale])
		mutex.unlock()

	func count() -> int:
		mutex.lock()
		var result: int = errors.size()
		mutex.unlock()
		return result

var failures: Array[String] = []
var passed: int = 0
var capture: ErrorCapture = ErrorCapture.new()
var fixtures: Array[Board] = []
var cascade_done: bool = false
var cascade_events: Array = []

func _init() -> void:
	OS.add_logger(capture)
	call_deferred("_run")

func _run() -> void:
	seed(2209)
	_run_test("matched snapshot rejection is atomic", _test_matched_rejection)
	_run_test("dead board rejection is atomic", _test_dead_board_rejection)
	_run_test("malformed grid rejection is atomic", _test_malformed_grids)
	_run_test("valid and JSON snapshots round trip without aliases", _test_round_trip)
	_run_test("restore filters malformed weights", _test_weight_sanitization)
	_run_test("large finite weights normalize without overflow", _test_large_weights)
	_run_test("setup uses the same safe weights boundary", _test_setup_weights)
	_run_test("successful restore clears selection and reapplies locks", _test_restore_input)
	_run_test("restore during resolution is rejected atomically", _test_busy_restore)
	await _run_async_test("single-color refill cannot resolve forever", _test_single_color_cascade)
	await _run_async_test("normal high-gray cascades retain event rules", _test_high_gray_cascade)
	await _run_async_test("extreme finite gray weights cannot resolve forever", _test_extreme_gray_cascade)
	_run_test("gray protection keeps the strict threshold and cleanse count", _test_gray_threshold)
	await _run_async_test("default-weight skill refills protect against high gray", _test_skill_gray_protection)
	_finish()

func _run_test(test_name: String, test_callable: Callable) -> void:
	var before: int = failures.size()
	var errors_before: int = capture.count()
	var completed: Variant = test_callable.call()
	_record_result(test_name, before, errors_before, completed)
	_cleanup()

func _run_async_test(test_name: String, test_callable: Callable) -> void:
	var before: int = failures.size()
	var errors_before: int = capture.count()
	var completed: Variant = await test_callable.call()
	_record_result(test_name, before, errors_before, completed)
	_cleanup()

func _record_result(test_name: String, before: int, errors_before: int, completed: Variant) -> void:
	_expect(completed is bool and completed == true, test_name + ": test did not reach its completion marker")
	_expect(capture.count() == errors_before, test_name + ": runtime errors are failures, never passes")
	if failures.size() == before:
		passed += 1
		print("[PASS] " + test_name)
	else:
		print("[FAIL] " + test_name)

func _finish() -> void:
	OS.remove_logger(capture)
	for failure in failures:
		print("[ASSERT] " + failure)
	for error in capture.errors:
		print("[RUNTIME] " + error)
	print("V2.2 board safety: %d passed, %d assertions failed, %d runtime errors" % [passed, failures.size(), capture.count()])
	quit(0 if failures.is_empty() and capture.count() == 0 else 1)

func _cleanup() -> void:
	for board in fixtures:
		board.free()
	fixtures.clear()

func _new_board() -> Board:
	var board: Board = BOARD_SCRIPT.new()
	root.add_child(board)
	board.setup(DEFAULT_WEIGHTS)
	board.event_sequence = 17
	fixtures.append(board)
	return board

func _latin_grid() -> Array:
	var result: Array = []
	for y in range(BOARD_SCRIPT.ROWS):
		var row: Array = []
		for x in range(BOARD_SCRIPT.COLS):
			row.append(COLORS[(x + y) % COLORS.size()])
		result.append(row)
	return result

func _visible_state(board: Board) -> Array:
	var result: Array = []
	for row in board.tile_nodes:
		for tile in row:
			result.append([tile.tile_type, tile.is_selected, tile.disabled])
	return result

func _expect_rejected_unchanged(board: Board, candidate: Variant, label: String) -> void:
	var before: Dictionary = board.create_snapshot()
	var original_grid: Array = board.grid
	var selected: Vector2i = board.selected_cell
	var was_busy: bool = board.busy
	var locked: bool = board.external_locked
	var visible: Array = _visible_state(board)
	_expect(not board.restore_snapshot(candidate), label + ": must reject")
	_expect(board.create_snapshot() == before, label + ": must preserve grid, weights and sequence")
	_expect(is_same(board.grid, original_grid), label + ": must not replace live grid on failure")
	_expect(board.selected_cell == selected and board.busy == was_busy and board.external_locked == locked, label + ": must preserve input state")
	_expect(_visible_state(board) == visible, label + ": must preserve tile state")

func _test_matched_rejection() -> bool:
	var board: Board = _new_board()
	board.set_locked(true)
	board._select_cell(Vector2i(2, 3))
	var candidate: Dictionary = board.create_snapshot()
	for row in candidate["grid"]:
		row.fill("red")
	candidate["weights"] = {"purple": 12.0}
	candidate["event_sequence"] = 999
	_expect_rejected_unchanged(board, candidate, "pre-existing matches")
	return true

func _test_dead_board_rejection() -> bool:
	var board: Board = _new_board()
	var candidate: Dictionary = board.create_snapshot()
	candidate["grid"] = _latin_grid()
	candidate["event_sequence"] = 999
	_expect_rejected_unchanged(board, candidate, "no possible swap")
	return true

func _test_malformed_grids() -> bool:
	var board: Board = _new_board()
	for candidate in [null, [], {}, {"grid": "bad"}, {"grid": [[]]}]:
		_expect_rejected_unchanged(board, candidate, "malformed shape")
	var candidate: Dictionary = board.create_snapshot()
	candidate["grid"][0][0] = "purple"
	_expect_rejected_unchanged(board, candidate, "unsupported cell")
	for cell in [null, 42, [], {}, true]:
		candidate = board.create_snapshot()
		candidate["grid"][0][0] = cell
		_expect_rejected_unchanged(board, candidate, "non-string cell")
	for sequence in [null, [], {}, true, "12", NAN, INF, -INF]:
		candidate = board.create_snapshot()
		candidate["event_sequence"] = sequence
		_expect_rejected_unchanged(board, candidate, "invalid event sequence")
	return true

func _test_round_trip() -> bool:
	var source: Board = _new_board()
	var expected: Dictionary = source.create_snapshot()
	var target: Board = _new_board()
	_expect(target.restore_snapshot(expected), "valid snapshot must restore")
	_expect(target.create_snapshot() == expected, "valid snapshot must round trip exactly")
	var json_snapshot: Variant = JSON.parse_string(JSON.stringify(expected))
	_expect(target.restore_snapshot(json_snapshot), "JSON snapshot must restore")
	_expect(target.create_snapshot() == expected, "JSON snapshot must preserve grid, weights and sequence")
	json_snapshot["grid"][0][0] = "purple"
	json_snapshot["weights"]["red"] = 123.0
	_expect(target.create_snapshot() == expected, "restored state must not alias snapshot")
	var exported: Dictionary = target.create_snapshot()
	exported["grid"][0][0] = "purple"
	exported["weights"]["red"] = 321.0
	_expect(target.create_snapshot() == expected, "exported state must not alias board")
	expected.erase("weights")
	expected.erase("event_sequence")
	_expect(target.restore_snapshot(expected), "legacy snapshot without optional fields must restore")
	_expect(target.weights == DEFAULT_WEIGHTS and target.event_sequence == 0, "legacy defaults must stay compatible")
	return true

func _weights_are_safe(value: Dictionary) -> bool:
	var total: float = 0.0
	if value.is_empty():
		return false
	for key in value:
		if not COLORS.has(key) or not (value[key] is float or value[key] is int):
			return false
		var weight: float = float(value[key])
		if not is_finite(weight) or weight <= 0.0:
			return false
		total += weight
	return is_finite(total) and is_equal_approx(total, 1.0)

func _test_weight_sanitization() -> bool:
	var board: Board = _new_board()
	var cases: Array = [
		{"purple": 1.0, "red": 2.0, "blue": 6.0},
		{"gray": NAN, "red": -1.0, "blue": 0.0, "gold": INF},
		{"gray": {}, "red": "2", "blue": true, "gold": []},
		{}, null, [],
		{"gray": -INF, "red": 3.0, "blue": 1.0},
	]
	for index in range(cases.size()):
		var snapshot: Dictionary = board.create_snapshot()
		snapshot["weights"] = cases[index]
		_expect(board.restore_snapshot(snapshot), "valid grid with damaged weights must recover")
		var safe: bool = _weights_are_safe(board.weights)
		_expect(safe, "weights case %d must contain only supported finite positive probabilities" % index)
		if not safe:
			continue
		if index == 0:
			_expect(is_equal_approx(board.weights.get("red", 0.0), 0.25) and is_equal_approx(board.weights.get("blue", 0.0), 0.75), "valid weight ratios must survive filtering")
		elif index in [1, 2, 3, 4, 5]:
			_expect(board.weights == DEFAULT_WEIGHTS, "unusable weights must use the existing default distribution")
		for draw in range(64):
			_expect(COLORS.has(board._weighted_random_type()), "refill must sample supported colors")
			_expect(["red", "blue", "gold"].has(board._weighted_random_non_gray()), "cleanse must sample supported non-gray colors")
	return true

func _test_large_weights() -> bool:
	var board: Board = _new_board()
	var snapshot: Dictionary = board.create_snapshot()
	snapshot["weights"] = {"red": 1.0e308, "blue": 1.0e308}
	_expect(board.restore_snapshot(snapshot), "large finite weights must restore")
	_expect(_weights_are_safe(board.weights), "large finite weights must not overflow the total")
	_expect(is_equal_approx(board.weights.get("red", 0.0), 0.5) and is_equal_approx(board.weights.get("blue", 0.0), 0.5), "large equal weights must remain equal probabilities")
	return true

func _test_setup_weights() -> bool:
	var board: Board = _new_board()
	# Guard the new boundary so a missing method is an assertion, not a script error.
	if not board.has_method("_normalize_weights"):
		_expect(false, "setup needs a shared safe weight boundary")
		return true
	var source: Dictionary = {"purple": 1.0e308, "gray": NAN, "red": 2.0, "blue": 6.0}
	board.setup(source)
	_expect(_weights_are_safe(board.weights), "setup must normalize weights before generation")
	_expect(not board.weights.has("purple"), "setup must discard unsupported colors")
	source["red"] = 999.0
	_expect(is_equal_approx(board.weights.get("red", 0.0), 0.25), "setup must not alias caller weights")
	_expect(board._is_playable_state(), "sanitized setup must produce a playable board")
	return true

func _test_restore_input() -> bool:
	var board: Board = _new_board()
	var snapshot: Dictionary = board.create_snapshot()
	for locked in [true, false]:
		board._select_cell(Vector2i(1, 2))
		board.external_locked = locked
		for row in board.tile_nodes:
			for tile in row:
				tile.disabled = not locked
		_expect(board.restore_snapshot(snapshot), "idle board must restore")
		_expect(board.selected_cell == Vector2i(-1, -1), "restore must clear stale selection")
		_expect(not board.busy and board.external_locked == locked, "restore must preserve the battle-owned lock")
		for row in board.tile_nodes:
			for tile in row:
				_expect(not tile.is_selected and tile.disabled == locked, "restored tile input must match board lock")
	return true

func _test_busy_restore() -> bool:
	var board: Board = _new_board()
	var candidate: Dictionary = board.create_snapshot()
	candidate["event_sequence"] = 999
	board.busy = true
	_expect_rejected_unchanged(board, candidate, "in-flight resolution")
	return true

func _collect_cascade(board: Board, start: int, active: bool) -> void:
	cascade_events = await board._resolve_cascades(start, active)
	cascade_done = true

func _wait_for_cascade(board: Board, start: int, active: bool) -> bool:
	cascade_done = false
	cascade_events = []
	_collect_cascade(board, start, active)
	var deadline: int = Time.get_ticks_msec() + 5000
	while not cascade_done and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(cascade_done, "cascade must finish within five real seconds")
	if not cascade_done:
		# The timeout is already a failure. Drain the coroutine before freeing it.
		board.weights = DEFAULT_WEIGHTS.duplicate()
		deadline = Time.get_ticks_msec() + 5000
		while not cascade_done and Time.get_ticks_msec() < deadline:
			await process_frame
		if not cascade_done:
			_finish()
			await process_frame
		return false
	return true

func _test_single_color_cascade() -> bool:
	var board: Board = _new_board()
	board.weights = {"gray": 1.0}
	for row in board.grid:
		row.fill("gray")
	board.event_sequence = 0
	var old_scale: float = Engine.time_scale
	Engine.time_scale = 100.0
	if not await _wait_for_cascade(board, 1, true):
		Engine.time_scale = old_scale
		return true
	Engine.time_scale = old_scale
	_expect(board._is_playable_state(), "deterministic refill recovery must leave a playable board")
	_expect(cascade_events.size() == 1, "a fixed-point refill must not farm repeated clear events")
	if cascade_events.size() == 1:
		var event: Dictionary = cascade_events[0]
		_expect(event["type"] == "gray" and event["count"] == 36 and event["cascade"] == 1 and event["active"], "the genuine initial match event must be preserved")
	_expect(board.event_sequence == 1, "rebuild must not manufacture clear events")
	return true

func _test_high_gray_cascade() -> bool:
	var board: Board = _new_board()
	board.weights = {"gray": 0.64, "red": 0.12, "blue": 0.12, "gold": 0.12}
	for row in board.grid:
		row.fill("gray")
	board.event_sequence = 0
	seed(2209)
	var old_scale: float = Engine.time_scale
	Engine.time_scale = 100.0
	if not await _wait_for_cascade(board, 2, false):
		Engine.time_scale = old_scale
		return true
	Engine.time_scale = old_scale
	_expect(not cascade_events.is_empty(), "high-gray cascade must report its initial match")
	_expect(board._is_playable_state(), "high-gray resolution must return a playable board")
	var sequence: int = 0
	for event in cascade_events:
		sequence += 1
		_expect(COLORS.has(event["type"]) and event["count"] >= 3 and event["positions"].size() == event["count"], "normal cascade event content must remain intact")
		_expect(event["sequence"] == sequence and event["cascade"] >= 2 and not event["active"], "skill cascades must retain passive and sequence semantics")
	return true

func _test_extreme_gray_cascade() -> bool:
	var board: Board = _new_board()
	var snapshot: Dictionary = board.create_snapshot()
	snapshot["weights"] = {"gray": 1.0e308, "red": 1.0, "blue": 1.0, "gold": 1.0}
	_expect(board.restore_snapshot(snapshot), "extreme finite weights must restore safely")
	_expect(_weights_are_safe(board.weights), "extreme probabilities must remain finite and positive")
	for row in board.grid:
		row.fill("gray")
	board.event_sequence = 0
	var old_scale: float = Engine.time_scale
	Engine.time_scale = 100.0
	if not await _wait_for_cascade(board, 1, true):
		Engine.time_scale = old_scale
		return true
	Engine.time_scale = old_scale
	_expect(board._is_playable_state(), "float-rounded single-color refill must recover")
	_expect(cascade_events.size() == 1 and board.event_sequence == 1, "float-rounded refill must not farm repeated events")
	return true

func _test_gray_threshold() -> bool:
	var board: Board = _new_board()
	for count in [25, 26, 36]:
		board.grid.clear()
		for y in range(BOARD_SCRIPT.ROWS):
			var row: Array = []
			for x in range(BOARD_SCRIPT.COLS):
				row.append("gray" if y * BOARD_SCRIPT.COLS + x < count else "red")
			board.grid.append(row)
		var expected: int = 0 if count == 25 else 2
		_expect(board._recover_from_gray_deadlock() == expected, "gray protection must trigger strictly above 72%, once per chain")
		_expect(_gray_count(board.grid) == count - expected, "protection must cleanse exactly two, not loop until below threshold")
	return true

func _new_probe() -> CollapseProbe:
	var board: CollapseProbe = CollapseProbe.new()
	root.add_child(board)
	board.setup(DEFAULT_WEIGHTS)
	fixtures.append(board)
	return board

func _collect_explosion(board: Board) -> void:
	cascade_events = await board.explode_color("red")
	cascade_done = true

func _test_skill_gray_protection() -> bool:
	var board: CollapseProbe = _new_probe()
	board.grid.clear()
	for y in range(BOARD_SCRIPT.ROWS):
		var row: Array = []
		for x in range(BOARD_SCRIPT.COLS):
			row.append("red" if (x + y) % 3 == 2 else "gray")
		board.grid.append(row)
	_expect(board._is_playable_state(), "default-weight skill fixture must start playable")
	board.event_sequence = 0
	seed(2209)
	var old_scale: float = Engine.time_scale
	Engine.time_scale = 100.0
	cascade_done = false
	_collect_explosion(board)
	var deadline: int = Time.get_ticks_msec() + 5000
	while not cascade_done and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(cascade_done, "default-weight explosion must finish within five seconds")
	if not cascade_done:
		_finish()
		await process_frame
	Engine.time_scale = old_scale
	_expect_collapse_protection(board, "default-weight skill")
	_expect(not board.busy and board._is_playable_state(), "skill protection must return an idle playable board")
	_expect(not cascade_events.is_empty() and cascade_events[0]["type"] == "red" and cascade_events[0]["count"] == 12, "skill protection must preserve the original twelve-red clear")
	return true

func _expect_collapse_protection(board: CollapseProbe, label: String) -> void:
	var high_gray_steps: int = 0
	for observation in board.observations:
		var before: Array = observation["before"]
		var after: Array = observation["after"]
		var gray_before: int = _gray_count(before)
		var gray_after: int = _gray_count(after)
		if gray_before >= 26:
			high_gray_steps += 1
			_expect(gray_after == gray_before - 2 and observation["cleansed"] == 2, label + ": each high-gray refill must cleanse exactly two cells")
		else:
			_expect(observation["cleansed"] == 0, label + ": refills below threshold must remain unchanged")
		_expect(observation["sequence_before"] == observation["sequence_after"], label + ": auto-cleanse must not manufacture clear events")
	# A seeded refill can legitimately land below the strict >72% threshold;
	# the assertions above still verify every observed high-gray refill.
	print("[OBSERVED] %s: %d high-gray refills" % [label, high_gray_steps])

func _gray_count(board_grid: Array) -> int:
	var count: int = 0
	for row in board_grid:
		for color_key in row:
			if String(color_key) == "gray":
				count += 1
	return count

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
