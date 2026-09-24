extends Node

const GameDataScript = preload("res://scripts/GameData.gd")
const DataValidatorScript = preload("res://scripts/DataValidator.gd")
const MapTemplateResolverScript = preload("res://scripts/MapTemplateResolver.gd")
const AscensionRulesScript = preload("res://scripts/AscensionRules.gd")
const RunStatsScript = preload("res://scripts/RunStats.gd")
const NarrativeMemoryScript = preload("res://scripts/NarrativeMemory.gd")
const StrategyRulesScript = preload("res://scripts/StrategyRules.gd")
const ChapterProjectsScript = preload("res://scripts/ChapterProjects.gd")
const BASE_STARTING_GOLD: int = 50

signal run_state_changed
signal profile_state_changed

const MAX_HAND_SIZE = 3
const BASE_RETAIN_LIMIT = 1
const PEG_UPGRADE_KEYS: Array[String] = ["critical", "echo", "bounty", "pierce"]
const MAP_CHAPTER_IDS: Array[String] = ["C1", "C2", "C3"]
const VALID_RUN_PHASES: Array[String] = [
	"character_selection", "vow_selection", "policy_selection", "route_selection", "map",
	"battle", "event", "chest", "shop", "camp", "reward", "torn_banner", "ending",
]
const DEFAULT_MAP_TEMPLATE_IDS: Array[String] = ["standard", "risk", "economy"]
const ARCHIVE_MAP_TEMPLATE_ID: String = "archive"
const EVENT_HASH_MODULUS: int = 2_147_483_629
const EVENT_HASH_MULTIPLIER: int = 131

var player_max_hp: int = 120
var player_hp: int = 120
var shield: int = 0
var coins: int = 0
var pigment: int = 0
var gray_pressure: int = 0
var ascension_level: int = 0
var current_node_id: String = "C1-00"
var run_seed: int = 1
var run_phase: String = "character_selection"
var map_template_ids: Dictionary = {}
var map_view_states: Dictionary = {}
var battle_snapshot: Dictionary = {}
var starting_archetype_id: String = ""
var selected_character_id: String = ""
var selected_vow_id: String = ""
var selected_policy_id: String = ""
var chapter_policies: Dictionary = {}
var visited_nodes: Dictionary = {}
var event_assignments: Dictionary = {}
var event_chain_progress: Dictionary = {}
var claimed_memory_nodes: Dictionary = {}
var pending_reward: Dictionary = {}
var retained_card_instance_id: String = ""
var retained_card_instance_ids: Array[String] = []
var next_pollution_bonus: int = 0
var shop_upgrade_discount: float = 0.0
var shop_delete_count: int = 0
var shop_upgrade_count: int = 0
var shop_purchase_count: int = 0
var shop_refresh_count: int = 0
var free_shop_refreshes: int = 0
var relic_shop_discount: float = 0.0
var skipped_card_reward_previous: bool = false
var white_feather_used_chapters: Dictionary = {}
var pending_torn_banner_reward: bool = false
var pending_event_chain_id: String = ""
var current_options: Array[String] = []

var deck: Array[Dictionary] = []
var draw_pile: Array[String] = []
var discard_pile: Array[String] = []
var hand: Array[String] = []
var relics: Array[String] = []
var color_bias: Dictionary = {}
var color_usage: Dictionary = {}
var peg_upgrades: Dictionary = {}
var data_validation_errors: Array[String] = []
var next_card_instance_serial: int = 1
var run_stats: RefCounted = RunStatsScript.new()
var unlocked_memory_ids: Array[String] = []
var equipped_memory_ids: Array[String] = []
var memory_insight: int = 0
var projects: RefCounted = ChapterProjectsScript.new()

func _ready() -> void:
	_ensure_memory_profile()
	data_validation_errors = DataValidatorScript.validate_all()
	for validation_error in data_validation_errors:
		push_error("游戏数据校验失败：%s" % validation_error)

func reset_run() -> void:
	player_max_hp = 120
	player_hp = player_max_hp
	shield = 0
	coins = BASE_STARTING_GOLD
	pigment = 1
	gray_pressure = 0
	current_node_id = "C1-00"
	run_seed = randi()
	run_phase = "character_selection"
	run_stats.reset()
	run_stats.start(str(run_seed), {"ascension": ascension_level})
	map_template_ids.clear()
	map_view_states.clear()
	battle_snapshot.clear()
	_select_map_templates()
	starting_archetype_id = ""
	selected_character_id = ""
	selected_vow_id = ""
	selected_policy_id = ""
	chapter_policies.clear()
	projects = ChapterProjectsScript.new()
	visited_nodes.clear()
	event_assignments.clear()
	event_chain_progress.clear()
	claimed_memory_nodes.clear()
	pending_reward.clear()
	retained_card_instance_id = ""
	retained_card_instance_ids.clear()
	next_pollution_bonus = 0
	shop_upgrade_discount = 0.0
	shop_delete_count = 0
	shop_upgrade_count = 0
	shop_purchase_count = 0
	shop_refresh_count = 0
	free_shop_refreshes = 0
	relic_shop_discount = 0.0
	skipped_card_reward_previous = false
	white_feather_used_chapters.clear()
	pending_torn_banner_reward = false
	pending_event_chain_id = ""
	current_options.clear()
	next_card_instance_serial = 1
	deck.clear()
	for card_id in GameDataScript.INITIAL_DECK:
		deck.append(create_card_instance(card_id))
	draw_pile = _all_deck_instance_ids()
	draw_pile.shuffle()
	discard_pile.clear()
	hand.clear()
	relics.clear()
	color_bias = {"red": 0, "blue": 0, "gold": 0}
	color_usage = {"gray": 0, "red": 0, "blue": 0, "gold": 0}
	peg_upgrades = {"critical": 0, "echo": 0, "bounty": 0, "pierce": 0}
	_ensure_memory_profile()

func get_current_node() -> Dictionary:
	return get_node_data(current_node_id)

func get_node_data(node_id: String) -> Dictionary:
	var node_data: Dictionary = GameDataScript.node(node_id)
	if node_data.is_empty():
		return node_data
	var chapter_id: String = node_id.get_slice("-", 0)
	var template: Dictionary = get_active_map_template(chapter_id)
	var edge_overrides: Variant = template.get("edge_overrides", {})
	if edge_overrides is Dictionary and edge_overrides.has(node_id):
		node_data["edges"] = Array(edge_overrides[node_id]).duplicate()
	return node_data

func get_active_map_template(chapter_id: String = "") -> Dictionary:
	var resolved_chapter: String = chapter_id if chapter_id != "" else get_current_chapter_id()
	var template_id: String = String(map_template_ids.get(resolved_chapter, ""))
	return GameDataScript.MAP_TEMPLATE_SPECS.get(resolved_chapter, {}).get(template_id, {}).duplicate(true)

func get_map_template_label(chapter_id: String = "") -> String:
	var template: Dictionary = get_active_map_template(chapter_id)
	return "%s · %s" % [template.get("name", "未命名路线"), template.get("tag", "")]

func is_archive_map_pool_unlocked() -> bool:
	for set_value in NarrativeMemoryScript.MEMORY_SETS.values():
		var memory_ids: Variant = set_value.get("ids", []) if set_value is Dictionary else []
		if not memory_ids is Array or memory_ids.is_empty():
			continue
		var is_starter_set: bool = true
		for memory_id in memory_ids:
			if not NarrativeMemoryScript.DEFAULT_UNLOCKED.has(String(memory_id)):
				is_starter_set = false
				break
		if is_starter_set:
			continue
		var is_complete: bool = true
		for memory_id in memory_ids:
			if not unlocked_memory_ids.has(String(memory_id)):
				is_complete = false
				break
		if is_complete:
			return true
	return false

func select_map_template_pool(template_id: String) -> bool:
	var requested_available: bool = _is_map_template_pool_available(template_id)
	var resolved_template_id: String = template_id if requested_available else _get_vow_default_map_template_id()
	for chapter_id in MAP_CHAPTER_IDS:
		var chapter_templates: Dictionary = GameDataScript.MAP_TEMPLATE_SPECS.get(chapter_id, {})
		map_template_ids[chapter_id] = resolved_template_id if chapter_templates.has(resolved_template_id) else "standard"
	run_phase = "map"
	run_state_changed.emit()
	return requested_available

func _select_map_templates(saved_ids: Dictionary = {}, archive_unlocked_override: Variant = null) -> void:
	var catalog: Dictionary = GameDataScript.map_template_catalog()
	var archive_unlocked: bool = (
		is_archive_map_pool_unlocked()
		if archive_unlocked_override == null
		else archive_unlocked_override == true
	)
	var fallback_template_id: String = _get_vow_default_map_template_id()
	map_template_ids.clear()
	for chapter_id in MAP_CHAPTER_IDS:
		var saved_id: String = String(saved_ids.get(chapter_id, ""))
		var has_saved_id: bool = saved_ids.has(chapter_id)
		if has_saved_id and _is_map_template_pool_available(saved_id, archive_unlocked):
			map_template_ids[chapter_id] = saved_id
			continue
		if has_saved_id:
			map_template_ids[chapter_id] = fallback_template_id
			continue
		var chapter_catalog: Dictionary = _dictionary_value(catalog.get(chapter_id, {})).duplicate(true)
		if not archive_unlocked:
			chapter_catalog.erase(ARCHIVE_MAP_TEMPLATE_ID)
		var selected: Dictionary = MapTemplateResolverScript.select_template(
			{chapter_id: chapter_catalog},
			chapter_id,
			run_seed
		)
		var selected_id: String = String(selected.get("id", fallback_template_id))
		map_template_ids[chapter_id] = selected_id if _is_map_template_pool_available(selected_id, archive_unlocked) else fallback_template_id

func _is_map_template_pool_available(template_id: String, archive_unlocked_override: Variant = null) -> bool:
	if DEFAULT_MAP_TEMPLATE_IDS.has(template_id):
		return true
	if template_id != ARCHIVE_MAP_TEMPLATE_ID:
		return false
	return (
		is_archive_map_pool_unlocked()
		if archive_unlocked_override == null
		else archive_unlocked_override == true
	)

func _get_vow_default_map_template_id() -> String:
	var template_id: String = String(get_selected_vow().get("template_id", "standard"))
	return template_id if DEFAULT_MAP_TEMPLATE_IDS.has(template_id) else "standard"

func get_current_encounter() -> Dictionary:
	var node: Dictionary = get_current_node()
	return _scaled_encounter(GameDataScript.encounter(String(node.get("encounter_id", ""))))

func get_current_event_id() -> String:
	if event_assignments.has(current_node_id):
		var assigned_event_id: String = String(event_assignments[current_node_id])
		if _is_event_chain_stage_unlocked(assigned_event_id):
			return assigned_event_id
		event_assignments.erase(current_node_id)
	var node_data: Dictionary = get_current_node()
	var chain_candidates: Array[String] = []
	var regular_candidates: Array[String] = []
	var event_pool: Variant = node_data.get("event_pool", [])
	if event_pool is Array:
		for event_value in event_pool:
			var pooled_event_id: String = String(event_value)
			if not GameDataScript.EVENTS.has(pooled_event_id) or not _is_event_chain_stage_unlocked(pooled_event_id):
				continue
			var pooled_event: Dictionary = GameDataScript.event(pooled_event_id)
			var target_candidates: Array[String] = chain_candidates if String(pooled_event.get("chain_id", "")).is_empty() == false else regular_candidates
			if not target_candidates.has(pooled_event_id):
				target_candidates.append(pooled_event_id)
	var fallback_event_id: String = String(node_data.get("event_id", ""))
	if chain_candidates.is_empty() and regular_candidates.is_empty() and GameDataScript.EVENTS.has(fallback_event_id) and _is_event_chain_stage_unlocked(fallback_event_id):
		var fallback_event: Dictionary = GameDataScript.event(fallback_event_id)
		if String(fallback_event.get("chain_id", "")).is_empty():
			regular_candidates.append(fallback_event_id)
		else:
			chain_candidates.append(fallback_event_id)
	var candidates: Array[String] = chain_candidates if not chain_candidates.is_empty() else regular_candidates
	if candidates.is_empty():
		return ""
	candidates.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = _event_rng_seed(current_node_id)
	var selected_event_id: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	event_assignments[current_node_id] = selected_event_id
	return selected_event_id

func _event_rng_seed(node_id: String) -> int:
	var stable_hash: int = posmod(run_seed, EVENT_HASH_MODULUS)
	var chapter_id: String = node_id.get_slice("-", 0)
	for byte_value in (chapter_id + "|" + node_id).to_utf8_buffer():
		stable_hash = posmod(stable_hash * EVENT_HASH_MULTIPLIER + int(byte_value), EVENT_HASH_MODULUS)
	return stable_hash

func _is_event_chain_stage_unlocked(event_id: String) -> bool:
	var event_data: Dictionary = GameDataScript.event(event_id)
	if event_data.is_empty():
		return false
	var chain_id: String = String(event_data.get("chain_id", ""))
	var chain_stage: int = int(event_data.get("chain_stage", 0))
	if chain_id.is_empty() or chain_stage <= 0:
		return true
	return int(event_chain_progress.get(chain_id, 0)) == chain_stage - 1

func set_ascension_level(level: int) -> void:
	ascension_level = AscensionRulesScript.clamp_level(level)
	if run_stats != null:
		run_stats.metadata["ascension"] = ascension_level

func get_current_chapter_id() -> String:
	return current_node_id.get_slice("-", 0)

func _scaled_encounter(encounter: Dictionary) -> Dictionary:
	if encounter.is_empty():
		return encounter
	var node_type: String = String(encounter.get("node_type", "combat"))
	var encounter_type: String = "boss" if node_type == "boss" else ("elite" if node_type in ["elite", "challenge"] else "normal")
	var scaled: Dictionary = AscensionRulesScript.apply_to_battle_params({
		"encounter_type": encounter_type,
		"enemy_max_health": int(encounter.get("max_hp", 1)),
		"enemy_health": int(encounter.get("max_hp", 1)),
		"enemy_damage": int(encounter.get("attack", 1)),
	}, ascension_level)
	var base_attack: int = maxi(int(encounter.get("attack", 1)), 1)
	var damage_multiplier: float = float(scaled.get("enemy_damage", base_attack)) / float(base_attack)
	var template_hp_multiplier: float = maxf(float(get_active_map_template().get("enemy_hp_multiplier", 1.0)), 0.01)
	encounter["max_hp"] = maxi(int(round(float(scaled.get("enemy_max_health", encounter.get("max_hp", 1))) * template_hp_multiplier)), 1)
	encounter["attack"] = int(scaled.get("enemy_damage", base_attack))
	var run_rules: Dictionary = AscensionRulesScript.get_cumulative_rules(ascension_level)
	encounter["reward"] = int(round(float(encounter.get("reward", 0)) * float(run_rules.get("gold_reward_multiplier", 1.0))))
	var scaled_intents: Array = []
	for intent_value in encounter.get("intents", []):
		var intent: Dictionary = intent_value.duplicate(true)
		var intent_type: String = String(intent.get("type", ""))
		if intent_type in ["attack", "heavy", "charge"]:
			intent["value"] = int(round(float(intent.get("value", encounter.get("attack", 1))) * damage_multiplier))
			intent["value"] += int(get_selected_policy().get("enemy_damage_bonus", 0))
		elif intent_type == "pollute":
			intent["value"] = int(ceil(float(intent.get("value", 0)) * float(run_rules.get("gray_corruption_multiplier", 1.0))))
		scaled_intents.append(intent)
	encounter["intents"] = scaled_intents
	encounter["attack"] += int(get_selected_policy().get("enemy_damage_bonus", 0))
	return encounter

func choose_node(node_id: String) -> bool:
	if node_id == "" or not GameDataScript.CHAPTER_NODES.has(node_id):
		return false
	if pending_torn_banner_reward or not current_options.has(node_id):
		return false
	var actual_edges: Array = get_current_node().get("edges", [])
	if not actual_edges.has(node_id):
		return false
	if not is_node_available_for_character(node_id):
		return false
	current_node_id = node_id
	battle_snapshot.clear()
	current_options.clear()
	run_phase = _run_phase_for_node(get_current_node())
	run_state_changed.emit()
	return true

func complete_current_node(next_phase: String = "map") -> void:
	if visited_nodes.has(current_node_id):
		return
	battle_snapshot.clear()
	visited_nodes[current_node_id] = true
	var node: Dictionary = get_current_node()
	projects.advance(current_node_id, String(node.get("type", "")))
	current_options = []
	for edge in node.get("edges", []):
		current_options.append(String(edge))
	run_phase = next_phase if VALID_RUN_PHASES.has(next_phase) else "map"
	if String(node.get("type", "")) == "boss" and not node.get("edges", []).is_empty():
		run_phase = "policy_selection"
	if pending_torn_banner_reward:
		run_phase = "torn_banner"
	run_state_changed.emit()

func get_available_node_ids() -> Array[String]:
	var node: Dictionary = get_current_node()
	var edges: Array[String] = []
	for edge in node.get("edges", []):
		edges.append(String(edge))
	return edges

func is_node_available_for_character(node_id: String) -> bool:
	var node_data: Dictionary = get_node_data(node_id)
	if node_data.is_empty():
		return false
	var character_ids: Variant = node_data.get("character_ids", [])
	return not character_ids is Array or character_ids.is_empty() or character_ids.has(selected_character_id)

func is_boss_node() -> bool:
	return String(get_current_node().get("type", "")) == "boss"

func draw_new_turn_hand() -> Array[Dictionary]:
	var retained_lookup: Dictionary = {}
	var valid_retained: Array[String] = []
	for instance_id in retained_card_instance_ids:
		if hand.has(instance_id) and not retained_lookup.has(instance_id):
			valid_retained.append(instance_id)
			retained_lookup[instance_id] = true
	if valid_retained.is_empty() and retained_card_instance_id != "" and hand.has(retained_card_instance_id):
		valid_retained.append(retained_card_instance_id)
		retained_lookup[retained_card_instance_id] = true
	for instance_id in hand:
		if not retained_lookup.has(instance_id):
			discard_pile.append(instance_id)
	hand = valid_retained
	clear_retained_cards()
	while hand.size() < MAX_HAND_SIZE:
		var next_card: Dictionary = draw_card()
		if next_card.is_empty():
			break
		hand.append(String(next_card.get("instance_id", "")))
	return get_hand_card_instances()

func draw_card() -> Dictionary:
	if draw_pile.is_empty():
		_shuffle_discard_into_draw()
	if draw_pile.is_empty():
		return {}
	return get_card_instance(String(draw_pile.pop_back()))

func draw_extra_to_hand() -> Dictionary:
	var card: Dictionary = draw_card()
	if not card.is_empty():
		hand.append(String(card.get("instance_id", "")))
	return card

func retain_card(instance_id: String, extra_limit: int = 0) -> bool:
	if not hand.has(instance_id):
		return false
	if retained_card_instance_ids.has(instance_id):
		retained_card_instance_ids.erase(instance_id)
		_sync_legacy_retained_card()
		return true
	if retained_card_instance_ids.size() >= get_retain_limit(extra_limit):
		return false
	retained_card_instance_ids.append(instance_id)
	_sync_legacy_retained_card()
	return true

func set_retained_cards(instance_ids: Array[String], extra_limit: int = 0) -> void:
	var requested_ids: Array[String] = instance_ids.duplicate()
	retained_card_instance_ids.clear()
	for instance_id in requested_ids:
		if retained_card_instance_ids.size() >= get_retain_limit(extra_limit):
			break
		if hand.has(instance_id) and not retained_card_instance_ids.has(instance_id):
			retained_card_instance_ids.append(instance_id)
	_sync_legacy_retained_card()

func clear_retained_cards() -> void:
	retained_card_instance_ids.clear()
	retained_card_instance_id = ""

func is_card_retained(instance_id: String) -> bool:
	return retained_card_instance_ids.has(instance_id)

func get_retain_limit(extra_limit: int = 0) -> int:
	var relic_bonus: int = 1 if relics.has("colorless_crown") else 0
	return BASE_RETAIN_LIMIT + relic_bonus + max(extra_limit, 0)

func discard_unretained_hand() -> void:
	for card_id in hand:
		discard_pile.append(card_id)
	hand.clear()
	clear_retained_cards()

func create_card_instance(card_id: String, level: int = 0) -> Dictionary:
	if not GameDataScript.SPECTRA.has(card_id):
		return {}
	var instance: Dictionary = {
		"instance_id": "card_%06d" % next_card_instance_serial,
		"card_id": card_id,
		"level": clampi(level, 0, 1),
	}
	next_card_instance_serial += 1
	return instance

func get_card_instance(instance_id: String) -> Dictionary:
	for card in deck:
		if String(card.get("instance_id", "")) == instance_id:
			return card.duplicate(true)
	return {}

func get_hand_card_instances() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance_id in hand:
		var card: Dictionary = get_card_instance(instance_id)
		if not card.is_empty():
			result.append(card)
	return result

func add_card(card_id: String) -> Dictionary:
	var instance: Dictionary = create_card_instance(card_id)
	if instance.is_empty():
		return {}
	deck.append(instance)
	discard_pile.append(String(instance.get("instance_id", "")))
	var color_key: String = String(GameDataScript.spectrum(card_id).get("color", "neutral"))
	if color_bias.has(color_key):
		color_bias[color_key] = int(color_bias[color_key]) + 1
	return instance.duplicate(true)

func upgrade_card(instance_id: String) -> bool:
	var deck_index: int = _find_deck_index(instance_id)
	if deck_index < 0 or is_card_upgraded(instance_id):
		return false
	deck[deck_index]["level"] = 1
	return true

func is_card_upgraded(instance_id: String) -> bool:
	return get_card_level(instance_id) > 0

func get_card_level(instance_id: String) -> int:
	var card: Dictionary = get_card_instance(instance_id)
	return clampi(int(card.get("level", 0)), 0, 1)

func get_upgradable_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card in deck:
		if int(card.get("level", 0)) <= 0:
			result.append(card.duplicate(true))
	return result

func get_upgraded_card_count() -> int:
	var count: int = 0
	for card in deck:
		if int(card.get("level", 0)) > 0:
			count += 1
	return count

func remove_card(instance_id: String) -> bool:
	var deck_index: int = _find_deck_index(instance_id)
	if deck.size() <= 6 or deck_index < 0:
		return false
	deck.remove_at(deck_index)
	draw_pile.erase(instance_id)
	discard_pile.erase(instance_id)
	hand.erase(instance_id)
	retained_card_instance_ids.erase(instance_id)
	_sync_legacy_retained_card()
	return true

func add_relic(relic_id: String) -> void:
	if relic_id != "" and not relics.has(relic_id):
		relics.append(relic_id)
		match relic_id:
			"root_token":
				player_max_hp += 6
				player_hp = min(player_hp + 6, player_max_hp)
			"violet_ticket":
				free_shop_refreshes += 2
			"ivory_key":
				add_pigment(2)
			"ash_contract":
				add_reward_coins(30)
				add_gray_pressure(2)

func upgrade_peg(upgrade_key: String, amount: int = 1) -> bool:
	if not PEG_UPGRADE_KEYS.has(upgrade_key) or amount <= 0:
		return false
	var current_level: int = int(peg_upgrades.get(upgrade_key, 0))
	if current_level >= 3:
		return false
	peg_upgrades[upgrade_key] = mini(current_level + amount, 3)
	run_state_changed.emit()
	return true

func get_total_peg_upgrades() -> int:
	var total: int = 0
	for value in peg_upgrades.values():
		total += int(value)
	return total

func get_selected_character() -> Dictionary:
	var character_id: String = selected_character_id if selected_character_id != "" else starting_archetype_id
	return GameDataScript.starting_archetype(character_id)

func get_selected_vow() -> Dictionary:
	return NarrativeMemoryScript.vow(selected_vow_id)

func get_policy_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for policy_id in StrategyRulesScript.ids():
		result.append(StrategyRulesScript.policy(policy_id))
	return result

func get_selected_policy() -> Dictionary:
	return StrategyRulesScript.policy(selected_policy_id)

func get_policy_battle_shield() -> int:
	return maxi(int(get_selected_policy().get("battle_shield", 0)), 0) + int(projects.effect_total("first_turn_shield"))

func can_start_project(project_id: String) -> bool:
	return run_phase in ["map", "policy_selection", "route_selection"] and coins >= 30 and pigment >= 1 and projects.status(get_strategy_chapter_id()).is_empty() and ChapterProjectsScript.PROJECTS.has(project_id)

func start_project(project_id: String) -> bool:
	if not can_start_project(project_id):
		return false
	if not spend_coins(30):
		return false
	if not spend_pigment(1):
		add_reward_coins(30)
		return false
	if not projects.begin(get_strategy_chapter_id(), project_id):
		add_reward_coins(30)
		add_pigment(1)
		return false
	run_state_changed.emit()
	return true

func apply_policy(policy_id: String) -> bool:
	if not StrategyRulesScript.POLICIES.has(policy_id) or not can_choose_policy():
		return false
	var chapter_id: String = get_strategy_chapter_id()
	selected_policy_id = policy_id
	chapter_policies[chapter_id] = policy_id
	var data: Dictionary = StrategyRulesScript.policy(policy_id)
	free_shop_refreshes += maxi(int(data.get("free_refresh", 0)), 0)
	run_phase = "route_selection" if current_node_id == "C1-00" and run_phase == "policy_selection" else "map"
	run_stats.metadata["policy_id"] = policy_id
	run_state_changed.emit()
	return true

func get_strategy_chapter_id() -> String:
	var node: Dictionary = get_current_node()
	if String(node.get("type", "")) == "boss" and visited_nodes.has(current_node_id):
		var edges: Variant = node.get("edges", [])
		if edges is Array and not edges.is_empty():
			return String(edges[0]).get_slice("-", 0)
	return get_current_chapter_id()

func can_choose_policy() -> bool:
	return selected_character_id != "" and selected_vow_id != "" \
		and run_phase in ["map", "policy_selection", "route_selection"] \
		and not chapter_policies.has(get_strategy_chapter_id()) \
		and not current_options.is_empty() \
		and pending_reward.is_empty() and not pending_torn_banner_reward

func get_gray_pressure_cap() -> int:
	return 20

func apply_vow(vow_id: String) -> bool:
	var vow_data: Dictionary = NarrativeMemoryScript.vow(vow_id)
	if vow_data.is_empty() or starting_archetype_id == "" or selected_vow_id != "":
		return false
	selected_vow_id = vow_id
	run_phase = "policy_selection"
	var template_id: String = String(vow_data.get("template_id", "standard"))
	for chapter_id in MAP_CHAPTER_IDS:
		if GameDataScript.MAP_TEMPLATE_SPECS.get(chapter_id, {}).has(template_id):
			map_template_ids[chapter_id] = template_id
	var max_hp_delta: int = int(vow_data.get("max_hp_delta", 0))
	if max_hp_delta != 0:
		player_max_hp = clampi(player_max_hp + max_hp_delta, 80, 180)
		player_hp = min(player_hp, player_max_hp)
	run_stats.metadata["vow_id"] = vow_id
	run_state_changed.emit()
	return true

func get_memory_effect_total(effect_id: String) -> float:
	var total: float = 0.0
	for memory_id in equipped_memory_ids:
		var memory_data: Dictionary = NarrativeMemoryScript.fragment(memory_id)
		if String(memory_data.get("effect", "")) == effect_id:
			total += float(memory_data.get("value", 0.0))
	total += projects.effect_total(effect_id)
	return total

func unlock_memory(memory_id: String) -> Dictionary:
	if not NarrativeMemoryScript.FRAGMENTS.has(memory_id):
		return {}
	var is_new: bool = not unlocked_memory_ids.has(memory_id)
	if is_new:
		unlocked_memory_ids.append(memory_id)
	else:
		memory_insight += 1 + int(get_selected_vow().get("duplicate_insight_bonus", 0))
	_ensure_memory_profile()
	profile_state_changed.emit()
	return {
		"id": memory_id,
		"new": is_new,
		"insight": memory_insight,
		"data": NarrativeMemoryScript.fragment(memory_id),
	}

func set_equipped_memories(memory_ids: Variant) -> bool:
	var sanitized: Array[String] = NarrativeMemoryScript.sanitize_equipped(memory_ids, unlocked_memory_ids)
	if sanitized.is_empty():
		return false
	equipped_memory_ids = sanitized
	profile_state_changed.emit()
	run_state_changed.emit()
	return true

func toggle_equipped_memory(memory_id: String) -> bool:
	if not unlocked_memory_ids.has(memory_id):
		return false
	var requested: Array[String] = equipped_memory_ids.duplicate()
	if requested.has(memory_id):
		if requested.size() <= 1:
			return false
		requested.erase(memory_id)
	else:
		if requested.size() >= NarrativeMemoryScript.MAX_EQUIPPED:
			requested.pop_front()
		requested.append(memory_id)
	return set_equipped_memories(requested)

func create_profile_snapshot() -> Dictionary:
	_ensure_memory_profile()
	return {
		"unlocked_memory_ids": unlocked_memory_ids.duplicate(),
		"equipped_memory_ids": equipped_memory_ids.duplicate(),
		"memory_insight": memory_insight,
	}

func restore_profile_snapshot(snapshot_value: Variant) -> bool:
	if not snapshot_value is Dictionary:
		_ensure_memory_profile()
		return false
	var snapshot: Dictionary = snapshot_value
	unlocked_memory_ids = NarrativeMemoryScript.sanitize_unlocked(snapshot.get("unlocked_memory_ids", []))
	equipped_memory_ids = NarrativeMemoryScript.sanitize_equipped(snapshot.get("equipped_memory_ids", []), unlocked_memory_ids)
	memory_insight = clampi(int(snapshot.get("memory_insight", 0)), 0, 9999)
	return true

func _ensure_memory_profile() -> void:
	unlocked_memory_ids = NarrativeMemoryScript.sanitize_unlocked(unlocked_memory_ids)
	equipped_memory_ids = NarrativeMemoryScript.sanitize_equipped(equipped_memory_ids, unlocked_memory_ids)
	memory_insight = clampi(memory_insight, 0, 9999)

func get_character_passive_id() -> String:
	return String(get_selected_character().get("passive_id", ""))

func has_character_passive(passive_id: String) -> bool:
	return passive_id != "" and get_character_passive_id() == passive_id

func add_reward_coins(amount: int) -> void:
	var gained: int = max(amount, 0)
	coins += gained
	run_stats.record("coins_gained", gained)

func spend_coins(amount: int) -> bool:
	if amount <= 0 or coins < amount:
		return false
	coins -= amount
	run_stats.record("coins_spent", max(amount, 0))
	return true

func heal(amount: int) -> void:
	var rules: Dictionary = AscensionRulesScript.get_cumulative_rules(ascension_level)
	var scaled_amount: int = int(round(float(max(amount, 0)) * float(rules.get("healing_multiplier", 1.0))))
	player_hp = min(player_hp + scaled_amount, player_max_hp)

func add_shield(amount: int) -> void:
	var gained: int = max(amount, 0)
	shield += gained
	run_stats.record("shield_gained", gained)

func absorb_damage(amount: int) -> int:
	var incoming: int = max(amount, 0)
	var blocked: int = min(shield, incoming)
	shield -= blocked
	var real_damage: int = incoming - blocked
	player_hp = max(player_hp - real_damage, 0)
	run_stats.record("shield_absorbed", blocked)
	return real_damage

func add_pigment(amount: int) -> void:
	pigment += max(amount, 0)

func add_gray_pressure(amount: int) -> int:
	if amount <= 0:
		return 0
	var previous_pressure: int = gray_pressure
	var rules: Dictionary = AscensionRulesScript.get_cumulative_rules(ascension_level)
	var resisted: int = int(get_memory_effect_total("gray_resist")) + int(get_selected_policy().get("gray_resist", 0))
	var template_bonus: int = max(int(get_active_map_template().get("gray_pressure_bonus", 0)), 0)
	var effective_amount: int = max(amount + template_bonus - resisted, 0)
	gray_pressure = min(
		gray_pressure + int(ceil(float(effective_amount) * float(rules.get("gray_corruption_multiplier", 1.0)))),
		get_gray_pressure_cap()
	)
	var chapter_key: String = current_node_id.get_slice("-", 0)
	if relics.has("white_feather") and previous_pressure < 6 and gray_pressure >= 6 and not white_feather_used_chapters.has(chapter_key):
		white_feather_used_chapters[chapter_key] = true
		var reduced: int = min(gray_pressure, 3)
		gray_pressure -= reduced
		return reduced
	return 0

func spend_pigment(amount: int) -> bool:
	if amount <= 0 or pigment < amount:
		return false
	pigment -= amount
	return true

func add_color_bias(color_key: String, amount: int = 1) -> void:
	if color_bias.has(color_key):
		color_bias[color_key] = int(color_bias[color_key]) + amount

func record_color_usage(color_key: String, amount: int) -> void:
	if color_usage.has(color_key):
		color_usage[color_key] = int(color_usage[color_key]) + max(amount, 0)

func get_board_weights() -> Dictionary:
	var weights: Dictionary = GameDataScript.BASE_WEIGHTS.duplicate(true)
	var total_bonus: float = 0.0
	for color_key in color_bias.keys():
		var bonus: float = float(color_bias[color_key]) * 0.06
		weights[color_key] = float(weights[color_key]) + bonus
		total_bonus += bonus
	var pressure_bonus: float = min(0.14, float(gray_pressure) * 0.0075)
	weights["gray"] = float(weights["gray"]) + pressure_bonus
	total_bonus -= pressure_bonus
	if next_pollution_bonus > 0:
		var pollution_bonus: float = min(0.10, float(next_pollution_bonus) * 0.025)
		weights["gray"] = float(weights["gray"]) + pollution_bonus
		total_bonus -= pollution_bonus
	var ascension_rules: Dictionary = AscensionRulesScript.get_cumulative_rules(ascension_level)
	var ascension_gray: float = float(ascension_rules.get("gray_spawn_chance_add", 0.0))
	weights["gray"] = float(weights["gray"]) + ascension_gray
	total_bonus -= ascension_gray
	weights["gray"] = max(0.30, float(weights["gray"]) - max(total_bonus, 0.0))
	return StrategyRulesScript.apply_weights(weights, selected_policy_id)

func build_battle_reward(encounter: Dictionary) -> Dictionary:
	if not pending_reward.is_empty() and String(pending_reward.get("node_id", "")) == current_node_id:
		return pending_reward.duplicate(true)
	battle_snapshot.clear()
	var node_type: String = String(encounter.get("node_type", "combat"))
	var reward: Dictionary = {
		"transaction_id": "%s:%d" % [current_node_id, Time.get_ticks_usec()],
		"node_id": current_node_id,
		"node_type": node_type,
		"gold": int(encounter.get("reward", 20)),
		"cards": _pick_card_rewards(encounter),
		"relic": "",
		"pigment": 0,
		"skip_bonus": 10,
		"source": String(encounter.get("name", "")),
		"final_boss": encounter.get("final_boss", false) == true,
		"memory_id": "",
	}
	if encounter.get("relic_reward", false) == true:
		reward["relic"] = _pick_relic(["common", "rare"])
		reward["pigment"] = 1 if randf() < 0.5 else 0
	elif node_type == "combat" and randf() < 0.30:
		reward["pigment"] = 1
	elif node_type == "challenge":
		reward["pigment"] = 1
		reward["skip_bonus"] = 15
	if node_type == "boss":
		reward["gold"] = max(int(encounter.get("reward", 0)), 0)
		reward["cards"] = []
		reward["relic"] = String(encounter.get("boss_relic", ""))
		reward["pigment"] = 0 if encounter.get("final_boss", false) == true else 2
		reward["skip_bonus"] = 0
	var vow_data: Dictionary = get_selected_vow()
	var guaranteed_memory: bool = vow_data.get("memory_every_battle", false) == true
	var memory_roll: bool = posmod(run_seed + current_node_id.hash(), 100) < 35
	if not claimed_memory_nodes.has(current_node_id) and (guaranteed_memory or node_type in ["elite", "challenge", "boss"] or memory_roll):
		reward["memory_id"] = NarrativeMemoryScript.reward_for(current_node_id, run_seed, unlocked_memory_ids)
	reward["gold"] = max(
		int(round(float(reward.get("gold", 0)) * float(get_selected_policy().get("reward_multiplier", 1.0))))
		+ int(get_selected_policy().get("reward_bonus", 0))
		+ int(get_memory_effect_total("reward_gold")),
		0
	)
	pending_reward = reward
	run_phase = "reward"
	run_state_changed.emit()
	return reward.duplicate(true)

func has_pending_reward() -> bool:
	return not pending_reward.is_empty()

func get_pending_reward() -> Dictionary:
	return pending_reward.duplicate(true)

func claim_battle_reward(selected_card_id: String = "", skip_cards: bool = false) -> bool:
	if pending_reward.is_empty():
		return false
	if String(pending_reward.get("node_id", "")) != current_node_id or visited_nodes.has(current_node_id):
		return false
	var reward_cards: Array[String] = _valid_card_array(pending_reward.get("cards", []))
	var is_boss_reward: bool = String(pending_reward.get("node_type", "")) == "boss"
	if selected_card_id != "" and not reward_cards.has(selected_card_id):
		return false
	if selected_card_id == "" and not skip_cards and not reward_cards.is_empty() and not is_boss_reward:
		return false

	add_reward_coins(max(int(pending_reward.get("gold", 0)), 0))
	add_pigment(max(int(pending_reward.get("pigment", 0)), 0))
	var relic_id: String = String(pending_reward.get("relic", ""))
	if GameDataScript.RELICS.has(relic_id):
		add_relic(relic_id)
	if selected_card_id != "":
		add_card(selected_card_id)
		run_stats.record_spectrum_tags(GameDataScript.spectrum_tags(selected_card_id), "selected")
	elif skip_cards:
		var skip_gold: int = max(int(pending_reward.get("skip_bonus", 0)), 0)
		if relics.has("clear_quill"):
			skip_gold += 5
		add_reward_coins(skip_gold)
		skipped_card_reward_previous = true
	if relics.has("renewal_flask"):
		heal(4)
	var memory_id: String = String(pending_reward.get("memory_id", ""))
	if memory_id != "" and not claimed_memory_nodes.has(current_node_id):
		unlock_memory(memory_id)
		claimed_memory_nodes[current_node_id] = true
	var memory_heal: int = int(get_memory_effect_total("post_battle_heal"))
	if memory_heal > 0:
		heal(memory_heal)
	if is_boss_reward and pending_reward.get("final_boss", false) != true and relics.has("torn_banner"):
		pending_torn_banner_reward = true
	pending_reward.clear()
	complete_current_node()
	return true

func make_shop_inventory(boss_shop: bool = false) -> Array[Dictionary]:
	var inventory: Array[Dictionary] = []
	var common_cards: Array[String] = _cards_not_owned(GameDataScript.all_common_spectra())
	var rare_cards: Array[String] = _cards_not_owned(GameDataScript.all_rare_spectra())
	common_cards.shuffle()
	rare_cards.shuffle()
	var common_slots: int = 4 if relics.has("travel_bell") else 3
	for i in range(min(common_slots, common_cards.size())):
		inventory.append({"type": "card", "id": common_cards[i], "price": _character_shop_price(45)})
	if not rare_cards.is_empty():
		inventory.append({"type": "card", "id": rare_cards[0], "price": _character_shop_price(70)})
	if not get_upgradable_cards().is_empty():
		inventory.append({"type": "upgrade", "id": "", "price": get_upgrade_price()})
	inventory.append({"type": "remove", "id": "", "price": get_delete_price()})
	inventory.append({"type": "heal", "id": "", "price": _character_shop_price(45 if boss_shop else 40)})
	var peg_candidates: Array[String] = []
	for upgrade_key in PEG_UPGRADE_KEYS:
		if int(peg_upgrades.get(upgrade_key, 0)) < 3:
			peg_candidates.append(upgrade_key)
	if not peg_candidates.is_empty():
		peg_candidates.shuffle()
		var peg_key: String = peg_candidates[0]
		var peg_price: int = 70 + int(peg_upgrades.get(peg_key, 0)) * 25
		inventory.append({"type": "peg_upgrade", "id": peg_key, "price": _character_shop_price(peg_price)})
	if coins >= 100:
		var relic_price: int = 120
		if relic_shop_discount > 0.0:
			relic_price = max(int(round(float(relic_price) * (1.0 - relic_shop_discount))), 1)
		inventory.append({"type": "relic", "id": _pick_relic(["common", "rare"]), "price": _character_shop_price(relic_price)})
	return inventory

func get_shop_refresh_price() -> int:
	if free_shop_refreshes > 0:
		return 0
	var refresh_bonus: int = max(int(get_active_map_template().get("shop_refresh_bonus", 0)), 0)
	return _character_shop_price(max(18 + shop_refresh_count * 7 - refresh_bonus, 0))

func refresh_shop_inventory(boss_shop: bool = false) -> Array[Dictionary]:
	var price: int = get_shop_refresh_price()
	if price == 0:
		free_shop_refreshes -= 1
	elif not spend_coins(price):
		return []
	shop_refresh_count += 1
	run_state_changed.emit()
	return make_shop_inventory(boss_shop)

func get_upgrade_price() -> int:
	var base: int = 55 + shop_upgrade_count * 20
	if shop_upgrade_discount > 0.0:
		base = int(round(float(base) * (1.0 - shop_upgrade_discount)))
	return _character_shop_price(base)

func get_delete_price() -> int:
	var base: int = 65 + shop_delete_count * 25
	if relics.has("merchant_seal") and shop_delete_count == 0:
		base = int(round(float(base) * 0.5))
	return _character_shop_price(base)

func _character_shop_price(base_price: int) -> int:
	var multiplier: float = 0.90 if has_character_passive("merchant_instinct") else 1.0
	multiplier *= float(AscensionRulesScript.get_cumulative_rules(ascension_level).get("shop_price_multiplier", 1.0))
	multiplier *= float(get_selected_policy().get("shop_price_multiplier", 1.0))
	multiplier *= maxf(1.0 - float(projects.effect_total("shop_discount")), 0.1)
	return max(int(round(float(max(base_price, 0)) * multiplier)), 1)

func buy_shop_item(item: Dictionary, target_card_instance_id: String = "") -> bool:
	var item_type: String = String(item.get("type", ""))
	var resolved_target: String = target_card_instance_id
	if item_type == "upgrade":
		if resolved_target == "":
			resolved_target = _pick_upgradable_card()
		if resolved_target == "" or _find_deck_index(resolved_target) < 0 or is_card_upgraded(resolved_target):
			return false
	elif item_type == "remove":
		if resolved_target == "":
			resolved_target = _first_removable_card()
		if resolved_target == "":
			return false
	var price: int = int(item.get("price", 0))
	if not spend_coins(price):
		return false
	match item_type:
		"card":
			add_card(String(item.get("id", "")))
		"upgrade":
			upgrade_card(resolved_target)
			shop_upgrade_count += 1
			shop_upgrade_discount = 0.0
		"remove":
			if not remove_card(resolved_target):
				coins += price
				return false
			shop_delete_count += 1
		"heal":
			heal(max(30, int(round(float(player_max_hp) * 0.25))))
		"relic":
			add_relic(String(item.get("id", "")))
			relic_shop_discount = 0.0
		"peg_upgrade":
			if not upgrade_peg(String(item.get("id", ""))):
				coins += price
				return false
	shop_purchase_count += 1
	if relics.has("gold_ledger") and shop_purchase_count % 3 == 0:
		add_pigment(1)
	run_state_changed.emit()
	return true

func consume_skipped_reward_bonus() -> void:
	skipped_card_reward_previous = false

func get_chest_choices() -> Array[Dictionary]:
	if not relics.has("gilded_key"):
		return []
	return [
		{"id": "relic", "label": "开启遗物匣"},
		{"id": "gold", "label": "取走 45 金币与 1 颜料"},
	]

func apply_chest_reward(choice: String = "") -> Dictionary:
	if visited_nodes.has(current_node_id) or String(get_current_node().get("type", "")) != "chest":
		return {}
	var reward: Dictionary = {}
	if relics.has("gilded_key") and not ["relic", "gold"].has(choice):
		return {}
	var grants_relic: bool = choice == "relic" or (choice == "" and randf() < 0.7)
	if grants_relic:
		var relic_pool: Array[String] = []
		if relics.has("gilded_key"):
			relic_pool.assign(["common", "rare"])
		else:
			relic_pool.assign(["common"])
		var relic_id: String = _pick_relic(relic_pool)
		add_relic(relic_id)
		reward = {"title": "旧调色箱", "body": "获得遗物：%s" % GameDataScript.relic(relic_id).get("name", relic_id), "relic_id": relic_id}
	else:
		var gold_amount: int = 45 if relics.has("gilded_key") else 25
		add_reward_coins(gold_amount)
		pigment += 1
		reward = {"title": "旧调色箱", "body": "获得 %d 金币与 1 颜料。" % gold_amount, "coins": gold_amount, "pigment": 1}
	complete_current_node()
	return reward

func get_torn_banner_candidates(action: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not pending_torn_banner_reward:
		return result
	for card in deck:
		if action == "upgrade" and int(card.get("level", 0)) > 0:
			continue
		result.append(card.duplicate(true))
	return result

func apply_torn_banner_choice(action: String, instance_id: String) -> bool:
	if not pending_torn_banner_reward:
		return false
	var source: Dictionary = get_card_instance(instance_id)
	if source.is_empty():
		return false
	match action:
		"copy":
			var copied: Dictionary = add_card(String(source.get("card_id", "")))
			if copied.is_empty():
				return false
			if int(source.get("level", 0)) > 0:
				upgrade_card(String(copied.get("instance_id", "")))
		"upgrade":
			if not upgrade_card(instance_id):
				return false
		_:
			return false
	pending_torn_banner_reward = false
	run_state_changed.emit()
	return true

func apply_start_choice(choice: String) -> String:
	if not configure_starting_archetype(choice):
		return "这个角色尚未解锁。"
	var archetype: Dictionary = GameDataScript.starting_archetype(choice)
	complete_current_node("vow_selection")
	return "选择了%s：%s。获得起始遗物「%s」。" % [
		archetype.get("name", choice),
		archetype.get("tagline", ""),
		GameDataScript.relic(String(archetype.get("relic", ""))).get("name", ""),
	]

func configure_starting_archetype(archetype_id: String) -> bool:
	var archetype: Dictionary = GameDataScript.starting_archetype(archetype_id)
	if archetype.is_empty():
		return false
	var starter_deck: Variant = archetype.get("deck", [])
	if not starter_deck is Array or starter_deck.is_empty():
		return false
	starting_archetype_id = archetype_id
	selected_character_id = archetype_id
	player_max_hp = max(int(archetype.get("max_hp", 120)), 1)
	player_hp = player_max_hp
	shield = 0
	next_card_instance_serial = 1
	deck.clear()
	for card_id in starter_deck:
		var instance: Dictionary = create_card_instance(String(card_id))
		if instance.is_empty():
			return false
		deck.append(instance)
	var profile_rules: Dictionary = AscensionRulesScript.apply_to_profile_params({"starting_gold": coins, "starting_burden_count": 0}, ascension_level)
	coins = int(profile_rules.get("starting_gold", coins))
	run_stats.record("coins_gained", coins)
	for burden_index in range(int(profile_rules.get("starting_burden_count", 0))):
		var burden: Dictionary = create_card_instance("obsidian_contract")
		if not burden.is_empty():
			deck.append(burden)
	draw_pile = _all_deck_instance_ids()
	draw_pile.shuffle()
	discard_pile.clear()
	hand.clear()
	clear_retained_cards()
	relics.clear()
	add_relic(String(archetype.get("relic", "")))
	color_bias = _color_bias_dictionary(archetype.get("bias", {}))
	run_stats.metadata["character_id"] = archetype_id
	run_stats.metadata["ascension"] = ascension_level
	return true

func apply_event_choice(event_id: String, choice: String) -> String:
	if visited_nodes.has(current_node_id) or String(get_current_node().get("type", "")) != "event":
		return "该事件已经结算。"
	match event_id:
		"shrine":
			if choice == "cleanse":
				player_hp = max(player_hp - 8, 1)
				var removed: String = _first_removable_card()
				if removed != "":
					var removed_card_id: String = String(get_card_instance(removed).get("card_id", removed))
					remove_card(removed)
					complete_current_node()
					return "失去 8 HP，净化了 %s。" % GameDataScript.spectrum(removed_card_id).get("name", removed_card_id)
				complete_current_node()
				return "失去 8 HP，但牌组已很薄，无法继续净化。"
			pigment += 1
			next_pollution_bonus += 2
			complete_current_node()
			return "获得 1 颜料；下一场战斗灰雾更浓。"
		"colorist":
			if choice == "dye" and coins >= 35 and pigment >= 1:
				spend_coins(35)
				pigment -= 1
				add_color_bias(String(["red", "blue", "gold"].pick_random()), 1)
				complete_current_node()
				return "花费 35 金币与 1 颜料，完成一次随机染色。"
			add_reward_coins(12)
			complete_current_node()
			return "跳过染色，获得 12 金币。"
		"gallery":
			if choice == "relic":
				add_relic(_pick_relic(["rare"]))
				add_card("obsidian_contract")
				complete_current_node()
				return "获得稀有遗物，但黑曜契约进入牌组。"
			heal(20)
			complete_current_node()
			return "避开危险画作，回复 20 HP。"
		_:
			return _apply_data_event_choice(event_id, choice)

func get_pending_event_chain_id() -> String:
	return pending_event_chain_id

func _apply_data_event_choice(event_id: String, choice: String) -> String:
	var event_data: Dictionary = GameDataScript.event(event_id)
	if event_data.is_empty():
		return "事件数据无效。"
	if not _is_event_chain_stage_unlocked(event_id):
		return "事件链前序尚未解锁。"
	var selected: Dictionary = {}
	for choice_value in event_data.get("choices", []):
		if String(choice_value.get("id", "")) == choice:
			selected = choice_value
			break
	if selected.is_empty():
		return "事件选项无效。"
	var requested_peg_upgrade: String = String(selected.get("peg_upgrade", ""))
	if requested_peg_upgrade != "" and int(peg_upgrades.get(requested_peg_upgrade, 0)) >= 3:
		return "资源不足：这项谱式调律已经达到上限。"
	var coin_cost: int = max(int(selected.get("coin_cost", 0)), 0)
	var pigment_cost: int = max(int(selected.get("pigment_cost", 0)), 0)
	if coins < coin_cost or pigment < pigment_cost:
		return "资源不足，无法执行这个选择。"
	spend_coins(coin_cost)
	pigment -= pigment_cost
	var summary: Array[String] = []
	var max_hp_delta: int = int(selected.get("max_hp", 0))
	if max_hp_delta != 0:
		player_max_hp = max(player_max_hp + max_hp_delta, 1)
		player_hp = min(player_hp, player_max_hp)
		summary.append("最大 HP %s%d" % ["+" if max_hp_delta > 0 else "", max_hp_delta])
	var hp_delta: int = int(selected.get("hp", 0))
	if hp_delta < 0:
		player_hp = max(player_hp + hp_delta, 1)
		summary.append("失去 %d HP" % abs(hp_delta))
	var heal_amount: int = max(int(selected.get("heal", 0)), 0)
	if heal_amount > 0:
		heal(heal_amount)
		summary.append("回复 %d HP" % heal_amount)
	var coin_gain: int = max(int(selected.get("coins", 0)), 0)
	var pigment_gain: int = max(int(selected.get("pigment", 0)), 0)
	add_reward_coins(coin_gain)
	add_pigment(pigment_gain)
	if coin_gain > 0:
		summary.append("获得 %d 金币" % coin_gain)
	if pigment_gain > 0:
		summary.append("获得 %d 颜料" % pigment_gain)
	var pressure_gain: int = max(int(selected.get("gray_pressure", 0)), 0)
	if pressure_gain > 0:
		add_gray_pressure(pressure_gain)
		summary.append("灰蚀压力 +%d" % pressure_gain)
	var card_id: String = String(selected.get("card_id", ""))
	var card_pool: Variant = selected.get("card_pool", [])
	if selected.get("character_pool", false) == true:
		card_pool = get_selected_character().get("exclusive_pools", [])
	if card_id == "" and card_pool is Array and not card_pool.is_empty():
		var candidates: Array[String] = GameDataScript.spectra_in_pool(card_pool)
		if not candidates.is_empty():
			card_id = String(candidates.pick_random())
	if card_id != "":
		add_card(card_id)
		summary.append("获得《%s》" % GameDataScript.spectrum(card_id).get("name", card_id))
	var relic_pool: Variant = selected.get("relic_pool", [])
	if relic_pool is Array and not relic_pool.is_empty():
		var relic_id: String = _pick_relic(relic_pool)
		add_relic(relic_id)
		summary.append("获得遗物《%s》" % GameDataScript.relic(relic_id).get("name", relic_id))
	var exact_relic_id: String = String(selected.get("relic_id", ""))
	if GameDataScript.RELICS.has(exact_relic_id):
		add_relic(exact_relic_id)
		summary.append("获得遗物《%s》" % GameDataScript.relic(exact_relic_id).get("name", exact_relic_id))
	var shield_gain: int = max(int(selected.get("shield", 0)), 0)
	if shield_gain > 0:
		add_shield(shield_gain)
		summary.append("获得 %d 护盾" % shield_gain)
	var free_refresh_gain: int = max(int(selected.get("free_shop_refreshes", 0)), 0)
	if free_refresh_gain > 0:
		free_shop_refreshes += free_refresh_gain
		summary.append("免费刷新 +%d" % free_refresh_gain)
	if selected.get("upgrade_random", false) == true:
		var upgrade_target: String = _pick_upgradable_card()
		if upgrade_target != "" and upgrade_card(upgrade_target):
			var upgraded_card_id: String = String(get_card_instance(upgrade_target).get("card_id", ""))
			summary.append("精研《%s》" % GameDataScript.spectrum(upgraded_card_id).get("name", upgraded_card_id))
	var pressure_delta: int = int(selected.get("gray_pressure_delta", 0))
	if pressure_delta != 0:
		gray_pressure = max(gray_pressure + pressure_delta, 0)
		summary.append("灰蚀压力 %s%d" % ["+" if pressure_delta > 0 else "", pressure_delta])
	var peg_upgrade_key: String = String(selected.get("peg_upgrade", ""))
	if peg_upgrade_key != "" and upgrade_peg(peg_upgrade_key, max(int(selected.get("peg_upgrade_amount", 1)), 1)):
		summary.append("%s调律 +1" % peg_upgrade_key)
	_advance_event_chain(event_data)
	var chain_event_id: String = String(selected.get("chain_event", ""))
	if chain_event_id != "" and GameDataScript.EVENTS.has(chain_event_id):
		pending_event_chain_id = chain_event_id
		run_state_changed.emit()
	else:
		pending_event_chain_id = ""
		complete_current_node()
	return "；".join(summary) + "。" if not summary.is_empty() else "事件结束。"

func _advance_event_chain(event_data: Dictionary) -> void:
	var chain_id: String = String(event_data.get("chain_id", ""))
	var chain_stage: int = int(event_data.get("chain_stage", 0))
	if chain_id.is_empty() or chain_stage <= 0:
		return
	if int(event_chain_progress.get(chain_id, 0)) == chain_stage - 1:
		event_chain_progress[chain_id] = chain_stage

func apply_camp_choice(choice: String) -> String:
	if visited_nodes.has(current_node_id) or String(get_current_node().get("type", "")) != "camp":
		return "该营地已经结算。"
	match choice:
		"sell_pigment":
			if pigment < 2:
				return "颜料不足，无法出售。"
			spend_pigment(2)
			add_reward_coins(35)
			complete_current_node()
			return "出售 2 颜料，获得 35 金币。"
		"refine_color":
			if coins < 25:
				return "金币不足，无法提炼。"
			spend_coins(25)
			add_pigment(1)
			gray_pressure = max(gray_pressure - 2, 0)
			complete_current_node()
			return "花费 25 金币，提炼 1 颜料并降低 2 点灰蚀压力。"
		"heal":
			var amount: int = 30 if current_node_id != "C1-07" else 24
			heal(amount)
			complete_current_node()
			return "回复 %d HP。" % amount
		"upgrade":
			return apply_camp_upgrade(_pick_upgradable_card())
		"cleanse":
			var removed: String = _first_removable_card()
			if removed != "":
				var removed_card_id: String = String(get_card_instance(removed).get("card_id", removed))
				remove_card(removed)
				complete_current_node()
				return "净化了 %s。" % GameDataScript.spectrum(removed_card_id).get("name", removed_card_id)
			complete_current_node()
			return "牌组太薄，无法继续净化。"
		_:
			complete_current_node()
			return "你侦察到 Boss 会反制当前最高颜色倾向。"

func get_camp_conversion_options() -> Array[Dictionary]:
	return [
		{"id": "sell_pigment", "label": "出售颜料", "description": "消耗 2 颜料，获得 35 金币。"},
		{"id": "refine_color", "label": "提炼净色", "description": "消耗 25 金币，获得 1 颜料并降低 2 点灰蚀压力。"},
	]

func apply_camp_upgrade(instance_id: String) -> String:
	if visited_nodes.has(current_node_id) or String(get_current_node().get("type", "")) != "camp":
		return "该营地已经结算。"
	var card_id: String = String(get_card_instance(instance_id).get("card_id", ""))
	if not upgrade_card(instance_id):
		return "这张色谱无法继续精研。"
	complete_current_node()
	return "精研了 %s。" % GameDataScript.spectrum(card_id).get("name", card_id)

func get_total_usage() -> int:
	var total: int = 0
	for color_key in color_usage.keys():
		total += int(color_usage[color_key])
	return total

func get_usage_ratios() -> Dictionary:
	var total: int = max(get_total_usage(), 1)
	var ratios: Dictionary = {}
	for color_key in color_usage.keys():
		ratios[color_key] = float(color_usage[color_key]) / float(total)
	return ratios

func get_dominant_color() -> String:
	var top_key: String = "gray"
	var top_value: int = -1
	for color_key in color_usage.keys():
		if int(color_usage[color_key]) > top_value:
			top_value = int(color_usage[color_key])
			top_key = String(color_key)
	return top_key

func get_dominant_player_color() -> String:
	var top_key: String = "red"
	var top_value: int = -1
	for color_key in GameDataScript.PLAYER_COLORS:
		if int(color_usage.get(color_key, 0)) > top_value:
			top_value = int(color_usage.get(color_key, 0))
			top_key = color_key
	return top_key

func get_lowest_player_color_ratio() -> float:
	var player_total: int = 0
	for color_key in GameDataScript.PLAYER_COLORS:
		player_total += max(int(color_usage.get(color_key, 0)), 0)
	if player_total <= 0:
		return 0.0
	var lowest_ratio: float = 1.0
	for color_key in GameDataScript.PLAYER_COLORS:
		lowest_ratio = min(lowest_ratio, float(max(int(color_usage.get(color_key, 0)), 0)) / float(player_total))
	return lowest_ratio

func get_finale_crown_shield() -> int:
	if not relics.has("finale_crown"):
		return 0
	return clampi(int(floor(get_lowest_player_color_ratio() * 54.0)), 0, 18)

func get_ending_report(victory: bool = true) -> Dictionary:
	var ratios: Dictionary = get_usage_ratios()
	var top_key: String = get_dominant_color()
	var top_ratio: float = float(ratios.get(top_key, 0.0))
	var memory_progress: Dictionary = NarrativeMemoryScript.set_progress(unlocked_memory_ids)
	var complete_sets: int = 0
	for progress_value in memory_progress.values():
		if progress_value.get("complete", false) == true:
			complete_sets += 1
	var title: String = "色彩平衡者"
	var body: String = "你走过灰雾边境、镜湖工坊与无色王庭，没有让任何一种颜色重新垄断世界。"
	var ending_id: String = "balanced"
	if not victory:
		title = "灰蚀失败"
		body = "灰雾吞没了调色路线。下一次需要更重视净化、护盾和路线风险。"
		ending_id = "defeat"
	elif complete_sets >= 3 and float(ratios.get("red", 0.0)) >= 0.18 and float(ratios.get("blue", 0.0)) >= 0.18 and float(ratios.get("gold", 0.0)) >= 0.18 and float(ratios.get("gray", 0.0)) < 0.40:
		title = "复调终局"
		body = "断色令没有被另一条唯一真相取代。你让彼此矛盾的证词同时留在档案中，回廊因此停止坍缩。"
		ending_id = "polyphony"
	elif gray_pressure >= 12 or float(ratios.get("gray", 0.0)) >= 0.50:
		title = "灰蚀胜利"
		body = "你击败了无色王，却让太多未被解释的空位留在世界里。胜利安静得近乎另一道断色令。"
		ending_id = "gray"
	elif top_ratio >= 0.55 and top_key != "gray":
		title = "%s魔王倾向" % GameDataScript.color_full_name(top_key)
		body = "%s成为你改写世界的主色。强大，但也危险。" % GameDataScript.color_full_name(top_key)
		ending_id = "dominant_%s" % top_key
	var vow_data: Dictionary = get_selected_vow()
	if not vow_data.is_empty():
		body += "\n\n%s" % String(vow_data.get("ending", ""))
	var evidence: Array[String] = [
		"红 %d%% / 蓝 %d%% / 金 %d%% / 灰 %d%%" % [
			int(round(float(ratios.get("red", 0.0)) * 100.0)),
			int(round(float(ratios.get("blue", 0.0)) * 100.0)),
			int(round(float(ratios.get("gold", 0.0)) * 100.0)),
			int(round(float(ratios.get("gray", 0.0)) * 100.0)),
		],
		"完成记忆组 %d / %d" % [complete_sets, NarrativeMemoryScript.MEMORY_SETS.size()],
		"誓约：%s" % String(vow_data.get("name", "未立誓")),
	]
	return {
		"ending_id": ending_id,
		"title": title,
		"body": body,
		"top_key": top_key,
		"top_ratio": top_ratio,
		"ratios": ratios,
		"evidence": evidence,
		"stats": run_stats.summary(),
	}

func create_save_snapshot() -> Dictionary:
	return {
		"player_max_hp": player_max_hp,
		"player_hp": player_hp,
		"shield": shield,
		"coins": coins,
		"pigment": pigment,
		"gray_pressure": gray_pressure,
		"ascension_level": ascension_level,
		"current_node_id": current_node_id,
		"run_phase": run_phase,
		"run_seed": run_seed,
		"map_template_ids": map_template_ids.duplicate(true),
		"map_view_states": map_view_states.duplicate(true),
		"battle_snapshot": battle_snapshot.duplicate(true),
		"starting_archetype_id": starting_archetype_id,
		"selected_character_id": selected_character_id,
		"selected_vow_id": selected_vow_id,
		"selected_policy_id": selected_policy_id,
		"chapter_policies": chapter_policies.duplicate(true),
		"visited_nodes": visited_nodes.duplicate(true),
		"event_assignments": event_assignments.duplicate(true),
		"event_chain_progress": event_chain_progress.duplicate(true),
		"claimed_memory_nodes": claimed_memory_nodes.duplicate(true),
		"unlocked_memory_ids": unlocked_memory_ids.duplicate(),
		"equipped_memory_ids": equipped_memory_ids.duplicate(),
		"memory_insight": memory_insight,
		"pending_reward": pending_reward.duplicate(true),
		"retained_card_instance_id": retained_card_instance_id,
		"retained_card_instance_ids": retained_card_instance_ids.duplicate(),
		"next_pollution_bonus": next_pollution_bonus,
		"shop_upgrade_discount": shop_upgrade_discount,
		"shop_delete_count": shop_delete_count,
		"shop_upgrade_count": shop_upgrade_count,
		"shop_purchase_count": shop_purchase_count,
		"shop_refresh_count": shop_refresh_count,
		"free_shop_refreshes": free_shop_refreshes,
		"relic_shop_discount": relic_shop_discount,
		"skipped_card_reward_previous": skipped_card_reward_previous,
		"white_feather_used_chapters": white_feather_used_chapters.duplicate(true),
		"pending_torn_banner_reward": pending_torn_banner_reward,
		"pending_event_chain_id": pending_event_chain_id,
		"current_options": current_options.duplicate(),
		"deck": deck.duplicate(true),
		"draw_pile": draw_pile.duplicate(),
		"discard_pile": discard_pile.duplicate(),
		"hand": hand.duplicate(),
		"relics": relics.duplicate(),
		"next_card_instance_serial": next_card_instance_serial,
		"color_bias": color_bias.duplicate(true),
		"color_usage": color_usage.duplicate(true),
		"peg_upgrades": peg_upgrades.duplicate(true),
		"run_stats": run_stats.serialize(),
		"chapter_projects": projects.snapshot(),
	}

func restore_save_snapshot(snapshot: Dictionary) -> bool:
	var saved_node_id: String = String(snapshot.get("current_node_id", ""))
	if not GameDataScript.CHAPTER_NODES.has(saved_node_id) or not _has_valid_saved_deck(snapshot.get("deck", [])):
		return false

	var archive_map_unlocked: bool = is_archive_map_pool_unlocked()
	reset_run()
	deck = _restore_deck(snapshot.get("deck", []), snapshot.get("upgraded_cards", {}))
	if deck.is_empty():
		return false
	player_max_hp = max(int(snapshot.get("player_max_hp", 120)), 1)
	player_hp = clampi(int(snapshot.get("player_hp", player_max_hp)), 0, player_max_hp)
	shield = max(int(snapshot.get("shield", 0)), 0)
	coins = max(int(snapshot.get("coins", 0)), 0)
	pigment = max(int(snapshot.get("pigment", 0)), 0)
	gray_pressure = max(int(snapshot.get("gray_pressure", 0)), 0)
	ascension_level = AscensionRulesScript.clamp_level(int(snapshot.get("ascension_level", 0)))
	current_node_id = saved_node_id
	run_seed = int(snapshot.get("run_seed", 1))
	selected_vow_id = String(snapshot.get("selected_vow_id", ""))
	if not NarrativeMemoryScript.VOWS.has(selected_vow_id):
		selected_vow_id = ""
	chapter_policies = _valid_chapter_policies(snapshot.get("chapter_policies", {}))
	var saved_map_template_ids: Dictionary = _dictionary_value(snapshot.get("map_template_ids", {}))
	for chapter_id in MAP_CHAPTER_IDS:
		if not saved_map_template_ids.has(chapter_id):
			saved_map_template_ids[chapter_id] = ""
	_select_map_templates(saved_map_template_ids, archive_map_unlocked)
	map_view_states = _map_view_state_dictionary(snapshot.get("map_view_states", {}))
	battle_snapshot = _valid_battle_snapshot(snapshot.get("battle_snapshot", {}), saved_node_id)
	starting_archetype_id = String(snapshot.get("starting_archetype_id", ""))
	selected_character_id = String(snapshot.get("selected_character_id", starting_archetype_id))
	if not GameDataScript.STARTING_ARCHETYPES.has(selected_character_id):
		selected_character_id = ""
	if not GameDataScript.STARTING_ARCHETYPES.has(starting_archetype_id):
		starting_archetype_id = selected_character_id
	if selected_character_id == "":
		selected_character_id = starting_archetype_id
	visited_nodes = _bool_dictionary(snapshot.get("visited_nodes", {}))
	# The completed boss belongs to the previous chapter; its council already
	# belongs to the next. Keep the latest enacted policy until replaced.
	selected_policy_id = ""
	for chapter_id in MAP_CHAPTER_IDS:
		if chapter_policies.has(chapter_id):
			selected_policy_id = String(chapter_policies[chapter_id])
		if chapter_id == get_strategy_chapter_id():
			break
	event_chain_progress = _valid_event_chain_progress(snapshot.get("event_chain_progress", {}))
	event_assignments = _valid_event_assignments(snapshot.get("event_assignments", {}))
	claimed_memory_nodes = _bool_dictionary(snapshot.get("claimed_memory_nodes", {}))
	var restored_unlocked: Array[String] = NarrativeMemoryScript.sanitize_unlocked(snapshot.get("unlocked_memory_ids", []))
	for memory_id in restored_unlocked:
		if not unlocked_memory_ids.has(memory_id):
			unlocked_memory_ids.append(memory_id)
	equipped_memory_ids = NarrativeMemoryScript.sanitize_equipped(snapshot.get("equipped_memory_ids", equipped_memory_ids), unlocked_memory_ids)
	memory_insight = clampi(max(memory_insight, int(snapshot.get("memory_insight", 0))), 0, 9999)
	pending_reward = _valid_pending_reward(snapshot.get("pending_reward", {}), saved_node_id)
	next_pollution_bonus = max(int(snapshot.get("next_pollution_bonus", 0)), 0)
	shop_upgrade_discount = clampf(float(snapshot.get("shop_upgrade_discount", 0.0)), 0.0, 0.9)
	shop_delete_count = max(int(snapshot.get("shop_delete_count", 0)), 0)
	shop_upgrade_count = max(int(snapshot.get("shop_upgrade_count", 0)), 0)
	shop_purchase_count = max(int(snapshot.get("shop_purchase_count", 0)), 0)
	shop_refresh_count = max(int(snapshot.get("shop_refresh_count", 0)), 0)
	free_shop_refreshes = max(int(snapshot.get("free_shop_refreshes", 0)), 0)
	relic_shop_discount = clampf(float(snapshot.get("relic_shop_discount", 0.0)), 0.0, 0.9)
	skipped_card_reward_previous = snapshot.get("skipped_card_reward_previous", false) == true
	white_feather_used_chapters = _chapter_bool_dictionary(snapshot.get("white_feather_used_chapters", {}))
	pending_torn_banner_reward = snapshot.get("pending_torn_banner_reward", false) == true
	pending_event_chain_id = String(snapshot.get("pending_event_chain_id", ""))
	if not GameDataScript.EVENTS.has(pending_event_chain_id):
		pending_event_chain_id = ""
	current_options = _valid_current_options(snapshot.get("current_options", []), saved_node_id)
	var used_instance_ids: Dictionary = {}
	hand = _restore_pile(snapshot.get("hand", []), used_instance_ids)
	draw_pile = _restore_pile(snapshot.get("draw_pile", []), used_instance_ids)
	discard_pile = _restore_pile(snapshot.get("discard_pile", []), used_instance_ids)
	for instance_id in _all_deck_instance_ids():
		if not used_instance_ids.has(instance_id):
			draw_pile.append(instance_id)
			used_instance_ids[instance_id] = true
	relics = _valid_relic_array(snapshot.get("relics", []))
	color_bias = _color_bias_dictionary(snapshot.get("color_bias", {}))
	color_usage = _color_usage_dictionary(snapshot.get("color_usage", {}))
	peg_upgrades = _peg_upgrade_dictionary(snapshot.get("peg_upgrades", {}))
	projects.restore(snapshot.get("chapter_projects", {}))
	var stats_value: Variant = snapshot.get("run_stats", {})
	if stats_value is Dictionary and not stats_value.is_empty():
		run_stats.restore(stats_value)
	else:
		run_stats.reset()
		run_stats.start(str(run_seed), {"character_id": selected_character_id, "ascension": ascension_level})
	next_card_instance_serial = max(
		next_card_instance_serial,
		int(snapshot.get("next_card_instance_serial", next_card_instance_serial))
	)
	retained_card_instance_ids = _valid_retained_card_array(snapshot.get("retained_card_instance_ids", []))
	if retained_card_instance_ids.is_empty():
		retained_card_instance_id = String(snapshot.get("retained_card_instance_id", ""))
	else:
		_sync_legacy_retained_card()
	if retained_card_instance_id == "" and retained_card_instance_ids.is_empty():
		var legacy_retained_card_id: String = String(snapshot.get("retained_card_id", ""))
		retained_card_instance_id = _first_hand_instance_for_card(legacy_retained_card_id)
	if retained_card_instance_ids.is_empty() and retained_card_instance_id != "" and hand.has(retained_card_instance_id):
		retained_card_instance_ids.append(retained_card_instance_id)
	set_retained_cards(retained_card_instance_ids)
	run_phase = _restored_run_phase(snapshot)
	if run_phase != "battle":
		battle_snapshot.clear()
	return true

func has_battle_snapshot() -> bool:
	return not battle_snapshot.is_empty()

func get_battle_snapshot() -> Dictionary:
	return battle_snapshot.duplicate(true)

func set_battle_snapshot(snapshot: Dictionary) -> void:
	battle_snapshot = snapshot.duplicate(true)
	run_phase = "battle"
	run_state_changed.emit()

func clear_battle_snapshot() -> void:
	battle_snapshot.clear()

func get_map_view_state(chapter_id: String) -> Dictionary:
	var source: Variant = map_view_states.get(chapter_id, {})
	if not source is Dictionary:
		return {}
	var state: Dictionary = source
	var pan_value: Variant = state.get("pan", [0.0, 0.0])
	var pan := Vector2.ZERO
	if pan_value is Array and pan_value.size() >= 2:
		pan = Vector2(float(pan_value[0]), float(pan_value[1]))
	return {
		"zoom": clampf(float(state.get("zoom", 1.0)), 0.75, 1.60),
		"pan": pan,
		"node_id": String(state.get("node_id", "")),
	}

func set_map_view_state(chapter_id: String, zoom: float, pan: Vector2, node_id: String = "") -> void:
	if not MAP_CHAPTER_IDS.has(chapter_id):
		return
	map_view_states[chapter_id] = {
		"zoom": clampf(zoom, 0.75, 1.60),
		"pan": [pan.x, pan.y],
		"node_id": node_id,
	}

func checkpoint_transient_state() -> void:
	run_state_changed.emit()

func _sync_legacy_retained_card() -> void:
	retained_card_instance_id = retained_card_instance_ids[0] if not retained_card_instance_ids.is_empty() else ""

func _valid_retained_card_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for entry in value:
		var instance_id: String = String(entry)
		if hand.has(instance_id) and not result.has(instance_id):
			result.append(instance_id)
	return result

func _valid_event_assignments(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	for node_value in value.keys():
		var node_id: String = String(node_value)
		var event_id: String = String(value[node_value])
		if GameDataScript.CHAPTER_NODES.has(node_id) and GameDataScript.EVENTS.has(event_id) and _is_event_chain_stage_unlocked(event_id):
			result[node_id] = event_id
	return result

func _valid_event_chain_progress(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	var stage_limits: Dictionary = {}
	for event_value in GameDataScript.EVENTS.values():
		if not event_value is Dictionary:
			continue
		var event_data: Dictionary = event_value
		var chain_id: String = String(event_data.get("chain_id", ""))
		var chain_stage: int = int(event_data.get("chain_stage", 0))
		if not chain_id.is_empty() and chain_stage > 0:
			stage_limits[chain_id] = maxi(int(stage_limits.get(chain_id, 0)), chain_stage)
	for chain_value in value.keys():
		var chain_id: String = String(chain_value)
		if not stage_limits.has(chain_id):
			continue
		var stage_value: Variant = value[chain_value]
		if not stage_value is int and not stage_value is float:
			continue
		var restored_stage: int = clampi(int(stage_value), 0, int(stage_limits[chain_id]))
		if restored_stage > 0:
			result[chain_id] = restored_stage
	return result

func _shuffle_discard_into_draw() -> void:
	draw_pile = discard_pile.duplicate()
	discard_pile.clear()
	draw_pile.shuffle()

func _valid_card_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			var card_id: String = String(entry)
			if GameDataScript.SPECTRA.has(card_id):
				result.append(card_id)
	return result

func _has_valid_saved_deck(value: Variant) -> bool:
	if not value is Array or value.is_empty():
		return false
	for entry in value:
		if entry is Dictionary:
			if GameDataScript.SPECTRA.has(String(entry.get("card_id", ""))):
				return true
		elif GameDataScript.SPECTRA.has(String(entry)):
			return true
	return false

func _restore_deck(value: Variant, legacy_upgrades: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used_ids: Dictionary = {}
	var upgrades: Dictionary = legacy_upgrades if legacy_upgrades is Dictionary else {}
	next_card_instance_serial = 1
	if not value is Array:
		return result
	for entry in value:
		var card_id: String = ""
		var instance_id: String = ""
		var level: int = 0
		if entry is Dictionary:
			card_id = String(entry.get("card_id", ""))
			instance_id = String(entry.get("instance_id", ""))
			level = clampi(int(entry.get("level", 0)), 0, 1)
		else:
			card_id = String(entry)
			level = 1 if int(upgrades.get(card_id, 0)) > 0 else 0
		if not GameDataScript.SPECTRA.has(card_id):
			continue
		if instance_id == "" or used_ids.has(instance_id):
			instance_id = _next_unique_card_instance_id(used_ids)
		else:
			used_ids[instance_id] = true
		result.append({"instance_id": instance_id, "card_id": card_id, "level": level})
	while used_ids.has("card_%06d" % next_card_instance_serial):
		next_card_instance_serial += 1
	return result

func _restore_pile(value: Variant, used_instance_ids: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for entry in value:
		var candidate: String = String(entry.get("instance_id", "")) if entry is Dictionary else String(entry)
		if _find_deck_index(candidate) >= 0 and not used_instance_ids.has(candidate):
			result.append(candidate)
			used_instance_ids[candidate] = true
			continue
		for card in deck:
			var instance_id: String = String(card.get("instance_id", ""))
			if String(card.get("card_id", "")) == candidate and not used_instance_ids.has(instance_id):
				result.append(instance_id)
				used_instance_ids[instance_id] = true
				break
	return result

func _next_unique_card_instance_id(used_ids: Dictionary) -> String:
	var instance_id: String = "card_%06d" % next_card_instance_serial
	while used_ids.has(instance_id):
		next_card_instance_serial += 1
		instance_id = "card_%06d" % next_card_instance_serial
	used_ids[instance_id] = true
	next_card_instance_serial += 1
	return instance_id

func _all_deck_instance_ids() -> Array[String]:
	var result: Array[String] = []
	for card in deck:
		result.append(String(card.get("instance_id", "")))
	return result

func _find_deck_index(instance_id: String) -> int:
	for index in range(deck.size()):
		if String(deck[index].get("instance_id", "")) == instance_id:
			return index
	return -1

func _first_hand_instance_for_card(card_id: String) -> String:
	for instance_id in hand:
		if String(get_card_instance(instance_id).get("card_id", "")) == card_id:
			return instance_id
	return ""

func _valid_relic_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			var relic_id: String = String(entry)
			if GameDataScript.RELICS.has(relic_id) and not result.has(relic_id):
				result.append(relic_id)
	return result

func _valid_node_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			var node_id: String = String(entry)
			if GameDataScript.CHAPTER_NODES.has(node_id):
				result.append(node_id)
	return result

func _valid_current_options(value: Variant, node_id: String) -> Array[String]:
	var result: Array[String] = []
	var node_data: Dictionary = get_node_data(node_id)
	var actual_edges: Array = node_data.get("edges", [])
	if value is Array:
		for entry in value:
			var option_id: String = String(entry)
			if not actual_edges.has(option_id) or result.has(option_id):
				continue
			if not GameDataScript.CHAPTER_NODES.has(option_id) or not is_node_available_for_character(option_id):
				continue
			result.append(option_id)
	return result

func _bool_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for key in value.keys():
			var node_id: String = String(key)
			if GameDataScript.CHAPTER_NODES.has(node_id) and value[key] == true:
				result[node_id] = true
	return result

func _chapter_bool_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for key in value.keys():
			var chapter_id: String = String(key)
			if MAP_CHAPTER_IDS.has(chapter_id) and value[key] == true:
				result[chapter_id] = true
	return result

func _run_phase_for_node(node: Dictionary) -> String:
	match String(node.get("type", "")):
		"combat", "elite", "challenge", "boss":
			return "battle"
		"event":
			return "event"
		"chest":
			return "chest"
		"shop":
			return "shop"
		"camp":
			return "camp"
		_:
			return "map"

func _restored_run_phase(snapshot: Dictionary) -> String:
	var requested: String = String(snapshot.get("run_phase", ""))
	var node_phase: String = _run_phase_for_node(get_current_node())
	if current_node_id != "C1-00" and requested in ["", "character_selection", "vow_selection", "route_selection"]:
		return node_phase
	if VALID_RUN_PHASES.has(requested):
		# Older snapshots can carry reset_run()'s default phase while pointing at
		# a node that was already entered. Do not let that stale value hide the
		# node's real re-entry phase.
		if requested == "character_selection" and current_node_id != "C1-00":
			requested = ""
		elif requested == "vow_selection" and (current_node_id != "C1-00" or selected_character_id == ""):
			requested = ""
		elif requested == "route_selection" and (
			current_node_id != "C1-00" or selected_vow_id == "" or selected_policy_id == ""
		):
			requested = ""
		elif requested == "policy_selection" and (
			selected_character_id == "" or selected_vow_id == ""
			or chapter_policies.has(get_strategy_chapter_id())
			or current_options.is_empty() or not pending_reward.is_empty()
			or pending_torn_banner_reward
		):
			requested = ""
		else:
			return requested
	if starting_archetype_id == "" or selected_character_id == "":
		return "character_selection"
	if selected_vow_id == "":
		return "vow_selection"
	if current_node_id == "C1-00" and selected_policy_id == "":
		return "policy_selection"
	if not pending_event_chain_id.is_empty():
		return "event"
	if not pending_reward.is_empty():
		return "reward"
	if pending_torn_banner_reward:
		return "torn_banner"
	if not current_options.is_empty():
		return "map"
	return node_phase

func _color_bias_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {"red": 0, "blue": 0, "gold": 0}
	if value is Dictionary:
		for color_key in result.keys():
			result[color_key] = max(int(value.get(color_key, 0)), 0)
	return result

func _valid_chapter_policies(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	for chapter_value in value.keys():
		if not chapter_value is String or not value[chapter_value] is String:
			continue
		var chapter_id: String = chapter_value
		var policy_id: String = value[chapter_value]
		if MAP_CHAPTER_IDS.has(chapter_id) and StrategyRulesScript.POLICIES.has(policy_id):
			result[chapter_id] = policy_id
	return result

func _color_usage_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {"gray": 0, "red": 0, "blue": 0, "gold": 0}
	if value is Dictionary:
		for color_key in result.keys():
			result[color_key] = max(int(value.get(color_key, 0)), 0)
	return result

func _peg_upgrade_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {"critical": 0, "echo": 0, "bounty": 0, "pierce": 0}
	if not value is Dictionary:
		return result
	for upgrade_key in PEG_UPGRADE_KEYS:
		result[upgrade_key] = clampi(int(value.get(upgrade_key, 0)), 0, 3)
	return result

func _dictionary_value(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _map_view_state_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	for chapter_value in value.keys():
		var chapter_id: String = String(chapter_value)
		if not MAP_CHAPTER_IDS.has(chapter_id):
			continue
		var state_value: Variant = value[chapter_value]
		if not state_value is Dictionary:
			continue
		var state: Dictionary = state_value
		var pan_value: Variant = state.get("pan", [0.0, 0.0])
		var pan_x: float = 0.0
		var pan_y: float = 0.0
		if pan_value is Array and pan_value.size() >= 2:
			pan_x = float(pan_value[0])
			pan_y = float(pan_value[1])
		if is_nan(pan_x) or is_inf(pan_x):
			pan_x = 0.0
		if is_nan(pan_y) or is_inf(pan_y):
			pan_y = 0.0
		var node_id: String = String(state.get("node_id", ""))
		if node_id != "" and not GameDataScript.CHAPTER_NODES.has(node_id):
			node_id = ""
		result[chapter_id] = {
			"zoom": clampf(float(state.get("zoom", 1.0)), 0.75, 1.60),
			"pan": [pan_x, pan_y],
			"node_id": node_id,
		}
	return result

func _valid_battle_snapshot(value: Variant, saved_node_id: String) -> Dictionary:
	if not value is Dictionary:
		return {}
	var source: Dictionary = value
	if int(source.get("snapshot_version", 0)) != 1:
		return {}
	if String(source.get("node_id", "")) != saved_node_id:
		return {}
	if not source.get("enemy", {}) is Dictionary:
		return {}
	if not source.get("spectrum", {}) is Dictionary:
		return {}
	if not source.get("board", {}) is Dictionary:
		return {}
	return source.duplicate(true)

func _valid_pending_reward(value: Variant, saved_node_id: String) -> Dictionary:
	if not value is Dictionary:
		return {}
	var source: Dictionary = value
	if String(source.get("node_id", "")) != saved_node_id:
		return {}
	var node_type: String = String(source.get("node_type", ""))
	if not ["combat", "elite", "challenge", "boss"].has(node_type):
		return {}
	var relic_id: String = String(source.get("relic", ""))
	if relic_id != "" and not GameDataScript.RELICS.has(relic_id):
		relic_id = ""
	return {
		"transaction_id": String(source.get("transaction_id", "%s:restored" % saved_node_id)),
		"node_id": saved_node_id,
		"node_type": node_type,
		"gold": max(int(source.get("gold", 0)), 0),
		"cards": _valid_card_array(source.get("cards", [])),
		"relic": relic_id,
		"pigment": max(int(source.get("pigment", 0)), 0),
		"skip_bonus": max(int(source.get("skip_bonus", 0)), 0),
		"source": String(source.get("source", "")),
		"final_boss": source.get("final_boss", false) == true,
		"memory_id": String(source.get("memory_id", "")) if NarrativeMemoryScript.FRAGMENTS.has(String(source.get("memory_id", ""))) else "",
	}

func _pick_card_rewards(encounter: Dictionary) -> Array[String]:
	var tags: Array = []
	var encounter_tags: Variant = encounter.get("reward_pool", ["common"])
	if encounter_tags is Array:
		tags.assign(encounter_tags)
	var exclusive_pools: Variant = get_selected_character().get("exclusive_pools", [])
	if exclusive_pools is Array:
		for pool_tag in exclusive_pools:
			if not tags.has(pool_tag):
				tags.append(pool_tag)
	var pool: Array[String] = GameDataScript.spectra_in_pool(tags)
	if pool.is_empty():
		pool = GameDataScript.all_common_spectra()
	pool = _cards_not_owned(pool)
	if pool.size() < 3:
		pool.append_array(GameDataScript.all_common_spectra())
	pool.shuffle()
	var result: Array[String] = []
	for card_id in pool:
		if not result.has(card_id):
			result.append(card_id)
		if result.size() >= 3:
			break
	return result

func _cards_not_owned(cards: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for card_id in cards:
		if not _deck_has_card_definition(card_id):
			result.append(card_id)
	return result if not result.is_empty() else cards.duplicate()

func _pick_relic(rarities: Array[String]) -> String:
	var pool: Array[String] = []
	for relic_id in GameDataScript.RELICS.keys():
		var data: Dictionary = GameDataScript.RELICS[relic_id]
		if rarities.has(String(data.get("rarity", "common"))) and not relics.has(String(relic_id)):
			pool.append(String(relic_id))
	if pool.is_empty():
		return ""
	return String(pool.pick_random())

func _first_removable_card() -> String:
	for card in deck:
		var card_id: String = String(card.get("card_id", ""))
		if _deck_card_definition_count(card_id) > 1:
			return String(card.get("instance_id", ""))
	if deck.size() > 6:
		return String(deck[deck.size() - 1].get("instance_id", ""))
	return ""

func _pick_upgradable_card() -> String:
	var candidates: Array[Dictionary] = get_upgradable_cards()
	if candidates.is_empty():
		return ""
	return String(candidates.pick_random().get("instance_id", ""))

func _deck_has_card_definition(card_id: String) -> bool:
	return _deck_card_definition_count(card_id) > 0

func _deck_card_definition_count(card_id: String) -> int:
	var count: int = 0
	for card in deck:
		if String(card.get("card_id", "")) == card_id:
			count += 1
	return count
