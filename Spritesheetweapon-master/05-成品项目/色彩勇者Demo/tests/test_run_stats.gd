extends SceneTree

const RunStatsScript = preload("res://scripts/RunStats.gd")

var failures: Array[String] = []
var passed_tests: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_test("records all run statistics and summary metrics", _test_recording_and_summary)
	_run_test("serialization round trip", _test_serialization_round_trip)
	_run_test("legacy data with missing fields", _test_legacy_data_defaults)
	_run_test("zero denominators", _test_zero_denominators)
	_run_test("invalid and empty input defense", _test_invalid_inputs)

	print("RunStats tests: %d passed, %d failed" % [passed_tests, failures.size()])
	if failures.is_empty():
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _run_test(test_name: String, test_callable: Callable) -> void:
	var failure_count_before: int = failures.size()
	test_callable.call()
	if failures.size() == failure_count_before:
		passed_tests += 1
		print("[PASS] %s" % test_name)
	else:
		print("[FAIL] %s" % test_name)


func _test_recording_and_summary() -> void:
	var stats: Variant = RunStatsScript.new()
	_expect(stats.start("run-1", {"character_id": "red"}), "A valid run must start.")
	_expect(stats.record("turn", 3), "Turns must record.")
	_expect(stats.record("swap", 5), "Swaps must record.")
	_expect(stats.record("match", 4), "Matches must record.")
	_expect(stats.record("cascade", 2), "Cascades must record.")
	_expect(stats.record("spectrum_completed", 2), "Completed spectra must record.")
	_expect(stats.record("resonance_advance", 4), "Resonance advances must record.")
	_expect(stats.record("resonance_trigger", 2), "Resonance triggers must record.")
	_expect(stats.record("shot", 2), "Shots must record.")
	_expect(stats.record("ball", 4), "Balls must record.")
	_expect(stats.record("hit", 3), "Hits must record.")
	_expect(stats.record("crit", 1), "Critical hits must record.")
	_expect(stats.record("hazard_peg", 2), "Hazard pegs must record.")
	_expect(stats.record("damage", 30, {"source": "spectrum"}), "Spectrum damage must record.")
	_expect(stats.record("damage", {"amount": 10, "source": "relic"}), "Relic damage must record.")
	_expect(stats.record("shield_gained", 12), "Shield gained must record.")
	_expect(stats.record("shield_absorbed", 7), "Shield absorbed must record.")
	_expect(stats.record("coins_gained", 20), "Coins gained must record.")
	_expect(stats.record("coins_spent", 6), "Coins spent must record.")
	_expect(stats.record("battle_result", "victory"), "Battle wins must record.")
	_expect(stats.record("battle_loss"), "Battle losses must record.")

	var result: Dictionary = stats.summary()
	_expect(bool(result["started"]), "Summary must report an active run.")
	_expect(String(result["run_id"]) == "run-1", "Summary must preserve the run identifier.")
	_expect(int(result["turns"]) == 3, "Summary must include turns.")
	_expect(int(result["swaps"]) == 5, "Summary must include swaps.")
	_expect(int(result["matches"]) == 4, "Summary must include matches.")
	_expect(int(result["cascades"]) == 2, "Summary must include cascades.")
	_expect(int(result["spectra_completed"]) == 2, "Summary must include completed spectra.")
	_expect(int(result["resonance_advances"]) == 4, "Summary must include resonance advances.")
	_expect(int(result["resonance_triggers"]) == 2, "Summary must include resonance triggers.")
	_expect(is_equal_approx(float(result["resonance_rate"]), 0.5), "Resonance rate must use triggers per advance.")
	_expect(int(result["shots_fired"]) == 2, "Summary must include shots.")
	_expect(int(result["balls_fired"]) == 4, "Summary must include balls.")
	_expect(int(result["hits"]) == 3, "Summary must include hits.")
	_expect(int(result["critical_hits"]) == 1, "Summary must include critical hits.")
	_expect(int(result["hazard_pegs"]) == 2, "Summary must include hazard pegs.")
	_expect(int(result["damage_total"]) == 40, "Summary must total damage sources.")
	_expect(int(result["shield_gained"]) == 12, "Summary must include shield gained.")
	_expect(int(result["shield_absorbed"]) == 7, "Summary must include shield absorbed.")
	_expect(int(result["coins_net"]) == 14, "Summary must include net coins.")
	_expect(int(result["battles_total"]) == 2, "Summary must count battle results.")
	_expect(is_equal_approx(float(result["hit_rate"]), 0.75), "Hit rate must use hits per ball.")
	_expect(is_equal_approx(float(result["crit_rate"]), 1.0 / 3.0), "Crit rate must use crits per hit.")
	_expect(is_equal_approx(float(result["average_damage_per_shot"]), 20.0), "Average damage must use total damage per shot.")
	_expect(String(result["top_damage_source"]) == "spectrum", "Summary must report the highest damage source.")
	_expect(int(result["top_damage_amount"]) == 30, "Summary must report the highest source damage.")


func _test_serialization_round_trip() -> void:
	var original: Variant = RunStatsScript.new()
	original.start("round-trip", {"seed": 9137, "character": "blue"})
	original.record("turns", 8)
	original.record("resonance_advance", 3)
	original.record("resonance_trigger", 1)
	original.record("shots_fired", 3)
	original.record("damage", 19, "spectrum")
	original.record("battle_result", 2, {"result": "win"})
	var serialized: Dictionary = original.serialize()

	var restored: Variant = RunStatsScript.new()
	_expect(restored.restore(serialized), "Serialized RunStats data must restore.")
	_expect(restored.serialize() == serialized, "Serialize and restore must round trip exactly.")
	var mutated_metadata: Dictionary = restored.metadata
	mutated_metadata["seed"] = 1
	_expect(int(serialized["metadata"]["seed"]) == 9137, "Serialized metadata must be deep copied.")


func _test_legacy_data_defaults() -> void:
	var stats: Variant = RunStatsScript.new()
	var legacy_data: Dictionary = {
		"active": true,
		"id": "legacy-run",
		"turns": 4,
		"clears": 6,
		"shots": 2,
		"balls": 3,
		"damage_total": 17,
		"battles_won": 1,
	}
	_expect(stats.restore(legacy_data), "Legacy data with missing fields must restore.")
	var result: Dictionary = stats.summary()
	_expect(bool(result["started"]), "Legacy active state must migrate.")
	_expect(String(result["run_id"]) == "legacy-run", "Legacy run id must migrate.")
	_expect(int(result["turns"]) == 4, "Legacy turns must migrate.")
	_expect(int(result["matches"]) == 6, "Legacy clears must migrate to matches.")
	_expect(int(result["swaps"]) == 0, "Missing legacy counters must default to zero.")
	_expect(int(result["resonance_advances"]) == 0, "Legacy runs must default missing resonance advances to zero.")
	_expect(int(result["resonance_triggers"]) == 0, "Legacy runs must default missing resonance triggers to zero.")
	_expect(int(result["damage_total"]) == 17, "Legacy total damage must be preserved.")
	_expect(String(result["top_damage_source"]) == "unknown", "Unattributed legacy damage must use a safe source.")
	_expect(int(result["battle_results"]["win"]) == 1, "Legacy wins must migrate.")
	_expect(int(result["battle_results"]["loss"]) == 0, "Missing battle results must default to zero.")


func _test_zero_denominators() -> void:
	var stats: Variant = RunStatsScript.new()
	stats.start()
	stats.record("damage", 9, {"source": "relic"})
	var result: Dictionary = stats.summary()
	_expect(is_equal_approx(float(result["hit_rate"]), 0.0), "Zero balls must produce a zero hit rate.")
	_expect(is_equal_approx(float(result["crit_rate"]), 0.0), "Zero hits must produce a zero crit rate.")
	_expect(is_equal_approx(float(result["resonance_rate"]), 0.0), "Zero resonance advances must produce a zero resonance rate.")
	_expect(is_equal_approx(float(result["average_damage_per_shot"]), 0.0), "Zero shots must produce zero average damage.")


func _test_invalid_inputs() -> void:
	var stats: Variant = RunStatsScript.new()
	_expect(stats.start("", {" character ": "mixed", "": 5}), "An anonymous run must start safely.")
	_expect(String(stats.metadata.get("character", "")) == "mixed", "Metadata keys must be trimmed safely.")
	_expect(not stats.metadata.has(""), "Empty metadata keys must be discarded.")
	_expect(not stats.record("", 1), "Empty event names must be rejected.")
	_expect(not stats.record("unknown_event", 1), "Unknown event names must be rejected.")
	_expect(not stats.record("turn", 0), "Zero counter amounts must be rejected.")
	_expect(not stats.record("turn", -2), "Negative counter amounts must be rejected.")
	_expect(not stats.record("damage", 5, {"source": ""}), "Empty damage sources must be rejected.")
	_expect(not stats.record("damage", -5, {"source": "spectrum"}), "Negative damage must be rejected.")
	_expect(not stats.record("battle_result", ""), "Empty battle outcomes must be rejected.")
	_expect(not stats.record("battle_result", "draw"), "Unknown battle outcomes must be rejected.")
	_expect(not stats.restore([]), "Non-dictionary restore data must be rejected.")
	_expect(not stats.restore({}), "Empty restore data must be rejected.")
	_expect(stats.restore({
		"turns": -9,
		"damage_by_source": {"": 10, "spectrum": -4},
		"battle_results": {"win": -2, "": 3},
	}), "Malformed legacy fields must restore with safe defaults.")
	var result: Dictionary = stats.summary()
	_expect(int(result["turns"]) == 0, "Negative restored counters must clamp to zero.")
	_expect(int(result["damage_total"]) == 0, "Invalid restored damage must be discarded.")
	_expect(int(result["battles_total"]) == 0, "Invalid restored battle results must be discarded.")
	stats.reset()
	_expect(not stats.started and stats.summary()["turns"] == 0, "Reset must clear all run statistics.")


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
