extends SceneTree

const GameDataScript = preload("res://scripts/GameData.gd")
const MainScript = preload("res://scripts/Main.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Control = MainScript.new()
	_test_counts(main)
	_test_spectrum_filters(main)
	_test_relic_filters(main)
	_test_default_detail_data()
	_test_route_and_event_chain_emit_save_signal()
	main.free()
	if failures.is_empty():
		print("V1.1 codex tests passed: 5")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_counts(main: Control) -> void:
	var counts: Dictionary = main.codex_counts()
	_expect(int(counts.get("characters", 0)) == 5, "图鉴必须动态读取 5 名角色。")
	_expect(int(counts.get("spectra", 0)) == GameDataScript.SPECTRA.size(), "图鉴必须动态读取完整色谱目录。")
	_expect(int(counts.get("relics", 0)) == GameDataScript.RELICS.size(), "图鉴必须动态读取完整遗物目录。")
	_expect(int(counts.get("events", 0)) == GameDataScript.EVENTS.size(), "图鉴必须动态读取完整事件目录。")
	_expect(int(counts.get("relics", 0)) >= 48 and int(counts.get("events", 0)) >= 24, "图鉴内容不得低于 1.1 基线。")

func _test_spectrum_filters(main: Control) -> void:
	var green_cards: Array[String] = main.codex_filtered_ids("spectra", "green", "all")
	var epic_green_cards: Array[String] = main.codex_filtered_ids("spectra", "green", "epic")
	_expect(green_cards.size() >= 9, "翠生筛选应至少返回 9 张色谱。")
	_expect(epic_green_cards.size() >= 1, "翠生史诗筛选应至少返回 1 张色谱。")
	for card_id in green_cards:
		_expect(String(GameDataScript.SPECTRA[card_id].get("color", "")) == "green", "学派筛选不能混入其他色谱。")

func _test_relic_filters(main: Control) -> void:
	var boss_relics: Array[String] = main.codex_filtered_ids("relics", "all", "boss")
	_expect(not boss_relics.is_empty(), "首领遗物筛选不应为空。")
	for relic_id in boss_relics:
		_expect(String(GameDataScript.RELICS[relic_id].get("rarity", "")) == "boss", "首领遗物筛选不能混入其他稀有度。")

func _test_default_detail_data() -> void:
	var character: Dictionary = GameDataScript.starting_archetype("red")
	var card: Dictionary = GameDataScript.spectrum("ember_slash")
	var event: Dictionary = GameDataScript.event("colorless_orchestra")
	_expect(String(character.get("passive_text", "")) != "" and character.get("deck", []).size() == 8, "角色详情必须包含被动与起始牌组。")
	_expect(String(card.get("condition", "")) != "" and String(card.get("effect", "")) != "" and not card.get("upgrade", {}).is_empty(), "色谱详情必须包含条件、效果与精研。")
	_expect(String(event.get("body", "")) != "" and event.get("choices", []).size() >= 2, "事件详情必须包含正文与所有选项。")

func _test_route_and_event_chain_emit_save_signal() -> void:
	var game_manager: Node = root.get_node("GameManager")
	game_manager.reset_run()
	game_manager.configure_starting_archetype("red")
	game_manager.current_options.assign(["C1-01"])
	var save_signals: Array[int] = [0]
	var callback: Callable = func() -> void: save_signals[0] += 1
	game_manager.run_state_changed.connect(callback)
	_expect(game_manager.choose_node("C1-01"), "合法选路应成功。")
	_expect(save_signals[0] == 1, "进入节点必须触发一次存档信号。")
	game_manager.current_node_id = "C1-02B"
	game_manager.apply_event_choice("colorless_orchestra", "listen")
	_expect(game_manager.pending_event_chain_id == "orchestra_backstage", "连续事件第一段应持久化后续事件 ID。")
	_expect(save_signals[0] == 2, "进入连续事件第二段前必须再次触发存档信号。")
	game_manager.run_state_changed.disconnect(callback)

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
