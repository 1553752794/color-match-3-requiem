extends RefCounted
class_name SpectrumResolution

const RARITY_PULSE_DAMAGE: Dictionary = {
	"common": 8,
	"rare": 13,
	"epic": 20,
	"curse": 0,
}


static func base_damage_for_rarity(rarity: String) -> int:
	return int(RARITY_PULSE_DAMAGE.get(rarity, RARITY_PULSE_DAMAGE["common"]))


static func resolve(
	card: Dictionary,
	character_profile: Dictionary = {},
	modifier: Dictionary = {},
	tuning: Dictionary = {},
	memory: Dictionary = {}
) -> Dictionary:
	var rarity: String = String(card.get("rarity", "common"))
	var color_key: String = String(card.get("color", "neutral"))
	var base_damage: int = base_damage_for_rarity(rarity)
	base_damage += max(int(character_profile.get("pulse_damage_bonus", 0)), 0)
	base_damage += max(int(character_profile.get("per_hit_bonus", 0)), 0) * 3
	base_damage += max(int(memory.get("base_damage", 0)), 0)
	base_damage += max(int(tuning.get("critical", 0)), 0) * 2

	var flat_damage: int = max(int(modifier.get("flat_damage", 0)), 0)
	flat_damage += max(int(modifier.get("per_hit_bonus", 0)), 0) * 3
	flat_damage += max(int(modifier.get("echo_damage", 0)), 0)
	flat_damage += max(int(modifier.get("hazard_damage", 0)), 0)

	var repeat_count: int = clampi(maxi(
		int(character_profile.get("repeat_count", character_profile.get("multiball", 1))),
		int(modifier.get("repeat_count", modifier.get("multiball", 1)))
	),
		1,
		4
	)
	var repeat_ratio: float = clampf(
		float(modifier.get("repeat_ratio", modifier.get("ball_damage_ratio", character_profile.get("repeat_ratio", character_profile.get("ball_damage_ratio", 0.55))))),
		0.25,
		1.0
	)
	var repeat_damage: int = int(round(float(base_damage) * float(repeat_count - 1) * repeat_ratio))
	var amplification: float = clampf(
		float(memory.get("amplification", 0.0)) + float(modifier.get("damage_ratio_bonus", 0.0)),
		0.0,
		0.35
	)
	var total_damage: int = int(round(float(base_damage + flat_damage + repeat_damage) * (1.0 + amplification)))

	var armor_break: int = max(int(character_profile.get("armor_break", 0)), 0)
	armor_break += max(int(character_profile.get("pierce", 0)), 0)
	armor_break += max(int(memory.get("armor_break", 0)), 0)
	armor_break += max(int(modifier.get("armor_break", 0)), 0)
	armor_break += max(int(modifier.get("pierce_bonus", 0)), 0)
	armor_break += max(int(modifier.get("lock_pierce", 0)), 0)
	armor_break += max(int(modifier.get("armor_break_hits", 0)), 0)
	armor_break += max(int(tuning.get("pierce", 0)), 0)

	var bonus_coins: int = max(int(character_profile.get("completion_coins", 0)), 0)
	bonus_coins += max(int(character_profile.get("gold_pegs", 0)), 0) * max(int(character_profile.get("coins_per_gold_peg", 1)), 1)
	bonus_coins += max(int(modifier.get("bonus_coins", modifier.get("bonus_gold_pegs", 0))), 0)
	if color_key == "gold":
		bonus_coins += max(int(tuning.get("bounty", 0)), 0)

	var cleanse: int = max(int(character_profile.get("cleanse_on_completion", 0)), 0)
	cleanse += max(int(character_profile.get("cleanse_on_shot", 0)), 0)
	cleanse += max(int(modifier.get("cleanse", 0)), 0)
	if modifier.get("ignore_hazard", false) == true:
		cleanse += 1
	if modifier.get("ignore_void", false) == true:
		cleanse += 1

	return {
		"damage": max(total_damage, 0),
		"color": color_key,
		"ignore_armor": armor_break > 0,
		"armor_break": armor_break,
		"shield": max(int(character_profile.get("completion_shield", character_profile.get("shield_per_hits", 0))), 0) + max(int(modifier.get("shield", 0)), 0),
		"coins": bonus_coins,
		"cleanse": mini(cleanse, 4),
		"burn": max(int(character_profile.get("completion_burn", character_profile.get("high_hit_burn", 0))), 0) + max(int(modifier.get("burn", modifier.get("high_hit_burn", 0))), 0),
		"freeze": max(int(modifier.get("freeze", 0)), 0),
		"repeat_count": repeat_count,
		"repeat_ratio": repeat_ratio,
	}
