## 6x6 match board. It owns tile generation, selection, swapping, match finding,
## clearing, falling, refill, cascades, and skill-triggered board explosions.
extends Control
class_name Board

## Emitted after a valid player swap finishes resolving every cascade.
signal move_resolved(clear_events: Array, cascade_count: int)
## Emitted when an adjacent swap does not create a match and is rolled back.
signal invalid_swap
## Emitted while the board is animating or resolving so other systems can lock UI.
signal board_busy_changed(is_busy: bool)

const TileScript = preload("res://scripts/Tile.gd")

const COLS = 6
const ROWS = 6
const TILE_SIZE = 48
const TILE_GAP = 4
const EMPTY = ""
const GRAY_DEADLOCK_RATIO = 0.72
const GRAY_DEADLOCK_CLEANSE_COUNT = 2
const EXTERNAL_REBUILD_NODE_LIMIT = 100000
const SUPPORTED_COLORS = ["gray", "red", "blue", "gold"]
const DEFAULT_WEIGHTS = {
	"gray": 0.43,
	"red": 0.19,
	"blue": 0.19,
	"gold": 0.19,
}
const MIN_RELATIVE_WEIGHT: float = 0.000000000001

## grid stores color keys, while tile_nodes stores the reusable Button nodes.
var grid: Array = []
var tile_nodes: Array = []
## Spawn weights are copied from GameManager and can be biased by rewards.
var weights: Dictionary = DEFAULT_WEIGHTS.duplicate()

## Current interaction state. external_locked is controlled by BattleManager.
var grid_root: GridContainer
var selected_cell: Vector2i = Vector2i(-1, -1)
var busy: bool = false
var external_locked: bool = false
var event_sequence: int = 0
var _external_rebuild_nodes: int = 0

func _ready() -> void:
	_ensure_grid_root()

## Rebuilds the board with new color weights for the current battle.
func setup(new_weights: Dictionary) -> void:
	weights = _normalize_weights(new_weights)
	event_sequence = 0
	_ensure_grid_root()
	_generate_board()
	_refresh_tiles(true)
	_apply_external_lock()

## Locks board input during battle animations, skills, and enemy turns.
func set_locked(value: bool) -> void:
	external_locked = value
	_clear_selection()
	_apply_external_lock()

func create_snapshot() -> Dictionary:
	return {
		"grid": grid.duplicate(true),
		"weights": weights.duplicate(true),
		"event_sequence": event_sequence,
	}

## Returns a deterministic first-clear preview without changing live board state.
func preview_swap(first: Vector2i, second: Vector2i) -> Dictionary:
	if busy or not _in_bounds(first) or not _in_bounds(second) or not _are_adjacent(first, second):
		return {"valid": false, "clear_events": [], "cascade_count": 0}
	var candidate_grid: Array = grid.duplicate(true)
	_swap_cells(first, second, candidate_grid)
	var matched: Dictionary = _find_matches(candidate_grid)
	if matched.is_empty():
		return {"valid": false, "clear_events": [], "cascade_count": 0}
	var groups_by_type: Dictionary = _group_matches_by_type(matched)
	var events: Array[Dictionary] = []
	for color_key in groups_by_type.keys():
		for group_value in groups_by_type[color_key]:
			var group: Array = group_value
			events.append({
				"type": String(color_key),
				"count": group.size(),
				"cascade": 1,
				"active": true,
				"positions": group.duplicate(),
			})
	var counts: Dictionary = _count_matches_by_type(matched)
	return {
		"valid": true,
		"clear_events": events,
		"cascade_count": 1,
		"match_counts": counts,
		"first": first,
		"second": second,
	}

func restore_snapshot(snapshot_value: Variant) -> bool:
	# A suspended swap/skill still owns the grid until its resolution finishes.
	if busy or not snapshot_value is Dictionary:
		return false
	var snapshot: Dictionary = snapshot_value
	var grid_value: Variant = snapshot.get("grid", [])
	if not grid_value is Array or grid_value.size() != ROWS:
		return false
	var restored_grid: Array = []
	for row_value in grid_value:
		if not row_value is Array or row_value.size() != COLS:
			return false
		var restored_row: Array[String] = []
		for color_value in row_value:
			if not (color_value is String or color_value is StringName):
				return false
			var color_key: String = String(color_value)
			if not SUPPORTED_COLORS.has(color_key):
				return false
			restored_row.append(color_key)
		restored_grid.append(restored_row)
	if not _is_playable_state(restored_grid):
		return false
	var sequence_value: Variant = snapshot.get("event_sequence", 0)
	if not (sequence_value is int or sequence_value is float) or not is_finite(float(sequence_value)):
		return false
	var restored_sequence: int = maxi(int(sequence_value), 0)
	var restored_weights: Dictionary = _normalize_weights(snapshot.get("weights", weights))

	# Commit only after validation; rejected snapshots leave live state untouched.
	grid = restored_grid
	weights = restored_weights
	event_sequence = restored_sequence
	selected_cell = Vector2i(-1, -1)
	_ensure_grid_root()
	_refresh_tiles(true)
	_apply_external_lock()
	return true

func _normalize_weights(weights_value: Variant) -> Dictionary:
	var normalized: Dictionary = {}
	var largest: float = 0.0
	var total: float = 0.0
	if weights_value is Dictionary:
		for color_key in SUPPORTED_COLORS:
			var value: Variant = weights_value.get(color_key, 0.0)
			if not (value is int or value is float):
				continue
			var weight: float = float(value)
			if not is_finite(weight) or weight <= 0.0:
				continue
			normalized[color_key] = weight
			largest = maxf(largest, weight)
			total += weight
	if normalized.is_empty():
		return DEFAULT_WEIGHTS.duplicate()
	if is_equal_approx(total, 1.0):
		return normalized

	# Scale before summing so even finite weights near the float limit are safe.
	total = 0.0
	for color_key in normalized.keys():
		var scaled: float = float(normalized[color_key]) / largest
		if scaled < MIN_RELATIVE_WEIGHT:
			normalized.erase(color_key)
			continue
		normalized[color_key] = scaled
		total += scaled
	for color_key in normalized.keys():
		var probability: float = float(normalized[color_key]) / total
		if probability > 0.0:
			normalized[color_key] = probability
		else:
			normalized.erase(color_key)
	return normalized

## Skill helper used by Flame Storm. It clears every tile of one color and then
## resolves natural cascades created by the refill.
func explode_color(color_key: String) -> Array:
	if busy:
		return []
	busy = true
	board_busy_changed.emit(true)
	_clear_selection()

	var matched: Dictionary = {}
	for y in range(ROWS):
		for x in range(COLS):
			if String(grid[y][x]) == color_key:
				matched[Vector2i(x, y)] = color_key

	var events: Array = []
	if matched.is_empty():
		busy = false
		board_busy_changed.emit(false)
		return events

	for pos in matched.keys():
		var tile: Tile = tile_nodes[pos.y][pos.x] as Tile
		tile.play_clear()
	await get_tree().create_timer(0.18).timeout

	var first_count: int = matched.size()
	_clear_cells(matched)
	_collapse_columns()
	_recover_from_gray_deadlock()
	_refresh_tiles(true)
	events.append(_make_event(color_key, first_count, 1, false, matched.keys()))

	var cascade_events: Array = await _resolve_cascades(2)
	events.append_array(cascade_events)
	if not _has_possible_move():
		_generate_board()
		_refresh_tiles(true)
	busy = false
	board_busy_changed.emit(false)
	return events

func pollute_random_cells(amount: int) -> int:
	var candidates: Array[Vector2i] = []
	for y in range(ROWS):
		for x in range(COLS):
			if String(grid[y][x]) != "gray":
				candidates.append(Vector2i(x, y))
	candidates.shuffle()
	var changed: int = 0
	for pos in candidates:
		if changed >= amount:
			break
		grid[pos.y][pos.x] = "gray"
		changed += 1
	_recover_from_gray_deadlock()
	_stabilize_after_external_change()
	_refresh_tiles(true)
	return changed

func _recover_from_gray_deadlock() -> int:
	var gray_count: int = 0
	for y in range(ROWS):
		for x in range(COLS):
			if String(grid[y][x]) == "gray":
				gray_count += 1
	if float(gray_count) / float(COLS * ROWS) <= GRAY_DEADLOCK_RATIO:
		return 0
	var has_non_gray_weight: bool = false
	for color_key in ["red", "blue", "gold"]:
		if float(weights.get(color_key, 0.0)) > 0.0:
			has_non_gray_weight = true
			break
	if not has_non_gray_weight:
		return 0

	var candidates: Array[Vector2i] = []
	for y in range(ROWS):
		for x in range(COLS):
			if String(grid[y][x]) == "gray":
				candidates.append(Vector2i(x, y))
	candidates.shuffle()
	var cleansed: int = 0
	for pos in candidates:
		if cleansed >= GRAY_DEADLOCK_CLEANSE_COUNT:
			break
		grid[pos.y][pos.x] = _weighted_random_non_gray()
		cleansed += 1
	return cleansed

func cleanse_gray_cells(amount: int) -> int:
	var candidates: Array[Vector2i] = []
	for y in range(ROWS):
		for x in range(COLS):
			if String(grid[y][x]) == "gray":
				candidates.append(Vector2i(x, y))
	candidates.shuffle()
	var changed: int = 0
	for pos in candidates:
		if changed >= amount:
			break
		grid[pos.y][pos.x] = _weighted_random_non_gray()
		changed += 1
	_stabilize_after_external_change()
	_refresh_tiles(true)
	return changed

func dye_gray_cells(color_key: String, amount: int) -> int:
	if not ["red", "blue", "gold"].has(color_key):
		return 0
	var candidates: Array[Vector2i] = []
	for y in range(ROWS):
		for x in range(COLS):
			if String(grid[y][x]) == "gray":
				candidates.append(Vector2i(x, y))
	candidates.shuffle()
	var changed: int = 0
	for pos in candidates:
		if changed >= amount:
			break
		grid[pos.y][pos.x] = color_key
		changed += 1
	_stabilize_after_external_change()
	_refresh_tiles(true)
	return changed

func _stabilize_after_external_change() -> void:
	if _is_playable_state():
		return
	var remaining: Dictionary = {}
	for y in range(ROWS):
		for x in range(COLS):
			var color_key: String = String(grid[y][x])
			if color_key == EMPTY:
				_generate_board()
				return
			remaining[color_key] = int(remaining.get(color_key, 0)) + 1

	for clear_y in range(ROWS):
		for clear_x in range(COLS):
			grid[clear_y][clear_x] = EMPTY
	_external_rebuild_nodes = 0
	if not _try_rebuild_with_counts(remaining, 0) and not _shuffle_with_counts(remaining):
		_generate_board()

func _try_rebuild_with_counts(remaining: Dictionary, index: int) -> bool:
	if _external_rebuild_nodes >= EXTERNAL_REBUILD_NODE_LIMIT:
		return false
	_external_rebuild_nodes += 1
	if index >= ROWS * COLS:
		return _is_playable_state()

	var y: int = index / COLS
	var x: int = index % COLS
	var candidates: Array[String] = []
	for color_value in remaining.keys():
		var color_key: String = String(color_value)
		if int(remaining.get(color_key, 0)) > 0:
			candidates.append(color_key)
	candidates.sort_custom(func(a: String, b: String) -> bool:
		return int(remaining.get(a, 0)) > int(remaining.get(b, 0))
	)

	for color_key in candidates:
		if _would_make_line(x, y, color_key, grid[y]):
			continue
		grid[y][x] = color_key
		remaining[color_key] = int(remaining[color_key]) - 1
		if _try_rebuild_with_counts(remaining, index + 1):
			return true
		remaining[color_key] = int(remaining[color_key]) + 1
		grid[y][x] = EMPTY
	return false

func _is_playable_state(candidate_grid: Array = []) -> bool:
	return _find_matches(candidate_grid).is_empty() and _has_possible_move(candidate_grid)

func _shuffle_with_counts(remaining: Dictionary) -> bool:
	var values: Array[String] = []
	for color_value in remaining.keys():
		var color_key: String = String(color_value)
		for _index in range(max(int(remaining.get(color_key, 0)), 0)):
			values.append(color_key)
	if values.size() != ROWS * COLS:
		return false
	for _attempt in range(512):
		values.shuffle()
		for index in range(values.size()):
			var y: int = index / COLS
			var x: int = index % COLS
			grid[y][x] = values[index]
		if _is_playable_state():
			return true
	return false

## Lazily creates the visual grid once and reuses tile nodes across refills.
func _ensure_grid_root() -> void:
	if grid_root != null:
		return
	custom_minimum_size = Vector2(COLS * TILE_SIZE + (COLS - 1) * TILE_GAP, ROWS * TILE_SIZE + (ROWS - 1) * TILE_GAP)
	grid_root = GridContainer.new()
	grid_root.name = "Grid"
	grid_root.columns = COLS
	grid_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_root.add_theme_constant_override("h_separation", TILE_GAP)
	grid_root.add_theme_constant_override("v_separation", TILE_GAP)
	add_child(grid_root)

	for y in range(ROWS):
		var row: Array = []
		for x in range(COLS):
			var tile: Tile = TileScript.new()
			tile.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
			tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tile.setup(Vector2i(x, y), "gray")
			tile.tile_clicked.connect(_on_tile_clicked)
			grid_root.add_child(tile)
			row.append(tile)
		tile_nodes.append(row)

## Generates a board with no immediate matches and at least one possible move.
func _generate_board() -> void:
	grid.clear()
	for y in range(ROWS):
		var row: Array = []
		for x in range(COLS):
			row.append(_pick_type_for_cell(x, y, row))
		grid.append(row)

	var guard: int = 0
	while (not _find_matches().is_empty() or not _has_possible_move()) and guard < 40:
		guard += 1
		grid.clear()
		for y in range(ROWS):
			var row: Array = []
			for x in range(COLS):
				row.append(_pick_type_for_cell(x, y, row))
			grid.append(row)

## Picks a weighted color while avoiding a starting 3-in-a-row at this cell.
func _pick_type_for_cell(x: int, y: int, current_row: Array) -> String:
	for attempt in range(16):
		var candidate: String = _weighted_random_type()
		if not _would_make_line(x, y, candidate, current_row):
			return candidate

	for candidate in ["gray", "red", "blue", "gold"]:
		if not _would_make_line(x, y, candidate, current_row):
			return candidate
	return _weighted_random_type()

## Checks whether placing candidate would create an immediate horizontal or
## vertical line during board generation.
func _would_make_line(x: int, y: int, candidate: String, current_row: Array) -> bool:
	if x >= 2 and String(current_row[x - 1]) == candidate and String(current_row[x - 2]) == candidate:
		return true
	if y >= 2 and String(grid[y - 1][x]) == candidate and String(grid[y - 2][x]) == candidate:
		return true
	return false

## Draws a color key using the active spawn weights.
func _weighted_random_type() -> String:
	var total: float = 0.0
	for value in weights.values():
		total += float(value)
	var roll: float = randf() * total
	for color_key in weights.keys():
		roll -= float(weights[color_key])
		if roll <= 0.0:
			return String(color_key)
	return "gray"

func _has_deterministic_refill() -> bool:
	if weights.is_empty():
		return true
	var total: float = 0.0
	for value in weights.values():
		total += float(value)
	# Include tiny weights rounded out of the total: every roll hits the first key.
	return float(weights.values()[0]) >= total

func _weighted_random_non_gray() -> String:
	var local_weights: Dictionary = weights.duplicate(true)
	local_weights.erase("gray")
	var total: float = 0.0
	for value in local_weights.values():
		total += float(value)
	var roll: float = randf() * max(total, 0.001)
	for color_key in local_weights.keys():
		roll -= float(local_weights[color_key])
		if roll <= 0.0:
			return String(color_key)
	return String(["red", "blue", "gold"].pick_random())

## Handles selection, deselection, reselection, and adjacent swap attempts.
func _on_tile_clicked(pos: Vector2i) -> void:
	if busy or external_locked:
		return
	if selected_cell == Vector2i(-1, -1):
		_select_cell(pos)
		return
	if selected_cell == pos:
		_clear_selection()
		return
	if not _are_adjacent(selected_cell, pos):
		_select_cell(pos)
		return
	await _try_swap(selected_cell, pos)

## Swaps two adjacent cells. If no match appears, the swap is reverted and the
## player does not spend a move.
func _try_swap(a: Vector2i, b: Vector2i) -> void:
	busy = true
	board_busy_changed.emit(true)
	_swap_cells(a, b)
	_clear_selection()
	_refresh_tiles()
	await get_tree().create_timer(0.08).timeout

	var clear_events: Array = await _resolve_cascades(1, true)
	if clear_events.is_empty():
		_swap_cells(a, b)
		_refresh_tiles()
		invalid_swap.emit()
		busy = false
		board_busy_changed.emit(false)
		return

	var cascade_count: int = 0
	for event in clear_events:
		cascade_count = max(cascade_count, int(event.get("cascade", 1)))
	move_resolved.emit(clear_events, cascade_count)
	busy = false
	board_busy_changed.emit(false)

## Repeatedly clears matches, collapses columns, refills, and records one event
## per color per cascade step for BattleManager.
func _resolve_cascades(start_cascade: int, first_is_active: bool = false) -> Array:
	var events: Array = []
	var cascade: int = start_cascade
	while true:
		var matched: Dictionary = _find_matches()
		if matched.is_empty():
			break

		var groups_by_type: Dictionary = _group_matches_by_type(matched)
		for color_key in groups_by_type.keys():
			for group_value in groups_by_type[color_key]:
				var group: Array = group_value
				events.append(_make_event(String(color_key), group.size(), cascade, first_is_active and cascade == start_cascade, group))

		for pos in matched.keys():
			var tile: Tile = tile_nodes[pos.y][pos.x] as Tile
			tile.play_clear()
		await get_tree().create_timer(0.18).timeout

		var before_refill: Array = grid.duplicate(true) if _has_deterministic_refill() else []
		_clear_cells(matched)
		_collapse_columns()
		var refill_was_identical: bool = not before_refill.is_empty() and grid == before_refill
		_recover_from_gray_deadlock()
		# An identical deterministic refill cannot produce a different next cascade.
		if refill_was_identical:
			_generate_board()
			_refresh_tiles(true)
			break
		_refresh_tiles(true)
		await get_tree().create_timer(0.12).timeout
		cascade += 1
	if not events.is_empty() and not _has_possible_move():
		_generate_board()
		_refresh_tiles(true)
	return events

## Finds all horizontal and vertical runs with length >= 3.
func _find_matches(candidate_grid: Array = []) -> Dictionary:
	var board_grid: Array = grid if candidate_grid.is_empty() else candidate_grid
	var matched: Dictionary = {}
	for y in range(ROWS):
		var run_type: String = String(board_grid[y][0])
		var run_start: int = 0
		var run_length: int = 1
		for x in range(1, COLS):
			var current: String = String(board_grid[y][x])
			if current != EMPTY and current == run_type:
				run_length += 1
			else:
				_add_run_if_match(matched, run_type, run_start, y, run_length, true)
				run_type = current
				run_start = x
				run_length = 1
		_add_run_if_match(matched, run_type, run_start, y, run_length, true)

	for x in range(COLS):
		var run_type: String = String(board_grid[0][x])
		var run_start: int = 0
		var run_length: int = 1
		for y in range(1, ROWS):
			var current: String = String(board_grid[y][x])
			if current != EMPTY and current == run_type:
				run_length += 1
			else:
				_add_run_if_match(matched, run_type, x, run_start, run_length, false)
				run_type = current
				run_start = y
				run_length = 1
		_add_run_if_match(matched, run_type, x, run_start, run_length, false)
	return matched

## Adds every cell in a valid run into the shared matched dictionary.
func _add_run_if_match(matched: Dictionary, type_key: String, a: int, b: int, length: int, horizontal: bool) -> void:
	if type_key == EMPTY or length < 3:
		return
	for i in range(length):
		var pos: Vector2i = Vector2i(a + i, b) if horizontal else Vector2i(a, b + i)
		matched[pos] = type_key

## Converts matched cells into color counts for reward and damage logic.
func _count_matches_by_type(matched: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for pos in matched.keys():
		var color_key: String = String(matched[pos])
		counts[color_key] = int(counts.get(color_key, 0)) + 1
	return counts

func _group_matches_by_type(matched: Dictionary) -> Dictionary:
	var pending: Dictionary = matched.duplicate(true)
	var groups_by_type: Dictionary = {}
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while not pending.is_empty():
		var seed_pos: Vector2i = Vector2i(pending.keys()[0])
		var color_key: String = String(pending[seed_pos])
		pending.erase(seed_pos)
		var queue: Array[Vector2i] = [seed_pos]
		var group: Array[Vector2i] = []
		while not queue.is_empty():
			var pos: Vector2i = queue.pop_front()
			group.append(pos)
			for direction in directions:
				var neighbor: Vector2i = pos + direction
				if pending.has(neighbor) and String(pending[neighbor]) == color_key:
					pending.erase(neighbor)
					queue.append(neighbor)
		var color_groups: Array = groups_by_type.get(color_key, [])
		color_groups.append(group)
		groups_by_type[color_key] = color_groups
	return groups_by_type

func _positions_for_type(matched: Dictionary, color_key: String) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for pos in matched.keys():
		if String(matched[pos]) == color_key:
			positions.append(pos)
	return positions

func _make_event(color_key: String, count: int, cascade: int, active: bool, positions: Array) -> Dictionary:
	event_sequence += 1
	return {
		"type": color_key,
		"count": count,
		"cascade": cascade,
		"active": active,
		"sequence": event_sequence,
		"positions": positions.duplicate(),
	}

## Marks matched grid cells empty before the column collapse.
func _clear_cells(matched: Dictionary) -> void:
	for pos in matched.keys():
		grid[pos.y][pos.x] = EMPTY

## Drops existing tiles downward and fills the empty top cells with weighted new
## colors. Visual nodes are refreshed separately.
func _collapse_columns() -> void:
	for x in range(COLS):
		var kept: Array[String] = []
		for y in range(ROWS - 1, -1, -1):
			var value: String = String(grid[y][x])
			if value != EMPTY:
				kept.append(value)

		var write_y: int = ROWS - 1
		for value in kept:
			grid[write_y][x] = value
			write_y -= 1
		while write_y >= 0:
			grid[write_y][x] = _weighted_random_type()
			write_y -= 1

## Synchronizes each visual Tile node with the logical grid state.
func _refresh_tiles(play_spawn_effect: bool = false) -> void:
	for y in range(ROWS):
		for x in range(COLS):
			var tile: Tile = tile_nodes[y][x] as Tile
			tile.set_grid_position(Vector2i(x, y))
			tile.set_tile_type(String(grid[y][x]))
			tile.set_selected(selected_cell == Vector2i(x, y))
			if play_spawn_effect and y < 2:
				tile.play_spawn()

## Swaps only logical grid values; visuals are updated by _refresh_tiles().
func _swap_cells(a: Vector2i, b: Vector2i, candidate_grid: Array = []) -> void:
	var board_grid: Array = grid if candidate_grid.is_empty() else candidate_grid
	var temp: Variant = board_grid[a.y][a.x]
	board_grid[a.y][a.x] = board_grid[b.y][b.x]
	board_grid[b.y][b.x] = temp

## Returns true for orthogonal neighbors only.
func _are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1

func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < COLS and pos.y >= 0 and pos.y < ROWS

## Brute-force move availability check. The board is small, so testing every
## right/down swap remains simple and reliable for the 1.0 ruleset.
func _has_possible_move(candidate_grid: Array = []) -> bool:
	for y in range(ROWS):
		for x in range(COLS):
			var pos: Vector2i = Vector2i(x, y)
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var other: Vector2i = pos + direction
				if other.x >= COLS or other.y >= ROWS:
					continue
				_swap_cells(pos, other, candidate_grid)
				var has_match: bool = not _find_matches(candidate_grid).is_empty()
				_swap_cells(pos, other, candidate_grid)
				if has_match:
					return true
	return false

## Selects one cell and refreshes highlight visuals.
func _select_cell(pos: Vector2i) -> void:
	selected_cell = pos
	_refresh_tiles()

## Clears selection and removes highlight visuals.
func _clear_selection() -> void:
	selected_cell = Vector2i(-1, -1)
	_refresh_tiles()

## Applies the combat lock to every tile button.
func _apply_external_lock() -> void:
	for row in tile_nodes:
		for tile in row:
			var tile_button: Tile = tile as Tile
			tile_button.disabled = external_locked
