extends SceneTree

const TileScript = preload("res://scripts/Tile.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var tile: Variant = TileScript.new()
	tile.play_clear("line_4")
	_expect(tile.last_clear_shape == "line_4", "special clear animation must retain the resolved shape.")
	tile.set_tile_type("red")
	_expect(tile.last_clear_shape == "", "refilling a tile must clear the previous shape marker.")
	tile.play_clear("line_3")
	_expect(tile.last_clear_shape == "line_3", "normal clear animation must retain the default shape.")
	tile.free()

	if failures.is_empty():
		print("V2.4 special match animation tests passed: 3")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
