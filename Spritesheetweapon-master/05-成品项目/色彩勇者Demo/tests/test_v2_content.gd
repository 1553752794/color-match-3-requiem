extends SceneTree

const DataValidatorScript = preload("res://scripts/DataValidator.gd")
const GameDataScript = preload("res://scripts/GameData.gd")
const EnemyScript = preload("res://scripts/Enemy.gd")
const MapTemplateResolverScript = preload("res://scripts/MapTemplateResolver.gd")
const SpectrumManagerScript = preload("res://scripts/SpectrumManager.gd")

const ARCHIVE_SCHOOLS: Array[String] = ["red", "blue", "gold", "gray", "green", "purple", "white", "black"]
const CONDITION_TYPES: Array[String] = [
	"color_total", "unique_colors", "cascade", "match_size", "color_sequence",
	"completed_cards", "completed_colors", "gray_pressure", "hp_below", "shield_min",
	"coins_min", "enemy_burn", "enemy_intent", "moves_left_after", "color_events",
	"no_damage_color", "polluted_completed",
]
const EFFECT_TYPES: Array[String] = [
	"damage", "shield", "heal", "pigment", "coins", "burn", "freeze", "cleanse",
	"dye", "draw", "gray_pressure", "self_damage", "move", "damage_reduction",
	"shop_upgrade_discount",
]
const SHOT_MODIFIER_KEYS: Array[String] = [
	"per_hit_bonus", "crit_multiplier_bonus", "crit_chance_bonus", "pierce_bonus",
	"multiball", "ball_damage_ratio", "bonus_gold_pegs", "bonus_damage", "echo_damage",
	"hazard_damage", "lock_pierce", "armor_break_hits", "high_hit_burn",
	"ignore_hazard", "ignore_void",
]
const EVENT_CHOICE_KEYS: Array[String] = [
	"id", "label", "coin_cost", "pigment_cost", "max_hp", "hp", "heal", "coins",
	"pigment", "gray_pressure", "card_id", "card_pool", "character_pool", "relic_pool",
	"relic_id", "shield", "free_shop_refreshes", "upgrade_random", "gray_pressure_delta",
	"peg_upgrade", "peg_upgrade_amount", "chain_event",
]
const REQUIRED_CHAINS: Array[String] = [
	"CHAIN-ASH-ORIGIN", "CHAIN-MIRROR-WITNESS", "CHAIN-DEBT", "CHAIN-ORCHESTRA",
	"CHAIN-CALIBRATION",
]
const ARCHIVE_RELICS: Array[String] = [
	"mist_filter", "night_coin", "aim_gyroscope", "first_orbit", "hazard_capacitor",
	"queue_limiter", "phase_tuning_fork",
]
const ARCHIVE_ENCOUNTERS: Array[String] = [
	"C1-AR1", "C1-AR2", "C2-AR1", "C2-AR2", "C3-AR1", "C3-AR2",
]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_data_validation()
	_test_archive_spectrum_quota()
	_test_spectrum_whitelists()
	_test_generic_conditions_are_playable()
	_test_fragmented_event_chains()
	_test_archive_relic_rotation()
	_test_archive_encounters()
	_test_legacy_intent_normalization()
	_test_archive_map_rotation()
	if failures.is_empty():
		print("V2.0 content tests passed: 9")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_data_validation() -> void:
	var errors: Array[String] = DataValidatorScript.validate_all()
	_expect(errors.is_empty(), "2.0 GameData 必须通过完整数据验证：%s" % str(errors))


func _test_archive_spectrum_quota() -> void:
	var collectible_count: int = 0
	var curse_count: int = 0
	var rarity_counts: Dictionary = {"common": 0, "rare": 0, "epic": 0}
	var school_counts: Dictionary = {}
	var school_rarities: Dictionary = {}
	for school in ARCHIVE_SCHOOLS:
		school_counts[school] = 0
		school_rarities[school] = {}
	for card_value in GameDataScript.SPECTRA.values():
		var card: Dictionary = card_value
		var pools: Array = card.get("pools", [])
		if not pools.has("archive_v2"):
			continue
		if pools.has("curse"):
			curse_count += 1
			continue
		collectible_count += 1
		var rarity: String = String(card.get("rarity", ""))
		var color_key: String = String(card.get("color", ""))
		rarity_counts[rarity] = int(rarity_counts.get(rarity, 0)) + 1
		school_counts[color_key] = int(school_counts.get(color_key, 0)) + 1
		var rarities: Dictionary = school_rarities.get(color_key, {})
		rarities[rarity] = true
		school_rarities[color_key] = rarities

	_expect(GameDataScript.SPECTRA.size() == 119, "2.1.0 色谱目录应为 116 张可收集色谱与 3 张事件诅咒。")
	_expect(collectible_count == 30, "2.0 必须新增 30 张 archive_v2 可收集色谱。")
	_expect(curse_count == 2, "2.0 必须新增 2 张 archive_v2 事件诅咒。")
	_expect(rarity_counts == {"common": 14, "rare": 11, "epic": 5}, "2.0 新色谱稀有度必须为 14/11/5。")
	for school in ARCHIVE_SCHOOLS:
		_expect(int(school_counts.get(school, 0)) >= 3, "%s 学派至少需要 3 张 2.0 色谱。" % school)
		var rarities: Dictionary = school_rarities.get(school, {})
		_expect(rarities.has("common") and rarities.has("rare"), "%s 学派必须同时拥有普通与稀有 2.0 色谱。" % school)


func _test_spectrum_whitelists() -> void:
	for card_id_value in GameDataScript.SPECTRA.keys():
		var card_id: String = String(card_id_value)
		var card: Dictionary = GameDataScript.SPECTRA[card_id]
		if not card.get("pools", []).has("archive_v2"):
			continue
		var condition_type: String = String(card.get("condition_type", ""))
		_expect(CONDITION_TYPES.has(condition_type), "%s 使用了未实现条件：%s。" % [card_id, condition_type])
		_validate_effects(card_id, card.get("effects", []))
		_validate_shot_modifier(card_id, card.get("shot_modifier", {}))
		var upgrade: Dictionary = card.get("upgrade", {})
		_validate_effects(card_id + "+", upgrade.get("effects", []))
		_validate_shot_modifier(card_id + "+", upgrade.get("shot_modifier", {}))


func _validate_effects(card_id: String, effects_value: Variant) -> void:
	_expect(effects_value is Array and not effects_value.is_empty(), "%s 必须定义可执行 effects。" % card_id)
	if not effects_value is Array:
		return
	for effect_value in effects_value:
		_expect(effect_value is Dictionary, "%s 的 effect 必须是 Dictionary。" % card_id)
		if not effect_value is Dictionary:
			continue
		var effect: Dictionary = effect_value
		var effect_type: String = String(effect.get("type", ""))
		_expect(EFFECT_TYPES.has(effect_type), "%s 使用了未实现效果：%s。" % [card_id, effect_type])
		_expect(abs(int(effect.get("value", 0))) <= 120, "%s 的单项效果超过 120 硬边界。" % card_id)


func _validate_shot_modifier(card_id: String, modifier_value: Variant) -> void:
	if not modifier_value is Dictionary:
		_expect(false, "%s 的 shot_modifier 必须是 Dictionary。" % card_id)
		return
	var modifier: Dictionary = modifier_value
	for key_value in modifier.keys():
		var key: String = String(key_value)
		_expect(SHOT_MODIFIER_KEYS.has(key), "%s 使用了未实现谱弹修正：%s。" % [card_id, key])
	_expect(int(modifier.get("multiball", 1)) <= 8, "%s 的多球数超过 8。" % card_id)


func _test_generic_conditions_are_playable() -> void:
	var manager: SpectrumManager = SpectrumManagerScript.new()
	manager.begin_turn([{"instance_id": "v2-red", "card_id": "archive_cinder_index", "level": 0}])
	var fired: Array[Dictionary] = manager.register_clear_event(
		{"type": "red", "count": 5, "cascade": 1, "active": true},
		15,
		{"moves_left": 2, "moves_left_after": 1}
	)
	_expect(_fired_card(fired, "archive_cinder_index"), "余烬索引的通用 color_total 条件必须可触发。")

	manager.begin_turn([{"instance_id": "v2-purple", "card_id": "mirror_footnote", "level": 0}])
	manager.register_clear_event({"type": "red", "count": 3, "cascade": 1, "active": true}, 9, {"moves_left": 2})
	fired = manager.register_clear_event({"type": "blue", "count": 3, "cascade": 1, "active": true}, 9, {"moves_left": 1})
	_expect(_fired_card(fired, "mirror_footnote"), "镜面脚注的通用 color_sequence 条件必须可触发。")


func _fired_card(fired: Array[Dictionary], card_id: String) -> bool:
	for result in fired:
		if String(result.get("card_id", "")) == card_id:
			return true
	return false


func _test_fragmented_event_chains() -> void:
	var archive_events: Array[Dictionary] = []
	var rarity_counts: Dictionary = {"common": 0, "uncommon": 0, "rare": 0}
	var fragments: Dictionary = {}
	var chains: Dictionary = {}
	for event_id_value in GameDataScript.EVENTS.keys():
		var event_id: String = String(event_id_value)
		var event_data: Dictionary = GameDataScript.EVENTS[event_id]
		if not event_data.has("fragment_id"):
			continue
		archive_events.append(event_data)
		var rarity: String = String(event_data.get("rarity", ""))
		rarity_counts[rarity] = int(rarity_counts.get(rarity, 0)) + 1
		var fragment_id: String = String(event_data.get("fragment_id", ""))
		_expect(not fragment_id.is_empty() and not fragments.has(fragment_id), "%s 的碎片 ID 必须非空且唯一。" % event_id)
		fragments[fragment_id] = true
		var chain_id: String = String(event_data.get("chain_id", ""))
		var chain_state: Dictionary = chains.get(chain_id, {"stages": [], "chapters": []})
		chain_state["stages"].append(int(event_data.get("chain_stage", 0)))
		chain_state["chapters"].append(String(event_data.get("chapter_id", "")))
		chains[chain_id] = chain_state
		_validate_event_choices(event_id, event_data)

	_expect(GameDataScript.EVENTS.size() == 54, "2.0 事件目录必须从 36 扩充到 54。")
	_expect(archive_events.size() == 18, "2.0 必须新增 18 个碎片化叙事事件。")
	_expect(rarity_counts == {"common": 9, "uncommon": 6, "rare": 3}, "2.0 事件稀有度必须为 9/6/3。")
	for chain_id in REQUIRED_CHAINS:
		var chain_state: Dictionary = chains.get(chain_id, {})
		var stages: Array = chain_state.get("stages", [])
		var chapters: Array = chain_state.get("chapters", [])
		stages.sort()
		chapters.sort()
		_expect(stages == [1, 2, 3], "%s 必须包含起因、证词、余波三阶段。" % chain_id)
		_expect(chapters == ["C1", "C2", "C3"], "%s 必须跨越三章。" % chain_id)


func _validate_event_choices(event_id: String, event_data: Dictionary) -> void:
	var choices: Array = event_data.get("choices", [])
	_expect(choices.size() == 2, "%s 必须提供两个明确选项。" % event_id)
	for choice_value in choices:
		var choice: Dictionary = choice_value
		for key_value in choice.keys():
			var key: String = String(key_value)
			_expect(EVENT_CHOICE_KEYS.has(key), "%s.%s 使用了未实现事件字段。" % [event_id, key])
		_expect(int(choice.get("coins", 0)) <= 65, "%s 的直接金币超过事件上限。" % event_id)
		_expect(int(choice.get("pigment", 0)) <= 2, "%s 的颜料收益超过事件上限。" % event_id)
		_expect(int(choice.get("gray_pressure", 0)) <= 3, "%s 的灰蚀收益超过事件上限。" % event_id)
		_expect(abs(int(choice.get("max_hp", 0))) <= 8, "%s 的最大 HP 改动超过事件上限。" % event_id)
		var card_id: String = String(choice.get("card_id", ""))
		if not card_id.is_empty():
			_expect(GameDataScript.SPECTRA.has(card_id), "%s 引用了不存在的色谱 %s。" % [event_id, card_id])
		var card_pool: Variant = choice.get("card_pool", [])
		if card_pool is Array and not card_pool.is_empty():
			_expect(not GameDataScript.spectra_in_pool(card_pool).is_empty(), "%s 的 card_pool 为空。" % event_id)
		var relic_id: String = String(choice.get("relic_id", ""))
		if not relic_id.is_empty():
			_expect(GameDataScript.RELICS.has(relic_id), "%s 引用了不存在的遗物 %s。" % [event_id, relic_id])


func _test_archive_relic_rotation() -> void:
	var battle_source: String = FileAccess.get_file_as_string("res://scripts/BattleManager.gd")
	var event_relics: Dictionary = {}
	for event_data_value in GameDataScript.EVENTS.values():
		var event_data: Dictionary = event_data_value
		if not event_data.has("fragment_id"):
			continue
		for choice_value in event_data.get("choices", []):
			var relic_id: String = String(choice_value.get("relic_id", ""))
			if not relic_id.is_empty():
				event_relics[relic_id] = true
	for relic_id in ARCHIVE_RELICS:
		var relic: Dictionary = GameDataScript.relic(relic_id)
		_expect(relic.get("archive_v2", false) == true, "%s 必须标记为 2.0 档案馆轮换遗物。" % relic_id)
		_expect(not String(relic.get("archive_note", "")).is_empty(), "%s 必须提供档案叙事。" % relic_id)
		_expect(event_relics.has(relic_id), "%s 必须拥有 2.0 事件中的确定性获取路线。" % relic_id)
		_expect(battle_source.contains('relics.has("%s")' % relic_id), "%s 必须已有实际运行时钩子，禁止空壳遗物。" % relic_id)
	_expect(GameDataScript.RELICS.size() == 72, "仅修改 GameData 时不得把无运行时效果的新遗物混入 72 件掉落池。")


func _test_archive_encounters() -> void:
	var intent_types: Array[String] = [
		"attack", "heavy", "charge", "defend", "pollute", "steal", "resist_dominant",
		"spectrum_drift", "spectrum_suppress", "spectrum_seal", "board_corrupt",
	]
	for encounter_id in ARCHIVE_ENCOUNTERS:
		var encounter: Dictionary = GameDataScript.encounter(encounter_id)
		_expect(not encounter.is_empty(), "缺少 2.0 遭遇：%s。" % encounter_id)
		_expect(encounter.get("reward_pool", []).has("archive_v2"), "%s 必须掉落档案馆色谱。" % encounter_id)
		var chapter: int = int(encounter_id.substr(1, 1))
		var is_elite: bool = String(encounter.get("node_type", "")) == "elite"
		var hp_cap: int = [0, 190, 300, 430][chapter] if is_elite else [0, 140, 210, 320][chapter]
		_expect(int(encounter.get("max_hp", 0)) <= hp_cap, "%s 超过章节 HP 预算。" % encounter_id)
		var previous_type: String = ""
		for intent_value in encounter.get("intents", []):
			var intent: Dictionary = intent_value
			var intent_type: String = String(intent.get("type", ""))
			_expect(intent_types.has(intent_type), "%s 使用了未实现意图：%s。" % [encounter_id, intent_type])
			if intent_type == "heavy":
				_expect(previous_type == "charge", "%s 的重击必须提前一个完整回合预告。" % encounter_id)
			previous_type = intent_type


func _test_legacy_intent_normalization() -> void:
	var aliases: Dictionary = {
		"aim_drift": "spectrum_drift",
		"crit_suppress": "spectrum_suppress",
		"peg_seal": "spectrum_seal",
		"seal": "spectrum_seal",
		"add_hazard": "board_corrupt",
	}
	var legacy_types: Array[String] = []
	for legacy_type_value in aliases.keys():
		var legacy_type: String = String(legacy_type_value)
		legacy_types.append(legacy_type)
		var normalized: Dictionary = GameDataScript.normalize_enemy_intent({"type": legacy_type, "value": 3})
		_expect(String(normalized.get("type", "")) == String(aliases[legacy_type]), "%s 必须归一化为 %s。" % [legacy_type, aliases[legacy_type]])
	_expect(legacy_types.size() == aliases.size(), "旧意图兼容表必须完整转换为可检查的类型集合。")

	var legacy_enemy: Enemy = EnemyScript.new({
		"enemy_name": "兼容性测试敌人",
		"intents": [{"type": "aim_drift", "value": 0.18}],
	})
	_expect(String(legacy_enemy.get_current_intent().get("type", "")) == "spectrum_drift", "Enemy 入口必须归一化旧意图。")
	_expect(legacy_enemy.get_intent_text().begins_with("色谱漂移"), "旧意图归一化后必须使用当前中文显示。")

	for encounter_value in GameDataScript.ENCOUNTERS.values():
		var encounter: Dictionary = encounter_value
		for intent_value in encounter.get("intents", []):
			var intent: Dictionary = intent_value
			_expect(not legacy_types.has(String(intent.get("type", ""))), "%s 仍暴露旧意图类型。" % String(encounter.get("id", "unknown")))


func _test_archive_map_rotation() -> void:
	var catalog: Dictionary = GameDataScript.map_template_catalog()
	var errors: Array[String] = MapTemplateResolverScript.validate_catalog(catalog, 4)
	_expect(errors.is_empty(), "四模板地图目录必须有效：%s" % str(errors))
	for chapter_id in ["C1", "C2", "C3"]:
		var chapter_templates: Dictionary = catalog.get(chapter_id, {})
		_expect(chapter_templates.size() == 4, "%s 必须拥有 4 张轮换地图。" % chapter_id)
		var archive_template: Dictionary = chapter_templates.get("archive", {})
		var path: Array[String] = _first_path(archive_template.get("nodes", {}), chapter_id + "-00")
		_expect(path.has(chapter_id + "-03R") and path.has(chapter_id + "-06R"), "%s 档案地图必须经过事件柜与档案精英。" % chapter_id)
		_expect(path.back() == chapter_id + "-08", "%s 档案地图必须到达章节 Boss。" % chapter_id)


func _first_path(nodes: Dictionary, start_id: String) -> Array[String]:
	var path: Array[String] = []
	var current_id: String = start_id
	for step in range(20):
		if current_id.is_empty() or not nodes.has(current_id) or path.has(current_id):
			break
		path.append(current_id)
		var node: Dictionary = nodes[current_id]
		if String(node.get("type", "")) == "boss":
			break
		var edges: Array = node.get("edges", [])
		if edges.is_empty():
			break
		current_id = String(edges[0])
	return path


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
