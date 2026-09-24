extends SceneTree

const TEST_SAVE_PATH := "user://test_run_save.json"
const TEST_PROFILE_SAVE_PATH := "user://test_profile_save.json"

var failures: Array[String] = []
var passed_tests: int = 0
var game_manager: Node
var save_manager: Node
var original_save_path: String
var original_profile_save_path: String
var original_profile_loaded: bool


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	game_manager = root.get_node("GameManager")
	save_manager = root.get_node("SaveManager")
	original_save_path = save_manager.run_save_path
	original_profile_save_path = save_manager.profile_save_path
	original_profile_loaded = save_manager.profile_loaded
	save_manager.run_save_path = TEST_SAVE_PATH
	save_manager.profile_save_path = TEST_PROFILE_SAVE_PATH
	save_manager.clear_run()
	_clear_profile_test_files()

	_run_test("保存并恢复核心局内状态", _test_save_and_restore_core_state)
	_run_test("异常快照拒绝与安全回退", _test_invalid_snapshot_rejection_and_fallback)
	_run_test("存档摘要", _test_run_summary)
	_run_test("v1 牌组迁移", _test_v1_card_instance_migration)
	_run_test("v2 到 v3 默认字段迁移", _test_v2_to_v3_default_field_migration)
	_run_test("v3 字段非法值容错", _test_v3_field_sanitization)
	_run_test("v2 存档文件加载", _test_v2_file_loads_with_v3_defaults)

	_run_test("atomic run save", _test_atomic_run_save)
	_run_test("run save backup rotation", _test_run_save_backup_rotation)
	_run_test("corrupt run primary recovery", _test_corrupt_run_primary_recovery)
	_run_test("missing run primary recovery", _test_missing_run_primary_recovery)
	_run_test("profile backup rotation", _test_profile_backup_rotation)
	_run_test("corrupt profile primary recovery", _test_corrupt_profile_primary_recovery)
	_run_test("clear run save family", _test_clear_run_save_family)

	save_manager.clear_run()
	_clear_profile_test_files()
	save_manager.run_save_path = original_save_path
	save_manager.profile_save_path = original_profile_save_path
	save_manager.profile_loaded = original_profile_loaded

	print("Save manager tests: %d passed, %d failed" % [passed_tests, failures.size()])
	if failures.is_empty():
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _run_test(test_name: String, test_callable: Callable) -> void:
	var failure_count_before: int = failures.size()
	test_callable.call()
	if failures.size() == failure_count_before:
		passed_tests += 1
		print("[PASS] %s" % test_name)
	else:
		print("[FAIL] %s" % test_name)


func _test_save_and_restore_core_state() -> void:
	game_manager.reset_run()
	game_manager.player_max_hp = 135
	game_manager.player_hp = 73
	game_manager.coins = 146
	game_manager.current_node_id = "C1-04B"
	game_manager.deck.clear()
	var ember_one: Dictionary = game_manager.create_card_instance("ember_slash", 1)
	var frost: Dictionary = game_manager.create_card_instance("frost_guard")
	var ember_two: Dictionary = game_manager.create_card_instance("ember_slash")
	game_manager.deck.assign([ember_one, frost, ember_two])
	game_manager.draw_pile.assign([String(frost.get("instance_id", ""))])
	game_manager.discard_pile.assign([String(ember_two.get("instance_id", ""))])
	game_manager.hand.assign([String(ember_one.get("instance_id", ""))])
	game_manager.relics.assign(["ash_pot"])

	_expect(save_manager.save_run(), "有效局内状态应成功保存。")
	_expect(save_manager.has_run_save(), "保存后测试存档文件应存在。")

	game_manager.player_hp = 1
	game_manager.coins = 0
	game_manager.current_node_id = "C1-00"
	game_manager.reset_run()

	_expect(save_manager.load_run(), "有效存档应成功加载。")
	_expect(game_manager.player_max_hp == 135, "加载后最大 HP 应恢复。")
	_expect(game_manager.player_hp == 73, "加载后当前 HP 应恢复。")
	_expect(game_manager.coins == 146, "加载后金币应恢复。")
	_expect(game_manager.current_node_id == "C1-04B", "加载后当前节点应恢复。")
	_expect(_deck_card_ids() == ["ember_slash", "frost_guard", "ember_slash"], "加载后牌组及重复牌应恢复。")
	_expect(game_manager.get_card_level(String(game_manager.deck[0].get("instance_id", ""))) == 1, "加载后指定实例的精研状态应恢复。")
	_expect(game_manager.get_card_level(String(game_manager.deck[2].get("instance_id", ""))) == 0, "同名未精研副本应保持基础等级。")
	_expect(game_manager.relics == ["ash_pot"], "加载后遗物应恢复。")


func _test_invalid_snapshot_rejection_and_fallback() -> void:
	game_manager.reset_run()
	game_manager.player_hp = 88
	_expect(
		not game_manager.restore_save_snapshot({"current_node_id": "C1-01"}),
		"缺少牌组的快照应被拒绝。"
	)
	_expect(game_manager.player_hp == 88, "拒绝无效快照时不应破坏当前状态。")
	_expect(
		not game_manager.restore_save_snapshot({
			"current_node_id": "INVALID_NODE",
			"deck": ["ember_slash"],
		}),
		"包含非法节点的快照应被拒绝。"
	)

	var recoverable_snapshot: Dictionary = {
		"current_node_id": "C1-01",
		"deck": ["ember_slash", "invalid_card"],
		"player_max_hp": -10,
		"player_hp": 999,
		"coins": -20,
		"relics": ["ash_pot", "invalid_relic"],
		"upgraded_cards": {"ember_slash": 2, "invalid_card": 1},
	}
	_expect(game_manager.restore_save_snapshot(recoverable_snapshot), "必填字段有效时，缺失可选字段应安全回退。")
	_expect(game_manager.player_max_hp == 1, "异常最大 HP 应回退到安全下限。")
	_expect(game_manager.player_hp == 1, "当前 HP 应限制在恢复后的最大 HP 内。")
	_expect(game_manager.coins == 0, "负数金币应回退为零。")
	_expect(game_manager.relics == ["ash_pot"], "非法遗物应被过滤。")
	_expect(_deck_card_ids() == ["ember_slash"], "牌组中的非法卡牌应被过滤。")
	_expect(game_manager.get_card_level(String(game_manager.deck[0].get("instance_id", ""))) == 1, "旧升级数据应迁移到有效卡牌实例。")
	_expect(game_manager.pigment == 0, "缺失的可选颜料字段应使用默认值。")
	_expect(game_manager.current_options.is_empty(), "缺失的可选路线字段应安全回退为空。")


func _test_run_summary() -> void:
	game_manager.reset_run()
	game_manager.player_max_hp = 128
	game_manager.player_hp = 64
	game_manager.coins = 91
	game_manager.deck.clear()
	game_manager.deck.assign([
		game_manager.create_card_instance("ember_slash"),
		game_manager.create_card_instance("ember_slash"),
		game_manager.create_card_instance("frost_guard"),
	])
	_expect(save_manager.save_run(), "摘要测试存档应成功写入。")
	_expect(
		save_manager.get_run_summary() == "HP 64/128 · 金币 91 · 牌组 3",
		"get_run_summary() 应返回正确的 HP、金币与牌组数量。"
	)


func _test_v1_card_instance_migration() -> void:
	var legacy_payload: Dictionary = {
		"save_version": 1,
		"build_version": "0.4.0-dev",
		"run": {
			"current_node_id": "C1-01",
			"deck": ["ember_slash", "ember_slash", "frost_guard"],
			"hand": ["ember_slash"],
			"draw_pile": ["frost_guard"],
			"discard_pile": ["ember_slash"],
			"retained_card_id": "ember_slash",
			"upgraded_cards": {"ember_slash": 1},
		},
	}
	var file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy_payload))
	file.close()
	_expect(save_manager.load_run(), "v1 字符串牌组存档应自动迁移。")
	_expect(game_manager.deck.size() == 3, "迁移后应保留全部重复牌。")
	_expect(_unique_instance_count() == 3, "迁移后每张牌都应获得唯一实例 ID。")
	_expect(game_manager.get_upgraded_card_count() == 2, "v1 同名升级规则应迁移到两个对应实例。")
	_expect(game_manager.retained_card_instance_id != "", "v1 保留牌应迁移为实例 ID。")
	_expect(game_manager.hand.has(game_manager.retained_card_instance_id), "迁移后的保留实例必须仍在手牌中。")


func _test_v2_to_v3_default_field_migration() -> void:
	var legacy_run: Dictionary = {
		"current_node_id": "C1-01",
		"deck": [{"instance_id": "card_000001", "card_id": "ember_slash", "level": 0}],
	}
	var original: Dictionary = legacy_run.duplicate(true)
	var migrated: Dictionary = save_manager._migrate_run(legacy_run, 2)
	_expect(save_manager.SAVE_VERSION == 4, "当前存档结构版本必须为 4。")
	_expect(legacy_run == original, "v2 到 v3 迁移不得原地修改旧存档数据。")
	_expect(int(migrated.get("ascension_level", -1)) == 0, "v2 缺失进阶等级时必须回退到 A0。")
	_expect(migrated.get("run_stats") is Dictionary and migrated["run_stats"].is_empty(), "v2 缺失统计时必须补为空统计字典。")
	_expect(
		migrated.get("map_template_ids") == {"C1": "standard", "C2": "standard", "C3": "standard"},
		"v2 缺失地图模板时必须补齐三章 standard。"
	)
	_expect(
		migrated.get("peg_upgrades") == {"critical": 0, "echo": 0, "bounty": 0, "pierce": 0},
		"v2 缺失钉板强化时必须补齐四项零级强化。"
	)


func _test_v3_field_sanitization() -> void:
	var malformed: Dictionary = {
		"ascension_level": 999,
		"run_stats": ["invalid"],
		"map_template_ids": {
			"C1": "risk",
			"C2": "removed_template",
			"C3": 42,
			"C4": "economy",
		},
		"peg_upgrades": {
			"critical": 99,
			"echo": -8,
			"bounty": "2",
			"pierce": {"invalid": true},
			"unknown": 3,
		},
	}
	var migrated: Dictionary = save_manager._migrate_run(malformed, 2)
	_expect(int(migrated["ascension_level"]) == 10, "过高进阶必须限制为 A10。")
	_expect(migrated["run_stats"].is_empty(), "非法统计数据必须回退为空字典。")
	_expect(
		migrated["map_template_ids"] == {"C1": "risk", "C2": "standard", "C3": "standard"},
		"迁移必须保留合法模板，并将缺失或非法模板回退为 standard。"
	)
	_expect(
		migrated["peg_upgrades"] == {"critical": 3, "echo": 0, "bounty": 2, "pierce": 0},
		"钉板强化必须过滤未知键、容错非法类型并限制在 0-3。"
	)
	var low: Dictionary = save_manager._migrate_run({"ascension_level": -50}, 3)
	_expect(int(low["ascension_level"]) == 0, "过低进阶必须限制为 A0。")


func _test_v2_file_loads_with_v3_defaults() -> void:
	var legacy_payload: Dictionary = {
		"save_version": 2,
		"build_version": "1.4.0",
		"run": {
			"current_node_id": "C1-01",
			"deck": [{"instance_id": "card_000001", "card_id": "ember_slash", "level": 0}],
			"hand": [],
			"draw_pile": ["card_000001"],
			"discard_pile": [],
			"ascension_level": 80,
			"map_template_ids": {"C1": "economy", "C2": "invalid"},
			"peg_upgrades": {"critical": 8, "echo": 1, "bounty": -1, "invalid": 2},
		},
	}
	var file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy_payload))
	file.close()
	_expect(save_manager.load_run(), "v2 存档文件必须能够迁移并加载。")
	_expect(game_manager.ascension_level == 10, "v2 文件中的进阶等级必须按 A0-A10 限制。")
	_expect(
		game_manager.map_template_ids == {"C1": "economy", "C2": "standard", "C3": "standard"},
		"v2 文件缺失或非法地图模板必须安全回退。"
	)
	_expect(
		game_manager.peg_upgrades == {"critical": 3, "echo": 1, "bounty": 0, "pierce": 0},
		"v2 文件中的非法钉板强化必须安全规范化。"
	)
	_expect(bool(game_manager.run_stats.summary().get("started", false)), "v2 文件缺失统计时必须初始化可用的本局统计。")


func _test_atomic_run_save() -> void:
	_clear_run_test_files()
	game_manager.reset_run()
	game_manager.player_hp = 101
	_expect(save_manager.save_run(), "atomic run save should succeed")
	_expect(FileAccess.file_exists(TEST_SAVE_PATH), "atomic run save should create the primary")
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH + ".tmp"), "atomic run save should clean the temporary file")
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH + ".bak"), "the first run save should not create a backup")


func _test_run_save_backup_rotation() -> void:
	_clear_run_test_files()
	game_manager.reset_run()
	game_manager.player_hp = 77
	_expect(save_manager.save_run(), "the first run save should succeed")
	game_manager.player_hp = 88
	_expect(save_manager.save_run(), "the second run save should succeed")
	var backup: Dictionary = _read_json_file(TEST_SAVE_PATH + ".bak")
	_expect(int(backup.get("run", {}).get("player_hp", -1)) == 77, "the backup should contain the previous run state")
	_expect(int(_read_json_file(TEST_SAVE_PATH).get("run", {}).get("player_hp", -1)) == 88, "the primary should contain the newest run state")


func _test_corrupt_run_primary_recovery() -> void:
	_clear_run_test_files()
	game_manager.reset_run()
	game_manager.player_hp = 77
	_expect(save_manager.save_run(), "the recovery seed save should succeed")
	game_manager.player_hp = 88
	_expect(save_manager.save_run(), "the recovery rotation save should succeed")
	_write_test_file(TEST_SAVE_PATH, "{\"broken\":true}")
	game_manager.player_hp = 1
	_expect(save_manager.load_run(), "a corrupt run primary should recover from the backup")
	_expect(game_manager.player_hp == 77, "run recovery should restore the backup state")
	_expect(int(_read_json_file(TEST_SAVE_PATH).get("run", {}).get("player_hp", -1)) == 77, "run recovery should repair the primary")
	_expect(int(_read_json_file(TEST_SAVE_PATH + ".bak").get("run", {}).get("player_hp", -1)) == 77, "run recovery should retain the backup")


func _test_missing_run_primary_recovery() -> void:
	_clear_run_test_files()
	game_manager.reset_run()
	game_manager.player_hp = 66
	_expect(save_manager.save_run(), "the missing-primary seed save should succeed")
	game_manager.player_hp = 99
	_expect(save_manager.save_run(), "the missing-primary rotation save should succeed")
	_clear_test_file(TEST_SAVE_PATH)
	game_manager.player_hp = 1
	_expect(save_manager.has_run_save(), "a valid run backup should count as an available save")
	_expect(save_manager.load_run(), "a missing run primary should recover from the backup")
	_expect(game_manager.player_hp == 66, "missing-primary recovery should restore the backup state")
	_expect(FileAccess.file_exists(TEST_SAVE_PATH), "missing-primary recovery should recreate the primary")
	_expect(FileAccess.file_exists(TEST_SAVE_PATH + ".bak"), "missing-primary recovery should retain the backup")


func _test_profile_backup_rotation() -> void:
	_clear_profile_test_files()
	game_manager.unlocked_memory_ids.clear()
	game_manager.unlocked_memory_ids.append("M01")
	game_manager.equipped_memory_ids.clear()
	game_manager.equipped_memory_ids.append("M01")
	game_manager.memory_insight = 3
	_expect(save_manager.save_profile(), "the first profile save should succeed")
	game_manager.memory_insight = 8
	_expect(save_manager.save_profile(), "the second profile save should succeed")
	var backup: Dictionary = _read_json_file(TEST_PROFILE_SAVE_PATH + ".bak")
	_expect(int(backup.get("profile", {}).get("memory_insight", -1)) == 3, "the profile backup should contain the previous profile state")
	_expect(not FileAccess.file_exists(TEST_PROFILE_SAVE_PATH + ".tmp"), "profile save should clean the temporary file")


func _test_corrupt_profile_primary_recovery() -> void:
	_clear_profile_test_files()
	game_manager.unlocked_memory_ids.clear()
	game_manager.unlocked_memory_ids.append("M01")
	game_manager.equipped_memory_ids.clear()
	game_manager.equipped_memory_ids.append("M01")
	game_manager.memory_insight = 4
	_expect(save_manager.save_profile(), "the profile recovery seed save should succeed")
	game_manager.memory_insight = 9
	_expect(save_manager.save_profile(), "the profile recovery rotation save should succeed")
	_write_test_file(TEST_PROFILE_SAVE_PATH, "{\"broken\":true}")
	game_manager.memory_insight = 0
	_expect(save_manager.load_profile(), "a corrupt profile primary should recover from the backup")
	_expect(game_manager.memory_insight == 4, "profile recovery should restore the backup state")
	_expect(int(_read_json_file(TEST_PROFILE_SAVE_PATH).get("profile", {}).get("memory_insight", -1)) == 4, "profile recovery should repair the primary")
	_expect(int(_read_json_file(TEST_PROFILE_SAVE_PATH + ".bak").get("profile", {}).get("memory_insight", -1)) == 4, "profile recovery should retain the backup")


func _test_clear_run_save_family() -> void:
	_clear_run_test_files()
	game_manager.reset_run()
	_expect(save_manager.save_run(), "clear-run setup save should succeed")
	game_manager.player_hp = 42
	_expect(save_manager.save_run(), "clear-run setup rotation should succeed")
	_write_test_file(TEST_SAVE_PATH + ".tmp", "stale temporary data")
	save_manager.clear_run()
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH), "clear_run should remove the primary")
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH + ".tmp"), "clear_run should remove the temporary file")
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH + ".bak"), "clear_run should remove the backup")


func _deck_card_ids() -> Array[String]:
	var result: Array[String] = []
	for card in game_manager.deck:
		result.append(String(card.get("card_id", "")))
	return result


func _unique_instance_count() -> int:
	var ids: Dictionary = {}
	for card in game_manager.deck:
		ids[String(card.get("instance_id", ""))] = true
	return ids.size()


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)


func _clear_run_test_files() -> void:
	_clear_test_file(TEST_SAVE_PATH)
	_clear_test_file(TEST_SAVE_PATH + ".tmp")
	_clear_test_file(TEST_SAVE_PATH + ".bak")


func _clear_profile_test_files() -> void:
	_clear_test_file(TEST_PROFILE_SAVE_PATH)
	_clear_test_file(TEST_PROFILE_SAVE_PATH + ".tmp")
	_clear_test_file(TEST_PROFILE_SAVE_PATH + ".bak")


func _write_test_file(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("unable to create test fixture: %s" % path)
		return
	file.store_string(text)
	file.flush()
	file.close()


func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _clear_test_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
