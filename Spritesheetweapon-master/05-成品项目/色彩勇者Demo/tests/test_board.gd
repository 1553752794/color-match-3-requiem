extends SceneTree

const BoardScript = preload("res://scripts/Board.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_column_collapse_preserves_existing_tiles()
	_test_pollution_deadlock_recovery()
	if failures.is_empty():
		print("Board tests passed: 2")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_column_collapse_preserves_existing_tiles() -> void:
	var board: Board = BoardScript.new()
	board.grid.clear()
	for row_index in range(BoardScript.ROWS):
		board.grid.append(["gray", "red", "blue", "gold", "gray", "red"])
	board.grid[0][0] = BoardScript.EMPTY
	board.grid[1][0] = "red"
	board.grid[2][0] = BoardScript.EMPTY
	board.grid[3][0] = "blue"
	board.grid[4][0] = "gold"
	board.grid[5][0] = BoardScript.EMPTY
	board.grid[5][0] = "gray"
	board._collapse_columns()
	_expect(board.grid[5][0] == "gray", "最底部旧色块应保持在列底。")
	_expect(board.grid[4][0] == "gold", "第二个旧色块应下落到倒数第二格。")
	_expect(board.grid[3][0] == "blue", "第三个旧色块应保持相对顺序。")
	_expect(board.grid[2][0] == "red", "最上方旧色块应落在补齐区下方。")
	for y in range(BoardScript.ROWS):
		for x in range(BoardScript.COLS):
			_expect(String(board.grid[y][x]) != BoardScript.EMPTY, "下落补齐后棋盘不能残留空格。")
	board.free()

func _test_pollution_deadlock_recovery() -> void:
	var board: Board = BoardScript.new()
	root.add_child(board)
	board.grid.clear()
	for row_index in range(BoardScript.ROWS):
		var row: Array[String] = []
		for column_index in range(BoardScript.COLS):
			row.append("gray" if row_index * BoardScript.COLS + column_index < 25 else "red")
		board.grid.append(row)

	var polluted: int = board.pollute_random_cells(1)
	var gray_count: int = 0
	for row in board.grid:
		for color_key in row:
			if String(color_key) == "gray":
				gray_count += 1
	_expect(polluted == 1, "污染流程应先将 1 个非灰色块转为灰色。")
	_expect(gray_count <= 24, "灰格超过 72% 后应净化至少 2 格，或重建为可玩的低灰格棋盘。")
	_expect(board._find_matches().is_empty(), "污染恢复后棋盘不能残留预成消除。")
	_expect(board._has_possible_move(), "污染恢复后棋盘至少应存在一步合法交换。")
	board.free()

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
