extends SceneTree

const SpectrumManagerScript = preload("res://scripts/SpectrumManager.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_duplicate_cards_trigger_independently()
	_test_ember_upgrade_changes_threshold()
	_test_card_states_have_slot_identity()
	_test_gray_pressure_progress_uses_battle_context()
	_test_drawn_cards_ignore_prior_turn_events()
	if failures.is_empty():
		print("SpectrumManager tests passed: 5")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_duplicate_cards_trigger_independently() -> void:
	var manager: SpectrumManager = SpectrumManagerScript.new()
	manager.begin_turn([
		_card("card_1", "ember_slash"),
		_card("card_2", "ember_slash"),
	])
	var fired: Array[Dictionary] = manager.register_clear_event(
		{"type": "red", "count": 5, "cascade": 1},
		10,
		{"moves_left": 3, "last_red_count": 5, "last_blue_count": 0}
	)
	_expect(fired.size() == 2, "两张同名余烬斩应独立触发。")
	_expect(manager.is_triggered(0) and manager.is_triggered(1), "两个手牌槽位都应记录为已触发。")

func _test_ember_upgrade_changes_threshold() -> void:
	var base_manager: SpectrumManager = SpectrumManagerScript.new()
	base_manager.begin_turn([_card("card_1", "ember_slash")])
	var base_fired: Array[Dictionary] = base_manager.register_clear_event(
		{"type": "red", "count": 4, "cascade": 1},
		10,
		{"moves_left": 3, "last_red_count": 4, "last_blue_count": 0}
	)
	_expect(base_fired.is_empty(), "未升级余烬斩不应在累计 4 红时触发。")

	var upgraded_manager: SpectrumManager = SpectrumManagerScript.new()
	upgraded_manager.begin_turn([_card("card_2", "ember_slash", 1)])
	var upgraded_fired: Array[Dictionary] = upgraded_manager.register_clear_event(
		{"type": "red", "count": 4, "cascade": 1},
		10,
		{"moves_left": 3, "last_red_count": 4, "last_blue_count": 0}
	)
	_expect(upgraded_fired.size() == 1, "精研余烬斩应在累计 4 红时触发。")

func _test_card_states_have_slot_identity() -> void:
	var manager: SpectrumManager = SpectrumManagerScript.new()
	manager.begin_turn([
		_card("frost_1", "frost_guard"),
		_card("frost_2", "frost_guard", 1),
	])
	var states: Array[Dictionary] = manager.get_card_states(1)
	_expect(states.size() == 2, "两张同名色谱应生成两个牌面状态。")
	_expect(String(states[0].get("instance_id", "")) == "frost_1", "第一张牌应保留永久实例标识。")
	_expect(String(states[1].get("instance_id", "")) == "frost_2", "第二张牌应保留永久实例标识。")
	_expect(states[0].get("upgraded", false) == false and states[1].get("upgraded", false) == true, "同名色谱应允许独立精研。")
	_expect(states[1].get("retained", false) == true and states[0].get("retained", false) == false, "保留状态应只标记选中的槽位。")

func _test_gray_pressure_progress_uses_battle_context() -> void:
	var manager: SpectrumManager = SpectrumManagerScript.new()
	manager.begin_turn([_card("ash_1", "ash_usury")])
	manager.evaluate_triggers({"moves_left": 3, "gray_pressure": 3})
	var states: Array[Dictionary] = manager.get_card_states()
	_expect(String(states[0].get("progress", "")) == "灰蚀压力 3/4", "灰蚀进度应显示当前战局压力，而不是卡牌阈值。")

func _test_drawn_cards_ignore_prior_turn_events() -> void:
	var manager: SpectrumManager = SpectrumManagerScript.new()
	manager.begin_turn([
		_card("starter_red", "ember_slash"),
		_card("starter_pause", "colorless_pause"),
	])
	var opening_fired: Array[Dictionary] = manager.register_clear_event(
		{"type": "red", "count": 5, "cascade": 1, "active": true},
		0,
		{"moves_left": 3, "last_red_count": 5, "last_blue_count": 0}
	)
	_expect(opening_fired.size() == 2, "开局红谱与无色停顿应先完成，建立抽牌前历史。")

	manager.add_card_to_hand(_card("drawn_daylight", "daylight_calibration"))
	manager.add_card_to_hand(_card("drawn_red", "ember_slash"))
	_expect(manager.evaluate_triggers({"moves_left": 3}).is_empty(), "新抽色谱不得在无新消除时追溯触发。")
	var states: Array[Dictionary] = manager.get_card_states()
	_expect(String(states[2].get("progress", "")) == "不同色谱 0/2", "新抽白昼校准应从 0 个后续学派开始计数。")
	_expect(String(states[3].get("progress", "")) == "红 0/5", "新抽红谱应从 0 个后续红色格开始计数。")

	var blue_fired: Array[Dictionary] = manager.register_clear_event(
		{"type": "blue", "count": 3, "cascade": 1, "active": true},
		0,
		{"moves_left": 2, "last_red_count": 0, "last_blue_count": 3}
	)
	_expect(blue_fired.is_empty(), "后续蓝消不得让新抽红谱读取抽牌前的 5 个红色格。")
	var red_fired: Array[Dictionary] = manager.register_clear_event(
		{"type": "red", "count": 5, "cascade": 1, "active": true},
		0,
		{"moves_left": 1, "last_red_count": 5, "last_blue_count": 0}
	)
	_expect(red_fired.any(func(trigger: Dictionary) -> bool: return String(trigger.get("instance_id", "")) == "drawn_red"), "新抽红谱应在抽牌后的 5 个红色格达标时正常触发。")

	manager.add_card_to_hand(_card("drawn_tone", "tone_phrase"))
	var cascade_fired: Array[Dictionary] = manager.register_clear_event(
		{"type": "blue", "count": 3, "cascade": 2, "active": true},
		0,
		{"moves_left": 0, "last_red_count": 0, "last_blue_count": 3}
	)
	_expect(cascade_fired.any(func(trigger: Dictionary) -> bool: return String(trigger.get("instance_id", "")) == "drawn_daylight"), "新抽白昼校准应能读取抽牌后完成的两个不同学派。")

func _card(instance_id: String, card_id: String, level: int = 0) -> Dictionary:
	return {"instance_id": instance_id, "card_id": card_id, "level": level}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
