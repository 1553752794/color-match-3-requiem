extends RefCounted
class_name Enemy

const GameDataScript = preload("res://scripts/GameData.gd")

var enemy_id: String = ""
var enemy_name: String = "灰雾学徒"
var max_hp: int = 84
var hp: int = 84
var attack: int = 10
var reward: int = 18
var description: String = ""
var node_type: String = "combat"
var intents: Array = []
var turn_index: int = 0
var burn_stacks: int = 0
var burn_turns: int = 0
var freeze_turns: int = 0
var armor: int = 0
var resistance_color: String = ""
var resistance_rate: float = 0.0
var resistance_turns: int = 0
var resistance_just_applied: bool = false
var charge_pending: bool = false
var interrupted_this_turn: bool = false
var boss: bool = false

func _init(data: Dictionary = {}) -> void:
	enemy_id = String(data.get("enemy_id", ""))
	enemy_name = String(data.get("enemy_name", enemy_name))
	max_hp = int(data.get("max_hp", max_hp))
	hp = max_hp
	attack = int(data.get("attack", attack))
	reward = int(data.get("reward", reward))
	description = String(data.get("description", description))
	node_type = String(data.get("node_type", node_type))
	intents.clear()
	for intent_value in data.get("intents", []):
		if intent_value is Dictionary:
			intents.append(GameDataScript.normalize_enemy_intent(intent_value))
	boss = data.get("boss", false) == true

func get_current_intent() -> Dictionary:
	if boss:
		return _boss_intent()
	if intents.is_empty():
		return {"type": "attack", "text": "准备攻击", "value": attack}
	return intents[turn_index % intents.size()].duplicate(true)

func advance_intent() -> void:
	turn_index += 1
	interrupted_this_turn = false

func take_damage(amount: int, color_key: String = "gray", ignore_armor: bool = false) -> int:
	var incoming: int = max(amount, 0)
	if resistance_turns > 0 and resistance_color == color_key:
		incoming = int(round(float(incoming) * (1.0 - resistance_rate)))
	var blocked: int = 0 if ignore_armor else min(armor, incoming)
	if not ignore_armor:
		armor -= blocked
	var real_amount: int = incoming - blocked
	hp = max(hp - real_amount, 0)
	return real_amount

func heal(amount: int) -> int:
	var before: int = hp
	hp = min(hp + max(amount, 0), max_hp)
	return hp - before

func add_armor(amount: int) -> void:
	armor += max(amount, 0)

func apply_burn(turns: int, stacks: int = 1) -> void:
	burn_turns = max(burn_turns, turns)
	burn_stacks = min(burn_stacks + max(stacks, 1), 4)

func apply_freeze(turns: int) -> void:
	freeze_turns = max(freeze_turns, turns)

func interrupt_charge() -> bool:
	if not charge_pending:
		return false
	charge_pending = false
	interrupted_this_turn = true
	return true

func set_resistance(color_key: String, rate: float, turns: int = 1) -> void:
	resistance_color = color_key
	resistance_rate = clamp(rate, 0.0, 0.9)
	resistance_turns = max(turns, 0)
	resistance_just_applied = resistance_turns > 0

func clear_resistance() -> bool:
	if resistance_turns <= 0:
		return false
	resistance_color = ""
	resistance_rate = 0.0
	resistance_turns = 0
	resistance_just_applied = false
	return true

func tick_status_after_enemy_turn() -> void:
	if resistance_turns <= 0:
		resistance_just_applied = false
		return
	if resistance_just_applied:
		resistance_just_applied = false
		return
	resistance_turns -= 1
	if resistance_turns <= 0:
		resistance_color = ""
		resistance_rate = 0.0
		resistance_just_applied = false

func is_dead() -> bool:
	return hp <= 0

func create_snapshot() -> Dictionary:
	return {
		"enemy_id": enemy_id,
		"hp": hp,
		"max_hp": max_hp,
		"attack": attack,
		"reward": reward,
		"turn_index": turn_index,
		"burn_stacks": burn_stacks,
		"burn_turns": burn_turns,
		"freeze_turns": freeze_turns,
		"armor": armor,
		"resistance_color": resistance_color,
		"resistance_rate": resistance_rate,
		"resistance_turns": resistance_turns,
		"resistance_just_applied": resistance_just_applied,
		"charge_pending": charge_pending,
		"interrupted_this_turn": interrupted_this_turn,
	}

func restore_snapshot(snapshot_value: Variant) -> bool:
	if not snapshot_value is Dictionary:
		return false
	var snapshot: Dictionary = snapshot_value
	if String(snapshot.get("enemy_id", enemy_id)) != enemy_id:
		return false
	max_hp = maxi(int(snapshot.get("max_hp", max_hp)), 1)
	hp = clampi(int(snapshot.get("hp", hp)), 0, max_hp)
	attack = maxi(int(snapshot.get("attack", attack)), 0)
	reward = maxi(int(snapshot.get("reward", reward)), 0)
	turn_index = maxi(int(snapshot.get("turn_index", 0)), 0)
	burn_stacks = clampi(int(snapshot.get("burn_stacks", 0)), 0, 4)
	burn_turns = maxi(int(snapshot.get("burn_turns", 0)), 0)
	freeze_turns = maxi(int(snapshot.get("freeze_turns", 0)), 0)
	armor = maxi(int(snapshot.get("armor", 0)), 0)
	resistance_color = String(snapshot.get("resistance_color", ""))
	resistance_rate = clampf(float(snapshot.get("resistance_rate", 0.0)), 0.0, 0.9)
	resistance_turns = maxi(int(snapshot.get("resistance_turns", 0)), 0)
	resistance_just_applied = snapshot.get("resistance_just_applied", false) == true and resistance_turns > 0
	charge_pending = snapshot.get("charge_pending", false) == true
	interrupted_this_turn = snapshot.get("interrupted_this_turn", false) == true
	return true

func get_status_text() -> String:
	var parts: Array[String] = []
	if armor > 0:
		parts.append("护甲 %d" % armor)
	if burn_turns > 0:
		parts.append("燃烧 %d层/%d回合" % [burn_stacks, burn_turns])
	if freeze_turns > 0:
		parts.append("冻结 %d" % freeze_turns)
	if charge_pending:
		parts.append("蓄力")
	if resistance_turns > 0:
		parts.append("%s抗性" % GameDataScript.color_full_name(resistance_color))
	return "无状态" if parts.is_empty() else " / ".join(parts)

func get_intent_text() -> String:
	var intent: Dictionary = get_current_intent()
	var intent_type: String = String(intent.get("type", "attack"))
	match intent_type:
		"attack", "heavy":
			return "%s：%d 伤害" % [intent.get("text", "攻击"), int(intent.get("value", attack))]
		"charge":
			return "%s：下次 %d 伤害" % [intent.get("text", "蓄力"), int(intent.get("value", attack))]
		"pollute":
			return "%s：污染 %d 格" % [intent.get("text", "污染"), int(intent.get("value", 2))]
		"defend":
			return "%s：护甲 %d" % [intent.get("text", "防御"), int(intent.get("value", 18))]
		"resist":
			return "%s：%s -%d%%" % [intent.get("text", "抗性"), GameDataScript.color_full_name(String(intent.get("color", "red"))), int(float(intent.get("value", 0.35)) * 100.0)]
		"steal":
			return "%s：%d 金币" % [intent.get("text", "偷取"), int(intent.get("value", 6))]
		"heal":
			return "%s：回复 %d" % [intent.get("text", "治疗"), int(intent.get("value", 20))]
		"player_burn":
			return "%s：玩家燃烧" % intent.get("text", "燃烧")
		"spectrum_drift":
			return "%s：下一谱伤害 -%d%%" % [intent.get("text", "色谱漂移"), int(float(intent.get("value", 0.18)) * 100.0)]
		"spectrum_suppress":
			return "%s：下一谱固定伤害 -4" % intent.get("text", "色谱压制")
		"board_corrupt":
			return "%s：下一谱伤害 -2，并腐化棋盘 1 格" % intent.get("text", "棋盘腐化")
		"spectrum_seal":
			return "%s：下一谱伤害 -%d" % [intent.get("text", "色谱封锁"), int(intent.get("value", 3))]
		_:
			return String(intent.get("text", intent_type))

func get_boss_phase() -> int:
	if not boss:
		return 1
	var hp_ratio: float = float(hp) / float(max(max_hp, 1))
	if hp_ratio <= 0.30:
		return 3
	if hp_ratio <= 0.65:
		return 2
	return 1

func _boss_intent() -> Dictionary:
	if intents.is_empty():
		return {"type": "attack", "text": "首领攻击", "value": attack}
	var phase: int = get_boss_phase()
	var indices: Array = []
	match enemy_id:
		"B-GR-01":
			indices = [0, 1, 2] if phase == 1 else ([1, 3, 4, 2] if phase == 2 else [0, 1, 3, 4])
		"B-ML-01":
			indices = [0, 1, 2] if phase == 1 else ([2, 3, 4, 5] if phase == 2 else [0, 3, 4, 5])
		"B-CT-01":
			indices = [0, 2, 3] if phase == 1 else ([0, 1, 3, 4, 5] if phase == 2 else [1, 0, 4, 5])
		_:
			return intents[turn_index % intents.size()].duplicate(true)
	var selected_index: int = indices[turn_index % indices.size()]
	return intents[clampi(selected_index, 0, intents.size() - 1)].duplicate(true)
