extends RefCounted
class_name SpectrumManager

const GameDataScript = preload("res://scripts/GameData.gd")

const CONDITION_KEYS: Dictionary = {
	"ember_slash": "threshold",
	"wildfire": "match_size",
	"molten_finish": "completed_red",
	"flame_crown": "match_size",
	"frost_guard": "match_size",
	"golden_beat": "gold_count",
	"palette_drill": "unique_colors",
	"tone_phrase": "cascade",
	"crimson_echo": "event_count",
	"frostline_plan": "cascade",
	"cold_wall": "threshold",
	"zero_finale": "consecutive_turns",
	"caravan_beat": "match_size",
	"gilded_charm": "threshold",
	"royal_coin": "coin_threshold",
	"golden_finale": "battle_coins",
	"mist_phrase": "threshold",
	"gray_blade": "match_size",
	"gray_king_contract": "corruption_threshold",
	"daylight_calibration": "completed_colors",
	"finale_variation": "completed_cards",
}

var hand: Array[Dictionary] = []
var triggered: Dictionary = {}
var color_counts: Dictionary = {}
var color_events: Dictionary = {}
var color_sequence: Array[String] = []
var unique_colors: Dictionary = {}
var clear_event_history: Array[Dictionary] = []
var max_cascade: int = 1
var completed_count: int = 0
var completed_colors: Dictionary = {}
var completed_color_counts: Dictionary = {}
var completion_color_history: Array[String] = []
var previous_turn_completed_colors: Dictionary = {}
var last_base_damage: int = 0
var last_event_color: String = ""
var last_event_count: int = 0
var last_event_cascade: int = 1
var last_event_active: bool = false
var active_blue_seen: bool = false
var last_moves_left: int = 3
var took_damage_this_turn: bool = false
var condition_reduction_instance_id: String = ""
var condition_reduction_key: String = ""
var last_context: Dictionary = {}
var trajectory_lens_enabled: bool = false

func begin_turn(
	new_hand: Array[Dictionary],
	enable_condition_reduction: bool = false,
	enable_trajectory_lens: bool = false
) -> void:
	hand = new_hand.duplicate(true)
	previous_turn_completed_colors = completed_colors.duplicate(true)
	triggered.clear()
	color_counts = {"gray": 0, "red": 0, "blue": 0, "gold": 0}
	color_events = {"gray": 0, "red": 0, "blue": 0, "gold": 0}
	color_sequence.clear()
	unique_colors.clear()
	clear_event_history.clear()
	max_cascade = 1
	completed_count = 0
	completed_colors.clear()
	completed_color_counts.clear()
	completion_color_history.clear()
	last_base_damage = 0
	last_event_color = ""
	last_event_count = 0
	last_event_cascade = 1
	last_event_active = false
	active_blue_seen = false
	last_moves_left = 3
	took_damage_this_turn = false
	condition_reduction_instance_id = ""
	condition_reduction_key = ""
	last_context.clear()
	trajectory_lens_enabled = enable_trajectory_lens
	if enable_condition_reduction:
		_assign_random_condition_reduction()

func mark_player_damaged() -> void:
	took_damage_this_turn = true

func add_card_to_hand(card_instance: Dictionary) -> void:
	if not card_instance.is_empty():
		var added_card: Dictionary = card_instance.duplicate(true)
		added_card["_turn_event_baseline"] = clear_event_history.size()
		added_card["_turn_completion_baseline"] = completion_color_history.size()
		hand.append(added_card)

func register_clear_event(event: Dictionary, base_damage: int, context: Dictionary) -> Array[Dictionary]:
	var color_key: String = String(event.get("type", "gray"))
	var count: int = int(event.get("count", 0))
	var cascade: int = int(event.get("cascade", 1))
	if count > 0:
		color_counts[color_key] = int(color_counts.get(color_key, 0)) + count
		color_events[color_key] = int(color_events.get(color_key, 0)) + 1
		color_sequence.append(color_key)
		unique_colors[color_key] = true
		max_cascade = max(max_cascade, cascade)
		clear_event_history.append({
			"color": color_key,
			"count": count,
			"cascade": cascade,
			"active": event.get("active", false) == true,
		})
		if color_key == "blue" and event.get("active", false) == true:
			active_blue_seen = true
	last_base_damage = base_damage
	last_event_color = color_key
	last_event_count = count
	last_event_cascade = cascade
	last_event_active = event.get("active", false) == true
	last_moves_left = int(context.get("moves_left", last_moves_left))
	return evaluate_triggers(context)

func evaluate_triggers(context: Dictionary) -> Array[Dictionary]:
	last_context = context.duplicate(true)
	last_moves_left = int(context.get("moves_left", last_moves_left))
	var fired: Array[Dictionary] = []
	var changed: bool = true
	while changed:
		changed = false
		for slot in range(hand.size()):
			var card_instance: Dictionary = hand[slot]
			var instance_id: String = String(card_instance.get("instance_id", ""))
			if instance_id == "" or triggered.has(instance_id):
				continue
			var card_id: String = String(card_instance.get("card_id", ""))
			if _is_condition_met(card_instance, context):
				triggered[instance_id] = true
				completed_count += 1
				var card: Dictionary = _card_data(card_instance)
				var completed_color: String = String(card.get("color", "neutral"))
				completed_colors[completed_color] = true
				completed_color_counts[completed_color] = int(completed_color_counts.get(completed_color, 0)) + 1
				completion_color_history.append(completed_color)
				fired.append({
					"card_id": card_id,
					"instance_id": instance_id,
					"level": int(card_instance.get("level", 0)),
					"slot": slot,
				})
				changed = true
	return fired

## Evaluates hypothetical clear events and restores every live spectrum field.
## This is intentionally implemented through the existing trigger rules so the
## combat preview cannot drift from the real resolution path.
func preview_clear_events(events: Array[Dictionary], context: Dictionary) -> Array[Dictionary]:
	var snapshot: Dictionary = create_snapshot()
	var fired: Array[Dictionary] = []
	var base_damage: int = maxi(int(context.get("base_damage", 0)), 0)
	for event in events:
		fired.append_array(register_clear_event(event, base_damage, context))
	restore_snapshot(snapshot)
	return fired

func get_card_states(retained_slots: Variant = -1) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	var trajectory_slot: int = _trajectory_target_slot()
	for slot in range(hand.size()):
		var card_instance: Dictionary = hand[slot]
		var card_id: String = String(card_instance.get("card_id", ""))
		var instance_id: String = String(card_instance.get("instance_id", ""))
		var card: Dictionary = _card_data(card_instance)
		var condition_reduced: bool = instance_id == condition_reduction_instance_id
		var is_retained: bool = retained_slots.has(slot) if retained_slots is Array else int(retained_slots) == slot
		var card_triggered: bool = triggered.has(instance_id)
		states.append({
			"id": card_id,
			"slot": slot,
			"instance_id": instance_id,
			"name": String(card.get("name", card_id)),
			"color": String(card.get("color", "neutral")),
			"rarity": String(card.get("rarity", "common")),
			"condition": String(card.get("condition", "")) + ("（四色骰 -1）" if condition_reduced else ""),
			"effect": String(card.get("effect", "")),
			"progress": _progress_text(card_instance, card),
			"triggered": card_triggered,
			"retained": is_retained,
			"upgraded": card.get("upgraded", false) == true,
			"condition_reduced": condition_reduced,
			"trajectory_preview": trajectory_lens_enabled and slot == trajectory_slot and not card_triggered,
			"trajectory_progress": _trajectory_progress(card_instance, card),
		})
	return states

func is_triggered(slot: int) -> bool:
	if slot < 0 or slot >= hand.size():
		return false
	return triggered.has(String(hand[slot].get("instance_id", "")))

func create_snapshot() -> Dictionary:
	return {
		"hand": hand.duplicate(true),
		"triggered": triggered.duplicate(true),
		"color_counts": color_counts.duplicate(true),
		"color_events": color_events.duplicate(true),
		"color_sequence": color_sequence.duplicate(),
		"unique_colors": unique_colors.duplicate(true),
		"clear_event_history": clear_event_history.duplicate(true),
		"max_cascade": max_cascade,
		"completed_count": completed_count,
		"completed_colors": completed_colors.duplicate(true),
		"completed_color_counts": completed_color_counts.duplicate(true),
		"completion_color_history": completion_color_history.duplicate(),
		"previous_turn_completed_colors": previous_turn_completed_colors.duplicate(true),
		"last_base_damage": last_base_damage,
		"last_event_color": last_event_color,
		"last_event_count": last_event_count,
		"last_event_cascade": last_event_cascade,
		"last_event_active": last_event_active,
		"active_blue_seen": active_blue_seen,
		"last_moves_left": last_moves_left,
		"took_damage_this_turn": took_damage_this_turn,
		"condition_reduction_instance_id": condition_reduction_instance_id,
		"condition_reduction_key": condition_reduction_key,
		"last_context": last_context.duplicate(true),
		"trajectory_lens_enabled": trajectory_lens_enabled,
	}

func restore_snapshot(snapshot_value: Variant) -> bool:
	if not snapshot_value is Dictionary:
		return false
	var snapshot: Dictionary = snapshot_value
	var restored_hand: Array[Dictionary] = []
	var hand_value: Variant = snapshot.get("hand", [])
	if not hand_value is Array or hand_value.is_empty():
		return false
	for card_value in hand_value:
		if not card_value is Dictionary:
			return false
		var card_instance: Dictionary = card_value
		if not GameDataScript.SPECTRA.has(String(card_instance.get("card_id", ""))):
			return false
		restored_hand.append(card_instance.duplicate(true))
	hand = restored_hand
	triggered = _bool_dictionary(snapshot.get("triggered", {}))
	color_counts = _color_dictionary(snapshot.get("color_counts", {}))
	color_events = _color_dictionary(snapshot.get("color_events", {}))
	color_sequence = _string_array(snapshot.get("color_sequence", []))
	unique_colors = _bool_dictionary(snapshot.get("unique_colors", {}))
	clear_event_history = _dictionary_array(snapshot.get("clear_event_history", []))
	max_cascade = maxi(int(snapshot.get("max_cascade", 1)), 1)
	completed_count = maxi(int(snapshot.get("completed_count", 0)), 0)
	completed_colors = _bool_dictionary(snapshot.get("completed_colors", {}))
	completed_color_counts = _count_dictionary(snapshot.get("completed_color_counts", {}))
	completion_color_history = _string_array(snapshot.get("completion_color_history", []))
	previous_turn_completed_colors = _bool_dictionary(snapshot.get("previous_turn_completed_colors", {}))
	last_base_damage = maxi(int(snapshot.get("last_base_damage", 0)), 0)
	last_event_color = String(snapshot.get("last_event_color", ""))
	last_event_count = maxi(int(snapshot.get("last_event_count", 0)), 0)
	last_event_cascade = maxi(int(snapshot.get("last_event_cascade", 1)), 1)
	last_event_active = snapshot.get("last_event_active", false) == true
	active_blue_seen = snapshot.get("active_blue_seen", false) == true
	last_moves_left = clampi(int(snapshot.get("last_moves_left", 3)), 0, 4)
	took_damage_this_turn = snapshot.get("took_damage_this_turn", false) == true
	condition_reduction_instance_id = String(snapshot.get("condition_reduction_instance_id", ""))
	condition_reduction_key = String(snapshot.get("condition_reduction_key", ""))
	last_context = snapshot.get("last_context", {}).duplicate(true) if snapshot.get("last_context", {}) is Dictionary else {}
	trajectory_lens_enabled = snapshot.get("trajectory_lens_enabled", false) == true
	for instance_id in triggered.keys():
		if not _hand_has_instance(String(instance_id)):
			triggered.erase(instance_id)
	if not _hand_has_instance(condition_reduction_instance_id):
		condition_reduction_instance_id = ""
	return true

func _hand_has_instance(instance_id: String) -> bool:
	if instance_id.is_empty():
		return false
	for card_instance in hand:
		if String(card_instance.get("instance_id", "")) == instance_id:
			return true
	return false

func _bool_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for key in value.keys():
			if value[key] == true:
				result[String(key)] = true
	return result

func _color_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {"gray": 0, "red": 0, "blue": 0, "gold": 0}
	if value is Dictionary:
		for color_key in result.keys():
			result[color_key] = maxi(int(value.get(color_key, 0)), 0)
	return result

func _count_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for key in value.keys():
			var normalized_key: String = String(key)
			if not normalized_key.is_empty():
				result[normalized_key] = maxi(int(value[key]), 0)
	return result

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(String(entry))
	return result

func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value:
			if entry is Dictionary:
				result.append(entry.duplicate(true))
	return result

func _card_data(card_instance: Dictionary) -> Dictionary:
	return GameDataScript.spectrum_for_level(
		String(card_instance.get("card_id", "")),
		int(card_instance.get("level", 0))
	)

func _is_condition_met(card_instance: Dictionary, context: Dictionary) -> bool:
	var card_id: String = String(card_instance.get("card_id", ""))
	var card: Dictionary = _card_data(card_instance)
	var moves_left: int = int(context.get("moves_left", last_moves_left))
	if card_instance.has("_turn_event_baseline") and _event_baseline(card_instance) >= clear_event_history.size():
		return false
	match card_id:
		"ember_slash":
			var threshold: int = max(_condition_int(card_instance, card, "threshold", 5) - int(context.get("red_condition_reduction", 0)), 1)
			return _color_count_since(card_instance, "red") >= threshold
		"wildfire":
			return int(context.get("last_red_count", 0)) >= _condition_int(card_instance, card, "match_size", 4)
		"fireline_dash":
			return last_event_color == "red" and int(context.get("moves_left_after", moves_left - 1)) >= int(card.get("remaining_moves_min", 1))
		"warm_guard":
			return last_event_color == "red" and int(context.get("enemy_burn_stacks", 0)) > 0
		"molten_finish":
			return _completed_color_count_since(card_instance, "red") >= _condition_int(card_instance, card, "completed_red", 2)
		"blood_pact":
			return last_event_color == "red" and float(context.get("player_hp_ratio", 1.0)) < float(card.get("hp_ratio", 0.5))
		"flame_crown":
			return (last_event_color == "red" and last_event_count >= _condition_int(card_instance, card, "match_size", 5)) or _max_cascade_since(card_instance) >= int(card.get("cascade", 3))
		"frost_guard":
			return int(context.get("last_blue_count", 0)) >= _condition_int(card_instance, card, "match_size", 4) or _color_event_count_since(card_instance, "blue") >= int(card.get("event_count", 2))
		"golden_beat":
			return _color_count_since(card_instance, "gold") >= _condition_int(card_instance, card, "gold_count", 3) and _completed_count_since(card_instance) >= 1
		"palette_drill":
			return _unique_colors_since(card_instance).size() >= _condition_int(card_instance, card, "unique_colors", 2)
		"tone_phrase":
			return _max_cascade_since(card_instance) >= _condition_int(card_instance, card, "cascade", 2)
		"crimson_echo":
			return _color_event_count_since(card_instance, "red") >= _condition_int(card_instance, card, "event_count", 2)
		"ice_rest":
			return _has_order_since(card_instance, "blue", "not_blue")
		"mirror_dodge":
			return not took_damage_this_turn and last_event_color == "blue"
		"frostline_plan":
			return _active_blue_seen_since(card_instance) and _max_cascade_since(card_instance) >= _condition_int(card_instance, card, "cascade", 2)
		"cold_wall":
			return _color_count_since(card_instance, "blue") >= _condition_int(card_instance, card, "threshold", 6)
		"stasis_seal":
			return last_event_color == "blue" and String(context.get("enemy_intent_type", "")) in ["attack", "heavy"]
		"prism_ice":
			return int(context.get("shield", 0)) > 0 and _completed_count_since(card_instance) >= 1
		"zero_finale":
			var required_turns: int = _condition_int(card_instance, card, "consecutive_turns", 2)
			if required_turns <= 1:
				return _completed_color_count_since(card_instance, "blue") > 0
			return previous_turn_completed_colors.has("blue") and _completed_color_count_since(card_instance, "blue") > 0
		"bond_refraction":
			return not took_damage_this_turn and _color_count_since(card_instance, "gold") > 0
		"caravan_beat":
			return last_event_color == "gold" and last_event_active and last_event_count >= _condition_int(card_instance, card, "match_size", 4)
		"remainder_echo":
			return context.get("skipped_reward_previous", false) == true and last_event_color == "gold"
		"gilded_charm":
			return _color_count_since(card_instance, "gold") >= _condition_int(card_instance, card, "threshold", 5)
		"arbitrage_concerto":
			var colors_since: Dictionary = _completed_colors_since(card_instance)
			return colors_since.has("gold") and colors_since.keys().any(func(color_key: Variant) -> bool: return String(color_key) != "gold")
		"royal_coin":
			return int(context.get("coins", 0)) >= _condition_int(card_instance, card, "coin_threshold", 80) and last_event_color == "gold"
		"golden_finale":
			return int(context.get("battle_gold_earned", 0)) >= _condition_int(card_instance, card, "battle_coins", 24)
		"ash_alchemy":
			return _has_order_since(card_instance, "gray", "gold")
		"mist_phrase":
			return _color_count_since(card_instance, "gray") >= _condition_int(card_instance, card, "threshold", 6)
		"gray_blade":
			return last_event_color == "gray" and last_event_active and last_event_count >= _condition_int(card_instance, card, "match_size", 4)
		"color_from_mist":
			return _has_order_since(card_instance, "gray", "player_color")
		"echo_stele":
			return context.get("enemy_polluted_this_battle", false) == true and _completed_count_since(card_instance) >= 1
		"gray_king_contract":
			return int(context.get("gray_pressure", 0)) >= _condition_int(card_instance, card, "corruption_threshold", 8)
		"daylight_calibration":
			return _completed_colors_since(card_instance).size() >= _condition_int(card_instance, card, "completed_colors", 2)
		"prism_concerto":
			return _color_event_count_since(card_instance, "red") > 0 and _color_event_count_since(card_instance, "blue") > 0 and _color_event_count_since(card_instance, "gold") > 0
		"colorless_pause":
			return _max_completed_color_count_since(card_instance) <= int(card.get("same_color_completed_max", 1)) and _completed_count_since(card_instance) >= 1
		"finale_variation":
			return _completed_count_since(card_instance) >= _condition_int(card_instance, card, "completed_cards", 3)
		"obsidian_contract":
			return int(context.get("moves_left", 3)) <= int(card.get("moves_left", 1)) and _completed_count_since(card_instance) >= 1
		_:
			return _is_generic_condition_met(card_instance, card, context)

func _is_generic_condition_met(card_instance: Dictionary, card: Dictionary, context: Dictionary) -> bool:
	var condition_type: String = String(card.get("condition_type", ""))
	var board_color: String = String(card.get("board_color", ""))
	match condition_type:
		"color_total":
			return _color_count_since(card_instance, board_color) >= _condition_int(card_instance, card, "threshold", 3)
		"unique_colors":
			return _unique_colors_since(card_instance).size() >= _condition_int(card_instance, card, "unique_colors", 2)
		"cascade":
			return _max_cascade_since(card_instance) >= _condition_int(card_instance, card, "cascade", 2)
		"match_size":
			return last_event_color == board_color and last_event_count >= _condition_int(card_instance, card, "match_size", 4) and (not card.get("active_only", false) or last_event_active)
		"color_sequence":
			return _has_order_since(card_instance, String(card.get("first_color", "gray")), String(card.get("second_color", "player_color")))
		"completed_cards":
			return _completed_count_since(card_instance) >= _condition_int(card_instance, card, "completed_cards", 2)
		"completed_colors":
			return _completed_colors_since(card_instance).size() >= _condition_int(card_instance, card, "completed_colors", 2)
		"gray_pressure":
			return int(context.get("gray_pressure", 0)) >= _condition_int(card_instance, card, "gray_pressure", 4)
		"hp_below":
			return float(context.get("player_hp_ratio", 1.0)) <= float(card.get("hp_ratio", 0.5))
		"shield_min":
			return int(context.get("shield", 0)) >= _condition_int(card_instance, card, "shield_min", 10)
		"coins_min":
			return int(context.get("coins", 0)) >= _condition_int(card_instance, card, "coins_min", 30)
		"enemy_burn":
			return int(context.get("enemy_burn_stacks", 0)) >= _condition_int(card_instance, card, "enemy_burn_stacks", 2)
		"enemy_intent":
			var intent_types: Variant = card.get("intent_types", [])
			return intent_types is Array and intent_types.has(String(context.get("enemy_intent_type", "")))
		"moves_left_after":
			return int(context.get("moves_left_after", 0)) <= int(card.get("moves_left_after_max", 0)) and _completed_count_since(card_instance) >= int(card.get("completed_cards_min", 0))
		"color_events":
			return _color_event_count_since(card_instance, board_color) >= _condition_int(card_instance, card, "event_count", 2)
		"no_damage_color":
			return not took_damage_this_turn and last_event_color == board_color
		"polluted_completed":
			return context.get("enemy_polluted_this_battle", false) == true and _completed_count_since(card_instance) >= _condition_int(card_instance, card, "completed_cards", 1)
		_:
			return false

func _event_baseline(card_instance: Dictionary) -> int:
	return clampi(int(card_instance.get("_turn_event_baseline", 0)), 0, clear_event_history.size())

func _completion_baseline(card_instance: Dictionary) -> int:
	return clampi(int(card_instance.get("_turn_completion_baseline", 0)), 0, completion_color_history.size())

func _color_count_since(card_instance: Dictionary, color_key: String) -> int:
	var result: int = 0
	for event_index in range(_event_baseline(card_instance), clear_event_history.size()):
		var event: Dictionary = clear_event_history[event_index]
		if String(event.get("color", "")) == color_key:
			result += int(event.get("count", 0))
	return result

func _color_event_count_since(card_instance: Dictionary, color_key: String) -> int:
	var result: int = 0
	for event_index in range(_event_baseline(card_instance), clear_event_history.size()):
		if String(clear_event_history[event_index].get("color", "")) == color_key:
			result += 1
	return result

func _unique_colors_since(card_instance: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for event_index in range(_event_baseline(card_instance), clear_event_history.size()):
		result[String(clear_event_history[event_index].get("color", "gray"))] = true
	return result

func _max_cascade_since(card_instance: Dictionary) -> int:
	var result: int = 1
	for event_index in range(_event_baseline(card_instance), clear_event_history.size()):
		result = max(result, int(clear_event_history[event_index].get("cascade", 1)))
	return result

func _active_blue_seen_since(card_instance: Dictionary) -> bool:
	for event_index in range(_event_baseline(card_instance), clear_event_history.size()):
		var event: Dictionary = clear_event_history[event_index]
		if String(event.get("color", "")) == "blue" and event.get("active", false) == true:
			return true
	return false

func _has_order_since(card_instance: Dictionary, first: String, second: String) -> bool:
	var seen_first: bool = false
	for event_index in range(_event_baseline(card_instance), clear_event_history.size()):
		var color_key: String = String(clear_event_history[event_index].get("color", "gray"))
		if color_key == first:
			seen_first = true
		elif seen_first:
			if second == "not_blue" and color_key != "blue":
				return true
			if second == "player_color" and ["red", "blue", "gold"].has(color_key):
				return true
			if color_key == second:
				return true
	return false

func _completed_count_since(card_instance: Dictionary) -> int:
	return completion_color_history.size() - _completion_baseline(card_instance)

func _completed_colors_since(card_instance: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for completion_index in range(_completion_baseline(card_instance), completion_color_history.size()):
		result[completion_color_history[completion_index]] = true
	return result

func _completed_color_count_since(card_instance: Dictionary, color_key: String) -> int:
	var result: int = 0
	for completion_index in range(_completion_baseline(card_instance), completion_color_history.size()):
		if completion_color_history[completion_index] == color_key:
			result += 1
	return result

func _max_completed_color_count_since(card_instance: Dictionary) -> int:
	var counts: Dictionary = {}
	var result: int = 0
	for completion_index in range(_completion_baseline(card_instance), completion_color_history.size()):
		var color_key: String = completion_color_history[completion_index]
		counts[color_key] = int(counts.get(color_key, 0)) + 1
		result = max(result, int(counts[color_key]))
	return result

func _progress_text(card_instance: Dictionary, card: Dictionary) -> String:
	var card_id: String = String(card_instance.get("card_id", ""))
	match card_id:
		"ember_slash":
			return "红 %d/%d" % [_color_count_since(card_instance, "red"), _condition_int(card_instance, card, "threshold", 5)]
		"wildfire":
			var red_count: int = last_event_count if last_event_color == "red" else 0
			return "本步红 %d/%d" % [red_count, _condition_int(card_instance, card, "match_size", 4)]
		"fireline_dash":
			return "本步%s；剩 %d 步" % [GameDataScript.color_full_name(last_event_color), last_moves_left]
		"warm_guard":
			return "等待燃烧中的红消"
		"molten_finish":
			return "红谱 %d/%d" % [_completed_color_count_since(card_instance, "red"), _condition_int(card_instance, card, "completed_red", 2)]
		"blood_pact":
			return "等待半血以下红消"
		"flame_crown":
			return "红连 %d/%d；级联 %d/%d" % [last_event_count if last_event_color == "red" else 0, _condition_int(card_instance, card, "match_size", 5), _max_cascade_since(card_instance), int(card.get("cascade", 3))]
		"frost_guard":
			var blue_count: int = last_event_count if last_event_color == "blue" else 0
			return "本步蓝 %d/%d；蓝消 %d/%d" % [blue_count, _condition_int(card_instance, card, "match_size", 4), _color_event_count_since(card_instance, "blue"), int(card.get("event_count", 2))]
		"golden_beat":
			return "金 %d/%d；已完成 %d" % [_color_count_since(card_instance, "gold"), _condition_int(card_instance, card, "gold_count", 3), _completed_count_since(card_instance)]
		"palette_drill":
			return "颜色 %d/%d" % [_unique_colors_since(card_instance).size(), _condition_int(card_instance, card, "unique_colors", 2)]
		"tone_phrase":
			return "级联 %d/%d" % [_max_cascade_since(card_instance), _condition_int(card_instance, card, "cascade", 2)]
		"crimson_echo":
			return "红消 %d/%d" % [_color_event_count_since(card_instance, "red"), _condition_int(card_instance, card, "event_count", 2)]
		"ice_rest":
			return "已消蓝；等待非蓝" if _unique_colors_since(card_instance).has("blue") else "等待先消蓝"
		"mirror_dodge":
			return "已受伤" if took_damage_this_turn else "等待蓝消"
		"frostline_plan":
			return "主动蓝 %s；级联 %d/%d" % ["已完成" if _active_blue_seen_since(card_instance) else "未完成", _max_cascade_since(card_instance), _condition_int(card_instance, card, "cascade", 2)]
		"cold_wall":
			return "蓝 %d/%d" % [_color_count_since(card_instance, "blue"), _condition_int(card_instance, card, "threshold", 6)]
		"stasis_seal":
			return "等待攻击意图下的蓝消"
		"prism_ice":
			return "完成 %d；需先有护盾" % _completed_count_since(card_instance)
		"zero_finale":
			return "上回合蓝谱 %s" % ["已完成" if previous_turn_completed_colors.has("blue") else "未完成"]
		"bond_refraction":
			return "金 %d；%s" % [_color_count_since(card_instance, "gold"), "本回合已受伤" if took_damage_this_turn else "未受伤"]
		"caravan_beat":
			return "本步金 %d/%d" % [last_event_count if last_event_color == "gold" else 0, _condition_int(card_instance, card, "match_size", 4)]
		"remainder_echo":
			return "等待跳过奖励后的金消"
		"gilded_charm":
			return "金 %d/%d" % [_color_count_since(card_instance, "gold"), _condition_int(card_instance, card, "threshold", 5)]
		"arbitrage_concerto":
			return "已完成：%s" % "、".join(_completed_colors_since(card_instance).keys())
		"royal_coin":
			return "需金币 >=%d" % _condition_int(card_instance, card, "coin_threshold", 80)
		"golden_finale":
			return "本战金收益等待达标"
		"ash_alchemy":
			return "已消灰；等待金" if _unique_colors_since(card_instance).has("gray") else "等待先消灰"
		"mist_phrase":
			return "灰 %d/%d" % [_color_count_since(card_instance, "gray"), _condition_int(card_instance, card, "threshold", 6)]
		"gray_blade":
			return "本步灰 %d/%d" % [last_event_count if last_event_color == "gray" else 0, _condition_int(card_instance, card, "match_size", 4)]
		"color_from_mist":
			return "已消灰；等待玩家色" if _unique_colors_since(card_instance).has("gray") else "等待先消灰"
		"echo_stele":
			return "等待污染后完成色谱"
		"gray_king_contract":
			return "灰蚀压力需 >=%d" % _condition_int(card_instance, card, "corruption_threshold", 8)
		"daylight_calibration":
			return "不同色谱 %d/%d" % [_completed_colors_since(card_instance).size(), _condition_int(card_instance, card, "completed_colors", 2)]
		"prism_concerto":
			return "红%d 蓝%d 金%d" % [_color_event_count_since(card_instance, "red"), _color_event_count_since(card_instance, "blue"), _color_event_count_since(card_instance, "gold")]
		"colorless_pause":
			return "同色完成最高 %d/%d" % [_max_completed_color_count_since(card_instance), int(card.get("same_color_completed_max", 1))]
		"finale_variation":
			return "色谱 %d/%d" % [_completed_count_since(card_instance), _condition_int(card_instance, card, "completed_cards", 3)]
		"obsidian_contract":
			return "剩余 %d 步；需 %d 步" % [last_moves_left, int(card.get("moves_left", 1))]
		_:
			return _generic_progress_text(card_instance, card)

func _generic_progress_text(card_instance: Dictionary, card: Dictionary) -> String:
	var condition_type: String = String(card.get("condition_type", ""))
	var board_color: String = String(card.get("board_color", ""))
	match condition_type:
		"color_total":
			return "%s %d/%d" % [GameDataScript.color_name(board_color), _color_count_since(card_instance, board_color), _condition_int(card_instance, card, "threshold", 3)]
		"unique_colors":
			return "颜色 %d/%d" % [_unique_colors_since(card_instance).size(), _condition_int(card_instance, card, "unique_colors", 2)]
		"cascade":
			return "级联 %d/%d" % [_max_cascade_since(card_instance), _condition_int(card_instance, card, "cascade", 2)]
		"match_size":
			return "本步%s %d/%d" % [GameDataScript.color_name(board_color), last_event_count if last_event_color == board_color else 0, _condition_int(card_instance, card, "match_size", 4)]
		"completed_cards":
			return "色谱 %d/%d" % [_completed_count_since(card_instance), _condition_int(card_instance, card, "completed_cards", 2)]
		"completed_colors":
			return "色谱学派 %d/%d" % [_completed_colors_since(card_instance).size(), _condition_int(card_instance, card, "completed_colors", 2)]
		"gray_pressure":
			return "灰蚀压力 %d/%d" % [int(last_context.get("gray_pressure", 0)), _condition_int(card_instance, card, "gray_pressure", 4)]
		"shield_min":
			return "护盾需 >=%d" % _condition_int(card_instance, card, "shield_min", 10)
		"coins_min":
			return "金币需 >=%d" % _condition_int(card_instance, card, "coins_min", 30)
		"enemy_burn":
			return "敌方燃烧需 >=%d" % _condition_int(card_instance, card, "enemy_burn_stacks", 2)
		"moves_left_after":
			return "本步后剩余 %d 步" % max(last_moves_left - 1, 0)
		"color_events":
			return "%s消除 %d/%d" % [GameDataScript.color_name(board_color), _color_event_count_since(card_instance, board_color), _condition_int(card_instance, card, "event_count", 2)]
		_:
			return String(card.get("short", "等待条件"))

func _trajectory_target_slot() -> int:
	if not trajectory_lens_enabled:
		return -1
	var target_slot: int = -1
	var best_progress: float = 0.0
	for slot in range(hand.size()):
		var card_instance: Dictionary = hand[slot]
		var instance_id: String = String(card_instance.get("instance_id", ""))
		if instance_id.is_empty() or triggered.has(instance_id):
			continue
		var progress: float = _trajectory_progress(card_instance, _card_data(card_instance))
		if progress <= best_progress:
			continue
		best_progress = progress
		target_slot = slot
	return target_slot

func _trajectory_progress(card_instance: Dictionary, card: Dictionary) -> float:
	var card_id: String = String(card_instance.get("card_id", ""))
	match card_id:
		"ember_slash":
			return _trajectory_ratio(_color_count_since(card_instance, "red"), _condition_int(card_instance, card, "threshold", 5))
		"wildfire":
			return _trajectory_ratio(last_event_count if last_event_color == "red" else 0, _condition_int(card_instance, card, "match_size", 4))
		"molten_finish":
			return _trajectory_ratio(_completed_color_count_since(card_instance, "red"), _condition_int(card_instance, card, "completed_red", 2))
		"frost_guard":
			return maxf(
				_trajectory_ratio(last_event_count if last_event_color == "blue" else 0, _condition_int(card_instance, card, "match_size", 4)),
				_trajectory_ratio(_color_event_count_since(card_instance, "blue"), int(card.get("event_count", 2)))
			)
		"golden_beat":
			return _trajectory_ratio(_color_count_since(card_instance, "gold"), _condition_int(card_instance, card, "gold_count", 3))
		"palette_drill":
			return _trajectory_ratio(_unique_colors_since(card_instance).size(), _condition_int(card_instance, card, "unique_colors", 2))
		"tone_phrase":
			return _trajectory_ratio(_max_cascade_since(card_instance), _condition_int(card_instance, card, "cascade", 2))
		"crimson_echo":
			return _trajectory_ratio(_color_event_count_since(card_instance, "red"), _condition_int(card_instance, card, "event_count", 2))
		"cold_wall":
			return _trajectory_ratio(_color_count_since(card_instance, "blue"), _condition_int(card_instance, card, "threshold", 6))
		"gilded_charm":
			return _trajectory_ratio(_color_count_since(card_instance, "gold"), _condition_int(card_instance, card, "threshold", 5))
		"gray_king_contract":
			return _trajectory_ratio(int(last_context.get("gray_pressure", 0)), _condition_int(card_instance, card, "corruption_threshold", 8))
		"daylight_calibration":
			return _trajectory_ratio(_completed_colors_since(card_instance).size(), _condition_int(card_instance, card, "completed_colors", 2))
		"finale_variation":
			return _trajectory_ratio(_completed_count_since(card_instance), _condition_int(card_instance, card, "completed_cards", 3))
		_:
			return _generic_trajectory_progress(card_instance, card)

func _generic_trajectory_progress(card_instance: Dictionary, card: Dictionary) -> float:
	var condition_type: String = String(card.get("condition_type", ""))
	var board_color: String = String(card.get("board_color", ""))
	match condition_type:
		"color_total":
			return _trajectory_ratio(_color_count_since(card_instance, board_color), _condition_int(card_instance, card, "threshold", 3))
		"unique_colors":
			return _trajectory_ratio(_unique_colors_since(card_instance).size(), _condition_int(card_instance, card, "unique_colors", 2))
		"cascade":
			return _trajectory_ratio(_max_cascade_since(card_instance), _condition_int(card_instance, card, "cascade", 2))
		"match_size":
			return _trajectory_ratio(last_event_count if last_event_color == board_color else 0, _condition_int(card_instance, card, "match_size", 4))
		"completed_cards":
			return _trajectory_ratio(_completed_count_since(card_instance), _condition_int(card_instance, card, "completed_cards", 2))
		"completed_colors":
			return _trajectory_ratio(_completed_colors_since(card_instance).size(), _condition_int(card_instance, card, "completed_colors", 2))
		"gray_pressure":
			return _trajectory_ratio(int(last_context.get("gray_pressure", 0)), _condition_int(card_instance, card, "gray_pressure", 4))
		"shield_min":
			return _trajectory_ratio(int(last_context.get("shield", 0)), _condition_int(card_instance, card, "shield_min", 10))
		"coins_min":
			return _trajectory_ratio(int(last_context.get("coins", 0)), _condition_int(card_instance, card, "coins_min", 30))
		"enemy_burn":
			return _trajectory_ratio(int(last_context.get("enemy_burn_stacks", 0)), _condition_int(card_instance, card, "enemy_burn_stacks", 2))
		"enemy_intent":
			var intent_types: Variant = card.get("intent_types", [])
			return 1.0 if intent_types is Array and intent_types.has(String(last_context.get("enemy_intent_type", ""))) else 0.0
		"moves_left_after":
			return 1.0 if max(last_moves_left - 1, 0) <= int(card.get("moves_left_after_max", 0)) else 0.0
		"color_events":
			return _trajectory_ratio(_color_event_count_since(card_instance, board_color), _condition_int(card_instance, card, "event_count", 2))
		"color_sequence":
			return 1.0 if _has_order_since(card_instance, String(card.get("first_color", "gray")), String(card.get("second_color", "player_color"))) else 0.0
		"no_damage_color":
			return 1.0 if not took_damage_this_turn and last_event_color == board_color else 0.0
		"polluted_completed":
			return 1.0 if last_context.get("enemy_polluted_this_battle", false) == true and _completed_count_since(card_instance) >= 1 else 0.0
		_:
			return 0.0

func _trajectory_ratio(current: int, target: int) -> float:
	if target <= 0:
		return 0.0
	return clampf(float(current) / float(target), 0.0, 1.0)

func _assign_random_condition_reduction() -> void:
	var candidates: Array[Dictionary] = []
	for card_instance in hand:
		var card_id: String = String(card_instance.get("card_id", ""))
		var card: Dictionary = _card_data(card_instance)
		var key: String = String(card.get("condition_key", CONDITION_KEYS.get(card_id, "")))
		if key == "":
			continue
		if int(card.get(key, 1)) > 1:
			candidates.append(card_instance)
	if candidates.is_empty():
		return
	var target: Dictionary = candidates.pick_random()
	condition_reduction_instance_id = String(target.get("instance_id", ""))
	var target_card: Dictionary = _card_data(target)
	condition_reduction_key = String(target_card.get("condition_key", CONDITION_KEYS.get(String(target.get("card_id", "")), "")))

func _condition_int(card_instance: Dictionary, card: Dictionary, key: String, fallback: int) -> int:
	var value: int = int(card.get(key, fallback))
	if String(card_instance.get("instance_id", "")) == condition_reduction_instance_id and key == condition_reduction_key:
		value -= 1
	return max(value, 1)
