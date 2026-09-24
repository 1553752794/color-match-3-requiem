extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: Node = root.get_node("GameManager")
	manager.reset_run()
	manager.map_template_ids = {"C1": "standard", "C2": "standard", "C3": "standard"}
	manager.current_node_id = "C1-07"
	manager.coins = 40
	manager.pigment = 3
	manager.visited_nodes.clear()
	_expect(manager.get_camp_conversion_options().size() == 2, "camp must expose two resource conversion choices")
	var before_coins: int = manager.coins
	var before_pigment: int = manager.pigment
	var result: String = manager.apply_camp_choice("sell_pigment")
	_expect(result.contains("35") and manager.coins == before_coins + 35 and manager.pigment == before_pigment - 2, "selling pigment must atomically grant 35 coins for 2 pigment")
	_expect(manager.visited_nodes.has("C1-07"), "conversion must settle the camp node")
	_expect(manager.apply_camp_choice("refine_color").contains("已经结算"), "camp conversion must reject repeat settlement")

	manager.reset_run()
	manager.map_template_ids = {"C1": "standard", "C2": "standard", "C3": "standard"}
	manager.current_node_id = "C1-07"
	manager.coins = 25
	manager.pigment = 0
	manager.visited_nodes.clear()
	var refine_result: String = manager.apply_camp_choice("refine_color")
	_expect(refine_result.contains("1 颜料") and manager.coins == 0 and manager.pigment == 1, "refining color must exchange 25 coins for 1 pigment")
	_expect(manager.gray_pressure == 0, "refining color must reduce gray pressure without going negative")

	manager.reset_run()
	manager.map_template_ids = {"C1": "standard", "C2": "standard", "C3": "standard"}
	manager.current_node_id = "C1-07"
	manager.coins = 24
	manager.pigment = 1
	manager.visited_nodes.clear()
	_expect(manager.apply_camp_choice("refine_color").contains("不足"), "refining color must reject insufficient coins")
	_expect(manager.coins == 24 and manager.pigment == 1 and manager.visited_nodes.is_empty(), "failed conversion must not mutate resources or settle node")

	for invalid_amount in [-1, 0]:
		_expect(not manager.spend_coins(invalid_amount), "non-positive coin spending must be rejected")
		_expect(not manager.spend_pigment(invalid_amount), "non-positive pigment spending must be rejected")
	for failure in failures:
		push_error(failure)
	print("V2.3 camp conversion: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition and not failures.has(message):
		failures.append(message)
