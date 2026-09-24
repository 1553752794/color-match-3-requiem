class_name StrategyRules
extends RefCounted

const POLICIES: Dictionary = {
	"red_accord": {
		"id": "red_accord",
		"name": "红焰协定",
		"summary": "红权重 +0.08 / 蓝 -0.04；战斗奖励 +6 金币。\n代价：敌人攻击与重击 +2。",
		"color": "red",
		"weight_bonus": {"red": 0.08},
		"weight_penalty": {"blue": -0.04},
		"reward_bonus": 6,
		"enemy_damage_bonus": 2,
	},
	"blue_charter": {
		"id": "blue_charter",
		"name": "蓝霜宪章",
		"summary": "蓝权重 +0.08 / 红 -0.04；每场开局护盾 +6。\n代价：战斗金币奖励 -10%。",
		"color": "blue",
		"weight_bonus": {"blue": 0.08},
		"weight_penalty": {"red": -0.04},
		"battle_shield": 6,
		"reward_multiplier": 0.9,
	},
	"golden_exchange": {
		"id": "golden_exchange",
		"name": "金辉商约",
		"summary": "战斗金币奖励 +20%；立即获得一次免费刷新。\n代价：所有商店价格 +10%。",
		"color": "gold",
		"reward_multiplier": 1.2,
		"free_refresh": 1,
		"shop_price_multiplier": 1.1,
	},
	"gray_covenant": {
		"id": "gray_covenant",
		"name": "灰蚀公约",
		"summary": "灰权重 -0.06 / 金 -0.02；每次灰蚀压力增量 -1。\n代价：战斗金币奖励 -10%。",
		"color": "gray",
		"weight_bonus": {"gray": -0.06},
		"weight_penalty": {"gold": -0.02},
		"gray_resist": 1,
		"reward_multiplier": 0.9,
	},
}

static func policy(policy_id: String) -> Dictionary:
	return POLICIES.get(policy_id, {}).duplicate(true)

static func ids() -> Array[String]:
	var result: Array[String] = []
	for value in POLICIES.keys():
		result.append(String(value))
	result.sort()
	return result

static func apply_weights(base: Dictionary, policy_id: String) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	var data: Dictionary = policy(policy_id)
	for color_value in data.get("weight_bonus", {}).keys():
		var color := String(color_value)
		result[color] = maxf(float(result.get(color, 0.0)) + float(data.weight_bonus[color_value]), 0.01)
	for color_value in data.get("weight_penalty", {}).keys():
		var penalty_color := String(color_value)
		result[penalty_color] = maxf(float(result.get(penalty_color, 0.0)) + float(data.weight_penalty[color_value]), 0.01)
	return result
