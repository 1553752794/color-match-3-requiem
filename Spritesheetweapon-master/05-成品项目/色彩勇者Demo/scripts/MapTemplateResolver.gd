class_name MapTemplateResolver
extends RefCounted

const MIN_PLAYABLE_LAYERS: int = 8
const DEFAULT_MIN_TEMPLATES_PER_CHAPTER: int = 3
const _HASH_MODULUS: int = 2_147_483_629
const _HASH_MULTIPLIER: int = 131


## Selects a template from {chapter_id: {template_id: template}} without relying
## on Dictionary insertion order or global random state.
static func select_template(templates_by_chapter: Dictionary, chapter_id: String, run_seed: int) -> Dictionary:
	var chapter_value: Variant = templates_by_chapter.get(chapter_id, {})
	if not chapter_value is Dictionary:
		return {}

	var chapter_templates: Dictionary = chapter_value
	var template_ids: Array[String] = []
	for template_id_value in chapter_templates.keys():
		var template_id: String = String(template_id_value).strip_edges()
		if not template_id.is_empty() and chapter_templates.get(template_id_value) is Dictionary:
			template_ids.append(template_id)
	template_ids.sort()
	if template_ids.is_empty():
		return {}

	var selected_id: String = template_ids[_stable_index(chapter_id, run_seed, template_ids.size())]
	var selected_value: Variant = chapter_templates.get(selected_id, {})
	if not selected_value is Dictionary:
		return {}
	var selected_template: Dictionary = selected_value
	if not validate_template(selected_template).is_empty():
		return {}
	return selected_template.duplicate(true)


## Valid template shape: {"id": "...", "nodes": {node_id: {type, layer, edges}}}.
## A direct node Dictionary is also accepted for isolated validation.
static func validate_template(template: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var nodes_value: Variant = _nodes_value(template)
	if not nodes_value is Dictionary:
		errors.append("[MISSING_NODES] Template must contain a non-empty nodes Dictionary.")
		return errors

	var source_nodes: Dictionary = nodes_value
	if source_nodes.is_empty():
		errors.append("[MISSING_NODES] Template must contain a non-empty nodes Dictionary.")
		return errors

	var nodes: Dictionary = {}
	for node_id_value in source_nodes.keys():
		var node_id: String = String(node_id_value).strip_edges()
		var node_value: Variant = source_nodes.get(node_id_value)
		if node_id.is_empty() or not node_value is Dictionary:
			errors.append("[INVALID_NODE] Every node must have a non-empty id and Dictionary data.")
			continue
		if nodes.has(node_id):
			errors.append("[DUPLICATE_NODE] Node id '%s' is duplicated after normalization." % node_id)
			continue
		nodes[node_id] = node_value

	var starts: Array[String] = []
	var bosses: Array[String] = []
	var playable_layers: Dictionary = {}
	for node_id_value in nodes.keys():
		var node_id: String = String(node_id_value)
		var node: Dictionary = nodes[node_id]
		var node_type: String = String(node.get("type", "")).strip_edges()
		match node_type:
			"start":
				starts.append(node_id)
			"boss":
				bosses.append(node_id)

		var layer_value: Variant = node.get("layer")
		if not layer_value is int and not layer_value is float:
			errors.append("[INVALID_LAYER] Node '%s' must have a numeric layer." % node_id)
		elif int(layer_value) >= 1:
			playable_layers[int(layer_value)] = true

		var edges_value: Variant = node.get("edges")
		if not edges_value is Array:
			errors.append("[INVALID_EDGES] Node '%s' must have an edges Array." % node_id)
			continue
		for edge_value in edges_value:
			var edge_id: String = String(edge_value).strip_edges()
			if edge_id.is_empty() or not nodes.has(edge_id):
				errors.append("[DANGLING_EDGE] Node '%s' references missing node '%s'." % [node_id, edge_id])

	if starts.is_empty():
		errors.append("[MISSING_START] Template must contain exactly one start node.")
	elif starts.size() > 1:
		errors.append("[MULTIPLE_STARTS] Template must contain exactly one start node.")
	if bosses.is_empty():
		errors.append("[MISSING_BOSS] Template must contain exactly one boss node.")
	elif bosses.size() > 1:
		errors.append("[MULTIPLE_BOSSES] Template must contain exactly one boss node.")
	if playable_layers.size() < MIN_PLAYABLE_LAYERS:
		errors.append(
			"[TOO_FEW_LAYERS] Template has %d playable layers; at least %d are required."
			% [playable_layers.size(), MIN_PLAYABLE_LAYERS]
		)
	if starts.size() == 1 and bosses.size() == 1 and not _is_reachable(nodes, starts[0], bosses[0]):
		errors.append("[UNREACHABLE_BOSS] Boss node '%s' is not reachable from start node '%s'." % [bosses[0], starts[0]])
	return errors


## Validates every candidate and enforces a minimum rotating pool per chapter.
static func validate_catalog(
	templates_by_chapter: Dictionary,
	minimum_templates_per_chapter: int = DEFAULT_MIN_TEMPLATES_PER_CHAPTER
) -> Array[String]:
	var errors: Array[String] = []
	var minimum_count: int = maxi(minimum_templates_per_chapter, 1)
	if templates_by_chapter.is_empty():
		errors.append("[EMPTY_CATALOG] Map template catalog must contain at least one chapter.")
		return errors

	for chapter_id_value in templates_by_chapter.keys():
		var chapter_id: String = String(chapter_id_value).strip_edges()
		var chapter_value: Variant = templates_by_chapter.get(chapter_id_value)
		if chapter_id.is_empty() or not chapter_value is Dictionary:
			errors.append("[INVALID_CHAPTER] Every chapter must have a non-empty id and template Dictionary.")
			continue
		var chapter_templates: Dictionary = chapter_value
		if chapter_templates.size() < minimum_count:
			errors.append(
				"[TOO_FEW_TEMPLATES] Chapter '%s' has %d candidates; at least %d are required."
				% [chapter_id, chapter_templates.size(), minimum_count]
			)
		for template_id_value in chapter_templates.keys():
			var template_id: String = String(template_id_value).strip_edges()
			var template_value: Variant = chapter_templates.get(template_id_value)
			if template_id.is_empty() or not template_value is Dictionary:
				errors.append("[INVALID_TEMPLATE] Chapter '%s' contains an invalid template entry." % chapter_id)
				continue
			var template_errors: Array[String] = validate_template(template_value)
			for template_error in template_errors:
				errors.append("%s %s/%s" % [template_error, chapter_id, template_id])
	return errors


static func _stable_index(chapter_id: String, run_seed: int, candidate_count: int) -> int:
	var stable_hash: int = posmod(run_seed, _HASH_MODULUS)
	for byte_value in chapter_id.to_utf8_buffer():
		stable_hash = posmod(stable_hash * _HASH_MULTIPLIER + int(byte_value), _HASH_MODULUS)
	return posmod(stable_hash, candidate_count)


static func _nodes_value(template: Dictionary) -> Variant:
	if template.has("nodes"):
		return template.get("nodes")
	if _looks_like_node_dictionary(template):
		return template
	return null


static func _looks_like_node_dictionary(value: Dictionary) -> bool:
	if value.is_empty():
		return false
	for node_value in value.values():
		if not node_value is Dictionary:
			return false
		var node: Dictionary = node_value
		if not node.has("type") or not node.has("layer") or not node.has("edges"):
			return false
	return true


static func _is_reachable(nodes: Dictionary, start_id: String, target_id: String) -> bool:
	var pending: Array[String] = [start_id]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var node_id: String = pending.pop_front()
		if visited.has(node_id):
			continue
		visited[node_id] = true
		if node_id == target_id:
			return true
		var node_value: Variant = nodes.get(node_id)
		if not node_value is Dictionary:
			continue
		var node: Dictionary = node_value
		var edges_value: Variant = node.get("edges", [])
		if not edges_value is Array:
			continue
		for edge_value in edges_value:
			var edge_id: String = String(edge_value).strip_edges()
			if nodes.has(edge_id) and not visited.has(edge_id):
				pending.append(edge_id)
	return false
