extends SceneTree

const BattleManagerScript = preload("res://scripts/BattleManager.gd")
const GameDataScript = preload("res://scripts/GameData.gd")

var failures: Array[String] = []
var game_manager: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	game_manager = root.get_node("GameManager")
	_test_character_data()
	_test_character_hp_and_save_compatibility()
	_test_merchant_instinct()
	_test_first_flame()
	_test_mirror_counter()
	_test_mist_ward()
	_test_triad_resonance()
	if failures.is_empty():
		print("V1.1 character tests passed: 7")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_character_data() -> void:
	_expect(GameDataScript.STARTING_ARCHETYPES.size() == 5, "1.1 必须提供 5 名可玩角色。")
	for character_id in GameDataScript.STARTING_ARCHETYPES.keys():
		var character: Dictionary = GameDataScript.starting_archetype(String(character_id))
		_expect(int(character.get("max_hp", 0)) > 0, "%s 缺少有效最大生命。" % character_id)
		_expect(String(character.get("passive_id", "")) != "", "%s 缺少可执行被动。" % character_id)
		_expect(character.get("deck", []).size() == 8, "%s 的起始牌组必须为 8 张。" % character_id)
		_expect(GameDataScript.RELICS.has(String(character.get("relic", ""))), "%s 的起始遗物无效。" % character_id)
		for card_id in character.get("deck", []):
			_expect(GameDataScript.SPECTRA.has(String(card_id)), "%s 的起始牌组含无效色谱。" % character_id)

func _test_character_hp_and_save_compatibility() -> void:
	game_manager.reset_run()
	_expect(game_manager.configure_starting_archetype("blue"), "凛镜应可被选择。")
	_expect(game_manager.player_max_hp == 128 and game_manager.player_hp == 128, "凛镜应以 128/128 HP 开局。")
	_expect(game_manager.selected_character_id == "blue", "选择角色后必须写入正式角色 ID。")
	var legacy_snapshot: Dictionary = game_manager.create_save_snapshot()
	legacy_snapshot.erase("selected_character_id")
	game_manager.reset_run()
	_expect(game_manager.restore_save_snapshot(legacy_snapshot), "旧版仅含 starting_archetype_id 的存档应可恢复。")
	_expect(game_manager.selected_character_id == "blue", "旧存档角色 ID 应迁移到 selected_character_id。")

func _test_merchant_instinct() -> void:
	game_manager.reset_run()
	game_manager.configure_starting_archetype("gold")
	_expect(game_manager.get_shop_refresh_price() < 18, "洛恩的商店刷新价格应降低 10%。")
	_expect(game_manager.get_upgrade_price() < 55, "洛恩的升级服务价格应降低 10%。")
	var inventory: Array[Dictionary] = game_manager.make_shop_inventory()
	for item in inventory:
		if String(item.get("type", "")) == "card":
			_expect(int(item.get("price", 99)) < 45, "洛恩的普通色谱售价应降低 10%。")
			return
	_expect(false, "商店测试未生成普通色谱商品。")

func _test_first_flame() -> void:
	var battle: BattleManager = _new_battle("red")
	battle._apply_character_clear_passives({"active": true}, "red", 4)
	_expect(battle.enemy.burn_stacks == 1, "烬歌首次主动红色 4 连应追加 1 层燃烧。")
	battle._apply_character_clear_passives({"active": true}, "red", 5)
	_expect(battle.enemy.burn_stacks == 1, "烬歌被动每场战斗只能触发一次。")
	battle.free()

func _test_mirror_counter() -> void:
	var battle: BattleManager = _new_battle("blue")
	battle.enemy.charge_pending = true
	var hand: Array[Dictionary] = [{"instance_id": "mirror_test", "card_id": "ice_rest", "level": 0}]
	battle.spectrum_manager.begin_turn(hand)
	battle._apply_spectrum_effect("ice_rest", 0, 0)
	_expect(game_manager.shield == 11, "凛镜达成蓝色色谱并打断蓄力后，应叠加 3 点谱式护盾与 8 点镜返护盾。")
	battle.free()

func _test_mist_ward() -> void:
	var battle: BattleManager = _new_battle("gray")
	battle._resolve_intent({"type": "pollute", "value": 2})
	_expect(game_manager.shield == 5 and battle.mist_ward_used, "弥砂首次遭受污染应获得 5 护盾。")
	battle._resolve_intent({"type": "pollute", "value": 2})
	_expect(game_manager.shield == 5, "弥砂拾雾每场战斗只能触发一次。")
	battle.free()

func _test_triad_resonance() -> void:
	var battle: BattleManager = _new_battle("mixed")
	var pigment_before: int = game_manager.pigment
	var moves_before: int = battle.moves_left
	battle.spectrum_manager.unique_colors = {"red": true, "blue": true, "gold": true}
	battle._try_trigger_triad_resonance()
	_expect(game_manager.pigment == pigment_before + 1, "伊澜三声共鸣应获得 1 颜料。")
	_expect(battle.moves_left == moves_before + 1, "伊澜三声共鸣应返还 1 步。")
	battle._try_trigger_triad_resonance()
	_expect(game_manager.pigment == pigment_before + 1, "伊澜三声共鸣每场战斗只能触发一次。")
	battle.free()

func _new_battle(character_id: String) -> BattleManager:
	game_manager.reset_run()
	game_manager.equipped_memory_ids.clear()
	game_manager.configure_starting_archetype(character_id)
	var battle: BattleManager = BattleManagerScript.new()
	battle.GameManager = game_manager
	root.add_child(battle)
	battle.start_battle(GameDataScript.encounter("C1-01"))
	return battle

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
