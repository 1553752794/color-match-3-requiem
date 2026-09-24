extends SceneTree

const DataValidatorScript = preload("res://scripts/DataValidator.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_current_game_data_is_valid()
	_test_dangling_edge_is_reported()
	_test_bad_encounter_reference_is_reported()
	_test_unreachable_boss_is_reported()
	_test_invalid_starter_card_is_reported()
	if failures.is_empty():
		print("Data validation tests: 5 passed, 0 failed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_current_game_data_is_valid() -> void:
	var errors: Array[String] = DataValidatorScript.validate_all()
	_expect(errors.is_empty(), "Current GameData should have 0 validation errors, got: %s" % str(errors))


func _test_dangling_edge_is_reported() -> void:
	var fixture: Dictionary = _valid_fixture()
	var nodes: Dictionary = fixture.get("nodes", {})
	var start_node: Dictionary = nodes.get("START", {})
	start_node["edges"] = ["MISSING_NODE"]
	var errors: Array[String] = _validate_fixture(fixture)
	_expect(_has_error(errors, "[DANGLING_EDGE]"), "A dangling node edge should be reported.")


func _test_bad_encounter_reference_is_reported() -> void:
	var fixture: Dictionary = _valid_fixture()
	var nodes: Dictionary = fixture.get("nodes", {})
	var combat_node: Dictionary = nodes.get("COMBAT", {})
	combat_node["encounter_id"] = "MISSING_ENCOUNTER"
	var errors: Array[String] = _validate_fixture(fixture)
	_expect(_has_error(errors, "[BAD_ENCOUNTER_REF]"), "An unknown encounter reference should be reported.")


func _test_unreachable_boss_is_reported() -> void:
	var fixture: Dictionary = _valid_fixture()
	var nodes: Dictionary = fixture.get("nodes", {})
	var combat_node: Dictionary = nodes.get("COMBAT", {})
	combat_node["edges"] = []
	var errors: Array[String] = _validate_fixture(fixture)
	_expect(_has_error(errors, "[UNREACHABLE_BOSS]"), "An unreachable boss should be reported.")


func _test_invalid_starter_card_is_reported() -> void:
	var fixture: Dictionary = _valid_fixture()
	fixture["initial_deck"] = ["missing_card"]
	var errors: Array[String] = _validate_fixture(fixture)
	_expect(_has_error(errors, "[INVALID_STARTER_CARD]"), "An unknown starter card should be reported.")


func _valid_fixture() -> Dictionary:
	var spectra: Dictionary = {
		"starter_card": {
			"id": "starter_card",
			"name": "Starter Card",
			"color": "red",
			"rarity": "common",
			"condition": "Match red",
			"effect": "Deal damage",
			"short": "Red match",
			"pools": ["common", "starter"],
		},
	}
	var relics: Dictionary = {
		"test_relic": {
			"id": "test_relic",
			"name": "Test Relic",
			"rarity": "common",
			"description": "Test effect",
		},
	}
	var encounters: Dictionary = {
		"combat_encounter": _valid_encounter("combat_encounter", "combat"),
		"boss_encounter": _valid_encounter("boss_encounter", "boss"),
	}
	var nodes: Dictionary = {
		"START": {
			"id": "START",
			"layer": 0,
			"name": "Start",
			"type": "start",
			"edges": ["COMBAT"],
			"description": "Start node",
		},
		"COMBAT": {
			"id": "COMBAT",
			"layer": 1,
			"name": "Combat",
			"type": "combat",
			"encounter_id": "combat_encounter",
			"edges": ["BOSS"],
			"description": "Combat node",
		},
		"BOSS": {
			"id": "BOSS",
			"layer": 2,
			"name": "Boss",
			"type": "boss",
			"encounter_id": "boss_encounter",
			"edges": [],
			"description": "Boss node",
		},
	}
	return {
		"spectra": spectra,
		"relics": relics,
		"encounters": encounters,
		"nodes": nodes,
		"initial_deck": ["starter_card"],
	}


func _valid_encounter(encounter_id: String, node_type: String) -> Dictionary:
	return {
		"id": encounter_id,
		"name": "Test Encounter",
		"enemy_name": "Test Enemy",
		"enemy_id": "EN-TEST",
		"max_hp": 10,
		"attack": 2,
		"reward": 1,
		"reward_pool": ["common"],
		"node_type": node_type,
		"description": "Test encounter",
	}


func _validate_fixture(fixture: Dictionary) -> Array[String]:
	var spectra: Dictionary = fixture.get("spectra", {})
	var relics: Dictionary = fixture.get("relics", {})
	var encounters: Dictionary = fixture.get("encounters", {})
	var nodes: Dictionary = fixture.get("nodes", {})
	var initial_deck: Array = fixture.get("initial_deck", [])
	return DataValidatorScript.validate_registry(spectra, relics, encounters, nodes, initial_deck)


func _has_error(errors: Array[String], code: String) -> bool:
	for error_message in errors:
		if error_message.begins_with(code):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
