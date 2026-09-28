extends Node
class_name BattleManager

signal state_changed(state: Dictionary)
signal damage_event(amount: int, color_key: String)
signal player_hit(amount: int)
signal battle_won
signal battle_lost
signal log_added(message: String)
signal input_lock_changed(is_locked: bool)
signal spectrum_triggered(card_state: Dictionary)
signal spectrum_resolved(result: Dictionary)
signal board_pollution_requested(amount: int)
signal board_cleanse_requested(amount: int)
signal board_dye_requested(color_key: String, amount: int)
signal resonance_changed(state: Dictionary)
signal checkpoint_ready(snapshot: Dictionary)
signal combat_feedback_emitted(feedback: Dictionary)

const EnemyScript = preload("res://scripts/Enemy.gd")
const SpectrumManagerScript = preload("res://scripts/SpectrumManager.gd")
const GameDataScript = preload("res://scripts/GameData.gd")
const AscensionRulesScript = preload("res://scripts/AscensionRules.gd")
const ResonanceSequenceScript = preload("res://scripts/ResonanceSequence.gd")
const SpectrumResolutionScript = preload("res://scripts/SpectrumResolution.gd")

const MAX_MOVES = 3
const BASE_DAMAGE = 10
const BURN_DAMAGE_PER_STACK = 5
const GOLD_SOFT_CAP = 24
const MAX_SKILL_CHARGE = 20
const SNAPSHOT_VERSION: int = 1

var enemy: Enemy
var spectrum_manager: RefCounted
var moves_left: int = MAX_MOVES
var last_combo: int = 0
var resolving: bool = false
var battle_finished: bool = false
var gold_boost_active: bool = false
var gold_bonus_this_battle: int = 0
var completed_mixed_relic_used: bool = false
var charge_refund_used: bool = false
var pollution_relic_used: bool = false
var base_damage_this_step: int = 0
var battle_pigments: Dictionary = {"gray": 0, "red": 0, "blue": 0, "gold": 0}
var skill_charge: int = 0
var pending_spectrum_modifier: Dictionary = {}
var pending_enemy_disruption: Dictionary = {}
var last_spectrum_resolution: Dictionary = {}
var _active_spectrum_id: String = ""
var _active_resolution_damage: int = 0
var player_burn_turns: int = 0
var retained_slots: Array[int] = []
var palette_pigment_awarded: int = 0
var red_condition_reduction: int = 0
var pending_damage_reduction: int = 0
var enemy_polluted_this_battle: bool = false
var gold_cap_removed: bool = false
var color_thread_used_this_turn: bool = false
var molten_ring_used: bool = false
var still_lake_draws: int = 0
var turn_number: int = 0
var self_damage_relic_used: bool = false
var first_flame_used: bool = false
var mist_ward_used: bool = false
var triad_resonance_used: bool = false
var moss_circlet_used_this_turn: bool = false
var echo_metronome_used: bool = false
var dusk_mask_used: bool = false
var cadenza_lens_used: bool = false
var balanced_scale_used: bool = false
var eclipse_vial_used: bool = false
var first_orbit_used: bool = false
var last_boss_phase_seen: int = 0
var target_spectrum_instance_id: String = ""
var resonance_sequence: RefCounted = ResonanceSequenceScript.new()
var GameManager: Node

func _gm() -> Node:
	if GameManager == null:
		GameManager = get_node("/root/GameManager")
	return GameManager

func create_snapshot() -> Dictionary:
	if enemy == null or spectrum_manager == null:
		return {}
	return {
		"snapshot_version": SNAPSHOT_VERSION,
		"node_id": String(GameManager.current_node_id),
		"enemy": enemy.create_snapshot(),
		"spectrum": spectrum_manager.create_snapshot(),
		"moves_left": moves_left,
		"last_combo": last_combo,
		"gold_boost_active": gold_boost_active,
		"gold_bonus_this_battle": gold_bonus_this_battle,
		"completed_mixed_relic_used": completed_mixed_relic_used,
		"charge_refund_used": charge_refund_used,
		"pollution_relic_used": pollution_relic_used,
		"base_damage_this_step": base_damage_this_step,
		"battle_pigments": battle_pigments.duplicate(true),
		"skill_charge": skill_charge,
		"pending_spectrum_modifier": pending_spectrum_modifier.duplicate(true),
		"pending_enemy_disruption": pending_enemy_disruption.duplicate(true),
		"last_spectrum_resolution": last_spectrum_resolution.duplicate(true),
		"active_spectrum_id": _active_spectrum_id,
		"active_resolution_damage": _active_resolution_damage,
		"player_burn_turns": player_burn_turns,
		"retained_slots": retained_slots.duplicate(),
		"palette_pigment_awarded": palette_pigment_awarded,
		"red_condition_reduction": red_condition_reduction,
		"pending_damage_reduction": pending_damage_reduction,
		"enemy_polluted_this_battle": enemy_polluted_this_battle,
		"gold_cap_removed": gold_cap_removed,
		"color_thread_used_this_turn": color_thread_used_this_turn,
		"molten_ring_used": molten_ring_used,
		"still_lake_draws": still_lake_draws,
		"turn_number": turn_number,
		"self_damage_relic_used": self_damage_relic_used,
		"first_flame_used": first_flame_used,
		"mist_ward_used": mist_ward_used,
		"triad_resonance_used": triad_resonance_used,
		"moss_circlet_used_this_turn": moss_circlet_used_this_turn,
		"echo_metronome_used": echo_metronome_used,
		"dusk_mask_used": dusk_mask_used,
		"cadenza_lens_used": cadenza_lens_used,
		"balanced_scale_used": balanced_scale_used,
		"eclipse_vial_used": eclipse_vial_used,
		"first_orbit_used": first_orbit_used,
		"last_boss_phase_seen": last_boss_phase_seen,
		"target_spectrum_instance_id": target_spectrum_instance_id,
		"resonance_sequence": resonance_sequence.snapshot(),
	}

func restore_battle(enemy_data: Dictionary, snapshot_value: Variant) -> bool:
	_gm()
	if not snapshot_value is Dictionary:
		return false
	var snapshot: Dictionary = snapshot_value
	if int(snapshot.get("snapshot_version", 0)) != SNAPSHOT_VERSION:
		return false
	if String(snapshot.get("node_id", "")) != String(GameManager.current_node_id):
		return false
	var restored_enemy: Enemy = EnemyScript.new(enemy_data)
	if not restored_enemy.restore_snapshot(snapshot.get("enemy", {})):
		return false
	var restored_spectrum: SpectrumManager = SpectrumManagerScript.new()
	if not restored_spectrum.restore_snapshot(snapshot.get("spectrum", {})):
		return false
	enemy = restored_enemy
	spectrum_manager = restored_spectrum
	moves_left = clampi(int(snapshot.get("moves_left", MAX_MOVES)), 0, MAX_MOVES + 1)
	last_combo = maxi(int(snapshot.get("last_combo", 0)), 0)
	gold_boost_active = snapshot.get("gold_boost_active", false) == true
	gold_bonus_this_battle = maxi(int(snapshot.get("gold_bonus_this_battle", 0)), 0)
	completed_mixed_relic_used = snapshot.get("completed_mixed_relic_used", false) == true
	charge_refund_used = snapshot.get("charge_refund_used", false) == true
	pollution_relic_used = snapshot.get("pollution_relic_used", false) == true
	base_damage_this_step = maxi(int(snapshot.get("base_damage_this_step", 0)), 0)
	battle_pigments = _restore_battle_pigments(snapshot.get("battle_pigments", {}))
	skill_charge = clampi(int(snapshot.get("skill_charge", 0)), 0, MAX_SKILL_CHARGE)
	pending_spectrum_modifier = snapshot.get("pending_spectrum_modifier", {}).duplicate(true) if snapshot.get("pending_spectrum_modifier", {}) is Dictionary else {}
	pending_enemy_disruption = snapshot.get("pending_enemy_disruption", {}).duplicate(true) if snapshot.get("pending_enemy_disruption", {}) is Dictionary else {}
	last_spectrum_resolution = snapshot.get("last_spectrum_resolution", {}).duplicate(true) if snapshot.get("last_spectrum_resolution", {}) is Dictionary else {}
	_active_spectrum_id = String(snapshot.get("active_spectrum_id", ""))
	_active_resolution_damage = maxi(int(snapshot.get("active_resolution_damage", 0)), 0)
	player_burn_turns = maxi(int(snapshot.get("player_burn_turns", 0)), 0)
	retained_slots = _restore_int_array(snapshot.get("retained_slots", []))
	palette_pigment_awarded = maxi(int(snapshot.get("palette_pigment_awarded", 0)), 0)
	red_condition_reduction = maxi(int(snapshot.get("red_condition_reduction", 0)), 0)
	pending_damage_reduction = maxi(int(snapshot.get("pending_damage_reduction", 0)), 0)
	enemy_polluted_this_battle = snapshot.get("enemy_polluted_this_battle", false) == true
	gold_cap_removed = snapshot.get("gold_cap_removed", false) == true
	color_thread_used_this_turn = snapshot.get("color_thread_used_this_turn", false) == true
	molten_ring_used = snapshot.get("molten_ring_used", false) == true
	still_lake_draws = maxi(int(snapshot.get("still_lake_draws", 0)), 0)
	turn_number = maxi(int(snapshot.get("turn_number", 1)), 1)
	self_damage_relic_used = snapshot.get("self_damage_relic_used", false) == true
	first_flame_used = snapshot.get("first_flame_used", false) == true
	mist_ward_used = snapshot.get("mist_ward_used", false) == true
	triad_resonance_used = snapshot.get("triad_resonance_used", false) == true
	moss_circlet_used_this_turn = snapshot.get("moss_circlet_used_this_turn", false) == true
	echo_metronome_used = snapshot.get("echo_metronome_used", false) == true
	dusk_mask_used = snapshot.get("dusk_mask_used", false) == true
	cadenza_lens_used = snapshot.get("cadenza_lens_used", false) == true
	balanced_scale_used = snapshot.get("balanced_scale_used", false) == true
	eclipse_vial_used = snapshot.get("eclipse_vial_used", false) == true
	first_orbit_used = snapshot.get("first_orbit_used", false) == true
	last_boss_phase_seen = maxi(int(snapshot.get("last_boss_phase_seen", enemy.get_boss_phase() if enemy.boss else 0)), 0)
	target_spectrum_instance_id = String(snapshot.get("target_spectrum_instance_id", ""))
	_sanitize_target_spectrum()
	resonance_sequence.restore(snapshot.get("resonance_sequence", {}))
	resolving = false
	battle_finished = false
	_sync_retained_slots()
	input_lock_changed.emit(false)
	_emit_state()
	_emit_checkpoint()
	return true

func _restore_battle_pigments(value: Variant) -> Dictionary:
	var result: Dictionary = {"gray": 0, "red": 0, "blue": 0, "gold": 0}
	if value is Dictionary:
		for color_key in result.keys():
			result[color_key] = maxi(int(value.get(color_key, 0)), 0)
	return result

func _restore_int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for entry in value:
			result.append(maxi(int(entry), 0))
	return result

func _emit_checkpoint() -> void:
	if resolving or battle_finished or enemy == null or spectrum_manager == null:
		return
	checkpoint_ready.emit(create_snapshot())

func start_battle(enemy_data: Dictionary) -> void:
	_gm()
	enemy = EnemyScript.new(enemy_data)
	spectrum_manager = SpectrumManagerScript.new()
	moves_left = MAX_MOVES
	last_combo = 0
	resolving = false
	battle_finished = false
	gold_boost_active = false
	gold_bonus_this_battle = 0
	completed_mixed_relic_used = false
	charge_refund_used = false
	pollution_relic_used = false
	player_burn_turns = 0
	retained_slots.clear()
	palette_pigment_awarded = 0
	red_condition_reduction = 0
	pending_damage_reduction = 0
	enemy_polluted_this_battle = false
	gold_cap_removed = false
	color_thread_used_this_turn = false
	molten_ring_used = false
	still_lake_draws = 0
	turn_number = 0
	self_damage_relic_used = false
	first_flame_used = false
	mist_ward_used = false
	triad_resonance_used = false
	moss_circlet_used_this_turn = false
	echo_metronome_used = false
	dusk_mask_used = false
	cadenza_lens_used = false
	balanced_scale_used = false
	eclipse_vial_used = false
	first_orbit_used = false
	last_boss_phase_seen = enemy.get_boss_phase() if enemy.boss else 0
	target_spectrum_instance_id = ""
	resonance_sequence.reset()
	battle_pigments = {"gray": 0, "red": 0, "blue": 0, "gold": 0}
	skill_charge = clampi(int(GameManager.get_memory_effect_total("skill_charge_start")), 0, MAX_SKILL_CHARGE)
	pending_spectrum_modifier.clear()
	pending_enemy_disruption.clear()
	last_spectrum_resolution.clear()
	_active_spectrum_id = ""
	_active_resolution_damage = 0
	GameManager.next_pollution_bonus = 0
	if GameManager.relics.has("seed_satchel"):
		GameManager.heal(4)
	if GameManager.relics.has("dawn_candle") and GameManager.gray_pressure <= 3:
		GameManager.add_shield(7)
		log_added.emit("黎明烛在低灰蚀压力下提供 7 护盾。")
	var memory_shield: int = int(GameManager.get_memory_effect_total("first_turn_shield"))
	if memory_shield > 0:
		GameManager.add_shield(memory_shield)
		log_added.emit("回想碎片提供 %d 开局护盾。" % memory_shield)
	var policy_shield: int = GameManager.get_policy_battle_shield()
	if policy_shield > 0:
		GameManager.add_shield(policy_shield)
		log_added.emit("章节政策提供 %d 开局护盾。" % policy_shield)
	if enemy_data.get("final_boss", false) == true:
		var finale_shield: int = GameManager.get_finale_crown_shield()
		if finale_shield > 0:
			GameManager.add_shield(finale_shield)
			log_added.emit("终幕花冠因最低颜色倾向提供 %d 护盾。" % finale_shield)
	_begin_player_turn()
	log_added.emit("%s 出现了。意图：%s" % [enemy.enemy_name, enemy.get_intent_text()])
	input_lock_changed.emit(false)
	_emit_state()
	_emit_checkpoint()

func set_retained_card(instance_id: String) -> void:
	if battle_finished or spectrum_manager == null:
		return
	var slot: int = -1
	for hand_index in range(spectrum_manager.hand.size()):
		if String(spectrum_manager.hand[hand_index].get("instance_id", "")) == instance_id:
			slot = hand_index
			break
	if slot < 0 or slot >= spectrum_manager.hand.size() or spectrum_manager.is_triggered(slot):
		return
	GameManager.retain_card(instance_id, _get_retention_bonus())
	_sync_retained_slots()
	_emit_state()
	_emit_checkpoint()

func set_target_spectrum(instance_id: String) -> bool:
	if battle_finished or spectrum_manager == null:
		return false
	if instance_id.is_empty():
		target_spectrum_instance_id = ""
		_emit_state()
		_emit_checkpoint()
		return true
	for card_state in spectrum_manager.get_card_states(retained_slots):
		if String(card_state.get("instance_id", "")) != instance_id:
			continue
		if card_state.get("triggered", false) == true:
			return false
		target_spectrum_instance_id = instance_id
		_emit_state()
		_emit_checkpoint()
		return true
	return false

func preview_swap(preview: Dictionary) -> Dictionary:
	var result: Dictionary = preview.duplicate(true)
	if result.get("valid", false) != true or spectrum_manager == null:
		return result
	var pigment_by_color: Dictionary = {}
	var red_count: int = 0
	var blue_count: int = 0
	var last_color: String = ""
	for event_value in result.get("clear_events", []):
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var color_key: String = String(event.get("type", ""))
		var amount: int = maxi(int(event.get("count", 0)), 0)
		if color_key.is_empty() or amount <= 0:
			continue
		pigment_by_color[color_key] = int(pigment_by_color.get(color_key, 0)) + _pigment_yield(amount, 1)
		last_color = color_key
		if color_key == "red":
			red_count = max(red_count, amount)
		elif color_key == "blue":
			blue_count = max(blue_count, amount)
	result["pigment_by_color"] = pigment_by_color
	var current_intent: Dictionary = enemy.get_current_intent() if enemy != null else {}
	var preview_context: Dictionary = {
		"moves_left": moves_left,
		"moves_left_after": max(moves_left - 1, 0),
		"last_red_count": red_count,
		"last_blue_count": blue_count,
		"enemy_intent": current_intent,
		"enemy_intent_type": String(current_intent.get("type", "")),
		"enemy_burn_stacks": enemy.burn_stacks if enemy != null else 0,
		"player_hp_ratio": float(GameManager.player_hp) / float(max(GameManager.player_max_hp, 1)),
		"shield": GameManager.shield,
		"coins": GameManager.coins,
		"battle_gold_earned": gold_bonus_this_battle,
		"skipped_reward_previous": GameManager.skipped_card_reward_previous,
		"enemy_polluted_this_battle": enemy_polluted_this_battle,
		"gray_pressure": GameManager.gray_pressure,
		"red_condition_reduction": red_condition_reduction,
		"base_damage": int(pigment_by_color.get("red", 0)) + int(pigment_by_color.get("blue", 0)) + int(pigment_by_color.get("gold", 0)) + int(pigment_by_color.get("gray", 0)),
	}
	var preview_events: Array[Dictionary] = []
	for event_value in result.get("clear_events", []):
		if event_value is Dictionary:
			preview_events.append(event_value)
	var fired: Array[Dictionary] = spectrum_manager.preview_clear_events(preview_events, preview_context)
	var triggerable_instance_ids: Array[String] = []
	var sequence_preview: RefCounted = ResonanceSequenceScript.new()
	sequence_preview.restore(resonance_sequence.snapshot())
	var predicted_resonance: Dictionary = {}
	for trigger in fired:
		var instance_id: String = String(trigger.get("instance_id", ""))
		if not instance_id.is_empty():
			triggerable_instance_ids.append(instance_id)
		var card: Dictionary = GameDataScript.spectrum_for_level(
			String(trigger.get("card_id", "")), int(trigger.get("level", 0))
		)
		var resonance_result: Dictionary = sequence_preview.register_color(String(card.get("color", "neutral")))
		var resonance_value: Dictionary = resonance_result.get("resonance", {})
		if not resonance_value.is_empty():
			predicted_resonance = resonance_value.duplicate(true)
	result["triggerable_instance_ids"] = triggerable_instance_ids
	result["resonance_id"] = String(predicted_resonance.get("id", ""))
	result["resonance_name"] = String(predicted_resonance.get("name", ""))
	result["target_will_trigger"] = triggerable_instance_ids.has(target_spectrum_instance_id)
	result["last_color"] = last_color
	result["risk_text"] = ""
	var intent_type: String = String(current_intent.get("type", ""))
	if intent_type == "spectrum_seal":
		result["risk_text"] = "敌人正在封锁色谱，优先完成目标色谱。"
	elif intent_type == "board_corrupt":
		result["risk_text"] = "敌人准备污染棋盘，尽量利用本次连锁。"
	return result

func get_target_spectrum_state() -> Dictionary:
	_sanitize_target_spectrum()
	if target_spectrum_instance_id.is_empty() or spectrum_manager == null:
		return {}
	for card_state in spectrum_manager.get_card_states(retained_slots):
		if String(card_state.get("instance_id", "")) == target_spectrum_instance_id:
			var result: Dictionary = card_state.duplicate(true)
			result["targeted"] = true
			return result
	return {}

func _sanitize_target_spectrum() -> void:
	if target_spectrum_instance_id.is_empty() or spectrum_manager == null:
		return
	for card_state in spectrum_manager.get_card_states(retained_slots):
		if String(card_state.get("instance_id", "")) == target_spectrum_instance_id and card_state.get("triggered", false) != true:
			return
	target_spectrum_instance_id = ""

func on_player_move(clear_events: Array, cascade_count: int) -> void:
	if resolving or battle_finished or enemy == null:
		return
	resolving = true
	input_lock_changed.emit(true)
	last_combo = cascade_count
	GameManager.run_stats.record("swaps", 1)
	GameManager.run_stats.record("matches", clear_events.size())
	GameManager.run_stats.record("cascades", maxi(cascade_count - 1, 0))
	base_damage_this_step = 0
	_apply_clear_events(clear_events)
	if _check_win():
		resolving = false
		return
	await _finish_player_move()

func use_character_skill() -> bool:
	if battle_finished or resolving:
		return false
	var character: Dictionary = GameManager.get_selected_character()
	var skill: Dictionary = character.get("active_skill", {})
	var cost: int = max(int(skill.get("cost", 99)), 1)
	if skill_charge < cost:
		return false
	skill_charge -= cost
	var modifier: Dictionary = {}
	match String(skill.get("id", "")):
		"blazing_line":
			modifier = {"flat_damage": 10, "burn": 2}
		"mirror_angle":
			GameManager.add_shield(6)
			modifier = {"shield": 8, "freeze": 1}
		"gilded_investment":
			modifier = {"bonus_coins": 8}
		"mist_weight":
			board_cleanse_requested.emit(2)
			modifier = {"armor_break": 2, "flat_damage": 6, "cleanse": 1}
		"prism_volley":
			modifier = {"repeat_count": 3, "repeat_ratio": 0.55}
	pending_spectrum_modifier = _merge_spectrum_modifier(pending_spectrum_modifier, modifier)
	log_added.emit("%s发动主动技：%s。" % [character.get("name", "勇者"), skill.get("name", "调色技")])
	_emit_state()
	_emit_checkpoint()
	return true

func _finish_player_move() -> void:
	moves_left -= 1
	log_added.emit("剩余步数：%d" % moves_left)
	if moves_left <= 0:
		await _enemy_action()
		if not battle_finished:
			_begin_player_turn()
	resolving = false
	if not battle_finished:
		input_lock_changed.emit(false)
	_emit_state()
	_emit_checkpoint()

func _begin_player_turn() -> void:
	if turn_number > 0:
		GameManager.shield = min(GameManager.shield, 3) if GameManager.relics.has("blue_shawl") else 0
	turn_number += 1
	resonance_sequence.begin_turn()
	resonance_changed.emit(resonance_sequence.get_state())
	GameManager.run_stats.record("turns", 1)
	moves_left = MAX_MOVES
	gold_boost_active = false
	red_condition_reduction = 0
	color_thread_used_this_turn = false
	moss_circlet_used_this_turn = false
	var new_hand: Array[Dictionary] = GameManager.draw_new_turn_hand()
	retained_slots.clear()
	spectrum_manager.begin_turn(
		new_hand,
		GameManager.relics.has("four_color_die"),
		GameManager.relics.has("trajectory_lens")
	)
	_sanitize_target_spectrum()
	log_added.emit("抽取色谱：%s" % _hand_names(new_hand))
	if spectrum_manager.condition_reduction_instance_id != "":
		var reduced_card: Dictionary = GameManager.get_card_instance(spectrum_manager.condition_reduction_instance_id)
		var reduced_card_id: String = String(reduced_card.get("card_id", ""))
		log_added.emit("四色骰令《%s》的首项数值条件 -1。" % GameDataScript.spectrum(reduced_card_id).get("name", reduced_card_id))
	_emit_combat_feedback("turn", "第 %d 回合" % turn_number, "剩余 %d 步交换" % moves_left)

func _apply_clear_events(clear_events: Array) -> void:
	if clear_events.is_empty():
		return
	for event in clear_events:
		var color_key: String = String(event.get("type", "gray"))
		var count: int = int(event.get("count", 0))
		var cascade: int = int(event.get("cascade", 1))
		if count <= 0:
			continue

		GameManager.record_color_usage(color_key, count)
		var pigment_yield: int = _pigment_yield(count, cascade)
		battle_pigments[color_key] = int(battle_pigments.get(color_key, 0)) + pigment_yield
		skill_charge = mini(skill_charge + pigment_yield, MAX_SKILL_CHARGE)
		base_damage_this_step += pigment_yield
		_apply_color_baseline(color_key, count, cascade, pigment_yield)
		_apply_character_clear_passives(event, color_key, count)
		_apply_clear_relics(event, color_key, count, cascade)
		_emit_combat_feedback(
			"clear", "%s消除 x%d" % [GameDataScript.color_full_name(color_key), count],
			"基础色素 +%d / 连锁 %d" % [pigment_yield, cascade], color_key, 0.9
		)

		var current_intent: Dictionary = enemy.get_current_intent()
		var context: Dictionary = {
			"moves_left": moves_left,
			"moves_left_after": max(moves_left - 1, 0),
			"last_red_count": count if color_key == "red" else 0,
			"last_blue_count": count if color_key == "blue" else 0,
			"enemy_intent": current_intent,
			"enemy_intent_type": String(current_intent.get("type", "")),
			"enemy_burn_stacks": enemy.burn_stacks,
			"player_hp_ratio": float(GameManager.player_hp) / float(max(GameManager.player_max_hp, 1)),
			"shield": GameManager.shield,
			"coins": GameManager.coins,
			"battle_gold_earned": gold_bonus_this_battle,
			"skipped_reward_previous": GameManager.skipped_card_reward_previous,
			"enemy_polluted_this_battle": enemy_polluted_this_battle,
			"gray_pressure": GameManager.gray_pressure,
			"red_condition_reduction": red_condition_reduction,
		}
		var fired: Array[Dictionary] = spectrum_manager.register_clear_event(event, 0, context)
		for trigger in fired:
			_apply_spectrum_effect(
				String(trigger.get("card_id", "")),
				int(trigger.get("slot", -1)),
				int(trigger.get("level", 0))
			)
			# The killing card completes its rewards; later cards and cascades must stop.
			if battle_finished:
				return
		_sanitize_retained_cards()
		_try_trigger_triad_resonance()
		if GameManager.relics.has("color_thread") and spectrum_manager.unique_colors.size() >= 3 and not color_thread_used_this_turn:
			color_thread_used_this_turn = true
			GameManager.add_shield(5)
			log_added.emit("彩线轴因三色消除提供 5 护盾。")
		if GameManager.relics.has("balanced_scale") and spectrum_manager.unique_colors.size() >= 3 and not balanced_scale_used:
			balanced_scale_used = true
			GameManager.heal(5)
			log_added.emit("三色天平因三色消除回复 5 HP。")
		_emit_state(max(moves_left - 1, 0))

func _apply_color_baseline(color_key: String, count: int, cascade: int, pigment_yield: int) -> void:
	match color_key:
		"red":
			enemy.apply_burn(2, 1)
			if GameManager.relics.has("red_hilt") and cascade == 1 and count >= 4:
				battle_pigments["red"] = int(battle_pigments.get("red", 0)) + 1
				skill_charge = mini(skill_charge + 1, MAX_SKILL_CHARGE)
				base_damage_this_step += 1
				log_added.emit("红釉剑柄回收碎色，额外获得 1 红色素。")
			log_added.emit("红焰 x%d：获得 %d 红色素，燃烧加深。" % [count, pigment_yield])
		"blue":
			if randf() < 0.30:
				_apply_freeze(1)
				log_added.emit("蓝霜 x%d：获得 %d 蓝色素，冻结成功。" % [count, pigment_yield])
			else:
				log_added.emit("蓝霜 x%d：获得 %d 蓝色素。" % [count, pigment_yield])
		"gold":
			var gained: int = count * 2
			if gold_boost_active:
				gained = int(ceil(float(gained) * 1.5))
			var cap: int = int(round(float(GOLD_SOFT_CAP) * (1.2 if GameManager.relics.has("merchant_seal") else 1.0)))
			var accepted: int = gained if gold_cap_removed else min(gained, max(cap - gold_bonus_this_battle, 0))
			GameManager.add_reward_coins(accepted)
			gold_bonus_this_battle += accepted
			log_added.emit("金辉 x%d：获得 %d 金色素与 %d 金币。" % [count, pigment_yield, accepted])
		_:
			if GameManager.relics.has("gray_goblet") and randf() < 0.20:
				GameManager.heal(1)
				log_added.emit("灰石酒杯回复 1 HP。")
			log_added.emit("灰蚀 x%d：获得 %d 灰色素。" % [count, pigment_yield])

func _apply_spectrum_effect(card_id: String, slot: int, level: int) -> void:
	var completed_instance_id: String = ""
	if spectrum_manager != null and slot >= 0 and slot < spectrum_manager.hand.size():
		completed_instance_id = String(spectrum_manager.hand[slot].get("instance_id", ""))
	GameManager.run_stats.record("spectra_completed", 1)
	var card: Dictionary = GameDataScript.spectrum_for_level(card_id, level)
	GameManager.run_stats.record_spectrum_tags(GameDataScript.spectrum_tags(card_id), "completed")
	var resonance_result: Dictionary = resonance_sequence.register_color(String(card.get("color", "neutral")))
	var resonance: Dictionary = resonance_result.get("resonance", {})
	if resonance_result.get("registered", false) == true:
		GameManager.run_stats.record("resonance_advance", 1)
	if not resonance.is_empty():
		GameManager.run_stats.record("resonance_trigger", 1)
		log_added.emit("谱序共鸣：%s。" % String(resonance.get("name", "未知和声")))
	resonance_changed.emit(resonance_sequence.get_state())
	_active_spectrum_id = card_id
	_active_resolution_damage = 0
	var resolution_modifier: Dictionary = _card_resolution_modifier(card)
	var character: Dictionary = GameManager.get_selected_character()
	var character_profile: Dictionary = character.get("spectrum_profile", character.get("orb_profile", {}))
	var pulse: Dictionary = SpectrumResolutionScript.resolve(
		card,
		character_profile,
		resolution_modifier,
		GameManager.peg_upgrades,
		{
			"base_damage": int(GameManager.get_memory_effect_total("spectrum_base_damage")) + int(GameManager.get_memory_effect_total("shot_base_damage")),
			"amplification": float(GameManager.get_memory_effect_total("spectrum_amp")) + float(GameManager.get_memory_effect_total("shot_crit")),
			"armor_break": int(GameManager.get_memory_effect_total("spectrum_break")) + int(GameManager.get_memory_effect_total("shot_pierce")),
		}
	)
	_apply_resolution_relics(pulse, card)
	var pulse_damage: int = _deal_resolution_pulse(pulse, card_id)
	_apply_resolution_rewards(pulse)
	log_added.emit("色谱完成：%s" % card.get("name", card_id))
	spectrum_triggered.emit(_card_state_for_slot(slot))
	if completed_instance_id == target_spectrum_instance_id:
		target_spectrum_instance_id = ""
	match card_id:
		"ember_slash":
			_deal_spectrum_damage(int(card.get("damage", 18)), "red")
			enemy.apply_burn(int(card.get("burn_turns", 2)), int(card.get("burn_stacks", 2)))
			if level > 0 and GameManager.relics.has("molten_ring") and not molten_ring_used:
				molten_ring_used = true
				enemy.apply_burn(1, 1)
		"fireline_dash":
			_deal_spectrum_damage(int(card.get("damage", 12)), "red")
			red_condition_reduction = max(red_condition_reduction, int(card.get("condition_reduction", 1)))
		"warm_guard":
			GameManager.add_shield(int(card.get("shield", 8)))
		"molten_finish":
			_deal_spectrum_damage(int(card.get("damage", 35)), "red")
			enemy.apply_burn(max(enemy.burn_turns, 1), enemy.burn_stacks)
		"blood_pact":
			_apply_self_damage_spectrum(card, "red")
		"flame_crown":
			_deal_spectrum_damage(int(card.get("damage", 60)), "red")
			enemy.set_resistance("red", float(card.get("red_resistance", 0.25)), 1)
		"wildfire":
			board_dye_requested.emit("red", int(card.get("dye_count", 2)))
		"frost_guard":
			GameManager.add_shield(int(card.get("shield", 12)))
		"golden_beat":
			_gain_card_gold(int(card.get("coins", 8)))
			gold_boost_active = true
		"palette_drill":
			var pigment_room: int = max(int(card.get("pigment_battle_cap", 1)) - palette_pigment_awarded, 0)
			var pigment_gain: int = min(int(card.get("pigment", 1)), pigment_room)
			GameManager.add_pigment(pigment_gain)
			palette_pigment_awarded += pigment_gain
			if spectrum_manager.unique_colors.size() >= int(card.get("cleanse_colors", 3)):
				board_cleanse_requested.emit(int(card.get("cleanse_count", 1)))
		"tone_phrase":
			_deal_spectrum_damage(int(card.get("damage", 12)), "neutral")
			if GameManager.relics.has("old_score"):
				_deal_spectrum_damage(4, "neutral")
			for draw_index in range(int(card.get("draw_count", 1))):
				var new_card: Dictionary = GameManager.draw_extra_to_hand()
				if not new_card.is_empty():
					spectrum_manager.add_card_to_hand(new_card)
					var new_card_id: String = String(new_card.get("card_id", ""))
					log_added.emit("镇魂短句抽到：%s" % GameDataScript.spectrum(new_card_id).get("name", new_card_id))
		"crimson_echo":
			_deal_spectrum_damage(int(round(float(base_damage_this_step) * float(card.get("damage_ratio", 0.4)))), "red")
		"ice_rest":
			if enemy.interrupt_charge():
				log_added.emit("冰封休止打断了蓄力。")
				if GameManager.has_character_passive("mirror_counter"):
					GameManager.add_shield(8)
					log_added.emit("凛镜的镜返提供 8 护盾。")
				if GameManager.relics.has("frozen_watch") and not charge_refund_used:
					moves_left = min(moves_left + 1, 4)
					charge_refund_used = true
					log_added.emit("冻裂怀表返还 1 步。")
			else:
				if randf() < float(card.get("freeze_chance", 0.65)):
					_apply_freeze(1)
		"mirror_dodge":
			pending_damage_reduction = max(pending_damage_reduction, int(card.get("damage_reduction", 10)))
		"frostline_plan":
			_draw_spectrum_cards(int(card.get("draw_count", 1)), "霜线规划")
		"cold_wall":
			GameManager.add_shield(int(card.get("shield", 20)))
		"stasis_seal":
			_apply_freeze(int(card.get("freeze_turns", 1)))
			GameManager.add_shield(int(card.get("shield", 8)))
		"prism_ice":
			_deal_spectrum_damage(int(round(float(GameManager.shield) * float(card.get("shield_damage_ratio", 0.6)))), "blue")
		"zero_finale":
			if not enemy.boss:
				_apply_freeze(int(card.get("freeze_turns", 1)))
			else:
				GameManager.add_shield(int(card.get("boss_shield", 12)))
		"bond_refraction":
			GameManager.shop_upgrade_discount = max(GameManager.shop_upgrade_discount, _scaled_gold_float(float(card.get("discount", 0.2))))
		"caravan_beat":
			_gain_card_gold(int(card.get("coins", 12)))
		"remainder_echo":
			_gain_card_gold(int(card.get("coins", 6)))
			GameManager.add_pigment(int(card.get("pigment", 1)))
			GameManager.consume_skipped_reward_bonus()
		"gilded_charm":
			GameManager.add_shield(_scaled_gold_value(min(gold_bonus_this_battle, int(card.get("shield_cap", 16)))))
		"arbitrage_concerto":
			_draw_spectrum_cards(int(card.get("draw_count", 1)), "套利连奏")
			GameManager.free_shop_refreshes += int(card.get("free_shop_refreshes", 1))
			_gain_card_gold(int(card.get("coins", 0)))
		"royal_coin":
			if GameManager.spend_coins(int(card.get("coin_cost", 20))):
				_deal_spectrum_damage(_scaled_gold_value(int(card.get("damage", 45))), "gold")
		"golden_finale":
			var relic_discount: float = _scaled_gold_float(float(card.get("relic_discount", 0.20)))
			GameManager.relic_shop_discount = max(GameManager.relic_shop_discount, relic_discount)
			gold_cap_removed = true
		"ash_alchemy":
			var gray_count: int = int(spectrum_manager.color_counts.get("gray", 0))
			GameManager.add_reward_coins(gray_count * int(card.get("coins_per_gray", 1)))
			var ash_shield: int = min(gray_count * int(card.get("shield_per_gray", 2)), int(card.get("shield_cap", 10)))
			GameManager.add_shield(ash_shield)
		"mist_phrase":
			board_cleanse_requested.emit(int(card.get("cleanse_count", 2)))
		"gray_blade":
			_deal_spectrum_damage(int(card.get("damage", 20)), "gray")
			GameManager.gray_pressure = max(GameManager.gray_pressure - int(card.get("corruption_reduction", 1)), 0)
		"color_from_mist":
			GameManager.add_pigment(int(card.get("pigment", 1)))
		"echo_stele":
			board_cleanse_requested.emit(int(card.get("cleanse_count", 3)))
			_draw_spectrum_cards(int(card.get("draw_count", 1)), "残响石碑")
		"gray_king_contract":
			_deal_spectrum_damage(GameManager.gray_pressure * int(card.get("damage_per_corruption", 8)), "gray")
			GameManager.gray_pressure = int(floor(float(GameManager.gray_pressure) * float(card.get("corruption_keep_ratio", 0.5))))
		"daylight_calibration":
			player_burn_turns = 0
			GameManager.heal(int(card.get("heal", 4)))
		"prism_concerto":
			_deal_spectrum_damage(int(card.get("red_damage", 8)), "red")
			GameManager.add_shield(int(card.get("blue_shield", 6)))
			_gain_card_gold(int(card.get("gold_coins", 4)))
		"colorless_pause":
			GameManager.add_shield(int(card.get("shield", 10)))
			_draw_spectrum_cards(int(card.get("draw_count", 1)), "无色停顿")
		"finale_variation":
			_deal_spectrum_damage(int(card.get("damage", 50)), "mixed")
			GameManager.add_pigment(int(card.get("pigment", 2)))
		"obsidian_contract":
			_apply_self_damage_spectrum(card, "black")
		_:
			_apply_generic_spectrum_effects(card)
	var card_color: String = String(card.get("color", ""))
	if card_color == "green" and GameManager.relics.has("gardener_knife"):
		GameManager.add_shield(2)
	if card_color == "purple" and GameManager.relics.has("paradox_coin"):
		_gain_card_gold(3)
	if card_color == "black":
		if GameManager.relics.has("debtor_seal"):
			_gain_card_gold(3)
		if GameManager.relics.has("abyss_chain"):
			GameManager.add_shield(4)
	if GameManager.relics.has("cadenza_lens") and spectrum_manager.completed_count >= 3 and not cadenza_lens_used:
		cadenza_lens_used = true
		GameManager.add_shield(8)
		log_added.emit("华彩透镜因三谱连成提供 8 护盾。")
	if ["mixed", "white"].has(card_color) and enemy.clear_resistance():
		log_added.emit("混色色谱击碎了敌人的颜色抗性。")
	if ["mixed", "white", "black"].has(card_color) and GameManager.relics.has("split_prism") and not completed_mixed_relic_used:
		completed_mixed_relic_used = true
		var extra: Dictionary = GameManager.draw_extra_to_hand()
		if not extra.is_empty():
			spectrum_manager.add_card_to_hand(extra)
			var extra_card_id: String = String(extra.get("card_id", ""))
			log_added.emit("裂色棱镜额外抽到：%s" % GameDataScript.spectrum(extra_card_id).get("name", extra_card_id))
	var effect_damage: int = maxi(_active_resolution_damage - pulse_damage, 0)
	var resonance_damage: int = _resolve_resonance(resonance, String(card.get("color", "neutral")))
	if not resonance.is_empty():
		_emit_combat_feedback(
			"resonance", String(resonance.get("name", "谱序共鸣")),
			"引音 %s / 应音 %s" % [
				GameDataScript.color_full_name(String(resonance.get("lead", {}).get("color", "neutral"))),
				GameDataScript.color_full_name(card_color),
			], card_color, 1.8
		)
	last_spectrum_resolution = {
		"card_id": card_id,
		"name": String(card.get("name", card_id)),
		"color": String(card.get("color", "neutral")),
		"pulse_damage": pulse_damage,
		"effect_damage": effect_damage,
		"resonance_damage": resonance_damage,
		"total_damage": _active_resolution_damage,
		"repeat_count": int(pulse.get("repeat_count", 1)),
		"armor_break": int(pulse.get("armor_break", 0)),
		"resonance": resonance.duplicate(true),
	}
	_active_spectrum_id = ""
	spectrum_resolved.emit(last_spectrum_resolution.duplicate(true))
	log_added.emit("《%s》即时结算，共造成 %d 伤害。" % [card.get("name", card_id), int(last_spectrum_resolution["total_damage"])])
	_emit_combat_feedback(
		"spectrum", String(last_spectrum_resolution["name"]),
		"即时结算：%d 伤害" % int(last_spectrum_resolution["total_damage"]),
		String(last_spectrum_resolution["color"]), 1.6
	)
	_emit_state()
	_check_win()

func _apply_generic_spectrum_effects(card: Dictionary) -> void:
	var effects_value: Variant = card.get("effects", [])
	if not effects_value is Array:
		return
	for effect_value in effects_value:
		if not effect_value is Dictionary:
			continue
		var effect: Dictionary = effect_value
		var value: int = int(effect.get("value", 0))
		match String(effect.get("type", "")):
			"damage":
				var damage_value: int = max(value, 0)
				var damage_color: String = String(effect.get("color", card.get("color", "neutral")))
				if damage_color == "purple" and GameManager.relics.has("mirror_string"):
					damage_value += 4
				if damage_color == "black" and GameManager.relics.has("ink_razor"):
					damage_value += 6
				_deal_spectrum_damage(damage_value, damage_color)
			"shield":
				GameManager.add_shield(value)
			"heal":
				var heal_value: int = value + (2 if String(card.get("color", "")) == "green" and GameManager.relics.has("evergreen_score") else 0)
				GameManager.heal(heal_value)
			"pigment":
				GameManager.add_pigment(value)
			"coins":
				_gain_card_gold(value)
			"burn":
				enemy.apply_burn(int(effect.get("turns", 1)), max(value, 1))
			"freeze":
				_apply_freeze(max(value, 1))
			"cleanse":
				var cleanse_value: int = max(value, 1)
				if String(card.get("color", "")) == "white" and GameManager.relics.has("purity_sigil"):
					cleanse_value += 1
				board_cleanse_requested.emit(cleanse_value)
			"dye":
				var dye_color: String = String(effect.get("color", "random_player"))
				if dye_color == "random_player":
					dye_color = String(GameDataScript.PLAYER_COLORS.pick_random())
				board_dye_requested.emit(dye_color, max(value, 1))
			"draw":
				_draw_spectrum_cards(max(value, 1), String(card.get("name", "色谱")))
			"gray_pressure":
				GameManager.gray_pressure = max(GameManager.gray_pressure + value, 0)
			"self_damage":
				_take_self_damage(value)
			"move":
				moves_left = min(moves_left + max(value, 0), MAX_MOVES + 1)
			"damage_reduction":
				pending_damage_reduction = max(pending_damage_reduction, value)
			"shop_upgrade_discount":
				GameManager.shop_upgrade_discount = max(GameManager.shop_upgrade_discount, float(effect.get("ratio", 0.15)))

func _draw_spectrum_cards(amount: int, source_name: String) -> void:
	for draw_index in range(max(amount, 0)):
		var drawn: Dictionary = GameManager.draw_extra_to_hand()
		if drawn.is_empty():
			return
		spectrum_manager.add_card_to_hand(drawn)
		var drawn_card_id: String = String(drawn.get("card_id", ""))
		log_added.emit("%s抽到：%s" % [source_name, GameDataScript.spectrum(drawn_card_id).get("name", drawn_card_id)])

func _gain_card_gold(amount: int) -> void:
	var gained: int = _scaled_gold_value(max(amount, 0))
	GameManager.add_reward_coins(gained)
	gold_bonus_this_battle += gained

func _scaled_gold_value(value: int) -> int:
	if GameManager.relics.has("cracked_abacus") and GameManager.coins < 20:
		return int(ceil(float(value) * 1.25))
	return value

func _scaled_gold_float(value: float) -> float:
	if GameManager.relics.has("cracked_abacus") and GameManager.coins < 20:
		return value * 1.25
	return value

func _apply_self_damage_spectrum(card: Dictionary, color_key: String) -> void:
	_take_self_damage(int(card.get("hp_cost", 3)))
	var reward_multiplier: int = 1
	if GameManager.relics.has("obsidian_cup") and not self_damage_relic_used:
		self_damage_relic_used = true
		reward_multiplier = 2
	_deal_spectrum_damage(int(card.get("damage", 30)) * reward_multiplier, color_key)

func _take_self_damage(amount: int) -> void:
	var actual_damage: int = max(amount, 0)
	if GameManager.relics.has("eclipse_vial") and not eclipse_vial_used:
		eclipse_vial_used = true
		actual_damage = max(actual_damage - 2, 0)
	GameManager.player_hp = max(GameManager.player_hp - actual_damage, 1)

func _apply_freeze(turns: int) -> void:
	enemy.apply_freeze(turns)
	if GameManager.relics.has("still_lake_seal") and still_lake_draws < 2:
		still_lake_draws += 1
		_draw_spectrum_cards(1, "静湖印")

func _deal_spectrum_damage(amount: int, color_key: String, damage_source: String = "spectrum_effect") -> void:
	var real_damage: int = enemy.take_damage(amount, color_key)
	var source: String = _active_spectrum_id if damage_source == "spectrum_effect" and _active_spectrum_id != "" else damage_source
	GameManager.run_stats.record("damage", real_damage, source)
	if _active_spectrum_id != "":
		_active_resolution_damage += real_damage
	damage_event.emit(real_damage, color_key)

func _card_resolution_modifier(card: Dictionary) -> Dictionary:
	var modifier: Dictionary = {}
	var legacy_modifier: Variant = card.get("shot_modifier", {})
	if legacy_modifier is Dictionary:
		modifier = _merge_spectrum_modifier(modifier, legacy_modifier)
	var card_modifier: Variant = card.get("resolution_modifier", {})
	if card_modifier is Dictionary:
		modifier = _merge_spectrum_modifier(modifier, card_modifier)
	if not pending_spectrum_modifier.is_empty():
		modifier = _merge_spectrum_modifier(modifier, pending_spectrum_modifier)
		pending_spectrum_modifier.clear()
	return modifier

func _resolve_resonance(resonance: Dictionary, color_key: String) -> int:
	if resonance.is_empty():
		return 0
	var resonance_id: String = String(resonance.get("id", ""))
	var damage: int = 0
	match resonance_id:
		"unison":
			damage = 6
		"violet":
			damage = 5
		"verdant":
			GameManager.add_shield(6)
		"amber":
			damage = 4
			GameManager.add_reward_coins(2)
		"daylight":
			damage = 5
			board_cleanse_requested.emit(1)
		"decolor":
			damage = 4
			board_cleanse_requested.emit(1)
			enemy.clear_resistance()
	damage += max(int(GameManager.get_memory_effect_total("resonance_base_damage")), 0)
	damage += max(int(GameManager.peg_upgrades.get("echo", 0)), 0)
	if GameManager.relics.has("echo_spring"):
		damage += 2
	damage = int(round(float(damage) * clampf(float(GameManager.get_selected_vow().get("resonance_damage_ratio", 1.0)), 1.0, 1.25)))
	var vow_shield: int = int(GameManager.get_selected_vow().get("resonance_shield", 0))
	if vow_shield > 0:
		GameManager.add_shield(vow_shield)
	if damage <= 0:
		return 0
	var real_damage: int = enemy.take_damage(damage, color_key)
	_active_resolution_damage += real_damage
	GameManager.run_stats.record("damage", real_damage, "resonance")
	damage_event.emit(real_damage, color_key)
	return real_damage

func _deal_resolution_pulse(pulse: Dictionary, card_id: String) -> int:
	var raw_damage: int = max(int(pulse.get("damage", 0)), 0)
	if not pending_enemy_disruption.is_empty():
		pending_enemy_disruption = GameDataScript.normalize_enemy_intent(pending_enemy_disruption)
		var capacitor_active: bool = GameManager.relics.has("hazard_capacitor")
		match String(pending_enemy_disruption.get("type", "")):
			"spectrum_drift":
				if not capacitor_active:
					var drift: float = clampf(float(pending_enemy_disruption.get("value", 0.18)), 0.0, 0.25)
					if GameManager.relics.has("aim_gyroscope"):
						drift *= 0.5
					raw_damage = int(round(float(raw_damage) * (1.0 - drift)))
			"spectrum_suppress":
				if not capacitor_active:
					raw_damage = maxi(raw_damage - 4, 0)
			"board_corrupt":
				if not capacitor_active:
					raw_damage = maxi(raw_damage - 2, 0)
				var ascension_rules: Dictionary = AscensionRulesScript.get_cumulative_rules(GameManager.ascension_level)
				board_pollution_requested.emit(1 + maxi(int(ascension_rules.get("hazard_peg_count_add", 0)), 0))
			"spectrum_seal":
				if not capacitor_active:
					raw_damage = maxi(raw_damage - max(int(pending_enemy_disruption.get("value", 3)), 1), 0)
		if capacitor_active:
			raw_damage += 3
		pending_enemy_disruption.clear()
	var color_key: String = String(pulse.get("color", "neutral"))
	var real_damage: int = enemy.take_damage(raw_damage, color_key, pulse.get("ignore_armor", false) == true)
	GameManager.run_stats.record("damage", real_damage, card_id)
	_active_resolution_damage += real_damage
	damage_event.emit(real_damage, color_key)
	return real_damage


func _apply_resolution_rewards(pulse: Dictionary) -> void:
	var shield_gain: int = max(int(pulse.get("shield", 0)), 0)
	if shield_gain > 0:
		GameManager.add_shield(shield_gain)
	var coin_gain: int = max(int(pulse.get("coins", 0)), 0)
	if coin_gain > 0:
		_gain_card_gold(coin_gain)
	var cleanse_count: int = max(int(pulse.get("cleanse", 0)), 0)
	if cleanse_count > 0:
		board_cleanse_requested.emit(cleanse_count)
	var burn_stacks: int = max(int(pulse.get("burn", 0)), 0)
	if burn_stacks > 0:
		enemy.apply_burn(2, burn_stacks)
	var freeze_turns: int = max(int(pulse.get("freeze", 0)), 0)
	if freeze_turns > 0:
		_apply_freeze(freeze_turns)


func _apply_resolution_relics(pulse: Dictionary, card: Dictionary) -> void:
	var color_key: String = String(card.get("color", "neutral"))
	if GameManager.relics.has("first_orbit") and not first_orbit_used:
		first_orbit_used = true
		pulse["damage"] = int(pulse.get("damage", 0)) + 8
	if enemy.boss:
		var current_phase: int = enemy.get_boss_phase()
		if current_phase != last_boss_phase_seen:
			last_boss_phase_seen = current_phase
			if GameManager.relics.has("phase_tuning_fork"):
				pulse["damage"] = int(pulse.get("damage", 0)) + 10
	if color_key == "red" and GameManager.relics.has("flare_nozzle"):
		pulse["damage"] = int(pulse.get("damage", 0)) + 3
	if color_key == "blue" and GameManager.relics.has("mirror_baffle"):
		pulse["shield"] = int(pulse.get("shield", 0)) + 3
	if color_key == "gray" and GameManager.relics.has("mist_ram"):
		pulse["ignore_armor"] = true
	if color_key in ["mixed", "white"] and GameManager.relics.has("prism_splitter"):
		pulse["damage"] = int(pulse.get("damage", 0)) + 6
	if GameManager.relics.has("critical_ink"):
		pulse["damage"] = int(pulse.get("damage", 0)) + 4
	if GameManager.relics.has("queue_bell") and spectrum_manager.completed_count >= 3:
		pulse["damage"] = int(pulse.get("damage", 0)) + 4
	if GameManager.relics.has("queue_limiter") and spectrum_manager.completed_count >= 4:
		pulse["damage"] = int(pulse.get("damage", 0)) + 6
	if GameManager.relics.has("rebound_thread") and last_combo >= 2:
		pulse["damage"] = int(pulse.get("damage", 0)) + 4
	if GameManager.relics.has("lockpick_gear"):
		pulse["ignore_armor"] = true
	if color_key == "red" and GameManager.relics.has("cinder_compass"):
		pulse["burn"] = int(pulse.get("burn", 0)) + 1
	if GameManager.relics.has("bumper_core"):
		pulse["shield"] = int(pulse.get("shield", 0)) + 2
	if color_key in ["mixed", "white"] and GameManager.relics.has("reflection_seal"):
		pulse["ignore_armor"] = true
	if color_key == "gold" and GameManager.relics.has("profit_pin"):
		pulse["coins"] = int(pulse.get("coins", 0)) + 1
	if color_key == "gray" and GameManager.relics.has("mist_filter"):
		pulse["cleanse"] = int(pulse.get("cleanse", 0)) + 1
	if color_key == "black" and GameManager.relics.has("void_anchor"):
		pulse["shield"] = int(pulse.get("shield", 0)) + 4
	if color_key in ["mixed", "white"] and GameManager.relics.has("resistance_key"):
		enemy.clear_resistance()

func _merge_spectrum_modifier(base: Dictionary, modifier: Dictionary) -> Dictionary:
	var merged: Dictionary = base.duplicate(true)
	for key in [
		"flat_damage", "per_hit_bonus", "echo_damage", "hazard_damage", "bonus_coins",
		"bonus_gold_pegs", "armor_break", "pierce_bonus", "lock_pierce", "cleanse",
		"shield", "burn", "high_hit_burn", "freeze",
	]:
		merged[key] = int(merged.get(key, 0)) + int(modifier.get(key, 0))
	merged["armor_break_hits"] = maxi(int(merged.get("armor_break_hits", 0)), int(modifier.get("armor_break_hits", 0)))
	merged["repeat_count"] = maxi(
		int(merged.get("repeat_count", merged.get("multiball", 1))),
		int(modifier.get("repeat_count", modifier.get("multiball", 1)))
	)
	if modifier.has("repeat_ratio") or modifier.has("ball_damage_ratio"):
		merged["repeat_ratio"] = float(modifier.get("repeat_ratio", modifier.get("ball_damage_ratio", 0.55)))
	merged["damage_ratio_bonus"] = float(merged.get("damage_ratio_bonus", 0.0)) + float(modifier.get("damage_ratio_bonus", 0.0))
	merged["ignore_hazard"] = merged.get("ignore_hazard", false) == true or modifier.get("ignore_hazard", false) == true
	merged["ignore_void"] = merged.get("ignore_void", false) == true or modifier.get("ignore_void", false) == true
	return merged

func _pigment_yield(count: int, cascade: int) -> int:
	var base_yield: int = 0
	if count >= 6:
		base_yield = 11 + count - 6
	elif count == 5:
		base_yield = 8
	elif count == 4:
		base_yield = 5
	elif count >= 3:
		base_yield = 3
	return base_yield + mini(maxi(cascade - 1, 0), 5)

func _calculate_damage(color_key: String, count: int, cascade: int) -> int:
	var count_multiplier: float = 1.0
	if count == 4:
		count_multiplier = 1.5
	elif count == 5:
		count_multiplier = 2.5
	elif count >= 6:
		count_multiplier = 4.0
	var cascade_multiplier: float = 1.0 + float(max(cascade - 1, 0)) * 0.35
	var damage: float = float(BASE_DAMAGE) * count_multiplier * cascade_multiplier
	if color_key == "red":
		damage *= 1.5
	return int(round(damage))

func _enemy_action() -> void:
	log_added.emit("敌人回合：%s" % enemy.get_intent_text())
	_emit_combat_feedback(
		"enemy", "敌人回合",
		"%s：冻结，跳过行动" % enemy.enemy_name if enemy.freeze_turns > 0 else enemy.get_intent_text(),
		"gray", 1.6
	)
	var settings: Node = get_node_or_null("/root/SettingsManager")
	var delay: float = 0.30
	if settings != null:
		delay = 0.0 if settings.quick_resolve else delay / maxf(float(settings.combat_speed), 0.5)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout

	if enemy.burn_turns > 0 and enemy.burn_stacks > 0:
		var burn_damage: int = BURN_DAMAGE_PER_STACK * enemy.burn_stacks
		enemy.burn_turns -= 1
		_deal_spectrum_damage(burn_damage, "red", "burn")
		log_added.emit("燃烧造成 %d 伤害。" % burn_damage)
		if GameManager.relics.has("warm_charm") and enemy.burn_stacks >= 3:
			GameManager.add_shield(4)
			log_added.emit("余温护符在燃烧结算后提供 4 护盾。")
		if _check_win():
			return

	if player_burn_turns > 0:
		player_burn_turns -= 1
		var burn_to_player: int = GameManager.absorb_damage(4)
		player_hit.emit(burn_to_player)
		log_added.emit("勇者燃烧，受到 %d 伤害。" % burn_to_player)
		if _check_loss():
			return

	if enemy.freeze_turns > 0:
		enemy.freeze_turns -= 1
		enemy.charge_pending = false
		log_added.emit("%s 被冻结，跳过行动。" % enemy.enemy_name)
		enemy.advance_intent()
		enemy.tick_status_after_enemy_turn()
		return

	var intent: Dictionary = enemy.get_current_intent()
	await _resolve_intent(intent)
	enemy.advance_intent()
	enemy.tick_status_after_enemy_turn()

func _resolve_intent(intent: Dictionary) -> void:
	intent = GameDataScript.normalize_enemy_intent(intent)
	var intent_type: String = String(intent.get("type", "attack"))
	match intent_type:
		"attack":
			_hit_player(int(intent.get("value", enemy.attack)))
		"heavy":
			enemy.charge_pending = false
			if enemy.interrupted_this_turn:
				enemy.interrupted_this_turn = false
				log_added.emit("鎵撴柇鎴愬姛锛氭晫浜虹殑閲嶅嚮琚彇娑堛€?")
				return
			_hit_player(int(intent.get("value", enemy.attack)))
		"charge":
			enemy.charge_pending = true
			log_added.emit("%s 正在聚力。" % enemy.enemy_name)
		"defend":
			enemy.add_armor(int(intent.get("value", 18)))
			log_added.emit("%s 获得 %d 护甲。" % [enemy.enemy_name, int(intent.get("value", 18))])
		"pollute":
			var amount: int = int(intent.get("value", 2))
			enemy_polluted_this_battle = true
			if GameManager.relics.has("white_lantern"):
				amount = max(amount - 1, 1)
			var pressure_reduced: int = GameManager.add_gray_pressure(amount)
			board_pollution_requested.emit(amount)
			if pressure_reduced > 0:
				log_added.emit("净白羽清除了 %d 点灰蚀压力。" % pressure_reduced)
			if GameManager.relics.has("mist_bell") and not pollution_relic_used:
				pollution_relic_used = true
				board_cleanse_requested.emit(1)
				GameManager.add_pigment(1)
				log_added.emit("破雾铃净化 1 格，并获得 1 颜料。")
			if GameManager.has_character_passive("mist_ward") and not mist_ward_used:
				mist_ward_used = true
				board_cleanse_requested.emit(2)
				GameManager.add_shield(5)
				log_added.emit("弥砂拾走雾痕：净化 2 格并获得 5 护盾。")
			if GameManager.relics.has("ash_pot") and randf() < 0.30:
				var usable_color: String = String(GameDataScript.PLAYER_COLORS.pick_random())
				board_dye_requested.emit(usable_color, 1)
				log_added.emit("灰烬花盆将 1 个灰块转为%s。" % GameDataScript.color_full_name(usable_color))
			log_added.emit("灰雾污染 %d 格。" % amount)
		"steal":
			var value: int = int(intent.get("value", 6))
			if GameManager.relics.has("night_coin"):
				value = int(ceil(float(value) * 0.5))
			if GameManager.spend_coins(value):
				log_added.emit("%s 偷走 %d 金币。" % [enemy.enemy_name, value])
			else:
				_hit_player(6)
		"resist":
			enemy.set_resistance(String(intent.get("color", "red")), float(intent.get("value", 0.35)), 1)
			log_added.emit("%s 获得 %s抗性。" % [enemy.enemy_name, GameDataScript.color_full_name(enemy.resistance_color)])
		"resist_dominant":
			var color_key: String = GameManager.get_dominant_player_color()
			enemy.set_resistance(color_key, float(intent.get("value", 0.35)), 1)
			log_added.emit("灰蚀龙抵抗你的主色：%s。" % GameDataScript.color_full_name(color_key))
		"heal":
			var healed: int = enemy.heal(int(intent.get("value", 20)))
			log_added.emit("%s 回复 %d HP。" % [enemy.enemy_name, healed])
		"player_burn":
			player_burn_turns = max(player_burn_turns, int(intent.get("value", 1)))
			log_added.emit("勇者被点燃。")
		"spectrum_drift", "spectrum_suppress", "board_corrupt", "spectrum_seal":
			pending_enemy_disruption = intent.duplicate(true)
			if GameManager.relics.has("hazard_lining"):
				GameManager.add_shield(4)
			log_added.emit("%s 对下一次色谱结算施加干扰。" % String(intent.get("text", intent_type)))
		_:
			_hit_player(enemy.attack)

func _hit_player(amount: int) -> void:
	var incoming: int = amount
	if pending_damage_reduction > 0:
		incoming = max(incoming - pending_damage_reduction, 0)
		pending_damage_reduction = 0
	if GameManager.relics.has("dusk_mask") and not dusk_mask_used:
		dusk_mask_used = true
		incoming = max(incoming - 6, 0)
	var real_damage: int = GameManager.absorb_damage(incoming)
	if real_damage > 0:
		spectrum_manager.mark_player_damaged()
	player_hit.emit(real_damage)
	log_added.emit("%s 造成 %d 伤害。" % [enemy.enemy_name, real_damage])
	_check_loss()

func _apply_character_clear_passives(event: Dictionary, color_key: String, count: int) -> void:
	if (
		GameManager.has_character_passive("first_flame")
		and not first_flame_used
		and color_key == "red"
		and count >= 4
		and event.get("active", false) == true
	):
		first_flame_used = true
		enemy.apply_burn(1, 1)
		log_added.emit("烬歌点燃先声，额外施加 1 层燃烧。")

func _apply_clear_relics(event: Dictionary, color_key: String, count: int, cascade: int) -> void:
	if (
		GameManager.relics.has("moss_circlet")
		and not moss_circlet_used_this_turn
		and color_key == "blue"
		and count >= 4
		and event.get("active", false) == true
	):
		moss_circlet_used_this_turn = true
		GameManager.add_shield(4)
	if GameManager.relics.has("echo_metronome") and not echo_metronome_used and cascade >= 2:
		echo_metronome_used = true
		_draw_spectrum_cards(1, "回声节拍器")

func _try_trigger_triad_resonance() -> void:
	if not GameManager.has_character_passive("triad_resonance") or triad_resonance_used:
		return
	for color_key in GameDataScript.PLAYER_COLORS:
		if not spectrum_manager.unique_colors.has(color_key):
			return
	triad_resonance_used = true
	GameManager.add_pigment(1)
	moves_left = min(moves_left + 1, MAX_MOVES + 1)
	if GameManager.relics.has("spectrum_core"):
		skill_charge = mini(skill_charge + 4, MAX_SKILL_CHARGE)
	log_added.emit("伊澜完成三声共鸣：获得 1 颜料并返还 1 步。")

func _check_win() -> bool:
	if enemy != null and enemy.is_dead() and not battle_finished:
		battle_finished = true
		GameManager.run_stats.record("battle_win", 1)
		input_lock_changed.emit(true)
		GameManager.discard_unretained_hand()
		log_added.emit("%s 被重新染色。" % enemy.enemy_name)
		_emit_state()
		_emit_combat_feedback("victory", "战斗胜利", "%s 被重新染色。" % enemy.enemy_name, "gold", 2.0)
		battle_won.emit()
		return true
	return battle_finished

func _check_loss() -> bool:
	if GameManager.player_hp <= 0 and not battle_finished:
		battle_finished = true
		GameManager.run_stats.record("battle_loss", 1)
		input_lock_changed.emit(true)
		_emit_state()
		_emit_combat_feedback("defeat", "战斗失败", "勇者的色彩暂时黯淡。", "gray", 2.0)
		battle_lost.emit()
		return true
	return battle_finished

func _get_retention_bonus() -> int:
	if spectrum_manager == null:
		return 0
	var bonus: int = 0
	for card_instance in spectrum_manager.hand:
		var instance_id: String = String(card_instance.get("instance_id", ""))
		if spectrum_manager.triggered.has(instance_id):
			continue
		var card_id: String = String(card_instance.get("card_id", ""))
		if card_id == "frostline_plan":
			var card: Dictionary = GameDataScript.spectrum_for_level(card_id, int(card_instance.get("level", 0)))
			bonus += max(int(card.get("retain_bonus", 0)), 0)
	return bonus

func _sanitize_retained_cards() -> void:
	if spectrum_manager == null:
		return
	var valid_ids: Array[String] = []
	for instance_id in GameManager.retained_card_instance_ids:
		if not spectrum_manager.triggered.has(instance_id):
			valid_ids.append(instance_id)
	GameManager.set_retained_cards(valid_ids, _get_retention_bonus())
	_sync_retained_slots()

func _sync_retained_slots() -> void:
	retained_slots.clear()
	if spectrum_manager == null:
		return
	for slot in range(spectrum_manager.hand.size()):
		var instance_id: String = String(spectrum_manager.hand[slot].get("instance_id", ""))
		if GameManager.is_card_retained(instance_id):
			retained_slots.append(slot)

func _emit_combat_feedback(
	kind: String, title: String, detail: String,
	color: String = "neutral", duration: float = 1.4
) -> void:
	combat_feedback_emitted.emit({
		"kind": kind,
		"title": title,
		"detail": detail,
		"color": color,
		"duration": duration,
	})

func _emit_state(display_moves_left: int = -1) -> void:
	if enemy == null or spectrum_manager == null:
		return
	state_changed.emit({
		"enemy_name": enemy.enemy_name,
		"enemy_hp": enemy.hp,
		"enemy_max_hp": enemy.max_hp,
		"enemy_status": enemy.get_status_text(),
		"enemy_intent": enemy.get_intent_text(),
		"enemy_armor": enemy.armor,
		"player_hp": GameManager.player_hp,
		"player_max_hp": GameManager.player_max_hp,
		"shield": GameManager.shield,
		"moves_left": moves_left if display_moves_left < 0 else display_moves_left,
		"coins": GameManager.coins,
		"pigment": GameManager.pigment,
		"battle_pigments": battle_pigments.duplicate(true),
		"pending_spectrum_modifier": pending_spectrum_modifier.duplicate(true),
		"enemy_disruption": pending_enemy_disruption.duplicate(true),
		"last_spectrum_resolution": last_spectrum_resolution.duplicate(true),
		"skill_charge": skill_charge,
		"active_skill": GameManager.get_selected_character().get("active_skill", {}).duplicate(true),
		"resonance": resonance_sequence.get_state(),
		"vow": GameManager.get_selected_vow(),
		"equipped_memories": GameManager.equipped_memory_ids.duplicate(),
		"combo": last_combo,
		"gold_boost": gold_boost_active,
	"cards": _state_cards_with_target(),
	"target_spectrum_instance_id": target_spectrum_instance_id,
	"target_spectrum": get_target_spectrum_state(),
		"deck_count": GameManager.deck.size(),
		"draw_count": GameManager.draw_pile.size(),
		"discard_count": GameManager.discard_pile.size(),
	"relics": GameManager.relics.duplicate(),
	})

func _state_cards_with_target() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card_state in spectrum_manager.get_card_states(retained_slots):
		var state: Dictionary = card_state.duplicate(true)
		state["targeted"] = String(state.get("instance_id", "")) == target_spectrum_instance_id
		state["tags"] = GameDataScript.spectrum_tags(String(state.get("id", "")))
		result.append(state)
	return result

func _hand_names(cards: Array[Dictionary]) -> String:
	var names: Array[String] = []
	for card in cards:
		var card_id: String = String(card.get("card_id", ""))
		names.append(String(GameDataScript.spectrum(card_id).get("name", card_id)))
	return "、".join(names)

func _card_state_for_slot(slot: int) -> Dictionary:
	for state in spectrum_manager.get_card_states(retained_slots):
		if int(state.get("slot", -1)) == slot:
			return state
	return {}
