extends Control

const BoardScript = preload("res://scripts/Board.gd")
const BattleManagerScript = preload("res://scripts/BattleManager.gd")
const SpectrumCardScript = preload("res://scripts/SpectrumCard.gd")
const MapCanvasScript = preload("res://scripts/MapCanvas.gd")
const SkillButtonScript = preload("res://scripts/SkillButton.gd")
const GameDataScript = preload("res://scripts/GameData.gd")
const GameThemeScript = preload("res://scripts/GameTheme.gd")
const AscensionRulesScript = preload("res://scripts/AscensionRules.gd")
const NarrativeMemoryScript = preload("res://scripts/NarrativeMemory.gd")
const StrategyCouncilScript = preload("res://scripts/StrategyCouncil.gd")

const MUSIC_CHAPTER_1 = preload("res://assets/audio/v1/chapter1_gray_border.wav")
const MUSIC_CHAPTER_2 = preload("res://assets/audio/v1/chapter2_mirror_lake.wav")
const MUSIC_CHAPTER_3 = preload("res://assets/audio/v1/chapter3_colorless_court.wav")
const MUSIC_MENU = MUSIC_CHAPTER_1
const SFX_SELECT = preload("res://assets/audio/select.wav")
const SFX_ENTER = preload("res://assets/audio/enter.wav")
const SFX_BREAK = preload("res://assets/audio/break.wav")
const SOLDIER_IDLE = preload("res://assets/characters/soldier_idle.png")
const ORC_IDLE = preload("res://assets/characters/orc_idle.png")
const HERO_PORTRAIT = preload("res://assets/characters/portraits/hero_color_brave.png")
const BOSS_GRAY_DRAGON = preload("res://assets/characters/portraits/boss_gray_dragon.png")
const BOSS_MIRROR_CONDUCTOR = preload("res://assets/characters/portraits/boss_mirror_conductor.png")
const BOSS_COLORLESS_KING = preload("res://assets/characters/portraits/boss_colorless_king.png")
const ARCHIVE_BACKDROP = preload("res://assets/ui/v2/archive_backdrop.png")
const MAP_NODE_SIZE := Vector2(116.0, 58.0)
const MAP_NODE_GUTTER := 12.0
const MAP_CONTENT_MIN_HEIGHT := 1040.0
const MAP_ROUTE_MAX_WIDTH := 900.0
const SPECTRUM_CARD_WIDTH := 184.0

var current_screen: Control
var board: Board
var battle_manager: BattleManager
var battle_bg: ColorRect
var enemy_hp_bar: ProgressBar
var player_hp_bar: ProgressBar
var player_hp_text_label: Label
var enemy_status_label: Label
var enemy_intent_label: Label
var moves_label: Label
var spectrum_completion_label: Label
var coins_label: Label
var pigment_label: Label
var resonance_label: Label
var shield_label: Label
var combo_label: Label
var deck_label: Label
var log_label: RichTextLabel
var enemy_avatar: TextureRect
var hero_avatar: TextureRect
var spectrum_row: HBoxContainer
var resolution_name_label: Label
var resolution_damage_label: Label
var resolution_bonus_label: Label
var skill_button: Variant
var recent_logs: Array[String] = []
var last_state: Dictionary = {}
var active_shop_inventory: Array[Dictionary] = []
var map_view_save_timer: Timer
var map_view_dirty: bool = false
var selected_character_preview_id: String = "red"
var turn_exchange_count: int = 0
var codex_tab: String = "characters"
var codex_selected_id: String = ""
var codex_school_filter: String = "all"
var codex_rarity_filter: String = "all"
var route_pool_choice_committed: bool = false
var feedback_title: Label
var feedback_detail: Label
var feedback_timer: Timer
var feedback_priority: int = -1
var screen_generation: int = 0

var music_player: AudioStreamPlayer
var select_player: AudioStreamPlayer
var enter_player: AudioStreamPlayer
var break_player: AudioStreamPlayer
var GameManager: Node
var SaveManager: Node
var SettingsManager: Node

func _gm() -> Node:
	if GameManager == null:
		GameManager = get_node("/root/GameManager")
	return GameManager

func _ready() -> void:
	randomize()
	self.theme = GameThemeScript.create_theme()
	_setup_audio()
	_gm()
	SaveManager = get_node("/root/SaveManager")
	SettingsManager = get_node("/root/SettingsManager")
	map_view_save_timer = Timer.new()
	map_view_save_timer.name = "MapViewSaveTimer"
	map_view_save_timer.wait_time = 0.35
	map_view_save_timer.one_shot = true
	map_view_save_timer.timeout.connect(_flush_map_view_state)
	add_child(map_view_save_timer)
	tree_exiting.connect(_flush_map_view_state)
	SettingsManager.settings_changed.connect(_apply_audio_settings)
	_apply_audio_settings()
	show_main_menu()

func _setup_audio() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.stream = MUSIC_MENU
	music_player.volume_db = -15
	add_child(music_player)
	music_player.play()
	select_player = _new_sfx_player(SFX_SELECT, -8)
	enter_player = _new_sfx_player(SFX_ENTER, -8)
	break_player = _new_sfx_player(SFX_BREAK, -9)

func _apply_audio_settings() -> void:
	if SettingsManager == null:
		return
	if music_player != null:
		music_player.volume_db = -15.0 + linear_to_db(max(float(SettingsManager.music_volume), 0.0001))
		music_player.stream_paused = float(SettingsManager.music_volume) <= 0.001
	for player in [select_player, enter_player, break_player]:
		if player != null:
			player.volume_db = -8.0 + linear_to_db(max(float(SettingsManager.sfx_volume), 0.0001))

func _new_sfx_player(stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player

func show_main_menu() -> void:
	_clear_screen()
	_switch_music(MUSIC_MENU)
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	_add_menu_backdrop(current_screen)

	var overlay: PanelContainer = PanelContainer.new()
	overlay.anchor_bottom = 1.0
	overlay.offset_right = 590.0
	overlay.add_theme_stylebox_override("panel", GameThemeScript.panel_style(Color(0.043, 0.051, 0.063, 0.95), GameThemeScript.BG_BASE, 0, 0, 0))
	current_screen.add_child(overlay)

	var outer_margin: MarginContainer = MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 46)
	outer_margin.add_theme_constant_override("margin_right", 46)
	outer_margin.add_theme_constant_override("margin_top", 28)
	outer_margin.add_theme_constant_override("margin_bottom", 24)
	overlay.add_child(outer_margin)

	var composition: HBoxContainer = HBoxContainer.new()
	composition.add_theme_constant_override("separation", 24)
	outer_margin.add_child(composition)
	var rule: ColorRect = ColorRect.new()
	rule.color = GameThemeScript.RED
	rule.custom_minimum_size = Vector2(5, 0)
	rule.size_flags_vertical = Control.SIZE_EXPAND_FILL
	composition.add_child(rule)

	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(445, 0)
	box.add_theme_constant_override("separation", 8)
	composition.add_child(box)

	box.add_child(_make_label("正式版内容更新 · 2.3.0 / 复兴议会", 13, GameThemeScript.TEXT_SECONDARY))
	box.add_child(_vertical_spacer(4))
	var title: Label = _make_label("色彩勇者\n三消镇魂曲", 44, GameThemeScript.TEXT_PRIMARY)
	title.custom_minimum_size = Vector2(440, 100)
	box.add_child(title)
	box.add_child(_make_label("CHROMA HERO · REQUIEM OF MATCHES", 13, GameThemeScript.GOLD))
	box.add_child(_vertical_spacer(20))

	var pitch: Label = _make_label("颜色没有消失，只是有人删去了它们的证词。\n立下誓约，在三消与色谱之间续写回廊。", 16, GameThemeScript.TEXT_SECONDARY)
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pitch.custom_minimum_size = Vector2(440, 56)
	box.add_child(pitch)
	box.add_child(_vertical_spacer(12))

	if SaveManager.has_run_save():
		var continue_button: Button = _make_button("继续旅程   %s" % SaveManager.get_run_summary(), Vector2(330, 52), GameThemeScript.SURFACE_RAISED)
		continue_button.pressed.connect(func() -> void:
			_play_enter()
			if SaveManager.load_run():
				_resume_loaded_run()
			else:
				_on_toast(SaveManager.last_error, Callable(self, "show_main_menu"))
		)
		box.add_child(continue_button)

	var primary_row: HBoxContainer = HBoxContainer.new()
	primary_row.add_theme_constant_override("separation", 10)
	box.add_child(primary_row)
	var start_button: Button = _make_button("开始新旅程", Vector2(260, 52), GameThemeScript.RED)
	start_button.name = "NewJourney"
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.pressed.connect(func() -> void:
		_play_enter()
		_request_new_journey()
	)
	primary_row.add_child(start_button)

	var codex_button: Button = _make_button("图鉴", Vector2(72, 52), GameThemeScript.SURFACE)
	codex_button.tooltip_text = "角色、色谱、遗物与事件图鉴"
	codex_button.pressed.connect(func() -> void:
		_play_select()
		show_codex()
	)
	primary_row.add_child(codex_button)

	var settings_button: Button = _make_button("设置", Vector2(72, 52), GameThemeScript.SURFACE)
	settings_button.tooltip_text = "设置"
	settings_button.pressed.connect(func() -> void:
		_play_select()
		show_settings()
	)
	primary_row.add_child(settings_button)

	var utility_row: HBoxContainer = HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 10)
	box.add_child(utility_row)
	var archive_button: Button = _make_button("记忆回廊  %d / %d" % [GameManager.unlocked_memory_ids.size(), NarrativeMemoryScript.FRAGMENTS.size()], Vector2(230, 40), GameThemeScript.SURFACE_RAISED)
	archive_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archive_button.tooltip_text = "查看并重组已发现的记忆碎片"
	archive_button.pressed.connect(func() -> void:
		_play_select()
		show_memory_archive(false)
	)
	utility_row.add_child(archive_button)

	var quit_button: Button = _make_button("退出", Vector2(100, 40), GameThemeScript.SURFACE)
	quit_button.pressed.connect(func() -> void:
		_play_select()
		get_tree().quit()
	)
	utility_row.add_child(quit_button)
	box.add_child(_vertical_spacer(0))
	box.add_child(_make_label("正式版 2.3.0 · 政策 · 建设项目 · 复兴议会", 13, GameThemeScript.TEXT_MUTED))

	_add_chapter_signature(current_screen)
	start_button.grab_focus()

func _request_new_journey() -> void:
	if not SaveManager.has_run_save():
		_begin_new_journey()
		return
	var confirmation: ConfirmationDialog = current_screen.get_node_or_null("ConfirmNewJourney") as ConfirmationDialog
	if confirmation == null:
		confirmation = ConfirmationDialog.new()
		confirmation.name = "ConfirmNewJourney"
		confirmation.title = "开始新旅程"
		confirmation.dialog_text = "当前远征将被替换，已发现的记忆会保留。"
		confirmation.ok_button_text = "开始新旅程"
		confirmation.cancel_button_text = "保留远征"
		confirmation.confirmed.connect(_begin_new_journey)
		current_screen.add_child(confirmation)
	confirmation.popup_centered(Vector2i(420, 160))

func _begin_new_journey() -> void:
	SaveManager.clear_run()
	GameManager.reset_run()
	show_start_node()

func _resume_loaded_run() -> void:
	match String(GameManager.run_phase):
		"character_selection":
			show_start_node()
		"vow_selection":
			show_vow_selection()
		"policy_selection":
			show_policy_selection()
		"route_selection":
			show_route_pool_selection()
		"battle", "event", "chest", "shop", "camp":
			_enter_current_node()
		"reward":
			if GameManager.has_pending_reward():
				show_reward(GameManager.get_pending_reward())
			else:
				show_map()
		"torn_banner":
			if GameManager.pending_torn_banner_reward:
				show_torn_banner_choice()
			else:
				show_map()
		"ending":
			show_ending(true)
		_:
			if GameManager.get_pending_event_chain_id() != "":
				show_event(GameManager.get_pending_event_chain_id())
			elif GameManager.has_pending_reward():
				show_reward(GameManager.get_pending_reward())
			elif GameManager.pending_torn_banner_reward:
				show_torn_banner_choice()
			else:
				show_map()

func show_settings() -> void:
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	_add_texture_wash(current_screen, Color(0.18, 0.18, 0.18, 0.18))
	var box: VBoxContainer = _center_box(Vector2(760, 660), 8)
	box.add_child(_centered_label("设置", 34, Color(0.95, 0.90, 0.76)))
	box.add_child(_make_volume_setting("主音量", float(SettingsManager.master_volume), Callable(SettingsManager, "set_master_volume")))
	box.add_child(_make_volume_setting("音乐音量", float(SettingsManager.music_volume), Callable(SettingsManager, "set_music_volume")))
	box.add_child(_make_volume_setting("音效音量", float(SettingsManager.sfx_volume), Callable(SettingsManager, "set_sfx_volume")))

	var fullscreen_toggle: CheckButton = CheckButton.new()
	fullscreen_toggle.text = "全屏"
	fullscreen_toggle.button_pressed = bool(SettingsManager.fullscreen)
	fullscreen_toggle.add_theme_font_size_override("font_size", 17)
	fullscreen_toggle.toggled.connect(Callable(SettingsManager, "set_fullscreen"))
	box.add_child(fullscreen_toggle)

	var motion_toggle: CheckButton = CheckButton.new()
	motion_toggle.text = "减少动态效果"
	motion_toggle.button_pressed = bool(SettingsManager.reduced_motion)
	motion_toggle.add_theme_font_size_override("font_size", 17)
	motion_toggle.toggled.connect(Callable(SettingsManager, "set_reduced_motion"))
	box.add_child(motion_toggle)
	box.add_child(_make_toggle_setting("快速结算", bool(SettingsManager.quick_resolve), Callable(SettingsManager, "set_quick_resolve")))
	box.add_child(_make_speed_setting())

	var back: Button = _make_button("返回", Vector2(240, 48))
	back.pressed.connect(func() -> void:
		_play_select()
		show_main_menu()
	)
	box.add_child(back)

func codex_counts() -> Dictionary:
	return {
		"characters": GameDataScript.STARTING_ARCHETYPES.size(),
		"spectra": GameDataScript.SPECTRA.size(),
		"relics": GameDataScript.RELICS.size(),
		"events": GameDataScript.EVENTS.size(),
	}

func codex_filtered_ids(tab_name: String, school_filter: String = "all", rarity_filter: String = "all") -> Array[String]:
	var source: Dictionary = {}
	match tab_name:
		"characters":
			source = GameDataScript.STARTING_ARCHETYPES
		"spectra":
			source = GameDataScript.SPECTRA
		"relics":
			source = GameDataScript.RELICS
		"events":
			source = GameDataScript.EVENTS
		_:
			return []
	var ids: Array[String] = []
	for raw_id in source.keys():
		var entry: Dictionary = source[raw_id]
		if tab_name == "spectra" and school_filter != "all" and String(entry.get("color", "neutral")) != school_filter:
			continue
		if ["spectra", "relics"].has(tab_name) and rarity_filter != "all" and String(entry.get("rarity", "common")) != rarity_filter:
			continue
		ids.append(String(raw_id))
	ids.sort_custom(func(left: String, right: String) -> bool:
		return _codex_entry_name(tab_name, left).naturalnocasecmp_to(_codex_entry_name(tab_name, right)) < 0
	)
	return ids

func show_codex(tab_name: String = "", selected_id: String = "") -> void:
	if ["characters", "spectra", "relics", "events"].has(tab_name):
		codex_tab = tab_name
	if selected_id != "":
		codex_selected_id = selected_id
	var entry_ids: Array[String] = codex_filtered_ids(codex_tab, codex_school_filter, codex_rarity_filter)
	if not entry_ids.has(codex_selected_id):
		codex_selected_id = entry_ids[0] if not entry_ids.is_empty() else ""

	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	current_screen.name = "CodexScreen"
	_add_texture_wash(current_screen, Color(0.18, 0.18, 0.18, 0.16))

	var outer: MarginContainer = MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 30)
	outer.add_theme_constant_override("margin_right", 30)
	outer.add_theme_constant_override("margin_top", 22)
	outer.add_theme_constant_override("margin_bottom", 22)
	current_screen.add_child(outer)
	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	outer.add_child(root_box)

	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 46)
	header.add_theme_constant_override("separation", 14)
	root_box.add_child(header)
	var title: Label = _make_label("旅途图鉴", 30, GameThemeScript.TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var counts: Dictionary = codex_counts()
	header.add_child(_make_label("角色 %d  ·  色谱 %d  ·  遗物 %d  ·  事件 %d" % [counts.characters, counts.spectra, counts.relics, counts.events], 14, GameThemeScript.TEXT_SECONDARY))
	var back: Button = _make_button("返回", Vector2(104, 42), GameThemeScript.SURFACE)
	back.pressed.connect(func() -> void:
		_play_select()
		show_main_menu()
	)
	header.add_child(back)

	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.custom_minimum_size = Vector2(0, 44)
	tabs.add_theme_constant_override("separation", 8)
	root_box.add_child(tabs)
	var tab_specs: Array[Array] = [["characters", "角色 · %d" % counts.characters], ["spectra", "色谱 · %d" % counts.spectra], ["relics", "遗物 · %d" % counts.relics], ["events", "事件 · %d" % counts.events]]
	for spec in tab_specs:
		var target_tab: String = String(spec[0])
		var fill: Color = GameThemeScript.GOLD.darkened(0.42) if target_tab == codex_tab else GameThemeScript.SURFACE
		var tab_button: Button = _make_button(String(spec[1]), Vector2(0, 42), fill)
		tab_button.name = "CodexTab_%s" % target_tab
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.pressed.connect(_on_codex_tab_pressed.bind(target_tab))
		tabs.add_child(tab_button)

	root_box.add_child(_build_codex_filters(entry_ids.size()))
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root_box.add_child(body)
	body.add_child(_build_codex_list(entry_ids))
	body.add_child(_build_codex_detail(codex_tab, codex_selected_id))

func _on_codex_tab_pressed(tab_name: String) -> void:
	_play_select()
	codex_tab = tab_name
	codex_selected_id = ""
	codex_school_filter = "all"
	codex_rarity_filter = "all"
	show_codex()

func _on_codex_entry_pressed(entry_id: String) -> void:
	_play_select()
	codex_selected_id = entry_id
	show_codex()

func _build_codex_filters(result_count: int) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 42)
	row.add_theme_constant_override("separation", 10)
	row.add_child(_make_label("当前 %d 项" % result_count, 14, GameThemeScript.TEXT_MUTED))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	if codex_tab == "spectra":
		row.add_child(_make_label("学派", 14, GameThemeScript.TEXT_SECONDARY))
		var school_select: OptionButton = OptionButton.new()
		school_select.custom_minimum_size = Vector2(132, 38)
		var schools: Array[String] = ["all", "red", "blue", "gold", "gray", "neutral", "mixed", "green", "purple", "white", "black"]
		for school in schools:
			var school_label: String = "全部学派" if school == "all" else GameDataScript.color_full_name(school)
			school_select.add_item(school_label)
			school_select.set_item_metadata(school_select.item_count - 1, school)
			if school == codex_school_filter:
				school_select.select(school_select.item_count - 1)
		school_select.item_selected.connect(func(index: int) -> void:
			codex_school_filter = String(school_select.get_item_metadata(index))
			codex_selected_id = ""
			show_codex()
		)
		row.add_child(school_select)
	if ["spectra", "relics"].has(codex_tab):
		row.add_child(_make_label("稀有度", 14, GameThemeScript.TEXT_SECONDARY))
		var rarity_select: OptionButton = OptionButton.new()
		rarity_select.custom_minimum_size = Vector2(116, 38)
		var rarities: Array[String] = ["all", "common", "rare", "epic"]
		if codex_tab == "relics":
			rarities.append("boss")
		for rarity in rarities:
			rarity_select.add_item("全部" if rarity == "all" else _rarity_label(rarity))
			rarity_select.set_item_metadata(rarity_select.item_count - 1, rarity)
			if rarity == codex_rarity_filter:
				rarity_select.select(rarity_select.item_count - 1)
		rarity_select.item_selected.connect(func(index: int) -> void:
			codex_rarity_filter = String(rarity_select.get_item_metadata(index))
			codex_selected_id = ""
			show_codex()
		)
		row.add_child(rarity_select)
	return row

func _build_codex_list(entry_ids: Array[String]) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(GameThemeScript.SURFACE, GameThemeScript.BORDER))
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)
	if entry_ids.is_empty():
		list.add_child(_make_label("当前筛选没有条目。", 15, GameThemeScript.TEXT_MUTED))
	for entry_id in entry_ids:
		var selected: bool = entry_id == codex_selected_id
		var fill: Color = GameThemeScript.GOLD.darkened(0.52) if selected else GameThemeScript.SURFACE_RAISED
		var button: Button = _make_button(_codex_list_label(codex_tab, entry_id), Vector2(0, 48), fill)
		button.name = "CodexEntry_%s" % entry_id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_codex_entry_pressed.bind(entry_id))
		list.add_child(button)
	return panel

func _build_codex_detail(tab_name: String, entry_id: String) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "CodexDetail"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.067, 0.076, 0.090), GameThemeScript.BORDER))
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var detail: VBoxContainer = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 10)
	scroll.add_child(detail)
	if entry_id == "":
		detail.add_child(_make_label("选择左侧条目查看详情。", 18, GameThemeScript.TEXT_MUTED))
		return panel
	match tab_name:
		"characters":
			_add_codex_character_detail(detail, entry_id)
		"spectra":
			_add_codex_spectrum_detail(detail, entry_id)
		"relics":
			_add_codex_relic_detail(detail, entry_id)
		"events":
			_add_codex_event_detail(detail, entry_id)
	return panel

func _add_codex_character_detail(parent: VBoxContainer, character_id: String) -> void:
	var character: Dictionary = GameDataScript.starting_archetype(character_id)
	var tint: Color = GameDataScript.color_tint(String(character.get("color", "neutral")))
	var identity: HBoxContainer = HBoxContainer.new()
	identity.add_theme_constant_override("separation", 18)
	parent.add_child(identity)
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = _character_portrait(character_id)
	portrait.custom_minimum_size = Vector2(142, 142)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	identity.add_child(portrait)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(text)
	text.add_child(_make_label("%s  /  %s" % [character.get("name", character_id), character.get("title", "")], 28, GameThemeScript.TEXT_PRIMARY))
	text.add_child(_make_label(String(character.get("tagline", "")), 17, tint.lightened(0.24)))
	text.add_child(_make_label("最大 HP %d    定位 %s" % [character.get("max_hp", 0), character.get("difficulty", "")], 15, GameThemeScript.TEXT_SECONDARY))
	parent.add_child(_codex_wrapped_label("被动 · %s\n%s" % [character.get("passive_name", ""), character.get("passive_text", "")], 17, GameThemeScript.TEXT_PRIMARY, 68))
	var relic: Dictionary = GameDataScript.relic(String(character.get("relic", "")))
	parent.add_child(_codex_wrapped_label("起始遗物《%s》  %s" % [relic.get("name", "无"), relic.get("description", "")], 15, GameThemeScript.TEXT_SECONDARY, 48))
	parent.add_child(_codex_wrapped_label("起始牌组  %s" % _codex_deck_names(character.get("deck", [])), 15, GameThemeScript.TEXT_SECONDARY, 58))
	var pool_names: Array[String] = []
	for pool_id in character.get("exclusive_pools", []):
		pool_names.append(GameDataScript.color_full_name(String(pool_id)))
	parent.add_child(_codex_wrapped_label("专属奖励倾向  %s" % " · ".join(pool_names), 15, GameThemeScript.TEXT_MUTED, 36))

func _add_codex_spectrum_detail(parent: VBoxContainer, card_id: String) -> void:
	var card: Dictionary = GameDataScript.spectrum(card_id)
	var tint: Color = GameDataScript.color_tint(String(card.get("color", "neutral")))
	parent.add_child(_make_label(String(card.get("name", card_id)), 30, tint.lightened(0.22)))
	parent.add_child(_make_label("%s学派  ·  %s  ·  ID %s" % [GameDataScript.color_full_name(String(card.get("color", "neutral"))), _rarity_label(String(card.get("rarity", "common"))), card_id], 14, GameThemeScript.TEXT_MUTED))
	parent.add_child(_codex_wrapped_label("触发条件\n%s" % card.get("condition", card.get("short", "未配置")), 18, GameThemeScript.TEXT_PRIMARY, 66))
	parent.add_child(_codex_wrapped_label("效果\n%s" % card.get("effect", "未配置"), 18, GameThemeScript.TEXT_PRIMARY, 66))
	var upgrade: Dictionary = card.get("upgrade", {})
	var upgraded_condition: String = String(upgrade.get("condition", card.get("condition", card.get("short", "不变"))))
	var upgraded_effect: String = String(upgrade.get("effect", card.get("effect", "不变")))
	parent.add_child(_codex_wrapped_label("精研效果\n条件：%s\n效果：%s" % [upgraded_condition, upgraded_effect], 16, GameThemeScript.GOLD.lightened(0.18), 92))
	parent.add_child(_codex_wrapped_label("来源标签  %s" % _codex_source_tags(card.get("pools", [])), 14, GameThemeScript.TEXT_MUTED, 38))

func _add_codex_relic_detail(parent: VBoxContainer, relic_id: String) -> void:
	var relic: Dictionary = GameDataScript.relic(relic_id)
	parent.add_child(_make_label("《%s》" % relic.get("name", relic_id), 30, GameThemeScript.GOLD.lightened(0.20)))
	parent.add_child(_make_label("%s遗物  ·  ID %s" % [_rarity_label(String(relic.get("rarity", "common"))), relic_id], 14, GameThemeScript.TEXT_MUTED))
	parent.add_child(_codex_wrapped_label(String(relic.get("description", "未配置效果。")), 19, GameThemeScript.TEXT_PRIMARY, 92))

func _add_codex_event_detail(parent: VBoxContainer, event_id: String) -> void:
	var event: Dictionary = GameDataScript.event(event_id)
	parent.add_child(_make_label(String(event.get("title", event_id)), 30, GameThemeScript.TEXT_PRIMARY))
	parent.add_child(_make_label("事件 ID  %s" % event_id, 14, GameThemeScript.TEXT_MUTED))
	parent.add_child(_codex_wrapped_label(String(event.get("body", "")), 18, GameThemeScript.TEXT_SECONDARY, 78))
	parent.add_child(_make_label("可选决策", 18, GameThemeScript.GOLD))
	var choice_index: int = 1
	for choice_value in event.get("choices", []):
		var choice: Dictionary = choice_value
		parent.add_child(_codex_wrapped_label("%d. %s" % [choice_index, choice.get("label", choice.get("id", "未命名选项"))], 16, GameThemeScript.TEXT_PRIMARY, 46))
		choice_index += 1

func _codex_entry_name(tab_name: String, entry_id: String) -> String:
	match tab_name:
		"characters":
			return String(GameDataScript.STARTING_ARCHETYPES.get(entry_id, {}).get("name", entry_id))
		"spectra":
			return String(GameDataScript.SPECTRA.get(entry_id, {}).get("name", entry_id))
		"relics":
			return String(GameDataScript.RELICS.get(entry_id, {}).get("name", entry_id))
		"events":
			return String(GameDataScript.EVENTS.get(entry_id, {}).get("title", entry_id))
	return entry_id

func _codex_list_label(tab_name: String, entry_id: String) -> String:
	var name: String = _codex_entry_name(tab_name, entry_id)
	if tab_name == "characters":
		var character: Dictionary = GameDataScript.STARTING_ARCHETYPES[entry_id]
		return "%s  ·  %s" % [name, character.get("difficulty", "")]
	if tab_name == "spectra":
		var card: Dictionary = GameDataScript.SPECTRA[entry_id]
		return "%s  ·  %s / %s" % [name, GameDataScript.color_full_name(String(card.get("color", "neutral"))), _rarity_label(String(card.get("rarity", "common")))]
	if tab_name == "relics":
		return "%s  ·  %s" % [name, _rarity_label(String(GameDataScript.RELICS[entry_id].get("rarity", "common")))]
	return name

func _codex_deck_names(deck: Array) -> String:
	var names: Array[String] = []
	for card_id in deck:
		names.append(String(GameDataScript.spectrum(String(card_id)).get("name", card_id)))
	return " / ".join(names)

func _codex_source_tags(pools: Array) -> String:
	var labels: Array[String] = []
	var translations: Dictionary = {"starter": "起始", "common": "普通池", "rare": "稀有池", "epic": "史诗池", "elite": "精英奖励", "event": "事件", "curse": "诅咒"}
	for pool in pools:
		var pool_id: String = String(pool)
		labels.append(String(translations.get(pool_id, GameDataScript.color_full_name(pool_id))))
	return " · ".join(labels)

func _codex_wrapped_label(text: String, size: int, color: Color, minimum_height: float) -> Label:
	var label: Label = _make_label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0, minimum_height)
	return label

func _rarity_label(rarity: String) -> String:
	return String({"common": "普通", "rare": "稀有", "epic": "史诗", "boss": "首领"}.get(rarity, rarity))

func _make_volume_setting(label_text: String, value: float, setter: Callable) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(620, 48)
	row.add_theme_constant_override("separation", 14)
	var label: Label = _make_label(label_text, 17, Color(0.84, 0.82, 0.74))
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = round(value * 100.0)
	slider.custom_minimum_size = Vector2(380, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var percent: Label = _make_label("%d%%" % int(slider.value), 16, Color(0.94, 0.88, 0.68))
	percent.custom_minimum_size = Vector2(64, 0)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(percent)
	slider.value_changed.connect(func(new_value: float) -> void:
		percent.text = "%d%%" % int(new_value)
		setter.call(new_value / 100.0)
	)
	return row

func _make_toggle_setting(label_text: String, value: bool, setter: Callable) -> CheckButton:
	var toggle: CheckButton = CheckButton.new()
	toggle.text = label_text
	toggle.button_pressed = value
	toggle.add_theme_font_size_override("font_size", 17)
	toggle.toggled.connect(setter)
	return toggle

func _make_speed_setting() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(720, 40)
	row.add_theme_constant_override("separation", 12)
	var label: Label = _make_label("战斗速度", 17, GameThemeScript.TEXT_PRIMARY)
	label.custom_minimum_size = Vector2(150, 36)
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.5
	slider.max_value = 2.0
	slider.step = 0.25
	slider.value = float(SettingsManager.combat_speed)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label: Label = _make_label("%.2fx" % slider.value, 15, GameThemeScript.TEXT_SECONDARY)
	value_label.custom_minimum_size = Vector2(64, 36)
	row.add_child(value_label)
	slider.value_changed.connect(func(new_value: float) -> void:
		value_label.text = "%.2fx" % new_value
		SettingsManager.set_combat_speed(new_value)
	)
	return row

func show_start_node() -> void:
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	_add_texture_wash(current_screen, Color(0.18, 0.16, 0.14, 0.20))
	if not GameDataScript.STARTING_ARCHETYPES.has(selected_character_preview_id):
		selected_character_preview_id = "red"
	var box: VBoxContainer = _center_box(Vector2(1120, 660), 8)
	box.add_child(_centered_label("选择角色", 32, Color(0.96, 0.91, 0.74)))
	box.add_child(_centered_label("五种战斗逻辑，共用同一套四色棋盘。", 16, Color(0.80, 0.78, 0.72)))
	_add_ascension_selector(box)
	var body: HBoxContainer = HBoxContainer.new()
	body.custom_minimum_size = Vector2(1080, 390)
	body.add_theme_constant_override("separation", 14)
	box.add_child(body)
	var character_list: VBoxContainer = VBoxContainer.new()
	character_list.custom_minimum_size = Vector2(246, 0)
	character_list.add_theme_constant_override("separation", 7)
	body.add_child(character_list)
	for character_id in ["red", "blue", "gold", "gray", "mixed"]:
		_add_start_choice(character_list, character_id)
	body.add_child(_build_character_preview(selected_character_preview_id))
	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(footer)
	var back: Button = _make_button("返回主菜单", Vector2(180, 38), GameThemeScript.SURFACE)
	back.pressed.connect(func() -> void:
		_play_select()
		show_main_menu()
	)
	footer.add_child(back)

func _add_ascension_selector(parent: Control) -> void:
	var selected_level: int = int(GameManager.ascension_level)
	parent.add_child(_centered_label("进阶 %d · %s" % [selected_level, _ascension_description(selected_level)], 16, GameThemeScript.TEXT_SECONDARY))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 5)
	parent.add_child(grid)
	for level in range(AscensionRulesScript.MAX_LEVEL + 1):
		var target_level: int = level
		var fill: Color = GameThemeScript.GOLD.darkened(0.34) if target_level == selected_level else GameThemeScript.SURFACE
		var button: Button = _make_button("A%d" % target_level, Vector2(104, 34), fill)
		button.tooltip_text = _ascension_description(target_level)
		button.pressed.connect(func() -> void:
			_play_select()
			GameManager.set_ascension_level(target_level)
			show_start_node()
		)
		grid.add_child(button)

func _ascension_description(level: int) -> String:
	return AscensionRulesScript.get_level_description(level)

func _add_start_choice(parent: Control, choice: String) -> void:
	var character: Dictionary = GameDataScript.starting_archetype(choice)
	var selected: bool = choice == selected_character_preview_id
	var tint: Color = GameDataScript.color_tint(String(character.get("color", choice)))
	var fill: Color = tint.darkened(0.20 if selected else 0.56)
	var button: Button = _make_button("%s  ·  %s\n定位 · %s    被动 · %s" % [
		character.get("name", choice),
		character.get("title", "调色勇者"),
		character.get("difficulty", "标准"),
		character.get("passive_name", "未命名"),
	], Vector2(246, 70), fill)
	var active_skill: Dictionary = character.get("active_skill", {})
	button.tooltip_text = "被动：%s\n主动技：%s" % [character.get("passive_text", ""), active_skill.get("text", "")]
	button.pressed.connect(func() -> void:
		_play_select()
		selected_character_preview_id = choice
		show_start_node()
	)
	parent.add_child(button)

func _build_character_preview(character_id: String) -> Control:
	var character: Dictionary = GameDataScript.starting_archetype(character_id)
	var active_skill: Dictionary = character.get("active_skill", {})
	var tint: Color = GameDataScript.color_tint(String(character.get("color", "neutral")))
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 390)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", GameThemeScript.panel_style(GameThemeScript.SURFACE, tint.darkened(0.15), 2, 5, 16))
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var detail: VBoxContainer = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 9)
	margin.add_child(detail)
	var identity: HBoxContainer = HBoxContainer.new()
	identity.add_theme_constant_override("separation", 16)
	detail.add_child(identity)
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = _character_portrait(character_id)
	portrait.custom_minimum_size = Vector2(128, 128)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.modulate = tint.lightened(0.18)
	identity.add_child(portrait)
	var identity_text: VBoxContainer = VBoxContainer.new()
	identity_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_text.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_child(identity_text)
	identity_text.add_child(_make_label("%s  /  %s" % [character.get("name", character_id), character.get("title", "")], 28, GameThemeScript.TEXT_PRIMARY))
	identity_text.add_child(_make_label(String(character.get("tagline", "")), 17, tint.lightened(0.28)))
	identity_text.add_child(_make_label("定位 · %s    最大 HP %d" % [
		character.get("difficulty", "标准"),
		int(character.get("max_hp", 120)),
	], 15, GameThemeScript.TEXT_SECONDARY))
	detail.add_child(_make_label("被动 · %s" % character.get("passive_name", ""), 18, tint.lightened(0.24)))
	var passive_text: Label = _make_label(String(character.get("passive_text", "")), 16, GameThemeScript.TEXT_PRIMARY)
	passive_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passive_text.custom_minimum_size = Vector2(0, 34)
	detail.add_child(passive_text)
	var active_heading: Label = _make_label("主动技 · %s    %d 充能" % [active_skill.get("name", "未命名"), int(active_skill.get("cost", 0))], 18, GameThemeScript.GOLD)
	detail.add_child(active_heading)
	var active_text: Label = _make_label(String(active_skill.get("text", "")), 15, GameThemeScript.TEXT_PRIMARY)
	active_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_text.custom_minimum_size = Vector2(0, 34)
	detail.add_child(active_text)
	var deck_names: Array[String] = []
	for card_id in character.get("deck", []):
		deck_names.append(String(GameDataScript.spectrum(String(card_id)).get("name", card_id)))
	var core_deck_names: Array[String] = []
	for index in range(mini(4, deck_names.size())):
		core_deck_names.append(deck_names[index])
	var deck_label: Label = _make_label("初始构筑差异 · 核心 %s" % " / ".join(core_deck_names), 14, GameThemeScript.TEXT_SECONDARY)
	deck_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	deck_label.custom_minimum_size = Vector2(0, 34)
	detail.add_child(deck_label)
	var pool_names: Array[String] = []
	for pool_id in character.get("exclusive_pools", []):
		pool_names.append(GameDataScript.color_full_name(String(pool_id)))
	var starting_relic: Dictionary = GameDataScript.relic(String(character.get("relic", "")))
	detail.add_child(_make_label("起始遗物《%s》    奖励倾向 · %s    牌组 %d 张" % [
		starting_relic.get("name", "无"), " · ".join(pool_names), deck_names.size(),
	], 14, GameThemeScript.TEXT_MUTED))
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(spacer)
	var confirm: Button = _make_button("以 %s 开始旅程" % character.get("name", character_id), Vector2(0, 48), tint.darkened(0.28))
	confirm.pressed.connect(func() -> void:
		_play_enter()
		_on_toast(GameManager.apply_start_choice(character_id), Callable(self, "show_vow_selection"))
	)
	detail.add_child(confirm)
	return panel

func show_vow_selection() -> void:
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	_add_texture_wash(current_screen, Color(0.20, 0.18, 0.24, 0.24))
	var box: VBoxContainer = _center_box(Vector2(1100, 620), 16)
	box.add_child(_centered_label("为这次远征立誓", 34, GameThemeScript.TEXT_PRIMARY))
	box.add_child(_centered_label("誓约会同时改变三章地图池、战斗收益与终局证词。确认后本局不可更换。", 16, GameThemeScript.TEXT_SECONDARY))
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(1080, 390)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for vow_id_value in NarrativeMemoryScript.VOWS.keys():
		var vow_id: String = String(vow_id_value)
		var vow_data: Dictionary = NarrativeMemoryScript.vow(vow_id)
		var tint: Color = GameDataScript.color_tint(String(vow_data.get("color", "gray")))
		var panel: PanelContainer = PanelContainer.new()
		panel.custom_minimum_size = Vector2(340, 360)
		panel.add_theme_stylebox_override("panel", GameThemeScript.panel_style(GameThemeScript.SURFACE, tint.darkened(0.10), 2, 5, 18))
		row.add_child(panel)
		var vow_box: VBoxContainer = VBoxContainer.new()
		vow_box.add_theme_constant_override("separation", 12)
		panel.add_child(vow_box)
		var marker: ColorRect = ColorRect.new()
		marker.color = tint
		marker.custom_minimum_size = Vector2(0, 6)
		vow_box.add_child(marker)
		vow_box.add_child(_centered_label(String(vow_data.get("name", vow_id)), 25, tint.lightened(0.22)))
		vow_box.add_child(_centered_label(String(vow_data.get("subtitle", "")), 15, GameThemeScript.GOLD))
		var vow_body: Label = _make_label(String(vow_data.get("description", "")), 16, GameThemeScript.TEXT_PRIMARY)
		vow_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vow_body.custom_minimum_size = Vector2(0, 132)
		vow_box.add_child(vow_body)
		vow_box.add_child(_make_label("地图轮换：%s" % String({"standard": "均衡", "risk": "高风险", "economy": "事件"}.get(vow_data.get("template_id", "standard"), "均衡")), 14, GameThemeScript.TEXT_MUTED))
		var choose: Button = _make_button("立下此誓", Vector2(0, 48), tint.darkened(0.28))
		choose.pressed.connect(func() -> void:
			_play_enter()
			if GameManager.apply_vow(vow_id):
				show_policy_selection()
			else:
				_on_toast("誓约已锁定，无法重复选择。", Callable(self, "show_map"))
		)
		vow_box.add_child(choose)
	var back: Button = _make_button("返回角色选择", Vector2(220, 42), GameThemeScript.SURFACE)
	back.pressed.connect(func() -> void:
		_play_select()
		show_start_node()
	)
	box.add_child(back)

func show_policy_selection() -> void:
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	_add_texture_wash(current_screen, Color(0.18, 0.20, 0.18, 0.22))
	var box: VBoxContainer = _center_box(Vector2(1120, 620), 14)
	box.add_child(_centered_label("章节政策 · 第一项国家工程", 34, GameThemeScript.TEXT_PRIMARY))
	box.add_child(_centered_label("这是本局的长期路线：只选一项，之后会影响棋盘、战斗收益或压力上限。", 16, GameThemeScript.TEXT_SECONDARY))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	for policy_value in GameManager.get_policy_options():
		var policy: Dictionary = policy_value
		var policy_id := String(policy.get("id", ""))
		var tint := GameDataScript.color_tint(String(policy.get("color", "gray")))
		var button := _make_button("%s\n%s" % [policy.get("name", policy_id), policy.get("summary", "")], Vector2(500, 120), tint.darkened(0.30))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(func() -> void:
			_play_enter()
			if GameManager.apply_policy(policy_id):
				_show_route_pool_selection_or_map()
			else:
				_on_toast("政策已锁定，无法重复选择。", Callable(self, "show_map"))
		)
		grid.add_child(button)

func _show_route_pool_selection_or_map() -> void:
	if not GameManager.is_archive_map_pool_unlocked():
		show_map()
		return
	show_route_pool_selection()

func show_route_pool_selection() -> void:
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	_add_texture_wash(current_screen, Color(0.16, 0.18, 0.20, 0.22))
	route_pool_choice_committed = false
	var vow_data: Dictionary = GameManager.get_selected_vow()
	var default_pool_id: String = String(vow_data.get("template_id", "standard"))
	var default_pool_name: String = GameManager.get_map_template_label("C1").get_slice(" · ", 0)
	var box: VBoxContainer = _center_box(Vector2(900, 430), 14)
	box.add_child(_centered_label("路线抉择", 34, GameThemeScript.TEXT_PRIMARY))
	box.add_child(_centered_label("完整的非初始记忆组已开启一条被删去的路线。", 16, GameThemeScript.TEXT_SECONDARY))
	var choices: HBoxContainer = HBoxContainer.new()
	choices.custom_minimum_size = Vector2(860, 245)
	choices.add_theme_constant_override("separation", 16)
	box.add_child(choices)
	_add_route_pool_choice(choices, "沿当前誓约", "%s\n遵循誓约的三章路线池。" % default_pool_name, default_pool_id, GameThemeScript.BLUE)
	_add_route_pool_choice(choices, "进入失色档案馆", "三章均改为档案路线池。\n节点会留下更多互相矛盾的证词。", "archive", GameThemeScript.GOLD)
	var continue_default: Button = _make_button("返回并沿当前誓约", Vector2(260, 42), GameThemeScript.SURFACE)
	continue_default.pressed.connect(func() -> void:
		_play_select()
		_commit_route_pool_choice(default_pool_id)
	)
	box.add_child(continue_default)

func _add_route_pool_choice(parent: HBoxContainer, title: String, body: String, template_id: String, tint: Color) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(422, 238)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", GameThemeScript.panel_style(GameThemeScript.SURFACE, tint.darkened(0.08), 2, 5, 16))
	parent.add_child(panel)
	var choice_box: VBoxContainer = VBoxContainer.new()
	choice_box.add_theme_constant_override("separation", 10)
	panel.add_child(choice_box)
	var accent: ColorRect = ColorRect.new()
	accent.color = tint
	accent.custom_minimum_size = Vector2(0, 5)
	choice_box.add_child(accent)
	choice_box.add_child(_centered_label(title, 23, tint.lightened(0.18)))
	var description: Label = _make_label(body, 15, GameThemeScript.TEXT_SECONDARY)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(0, 80)
	choice_box.add_child(description)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choice_box.add_child(spacer)
	var select: Button = _make_button("选择此路线", Vector2(0, 44), tint.darkened(0.30))
	select.pressed.connect(func() -> void:
		_play_enter()
		_commit_route_pool_choice(template_id)
	)
	choice_box.add_child(select)

func _commit_route_pool_choice(template_id: String) -> void:
	if route_pool_choice_committed:
		return
	route_pool_choice_committed = true
	var previous_templates: Dictionary = GameManager.map_template_ids.duplicate(true)
	if not GameManager.select_map_template_pool(template_id):
		GameManager.map_template_ids.clear()
		GameManager.map_template_ids.merge(previous_templates, true)
		route_pool_choice_committed = false
		_on_toast("该路线池当前不可用，原路线已保留。", Callable(self, "show_route_pool_selection"))
		return
	if not SaveManager.save_run():
		GameManager.map_template_ids.clear()
		GameManager.map_template_ids.merge(previous_templates, true)
		route_pool_choice_committed = false
		_on_toast(SaveManager.last_error, Callable(self, "show_route_pool_selection"))
		return
	show_map()

func show_memory_archive(return_to_map: bool = false) -> void:
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	_add_texture_wash(current_screen, Color(0.16, 0.18, 0.20, 0.20))
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	current_screen.add_child(margin)
	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	margin.add_child(root_box)
	var header: HBoxContainer = HBoxContainer.new()
	root_box.add_child(header)
	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	title_box.add_child(_make_label("断色回廊 · 记忆档案", 32, GameThemeScript.TEXT_PRIMARY))
	title_box.add_child(_make_label("已发现 %d / %d  ·  记忆墨 %d  ·  回想槽 %d / %d" % [GameManager.unlocked_memory_ids.size(), NarrativeMemoryScript.FRAGMENTS.size(), GameManager.memory_insight, GameManager.equipped_memory_ids.size(), NarrativeMemoryScript.MAX_EQUIPPED], 14, GameThemeScript.TEXT_SECONDARY))
	var back: Button = _make_button("返回地图" if return_to_map else "返回主菜单", Vector2(150, 42), GameThemeScript.SURFACE)
	back.pressed.connect(func() -> void:
		_play_select()
		if return_to_map:
			show_map()
		else:
			show_main_menu()
	)
	header.add_child(back)
	var set_labels: Array[String] = []
	var progress: Dictionary = NarrativeMemoryScript.set_progress(GameManager.unlocked_memory_ids)
	for set_id_value in NarrativeMemoryScript.MEMORY_SETS.keys():
		var set_id: String = String(set_id_value)
		var set_data: Dictionary = NarrativeMemoryScript.MEMORY_SETS[set_id]
		var set_progress: Dictionary = progress.get(set_id, {})
		set_labels.append("%s %d/%d" % [set_data.get("name", set_id), int(set_progress.get("count", 0)), int(set_progress.get("total", 0))])
	var memory_set_grid: GridContainer = GridContainer.new()
	memory_set_grid.name = "MemorySetSummaryGrid"
	memory_set_grid.columns = 3
	memory_set_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	memory_set_grid.add_theme_constant_override("h_separation", 10)
	memory_set_grid.add_theme_constant_override("v_separation", 3)
	for set_label in set_labels:
		var summary: Label = _make_label(set_label, 13, GameThemeScript.GOLD)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.custom_minimum_size = Vector2(260, 28)
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		memory_set_grid.add_child(summary)
	root_box.add_child(memory_set_grid)
	var scroller: ScrollContainer = ScrollContainer.new()
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(scroller)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroller.add_child(grid)
	var memory_ids: Array[String] = []
	for memory_id_value in NarrativeMemoryScript.FRAGMENTS.keys():
		memory_ids.append(String(memory_id_value))
	memory_ids.sort()
	for memory_id in memory_ids:
		var unlocked: bool = GameManager.unlocked_memory_ids.has(memory_id)
		var memory_data: Dictionary = NarrativeMemoryScript.fragment(memory_id)
		var equipped: bool = GameManager.equipped_memory_ids.has(memory_id)
		var panel: PanelContainer = PanelContainer.new()
		panel.custom_minimum_size = Vector2(600, 134)
		var border: Color = GameThemeScript.GOLD if equipped else GameThemeScript.BORDER
		panel.add_theme_stylebox_override("panel", GameThemeScript.panel_style(GameThemeScript.SURFACE, border, 1 if not equipped else 2, 4, 12))
		grid.add_child(panel)
		var item: VBoxContainer = VBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		panel.add_child(item)
		if not unlocked:
			item.add_child(_make_label("%s  /  未解码档案" % memory_id, 17, GameThemeScript.TEXT_MUTED))
			item.add_child(_make_label("继续远征、挑战精英或追随见证之誓以发现这段证词。", 14, GameThemeScript.TEXT_MUTED))
			continue
		var item_header: HBoxContainer = HBoxContainer.new()
		item.add_child(item_header)
		var name_label: Label = _make_label("%s  /  %s" % [memory_id, memory_data.get("title", "")], 18, GameThemeScript.TEXT_PRIMARY)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_header.add_child(name_label)
		var equip: Button = _make_button("卸下" if equipped else "回想", Vector2(76, 32), GameThemeScript.GOLD.darkened(0.38) if equipped else GameThemeScript.SURFACE_RAISED)
		equip.disabled = GameManager.selected_character_id == ""
		equip.tooltip_text = "每局最多回想三枚碎片"
		equip.pressed.connect(func() -> void:
			_play_select()
			GameManager.toggle_equipped_memory(memory_id)
			show_memory_archive(return_to_map)
		)
		item_header.add_child(equip)
		item.add_child(_make_label("记录者：%s" % String(memory_data.get("speaker", "未知")), 13, GameThemeScript.GOLD))
		var body: Label = _make_label(String(memory_data.get("body", "")), 14, GameThemeScript.TEXT_SECONDARY)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(0, 42)
		item.add_child(body)
		item.add_child(_make_label("回想效果：%s" % _memory_effect_text(memory_data), 13, GameThemeScript.TEXT_MUTED))

func _memory_effect_text(memory_data: Dictionary) -> String:
	var value: Variant = memory_data.get("value", 0)
	match String(memory_data.get("effect", "")):
		"first_turn_shield": return "战斗开局护盾 +%d" % int(value)
		"resonance_base_damage": return "共鸣固定伤害 +%d" % int(value)
		"shot_crit", "spectrum_amp": return "谱式冲击 +%d%%" % int(round(float(value) * 100.0))
		"reward_gold": return "战斗奖励金币 +%d" % int(value)
		"gray_resist": return "每次灰蚀压力增加量 -%d" % int(value)
		"post_battle_heal": return "战斗后回复 %d HP" % int(value)
		"shot_base_damage", "spectrum_base_damage": return "谱式基础伤害 +%d" % int(value)
		"skill_charge_start": return "战斗开局充能 +%d" % int(value)
		"shot_pierce", "spectrum_break": return "谱式破障 +%d" % int(value)
		_: return "保留证词"

func show_map() -> void:
	_clear_screen()
	_switch_music(_music_for_chapter(_map_chapter_key()))
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	_add_texture_wash(current_screen, Color(0.24, 0.24, 0.25, 0.20))
	var map_chapter_key: String = _map_chapter_key()

	var title: Label = _make_label(_chapter_title(map_chapter_key), 34, GameThemeScript.TEXT_PRIMARY)
	title.position = Vector2(44, 26)
	current_screen.add_child(title)
	var template_label: Label = _make_label("地图池 · %s" % GameManager.get_map_template_label(map_chapter_key), 14, GameThemeScript.GOLD)
	template_label.position = Vector2(48, 66)
	current_screen.add_child(template_label)
	var view_status: Label = _make_label("纵向路线 · 自下而上    滚轮缩放 · 100%    拖拽状态 · 居中", 14, GameThemeScript.TEXT_SECONDARY)
	view_status.position = Vector2(430, 66)
	current_screen.add_child(view_status)

	var status: Label = _make_label("HP %d/%d    护盾 %d    金币 %d    颜料 %d    牌组 %d    遗物 %d    调律 %d" % [
		GameManager.player_hp,
		GameManager.player_max_hp,
		GameManager.shield,
		GameManager.coins,
		GameManager.pigment,
		GameManager.deck.size(),
		GameManager.relics.size(),
		GameManager.get_total_peg_upgrades(),
	], 17, Color(0.78, 0.78, 0.72))
	status.position = Vector2(48, 88)
	current_screen.add_child(status)
	var vow_data: Dictionary = GameManager.get_selected_vow()
	var narrative_status: Label = _make_label("当前誓约 · 《%s》    回想 %d/%d    档案 %d/%d    灰蚀压力 %d" % [
		vow_data.get("name", "未立誓"), GameManager.equipped_memory_ids.size(), NarrativeMemoryScript.MAX_EQUIPPED,
		GameManager.unlocked_memory_ids.size(), NarrativeMemoryScript.FRAGMENTS.size(), GameManager.gray_pressure,
	], 14, GameThemeScript.GOLD)
	narrative_status.position = Vector2(48, 112)
	current_screen.add_child(narrative_status)
	var policy_data: Dictionary = GameManager.get_selected_policy()
	var policy_status: Label = _make_label("章节政策 · %s    %s" % [policy_data.get("name", "未制定"), policy_data.get("summary", "尚未选择")], 14, GameThemeScript.GREEN)
	policy_status.position = Vector2(48, 136)
	current_screen.add_child(policy_status)
	var archive_button: Button = _make_button("记忆档案", Vector2(116, 36), GameThemeScript.SURFACE_RAISED)
	archive_button.position = Vector2(900, 48)
	archive_button.pressed.connect(func() -> void:
		_play_select()
		show_memory_archive(true)
	)
	current_screen.add_child(archive_button)
	var council_button: Button = _make_button("复兴议会", Vector2(116, 36), GameThemeScript.SURFACE_RAISED)
	council_button.position = Vector2(1022, 48)
	council_button.pressed.connect(func() -> void:
		_play_select()
		show_strategy_council()
	)
	current_screen.add_child(council_button)

	var map_area: MapCanvas = MapCanvasScript.new()
	map_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_area.offset_left = 28
	map_area.offset_top = 148
	map_area.offset_right = -28
	map_area.offset_bottom = -54
	current_screen.add_child(map_area)
	var map_content_size: Vector2 = Vector2(
		max(get_viewport_rect().size.x - 72.0, 980.0),
		max(get_viewport_rect().size.y - 190.0, MAP_CONTENT_MIN_HEIGHT)
	)
	map_area.set_content_size(map_content_size)
	var map_content: Control = map_area.get_content()
	var map_backdrop := TextureRect.new()
	map_backdrop.texture = ARCHIVE_BACKDROP
	map_backdrop.modulate = Color(0.72, 0.76, 0.82, 0.34)
	map_backdrop.position = Vector2.ZERO
	map_backdrop.size = map_content_size
	map_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	map_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_content.add_child(map_backdrop)

	var positions: Dictionary = _map_positions(map_chapter_key, map_content_size)
	var available: Array[String] = _legal_map_targets()
	for node_id in positions.keys():
		var node: Dictionary = GameManager.get_node_data(String(node_id))
		for edge_value in node.get("edges", []):
			var target_id: String = String(edge_value)
			if positions.has(node_id) and positions.has(target_id):
				var line_color := Color(0.30, 0.32, 0.34, 0.34)
				var line_width: float = 1.5
				if String(node_id) == String(GameManager.current_node_id) and available.has(target_id):
					line_color = GameThemeScript.BLUE
					line_color.a = 0.88
					line_width = 2.5
				elif GameManager.visited_nodes.has(node_id) and GameManager.visited_nodes.has(target_id):
					line_color = GameThemeScript.GOLD
					line_color.a = 0.68
					line_width = 2.2
				var line := Line2D.new()
				line.width = line_width
				line.default_color = line_color
				line.antialiased = false
				line.points = PackedVector2Array([
					positions[node_id] + Vector2(MAP_NODE_SIZE.x * 0.5, 0.0),
					positions[target_id] + Vector2(MAP_NODE_SIZE.x * 0.5, MAP_NODE_SIZE.y),
				])
				map_content.add_child(line)

	for node_id in positions.keys():
		var node: Dictionary = GameManager.get_node_data(String(node_id))
		var button: Button = _make_button("%s\n%s" % [node.get("name", node_id), GameDataScript.type_label(String(node.get("type", "")))], MAP_NODE_SIZE, _node_color(String(node.get("type", ""))))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 13)
		button.position = positions[node_id]
		button.disabled = not available.has(node_id) or GameManager.visited_nodes.has(node_id)
		if GameManager.visited_nodes.has(node_id):
			button.text = "%s\n已完成" % node.get("name", node_id)
		button.tooltip_text = String(node.get("description", ""))
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.mouse_force_pass_scroll_events = true
		var target_id: String = String(node_id)
		button.pressed.connect(func() -> void:
			_play_enter()
			if not _legal_map_targets().has(target_id) or not GameManager.choose_node(target_id):
				_on_toast("该节点不在当前可用路线中。", Callable(self, "show_map"))
				return
			_enter_current_node()
		)
		map_content.add_child(button)

	var zoom_controls: HBoxContainer = HBoxContainer.new()
	zoom_controls.anchor_left = 1.0
	zoom_controls.anchor_right = 1.0
	zoom_controls.offset_left = -246.0
	zoom_controls.offset_top = 86.0
	zoom_controls.offset_right = -38.0
	zoom_controls.offset_bottom = 126.0
	zoom_controls.alignment = BoxContainer.ALIGNMENT_END
	zoom_controls.add_theme_constant_override("separation", 6)
	current_screen.add_child(zoom_controls)
	var zoom_out_button: Button = _make_button("−", Vector2(40, 36), GameThemeScript.SURFACE)
	zoom_out_button.tooltip_text = "缩小地图"
	zoom_out_button.pressed.connect(map_area.zoom_out)
	zoom_controls.add_child(zoom_out_button)
	var zoom_label: Label = _make_label("100%", 14, GameThemeScript.TEXT_SECONDARY)
	zoom_label.custom_minimum_size = Vector2(54, 36)
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zoom_controls.add_child(zoom_label)
	var zoom_in_button: Button = _make_button("+", Vector2(40, 36), GameThemeScript.SURFACE)
	zoom_in_button.tooltip_text = "放大地图"
	zoom_in_button.pressed.connect(map_area.zoom_in)
	zoom_controls.add_child(zoom_in_button)
	var reset_button: Button = _make_button("↺", Vector2(40, 36), GameThemeScript.SURFACE)
	reset_button.tooltip_text = "复位地图"
	reset_button.pressed.connect(map_area.reset_view)
	zoom_controls.add_child(reset_button)
	map_area.view_changed.connect(func(zoom: float, pan: Vector2) -> void:
		zoom_label.text = "%d%%" % int(round(zoom * 100.0))
		view_status.text = "纵向路线 · 自下而上    滚轮缩放 · %d%%    拖拽状态 · %s" % [
			int(round(zoom * 100.0)), "居中" if pan.is_equal_approx(Vector2.ZERO) else "已偏移",
		]
		GameManager.set_map_view_state(map_chapter_key, zoom, pan, String(GameManager.current_node_id))
		map_view_dirty = true
		if map_view_save_timer != null:
			map_view_save_timer.start()
	)
	var saved_view: Dictionary = GameManager.get_map_view_state(map_chapter_key)
	if not saved_view.is_empty():
		var saved_pan_value: Variant = saved_view.get("pan", Vector2.ZERO)
		var saved_pan: Vector2 = saved_pan_value if saved_pan_value is Vector2 else Vector2.ZERO
		map_area.set_view_state(float(saved_view.get("zoom", 1.0)), saved_pan)
	var should_focus_progress: bool = saved_view.is_empty() or String(saved_view.get("node_id", "")) != String(GameManager.current_node_id)
	if should_focus_progress:
		var focus_node_id: String = _map_focus_target(positions, available)
		if positions.has(focus_node_id):
			var focus_point: Vector2 = positions[focus_node_id] + MAP_NODE_SIZE * 0.5
			map_area.call_deferred("focus_content_point", focus_point)

	var hint: Label = _make_label("可选节点 %d  ·  已完成 %d  ·  灰蚀压力 %d" % [available.size(), GameManager.visited_nodes.size(), GameManager.gray_pressure], 15, GameThemeScript.TEXT_SECONDARY)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 48.0
	hint.offset_top = -42.0
	hint.offset_bottom = -18.0
	current_screen.add_child(hint)

func _enter_current_node() -> void:
	var node: Dictionary = GameManager.get_current_node()
	match String(node.get("type", "")):
		"combat", "elite", "challenge", "boss":
			show_battle()
		"event":
			show_event(GameManager.get_current_event_id())
		"chest":
			if GameManager.get_chest_choices().is_empty():
				var reward: Dictionary = GameManager.apply_chest_reward()
				_on_toast("%s\n%s" % [reward.get("title", ""), reward.get("body", "")], Callable(self, "show_map"))
			else:
				show_chest_choice()
		"shop":
			show_shop()
		"camp":
			show_camp()
		_:
			GameManager.complete_current_node()
			show_map()

func show_strategy_council() -> void:
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	var council: StrategyCouncil = StrategyCouncilScript.new()
	council.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current_screen.add_child(council)
	council.build(GameManager)
	council.policy_selected.connect(func(policy_id: String) -> void:
		if GameManager.apply_policy(policy_id):
			show_strategy_council()
		else:
			_on_toast("当前无法制定这项政策。", Callable(self, "show_strategy_council"))
	)
	council.project_selected.connect(func(project_id: String) -> void:
		if GameManager.start_project(project_id):
			show_strategy_council()
		else:
			_on_toast("资源不足或本章已有项目。", Callable(self, "show_strategy_council"))
	)
	council.back_requested.connect(show_map)

func show_battle() -> void:
	_clear_screen()
	_switch_music(_music_for_current_chapter())
	recent_logs.clear()
	last_state.clear()
	turn_exchange_count = 0
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	battle_bg = current_screen.get_node("Background") as ColorRect

	var layout: VBoxContainer = VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 16
	layout.offset_top = 10
	layout.offset_right = -16
	layout.offset_bottom = -10
	layout.add_theme_constant_override("separation", 8)
	current_screen.add_child(layout)

	layout.add_child(_build_battle_top())
	layout.add_child(_build_battle_middle())
	layout.add_child(_build_battle_bottom())

	board.move_resolved.connect(_on_board_move_resolved)
	board.invalid_swap.connect(func() -> void:
		_play_select()
		_on_log_added("只有形成三连的交换才会消耗步数。")
	)

	battle_manager = BattleManagerScript.new()
	current_screen.add_child(battle_manager)
	battle_manager.state_changed.connect(_on_battle_state_changed)
	battle_manager.checkpoint_ready.connect(_on_battle_checkpoint)
	battle_manager.damage_event.connect(_on_damage_event)
	battle_manager.player_hit.connect(_on_player_hit)
	battle_manager.battle_won.connect(_on_battle_won)
	battle_manager.battle_lost.connect(_on_battle_lost)
	battle_manager.log_added.connect(_on_log_added)
	battle_manager.input_lock_changed.connect(Callable(board, "set_locked"))
	battle_manager.spectrum_triggered.connect(_on_spectrum_triggered)
	battle_manager.spectrum_resolved.connect(_on_spectrum_resolved)
	battle_manager.combat_feedback_emitted.connect(_on_combat_feedback)
	battle_manager.board_pollution_requested.connect(func(amount: int) -> void:
		board.pollute_random_cells(amount)
	)
	battle_manager.board_cleanse_requested.connect(func(amount: int) -> void:
		board.cleanse_gray_cells(amount)
	)
	battle_manager.board_dye_requested.connect(func(color_key: String, amount: int) -> void:
		board.dye_gray_cells(color_key, amount)
	)
	var encounter: Dictionary = GameManager.get_current_encounter()
	var restored_battle: bool = false
	if GameManager.has_battle_snapshot():
		var saved_battle: Dictionary = GameManager.get_battle_snapshot()
		var board_snapshot: Variant = saved_battle.get("board", {})
		if board.restore_snapshot(board_snapshot):
			restored_battle = battle_manager.restore_battle(encounter, saved_battle)
	if not restored_battle:
		GameManager.clear_battle_snapshot()
		board.setup(GameManager.get_board_weights())
		battle_manager.start_battle(encounter)
	_show_onboarding_hint("first_battle", "初奏 · 断色回廊")

func _build_combat_feedback() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "CombatFeedback"
	row.custom_minimum_size = Vector2(0, 36)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	feedback_title = _make_label("你的回合", 17, GameThemeScript.GOLD)
	feedback_title.custom_minimum_size = Vector2(160, 30)
	feedback_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	feedback_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(feedback_title)
	feedback_detail = _make_label("", 14, GameThemeScript.TEXT_SECONDARY)
	feedback_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback_detail.size_flags_stretch_ratio = 2.0
	feedback_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(feedback_detail)
	feedback_timer = Timer.new()
	feedback_timer.one_shot = true
	feedback_timer.timeout.connect(_reset_combat_feedback)
	row.add_child(feedback_timer)
	return row

func _reset_combat_feedback() -> void:
	feedback_priority = -1
	if not is_instance_valid(feedback_title) or battle_manager == null:
		return
	feedback_title.text = "敌人回合" if battle_manager.resolving else "你的回合"
	feedback_title.add_theme_color_override("font_color", GameThemeScript.GOLD)
	feedback_detail.text = "第 %d 回合 · 剩余 %d 次交换" % [battle_manager.turn_number, battle_manager.moves_left]

func _on_combat_feedback(feedback: Dictionary) -> void:
	if not is_instance_valid(feedback_title):
		return
	var kind: String = String(feedback.get("kind", ""))
	var priority: int = int({"victory": 5, "defeat": 5, "resonance": 4, "spectrum": 3, "enemy": 2, "clear": 1}.get(kind, 0))
	if feedback_timer.time_left > 0.0 and priority < feedback_priority:
		return
	feedback_priority = priority
	feedback_title.text = String(feedback.get("title", "奏式回响"))
	feedback_detail.text = String(feedback.get("detail", ""))
	feedback_title.tooltip_text = feedback_title.text
	feedback_detail.tooltip_text = feedback_detail.text
	feedback_title.add_theme_color_override("font_color", GameDataScript.color_tint(String(feedback.get("color", "gold"))))
	feedback_timer.start(clampf(float(feedback.get("duration", 2.0)), 0.5, 4.0))

func _show_onboarding_hint(hint_id: String, text: String) -> void:
	if SettingsManager.has_seen_onboarding_hint(hint_id):
		return
	SettingsManager.mark_onboarding_hint_seen(hint_id)
	# First encounters are commemorated in the existing log, never a blocking popup.
	if is_instance_valid(log_label) and board != null:
		_on_log_added(text)

func _build_battle_top() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 68)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", GameThemeScript.panel_style(GameThemeScript.SURFACE, GameThemeScript.BORDER, 1, 0, 14))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var marker: ColorRect = ColorRect.new()
	marker.color = GameThemeScript.RED
	marker.custom_minimum_size = Vector2(5, 30)
	row.add_child(marker)
	var battle_chapter: String = _chapter_key_from_node_id(String(GameManager.current_node_id))
	row.add_child(_make_label(_chapter_title(battle_chapter).replace("：", " · "), 20, GameThemeScript.TEXT_PRIMARY))
	moves_label = _make_label("本回合交换 0 / 3", 17, GameThemeScript.TEXT_PRIMARY)
	moves_label.custom_minimum_size = Vector2(152, 30)
	row.add_child(moves_label)
	spectrum_completion_label = _make_label("色谱达成 0 / 3", 17, GameThemeScript.GOLD)
	spectrum_completion_label.custom_minimum_size = Vector2(142, 30)
	row.add_child(spectrum_completion_label)
	resonance_label = _make_label("引音 · 待奏    应音 · 待奏", 15, GameThemeScript.BLUE.lightened(0.18))
	resonance_label.custom_minimum_size = Vector2(258, 30)
	resonance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resonance_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(resonance_label)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	coins_label = _make_label("金币 0", 15, GameThemeScript.GOLD)
	row.add_child(coins_label)
	pigment_label = _make_label("颜料 0", 15, GameThemeScript.GREEN)
	row.add_child(pigment_label)
	var return_button: Button = _make_button("≡", Vector2(36, 36), GameThemeScript.SURFACE)
	return_button.name = "BattleReturn"
	return_button.tooltip_text = "保存并返回主菜单"
	return_button.pressed.connect(_return_from_battle)
	row.add_child(return_button)
	return panel

func _return_from_battle() -> void:
	if battle_manager == null or board == null or board.busy or battle_manager.resolving or battle_manager.battle_finished:
		return
	_on_battle_checkpoint(battle_manager.create_snapshot())
	if SaveManager.save_run():
		show_main_menu()
	else:
		_on_log_added(SaveManager.last_error)

func _build_battle_middle() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 414)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var board_panel: PanelContainer = PanelContainer.new()
	board_panel.custom_minimum_size = Vector2(346, 0)
	board_panel.add_theme_stylebox_override("panel", GameThemeScript.panel_style(GameThemeScript.SURFACE, GameThemeScript.BORDER, 1, 4, 12))
	row.add_child(board_panel)
	var board_box: VBoxContainer = VBoxContainer.new()
	board_box.add_theme_constant_override("separation", 8)
	board_panel.add_child(board_box)
	var board_header: HBoxContainer = HBoxContainer.new()
	board_header.add_child(_make_label("色盘 · 6×6", 16, GameThemeScript.TEXT_PRIMARY))
	var board_header_spacer: Control = Control.new()
	board_header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_header.add_child(board_header_spacer)
	board_header.add_child(_make_label("三步回合", 13, GameThemeScript.GOLD))
	board_box.add_child(board_header)
	var board_shell: CenterContainer = CenterContainer.new()
	board_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_box.add_child(board_shell)
	board = BoardScript.new()
	board_shell.add_child(board)
	board.swap_preview_changed.connect(_on_board_swap_preview)

	var center_column: VBoxContainer = VBoxContainer.new()
	center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.add_theme_constant_override("separation", 8)
	row.add_child(center_column)
	center_column.add_child(_build_combat_feedback())
	center_column.add_child(_build_battle_arena())

	var spectrum_header: HBoxContainer = HBoxContainer.new()
	spectrum_header.add_child(_make_label("本回合色谱", 16, GameThemeScript.TEXT_PRIMARY))
	var spectrum_header_spacer: Control = Control.new()
	spectrum_header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spectrum_header.add_child(spectrum_header_spacer)
	spectrum_header.add_child(_make_label("回合契约", 12, GameThemeScript.TEXT_MUTED))
	center_column.add_child(spectrum_header)
	var spectrum_scroller: ScrollContainer = ScrollContainer.new()
	spectrum_scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spectrum_scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spectrum_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	spectrum_scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center_column.add_child(spectrum_scroller)
	spectrum_row = HBoxContainer.new()
	spectrum_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spectrum_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spectrum_row.alignment = BoxContainer.ALIGNMENT_CENTER
	spectrum_row.add_theme_constant_override("separation", 8)
	spectrum_scroller.add_child(spectrum_row)

	var resolution_box: VBoxContainer = VBoxContainer.new()
	resolution_box.add_theme_constant_override("separation", 3)
	board_box.add_child(resolution_box)
	var accent: ColorRect = ColorRect.new()
	accent.color = GameThemeScript.GOLD
	accent.custom_minimum_size = Vector2(0, 3)
	resolution_box.add_child(accent)
	resolution_name_label = _centered_label("等待色谱", 16, GameThemeScript.GOLD)
	resolution_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resolution_name_label.custom_minimum_size = Vector2(250, 22)
	resolution_box.add_child(resolution_name_label)
	resolution_damage_label = _centered_label("即时伤害  0", 15, GameThemeScript.TEXT_PRIMARY)
	resolution_box.add_child(resolution_damage_label)
	resolution_bonus_label = _centered_label("谱序尚未应答", 13, GameThemeScript.TEXT_SECONDARY)
	resolution_bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resolution_bonus_label.custom_minimum_size = Vector2(250, 30)
	resolution_box.add_child(resolution_bonus_label)
	return row

func _build_battle_bottom() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 104)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", GameThemeScript.panel_style(GameThemeScript.SURFACE, GameThemeScript.BORDER, 1, 0, 14))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)

	var log_box: VBoxContainer = VBoxContainer.new()
	log_box.custom_minimum_size = Vector2(280, 0)
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.size_flags_stretch_ratio = 1.5
	log_box.add_theme_constant_override("separation", 5)
	log_box.add_child(_make_label("战斗记录", 14, GameThemeScript.TEXT_PRIMARY))
	log_label = RichTextLabel.new()
	log_label.fit_content = false
	log_label.scroll_following = true
	log_label.bbcode_enabled = false
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("normal_font_size", 13)
	log_label.add_theme_color_override("default_color", GameThemeScript.TEXT_SECONDARY)
	log_box.add_child(log_label)
	row.add_child(log_box)

	var divider: ColorRect = ColorRect.new()
	divider.color = GameThemeScript.BORDER
	divider.custom_minimum_size = Vector2(1, 0)
	divider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(divider)

	var stats: VBoxContainer = VBoxContainer.new()
	stats.custom_minimum_size = Vector2(260, 0)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 7)
	row.add_child(stats)
	player_hp_text_label = _make_label("生命 0 / 0", 14, GameThemeScript.TEXT_PRIMARY)
	stats.add_child(player_hp_text_label)
	player_hp_bar = ProgressBar.new()
	player_hp_bar.custom_minimum_size = Vector2(250, 12)
	player_hp_bar.show_percentage = false
	player_hp_bar.add_theme_stylebox_override("background", GameThemeScript.panel_style(GameThemeScript.BG_DEEP, GameThemeScript.BG_DEEP, 0, 2, 0))
	player_hp_bar.add_theme_stylebox_override("fill", GameThemeScript.panel_style(GameThemeScript.GREEN, GameThemeScript.GREEN, 0, 2, 0))
	stats.add_child(player_hp_bar)
	combo_label = _make_label("连消 ×0", 20, GameThemeScript.GOLD)
	stats.add_child(combo_label)

	var battle_state_box: VBoxContainer = VBoxContainer.new()
	battle_state_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_state_box.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_state_box.add_theme_constant_override("separation", 8)
	battle_state_box.add_child(_make_label("战术状态", 14, GameThemeScript.TEXT_PRIMARY))
	battle_state_box.add_child(_make_label("遗物 %d  ·  精研 %d" % [GameManager.relics.size(), GameManager.get_upgraded_card_count()], 14, GameThemeScript.TEXT_SECONDARY))
	battle_state_box.add_child(_make_label(String(GameManager.get_current_node().get("name", "战斗节点")), 12, GameThemeScript.TEXT_MUTED))
	var selected_character: Dictionary = GameManager.get_selected_character()
	var active_skill: Dictionary = selected_character.get("active_skill", {})
	skill_button = SkillButtonScript.new()
	skill_button.setup(
		String(active_skill.get("id", "character_skill")),
		String(active_skill.get("name", "角色技")),
		String(selected_character.get("color", "gray")),
		int(active_skill.get("cost", 12))
	)
	skill_button.skill_requested.connect(func(_skill_id: String) -> void:
		if battle_manager != null:
			battle_manager.use_character_skill()
	)
	battle_state_box.add_child(skill_button)
	row.add_child(battle_state_box)
	return panel

func _build_battle_arena() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 174)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", GameThemeScript.panel_style(GameThemeScript.SURFACE_RAISED, GameThemeScript.BORDER, 1, 4, 0))
	var layers: Control = Control.new()
	panel.add_child(layers)

	var backdrop: TextureRect = TextureRect.new()
	backdrop.texture = ARCHIVE_BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	backdrop.modulate = Color(1.0, 1.0, 1.0, 0.9)
	layers.add_child(backdrop)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.035, 0.035, 0.039, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layers.add_child(shade)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	layers.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var hero_box: VBoxContainer = VBoxContainer.new()
	hero_box.custom_minimum_size = Vector2(126, 0)
	hero_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var selected_character: Dictionary = GameManager.get_selected_character()
	var selected_character_name: String = String(selected_character.get("name", "调色勇者"))
	var selected_character_color: Color = GameDataScript.color_tint(String(selected_character.get("color", "blue")))
	hero_box.add_child(_centered_label(selected_character_name, 14, selected_character_color))
	hero_avatar = TextureRect.new()
	hero_avatar.texture = _character_portrait(String(selected_character.get("id", "red")))
	hero_avatar.custom_minimum_size = Vector2(86, 86)
	hero_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_avatar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hero_box.add_child(hero_avatar)
	shield_label = _centered_label("护盾 0", 15, GameThemeScript.BLUE)
	hero_box.add_child(shield_label)
	deck_label = _centered_label("牌组 8", 12, GameThemeScript.TEXT_SECONDARY)
	hero_box.add_child(deck_label)
	row.add_child(hero_box)

	var arena_spacer: Control = Control.new()
	arena_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(arena_spacer)

	var enemy_info: VBoxContainer = VBoxContainer.new()
	enemy_info.custom_minimum_size = Vector2(190, 0)
	enemy_info.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_info.add_theme_constant_override("separation", 6)
	row.add_child(enemy_info)
	var enemy_name: Label = _make_label("敌人", 18, GameThemeScript.TEXT_PRIMARY)
	enemy_name.name = "EnemyName"
	enemy_info.add_child(enemy_name)
	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.custom_minimum_size = Vector2(190, 12)
	enemy_hp_bar.show_percentage = false
	enemy_hp_bar.add_theme_stylebox_override("background", GameThemeScript.panel_style(GameThemeScript.BG_DEEP, GameThemeScript.BG_DEEP, 0, 2, 0))
	enemy_hp_bar.add_theme_stylebox_override("fill", GameThemeScript.panel_style(GameThemeScript.RED, GameThemeScript.RED, 0, 2, 0))
	enemy_info.add_child(enemy_hp_bar)
	enemy_status_label = _make_label("状态  无", 13, GameThemeScript.TEXT_SECONDARY)
	enemy_info.add_child(enemy_status_label)
	var intent_panel: PanelContainer = PanelContainer.new()
	intent_panel.add_theme_stylebox_override("panel", GameThemeScript.panel_style(GameThemeScript.SURFACE_RAISED, GameThemeScript.RED, 1, 4, 8))
	var intent_box: VBoxContainer = VBoxContainer.new()
	intent_box.add_theme_constant_override("separation", 2)
	intent_box.add_child(_make_label("敌人意图", 12, GameThemeScript.RED.lightened(0.22)))
	enemy_intent_label = _make_label("准备攻击", 16, GameThemeScript.TEXT_PRIMARY)
	enemy_intent_label.custom_minimum_size = Vector2(180, 26)
	enemy_intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent_box.add_child(enemy_intent_label)
	intent_panel.add_child(intent_box)
	enemy_info.add_child(intent_panel)

	enemy_avatar = TextureRect.new()
	enemy_avatar.texture = _enemy_portrait_for_encounter(GameManager.get_current_encounter())
	enemy_avatar.custom_minimum_size = Vector2(94, 94)
	enemy_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_avatar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if GameManager.is_boss_node() else CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(enemy_avatar)
	return panel

func _on_board_move_resolved(clear_events: Array, cascade_count: int) -> void:
	_play_break()
	turn_exchange_count += 1
	if moves_label != null:
		moves_label.text = "本回合交换 %d" % turn_exchange_count
	battle_manager.on_player_move(clear_events, cascade_count)
	_show_onboarding_hint("first_swap", "初次采色")

func _on_board_swap_preview(preview: Dictionary) -> void:
	if not is_instance_valid(feedback_title) or battle_manager == null:
		return
	if preview.get("valid", false) != true:
		_reset_combat_feedback()
		return
	var pigment_by_color: Dictionary = preview.get("pigment_by_color", {})
	var pieces: Array[String] = []
	for color_key in ["red", "blue", "gold", "gray"]:
		var amount: int = int(pigment_by_color.get(color_key, 0))
		if amount > 0:
			pieces.append("%s+%d" % [GameDataScript.color_full_name(color_key), amount])
	var detail: String = "预览 " + (" / ".join(pieces) if not pieces.is_empty() else "无色素")
	var trigger_ids: Array = preview.get("triggerable_instance_ids", [])
	if not trigger_ids.is_empty():
		detail += "  · 色谱 %d 张可完成" % trigger_ids.size()
	var resonance_name: String = String(preview.get("resonance_name", ""))
	if not resonance_name.is_empty():
		detail += "  · 共鸣 %s" % resonance_name
	var risk_text: String = String(preview.get("risk_text", ""))
	if not risk_text.is_empty():
		detail += "  · " + risk_text
	feedback_title.text = "交换预览"
	feedback_detail.text = detail
	feedback_title.add_theme_color_override("font_color", GameThemeScript.GOLD)
	feedback_title.tooltip_text = feedback_title.text
	feedback_detail.tooltip_text = detail

func _on_battle_state_changed(state: Dictionary) -> void:
	var previous_moves_left: int = int(last_state.get("moves_left", 3))
	var current_moves_left: int = int(state.get("moves_left", 3))
	if not last_state.is_empty() and previous_moves_left <= 1 and current_moves_left >= 3:
		turn_exchange_count = 0
	last_state = state.duplicate(true)
	var enemy_name_label: Label = enemy_hp_bar.get_parent().get_node("EnemyName") as Label
	enemy_name_label.text = "%s  %d / %d" % [state["enemy_name"], state["enemy_hp"], state["enemy_max_hp"]]
	enemy_hp_bar.max_value = int(state["enemy_max_hp"])
	enemy_hp_bar.value = int(state["enemy_hp"])
	enemy_status_label.text = "状态  %s" % state["enemy_status"]
	enemy_intent_label.text = String(state["enemy_intent"])
	player_hp_bar.max_value = int(state["player_max_hp"])
	player_hp_bar.value = int(state["player_hp"])
	player_hp_text_label.text = "生命  %d / %d" % [int(state["player_hp"]), int(state["player_max_hp"])]
	moves_label.text = "本回合交换 %d    剩余 %d" % [turn_exchange_count, current_moves_left]
	coins_label.text = "金币 %d" % int(state["coins"])
	var battle_colors: Dictionary = state.get("battle_pigments", {})
	pigment_label.text = "色素 红%d 蓝%d 金%d 灰%d" % [
		int(battle_colors.get("red", 0)), int(battle_colors.get("blue", 0)),
		int(battle_colors.get("gold", 0)), int(battle_colors.get("gray", 0)),
	]
	shield_label.text = "护盾 %d" % int(state["shield"])
	combo_label.text = "连消 ×%d" % int(state["combo"])
	if state["gold_boost"] == true:
		combo_label.text += "  ·  金辉 +50%"
	deck_label.text = "牌组 %d  ·  抽 %d  ·  弃 %d" % [int(state["deck_count"]), int(state["draw_count"]), int(state["discard_count"])]
	var cards: Array = state.get("cards", [])
	var completed_spectra: int = 0
	for card_state_value in cards:
		var card_state: Dictionary = card_state_value
		if card_state.get("triggered", false) == true:
			completed_spectra += 1
	if spectrum_completion_label != null:
		spectrum_completion_label.text = "色谱达成 %d / %d" % [completed_spectra, cards.size()]
	_refresh_spectrum_cards(cards)
	_update_resolution_panel(state)
	if skill_button != null:
		skill_button.update_energy(int(state.get("skill_charge", 0)))
	_update_resonance_label(state.get("resonance", {}))
	_update_battle_background()

func _on_battle_checkpoint(snapshot: Dictionary) -> void:
	if board == null or snapshot.is_empty():
		return
	var full_snapshot: Dictionary = snapshot.duplicate(true)
	full_snapshot["board"] = board.create_snapshot()
	GameManager.set_battle_snapshot(full_snapshot)

func _update_resonance_label(resonance_value: Variant) -> void:
	if resonance_label == null or not resonance_value is Dictionary:
		return
	var state: Dictionary = resonance_value
	var lead: Dictionary = state.get("lead_note", {})
	var tail: Dictionary = state.get("tail_note", {})
	var last: Dictionary = state.get("last_resonance", {})
	var lead_name: String = GameDataScript.color_full_name(String(lead.get("color", ""))) if not lead.is_empty() else "待奏"
	var tail_name: String = GameDataScript.color_full_name(String(tail.get("color", ""))) if not tail.is_empty() else "待奏"
	resonance_label.text = "引音 · %s    应音 · %s" % [lead_name, tail_name]
	if not last.is_empty():
		resonance_label.text += "    共鸣 · %s" % String(last.get("name", "共鸣"))

func _refresh_spectrum_cards(cards: Array) -> void:
	if spectrum_row == null:
		return
	for child in spectrum_row.get_children():
		spectrum_row.remove_child(child)
		child.queue_free()
	for state in cards:
		var card: PanelContainer = SpectrumCardScript.new()
		card.setup(state, true)
		card.set_compact_mode(cards.size() >= 3)
		if cards.size() >= 3:
			card.custom_minimum_size.x = SPECTRUM_CARD_WIDTH
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.retain_requested.connect(func(instance_id: String) -> void:
			_play_select()
			battle_manager.set_retained_card(instance_id)
		)
		card.target_requested.connect(func(instance_id: String) -> void:
			_play_select()
			battle_manager.set_target_spectrum("" if String(battle_manager.target_spectrum_instance_id) == instance_id else instance_id)
		)
		spectrum_row.add_child(card)

func _on_spectrum_triggered(card_state: Dictionary) -> void:
	var from_pos: Vector2 = board.get_global_rect().get_center()
	var tint: Color = GameDataScript.color_tint(String(card_state.get("color", "neutral")))
	_spawn_floating_text(String(card_state.get("name", "色谱完成")), from_pos, from_pos + Vector2(0, -90), tint)

func _on_damage_event(amount: int, color_key: String) -> void:
	var from_pos: Vector2 = spectrum_row.get_global_rect().get_center() if spectrum_row != null else board.get_global_rect().get_center()
	var to_pos: Vector2 = enemy_avatar.get_global_rect().get_center()
	_spawn_floating_text("-%d" % amount, from_pos, to_pos, GameDataScript.color_tint(color_key))

func _on_spectrum_resolved(result: Dictionary) -> void:
	_show_onboarding_hint("first_spectrum", "首张奏式 · " + String(result.get("name", "色谱")))
	if not result.get("resonance", {}).is_empty():
		_show_onboarding_hint("first_resonance", "首次共鸣")
	if resolution_name_label != null:
		resolution_name_label.text = String(result.get("name", "色谱完成"))
		resolution_name_label.add_theme_color_override("font_color", GameDataScript.color_tint(String(result.get("color", "neutral"))))
	if resolution_damage_label != null:
		resolution_damage_label.text = "即时伤害  %d" % int(result.get("total_damage", 0))
	if not bool(SettingsManager.quick_resolve):
		var center: Vector2 = spectrum_row.get_global_rect().get_center() if spectrum_row != null else board.get_global_rect().get_center()
		_spawn_floating_text("奏式 %d" % int(result.get("total_damage", 0)), center, center + Vector2(0, -64), GameThemeScript.GOLD)


func _update_resolution_panel(state: Dictionary) -> void:
	if resolution_name_label == null or resolution_damage_label == null or resolution_bonus_label == null:
		return
	var result: Dictionary = state.get("last_spectrum_resolution", {})
	if result.is_empty():
		resolution_name_label.text = "等待色谱"
		resolution_damage_label.text = "即时伤害  0"
		resolution_bonus_label.text = "角色技已蓄势" if not state.get("pending_spectrum_modifier", {}).is_empty() else "谱序尚未应答"
		return
	resolution_name_label.text = String(result.get("name", "色谱完成"))
	resolution_name_label.add_theme_color_override("font_color", GameDataScript.color_tint(String(result.get("color", "neutral"))))
	resolution_damage_label.text = "即时伤害  %d" % int(result.get("total_damage", 0))
	var details: Array[String] = []
	if int(result.get("repeat_count", 1)) > 1:
		details.append("复奏 ×%d" % int(result.get("repeat_count", 1)))
	if int(result.get("armor_break", 0)) > 0:
		details.append("破障")
	var resonance: Dictionary = result.get("resonance", {})
	if not resonance.is_empty():
		details.append(String(resonance.get("name", "谱序共鸣")))
	if not state.get("enemy_disruption", {}).is_empty():
		details.append("下一谱受干扰")
	resolution_bonus_label.text = " · ".join(details) if not details.is_empty() else "基础奏式"

func _on_player_hit(amount: int) -> void:
	var from_pos: Vector2 = enemy_avatar.get_global_rect().get_center()
	var to_pos: Vector2 = hero_avatar.get_global_rect().get_center()
	_spawn_floating_text("-%d" % amount, from_pos, to_pos, Color(0.95, 0.34, 0.26))
	if SettingsManager.quick_resolve or SettingsManager.reduced_motion:
		hero_avatar.modulate = Color.WHITE
		return
	var speed: float = maxf(float(SettingsManager.combat_speed), 0.5)
	var tween: Tween = create_tween()
	tween.tween_property(hero_avatar, "modulate", Color(1, 0.55, 0.55), 0.08 / speed)
	tween.tween_property(hero_avatar, "modulate", Color.WHITE, 0.18 / speed)

func _on_log_added(message: String) -> void:
	recent_logs.append(message)
	while recent_logs.size() > 10:
		recent_logs.pop_front()
	if log_label != null:
		log_label.text = "\n".join(recent_logs)

func _on_battle_won() -> void:
	var generation: int = screen_generation
	var encounter: Dictionary = GameManager.get_current_encounter()
	var reward: Dictionary = GameManager.build_battle_reward(encounter)
	var delay: float = 0.0 if SettingsManager.quick_resolve else 0.75 / maxf(float(SettingsManager.combat_speed), 0.5)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if generation != screen_generation:
		return
	show_reward(reward)

func _on_battle_lost() -> void:
	var generation: int = screen_generation
	var delay: float = 0.0 if SettingsManager.quick_resolve else 0.65 / maxf(float(SettingsManager.combat_speed), 0.5)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if generation != screen_generation:
		return
	show_game_over()

func show_reward(reward: Dictionary) -> void:
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	_add_texture_wash(current_screen, Color(0.22, 0.20, 0.18, 0.22))
	var box: VBoxContainer = _center_box(Vector2(900, 560), 14)
	var is_boss_reward: bool = String(reward.get("node_type", "")) == "boss"
	var encounter: Dictionary = GameManager.get_current_encounter()
	var is_final_boss: bool = encounter.get("final_boss", false) == true
	var victory_title: String = "最终首领击破" if is_final_boss else ("章节首领击破" if is_boss_reward else "战斗胜利")
	box.add_child(_centered_label(victory_title, 36, Color(0.96, 0.91, 0.74)))
	box.add_child(_centered_label("获得 %d 金币%s。" % [int(reward.get("gold", 0)), " 与 %d 颜料" % int(reward.get("pigment", 0)) if int(reward.get("pigment", 0)) > 0 else ""], 19, Color(0.84, 0.82, 0.74)))
	var relic_id: String = String(reward.get("relic", ""))
	if relic_id != "":
		var relic: Dictionary = GameDataScript.relic(relic_id)
		box.add_child(_centered_label("将获得遗物：%s - %s" % [relic.get("name", relic_id), relic.get("description", "")], 17, Color(0.78, 0.86, 1.0)))
	var memory_id: String = String(reward.get("memory_id", ""))
	if memory_id != "":
		var memory_data: Dictionary = NarrativeMemoryScript.fragment(memory_id)
		var duplicate_memory: bool = GameManager.unlocked_memory_ids.has(memory_id)
		var memory_heading: String = "重复证词：转化为记忆墨" if duplicate_memory else "发现记忆碎片"
		box.add_child(_centered_label("%s  ·  %s《%s》" % [memory_heading, memory_id, memory_data.get("title", "未命名档案")], 17, GameThemeScript.GOLD))
		var memory_body: Label = _centered_label(String(memory_data.get("body", "这段证词仍有大半无法辨认。")), 14, GameThemeScript.TEXT_SECONDARY)
		memory_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		memory_body.custom_minimum_size = Vector2(760, 42)
		box.add_child(memory_body)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for card_id in reward.get("cards", []):
		_add_reward_card(row, String(card_id))
	if is_boss_reward:
		var confirm_text: String = "确认终局结算" if is_final_boss else "领取章节奖励并继续"
		var confirm: Button = _make_button(confirm_text, Vector2(280, 54), GameThemeScript.RED)
		confirm.pressed.connect(func() -> void:
			_play_enter()
			if GameManager.claim_battle_reward():
				_after_battle_reward_claimed()
			else:
				_on_toast("Boss 奖励已领取或已失效。", Callable(self, "show_map"))
		)
		box.add_child(confirm)
		return
	var skip: Button = _make_button("跳过：+10 金币", Vector2(220, 50))
	skip.pressed.connect(func() -> void:
		_play_enter()
		if GameManager.claim_battle_reward("", true):
			show_map()
		else:
			_on_toast("奖励已领取或已失效。", Callable(self, "show_map"))
	)
	box.add_child(skip)

func _add_reward_card(parent: Control, card_id: String) -> void:
	var card_data: Dictionary = GameDataScript.spectrum(card_id)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 214)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.11, 0.11, 0.12, 0.94), GameDataScript.color_tint(String(card_data.get("color", "neutral")))))
	parent.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(_make_label("%s · %s" % [card_data.get("name", card_id), GameDataScript.color_full_name(String(card_data.get("color", "neutral")))], 17, GameDataScript.color_tint(String(card_data.get("color", "neutral"))).lightened(0.18)))
	var detail: Label = _make_label("%s\n%s" % [card_data.get("condition", ""), card_data.get("effect", "")], 14, Color(0.82, 0.80, 0.74))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(228, 84)
	box.add_child(detail)
	var tags: Array[String] = GameDataScript.spectrum_tags(card_id)
	var tags_label: Label = _make_label("流派 · " + (" / ".join(tags) if not tags.is_empty() else "未分类"), 12, GameThemeScript.GOLD)
	tags_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tags_label.custom_minimum_size = Vector2(228, 24)
	box.add_child(tags_label)
	var synergy_reason: String = GameManager.get_spectrum_synergy_reason(card_id)
	if not synergy_reason.is_empty():
		var synergy_label: Label = _make_label("推荐 · " + synergy_reason, 12, GameThemeScript.TEXT_PRIMARY)
		synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		synergy_label.custom_minimum_size = Vector2(228, 24)
		box.add_child(synergy_label)
	var take: Button = _make_button("加入牌组", Vector2(0, 42), GameDataScript.color_tint(String(card_data.get("color", "neutral"))).darkened(0.30))
	take.pressed.connect(func() -> void:
		_play_enter()
		if GameManager.claim_battle_reward(card_id):
			show_map()
		else:
			_on_toast("奖励已领取或已失效。", Callable(self, "show_map"))
	)
	box.add_child(take)

func _after_battle_reward_claimed() -> void:
	var encounter: Dictionary = GameManager.get_current_encounter()
	if encounter.get("final_boss", false) == true:
		show_ending(true)
	elif GameManager.pending_torn_banner_reward:
		show_torn_banner_choice()
	else:
		show_map()

func show_event(event_id: String) -> void:
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	var box: VBoxContainer = _center_box(Vector2(820, 520), 14)
	var event_data: Dictionary = GameDataScript.event(event_id)
	box.add_child(_centered_label(String(event_data.get("title", "未知事件")), 36, Color(0.94, 0.88, 0.72)))
	var body: Label = _centered_label(String(event_data.get("body", "事件数据缺失。")), 18, Color(0.80, 0.78, 0.72))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(760, 64)
	box.add_child(body)
	box.add_child(_centered_label("金币 %d  ·  颜料 %d  ·  HP %d/%d" % [GameManager.coins, GameManager.pigment, GameManager.player_hp, GameManager.player_max_hp], 15, GameThemeScript.TEXT_SECONDARY))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for choice_value in event_data.get("choices", []):
		if choice_value is Dictionary:
			_add_event_button(row, event_id, choice_value)

func _add_event_button(parent: Control, event_id: String, choice_data: Dictionary) -> void:
	var choice_id: String = String(choice_data.get("id", ""))
	var button: Button = _make_button(String(choice_data.get("label", choice_id)), Vector2(320, 82))
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(func() -> void:
		_play_enter()
		var result: String = GameManager.apply_event_choice(event_id, choice_id)
		var next: Callable = Callable(self, "show_map")
		if result.begins_with("资源不足"):
			next = Callable(self, "show_event").bind(event_id)
		elif GameManager.get_pending_event_chain_id() != "":
			next = Callable(self, "show_event").bind(GameManager.get_pending_event_chain_id())
		_on_toast(result, next)
	)
	parent.add_child(button)

func show_chest_choice() -> void:
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	_add_texture_wash(current_screen, Color(0.26, 0.22, 0.12, 0.18))
	var box: VBoxContainer = _center_box(Vector2(820, 480), 14)
	box.add_child(_centered_label(String(GameManager.get_current_node().get("name", "旧调色箱")), 34, GameThemeScript.GOLD))
	box.add_child(_centered_label("镀金钥匙转动两次，只能带走其中一份馈赠。", 18, GameThemeScript.TEXT_SECONDARY))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for choice_value in GameManager.get_chest_choices():
		var choice: Dictionary = choice_value
		var choice_id: String = String(choice.get("id", ""))
		var button: Button = _make_button(String(choice.get("label", choice_id)), Vector2(300, 82), GameThemeScript.GOLD.darkened(0.42))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(func() -> void:
			_play_enter()
			var reward: Dictionary = GameManager.apply_chest_reward(choice_id)
			if reward.is_empty():
				_on_toast("宝箱选择已失效。", Callable(self, "show_map"))
			else:
				_on_toast("%s\n%s" % [reward.get("title", ""), reward.get("body", "")], Callable(self, "show_map"))
		)
		row.add_child(button)

func show_shop(regenerate_inventory: bool = true) -> void:
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	if regenerate_inventory:
		active_shop_inventory = GameManager.make_shop_inventory(_is_pre_boss_shop())
	var box: VBoxContainer = _center_box(Vector2(1000, 620), 10)
	box.add_child(_centered_label("破篷商队", 34, Color(0.96, 0.86, 0.58)))
	box.add_child(_centered_label("金币 %d | 牌组 %d | 精研 %d | HP %d/%d" % [GameManager.coins, GameManager.deck.size(), GameManager.get_upgraded_card_count(), GameManager.player_hp, GameManager.player_max_hp], 18, Color(0.84, 0.82, 0.74)))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for item in active_shop_inventory:
		_add_shop_item(grid, item)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	var refresh_price: int = GameManager.get_shop_refresh_price()
	var refresh_text: String = "刷新商品 · 免费（%d）" % GameManager.free_shop_refreshes if GameManager.free_shop_refreshes > 0 else "刷新商品 · %d 金币" % refresh_price
	var refresh: Button = _make_button(refresh_text, Vector2(240, 48), GameThemeScript.GOLD.darkened(0.40))
	refresh.disabled = GameManager.free_shop_refreshes <= 0 and GameManager.coins < refresh_price
	refresh.pressed.connect(func() -> void:
		_play_select()
		var refreshed_inventory: Array[Dictionary] = GameManager.refresh_shop_inventory(_is_pre_boss_shop())
		if refreshed_inventory.is_empty():
			_on_toast("金币不足，无法刷新商品。", Callable(self, "show_shop").bind(false))
		else:
			active_shop_inventory = refreshed_inventory
			show_shop(false)
	)
	actions.add_child(refresh)
	var leave: Button = _make_button("离开商店", Vector2(220, 48))
	leave.pressed.connect(func() -> void:
		_play_enter()
		active_shop_inventory.clear()
		GameManager.complete_current_node()
		show_map()
	)
	actions.add_child(leave)

func _add_shop_item(parent: Control, item: Dictionary) -> void:
	var text: String = ""
	match String(item.get("type", "")):
		"card":
			var card: Dictionary = GameDataScript.spectrum(String(item.get("id", "")))
			text = "%s\n%s\n%d 金币" % [card.get("name", ""), card.get("condition", ""), int(item.get("price", 0))]
		"upgrade":
			text = "选择 1 张色谱精研\n%d 金币" % int(item.get("price", 0))
		"remove":
			text = "删谱/净化\n%d 金币" % int(item.get("price", 0))
		"heal":
			text = "治疗 30 HP\n%d 金币" % int(item.get("price", 0))
		"relic":
			var relic: Dictionary = GameDataScript.relic(String(item.get("id", "")))
			text = "%s\n%s\n%d 金币" % [relic.get("name", ""), relic.get("description", ""), int(item.get("price", 0))]
		"peg_upgrade":
			var peg_names: Dictionary = {"critical": "锋锐调律", "echo": "复调回响", "bounty": "丰收节拍", "pierce": "破障奏式"}
			var peg_key: String = String(item.get("id", ""))
			text = "%s +1\n当前 Lv.%d\n%d 金币" % [peg_names.get(peg_key, peg_key), int(GameManager.peg_upgrades.get(peg_key, 0)), int(item.get("price", 0))]
	var button: Button = _make_button(text, Vector2(300, 96))
	button.pressed.connect(func() -> void:
		_play_enter()
		if String(item.get("type", "")) == "upgrade":
			show_upgrade_picker("shop", item)
		elif GameManager.buy_shop_item(item):
			active_shop_inventory.erase(item)
			show_shop(false)
		else:
			_on_toast("金币不足，或牌组太薄无法删谱。", Callable(self, "show_shop").bind(false))
	)
	parent.add_child(button)

func show_upgrade_picker(source: String, shop_item: Dictionary = {}) -> void:
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	var box: VBoxContainer = _center_box(Vector2(1100, 660), 10)
	box.add_child(_centered_label("选择精研色谱", 32, Color(0.95, 0.88, 0.70)))
	var subtitle: String = "选择一项营火精研。" if source == "camp" else "费用 %d 金币；确认后立即精研。" % int(shop_item.get("price", 0))
	box.add_child(_centered_label(subtitle, 17, Color(0.80, 0.78, 0.72)))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for card_instance in GameManager.get_upgradable_cards():
		var card_id: String = String(card_instance.get("card_id", ""))
		var instance_id: String = String(card_instance.get("instance_id", ""))
		var base: Dictionary = GameDataScript.spectrum(card_id)
		var upgraded: Dictionary = GameDataScript.spectrum_for_level(card_id, 1)
		var card_button: Button = _make_button("%s\n目标：%s\n精研：%s" % [base.get("name", card_id), upgraded.get("condition", ""), upgraded.get("effect", "")], Vector2(340, 104), GameDataScript.color_tint(String(base.get("color", "neutral"))).darkened(0.30))
		card_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var target_instance_id: String = instance_id
		var target_card_id: String = card_id
		card_button.pressed.connect(func() -> void:
			if card_button.disabled:
				return
			card_button.disabled = true
			_play_enter()
			if source == "shop":
				if GameManager.buy_shop_item(shop_item, target_instance_id):
					active_shop_inventory.erase(shop_item)
					_on_toast("已精研 %s。" % GameDataScript.spectrum(target_card_id).get("name", target_card_id), Callable(self, "show_shop").bind(false))
				else:
					_on_toast("金币不足，或该色谱已完成精研。", Callable(self, "show_shop").bind(false))
			else:
				var result: String = GameManager.apply_camp_upgrade(target_instance_id)
				_on_toast(result, Callable(self, "_continue_camp_action").bind(GameManager.visited_nodes.has(GameManager.current_node_id)))
		)
		grid.add_child(card_button)
	var back: Button = _make_button("返回", Vector2(200, 44))
	back.pressed.connect(func() -> void:
		_play_select()
		if source == "shop":
			show_shop(false)
		else:
			show_camp()
	)
	box.add_child(back)

func show_camp() -> void:
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	var box: VBoxContainer = _center_box(Vector2(820, 520), 14)
	box.add_child(_centered_label("调色台 / 镇门篝火", 34, Color(0.95, 0.88, 0.70)))
	box.add_child(_centered_label("只能选择一个行动。根据 HP、牌组质量和 Boss 压力取舍。", 18, Color(0.80, 0.78, 0.72)))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_add_camp_button(row, "heal", "治疗")
	_add_camp_button(row, "upgrade", "精研随机色谱")
	_add_camp_button(row, "cleanse", "净化一张牌")
	var conversion_row: HBoxContainer = HBoxContainer.new()
	conversion_row.alignment = BoxContainer.ALIGNMENT_CENTER
	conversion_row.add_theme_constant_override("separation", 10)
	box.add_child(conversion_row)
	_add_camp_button(conversion_row, "sell_pigment", "出售 2 颜料\n换 35 金币")
	_add_camp_button(conversion_row, "refine_color", "花 25 金币\n提炼净色")
	var boss_encounter: Dictionary = _boss_encounter_after_current_node()
	if GameManager.relics.has("gate_badge") and not boss_encounter.is_empty():
		var scout: Label = _centered_label(_boss_scout_text(boss_encounter), 15, Color(0.72, 0.84, 0.94))
		scout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		scout.custom_minimum_size = Vector2(780, 92)
		box.add_child(scout)

func _add_camp_button(parent: Control, choice: String, label: String) -> void:
	var button: Button = _make_button(label, Vector2(180, 68))
	button.pressed.connect(func() -> void:
		if button.disabled:
			return
		button.disabled = true
		_play_enter()
		if choice == "upgrade":
			show_upgrade_picker("camp")
		else:
			var result: String = GameManager.apply_camp_choice(choice)
			_on_toast(result, Callable(self, "_continue_camp_action").bind(GameManager.visited_nodes.has(GameManager.current_node_id)))
	)
	parent.add_child(button)

func _continue_camp_action(settled: bool) -> void:
	if settled:
		show_map()
	else:
		show_camp()

func show_torn_banner_choice() -> void:
	if not GameManager.pending_torn_banner_reward:
		show_map()
		return
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	_add_texture_wash(current_screen, Color(0.26, 0.16, 0.14, 0.20))
	var box: VBoxContainer = _center_box(Vector2(900, 500), 14)
	box.add_child(_centered_label("残破王旗", 36, GameThemeScript.RED.lightened(0.16)))
	box.add_child(_centered_label("旗面记住了这一章的胜利。选择复制一张现有色谱，或精研一张未升级色谱。", 18, GameThemeScript.TEXT_SECONDARY))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var copy_count: int = GameManager.get_torn_banner_candidates("copy").size()
	var copy_button: Button = _make_button("复制色谱\n%d 个可选目标" % copy_count, Vector2(300, 88), GameThemeScript.RED.darkened(0.38))
	copy_button.disabled = copy_count == 0
	copy_button.pressed.connect(func() -> void:
		_play_select()
		show_torn_banner_picker("copy")
	)
	row.add_child(copy_button)
	var upgrade_count: int = GameManager.get_torn_banner_candidates("upgrade").size()
	var upgrade_button: Button = _make_button("精研色谱\n%d 个可选目标" % upgrade_count, Vector2(300, 88), GameThemeScript.BLUE.darkened(0.34))
	upgrade_button.disabled = upgrade_count == 0
	upgrade_button.pressed.connect(func() -> void:
		_play_select()
		show_torn_banner_picker("upgrade")
	)
	row.add_child(upgrade_button)

func show_torn_banner_picker(action: String) -> void:
	var candidates: Array[Dictionary] = GameManager.get_torn_banner_candidates(action)
	if candidates.is_empty():
		show_torn_banner_choice()
		return
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	var box: VBoxContainer = _center_box(Vector2(1120, 680), 10)
	var action_label: String = "复制" if action == "copy" else "精研"
	box.add_child(_centered_label("残破王旗 · %s色谱" % action_label, 32, GameThemeScript.TEXT_PRIMARY))
	box.add_child(_centered_label("选择后立即结算，并进入下一章。", 16, GameThemeScript.TEXT_SECONDARY))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1080, 480)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for card_value in candidates:
		var card_instance: Dictionary = card_value
		var instance_id: String = String(card_instance.get("instance_id", ""))
		var card_id: String = String(card_instance.get("card_id", ""))
		var level: int = int(card_instance.get("level", 0))
		var card_data: Dictionary = GameDataScript.spectrum_for_level(card_id, level)
		var level_text: String = " +" if level > 0 else ""
		var card_button: Button = _make_button("%s%s\n%s\n%s" % [card_data.get("name", card_id), level_text, card_data.get("condition", ""), card_data.get("effect", "")], Vector2(346, 116), GameDataScript.color_tint(String(card_data.get("color", "neutral"))).darkened(0.36))
		card_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var target_instance_id: String = instance_id
		var target_card_name: String = String(card_data.get("name", card_id))
		card_button.pressed.connect(func() -> void:
			_play_enter()
			if GameManager.apply_torn_banner_choice(action, target_instance_id):
				_on_toast("残破王旗已%s《%s》。" % [action_label, target_card_name], Callable(self, "show_map"))
			else:
				_on_toast("王旗选择已失效，请重新选择。", Callable(self, "show_torn_banner_choice"))
		)
		grid.add_child(card_button)
	var back: Button = _make_button("返回行动选择", Vector2(220, 44))
	back.pressed.connect(func() -> void:
		_play_select()
		show_torn_banner_choice()
	)
	box.add_child(back)

func show_ending(victory: bool) -> void:
	SaveManager.clear_run()
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	_add_texture_wash(current_screen, Color(0.20, 0.20, 0.19, 0.18))
	var report: Dictionary = GameManager.get_ending_report(victory)
	var box: VBoxContainer = _center_box(Vector2(850, 650), 10)
	box.add_child(_centered_label("结算：%s" % report["title"], 36, Color(0.95, 0.90, 0.74)))
	var body: Label = _centered_label(String(report["body"]), 18, Color(0.78, 0.78, 0.72))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(760, 70)
	box.add_child(body)
	var evidence_lines: PackedStringArray = []
	for evidence_value in report.get("evidence", []):
		evidence_lines.append(String(evidence_value))
	if not evidence_lines.is_empty():
		var evidence: Label = _centered_label("结局证据  ·  %s" % "  ·  ".join(evidence_lines), 14, GameThemeScript.GOLD)
		evidence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		evidence.custom_minimum_size = Vector2(760, 42)
		box.add_child(evidence)
	var ratios: Dictionary = report["ratios"] as Dictionary
	for color_key in ["gray", "red", "blue", "gold"]:
		box.add_child(_make_ratio_row(color_key, float(ratios[color_key])))
	var stats: Dictionary = report.get("stats", {})
	var top_source: String = String(stats.get("top_damage_source", ""))
	if GameDataScript.SPECTRA.has(top_source):
		top_source = String(GameDataScript.spectrum(top_source).get("name", top_source))
	elif top_source == "burn":
		top_source = "燃烧"
	elif top_source == "relics_and_peg_upgrades":
		top_source = "遗物与调律"
	elif top_source == "spectrum_effect":
		top_source = "棋谱效果"
	if top_source == "":
		top_source = "无"
	box.add_child(_centered_label(
		"回合 %d  ·  交换 %d  ·  完成色谱 %d  ·  共鸣 %d" % [
			int(stats.get("turns", 0)), int(stats.get("swaps", 0)),
			int(stats.get("spectra_completed", 0)), int(stats.get("resonance_triggers", 0)),
		], 14, GameThemeScript.TEXT_SECONDARY
	))
	box.add_child(_centered_label(
		"单谱均伤 %.1f  ·  总伤害 %d  ·  主伤害 %s" % [
			float(stats.get("average_damage_per_spectrum", 0.0)),
			int(stats.get("total_damage", 0)), top_source,
		], 14, GameThemeScript.TEXT_SECONDARY
	))
	box.add_child(_centered_label(
		"谱序推进 %d  ·  共鸣触发 %d  ·  共鸣率 %d%%" % [
			int(stats.get("resonance_advances", 0)), int(stats.get("resonance_triggers", 0)),
			int(round(float(stats.get("resonance_rate", 0.0)) * 100.0)),
		], 14, GameThemeScript.TEXT_SECONDARY
	))
	box.add_child(_centered_label("遗物：%s    牌组：%d 张    灰蚀压力：%d" % [_relic_names(), GameManager.deck.size(), GameManager.gray_pressure], 15, Color(0.72, 0.72, 0.68)))
	var restart: Button = _make_button("重新开始", Vector2(220, 54))
	restart.pressed.connect(func() -> void:
		_play_enter()
		GameManager.reset_run()
		show_main_menu()
	)
	box.add_child(restart)

func show_game_over() -> void:
	show_ending(false)

func _make_ratio_row(color_key: String, ratio: float) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(720, 34)
	row.add_theme_constant_override("separation", 10)
	var label: Label = _make_label("%s %d%%" % [GameDataScript.color_full_name(color_key), int(round(ratio * 100.0))], 16, GameDataScript.color_tint(color_key))
	label.custom_minimum_size = Vector2(130, 30)
	row.add_child(label)
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = 1.0
	bar.value = ratio
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(560, 22)
	bar.add_theme_stylebox_override("background", _panel_style(Color(0.08, 0.08, 0.09), Color(0.28, 0.28, 0.28)))
	bar.add_theme_stylebox_override("fill", _panel_style(GameDataScript.color_tint(color_key).darkened(0.12), GameDataScript.color_tint(color_key).lightened(0.15)))
	row.add_child(bar)
	return row

func _on_toast(text: String, next: Callable) -> void:
	_clear_screen()
	current_screen = _make_screen(GameThemeScript.BG_BASE)
	var box: VBoxContainer = _center_box(Vector2(760, 420), 16)
	var label: Label = _centered_label(text, 22, Color(0.90, 0.86, 0.72))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(680, 120)
	box.add_child(label)
	var button: Button = _make_button("继续", Vector2(220, 54))
	button.pressed.connect(func() -> void:
		_play_enter()
		next.call()
	)
	box.add_child(button)

func _spawn_floating_text(text: String, from_pos: Vector2, to_pos: Vector2, tint: Color) -> void:
	if SettingsManager.quick_resolve or current_screen == null:
		return
	var label: Label = _make_label(text, 24, tint)
	label.z_index = 50
	current_screen.add_child(label)
	var reduced_motion: bool = bool(SettingsManager.reduced_motion)
	label.global_position = (to_pos if reduced_motion else from_pos) - Vector2(24, 14)
	var speed: float = maxf(float(SettingsManager.combat_speed), 0.5)
	var duration: float = (0.20 if reduced_motion else 0.48) / speed
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if not reduced_motion:
		tween.tween_property(label, "global_position", to_pos - Vector2(24, 14), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, duration).set_delay(0.05 / speed if reduced_motion else 0.18 / speed)
	tween.finished.connect(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)

func _update_battle_background() -> void:
	if battle_bg == null:
		return
	var ratios: Dictionary = GameManager.get_usage_ratios()
	var red: float = float(ratios.get("red", 0.0)) + float(GameManager.color_bias["red"]) * 0.05
	var blue: float = float(ratios.get("blue", 0.0)) + float(GameManager.color_bias["blue"]) * 0.05
	var gold: float = float(ratios.get("gold", 0.0)) + float(GameManager.color_bias["gold"]) * 0.05
	var gray: float = float(ratios.get("gray", 0.0)) + float(GameManager.gray_pressure) * 0.01
	var base: Color = GameThemeScript.BG_BASE
	battle_bg.color = Color(
		clamp(base.r + red * 0.045 + gold * 0.025 - gray * 0.012, 0.035, 0.14),
		clamp(base.g + gold * 0.035 - gray * 0.010, 0.040, 0.13),
		clamp(base.b + blue * 0.050 - gray * 0.008, 0.050, 0.16)
	)

func _make_screen(color: Color) -> Control:
	var screen: Control = Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(bg)
	return screen

func _clear_screen() -> void:
	screen_generation += 1
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.hide()
		current_screen.process_mode = Node.PROCESS_MODE_DISABLED
		current_screen.queue_free()
	current_screen = null
	board = null
	battle_manager = null
	battle_bg = null
	spectrum_row = null
	resolution_name_label = null
	resolution_damage_label = null
	resolution_bonus_label = null
	skill_button = null
	feedback_title = null
	feedback_detail = null
	feedback_timer = null
	feedback_priority = -1

func _center_box(min_size: Vector2, separation: int) -> VBoxContainer:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	current_screen.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = min_size
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", separation)
	center.add_child(box)
	return box

func _add_menu_backdrop(parent: Control) -> void:
	var texture: TextureRect = TextureRect.new()
	texture.name = "ChromaticHall"
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.texture = ARCHIVE_BACKDROP
	texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture.modulate = Color(0.94, 0.96, 1.0)
	parent.add_child(texture)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.025, 0.031, 0.037, 0.38)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shade)

func _add_chapter_signature(parent: Control) -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.anchor_left = 1.0
	box.anchor_top = 1.0
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -212.0
	box.offset_top = -104.0
	box.offset_right = -34.0
	box.offset_bottom = -28.0
	box.add_theme_constant_override("separation", 5)
	parent.add_child(box)
	var labels: Array[String] = ["灰雾边境 / 第一章", "镜湖工坊 / 第二章", "无色王庭 / 第三章"]
	var colors: Array[Color] = [GameThemeScript.RED, GameThemeScript.BLUE, GameThemeScript.GOLD]
	for index in range(labels.size()):
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 9)
		var marker: ColorRect = ColorRect.new()
		marker.color = colors[index]
		marker.custom_minimum_size = Vector2(12, 12)
		row.add_child(marker)
		var color: Color = GameThemeScript.TEXT_PRIMARY if index == 0 else GameThemeScript.TEXT_MUTED
		row.add_child(_make_label(labels[index], 12, color))
		box.add_child(row)

func _vertical_spacer(height: float) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _add_texture_wash(parent: Control, tint: Color) -> void:
	var texture: TextureRect = TextureRect.new()
	texture.texture = ARCHIVE_BACKDROP
	texture.modulate = tint
	texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(texture)

func _add_color_reveal_strips(parent: Control) -> void:
	var colors: Array[Color] = [Color(0.65, 0.14, 0.10, 0.28), Color(0.10, 0.30, 0.62, 0.24), Color(0.78, 0.56, 0.10, 0.24)]
	for i in range(colors.size()):
		var strip: ColorRect = ColorRect.new()
		strip.color = colors[i]
		strip.anchor_left = 0.12 + i * 0.18
		strip.anchor_right = 0.24 + i * 0.18
		strip.anchor_top = 0.72
		strip.anchor_bottom = 1.0
		parent.add_child(strip)

func _make_label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", GameThemeScript.font_for_size(size))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _centered_label(text: String, size: int, color: Color) -> Label:
	var label: Label = _make_label(text, size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _make_button(text: String, minimum_size: Vector2, fill: Color = Color(0.106, 0.125, 0.149)) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	GameThemeScript.apply_button(button, fill, GameThemeScript.BORDER)
	return button

func _panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	return GameThemeScript.panel_style(fill, border, 2, 4, 8)

func _atlas_texture(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas

func _character_portrait(character_id: String) -> Texture2D:
	var character: Dictionary = GameDataScript.starting_archetype(character_id)
	var portrait_path: String = String(character.get("portrait", ""))
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var portrait_resource: Resource = load(portrait_path)
		if portrait_resource is Texture2D:
			return portrait_resource as Texture2D
	return HERO_PORTRAIT

func _enemy_portrait_for_encounter(encounter: Dictionary) -> Texture2D:
	if encounter.get("boss", false) != true:
		return _atlas_texture(ORC_IDLE, Rect2(39, 38, 31, 26))
	match _chapter_key_from_node_id(String(encounter.get("id", GameManager.current_node_id))):
		"C1":
			return BOSS_GRAY_DRAGON
		"C2":
			return BOSS_MIRROR_CONDUCTOR
		"C3":
			return BOSS_COLORLESS_KING
		_:
			return _atlas_texture(ORC_IDLE, Rect2(39, 38, 31, 26))

func _music_for_current_chapter() -> AudioStream:
	return _music_for_chapter(_chapter_key_from_node_id(String(GameManager.current_node_id)))

func _music_for_chapter(chapter_key: String) -> AudioStream:
	match chapter_key:
		"C2":
			return MUSIC_CHAPTER_2
		"C3":
			return MUSIC_CHAPTER_3
		_:
			return MUSIC_CHAPTER_1

func _switch_music(stream: AudioStream) -> void:
	if music_player == null or stream == null:
		return
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	if music_player.stream == stream and music_player.playing:
		return
	music_player.stop()
	music_player.stream = stream
	music_player.play()

func _legal_map_targets() -> Array[String]:
	var legal_targets: Array[String] = []
	var current_node: Dictionary = GameManager.get_current_node()
	for edge_value in current_node.get("edges", []):
		var edge_id: String = String(edge_value)
		if GameManager.current_options.has(edge_id) and GameDataScript.CHAPTER_NODES.has(edge_id) and not GameManager.visited_nodes.has(edge_id) and GameManager.is_node_available_for_character(edge_id):
			legal_targets.append(edge_id)
	return legal_targets

func _is_pre_boss_shop() -> bool:
	var current_node: Dictionary = GameManager.get_current_node()
	for edge_value in current_node.get("edges", []):
		var next_node: Dictionary = GameManager.get_node_data(String(edge_value))
		if String(next_node.get("type", "")) == "boss":
			return true
		if String(next_node.get("type", "")) != "camp":
			continue
		for camp_edge_value in next_node.get("edges", []):
			if String(GameManager.get_node_data(String(camp_edge_value)).get("type", "")) == "boss":
				return true
	return false

func _boss_encounter_after_current_node() -> Dictionary:
	var current_node: Dictionary = GameManager.get_current_node()
	for edge_value in current_node.get("edges", []):
		var next_node: Dictionary = GameManager.get_node_data(String(edge_value))
		if String(next_node.get("type", "")) == "boss":
			return GameDataScript.encounter(String(next_node.get("encounter_id", "")))
	return {}

func _boss_scout_text(encounter: Dictionary) -> String:
	var dominant_color: String = GameManager.get_dominant_player_color()
	var intent_summaries: Array[String] = []
	for intent_value in encounter.get("intents", []):
		var intent: Dictionary = intent_value
		var intent_type: String = String(intent.get("type", ""))
		var intent_text: String = String(intent.get("text", intent_type))
		var value: float = float(intent.get("value", 0.0))
		match intent_type:
			"resist_dominant":
				intent_text = "%s（%s减伤 %d%%）" % [intent_text, GameDataScript.color_full_name(dominant_color), int(round(value * 100.0))]
			"resist":
				intent_text = "%s（%s减伤 %d%%）" % [intent_text, GameDataScript.color_full_name(String(intent.get("color", "neutral"))), int(round(value * 100.0))]
			_:
				if value > 0.0:
					intent_text += " %d" % int(round(value))
		intent_summaries.append(intent_text)
	return "镇门旧徽 · %s\n完整意图：%s" % [encounter.get("enemy_name", encounter.get("name", "章节 Boss")), " → ".join(intent_summaries)]

func _chapter_map_node_ids(chapter_key: String) -> Array[String]:
	var chapter_nodes: Dictionary = {}
	var minimum_layer: int = 2147483647
	for node_id_value in GameDataScript.CHAPTER_NODES.keys():
		var node_id: String = String(node_id_value)
		if _chapter_key_from_node_id(node_id) != chapter_key:
			continue
		var node_data: Dictionary = GameManager.get_node_data(node_id)
		chapter_nodes[node_id] = node_data
		minimum_layer = mini(minimum_layer, int(node_data.get("layer", 0)))
	if chapter_nodes.is_empty():
		return []

	var entry_nodes: Array[String] = []
	for node_id_value in chapter_nodes.keys():
		var node_id: String = String(node_id_value)
		var node_data: Dictionary = chapter_nodes[node_id]
		if int(node_data.get("layer", 0)) == minimum_layer:
			entry_nodes.append(node_id)
	entry_nodes.sort()

	var frontier: Array[String] = []
	if not entry_nodes.is_empty():
		frontier.append(entry_nodes[0])
	var current_id: String = String(GameManager.current_node_id)
	if chapter_nodes.has(current_id) and not frontier.has(current_id):
		frontier.append(current_id)
	for visited_id_value in GameManager.visited_nodes.keys():
		var visited_id: String = String(visited_id_value)
		if chapter_nodes.has(visited_id) and not frontier.has(visited_id):
			frontier.append(visited_id)

	var reachable: Dictionary = {}
	var cursor: int = 0
	while cursor < frontier.size():
		var node_id: String = frontier[cursor]
		cursor += 1
		if reachable.has(node_id):
			continue
		reachable[node_id] = true
		var node_data: Dictionary = GameManager.get_node_data(node_id)
		for edge_value in node_data.get("edges", []):
			var target_id: String = String(edge_value)
			if chapter_nodes.has(target_id) and not reachable.has(target_id):
				frontier.append(target_id)

	var result: Array[String] = []
	for node_id_value in reachable.keys():
		result.append(String(node_id_value))
	return result

func _map_focus_target(positions: Dictionary, available: Array[String]) -> String:
	if positions.has(GameManager.current_node_id) and not GameManager.visited_nodes.has(GameManager.current_node_id):
		return String(GameManager.current_node_id)
	var best_id: String = ""
	var best_y: float = INF
	for node_id in available:
		if not positions.has(node_id):
			continue
		var y: float = float((positions[node_id] as Vector2).y)
		if y < best_y:
			best_y = y
			best_id = node_id
	if best_id != "":
		return best_id
	if positions.has(GameManager.current_node_id):
		return String(GameManager.current_node_id)
	return String(positions.keys()[0]) if not positions.is_empty() else ""

func _flush_map_view_state() -> void:
	if not map_view_dirty or GameManager == null:
		return
	map_view_dirty = false
	GameManager.checkpoint_transient_state()


func _map_positions(chapter_key: String, content_size: Vector2 = Vector2.ZERO) -> Dictionary:
	var nodes_by_layer: Dictionary = {}
	for id in _chapter_map_node_ids(chapter_key):
		var node: Dictionary = GameManager.get_node_data(id)
		var layer: int = int(node.get("layer", 0))
		if not nodes_by_layer.has(layer):
			nodes_by_layer[layer] = []
		var layer_nodes: Array = nodes_by_layer[layer]
		layer_nodes.append(id)

	var layers: Array = nodes_by_layer.keys()
	layers.sort()
	var positions: Dictionary = {}
	if layers.is_empty():
		return positions

	var viewport_size: Vector2 = content_size if content_size != Vector2.ZERO else get_viewport_rect().size
	var layer_divisor: float = max(float(layers.size() - 1), 1.0)
	var top: float = 46.0
	var bottom: float = viewport_size.y - MAP_NODE_SIZE.y - 70.0
	var route_span: float = minf(maxf(viewport_size.x - 160.0 - MAP_NODE_SIZE.x, 520.0), MAP_ROUTE_MAX_WIDTH - MAP_NODE_SIZE.x)
	for layer_index in range(layers.size()):
		var layer_nodes: Array = nodes_by_layer[layers[layer_index]]
		layer_nodes.sort()
		var horizontal_gap: float = route_span if layer_nodes.size() <= 1 else minf(176.0, route_span / float(layer_nodes.size() - 1))
		var row_span: float = horizontal_gap * float(maxi(layer_nodes.size() - 1, 0))
		var first_x: float = viewport_size.x * 0.5 - MAP_NODE_SIZE.x * 0.5 - row_span * 0.5
		var y: float = lerpf(bottom, top, float(layer_index) / layer_divisor)
		for node_index in range(layer_nodes.size()):
			var ordered_id: String = String(layer_nodes[node_index])
			positions[ordered_id] = Vector2(first_x + horizontal_gap * node_index, y)
	return positions

func _map_chapter_key() -> String:
	var current_key: String = _chapter_key_from_node_id(String(GameManager.current_node_id))
	if current_key == "":
		current_key = "C1"
	if GameManager.visited_nodes.has(GameManager.current_node_id):
		for available_id in _legal_map_targets():
			var available_key: String = _chapter_key_from_node_id(String(available_id))
			if available_key != "" and available_key != current_key:
				return available_key
	return current_key

func _chapter_key_from_node_id(node_id: String) -> String:
	if not node_id.contains("-"):
		return ""
	return node_id.get_slice("-", 0).to_upper()

func _chapter_title(chapter_key: String) -> String:
	var data_script: Script = ResourceLoader.load("res://scripts/GameData.gd") as Script
	var constants: Dictionary = data_script.get_script_constant_map() if data_script != null else {}
	var chapters: Variant = constants.get("CHAPTERS", {})
	var chapter_number: int = int(chapter_key.trim_prefix("C"))
	var chapter_data: Variant
	if chapters is Dictionary:
		var chapter_map: Dictionary = chapters
		chapter_data = chapter_map.get(chapter_key, chapter_map.get(chapter_number, {}))
	elif chapters is Array and chapter_number > 0 and chapter_number <= chapters.size():
		chapter_data = chapters[chapter_number - 1]
	if chapter_data is Dictionary:
		var data: Dictionary = chapter_data
		var configured_title: String = String(data.get("title", data.get("name", "")))
		if configured_title != "":
			return configured_title
	elif chapter_data is String and String(chapter_data) != "":
		return String(chapter_data)
	var fallback_titles: Dictionary = {
		"C1": "第一章：灰雾边境",
		"C2": "第二章：镜湖工坊",
		"C3": "第三章：无色王庭",
	}
	return String(fallback_titles.get(chapter_key, "未知章节"))

func _node_color(node_type: String) -> Color:
	match node_type:
		"challenge":
			return Color(0.36, 0.18, 0.46)
		"elite":
			return Color(0.42, 0.18, 0.16)
		"event":
			return Color(0.24, 0.22, 0.38)
		"shop":
			return Color(0.42, 0.32, 0.12)
		"camp":
			return Color(0.18, 0.34, 0.30)
		"boss":
			return Color(0.38, 0.10, 0.10)
		"chest":
			return Color(0.38, 0.28, 0.12)
		_:
			return Color(0.24, 0.23, 0.21)

func _relic_names() -> String:
	if GameManager.relics.is_empty():
		return "无"
	var names: Array[String] = []
	for relic_id in GameManager.relics:
		names.append(String(GameDataScript.relic(relic_id).get("name", relic_id)))
	return "、".join(names)

func _play_select() -> void:
	if select_player != null:
		select_player.play()

func _play_enter() -> void:
	if enter_player != null:
		enter_player.play()

func _play_break() -> void:
	if break_player != null:
		break_player.play()
