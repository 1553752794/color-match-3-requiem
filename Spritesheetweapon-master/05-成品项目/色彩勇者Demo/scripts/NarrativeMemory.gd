extends RefCounted
class_name NarrativeMemory

const MAX_EQUIPPED: int = 3
const DEFAULT_UNLOCKED: Array[String] = ["M01", "M02", "M03"]

const VOWS: Dictionary = {
	"vow_order": {
		"id": "vow_order", "name": "守序之誓", "subtitle": "让差异依次发声",
		"description": "谱序达到对位或更高时获得 3 护盾。三章固定采用均衡地图池。",
		"template_id": "standard", "color": "blue", "resonance_shield": 3,
		"ending": "你没有让任何一种颜色独占答案，而是为它们留下了相邻的位置。",
	},
	"vow_fracture": {
		"id": "vow_fracture", "name": "破谱之誓", "subtitle": "用裂痕换取更响的终止式",
		"description": "最大 HP -10；和鸣以上谱式伤害提高 18%。三章固定采用高风险地图池。",
		"template_id": "risk", "color": "red", "max_hp_delta": -10, "resonance_damage_ratio": 1.18,
		"ending": "你把裂痕留在自己身上，让回廊第一次听见了毫不妥协的终止式。",
	},
	"vow_witness": {
		"id": "vow_witness", "name": "见证之誓", "subtitle": "先记住，再决定谁应被原谅",
		"description": "每场战斗都可发现记忆碎片；重复碎片转化的记忆墨 +1。三章固定采用事件地图池。",
		"template_id": "economy", "color": "gold", "memory_every_battle": true, "duplicate_insight_bonus": 1,
		"ending": "你没有替旧日作证；你只是把被删去的姓名重新写回了谱页。",
	},
}

const MEMORY_SETS: Dictionary = {
	"lamplighters": {"name": "守灯者旧誓", "ids": ["M01", "M02", "M03"]},
	"archivist": {"name": "被删去的守灯档案", "ids": ["M04", "M05", "M06"]},
	"court": {"name": "无色王庭", "ids": ["M07", "M08", "M09"]},
	"court_edict": {"name": "王庭删改令", "ids": ["M10", "M11", "M12"]},
	"mirror": {"name": "镜湖回声", "ids": ["M13", "M14", "M15"]},
	"mirror_rebellion": {"name": "倒影的罢工", "ids": ["M16", "M17", "M18"]},
	"corridor": {"name": "断色回廊", "ids": ["M19", "M20", "M21"]},
	"corridor_witness": {"name": "回廊见证词", "ids": ["M22", "M23", "M24"]},
	"score_calibration": {"name": "失拍校准记录", "ids": ["M25", "M26", "M27"]},
	"ending_contradiction": {"name": "三种都发生过的结局", "ids": ["M28", "M29", "M30"]},
}

const FRAGMENTS: Dictionary = {
	"M01": {"title": "未熄的第一盏灯", "set_id": "lamplighters", "slot": "cause", "chapter": 1, "speaker": "守灯人阿芙", "body": "边境第一次褪色时，守灯人被命令只保留红光。阿芙偷偷在灯芯里藏了一滴蓝。", "effect": "first_turn_shield", "value": 2},
	"M02": {"title": "两种火焰", "set_id": "lamplighters", "slot": "witness", "chapter": 1, "speaker": "残缺工单", "body": "工单写着：相异色谱连续完成时，回廊会回以和声。署名被烧掉了一半。", "effect": "resonance_base_damage", "value": 1},
	"M03": {"title": "门后的呼吸", "set_id": "lamplighters", "slot": "aftermath", "chapter": 1, "speaker": "陌生孩子", "body": "门外的人说灰雾没有声音。可每当灯灭，我都听见它在背诵我们的名字。", "effect": "spectrum_amp", "value": 0.02},
	"M04": {"title": "第七码头", "set_id": "archivist", "slot": "cause", "chapter": 1, "speaker": "边境账房", "body": "撤离名单只有六个码头。第七码头运走的不是居民，而是被王庭判定为不稳定的颜色。", "effect": "reward_gold", "value": 2},
	"M05": {"title": "熄灯条例", "set_id": "archivist", "slot": "witness", "chapter": 2, "speaker": "王庭布告", "body": "混色者不得守夜，不得抄谱，不得为死者点灯。违者的姓名将从颜色簿中剔除。", "effect": "gray_resist", "value": 1},
	"M06": {"title": "阿芙的末页", "set_id": "archivist", "slot": "aftermath", "chapter": 3, "speaker": "阿芙", "body": "若你读到这里，灯已经不重要了。重要的是别让他们把我们说成从未存在。", "effect": "post_battle_heal", "value": 1},
	"M07": {"title": "王冠的背面", "set_id": "court", "slot": "cause", "chapter": 1, "speaker": "宫廷雕刻师", "body": "王冠正面镶着七色宝石，背面却刻着一句话：颜色越少，秩序越稳。", "effect": "spectrum_base_damage", "value": 1},
	"M08": {"title": "白厅审讯录", "set_id": "court", "slot": "witness", "chapter": 2, "speaker": "无色书记", "body": "被告承认听见两种旋律同时响起。书记将这句话改成：被告承认制造噪音。", "effect": "skill_charge_start", "value": 1},
	"M09": {"title": "空席位", "set_id": "court", "slot": "aftermath", "chapter": 2, "speaker": "宴会侍从", "body": "每次宴会都多摆一把椅子，没人知道它属于谁。只有无色王从不允许撤走。", "effect": "first_turn_shield", "value": 3},
	"M10": {"title": "校色法案", "set_id": "court_edict", "slot": "cause", "chapter": 2, "speaker": "首席调律师", "body": "法案不是为了消灭颜色，而是规定颜色只能在获准的时刻出现。", "effect": "resonance_base_damage", "value": 1},
	"M11": {"title": "黑谱的合法性", "set_id": "court_edict", "slot": "witness", "chapter": 3, "speaker": "匿名辩词", "body": "黑并非没有颜色；它只是把所有未被允许的颜色一起藏了起来。", "effect": "spectrum_break", "value": 1},
	"M12": {"title": "最后一次表决", "set_id": "court_edict", "slot": "aftermath", "chapter": 3, "speaker": "议事钟", "body": "赞成票是金，反对票是蓝，弃权票是灰。钟声响后，记录里只剩灰。", "effect": "reward_gold", "value": 3},
	"M13": {"title": "镜湖原型机", "set_id": "mirror", "slot": "cause", "chapter": 1, "speaker": "凛镜", "body": "第一面镜子并不映照面孔，只显示一个人最害怕失去的颜色。", "effect": "spectrum_amp", "value": 0.02},
	"M14": {"title": "回声比人先到", "set_id": "mirror", "slot": "witness", "chapter": 2, "speaker": "工坊值班记录", "body": "夜班工人听见明天的警报。他们停机后，王庭以破坏生产的罪名逮捕了所有人。", "effect": "skill_charge_start", "value": 2},
	"M15": {"title": "冻住的道歉", "set_id": "mirror", "slot": "aftermath", "chapter": 2, "speaker": "未寄出的信", "body": "我不是没来得及道歉。我把那句话冻在湖底，以为时间会替我保管。", "effect": "post_battle_heal", "value": 1},
	"M16": {"title": "倒影罢工", "set_id": "mirror_rebellion", "slot": "cause", "chapter": 2, "speaker": "镜湖传闻", "body": "某天所有倒影都拒绝模仿主人。那是回廊第一次公开反抗。", "effect": "resonance_base_damage", "value": 2},
	"M17": {"title": "第二个凛镜", "set_id": "mirror_rebellion", "slot": "witness", "chapter": 3, "speaker": "镜中人", "body": "她问我谁才是复制品。我说，愿意离开镜面的人才需要承担答案。", "effect": "gray_resist", "value": 1},
	"M18": {"title": "湖水退去以后", "set_id": "mirror_rebellion", "slot": "aftermath", "chapter": 3, "speaker": "工坊童谣", "body": "湖底没有怪物，只有一整座被封存的旧工坊，以及仍在运转的记录机。", "effect": "spectrum_base_damage", "value": 2},
	"M19": {"title": "回廊入口", "set_id": "corridor", "slot": "cause", "chapter": 1, "speaker": "伊澜", "body": "断色回廊不是一处地点。每当两个互不相容的记忆被同时相信，它就会出现。", "effect": "first_turn_shield", "value": 3},
	"M20": {"title": "谱式的旧用途", "set_id": "corridor", "slot": "witness", "chapter": 1, "speaker": "仪式说明残页", "body": "谱式最初用于把记忆送过封锁线。后来有人发现，共振也能击穿盔甲。", "effect": "spectrum_break", "value": 1},
	"M21": {"title": "灰蚀并非天灾", "set_id": "corridor", "slot": "aftermath", "chapter": 2, "speaker": "研究员弥砂", "body": "灰蚀是被删去的颜色留下的空位。空位太多，世界才开始向内坍缩。", "effect": "gray_resist", "value": 2},
	"M22": {"title": "三份同名档案", "set_id": "corridor_witness", "slot": "cause", "chapter": 2, "speaker": "洛恩", "body": "我买到三份自己的出生记录。每一份父母不同，只有债务金额完全一致。", "effect": "reward_gold", "value": 4},
	"M23": {"title": "无色王的本名", "set_id": "corridor_witness", "slot": "witness", "chapter": 3, "speaker": "被涂改的谱页", "body": "王并非无色。他曾是第一个能同时听见八种色谱的人，因此最先害怕失控。", "effect": "resonance_base_damage", "value": 2},
	"M24": {"title": "留给下一位见证者", "set_id": "corridor_witness", "slot": "aftermath", "chapter": 3, "speaker": "色彩勇者", "body": "不要替我们选出唯一真相。把碎片留在这里，让下一位经过的人自己排列。", "effect": "spectrum_amp", "value": 0.04},
	"M25": {"title": "铸匠的零号标尺", "set_id": "score_calibration", "slot": "cause", "chapter": 1, "speaker": "谱式铸匠", "body": "第一份校准谱不是武器，而是测量一句话会被现实削去多少的仪式。刻度零点被人故意挪过。", "effect": "spectrum_base_damage", "value": 1},
	"M26": {"title": "井壁延迟记录", "set_id": "score_calibration", "slot": "witness", "chapter": 2, "speaker": "回声井值守员", "body": "回声不是重复。它是被删去的半句话绕远路回来，恰好接上下一段旋律。", "effect": "skill_charge_start", "value": 1},
	"M27": {"title": "不可逆校准", "set_id": "score_calibration", "slot": "aftermath", "chapter": 3, "speaker": "终幕工坊", "body": "工坊知道所有量谱都会撒谎，所以把最后一次校准留给愿意承担偏差的人。", "effect": "spectrum_break", "value": 1},
	"M28": {"title": "平衡者的空白页", "set_id": "ending_contradiction", "slot": "cause", "chapter": 3, "speaker": "终局档案", "body": "四种颜色保持平衡时，空白并没有消失，只是再也没人拥有唯一的解释权。", "effect": "first_turn_shield", "value": 3},
	"M29": {"title": "灰蚀胜利的王印", "set_id": "ending_contradiction", "slot": "witness", "chapter": 3, "speaker": "灰印保管人", "body": "灰并非失败的颜色。它是世界拒绝继续争辩时盖下的印，也证明沉默曾经作出选择。", "effect": "gray_resist", "value": 1},
	"M30": {"title": "魔王倾向的重叠署名", "set_id": "ending_contradiction", "slot": "aftermath", "chapter": 3, "speaker": "三份终局文书", "body": "红、蓝、金三份终局文书使用了同一个签名。互相冲突的胜利，都曾被王庭宣布为真。", "effect": "resonance_base_damage", "value": 1},
}


static func fragment(memory_id: String) -> Dictionary:
	var data: Dictionary = FRAGMENTS.get(memory_id, {}).duplicate(true)
	if not data.is_empty():
		data["id"] = memory_id
	return data


static func vow(vow_id: String) -> Dictionary:
	return VOWS.get(vow_id, {}).duplicate(true)


static func sanitize_unlocked(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			var memory_id: String = String(entry)
			if FRAGMENTS.has(memory_id) and not result.has(memory_id):
				result.append(memory_id)
	for memory_id in DEFAULT_UNLOCKED:
		if not result.has(memory_id):
			result.append(memory_id)
	return result


static func sanitize_equipped(value: Variant, unlocked: Array[String]) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			var memory_id: String = String(entry)
			if unlocked.has(memory_id) and not result.has(memory_id):
				result.append(memory_id)
				if result.size() >= MAX_EQUIPPED:
					break
	if result.is_empty():
		for memory_id in unlocked:
			result.append(memory_id)
			if result.size() >= MAX_EQUIPPED:
				break
	return result


static func reward_for(node_id: String, run_seed: int, unlocked_value: Variant) -> String:
	var unlocked: Array[String] = sanitize_unlocked(unlocked_value)
	var chapter_number: int = clampi(int(node_id.get_slice("-", 0).trim_prefix("C")), 1, 3)
	var candidates: Array[String] = []
	for memory_id in FRAGMENTS.keys():
		var id: String = String(memory_id)
		if int(FRAGMENTS[id].get("chapter", 1)) == chapter_number and not unlocked.has(id):
			candidates.append(id)
	if candidates.is_empty():
		for memory_id in FRAGMENTS.keys():
			var id: String = String(memory_id)
			if not unlocked.has(id):
				candidates.append(id)
	if candidates.is_empty():
		for memory_id in FRAGMENTS.keys():
			var id: String = String(memory_id)
			if int(FRAGMENTS[id].get("chapter", 1)) == chapter_number:
				candidates.append(id)
	if candidates.is_empty():
		return ""
	candidates.sort()
	var reward_index: int = posmod(run_seed + node_id.hash() * 31, candidates.size())
	return candidates[reward_index]


static func set_progress(unlocked_value: Variant) -> Dictionary:
	var unlocked: Array[String] = sanitize_unlocked(unlocked_value)
	var result: Dictionary = {}
	for set_id in MEMORY_SETS.keys():
		var ids: Array = MEMORY_SETS[set_id].get("ids", [])
		var count: int = 0
		for memory_id in ids:
			if unlocked.has(String(memory_id)):
				count += 1
		result[set_id] = {"count": count, "total": ids.size(), "complete": count == ids.size()}
	return result
