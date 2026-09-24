extends SceneTree

const SpectrumManagerScript = preload("res://scripts/SpectrumManager.gd")


class ConfigurableSpectrumManager:
	extends SpectrumManager

	var card_overrides: Dictionary = {}

	func _card_data(card_instance: Dictionary) -> Dictionary:
		var card: Dictionary = super._card_data(card_instance)
		var card_id: String = String(card_instance.get("card_id", ""))
		if card_overrides.has(card_id):
			card.merge(card_overrides[card_id], true)
		return card


var failures: Array[String] = []
var cases_run: int = 0
var cases_passed: int = 0
var current_case: String = ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_case("red/fireline accepts a cascade clear", _test_fireline_accepts_cascade_clear)
	_run_case("red/fireline checks moves after the swap", _test_fireline_checks_moves_after_swap)
	_run_case("blue/frostline requires an active blue clear", _test_frostline_requires_active_blue)
	_run_case("blue/frostline base waits for a cascade", _test_frostline_base_waits_for_cascade)
	_run_case("blue/frostline upgrade completes on active blue", _test_frostline_upgrade_completes_on_active_blue)
	_run_case("gold/royal coin reads coin_threshold", _test_royal_coin_reads_coin_threshold)
	_run_case("gold/royal coin requires a gold clear", _test_royal_coin_requires_gold_clear)
	_run_case("gold/golden finale uses base battle_coins", _test_golden_finale_base_threshold)
	_run_case("gold/golden finale uses upgraded battle_coins", _test_golden_finale_upgrade_threshold)
	_run_case("gold/caravan beat requires active clear", _test_caravan_beat_requires_active_clear)
	_run_case("gray/gray king uses base corruption_threshold", _test_gray_king_base_threshold)
	_run_case("gray/gray king uses upgraded corruption_threshold", _test_gray_king_upgrade_threshold)
	_run_case("gray/gray blade requires active clear", _test_gray_blade_requires_active_clear)
	_run_case("blue/zero finale base needs consecutive turns", _test_zero_finale_base_needs_consecutive_turns)
	_run_case("blue/zero finale upgrade needs one turn", _test_zero_finale_upgrade_needs_one_turn)
	_run_case("mixed/colorless pause allows one completion per color", _test_colorless_pause_allows_one_per_color)
	_run_case("mixed/colorless pause blocks a second same-color completion", _test_colorless_pause_blocks_second_same_color)
	_run_case("mixed/colorless pause reads same_color_completed_max", _test_colorless_pause_reads_same_color_completed_max)
	_run_case("mixed/prism concerto requires red blue and gold", _test_prism_concerto_requires_three_colors)

	var failed_cases: int = cases_run - cases_passed
	print("V1 spectrum tests: %d cases, %d passed, %d failed" % [cases_run, cases_passed, failed_cases])
	if failures.is_empty():
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _run_case(case_name: String, test_case: Callable) -> void:
	cases_run += 1
	current_case = case_name
	var failures_before: int = failures.size()
	test_case.call()
	if failures.size() == failures_before:
		cases_passed += 1


func _test_fireline_accepts_cascade_clear() -> void:
	var manager: SpectrumManager = _manager_with([_card("fireline", "fireline_dash")])
	var fired: Array[Dictionary] = _clear(
		manager,
		"red",
		3,
		2,
		false,
		{"moves_left": 2, "moves_left_after": 1}
	)
	_expect(_has_fired(fired, "fireline_dash"), "Fireline Dash should accept a red cascade while at least one move remains.")


func _test_fireline_checks_moves_after_swap() -> void:
	var manager: SpectrumManager = _manager_with([_card("fireline", "fireline_dash")])
	var fired: Array[Dictionary] = _clear(
		manager,
		"red",
		3,
		1,
		true,
		{"moves_left": 1, "moves_left_after": 0}
	)
	_expect(not _has_fired(fired, "fireline_dash"), "Fireline Dash should use moves_left_after and fail when the swap spends the last move.")


func _test_frostline_requires_active_blue() -> void:
	var manager: SpectrumManager = _manager_with([_card("frostline", "frostline_plan")])
	_clear(manager, "blue", 3, 1, false)
	var fired: Array[Dictionary] = _clear(manager, "red", 3, 2, false)
	_expect(not _has_fired(fired, "frostline_plan"), "A non-active blue clear must not prime Frostline Plan.")


func _test_frostline_base_waits_for_cascade() -> void:
	var manager: SpectrumManager = _manager_with([_card("frostline", "frostline_plan")])
	var active_fired: Array[Dictionary] = _clear(manager, "blue", 3, 1, true)
	var cascade_fired: Array[Dictionary] = _clear(manager, "red", 3, 2, false)
	_expect(
		not _has_fired(active_fired, "frostline_plan") and _has_fired(cascade_fired, "frostline_plan"),
		"Base Frostline Plan should trigger only after an active blue clear is followed by a cascade."
	)


func _test_frostline_upgrade_completes_on_active_blue() -> void:
	var manager: SpectrumManager = _manager_with([_card("frostline_plus", "frostline_plan", 1)])
	var fired: Array[Dictionary] = _clear(manager, "blue", 3, 1, true)
	_expect(_has_fired(fired, "frostline_plan"), "Upgraded Frostline Plan should complete on the active blue clear itself.")


func _test_royal_coin_reads_coin_threshold() -> void:
	var manager: SpectrumManager = _configurable_manager_with(
		[_card("royal", "royal_coin")],
		{"royal_coin": {"coin_threshold": 79}}
	)
	var fired: Array[Dictionary] = _clear(manager, "gold", 3, 1, true, {"coins": 79})
	_expect(_has_fired(fired, "royal_coin"), "Royal Coin should read coin_threshold instead of a fallback field or value.")


func _test_royal_coin_requires_gold_clear() -> void:
	var manager: SpectrumManager = _manager_with([_card("royal", "royal_coin")])
	var fired: Array[Dictionary] = _clear(manager, "red", 3, 1, true, {"coins": 80})
	_expect(not _has_fired(fired, "royal_coin"), "Royal Coin must not complete on a non-gold clear.")


func _test_golden_finale_base_threshold() -> void:
	var below_manager: SpectrumManager = _manager_with([_card("finale_below", "golden_finale")])
	var below: Array[Dictionary] = _clear(below_manager, "red", 3, 1, true, {"battle_gold_earned": 23})
	var exact_manager: SpectrumManager = _manager_with([_card("finale_exact", "golden_finale")])
	var exact: Array[Dictionary] = _clear(exact_manager, "red", 3, 1, true, {"battle_gold_earned": 24})
	_expect(
		not _has_fired(below, "golden_finale") and _has_fired(exact, "golden_finale"),
		"Base Golden Finale should complete exactly at battle_coins 24."
	)


func _test_golden_finale_upgrade_threshold() -> void:
	var manager: SpectrumManager = _manager_with([_card("finale_plus", "golden_finale", 1)])
	var fired: Array[Dictionary] = _clear(manager, "blue", 3, 1, true, {"battle_gold_earned": 23})
	_expect(_has_fired(fired, "golden_finale"), "Upgraded Golden Finale should read battle_coins 23.")


func _test_caravan_beat_requires_active_clear() -> void:
	var inactive_manager: SpectrumManager = _manager_with([_card("caravan_inactive", "caravan_beat")])
	var inactive: Array[Dictionary] = _clear(inactive_manager, "gold", 4, 1, false)
	var active_manager: SpectrumManager = _manager_with([_card("caravan_active", "caravan_beat")])
	var active: Array[Dictionary] = _clear(active_manager, "gold", 4, 1, true)
	_expect(
		not _has_fired(inactive, "caravan_beat") and _has_fired(active, "caravan_beat"),
		"Caravan Beat should use event.active, not cascade number, for an active match."
	)


func _test_gray_king_base_threshold() -> void:
	var below_manager: SpectrumManager = _manager_with([_card("gray_king_below", "gray_king_contract")])
	var below: Array[Dictionary] = _clear(below_manager, "red", 3, 1, true, {"gray_pressure": 7})
	var exact_manager: SpectrumManager = _manager_with([_card("gray_king_exact", "gray_king_contract")])
	var exact: Array[Dictionary] = _clear(exact_manager, "red", 3, 1, true, {"gray_pressure": 8})
	_expect(
		not _has_fired(below, "gray_king_contract") and _has_fired(exact, "gray_king_contract"),
		"Base Gray King Contract should complete exactly at corruption_threshold 8."
	)


func _test_gray_king_upgrade_threshold() -> void:
	var manager: SpectrumManager = _manager_with([_card("gray_king_plus", "gray_king_contract", 1)])
	var fired: Array[Dictionary] = _clear(manager, "gold", 3, 1, true, {"gray_pressure": 7})
	_expect(_has_fired(fired, "gray_king_contract"), "Upgraded Gray King Contract should read corruption_threshold 7.")


func _test_gray_blade_requires_active_clear() -> void:
	var inactive_manager: SpectrumManager = _manager_with([_card("gray_blade_inactive", "gray_blade")])
	var inactive: Array[Dictionary] = _clear(inactive_manager, "gray", 4, 1, false)
	var active_manager: SpectrumManager = _manager_with([_card("gray_blade_active", "gray_blade")])
	var active: Array[Dictionary] = _clear(active_manager, "gray", 4, 1, true)
	_expect(
		not _has_fired(inactive, "gray_blade") and _has_fired(active, "gray_blade"),
		"Gray Blade should use event.active, not cascade number, for an active match."
	)


func _test_zero_finale_base_needs_consecutive_turns() -> void:
	var manager: SpectrumManager = _manager_with([
		_card("cold_one", "cold_wall"),
		_card("zero_one", "zero_finale"),
	])
	var first_turn: Array[Dictionary] = _clear(manager, "blue", 6, 1, true)
	manager.begin_turn([
		_card("cold_two", "cold_wall"),
		_card("zero_two", "zero_finale"),
	])
	var second_turn: Array[Dictionary] = _clear(manager, "blue", 6, 1, true)
	_expect(
		not _has_fired(first_turn, "zero_finale") and _has_fired(second_turn, "zero_finale"),
		"Base Zero Finale should require blue spectra on two consecutive turns."
	)


func _test_zero_finale_upgrade_needs_one_turn() -> void:
	var manager: SpectrumManager = _manager_with([
		_card("cold", "cold_wall"),
		_card("zero_plus", "zero_finale", 1),
	])
	var fired: Array[Dictionary] = _clear(manager, "blue", 6, 1, true)
	_expect(_has_fired(fired, "zero_finale"), "Upgraded Zero Finale should honor consecutive_turns 1.")


func _test_colorless_pause_allows_one_per_color() -> void:
	var manager: SpectrumManager = _manager_with([
		_card("ember", "ember_slash"),
		_card("pause", "colorless_pause"),
	])
	var fired: Array[Dictionary] = _clear(manager, "red", 5, 1, true)
	_expect(_has_fired(fired, "colorless_pause"), "Colorless Pause should complete when no color has more than one completed spectrum.")


func _test_colorless_pause_blocks_second_same_color() -> void:
	var manager: SpectrumManager = _manager_with([
		_card("ember_one", "ember_slash"),
		_card("ember_two", "ember_slash"),
		_card("pause", "colorless_pause"),
	])
	var fired: Array[Dictionary] = _clear(manager, "red", 5, 1, true)
	_expect(not _has_fired(fired, "colorless_pause"), "Colorless Pause should fail after a second same-color spectrum completes.")


func _test_colorless_pause_reads_same_color_completed_max() -> void:
	var manager: SpectrumManager = _configurable_manager_with(
		[
			_card("ember_one", "ember_slash"),
			_card("ember_two", "ember_slash"),
			_card("pause", "colorless_pause"),
		],
		{"colorless_pause": {"same_color_completed_max": 2}}
	)
	var fired: Array[Dictionary] = _clear(manager, "red", 5, 1, true)
	_expect(_has_fired(fired, "colorless_pause"), "Colorless Pause should read same_color_completed_max instead of hard-coding 1.")


func _test_prism_concerto_requires_three_colors() -> void:
	var manager: SpectrumManager = _manager_with([_card("prism", "prism_concerto")])
	_clear(manager, "red", 3, 1, true)
	var after_two: Array[Dictionary] = _clear(manager, "blue", 3, 2, false)
	var after_three: Array[Dictionary] = _clear(manager, "gold", 3, 3, false)
	_expect(
		not _has_fired(after_two, "prism_concerto") and _has_fired(after_three, "prism_concerto"),
		"Prism Concerto should require red, blue, and gold clear events in the same turn."
	)


func _manager_with(cards: Array[Dictionary]) -> SpectrumManager:
	var manager: SpectrumManager = SpectrumManagerScript.new()
	manager.begin_turn(cards)
	return manager


func _configurable_manager_with(cards: Array[Dictionary], overrides: Dictionary) -> SpectrumManager:
	var manager: ConfigurableSpectrumManager = ConfigurableSpectrumManager.new()
	manager.card_overrides = overrides.duplicate(true)
	manager.begin_turn(cards)
	return manager


func _clear(
	manager: SpectrumManager,
	color_key: String,
	count: int,
	cascade: int,
	active: bool,
	extra_context: Dictionary = {}
) -> Array[Dictionary]:
	var context: Dictionary = {
		"moves_left": 3,
		"moves_left_after": 2,
		"last_red_count": count if color_key == "red" else 0,
		"last_blue_count": count if color_key == "blue" else 0,
		"coins": 0,
		"battle_gold_earned": 0,
		"gray_pressure": 0,
	}
	context.merge(extra_context, true)
	return manager.register_clear_event(
		{"type": color_key, "count": count, "cascade": cascade, "active": active},
		count,
		context
	)


func _card(instance_id: String, card_id: String, level: int = 0) -> Dictionary:
	return {"instance_id": instance_id, "card_id": card_id, "level": level}


func _has_fired(fired: Array[Dictionary], card_id: String) -> bool:
	for trigger in fired:
		if String(trigger.get("card_id", "")) == card_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[%s] %s" % [current_case, message])
