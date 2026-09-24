class_name ChapterProjects
extends RefCounted

const GameDataScript = preload("res://scripts/GameData.gd")
const CHAPTERS: Array[String] = ["C1", "C2", "C3"]
const PROJECT_IDS: Array[String] = ["forge", "sanctuary", "exchange"]
const PROJECTS: Dictionary = {
	"forge": {
		"id": "forge", "name": "熔彩工坊", "color": "red", "description": "本章期限：普通战/Boss +1，精英/挑战 +2；完成后永久获得谱式基础伤害 +3。",
		"coin_cost": 30, "pigment_cost": 1, "target": 2,
		"effects": {"spectrum_base_damage": 3},
	},
	"sanctuary": {
		"id": "sanctuary", "name": "净色花园", "color": "blue", "description": "本章期限：非战斗节点（事件/营火/商店/宝箱）各推进 +1；完成后永久获得每场开局护盾 +4。",
		"coin_cost": 30, "pigment_cost": 1, "target": 2,
		"effects": {"first_turn_shield": 4},
	},
	"exchange": {
		"id": "exchange", "name": "商路会馆", "color": "gold", "description": "本章期限：每个合法非起点节点推进 +1；完成后永久使商店价格降低 5%。",
		"coin_cost": 30, "pigment_cost": 1, "target": 3,
		"effects": {"shop_discount": 0.05},
	},
}

var records: Dictionary = {}

func begin(chapter_id: String, project_id: String) -> bool:
	if not CHAPTERS.has(chapter_id) or not PROJECTS.has(project_id):
		return false
	if records.has(chapter_id):
		return false
	records[chapter_id] = {
		"id": project_id,
		"progress": 0,
		"completed": false,
		"credited_nodes": [],
	}
	return true

func advance(node_id: String, node_type: String) -> Dictionary:
	var chapter_id: String = _chapter_id(node_id)
	if chapter_id.is_empty() or not records.has(chapter_id):
		return {}
	var record: Dictionary = records[chapter_id]
	if bool(record.get("completed", false)):
		return {}
	var project_id: String = String(record.get("id", ""))
	if not PROJECTS.has(project_id) or _node_type(node_id) != node_type or node_type == "start":
		return {}
	var credited_nodes: Array = record.get("credited_nodes", []).duplicate()
	if credited_nodes.has(node_id):
		return {}
	var increment: int = _node_value(project_id, node_type)
	if increment <= 0:
		return {}
	credited_nodes.append(node_id)
	record["credited_nodes"] = credited_nodes
	record["progress"] = _credited_progress(project_id, credited_nodes)
	if int(record["progress"]) >= int(PROJECTS[project_id]["target"]):
		record["completed"] = true
		records[chapter_id] = record
		var result: Dictionary = PROJECTS[project_id].duplicate(true)
		result["completed"] = true
		result["progress"] = record["progress"]
		result["credited_nodes"] = credited_nodes.duplicate()
		return result
	records[chapter_id] = record
	return {}

func snapshot() -> Dictionary:
	return records.duplicate(true)

func restore(value: Variant) -> void:
	records.clear()
	if not value is Dictionary:
		return
	var raw_records: Dictionary = value
	for chapter_value in raw_records.keys():
		if not chapter_value is String:
			continue
		var chapter_id: String = chapter_value
		if not CHAPTERS.has(chapter_id):
			continue
		var raw_record: Variant = raw_records[chapter_value]
		if not raw_record is Dictionary:
			continue
		if not raw_record.has("id") or not raw_record["id"] is String:
			continue
		var project_id: String = raw_record["id"]
		if not PROJECTS.has(project_id):
			continue
		var raw_progress: Variant = raw_record.get("progress", 0)
		if not (raw_progress is int or raw_progress is float) or not is_finite(float(raw_progress)):
			continue
		var raw_nodes: Variant = raw_record.get("credited_nodes", [])
		if not raw_nodes is Array:
			continue
		var credited_nodes: Array[String] = []
		for node_value in raw_nodes:
			if not node_value is String:
				continue
			var node_id: String = node_value
			if _chapter_id(node_id) != chapter_id or _node_type(node_id).is_empty() or _node_type(node_id) == "start":
				continue
			if not credited_nodes.has(node_id):
				credited_nodes.append(node_id)
		var progress: int = _credited_progress(project_id, credited_nodes)
		if not is_equal_approx(float(raw_progress), float(progress)):
			continue
		records[chapter_id] = {
			"id": project_id,
			"progress": progress,
			"completed": progress >= int(PROJECTS[project_id]["target"]),
			"credited_nodes": credited_nodes,
		}

func effect_total(effect_id: String) -> float:
	var total: float = 0.0
	for record_value in records.values():
		var record: Dictionary = record_value
		if not bool(record.get("completed", false)):
			continue
		var project_id: String = String(record.get("id", ""))
		if PROJECTS.has(project_id):
			total += float(PROJECTS[project_id].get("effects", {}).get(effect_id, 0.0))
	return total

func status(chapter_id: String) -> Dictionary:
	if not records.has(chapter_id):
		return {}
	var record: Dictionary = records[chapter_id]
	var project_id: String = String(record.get("id", ""))
	if not PROJECTS.has(project_id):
		return {}
	var result: Dictionary = PROJECTS[project_id].duplicate(true)
	result.merge(record.duplicate(true))
	return result

func options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for project_id in PROJECT_IDS:
		result.append(PROJECTS[project_id].duplicate(true))
	return result

func _chapter_id(node_id: String) -> String:
	if node_id.length() < 3 or node_id[2] != "-":
		return ""
	var chapter_id: String = node_id.substr(0, 2)
	return chapter_id if CHAPTERS.has(chapter_id) else ""

func _node_type(node_id: String) -> String:
	var node: Dictionary = GameDataScript.node(node_id)
	return String(node.get("type", ""))

func _node_value(project_id: String, node_type: String) -> int:
	match project_id:
		"forge":
			return 2 if node_type in ["elite", "challenge"] else 1 if node_type in ["combat", "boss"] else 0
		"sanctuary":
			return 1 if node_type in ["event", "camp", "chest", "shop"] else 0
		"exchange":
			return 0 if node_type in ["", "start"] else 1
	return 0

func _credited_progress(project_id: String, credited_nodes: Array) -> int:
	var progress: int = 0
	for node_id in credited_nodes:
		progress += _node_value(project_id, _node_type(String(node_id)))
	return progress
