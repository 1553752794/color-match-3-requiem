extends SceneTree

var failures: Array[String] = []
var game_manager: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	game_manager = root.get_node("GameManager")
	game_manager.reset_run()
	game_manager.selected_character_id = "red"
	var character_reason: String = game_manager.get_spectrum_synergy_reason("ember_slash")
	_expect(character_reason.contains("角色") and character_reason.contains("燃烧"), "matching character should explain the burn synergy.")

	game_manager.selected_character_id = "blue"
	game_manager.run_stats.record_spectrum_tag("燃烧", "completed")
	var completed_reason: String = game_manager.get_spectrum_synergy_reason("ember_slash")
	_expect(completed_reason.contains("延续") and completed_reason.contains("燃烧"), "completed tag should explain a continuing build.")

	game_manager.reset_run()
	game_manager.selected_character_id = "red"
	game_manager.deck.clear()
	game_manager.deck.append(game_manager.create_card_instance("frost_guard"))
	var deck_reason: String = game_manager.get_spectrum_synergy_reason("ice_rest")
	_expect(deck_reason.contains("牌组") and deck_reason.contains("冻结"), "matching deck tags should explain the deck synergy.")

	game_manager.reset_run()
	game_manager.selected_character_id = "red"
	game_manager.deck.clear()
	_expect(game_manager.get_spectrum_synergy_reason("gray_blade") == "", "cards without evidence must not show a fake recommendation.")

	if failures.is_empty():
		print("V2.4 reward synergy tests passed: 4")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
