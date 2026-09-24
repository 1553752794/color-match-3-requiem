extends RefCounted
class_name ResonanceSequence

const COLOR_TONES: Dictionary = {
	"red": ["R"],
	"blue": ["B"],
	"gold": ["G"],
	"gray": ["X"],
	"purple": ["R", "B"],
	"green": ["B", "G"],
	"white": ["R", "B", "G"],
	"mixed": ["R", "B", "G"],
	"black": ["X"],
}

const RESONANCE_RULES: Dictionary = {
	"unison": {"name": "同频和声", "bonus_damage": 4, "echo_damage": 1},
	"violet": {"name": "紫弦折射", "bonus_damage": 2, "crit_chance": 0.12},
	"verdant": {"name": "翠生回路", "shield": 4, "hazard_guard": 1},
	"amber": {"name": "熔金脉冲", "bonus_damage": 3, "coins": 1},
	"daylight": {"name": "白昼三和", "bonus_damage": 4, "cleanse": 1, "hazard_guard": 1},
	"decolor": {"name": "消色回声", "bonus_damage": 2, "cleanse": 1, "pierce": 1},
}

var lead_note: Dictionary = {}
var tail_note: Dictionary = {}
var resonance_consumed: bool = false
var last_resonance: Dictionary = {}
var turn_index: int = 0
var trigger_count: int = 0
var completed_notes: int = 0


func reset() -> void:
	lead_note.clear()
	tail_note.clear()
	resonance_consumed = false
	last_resonance.clear()
	turn_index = 0
	trigger_count = 0
	completed_notes = 0


func begin_turn() -> Dictionary:
	turn_index += 1
	lead_note = tail_note.duplicate(true)
	tail_note.clear()
	resonance_consumed = false
	last_resonance.clear()
	return get_state()


func register_color(color_key: String) -> Dictionary:
	var current_note: Dictionary = note_for_color(color_key)
	if current_note.is_empty():
		var ignored: Dictionary = get_state()
		ignored["registered"] = false
		ignored["resonance"] = {}
		return ignored

	completed_notes += 1
	var resonance: Dictionary = {}
	if not lead_note.is_empty() and not resonance_consumed:
		resonance = resolve_pair(lead_note, current_note)
		resonance_consumed = true
		if not resonance.is_empty():
			trigger_count += 1
			last_resonance = resonance.duplicate(true)
	tail_note = current_note.duplicate(true)

	var result: Dictionary = get_state()
	result["registered"] = true
	result["current_note"] = current_note
	result["resonance"] = resonance
	return result


func get_state() -> Dictionary:
	return {
		"lead_note": lead_note.duplicate(true),
		"tail_note": tail_note.duplicate(true),
		"consumed": resonance_consumed,
		"last_resonance": last_resonance.duplicate(true),
		"turn": turn_index,
		"trigger_count": trigger_count,
		"completed_notes": completed_notes,
	}


func snapshot() -> Dictionary:
	return get_state()


func restore(snapshot_value: Variant) -> void:
	reset()
	if not snapshot_value is Dictionary:
		return
	var snapshot_data: Dictionary = snapshot_value
	lead_note = _sanitize_note(snapshot_data.get("lead_note", {}))
	tail_note = _sanitize_note(snapshot_data.get("tail_note", {}))
	resonance_consumed = snapshot_data.get("consumed", false) == true
	last_resonance = _sanitize_resonance(snapshot_data.get("last_resonance", {}))
	turn_index = maxi(int(snapshot_data.get("turn", 0)), 0)
	trigger_count = maxi(int(snapshot_data.get("trigger_count", 0)), 0)
	completed_notes = maxi(int(snapshot_data.get("completed_notes", 0)), 0)


static func note_for_color(color_key: String) -> Dictionary:
	var normalized: String = color_key.to_lower().strip_edges()
	var tones_value: Variant = COLOR_TONES.get(normalized, [])
	if not tones_value is Array or tones_value.is_empty():
		return {}
	return {"color": normalized, "tones": Array(tones_value).duplicate()}


static func resolve_pair(lead_value: Variant, answer_value: Variant) -> Dictionary:
	var lead: Dictionary = _sanitize_note(lead_value)
	var answer: Dictionary = _sanitize_note(answer_value)
	if lead.is_empty() or answer.is_empty():
		return {}
	var lead_tones: Array = lead.get("tones", [])
	var answer_tones: Array = answer.get("tones", [])
	var resonance_id: String = ""
	if lead_tones.has("X") or answer_tones.has("X"):
		resonance_id = "decolor"
	elif _has_intersection(lead_tones, answer_tones):
		resonance_id = "unison"
	else:
		var union: Array[String] = _tone_union(lead_tones, answer_tones)
		if union == ["B", "R"]:
			resonance_id = "violet"
		elif union == ["B", "G"]:
			resonance_id = "verdant"
		elif union == ["G", "R"]:
			resonance_id = "amber"
		elif union == ["B", "G", "R"]:
			resonance_id = "daylight"
	if resonance_id == "":
		return {}
	var rule: Dictionary = RESONANCE_RULES[resonance_id].duplicate(true)
	rule["id"] = resonance_id
	rule["lead"] = lead
	rule["answer"] = answer
	return rule


static func _sanitize_note(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var color_key: String = String(value.get("color", ""))
	return note_for_color(color_key)


static func _sanitize_resonance(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var resonance_id: String = String(value.get("id", ""))
	if not RESONANCE_RULES.has(resonance_id):
		return {}
	var result: Dictionary = RESONANCE_RULES[resonance_id].duplicate(true)
	result["id"] = resonance_id
	result["lead"] = _sanitize_note(value.get("lead", {}))
	result["answer"] = _sanitize_note(value.get("answer", {}))
	return result


static func _has_intersection(left: Array, right: Array) -> bool:
	for tone in left:
		if right.has(tone):
			return true
	return false


static func _tone_union(left: Array, right: Array) -> Array[String]:
	var result: Array[String] = []
	for tone_value in left + right:
		var tone: String = String(tone_value)
		if not result.has(tone):
			result.append(tone)
	result.sort()
	return result
