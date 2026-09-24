extends SceneTree

const BattleManagerScript = preload("res://scripts/BattleManager.gd")
const EnemyScript = preload("res://scripts/Enemy.gd")
const GameDataScript = preload("res://scripts/GameData.gd")
const SpectrumResolutionScript = preload("res://scripts/SpectrumResolution.gd")

var failures: Array[String] = []
var game_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	game_manager = root.get_node("GameManager")
	_test_content_scale()
	_test_character_spectrum_profiles()
	_test_boss_intents_are_distinct()
	_test_resolution_modifiers()
	_test_rarity_resolution_curve()
	await _test_enemy_disruption_lifecycle()
	if failures.is_empty():
		print("V1.4 ecosystem tests passed: 6")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_content_scale() -> void:
	_expect(GameDataScript.SPECTRA.size() >= 85, "Later releases must retain at least the complete 1.4 spectrum catalog.")
	_expect(GameDataScript.RELICS.size() >= 72, "Later releases must retain at least 72 relics.")
	_expect(GameDataScript.EVENTS.size() >= 36, "Later releases must retain at least 36 events.")
	for card_id in ["flame_lane", "mist_borer", "mirror_cadence", "refracted_duet", "royal_lockpick", "four_color_barrage"]:
		_expect(GameDataScript.SPECTRA.has(card_id), "Missing retained spectrum: %s." % card_id)


func _test_character_spectrum_profiles() -> void:
	var signatures: Dictionary = {}
	for character_id in ["red", "blue", "gold", "gray", "mixed"]:
		var character: Dictionary = GameDataScript.STARTING_ARCHETYPES.get(character_id, {})
		var profile: Dictionary = character.get("spectrum_profile", {})
		_expect(not profile.is_empty(), "%s must define a spectrum-resolution profile." % character_id)
		signatures[str(profile)] = true
	_expect(signatures.size() == 5, "All five characters must have mechanically distinct spectrum profiles.")


func _test_boss_intents_are_distinct() -> void:
	var first_types: Dictionary = {}
	for encounter_id in ["C1-08", "C2-08", "C3-08"]:
		var boss_enemy: Enemy = EnemyScript.new(GameDataScript.encounter(encounter_id))
		first_types[String(boss_enemy.get_current_intent().get("type", ""))] = true
		boss_enemy.hp = int(round(float(boss_enemy.max_hp) * 0.50))
		_expect(boss_enemy.get_boss_phase() == 2, "%s must enter phase two at half health." % encounter_id)
	_expect(first_types.size() == 3, "The three chapter bosses must open with distinct tactical intents.")


func _test_resolution_modifiers() -> void:
	game_manager.reset_run()
	game_manager.configure_starting_archetype("mixed")
	var battle: BattleManager = BattleManagerScript.new()
	battle.GameManager = game_manager
	root.add_child(battle)
	battle.start_battle(GameDataScript.encounter("C2-01"))
	var card: Dictionary = GameDataScript.spectrum_for_level("refracted_duet", 0)
	var modifier: Dictionary = battle._card_resolution_modifier(card)
	var result: Dictionary = SpectrumResolutionScript.resolve(card, {}, modifier)
	_expect(int(result.get("repeat_count", 0)) >= 2, "Refracted Duet must resolve at least twice.")
	_expect(float(result.get("repeat_ratio", 0.0)) >= 0.25, "Repeat damage must stay inside the supported ratio range.")
	var merged: Dictionary = {}
	for _index in range(12):
		merged = battle._merge_spectrum_modifier(merged, {"flat_damage": 1})
	_expect(int(merged.get("flat_damage", 0)) == 12, "Repeated tuning bonuses must aggregate without a hidden queue cap.")
	battle.free()


func _test_rarity_resolution_curve() -> void:
	var common: Dictionary = SpectrumResolutionScript.resolve({"rarity": "common"})
	var rare: Dictionary = SpectrumResolutionScript.resolve({"rarity": "rare"})
	var epic: Dictionary = SpectrumResolutionScript.resolve({"rarity": "epic"})
	_expect(int(common.get("damage", 0)) < int(rare.get("damage", 0)), "Rare spectra must exceed common pulse damage.")
	_expect(int(rare.get("damage", 0)) < int(epic.get("damage", 0)), "Epic spectra must exceed rare pulse damage.")


func _test_enemy_disruption_lifecycle() -> void:
	game_manager.reset_run()
	game_manager.configure_starting_archetype("blue")
	var battle: BattleManager = BattleManagerScript.new()
	battle.GameManager = game_manager
	root.add_child(battle)
	battle.start_battle(GameDataScript.encounter("C2-01"))
	await battle._resolve_intent({"type": "aim_drift", "text": "spectrum suppression", "value": 0.20})
	_expect(not battle.pending_enemy_disruption.is_empty(), "A telegraphed disruption must affect the next completed spectrum.")
	var hp_before: int = battle.enemy.hp
	battle._deal_resolution_pulse({"damage": 20, "color": "red"}, "test_spectrum")
	_expect(hp_before - battle.enemy.hp == 16, "A 20 percent disruption must reduce a 20-damage pulse to 16.")
	_expect(battle.pending_enemy_disruption.is_empty(), "Enemy disruption must be consumed by exactly one completed spectrum.")
	battle.free()


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
