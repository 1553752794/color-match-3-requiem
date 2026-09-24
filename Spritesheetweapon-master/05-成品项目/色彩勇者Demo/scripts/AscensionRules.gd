class_name AscensionRules
extends RefCounted

const MIN_LEVEL: int = 0
const MAX_LEVEL: int = 10

const MAX_ENEMY_HEALTH_MULTIPLIER: float = 1.25
const MAX_ENEMY_DAMAGE_MULTIPLIER: float = 1.20
const MIN_HEALING_MULTIPLIER: float = 0.75
const MIN_GOLD_REWARD_MULTIPLIER: float = 0.75
const MAX_SHOP_PRICE_MULTIPLIER: float = 1.25
const MAX_GRAY_SPAWN_CHANCE_ADD: float = 0.12
const MAX_GRAY_CORRUPTION_MULTIPLIER: float = 1.50
const MAX_HAZARD_PEG_CHANCE_ADD: float = 0.12
const MAX_HAZARD_PEG_COUNT_ADD: int = 3
const MAX_ELITE_HEALTH_MULTIPLIER: float = 1.30
const MAX_ELITE_DAMAGE_MULTIPLIER: float = 1.20
const MAX_BOSS_HEALTH_MULTIPLIER: float = 1.35
const MAX_BOSS_DAMAGE_MULTIPLIER: float = 1.20
const MAX_STARTING_BURDEN_COUNT: int = 2
const MAX_STARTING_GOLD_PENALTY: int = 50

const MAX_EFFECTIVE_GRAY_SPAWN_CHANCE: float = 0.65
const MAX_EFFECTIVE_HAZARD_PEG_CHANCE: float = 0.35
const MAX_EFFECTIVE_HAZARD_PEG_COUNT: int = 6
const MAX_EFFECTIVE_ENEMY_HEALTH: int = 999_999
const MAX_EFFECTIVE_ENEMY_DAMAGE: int = 99_999
const MAX_EFFECTIVE_ELITE_HEALTH_MULTIPLIER: float = 1.35
const MAX_EFFECTIVE_ELITE_DAMAGE_MULTIPLIER: float = 1.25
const MAX_EFFECTIVE_BOSS_HEALTH_MULTIPLIER: float = 1.40
const MAX_EFFECTIVE_BOSS_DAMAGE_MULTIPLIER: float = 1.30

const BASE_RULES: Dictionary = {
	"enemy_health_multiplier": 1.0,
	"enemy_damage_multiplier": 1.0,
	"healing_multiplier": 1.0,
	"gold_reward_multiplier": 1.0,
	"shop_price_multiplier": 1.0,
	"gray_spawn_chance_add": 0.0,
	"gray_corruption_multiplier": 1.0,
	"hazard_peg_chance_add": 0.0,
	"hazard_peg_count_add": 0,
	"elite_health_multiplier": 1.0,
	"elite_damage_multiplier": 1.0,
	"boss_health_multiplier": 1.0,
	"boss_damage_multiplier": 1.0,
	"starting_burden_count_add": 0,
	"starting_gold_penalty": 0,
}

const LEVEL_RULES: Array[Dictionary] = [
	{
		"level": 0,
		"name": "A0 初登远征",
		"description": "标准规则，无额外进阶修正。",
		"modifiers": {},
	},
	{
		"level": 1,
		"name": "A1 坚韧敌阵",
		"description": "所有敌人最大生命提高 10%。",
		"modifiers": {"enemy_health_multiplier": 1.10},
	},
	{
		"level": 2,
		"name": "A2 锐利敌意",
		"description": "所有敌人伤害提高 10%。",
		"modifiers": {"enemy_damage_multiplier": 1.10},
	},
	{
		"level": 3,
		"name": "A3 枯竭补给",
		"description": "所有治疗效果降低 15%。",
		"modifiers": {"healing_multiplier": 0.85},
	},
	{
		"level": 4,
		"name": "A4 高价远征",
		"description": "金币收益降低 15%，商店价格提高 10%。",
		"modifiers": {
			"gold_reward_multiplier": 0.85,
			"shop_price_multiplier": 1.10,
		},
	},
	{
		"level": 5,
		"name": "A5 灰蚀涌动",
		"description": "灰色生成率增加 5 个百分点，灰蚀积累提高 20%。",
		"modifiers": {
			"gray_spawn_chance_add": 0.05,
			"gray_corruption_multiplier": 1.20,
		},
	},
	{
		"level": 6,
		"name": "A6 灰雾侵谱",
		"description": "侵谱意图会追加 1 格污染，下一次色谱更易受到压制。",
		"modifiers": {
			"hazard_peg_chance_add": 0.05,
			"hazard_peg_count_add": 1,
		},
	},
	{
		"level": 7,
		"name": "A7 精英蜕变",
		"description": "精英生命提高 15%、伤害提高 10%，侵谱压力小幅增加。",
		"modifiers": {
			"elite_health_multiplier": 1.15,
			"elite_damage_multiplier": 1.10,
			"hazard_peg_chance_add": 0.01,
		},
	},
	{
		"level": 8,
		"name": "A8 首领觉醒",
		"description": "Boss 生命提高 20%、伤害提高 15%，侵谱压力小幅增加。",
		"modifiers": {
			"boss_health_multiplier": 1.20,
			"boss_damage_multiplier": 1.15,
			"hazard_peg_chance_add": 0.01,
		},
	},
	{
		"level": 9,
		"name": "A9 沉重启程",
		"description": "开局携带 1 层负担，初始金币减少 25。",
		"modifiers": {
			"starting_burden_count_add": 1,
			"starting_gold_penalty": 25,
		},
	},
	{
		"level": 10,
		"name": "A10 终局共振",
		"description": "所有压力轴再次增强；累计修正受 A10 上限保护。",
		"modifiers": {
			"enemy_health_multiplier": 1.08,
			"enemy_damage_multiplier": 1.05,
			"healing_multiplier": 0.95,
			"gold_reward_multiplier": 0.95,
			"gray_spawn_chance_add": 0.03,
			"gray_corruption_multiplier": 1.10,
			"hazard_peg_chance_add": 0.03,
			"hazard_peg_count_add": 1,
			"elite_health_multiplier": 1.08,
			"elite_damage_multiplier": 1.05,
			"boss_health_multiplier": 1.08,
			"boss_damage_multiplier": 1.05,
			"starting_burden_count_add": 1,
			"starting_gold_penalty": 25,
		},
	},
]


static func clamp_level(level: int) -> int:
	return clampi(level, MIN_LEVEL, MAX_LEVEL)


static func get_level_rule(level: int) -> Dictionary:
	return LEVEL_RULES[clamp_level(level)].duplicate(true)


static func get_level_description(level: int) -> String:
	return String(LEVEL_RULES[clamp_level(level)].get("description", ""))


static func get_cumulative_rules(level: int) -> Dictionary:
	var safe_level: int = clamp_level(level)
	var cumulative: Dictionary = BASE_RULES.duplicate(true)
	for current_level in range(1, safe_level + 1):
		var level_modifiers: Dictionary = LEVEL_RULES[current_level].get("modifiers", {})
		_merge_modifiers(cumulative, level_modifiers)
	cumulative["level"] = safe_level
	return cumulative


static func apply_to_run_params(params: Dictionary, level: int) -> Dictionary:
	var result: Dictionary = params.duplicate(true)
	var rules: Dictionary = get_cumulative_rules(level)
	result["ascension_level"] = int(rules["level"])
	result["healing_multiplier"] = maxf(
		float(params.get("healing_multiplier", 1.0)) * float(rules["healing_multiplier"]),
		0.0
	)
	result["gold_reward_multiplier"] = maxf(
		float(params.get("gold_reward_multiplier", 1.0)) * float(rules["gold_reward_multiplier"]),
		0.0
	)
	result["shop_price_multiplier"] = maxf(
		float(params.get("shop_price_multiplier", 1.0)) * float(rules["shop_price_multiplier"]),
		0.0
	)
	_apply_board_pressure(result, params, rules)
	return result


static func apply_to_battle_params(params: Dictionary, level: int) -> Dictionary:
	var result: Dictionary = params.duplicate(true)
	var rules: Dictionary = get_cumulative_rules(level)
	var encounter_type: String = String(params.get("encounter_type", "normal")).to_lower()
	var health_multiplier: float = float(rules["enemy_health_multiplier"])
	var damage_multiplier: float = float(rules["enemy_damage_multiplier"])
	if encounter_type == "elite":
		health_multiplier = minf(
			health_multiplier * float(rules["elite_health_multiplier"]),
			MAX_EFFECTIVE_ELITE_HEALTH_MULTIPLIER
		)
		damage_multiplier = minf(
			damage_multiplier * float(rules["elite_damage_multiplier"]),
			MAX_EFFECTIVE_ELITE_DAMAGE_MULTIPLIER
		)
	elif encounter_type == "boss":
		health_multiplier = minf(
			health_multiplier * float(rules["boss_health_multiplier"]),
			MAX_EFFECTIVE_BOSS_HEALTH_MULTIPLIER
		)
		damage_multiplier = minf(
			damage_multiplier * float(rules["boss_damage_multiplier"]),
			MAX_EFFECTIVE_BOSS_DAMAGE_MULTIPLIER
		)

	result["ascension_level"] = int(rules["level"])
	result["enemy_health_multiplier"] = health_multiplier
	result["enemy_damage_multiplier"] = damage_multiplier
	var base_max_health: int = maxi(int(params.get("enemy_max_health", 0)), 0)
	var base_health: int = maxi(int(params.get("enemy_health", base_max_health)), 0)
	var base_damage: int = maxi(int(params.get("enemy_damage", 0)), 0)
	result["enemy_max_health"] = _scale_int(base_max_health, health_multiplier, MAX_EFFECTIVE_ENEMY_HEALTH)
	result["enemy_health"] = _scale_int(base_health, health_multiplier, MAX_EFFECTIVE_ENEMY_HEALTH)
	result["enemy_damage"] = _scale_int(base_damage, damage_multiplier, MAX_EFFECTIVE_ENEMY_DAMAGE)
	_apply_board_pressure(result, params, rules)
	return result


static func apply_to_profile_params(params: Dictionary, level: int) -> Dictionary:
	var result: Dictionary = params.duplicate(true)
	var rules: Dictionary = get_cumulative_rules(level)
	var base_gold: int = maxi(int(params.get("starting_gold", 0)), 0)
	var base_burdens: int = maxi(int(params.get("starting_burden_count", 0)), 0)
	result["ascension_level"] = int(rules["level"])
	result["starting_gold"] = maxi(base_gold - int(rules["starting_gold_penalty"]), 0)
	result["starting_burden_count"] = mini(
		base_burdens + int(rules["starting_burden_count_add"]),
		MAX_STARTING_BURDEN_COUNT
	)
	return result


static func _merge_modifiers(cumulative: Dictionary, modifiers: Dictionary) -> void:
	for key_value in modifiers.keys():
		var key: String = String(key_value)
		var modifier: Variant = modifiers[key_value]
		match key:
			"enemy_health_multiplier":
				cumulative[key] = minf(float(cumulative[key]) * float(modifier), MAX_ENEMY_HEALTH_MULTIPLIER)
			"enemy_damage_multiplier":
				cumulative[key] = minf(float(cumulative[key]) * float(modifier), MAX_ENEMY_DAMAGE_MULTIPLIER)
			"healing_multiplier":
				cumulative[key] = maxf(float(cumulative[key]) * float(modifier), MIN_HEALING_MULTIPLIER)
			"gold_reward_multiplier":
				cumulative[key] = maxf(float(cumulative[key]) * float(modifier), MIN_GOLD_REWARD_MULTIPLIER)
			"shop_price_multiplier":
				cumulative[key] = minf(float(cumulative[key]) * float(modifier), MAX_SHOP_PRICE_MULTIPLIER)
			"gray_spawn_chance_add":
				cumulative[key] = minf(float(cumulative[key]) + float(modifier), MAX_GRAY_SPAWN_CHANCE_ADD)
			"gray_corruption_multiplier":
				cumulative[key] = minf(float(cumulative[key]) * float(modifier), MAX_GRAY_CORRUPTION_MULTIPLIER)
			"hazard_peg_chance_add":
				cumulative[key] = minf(float(cumulative[key]) + float(modifier), MAX_HAZARD_PEG_CHANCE_ADD)
			"hazard_peg_count_add":
				cumulative[key] = mini(int(cumulative[key]) + int(modifier), MAX_HAZARD_PEG_COUNT_ADD)
			"elite_health_multiplier":
				cumulative[key] = minf(float(cumulative[key]) * float(modifier), MAX_ELITE_HEALTH_MULTIPLIER)
			"elite_damage_multiplier":
				cumulative[key] = minf(float(cumulative[key]) * float(modifier), MAX_ELITE_DAMAGE_MULTIPLIER)
			"boss_health_multiplier":
				cumulative[key] = minf(float(cumulative[key]) * float(modifier), MAX_BOSS_HEALTH_MULTIPLIER)
			"boss_damage_multiplier":
				cumulative[key] = minf(float(cumulative[key]) * float(modifier), MAX_BOSS_DAMAGE_MULTIPLIER)
			"starting_burden_count_add":
				cumulative[key] = mini(int(cumulative[key]) + int(modifier), MAX_STARTING_BURDEN_COUNT)
			"starting_gold_penalty":
				cumulative[key] = mini(int(cumulative[key]) + int(modifier), MAX_STARTING_GOLD_PENALTY)


static func _apply_board_pressure(result: Dictionary, params: Dictionary, rules: Dictionary) -> void:
	result["gray_spawn_chance"] = clampf(
		float(params.get("gray_spawn_chance", 0.43)) + float(rules["gray_spawn_chance_add"]),
		0.0,
		MAX_EFFECTIVE_GRAY_SPAWN_CHANCE
	)
	result["gray_corruption_multiplier"] = clampf(
		float(params.get("gray_corruption_multiplier", 1.0)) * float(rules["gray_corruption_multiplier"]),
		0.0,
		MAX_GRAY_CORRUPTION_MULTIPLIER
	)
	result["hazard_peg_chance"] = clampf(
		float(params.get("hazard_peg_chance", 0.0)) + float(rules["hazard_peg_chance_add"]),
		0.0,
		MAX_EFFECTIVE_HAZARD_PEG_CHANCE
	)
	result["max_hazard_pegs"] = clampi(
		int(params.get("max_hazard_pegs", 0)) + int(rules["hazard_peg_count_add"]),
		0,
		MAX_EFFECTIVE_HAZARD_PEG_COUNT
	)


static func _scale_int(value: int, multiplier: float, maximum: int) -> int:
	if value <= 0:
		return 0
	return clampi(int(round(float(value) * multiplier)), 1, maximum)
