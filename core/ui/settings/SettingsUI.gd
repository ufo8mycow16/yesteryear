extends Control
class_name SettingsUI
## The SYSTEM menu (in-game, opened by the HUD's SYSTEM button or F10) and the
## OPTIONS menu (from the main menu). One panel with a main page and four
## submenus (REV 293: it said three - ACCESSIBILITY was added later):
##
##   SOUND     master / speech / music / ambient / effects / interface volume sliders,
##             and how dialogue is shown (speech + subtitles, subtitles only, speech only)
##   GRAPHICS  quality preset, display mode, resolution (only sizes your screen
##             can show), texture quality, anti-aliasing, lighting, vsync, frame-rate limit
##   CONTROLS  mouse and camera options, plus keyboard AND gamepad rebinding
##   ACCESSIBILITY  subtitle size / background, speaker names and colours, high contrast,
##             reduced motion, character name tags, hotspot marker colour
##
## Everything is saved by GameSettings (user://settings.cfg) the moment it
## changes. SAVE GAME and LOAD GAME open the slot list (SaveLoadUI).
##
## Using it: UP/DOWN to move, LEFT/RIGHT to change a value, ENTER to press a
## button, ESC to go back. The mouse works too (drag the sliders, click values).

## Emitted whenever the panel closes (the main menu listens for this).
signal closed()
## REV 105: emitted when it opens (the HUD dims the scene at once - the game is paused by then).
signal opened()

## True when opened from the main menu: no SAVE/LOAD/main-menu buttons, and
## the heading reads OPTIONS.
var menu_mode: bool = false

const MAIN_MENU_SCENE := "res://core/menu/MainMenu.tscn"
const SELECTED_NAV_COLOR := Color(0.7, 0.7, 0.7)
const PANEL_WIDTH := 700.0
const ROW_WIDTH := 660.0

enum Page { MAIN, SOUND, GRAPHICS, CONTROLS, ACCESSIBILITY }

var _page: int = Page.MAIN
var _leave_armed: bool = false
var _reset_armed: bool = false

var _panel: PanelContainer
var _heading: Label
var _scroll: ScrollContainer
var _rows_box: VBoxContainer
var _status: Label
var _hint: Label
var _save_load: SaveLoadUI
var _info: Label             # REV 105: where you are / objective / play time (in-game only)
var _paused_it := false      # we paused the game, so we unpause it
var _quit_armed := false

## Every row on the current page. A row is a Dictionary:
##   kind        "button" | "slider" | "choice" | "bind" | "note"
##   node        the Control that was added to the page
##   selectable  can the cursor stop here
##   press       Callable()          ENTER / click
##   adjust      Callable(dir: int)  LEFT / RIGHT   (-1 or +1)
##   refresh     Callable()          re-read the value and update the text
var _rows: Array[Dictionary] = []
var _selected: int = 0
## While waiting for the player to press a key / button: {"row": Dictionary, "key": bool}
var _listening: Dictionary = {}


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = PanelContainer.new()
	UITheme.style_panel(_panel)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)

	_heading = Label.new()
	UITheme.style_title(_heading)
	column.add_child(_heading)
	_info = Label.new()
	UITheme.style_dim(_info)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.x = PANEL_WIDTH
	_info.visible = false
	column.add_child(_info)
	column.add_child(UITheme.make_separator())

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	column.add_child(_scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 4)
	_rows_box.custom_minimum_size = Vector2(ROW_WIDTH, 0)
	_scroll.add_child(_rows_box)

	_status = Label.new()
	UITheme.style_hint(_status)
	column.add_child(_status)

	_hint = Label.new()
	UITheme.style_dim(_hint)
	_hint.text = "UP / DOWN  MOVE      LEFT / RIGHT  CHANGE      ENTER  SELECT      ESC  BACK"
	InputHints.bind(_hint, "{ui_navigate_up} {ui_navigate_down} MOVE|{ui_left} {ui_right} CHANGE|{ui_navigate_confirm} SELECT|{menu_cancel} BACK")
	column.add_child(_hint)

	# The slot list for SAVE GAME / LOAD GAME. While it is open this panel
	# steps aside (it stays "visible" so the HUD still counts the System menu
	# as open), then comes back when the slot list closes.
	_save_load = SaveLoadUI.new()
	_save_load.closed.connect(_on_save_load_closed)
	add_child(_save_load)

	# REV 105: keep values and the subtitle preview right if a setting changes from elsewhere
	GameSettings.accessibility_changed.connect(func() -> void:
		if visible and _page == Page.ACCESSIBILITY:
			_refresh_all())


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_listening = {}
	_leave_armed = false
	_quit_armed = false
	# REV 105: in a game this is the pause menu - everything stops (voices, scripted scenes,
	# animation, the clock) until it closes. The menu itself keeps running.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not menu_mode and is_inside_tree() and not get_tree().paused:
		SaveSystem.remember_screen()     # REV 116: the save thumbnail is the game, not this menu
		get_tree().paused = true
		_paused_it = true
	_update_info()
	_show_page(Page.MAIN, 0)
	visible = true
	UITheme.fade_in(_panel)
	SfxManager.ui("open")
	opened.emit()


func close() -> void:
	if _save_load != null and _save_load.visible:
		_save_load.visible = false
	_panel.visible = true
	_leave_armed = false
	_quit_armed = false
	_listening = {}
	visible = false
	_unpause()
	closed.emit()


func _unpause() -> void:
	if _paused_it and is_inside_tree():
		get_tree().paused = false
	_paused_it = false


func _exit_tree() -> void:
	_unpause()    # never leave the game frozen if the HUD goes away with the menu open


## "BRIDGE  ·  OBJECTIVE: Find out who ...  ·  PLAYED 1:23"
func _update_info() -> void:
	if menu_mode:
		_info.visible = false
		return
	var parts: PackedStringArray = []
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene != null and scene.has_method("location_name"):
		var where := String(scene.call("location_name"))
		if where != "":
			parts.append(where.to_upper())
	var obj: ObjectiveData = ObjectiveManager.get_current_objective()
	if obj != null and String(obj.text) != "":
		parts.append("OBJECTIVE: " + String(obj.text))
	var secs := int(SaveSystem.play_time_seconds)
	parts.append("PLAYED %d:%02d" % [secs / 3600, (secs / 60) % 60])
	_info.text = "   \u00b7   ".join(parts)
	_info.visible = true


func _open_save_load(loading: bool) -> void:
	_panel.visible = false
	if loading:
		_save_load.open_load()
	else:
		_save_load.open_save()


func _on_save_load_closed() -> void:
	_panel.visible = true
	_show_page(Page.MAIN, 0)


# =========================================================================
# Pages
# =========================================================================

func _show_page(page: int, select_index: int = 0) -> void:
	_page = page
	_listening = {}
	_reset_armed = false
	_status.text = ""
	for child in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_rows.clear()

	match page:
		Page.MAIN:
			_heading.text = "OPTIONS" if menu_mode else "PAUSED"
			_build_main_page()
		Page.SOUND:
			_heading.text = "SOUND"
			_build_sound_page()
		Page.GRAPHICS:
			_heading.text = "GRAPHICS"
			_build_graphics_page()
		Page.CONTROLS:
			_heading.text = "CONTROLS"
			_build_controls_page()
		Page.ACCESSIBILITY:
			_heading.text = "ACCESSIBILITY"
			_build_accessibility_page()

	_refresh_all()
	_selected = _first_selectable_from(clampi(select_index, 0, maxi(_rows.size() - 1, 0)))
	_fit_panel()
	_update_selection_highlight()


func _build_main_page() -> void:
	if not menu_mode:
		_add_button("RESUME", close)
		_add_button("SAVE GAME", _open_save_load.bind(false))
		_add_button("LOAD GAME", _open_save_load.bind(true))
	# REV 293: each page button remembers which page it opens ("opens"), so BACK can land on it
	# again without counting rows (see _back).
	for entry in [["SOUND", Page.SOUND], ["GRAPHICS", Page.GRAPHICS], ["CONTROLS", Page.CONTROLS],
			["ACCESSIBILITY", Page.ACCESSIBILITY]]:
		var page_row := _add_button(String(entry[0]), _show_page.bind(int(entry[1]), 0))
		page_row["opens"] = int(entry[1])
	if not menu_mode:
		var quit_row := _add_button("QUIT TO MAIN MENU", Callable())
		var quit_btn: Button = quit_row["node"]
		quit_row["press"] = _on_main_menu_pressed.bind(quit_btn)
		var desk_row := _add_button("QUIT TO DESKTOP", Callable())
		var desk_btn: Button = desk_row["node"]
		desk_row["press"] = _on_quit_desktop_pressed.bind(desk_btn)
	else:
		_add_button("CLOSE  [ESC]", close)


# ------------------------------------------------------------------- sound --

func _build_sound_page() -> void:
	_add_note("VOLUME")
	_add_volume_slider("MASTER VOLUME", "master")
	_add_volume_slider("SPEECH", "speech")
	_add_volume_slider("MUSIC", "music")
	_add_volume_slider("AMBIENT SOUND", "ambient")
	_add_volume_slider("SOUND EFFECTS", "sfx")
	_add_volume_slider("INTERFACE SOUNDS", "interface")
	_add_note("HOW DIALOGUE IS SHOWN")
	var names := ["SPEECH AND SUBTITLES", "SUBTITLES ONLY", "SPEECH ONLY"]
	_add_choice("DIALOGUE",
		func() -> String: return String(names[GameSettings.audio_mode]),
		func(dir: int) -> void: GameSettings.set_audio_mode(posmod(GameSettings.audio_mode + dir, 3)))
	_add_button("BACK  [ESC]", _back)


func _add_volume_slider(label_text: String, key: String) -> void:
	_add_slider(label_text,
		func() -> int: return GameSettings.get_volume(key),
		func(v: int) -> void: GameSettings.set_volume(key, v))


# ---------------------------------------------------------------- graphics --

func _build_graphics_page() -> void:
	_add_note(GameSettings.monitor_text())
	var modes := ["WINDOWED", "BORDERLESS FULLSCREEN", "EXCLUSIVE FULLSCREEN"]
	var resolutions: Array = GameSettings.available_resolutions()

	_add_choice("QUALITY PRESET",
		func() -> String: return String(GameSettings.PRESET_NAMES[GameSettings.quality_preset]),
		func(dir: int) -> void:
			var cur: int = GameSettings.quality_preset
			var nxt: int = (0 if dir > 0 else 2) if cur == 3 else posmod(cur + dir, 3)
			GameSettings.set_quality_preset(nxt))
	_add_choice("DISPLAY MODE",
		func() -> String: return String(modes[GameSettings.window_mode]),
		func(dir: int) -> void: GameSettings.set_window_mode(posmod(GameSettings.window_mode + dir, 3)))
	_add_choice("RESOLUTION",
		func() -> String:
			var r: Vector2i = GameSettings.resolution
			return "%d x %d" % [r.x, r.y],
		func(dir: int) -> void:
			var i: int = resolutions.find(GameSettings.resolution)
			if i < 0:
				i = 0
			GameSettings.set_resolution(resolutions[posmod(i + dir, resolutions.size())]))
	_add_choice("TEXTURE QUALITY",
		func() -> String: return String(GameSettings.TEXTURE_NAMES[GameSettings.texture_quality]),
		func(dir: int) -> void: GameSettings.set_texture_quality(posmod(GameSettings.texture_quality + dir, 3)))
	_add_choice("ANTI-ALIASING",
		func() -> String: return String(GameSettings.AA_NAMES[GameSettings.antialiasing]),
		func(dir: int) -> void:     # REV 681: OFF, FXAA, 2X, 4X
			var order: Array = GameSettings.AA_ORDER
			var i: int = maxi(0, order.find(GameSettings.antialiasing))
			GameSettings.set_antialiasing(int(order[posmod(i + dir, order.size())])))
	_add_choice("LIGHTING",
		func() -> String: return "ENHANCED" if GameSettings.enhanced_lighting else "CLASSIC",
		func(_dir: int) -> void: GameSettings.set_enhanced_lighting(not GameSettings.enhanced_lighting))
	_add_choice("SCREEN EFFECTS",     # REV 417
		func() -> String: return String(GameSettings.SCREEN_EFFECT_NAMES[GameSettings.screen_effects]),
		func(dir: int) -> void: GameSettings.set_screen_effects(GameSettings.screen_effects + dir))
	_add_choice("ROOM MOODS",     # REV 456: the TOS theatrical lighting on the ship's decks
		func() -> String: return "ON" if GameSettings.mood_lighting else "OFF",
		func(_dir: int) -> void: GameSettings.set_mood_lighting(not GameSettings.mood_lighting))
	_add_choice("DYNAMIC RESOLUTION",     # REV 681: draws the 3D a little smaller when the PC can't keep up
		func() -> String: return "ON" if GameSettings.dynamic_resolution else "OFF",
		func(_dir: int) -> void: GameSettings.set_dynamic_resolution(not GameSettings.dynamic_resolution))
	_add_choice("VSYNC",
		func() -> String: return "ON" if GameSettings.vsync else "OFF",
		func(_dir: int) -> void: GameSettings.set_vsync(not GameSettings.vsync))
	_add_choice("FRAME RATE LIMIT",
		func() -> String:
			return "UNLIMITED" if GameSettings.fps_limit == 0 else "%d FPS" % GameSettings.fps_limit,
		func(dir: int) -> void:
			var i: int = GameSettings.FPS_CHOICES.find(GameSettings.fps_limit)
			if i < 0:
				i = 1
			GameSettings.set_fps_limit(int(GameSettings.FPS_CHOICES[posmod(i + dir, GameSettings.FPS_CHOICES.size())])))
	if OS.is_debug_build():
		_add_choice("DEBUG INFO  [F3]",
			func() -> String: return "ON" if GameSettings.debug_overlay else "OFF",
			func(_dir: int) -> void: GameSettings.set_debug_overlay(not GameSettings.debug_overlay))
	_add_note("OLDER COMPUTER? CHOOSE LOW (OR MEDIUM) AND LEAVE DYNAMIC RESOLUTION ON.")
	_add_note("IN FULLSCREEN, RESOLUTION SETS THE SIZE THE GAME IS DRAWN AT (THEN SCALED UP).")
	_add_button("BACK  [ESC]", _back)


# ----------------------------------------------------------- accessibility --

func _build_accessibility_page() -> void:
	_add_note("SUBTITLES")
	_add_choice("SUBTITLE TEXT SIZE",
		func() -> String: return String(GameSettings.SUBTITLE_SIZE_NAMES[GameSettings.subtitle_size]),
		func(dir: int) -> void: GameSettings.set_subtitle_size(posmod(GameSettings.subtitle_size + dir, 4)))
	_add_choice("SUBTITLE BACKGROUND",
		func() -> String: return String(GameSettings.SUBTITLE_BACKGROUND_NAMES[GameSettings.subtitle_background]),
		func(dir: int) -> void: GameSettings.set_subtitle_background(posmod(GameSettings.subtitle_background + dir, 4)))
	_add_choice("SPEAKER NAMES",
		func() -> String: return "ON" if GameSettings.speaker_names else "OFF",
		func(_dir: int) -> void: GameSettings.set_speaker_names(not GameSettings.speaker_names))
	_add_choice("SPEAKER COLOURS",
		func() -> String: return "ON" if GameSettings.speaker_colours else "OFF",
		func(_dir: int) -> void: GameSettings.set_speaker_colours(not GameSettings.speaker_colours))
	_add_subtitle_preview()
	_add_choice("HIGH CONTRAST",
		func() -> String: return "ON" if GameSettings.high_contrast else "OFF",
		func(_dir: int) -> void: GameSettings.set_high_contrast(not GameSettings.high_contrast))
	_add_choice("REDUCED MOTION",
		func() -> String: return "ON" if GameSettings.reduced_motion else "OFF",
		func(_dir: int) -> void: GameSettings.set_reduced_motion(not GameSettings.reduced_motion))
	_add_note("HIGH CONTRAST MAKES THE SUBTITLE BOX SOLID BLACK WITH WHITE TEXT, AND MENUS AND PANELS SOLID BLACK WITH WHITE EDGES.")
	_add_note("CHARACTERS")
	_add_choice("CHARACTER NAMES",
		func() -> String: return String(GameSettings.NAME_TAG_NAMES[GameSettings.name_tags]),
		func(dir: int) -> void: GameSettings.set_name_tags(posmod(GameSettings.name_tags + dir, 3)))
	_add_note("EACH CHARACTER'S NAME ABOVE THEIR HEAD, IN THEIR SUBTITLE COLOUR. THE PERSON YOU'RE AIMING AT IS HIGHLIGHTED.")
	_add_note("HOTSPOTS")
	_add_choice("HOTSPOT MARKER COLOUR",
		func() -> String: return String(GameSettings.MARKER_PALETTE_NAMES[GameSettings.marker_palette]),
		func(dir: int) -> void: GameSettings.set_marker_palette(posmod(GameSettings.marker_palette + dir, 4)))
	_add_note("THE MARKERS SHOWN WHILE YOU HOLD THE SHOW HOTSPOTS KEY. BLUE OR WHITE STAND OUT BETTER FOR MANY KINDS OF COLOUR BLINDNESS.")
	_add_button("BACK  [ESC]", _back)


## REV 293: who "says" the sample subtitle (a GameNames character id).
const PREVIEW_SPEAKER := "mccoy"

## A sample subtitle that shows the current settings as you change them.
func _add_subtitle_preview() -> void:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(ROW_WIDTH, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.set_content_margin_all(9)
	style.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", style)
	# a stand-in for the scene behind the words, so NONE and LIGHT can be judged
	var scene_tint := ColorRect.new()
	scene_tint.color = Color(0.32, 0.36, 0.42)
	scene_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(ROW_WIDTH, 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	box.add_child(col)
	var who := Label.new()
	UITheme.style_title(who)
	var said := Label.new()
	UITheme.style_body(said)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(who)
	col.add_child(said)
	var stack := MarginContainer.new()
	stack.add_child(scene_tint)
	stack.add_child(box)
	stack.custom_minimum_size = Vector2(ROW_WIDTH, 0)
	var refresh := func() -> void:
		var big: int = GameSettings.subtitle_size
		var alpha: float = GameSettings.subtitle_background_alpha()
		var contrast: bool = GameSettings.high_contrast
		style.bg_color = Color(0, 0, 0, 1.0) if contrast else Color(UITheme.PANEL_BG.r, UITheme.PANEL_BG.g, UITheme.PANEL_BG.b, alpha)
		var edge: Color = Color.WHITE if contrast else UITheme.GOLD
		style.border_color = Color(edge.r, edge.g, edge.b, 1.0 if contrast else clampf(alpha / 0.88, 0.0, 1.0))
		var outline: int = 0 if alpha >= 0.85 else (4 if alpha > 0.0 else 6)
		# REV 293: name and colour both come from the speaker id (GameNames for the shown name,
		# speaker_colour of the id for its colour) - no typed-in "McCoy" any more.
		who.text = GameNames.character(PREVIEW_SPEAKER)
		who.visible = GameSettings.speaker_names
		who.add_theme_font_size_override("font_size", 17 + 3 * big)
		who.add_theme_color_override("font_color", GameSettings.speaker_colour(PREVIEW_SPEAKER, UITheme.GOLD))
		said.text = "I'm a doctor, not a decorator! Now hold still, Jim."
		said.add_theme_font_size_override("font_size", GameSettings.subtitle_font_size())
		said.add_theme_color_override("font_color", Color.WHITE if contrast else UITheme.TEXT_PRIMARY)
		for l in [who, said]:
			(l as Label).add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			(l as Label).add_theme_constant_override("outline_size", outline)
		_fit_panel.call_deferred()
	refresh.call()
	_register({"kind": "note", "node": stack, "selectable": false, "refresh": refresh})


# ---------------------------------------------------------------- controls --

func _build_controls_page() -> void:
	_add_note("MOUSE")
	_add_choice("INVERT MOUSE Y-AXIS",
		func() -> String: return "ON" if GameSettings.invert_mouse_y else "OFF",
		func(_dir: int) -> void: GameSettings.set_invert_mouse_y(not GameSettings.invert_mouse_y))
	_add_choice("INVERT MOUSE WHEEL ZOOM",
		func() -> String: return "ON" if GameSettings.invert_zoom else "OFF",
		func(_dir: int) -> void: GameSettings.set_invert_zoom(not GameSettings.invert_zoom))
	_add_note("CAMERA")
	_add_slider("FIELD OF VIEW", func() -> int: return GameSettings.camera_fov,
		func(v: int) -> void: GameSettings.set_camera_fov(v), 55, 95, 5, "%d DEG")
	_add_slider("CAMERA SPEED - MOUSE", func() -> int: return GameSettings.camera_speed_mouse,
		func(v: int) -> void: GameSettings.set_camera_speed_mouse(v), 25, 200, 25)
	_add_slider("CAMERA SPEED - KEYS / PAD", func() -> int: return GameSettings.camera_speed_keys,
		func(v: int) -> void: GameSettings.set_camera_speed_keys(v), 25, 200, 25)
	_add_note("KEYBOARD AND GAMEPAD  -  SELECT A BOX, PRESS ENTER, THEN PRESS THE NEW KEY OR BUTTON")
	_add_note("ESC CANCELS.  DELETE CLEARS THE BOX.  LEFT / RIGHT SWITCHES BETWEEN KEYBOARD AND GAMEPAD.")
	for entry in GameSettings.REBINDABLE_ACTIONS:
		_add_bind(String(entry[0]), String(entry[1]))
	var reset_row := _add_button("RESET CONTROLS TO DEFAULT", Callable())
	var reset_btn: Button = reset_row["node"]
	reset_row["press"] = _on_reset_pressed.bind(reset_btn)
	_add_button("BACK  [ESC]", _back)


func _on_reset_pressed(button: Button) -> void:
	if not _reset_armed:
		_reset_armed = true
		button.text = "PRESS AGAIN TO RESET ALL KEYS AND BUTTONS"
		return
	_reset_armed = false
	GameSettings.reset_controls()
	button.text = "RESET CONTROLS TO DEFAULT"
	_status.text = "CONTROLS RESET TO DEFAULT."
	_refresh_all()


func _add_bind(label_text: String, action: String) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(ROW_WIDTH, 0)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(250, 0)
	UITheme.style_body(name_label)
	box.add_child(name_label)

	var row := {"kind": "bind", "node": box, "selectable": true, "sub": 0, "action": action, "buttons": []}
	var buttons: Array = row["buttons"]
	for i in 2:
		var b := Button.new()
		b.custom_minimum_size = Vector2(190, 0)
		b.focus_mode = Control.FOCUS_NONE
		UITheme.style_button(b)
		# REV 108: "LEFT STICK RIGHT" in wide Microgramma overflowed the box - smaller, and clipped
		b.add_theme_font_size_override("font_size", 12)
		b.clip_text = true
		b.pressed.connect(_on_bind_clicked.bind(row, i))
		b.mouse_entered.connect(_select_row.bind(row))
		box.add_child(b)
		buttons.append(b)
	row["press"] = _begin_listen.bind(row)
	row["adjust"] = func(dir: int) -> void:
		row["sub"] = clampi(int(row["sub"]) + dir, 0, 1)
		_update_selection_highlight()
	row["refresh"] = func() -> void:
		var is_listening: bool = not _listening.is_empty() and is_same(_listening["row"], row)
		for i in 2:
			var btn: Button = buttons[i]
			if is_listening and (i == 0) == bool(_listening["key"]):
				btn.text = "PRESS A KEY..." if i == 0 else "PRESS A BUTTON..."
			else:
				btn.text = GameSettings.get_binding_text(action, i == 0)
	_rows_box.add_child(box)
	_rows.append(row)


func _on_bind_clicked(row: Dictionary, sub: int) -> void:
	_select_row(row)
	row["sub"] = sub
	_begin_listen(row)


func _begin_listen(row: Dictionary) -> void:
	_listening = {"row": row, "key": int(row["sub"]) == 0}
	_status.text = "PRESS A %s FOR  %s   (ESC CANCELS, DELETE CLEARS)" % [
		"KEY" if bool(_listening["key"]) else "GAMEPAD BUTTON OR STICK DIRECTION",
		_action_label(String(row["action"]))]
	_refresh_all()
	_update_selection_highlight()


func _stop_listening(message: String = "") -> void:
	_listening = {}
	_status.text = message
	_refresh_all()
	_update_selection_highlight()


func _action_label(action: String) -> String:
	for entry in GameSettings.REBINDABLE_ACTIONS:
		if String(entry[1]) == action:
			return String(entry[0])
	return action


## Runs before everything else, so the next key / button goes to the rebinding
## instead of the menu.
func _input(event: InputEvent) -> void:
	if _listening.is_empty() or not visible:
		return
	var row: Dictionary = _listening["row"]
	var action: String = String(row["action"])
	var want_key: bool = bool(_listening["key"])

	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_stop_listening()   # clicking anywhere else cancels
		return

	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		get_viewport().set_input_as_handled()
		var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
		if code == KEY_ESCAPE:
			_stop_listening("CANCELLED.")
			return
		if not want_key:
			return   # waiting for a gamepad input; ignore the keyboard
		if code == KEY_DELETE or code == KEY_BACKSPACE:
			GameSettings.clear_binding(action, true)
			_stop_listening("CLEARED  %s  (KEYBOARD)." % _action_label(action))
			return
		var bound := InputEventKey.new()
		bound.physical_keycode = code as Key
		_finish_bind(action, true, bound)
		return

	if not want_key:
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
			get_viewport().set_input_as_handled()
			var jb := InputEventJoypadButton.new()
			jb.button_index = (event as InputEventJoypadButton).button_index
			_finish_bind(action, false, jb)
		elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.7:
			get_viewport().set_input_as_handled()
			var jm := InputEventJoypadMotion.new()
			jm.axis = (event as InputEventJoypadMotion).axis
			jm.axis_value = 1.0 if (event as InputEventJoypadMotion).axis_value > 0.0 else -1.0
			_finish_bind(action, false, jm)


func _finish_bind(action: String, want_key: bool, ev: InputEvent) -> void:
	var taken_from: String = GameSettings.set_binding(action, want_key, ev)
	var msg := "%s  =  %s" % [_action_label(action), GameSettings.event_text(ev)]
	if taken_from != "":
		msg += "      (TAKEN FROM  %s)" % taken_from
	_stop_listening(msg)


# =========================================================================
# Row builders
# =========================================================================

func _register(row: Dictionary) -> Dictionary:
	_rows_box.add_child(row["node"])
	_rows.append(row)
	return row


func _add_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(ROW_WIDTH, 0)
	UITheme.style_hint(label)
	_register({"kind": "note", "node": label, "selectable": false})


func _add_button(text: String, callback: Callable) -> Dictionary:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(ROW_WIDTH, 0)
	btn.focus_mode = Control.FOCUS_NONE
	UITheme.style_button(btn)
	if text.contains("[ESC]"):
		InputHints.bind(btn, text.replace("[ESC]", "{menu_cancel}"))   # REV 103
	var row := {"kind": "button", "node": btn, "selectable": true, "press": callback}
	btn.pressed.connect(_on_row_clicked.bind(row))
	btn.mouse_entered.connect(_select_row.bind(row))
	return _register(row)


## A value you step through: LEFT / RIGHT or a click changes it.
## value_fn() -> String shows the current value; step_fn(dir) changes it.
func _add_choice(label_text: String, value_fn: Callable, step_fn: Callable) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(ROW_WIDTH, 0)
	btn.focus_mode = Control.FOCUS_NONE
	UITheme.style_button(btn)
	var row := {"kind": "choice", "node": btn, "selectable": true}
	row["press"] = func() -> void:
		step_fn.call(1)
		_refresh_all()
	row["adjust"] = func(dir: int) -> void:
		step_fn.call(dir)
		_refresh_all()
	row["refresh"] = func() -> void:
		btn.text = "%s:   <  %s  >" % [label_text, String(value_fn.call())]
	btn.pressed.connect(_on_row_clicked.bind(row))
	btn.mouse_entered.connect(_select_row.bind(row))
	_register(row)


## A 0..100 slider: drag it, or LEFT / RIGHT in steps of 5.
## REV 103: optional range, step and value format (default: 0-100 %).
func _add_slider(label_text: String, get_fn: Callable, set_fn: Callable, min_v: int = 0, max_v: int = 100, step_v: int = 5, fmt: String = "%d%%") -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(ROW_WIDTH, 34)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(230, 0)
	UITheme.style_body(name_label)
	box.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.custom_minimum_size = Vector2(300, 28)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	box.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(70, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_body(value_label)
	box.add_child(value_label)

	var row := {"kind": "slider", "node": box, "selectable": true}
	row["refresh"] = func() -> void:
		var v: int = int(get_fn.call())
		slider.set_value_no_signal(v)
		value_label.text = fmt % v
	row["adjust"] = func(dir: int) -> void:
		set_fn.call(clampi(int(get_fn.call()) + dir * step_v, min_v, max_v))
		_refresh_all()
	row["press"] = Callable()
	slider.value_changed.connect(func(v: float) -> void:
		set_fn.call(int(v))
		value_label.text = fmt % int(v))
	slider.drag_started.connect(_select_row.bind(row))
	box.mouse_entered.connect(_select_row.bind(row))
	_register(row)


# =========================================================================
# Navigation
# =========================================================================

func _refresh_all() -> void:
	for row in _rows:
		if row.has("refresh"):
			(row["refresh"] as Callable).call()


func _select_row(row: Dictionary) -> void:
	var i := -1
	for n in _rows.size():
		if is_same(_rows[n], row):
			i = n
			break
	if i >= 0 and i != _selected and _listening.is_empty():
		_selected = i
		_update_selection_highlight()


func _on_row_clicked(row: Dictionary) -> void:
	_select_row(row)
	var press: Callable = row.get("press", Callable())
	if press.is_valid():
		press.call()
		_update_selection_highlight()


func _first_selectable_from(start: int) -> int:
	for i in range(start, _rows.size()):
		if bool(_rows[i]["selectable"]):
			return i
	for i in range(_rows.size()):
		if bool(_rows[i]["selectable"]):
			return i
	return 0


func _move(step: int) -> void:
	if _rows.is_empty():
		return
	var i := _selected
	for _n in _rows.size():
		i = posmod(i + step, _rows.size())
		if bool(_rows[i]["selectable"]):
			_selected = i
			break
	SfxManager.ui("move")
	_update_selection_highlight()


func _adjust(dir: int) -> void:
	if _rows.is_empty():
		return
	var adjust: Callable = _rows[_selected].get("adjust", Callable())
	if adjust.is_valid():
		adjust.call(dir)
		_update_selection_highlight()


func _activate_selected() -> void:
	if _rows.is_empty():
		return
	SfxManager.ui("confirm")
	var press: Callable = _rows[_selected].get("press", Callable())
	if press.is_valid():
		press.call()
		_update_selection_highlight()


func _back() -> void:
	SfxManager.ui("back")
	if not _listening.is_empty():
		_stop_listening("CANCELLED.")
	elif _page != Page.MAIN:
		var from_page := _page
		_show_page(Page.MAIN, 0)
		# Land back on the entry that opened this page. REV 293: found by what it opens, not by
		# counting rows, so adding or moving buttons on the main page can't break it.
		for i in _rows.size():
			if int(_rows[i].get("opens", -1)) == from_page:
				_selected = i
				_update_selection_highlight()
				break
	else:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _rows.is_empty():
		return
	if _save_load != null and _save_load.visible:
		return   # the slot list is handling the keyboard
	if not _listening.is_empty():
		return

	if event.is_action_pressed("ui_navigate_down"):
		_move(1)
	elif event.is_action_pressed("ui_navigate_up"):
		_move(-1)
	elif event.is_action_pressed("ui_left"):
		_adjust(-1)
	elif event.is_action_pressed("ui_right"):
		_adjust(1)
	elif event.is_action_pressed("ui_navigate_confirm"):
		_activate_selected()
	elif event.is_action_pressed("menu_cancel"):
		_back()
	elif not menu_mode and event.is_action_pressed("system_menu_open"):
		close()      # REV 105: the same key/button that opened the pause menu closes it
	else:
		return
	get_viewport().set_input_as_handled()


func _update_selection_highlight() -> void:
	for i in range(_rows.size()):
		var row: Dictionary = _rows[i]
		if not bool(row["selectable"]):
			continue
		var is_sel: bool = i == _selected
		(row["node"] as Control).modulate = Color.WHITE if is_sel else SELECTED_NAV_COLOR
		if String(row["kind"]) == "bind":
			var buttons: Array = row["buttons"]
			for b in buttons.size():
				UITheme.style_button(buttons[b], is_sel and int(row["sub"]) == b)
	if _selected >= 0 and _selected < _rows.size():
		_ensure_visible.call_deferred(_rows[_selected]["node"])


func _ensure_visible(node: Control) -> void:
	if is_instance_valid(node) and _scroll != null and node.is_inside_tree():
		_scroll.ensure_control_visible(node)


func _fit_panel() -> void:
	# Size the scroll area to its content, but never taller than the screen can
	# hold; long pages (CONTROLS) then scroll.
	var viewport_size: Vector2 = get_viewport_rect().size
	var content_h: float = _rows_box.get_combined_minimum_size().y
	var max_h: float = maxf(viewport_size.y * 0.62, 240.0)
	_scroll.custom_minimum_size = Vector2(PANEL_WIDTH, minf(content_h + 4.0, max_h))
	var content_size: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = content_size
	_panel.position = (viewport_size - content_size) / 2.0


## Two presses: the first arms it (and warns), the second leaves the game.
func _on_main_menu_pressed(button: Button) -> void:
	if not _leave_armed:
		_leave_armed = true
		button.text = "PRESS AGAIN: UNSAVED PROGRESS IS LOST"
		return
	_leave_armed = false
	_paused_it = false
	SaveSystem.return_to_main_menu(MAIN_MENU_SCENE)    # (it unpauses)


## Same two-press guard, then the game closes.
func _on_quit_desktop_pressed(button: Button) -> void:
	if not _quit_armed:
		_quit_armed = true
		button.text = "PRESS AGAIN TO QUIT: UNSAVED PROGRESS IS LOST"
		return
	get_tree().quit()
