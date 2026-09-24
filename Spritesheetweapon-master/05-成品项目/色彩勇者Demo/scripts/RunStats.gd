extends RefCounted
class_name RunStats

const SCHEMA_VERSION: int = 2
const MAX_STAT_VALUE: int = 1_000_000_000
const MAX_DAMAGE_SOURCES: int = 128
const MAX_IDENTIFIER_LENGTH: int = 128
const MAX_SOURCE_LENGTH: int = 64

const EVENT_ALIASES: Dictionary = {
	"turn": "turns",
	"turns": "turns",
	"round": "turns",
	"swap": "swaps",
	"swaps": "swaps",
	"match": "matches",
	"matches": "matches",
	"clear": "matches",
	"clears": "matches",
	"elimination": "matches",
	"cascade": "cascades",
	"cascades": "cascades",
	"spectrum": "spectra_completed",
	"spectra": "spectra_completed",
	"spectrum_completed": "spectra_completed",
	"spectra_completed": "spectra_completed",
	"score_completed": "spectra_completed",
	"resonance_advance": "resonance_advances",
	"resonance_advances": "resonance_advances",
	"sequence_advance": "resonance_advances",
	"resonance_trigger": "resonance_triggers",
	"resonance_triggers": "resonance_triggers",
	"resonance": "resonance_triggers",
	"shot": "shots_fired",
	"shots": "shots_fired",
	"shot_fired": "shots_fired",
	"shots_fired": "shots_fired",
	"launch": "shots_fired",
	"ball": "balls_fired",
	"balls": "balls_fired",
	"ball_fired": "balls_fired",
	"balls_fired": "balls_fired",
	"marble": "balls_fired",
	"orb": "balls_fired",
	"hit": "hits",
	"hits": "hits",
	"peg_hit": "hits",
	"critical": "critical_hits",
	"crit": "critical_hits",
	"crits": "critical_hits",
	"critical_hit": "critical_hits",
	"critical_hits": "critical_hits",
	"hazard": "hazard_pegs",
	"hazard_peg": "hazard_pegs",
	"hazard_pegs": "hazard_pegs",
	"damage": "damage",
	"damage_dealt": "damage",
	"shield": "shield_gained",
	"shield_gain": "shield_gained",
	"shield_gained": "shield_gained",
	"shield_absorbed": "shield_absorbed",
	"shield_blocked": "shield_absorbed",
	"coin": "coins_gained",
	"coins": "coins_gained",
	"gold": "coins_gained",
	"coins_gained": "coins_gained",
	"coins_earned": "coins_gained",
	"coins_spent": "coins_spent",
	"gold_spent": "coins_spent",
	"battle": "battle_result",
	"battle_result": "battle_result",
	"battle_win": "battle_result",
	"battle_loss": "battle_result",
	"battle_escape": "battle_result",
}

var started: bool = false
var run_id: String = ""
var metadata: Dictionary = {}

var turns: int = 0
var swaps: int = 0
var matches: int = 0
var cascades: int = 0
var spectra_completed: int = 0
var resonance_advances: int = 0
var resonance_triggers: int = 0
var shots_fired: int = 0
var balls_fired: int = 0
var hits: int = 0
var critical_hits: int = 0
var hazard_pegs: int = 0
var damage_by_source: Dictionary = {}
var shield_gained: int = 0
var shield_absorbed: int = 0
var coins_gained: int = 0
var coins_spent: int = 0
var battle_results: Dictionary = {}
var spectrum_tags_completed: Dictionary = {}
var spectrum_tags_selected: Dictionary = {}

const BUILD_TAGS: Array[String] = [
	"燃烧", "冻结", "护盾", "金币", "灰蚀", "连锁", "共鸣", "多色", "自伤",
]


func _init() -> void:
	reset()


func start(run_identifier: Variant = "", run_metadata: Variant = {}) -> bool:
	var next_run_id: String = ""
	var next_metadata: Dictionary = {}
	if _is_string_value(run_identifier):
		next_run_id = String(run_identifier).strip_edges().left(MAX_IDENTIFIER_LENGTH)
	elif typeof(run_identifier) == TYPE_DICTIONARY:
		var identifier_metadata: Dictionary = run_identifier
		next_metadata = _sanitize_metadata(identifier_metadata)
	else:
		return false

	if typeof(run_metadata) != TYPE_DICTIONARY:
		return false
	var explicit_metadata: Dictionary = run_metadata
	var sanitized_metadata: Dictionary = _sanitize_metadata(explicit_metadata)
	for key_value in sanitized_metadata:
		var key: String = String(key_value)
		next_metadata[key] = sanitized_metadata[key_value]

	reset()
	started = true
	run_id = next_run_id
	metadata = next_metadata.duplicate(true)
	return true


func reset() -> void:
	started = false
	run_id = ""
	metadata = {}
	turns = 0
	swaps = 0
	matches = 0
	cascades = 0
	spectra_completed = 0
	resonance_advances = 0
	resonance_triggers = 0
	shots_fired = 0
	balls_fired = 0
	hits = 0
	critical_hits = 0
	hazard_pegs = 0
	damage_by_source = {}
	shield_gained = 0
	shield_absorbed = 0
	coins_gained = 0
	coins_spent = 0
	battle_results = {
		"win": 0,
		"loss": 0,
		"escape": 0,
	}
	spectrum_tags_completed = {}
	spectrum_tags_selected = {}


func record(event_name: Variant, value: Variant = 1, details: Variant = {}) -> bool:
	var raw_event: String = _normalized_token(event_name)
	if raw_event.is_empty():
		return false
	var canonical_event: String = String(EVENT_ALIASES.get(raw_event, ""))
	if canonical_event.is_empty():
		return false

	var payload: Dictionary = {}
	if typeof(value) == TYPE_DICTIONARY:
		var value_payload: Dictionary = value
		payload = value_payload.duplicate(true)
	if typeof(details) == TYPE_DICTIONARY:
		var detail_payload: Dictionary = details
		for key in detail_payload:
			payload[key] = detail_payload[key]
	elif _is_string_value(details):
		if canonical_event == "damage":
			payload["source"] = details
		elif canonical_event == "battle_result":
			payload["result"] = details
	elif details != null:
		return false

	var amount_value: Variant = value
	if typeof(value) == TYPE_DICTIONARY:
		amount_value = payload.get("amount", payload.get("value", 1))
	elif _is_string_value(value):
		if canonical_event == "battle_result":
			payload["result"] = value
			amount_value = payload.get("amount", 1)
		elif canonical_event == "damage":
			payload["source"] = value
			amount_value = payload.get("amount", 0)

	if raw_event == "battle_win":
		payload["result"] = "win"
	elif raw_event == "battle_loss":
		payload["result"] = "loss"
	elif raw_event == "battle_escape":
		payload["result"] = "escape"

	var amount: int = _safe_non_negative_int(amount_value)
	if amount <= 0:
		return false

	match canonical_event:
		"damage":
			return _record_damage(payload, amount)
		"battle_result":
			return _record_battle_result(payload, amount)
		_:
			return _record_counter(canonical_event, amount)


func summary() -> Dictionary:
	var total_damage: int = _total_damage()
	var top_source: String = ""
	var top_amount: int = 0
	var sources: Array[String] = []
	for source_value in damage_by_source:
		sources.append(String(source_value))
	sources.sort()
	for source in sources:
		var source_amount: int = _safe_non_negative_int(damage_by_source.get(source, 0))
		if source_amount > top_amount:
			top_source = source
			top_amount = source_amount

	var hit_rate: float = _bounded_rate(hits, balls_fired)
	var crit_rate: float = _bounded_rate(critical_hits, hits)
	var average_damage: float = 0.0
	var average_damage_per_spectrum: float = 0.0
	var average_hits_per_ball: float = 0.0
	if shots_fired > 0:
		average_damage = float(total_damage) / float(shots_fired)
	if balls_fired > 0:
		average_hits_per_ball = float(hits) / float(balls_fired)
	if spectra_completed > 0:
		average_damage_per_spectrum = float(total_damage) / float(spectra_completed)

	return {
		"started": started,
		"run_id": run_id,
		"metadata": metadata.duplicate(true),
		"turns": turns,
		"swaps": swaps,
		"matches": matches,
		"cascades": cascades,
		"spectra_completed": spectra_completed,
		"resonance_advances": resonance_advances,
		"resonance_triggers": resonance_triggers,
		"resonance_rate": _bounded_rate(resonance_triggers, resonance_advances),
		"shots_fired": shots_fired,
		"balls_fired": balls_fired,
		"hits": hits,
		"critical_hits": critical_hits,
		"hazard_pegs": hazard_pegs,
		"damage_total": total_damage,
		"total_damage": total_damage,
		"damage_by_source": damage_by_source.duplicate(true),
		"shield_gained": shield_gained,
		"shield_absorbed": shield_absorbed,
		"coins_gained": coins_gained,
		"coins_spent": coins_spent,
		"coins_net": coins_gained - coins_spent,
		"battle_results": battle_results.duplicate(true),
		"battles_total": _battle_total(),
		"hit_rate": hit_rate,
		"crit_rate": crit_rate,
		"average_damage_per_shot": average_damage,
		"average_damage_per_spectrum": average_damage_per_spectrum,
		"average_hits_per_ball": average_hits_per_ball,
		"top_damage_source": top_source,
		"top_damage_amount": top_amount,
		"spectrum_tags_completed": spectrum_tags_completed.duplicate(true),
		"spectrum_tags_selected": spectrum_tags_selected.duplicate(true),
		"dominant_spectrum_tag": _dominant_tag(spectrum_tags_completed),
	}


func serialize() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"started": started,
		"run_id": run_id,
		"metadata": metadata.duplicate(true),
		"turns": turns,
		"swaps": swaps,
		"matches": matches,
		"cascades": cascades,
		"spectra_completed": spectra_completed,
		"resonance_advances": resonance_advances,
		"resonance_triggers": resonance_triggers,
		"shots_fired": shots_fired,
		"balls_fired": balls_fired,
		"hits": hits,
		"critical_hits": critical_hits,
		"hazard_pegs": hazard_pegs,
		"damage_by_source": damage_by_source.duplicate(true),
		"shield_gained": shield_gained,
		"shield_absorbed": shield_absorbed,
		"coins_gained": coins_gained,
		"coins_spent": coins_spent,
		"battle_results": battle_results.duplicate(true),
		"spectrum_tags_completed": spectrum_tags_completed.duplicate(true),
		"spectrum_tags_selected": spectrum_tags_selected.duplicate(true),
	}


func restore(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var snapshot: Dictionary = data
	if snapshot.is_empty():
		return false

	var counters: Dictionary = {}
	if typeof(snapshot.get("counters", null)) == TYPE_DICTIONARY:
		counters = snapshot["counters"]

	reset()
	started = _safe_bool(snapshot.get("started", snapshot.get("active", false)))
	run_id = _safe_text(snapshot.get("run_id", snapshot.get("id", "")), MAX_IDENTIFIER_LENGTH)
	if typeof(snapshot.get("metadata", null)) == TYPE_DICTIONARY:
		var restored_metadata: Dictionary = snapshot["metadata"]
		metadata = _sanitize_metadata(restored_metadata)

	turns = _read_count(snapshot, counters, "turns", "turn")
	swaps = _read_count(snapshot, counters, "swaps", "swap")
	matches = _read_count(snapshot, counters, "matches", "clears", "eliminations")
	cascades = _read_count(snapshot, counters, "cascades", "cascade")
	spectra_completed = _read_count(snapshot, counters, "spectra_completed", "completed_spectra", "spectrums_completed")
	resonance_advances = _read_count(snapshot, counters, "resonance_advances", "resonance_progress", "sequence_advances")
	resonance_triggers = _read_count(snapshot, counters, "resonance_triggers", "resonances", "sequence_triggers")
	shots_fired = _read_count(snapshot, counters, "shots_fired", "shots")
	balls_fired = _read_count(snapshot, counters, "balls_fired", "balls", "marbles_fired")
	hits = _read_count(snapshot, counters, "hits", "peg_hits")
	critical_hits = _read_count(snapshot, counters, "critical_hits", "crits")
	hazard_pegs = _read_count(snapshot, counters, "hazard_pegs", "hazards", "hazard_pegs_hit")
	shield_gained = _read_count(snapshot, counters, "shield_gained", "shield")
	shield_absorbed = _read_count(snapshot, counters, "shield_absorbed", "shield_blocked")
	coins_gained = _read_count(snapshot, counters, "coins_gained", "coins_earned", "coins")
	coins_spent = _read_count(snapshot, counters, "coins_spent", "gold_spent")

	_restore_damage_sources(snapshot, counters)
	_restore_battle_results(snapshot, counters)
	_restore_tag_counts(snapshot, counters, "spectrum_tags_completed", spectrum_tags_completed)
	_restore_tag_counts(snapshot, counters, "spectrum_tags_selected", spectrum_tags_selected)
	return true

func record_spectrum_tag(tag: String, event_name: String = "completed") -> bool:
	var normalized: String = tag.strip_edges()
	if not BUILD_TAGS.has(normalized):
		return false
	var target: Dictionary = spectrum_tags_completed if event_name == "completed" else spectrum_tags_selected if event_name == "selected" else {}
	if target.is_empty() and event_name not in ["completed", "selected"]:
		return false
	target[normalized] = _saturating_add(_safe_non_negative_int(target.get(normalized, 0)), 1)
	return true

func record_spectrum_tags(tags: Array, event_name: String = "completed") -> int:
	var recorded: int = 0
	for tag in tags:
		if record_spectrum_tag(String(tag), event_name):
			recorded += 1
	return recorded


func _record_counter(counter_name: String, amount: int) -> bool:
	match counter_name:
		"turns":
			turns = _saturating_add(turns, amount)
		"swaps":
			swaps = _saturating_add(swaps, amount)
		"matches":
			matches = _saturating_add(matches, amount)
		"cascades":
			cascades = _saturating_add(cascades, amount)
		"spectra_completed":
			spectra_completed = _saturating_add(spectra_completed, amount)
		"resonance_advances":
			resonance_advances = _saturating_add(resonance_advances, amount)
		"resonance_triggers":
			resonance_triggers = _saturating_add(resonance_triggers, amount)
		"shots_fired":
			shots_fired = _saturating_add(shots_fired, amount)
		"balls_fired":
			balls_fired = _saturating_add(balls_fired, amount)
		"hits":
			hits = _saturating_add(hits, amount)
		"critical_hits":
			critical_hits = _saturating_add(critical_hits, amount)
		"hazard_pegs":
			hazard_pegs = _saturating_add(hazard_pegs, amount)
		"shield_gained":
			shield_gained = _saturating_add(shield_gained, amount)
		"shield_absorbed":
			shield_absorbed = _saturating_add(shield_absorbed, amount)
		"coins_gained":
			coins_gained = _saturating_add(coins_gained, amount)
		"coins_spent":
			coins_spent = _saturating_add(coins_spent, amount)
		_:
			return false
	return true


func _record_damage(payload: Dictionary, amount: int) -> bool:
	var source: String = _normalized_source(payload.get("source", payload.get("damage_source", "")))
	if source.is_empty():
		return false
	if not damage_by_source.has(source) and damage_by_source.size() >= MAX_DAMAGE_SOURCES:
		return false
	var current: int = _safe_non_negative_int(damage_by_source.get(source, 0))
	damage_by_source[source] = _saturating_add(current, amount)
	return true


func _record_battle_result(payload: Dictionary, amount: int) -> bool:
	var result: String = _normalized_battle_result(payload.get("result", payload.get("outcome", "")))
	if result.is_empty():
		return false
	battle_results[result] = _saturating_add(_safe_non_negative_int(battle_results.get(result, 0)), amount)
	return true


func _restore_damage_sources(snapshot: Dictionary, counters: Dictionary) -> void:
	var source_value: Variant = snapshot.get(
		"damage_by_source",
		snapshot.get("damage_sources", counters.get("damage_by_source", {}))
	)
	if typeof(source_value) == TYPE_DICTIONARY:
		var source_data: Dictionary = source_value
		for source_value_key in source_data:
			if damage_by_source.size() >= MAX_DAMAGE_SOURCES:
				break
			var source: String = _normalized_source(source_value_key)
			var amount: int = _safe_non_negative_int(source_data[source_value_key])
			if not source.is_empty() and amount > 0:
				damage_by_source[source] = _saturating_add(
					_safe_non_negative_int(damage_by_source.get(source, 0)),
					amount
				)

	if damage_by_source.is_empty():
		var legacy_total: int = _read_count(snapshot, counters, "damage_total", "total_damage")
		if legacy_total > 0:
			damage_by_source["unknown"] = legacy_total


func _restore_battle_results(snapshot: Dictionary, counters: Dictionary) -> void:
	var result_value: Variant = snapshot.get(
		"battle_results",
		snapshot.get("battle_outcomes", counters.get("battle_results", {}))
	)
	if typeof(result_value) == TYPE_DICTIONARY:
		var result_data: Dictionary = result_value
		for result_key in result_data:
			var result: String = _normalized_battle_result(result_key)
			var amount: int = _safe_non_negative_int(result_data[result_key])
			if not result.is_empty() and amount > 0:
				battle_results[result] = _saturating_add(
					_safe_non_negative_int(battle_results.get(result, 0)),
					amount
				)

	if _safe_non_negative_int(battle_results.get("win", 0)) == 0:
		battle_results["win"] = _read_count(snapshot, counters, "battles_won", "wins")
	if _safe_non_negative_int(battle_results.get("loss", 0)) == 0:
		battle_results["loss"] = _read_count(snapshot, counters, "battles_lost", "losses")
	if _safe_non_negative_int(battle_results.get("escape", 0)) == 0:
		battle_results["escape"] = _read_count(snapshot, counters, "battles_escaped", "escapes", "retreats")

func _restore_tag_counts(snapshot: Dictionary, counters: Dictionary, key: String, target: Dictionary) -> void:
	var raw: Variant = snapshot.get(key, counters.get(key, {}))
	if not raw is Dictionary:
		return
	for tag_value in raw.keys():
		var tag: String = String(tag_value)
		if not BUILD_TAGS.has(tag):
			continue
		var amount: int = _safe_non_negative_int(raw[tag_value])
		if amount > 0:
			target[tag] = mini(amount, MAX_STAT_VALUE)

func _dominant_tag(counts: Dictionary) -> String:
	var best_tag: String = ""
	var best_count: int = 0
	for tag in BUILD_TAGS:
		var count: int = _safe_non_negative_int(counts.get(tag, 0))
		if count > best_count:
			best_tag = tag
			best_count = count
	return best_tag


func _read_count(
	snapshot: Dictionary,
	counters: Dictionary,
	key: String,
	legacy_key: String = "",
	second_legacy_key: String = ""
) -> int:
	var keys: Array[String] = [key]
	if not legacy_key.is_empty():
		keys.append(legacy_key)
	if not second_legacy_key.is_empty():
		keys.append(second_legacy_key)
	for candidate in keys:
		if counters.has(candidate):
			return _safe_non_negative_int(counters[candidate])
	for candidate in keys:
		if snapshot.has(candidate):
			return _safe_non_negative_int(snapshot[candidate])
	return 0


func _total_damage() -> int:
	var total: int = 0
	for amount_value in damage_by_source.values():
		total = _saturating_add(total, _safe_non_negative_int(amount_value))
	return total


func _battle_total() -> int:
	var total: int = 0
	for result in ["win", "loss", "escape"]:
		total = _saturating_add(total, _safe_non_negative_int(battle_results.get(result, 0)))
	return total


func _bounded_rate(numerator: int, denominator: int) -> float:
	if numerator <= 0 or denominator <= 0:
		return 0.0
	return minf(float(numerator) / float(denominator), 1.0)


func _saturating_add(current: int, amount: int) -> int:
	return mini(maxi(current, 0) + maxi(amount, 0), MAX_STAT_VALUE)


func _safe_non_negative_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return clampi(int(value), 0, MAX_STAT_VALUE)
	if typeof(value) == TYPE_FLOAT:
		var float_value: float = value
		if is_nan(float_value) or is_inf(float_value):
			return 0
		return clampi(int(float_value), 0, MAX_STAT_VALUE)
	return 0


func _safe_bool(value: Variant) -> bool:
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	if typeof(value) == TYPE_INT:
		return int(value) > 0
	return false


func _safe_text(value: Variant, maximum_length: int) -> String:
	if not _is_string_value(value):
		return ""
	return String(value).strip_edges().left(maxi(maximum_length, 0))


func _normalized_token(value: Variant) -> String:
	return _safe_text(value, MAX_IDENTIFIER_LENGTH).to_lower()


func _normalized_source(value: Variant) -> String:
	return _safe_text(value, MAX_SOURCE_LENGTH).to_lower()


func _normalized_battle_result(value: Variant) -> String:
	match _normalized_token(value):
		"win", "won", "victory":
			return "win"
		"loss", "lost", "defeat":
			return "loss"
		"escape", "escaped", "retreat", "abandon":
			return "escape"
		_:
			return ""


func _sanitize_metadata(value: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	for key_value in value:
		var key: String = _safe_text(key_value, MAX_IDENTIFIER_LENGTH)
		if key.is_empty() or value[key_value] == null:
			continue
		sanitized[key] = value[key_value]
	return sanitized


func _is_string_value(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME
