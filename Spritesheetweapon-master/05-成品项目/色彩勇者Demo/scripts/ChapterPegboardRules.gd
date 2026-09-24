class_name ChapterPegboardRules
extends RefCounted

const BOARD_COLUMNS: int = 9
const BOARD_ROWS: int = 8
const BOARD_PEG_COUNT: int = BOARD_COLUMNS * BOARD_ROWS
const MAX_EDGE_PEG_RATIO: float = 0.25
const MIN_AIM_SPAN: float = 1.0
const MIN_AIM_SIDE_REACH: float = 0.4

const INTENT_PHASE_TELEGRAPH: String = "telegraph"
const INTENT_PHASE_ACTIVE: String = "active"
const INTENT_PHASE_CLEARED: String = "cleared"

const PROFILE_KEYS: Array[String] = ["normal", "elite", "boss_phase1", "boss_phase2"]
const PEG_TYPE_ORDER: Array[String] = [
	"normal",
	"critical",
	"echo",
	"flame",
	"mist",
	"mirror",
	"bumper",
	"resistance",
	"lock",
	"void",
	"hazard",
]

const INTENT_DEFINITIONS: Dictionary = {
	"seal": {
		"id": "seal",
		"telegraph_key": "intent.seal.telegraph",
		"telegraph_turns": 1,
		"duration_shots": 1,
		"clear_events": ["shot_resolved", "enemy_defeated", "battle_end", "dispel"],
		"effect": {"sealed_pegs_per_strength": 3},
	},
	"aim_drift": {
		"id": "aim_drift",
		"telegraph_key": "intent.aim_drift.telegraph",
		"telegraph_turns": 1,
		"duration_shots": 1,
		"clear_events": ["shot_resolved", "enemy_defeated", "battle_end", "dispel"],
		"effect": {"drift_per_strength": 0.12},
	},
	"crit_suppress": {
		"id": "crit_suppress",
		"telegraph_key": "intent.crit_suppress.telegraph",
		"telegraph_turns": 1,
		"duration_shots": 1,
		"clear_events": ["shot_resolved", "enemy_defeated", "battle_end", "dispel"],
		"effect": {"crit_multiplier_per_strength": 0.65},
	},
	"add_hazard": {
		"id": "add_hazard",
		"telegraph_key": "intent.add_hazard.telegraph",
		"telegraph_turns": 1,
		"duration_shots": 1,
		"clear_events": ["shot_resolved", "enemy_defeated", "battle_end", "dispel"],
		"effect": {"hazard_pegs_per_strength": 3},
	},
}

const PROFILE_CATALOG: Dictionary = {
	1: {
		"normal": {
			"id": "c1_normal_ember_mist",
			"theme": "ember_mist",
			"aim_min": -0.92,
			"aim_max": 0.92,
			"peg_counts": {"normal": 44, "critical": 6, "echo": 4, "flame": 10, "mist": 8},
			"physics": {"gravity": 1.00, "bounce": 0.82, "horizontal_noise": 0.08},
			"rules": {"flame_damage_multiplier": 1.15, "mist_echo_chance": 0.10, "hazard_damage": 2},
		},
		"elite": {
			"id": "c1_elite_wildfire_bank",
			"theme": "ember_mist",
			"aim_min": -0.88,
			"aim_max": 0.88,
			"peg_counts": {"normal": 36, "critical": 6, "flame": 14, "mist": 10, "hazard": 6},
			"physics": {"gravity": 1.04, "bounce": 0.86, "horizontal_noise": 0.10},
			"rules": {"flame_damage_multiplier": 1.25, "mist_echo_chance": 0.12, "hazard_damage": 3},
		},
		"boss_phase1": {
			"id": "c1_boss_p1_ashen_choir",
			"theme": "ember_mist",
			"aim_min": -0.84,
			"aim_max": 0.84,
			"peg_counts": {"normal": 32, "critical": 6, "flame": 16, "mist": 12, "hazard": 6},
			"physics": {"gravity": 1.06, "bounce": 0.88, "horizontal_noise": 0.11},
			"rules": {"flame_damage_multiplier": 1.30, "mist_echo_chance": 0.14, "hazard_damage": 3},
			"boss_rewrite": {"phase": 1, "rule": "flame_chain", "flame_chain_length": 2},
		},
		"boss_phase2": {
			"id": "c1_boss_p2_mist_inferno",
			"theme": "ember_mist",
			"aim_min": -0.76,
			"aim_max": 0.76,
			"peg_counts": {"normal": 26, "critical": 4, "flame": 18, "mist": 14, "hazard": 10},
			"physics": {"gravity": 1.10, "bounce": 0.92, "horizontal_noise": 0.14},
			"rules": {"flame_damage_multiplier": 1.40, "mist_echo_chance": 0.18, "hazard_damage": 4},
			"boss_rewrite": {"phase": 2, "rule": "mist_inferno", "flame_chain_length": 3, "mist_converts_hazard": true},
		},
	},
	2: {
		"normal": {
			"id": "c2_normal_mirror_foundry",
			"theme": "mirror_foundry",
			"aim_min": -0.90,
			"aim_max": 0.90,
			"peg_counts": {"normal": 42, "critical": 4, "mirror": 8, "bumper": 10, "resistance": 8},
			"physics": {"gravity": 0.96, "bounce": 0.96, "horizontal_noise": 0.06},
			"rules": {"mirror_copy_multiplier": 0.45, "bumper_impulse": 1.10, "resistance_damage_reduction": 0.20},
		},
		"elite": {
			"id": "c2_elite_refraction_engine",
			"theme": "mirror_foundry",
			"aim_min": -0.84,
			"aim_max": 0.84,
			"peg_counts": {"normal": 30, "critical": 4, "mirror": 12, "bumper": 12, "resistance": 10, "hazard": 4},
			"physics": {"gravity": 0.94, "bounce": 1.02, "horizontal_noise": 0.07},
			"rules": {"mirror_copy_multiplier": 0.55, "bumper_impulse": 1.20, "resistance_damage_reduction": 0.25},
		},
		"boss_phase1": {
			"id": "c2_boss_p1_prism_warden",
			"theme": "mirror_foundry",
			"aim_min": -0.80,
			"aim_max": 0.80,
			"peg_counts": {"normal": 26, "critical": 4, "mirror": 14, "bumper": 14, "resistance": 10, "hazard": 4},
			"physics": {"gravity": 0.92, "bounce": 1.06, "horizontal_noise": 0.08},
			"rules": {"mirror_copy_multiplier": 0.60, "bumper_impulse": 1.25, "resistance_damage_reduction": 0.30},
			"boss_rewrite": {"phase": 1, "rule": "mirror_tax", "first_mirror_is_resisted": true},
		},
		"boss_phase2": {
			"id": "c2_boss_p2_shattered_lens",
			"theme": "mirror_foundry",
			"aim_min": -0.72,
			"aim_max": 0.72,
			"peg_counts": {"normal": 20, "critical": 2, "mirror": 16, "bumper": 16, "resistance": 12, "hazard": 6},
			"physics": {"gravity": 0.90, "bounce": 1.12, "horizontal_noise": 0.10},
			"rules": {"mirror_copy_multiplier": 0.70, "bumper_impulse": 1.35, "resistance_damage_reduction": 0.35},
			"boss_rewrite": {"phase": 2, "rule": "shattered_reflection", "mirror_repeats": 2, "bumper_rotates_aim": true},
		},
	},
	3: {
		"normal": {
			"id": "c3_normal_void_vault",
			"theme": "void_vault",
			"aim_min": -0.86,
			"aim_max": 0.86,
			"peg_counts": {"normal": 40, "critical": 4, "resistance": 4, "lock": 8, "void": 8, "hazard": 8},
			"physics": {"gravity": 1.02, "bounce": 0.84, "horizontal_noise": 0.09},
			"rules": {"lock_hits_to_open": 2, "void_hit_loss": 1, "hazard_damage": 4},
		},
		"elite": {
			"id": "c3_elite_sealed_abyss",
			"theme": "void_vault",
			"aim_min": -0.80,
			"aim_max": 0.80,
			"peg_counts": {"normal": 30, "critical": 4, "resistance": 6, "lock": 12, "void": 10, "hazard": 10},
			"physics": {"gravity": 1.06, "bounce": 0.82, "horizontal_noise": 0.11},
			"rules": {"lock_hits_to_open": 3, "void_hit_loss": 1, "hazard_damage": 5},
		},
		"boss_phase1": {
			"id": "c3_boss_p1_chromatic_lock",
			"theme": "void_vault",
			"aim_min": -0.76,
			"aim_max": 0.76,
			"peg_counts": {"normal": 26, "critical": 2, "resistance": 6, "lock": 14, "void": 12, "hazard": 12},
			"physics": {"gravity": 1.08, "bounce": 0.80, "horizontal_noise": 0.12},
			"rules": {"lock_hits_to_open": 3, "void_hit_loss": 2, "hazard_damage": 5},
			"boss_rewrite": {"phase": 1, "rule": "chromatic_lock", "locks_require_matching_color": true},
		},
		"boss_phase2": {
			"id": "c3_boss_p2_event_horizon",
			"theme": "void_vault",
			"aim_min": -0.70,
			"aim_max": 0.70,
			"peg_counts": {"normal": 18, "critical": 2, "resistance": 8, "lock": 16, "void": 14, "hazard": 14},
			"physics": {"gravity": 1.12, "bounce": 0.78, "horizontal_noise": 0.14},
			"rules": {"lock_hits_to_open": 4, "void_hit_loss": 2, "hazard_damage": 6},
			"boss_rewrite": {"phase": 2, "rule": "event_horizon", "void_consumes_echo": true, "hazards_relock": true},
		},
	},
}


static func get_catalog() -> Dictionary:
	return PROFILE_CATALOG.duplicate(true)


static func get_intent_definitions() -> Dictionary:
	return INTENT_DEFINITIONS.duplicate(true)


static func compose_profile(
	chapter: int,
	encounter_type: String,
	boss_phase: int = 1,
	enemy_intent: Variant = {}
) -> Dictionary:
	var safe_chapter: int = clampi(chapter, 1, 3)
	var safe_encounter_type: String = _normalize_encounter_type(encounter_type)
	var safe_boss_phase: int = 0
	var profile_key: String = safe_encounter_type
	if safe_encounter_type == "boss":
		safe_boss_phase = 2 if boss_phase >= 2 else 1
		profile_key = "boss_phase%d" % safe_boss_phase

	var chapter_profiles: Dictionary = PROFILE_CATALOG[safe_chapter]
	var profile: Dictionary = chapter_profiles[profile_key].duplicate(true)
	profile["chapter"] = safe_chapter
	profile["encounter_type"] = safe_encounter_type
	profile["boss_phase"] = safe_boss_phase
	profile["profile_key"] = profile_key
	profile["aim"] = {
		"min": float(profile.get("aim_min", -0.8)),
		"max": float(profile.get("aim_max", 0.8)),
		"drift": 0.0,
	}
	profile.erase("aim_min")
	profile.erase("aim_max")
	profile["pegs"] = _build_pegs(profile)
	profile["board"] = _board_summary(profile["pegs"])

	var intent_state: Dictionary = _normalize_intent_input(enemy_intent)
	profile["enemy_intent"] = intent_state
	profile["intent_preview"] = get_intent_preview(intent_state)
	if is_intent_active(intent_state):
		_apply_active_intent(profile, intent_state)
	profile["peg_counts"] = _count_peg_types(profile["pegs"])
	profile["board"] = _board_summary(profile["pegs"])
	return profile


static func create_intent(intent_id: String, source_turn: int = 0, strength: int = 1) -> Dictionary:
	var normalized_id: String = intent_id.strip_edges().to_lower()
	if not INTENT_DEFINITIONS.has(normalized_id):
		return {}
	var definition: Dictionary = INTENT_DEFINITIONS[normalized_id]
	return {
		"id": normalized_id,
		"phase": INTENT_PHASE_TELEGRAPH,
		"source_turn": maxi(source_turn, 0),
		"strength": clampi(strength, 1, 3),
		"remaining_telegraph_turns": int(definition["telegraph_turns"]),
		"remaining_shots": int(definition["duration_shots"]),
		"clear_reason": "",
	}


static func get_intent_preview(intent_state: Dictionary) -> Dictionary:
	var intent_id: String = String(intent_state.get("id", ""))
	if not INTENT_DEFINITIONS.has(intent_id) or String(intent_state.get("phase", "")) == INTENT_PHASE_CLEARED:
		return {}
	var definition: Dictionary = INTENT_DEFINITIONS[intent_id]
	return {
		"id": intent_id,
		"phase": String(intent_state.get("phase", INTENT_PHASE_TELEGRAPH)),
		"telegraph_key": String(definition["telegraph_key"]),
		"will_apply_next_shot": true,
		"remaining_telegraph_turns": maxi(int(intent_state.get("remaining_telegraph_turns", 0)), 0),
		"remaining_shots": maxi(int(intent_state.get("remaining_shots", 0)), 0),
	}


static func advance_intent(intent_state: Dictionary, event: String) -> Dictionary:
	var state: Dictionary = intent_state.duplicate(true)
	var intent_id: String = String(state.get("id", ""))
	if not INTENT_DEFINITIONS.has(intent_id):
		return {}
	if String(state.get("phase", "")) == INTENT_PHASE_CLEARED:
		return state

	var normalized_event: String = event.strip_edges().to_lower()
	if normalized_event in ["enemy_defeated", "battle_end", "dispel", "clear"]:
		return clear_intent(state, normalized_event)
	if String(state.get("phase", "")) == INTENT_PHASE_TELEGRAPH and normalized_event in ["enemy_turn_end", "telegraph_tick"]:
		var telegraph_turns: int = maxi(int(state.get("remaining_telegraph_turns", 1)) - 1, 0)
		state["remaining_telegraph_turns"] = telegraph_turns
		if telegraph_turns == 0:
			state["phase"] = INTENT_PHASE_ACTIVE
		return state
	if String(state.get("phase", "")) == INTENT_PHASE_ACTIVE and normalized_event == "shot_resolved":
		var remaining_shots: int = maxi(int(state.get("remaining_shots", 1)) - 1, 0)
		state["remaining_shots"] = remaining_shots
		if remaining_shots == 0:
			return clear_intent(state, "duration_expired")
	return state


static func clear_intent(intent_state: Dictionary, reason: String = "manual") -> Dictionary:
	var state: Dictionary = intent_state.duplicate(true)
	if state.is_empty():
		return state
	state["phase"] = INTENT_PHASE_CLEARED
	state["remaining_telegraph_turns"] = 0
	state["remaining_shots"] = 0
	state["clear_reason"] = reason.strip_edges().to_lower()
	return state


static func is_intent_active(intent_state: Dictionary) -> bool:
	return (
		INTENT_DEFINITIONS.has(String(intent_state.get("id", "")))
		and String(intent_state.get("phase", "")) == INTENT_PHASE_ACTIVE
		and int(intent_state.get("remaining_shots", 0)) > 0
	)


static func get_edge_peg_ratio(profile: Dictionary) -> float:
	var board_value: Variant = profile.get("board", {})
	if board_value is Dictionary:
		var board: Dictionary = board_value
		var peg_count: int = int(board.get("peg_count", 0))
		if peg_count > 0:
			return float(board.get("edge_peg_count", 0)) / float(peg_count)
	var pegs_value: Variant = profile.get("pegs", [])
	if not pegs_value is Array or pegs_value.is_empty():
		return 0.0
	var edge_count: int = 0
	for peg_value in pegs_value:
		if peg_value is Dictionary and bool(peg_value.get("is_edge", false)):
			edge_count += 1
	return float(edge_count) / float(pegs_value.size())


static func is_aim_range_usable(profile: Dictionary) -> bool:
	var aim_value: Variant = profile.get("aim", {})
	if not aim_value is Dictionary:
		return false
	var aim: Dictionary = aim_value
	var aim_min: float = float(aim.get("min", 0.0))
	var aim_max: float = float(aim.get("max", 0.0))
	return (
		aim_min <= -MIN_AIM_SIDE_REACH
		and aim_max >= MIN_AIM_SIDE_REACH
		and aim_max - aim_min >= MIN_AIM_SPAN
	)


static func validate_profile(profile: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var profile_id: String = String(profile.get("id", "<unknown>"))
	var pegs_value: Variant = profile.get("pegs", [])
	if not pegs_value is Array or pegs_value.size() != BOARD_PEG_COUNT:
		errors.append("[PEG_COUNT] %s must contain exactly %d pegs." % [profile_id, BOARD_PEG_COUNT])
	if get_edge_peg_ratio(profile) > MAX_EDGE_PEG_RATIO + 0.00001:
		errors.append("[EDGE_RATIO] %s exceeds the %.2f edge peg ratio limit." % [profile_id, MAX_EDGE_PEG_RATIO])
	if not is_aim_range_usable(profile):
		errors.append("[AIM_RANGE] %s does not preserve a usable aim range." % profile_id)
	return errors


static func validate_catalog() -> Array[String]:
	var errors: Array[String] = []
	var required_types: Dictionary = {
		1: ["flame", "mist"],
		2: ["mirror", "bumper", "resistance"],
		3: ["lock", "void", "hazard"],
	}
	for chapter in range(1, 4):
		var chapter_profiles: Dictionary = PROFILE_CATALOG.get(chapter, {})
		for profile_key in PROFILE_KEYS:
			if not chapter_profiles.has(profile_key):
				errors.append("[MISSING_PROFILE] Chapter %d is missing %s." % [chapter, profile_key])
				continue
			var encounter_type: String = "boss" if profile_key.begins_with("boss_") else profile_key
			var boss_phase: int = 2 if profile_key == "boss_phase2" else 1
			var profile: Dictionary = compose_profile(chapter, encounter_type, boss_phase)
			for profile_error in validate_profile(profile):
				errors.append(profile_error)
			var counts: Dictionary = profile.get("peg_counts", {})
			for peg_type in required_types[chapter]:
				if int(counts.get(peg_type, 0)) <= 0:
					errors.append("[MISSING_MECHANIC] %s must include %s pegs." % [profile["id"], peg_type])
	return errors


static func _normalize_encounter_type(encounter_type: String) -> String:
	match encounter_type.strip_edges().to_lower():
		"elite":
			return "elite"
		"boss":
			return "boss"
		_:
			return "normal"


static func _normalize_intent_input(enemy_intent: Variant) -> Dictionary:
	if enemy_intent is String or enemy_intent is StringName:
		var direct_state: Dictionary = create_intent(String(enemy_intent))
		if not direct_state.is_empty():
			direct_state["phase"] = INTENT_PHASE_ACTIVE
			direct_state["remaining_telegraph_turns"] = 0
		return direct_state
	if not enemy_intent is Dictionary:
		return {}
	var state: Dictionary = enemy_intent.duplicate(true)
	var intent_id: String = String(state.get("id", "")).strip_edges().to_lower()
	if not INTENT_DEFINITIONS.has(intent_id):
		return {}
	state["id"] = intent_id
	state["strength"] = clampi(int(state.get("strength", 1)), 1, 3)
	state["remaining_telegraph_turns"] = maxi(int(state.get("remaining_telegraph_turns", 0)), 0)
	state["remaining_shots"] = maxi(int(state.get("remaining_shots", 1)), 0)
	var phase: String = String(state.get("phase", INTENT_PHASE_ACTIVE)).to_lower()
	if phase not in [INTENT_PHASE_TELEGRAPH, INTENT_PHASE_ACTIVE, INTENT_PHASE_CLEARED]:
		phase = INTENT_PHASE_ACTIVE
	state["phase"] = phase
	return state


static func _build_pegs(profile: Dictionary) -> Array[Dictionary]:
	var peg_pool: Array[String] = []
	var peg_counts: Dictionary = profile.get("peg_counts", {})
	for peg_type in PEG_TYPE_ORDER:
		for unused_index in range(maxi(int(peg_counts.get(peg_type, 0)), 0)):
			peg_pool.append(peg_type)
	while peg_pool.size() < BOARD_PEG_COUNT:
		peg_pool.append("normal")
	if peg_pool.size() > BOARD_PEG_COUNT:
		peg_pool.resize(BOARD_PEG_COUNT)

	var pegs: Array[Dictionary] = []
	var offset: int = _stable_hash(String(profile.get("id", "profile"))) % BOARD_PEG_COUNT
	for row in range(BOARD_ROWS):
		for column in range(BOARD_COLUMNS):
			var index: int = row * BOARD_COLUMNS + column
			var pool_index: int = posmod(index * 29 + offset, BOARD_PEG_COUNT)
			var stagger: float = 0.04 if row % 2 == 1 and column > 0 and column < BOARD_COLUMNS - 1 else 0.0
			var x: float = -0.92 + float(column) * (1.84 / float(BOARD_COLUMNS - 1)) + stagger
			var y: float = 0.18 + float(row) * (0.68 / float(BOARD_ROWS - 1))
			pegs.append({
				"id": "p_%02d_%02d" % [row, column],
				"column": column,
				"row": row,
				"x": x,
				"y": y,
				"type": peg_pool[pool_index],
				"is_edge": column == 0 or column == BOARD_COLUMNS - 1,
			})
	return pegs


static func _board_summary(pegs: Array) -> Dictionary:
	var edge_count: int = 0
	for peg_value in pegs:
		if peg_value is Dictionary and bool(peg_value.get("is_edge", false)):
			edge_count += 1
	return {
		"columns": BOARD_COLUMNS,
		"rows": BOARD_ROWS,
		"peg_count": pegs.size(),
		"edge_peg_count": edge_count,
		"edge_peg_ratio": float(edge_count) / float(maxi(pegs.size(), 1)),
	}


static func _apply_active_intent(profile: Dictionary, intent_state: Dictionary) -> void:
	var intent_id: String = String(intent_state["id"])
	var strength: int = clampi(int(intent_state.get("strength", 1)), 1, 3)
	var definition: Dictionary = INTENT_DEFINITIONS[intent_id]
	var effect: Dictionary = definition["effect"]
	var rules: Dictionary = profile.get("rules", {}).duplicate(true)
	var intent_effects: Dictionary = {"id": intent_id, "strength": strength}
	match intent_id:
		"seal":
			var seal_count: int = int(effect["sealed_pegs_per_strength"]) * strength
			var sealed_ids: Array[String] = _replace_peg_types(profile, "lock", seal_count, intent_id, ["normal", "echo", "critical"])
			rules["sealed_peg_ids"] = sealed_ids
			intent_effects["sealed_peg_ids"] = sealed_ids
		"aim_drift":
			var direction: int = int(intent_state.get("direction", 0))
			if direction == 0:
				direction = -1 if (_stable_hash(String(profile["id"])) + int(intent_state.get("source_turn", 0))) % 2 == 0 else 1
			var drift: float = clampf(float(effect["drift_per_strength"]) * float(strength) * float(signi(direction)), -0.36, 0.36)
			var aim: Dictionary = profile["aim"]
			aim["drift"] = drift
			rules["aim_drift"] = drift
			intent_effects["aim_drift"] = drift
		"crit_suppress":
			var crit_multiplier: float = pow(float(effect["crit_multiplier_per_strength"]), strength)
			rules["crit_chance_multiplier"] = crit_multiplier
			intent_effects["crit_chance_multiplier"] = crit_multiplier
		"add_hazard":
			var hazard_count: int = int(effect["hazard_pegs_per_strength"]) * strength
			var hazard_ids: Array[String] = _replace_peg_types(profile, "hazard", hazard_count, intent_id, ["normal", "echo", "critical"])
			rules["added_hazard_peg_ids"] = hazard_ids
			intent_effects["added_hazard_peg_ids"] = hazard_ids
	profile["rules"] = rules
	profile["intent_effects"] = intent_effects


static func _replace_peg_types(
	profile: Dictionary,
	replacement_type: String,
	requested_count: int,
	salt: String,
	allowed_types: Array[String]
) -> Array[String]:
	var pegs: Array = profile.get("pegs", [])
	var candidate_indices: Array[int] = []
	for index in range(pegs.size()):
		var peg_value: Variant = pegs[index]
		if not peg_value is Dictionary:
			continue
		var peg: Dictionary = peg_value
		if not bool(peg.get("is_edge", false)) and allowed_types.has(String(peg.get("type", "normal"))):
			candidate_indices.append(index)
	var replaced_ids: Array[String] = []
	if candidate_indices.is_empty():
		return replaced_ids
	var start: int = _stable_hash("%s:%s" % [profile.get("id", ""), salt]) % candidate_indices.size()
	for step in range(mini(maxi(requested_count, 0), candidate_indices.size())):
		var candidate_position: int = posmod(start + step, candidate_indices.size())
		var peg_index: int = candidate_indices[candidate_position]
		var peg: Dictionary = pegs[peg_index]
		peg["base_type"] = String(peg.get("type", "normal"))
		peg["type"] = replacement_type
		replaced_ids.append(String(peg["id"]))
	return replaced_ids


static func _count_peg_types(pegs: Array) -> Dictionary:
	var counts: Dictionary = {}
	for peg_value in pegs:
		if not peg_value is Dictionary:
			continue
		var peg_type: String = String(peg_value.get("type", "normal"))
		counts[peg_type] = int(counts.get(peg_type, 0)) + 1
	return counts


static func _stable_hash(value: String) -> int:
	var result: int = 17
	for byte_value in value.to_utf8_buffer():
		result = posmod(result * 131 + int(byte_value), 2_147_483_629)
	return result
