extends SceneTree

const MAIN_PATH: String = "res://scripts/Main.gd"

var failures: Array[String] = []
var passed_tests: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source: String = FileAccess.get_file_as_string(MAIN_PATH)
	_run_test("Main.gd parses", func() -> void:
		_expect(ResourceLoader.load(MAIN_PATH) != null, "Main.gd 必须能由 Godot 4.6 正常加载。")
	)
	_run_test("character choice hierarchy", func() -> void:
		_expect(source.contains("定位 ·"), "角色选择必须显示定位。")
		_expect(source.contains("被动 ·"), "角色选择必须显示被动。")
		_expect(source.contains("主动技 ·"), "角色选择必须显示主动技。")
		_expect(source.contains("初始构筑差异 ·"), "角色选择必须显式比较初始构筑差异。")
	)
	_run_test("map status hierarchy", func() -> void:
		_expect(source.contains("当前誓约 ·"), "地图页必须显示当前誓约。")
		_expect(source.contains("地图池 ·"), "地图页必须显示本局地图池。")
		_expect(source.contains("纵向路线 · 自下而上"), "地图页必须明确纵向爬塔方向。")
		_expect(source.contains("滚轮缩放 ·") and source.contains("拖拽状态 ·"), "地图页必须显示缩放与拖拽状态。")
	)
	_run_test("archive route pool is reachable and idempotent", func() -> void:
		_expect(source.contains("func show_route_pool_selection()"), "路线池解锁后必须显示路线二选一界面。")
		_expect(source.contains("GameManager.is_archive_map_pool_unlocked()"), "路线入口必须根据档案池解锁状态分流。")
		_expect(source.contains("GameManager.select_map_template_pool(template_id)"), "路线选择必须调用地图池提交接口。")
		_expect(source.contains("SaveManager.save_run()"), "路线选择后必须立即保存局内状态。")
		_expect(source.contains("route_pool_choice_committed"), "重复点击路线选择不得重复改写状态。")
	)
	_run_test("layout safeguards at 1280", func() -> void:
		_expect(source.contains("memory_set_grid.columns = 3"), "档案记忆组摘要必须使用稳定分栏。")
		_expect(source.contains("MAP_NODE_SIZE := Vector2(116.0, 58.0)"), "地图节点必须使用统一安全尺寸。")
		_expect(source.contains("MAP_NODE_GUTTER"), "地图层间必须保留节点间距。")
		_expect(source.contains("MAP_CONTENT_MIN_HEIGHT := 1040.0"), "纵向地图必须保留稳定的爬塔高度。")
		_expect(source.contains("positions[node_id] + Vector2(MAP_NODE_SIZE.x * 0.5, 0.0)"), "地图路线必须按纵向节点端点连接。")
		_expect(source.contains("button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART"), "地图长标题必须在固定节点内智能换行。")
		_expect(source.contains("SPECTRUM_CARD_WIDTH := 184.0"), "三张色谱卡必须使用固定三列宽度。")
	)
	_run_test("battle scan hierarchy", func() -> void:
		_expect(source.contains("本回合交换") and source.contains("色谱达成"), "战斗 HUD 必须并列显示交换数与色谱达成数。")
		_expect(source.contains("引音 ·") and source.contains("应音 ·"), "战斗 HUD 必须显示引音与应音。")
		_expect(source.contains("敌人意图"), "战斗 HUD 必须显式标注敌人意图。")
	)
	_run_test("v2 vocabulary only", func() -> void:
		for legacy_term in ["瞄准", "发射", "弹珠", "钉盘"]:
			_expect(not source.contains(legacy_term), "Main.gd 的可见文案不得出现 1.x 词：%s。" % legacy_term)
	)

	print("V2 UI contract tests: %d passed, %d failed" % [passed_tests, failures.size()])
	if failures.is_empty():
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _run_test(test_name: String, test_callable: Callable) -> void:
	var before: int = failures.size()
	test_callable.call()
	if failures.size() == before:
		passed_tests += 1
		print("[PASS] %s" % test_name)
	else:
		print("[FAIL] %s" % test_name)


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
