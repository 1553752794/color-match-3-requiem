extends RefCounted
class_name PegboardResolver

const MIN_HITS_PER_BALL: int = 7
const MAX_HITS_PER_BALL: int = 13
const MAX_BALLS: int = 8
const MAX_DAMAGE_VALUE: int = 1_000_000

const TIER_DEFAULTS: Dictionary = {
	"common": {"base_damage": 8, "damage_per_hit": 2},
	"rare": {"base_damage": 12, "damage_per_hit": 3},
	"epic": {"base_damage": 18, "damage_per_hit": 3},
}

const CHARACTER_EFFECTS: Dictionary = {
	"red": "center_momentum",
	"blue": "precision_crit",
	"gold": "bounty_pegs",
	"gray": "mist_pierce",
	"mixed": "prismatic_control",
}


func resolve(shot: Dictionary, aim: float, seed: int, chapter: int) -> Dictionary:
	var profile_value: Variant = shot.get("pegboard_profile", {})
	var profile: Dictionary = profile_value if profile_value is Dictionary else {}
	var aim_rules: Dictionary = profile.get("aim", {}) if not profile.is_empty() else {}
	var aim_min: float = clampf(float(aim_rules.get("min", -1.0)), -1.0, 1.0)
	var aim_max: float = clampf(float(aim_rules.get("max", 1.0)), aim_min, 1.0)
	var normalized_aim: float = clampf(aim + float(aim_rules.get("drift", 0.0)), aim_min, aim_max)
	var safe_chapter: int = clampi(chapter, 1, 99)
	var character_id: String = _normalized_character_id(String(shot.get("character_id", "")))
	var orb_type: String = String(shot.get("orb_type", "common")).to_lower()
	var tier: String = _resolve_tier(shot, orb_type)
	var tier_defaults: Dictionary = TIER_DEFAULTS[tier]
	var base_damage: int = clampi(
		_safe_int(shot.get("base_damage", tier_defaults["base_damage"]), int(tier_defaults["base_damage"])),
		0,
		MAX_DAMAGE_VALUE
	)
	var damage_per_hit: int = clampi(
		_safe_int(shot.get("damage_per_hit", tier_defaults["damage_per_hit"]), int(tier_defaults["damage_per_hit"])),
		0,
		MAX_DAMAGE_VALUE
	)
	var crit_multiplier: float = clampf(_safe_float(shot.get("crit_multiplier", 1.5), 1.5), 1.0, 10.0)
	var crit_chance: float = clampf(_safe_float(shot.get("crit_chance", 0.12), 0.12), 0.0, 1.0)
	var pierce: int = _positive_count(shot.get("pierce", 0), 4)
	var ball_count: int = _ball_count(shot.get("multiball", 1))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var balls: Array[Dictionary] = []
	var all_peg_types: Array[String] = []
	var total_hits: int = 0
	var total_crit_hits: int = 0
	var total_damage: int = 0
	var resonance_changes: Array[Dictionary] = []

	for ball_index in range(ball_count):
		var ball_aim: float = _ball_aim(normalized_aim, ball_index, ball_count, character_id)
		var ball: Dictionary = _resolve_ball(
			base_damage,
			damage_per_hit,
			crit_multiplier,
			crit_chance,
			pierce,
			ball_aim,
			safe_chapter,
			character_id,
			orb_type,
			ball_index,
			profile,
			shot,
			rng
		)
		balls.append(ball)
		total_hits += int(ball["hits"])
		total_crit_hits += int(ball["crit_hits"])
		total_damage += int(ball["damage"])
		for peg_type in ball["peg_types"]:
			all_peg_types.append(String(peg_type))
		for change_value in ball.get("resonance_changes", []):
			if change_value is Dictionary:
				var change: Dictionary = change_value.duplicate(true)
				change["ball_index"] = ball_index
				resonance_changes.append(change)

	var primary_path: Array = []
	if not balls.is_empty():
		primary_path = balls[0]["path"].duplicate()

	return {
		"hits": max(total_hits, 0),
		"crit_hits": max(total_crit_hits, 0),
		"damage": max(total_damage, 0),
		"path": primary_path,
		"peg_types": all_peg_types,
		"balls": balls,
		"aim": normalized_aim,
		"chapter": safe_chapter,
		"character_id": character_id,
		"character_effect": String(CHARACTER_EFFECTS.get(character_id, "standard")),
		"orb_type": orb_type,
		"profile_id": String(profile.get("id", "legacy_chapter_%d" % safe_chapter)),
		"profile_theme": String(profile.get("theme", "legacy")),
		"aim_range": Vector2(aim_min, aim_max),
		"resonance_changes": resonance_changes,
	}


func _resolve_ball(
	base_damage: int,
	damage_per_hit: int,
	crit_multiplier: float,
	crit_chance: float,
	pierce: int,
	aim: float,
	chapter: int,
	character_id: String,
	orb_type: String,
	ball_index: int,
	profile: Dictionary,
	shot: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var hits: int = _roll_hit_count(aim, chapter, character_id, pierce, profile, rng)
	var adjusted_crit_chance: float = _character_crit_chance(crit_chance, character_id)
	var peg_types: Array[String] = []
	var path: Array[Vector2] = [Vector2(aim * 0.82, 0.0)]
	var crit_hits: int = 0
	var bonus_hazard_hits: int = 0
	var max_bonus_hazard_hits: int = clampi(_safe_int(shot.get("max_bonus_hazard_hits", 0), 0), 0, 8)
	var x: float = path[0].x
	var path_stability: float = 0.58 if character_id == "blue" else 1.0

	for hit_index in range(hits):
		var peg_type: String = _roll_peg_type(
			hit_index,
			hits,
			adjusted_crit_chance,
			pierce,
			chapter,
			character_id,
			profile,
			shot,
			rng,
			bonus_hazard_hits < max_bonus_hazard_hits
		)
		if peg_type == "bonus_hazard":
			bonus_hazard_hits += 1
			peg_type = "hazard"
		peg_types.append(peg_type)
		if peg_type == "critical":
			crit_hits += 1
		var directed_drift: float = -aim * 0.035
		var random_drift: float = rng.randf_range(-0.24, 0.24) * path_stability
		x = clampf(x + directed_drift + random_drift, -1.0, 1.0)
		path.append(Vector2(x, float(hit_index + 1) / float(hits + 1)))

	path.append(Vector2(clampf(x + rng.randf_range(-0.08, 0.08), -1.0, 1.0), 1.0))
	var ball_resonance_changes: Array[Dictionary] = []
	if ball_index == 0:
		ball_resonance_changes = _apply_resonance_to_pegs(peg_types, shot.get("resonance", {}))
	crit_hits = peg_types.count("critical")
	var damage: int = _profile_damage(
		base_damage,
		damage_per_hit,
		crit_multiplier,
		peg_types,
		profile,
		shot
	)

	return {
		"index": ball_index,
		"aim": aim,
		"hits": hits,
		"crit_hits": crit_hits,
		"damage": damage,
		"path": path,
		"peg_types": peg_types,
		"orb_type": orb_type,
		"resonance_changes": ball_resonance_changes,
	}


func _apply_resonance_to_pegs(peg_types: Array[String], resonance_value: Variant) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	if not resonance_value is Dictionary:
		return changes
	var resonance_id: String = String(resonance_value.get("id", ""))
	match resonance_id:
		"unison":
			_replace_pegs(peg_types, ["normal", "resistance"], "echo", 2, changes)
		"violet":
			_replace_pegs(peg_types, ["normal", "echo"], "critical", 1, changes)
		"verdant":
			_replace_pegs(peg_types, ["hazard", "void", "lock", "resistance"], "normal", 2, changes)
			if changes.is_empty():
				_replace_pegs(peg_types, ["normal"], "frost", 1, changes)
		"amber":
			_replace_pegs(peg_types, ["normal"], "flame", 1, changes)
			_replace_pegs(peg_types, ["normal"], "gold", 1, changes)
		"daylight":
			_replace_pegs(peg_types, ["hazard", "void", "lock", "resistance"], "normal", 1, changes)
			_replace_pegs(peg_types, ["normal", "echo"], "critical", 1, changes)
		"decolor":
			_replace_pegs(peg_types, ["hazard", "void", "lock", "resistance", "normal"], "mist", 1, changes)
	return changes


func _replace_pegs(
	peg_types: Array[String],
	from_types: Array,
	to_type: String,
	max_changes: int,
	changes: Array[Dictionary]
) -> void:
	var replaced: int = 0
	for hit_index in range(peg_types.size()):
		if replaced >= max_changes:
			return
		if _change_has_index(changes, hit_index) or not from_types.has(peg_types[hit_index]):
			continue
		var from_type: String = peg_types[hit_index]
		peg_types[hit_index] = to_type
		changes.append({"hit_index": hit_index, "from_type": from_type, "to_type": to_type})
		replaced += 1


func _change_has_index(changes: Array[Dictionary], hit_index: int) -> bool:
	for change in changes:
		if int(change.get("hit_index", -1)) == hit_index:
			return true
	return false


func _roll_hit_count(
	aim: float,
	chapter: int,
	character_id: String,
	pierce: int,
	profile: Dictionary,
	rng: RandomNumberGenerator
) -> int:
	var edge_penalty: int = int(round(absf(aim) * 2.0))
	var center_bonus: int = 1 if absf(aim) <= 0.25 else 0
	var chapter_bonus: int = mini(int(floor(float(chapter - 1) / 2.0)), 2)
	var character_bonus: int = _character_hit_bonus(character_id, aim)
	var physics: Dictionary = profile.get("physics", {}) if not profile.is_empty() else {}
	var bounce_bonus: int = int(round((float(physics.get("bounce", 0.82)) - 0.82) * 4.0))
	var variance: int = rng.randi_range(-2, 2)
	return clampi(
		10 + center_bonus - edge_penalty + chapter_bonus + character_bonus + pierce + bounce_bonus + variance,
		MIN_HITS_PER_BALL,
		MAX_HITS_PER_BALL
	)


func _roll_peg_type(
	hit_index: int,
	hits: int,
	crit_chance: float,
	pierce: int,
	chapter: int,
	character_id: String,
	profile: Dictionary,
	shot: Dictionary,
	rng: RandomNumberGenerator,
	allow_bonus_hazard: bool
) -> String:
	if hit_index == 0:
		match character_id:
			"red":
				return "flame"
			"blue":
				return "frost"
			"gold":
				return "gold"
			"gray":
				return "mist"
			"mixed":
				return "prism"
	if character_id == "gold" and hit_index > 0 and hit_index % 4 == 0:
		return "gold"
	if character_id == "red" and hit_index == hits - 1:
		return "flame"
	if pierce > 0 and hit_index > 0 and hit_index % maxi(3, 6 - pierce) == 0:
		return "pierce"
	if not profile.is_empty():
		return _profile_peg_type(profile, shot, rng, allow_bonus_hazard)

	var roll: float = rng.randf()
	if roll < crit_chance:
		return "critical"
	var hazard_chance: float = minf(0.02 * float(chapter - 1), 0.12)
	if roll < crit_chance + hazard_chance:
		return "hazard"
	if roll < crit_chance + hazard_chance + 0.08:
		return "echo"
	return "normal"


func _profile_peg_type(profile: Dictionary, shot: Dictionary, rng: RandomNumberGenerator, allow_bonus_hazard: bool) -> String:
	var hazard_add: float = clampf(_safe_float(shot.get("hazard_chance_add", 0.0), 0.0), 0.0, 0.25)
	if allow_bonus_hazard and hazard_add > 0.0 and rng.randf() < hazard_add:
		return "bonus_hazard"
	var pegs_value: Variant = profile.get("pegs", [])
	if not pegs_value is Array or pegs_value.is_empty():
		return "normal"
	var peg_value: Variant = pegs_value[rng.randi_range(0, pegs_value.size() - 1)]
	if not peg_value is Dictionary:
		return "normal"
	var peg_type: String = String(peg_value.get("type", "normal"))
	if peg_type == "critical":
		var rules: Dictionary = profile.get("rules", {})
		var crit_multiplier: float = clampf(float(rules.get("crit_chance_multiplier", 1.0)), 0.0, 1.0)
		if rng.randf() > crit_multiplier:
			return "normal"
	return peg_type


func _profile_damage(
	base_damage: int,
	damage_per_hit: int,
	crit_multiplier: float,
	peg_types: Array[String],
	profile: Dictionary,
	shot: Dictionary
) -> int:
	if profile.is_empty():
		var crit_hits: int = peg_types.count("critical")
		return max(
			base_damage + (peg_types.size() - crit_hits) * damage_per_hit
			+ int(round(float(crit_hits * damage_per_hit) * crit_multiplier)),
			0
		)
	var rules: Dictionary = profile.get("rules", {})
	var damage: float = float(base_damage)
	var void_guard: int = clampi(_safe_int(shot.get("void_guard", 0), 0), 0, 32)
	var lock_pierce: int = clampi(_safe_int(shot.get("lock_pierce", 0), 0), 0, 32)
	for peg_type in peg_types:
		var hit_damage: float = float(damage_per_hit)
		match peg_type:
			"critical":
				hit_damage *= crit_multiplier
			"flame":
				hit_damage *= maxf(float(rules.get("flame_damage_multiplier", 1.0)), 0.0)
			"mirror":
				hit_damage *= 1.0 + maxf(float(rules.get("mirror_copy_multiplier", 0.0)), 0.0)
			"resistance":
				hit_damage *= 1.0 - clampf(float(rules.get("resistance_damage_reduction", 0.25)), 0.0, 0.9)
			"hazard":
				if shot.get("ignore_hazard", false) != true:
					hit_damage = -float(maxi(int(rules.get("hazard_damage", 3)), 0))
			"void":
				if shot.get("ignore_void", false) == true or void_guard > 0:
					void_guard = maxi(void_guard - 1, 0)
				else:
					hit_damage = -float(maxi(int(rules.get("void_hit_loss", 1)), 0) * damage_per_hit)
			"lock":
				if lock_pierce > 0:
					lock_pierce -= 1
				else:
					hit_damage = 0.0
		damage += hit_damage
	return clampi(int(round(damage)), 0, MAX_DAMAGE_VALUE)


func _ball_aim(base_aim: float, ball_index: int, ball_count: int, character_id: String) -> float:
	if ball_count <= 1:
		return base_aim
	var centered_index: float = float(ball_index) - float(ball_count - 1) * 0.5
	var spread: float = 0.16
	if character_id == "mixed":
		spread = 0.09
	return clampf(base_aim + centered_index * spread, -1.0, 1.0)


func _character_hit_bonus(character_id: String, aim: float) -> int:
	match character_id:
		"red":
			return 1 if absf(aim) <= 0.40 else 0
		"blue":
			return 1 if absf(aim) <= 0.18 else 0
		"gray":
			return 1
		_:
			return 0


func _character_crit_chance(base_chance: float, character_id: String) -> float:
	var bonus: float = 0.0
	match character_id:
		"blue":
			bonus = 0.12
		"mixed":
			bonus = 0.04
		_:
			bonus = 0.0
	return clampf(base_chance + bonus, 0.0, 1.0)


func _resolve_tier(shot: Dictionary, orb_type: String) -> String:
	var tier: String = String(shot.get("rarity", orb_type)).to_lower()
	if not TIER_DEFAULTS.has(tier):
		return "common"
	return tier


func _ball_count(value: Variant) -> int:
	if value is bool:
		return 2 if bool(value) else 1
	return clampi(_safe_int(value, 1), 1, MAX_BALLS)


func _positive_count(value: Variant, maximum: int) -> int:
	if value is bool:
		return 1 if bool(value) else 0
	return clampi(_safe_int(value, 0), 0, maximum)


func _safe_int(value: Variant, fallback: int) -> int:
	if value is int:
		return int(value)
	if value is float:
		var numeric_value: float = float(value)
		if not is_nan(numeric_value) and not is_inf(numeric_value):
			return int(numeric_value)
	return fallback


func _safe_float(value: Variant, fallback: float) -> float:
	if value is int or value is float:
		var numeric_value: float = float(value)
		if not is_nan(numeric_value) and not is_inf(numeric_value):
			return numeric_value
	return fallback


func _normalized_character_id(character_id: String) -> String:
	match character_id.to_lower():
		"jinge", "ember":
			return "red"
		"linjing", "frost":
			return "blue"
		"luoen", "merchant":
			return "gold"
		"misha", "mist":
			return "gray"
		"yilan", "prism":
			return "mixed"
		_:
			return character_id.to_lower()
