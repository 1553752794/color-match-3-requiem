extends SceneTree

const GameDataScript = preload("res://scripts/GameData.gd")
const DataValidatorScript = preload("res://scripts/DataValidator.gd")
const RunStatsScript = preload("res://scripts/RunStats.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var errors: Array[String] = DataValidatorScript.validate_all()
	_expect(errors.is_empty(), "2.4 data validation must pass: %s" % str(errors))
	var tags: Array[String] = GameDataScript.spectrum_tags("ember_slash")
	_expect(tags.has("燃烧"), "ember_slash must expose the burn build tag.")
	_expect(GameDataScript.spectra_matching_tags(["燃烧", "燃烧"]).size() > 0, "tag query must return matching cards.")

	var stats: Variant = RunStatsScript.new()
	stats.start("v24")
	_expect(stats.record_spectrum_tags(["燃烧", "共鸣"], "completed") == 2, "valid completion tags must record.")
	_expect(stats.record_spectrum_tag("未知", "completed") == false, "unknown tags must be rejected.")
	var saved: Dictionary = stats.serialize()
	var restored: Variant = RunStatsScript.new()
	_expect(restored.restore(saved), "tag statistics must restore.")
	_expect(int(restored.summary()["spectrum_tags_completed"]["燃烧"]) == 1, "burn tag count must survive restore.")
	_expect(restored.restore({"started": true}), "legacy stats without tags must restore.")

	if failures.is_empty():
		print("V2.4 build tag tests passed: 5")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
