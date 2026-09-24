extends Node

signal settings_changed
signal settings_save_failed(message: String)

const SETTINGS_PATH = "user://settings.cfg"
const ONBOARDING_HINT_IDS: Array[String] = [
	"character_choice",
	"vow_choice",
	"first_battle",
	"first_swap",
	"first_spectrum",
	"first_resonance",
	"first_enemy_intent",
]

var master_volume: float = 1.0
var music_volume: float = 0.75
var sfx_volume: float = 0.85
var fullscreen: bool = false
var reduced_motion: bool = false
var aim_assist: bool = true
var quick_resolve: bool = false
var high_contrast_pegs: bool = false
var combat_speed: float = 1.0
var last_error: String = ""
var settings_path: String = SETTINGS_PATH
var onboarding_hints_seen: Dictionary = {}

func _ready() -> void:
	load_settings()
	apply_settings()

func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	master_volume = clampf(float(config.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	reduced_motion = bool(config.get_value("accessibility", "reduced_motion", reduced_motion))
	aim_assist = bool(config.get_value("accessibility", "aim_assist", aim_assist))
	quick_resolve = bool(config.get_value("accessibility", "quick_resolve", quick_resolve))
	high_contrast_pegs = bool(config.get_value("accessibility", "high_contrast_pegs", high_contrast_pegs))
	combat_speed = clampf(float(config.get_value("gameplay", "combat_speed", combat_speed)), 0.5, 2.0)
	onboarding_hints_seen = _restore_onboarding_hints(config.get_value("onboarding", "hints_seen", []))

func save_settings() -> bool:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	config.set_value("accessibility", "aim_assist", aim_assist)
	config.set_value("accessibility", "quick_resolve", quick_resolve)
	config.set_value("accessibility", "high_contrast_pegs", high_contrast_pegs)
	config.set_value("gameplay", "combat_speed", combat_speed)
	config.set_value("onboarding", "hints_seen", onboarding_hints_seen.keys())
	var error: Error = config.save(settings_path)
	if error != OK:
		last_error = "设置保存失败：%s" % error_string(error)
		settings_save_failed.emit(last_error)
		push_warning(last_error)
		return false
	last_error = ""
	return true

func has_seen_onboarding_hint(hint_id: String) -> bool:
	return onboarding_hints_seen.get(hint_id, false) == true

func mark_onboarding_hint_seen(hint_id: String) -> void:
	if not ONBOARDING_HINT_IDS.has(hint_id):
		return
	if has_seen_onboarding_hint(hint_id):
		return
	onboarding_hints_seen[hint_id] = true
	save_settings()

func _restore_onboarding_hints(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Array:
		return result
	for entry in value:
		var hint_id: String = String(entry)
		if ONBOARDING_HINT_IDS.has(hint_id):
			result[hint_id] = true
	return result

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_commit()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_commit()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_commit()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_commit()

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_commit()

func set_aim_assist(value: bool) -> void:
	aim_assist = value
	_commit()

func set_quick_resolve(value: bool) -> void:
	quick_resolve = value
	_commit()

func set_high_contrast_pegs(value: bool) -> void:
	high_contrast_pegs = value
	_commit()

func set_combat_speed(value: float) -> void:
	combat_speed = clampf(value, 0.5, 2.0)
	_commit()

func apply_settings() -> void:
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(max(master_volume, 0.0001)))
		AudioServer.set_bus_mute(master_bus, master_volume <= 0.001)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _commit() -> void:
	apply_settings()
	if save_settings():
		settings_changed.emit()
