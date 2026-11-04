extends Control
class_name MainMenu
## The main menu. A live Enterprise-over-Vulcan backdrop (the opening titles'
## own scene, in its endless "menu" mode), the game's title top-left, and the
## menu list beneath it. Visual rules: no framed buttons; off-white text, gold
## for the selected entry with a small marker and a thin gold rule; a soft dark
## gradient on the left for contrast instead of panels.
##
## INPUT: keyboard (Up/Down or W/S, Enter/Space, Esc), mouse (hover selects,
## click confirms), controller (D-pad or left stick, A to confirm, B to back).
##
## IDLE: after IDLE_SECONDS with no input the title and menu fade away, leaving
## only the backdrop. The first input afterwards only brings the menu back; it
## is swallowed, so waking it can never activate an entry.
##
## SOUND: nothing is required. If a music file exists at MUSIC_PATHS it loops on
## the "Music" bus; if click sounds exist at SFX_NAV_PATHS / SFX_CONFIRM_PATHS
## they play on navigate / confirm.

# ------------------------------------------------------------ tuning knobs --
const IDLE_SECONDS := 30.0
const UI_FADE_SECONDS := 0.7          # the entrance and the idle fade
const SELECT_SECONDS := 0.15          # selection change
const LEAVE_FADE_SECONDS := 0.6       # fade to black when a game starts
const STICK_THRESHOLD := 0.6

## Where "NEW GAME" goes. The full opening (Romulan cold open, five-year
## transition) is not built yet, so this is the Prologue for now.
const NEW_GAME_SCENE := "res://episodes/prologue/scenes/ColdOpen.tscn"
const PROLOGUE_SCENE := "res://episodes/prologue/scenes/BowlingAlley.tscn"
const EPISODE1_SCENE := "res://episodes/episode1/scenes/Ep1Opening.tscn"

const MUSIC_PATHS: Array[String] = [
	"res://assets/audio/menu/MUS_MENU.ogg",
	"res://assets/audio/menu/MUS_MENU.mp3",
	"res://assets/audio/menu/MUS_MENU.wav",
]
const SFX_NAV_PATHS: Array[String] = [
	"res://assets/audio/menu/SFX_MENU_NAV.wav",
	"res://assets/audio/menu/SFX_MENU_NAV.ogg",
]
const SFX_CONFIRM_PATHS: Array[String] = [
	"res://assets/audio/menu/SFX_MENU_CONFIRM.wav",
	"res://assets/audio/menu/SFX_MENU_CONFIRM.ogg",
]

const LOGO_FONT_PATH := "res://assets/fonts/StarTrek_BT_Regular.ttf"

# Layout, in the project's 1280x720 UI units (they scale with the window).
const LEFT_MARGIN := 64.0
const TITLE_TOP := 40.0
const TITLE_WIDTH := 440.0
const MENU_TOP := 292.0
const MENU_WIDTH := 340.0
const ROW_HEIGHT := 40.0
const MENU_FONT_SIZE := 19
const VIGNETTE_WIDTH_FRACTION := 0.5
const VIGNETTE_ALPHA := 0.88

const TEXT_IDLE := Color(0.88, 0.88, 0.86)
const TEXT_DISABLED := Color(0.42, 0.42, 0.42)

var _backdrop: TitleSequence
var _ui_root: Control
var _title_block: Control
var _menu_box: Control
var _rows: Array = []        # of Row
var _selected: int = -1
var _idle_time: float = 0.0
var _ui_hidden: bool = false
var _busy: bool = false      # a game is starting; ignore everything
var _modal: Control = null   # whichever sub-panel is open (options, load, credits, confirm)
var _stick_ready: bool = true
var _message_label: Label
var _message_tween: Tween
var _music: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _nav_stream: AudioStream
var _confirm_stream: AudioStream
var _options_ui: SettingsUI
var _load_ui: SaveLoadUI
var _collection_ui: CollectionUI     # REV 293
var _black: ColorRect
var _confirm_box: PanelContainer
var _confirm_buttons: Array[Button] = []
var _confirm_index: int = 1
var _confirm_yes: Callable
var _credits_box: PanelContainer


class Row:
	var id: String
	var enabled: bool = true
	var control: Control
	var label: Label
	var marker: Polygon2D
	var rule: ColorRect
	var tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_backdrop = TitleSequence.new()
	_backdrop.menu_mode = true
	add_child(_backdrop)
	_backdrop.play_menu()

	_build_vignette()
	_ui_root = Control.new()
	_ui_root.name = "MenuUI"
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_root)
	_build_title()
	_build_menu()
	_build_message_label()
	_build_debug_tag()

	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 1)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)

	_setup_audio()
	_entrance()


# ------------------------------------------------------------------ build --

func _build_vignette() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0, 0, 0, VIGNETTE_ALPHA), Color(0, 0, 0, VIGNETTE_ALPHA * 0.55), Color(0, 0, 0, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	texture.width = 256
	texture.height = 8
	var rect := TextureRect.new()
	rect.name = "LeftVignette"
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.anchor_right = VIGNETTE_WIDTH_FRACTION
	rect.anchor_bottom = 1.0
	add_child(rect)


func _title_font_logo() -> Font:
	if ResourceLoader.exists(LOGO_FONT_PATH):
		var font: Font = load(LOGO_FONT_PATH)
		if font != null:
			var variation := FontVariation.new()
			variation.base_font = font
			variation.variation_transform = Transform2D(Vector2(1.1, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
			variation.variation_embolden = 0.55
			return variation
	return UITheme.font_bold


func _tracked(font: Font, tracking: int) -> Font:
	if font == null:
		return null
	var variation := FontVariation.new()
	variation.base_font = font
	variation.spacing_glyph = tracking
	return variation


func _make_title_label(text: String, size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_title() -> void:
	_title_block = VBoxContainer.new()
	_title_block.name = "TitleBlock"
	_title_block.position = Vector2(LEFT_MARGIN, TITLE_TOP)
	_title_block.custom_minimum_size = Vector2(TITLE_WIDTH, 0)
	_title_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_title_block as VBoxContainer).add_theme_constant_override("separation", 2)
	_ui_root.add_child(_title_block)

	var star_trek := _make_title_label("STAR TREK", 58, UITheme.GOLD, _title_font_logo())
	_title_block.add_child(star_trek)

	# "—— THE SECRET OF ——": small, between two thin gold rules.
	var of_row := HBoxContainer.new()
	of_row.add_theme_constant_override("separation", 10)
	of_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_block.add_child(of_row)
	of_row.add_child(_make_rule(26.0))
	of_row.add_child(_make_title_label("THE SECRET OF", 14, TEXT_IDLE, _tracked(UITheme.font_regular, 4)))
	var tail := _make_rule(0.0)
	tail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	of_row.add_child(tail)

	_title_block.add_child(_make_title_label("VULCAN FURY", 46, UITheme.GOLD, UITheme.font_bold))

	var fan := _make_title_label("AN UNOFFICIAL FAN PRODUCTION", 9, TEXT_IDLE, _tracked(UITheme.font_regular, 3))
	fan.modulate.a = 0.85
	_title_block.add_child(fan)


func _make_rule(width: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, 14)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var line := ColorRect.new()
	line.color = Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.9)
	line.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	line.anchor_top = 0.5
	line.anchor_bottom = 0.5
	line.offset_top = -0.5
	line.offset_bottom = 0.5
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)
	return holder


func _build_menu() -> void:
	_menu_box = Control.new()
	_menu_box.name = "MenuList"
	_menu_box.position = Vector2(LEFT_MARGIN - 8.0, MENU_TOP)
	_menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_menu_box)
	_fill_rows(_main_entries())


func _main_entries() -> Array:
	var entries: Array = [
		["continue", "CONTINUE"],
		["new", "NEW GAME"],
		["load", "LOAD GAME"],
		["chapters", "CHAPTERS"],
		["trailers", "TRAILERS"],      # REV 237
		["collection", "COLLECTION"],
		["options", "OPTIONS"],
		["credits", "CREDITS"],
		["quit", "QUIT"],
	]
	if OS.is_debug_build():
		entries.append(["scenes", "DEBUG: SCENE SELECT"])     # REV 288
		entries.append(["debug", "DEBUG: LOCATIONS"])
		entries.append(["mapviewer", "DEBUG: MAP VIEWER"])   # REV 165
		entries.append(["crewviewer", "DEBUG: CREW VIEWER"])   # REV 180
	return entries


## Replaces whatever rows are showing with these [id, text] entries.
func _fill_rows(entries: Array) -> void:
	for old in _rows:
		old.control.queue_free()
	_rows.clear()
	_selected = -1
	var y := 0.0
	for entry in entries:
		var row := _make_row(String(entry[0]), String(entry[1]), y)
		if row.id == "continue":
			row.enabled = _latest_save().size() > 0
		_rows.append(row)
		y += ROW_HEIGHT
	_menu_box.custom_minimum_size = Vector2(MENU_WIDTH, y)
	for i in range(_rows.size()):
		_style_row(_rows[i], false, false)
	# Start on the first usable entry: CONTINUE when there's a save, else NEW GAME.
	_select(_first_enabled(), false)


# ---------------------------------------------------- debug: locations list --
# (Only in a debug build.) Every place in the game that can be walked around in.

const DEBUG_PER_PAGE := 8
var _debug_page: int = -1   # -1 = the normal menu is showing
var _debug_kind := "locations"   # REV 288: or "scenes" (the scene select)


## REV 288: every scene of Episodes 1 and 2 in story order, each opened as if the story had been
## played up to it (Ep1.debug_scene / Ep2.debug_scene set the flags and the Case File).
func _scene_select() -> Array:
	var list: Array = [
		["dbg_scene:" + NEW_GAME_SCENE, "COLD OPEN"],
		["dbg_scene:" + PROLOGUE_SCENE, "PROLOGUE: THE BOWLING ALLEY"],
		["dbg_ep1open", "EPISODE ONE: THE OPENING (SPACE, TRANSPORTER ROOM)"],
	]
	for i in Ep1.DEBUG_SCENES.size():
		list.append(["dbg_ep1scene:%d" % i, "EP1  " + String(Ep1.DEBUG_SCENES[i]["label"])])
	list.append(["dbg_scene:res://episodes/episode1/scenes/EpisodeOneEnd.tscn", "EP1  END CARD"])
	var ep2: Variant = load("res://episodes/episode2/Ep2.gd")
	if ep2 != null:
		var scenes: Array = ep2.DEBUG_SCENES
		for i in scenes.size():
			list.append(["dbg_ep2scene:%d" % i, "EP2  " + String(scenes[i]["label"])])
	# REV 594: Episode 3 (EPISODE3_SCRIPT.md)
	list.append(["dbg_scene:res://episodes/episode2/scenes/EpisodeTwoEnd.tscn", "EP2  END CARD"])
	var ep3: Variant = load("res://episodes/episode3/Ep3.gd") if ResourceLoader.exists("res://episodes/episode3/Ep3.gd") else null
	if ep3 != null:
		var scenes3: Array = ep3.DEBUG_SCENES
		for i in scenes3.size():
			list.append(["dbg_ep3scene:%d" % i, "EP3  " + String(scenes3[i]["label"])])
	# REV 494: Episode 5's scenes as they're built (the Arena memory first)
	var ep5: Variant = load("res://episodes/episode5/Ep5.gd") if ResourceLoader.exists("res://episodes/episode5/Ep5.gd") else null
	if ep5 != null:
		var scenes5: Array = ep5.DEBUG_SCENES
		for i in scenes5.size():
			list.append(["dbg_ep5scene:%d" % i, "EP5  " + String(scenes5[i]["label"])])
	return list


func _debug_locations() -> Array:
	var list: Array = [
		["dbg_scene:res://core/debug/NewBridge.tscn", "NEW BRIDGE (TEST)"],     # REV 795: the SketchUp bridge, walk-around only
		["dbg_scene:res://core/debug/NewDeck7.tscn", "NEW DECK 7 (TEST)"],     # REV 802: Deck 7 built from Franz Joseph's plans
		["dbg_scene:" + NEW_GAME_SCENE, "COLD OPEN: ROMULUS"],
		["dbg_scene:" + PROLOGUE_SCENE, "PROLOGUE: BOWLING ALLEY"],
		["dbg_scene:res://core/ui/cutscene/TitlesPreview.tscn", "OPENING TITLES"],
	]
	# REV 56: engineering (both levels) first, so it is easy to find. REV 308: Deck 7 map first, old map after.
	list.append(["dbg_room:ae_engineering", "EP1: ENTERPRISE - ENGINEERING (DECK 7 MAIN FLOOR)"])
	list.append(["dbg_room:ae_engineering#up", "EP1: ENTERPRISE - ENGINEERING (DECK 6 UPPER LEVEL)"])
	# REV 87: the TOS Cruiser, level by level. REV 421: and the secondary hull maps, deck by deck (Ep1.MAP_LEVELS)
	for mk in Ep1.MAP_LEVELS:
		var lvls: Array = Ep1.MAP_LEVELS[mk]
		for i in lvls.size():
			list.append(["dbg_room:%s#%d" % [mk, i], "EP1: " + String(Ep1.MAP_LEVEL_NAMES[mk]) + String(lvls[i][0]).to_upper()])
	for key in Ep1.ROOMS.keys():
		if String(key) in ["ae_engineering", "ae_engineering_up"] or Ep1.MAP_LEVELS.has(String(key)):
			continue
		list.append(["dbg_room:" + String(key), "EP1: " + String(Ep1.ROOMS[key][0]).to_upper()])
	list.append(["dbg_scene:res://episodes/episode1/scenes/EpisodeOneEnd.tscn", "EPISODE ONE: END CARD"])
	# REV 269: Episode 2 from the start (a fresh Episode 2 state)
	list.append(["dbg_ep2", "EP2: SICKBAY (START OF EPISODE TWO)"])
	return list


func _show_debug_page(page: int) -> void:
	var all: Array = _scene_select() if _debug_kind == "scenes" else _debug_locations()
	var pages: int = int(ceil(float(all.size()) / float(DEBUG_PER_PAGE)))
	_debug_page = (page + pages) % pages
	var entries: Array = []
	for i in range(_debug_page * DEBUG_PER_PAGE, mini(all.size(), (_debug_page + 1) * DEBUG_PER_PAGE)):
		entries.append(all[i])
	if pages > 1:
		entries.append(["dbg_more", ("MORE SCENES  (%d / %d)" if _debug_kind == "scenes" else "MORE LOCATIONS  (%d / %d)") % [_debug_page + 1, pages]])
	entries.append(["dbg_back", "<  BACK"])
	_fill_rows(entries)


func _leave_debug() -> void:
	_debug_page = -1
	_fill_rows(_main_entries())


func _activate_debug(id: String) -> void:
	if id == "dbg_more":
		_show_debug_page(_debug_page + 1)
	elif id == "dbg_back":
		_leave_debug()
	elif id == "dbg_ep1open":
		Ep1.new_game()
		_start_game(EPISODE1_SCENE)
	elif id.begins_with("dbg_ep1scene:"):
		_start_game(Ep1.debug_scene(int(id.substr("dbg_ep1scene:".length()))))
	elif id.begins_with("dbg_ep2scene:"):
		var ep2: Variant = load("res://episodes/episode2/Ep2.gd")
		_start_game(String(ep2.debug_scene(int(id.substr("dbg_ep2scene:".length())))))
	elif id.begins_with("dbg_ep3scene:"):
		var ep3: Variant = load("res://episodes/episode3/Ep3.gd")
		_start_game(String(ep3.debug_scene(int(id.substr("dbg_ep3scene:".length())))))
	elif id.begins_with("dbg_ep5scene:"):
		var ep5: Variant = load("res://episodes/episode5/Ep5.gd")
		_start_game(String(ep5.debug_scene(int(id.substr("dbg_ep5scene:".length())))))
	elif id == "dbg_ep2":
		load("res://episodes/episode2/Ep2.gd").new_game()
		_start_game("res://episodes/episode2/scenes/Sickbay.tscn")
	elif id.begins_with("dbg_scene:"):
		_start_game(id.substr("dbg_scene:".length()))
	elif id.begins_with("dbg_room:"):
		var rk := id.substr("dbg_room:".length())
		if rk.ends_with("#up"):
			rk = rk.trim_suffix("#up")
			ShipDecks.eng_upper = true
		elif rk.contains("#") and Ep1.MAP_LEVELS.has(rk.get_slice("#", 0)):
			var li := int(rk.get_slice("#", 1))
			rk = rk.get_slice("#", 0)
			var lvls: Array = Ep1.MAP_LEVELS[rk]
			Ep1.tc_arrive(lvls[clampi(li, 0, lvls.size() - 1)][1])
		_start_game(Ep1.debug_enter(rk))


func _make_row(id: String, text: String, y: float) -> Row:
	var row := Row.new()
	row.id = id
	var control := Control.new()
	control.position = Vector2(0, y)
	control.size = Vector2(MENU_WIDTH, ROW_HEIGHT)
	control.custom_minimum_size = control.size
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_menu_box.add_child(control)
	row.control = control

	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([Vector2(0, 0), Vector2(13, 7), Vector2(0, 14)])
	marker.position = Vector2(8, ROW_HEIGHT * 0.5 - 7.0)
	marker.color = UITheme.GOLD
	marker.modulate.a = 0.0
	control.add_child(marker)
	row.marker = marker

	var label := Label.new()
	label.text = text
	label.position = Vector2(36, 0)
	label.size = Vector2(MENU_WIDTH - 36.0, ROW_HEIGHT - 4.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	var font: Font = UITheme.font_regular
	if font != null:
		label.add_theme_font_override("font", _tracked(font, 2))
	control.add_child(label)
	row.label = label

	var rule := ColorRect.new()
	rule.color = UITheme.GOLD
	rule.position = Vector2(36, ROW_HEIGHT - 5.0)
	rule.size = Vector2(0, 1.5)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(rule)
	row.rule = rule

	var index := _rows.size()
	control.mouse_entered.connect(func():
		if _can_navigate() and _rows[index].enabled:
			_select(index, true))
	control.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _can_navigate():
				_activate(index))
	return row


func _build_message_label() -> void:
	_message_label = Label.new()
	_message_label.position = Vector2(LEFT_MARGIN + 28.0, MENU_TOP + ROW_HEIGHT * 7.0 + 20.0)
	_message_label.size = Vector2(420, 24)
	UITheme.style_hint(_message_label)
	_message_label.modulate.a = 0.0
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_message_label)


func _build_debug_tag() -> void:
	if not OS.is_debug_build():
		return
	var tag := Label.new()
	tag.text = "DEBUG BUILD"
	UITheme.style_hint(tag)
	tag.position = Vector2(20, 690)
	tag.modulate.a = 0.6
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(tag)


# ------------------------------------------------------------------ audio --

func _first_existing(paths: Array[String]) -> String:
	for path in paths:
		if ResourceLoader.exists(path):
			return path
	return ""


func _setup_audio() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_sfx)
	var nav_path := _first_existing(SFX_NAV_PATHS)
	if nav_path != "":
		_nav_stream = load(nav_path)
	var confirm_path := _first_existing(SFX_CONFIRM_PATHS)
	if confirm_path != "":
		_confirm_stream = load(confirm_path)

	var music_path := _first_existing(MUSIC_PATHS)
	if music_path != "":
		var stream: AudioStream = load(music_path)
		if stream != null:
			if "loop" in stream:
				stream.loop = true
			_music = AudioStreamPlayer.new()
			_music.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
			_music.stream = stream
			_music.volume_db = -80.0
			add_child(_music)
			_music.play()
			create_tween().tween_property(_music, "volume_db", 0.0, 1.5)


func _play_sfx(stream: AudioStream) -> void:
	if stream != null:
		_sfx.stream = stream
		_sfx.play()


# ---------------------------------------------------------------- showing --

func _entrance() -> void:
	_title_block.modulate.a = 0.0
	_menu_box.modulate.a = 0.0
	var menu_end := _menu_box.position
	_menu_box.position = menu_end + Vector2(-18, 0)
	_black.color.a = 1.0
	var tween := create_tween()
	tween.set_parallel(true)
	# REV 297: UITheme.dur = instant with Reduced Motion (no fade, no slide)
	tween.tween_property(_black, "color:a", 0.0, UITheme.dur(0.7))
	tween.tween_property(_title_block, "modulate:a", 1.0, UITheme.dur(0.6)).set_delay(UITheme.dur(0.25))
	tween.tween_property(_menu_box, "modulate:a", 1.0, UITheme.dur(0.6)).set_delay(UITheme.dur(0.5))
	tween.tween_property(_menu_box, "position", menu_end, UITheme.dur(0.6)).set_delay(UITheme.dur(0.5)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_idle_time = 0.0


## REV 103: while the menu is faded away on idle, a quiet breathing prompt says how to wake it.
var _wake_prompt: Label = null
var _wake_tween: Tween = null


func _show_wake_prompt(on: bool) -> void:
	if _wake_prompt == null:
		_wake_prompt = Label.new()
		_wake_prompt.name = "WakePrompt"
		_wake_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wake_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_wake_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_wake_prompt.offset_left = -240.0
		_wake_prompt.offset_right = 240.0
		_wake_prompt.offset_top = -72.0
		_wake_prompt.offset_bottom = -48.0
		if UITheme.font_regular != null:
			_wake_prompt.add_theme_font_override("font", _tracked(UITheme.font_regular, 4))
		_wake_prompt.add_theme_font_size_override("font_size", 12)
		_wake_prompt.add_theme_color_override("font_color", TEXT_IDLE)
		_wake_prompt.modulate.a = 0.0
		add_child(_wake_prompt)   # beside the menu, not inside it, so it shows while the menu is hidden
	if _wake_tween != null and _wake_tween.is_valid():
		_wake_tween.kill()
	_wake_tween = create_tween()
	if on:
		_wake_prompt.text = "PRESS ANY BUTTON" if InputHints.using_gamepad else "PRESS ANY KEY"
		_wake_tween.tween_interval(UITheme.dur(UI_FADE_SECONDS))       # after the menu has faded away
		_wake_tween.tween_property(_wake_prompt, "modulate:a", 0.75, UITheme.dur(1.2))
		_wake_tween.tween_callback(_breathe)
	else:
		_wake_tween.tween_property(_wake_prompt, "modulate:a", 0.0, UITheme.dur(0.2))


## Slow fade between dim and bright for as long as the menu stays hidden.
func _breathe() -> void:
	if not _ui_hidden or _wake_prompt == null:
		return
	if GameSettings.reduced_motion:     # REV 297: no pulsing with Reduced Motion - the prompt just stays lit
		_wake_prompt.modulate.a = 0.75
		return
	_wake_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_wake_tween.tween_property(_wake_prompt, "modulate:a", 0.3, 1.4)
	_wake_tween.tween_property(_wake_prompt, "modulate:a", 0.75, 1.4)
	_wake_tween.tween_callback(_breathe)


func _hide_ui() -> void:
	_ui_hidden = true
	_show_wake_prompt(true)
	create_tween().tween_property(_ui_root, "modulate:a", 0.0, UITheme.dur(UI_FADE_SECONDS))
	# The vignette fades with it so the backdrop is completely clear.
	var vignette: Node = get_node_or_null("LeftVignette")
	if vignette != null:
		create_tween().tween_property(vignette, "modulate:a", 0.0, UITheme.dur(UI_FADE_SECONDS))


func _show_ui() -> void:
	_ui_hidden = false
	_idle_time = 0.0
	_show_wake_prompt(false)
	create_tween().tween_property(_ui_root, "modulate:a", 1.0, UITheme.dur(0.25))
	var vignette: Node = get_node_or_null("LeftVignette")
	if vignette != null:
		create_tween().tween_property(vignette, "modulate:a", 1.0, UITheme.dur(0.25))


func _process(delta: float) -> void:
	# Debug layout editor (F1): the menu steps out of the way and stops reacting.
	var editing: bool = _backdrop != null and _backdrop.menu_edit
	_ui_root.visible = not editing
	var vignette_node: Node = get_node_or_null("LeftVignette")
	if vignette_node != null:
		vignette_node.visible = not editing
	if editing:
		return
	if _busy or _modal != null or _ui_hidden:
		return
	_idle_time += delta
	if _idle_time >= IDLE_SECONDS:
		_hide_ui()


# --------------------------------------------------------------- selection --

func _first_enabled() -> int:
	for i in range(_rows.size()):
		if _rows[i].enabled:
			return i
	return 0


func _select(index: int, animate: bool) -> void:
	if index == _selected:
		return
	var previous := _selected
	_selected = index
	if previous >= 0:
		_style_row(_rows[previous], false, animate)
	_style_row(_rows[_selected], true, animate)
	if animate:
		_play_sfx(_nav_stream)


func _step(direction: int) -> void:
	var count := _rows.size()
	var next := _selected
	for _i in range(count):
		next = (next + direction + count) % count
		if _rows[next].enabled:
			break
	_select(next, true)


func _style_row(row: Row, selected: bool, animate: bool) -> void:
	var color: Color
	if not row.enabled:
		color = TEXT_DISABLED
	elif selected:
		color = UITheme.GOLD_BRIGHT
	else:
		color = TEXT_IDLE
	var rule_width := 0.0
	if selected and row.enabled:
		rule_width = MENU_WIDTH - 40.0
	var marker_alpha := 1.0 if selected and row.enabled else 0.0
	if row.tween != null and row.tween.is_valid():
		row.tween.kill()
	if not animate:
		row.label.add_theme_color_override("font_color", color)
		row.rule.size.x = rule_width
		row.marker.modulate.a = marker_alpha
		return
	row.tween = create_tween()
	row.tween.set_parallel(true)
	row.tween.set_trans(Tween.TRANS_SINE)
	if not is_instance_valid(row.label):
		return
	var from_color: Color = row.label.get_theme_color("font_color")
	row.tween.tween_method(_set_row_color.bind(row), from_color, color, SELECT_SECONDS)
	row.tween.tween_property(row.rule, "size:x", rule_width, SELECT_SECONDS * 1.4)
	row.tween.tween_property(row.marker, "modulate:a", marker_alpha, SELECT_SECONDS)


func _set_row_color(c: Color, row: Row) -> void:
	if row != null and is_instance_valid(row.label):
		row.label.add_theme_color_override("font_color", c)


# -------------------------------------------------------------------- input --

func _can_navigate() -> bool:
	return not _busy and _modal == null and not _ui_hidden


func _is_activity(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventMouseMotion:
		return event.relative.length() > 1.0
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) > STICK_THRESHOLD
	return false


## Runs before everything else: resets the idle clock, and when the menu is
## faded out, uses the first key/button/click ONLY to bring it back.
func _input(event: InputEvent) -> void:
	if _busy or not _is_activity(event):
		return
	_idle_time = 0.0
	if _ui_hidden:
		_show_ui()
		if not (event is InputEventMouseMotion):
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or (_backdrop != null and _backdrop.menu_edit):
		return
	if _modal == _confirm_box and _confirm_box != null:
		_confirm_input(event)
		return
	if _modal != null:
		# Options / load / collection / credits look after their own keys; credits closes on any.
		if _modal == _credits_box and _is_activity(event) and not (event is InputEventMouseMotion):
			_close_credits()
			get_viewport().set_input_as_handled()
		return
	if _ui_hidden:
		return
	if _debug_page >= 0 and _is_cancel(event):
		_leave_debug()
		get_viewport().set_input_as_handled()
		return
	if _is_cancel(event) and not _rows.is_empty() and String(_rows[_rows.size() - 1].id) in ["chap_back", "trailer_back"]:
		_fill_rows(_main_entries())      # REV 117: back out of CHAPTERS (REV 237: and TRAILERS)
		get_viewport().set_input_as_handled()
		return

	var dir := _nav_direction(event)
	if dir != 0:
		_step(dir)
		get_viewport().set_input_as_handled()
	elif _is_confirm(event):
		_activate(_selected)
		get_viewport().set_input_as_handled()


## -1 (up), +1 (down) or 0, from arrows, W/S, the D-pad or the left stick.
## Handled here rather than in the project's input map so the in-game menus
## and player movement are left exactly as they are.
func _nav_direction(event: InputEvent) -> int:
	if event.is_action_pressed("ui_navigate_up"):
		return -1
	if event.is_action_pressed("ui_navigate_down"):
		return 1
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_W:
			return -1
		if event.keycode == KEY_S:
			return 1
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_UP:
			return -1
		if event.button_index == JOY_BUTTON_DPAD_DOWN:
			return 1
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
		if absf(event.axis_value) < 0.3:
			_stick_ready = true
		elif _stick_ready and absf(event.axis_value) > STICK_THRESHOLD:
			_stick_ready = false
			return -1 if event.axis_value < 0.0 else 1
	return 0


func _is_confirm(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_navigate_confirm"):
		return true
	return event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A


func _is_cancel(event: InputEvent) -> bool:
	if event.is_action_pressed("menu_cancel"):
		return true
	return event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B


# ----------------------------------------------------------------- actions --

func _activate(index: int) -> void:
	if index < 0 or index >= _rows.size() or not _rows[index].enabled or _busy:
		return
	_play_sfx(_confirm_stream)
	match String(_rows[index].id):
		"continue": _do_continue()
		"new": _do_new_game()
		"load": _open_load()
		"collection": _open_collection()     # REV 293: the same screen as in a game
		"options": _open_options()
		"credits": _open_credits()
		"quit": _ask("Quit the game?", "QUIT", _quit)
		"debug":
			_debug_kind = "locations"
			_show_debug_page(0)
		"scenes":
			_debug_kind = "scenes"
			_show_debug_page(0)
		"mapviewer": _start_game("res://core/debug/MapViewer.tscn")
		"crewviewer": _start_game("res://core/debug/CrewViewer.tscn")
		"chapters": _show_chapters()
		"trailers": _show_trailers()
		_:
			var rid := String(_rows[index].id)
			if rid.begins_with("chap"):
				_activate_chapter(rid)
			elif rid.begins_with("trailer"):
				_activate_trailer(rid)
			else:
				_activate_debug(rid)


# ------------------------------------------------------------ trailers (REV 237) --
## Each trailer plays and then comes back here, to the main menu.
const TRAILERS := [
	{"id": "teaser", "title": "TEASER - THE SECRET OF VULCAN FURY", "scene": "res://episodes/teaser/Teaser.tscn"},
]


func _show_trailers() -> void:
	var entries: Array = []
	for tr in TRAILERS:
		if ResourceLoader.exists(String(tr["scene"])):
			entries.append(["trailer:" + String(tr["id"]), String(tr["title"])])
	entries.append(["trailer_back", "<  BACK"])
	_fill_rows(entries)


func _activate_trailer(id: String) -> void:
	if id == "trailer_back":
		_fill_rows(_main_entries())
		return
	var key := id.trim_prefix("trailer:")
	for tr in TRAILERS:
		if String(tr["id"]) == key:
			_start_game(String(tr["scene"]))     # just watching - nothing to lose, no question
			return


# ------------------------------------------------------------ chapters (REV 117) --

func _show_chapters() -> void:
	var entries: Array = []
	for c in Chapters.CHAPTERS:
		var reached: bool = Chapters.is_reached(String(c["id"]))
		entries.append(["chap:" + String(c["id"]) if reached else "chap_locked", String(c["title"]) if reached else "- - -   NOT YET REACHED"])
	entries.append(["chap_back", "<  BACK"])
	_fill_rows(entries)
	for r in _rows:
		if r.id == "chap_locked":
			r.enabled = false
			_style_row(r, false, false)
	_select(_first_enabled(), false)


func _activate_chapter(id: String) -> void:
	if id == "chap_back":
		_fill_rows(_main_entries())
		return
	var key := id.trim_prefix("chap:")
	for c in Chapters.CHAPTERS:
		if String(c["id"]) != key:
			continue
		if c.has("credits"):
			_roll_chapter_credits(String(c["credits"]))
			return
		var go := func():
			SaveSystem.play_time_seconds = 0.0     # REV 296: a chapter started from here counts its own play time
			if bool(c.get("episode1", false)):
				Ep1.new_game()
			elif bool(c.get("episode2", false)):
				load("res://episodes/episode2/Ep2.gd").new_game()   # REV 269
			elif bool(c.get("episode3", false)):
				load("res://episodes/episode3/Ep3.gd").new_game()   # REV 594
			_start_game(String(c["scene"]))
		if key == "titles":
			go.call()      # just watching - nothing to lose
		else:
			_ask("Start \"%s\"? Your saves are kept." % String(c["title"]), "START", go)
		return


func _roll_chapter_credits(title: String) -> void:
	if _busy:
		return
	_busy = true
	_hide_ui()
	_show_wake_prompt(false)
	await _END_CREDITS.roll(self, title, false)
	_busy = false
	_show_ui()


func _show_message(text: String) -> void:
	_message_label.text = text
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()
	_message_label.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(2.4)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.6)


## [kind, index] of the newest save of any sort, or [] when there are none.
func _latest_save() -> Array:
	var best: Array = []
	var best_time := -1
	var candidates: Array = [["quick", 0]]
	for i in range(SaveSystem.AUTOSAVE_SLOT_COUNT):
		candidates.append(["auto", i])
	for i in range(SaveSystem.MANUAL_SLOT_COUNT):
		candidates.append(["manual", i])
	for c in candidates:
		var info: Dictionary = SaveSystem.get_slot_info(String(c[0]), int(c[1]))
		if info.get("exists", false) and int(info.get("timestamp", 0)) > best_time:
			best_time = int(info.get("timestamp", 0))
			best = c
	return best


func _do_continue() -> void:
	var latest := _latest_save()
	if latest.is_empty():
		_show_message("There is no saved game to continue.")
		return
	_fade_out_then(func():
		var result := SaveSystem.load_slot(String(latest[0]), int(latest[1]))
		if result != "":
			_busy = false
			_black.color.a = 0.0
			_show_message("Couldn't load: " + result))


func _do_new_game() -> void:
	if _latest_save().is_empty():
		_start_game(NEW_GAME_SCENE)
	else:
		_ask("Start a new game? Your saves are kept.", "NEW GAME", _start_game.bind(NEW_GAME_SCENE))


func _start_game(scene_path: String) -> void:
	if scene_path == EPISODE1_SCENE:
		TitleSequence.preload_world()     # REV 229: still held by the menu's backdrop, so this is instant
	_fade_out_then(func():
		SaveSystem.take_pending_load()
		if not scene_path.begins_with("res://episodes/episode1/"):
			AudioSubtitleManager.speech_root = AudioSubtitleManager.SPEECH_ROOT   # REV 77
		get_tree().change_scene_to_file(scene_path))


func _fade_out_then(action: Callable) -> void:
	_busy = true
	if _confirm_box != null:
		_close_confirm()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_black, "color:a", 1.0, LEAVE_FADE_SECONDS)
	if _music != null:
		tween.tween_property(_music, "volume_db", -60.0, LEAVE_FADE_SECONDS)
	tween.chain().tween_callback(action)


func _quit() -> void:
	_fade_out_then(func(): get_tree().quit())


# ----------------------------------------------------------------- options --

func _open_options() -> void:
	if _options_ui == null:
		_options_ui = SettingsUI.new()
		_options_ui.menu_mode = true
		_options_ui.closed.connect(_on_options_closed)
		add_child(_options_ui)
	_modal = _options_ui
	_options_ui.open()


func _on_options_closed() -> void:
	_modal = null
	_idle_time = 0.0


## REV 293: COLLECTION opens the very screen the HUD opens in a game (CollectionUI), over the
## backdrop. It looks after its own keys and pad buttons (B / Esc / K close it, up/down scroll);
## when it closes, the menu takes the keys back.
func _open_collection() -> void:
	if _collection_ui == null:
		_collection_ui = CollectionUI.new()
		_collection_ui.closed.connect(func():
			_modal = null
			_idle_time = 0.0)
		add_child(_collection_ui)
	_modal = _collection_ui
	_collection_ui.open()


func _open_load() -> void:
	if _load_ui == null:
		_load_ui = SaveLoadUI.new()
		_load_ui.closed.connect(func():
			_modal = null
			_idle_time = 0.0)
		add_child(_load_ui)
	_modal = _load_ui
	_load_ui.open_load()


# ----------------------------------------------------------------- credits --

const _END_CREDITS := preload("res://core/ui/cutscene/EndCredits.gd")


## REV 104: the full closing credits (CREDITS.txt) over the menu's backdrop, then back to the menu.
func _open_credits() -> void:
	if _busy:
		return
	_busy = true
	_hide_ui()
	_show_wake_prompt(false)
	await _END_CREDITS.roll(self, "", false)
	_busy = false
	_show_ui()


## The old one-panel credits (kept, unused).
func _open_credits_panel() -> void:
	if _credits_box == null:
		_credits_box = PanelContainer.new()
		UITheme.style_panel(_credits_box)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		_credits_box.add_child(column)
		var heading := Label.new()
		heading.text = "CREDITS"
		UITheme.style_title(heading)
		column.add_child(heading)
		column.add_child(UITheme.make_separator())
		var lines := [
			"STAR TREK: THE SECRET OF VULCAN FURY",
			"A Third Moon Interactive production",
			"",
			"An unofficial, non-commercial fan production.",
			"Star Trek and related marks belong to their respective owners.",
			"",
			"(Full credits to come.)",
		]
		for line in lines:
			var label := Label.new()
			label.text = line
			UITheme.style_body(label)
			column.add_child(label)
		var hint := Label.new()
		hint.text = "Press any key to go back."
		UITheme.style_hint(hint)
		column.add_child(hint)
		add_child(_credits_box)
	_credits_box.visible = true
	_modal = _credits_box
	var size_now := _credits_box.get_combined_minimum_size()
	_credits_box.size = size_now
	_credits_box.position = (get_viewport_rect().size - size_now) / 2.0
	UITheme.fade_in(_credits_box)


func _close_credits() -> void:
	_credits_box.visible = false
	_modal = null
	_idle_time = 0.0


# ----------------------------------------------------------------- confirm --

func _ask(message: String, yes_text: String, on_yes: Callable) -> void:
	if _confirm_box != null:
		_confirm_box.queue_free()
	_confirm_yes = on_yes
	_confirm_box = PanelContainer.new()
	UITheme.style_panel(_confirm_box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_confirm_box.add_child(column)
	var question := Label.new()
	question.text = message
	UITheme.style_body(question)
	column.add_child(question)
	_confirm_buttons.clear()
	for entry in [[yes_text, true], ["CANCEL", false]]:
		var button := Button.new()
		button.text = String(entry[0])
		button.custom_minimum_size = Vector2(300, 0)
		button.focus_mode = Control.FOCUS_NONE
		UITheme.style_button(button)
		var is_yes: bool = entry[1]
		button.pressed.connect(func(): _confirm_pick(is_yes))
		column.add_child(button)
		_confirm_buttons.append(button)
	add_child(_confirm_box)
	_modal = _confirm_box
	var size_now := _confirm_box.get_combined_minimum_size()
	_confirm_box.size = size_now
	_confirm_box.position = (get_viewport_rect().size - size_now) / 2.0
	_confirm_index = 1   # default to CANCEL so a stray key can't confirm
	_confirm_highlight()
	UITheme.fade_in(_confirm_box)


func _confirm_highlight() -> void:
	for i in range(_confirm_buttons.size()):
		_confirm_buttons[i].modulate = Color.WHITE if i == _confirm_index else Color(0.7, 0.7, 0.7)


func _confirm_input(event: InputEvent) -> void:
	if _nav_direction(event) != 0:
		_confirm_index = 1 - _confirm_index
		_confirm_highlight()
		get_viewport().set_input_as_handled()
	elif _is_confirm(event):
		_confirm_pick(_confirm_index == 0)
		get_viewport().set_input_as_handled()
	elif _is_cancel(event):
		_confirm_pick(false)
		get_viewport().set_input_as_handled()


func _confirm_pick(yes: bool) -> void:
	var action := _confirm_yes
	_close_confirm()
	if yes and action.is_valid():
		action.call()


func _close_confirm() -> void:
	if _confirm_box != null:
		_confirm_box.queue_free()
		_confirm_box = null
	_confirm_buttons.clear()
	_modal = null
	_idle_time = 0.0
