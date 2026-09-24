extends RefCounted
class_name DataValidator

const GameDataScript = preload("res://scripts/GameData.gd")

const SPECTRUM_REQUIRED_FIELDS: Array[String] = [
	"name", "color", "rarity", "condition", "effect", "short", "pools",
]
const RELIC_REQUIRED_FIELDS: Array[String] = ["name", "rarity", "description"]
const ENCOUNTER_REQUIRED_FIELDS: Array[String] = [
	"name", "enemy_name", "enemy_id", "max_hp", "attack", "reward", "reward_pool", "node_type", "description",
]
const NODE_REQUIRED_FIELDS: Array[String] = ["layer", "name", "type", "edges", "description"]
const EVENT_REQUIRED_FIELDS: Array[String] = ["title", "body", "choices"]
const ENCOUNTER_NODE_TYPES: Array[String] = ["combat", "elite", "challenge", "boss"]
const RESERVED_REWARD_POOL_TAGS: Array[String] = ["boss"]
const SPECTRUM_TAGS: Array[String] = [
	"燃烧", "冻结", "护盾", "金币", "灰蚀", "连锁", "共鸣", "多色", "自伤",
]


static func validate_all() -> Array[String]:
	return validate_registry(
		GameDataScript.SPECTRA,
		GameDataScript.RELICS,
		GameDataScript.ENCOUNTERS,
		GameDataScript.CHAPTER_NODES,
		GameDataScript.INITIAL_DECK,
		GameDataScript.STARTING_ARCHETYPES,
		GameDataScript.EVENTS
	)


static func validate_registry(
	spectra: Dictionary,
	relics: Dictionary,
	encounters: Dictionary,
	chapter_nodes: Dictionary,
	initial_deck: Array,
	starting_archetypes: Dictionary = {},
	events: Dictionary = {}
) -> Array[String]:
	var errors: Array[String] = []
	_validate_registry_entries("SPECTRA", spectra, SPECTRUM_REQUIRED_FIELDS, errors)
	_validate_registry_entries("RELICS", relics, RELIC_REQUIRED_FIELDS, errors)
	_validate_registry_entries("ENCOUNTERS", encounters, ENCOUNTER_REQUIRED_FIELDS, errors)
	_validate_registry_entries("CHAPTER_NODES", chapter_nodes, NODE_REQUIRED_FIELDS, errors)
	if not events.is_empty():
		_validate_registry_entries("EVENTS", events, EVENT_REQUIRED_FIELDS, errors)
		_validate_event_choices(events, errors)
	_validate_spectrum_pools(spectra, errors)
	_validate_spectrum_tags(spectra, errors)
	_validate_reward_pools(spectra, encounters, errors)
	_validate_node_references(chapter_nodes, encounters, events, errors)
	_validate_boss_reachability(chapter_nodes, errors)
	_validate_initial_deck(spectra, initial_deck, errors)
	_validate_starting_archetypes(spectra, relics, starting_archetypes, errors)
	return errors


static func _validate_registry_entries(
	registry_name: String,
	registry: Dictionary,
	required_fields: Array[String],
	errors: Array[String]
) -> void:
	if registry.is_empty():
		errors.append("[EMPTY_REGISTRY] %s must not be empty." % registry_name)
		return

	var embedded_ids: Dictionary = {}
	for key_value in registry.keys():
		var entry_id: String = String(key_value).strip_edges()
		if entry_id.is_empty():
			errors.append("[INVALID_ID] %s contains an empty registry key." % registry_name)

		var value: Variant = registry.get(key_value)
		if not value is Dictionary:
			errors.append("[INVALID_ENTRY] %s.%s must be a Dictionary." % [registry_name, entry_id])
			continue
		var entry: Dictionary = value
		_validate_optional_embedded_id(registry_name, entry_id, entry, embedded_ids, errors)

		for field_name in required_fields:
			if not entry.has(field_name):
				errors.append("[MISSING_FIELD] %s.%s is missing '%s'." % [registry_name, entry_id, field_name])
				continue
			var field_value: Variant = entry.get(field_name)
			if field_value == null or (field_value is String and String(field_value).strip_edges().is_empty()):
				errors.append("[EMPTY_FIELD] %s.%s.%s must not be empty." % [registry_name, entry_id, field_name])


static func _validate_optional_embedded_id(
	registry_name: String,
	entry_id: String,
	entry: Dictionary,
	embedded_ids: Dictionary,
	errors: Array[String]
) -> void:
	if not entry.has("id"):
		return
	var embedded_id: String = String(entry.get("id", "")).strip_edges()
	if embedded_id.is_empty():
		errors.append("[INVALID_ID] %s.%s has an empty embedded id." % [registry_name, entry_id])
		return
	if embedded_id != entry_id:
		errors.append("[ID_MISMATCH] %s.%s embeds id '%s'." % [registry_name, entry_id, embedded_id])
	if embedded_ids.has(embedded_id):
		errors.append(
			"[DUPLICATE_EMBEDDED_ID] %s.%s and %s.%s both embed id '%s'." % [
				registry_name,
				String(embedded_ids[embedded_id]),
				registry_name,
				entry_id,
				embedded_id,
			]
		)
	else:
		embedded_ids[embedded_id] = entry_id


static func _validate_spectrum_pools(spectra: Dictionary, errors: Array[String]) -> void:
	for key_value in spectra.keys():
		var card_id: String = String(key_value)
		var value: Variant = spectra.get(key_value)
		if not value is Dictionary:
			continue
		var card: Dictionary = value
		var pools_value: Variant = card.get("pools")
		if not pools_value is Array:
			errors.append("[INVALID_FIELD_TYPE] SPECTRA.%s.pools must be an Array." % card_id)
			continue
		var pools: Array = pools_value
		if pools.is_empty():
			errors.append("[EMPTY_CARD_POOLS] SPECTRA.%s.pools must not be empty." % card_id)

static func _validate_spectrum_tags(spectra: Dictionary, errors: Array[String]) -> void:
	for key_value in spectra.keys():
		var card_id: String = String(key_value)
		var tags: Array[String] = GameDataScript.spectrum_tags(card_id)
		if tags.is_empty():
			errors.append("[EMPTY_CARD_TAGS] SPECTRA.%s must have at least one build tag." % card_id)
			continue
		var seen: Dictionary = {}
		for tag in tags:
			if not SPECTRUM_TAGS.has(tag):
				errors.append("[UNKNOWN_CARD_TAG] SPECTRA.%s uses unknown tag '%s'." % [card_id, tag])
			elif seen.has(tag):
				errors.append("[DUPLICATE_CARD_TAG] SPECTRA.%s repeats tag '%s'." % [card_id, tag])
			seen[tag] = true


static func _validate_reward_pools(
	spectra: Dictionary,
	encounters: Dictionary,
	errors: Array[String]
) -> void:
	var pool_tags: Dictionary = {}
	for reserved_tag in RESERVED_REWARD_POOL_TAGS:
		pool_tags[reserved_tag] = true
	for value in spectra.values():
		if not value is Dictionary:
			continue
		var card: Dictionary = value
		var pools_value: Variant = card.get("pools", [])
		if not pools_value is Array:
			continue
		for pool_value in pools_value:
			var pool_tag: String = String(pool_value).strip_edges()
			if not pool_tag.is_empty():
				pool_tags[pool_tag] = true

	for key_value in encounters.keys():
		var encounter_id: String = String(key_value)
		var value: Variant = encounters.get(key_value)
		if not value is Dictionary:
			continue
		var encounter: Dictionary = value
		var reward_pool_value: Variant = encounter.get("reward_pool")
		if not reward_pool_value is Array:
			errors.append("[INVALID_FIELD_TYPE] ENCOUNTERS.%s.reward_pool must be an Array." % encounter_id)
			continue
		var reward_pool: Array = reward_pool_value
		if reward_pool.is_empty():
			errors.append("[EMPTY_REWARD_POOL] ENCOUNTERS.%s.reward_pool must not be empty." % encounter_id)
			continue
		for reward_value in reward_pool:
			var reward_ref: String = String(reward_value).strip_edges()
			if reward_ref.is_empty() or (not spectra.has(reward_ref) and not pool_tags.has(reward_ref)):
				errors.append(
					"[INVALID_REWARD_REFERENCE] ENCOUNTERS.%s.reward_pool references unknown card or pool '%s'." % [
						encounter_id,
						reward_ref,
					]
				)


static func _validate_node_references(
	chapter_nodes: Dictionary,
	encounters: Dictionary,
	events: Dictionary,
	errors: Array[String]
) -> void:
	for key_value in chapter_nodes.keys():
		var node_id: String = String(key_value)
		var value: Variant = chapter_nodes.get(key_value)
		if not value is Dictionary:
			continue
		var node_data: Dictionary = value
		var edges_value: Variant = node_data.get("edges")
		if not edges_value is Array:
			errors.append("[INVALID_FIELD_TYPE] CHAPTER_NODES.%s.edges must be an Array." % node_id)
		else:
			var edges: Array = edges_value
			for edge_value in edges:
				var edge_id: String = String(edge_value).strip_edges()
				if edge_id.is_empty() or not chapter_nodes.has(edge_id):
					errors.append("[DANGLING_EDGE] CHAPTER_NODES.%s points to missing node '%s'." % [node_id, edge_id])

		var node_type: String = String(node_data.get("type", ""))
		if node_type == "event" and not events.is_empty():
			var event_id: String = String(node_data.get("event_id", ""))
			if event_id.is_empty() or not events.has(event_id):
				errors.append("[BAD_EVENT_REF] CHAPTER_NODES.%s references missing event '%s'." % [node_id, event_id])
			var event_pool_value: Variant = node_data.get("event_pool", [])
			if event_pool_value is Array:
				for pooled_event_value in event_pool_value:
					var pooled_event_id: String = String(pooled_event_value)
					if not events.has(pooled_event_id):
						errors.append("[BAD_EVENT_REF] CHAPTER_NODES.%s event_pool references missing event '%s'." % [node_id, pooled_event_id])
		var requires_encounter: bool = ENCOUNTER_NODE_TYPES.has(node_type)
		if not node_data.has("encounter_id"):
			if requires_encounter:
				errors.append("[BAD_ENCOUNTER_REF] CHAPTER_NODES.%s requires encounter_id." % node_id)
			continue
		var encounter_id: String = String(node_data.get("encounter_id", "")).strip_edges()
		if encounter_id.is_empty() or not encounters.has(encounter_id):
			errors.append(
				"[BAD_ENCOUNTER_REF] CHAPTER_NODES.%s references missing encounter '%s'." % [node_id, encounter_id]
			)

static func _validate_event_choices(events: Dictionary, errors: Array[String]) -> void:
	for key_value in events.keys():
		var event_id: String = String(key_value)
		var event_data: Variant = events.get(key_value)
		if not event_data is Dictionary:
			continue
		var choices_value: Variant = event_data.get("choices", [])
		if not choices_value is Array or choices_value.size() < 2:
			errors.append("[INVALID_EVENT_CHOICES] EVENTS.%s must define at least two choices." % event_id)
			continue
		var choice_ids: Dictionary = {}
		for choice_value in choices_value:
			if not choice_value is Dictionary:
				errors.append("[INVALID_EVENT_CHOICE] EVENTS.%s contains a non-Dictionary choice." % event_id)
				continue
			var choice_id: String = String(choice_value.get("id", "")).strip_edges()
			var choice_label: String = String(choice_value.get("label", "")).strip_edges()
			if choice_id.is_empty() or choice_label.is_empty() or choice_ids.has(choice_id):
				errors.append("[INVALID_EVENT_CHOICE] EVENTS.%s has an empty or duplicate choice." % event_id)
			choice_ids[choice_id] = true


static func _validate_boss_reachability(chapter_nodes: Dictionary, errors: Array[String]) -> void:
	var starts: Array[String] = []
	var bosses: Array[String] = []
	for key_value in chapter_nodes.keys():
		var node_id: String = String(key_value)
		var value: Variant = chapter_nodes.get(key_value)
		if not value is Dictionary:
			continue
		var node_data: Dictionary = value
		match String(node_data.get("type", "")):
			"start":
				starts.append(node_id)
			"boss":
				bosses.append(node_id)

	if starts.is_empty():
		errors.append("[MISSING_START] CHAPTER_NODES has no start node.")
	if bosses.is_empty():
		errors.append("[MISSING_BOSS] CHAPTER_NODES has no boss node.")
	if starts.is_empty() or bosses.is_empty():
		return

	var reachable: Dictionary = {}
	var queue: Array[String] = starts.duplicate()
	var cursor: int = 0
	while cursor < queue.size():
		var node_id: String = queue[cursor]
		cursor += 1
		if reachable.has(node_id):
			continue
		reachable[node_id] = true
		var value: Variant = chapter_nodes.get(node_id)
		if not value is Dictionary:
			continue
		var node_data: Dictionary = value
		var edges_value: Variant = node_data.get("edges", [])
		if not edges_value is Array:
			continue
		for edge_value in edges_value:
			var edge_id: String = String(edge_value)
			if chapter_nodes.has(edge_id) and not reachable.has(edge_id):
				queue.append(edge_id)

	for boss_id in bosses:
		if not reachable.has(boss_id):
			errors.append("[UNREACHABLE_BOSS] Boss node '%s' is not reachable from any start node." % boss_id)


static func _validate_initial_deck(
	spectra: Dictionary,
	initial_deck: Array,
	errors: Array[String]
) -> void:
	if initial_deck.is_empty():
		errors.append("[EMPTY_INITIAL_DECK] INITIAL_DECK must not be empty.")
		return
	for card_value in initial_deck:
		var card_id: String = String(card_value).strip_edges()
		if card_id.is_empty() or not spectra.has(card_id):
			errors.append("[INVALID_STARTER_CARD] INITIAL_DECK references unknown card '%s'." % card_id)


static func _validate_starting_archetypes(
	spectra: Dictionary,
	relics: Dictionary,
	starting_archetypes: Dictionary,
	errors: Array[String]
) -> void:
	for key_value in starting_archetypes.keys():
		var archetype_id: String = String(key_value)
		var value: Variant = starting_archetypes.get(key_value)
		if not value is Dictionary:
			errors.append("[INVALID_ARCHETYPE] STARTING_ARCHETYPES.%s must be a Dictionary." % archetype_id)
			continue
		var archetype: Dictionary = value
		if archetype.has("id") and String(archetype.get("id", "")) != archetype_id:
			errors.append("[ID_MISMATCH] STARTING_ARCHETYPES.%s embeds id '%s'." % [archetype_id, archetype.get("id", "")])
		if int(archetype.get("max_hp", 0)) <= 0:
			errors.append("[INVALID_ARCHETYPE_HP] STARTING_ARCHETYPES.%s must define positive max_hp." % archetype_id)
		if String(archetype.get("passive_id", "")).is_empty() or String(archetype.get("passive_text", "")).is_empty():
			errors.append("[INVALID_ARCHETYPE_PASSIVE] STARTING_ARCHETYPES.%s must define a passive id and text." % archetype_id)
		var exclusive_pools: Variant = archetype.get("exclusive_pools", [])
		if not exclusive_pools is Array or exclusive_pools.is_empty():
			errors.append("[INVALID_ARCHETYPE_POOLS] STARTING_ARCHETYPES.%s must define reward pools." % archetype_id)
		var deck_value: Variant = archetype.get("deck", [])
		if not deck_value is Array or deck_value.size() != 8:
			errors.append("[INVALID_ARCHETYPE_DECK] STARTING_ARCHETYPES.%s must contain exactly 8 cards." % archetype_id)
		elif deck_value is Array:
			for card_value in deck_value:
				if not spectra.has(String(card_value)):
					errors.append("[INVALID_ARCHETYPE_CARD] STARTING_ARCHETYPES.%s references unknown card '%s'." % [archetype_id, card_value])
		var relic_id: String = String(archetype.get("relic", ""))
		if not relics.has(relic_id):
			errors.append("[INVALID_ARCHETYPE_RELIC] STARTING_ARCHETYPES.%s references unknown relic '%s'." % [archetype_id, relic_id])
