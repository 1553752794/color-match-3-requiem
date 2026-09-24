extends SceneTree

const SETTINGS_SCRIPT = preload("res://scripts/SettingsManager.gd")

var passed: int = 0
var failed: int = 0

func _init() -> void:
	_test_onboarding_hint_whitelist_and_round_trip()
	print("V2.2 onboarding tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _test_onboarding_hint_whitelist_and_round_trip() -> void:
	var settings: Node = SETTINGS_SCRIPT.new()
	settings.settings_path = "user://test_v2_2_onboarding.cfg"
	_expect(not settings.has_seen_onboarding_hint("first_swap"), "New settings must not mark first_swap as seen.")
	settings.mark_onboarding_hint_seen("first_swap")
	_expect(settings.has_seen_onboarding_hint("first_swap"), "Known onboarding hint must persist in memory.")
	settings.mark_onboarding_hint_seen("unknown_hint")
	_expect(not settings.has_seen_onboarding_hint("unknown_hint"), "Unknown onboarding hints must be ignored.")
	_expect(settings.save_settings(), "Onboarding settings must save.")
	var restored: Node = SETTINGS_SCRIPT.new()
	restored.settings_path = settings.settings_path
	restored.load_settings()
	_expect(restored.has_seen_onboarding_hint("first_swap"), "Onboarding hint must survive settings reload.")
	_expect(not restored.has_seen_onboarding_hint("unknown_hint"), "Unknown hint must not be persisted.")
	_cleanup(settings.settings_path)
	settings.free()
	restored.free()

func _expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error(message)

func _cleanup(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)
