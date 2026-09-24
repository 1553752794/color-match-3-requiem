extends Node

signal run_saved
signal run_loaded
signal save_failed(message: String)

const NarrativeMemoryScript = preload("res://scripts/NarrativeMemory.gd")
const SAVE_VERSION = 4
const PROFILE_VERSION = 1
const BUILD_VERSION = "2.3.0"
const RUN_SAVE_PATH = "user://run_save.json"
const PROFILE_SAVE_PATH = "user://profile_save.json"
const MIN_ASCENSION_LEVEL: int = 0
const MAX_ASCENSION_LEVEL: int = 10
const MAP_CHAPTER_IDS: Array[String] = ["C1", "C2", "C3"]
const VALID_MAP_TEMPLATE_IDS: Array[String] = ["standard", "risk", "economy", "archive"]
const PEG_UPGRADE_KEYS: Array[String] = ["critical", "echo", "bounty", "pierce"]
const MAX_PEG_UPGRADE_LEVEL: int = 3

var last_error: String = ""
var GameManager: Node
var run_save_path: String = RUN_SAVE_PATH
var profile_save_path: String = PROFILE_SAVE_PATH
var profile_loaded: bool = false

func _ready() -> void:
	_connect_game_manager()

func _connect_game_manager() -> void:
	GameManager = get_node_or_null("/root/GameManager")
	if GameManager != null and not GameManager.run_state_changed.is_connected(save_run):
		GameManager.run_state_changed.connect(save_run)
	if GameManager != null and not GameManager.profile_state_changed.is_connected(save_profile):
		GameManager.profile_state_changed.connect(save_profile)
	if GameManager != null and not profile_loaded:
		load_profile()

func has_run_save() -> bool:
	return _read_candidate(run_save_path, "run").get("ok", false) == true \
		or _read_candidate(run_save_path + ".bak", "run").get("ok", false) == true

func save_run() -> bool:
	if GameManager == null:
		_connect_game_manager()
	if GameManager == null:
		return _fail("GameManager 尚未就绪，无法保存。")
	var payload: Dictionary = {
		"save_version": SAVE_VERSION,
		"build_version": BUILD_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"run": GameManager.create_save_snapshot(),
	}
	if not _atomic_write_json(run_save_path, payload, "run"):
		return false
	last_error = ""
	run_saved.emit()
	return true

func load_run() -> bool:
	if GameManager == null:
		_connect_game_manager()
	if GameManager == null:
		return _fail("GameManager is unavailable; run save cannot be loaded.")
	var candidate: Dictionary = _load_json_with_backup(run_save_path, "run")
	if candidate.get("ok", false) == true and _restore_run_payload(candidate.get("payload", {})):
		last_error = ""
		run_loaded.emit()
		return true
	var backup: Dictionary = _read_candidate(run_save_path + ".bak", "run")
	if backup.get("ok", false) == true and _restore_run_payload(backup.get("payload", {})):
		_repair_primary_from_backup(run_save_path, backup, "run")
		last_error = ""
		run_loaded.emit()
		return true
	return _fail(String(candidate.get("error", "No valid run save was found.")))

func clear_run() -> void:
	_remove_file(run_save_path)
	_remove_file(run_save_path + ".tmp")
	_remove_file(run_save_path + ".bak")

func save_profile() -> bool:
	if GameManager == null:
		_connect_game_manager()
	if GameManager == null:
		return _fail("GameManager 尚未就绪，无法保存账号档案。")
	var payload: Dictionary = {
		"profile_version": PROFILE_VERSION,
		"build_version": BUILD_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"profile": GameManager.create_profile_snapshot(),
	}
	if not _atomic_write_json(profile_save_path, payload, "profile"):
		return false
	profile_loaded = true
	last_error = ""
	return true

func load_profile() -> bool:
	profile_loaded = true
	if GameManager == null:
		return false
	var candidate: Dictionary = _load_json_with_backup(profile_save_path, "profile")
	if candidate.get("ok", false) == true and _restore_profile_payload(candidate.get("payload", {})):
		last_error = ""
		return true
	var backup: Dictionary = _read_candidate(profile_save_path + ".bak", "profile")
	if backup.get("ok", false) == true and _restore_profile_payload(backup.get("payload", {})):
		_repair_primary_from_backup(profile_save_path, backup, "profile")
		last_error = ""
		return true
	return false

func get_run_summary() -> String:
	var candidate: Dictionary = _load_json_with_backup(run_save_path, "run")
	if candidate.get("ok", false) != true:
		return ""
	var recovered_payload: Dictionary = candidate.get("payload", {})
	var recovered_run: Variant = recovered_payload.get("run", {})
	if not recovered_run is Dictionary:
		return ""
	var recovered_deck: Variant = recovered_run.get("deck", [])
	var recovered_deck_count: int = recovered_deck.size() if recovered_deck is Array else 0
	return "HP %d/%d · 金币 %d · 牌组 %d" % [
		int(recovered_run.get("player_hp", 0)),
		int(recovered_run.get("player_max_hp", 0)),
		int(recovered_run.get("coins", 0)),
		recovered_deck_count,
	]

func _atomic_write_json(path: String, payload: Dictionary, label: String) -> bool:
	var temp_path: String = path + ".tmp"
	var backup_path: String = path + ".bak"
	_remove_file(temp_path)

	var serialized: String = JSON.stringify(payload, "\t")
	if not _write_text_file(temp_path, serialized):
		return _fail("Unable to write %s save temporary file." % label)

	var temp_result: Dictionary = _read_candidate(temp_path, label)
	if temp_result.get("ok", false) != true or String(temp_result.get("text", "")) != serialized:
		_remove_file(temp_path)
		return _fail("Unable to validate %s save temporary file." % label)

	var primary_result: Dictionary = _read_candidate(path, label)
	var backup_result: Dictionary = _read_candidate(backup_path, label)
	var primary_exists: bool = FileAccess.file_exists(path)
	var backup_exists: bool = FileAccess.file_exists(backup_path)

	if primary_result.get("ok", false) == true:
		if backup_exists and not _remove_file(backup_path):
			_remove_file(temp_path)
			return _fail("Unable to rotate the previous %s backup." % label)
		if not _rename_file(path, backup_path):
			_remove_file(temp_path)
			return _fail("Unable to preserve the previous %s save." % label)
	else:
		# Never let a malformed primary replace a known-good backup.
		if primary_exists and not _remove_file(path):
			_remove_file(temp_path)
			return _fail("Unable to discard the invalid %s save." % label)
		if backup_exists and backup_result.get("ok", false) != true and not _remove_file(backup_path):
			_remove_file(temp_path)
			return _fail("Unable to discard the invalid %s backup." % label)

	if not _rename_file(temp_path, path):
		_remove_file(temp_path)
		if FileAccess.file_exists(backup_path) and _read_candidate(backup_path, label).get("ok", false) == true:
			_copy_file_text(backup_path, path)
		return _fail("Unable to promote the new %s save." % label)
	return true

func _load_json_with_backup(path: String, label: String) -> Dictionary:
	var primary: Dictionary = _read_candidate(path, label)
	if primary.get("ok", false) == true:
		return primary

	var backup: Dictionary = _read_candidate(path + ".bak", label)
	if backup.get("ok", false) == true:
		_repair_primary_from_backup(path, backup, label)
		backup["used_backup"] = true
		return backup

	return {
		"ok": false,
		"error": String(primary.get("error", "No valid %s save was found." % label)),
	}

func _read_candidate(path: String, label: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "No %s save file exists." % label}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Unable to read %s save file." % label}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {"ok": false, "error": "The %s save JSON is malformed." % label}
	var payload: Dictionary = parsed
	if not _is_valid_payload(payload, label):
		return {"ok": false, "error": "The %s save structure is invalid." % label}
	return {"ok": true, "payload": payload, "text": text}

func _is_valid_payload(payload: Dictionary, label: String) -> bool:
	if label == "run":
		var version: int = int(payload.get("save_version", 0))
		return version > 0 and version <= SAVE_VERSION and payload.get("run", null) is Dictionary
	if label == "profile":
		return int(payload.get("profile_version", 0)) == PROFILE_VERSION and payload.get("profile", null) is Dictionary
	return false

func _restore_run_payload(payload: Variant) -> bool:
	if GameManager == null or not payload is Dictionary:
		return false
	var save_payload: Dictionary = payload
	var version: int = int(save_payload.get("save_version", 0))
	var run_value: Variant = save_payload.get("run", {})
	if version <= 0 or version > SAVE_VERSION or not run_value is Dictionary:
		return false
	return GameManager.restore_save_snapshot(_migrate_run(run_value, version))

func _restore_profile_payload(payload: Variant) -> bool:
	if GameManager == null or not payload is Dictionary:
		return false
	return GameManager.restore_profile_snapshot(payload.get("profile", {}))

func _repair_primary_from_backup(path: String, backup: Dictionary, label: String) -> bool:
	var backup_text: String = String(backup.get("text", ""))
	if backup_text.is_empty():
		return false
	var temp_path: String = path + ".tmp"
	_remove_file(temp_path)
	if not _write_text_file(temp_path, backup_text):
		_remove_file(temp_path)
		return false
	var temp_result: Dictionary = _read_candidate(temp_path, label)
	if temp_result.get("ok", false) != true or String(temp_result.get("text", "")) != backup_text:
		_remove_file(temp_path)
		return false
	if FileAccess.file_exists(path) and not _remove_file(path):
		_remove_file(temp_path)
		return false
	if _rename_file(temp_path, path):
		return true
	_remove_file(temp_path)
	if not FileAccess.file_exists(path):
		_write_text_file(path, backup_text)
	return FileAccess.file_exists(path)

func _write_text_file(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var stored: bool = file.store_string(text)
	file.flush()
	file.close()
	return stored

func _copy_file_text(source: String, destination: String) -> bool:
	var source_file: FileAccess = FileAccess.open(source, FileAccess.READ)
	if source_file == null:
		return false
	var source_text: String = source_file.get_as_text()
	source_file.close()
	return _write_text_file(destination, source_text)

func _rename_file(source: String, destination: String) -> bool:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source),
		ProjectSettings.globalize_path(destination)
	) == OK

func _remove_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK

func _migrate_run(run_data: Dictionary, from_version: int) -> Dictionary:
	var migrated: Dictionary = run_data.duplicate(true)
	var version: int = from_version
	while version < SAVE_VERSION:
		match version:
			1:
				migrated = _migrate_v1_card_instances(migrated)
			2:
				migrated = _migrate_v2_run_fields(migrated)
			3:
				migrated = _migrate_v3_narrative_fields(migrated)
			_:
				break
		version += 1
	return _sanitize_v4_fields(migrated)

func _migrate_v3_narrative_fields(run_data: Dictionary) -> Dictionary:
	var migrated: Dictionary = run_data.duplicate(true)
	migrated["selected_vow_id"] = String(migrated.get("selected_vow_id", ""))
	migrated["claimed_memory_nodes"] = migrated.get("claimed_memory_nodes", {}) if migrated.get("claimed_memory_nodes", {}) is Dictionary else {}
	migrated["unlocked_memory_ids"] = NarrativeMemoryScript.sanitize_unlocked(migrated.get("unlocked_memory_ids", []))
	migrated["equipped_memory_ids"] = NarrativeMemoryScript.sanitize_equipped(migrated.get("equipped_memory_ids", []), migrated["unlocked_memory_ids"])
	migrated["memory_insight"] = clampi(_safe_int(migrated.get("memory_insight", 0)), 0, 9999)
	return _sanitize_v4_fields(migrated)

func _sanitize_v4_fields(run_data: Dictionary) -> Dictionary:
	var sanitized: Dictionary = _sanitize_v3_fields(run_data)
	var vow_id: String = String(sanitized.get("selected_vow_id", ""))
	sanitized["selected_vow_id"] = vow_id if NarrativeMemoryScript.VOWS.has(vow_id) else ""
	sanitized["map_template_ids"] = _map_template_dictionary(
		run_data.get("map_template_ids", {}),
		_default_map_template_id(sanitized["selected_vow_id"])
	)
	sanitized["claimed_memory_nodes"] = sanitized.get("claimed_memory_nodes", {}) if sanitized.get("claimed_memory_nodes", {}) is Dictionary else {}
	sanitized["unlocked_memory_ids"] = NarrativeMemoryScript.sanitize_unlocked(sanitized.get("unlocked_memory_ids", []))
	sanitized["equipped_memory_ids"] = NarrativeMemoryScript.sanitize_equipped(sanitized.get("equipped_memory_ids", []), sanitized["unlocked_memory_ids"])
	sanitized["memory_insight"] = clampi(_safe_int(sanitized.get("memory_insight", 0)), 0, 9999)
	return sanitized

func _migrate_v2_run_fields(run_data: Dictionary) -> Dictionary:
	var migrated: Dictionary = run_data.duplicate(true)
	if not migrated.get("run_stats", {}) is Dictionary:
		migrated["run_stats"] = {}
	if not migrated.get("map_template_ids", {}) is Dictionary:
		migrated["map_template_ids"] = {}
	if not migrated.get("peg_upgrades", {}) is Dictionary:
		migrated["peg_upgrades"] = {}
	return _sanitize_v3_fields(migrated)

func _sanitize_v3_fields(run_data: Dictionary) -> Dictionary:
	var sanitized: Dictionary = run_data.duplicate(true)
	sanitized["ascension_level"] = clampi(
		_safe_int(sanitized.get("ascension_level", MIN_ASCENSION_LEVEL)),
		MIN_ASCENSION_LEVEL,
		MAX_ASCENSION_LEVEL
	)
	sanitized["run_stats"] = _run_stats_dictionary(sanitized.get("run_stats", {}))
	sanitized["map_template_ids"] = _map_template_dictionary(sanitized.get("map_template_ids", {}))
	sanitized["peg_upgrades"] = _peg_upgrade_dictionary(sanitized.get("peg_upgrades", {}))
	return sanitized

func _run_stats_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _map_template_dictionary(value: Variant, fallback_template_id: String = "standard") -> Dictionary:
	var result: Dictionary = {}
	var source: Dictionary = value if value is Dictionary else {}
	var safe_fallback: String = fallback_template_id if VALID_MAP_TEMPLATE_IDS.has(fallback_template_id) and fallback_template_id != "archive" else "standard"
	for chapter_id in MAP_CHAPTER_IDS:
		var template_value: Variant = source.get(chapter_id, "")
		var template_id: String = String(template_value) if template_value is String or template_value is StringName else ""
		result[chapter_id] = template_id if VALID_MAP_TEMPLATE_IDS.has(template_id) else safe_fallback
	return result

func _default_map_template_id(vow_id: String) -> String:
	var template_id: String = String(NarrativeMemoryScript.vow(vow_id).get("template_id", "standard"))
	return template_id if VALID_MAP_TEMPLATE_IDS.has(template_id) and template_id != "archive" else "standard"

func _peg_upgrade_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	var source: Dictionary = value if value is Dictionary else {}
	for upgrade_key in PEG_UPGRADE_KEYS:
		result[upgrade_key] = clampi(
			_safe_int(source.get(upgrade_key, 0)),
			0,
			MAX_PEG_UPGRADE_LEVEL
		)
	return result

func _safe_int(value: Variant, fallback: int = 0) -> int:
	if value is int:
		return int(value)
	if value is float:
		var float_value: float = float(value)
		if not is_nan(float_value) and not is_inf(float_value):
			return int(float_value)
	if value is String or value is StringName:
		var string_value: String = String(value).strip_edges()
		if string_value.is_valid_int():
			return int(string_value)
	return fallback

func _migrate_v1_card_instances(run_data: Dictionary) -> Dictionary:
	var migrated: Dictionary = run_data.duplicate(true)
	var deck_value: Variant = migrated.get("deck", [])
	if not deck_value is Array:
		return migrated
	var legacy_upgrades: Dictionary = migrated.get("upgraded_cards", {}) if migrated.get("upgraded_cards", {}) is Dictionary else {}
	var deck_instances: Array[Dictionary] = []
	var available_by_card: Dictionary = {}
	for index in range(deck_value.size()):
		var card_id: String = String(deck_value[index])
		var instance_id: String = "card_%06d" % (index + 1)
		deck_instances.append({
			"instance_id": instance_id,
			"card_id": card_id,
			"level": 1 if int(legacy_upgrades.get(card_id, 0)) > 0 else 0,
		})
		if not available_by_card.has(card_id):
			available_by_card[card_id] = []
		available_by_card[card_id].append(instance_id)

	var used_ids: Dictionary = {}
	for pile_name in ["hand", "draw_pile", "discard_pile"]:
		var migrated_pile: Array[String] = []
		var pile_value: Variant = migrated.get(pile_name, [])
		if pile_value is Array:
			for entry in pile_value:
				var card_id: String = String(entry)
				var candidates: Array = available_by_card.get(card_id, [])
				for instance_id in candidates:
					if not used_ids.has(instance_id):
						migrated_pile.append(String(instance_id))
						used_ids[instance_id] = true
						break
		migrated[pile_name] = migrated_pile

	for instance in deck_instances:
		var instance_id: String = String(instance.get("instance_id", ""))
		if not used_ids.has(instance_id):
			migrated["draw_pile"].append(instance_id)
			used_ids[instance_id] = true

	var legacy_retained_card_id: String = String(migrated.get("retained_card_id", ""))
	var retained_instance_id: String = ""
	for instance_id in migrated.get("hand", []):
		for instance in deck_instances:
			if String(instance.get("instance_id", "")) == String(instance_id) and String(instance.get("card_id", "")) == legacy_retained_card_id:
				retained_instance_id = String(instance_id)
				break
		if retained_instance_id != "":
			break
	migrated["deck"] = deck_instances
	migrated["retained_card_instance_id"] = retained_instance_id
	migrated["next_card_instance_serial"] = deck_instances.size() + 1
	migrated.erase("retained_card_id")
	migrated.erase("upgraded_cards")
	return migrated

func _fail(message: String) -> bool:
	last_error = message
	save_failed.emit(message)
	push_warning(message)
	return false
