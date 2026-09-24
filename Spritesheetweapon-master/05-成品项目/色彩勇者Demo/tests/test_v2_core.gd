extends SceneTree

const ResonanceSequenceScript = preload("res://scripts/ResonanceSequence.gd")
const NarrativeMemoryScript = preload("res://scripts/NarrativeMemory.gd")
const SpectrumResolutionScript = preload("res://scripts/SpectrumResolution.gd")

var failures: Array[String] = []
var passed_tests: int = 0
var game_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	game_manager = root.get_node("GameManager")
	_run_test("cross-turn resonance lifecycle", _test_resonance_lifecycle)
	_run_test("eight-school resonance families", _test_resonance_families)
	_run_test("spectrum completion package", _test_spectrum_completion_package)
	_run_test("fragment archive boundaries", _test_fragment_archive)
	_run_test("vow and Save v4 round trip", _test_vow_save_round_trip)

	print("V2.0 core tests: %d passed, %d failed" % [passed_tests, failures.size()])
	if failures.is_empty():
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _run_test(test_name: String, test_callable: Callable) -> void:
	var before: int = failures.size()
	test_callable.call()
	if failures.size() == before:
		passed_tests += 1
		print("[PASS] %s" % test_name)
	else:
		print("[FAIL] %s" % test_name)


func _test_resonance_lifecycle() -> void:
	var sequence: RefCounted = ResonanceSequenceScript.new()
	sequence.begin_turn()
	var first: Dictionary = sequence.register_color("red")
	_expect(first.get("resonance", {}).is_empty(), "The first battle turn must not resonate without a lead note.")
	sequence.begin_turn()
	var violet: Dictionary = sequence.register_color("blue")
	_expect(String(violet.get("resonance", {}).get("id", "")) == "violet", "Red into blue must create violet resonance.")
	var consumed: Dictionary = sequence.register_color("gold")
	_expect(consumed.get("resonance", {}).is_empty(), "Only the first valid answer may consume resonance each turn.")
	sequence.begin_turn()
	var ignored: Dictionary = sequence.register_color("neutral")
	_expect(ignored.get("registered", true) == false, "Neutral spectra must not consume or replace the lead note.")
	var verdant: Dictionary = sequence.register_color("blue")
	_expect(String(verdant.get("resonance", {}).get("id", "")) == "verdant", "Gold tail into blue must create verdant resonance.")


func _test_resonance_families() -> void:
	_expect(String(ResonanceSequenceScript.resolve_pair(
		ResonanceSequenceScript.note_for_color("gray"),
		ResonanceSequenceScript.note_for_color("red")
	).get("id", "")) == "decolor", "Gray signatures must take decolor priority.")
	_expect(String(ResonanceSequenceScript.resolve_pair(
		ResonanceSequenceScript.note_for_color("purple"),
		ResonanceSequenceScript.note_for_color("gold")
	).get("id", "")) == "daylight", "Purple plus gold must cover the daylight triad.")
	_expect(String(ResonanceSequenceScript.resolve_pair(
		ResonanceSequenceScript.note_for_color("white"),
		ResonanceSequenceScript.note_for_color("red")
	).get("id", "")) == "unison", "Intersecting signatures must resolve as unison.")


func _test_spectrum_completion_package() -> void:
	var result: Dictionary = SpectrumResolutionScript.resolve(
		{"rarity": "rare", "color": "blue"},
		{"completion_shield": 3, "armor_break": 1},
		{"repeat_count": 2, "repeat_ratio": 0.5, "shield": 2},
		{"critical": 1, "pierce": 1}
	)
	_expect(int(result.get("damage", 0)) == 23, "A tuned rare spectrum must resolve its full pulse and repeat damage immediately.")
	_expect(int(result.get("shield", 0)) == 5, "Character and card shield rewards must stack in the same resolution.")
	_expect(bool(result.get("ignore_armor", false)), "Armor break from profile or tuning must apply to the current spectrum.")


func _test_fragment_archive() -> void:
	_expect(NarrativeMemoryScript.FRAGMENTS.size() == 30, "The 2.0 archive must ship with exactly 30 fragments.")
	_expect(NarrativeMemoryScript.MEMORY_SETS.size() == 10, "The archive must form exactly ten memory sets.")
	var assigned_ids: Array[String] = []
	var expected_slots: Array[String] = ["cause", "witness", "aftermath"]
	for set_id_value in NarrativeMemoryScript.MEMORY_SETS.keys():
		var set_id: String = String(set_id_value)
		var ids: Array = NarrativeMemoryScript.MEMORY_SETS[set_id].get("ids", [])
		_expect(ids.size() == 3, "Memory set %s must contain exactly three fragments." % set_id)
		for index in ids.size():
			var memory_id: String = String(ids[index])
			_expect(NarrativeMemoryScript.FRAGMENTS.has(memory_id), "Memory set %s references an unknown fragment." % set_id)
			_expect(not assigned_ids.has(memory_id), "Fragment %s must belong to only one memory set." % memory_id)
			assigned_ids.append(memory_id)
			var data: Dictionary = NarrativeMemoryScript.fragment(memory_id)
			_expect(String(data.get("set_id", "")) == set_id, "Fragment %s must point back to its memory set." % memory_id)
			_expect(String(data.get("slot", "")) == expected_slots[index], "Memory set %s must follow cause/witness/aftermath order." % set_id)
	_expect(assigned_ids.size() == NarrativeMemoryScript.FRAGMENTS.size(), "Every fragment must be assigned to one memory set.")
	for index in 30:
		var expected_id: String = "M%02d" % (index + 1)
		_expect(NarrativeMemoryScript.FRAGMENTS.has(expected_id), "The archive must contain the contiguous ID %s." % expected_id)
	var unlocked: Array[String] = NarrativeMemoryScript.sanitize_unlocked([])
	_expect(unlocked == NarrativeMemoryScript.DEFAULT_UNLOCKED, "A fresh profile must expose only the three starter fragments.")
	var cleaned: Array[String] = NarrativeMemoryScript.sanitize_unlocked(["M30", "M30", "UNKNOWN"])
	_expect(cleaned == ["M30", "M01", "M02", "M03"], "Archive cleanup must deduplicate, reject unknown IDs, and restore starters.")
	var equipped: Array[String] = NarrativeMemoryScript.sanitize_equipped(["M01", "M02", "M03", "M04"], unlocked)
	_expect(equipped.size() == NarrativeMemoryScript.MAX_EQUIPPED, "Equipped memories must respect the three-slot cap.")
	var reward_id: String = NarrativeMemoryScript.reward_for("C1-02A", 44, unlocked)
	_expect(NarrativeMemoryScript.FRAGMENTS.has(reward_id) and not unlocked.has(reward_id), "A deterministic reward should prefer a locked chapter fragment.")
	_expect(reward_id == NarrativeMemoryScript.reward_for("C1-02A", 44, unlocked), "Fragment rewards must remain deterministic for the same node and run seed.")
	var progress: Dictionary = NarrativeMemoryScript.set_progress(unlocked)
	_expect(bool(progress.get("lamplighters", {}).get("complete", false)), "The three starter fragments must complete the starter memory set.")
	for set_progress_value in progress.values():
		var set_data: Dictionary = set_progress_value
		_expect(int(set_data.get("total", 0)) == 3, "Every memory progress entry must expose a three-fragment total.")


func _test_vow_save_round_trip() -> void:
	game_manager.set_ascension_level(0)
	game_manager.reset_run()
	_expect(game_manager.configure_starting_archetype("red"), "A real character must be configured before taking a vow.")
	_expect(game_manager.apply_vow("vow_fracture"), "A valid vow must apply exactly once.")
	_expect(game_manager.player_max_hp == 102, "Fracture vow must reduce Jinge's max HP by ten.")
	_expect(game_manager.map_template_ids == {"C1": "risk", "C2": "risk", "C3": "risk"}, "Fracture vow must select the risk map pool for all chapters.")
	_expect(not game_manager.apply_vow("vow_order"), "A run must not replace its vow after confirmation.")
	game_manager.unlock_memory("M04")
	game_manager.set_equipped_memories(["M02", "M03", "M04"])
	var snapshot: Dictionary = game_manager.create_save_snapshot()
	_expect(String(snapshot.get("selected_vow_id", "")) == "vow_fracture", "Save v4 snapshots must include the selected vow.")
	_expect(game_manager.restore_save_snapshot(snapshot), "A 2.0 snapshot must restore successfully.")
	_expect(game_manager.selected_vow_id == "vow_fracture", "The selected vow must survive a round trip.")
	_expect(game_manager.equipped_memory_ids == ["M02", "M03", "M04"], "The memory loadout must survive a round trip.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
