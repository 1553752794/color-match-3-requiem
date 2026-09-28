extends SceneTree

var failures: Array[String] = []
var game_manager: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	game_manager = root.get_node("GameManager")
	game_manager.reset_run()
	game_manager.coins = 100
	var removable: Array[Dictionary] = game_manager.get_removable_cards()
	_expect(removable.size() == game_manager.deck.size(), "a deck above the minimum must expose every removable instance.")
	var target: Dictionary = removable.back() if not removable.is_empty() else {}
	var target_id: String = String(target.get("instance_id", ""))
	var target_card_id: String = String(target.get("card_id", ""))
	var item: Dictionary = {"type": "remove", "price": 17}
	var coins_before: int = game_manager.coins
	_expect(game_manager.buy_shop_item(item, target_id), "shop removal should accept an explicitly selected card.")
	_expect(game_manager.get_card_instance(target_id).is_empty(), "selected card instance must be removed.")
	_expect(game_manager.coins == coins_before - 17, "shop removal should charge the displayed price.")
	_expect(not _contains_card(game_manager.deck, target_id, target_card_id), "removed card must leave the deck.")

	while game_manager.deck.size() > 6:
		game_manager.remove_card(String(game_manager.deck.back().get("instance_id", "")))
	game_manager.coins = 100
	var coins_at_minimum: int = game_manager.coins
	_expect(game_manager.get_removable_cards().is_empty(), "a six-card deck must not expose removals.")
	_expect(not game_manager.buy_shop_item(item), "shop removal must reject a deck at the minimum.")
	_expect(game_manager.coins == coins_at_minimum, "rejected removal must not charge coins.")

	if failures.is_empty():
		print("V2.4 shop removal tests passed: 7")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _contains_card(cards: Array[Dictionary], instance_id: String, card_id: String) -> bool:
	for card in cards:
		if String(card.get("instance_id", "")) == instance_id or String(card.get("card_id", "")) == card_id:
			if String(card.get("instance_id", "")) == instance_id:
				return true
	return false

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
