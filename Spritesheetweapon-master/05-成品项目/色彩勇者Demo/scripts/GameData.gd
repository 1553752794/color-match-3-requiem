extends RefCounted
class_name GameData

const COLOR_ORDER: Array[String] = ["gray", "red", "blue", "gold"]
const PLAYER_COLORS: Array[String] = ["red", "blue", "gold"]

const COLOR_NAMES: Dictionary = {
	"gray": "灰",
	"red": "红",
	"blue": "蓝",
	"gold": "金",
	"neutral": "中立",
	"mixed": "混色",
	"green": "绿",
	"purple": "紫",
	"white": "白",
	"black": "黑",
}

const COLOR_FULL_NAMES: Dictionary = {
	"gray": "灰蚀",
	"red": "红焰",
	"blue": "蓝霜",
	"gold": "金辉",
	"neutral": "中立",
	"mixed": "混色",
	"green": "翠生",
	"purple": "紫弦",
	"white": "白昼",
	"black": "黑曜",
}

const COLOR_TINTS: Dictionary = {
	"gray": Color(0.55, 0.55, 0.58),
	"red": Color(0.95, 0.28, 0.20),
	"blue": Color(0.36, 0.62, 1.0),
	"gold": Color(0.98, 0.76, 0.22),
	"neutral": Color(0.78, 0.76, 0.68),
	"mixed": Color(0.70, 0.46, 0.92),
	"green": Color(0.26, 0.72, 0.48),
	"purple": Color(0.66, 0.38, 0.84),
	"white": Color(0.92, 0.94, 0.90),
	"black": Color(0.34, 0.29, 0.42),
}

const BASE_WEIGHTS: Dictionary = {
	"gray": 0.43,
	"red": 0.19,
	"blue": 0.19,
	"gold": 0.19,
}

const SPECTRA: Dictionary = {
	"ember_slash": {
		"id": "ember_slash",
		"name": "余烬斩",
		"color": "red",
		"rarity": "common",
		"condition": "本回合累计红 >=5",
		"effect": "18 伤害，燃烧 2 层。",
		"short": "红 >=5",
		"threshold": 5,
		"damage": 18,
		"burn_turns": 2,
		"burn_stacks": 2,
		"pools": ["common", "red", "starter"],
		"upgrade": {
			"condition": "本回合累计红 >=4",
			"effect": "24 伤害，燃烧 2 层。",
			"short": "红 >=4",
			"threshold": 4,
			"damage": 24,
		},
	},
	"wildfire": {
		"id": "wildfire",
		"name": "燎原",
		"color": "red",
		"rarity": "common",
		"condition": "一次红色 4 连+",
		"effect": "随机 2 个灰块染红。",
		"short": "红 4 连",
		"match_size": 4,
		"dye_count": 2,
		"pools": ["common", "red"],
		"upgrade": {
			"effect": "随机 3 个灰块染红。",
			"dye_count": 3,
		},
	},
	"crimson_echo": {
		"id": "crimson_echo",
		"name": "赤潮回响",
		"color": "red",
		"rarity": "rare",
		"condition": "本回合触发 2 次红色消除",
		"effect": "追加 40% 本步基础伤害。",
		"short": "2 次红消",
		"event_count": 2,
		"damage_ratio": 0.4,
		"pools": ["rare", "red", "elite"],
		"upgrade": {
			"effect": "追加 60% 本步基础伤害。",
			"damage_ratio": 0.6,
		},
	},
	"fireline_dash": {
		"id": "fireline_dash",
		"name": "火线突进",
		"color": "red",
		"rarity": "common",
		"condition": "红色消除后仍剩余至少 1 步",
		"effect": "造成 12 伤害，下一张红色色谱条件 -1。",
		"short": "消红后剩 1 步",
		"remaining_moves_min": 1,
		"damage": 12,
		"next_red_threshold_reduction": 1,
		"pools": ["common", "red"],
		"upgrade": {
			"effect": "造成 16 伤害，下一张红色色谱条件 -1。",
			"damage": 16,
		},
	},
	"warm_guard": {
		"id": "warm_guard",
		"name": "余温护身",
		"color": "red",
		"rarity": "common",
		"condition": "敌人处于燃烧状态时消除红色",
		"effect": "获得 8 护盾。",
		"short": "敌燃烧 + 消红",
		"enemy_burn_min": 1,
		"shield": 8,
		"pools": ["common", "red"],
		"upgrade": {
			"effect": "获得 10 护盾。",
			"shield": 10,
		},
	},
	"molten_finish": {
		"id": "molten_finish",
		"name": "熔核终止",
		"color": "red",
		"rarity": "rare",
		"condition": "本回合完成 2 张红色色谱",
		"effect": "造成 35 伤害，敌人燃烧层数翻倍，最多 12 层。",
		"short": "完成 2 张红谱",
		"completed_red_cards": 2,
		"damage": 35,
		"burn_multiplier": 2.0,
		"burn_cap": 12,
		"pools": ["rare", "red", "elite"],
		"upgrade": {
			"effect": "造成 46 伤害，敌人燃烧层数翻倍，最多 12 层。",
			"damage": 46,
		},
	},
	"blood_pact": {
		"id": "blood_pact",
		"name": "血色契约",
		"color": "red",
		"rarity": "rare",
		"condition": "HP 低于 50% 时消除红色",
		"effect": "失去 3 HP，造成 30 伤害。",
		"short": "半血以下 + 消红",
		"hp_ratio_below": 0.5,
		"hp_cost": 3,
		"damage": 30,
		"pools": ["rare", "red", "elite"],
		"upgrade": {
			"effect": "失去 3 HP，造成 39 伤害。",
			"damage": 39,
		},
	},
	"flame_crown": {
		"id": "flame_crown",
		"name": "炎冠审判",
		"color": "red",
		"rarity": "epic",
		"condition": "完成红色 5 连或触发 3 级联",
		"effect": "造成 60 伤害，敌人下回合红色抗性 +25%。",
		"short": "红 5 连 / 3 级联",
		"match_size": 5,
		"cascade": 3,
		"damage": 60,
		"enemy_red_resistance": 0.25,
		"resistance_turns": 1,
		"pools": ["epic", "red", "elite"],
		"upgrade": {
			"effect": "造成 78 伤害，敌人下回合红色抗性 +25%。",
			"damage": 78,
		},
	},
	"frost_guard": {
		"id": "frost_guard",
		"name": "凝霜格",
		"color": "blue",
		"rarity": "common",
		"condition": "一次蓝色 4 连，或两次蓝色消除",
		"effect": "获得 14 护盾。",
		"short": "蓝 4 连 / 2 次蓝",
		"match_size": 4,
		"event_count": 2,
		"shield": 14,
		"pools": ["common", "blue", "starter"],
		"upgrade": {
			"effect": "获得 18 护盾。",
			"shield": 18,
		},
	},
	"ice_rest": {
		"id": "ice_rest",
		"name": "冰封休止",
		"color": "blue",
		"rarity": "rare",
		"condition": "先消蓝，再消任意非蓝色",
		"effect": "若敌人蓄力则打断，否则高概率冻结。",
		"short": "蓝 -> 非蓝",
		"freeze_chance": 0.65,
		"pools": ["rare", "blue", "elite"],
		"upgrade": {
			"effect": "若敌人蓄力则打断，否则必定冻结。",
			"freeze_chance": 1.0,
		},
	},
	"mirror_dodge": {
		"id": "mirror_dodge",
		"name": "镜湖回避",
		"color": "blue",
		"rarity": "common",
		"condition": "本回合未受伤且消除蓝色",
		"effect": "下一次受到的伤害减少 10。",
		"short": "未受伤 + 消蓝",
		"damage_reduction": 10,
		"effect_charges": 1,
		"pools": ["common", "blue"],
		"upgrade": {
			"effect": "下一次受到的伤害减少 13。",
			"damage_reduction": 13,
		},
	},
	"frostline_plan": {
		"id": "frostline_plan",
		"name": "霜线规划",
		"color": "blue",
		"rarity": "common",
		"condition": "主动蓝色消除后触发级联",
		"effect": "抽 1 张色谱；若本回合未完成，则保留槽 +1。",
		"short": "主动蓝消后级联",
		"cascade": 2,
		"draw_count": 1,
		"retain_bonus": 1,
		"pools": ["common", "blue"],
		"upgrade": {
			"condition": "主动蓝色消除完成后触发",
			"short": "主动蓝消",
			"cascade": 1,
		},
	},
	"cold_wall": {
		"id": "cold_wall",
		"name": "冷光护墙",
		"color": "blue",
		"rarity": "common",
		"condition": "本回合累计蓝色 >=6",
		"effect": "获得 20 护盾。",
		"short": "蓝 >=6",
		"threshold": 6,
		"shield": 20,
		"pools": ["common", "blue"],
		"upgrade": {
			"effect": "获得 26 护盾。",
			"shield": 26,
		},
	},
	"stasis_seal": {
		"id": "stasis_seal",
		"name": "静滞封印",
		"color": "blue",
		"rarity": "rare",
		"condition": "敌人为攻击意图时消除蓝色",
		"effect": "冻结敌人 1 回合并获得 8 护盾。",
		"short": "攻击意图 + 消蓝",
		"freeze_turns": 1,
		"shield": 8,
		"pools": ["rare", "blue", "elite"],
		"upgrade": {
			"effect": "冻结敌人 1 回合并获得 10 护盾。",
			"shield": 10,
		},
	},
	"prism_ice": {
		"id": "prism_ice",
		"name": "反射棱冰",
		"color": "blue",
		"rarity": "rare",
		"condition": "拥有护盾时完成任意色谱",
		"effect": "对敌人造成当前护盾 60% 的伤害。",
		"short": "有盾 + 完成色谱",
		"shield_damage_ratio": 0.6,
		"pools": ["rare", "blue", "elite"],
		"upgrade": {
			"effect": "对敌人造成当前护盾 80% 的伤害。",
			"shield_damage_ratio": 0.8,
		},
	},
	"zero_finale": {
		"id": "zero_finale",
		"name": "零度终幕",
		"color": "blue",
		"rarity": "epic",
		"condition": "连续 2 回合完成蓝色色谱",
		"effect": "敌人跳过下一次非 Boss 行动。",
		"short": "连续 2 回合蓝谱",
		"consecutive_turns": 2,
		"skip_actions": 1,
		"boss_immune": true,
		"pools": ["epic", "blue", "elite"],
		"upgrade": {
			"condition": "本回合完成蓝色色谱",
			"short": "完成蓝谱",
			"consecutive_turns": 1,
		},
	},
	"golden_beat": {
		"id": "golden_beat",
		"name": "点金拍",
		"color": "gold",
		"rarity": "common",
		"condition": "消除金 >=3，且已完成任一色谱",
		"effect": "+8 金币，本回合金色收益 +50%。",
		"short": "金 >=3 + 已触发",
		"gold_count": 3,
		"coins": 8,
		"gold_multiplier": 1.5,
		"pools": ["common", "gold", "starter"],
		"upgrade": {
			"effect": "+12 金币，本回合金色收益 +50%。",
			"coins": 12,
		},
	},
	"bond_refraction": {
		"id": "bond_refraction",
		"name": "债券折光",
		"color": "gold",
		"rarity": "rare",
		"condition": "本回合未受伤且消除金色",
		"effect": "下一次商店升级费用 -20%。",
		"short": "未受伤 + 金",
		"discount": 0.2,
		"pools": ["rare", "gold", "elite"],
		"upgrade": {
			"effect": "下一次商店升级费用 -35%。",
			"discount": 0.35,
		},
	},
	"caravan_beat": {
		"id": "caravan_beat",
		"name": "商队节拍",
		"color": "gold",
		"rarity": "common",
		"condition": "主动完成金色 4 连+",
		"effect": "获得 12 金币。",
		"short": "主动金 4 连",
		"match_size": 4,
		"coins": 12,
		"pools": ["common", "gold"],
		"upgrade": {
			"effect": "获得 15 金币。",
			"coins": 15,
		},
	},
	"remainder_echo": {
		"id": "remainder_echo",
		"name": "余款回响",
		"color": "gold",
		"rarity": "common",
		"condition": "跳过 1 张奖励后，在下一场战斗消除金色",
		"effect": "获得 1 颜料与 6 金币。",
		"short": "跳过奖励后消金",
		"skipped_rewards": 1,
		"pigment": 1,
		"coins": 6,
		"pools": ["common", "gold"],
		"upgrade": {
			"effect": "获得 1 颜料与 8 金币。",
			"coins": 8,
		},
	},
	"gilded_charm": {
		"id": "gilded_charm",
		"name": "镀金护符",
		"color": "gold",
		"rarity": "common",
		"condition": "本回合累计金色 >=5",
		"effect": "获得等同于本场战斗金币收益的护盾，最多 16。",
		"short": "金 >=5",
		"threshold": 5,
		"shield_per_coin": 1,
		"shield_cap": 16,
		"pools": ["common", "gold"],
		"upgrade": {
			"effect": "获得等同于本场战斗金币收益的护盾，最多 21。",
			"shield_cap": 21,
		},
	},
	"arbitrage_concerto": {
		"id": "arbitrage_concerto",
		"name": "套利连奏",
		"color": "gold",
		"rarity": "rare",
		"condition": "同回合完成金色色谱与非金色色谱",
		"effect": "抽 1 张色谱，下一次商店刷新免费。",
		"short": "金谱 + 非金谱",
		"gold_cards_completed": 1,
		"non_gold_cards_completed": 1,
		"draw_count": 1,
		"free_shop_refreshes": 1,
		"pools": ["rare", "gold", "elite"],
		"upgrade": {
			"effect": "抽 1 张色谱，下一次商店刷新免费，并获得 6 金币。",
			"coins": 6,
		},
	},
	"royal_coin": {
		"id": "royal_coin",
		"name": "王币指令",
		"color": "gold",
		"rarity": "rare",
		"condition": "持有金币 >=80 时消除金色",
		"effect": "消耗 20 金币，造成 45 伤害。",
		"short": "金币 >=80 + 消金",
		"coin_threshold": 80,
		"coin_cost": 20,
		"damage": 45,
		"pools": ["rare", "gold", "elite"],
		"upgrade": {
			"effect": "消耗 20 金币，造成 58 伤害。",
			"damage": 58,
		},
	},
	"golden_finale": {
		"id": "golden_finale",
		"name": "黄金终章",
		"color": "gold",
		"rarity": "epic",
		"condition": "本场战斗获得金币 >=24",
		"effect": "获得 25% 遗物购买折扣，本回合金币收益不受软上限限制。",
		"short": "本场金币 >=24",
		"battle_coins": 24,
		"relic_discount": 0.25,
		"remove_gold_cap_turns": 1,
		"pools": ["epic", "gold", "elite"],
		"upgrade": {
			"condition": "本场战斗获得金币 >=23",
			"short": "本场金币 >=23",
			"battle_coins": 23,
		},
	},
	"palette_drill": {
		"id": "palette_drill",
		"name": "调色练习",
		"color": "neutral",
		"rarity": "common",
		"condition": "同回合消除 2 种颜色",
		"effect": "+1 颜料（每场最多 1）；若三色则净化 1 灰蚀。",
		"short": "2 色",
		"unique_colors": 2,
		"pigment": 1,
		"pigment_battle_cap": 1,
		"cleanse_colors": 3,
		"cleanse_count": 1,
		"pools": ["common", "neutral", "starter", "mixed"],
		"upgrade": {
			"effect": "+2 颜料（每场最多 2）；若三色则净化 2 灰蚀。",
			"pigment": 2,
			"pigment_battle_cap": 2,
			"cleanse_count": 2,
		},
	},
	"tone_phrase": {
		"id": "tone_phrase",
		"name": "镇魂短句",
		"color": "neutral",
		"rarity": "common",
		"condition": "触发 2 层以上级联",
		"effect": "12 伤害，并抽 1 张色谱。",
		"short": "2 层级联",
		"cascade": 2,
		"damage": 12,
		"draw_count": 1,
		"pools": ["common", "neutral", "starter"],
		"upgrade": {
			"effect": "18 伤害，并抽 1 张色谱。",
			"damage": 18,
		},
	},
	"ash_alchemy": {
		"id": "ash_alchemy",
		"name": "灰烬炼金",
		"color": "mixed",
		"rarity": "rare",
		"condition": "先消灰，再消金",
		"effect": "每点灰色转为 1 金币与 2 护盾（护盾上限 10）。",
		"short": "灰 -> 金",
		"coins_per_gray": 1,
		"shield_per_gray": 2,
		"shield_cap": 10,
		"pools": ["rare", "mixed"],
		"upgrade": {
			"effect": "每点灰色转为 2 金币与 3 护盾（护盾上限 14）。",
			"coins_per_gray": 2,
			"shield_per_gray": 3,
			"shield_cap": 14,
		},
	},
	"mist_phrase": {
		"id": "mist_phrase",
		"name": "破雾短句",
		"color": "gray",
		"rarity": "common",
		"condition": "本回合累计灰色 >=6",
		"effect": "净化 2 个灰块。",
		"short": "灰 >=6",
		"threshold": 6,
		"cleanse_count": 2,
		"pools": ["common", "gray"],
		"upgrade": {
			"condition": "本回合累计灰色 >=5",
			"short": "灰 >=5",
			"threshold": 5,
		},
	},
	"gray_blade": {
		"id": "gray_blade",
		"name": "灰刃",
		"color": "gray",
		"rarity": "common",
		"condition": "主动完成灰色 4 连+",
		"effect": "造成 20 伤害，灰蚀压力 -1。",
		"short": "主动灰 4 连",
		"match_size": 4,
		"damage": 20,
		"corruption_reduction": 1,
		"pools": ["common", "gray"],
		"upgrade": {
			"effect": "造成 26 伤害，灰蚀压力 -1。",
			"damage": 26,
		},
	},
	"color_from_mist": {
		"id": "color_from_mist",
		"name": "雾中取色",
		"color": "gray",
		"rarity": "common",
		"condition": "先消除灰色，再消除任意玩家颜色",
		"effect": "获得 1 颜料。",
		"short": "灰 -> 玩家色",
		"required_gray_events": 1,
		"required_player_color_events": 1,
		"pigment": 1,
		"pigment_battle_cap": 4,
		"pools": ["common", "gray"],
		"upgrade": {
			"effect": "获得 1 颜料，本场此效果最多触发 5 次。",
			"pigment_battle_cap": 5,
		},
	},
	"echo_stele": {
		"id": "echo_stele",
		"name": "残响石碑",
		"color": "gray",
		"rarity": "rare",
		"condition": "敌人污染棋盘后完成任意色谱",
		"effect": "净化 3 个灰块并抽 1 张色谱。",
		"short": "污染后完成色谱",
		"enemy_pollution_events": 1,
		"cleanse_count": 3,
		"draw_count": 1,
		"pools": ["rare", "gray", "elite"],
		"upgrade": {
			"effect": "净化 4 个灰块并抽 1 张色谱。",
			"cleanse_count": 4,
		},
	},
	"gray_king_contract": {
		"id": "gray_king_contract",
		"name": "灰王契约",
		"color": "gray",
		"rarity": "epic",
		"condition": "灰蚀压力 >=8",
		"effect": "造成灰蚀压力 x8 的伤害，并将灰蚀压力减半。",
		"short": "灰蚀压力 >=8",
		"corruption_threshold": 8,
		"damage_per_corruption": 8,
		"corruption_keep_ratio": 0.5,
		"pools": ["epic", "gray", "elite"],
		"upgrade": {
			"condition": "灰蚀压力 >=7",
			"short": "灰蚀压力 >=7",
			"corruption_threshold": 7,
		},
	},
	"daylight_calibration": {
		"id": "daylight_calibration",
		"name": "白昼校准",
		"color": "white",
		"rarity": "rare",
		"condition": "完成 2 张不同颜色色谱",
		"effect": "清除 1 个负面，回复 5 HP。",
		"short": "2 张不同色谱",
		"completed_colors": 2,
		"heal": 5,
		"pools": ["rare", "mixed", "elite"],
		"upgrade": {
			"effect": "清除 1 个负面，回复 6 HP。",
			"heal": 6,
		},
	},
	"prism_concerto": {
		"id": "prism_concerto",
		"name": "棱镜协奏",
		"color": "mixed",
		"rarity": "rare",
		"condition": "同回合分别消除红、蓝、金各 1 次",
		"effect": "造成 10 伤害，获得 8 护盾与 6 金币。",
		"short": "红蓝金各消 1 次",
		"required_color_events": 1,
		"red_damage": 10,
		"blue_shield": 8,
		"gold_coins": 6,
		"pools": ["rare", "mixed", "elite"],
		"upgrade": {
			"effect": "造成 13 伤害，获得 10 护盾与 8 金币。",
			"red_damage": 13,
			"blue_shield": 10,
			"gold_coins": 8,
		},
	},
	"colorless_pause": {
		"id": "colorless_pause",
		"name": "无色停顿",
		"color": "mixed",
		"rarity": "common",
		"condition": "本回合未完成第 2 张同色色谱",
		"effect": "获得 10 护盾并抽 1 张色谱。",
		"short": "无同色第 2 张",
		"same_color_completed_max": 1,
		"shield": 10,
		"draw_count": 1,
		"pools": ["common", "mixed"],
		"upgrade": {
			"effect": "获得 13 护盾并抽 1 张色谱。",
			"shield": 13,
		},
	},
	"finale_variation": {
		"id": "finale_variation",
		"name": "终曲变奏",
		"color": "mixed",
		"rarity": "epic",
		"condition": "本回合完成 3 张色谱",
		"effect": "造成 50 伤害并获得 2 颜料。",
		"short": "完成 3 张色谱",
		"completed_cards": 3,
		"damage": 50,
		"pigment": 2,
		"pools": ["epic", "mixed", "elite"],
		"upgrade": {
			"effect": "造成 65 伤害并获得 2 颜料。",
			"damage": 65,
		},
	},
	"verdant_suture": {
		"id": "verdant_suture", "name": "翠痕缝合", "color": "green", "rarity": "common",
		"condition": "本回合累计消除灰色 >=4", "effect": "回复 5 HP。", "short": "灰 >=4",
		"condition_type": "color_total", "condition_key": "threshold", "board_color": "gray", "threshold": 4,
		"effects": [{"type": "heal", "value": 5}], "pools": ["common", "green"],
		"upgrade": {"effect": "回复 7 HP。", "effects": [{"type": "heal", "value": 7}]},
	},
	"moss_guard": {
		"id": "moss_guard", "name": "苔纹护持", "color": "green", "rarity": "common",
		"condition": "本回合累计消除蓝色 >=4", "effect": "获得 12 护盾并回复 2 HP。", "short": "蓝 >=4",
		"condition_type": "color_total", "condition_key": "threshold", "board_color": "blue", "threshold": 4,
		"effects": [{"type": "shield", "value": 12}, {"type": "heal", "value": 2}], "pools": ["common", "green"],
		"upgrade": {"effect": "获得 16 护盾并回复 3 HP。", "effects": [{"type": "shield", "value": 16}, {"type": "heal", "value": 3}]},
	},
	"seed_exchange": {
		"id": "seed_exchange", "name": "种籽交换", "color": "green", "rarity": "common",
		"condition": "同回合先消金，再消灰", "effect": "获得 1 颜料并净化 1 格。", "short": "金 -> 灰",
		"condition_type": "color_sequence", "first_color": "gold", "second_color": "gray",
		"effects": [{"type": "pigment", "value": 1}, {"type": "cleanse", "value": 1}], "pools": ["common", "green"],
		"upgrade": {"effect": "获得 2 颜料并净化 2 格。", "effects": [{"type": "pigment", "value": 2}, {"type": "cleanse", "value": 2}]},
	},
	"renewal_step": {
		"id": "renewal_step", "name": "复苏步", "color": "green", "rarity": "common",
		"condition": "本回合消除 2 种颜色", "effect": "回复 4 HP并获得 6 护盾。", "short": "消除 2 色",
		"condition_type": "unique_colors", "condition_key": "unique_colors", "unique_colors": 2,
		"effects": [{"type": "heal", "value": 4}, {"type": "shield", "value": 6}], "pools": ["common", "green"],
		"upgrade": {"effect": "回复 6 HP并获得 8 护盾。", "effects": [{"type": "heal", "value": 6}, {"type": "shield", "value": 8}]},
	},
	"chlorophyll_refit": {
		"id": "chlorophyll_refit", "name": "叶绿改谱", "color": "green", "rarity": "common",
		"condition": "主动完成灰色 4 连+", "effect": "净化 2 格，并将 1 格染为玩家色。", "short": "主动灰 4 连",
		"condition_type": "match_size", "condition_key": "match_size", "board_color": "gray", "match_size": 4, "active_only": true,
		"effects": [{"type": "cleanse", "value": 2}, {"type": "dye", "value": 1, "color": "random_player"}], "pools": ["common", "green"],
		"upgrade": {"effect": "净化 3 格，并将 2 格染为玩家色。", "effects": [{"type": "cleanse", "value": 3}, {"type": "dye", "value": 2, "color": "random_player"}]},
	},
	"root_reserve": {
		"id": "root_reserve", "name": "根系储备", "color": "green", "rarity": "rare",
		"condition": "护盾达到 12", "effect": "回复 8 HP并获得 5 护盾。", "short": "护盾 >=12",
		"condition_type": "shield_min", "condition_key": "shield_min", "shield_min": 12,
		"effects": [{"type": "heal", "value": 8}, {"type": "shield", "value": 5}], "pools": ["rare", "green", "elite"],
		"upgrade": {"effect": "回复 11 HP并获得 7 护盾。", "effects": [{"type": "heal", "value": 11}, {"type": "shield", "value": 7}]},
	},
	"spring_refrain": {
		"id": "spring_refrain", "name": "春返副歌", "color": "green", "rarity": "rare",
		"condition": "本回合完成 2 张色谱", "effect": "回复 8 HP并抽 1 张。", "short": "完成 2 张",
		"condition_type": "completed_cards", "condition_key": "completed_cards", "completed_cards": 2,
		"effects": [{"type": "heal", "value": 8}, {"type": "draw", "value": 1}], "pools": ["rare", "green", "elite"],
		"upgrade": {"effect": "回复 10 HP并抽 2 张。", "effects": [{"type": "heal", "value": 10}, {"type": "draw", "value": 2}]},
	},
	"overgrowth_lattice": {
		"id": "overgrowth_lattice", "name": "蔓生格律", "color": "green", "rarity": "rare",
		"condition": "触发 2 级以上级联", "effect": "净化 2 格并获得 10 护盾。", "short": "2 级联",
		"condition_type": "cascade", "condition_key": "cascade", "cascade": 2,
		"effects": [{"type": "cleanse", "value": 2}, {"type": "shield", "value": 10}], "pools": ["rare", "green", "elite"],
		"upgrade": {"effect": "净化 3 格并获得 13 护盾。", "effects": [{"type": "cleanse", "value": 3}, {"type": "shield", "value": 13}]},
	},
	"emerald_finale": {
		"id": "emerald_finale", "name": "翡翠终花", "color": "green", "rarity": "epic",
		"condition": "本回合消除红、蓝、金、灰四种颜色", "effect": "造成 30 伤害，回复 12 HP，获得 1 颜料。", "short": "消除 4 色",
		"condition_type": "unique_colors", "condition_key": "unique_colors", "unique_colors": 4,
		"effects": [{"type": "damage", "value": 30, "color": "green"}, {"type": "heal", "value": 12}, {"type": "pigment", "value": 1}], "pools": ["epic", "green", "elite"],
		"upgrade": {"effect": "造成 40 伤害，回复 16 HP，获得 1 颜料。", "effects": [{"type": "damage", "value": 40, "color": "green"}, {"type": "heal", "value": 16}, {"type": "pigment", "value": 1}]},
	},
	"violet_afterimage": {
		"id": "violet_afterimage", "name": "紫弦残像", "color": "purple", "rarity": "common",
		"condition": "触发 2 级以上级联", "effect": "造成 16 伤害。", "short": "2 级联",
		"condition_type": "cascade", "condition_key": "cascade", "cascade": 2,
		"effects": [{"type": "damage", "value": 16, "color": "purple"}], "pools": ["common", "purple"],
		"upgrade": {"effect": "造成 22 伤害。", "effects": [{"type": "damage", "value": 22, "color": "purple"}]},
	},
	"echo_step": {
		"id": "echo_step", "name": "回声错步", "color": "purple", "rarity": "common",
		"condition": "同回合先消红，再消蓝", "effect": "抽 1 张并获得 5 护盾。", "short": "红 -> 蓝",
		"condition_type": "color_sequence", "first_color": "red", "second_color": "blue",
		"effects": [{"type": "draw", "value": 1}, {"type": "shield", "value": 5}], "pools": ["common", "purple"],
		"upgrade": {"effect": "抽 1 张并获得 9 护盾。", "effects": [{"type": "draw", "value": 1}, {"type": "shield", "value": 9}]},
	},
	"dusk_counter": {
		"id": "dusk_counter", "name": "暮色对拍", "color": "purple", "rarity": "common",
		"condition": "敌人为攻击或重击意图时完成消除", "effect": "造成 8 伤害并获得 10 护盾。", "short": "攻击意图",
		"condition_type": "enemy_intent", "intent_types": ["attack", "heavy"],
		"effects": [{"type": "damage", "value": 8, "color": "purple"}, {"type": "shield", "value": 10}], "pools": ["common", "purple"],
		"upgrade": {"effect": "造成 12 伤害并获得 13 护盾。", "effects": [{"type": "damage", "value": 12, "color": "purple"}, {"type": "shield", "value": 13}]},
	},
	"royal_interval": {
		"id": "royal_interval", "name": "王庭间奏", "color": "purple", "rarity": "common",
		"condition": "本回合累计消除金色 >=4", "effect": "造成 8 伤害并获得 6 金币。", "short": "金 >=4",
		"condition_type": "color_total", "condition_key": "threshold", "board_color": "gold", "threshold": 4,
		"effects": [{"type": "damage", "value": 8, "color": "purple"}, {"type": "coins", "value": 6}], "pools": ["common", "purple"],
		"upgrade": {"effect": "造成 11 伤害并获得 9 金币。", "effects": [{"type": "damage", "value": 11, "color": "purple"}, {"type": "coins", "value": 9}]},
	},
	"amethyst_thread": {
		"id": "amethyst_thread", "name": "紫晶牵线", "color": "purple", "rarity": "common",
		"condition": "本回合完成 2 次蓝色消除", "effect": "抽 1 张色谱。", "short": "2 次蓝消",
		"condition_type": "color_events", "condition_key": "event_count", "board_color": "blue", "event_count": 2,
		"effects": [{"type": "draw", "value": 1}], "pools": ["common", "purple"],
		"upgrade": {"effect": "抽 2 张色谱。", "effects": [{"type": "draw", "value": 2}]},
	},
	"mirrored_chord": {
		"id": "mirrored_chord", "name": "镜像和弦", "color": "purple", "rarity": "rare",
		"condition": "本回合完成 2 种学派色谱", "effect": "造成 24 伤害。", "short": "完成 2 学派",
		"condition_type": "completed_colors", "condition_key": "completed_colors", "completed_colors": 2,
		"effects": [{"type": "damage", "value": 24, "color": "purple"}], "pools": ["rare", "purple", "elite"],
		"upgrade": {"effect": "造成 32 伤害。", "effects": [{"type": "damage", "value": 32, "color": "purple"}]},
	},
	"silent_cadenza": {
		"id": "silent_cadenza", "name": "静默华彩", "color": "purple", "rarity": "rare",
		"condition": "本回合未受伤且消除蓝色", "effect": "获得 15 护盾并冻结 1 回合。", "short": "未受伤 + 蓝",
		"condition_type": "no_damage_color", "board_color": "blue",
		"effects": [{"type": "shield", "value": 15}, {"type": "freeze", "value": 1}], "pools": ["rare", "purple", "elite"],
		"upgrade": {"effect": "获得 20 护盾并冻结 1 回合。", "effects": [{"type": "shield", "value": 20}, {"type": "freeze", "value": 1}]},
	},
	"inversion_ritual": {
		"id": "inversion_ritual", "name": "倒置仪式", "color": "purple", "rarity": "rare",
		"condition": "同回合先消灰，再消红", "effect": "造成 26 伤害并净化 1 格。", "short": "灰 -> 红",
		"condition_type": "color_sequence", "first_color": "gray", "second_color": "red",
		"effects": [{"type": "damage", "value": 26, "color": "purple"}, {"type": "cleanse", "value": 1}], "pools": ["rare", "purple", "elite"],
		"upgrade": {"effect": "造成 34 伤害并净化 2 格。", "effects": [{"type": "damage", "value": 34, "color": "purple"}, {"type": "cleanse", "value": 2}]},
	},
	"purple_finale": {
		"id": "purple_finale", "name": "紫弦终章", "color": "purple", "rarity": "epic",
		"condition": "本回合完成 3 张色谱", "effect": "造成 55 伤害并抽 1 张。", "short": "完成 3 张",
		"condition_type": "completed_cards", "condition_key": "completed_cards", "completed_cards": 3,
		"effects": [{"type": "damage", "value": 55, "color": "purple"}, {"type": "draw", "value": 1}], "pools": ["epic", "purple", "elite"],
		"upgrade": {"effect": "造成 72 伤害并抽 1 张。", "effects": [{"type": "damage", "value": 72, "color": "purple"}, {"type": "draw", "value": 1}]},
	},
	"dawn_cleanse": {
		"id": "dawn_cleanse", "name": "晨光净式", "color": "white", "rarity": "common",
		"condition": "本回合累计消除灰色 >=4", "effect": "净化 2 格并获得 5 护盾。", "short": "灰 >=4",
		"condition_type": "color_total", "condition_key": "threshold", "board_color": "gray", "threshold": 4,
		"effects": [{"type": "cleanse", "value": 2}, {"type": "shield", "value": 5}], "pools": ["common", "white"],
		"upgrade": {"effect": "净化 3 格并获得 8 护盾。", "effects": [{"type": "cleanse", "value": 3}, {"type": "shield", "value": 8}]},
	},
	"ivory_measure": {
		"id": "ivory_measure", "name": "象牙衡拍", "color": "white", "rarity": "common",
		"condition": "本回合消除 2 种颜色", "effect": "获得 10 护盾。", "short": "消除 2 色",
		"condition_type": "unique_colors", "condition_key": "unique_colors", "unique_colors": 2,
		"effects": [{"type": "shield", "value": 10}], "pools": ["common", "white"],
		"upgrade": {"effect": "获得 14 护盾。", "effects": [{"type": "shield", "value": 14}]},
	},
	"clear_rest": {
		"id": "clear_rest", "name": "澄明休止", "color": "white", "rarity": "common",
		"condition": "同回合先消灰，再消蓝", "effect": "净化 2 格并回复 3 HP。", "short": "灰 -> 蓝",
		"condition_type": "color_sequence", "first_color": "gray", "second_color": "blue",
		"effects": [{"type": "cleanse", "value": 2}, {"type": "heal", "value": 3}], "pools": ["common", "white"],
		"upgrade": {"effect": "净化 3 格并回复 5 HP。", "effects": [{"type": "cleanse", "value": 3}, {"type": "heal", "value": 5}]},
	},
	"sunlit_guard": {
		"id": "sunlit_guard", "name": "日照护谱", "color": "white", "rarity": "common",
		"condition": "敌人为污染或抗性意图时完成消除", "effect": "获得 12 护盾与 1 颜料。", "short": "污染 / 抗性意图",
		"condition_type": "enemy_intent", "intent_types": ["pollute", "resist", "resist_dominant"],
		"effects": [{"type": "shield", "value": 12}, {"type": "pigment", "value": 1}], "pools": ["common", "white"],
		"upgrade": {"effect": "获得 16 护盾与 1 颜料。", "effects": [{"type": "shield", "value": 16}, {"type": "pigment", "value": 1}]},
	},
	"balance_note": {
		"id": "balance_note", "name": "均衡音", "color": "white", "rarity": "common",
		"condition": "本回合完成 2 种学派色谱", "effect": "回复 5 HP并获得 5 护盾。", "short": "完成 2 学派",
		"condition_type": "completed_colors", "condition_key": "completed_colors", "completed_colors": 2,
		"effects": [{"type": "heal", "value": 5}, {"type": "shield", "value": 5}], "pools": ["common", "white"],
		"upgrade": {"effect": "回复 7 HP并获得 7 护盾。", "effects": [{"type": "heal", "value": 7}, {"type": "shield", "value": 7}]},
	},
	"prism_verdict": {
		"id": "prism_verdict", "name": "棱镜裁决", "color": "white", "rarity": "rare",
		"condition": "本回合完成 3 种学派色谱", "effect": "造成 28 伤害并击碎颜色抗性。", "short": "完成 3 学派",
		"condition_type": "completed_colors", "condition_key": "completed_colors", "completed_colors": 3,
		"effects": [{"type": "damage", "value": 28, "color": "white"}], "pools": ["rare", "white", "elite"],
		"upgrade": {"effect": "造成 38 伤害并击碎颜色抗性。", "effects": [{"type": "damage", "value": 38, "color": "white"}]},
	},
	"white_archive": {
		"id": "white_archive", "name": "白页档案", "color": "white", "rarity": "rare",
		"condition": "触发 2 级以上级联", "effect": "抽 2 张色谱。", "short": "2 级联",
		"condition_type": "cascade", "condition_key": "cascade", "cascade": 2,
		"effects": [{"type": "draw", "value": 2}], "pools": ["rare", "white", "elite"],
		"upgrade": {"effect": "抽 2 张色谱并获得 6 护盾。", "effects": [{"type": "draw", "value": 2}, {"type": "shield", "value": 6}]},
	},
	"halo_recovery": {
		"id": "halo_recovery", "name": "光环回收", "color": "white", "rarity": "rare",
		"condition": "HP 不高于 50%", "effect": "回复 14 HP并获得 8 护盾。", "short": "半血以下",
		"condition_type": "hp_below", "hp_ratio": 0.5,
		"effects": [{"type": "heal", "value": 14}, {"type": "shield", "value": 8}], "pools": ["rare", "white", "elite"],
		"upgrade": {"effect": "回复 18 HP并获得 10 护盾。", "effects": [{"type": "heal", "value": 18}, {"type": "shield", "value": 10}]},
	},
	"pure_finale": {
		"id": "pure_finale", "name": "纯白终止", "color": "white", "rarity": "epic",
		"condition": "本回合消除红、蓝、金、灰四种颜色", "effect": "净化 5 格，造成 38 伤害并获得 1 颜料。", "short": "消除 4 色",
		"condition_type": "unique_colors", "condition_key": "unique_colors", "unique_colors": 4,
		"effects": [{"type": "cleanse", "value": 5}, {"type": "damage", "value": 38, "color": "white"}, {"type": "pigment", "value": 1}], "pools": ["epic", "white", "elite"],
		"upgrade": {"effect": "净化 6 格，造成 50 伤害并获得 1 颜料。", "effects": [{"type": "cleanse", "value": 6}, {"type": "damage", "value": 50, "color": "white"}, {"type": "pigment", "value": 1}]},
	},
	"ink_bargain": {
		"id": "ink_bargain", "name": "墨契还价", "color": "black", "rarity": "common",
		"condition": "最后 1 步完成任意色谱", "effect": "失去 2 HP，造成 24 伤害。", "short": "最后 1 步完成",
		"condition_type": "moves_left_after", "moves_left_after_max": 0, "completed_cards_min": 1,
		"effects": [{"type": "self_damage", "value": 2}, {"type": "damage", "value": 24, "color": "black"}], "pools": ["common", "black"],
		"upgrade": {"effect": "失去 1 HP，造成 31 伤害。", "effects": [{"type": "self_damage", "value": 1}, {"type": "damage", "value": 31, "color": "black"}]},
	},
	"ash_usury": {
		"id": "ash_usury", "name": "灰烬利息", "color": "black", "rarity": "common",
		"condition": "灰蚀压力达到 4", "effect": "失去 2 HP，获得 12 金币。", "short": "灰蚀 >=4",
		"condition_type": "gray_pressure", "condition_key": "gray_pressure", "gray_pressure": 4,
		"effects": [{"type": "self_damage", "value": 2}, {"type": "coins", "value": 12}], "pools": ["common", "black"],
		"upgrade": {"effect": "失去 2 HP，获得 16 金币。", "effects": [{"type": "self_damage", "value": 2}, {"type": "coins", "value": 16}]},
	},
	"void_edge": {
		"id": "void_edge", "name": "虚无刃", "color": "black", "rarity": "common",
		"condition": "本回合累计消除灰色 >=4", "effect": "造成 22 伤害，灰蚀压力 +1。", "short": "灰 >=4",
		"condition_type": "color_total", "condition_key": "threshold", "board_color": "gray", "threshold": 4,
		"effects": [{"type": "damage", "value": 22, "color": "black"}, {"type": "gray_pressure", "value": 1}], "pools": ["common", "black"],
		"upgrade": {"effect": "造成 30 伤害，灰蚀压力 +1。", "effects": [{"type": "damage", "value": 30, "color": "black"}, {"type": "gray_pressure", "value": 1}]},
	},
	"night_exchange": {
		"id": "night_exchange", "name": "夜色兑付", "color": "black", "rarity": "common",
		"condition": "同回合先消金，再消灰", "effect": "获得 10 金币与 1 颜料，灰蚀压力 +1。", "short": "金 -> 灰",
		"condition_type": "color_sequence", "first_color": "gold", "second_color": "gray",
		"effects": [{"type": "coins", "value": 10}, {"type": "pigment", "value": 1}, {"type": "gray_pressure", "value": 1}], "pools": ["common", "black"],
		"upgrade": {"effect": "获得 14 金币与 1 颜料，灰蚀压力 +1。", "effects": [{"type": "coins", "value": 14}, {"type": "pigment", "value": 1}, {"type": "gray_pressure", "value": 1}]},
	},
	"obsidian_guard": {
		"id": "obsidian_guard", "name": "黑曜护命", "color": "black", "rarity": "common",
		"condition": "HP 不高于 60%", "effect": "失去 2 HP，获得 18 护盾。", "short": "六成血以下",
		"condition_type": "hp_below", "hp_ratio": 0.6,
		"effects": [{"type": "self_damage", "value": 2}, {"type": "shield", "value": 18}], "pools": ["common", "black"],
		"upgrade": {"effect": "失去 1 HP，获得 24 护盾。", "effects": [{"type": "self_damage", "value": 1}, {"type": "shield", "value": 24}]},
	},
	"eclipse_mark": {
		"id": "eclipse_mark", "name": "蚀日刻印", "color": "black", "rarity": "rare",
		"condition": "敌人燃烧达到 2 层", "effect": "失去 3 HP，造成 30 伤害。", "short": "敌燃烧 >=2",
		"condition_type": "enemy_burn", "condition_key": "enemy_burn_stacks", "enemy_burn_stacks": 2,
		"effects": [{"type": "self_damage", "value": 3}, {"type": "damage", "value": 30, "color": "black"}], "pools": ["rare", "black", "elite"],
		"upgrade": {"effect": "失去 2 HP，造成 40 伤害。", "effects": [{"type": "self_damage", "value": 2}, {"type": "damage", "value": 40, "color": "black"}]},
	},
	"debt_requiem": {
		"id": "debt_requiem", "name": "债务安魂", "color": "black", "rarity": "rare",
		"condition": "持有至少 40 金币", "effect": "失去 3 HP，造成 36 伤害。", "short": "金币 >=40",
		"condition_type": "coins_min", "condition_key": "coins_min", "coins_min": 40,
		"effects": [{"type": "self_damage", "value": 3}, {"type": "damage", "value": 36, "color": "black"}], "pools": ["rare", "black", "elite"],
		"upgrade": {"effect": "失去 2 HP，造成 48 伤害。", "effects": [{"type": "self_damage", "value": 2}, {"type": "damage", "value": 48, "color": "black"}]},
	},
	"abyssal_echo": {
		"id": "abyssal_echo", "name": "深渊回声", "color": "black", "rarity": "rare",
		"condition": "本回合完成 2 张色谱", "effect": "造成 32 伤害，灰蚀压力 +1。", "short": "完成 2 张",
		"condition_type": "completed_cards", "condition_key": "completed_cards", "completed_cards": 2,
		"effects": [{"type": "damage", "value": 32, "color": "black"}, {"type": "gray_pressure", "value": 1}], "pools": ["rare", "black", "elite"],
		"upgrade": {"effect": "造成 42 伤害，灰蚀压力 +1。", "effects": [{"type": "damage", "value": 42, "color": "black"}, {"type": "gray_pressure", "value": 1}]},
	},
	"black_finale": {
		"id": "black_finale", "name": "黑曜终曲", "color": "black", "rarity": "epic",
		"condition": "灰蚀压力达到 8", "effect": "失去 5 HP，造成 70 伤害，灰蚀压力 -3。", "short": "灰蚀 >=8",
		"condition_type": "gray_pressure", "condition_key": "gray_pressure", "gray_pressure": 8,
		"effects": [{"type": "self_damage", "value": 5}, {"type": "damage", "value": 70, "color": "black"}, {"type": "gray_pressure", "value": -3}], "pools": ["epic", "black", "elite"],
		"upgrade": {"effect": "失去 4 HP，造成 92 伤害，灰蚀压力 -4。", "effects": [{"type": "self_damage", "value": 4}, {"type": "damage", "value": 92, "color": "black"}, {"type": "gray_pressure", "value": -4}]},
	},
	"flame_lane": {
		"id": "flame_lane", "name": "焰谱突进", "color": "red", "rarity": "common",
		"condition": "主动红色 4 连", "effect": "施加 1 层燃烧；本次谱式冲击额外造成 3 伤害。", "short": "主动红 4 连",
		"condition_type": "match_size", "board_color": "red", "match_size": 4, "active_only": true,
		"effects": [{"type": "burn", "value": 1, "turns": 2}], "resolution_modifier": {"flat_damage": 3}, "pools": ["common", "red", "chapter_peg"],
		"upgrade": {"effect": "施加 1 层燃烧；本次谱式冲击额外造成 6 伤害。", "resolution_modifier": {"flat_damage": 6}},
	},
	"mist_borer": {
		"id": "mist_borer", "name": "雾层钻头", "color": "gray", "rarity": "common",
		"condition": "累计消除 7 个灰色", "effect": "净化 1 格，本次谱式冲击无视护甲。", "short": "灰色累计 7",
		"condition_type": "color_total", "board_color": "gray", "threshold": 7,
		"effects": [{"type": "cleanse", "value": 1}], "resolution_modifier": {"armor_break": 1}, "pools": ["common", "gray", "chapter_peg"],
		"upgrade": {"effect": "净化 2 格，本次谱式冲击无视护甲。", "effects": [{"type": "cleanse", "value": 2}], "resolution_modifier": {"armor_break": 2}},
	},
	"ember_rebound": {
		"id": "ember_rebound", "name": "余烬折返", "color": "red", "rarity": "rare",
		"condition": "达到 2 级级联", "effect": "造成 16 红色伤害，本次谱式冲击额外造成 3 伤害。", "short": "级联 2",
		"condition_type": "cascade", "cascade": 2,
		"effects": [{"type": "damage", "value": 16, "color": "red"}], "resolution_modifier": {"flat_damage": 3}, "pools": ["rare", "red", "chapter_peg"],
		"upgrade": {"effect": "造成 22 红色伤害，本次谱式冲击额外造成 5 伤害。", "effects": [{"type": "damage", "value": 22, "color": "red"}], "resolution_modifier": {"flat_damage": 5}},
	},
	"fogbreaker_round": {
		"id": "fogbreaker_round", "name": "破雾定式", "color": "white", "rarity": "rare",
		"condition": "灰蚀压力达到 4", "effect": "净化 2 格，谱式结算时额外净化 1 格。", "short": "灰蚀 >=4",
		"condition_type": "gray_pressure", "gray_pressure": 4,
		"effects": [{"type": "cleanse", "value": 2}], "resolution_modifier": {"cleanse": 1}, "pools": ["rare", "white", "chapter_peg"],
		"upgrade": {"effect": "净化 3 格，谱式结算时额外净化 2 格。", "effects": [{"type": "cleanse", "value": 3}], "resolution_modifier": {"cleanse": 2}},
	},
	"mirror_cadence": {
		"id": "mirror_cadence", "name": "镜面拍点", "color": "blue", "rarity": "common",
		"condition": "主动蓝色 4 连", "effect": "获得 7 护盾，本次谱式冲击伤害 +12%。", "short": "主动蓝 4 连",
		"condition_type": "match_size", "board_color": "blue", "match_size": 4, "active_only": true,
		"effects": [{"type": "shield", "value": 7}], "resolution_modifier": {"damage_ratio_bonus": 0.12}, "pools": ["common", "blue", "chapter_peg"],
		"upgrade": {"effect": "获得 10 护盾，本次谱式冲击伤害 +18%。", "effects": [{"type": "shield", "value": 10}], "resolution_modifier": {"damage_ratio_bonus": 0.18}},
	},
	"echo_dividend": {
		"id": "echo_dividend", "name": "回声分红", "color": "gold", "rarity": "common",
		"condition": "累计消除 6 个金色", "effect": "获得 6 金币，谱式结算时额外获得 2 金币。", "short": "金色累计 6",
		"condition_type": "color_total", "board_color": "gold", "threshold": 6,
		"effects": [{"type": "coins", "value": 6}], "resolution_modifier": {"bonus_coins": 2}, "pools": ["common", "gold", "chapter_peg"],
		"upgrade": {"effect": "获得 9 金币，谱式结算时额外获得 3 金币。", "effects": [{"type": "coins", "value": 9}], "resolution_modifier": {"bonus_coins": 3}},
	},
	"refracted_duet": {
		"id": "refracted_duet", "name": "折光二重奏", "color": "mixed", "rarity": "rare",
		"condition": "本回合消除 2 种颜色", "effect": "造成 12 混色伤害；谱式冲击复奏 1 次，复奏伤害为 70%。", "short": "2 种颜色",
		"condition_type": "unique_colors", "unique_colors": 2,
		"effects": [{"type": "damage", "value": 12, "color": "mixed"}], "resolution_modifier": {"repeat_count": 2, "repeat_ratio": 0.70}, "pools": ["rare", "mixed", "chapter_peg"],
		"upgrade": {"effect": "造成 18 混色伤害；谱式冲击复奏 2 次，每次为 58%。", "effects": [{"type": "damage", "value": 18, "color": "mixed"}], "resolution_modifier": {"repeat_count": 3, "repeat_ratio": 0.58}},
	},
	"resistance_break": {
		"id": "resistance_break", "name": "抗性破拍", "color": "purple", "rarity": "rare",
		"condition": "敌方准备抗性、防御或蓄力", "effect": "造成 20 紫色伤害，本次谱式冲击无视护甲。", "short": "反制防守意图",
		"condition_type": "enemy_intent", "intent_types": ["resist", "resist_dominant", "defend", "charge"],
		"effects": [{"type": "damage", "value": 20, "color": "purple"}], "resolution_modifier": {"armor_break": 3}, "pools": ["rare", "purple", "chapter_peg"],
		"upgrade": {"effect": "造成 28 紫色伤害，本次谱式冲击无视护甲。", "effects": [{"type": "damage", "value": 28, "color": "purple"}], "resolution_modifier": {"armor_break": 5}},
	},
	"royal_lockpick": {
		"id": "royal_lockpick", "name": "王锁解谱", "color": "gold", "rarity": "rare",
		"condition": "持有至少 45 金币", "effect": "获得 5 金币，本次谱式冲击无视护甲。", "short": "金币 >=45",
		"condition_type": "coins_min", "coins_min": 45,
		"effects": [{"type": "coins", "value": 5}], "resolution_modifier": {"armor_break": 2}, "pools": ["rare", "gold", "chapter_peg"],
		"upgrade": {"effect": "获得 8 金币，本次谱式冲击无视护甲。", "effects": [{"type": "coins", "value": 8}], "resolution_modifier": {"armor_break": 3}},
	},
	"void_counterpoint": {
		"id": "void_counterpoint", "name": "虚无对位", "color": "black", "rarity": "rare",
		"condition": "本回合完成 2 张色谱", "effect": "获得 6 护盾，谱式结算时额外净化 1 格。", "short": "完成 2 张",
		"condition_type": "completed_cards", "completed_cards": 2,
		"effects": [{"type": "shield", "value": 6}], "resolution_modifier": {"cleanse": 1}, "pools": ["rare", "black", "chapter_peg"],
		"upgrade": {"effect": "获得 10 护盾，谱式结算时额外净化 1 格并造成 3 伤害。", "effects": [{"type": "shield", "value": 10}], "resolution_modifier": {"cleanse": 1, "flat_damage": 3}},
	},
	"hazard_harvest": {
		"id": "hazard_harvest", "name": "险局采收", "color": "green", "rarity": "epic",
		"condition": "本回合消除 3 种颜色", "effect": "回复 5 HP；谱式结算时净化 1 格并额外造成 4 伤害。", "short": "3 种颜色",
		"condition_type": "unique_colors", "unique_colors": 3,
		"effects": [{"type": "heal", "value": 5}], "resolution_modifier": {"cleanse": 1, "flat_damage": 4}, "pools": ["epic", "green", "chapter_peg", "elite"],
		"upgrade": {"effect": "回复 8 HP；谱式结算时净化 1 格并额外造成 6 伤害。", "effects": [{"type": "heal", "value": 8}], "resolution_modifier": {"cleanse": 1, "flat_damage": 6}},
	},
	"four_color_barrage": {
		"id": "four_color_barrage", "name": "四色镇魂合奏", "color": "mixed", "rarity": "epic",
		"condition": "本回合完成 3 种学派色谱", "effect": "造成 30 混色伤害；谱式冲击复奏 3 次，每次为 48%，总伤害 +6%。", "short": "完成 3 种学派",
		"condition_type": "completed_colors", "completed_colors": 3,
		"effects": [{"type": "damage", "value": 30, "color": "mixed"}], "resolution_modifier": {"repeat_count": 4, "repeat_ratio": 0.48, "damage_ratio_bonus": 0.06}, "pools": ["epic", "mixed", "chapter_peg", "elite"],
		"upgrade": {"effect": "造成 40 混色伤害；谱式冲击复奏 3 次，每次为 58%，总伤害 +10%。", "effects": [{"type": "damage", "value": 40, "color": "mixed"}], "resolution_modifier": {"repeat_count": 4, "repeat_ratio": 0.58, "damage_ratio_bonus": 0.10}},
	},
	"chromatic_relay": {
		"id": "chromatic_relay", "name": "双色接力", "color": "mixed", "rarity": "common",
		"condition": "同回合先消红色，再消蓝色", "effect": "获得 8 护盾与 1 颜料。", "short": "红 -> 蓝",
		"condition_type": "color_sequence", "first_color": "red", "second_color": "blue",
		"effects": [{"type": "shield", "value": 8}, {"type": "pigment", "value": 1}], "pools": ["common", "mixed"],
		"upgrade": {"effect": "获得 12 护盾与 1 颜料。", "effects": [{"type": "shield", "value": 12}, {"type": "pigment", "value": 1}]},
	},
	"triune_refrain": {
		"id": "triune_refrain", "name": "三声复句", "color": "mixed", "rarity": "rare",
		"condition": "本回合消除 3 种颜色", "effect": "造成 22 混色伤害并净化 1 格。", "short": "消除 3 色",
		"condition_type": "unique_colors", "unique_colors": 3,
		"effects": [{"type": "damage", "value": 22, "color": "mixed"}, {"type": "cleanse", "value": 1}], "pools": ["rare", "mixed", "elite"],
		"upgrade": {"effect": "造成 30 混色伤害并净化 2 格。", "effects": [{"type": "damage", "value": 30, "color": "mixed"}, {"type": "cleanse", "value": 2}]},
	},
	"archive_cinder_index": {
		"id": "archive_cinder_index", "name": "余烬索引", "color": "red", "rarity": "common",
		"condition": "本回合累计红色 >=5", "effect": "造成 14 红色伤害并施加 1 层燃烧；谱式冲击额外造成 3 伤害。", "short": "红色 >=5",
		"condition_type": "color_total", "condition_key": "threshold", "board_color": "red", "threshold": 5,
		"effects": [{"type": "damage", "value": 14, "color": "red"}, {"type": "burn", "value": 1, "turns": 2}],
		"resolution_modifier": {"flat_damage": 3}, "pools": ["common", "red", "archive_v2"],
		"upgrade": {"effect": "造成 19 红色伤害并施加 1 层燃烧；谱式冲击额外造成 3 伤害。", "effects": [{"type": "damage", "value": 19, "color": "red"}, {"type": "burn", "value": 1, "turns": 2}]},
	},
	"severed_flame_signature": {
		"id": "severed_flame_signature", "name": "断焰署名", "color": "red", "rarity": "common",
		"condition": "同回合先消灰，再消红", "effect": "造成 18 伤害并净化 1 格。", "short": "灰 -> 红",
		"condition_type": "color_sequence", "first_color": "gray", "second_color": "red",
		"effects": [{"type": "damage", "value": 18, "color": "red"}, {"type": "cleanse", "value": 1}], "pools": ["common", "red", "archive_v2"],
		"upgrade": {"effect": "造成 24 伤害并净化 2 格。", "effects": [{"type": "damage", "value": 24, "color": "red"}, {"type": "cleanse", "value": 2}]},
	},
	"corridor_blaze_answer": {
		"id": "corridor_blaze_answer", "name": "回廊焰答", "color": "red", "rarity": "rare",
		"condition": "本回合完成 2 张色谱", "effect": "造成 28 红色伤害并施加 2 层燃烧；谱式结算额外施加 1 层燃烧。", "short": "完成 2 张",
		"condition_type": "completed_cards", "condition_key": "completed_cards", "completed_cards": 2,
		"effects": [{"type": "damage", "value": 28, "color": "red"}, {"type": "burn", "value": 2, "turns": 2}],
		"resolution_modifier": {"burn": 1}, "pools": ["rare", "red", "archive_v2", "elite"],
		"upgrade": {"effect": "造成 37 红色伤害并施加 2 层燃烧；谱式结算额外施加 1 层燃烧。", "effects": [{"type": "damage", "value": 37, "color": "red"}, {"type": "burn", "value": 2, "turns": 2}]},
	},
	"redacted_sun": {
		"id": "redacted_sun", "name": "涂销之日", "color": "red", "rarity": "epic",
		"condition": "敌人燃烧达到 3 层", "effect": "失去 2 HP，造成 52 红色伤害；谱式冲击伤害 +8%。", "short": "燃烧 >=3",
		"condition_type": "enemy_burn", "condition_key": "enemy_burn_stacks", "enemy_burn_stacks": 3,
		"effects": [{"type": "self_damage", "value": 2}, {"type": "damage", "value": 52, "color": "red"}],
		"resolution_modifier": {"damage_ratio_bonus": 0.08}, "pools": ["epic", "red", "archive_v2", "elite"],
		"upgrade": {"effect": "失去 1 HP，造成 68 红色伤害；谱式冲击伤害 +10%。", "effects": [{"type": "self_damage", "value": 1}, {"type": "damage", "value": 68, "color": "red"}], "resolution_modifier": {"damage_ratio_bonus": 0.10}},
	},
	"mirror_margin": {
		"id": "mirror_margin", "name": "镜页边注", "color": "blue", "rarity": "common",
		"condition": "本回合未受伤且消除蓝色", "effect": "获得 10 护盾；谱式冲击伤害 +6%。", "short": "未受伤 + 蓝",
		"condition_type": "no_damage_color", "board_color": "blue", "effects": [{"type": "shield", "value": 10}],
		"resolution_modifier": {"damage_ratio_bonus": 0.06}, "pools": ["common", "blue", "archive_v2"],
		"upgrade": {"effect": "获得 14 护盾；谱式冲击伤害 +8%。", "effects": [{"type": "shield", "value": 14}], "resolution_modifier": {"damage_ratio_bonus": 0.08}},
	},
	"frost_catalogue": {
		"id": "frost_catalogue", "name": "霜印目录", "color": "blue", "rarity": "common",
		"condition": "本回合触发 2 次蓝色消除", "effect": "获得 12 护盾并冻结 1 回合。", "short": "2 次蓝消",
		"condition_type": "color_events", "condition_key": "event_count", "board_color": "blue", "event_count": 2,
		"effects": [{"type": "shield", "value": 12}, {"type": "freeze", "value": 1}], "pools": ["common", "blue", "archive_v2"],
		"upgrade": {"effect": "获得 16 护盾并冻结 1 回合。", "effects": [{"type": "shield", "value": 16}, {"type": "freeze", "value": 1}]},
	},
	"delayed_testimony": {
		"id": "delayed_testimony", "name": "迟到证词", "color": "blue", "rarity": "rare",
		"condition": "敌人准备攻击或重击", "effect": "获得 16 护盾，下次受到的伤害 -8。", "short": "攻击意图",
		"condition_type": "enemy_intent", "intent_types": ["attack", "heavy"],
		"effects": [{"type": "shield", "value": 16}, {"type": "damage_reduction", "value": 8}], "pools": ["rare", "blue", "archive_v2", "elite"],
		"upgrade": {"effect": "获得 21 护盾，下次受到的伤害 -10。", "effects": [{"type": "shield", "value": 21}, {"type": "damage_reduction", "value": 10}]},
	},
	"glass_lake_reprise": {
		"id": "glass_lake_reprise", "name": "镜湖返奏", "color": "blue", "rarity": "epic",
		"condition": "当前护盾至少 18", "effect": "造成 42 蓝色伤害并冻结 1 回合；谱式冲击复奏 1 次，复奏伤害为 65%。", "short": "护盾 >=18",
		"condition_type": "shield_min", "condition_key": "shield_min", "shield_min": 18,
		"effects": [{"type": "damage", "value": 42, "color": "blue"}, {"type": "freeze", "value": 1}],
		"resolution_modifier": {"repeat_count": 2, "repeat_ratio": 0.65}, "pools": ["epic", "blue", "archive_v2", "elite"],
		"upgrade": {"effect": "造成 55 蓝色伤害并冻结 1 回合；谱式冲击复奏 1 次，复奏伤害为 72%。", "effects": [{"type": "damage", "value": 55, "color": "blue"}, {"type": "freeze", "value": 1}], "resolution_modifier": {"repeat_count": 2, "repeat_ratio": 0.72}},
	},
	"lost_ledger": {
		"id": "lost_ledger", "name": "失页账簿", "color": "gold", "rarity": "common",
		"condition": "本回合累计金色 >=5", "effect": "获得 7 金币，谱式结算时额外获得 1 金币。", "short": "金色 >=5",
		"condition_type": "color_total", "condition_key": "threshold", "board_color": "gold", "threshold": 5,
		"effects": [{"type": "coins", "value": 7}], "resolution_modifier": {"bonus_coins": 1}, "pools": ["common", "gold", "archive_v2"],
		"upgrade": {"effect": "获得 10 金币，谱式结算时额外获得 2 金币。", "effects": [{"type": "coins", "value": 10}], "resolution_modifier": {"bonus_coins": 2}},
	},
	"archive_dividend": {
		"id": "archive_dividend", "name": "档案分红", "color": "gold", "rarity": "common",
		"condition": "同回合先消灰，再消金", "effect": "获得 8 金币与 1 颜料。", "short": "灰 -> 金",
		"condition_type": "color_sequence", "first_color": "gray", "second_color": "gold",
		"effects": [{"type": "coins", "value": 8}, {"type": "pigment", "value": 1}], "pools": ["common", "gold", "archive_v2"],
		"upgrade": {"effect": "获得 11 金币与 1 颜料。", "effects": [{"type": "coins", "value": 11}, {"type": "pigment", "value": 1}]},
	},
	"gilded_deposition": {
		"id": "gilded_deposition", "name": "鎏金证言", "color": "gold", "rarity": "rare",
		"condition": "持有至少 50 金币", "effect": "造成 24 金色伤害并获得 8 金币；本次谱式冲击无视护甲。", "short": "金币 >=50",
		"condition_type": "coins_min", "condition_key": "coins_min", "coins_min": 50,
		"effects": [{"type": "damage", "value": 24, "color": "gold"}, {"type": "coins", "value": 8}],
		"resolution_modifier": {"armor_break": 1}, "pools": ["rare", "gold", "archive_v2", "elite"],
		"upgrade": {"effect": "造成 32 金色伤害并获得 11 金币；本次谱式冲击无视护甲。", "effects": [{"type": "damage", "value": 32, "color": "gold"}, {"type": "coins", "value": 11}], "resolution_modifier": {"armor_break": 2}},
	},
	"final_receipt": {
		"id": "final_receipt", "name": "终幕收据", "color": "gold", "rarity": "epic",
		"condition": "本回合完成 3 张色谱", "effect": "造成 46 金色伤害并获得 10 金币；谱式冲击复奏 1 次，复奏伤害为 60%。", "short": "完成 3 张",
		"condition_type": "completed_cards", "condition_key": "completed_cards", "completed_cards": 3,
		"effects": [{"type": "damage", "value": 46, "color": "gold"}, {"type": "coins", "value": 10}],
		"resolution_modifier": {"repeat_count": 2, "repeat_ratio": 0.60}, "pools": ["epic", "gold", "archive_v2", "elite"],
		"upgrade": {"effect": "造成 60 金色伤害并获得 12 金币；谱式冲击复奏 1 次，复奏伤害为 68%。", "effects": [{"type": "damage", "value": 60, "color": "gold"}, {"type": "coins", "value": 12}], "resolution_modifier": {"repeat_count": 2, "repeat_ratio": 0.68}},
	},
	"erased_margin": {
		"id": "erased_margin", "name": "擦除边栏", "color": "gray", "rarity": "common",
		"condition": "本回合累计灰色 >=5", "effect": "净化 2 格并造成 10 伤害。", "short": "灰色 >=5",
		"condition_type": "color_total", "condition_key": "threshold", "board_color": "gray", "threshold": 5,
		"effects": [{"type": "cleanse", "value": 2}, {"type": "damage", "value": 10, "color": "gray"}], "pools": ["common", "gray", "archive_v2"],
		"upgrade": {"effect": "净化 3 格并造成 15 伤害。", "effects": [{"type": "cleanse", "value": 3}, {"type": "damage", "value": 15, "color": "gray"}]},
	},
	"dust_index": {
		"id": "dust_index", "name": "尘封索引", "color": "gray", "rarity": "common",
		"condition": "主动灰色 4 连", "effect": "净化 1 格并获得 8 护盾。", "short": "主动灰 4 连",
		"condition_type": "match_size", "condition_key": "match_size", "board_color": "gray", "match_size": 4, "active_only": true,
		"effects": [{"type": "cleanse", "value": 1}, {"type": "shield", "value": 8}], "pools": ["common", "gray", "archive_v2"],
		"upgrade": {"effect": "净化 2 格并获得 11 护盾。", "effects": [{"type": "cleanse", "value": 2}, {"type": "shield", "value": 11}]},
	},
	"censor_pressure": {
		"id": "censor_pressure", "name": "审查压痕", "color": "gray", "rarity": "rare",
		"condition": "灰蚀压力达到 4", "effect": "造成 28 伤害，灰蚀压力 -1。", "short": "灰蚀 >=4",
		"condition_type": "gray_pressure", "condition_key": "gray_pressure", "gray_pressure": 4,
		"effects": [{"type": "damage", "value": 28, "color": "gray"}, {"type": "gray_pressure", "value": -1}], "pools": ["rare", "gray", "archive_v2", "elite"],
		"upgrade": {"effect": "造成 37 伤害，灰蚀压力 -2。", "effects": [{"type": "damage", "value": 37, "color": "gray"}, {"type": "gray_pressure", "value": -2}]},
	},
	"blank_archive": {
		"id": "blank_archive", "name": "空白总档", "color": "gray", "rarity": "epic",
		"condition": "敌人本战施加过污染且本回合完成 1 张色谱", "effect": "造成 45 灰色伤害并净化 4 格；谱式结算时额外净化 1 格。", "short": "污染后完成谱",
		"condition_type": "polluted_completed", "condition_key": "completed_cards", "completed_cards": 1,
		"effects": [{"type": "damage", "value": 45, "color": "gray"}, {"type": "cleanse", "value": 4}],
		"resolution_modifier": {"cleanse": 1}, "pools": ["epic", "gray", "archive_v2", "elite"],
		"upgrade": {"effect": "造成 59 灰色伤害并净化 5 格；谱式结算时额外净化 2 格。", "effects": [{"type": "damage", "value": 59, "color": "gray"}, {"type": "cleanse", "value": 5}], "resolution_modifier": {"cleanse": 2}},
	},
	"moss_annotation": {
		"id": "moss_annotation", "name": "苔生批注", "color": "green", "rarity": "common",
		"condition": "同回合先消蓝，再消金", "effect": "回复 4 HP并获得 6 护盾。", "short": "蓝 -> 金",
		"condition_type": "color_sequence", "first_color": "blue", "second_color": "gold",
		"effects": [{"type": "heal", "value": 4}, {"type": "shield", "value": 6}], "pools": ["common", "green", "archive_v2"],
		"upgrade": {"effect": "回复 6 HP并获得 9 护盾。", "effects": [{"type": "heal", "value": 6}, {"type": "shield", "value": 9}]},
	},
	"seed_countermark": {
		"id": "seed_countermark", "name": "种籽复核章", "color": "green", "rarity": "common",
		"condition": "本回合完成 2 种学派色谱", "effect": "回复 6 HP，将 1 个灰块染为随机可用色。", "short": "完成 2 学派",
		"condition_type": "completed_colors", "condition_key": "completed_colors", "completed_colors": 2,
		"effects": [{"type": "heal", "value": 6}, {"type": "dye", "value": 1, "color": "random_player"}], "pools": ["common", "green", "archive_v2"],
		"upgrade": {"effect": "回复 8 HP，将 2 个灰块染为随机可用色。", "effects": [{"type": "heal", "value": 8}, {"type": "dye", "value": 2, "color": "random_player"}]},
	},
	"archive_germination": {
		"id": "archive_germination", "name": "档案萌发", "color": "green", "rarity": "rare",
		"condition": "HP 不高于 60%", "effect": "回复 12 HP并获得 10 护盾。", "short": "六成血以下",
		"condition_type": "hp_below", "hp_ratio": 0.60,
		"effects": [{"type": "heal", "value": 12}, {"type": "shield", "value": 10}], "pools": ["rare", "green", "archive_v2", "elite"],
		"upgrade": {"effect": "回复 16 HP并获得 13 护盾。", "effects": [{"type": "heal", "value": 16}, {"type": "shield", "value": 13}]},
	},
	"mirror_footnote": {
		"id": "mirror_footnote", "name": "镜面脚注", "color": "purple", "rarity": "common",
		"condition": "同回合先消红，再消蓝", "effect": "造成 18 伤害并抽 1 张色谱。", "short": "红 -> 蓝",
		"condition_type": "color_sequence", "first_color": "red", "second_color": "blue",
		"effects": [{"type": "damage", "value": 18, "color": "purple"}, {"type": "draw", "value": 1}], "pools": ["common", "purple", "archive_v2"],
		"upgrade": {"effect": "造成 24 伤害并抽 1 张色谱。", "effects": [{"type": "damage", "value": 24, "color": "purple"}, {"type": "draw", "value": 1}]},
	},
	"inverted_citation": {
		"id": "inverted_citation", "name": "倒置引文", "color": "purple", "rarity": "common",
		"condition": "本回合消除 2 种颜色", "effect": "造成 14 伤害并获得 6 护盾。", "short": "消除 2 色",
		"condition_type": "unique_colors", "condition_key": "unique_colors", "unique_colors": 2,
		"effects": [{"type": "damage", "value": 14, "color": "purple"}, {"type": "shield", "value": 6}], "pools": ["common", "purple", "archive_v2"],
		"upgrade": {"effect": "造成 20 伤害并获得 9 护盾。", "effects": [{"type": "damage", "value": 20, "color": "purple"}, {"type": "shield", "value": 9}]},
	},
	"counterpoint_deposition": {
		"id": "counterpoint_deposition", "name": "对位证词", "color": "purple", "rarity": "rare",
		"condition": "本回合完成 2 张色谱", "effect": "造成 30 紫色伤害并抽 1 张；谱式冲击伤害 +10%。", "short": "完成 2 张",
		"condition_type": "completed_cards", "condition_key": "completed_cards", "completed_cards": 2,
		"effects": [{"type": "damage", "value": 30, "color": "purple"}, {"type": "draw", "value": 1}],
		"resolution_modifier": {"damage_ratio_bonus": 0.10}, "pools": ["rare", "purple", "archive_v2", "elite"],
		"upgrade": {"effect": "造成 39 紫色伤害并抽 1 张；谱式冲击伤害 +12%。", "effects": [{"type": "damage", "value": 39, "color": "purple"}, {"type": "draw", "value": 1}], "resolution_modifier": {"damage_ratio_bonus": 0.12}},
	},
	"unsealed_page": {
		"id": "unsealed_page", "name": "解封白页", "color": "white", "rarity": "common",
		"condition": "本回合累计灰色 >=4", "effect": "净化 2 格并获得 6 护盾。", "short": "灰色 >=4",
		"condition_type": "color_total", "condition_key": "threshold", "board_color": "gray", "threshold": 4,
		"effects": [{"type": "cleanse", "value": 2}, {"type": "shield", "value": 6}], "pools": ["common", "white", "archive_v2"],
		"upgrade": {"effect": "净化 3 格并获得 9 护盾。", "effects": [{"type": "cleanse", "value": 3}, {"type": "shield", "value": 9}]},
	},
	"daylight_crossref": {
		"id": "daylight_crossref", "name": "白昼互证", "color": "white", "rarity": "rare",
		"condition": "本回合完成 3 种学派色谱", "effect": "净化 3 格并造成 24 伤害。", "short": "完成 3 学派",
		"condition_type": "completed_colors", "condition_key": "completed_colors", "completed_colors": 3,
		"effects": [{"type": "cleanse", "value": 3}, {"type": "damage", "value": 24, "color": "white"}], "pools": ["rare", "white", "archive_v2", "elite"],
		"upgrade": {"effect": "净化 4 格并造成 32 伤害。", "effects": [{"type": "cleanse", "value": 4}, {"type": "damage", "value": 32, "color": "white"}]},
	},
	"archivist_absolution": {
		"id": "archivist_absolution", "name": "档案员赦令", "color": "white", "rarity": "rare",
		"condition": "敌人本战施加过污染且本回合完成 1 张色谱", "effect": "回复 8 HP并净化 3 格。", "short": "污染后完成谱",
		"condition_type": "polluted_completed", "condition_key": "completed_cards", "completed_cards": 1,
		"effects": [{"type": "heal", "value": 8}, {"type": "cleanse", "value": 3}], "pools": ["rare", "white", "archive_v2", "elite"],
		"upgrade": {"effect": "回复 11 HP并净化 4 格。", "effects": [{"type": "heal", "value": 11}, {"type": "cleanse", "value": 4}]},
	},
	"final_index": {
		"id": "final_index", "name": "终局总索引", "color": "white", "rarity": "epic",
		"condition": "本回合消除红、蓝、金、灰四种颜色", "effect": "造成 48 白色伤害并获得 1 颜料；谱式结算时额外净化 1 格。", "short": "消除 4 色",
		"condition_type": "unique_colors", "condition_key": "unique_colors", "unique_colors": 4,
		"effects": [{"type": "damage", "value": 48, "color": "white"}, {"type": "pigment", "value": 1}],
		"resolution_modifier": {"cleanse": 1}, "pools": ["epic", "white", "archive_v2", "elite"],
		"upgrade": {"effect": "造成 63 白色伤害并获得 1 颜料；谱式结算时额外净化 2 格。", "effects": [{"type": "damage", "value": 63, "color": "white"}, {"type": "pigment", "value": 1}], "resolution_modifier": {"cleanse": 2}},
	},
	"debt_annotation": {
		"id": "debt_annotation", "name": "债务批注", "color": "black", "rarity": "common",
		"condition": "持有至少 35 金币", "effect": "失去 2 HP，获得 8 金币。", "short": "金币 >=35",
		"condition_type": "coins_min", "condition_key": "coins_min", "coins_min": 35,
		"effects": [{"type": "self_damage", "value": 2}, {"type": "coins", "value": 8}], "pools": ["common", "black", "archive_v2"],
		"upgrade": {"effect": "失去 1 HP，获得 11 金币。", "effects": [{"type": "self_damage", "value": 1}, {"type": "coins", "value": 11}]},
	},
	"ink_witness": {
		"id": "ink_witness", "name": "墨迹证人", "color": "black", "rarity": "rare",
		"condition": "灰蚀压力达到 5", "effect": "失去 2 HP，造成 32 伤害。", "short": "灰蚀 >=5",
		"condition_type": "gray_pressure", "condition_key": "gray_pressure", "gray_pressure": 5,
		"effects": [{"type": "self_damage", "value": 2}, {"type": "damage", "value": 32, "color": "black"}], "pools": ["rare", "black", "archive_v2", "elite"],
		"upgrade": {"effect": "失去 1 HP，造成 42 伤害。", "effects": [{"type": "self_damage", "value": 1}, {"type": "damage", "value": 42, "color": "black"}]},
	},
	"erased_oath": {
		"id": "erased_oath", "name": "删改誓词", "color": "black", "rarity": "rare",
		"condition": "最后 1 步完成任意色谱", "effect": "失去 2 HP，造成 34 黑色伤害；本次谱式冲击无视护甲。", "short": "最后 1 步完成",
		"condition_type": "moves_left_after", "moves_left_after_max": 0, "completed_cards_min": 1,
		"effects": [{"type": "self_damage", "value": 2}, {"type": "damage", "value": 34, "color": "black"}],
		"resolution_modifier": {"armor_break": 1}, "pools": ["rare", "black", "archive_v2", "elite"],
		"upgrade": {"effect": "失去 1 HP，造成 45 黑色伤害；本次谱式冲击无视护甲。", "effects": [{"type": "self_damage", "value": 1}, {"type": "damage", "value": 45, "color": "black"}], "resolution_modifier": {"armor_break": 2}},
	},
	"void_receipt": {
		"id": "void_receipt", "name": "虚无回执", "color": "black", "rarity": "rare",
		"condition": "敌人燃烧达到 2 层", "effect": "造成 28 伤害并获得 8 金币，灰蚀压力 +1。", "short": "燃烧 >=2",
		"condition_type": "enemy_burn", "condition_key": "enemy_burn_stacks", "enemy_burn_stacks": 2,
		"effects": [{"type": "damage", "value": 28, "color": "black"}, {"type": "coins", "value": 8}, {"type": "gray_pressure", "value": 1}], "pools": ["rare", "black", "archive_v2", "elite"],
		"upgrade": {"effect": "造成 37 伤害并获得 10 金币，灰蚀压力 +1。", "effects": [{"type": "damage", "value": 37, "color": "black"}, {"type": "coins", "value": 10}, {"type": "gray_pressure", "value": 1}]},
	},
	"erased_index_curse": {
		"id": "erased_index_curse", "name": "被刮去的索引", "color": "black", "rarity": "epic",
		"condition": "灰蚀压力达到 4", "effect": "失去 3 HP，灰蚀压力 +1。", "short": "灰蚀 >=4",
		"condition_type": "gray_pressure", "condition_key": "gray_pressure", "gray_pressure": 4,
		"effects": [{"type": "self_damage", "value": 3}, {"type": "gray_pressure", "value": 1}], "pools": ["curse", "event", "archive_v2"],
		"upgrade": {"effect": "失去 2 HP，灰蚀压力 +1。", "effects": [{"type": "self_damage", "value": 2}, {"type": "gray_pressure", "value": 1}]},
	},
	"blank_testimony_curse": {
		"id": "blank_testimony_curse", "name": "空白证词", "color": "gray", "rarity": "epic",
		"condition": "敌人本战施加过污染且本回合完成 1 张色谱", "effect": "失去 4 HP。", "short": "污染后完成谱",
		"condition_type": "polluted_completed", "condition_key": "completed_cards", "completed_cards": 1,
		"effects": [{"type": "self_damage", "value": 4}], "pools": ["curse", "event", "archive_v2"],
		"upgrade": {"effect": "失去 3 HP。", "effects": [{"type": "self_damage", "value": 3}]},
	},
	"obsidian_contract": {
		"id": "obsidian_contract",
		"name": "黑曜契约",
		"color": "black",
		"rarity": "epic",
		"condition": "剩余 1 步时完成色谱",
		"effect": "失去 3 HP，造成 35 伤害。",
		"short": "最后 1 步触发",
		"moves_left": 1,
		"hp_cost": 3,
		"damage": 35,
		"pools": ["curse", "event"],
		"upgrade": {
			"effect": "失去 2 HP，造成 48 伤害。",
			"hp_cost": 2,
			"damage": 48,
		},
	},
}

const RELICS: Dictionary = {
	"split_prism": {
		"id": "split_prism",
		"name": "裂色棱镜",
		"rarity": "common",
		"description": "每场第一次完成混色谱时抽 1 张。",
	},
	"warm_charm": {
		"id": "warm_charm",
		"name": "余温护符",
		"rarity": "common",
		"description": "燃烧结算时若敌人燃烧 >=3，获得 4 护盾。",
	},
	"mist_bell": {
		"id": "mist_bell",
		"name": "破雾铃",
		"rarity": "common",
		"description": "每场第一次污染发生后，净化 1 格并获得 1 颜料。",
	},
	"frozen_watch": {
		"id": "frozen_watch",
		"name": "冻裂怀表",
		"rarity": "rare",
		"description": "打断蓄力后返还 1 步，每场最多 1 次。",
	},
	"merchant_seal": {
		"id": "merchant_seal",
		"name": "商会印章",
		"rarity": "rare",
		"description": "删谱首次半价；金色收益软上限 +20%。",
	},
	"ash_pot": {
		"id": "ash_pot",
		"name": "灰烬花盆",
		"rarity": "rare",
		"description": "敌人污染后有 30% 将 1 个灰块转为可用颜色。",
	},
	"gate_badge": {
		"id": "gate_badge",
		"name": "镇门旧徽",
		"rarity": "common",
		"description": "Boss 前营火显示完整意图与抗性侦察。",
	},
	"colorless_crown": {
		"id": "colorless_crown",
		"name": "无色冠冕",
		"rarity": "boss",
		"description": "第一章通关印记；后续章节将解锁额外保留。",
	},
	"red_hilt": {
		"id": "red_hilt",
		"name": "红釉剑柄",
		"rarity": "common",
		"description": "主动红色 4 连额外获得 1 红色素，并计入技能充能。",
	},
	"blue_shawl": {
		"id": "blue_shawl",
		"name": "蓝纹披肩",
		"rarity": "common",
		"description": "回合结束时若有护盾，保留 3 点到下一回合。",
	},
	"gold_ledger": {
		"id": "gold_ledger",
		"name": "金账本",
		"rarity": "common",
		"description": "每完成 3 次购买后获得 1 颜料。",
	},
	"gray_goblet": {
		"id": "gray_goblet",
		"name": "灰石酒杯",
		"rarity": "common",
		"description": "消除灰色时有 20% 概率回复 1 HP。",
	},
	"molten_ring": {
		"id": "molten_ring",
		"name": "熔火戒",
		"rarity": "rare",
		"description": "升级后的红色色谱每场第一次触发时，追加 1 层燃烧。",
	},
	"still_lake_seal": {
		"id": "still_lake_seal",
		"name": "静湖印",
		"rarity": "rare",
		"description": "冻结敌人时抽 1 张色谱，每场最多 2 次。",
	},
	"gilded_key": {
		"id": "gilded_key",
		"name": "镀金钥匙",
		"rarity": "rare",
		"description": "开启宝箱时可以选择金币或遗物。",
	},
	"white_feather": {
		"id": "white_feather",
		"name": "净白羽",
		"rarity": "rare",
		"description": "每章第一次灰蚀压力达到 6 时，清除 3 点灰蚀压力。",
	},
	"obsidian_cup": {
		"id": "obsidian_cup",
		"name": "黑曜杯",
		"rarity": "rare",
		"description": "每场战斗第一次自伤效果的收益翻倍。",
	},
	"color_thread": {
		"id": "color_thread",
		"name": "彩线轴",
		"rarity": "common",
		"description": "同回合消除红、蓝、金三色时获得 5 护盾。",
	},
	"old_score": {
		"id": "old_score",
		"name": "旧乐谱",
		"rarity": "common",
		"description": "镇魂短句类效果额外造成 4 伤害。",
	},
	"travel_bell": {
		"id": "travel_bell",
		"name": "旅商铃",
		"rarity": "common",
		"description": "商店额外展示 1 件商品。",
	},
	"torn_banner": {
		"id": "torn_banner",
		"name": "残破王旗",
		"rarity": "boss",
		"description": "每章 Boss 战后选择复制或升级 1 张色谱。",
	},
	"four_color_die": {
		"id": "four_color_die",
		"name": "四色骰",
		"rarity": "rare",
		"description": "每回合随机 1 张手牌的首项数值条件 -1（最低为 1）。",
	},
	"cracked_abacus": {
		"id": "cracked_abacus",
		"name": "裂纹算盘",
		"rarity": "common",
		"description": "金币低于 20 时，金色色谱效果 +25%。",
	},
	"finale_crown": {
		"id": "finale_crown",
		"name": "终幕花冠",
		"rarity": "boss",
		"description": "最终 Boss 战前，按最低颜色倾向比例获得护盾。",
	},
	"seed_satchel": {
		"id": "seed_satchel", "name": "种籽挎包", "rarity": "common",
		"description": "每场战斗开始时回复 4 HP。",
	},
	"moss_circlet": {
		"id": "moss_circlet", "name": "苔纹环", "rarity": "common",
		"description": "每回合首次主动完成蓝色 4 连时获得 4 护盾。",
	},
	"renewal_flask": {
		"id": "renewal_flask", "name": "复苏瓶", "rarity": "rare",
		"description": "领取战斗奖励时回复 4 HP。",
	},
	"gardener_knife": {
		"id": "gardener_knife", "name": "园丁短刀", "rarity": "common",
		"description": "每完成一张翠生色谱，获得 2 护盾。",
	},
	"root_token": {
		"id": "root_token", "name": "根须护符", "rarity": "rare",
		"description": "获得时最大 HP +6，并回复 6 HP。",
	},
	"evergreen_score": {
		"id": "evergreen_score", "name": "常青谱页", "rarity": "rare",
		"description": "翠生色谱的回复量 +2。",
	},
	"echo_metronome": {
		"id": "echo_metronome", "name": "回声节拍器", "rarity": "common",
		"description": "每场首次触发 2 级以上级联时抽 1 张色谱。",
	},
	"dusk_mask": {
		"id": "dusk_mask", "name": "暮色面具", "rarity": "common",
		"description": "每场首次受到敌人伤害时，伤害减少 6。",
	},
	"mirror_string": {
		"id": "mirror_string", "name": "镜像琴弦", "rarity": "rare",
		"description": "紫弦色谱造成的伤害 +4。",
	},
	"violet_ticket": {
		"id": "violet_ticket", "name": "紫幕通票", "rarity": "common",
		"description": "获得时增加 2 次免费商店刷新。",
	},
	"cadenza_lens": {
		"id": "cadenza_lens", "name": "华彩透镜", "rarity": "rare",
		"description": "每场首次在一回合完成 3 张色谱时获得 8 护盾。",
	},
	"paradox_coin": {
		"id": "paradox_coin", "name": "悖论硬币", "rarity": "rare",
		"description": "每完成一张紫弦色谱，获得 3 金币。",
	},
	"purity_sigil": {
		"id": "purity_sigil", "name": "纯净印", "rarity": "common",
		"description": "白昼色谱的净化数量 +1。",
	},
	"balanced_scale": {
		"id": "balanced_scale", "name": "三色天平", "rarity": "rare",
		"description": "每场首次在同回合消除红、蓝、金时回复 5 HP。",
	},
	"dawn_candle": {
		"id": "dawn_candle", "name": "黎明烛", "rarity": "common",
		"description": "灰蚀压力不高于 3 时，战斗开始获得 7 护盾。",
	},
	"ivory_key": {
		"id": "ivory_key", "name": "象牙钥", "rarity": "common",
		"description": "获得时立即获得 2 颜料。",
	},
	"white_lantern": {
		"id": "white_lantern", "name": "净白提灯", "rarity": "rare",
		"description": "敌人的每次污染数量减少 1，最低为 1。",
	},
	"clear_quill": {
		"id": "clear_quill", "name": "澄明羽笔", "rarity": "common",
		"description": "跳过战斗色谱奖励时额外获得 5 金币。",
	},
	"ink_razor": {
		"id": "ink_razor", "name": "墨锋", "rarity": "common",
		"description": "黑曜色谱造成的伤害 +6。",
	},
	"debtor_seal": {
		"id": "debtor_seal", "name": "债户封蜡", "rarity": "common",
		"description": "每完成一张黑曜色谱，获得 3 金币。",
	},
	"abyss_chain": {
		"id": "abyss_chain", "name": "深渊锁链", "rarity": "rare",
		"description": "每完成一张黑曜色谱，获得 4 护盾。",
	},
	"ash_contract": {
		"id": "ash_contract", "name": "灰账契据", "rarity": "common",
		"description": "获得时得到 30 金币，但灰蚀压力 +2。",
	},
	"night_coin": {
		"id": "night_coin", "name": "夜面币", "rarity": "rare",
		"description": "敌人的偷取数量降低 50%。",
		"archive_v2": true, "archive_note": "债册第二区的公证费，正反两面分别刻着债主与债户。",
	},
	"eclipse_vial": {
		"id": "eclipse_vial", "name": "蚀光瓶", "rarity": "rare",
		"description": "每场战斗第一次色谱自伤减少 2。",
	},
	"flare_nozzle": {"id": "flare_nozzle", "name": "赤焰喷口", "rarity": "common", "description": "红焰色谱的谱式冲击额外造成 3 伤害。"},
	"mirror_baffle": {"id": "mirror_baffle", "name": "镜湖折流板", "rarity": "common", "description": "蓝霜色谱结算时额外获得 3 护盾。"},
	"profit_pin": {"id": "profit_pin", "name": "悬赏印花", "rarity": "common", "description": "金辉色谱结算时额外获得 1 金币。"},
	"mist_ram": {"id": "mist_ram", "name": "雾核撞角", "rarity": "common", "description": "灰蚀色谱的谱式冲击无视护甲。"},
	"prism_splitter": {"id": "prism_splitter", "name": "棱镜分光器", "rarity": "rare", "description": "混色与白昼色谱的谱式冲击额外造成 6 伤害。"},
	"critical_ink": {"id": "critical_ink", "name": "临界墨滴", "rarity": "rare", "description": "所有色谱的谱式冲击额外造成 4 伤害。"},
	"echo_spring": {"id": "echo_spring", "name": "回声簧片", "rarity": "common", "description": "触发谱序共鸣时额外造成 2 伤害。"},
	"hazard_lining": {"id": "hazard_lining", "name": "侵谱衬层", "rarity": "common", "description": "敌人施加封谱、侵谱或错调时获得 4 护盾。"},
	"first_orbit": {"id": "first_orbit", "name": "首发索引", "rarity": "rare", "description": "每场战斗首张完成的色谱，其谱式冲击额外造成 8 伤害。", "archive_v2": true, "archive_note": "乐监的勘误把被删去的第一拍保留为原始证词。"},
	"queue_bell": {"id": "queue_bell", "name": "三谱应答铃", "rarity": "rare", "description": "每回合完成第 3 张及后续色谱时，谱式冲击额外造成 4 伤害。"},
	"rebound_thread": {"id": "rebound_thread", "name": "折返丝线", "rarity": "common", "description": "由 2 级及以上级联完成色谱时，谱式冲击额外造成 4 伤害。"},
	"spectrum_core": {"id": "spectrum_core", "name": "三色核心", "rarity": "rare", "description": "同回合消除红蓝金三色后，角色技充能 +4。"},
	"cinder_compass": {"id": "cinder_compass", "name": "余烬罗盘", "rarity": "common", "description": "红焰色谱结算时额外施加 1 层燃烧。"},
	"mist_filter": {"id": "mist_filter", "name": "雾幕滤芯", "rarity": "common", "description": "灰蚀色谱结算时额外净化 1 格。", "archive_v2": true, "archive_note": "滤出的灰尘分属两个年代，证明灰蚀早于灰蚀龙苏醒。"},
	"reflection_seal": {"id": "reflection_seal", "name": "倒影封蜡", "rarity": "common", "description": "混色与白昼色谱的谱式冲击无视护甲。"},
	"bumper_core": {"id": "bumper_core", "name": "回环轴心", "rarity": "common", "description": "每张色谱结算时额外获得 2 护盾。"},
	"resistance_key": {"id": "resistance_key", "name": "抗性音叉", "rarity": "rare", "description": "混色与白昼色谱结算时清除敌人的颜色抗性。"},
	"lockpick_gear": {"id": "lockpick_gear", "name": "王锁齿轮", "rarity": "common", "description": "所有色谱的谱式冲击无视护甲。"},
	"void_anchor": {"id": "void_anchor", "name": "虚无锚", "rarity": "rare", "description": "黑曜色谱结算时额外获得 4 护盾。"},
	"hazard_capacitor": {"id": "hazard_capacitor", "name": "侵谱电容", "rarity": "rare", "description": "侵谱干扰不再降低谱式伤害，并额外造成 3 伤害。", "archive_v2": true, "archive_note": "追偿令允许债户用一次危险抉择抵销旧债。"},
	"phase_tuning_fork": {"id": "phase_tuning_fork", "name": "换相音叉", "rarity": "boss", "description": "Boss 每次进入新阶段后，首张完成色谱的谱式冲击额外造成 10 伤害。", "archive_v2": true, "archive_note": "最后一位读者用它标记每段被删改的首领证词。"},
	"aim_gyroscope": {"id": "aim_gyroscope", "name": "校准陀螺", "rarity": "common", "description": "敌方错调造成的谱式减伤降低 50%。", "archive_v2": true, "archive_note": "镜湖勘误表证明错拍并非误差，而是一种拒绝。"},
	"queue_limiter": {"id": "queue_limiter", "name": "四谱限位器", "rarity": "rare", "description": "每回合完成第 4 张及后续色谱时，谱式冲击额外造成 6 伤害。", "archive_v2": true, "archive_note": "终幕工坊用它保存没有席位的第四声部。"},
	"trajectory_lens": {"id": "trajectory_lens", "name": "谱序透镜", "rarity": "rare", "description": "调律预览会标记本回合最接近完成的色谱。"},
}

const CHAPTERS: Dictionary = {
	"C1": {"name": "第一章：灰雾边境", "theme": "灰雾、启程与四色基础"},
	"C2": {"name": "第二章：镜湖工坊", "theme": "护盾、经济与颜色抗性"},
	"C3": {"name": "第三章：无色王庭", "theme": "高压意图、灰蚀与终局构筑"},
}

const EVENTS: Dictionary = {
	"shrine": {
		"title": "褪色神龛", "body": "神龛能净化牌组，也会索取生命。",
		"choices": [{"id": "cleanse", "label": "-8 HP，净化 1 张"}, {"id": "resource", "label": "+1 颜料，下战污染 +2"}],
	},
	"colorist": {
		"title": "流浪调色师", "body": "他愿意帮你把路线染得更鲜明。",
		"choices": [{"id": "dye", "label": "35 金币 +1 颜料：染色"}, {"id": "skip", "label": "跳过：+12 金币"}],
	},
	"gallery": {
		"title": "破碎画廊", "body": "画框里有稀有遗物，也有黑曜代价。",
		"choices": [{"id": "relic", "label": "拿稀有遗物，加入黑曜契约"}, {"id": "heal", "label": "回复 20 HP"}],
	},
	"pigment_well": {
		"title": "颜料井", "body": "井底漂着尚未凝固的四色颜料。",
		"choices": [{"id": "draw", "label": "失去 6 HP，获得 2 颜料", "hp": -6, "pigment": 2}, {"id": "seal", "label": "封住井口，获得 18 金币", "coins": 18}],
	},
	"frozen_archive": {
		"title": "冰封谱库", "body": "冻结的旧谱仍保留着一段完整旋律。",
		"choices": [{"id": "study", "label": "获得随机蓝色色谱，灰蚀压力 +1", "card_pool": ["blue"], "gray_pressure": 1}, {"id": "melt", "label": "熔解封印，回复 24 HP", "heal": 24}],
	},
	"silent_auction": {
		"title": "静默拍卖", "body": "竞价者以手势交换遗物与颜料。",
		"choices": [{"id": "bid", "label": "支付 65 金币，获得随机稀有遗物", "coin_cost": 65, "relic_pool": ["rare"]}, {"id": "sell", "label": "出售 1 颜料，获得 32 金币", "pigment_cost": 1, "coins": 32}],
	},
	"mirror_lake": {
		"title": "镜湖倒影", "body": "倒影会复制你最克制的颜色。",
		"choices": [{"id": "touch", "label": "回复 18 HP，灰蚀压力 +2", "heal": 18, "gray_pressure": 2}, {"id": "observe", "label": "获得 1 颜料与随机混色色谱", "pigment": 1, "card_pool": ["mixed"]}],
	},
	"caravan_debt": {
		"title": "商队旧债", "body": "账本上仍留着上一位勇者的名字。",
		"choices": [{"id": "borrow", "label": "获得 55 金币，加入黑曜契约", "coins": 55, "card_id": "obsidian_contract"}, {"id": "settle", "label": "支付 30 金币，获得 2 颜料", "coin_cost": 30, "pigment": 2}],
	},
	"crimson_stage": {
		"title": "猩红舞台", "body": "空舞台要求以生命换取最后一段强音。",
		"choices": [{"id": "perform", "label": "失去 12 HP，获得随机红色稀有色谱", "hp": -12, "card_pool": ["red", "rare"]}, {"id": "rest", "label": "回复 26 HP", "heal": 26}],
	},
	"nameless_gallery": {
		"title": "无名画廊", "body": "每幅画都在抹去观者的一部分。",
		"choices": [{"id": "accept", "label": "灰蚀压力 +3，获得随机稀有遗物", "gray_pressure": 3, "relic_pool": ["rare"]}, {"id": "leave", "label": "离开并获得 24 金币", "coins": 24}],
	},
	"final_workshop": {
		"title": "终幕工坊", "body": "工坊只允许完成最后一次不可逆校准。",
		"choices": [{"id": "temper", "label": "最大 HP -8，获得终幕花冠", "max_hp": -8, "relic_id": "finale_crown"}, {"id": "repair", "label": "回复 35 HP", "heal": 35}],
	},
	"chorus_echo": {
		"title": "合唱残响", "body": "王庭墙壁重复着你一路使用最少的颜色。",
		"choices": [{"id": "answer", "label": "获得随机混色色谱与 1 颜料", "card_pool": ["mixed"], "pigment": 1}, {"id": "silence", "label": "获得 40 金币", "coins": 40}],
	},
	"seed_vault": {
		"title": "种籽密库", "body": "密库用生命温度保存已经绝迹的翠色。",
		"choices": [{"id": "graft", "label": "失去 8 HP，最大 HP +6，获得翠生色谱", "hp": -8, "max_hp": 6, "card_pool": ["green"]}, {"id": "harvest", "label": "获得 25 金币与 1 颜料", "coins": 25, "pigment": 1}],
	},
	"broken_metronome": {
		"title": "失拍节拍器", "body": "摆锤每一次反向，都让附近的声音晚到半拍。",
		"choices": [{"id": "repair", "label": "支付 35 金币，获得紫弦色谱与 1 颜料", "coin_cost": 35, "card_pool": ["purple"], "pigment": 1}, {"id": "wind", "label": "强行上弦：获得 45 金币，灰蚀 +2", "coins": 45, "gray_pressure": 2}],
	},
	"white_procession": {
		"title": "白昼巡礼", "body": "巡礼者只接受不能被撤回的交换。",
		"choices": [{"id": "confess", "label": "最大 HP -5，获得白昼色谱并回复 20 HP", "max_hp": -5, "card_pool": ["white"], "heal": 20}, {"id": "pass", "label": "目送队伍离开，获得 28 金币", "coins": 28}],
	},
	"black_notary": {
		"title": "黑墨公证人", "body": "他保证每一项代价都会在最糟糕的时候兑现。",
		"choices": [{"id": "sign", "label": "获得 60 金币与黑曜色谱，灰蚀 +2", "coins": 60, "card_pool": ["black"], "gray_pressure": 2}, {"id": "refuse", "label": "拒绝签字：回复 15 HP，获得 1 颜料", "heal": 15, "pigment": 1}],
	},
	"colorless_orchestra": {
		"title": "无色乐团", "body": "幕布后还有第二段演出，入场券是一小瓶颜料。",
		"choices": [{"id": "listen", "label": "交出 1 颜料，进入后台", "pigment_cost": 1, "chain_event": "orchestra_backstage"}, {"id": "leave", "label": "出售入场券，获得 32 金币", "coins": 32}],
	},
	"orchestra_backstage": {
		"title": "乐团后台", "body": "调音师允许你带走一种不会出现在棋盘上的声音。",
		"choices": [{"id": "tune", "label": "最大 HP +4，获得角色专属色谱", "max_hp": 4, "character_pool": true}, {"id": "encore", "label": "失去 10 HP，获得随机稀有遗物", "hp": -10, "relic_pool": ["rare"]}],
	},
	"character_mirror": {
		"title": "本色镜", "body": "镜中人没有复制外貌，只复制了你的战斗习惯。",
		"choices": [{"id": "accept", "label": "获得角色专属色谱，灰蚀 +1", "character_pool": true, "gray_pressure": 1}, {"id": "shatter", "label": "击碎镜面：获得 2 颜料", "pigment": 2}],
	},
	"refraction_forge": {
		"title": "折光锻台", "body": "锻台能精研旧谱，也能压出一张新学派谱。",
		"choices": [{"id": "temper", "label": "支付 45 金币，随机精研 1 张色谱", "coin_cost": 45, "upgrade_random": true}, {"id": "press", "label": "失去 6 HP，获得翠生或白昼色谱", "hp": -6, "card_pool": ["green", "white"]}],
	},
	"duelist_wake": {
		"title": "决斗家守灵夜", "body": "火盆里同时燃着红焰与黑墨。",
		"choices": [{"id": "challenge", "label": "失去 10 HP，获得红焰或黑曜稀有色谱", "hp": -10, "card_pool": ["red", "black", "rare"]}, {"id": "guard", "label": "守完长夜：获得 16 护盾与 18 金币", "shield": 16, "coins": 18}],
	},
	"frozen_clock": {
		"title": "冰封钟室", "body": "停摆的钟把未来两次交易留在了现在。",
		"choices": [{"id": "rewind", "label": "最大 HP -4，获得蓝霜或紫弦色谱", "max_hp": -4, "card_pool": ["blue", "purple"]}, {"id": "borrow", "label": "获得 2 次免费商店刷新", "free_shop_refreshes": 2}],
	},
	"merchant_crossroad": {
		"title": "无旗商路", "body": "两支商队都声称另一支在出售赝品。",
		"choices": [{"id": "trade", "label": "支付 30 金币，获得金辉色谱与 1 颜料", "coin_cost": 30, "card_pool": ["gold"], "pigment": 1}, {"id": "inspect", "label": "支付 55 金币，获得随机普通遗物", "coin_cost": 55, "relic_pool": ["common"]}],
	},
	"mist_shelter": {
		"title": "雾中避难所", "body": "这里的灰雾不会伤人，却会让人舍不得离开。",
		"choices": [{"id": "rest", "label": "回复 30 HP，灰蚀压力 +1", "heal": 30, "gray_pressure": 1}, {"id": "clean", "label": "支付 1 颜料，灰蚀压力 -3", "pigment_cost": 1, "gray_pressure_delta": -3}],
	},
	"pegsmith": {
		"title": "谱式调律师", "body": "调律师能改变色谱结算时的强奏与破甲方式。",
		"choices": [{"id": "critical", "label": "支付 38 金币，强奏调律 +1", "coin_cost": 38, "peg_upgrade": "critical"}, {"id": "pierce", "label": "失去 7 HP，破甲调律 +1", "hp": -7, "peg_upgrade": "pierce"}],
	},
	"echo_well": {
		"title": "回声深井", "body": "井壁会把一次谱序共鸣延伸成更长的尾音。",
		"choices": [{"id": "listen", "label": "支付 1 颜料，共鸣调律 +1", "pigment_cost": 1, "peg_upgrade": "echo"}, {"id": "seal", "label": "封井并获得 34 金币", "coins": 34}],
	},
	"bounty_lane": {
		"title": "悬赏谱道", "body": "每一枚金色谱印都写着不同债主的名字。",
		"choices": [{"id": "invest", "label": "支付 45 金币，金辉调律 +1", "coin_cost": 45, "peg_upgrade": "bounty"}, {"id": "collect", "label": "获得悬赏印花，灰蚀 +1", "relic_id": "profit_pin", "gray_pressure": 1}],
	},
	"prism_vendor": {
		"title": "分光行商", "body": "行商出售一台能强化混色与白昼谱式的旧机器。",
		"choices": [{"id": "buy", "label": "支付 72 金币，获得棱镜分光器", "coin_cost": 72, "relic_id": "prism_splitter"}, {"id": "trade", "label": "交出 1 颜料，获得临界墨滴", "pigment_cost": 1, "relic_id": "critical_ink"}],
	},
	"mist_foundry": {
		"title": "雾核铸坊", "body": "雾核压印可以清理污染，也可能压伤持有者。",
		"choices": [{"id": "ram", "label": "失去 8 HP，获得雾核撞角", "hp": -8, "relic_id": "mist_ram"}, {"id": "lining", "label": "支付 36 金币，获得侵谱衬层", "coin_cost": 36, "relic_id": "hazard_lining"}],
	},
	"silent_board": {
		"title": "静默谱架", "body": "谱架上没有声音，只有第一张索引仍在发光。",
		"choices": [{"id": "orbit", "label": "最大 HP -5，获得首发索引", "max_hp": -5, "relic_id": "first_orbit"}, {"id": "spring", "label": "获得回声簧片，灰蚀 +2", "relic_id": "echo_spring", "gray_pressure": 2}],
	},
	"cinder_switchyard": {
		"title": "余烬道岔", "body": "三段余烬谱句不断交换先后次序。",
		"choices": [{"id": "compass", "label": "支付 42 金币，获得余烬罗盘", "coin_cost": 42, "relic_id": "cinder_compass"}, {"id": "score", "label": "失去 6 HP，获得焰谱突进", "hp": -6, "card_id": "flame_lane"}],
	},
	"mist_calibration": {
		"title": "雾层校准台", "body": "滤芯能辨认灰蚀，也能把污染重新压回谱页。",
		"choices": [{"id": "filter", "label": "支付 1 颜料，获得雾幕滤芯", "pigment_cost": 1, "relic_id": "mist_filter"}, {"id": "drill", "label": "灰蚀 +1，获得雾层钻头", "gray_pressure": 1, "card_id": "mist_borer"}],
	},
	"mirror_workbench": {
		"title": "镜湖折返台", "body": "工匠把同一段消除顺序刻在镜面两侧。",
		"choices": [{"id": "seal", "label": "支付 48 金币，获得倒影封蜡", "coin_cost": 48, "relic_id": "reflection_seal"}, {"id": "duet", "label": "最大 HP -4，获得折光二重奏", "max_hp": -4, "card_id": "refracted_duet"}],
	},
	"bumper_exchange": {
		"title": "回环交换所", "body": "每一次级联都可以换成护盾、金币或更强的谱式。",
		"choices": [{"id": "core", "label": "支付 38 金币，获得回环轴心", "coin_cost": 38, "relic_id": "bumper_core"}, {"id": "dividend", "label": "交出 1 颜料，获得回声分红", "pigment_cost": 1, "card_id": "echo_dividend"}],
	},
	"royal_lockshop": {
		"title": "王锁修理铺", "body": "废弃王锁仍记得怎样封住一段谱式。",
		"choices": [{"id": "gear", "label": "支付 46 金币，获得王锁齿轮", "coin_cost": 46, "relic_id": "lockpick_gear"}, {"id": "score", "label": "灰蚀 +2，获得王锁解谱", "gray_pressure": 2, "card_id": "royal_lockpick"}],
	},
	"void_mooring": {
		"title": "虚无泊位", "body": "锚链的一端消失在无色王庭之外。",
		"choices": [{"id": "anchor", "label": "最大 HP -5，获得虚无锚", "max_hp": -5, "relic_id": "void_anchor"}, {"id": "capacitor", "label": "支付 55 金币，获得侵谱电容", "coin_cost": 55, "relic_id": "hazard_capacitor"}],
	},
	"ash_origin_record": {
		"title": "第五行刮痕", "body": "神龛拓片的第五行被反复刮除。余烬仍沿着一个名字的笔画发亮。",
		"rarity": "common", "chapter_id": "C1", "chain_id": "CHAIN-ASH-ORIGIN", "chain_stage": 1, "fragment_id": "FR-001",
		"choices": [
			{"id": "trace", "label": "失去 6 HP，沿余烬取得白昼色谱", "hp": -6, "card_pool": ["white"]},
			{"id": "seal", "label": "封存拓片：获得 1 颜料，灰蚀 +1", "pigment": 1, "gray_pressure": 1},
		],
	},
	"mirror_witness_oath": {
		"title": "本色镜宣誓", "body": "镜中的你先开口，却坚持自己才是被留下的原件。",
		"rarity": "common", "chapter_id": "C1", "chain_id": "CHAIN-MIRROR-WITNESS", "chain_stage": 1, "fragment_id": "FR-019",
		"choices": [
			{"id": "accept", "label": "承认倒影：获得角色学派色谱，灰蚀 +1", "character_pool": true, "gray_pressure": 1},
			{"id": "mark", "label": "在镜框刻记：获得 1 颜料与 8 护盾", "pigment": 1, "shield": 8},
		],
	},
	"debt_faded_note": {
		"title": "褪色借据", "body": "借据上的债主、债户和见证人用了同一种笔迹。",
		"rarity": "common", "chapter_id": "C1", "chain_id": "CHAIN-DEBT", "chain_stage": 1, "fragment_id": "FR-022",
		"choices": [
			{"id": "borrow", "label": "领取 30 金币，加入被刮去的索引", "coins": 30, "card_id": "erased_index_curse"},
			{"id": "settle", "label": "支付 30 金币，获得 1 颜料", "coin_cost": 30, "pigment": 1},
		],
	},
	"fourth_seat_ticket": {
		"title": "第四席旧票", "body": "票面写着四个声部，检票章却只承认其中三个。",
		"rarity": "common", "chapter_id": "C1", "chain_id": "CHAIN-ORCHESTRA", "chain_stage": 1, "fragment_id": "FR-016",
		"choices": [
			{"id": "listen", "label": "支付 1 颜料，获得角色学派色谱", "pigment_cost": 1, "character_pool": true},
			{"id": "sell", "label": "出售旧票：获得 24 金币", "coins": 24},
		],
	},
	"pegsmith_measure": {
		"title": "调律师的误差尺", "body": "尺上每一格都不同宽。调律师说，标准谱序从来只是王庭的方便说法。",
		"rarity": "common", "chapter_id": "C1", "chain_id": "CHAIN-CALIBRATION", "chain_stage": 1, "fragment_id": "FR-025",
		"choices": [
			{"id": "critical", "label": "支付 38 金币，强奏调律 +1", "coin_cost": 38, "peg_upgrade": "critical"},
			{"id": "echo", "label": "失去 6 HP，共鸣调律 +1", "hp": -6, "peg_upgrade": "echo"},
		],
	},
	"catalogue_blank_names": {
		"title": "空名目录", "body": "目录保存了页码，却把每位被调走的档案员姓名留成方框。",
		"rarity": "rare", "chapter_id": "C1", "chain_id": "CHAIN-ARCHIVE-KEEPERS", "chain_stage": 1, "fragment_id": "FR-028",
		"choices": [
			{"id": "read", "label": "读完空页：回复 24 HP", "heal": 24},
			{"id": "copy", "label": "抄下页码：获得 32 金币，灰蚀 +1", "coins": 32, "gray_pressure": 1},
		],
	},
	"ash_filter_testimony": {
		"title": "滤芯证词", "body": "旧滤芯留下两种灰：一种来自龙息，另一种早在龙醒来前就存在。",
		"rarity": "uncommon", "chapter_id": "C2", "chain_id": "CHAIN-ASH-ORIGIN", "chain_stage": 2, "fragment_id": "FR-002",
		"choices": [
			{"id": "filter", "label": "支付 1 颜料，获得雾幕滤芯", "pigment_cost": 1, "relic_id": "mist_filter"},
			{"id": "drill", "label": "失去 7 HP，获得雾层钻头", "hp": -7, "card_id": "mist_borer"},
		],
	},
	"mirror_lake_deposition": {
		"title": "镜湖口供", "body": "倒影逐句重复你的证词，唯独把“我”改成了另一个名字。",
		"rarity": "common", "chapter_id": "C2", "chain_id": "CHAIN-MIRROR-WITNESS", "chain_stage": 2, "fragment_id": "FR-020",
		"choices": [
			{"id": "stabilize", "label": "固定水面：获得 14 护盾与蓝霜色谱", "shield": 14, "card_pool": ["blue"]},
			{"id": "invert", "label": "倒转口供：最大 HP -4，获得紫弦色谱", "max_hp": -4, "card_pool": ["purple"]},
		],
	},
	"debt_registry": {
		"title": "黑墨债册", "body": "公证页显示，旧债每被偿还一次，债主的名字就会向后移动一栏。",
		"rarity": "uncommon", "chapter_id": "C2", "chain_id": "CHAIN-DEBT", "chain_stage": 2, "fragment_id": "FR-023",
		"choices": [
			{"id": "audit", "label": "支付 45 金币，获得夜面币", "coin_cost": 45, "relic_id": "night_coin"},
			{"id": "rewrite", "label": "涂改债主：获得 40 金币，灰蚀 +2", "coins": 40, "gray_pressure": 2},
		],
	},
	"backstage_missing_score": {
		"title": "后台缺谱", "body": "第四声部的谱架还在，谱页被裁成了王庭通行证。",
		"rarity": "common", "chapter_id": "C2", "chain_id": "CHAIN-ORCHESTRA", "chain_stage": 2, "fragment_id": "FR-017",
		"choices": [
			{"id": "tune", "label": "补写一段：最大 HP +3，获得混色色谱", "max_hp": 3, "card_pool": ["mixed"]},
			{"id": "encore", "label": "借走掌声：失去 10 HP，获得稀有遗物", "hp": -10, "relic_pool": ["rare"]},
		],
	},
	"mirror_recalibration": {
		"title": "镜面复校台", "body": "两组刻度互相否定，却都能完成同一张色谱。",
		"rarity": "common", "chapter_id": "C2", "chain_id": "CHAIN-CALIBRATION", "chain_stage": 2, "fragment_id": "FR-026",
		"choices": [
			{"id": "pierce", "label": "支付 42 金币，破甲调律 +1", "coin_cost": 42, "peg_upgrade": "pierce"},
			{"id": "bounty", "label": "交出 1 颜料，金辉调律 +1", "pigment_cost": 1, "peg_upgrade": "bounty"},
		],
	},
	"sealed_color_trial": {
		"title": "封色听证", "body": "听证席要求你证明：一种颜色被禁止后，其余颜色仍然自由。",
		"rarity": "rare", "chapter_id": "C2", "chain_id": "CHAIN-ARCHIVE-KEEPERS", "chain_stage": 2, "fragment_id": "FR-029",
		"choices": [
			{"id": "testify", "label": "失去 12 HP，获得白昼或黑曜色谱", "hp": -12, "card_pool": ["white", "black"]},
			{"id": "withhold", "label": "拒绝作证：获得稀有遗物，灰蚀 +2", "relic_pool": ["rare"], "gray_pressure": 2},
		],
	},
	"ash_dragon_margin": {
		"title": "龙鳞页边", "body": "灰蚀龙蜕下的鳞片刻着同一句话：我醒来时，档案已经删完。",
		"rarity": "uncommon", "chapter_id": "C3", "chain_id": "CHAIN-ASH-ORIGIN", "chain_stage": 3, "fragment_id": "FR-003",
		"choices": [
			{"id": "restore", "label": "支付 1 颜料，灰蚀 -2并获得白昼色谱", "pigment_cost": 1, "gray_pressure_delta": -2, "card_pool": ["white"]},
			{"id": "sell", "label": "出售鳞片：获得 32 金币", "coins": 32},
		],
	},
	"conductor_errata": {
		"title": "乐监勘误表", "body": "勘误表承认镜湖乐监每次挥拍都故意偏离王庭标准谱序。",
		"rarity": "uncommon", "chapter_id": "C3", "chain_id": "CHAIN-MIRROR-WITNESS", "chain_stage": 3, "fragment_id": "FR-012",
		"choices": [
			{"id": "preserve", "label": "支付 48 金币，获得校准陀螺", "coin_cost": 48, "relic_id": "aim_gyroscope"},
			{"id": "publish", "label": "最大 HP -5，获得首发索引", "max_hp": -5, "relic_id": "first_orbit"},
		],
	},
	"debt_collection": {
		"title": "王庭追偿令", "body": "追偿令没有金额，只有一句：把你从档案里借走的那个人还回来。",
		"rarity": "uncommon", "chapter_id": "C3", "chain_id": "CHAIN-DEBT", "chain_stage": 3, "fragment_id": "FR-024",
		"choices": [
			{"id": "repay", "label": "支付 45 金币，灰蚀 -2", "coin_cost": 45, "gray_pressure_delta": -2},
			{"id": "bounty", "label": "失去 14 HP，获得侵谱电容", "hp": -14, "relic_id": "hazard_capacitor"},
		],
	},
	"court_restored_score": {
		"title": "复原的第四谱", "body": "合唱墙后的残页恰好补上第四声部。它唱的不是答案，而是反对答案。",
		"rarity": "uncommon", "chapter_id": "C3", "chain_id": "CHAIN-ORCHESTRA", "chain_stage": 3, "fragment_id": "FR-018",
		"choices": [
			{"id": "restore", "label": "支付 1 颜料，获得混色或白昼色谱与 12 护盾", "pigment_cost": 1, "card_pool": ["mixed", "white"], "shield": 12},
			{"id": "silence", "label": "出售残页：获得 45 金币，灰蚀 +2", "coins": 45, "gray_pressure": 2},
		],
	},
	"final_temper_record": {
		"title": "终幕淬火记录", "body": "记录显示每一张合格色谱都曾在不合格刻度上通过测试。",
		"rarity": "common", "chapter_id": "C3", "chain_id": "CHAIN-CALIBRATION", "chain_stage": 3, "fragment_id": "FR-027",
		"choices": [
			{"id": "temper", "label": "支付 45 金币，共鸣调律 +1", "coin_cost": 45, "peg_upgrade": "echo"},
			{"id": "limit", "label": "失去 10 HP，获得四谱限位器", "hp": -10, "relic_id": "queue_limiter"},
		],
	},
	"corridor_last_reader": {
		"title": "最后一位读者", "body": "他没有脸，胸前借阅证上的照片却会变成当前持有者。",
		"rarity": "rare", "chapter_id": "C3", "chain_id": "CHAIN-ARCHIVE-KEEPERS", "chain_stage": 3, "fragment_id": "FR-030",
		"choices": [
			{"id": "inherit", "label": "最大 HP -8，获得换相音叉", "max_hp": -8, "relic_id": "phase_tuning_fork"},
			{"id": "close", "label": "替他合上目录：回复 40 HP", "heal": 40},
		],
	},
}

const ENCOUNTERS: Dictionary = {
	"C1-01": {
		"id": "C1-01",
		"name": "灰雾巡逻",
		"enemy_name": "灰雾学徒",
		"enemy_id": "EN-GR-01",
		"max_hp": 84,
		"attack": 10,
		"reward": 18,
		"reward_pool": ["common", "starter"],
		"node_type": "combat",
		"description": "基础战斗教学：攻击、燃烧、冻结、金币。",
		"intents": [
			{"type": "attack", "text": "准备攻击", "value": 10},
			{"type": "pollute", "text": "扩散灰雾", "value": 2},
			{"type": "attack", "text": "灰雾拍击", "value": 12},
		],
	},
	"C1-02A": {
		"id": "C1-02A",
		"name": "褪色犬群",
		"enemy_name": "褪色犬群",
		"enemy_id": "EN-HO-01",
		"max_hp": 115,
		"attack": 12,
		"reward": 20,
		"reward_pool": ["common"],
		"node_type": "combat",
		"description": "单体兼容的低 HP 压迫遭遇。",
		"intents": [
			{"type": "attack", "text": "犬群扑咬", "value": 12},
			{"type": "attack", "text": "围猎", "value": 14},
			{"type": "pollute", "text": "踩起灰尘", "value": 1},
		],
	},
	"C1-03A": {
		"id": "C1-03A",
		"name": "镀金盗贼",
		"enemy_name": "镀金盗贼",
		"enemy_id": "EN-GD-01",
		"max_hp": 98,
		"attack": 10,
		"reward": 24,
		"reward_pool": ["common", "gold"],
		"node_type": "combat",
		"description": "教学金色不只是收益，也会被敌人反制。",
		"intents": [
			{"type": "steal", "text": "窃取金辉", "value": 6},
			{"type": "attack", "text": "短刃攻击", "value": 10},
			{"type": "resist", "text": "金色抗性", "value": 0.35, "color": "gold"},
		],
	},
	"C1-04B": {
		"id": "C1-04B",
		"name": "霜痕哨兵",
		"enemy_name": "霜痕哨兵",
		"enemy_id": "EN-FR-01",
		"max_hp": 112,
		"attack": 12,
		"reward": 25,
		"reward_pool": ["common", "blue"],
		"node_type": "combat",
		"description": "蓄力教学：冻结可以取消重击。",
		"intents": [
			{"type": "attack", "text": "冰刃攻击", "value": 12},
			{"type": "charge", "text": "正在聚力", "value": 20},
			{"type": "heavy", "text": "霜痕重击", "value": 20},
		],
	},
	"C1-06A": {
		"id": "C1-06A",
		"name": "织雾小队",
		"enemy_name": "织雾小队",
		"enemy_id": "EN-WV-01",
		"max_hp": 132,
		"attack": 14,
		"reward": 28,
		"reward_pool": ["common", "mixed"],
		"node_type": "combat",
		"description": "Boss 前污染压力预演。",
		"intents": [
			{"type": "pollute", "text": "扩散灰雾", "value": 2},
			{"type": "attack", "text": "织雾突袭", "value": 14},
			{"type": "pollute", "text": "灰雾结网", "value": 2},
		],
	},
	"C1-05C": {
		"id": "C1-05C", "name": "灰烬搬运工", "enemy_name": "灰烬搬运工", "enemy_id": "EN-AS-01",
		"max_hp": 124, "attack": 13, "reward": 27, "reward_pool": ["common", "gray"], "node_type": "combat",
		"description": "以防御与污染交替消耗玩家资源。",
		"intents": [{"type": "defend", "text": "堆叠灰箱", "value": 16}, {"type": "pollute", "text": "倾倒灰烬", "value": 2}, {"type": "attack", "text": "沉重推击", "value": 15}],
	},
	"C1-04A": {
		"id": "C1-04A",
		"name": "霜甲卫士",
		"enemy_name": "霜甲卫士",
		"enemy_id": "EL-FR-01",
		"max_hp": 165,
		"attack": 18,
		"reward": 42,
		"reward_pool": ["rare", "blue", "elite"],
		"node_type": "elite",
		"relic_reward": true,
		"description": "检验蓝色打断、破甲和爆发窗口。",
		"intents": [
			{"type": "defend", "text": "结霜护甲", "value": 20},
			{"type": "attack", "text": "盾击", "value": 18},
			{"type": "charge", "text": "正在聚力", "value": 30},
			{"type": "heavy", "text": "破冰重击", "value": 30},
			{"type": "resist", "text": "蓝色抗性", "value": 0.35, "color": "blue"},
		],
	},
	"C1-06B": {
		"id": "C1-06B",
		"name": "猩红祭司",
		"enemy_name": "猩红祭司",
		"enemy_id": "EL-CR-01",
		"max_hp": 148,
		"attack": 16,
		"reward": 48,
		"reward_pool": ["rare", "red", "elite"],
		"node_type": "elite",
		"relic_reward": true,
		"description": "高风险高收益，考验续航与击杀窗口。",
		"intents": [
			{"type": "player_burn", "text": "血色献祭", "value": 1},
			{"type": "attack", "text": "祭司火击", "value": 16},
			{"type": "heal", "text": "牺牲侍从", "value": 24},
			{"type": "attack", "text": "赤焰合唱", "value": 20},
		],
	},
	"C1-08": {
		"id": "C1-08",
		"name": "灰蚀龙：无色镇魂曲",
		"enemy_name": "灰蚀龙",
		"enemy_id": "B-GR-01",
		"max_hp": 280,
		"attack": 22,
		"reward": 85,
		"reward_pool": ["rare", "mixed", "boss"],
		"node_type": "boss",
		"boss": true,
		"description": "章节最终检验：混色、净化、意图应对。", "boss_relic": "colorless_crown",
		"intents": [{"type": "pollute", "text": "无色吐息", "value": 3}, {"type": "board_corrupt", "text": "灰烬腐化", "value": 0.08}, {"type": "attack", "text": "龙翼横扫", "value": 22}, {"type": "resist_dominant", "text": "吞噬主色", "value": 0.35}, {"type": "charge", "text": "镇魂蓄势", "value": 34}, {"type": "heavy", "text": "无色镇魂曲", "value": 34}],
	},
	"C2-01": {
		"id": "C2-01", "name": "镜潮信使", "enemy_name": "镜潮信使", "enemy_id": "EN-ML-01", "max_hp": 150, "attack": 15, "reward": 30, "reward_pool": ["common", "blue"], "node_type": "combat", "description": "第二章开场，检验护盾回合管理。",
		"intents": [{"type": "attack", "text": "镜片飞投", "value": 15}, {"type": "spectrum_drift", "text": "镜面谱漂", "value": 0.16}, {"type": "defend", "text": "折射护甲", "value": 18}, {"type": "attack", "text": "回旋镜刃", "value": 18}],
	},
	"C2-02A": {
		"id": "C2-02A", "name": "熔彩矿工", "enemy_name": "熔彩矿工", "enemy_id": "EN-FG-01", "max_hp": 165, "attack": 17, "reward": 33, "reward_pool": ["common", "red"], "node_type": "combat", "description": "燃烧与重击交替出现。",
		"intents": [{"type": "player_burn", "text": "熔炉余温", "value": 1}, {"type": "attack", "text": "矿镐横扫", "value": 17}, {"type": "charge", "text": "高温蓄力", "value": 25}, {"type": "heavy", "text": "熔核砸击", "value": 25}],
	},
	"C2-03A": {
		"id": "C2-03A", "name": "税契偶师", "enemy_name": "税契偶师", "enemy_id": "EN-TX-01", "max_hp": 158, "attack": 16, "reward": 36, "reward_pool": ["common", "gold"], "node_type": "combat", "description": "用偷取压迫高金币构筑。",
		"intents": [{"type": "steal", "text": "征收色税", "value": 9}, {"type": "attack", "text": "账册拍击", "value": 16}, {"type": "defend", "text": "契约护层", "value": 20}],
	},
	"C2-04B": {
		"id": "C2-04B", "name": "寒潮祭钟", "enemy_name": "寒潮祭钟", "enemy_id": "EN-BL-01", "max_hp": 180, "attack": 18, "reward": 38, "reward_pool": ["common", "blue"], "node_type": "combat", "description": "稳定防守后释放蓄力攻击。",
		"intents": [{"type": "defend", "text": "凝结钟壁", "value": 24}, {"type": "charge", "text": "寒潮共鸣", "value": 28}, {"type": "heavy", "text": "冰钟震荡", "value": 28}],
	},
	"C2-05C": {
		"id": "C2-05C", "name": "棱镜猎手", "enemy_name": "棱镜猎手", "enemy_id": "EN-PR-01", "max_hp": 190, "attack": 19, "reward": 41, "reward_pool": ["common", "mixed"], "node_type": "combat", "description": "轮换颜色抗性，鼓励混色完成。",
		"intents": [{"type": "resist", "text": "红色折返", "value": 0.35, "color": "red"}, {"type": "attack", "text": "棱光狙击", "value": 19}, {"type": "resist", "text": "蓝色折返", "value": 0.35, "color": "blue"}, {"type": "attack", "text": "追猎突刺", "value": 21}],
	},
	"C2-06A": {
		"id": "C2-06A", "name": "灰玻工匠", "enemy_name": "灰玻工匠", "enemy_id": "EN-GL-01", "max_hp": 205, "attack": 20, "reward": 44, "reward_pool": ["common", "gray"], "node_type": "combat", "description": "Boss 前污染与护甲复合检验。",
		"intents": [{"type": "pollute", "text": "吹制灰玻", "value": 3}, {"type": "defend", "text": "玻璃甲壳", "value": 26}, {"type": "attack", "text": "碎片迸射", "value": 22}],
	},
	"C2-04A": {
		"id": "C2-04A", "name": "镜湖执法官", "enemy_name": "镜湖执法官", "enemy_id": "EL-ML-01", "max_hp": 250, "attack": 23, "reward": 58, "reward_pool": ["rare", "blue", "elite"], "node_type": "elite", "relic_reward": true, "description": "高护甲与主色抗性精英。",
		"intents": [{"type": "defend", "text": "镜湖法盾", "value": 32}, {"type": "spectrum_suppress", "text": "色谱压制令", "value": 0.12}, {"type": "resist_dominant", "text": "主色禁令", "value": 0.40}, {"type": "attack", "text": "执法重斩", "value": 25}, {"type": "charge", "text": "宣判蓄势", "value": 38}, {"type": "heavy", "text": "镜面宣判", "value": 38}],
	},
	"C2-06B": {
		"id": "C2-06B", "name": "熔炉双生", "enemy_name": "熔炉双生", "enemy_id": "EL-FG-02", "max_hp": 270, "attack": 24, "reward": 62, "reward_pool": ["rare", "red", "gold", "elite"], "node_type": "elite", "relic_reward": true, "description": "燃烧、偷取与回复的复合精英。",
		"intents": [{"type": "player_burn", "text": "双炉点火", "value": 1}, {"type": "steal", "text": "熔走金币", "value": 12}, {"type": "attack", "text": "双锤合击", "value": 26}, {"type": "heal", "text": "回炉重铸", "value": 30}],
	},
	"C2-08": {
		"id": "C2-08", "name": "镜湖乐监：倒影赋格", "enemy_name": "镜湖乐监", "enemy_id": "B-ML-01", "max_hp": 460, "attack": 28, "reward": 110, "reward_pool": ["rare", "mixed", "boss"], "node_type": "boss", "boss": true, "boss_relic": "torn_banner", "description": "第二章 Boss：连续抗性、蓄力与恢复。",
		"intents": [{"type": "spectrum_drift", "text": "倒影谱漂", "value": 0.22}, {"type": "attack", "text": "倒影拍击", "value": 25}, {"type": "spectrum_suppress", "text": "倒影压谱", "value": 0.15}, {"type": "charge", "text": "赋格蓄势", "value": 42}, {"type": "heavy", "text": "倒影赋格", "value": 42}, {"type": "heal", "text": "回声返奏", "value": 34}],
	},
	"C3-01": {
		"id": "C3-01", "name": "王庭司墨", "enemy_name": "王庭司墨", "enemy_id": "EN-CT-01", "max_hp": 230, "attack": 22, "reward": 45, "reward_pool": ["common", "gray"], "node_type": "combat", "description": "第三章开场，高污染压力。",
		"intents": [{"type": "pollute", "text": "泼洒王墨", "value": 3}, {"type": "spectrum_seal", "text": "王墨封谱", "value": 3}, {"type": "attack", "text": "墨刃", "value": 22}, {"type": "resist_dominant", "text": "抹除主色", "value": 0.35}],
	},
	"C3-02A": {
		"id": "C3-02A", "name": "断谱骑士", "enemy_name": "断谱骑士", "enemy_id": "EN-BK-01", "max_hp": 245, "attack": 24, "reward": 48, "reward_pool": ["common", "red"], "node_type": "combat", "description": "高频攻击考验即时防御。",
		"intents": [{"type": "attack", "text": "断谱斩", "value": 24}, {"type": "attack", "text": "追拍", "value": 20}, {"type": "charge", "text": "终止式蓄力", "value": 36}, {"type": "heavy", "text": "断章处刑", "value": 36}],
	},
	"C3-03A": {
		"id": "C3-03A", "name": "鎏金审计官", "enemy_name": "鎏金审计官", "enemy_id": "EN-AU-01", "max_hp": 260, "attack": 23, "reward": 52, "reward_pool": ["common", "gold"], "node_type": "combat", "description": "连续偷取与防御压缩经济窗口。",
		"intents": [{"type": "steal", "text": "终局审计", "value": 15}, {"type": "defend", "text": "封存账目", "value": 30}, {"type": "attack", "text": "金印砸击", "value": 25}],
	},
	"C3-04B": {
		"id": "C3-04B", "name": "静滞唱诗班", "enemy_name": "静滞唱诗班", "enemy_id": "EN-CH-01", "max_hp": 275, "attack": 25, "reward": 55, "reward_pool": ["common", "blue"], "node_type": "combat", "description": "护甲和蓄力形成固定节拍。",
		"intents": [{"type": "defend", "text": "静滞和声", "value": 32}, {"type": "charge", "text": "合唱吸气", "value": 40}, {"type": "heavy", "text": "终幕强音", "value": 40}, {"type": "attack", "text": "余音冲击", "value": 24}],
	},
	"C3-05C": {
		"id": "C3-05C", "name": "黑曜抄写员", "enemy_name": "黑曜抄写员", "enemy_id": "EN-OB-01", "max_hp": 295, "attack": 26, "reward": 58, "reward_pool": ["rare", "gray"], "node_type": "combat", "description": "污染、燃烧与攻击轮转。",
		"intents": [{"type": "pollute", "text": "抄录灰蚀", "value": 4}, {"type": "player_burn", "text": "黑曜烙印", "value": 1}, {"type": "attack", "text": "尖笔穿刺", "value": 27}],
	},
	"C3-06A": {
		"id": "C3-06A", "name": "四色行刑台", "enemy_name": "四色行刑台", "enemy_id": "EN-EX-01", "max_hp": 310, "attack": 28, "reward": 62, "reward_pool": ["rare", "mixed"], "node_type": "combat", "description": "最终 Boss 前的主色抗性预演。",
		"intents": [{"type": "resist_dominant", "text": "锁定主色", "value": 0.45}, {"type": "attack", "text": "四色轮斩", "value": 29}, {"type": "defend", "text": "无色底座", "value": 34}],
	},
	"C3-04A": {
		"id": "C3-04A", "name": "无色近卫", "enemy_name": "无色近卫", "enemy_id": "EL-CT-01", "max_hp": 370, "attack": 31, "reward": 78, "reward_pool": ["rare", "mixed", "elite"], "node_type": "elite", "relic_reward": true, "description": "高护甲、高抗性与重击的终局精英。",
		"intents": [{"type": "defend", "text": "王庭壁垒", "value": 42}, {"type": "spectrum_seal", "text": "近卫封谱", "value": 4}, {"type": "board_corrupt", "text": "王庭腐化", "value": 0.12}, {"type": "charge", "text": "近卫蓄斩", "value": 50}, {"type": "heavy", "text": "无色断头斩", "value": 50}],
	},
	"C3-06B": {
		"id": "C3-06B", "name": "终曲指挥家", "enemy_name": "终曲指挥家", "enemy_id": "EL-FN-01", "max_hp": 395, "attack": 32, "reward": 84, "reward_pool": ["rare", "red", "blue", "gold", "elite"], "node_type": "elite", "relic_reward": true, "description": "全意图轮转，检验成型构筑。",
		"intents": [{"type": "attack", "text": "起拍", "value": 28}, {"type": "pollute", "text": "灰调插入", "value": 4}, {"type": "heal", "text": "返始记号", "value": 38}, {"type": "charge", "text": "终曲蓄势", "value": 54}, {"type": "heavy", "text": "全奏终止", "value": 54}],
	},
	"C3-08": {
		"id": "C3-08", "name": "无色王：四色镇魂曲", "enemy_name": "无色王", "enemy_id": "B-CT-01", "max_hp": 680, "attack": 36, "reward": 0, "reward_pool": ["rare", "mixed", "boss"], "node_type": "boss", "boss": true, "final_boss": true, "description": "最终 Boss：四色倾向、灰蚀压力与完整构筑的总检验。",
		"intents": [{"type": "spectrum_seal", "text": "王权封谱", "value": 5}, {"type": "pollute", "text": "无色国度", "value": 5}, {"type": "spectrum_suppress", "text": "抹去谱效", "value": 0.18}, {"type": "board_corrupt", "text": "终幕腐化", "value": 0.14}, {"type": "charge", "text": "四色镇魂蓄势", "value": 62}, {"type": "heavy", "text": "四色镇魂曲", "value": 62}],
	},
	"C1-03X": {
		"id": "C1-03X", "name": "燃尽风口", "enemy_name": "焰痕追猎者", "enemy_id": "CH-C1-01", "max_hp": 142, "attack": 15, "reward": 38, "reward_pool": ["rare", "red", "black"], "node_type": "challenge", "description": "角色专属挑战：以燃烧与自伤换取高阶色谱。",
		"intents": [{"type": "player_burn", "text": "逆风引燃", "value": 1}, {"type": "attack", "text": "追焰斩", "value": 16}, {"type": "charge", "text": "燃尽蓄势", "value": 25}, {"type": "heavy", "text": "风口爆燃", "value": 25}],
	},
	"C1-03Y": {
		"id": "C1-03Y", "name": "雾根温床", "enemy_name": "噬色根群", "enemy_id": "CH-C1-02", "max_hp": 150, "attack": 14, "reward": 38, "reward_pool": ["rare", "green", "gray", "white"], "node_type": "challenge", "description": "角色专属挑战：连续污染与恢复检验。",
		"intents": [{"type": "pollute", "text": "根雾扩张", "value": 3}, {"type": "heal", "text": "吸色再生", "value": 18}, {"type": "attack", "text": "根须拍击", "value": 17}],
	},
	"C2-03X": {
		"id": "C2-03X", "name": "倒拍镜阵", "enemy_name": "迟声镜偶", "enemy_id": "CH-C2-01", "max_hp": 232, "attack": 22, "reward": 56, "reward_pool": ["rare", "blue", "purple"], "node_type": "challenge", "description": "角色专属挑战：蓄力、冻结与顺序消除检验。",
		"intents": [{"type": "charge", "text": "镜阵校时", "value": 34}, {"type": "heavy", "text": "倒拍震击", "value": 34}, {"type": "defend", "text": "折返镜壁", "value": 28}, {"type": "attack", "text": "迟声切割", "value": 22}],
	},
	"C2-03Y": {
		"id": "C2-03Y", "name": "无旗税关", "enemy_name": "灰账征收者", "enemy_id": "CH-C2-02", "max_hp": 224, "attack": 21, "reward": 58, "reward_pool": ["rare", "gold", "green", "black"], "node_type": "challenge", "description": "角色专属挑战：偷取、污染与经济兑现检验。",
		"intents": [{"type": "steal", "text": "征收路税", "value": 14}, {"type": "pollute", "text": "涂改账目", "value": 3}, {"type": "attack", "text": "铁算盘", "value": 23}],
	},
	"C3-03X": {
		"id": "C3-03X", "name": "双焰审判席", "enemy_name": "赤金裁决官", "enemy_id": "CH-C3-01", "max_hp": 348, "attack": 30, "reward": 76, "reward_pool": ["rare", "red", "gold", "black"], "node_type": "challenge", "description": "角色专属挑战：高伤害与金币压迫复合战。",
		"intents": [{"type": "resist", "text": "赤金禁令", "value": 0.40, "color": "red"}, {"type": "steal", "text": "罚没金币", "value": 18}, {"type": "attack", "text": "裁决槌", "value": 31}, {"type": "player_burn", "text": "烙印", "value": 1}],
	},
	"C3-03Y": {
		"id": "C3-03Y", "name": "四声静室", "enemy_name": "无色校音者", "enemy_id": "CH-C3-02", "max_hp": 365, "attack": 29, "reward": 78, "reward_pool": ["rare", "mixed", "white", "purple", "green"], "node_type": "challenge", "description": "角色专属挑战：四学派、净化与主色抗性终局检验。",
		"intents": [{"type": "resist_dominant", "text": "静室改调", "value": 0.45}, {"type": "pollute", "text": "无色覆写", "value": 4}, {"type": "defend", "text": "四声屏障", "value": 38}, {"type": "charge", "text": "静默蓄势", "value": 48}, {"type": "heavy", "text": "四声归零", "value": 48}],
	},
	"C1-AR1": {
		"id": "C1-AR1", "name": "失页巡检", "enemy_name": "索引巡检员", "enemy_id": "EN-AR-01",
		"max_hp": 126, "attack": 13, "reward": 27, "reward_pool": ["common", "white", "gray", "archive_v2"], "node_type": "combat",
		"description": "2.0 档案馆遭遇：先封住一段谱式，再用污染迫使玩家改变消除顺序。",
		"intents": [
			{"type": "spectrum_seal", "text": "封存色谱页", "value": 2},
			{"type": "attack", "text": "页夹切击", "value": 13},
			{"type": "pollute", "text": "撒落擦除粉", "value": 2},
		],
	},
	"C1-AR2": {
		"id": "C1-AR2", "name": "焚档司书", "enemy_name": "焚档司书", "enemy_id": "EL-AR-01",
		"max_hp": 178, "attack": 18, "reward": 46, "reward_pool": ["rare", "red", "black", "archive_v2", "elite"], "node_type": "elite", "relic_reward": true,
		"description": "2.0 档案馆精英：侵谱干扰与可冻结重击形成明确的爆发窗口。",
		"intents": [
			{"type": "board_corrupt", "text": "腐化禁阅架", "value": 0.08},
			{"type": "defend", "text": "铁页护封", "value": 22},
			{"type": "charge", "text": "焚卷蓄势", "value": 29},
			{"type": "heavy", "text": "总目录焚毁", "value": 29},
		],
	},
	"C2-AR1": {
		"id": "C2-AR1", "name": "镜档誊写", "enemy_name": "双面誊写员", "enemy_id": "EN-AR-02",
		"max_hp": 188, "attack": 19, "reward": 40, "reward_pool": ["common", "blue", "purple", "archive_v2"], "node_type": "combat",
		"description": "2.0 档案馆遭遇：错调与谱式压制轮换，要求调整手牌次序而非只堆伤害。",
		"intents": [
			{"type": "spectrum_drift", "text": "复写谱漂", "value": 0.16},
			{"type": "attack", "text": "镜笔横划", "value": 19},
			{"type": "spectrum_suppress", "text": "删改谱效", "value": 0.10},
			{"type": "defend", "text": "合页镜盾", "value": 22},
		],
	},
	"C2-AR2": {
		"id": "C2-AR2", "name": "证词公证机", "enemy_name": "证词公证机", "enemy_id": "EL-AR-02",
		"max_hp": 282, "attack": 25, "reward": 65, "reward_pool": ["rare", "gold", "purple", "archive_v2", "elite"], "node_type": "elite", "relic_reward": true,
		"description": "2.0 档案馆精英：封谱、抗性与偷取轮换，惩罚单色经济构筑。",
		"intents": [
			{"type": "spectrum_seal", "text": "盖章封谱", "value": 3},
			{"type": "resist_dominant", "text": "驳回主色证词", "value": 0.38},
			{"type": "steal", "text": "收取公证费", "value": 12},
			{"type": "attack", "text": "钢印压落", "value": 27},
		],
	},
	"C3-AR1": {
		"id": "C3-AR1", "name": "王庭删改官", "enemy_name": "王庭删改官", "enemy_id": "EN-AR-03",
		"max_hp": 300, "attack": 27, "reward": 59, "reward_pool": ["rare", "white", "black", "archive_v2"], "node_type": "combat",
		"description": "2.0 档案馆遭遇：污染后改写谱序，考验净化与手牌完成次序。",
		"intents": [
			{"type": "pollute", "text": "涂白证词", "value": 4},
			{"type": "spectrum_drift", "text": "改写谱漂", "value": 0.20},
			{"type": "attack", "text": "删改笔裁切", "value": 28},
			{"type": "defend", "text": "封档护页", "value": 32},
		],
	},
	"C3-AR2": {
		"id": "C3-AR2", "name": "失色馆长", "enemy_name": "失色馆长", "enemy_id": "EL-AR-03",
		"max_hp": 410, "attack": 33, "reward": 86, "reward_pool": ["rare", "mixed", "white", "black", "archive_v2", "elite"], "node_type": "elite", "relic_reward": true,
		"description": "2.0 档案馆精英：先施加侵谱并压低谱式伤害，再预告可冻结的终幕重击。",
		"intents": [
			{"type": "board_corrupt", "text": "腐化陈列原件", "value": 0.12},
			{"type": "spectrum_suppress", "text": "禁止谱效", "value": 0.15},
			{"type": "charge", "text": "闭馆蓄势", "value": 52},
			{"type": "heavy", "text": "全馆归档", "value": 52},
		],
	},
}

const CHAPTER_NODES: Dictionary = {
	"C1-00": {"id": "C1-00", "layer": 0, "name": "褪色路牌", "type": "start", "edges": ["C1-01"], "description": "选择初始小奖励，建立颜色目标。"},
	"C1-01": {"id": "C1-01", "layer": 1, "name": "灰雾巡逻", "type": "combat", "encounter_id": "C1-01", "edges": ["C1-02A", "C1-02B"], "description": "基础战斗教学。"},
	"C1-02A": {"id": "C1-02A", "layer": 2, "name": "褪色犬群", "type": "combat", "encounter_id": "C1-02A", "edges": ["C1-03A", "C1-03B", "C1-03X"], "description": "首次压力路线。"},
	"C1-02B": {"id": "C1-02B", "layer": 2, "name": "褪色神龛", "type": "event", "event_id": "shrine", "event_pool": ["shrine", "seed_vault", "pegsmith", "cinder_switchyard"], "edges": ["C1-03B", "C1-03C", "C1-03Y"], "description": "HP 与牌组质量取舍。"},
	"C1-03A": {"id": "C1-03A", "layer": 3, "name": "镀金盗贼", "type": "combat", "encounter_id": "C1-03A", "edges": ["C1-04A", "C1-04B"], "description": "金色收益与反制。"},
	"C1-03B": {"id": "C1-03B", "layer": 3, "name": "旧调色箱", "type": "chest", "edges": ["C1-04B", "C1-04C"], "description": "低风险补强。"},
	"C1-03C": {"id": "C1-03C", "layer": 3, "name": "流浪调色师", "type": "event", "event_id": "colorist", "event_pool": ["colorist", "broken_metronome", "echo_well"], "edges": ["C1-04B", "C1-04C"], "description": "主动染色或获得金币。"},
	"C1-03X": {"id": "C1-03X", "layer": 3, "name": "燃尽风口", "type": "challenge", "encounter_id": "C1-03X", "character_ids": ["red", "mixed"], "edges": ["C1-04A", "C1-04B"], "description": "烬歌 / 伊澜专属挑战。"},
	"C1-03Y": {"id": "C1-03Y", "layer": 3, "name": "雾根温床", "type": "challenge", "encounter_id": "C1-03Y", "character_ids": ["blue", "gray"], "edges": ["C1-04B", "C1-04C"], "description": "凛镜 / 弥砂专属挑战。"},
	"C1-04A": {"id": "C1-04A", "layer": 4, "name": "霜甲卫士", "type": "elite", "encounter_id": "C1-04A", "edges": ["C1-05A"], "description": "精英：防御与蓄力。"},
	"C1-04B": {"id": "C1-04B", "layer": 4, "name": "霜痕哨兵", "type": "combat", "encounter_id": "C1-04B", "edges": ["C1-05A", "C1-05B", "C1-05C"], "description": "安全路线中段战斗。"},
	"C1-04C": {"id": "C1-04C", "layer": 4, "name": "破篷商队", "type": "shop", "edges": ["C1-05B", "C1-05C", "C1-05D"], "description": "商店与牌组修剪。"},
	"C1-05A": {"id": "C1-05A", "layer": 5, "name": "调色台", "type": "camp", "edges": ["C1-06A", "C1-06B"], "description": "治疗、升级、净化三选一。"},
	"C1-05B": {"id": "C1-05B", "layer": 5, "name": "破碎画廊", "type": "event", "event_id": "gallery", "event_pool": ["gallery", "character_mirror"], "edges": ["C1-06A", "C1-06C"], "description": "稀有遗物诱惑与诅咒代价。"},
	"C1-05C": {"id": "C1-05C", "layer": 5, "name": "灰烬搬运工", "type": "combat", "encounter_id": "C1-05C", "edges": ["C1-06A", "C1-06C"], "description": "污染与护甲复合战斗。"},
	"C1-05D": {"id": "C1-05D", "layer": 5, "name": "颜料井", "type": "event", "event_id": "pigment_well", "event_pool": ["pigment_well", "mist_shelter", "mist_foundry", "mist_calibration"], "edges": ["C1-06B", "C1-06C"], "description": "以生命换颜料，或封井获利。"},
	"C1-06A": {"id": "C1-06A", "layer": 6, "name": "织雾小队", "type": "combat", "encounter_id": "C1-06A", "edges": ["C1-07"], "description": "Boss 前污染压力预演。"},
	"C1-06B": {"id": "C1-06B", "layer": 6, "name": "猩红祭司", "type": "elite", "encounter_id": "C1-06B", "edges": ["C1-07"], "description": "精英：燃烧与回复。"},
	"C1-06C": {"id": "C1-06C", "layer": 6, "name": "金色岔路", "type": "shop", "edges": ["C1-07"], "description": "Boss 前补强商店。"},
	"C1-07": {"id": "C1-07", "layer": 7, "name": "镇门篝火", "type": "camp", "edges": ["C1-08"], "description": "Boss 前最后调参。"},
	"C1-08": {"id": "C1-08", "layer": 8, "name": "灰蚀龙：无色镇魂曲", "type": "boss", "encounter_id": "C1-08", "edges": ["C2-01"], "description": "第一章 Boss。"},
	"C2-01": {"id": "C2-01", "layer": 1, "name": "镜潮信使", "type": "combat", "encounter_id": "C2-01", "edges": ["C2-02A", "C2-02B"], "description": "第二章开场战斗。"},
	"C2-02A": {"id": "C2-02A", "layer": 2, "name": "熔彩矿工", "type": "combat", "encounter_id": "C2-02A", "edges": ["C2-03A", "C2-03B", "C2-03X"], "description": "燃烧与重击路线。"},
	"C2-02B": {"id": "C2-02B", "layer": 2, "name": "冰封谱库", "type": "event", "event_id": "frozen_archive", "event_pool": ["frozen_archive", "frozen_clock", "prism_vendor", "mirror_workbench"], "edges": ["C2-03B", "C2-03C", "C2-03Y"], "description": "蓝色色谱与回复取舍。"},
	"C2-03A": {"id": "C2-03A", "layer": 3, "name": "税契偶师", "type": "combat", "encounter_id": "C2-03A", "edges": ["C2-04A", "C2-04B"], "description": "金币压迫战斗。"},
	"C2-03B": {"id": "C2-03B", "layer": 3, "name": "镜底宝箱", "type": "chest", "edges": ["C2-04B", "C2-04C"], "description": "章节中段补强。"},
	"C2-03C": {"id": "C2-03C", "layer": 3, "name": "静默拍卖", "type": "event", "event_id": "silent_auction", "event_pool": ["silent_auction", "merchant_crossroad", "bounty_lane", "bumper_exchange"], "edges": ["C2-04B", "C2-04C"], "description": "金币、颜料与遗物交易。"},
	"C2-03X": {"id": "C2-03X", "layer": 3, "name": "倒拍镜阵", "type": "challenge", "encounter_id": "C2-03X", "character_ids": ["blue", "mixed"], "edges": ["C2-04A", "C2-04B"], "description": "凛镜 / 伊澜专属挑战。"},
	"C2-03Y": {"id": "C2-03Y", "layer": 3, "name": "无旗税关", "type": "challenge", "encounter_id": "C2-03Y", "character_ids": ["gold", "gray"], "edges": ["C2-04B", "C2-04C"], "description": "洛恩 / 弥砂专属挑战。"},
	"C2-04A": {"id": "C2-04A", "layer": 4, "name": "镜湖执法官", "type": "elite", "encounter_id": "C2-04A", "edges": ["C2-05A", "C2-05B"], "description": "精英：护甲与主色抗性。"},
	"C2-04B": {"id": "C2-04B", "layer": 4, "name": "寒潮祭钟", "type": "combat", "encounter_id": "C2-04B", "edges": ["C2-05A", "C2-05C"], "description": "防守与蓄力节拍。"},
	"C2-04C": {"id": "C2-04C", "layer": 4, "name": "镜湖商站", "type": "shop", "edges": ["C2-05B", "C2-05C", "C2-05D"], "description": "第二章商店。"},
	"C2-05A": {"id": "C2-05A", "layer": 5, "name": "冷却台", "type": "camp", "edges": ["C2-06A", "C2-06B"], "description": "治疗、精研或净化。"},
	"C2-05B": {"id": "C2-05B", "layer": 5, "name": "镜湖倒影", "type": "event", "event_id": "mirror_lake", "event_pool": ["mirror_lake", "white_procession"], "edges": ["C2-06A", "C2-06C"], "description": "回复与灰蚀取舍。"},
	"C2-05C": {"id": "C2-05C", "layer": 5, "name": "棱镜猎手", "type": "combat", "encounter_id": "C2-05C", "edges": ["C2-06A", "C2-06B"], "description": "轮换颜色抗性。"},
	"C2-05D": {"id": "C2-05D", "layer": 5, "name": "商队旧债", "type": "event", "event_id": "caravan_debt", "event_pool": ["caravan_debt", "black_notary"], "edges": ["C2-06B", "C2-06C"], "description": "即时经济与长期代价。"},
	"C2-06A": {"id": "C2-06A", "layer": 6, "name": "灰玻工匠", "type": "combat", "encounter_id": "C2-06A", "edges": ["C2-07"], "description": "Boss 前污染检验。"},
	"C2-06B": {"id": "C2-06B", "layer": 6, "name": "熔炉双生", "type": "elite", "encounter_id": "C2-06B", "edges": ["C2-07"], "description": "精英：燃烧、偷取与回复。"},
	"C2-06C": {"id": "C2-06C", "layer": 6, "name": "工坊直售处", "type": "shop", "edges": ["C2-07"], "description": "Boss 前补强。"},
	"C2-07": {"id": "C2-07", "layer": 7, "name": "镜湖校音台", "type": "camp", "edges": ["C2-08"], "description": "第二章 Boss 前整备。"},
	"C2-08": {"id": "C2-08", "layer": 8, "name": "镜湖乐监：倒影赋格", "type": "boss", "encounter_id": "C2-08", "edges": ["C3-01"], "description": "第二章 Boss。"},
	"C3-01": {"id": "C3-01", "layer": 1, "name": "王庭司墨", "type": "combat", "encounter_id": "C3-01", "edges": ["C3-02A", "C3-02B"], "description": "第三章开场战斗。"},
	"C3-02A": {"id": "C3-02A", "layer": 2, "name": "断谱骑士", "type": "combat", "encounter_id": "C3-02A", "edges": ["C3-03A", "C3-03B", "C3-03X"], "description": "高频攻击路线。"},
	"C3-02B": {"id": "C3-02B", "layer": 2, "name": "猩红舞台", "type": "event", "event_id": "crimson_stage", "event_pool": ["crimson_stage", "duelist_wake"], "edges": ["C3-03B", "C3-03C", "C3-03Y"], "description": "生命与红色强音取舍。"},
	"C3-03A": {"id": "C3-03A", "layer": 3, "name": "鎏金审计官", "type": "combat", "encounter_id": "C3-03A", "edges": ["C3-04A", "C3-04B"], "description": "终局经济检验。"},
	"C3-03B": {"id": "C3-03B", "layer": 3, "name": "王庭秘藏", "type": "chest", "edges": ["C3-04B", "C3-04C"], "description": "终局补强。"},
	"C3-03C": {"id": "C3-03C", "layer": 3, "name": "无名画廊", "type": "event", "event_id": "nameless_gallery", "event_pool": ["nameless_gallery", "colorless_orchestra", "silent_board", "royal_lockshop"], "edges": ["C3-04B", "C3-04C"], "description": "灰蚀与遗物取舍。"},
	"C3-03X": {"id": "C3-03X", "layer": 3, "name": "双焰审判席", "type": "challenge", "encounter_id": "C3-03X", "character_ids": ["red", "gold"], "edges": ["C3-04A", "C3-04B"], "description": "烬歌 / 洛恩专属挑战。"},
	"C3-03Y": {"id": "C3-03Y", "layer": 3, "name": "四声静室", "type": "challenge", "encounter_id": "C3-03Y", "character_ids": ["blue", "gray", "mixed"], "edges": ["C3-04B", "C3-04C"], "description": "凛镜 / 弥砂 / 伊澜专属挑战。"},
	"C3-04A": {"id": "C3-04A", "layer": 4, "name": "无色近卫", "type": "elite", "encounter_id": "C3-04A", "edges": ["C3-05A", "C3-05B"], "description": "精英：高护甲与高抗性。"},
	"C3-04B": {"id": "C3-04B", "layer": 4, "name": "静滞唱诗班", "type": "combat", "encounter_id": "C3-04B", "edges": ["C3-05A", "C3-05C"], "description": "固定蓄力节拍。"},
	"C3-04C": {"id": "C3-04C", "layer": 4, "name": "王庭黑市", "type": "shop", "edges": ["C3-05B", "C3-05C", "C3-05D"], "description": "终局商店。"},
	"C3-05A": {"id": "C3-05A", "layer": 5, "name": "终幕工坊", "type": "event", "event_id": "final_workshop", "event_pool": ["final_workshop", "refraction_forge", "void_mooring"], "edges": ["C3-06A", "C3-06B"], "description": "不可逆的终局校准。"},
	"C3-05B": {"id": "C3-05B", "layer": 5, "name": "合唱残响", "type": "event", "event_id": "chorus_echo", "edges": ["C3-06A", "C3-06C"], "description": "补足混色资源。"},
	"C3-05C": {"id": "C3-05C", "layer": 5, "name": "黑曜抄写员", "type": "combat", "encounter_id": "C3-05C", "edges": ["C3-06A", "C3-06B"], "description": "污染与自伤压力。"},
	"C3-05D": {"id": "C3-05D", "layer": 5, "name": "终曲休止室", "type": "camp", "edges": ["C3-06B", "C3-06C"], "description": "最后一次中途整备。"},
	"C3-06A": {"id": "C3-06A", "layer": 6, "name": "四色行刑台", "type": "combat", "encounter_id": "C3-06A", "edges": ["C3-07"], "description": "最终 Boss 机制预演。"},
	"C3-06B": {"id": "C3-06B", "layer": 6, "name": "终曲指挥家", "type": "elite", "encounter_id": "C3-06B", "edges": ["C3-07"], "description": "精英：全意图轮转。"},
	"C3-06C": {"id": "C3-06C", "layer": 6, "name": "终局商亭", "type": "shop", "edges": ["C3-07"], "description": "最终补给。"},
	"C3-07": {"id": "C3-07", "layer": 7, "name": "王座前厅", "type": "camp", "edges": ["C3-08"], "description": "最终 Boss 前整备。"},
	"C3-08": {"id": "C3-08", "layer": 8, "name": "无色王：四色镇魂曲", "type": "boss", "encounter_id": "C3-08", "edges": [], "description": "最终 Boss。"},
	"C1-02R": {
		"id": "C1-02R", "layer": 2, "name": "旁录室·起因夹层", "type": "event", "event_id": "seed_vault",
		"event_pool": ["ash_origin_record", "mirror_witness_oath", "debt_faded_note", "seed_vault"], "edges": ["C1-03R"],
		"archive_bypass": true, "description": "绕开主展柜，从未编目的起因记录进入档案回廊。",
	},
	"C1-04S": {
		"id": "C1-04S", "layer": 4, "name": "旁录室·见证夹层", "type": "event", "event_id": "echo_well",
		"event_pool": ["fourth_seat_ticket", "pegsmith_measure", "catalogue_blank_names", "echo_well"], "edges": ["C1-05R"],
		"archive_bypass": true, "description": "跳过失页巡检，读取被封在墙后的另一份见证。",
	},
	"C2-02R": {
		"id": "C2-02R", "layer": 2, "name": "镜下侧库·证词夹层", "type": "event", "event_id": "frozen_archive",
		"event_pool": ["ash_filter_testimony", "mirror_lake_deposition", "debt_registry", "frozen_archive"], "edges": ["C2-03R"],
		"archive_bypass": true, "description": "沿镜背裂缝进入侧库，查阅已解锁记忆链的中段证词。",
	},
	"C2-04S": {
		"id": "C2-04S", "layer": 4, "name": "镜下侧库·勘误夹层", "type": "event", "event_id": "silent_auction",
		"event_pool": ["backstage_missing_score", "mirror_recalibration", "sealed_color_trial", "silent_auction"], "edges": ["C2-05R"],
		"archive_bypass": true, "description": "避开誊写室，从侧库取回另一组勘误证物。",
	},
	"C3-02R": {
		"id": "C3-02R", "layer": 2, "name": "总档案侧门·余波夹层", "type": "event", "event_id": "nameless_gallery",
		"event_pool": ["ash_dragon_margin", "conductor_errata", "debt_collection", "nameless_gallery"], "edges": ["C3-03R"],
		"archive_bypass": true, "description": "从总档案侧门进入，只陈列已完成前序的余波记录。",
	},
	"C3-04S": {
		"id": "C3-04S", "layer": 4, "name": "总档案侧门·终卷夹层", "type": "event", "event_id": "final_workshop",
		"event_pool": ["court_restored_score", "final_temper_record", "corridor_last_reader", "final_workshop"], "edges": ["C3-05R"],
		"archive_bypass": true, "description": "绕过删改官，直接核对另一组记忆链的终卷。",
	},
	"C1-03R": {
		"id": "C1-03R", "layer": 3, "name": "断色回廊·起因柜", "type": "event", "event_id": "ash_origin_record",
		"event_pool": ["ash_origin_record", "mirror_witness_oath", "debt_faded_note"], "edges": ["C1-04R"],
		"description": "从三条跨章记忆链的起因中随机抽取一条。",
	},
	"C1-04R": {"id": "C1-04R", "layer": 4, "name": "失页巡检", "type": "combat", "encounter_id": "C1-AR1", "edges": ["C1-05R"], "description": "失色档案馆普通遭遇。"},
	"C1-05R": {
		"id": "C1-05R", "layer": 5, "name": "断色回廊·见证柜", "type": "event", "event_id": "fourth_seat_ticket",
		"event_pool": ["fourth_seat_ticket", "pegsmith_measure", "catalogue_blank_names"], "edges": ["C1-06R"],
		"description": "从乐团、校准与档案员记忆链的起因中随机抽取一条。",
	},
	"C1-06R": {"id": "C1-06R", "layer": 6, "name": "焚档司书", "type": "elite", "encounter_id": "C1-AR2", "edges": ["C1-07"], "description": "档案馆精英：侵谱干扰与重击窗口。"},
	"C2-03R": {
		"id": "C2-03R", "layer": 3, "name": "断色回廊·证词柜", "type": "event", "event_id": "ash_filter_testimony",
		"event_pool": ["ash_filter_testimony", "mirror_lake_deposition", "debt_registry", "frozen_archive"], "edges": ["C2-04R"],
		"description": "抽取前三条记忆链的中段证词。",
	},
	"C2-04R": {"id": "C2-04R", "layer": 4, "name": "镜档誊写", "type": "combat", "encounter_id": "C2-AR1", "edges": ["C2-05R"], "description": "失色档案馆普通遭遇。"},
	"C2-05R": {
		"id": "C2-05R", "layer": 5, "name": "断色回廊·勘误柜", "type": "event", "event_id": "backstage_missing_score",
		"event_pool": ["backstage_missing_score", "mirror_recalibration", "sealed_color_trial", "silent_auction"], "edges": ["C2-06R"],
		"description": "抽取乐团、校准与档案员记忆链的中段证词。",
	},
	"C2-06R": {"id": "C2-06R", "layer": 6, "name": "证词公证机", "type": "elite", "encounter_id": "C2-AR2", "edges": ["C2-07"], "description": "档案馆精英：封谱、抗性与偷取。"},
	"C3-03R": {
		"id": "C3-03R", "layer": 3, "name": "断色回廊·余波柜", "type": "event", "event_id": "ash_dragon_margin",
		"event_pool": ["ash_dragon_margin", "conductor_errata", "debt_collection", "nameless_gallery"], "edges": ["C3-04R"],
		"description": "抽取前三条记忆链的余波与收束。",
	},
	"C3-04R": {"id": "C3-04R", "layer": 4, "name": "王庭删改官", "type": "combat", "encounter_id": "C3-AR1", "edges": ["C3-05R"], "description": "失色档案馆普通遭遇。"},
	"C3-05R": {
		"id": "C3-05R", "layer": 5, "name": "断色回廊·终卷柜", "type": "event", "event_id": "court_restored_score",
		"event_pool": ["court_restored_score", "final_temper_record", "corridor_last_reader", "final_workshop"], "edges": ["C3-06R"],
		"description": "抽取乐团、校准与档案员记忆链的余波与收束。",
	},
	"C3-06R": {"id": "C3-06R", "layer": 6, "name": "失色馆长", "type": "elite", "encounter_id": "C3-AR2", "edges": ["C3-07"], "description": "档案馆精英：侵谱、谱式压制与终幕重击。"},
}

const MAP_TEMPLATE_SPECS: Dictionary = {
	"C1": {
		"standard": {"id": "standard", "name": "灰雾中线", "tag": "均衡", "edge_overrides": {}},
		"risk": {
			"id": "risk", "name": "燃尽险径", "tag": "精英与挑战偏多",
			"enemy_hp_multiplier": 1.05,
			"edge_overrides": {
				"C1-01": ["C1-02A"], "C1-02A": ["C1-03A", "C1-03X"],
				"C1-03A": ["C1-04A", "C1-04B"], "C1-03X": ["C1-04A", "C1-04B"],
				"C1-04A": ["C1-05A", "C1-05B"], "C1-04B": ["C1-05A", "C1-05C"],
			},
		},
		"economy": {
			"id": "economy", "name": "拾彩商路", "tag": "事件与商店偏多",
			"shop_refresh_bonus": 5,
			"edge_overrides": {
				"C1-01": ["C1-02B"], "C1-02B": ["C1-03B", "C1-03C", "C1-03Y"],
				"C1-03B": ["C1-04B", "C1-04C"], "C1-03C": ["C1-04B", "C1-04C"],
				"C1-04B": ["C1-05B", "C1-05C", "C1-05D"], "C1-04C": ["C1-05B", "C1-05D"],
			},
		},
		"archive": {
			"id": "archive", "name": "失色档案馆", "tag": "双事件与档案精英",
			"gray_pressure_bonus": 1,
			"edge_overrides": {
				"C1-01": ["C1-02B", "C1-02R"], "C1-02B": ["C1-03R"], "C1-02R": ["C1-03R"],
				"C1-03R": ["C1-04R", "C1-04S"], "C1-04R": ["C1-05R"], "C1-04S": ["C1-05R"],
				"C1-05R": ["C1-06R"], "C1-06R": ["C1-07"],
			},
		},
	},
	"C2": {
		"standard": {"id": "standard", "name": "镜湖中环", "tag": "均衡", "edge_overrides": {}},
		"risk": {
			"id": "risk", "name": "熔炉逆流", "tag": "精英与抗性偏多",
			"enemy_hp_multiplier": 1.05,
			"edge_overrides": {
				"C2-01": ["C2-02A"], "C2-02A": ["C2-03A", "C2-03X"],
				"C2-03A": ["C2-04A", "C2-04B"], "C2-03X": ["C2-04A", "C2-04B"],
				"C2-04A": ["C2-05A", "C2-05B"], "C2-04B": ["C2-05A", "C2-05C"],
			},
		},
		"economy": {
			"id": "economy", "name": "拍卖回廊", "tag": "交易与宝箱偏多",
			"shop_refresh_bonus": 5,
			"edge_overrides": {
				"C2-01": ["C2-02B"], "C2-02B": ["C2-03B", "C2-03C", "C2-03Y"],
				"C2-03B": ["C2-04B", "C2-04C"], "C2-03C": ["C2-04B", "C2-04C"],
				"C2-04B": ["C2-05B", "C2-05C", "C2-05D"], "C2-04C": ["C2-05B", "C2-05D"],
			},
		},
		"archive": {
			"id": "archive", "name": "镜下档案库", "tag": "证词与公证精英",
			"gray_pressure_bonus": 1,
			"edge_overrides": {
				"C2-01": ["C2-02B", "C2-02R"], "C2-02B": ["C2-03R"], "C2-02R": ["C2-03R"],
				"C2-03R": ["C2-04R", "C2-04S"], "C2-04R": ["C2-05R"], "C2-04S": ["C2-05R"],
				"C2-05R": ["C2-06R"], "C2-06R": ["C2-07"],
			},
		},
	},
	"C3": {
		"standard": {"id": "standard", "name": "王庭正门", "tag": "均衡", "edge_overrides": {}},
		"risk": {
			"id": "risk", "name": "断谱审判路", "tag": "终局战斗偏多",
			"enemy_hp_multiplier": 1.05,
			"edge_overrides": {
				"C3-01": ["C3-02A"], "C3-02A": ["C3-03A", "C3-03X"],
				"C3-03A": ["C3-04A", "C3-04B"], "C3-03X": ["C3-04A", "C3-04B"],
				"C3-04A": ["C3-05A", "C3-05B"], "C3-04B": ["C3-05A", "C3-05C"],
			},
		},
		"economy": {
			"id": "economy", "name": "黑市密廊", "tag": "事件与终局整备偏多",
			"shop_refresh_bonus": 5,
			"edge_overrides": {
				"C3-01": ["C3-02B"], "C3-02B": ["C3-03B", "C3-03C", "C3-03Y"],
				"C3-03B": ["C3-04B", "C3-04C"], "C3-03C": ["C3-04B", "C3-04C"],
				"C3-04B": ["C3-05B", "C3-05C", "C3-05D"], "C3-04C": ["C3-05A", "C3-05D"],
			},
		},
		"archive": {
			"id": "archive", "name": "王庭总档案", "tag": "余波与馆长精英",
			"gray_pressure_bonus": 1,
			"edge_overrides": {
				"C3-01": ["C3-02B", "C3-02R"], "C3-02B": ["C3-03R"], "C3-02R": ["C3-03R"],
				"C3-03R": ["C3-04R", "C3-04S"], "C3-04R": ["C3-05R"], "C3-04S": ["C3-05R"],
				"C3-05R": ["C3-06R"], "C3-06R": ["C3-07"],
			},
		},
	},
}

const INITIAL_DECK: Array[String] = [
	"ember_slash",
	"ember_slash",
	"frost_guard",
	"frost_guard",
	"golden_beat",
	"palette_drill",
	"tone_phrase",
	"ash_alchemy",
]

const STARTING_ARCHETYPES: Dictionary = {
	"red": {
		"id": "red",
		"name": "烬歌",
		"title": "焰痕决斗家",
		"tagline": "让第一簇火决定整场战斗",
		"color": "red",
		"max_hp": 112,
		"difficulty": "进攻",
		"passive_id": "first_flame",
		"passive_name": "先声燃点",
		"passive_text": "每场战斗首次主动完成红色 4 连时，额外施加 1 层燃烧。",
		"active_skill": {"id": "blazing_line", "name": "灼线校准", "cost": 12, "text": "下一张达成色谱的谱式伤害 +10，并施加 2 层燃烧。"},
		"spectrum_profile": {"type": "ember", "name": "烬火谱式", "pulse_damage_bonus": 3, "completion_burn": 1},
		"portrait": "res://assets/characters/portraits/hero_jinge.png",
		"deck": [
			"ember_slash", "ember_slash", "wildfire", "crimson_echo",
			"frost_guard", "golden_beat", "palette_drill", "tone_phrase",
		],
		"relic": "warm_charm",
		"bias": {"red": 2, "blue": 0, "gold": 0},
		"exclusive_pools": ["red"],
	},
	"blue": {
		"id": "blue",
		"name": "凛镜",
		"title": "镜湖守望者",
		"tagline": "读懂意图，再冻结致命节拍",
		"color": "blue",
		"max_hp": 128,
		"difficulty": "稳健",
		"passive_id": "mirror_counter",
		"passive_name": "镜返",
		"passive_text": "打断敌人蓄力时获得 8 护盾。",
		"active_skill": {"id": "mirror_angle", "name": "镜角折返", "cost": 12, "text": "获得 6 护盾；下一张达成色谱再获得 8 护盾并冻结敌人。"},
		"spectrum_profile": {"type": "mirror", "name": "镜湖守式", "completion_shield": 3},
		"portrait": "res://assets/characters/portraits/hero_linjing.png",
		"deck": [
			"frost_guard", "frost_guard", "ice_rest", "daylight_calibration",
			"ember_slash", "golden_beat", "palette_drill", "tone_phrase",
		],
		"relic": "frozen_watch",
		"bias": {"red": 0, "blue": 2, "gold": 0},
		"exclusive_pools": ["blue"],
	},
	"gold": {
		"id": "gold",
		"name": "洛恩",
		"title": "断路估价师",
		"tagline": "把每一次取舍都折算成未来",
		"color": "gold",
		"max_hp": 116,
		"difficulty": "经营",
		"passive_id": "merchant_instinct",
		"passive_name": "行商直觉",
		"passive_text": "商店商品、服务与刷新价格降低 10%。",
		"active_skill": {"id": "gilded_investment", "name": "金辉加注", "cost": 11, "text": "下一张达成色谱额外获得 8 金币。"},
		"spectrum_profile": {"type": "gilded", "name": "金辉估值", "completion_coins": 2},
		"portrait": "res://assets/characters/portraits/hero_luoen.png",
		"deck": [
			"golden_beat", "golden_beat", "bond_refraction", "ash_alchemy",
			"ember_slash", "frost_guard", "palette_drill", "tone_phrase",
		],
		"relic": "merchant_seal",
		"bias": {"red": 0, "blue": 0, "gold": 2},
		"exclusive_pools": ["gold"],
	},
	"gray": {
		"id": "gray",
		"name": "弥砂",
		"title": "雾地拾谱人",
		"tagline": "从污染中留下可用的颜色",
		"color": "gray",
		"max_hp": 124,
		"difficulty": "转化",
		"passive_id": "mist_ward",
		"passive_name": "拾雾",
		"passive_text": "每场战斗首次遭受污染时，净化 2 格并获得 5 护盾。",
		"active_skill": {"id": "mist_weight", "name": "雾核增重", "cost": 12, "text": "净化 2 格；下一张达成色谱伤害 +6、无视护甲并再净化 1 格。"},
		"spectrum_profile": {"type": "mist", "name": "净雾转谱", "armor_break": 1, "cleanse_on_completion": 1},
		"portrait": "res://assets/characters/portraits/hero_misha.png",
		"deck": [
			"ash_alchemy", "ash_alchemy", "mist_phrase", "gray_blade",
			"frost_guard", "golden_beat", "palette_drill", "tone_phrase",
		],
		"relic": "mist_bell",
		"bias": {"red": 0, "blue": 1, "gold": 0},
		"exclusive_pools": ["gray"],
	},
	"mixed": {
		"id": "mixed",
		"name": "伊澜",
		"title": "三声调律师",
		"tagline": "让不同颜色在同一回合应答",
		"color": "mixed",
		"max_hp": 120,
		"difficulty": "技巧",
		"passive_id": "triad_resonance",
		"passive_name": "三声共鸣",
		"passive_text": "每场战斗首次在同回合消除红、蓝、金，获得 1 颜料并返还 1 步。",
		"active_skill": {"id": "prism_volley", "name": "三声齐奏", "cost": 14, "text": "下一张达成色谱的谱式冲击复奏 2 次，每次造成 55% 伤害。"},
		"spectrum_profile": {"type": "prism", "name": "三声复调"},
		"portrait": "res://assets/characters/portraits/hero_yilan.png",
		"deck": [
			"prism_concerto", "daylight_calibration", "colorless_pause", "ember_slash",
			"frost_guard", "golden_beat", "palette_drill", "tone_phrase",
		],
		"relic": "color_thread",
		"bias": {"red": 1, "blue": 1, "gold": 1},
		"exclusive_pools": ["mixed", "white"],
	},
}

static func color_name(color_key: String) -> String:
	return String(COLOR_NAMES.get(color_key, color_key))

static func color_full_name(color_key: String) -> String:
	return String(COLOR_FULL_NAMES.get(color_key, color_key))

static func color_tint(color_key: String) -> Color:
	return COLOR_TINTS.get(color_key, Color.WHITE)

static func spectrum(card_id: String) -> Dictionary:
	return SPECTRA.get(card_id, {}).duplicate(true)

static func spectrum_tags(card_id: String) -> Array[String]:
	var card: Dictionary = SPECTRA.get(card_id, {})
	if card.is_empty():
		return []
	var tags: Array[String] = []
	var color_key: String = String(card.get("color", ""))
	match color_key:
		"red":
			tags.append("燃烧")
		"blue":
			tags.append("冻结")
		"gold":
			tags.append("金币")
		"gray":
			tags.append("灰蚀")
	var effect_text: String = String(card.get("effect", "")) + String(card.get("condition", ""))
	if effect_text.contains("护盾") or card.has("shield"):
		tags.append("护盾")
	if effect_text.contains("金币") or card.has("coins") or card.has("bonus_coins") or card.has("coin_threshold"):
		tags.append("金币")
	if effect_text.contains("燃烧") or card.has("burn") or card.has("burn_turns") or card.has("burn_stacks"):
		tags.append("燃烧")
	if effect_text.contains("冻结") or card.has("freeze") or card.has("freeze_turns"):
		tags.append("冻结")
	if effect_text.contains("灰") or effect_text.contains("净化") or card.has("cleanse") or card.has("corruption_threshold"):
		tags.append("灰蚀")
	if effect_text.contains("连锁") or card.has("cascade") or card.has("max_cascade"):
		tags.append("连锁")
	if effect_text.contains("共鸣") or card.has("resonance") or card.has("resonance_id"):
		tags.append("共鸣")
	if effect_text.contains("多色") or card.has("unique_colors") or card.has("completed_colors"):
		tags.append("多色")
	if effect_text.contains("失去") or effect_text.contains("自伤") or card.has("hp_cost") or card.has("self_damage"):
		tags.append("自伤")
	if tags.is_empty():
		tags.append("连锁")
	var ordered: Array[String] = []
	for tag in ["燃烧", "冻结", "护盾", "金币", "灰蚀", "连锁", "共鸣", "多色", "自伤"]:
		if tags.has(tag):
			ordered.append(tag)
	return ordered

static func spectra_matching_tags(tags: Array[String]) -> Array[Dictionary]:
	var wanted: Dictionary = {}
	for tag in tags:
		var normalized: String = String(tag).strip_edges()
		if not normalized.is_empty():
			wanted[normalized] = true
	var result: Array[Dictionary] = []
	var ids: Array[String] = []
	for card_id_value in SPECTRA.keys():
		var card_id: String = String(card_id_value)
		for tag in spectrum_tags(card_id):
			if wanted.has(tag):
				ids.append(card_id)
				break
	ids.sort()
	for card_id in ids:
		var card: Dictionary = spectrum(card_id)
		card["tags"] = spectrum_tags(card_id)
		result.append(card)
	return result

static func spectrum_for_level(card_id: String, level: int = 0) -> Dictionary:
	var data: Dictionary = spectrum(card_id)
	if level > 0:
		var upgrade: Dictionary = data.get("upgrade", {})
		for key in upgrade.keys():
			data[key] = upgrade[key]
		data["upgraded"] = true
	else:
		data["upgraded"] = false
	data.erase("upgrade")
	return data

static func relic(relic_id: String) -> Dictionary:
	return RELICS.get(relic_id, {}).duplicate(true)

static func normalize_enemy_intent(intent: Dictionary) -> Dictionary:
	var normalized: Dictionary = intent.duplicate(true)
	var intent_type: String = String(normalized.get("type", "attack"))
	match intent_type:
		"aim_drift":
			intent_type = "spectrum_drift"
		"crit_suppress":
			intent_type = "spectrum_suppress"
		"peg_seal", "seal":
			intent_type = "spectrum_seal"
		"add_hazard":
			intent_type = "board_corrupt"
	normalized["type"] = intent_type
	return normalized

static func encounter(encounter_id: String) -> Dictionary:
	var data: Dictionary = ENCOUNTERS.get(encounter_id, {}).duplicate(true)
	var normalized_intents: Array = []
	for intent_value in data.get("intents", []):
		if intent_value is Dictionary:
			normalized_intents.append(normalize_enemy_intent(intent_value))
	data["intents"] = normalized_intents
	return data

static func node(node_id: String) -> Dictionary:
	return CHAPTER_NODES.get(node_id, {}).duplicate(true)

static func chapter(chapter_id: String) -> Dictionary:
	return CHAPTERS.get(chapter_id, {}).duplicate(true)

static func event(event_id: String) -> Dictionary:
	return EVENTS.get(event_id, {}).duplicate(true)

static func starting_archetype(archetype_id: String) -> Dictionary:
	return STARTING_ARCHETYPES.get(archetype_id, {}).duplicate(true)

static func map_template_catalog() -> Dictionary:
	var catalog: Dictionary = {}
	for chapter_value in MAP_TEMPLATE_SPECS.keys():
		var chapter_id: String = String(chapter_value)
		var chapter_templates: Dictionary = {}
		var specs: Dictionary = MAP_TEMPLATE_SPECS.get(chapter_id, {})
		for template_value in specs.values():
			var template_spec: Dictionary = template_value.duplicate(true)
			var nodes: Dictionary = {}
			for node_value in CHAPTER_NODES.values():
				var node_data: Dictionary = node_value
				var node_id: String = String(node_data.get("id", ""))
				if not node_id.begins_with(chapter_id + "-"):
					continue
				nodes[node_id] = node_data.duplicate(true)
				if String(nodes[node_id].get("type", "")) == "boss":
					nodes[node_id]["edges"] = []
			var virtual_start_id: String = chapter_id + "-00"
			if not nodes.has(virtual_start_id):
				var first_node_id: String = chapter_id + "-01"
				nodes[virtual_start_id] = {
					"id": virtual_start_id, "layer": 0, "name": "章节入口", "type": "start",
					"edges": [first_node_id], "description": "地图模板校验入口。",
				}
			var overrides: Dictionary = template_spec.get("edge_overrides", {})
			for node_id_value in overrides.keys():
				var node_id: String = String(node_id_value)
				if nodes.has(node_id):
					var node_data: Dictionary = nodes[node_id]
					node_data["edges"] = Array(overrides[node_id_value]).duplicate()
			var template_id: String = String(template_spec.get("id", ""))
			template_spec["chapter_id"] = chapter_id
			template_spec["nodes"] = nodes
			chapter_templates[template_id] = template_spec
		catalog[chapter_id] = chapter_templates
	return catalog

static func spectra_in_pool(pool_tags: Array) -> Array[String]:
	var result: Array[String] = []
	for card_id in SPECTRA.keys():
		var data: Dictionary = SPECTRA[card_id]
		var pools: Array = data.get("pools", [])
		for tag in pool_tags:
			if pools.has(tag):
				result.append(String(card_id))
				break
	return result

static func all_common_spectra() -> Array[String]:
	return spectra_in_pool(["common"])

static func all_rare_spectra() -> Array[String]:
	return spectra_in_pool(["rare", "epic"])

static func type_label(node_type: String) -> String:
	match node_type:
		"start":
			return "起点"
		"combat":
			return "普通战"
		"elite":
			return "精英"
		"challenge":
			return "挑战"
		"event":
			return "事件"
		"chest":
			return "宝箱"
		"shop":
			return "商店"
		"camp":
			return "营火"
		"boss":
			return "Boss"
		_:
			return node_type
