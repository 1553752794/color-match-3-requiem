extends SceneTree

var failures: Array[String] = []
var game_manager: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	game_manager = root.get_node("GameManager")
	_test_duplicate_retention_preserves_deck()
	_test_upgrade_is_single_level()
	_test_dominant_player_color_ignores_gray()
	_test_route_does_not_skip_single_exit_node()
	_test_route_rejects_locked_node()
	_test_starting_archetypes_build_distinct_runs()
	_test_colorless_crown_allows_two_retained_cards()
	_test_white_feather_triggers_once_per_chapter()
	_test_travel_bell_adds_shop_slot()
	if failures.is_empty():
		print("Run state tests passed: 9")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_duplicate_retention_preserves_deck() -> void:
	game_manager.reset_run()
	game_manager.deck.clear()
	var first_ember: Dictionary = game_manager.create_card_instance("ember_slash")
	var second_ember: Dictionary = game_manager.create_card_instance("ember_slash")
	var frost: Dictionary = game_manager.create_card_instance("frost_guard")
	game_manager.deck.assign([first_ember, second_ember, frost])
	game_manager.hand.assign([
		String(first_ember.get("instance_id", "")),
		String(second_ember.get("instance_id", "")),
		String(frost.get("instance_id", "")),
	])
	game_manager.draw_pile.clear()
	game_manager.discard_pile.clear()
	game_manager.retain_card(String(first_ember.get("instance_id", "")))
	var next_hand: Array[Dictionary] = game_manager.draw_new_turn_hand()
	_expect(next_hand.size() == 3, "保留重复牌后仍应保持三张手牌。")
	_expect(_count_card(next_hand, "ember_slash") == 2, "保留一张余烬斩不应吞掉另一张同名牌。")
	_expect(next_hand.size() + game_manager.draw_pile.size() + game_manager.discard_pile.size() == game_manager.deck.size(), "手牌、抽牌堆和弃牌堆数量应与牌组守恒。")

func _test_upgrade_is_single_level() -> void:
	game_manager.reset_run()
	var first_ember_id: String = _first_instance_id("ember_slash")
	var second_ember_id: String = _next_instance_id("ember_slash", first_ember_id)
	_expect(game_manager.upgrade_card(first_ember_id), "第一次精研应成功。")
	_expect(not game_manager.upgrade_card(first_ember_id), "同一色谱实例不能重复精研。")
	_expect(game_manager.get_card_level(first_ember_id) == 1, "精研等级应固定为 1。")
	_expect(game_manager.get_card_level(second_ember_id) == 0, "精研一张牌不应同步升级同名副本。")

func _test_dominant_player_color_ignores_gray() -> void:
	game_manager.reset_run()
	game_manager.color_usage = {"gray": 100, "red": 4, "blue": 7, "gold": 5}
	_expect(game_manager.get_dominant_player_color() == "blue", "Boss 主色抗性应忽略灰色并选择蓝色。")

func _test_route_does_not_skip_single_exit_node() -> void:
	game_manager.reset_run()
	game_manager.map_template_ids = {"C1": "standard", "C2": "standard", "C3": "standard"}
	game_manager.apply_start_choice("red")
	_expect(game_manager.current_node_id == "C1-00", "完成起点后当前位置不应提前跳到第一场战斗。")
	_expect(game_manager.get_available_node_ids() == ["C1-01"], "起点完成后应只开放第一场教学战。")
	game_manager.choose_node("C1-01")
	game_manager.complete_current_node()
	_expect(game_manager.current_node_id == "C1-01", "完成教学战后当前位置应保留在教学战节点。")
	_expect(game_manager.get_available_node_ids() == ["C1-02A", "C1-02B"], "教学战后应开放第二层两条路线。")

func _test_route_rejects_locked_node() -> void:
	game_manager.reset_run()
	game_manager.apply_start_choice("red")
	_expect(not game_manager.choose_node("C1-08"), "路线选择不应允许从起点跳过未完成节点直达 Boss。")
	_expect(game_manager.current_node_id == "C1-00", "非法路线选择不能改变当前位置。")

func _test_starting_archetypes_build_distinct_runs() -> void:
	var signatures: Dictionary = {}
	for archetype_id in ["red", "blue", "gold"]:
		game_manager.reset_run()
		_expect(game_manager.configure_starting_archetype(archetype_id), "%s 起始流派应能建立。" % archetype_id)
		_expect(game_manager.deck.size() == 8, "%s 起始流派应恰好有 8 张牌。" % archetype_id)
		_expect(_unique_deck_instance_count() == 8, "%s 起始牌应各有唯一实例 ID。" % archetype_id)
		_expect(game_manager.relics.size() == 1, "%s 起始流派应有 1 件起始遗物。" % archetype_id)
		var signature: String = "%s|%s" % [str(_deck_definition_ids()), str(game_manager.relics)]
		signatures[signature] = true
	_expect(signatures.size() == 3, "三套起始流派应提供不同的牌组与遗物组合。")

func _test_colorless_crown_allows_two_retained_cards() -> void:
	game_manager.reset_run()
	game_manager.add_relic("colorless_crown")
	game_manager.hand.assign(game_manager.draw_pile.slice(0, 3))
	game_manager.draw_pile = game_manager.draw_pile.slice(3)
	var first_id: String = game_manager.hand[0]
	var second_id: String = game_manager.hand[1]
	_expect(game_manager.retain_card(first_id), "无色冠冕应允许保留第一张色谱。")
	_expect(game_manager.retain_card(second_id), "无色冠冕应允许额外保留第二张色谱。")
	var next_hand: Array[Dictionary] = game_manager.draw_new_turn_hand()
	var next_ids: Array[String] = []
	for card in next_hand:
		next_ids.append(String(card.get("instance_id", "")))
	_expect(next_ids.has(first_id) and next_ids.has(second_id), "两张已保留色谱都应进入下一回合手牌。")

func _test_white_feather_triggers_once_per_chapter() -> void:
	game_manager.reset_run()
	game_manager.map_template_ids = {"C1": "standard", "C2": "standard", "C3": "standard"}
	game_manager.add_relic("white_feather")
	game_manager.current_node_id = "C1-01"
	game_manager.gray_pressure = 5
	_expect(game_manager.add_gray_pressure(1) == 3 and game_manager.gray_pressure == 3, "净白羽应在本章首次达到 6 压力时清除 3 点。")
	game_manager.gray_pressure = 5
	_expect(game_manager.add_gray_pressure(1) == 0 and game_manager.gray_pressure == 6, "净白羽同章只能触发一次。")
	game_manager.current_node_id = "C2-01"
	game_manager.gray_pressure = 5
	_expect(game_manager.add_gray_pressure(1) == 3 and game_manager.gray_pressure == 3, "进入下一章后净白羽应可再次触发。")

func _test_travel_bell_adds_shop_slot() -> void:
	game_manager.reset_run()
	seed(7)
	var base_inventory: Array[Dictionary] = game_manager.make_shop_inventory()
	game_manager.add_relic("travel_bell")
	seed(7)
	var bell_inventory: Array[Dictionary] = game_manager.make_shop_inventory()
	_expect(bell_inventory.size() == base_inventory.size() + 1, "旅商铃应让商店额外展示 1 件商品。")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _count_card(cards: Array[Dictionary], card_id: String) -> int:
	var count: int = 0
	for card in cards:
		if String(card.get("card_id", "")) == card_id:
			count += 1
	return count

func _first_instance_id(card_id: String) -> String:
	return _next_instance_id(card_id, "")

func _next_instance_id(card_id: String, excluded_id: String) -> String:
	for card in game_manager.deck:
		var instance_id: String = String(card.get("instance_id", ""))
		if String(card.get("card_id", "")) == card_id and instance_id != excluded_id:
			return instance_id
	return ""

func _deck_definition_ids() -> Array[String]:
	var result: Array[String] = []
	for card in game_manager.deck:
		result.append(String(card.get("card_id", "")))
	return result

func _unique_deck_instance_count() -> int:
	var ids: Dictionary = {}
	for card in game_manager.deck:
		ids[String(card.get("instance_id", ""))] = true
	return ids.size()
