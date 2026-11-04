extends CanvasLayer
## BuildInfo — the revision number of this copy of the game, shown small in the
## bottom-right corner of every screen, so a screenshot says which update it is.
##
## Every update zip bumps REVISION (and the note) here, and adds a line to
## REVISIONS.md. A screenshot with no number on it is from before revision 1.

const REVISION := 883
const BUILT := "2026-11-05"
const NOTE := "Glen's World Creator desert basin round the city edge, waystation, desert search and ruins"
const KeyList := preload("res://core/ui/KeyListPanel.gd")

var _where: Label
var _timer := 0.0
## REV 102: F3 shows frames per second next to the revision number (any build), for checking
## how heavy rooms run. And a small "SAVING" badge whenever the game autosaves.
var _rev_label: Label
var _show_fps := false
var _saving: Label
## REV 165: the shortcut list - every key the game uses, read from the live bindings - shown under the
## room/coordinates block while the F3 overlay is on (debug builds), in any scene where you control someone.
var _keys: PanelContainer
## REV 525 (Glen: "a message box that tells me exactly what the next step is"): F8 in debug builds shows
## a box, top middle, with the current room's debug_next_step() - the next puzzle step, where it is, and
## what's blocking it. Rooms opt in by adding debug_next_step() -> String (the Arena first).
var _next_box: PanelContainer
var _next_label: Label
var _show_next := false


## Room name and map coordinates (player and camera) in the top-left, so a screenshot says exactly where it was taken.
func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.15
	# REV 144: in debug builds F3 (also SYSTEM > GRAPHICS and the F9 developer menu) switches the whole
	# info overlay - FPS plus the room/coordinates block - and the choice is remembered. Release builds
	# keep F3 as the plain FPS counter and never show coordinates.
	var overlay: bool = GameSettings.debug_overlay if OS.is_debug_build() else _show_fps
	if _rev_label != null:
		var base := "REV %d  -  %s" % [REVISION, BUILT]
		# REV 681: when dynamic resolution has shrunk the 3D picture, say how far ("3D 85%")
		var dyn := GameSettings.dynamic_scale()
		var fps := "%d FPS   " % Engine.get_frames_per_second()
		if dyn < 0.995:
			fps = "%d FPS  3D %d%%   " % [Engine.get_frames_per_second(), roundi(dyn * 100.0)]
		_rev_label.text = (fps + base) if overlay else base
	_update_next_step()
	if not (overlay and OS.is_debug_build()):
		_where.text = ""
		_keys.hide()
		return
	# keep the debug block out of the way of the pause menu and other full screens
	var hud := get_tree().get_first_node_in_group("hud")
	# ...and out of cinematics and conversations (the HUD is hidden then), where it ran into the
	# letterbox subtitles at the top of the screen
	if get_tree().paused or (hud != null and not (hud as CanvasItem).is_visible_in_tree()) \
			or (hud != null and hud.has_method("is_any_panel_open") and bool(hud.call("is_any_panel_open"))) \
			or PhotoMode.active:
		_where.text = ""
		_keys.hide()
		return
	var scene := get_tree().current_scene
	if scene == null:
		_where.text = ""
	elif scene.has_method("debug_where"):
		_where.text = String(scene.call("debug_where"))
	else:
		_where.text = _generic_where(scene)
	_update_keys(scene)


func _update_keys(scene: Node) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if scene == null or player == null or scene.has_method("has_own_key_list") \
			or ("input_enabled" in player and not bool(player.get("input_enabled"))):
		_keys.hide()
		return
	_keys.call("set_rows", _game_key_rows(scene, player))
	var top := _where.position.y + (_where.get_minimum_size().y + 10.0 if _where.text != "" else 0.0)
	_keys.position = Vector2(12.0, roundf(top))
	_keys.show()


## Every key in the game, from the live input map (so rebinding shows here), plus the debug keys and
## any the current room adds with debug_keys(). Gamepad players see their buttons instead.
func _game_key_rows(scene: Node, player: Node) -> Array:
	var pad := InputHints.using_gamepad
	var rows: Array = [["# MOVING"]]
	var move: Array[String] = []
	for a in ["move_forward", "move_left", "move_back", "move_right"]:
		var k := InputHints.key(a)
		if k != "" and not move.has(k):
			move.append(k)
	rows.append([" ".join(move), "Move"])
	rows.append([InputHints.key("run"), "Run (hold)"])
	if not pad:
		rows.append(["RIGHT-DRAG", "Turn the camera"])
	var ql := InputHints.key("camera_orbit_left")
	var qr := InputHints.key("camera_orbit_right")
	rows.append([(ql + " / " + qr) if ql != "" and qr != "" else ql + qr, "Turn the camera"])
	if not pad:
		rows.append(["MOUSE WHEEL", "Zoom"])
		rows.append(["BOTH BUTTONS", "Walk forward"])
	rows.append(["# DEBUG"])
	rows.append(["F3", "Hide this list and read-out"])
	rows.append(["F8", "Next step box" + ("  (ON)" if _show_next else "")])
	rows.append([InputHints.key("dev_menu"), "Developer menu"])
	rows.append(["F7", "Lighting: classic / enhanced"])
	var flying := bool(player.get("flying")) if "flying" in player else false
	rows.append(["SHIFT + F", "Fly through walls" + ("  (ON)" if flying else "")])
	if flying:
		rows.append(["R / PAGE UP", "Fly up"])
		rows.append(["V / PAGE DOWN", "Fly down"])
	if scene.has_method("debug_keys"):
		rows.append_array(scene.call("debug_keys"))
	rows.append(["# ACTIONS"])
	for pair in [["interact", "Interact / confirm"], ["highlight_hotspots", "Show hotspots + mission (hold)"],
			["switch_character", _switch_label(scene)], ["inventory_open", "Inventory"],
			["mission_log_open", "Mission log"], ["case_file_open", "Case file"], ["map_open", "Map"],
			["dialogue_history_open", "Dialogue history"], ["collection_open", "Collection"],
			["photo_mode", "Photo mode"], ["phaser_toggle", "Phaser: draw / holster"], ["sit_floor", "Sit on the floor / get up"], ["system_menu_open", "System menu"],
			["quick_save", "Quick save"], ["quick_load", "Quick load"], ["toggle_fullscreen", "Fullscreen"]]:
		rows.append([InputHints.key(String(pair[0])), String(pair[1])])
	if not pad:
		rows.append(["ESC", "Pause / back"])
	return rows


## REV 741 (Glen's bug list item 2): the TAB line names whoever is actually on the team ("Switch Kyle / Scott"),
## not always Kirk / McCoy; rooms with no switching say so.
func _switch_label(scene: Node) -> String:
	if scene != null and scene.has_method("lead_name"):
		if "allow_switching" in scene and not bool(scene.get("allow_switching")):
			return "Switch character (not here)"
		return "Switch %s / %s" % [String(scene.call("lead_name", "kirk")), String(scene.call("lead_name", "mccoy"))]
	return "Switch character"


## REV 144: rooms without their own debug_where() (the bowling alley and most others) used to show
## nothing at all. This works for any scene: room name, player and camera position, which way the
## camera faces, and the lighting in force.
func _generic_where(scene: Node) -> String:
	var lines: Array[String] = []
	lines.append("ROOM %s   (%s)" % [GameNames.room_of(scene), scene.scene_file_path.get_file()])
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var p := player.global_position
		lines.append("PLAYER  x %.2f  y %.2f  z %.2f" % [p.x, p.y, p.z])
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var c := cam.global_position
		lines.append("CAMERA  x %.2f  y %.2f  z %.2f" % [c.x, c.y, c.z])
		var f := -cam.global_transform.basis.z
		lines.append("FACING  %d" % ((roundi(rad_to_deg(atan2(-f.z, f.x))) + 360) % 360))
	lines.append("LIGHT  %s   quality %s   (F7 compares)" % [
		"ENHANCED" if GameSettings.enhanced_lighting else "CLASSIC",
		String(GameSettings.PRESET_NAMES[GameSettings.quality_preset])])
	var ml := get_tree().get_first_node_in_group("modern_lighting")    # REV 552: the alley's brightness dial ([ / ])
	if ml != null and ml.has_method("dial") and float(ml.call("dial")) > 0.0:
		lines[lines.size() - 1] += "   MODERN x%.2f ([ / ])" % float(ml.call("dial"))
		var off := String(ml.call("effects_text")) if ml.has_method("effects_text") else ""
		lines.append("EFFECTS  Ctrl+1 SSR  2 SDFGI  3 SSIL  4 SSAO  5 FOG  6 GLOW  7 BLUR   " + off)
	return "\n".join(lines)


func _ready() -> void:
	# REV 116: exported-build self test (tools/qa/export_smoke.gd), only when asked for
	if OS.get_cmdline_user_args().has("--export-smoke") and ResourceLoader.exists("res://tools/qa/export_smoke.gd"):
		var smoke: Node = load("res://tools/qa/export_smoke.gd").new()
		get_tree().root.add_child.call_deferred(smoke)
	if OS.is_debug_build():
		Ep1ContentAudit.validate_once()
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	var label := Label.new()
	label.text = "REV %d  -  %s" % [REVISION, BUILT]
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8, 0.75))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# REV 749 (Glen's list, "maybe later": the REV / FPS line sat over the SYSTEM button) - top centre now, clear of
	# the HUD's corners (minimap top right, functions bottom right, the speaker bottom left)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.offset_left = -200.0
	label.offset_right = 200.0
	label.offset_top = 2.0
	label.offset_bottom = 18.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	_rev_label = label
	_saving = Label.new()
	_saving.text = "SAVING"
	_saving.add_theme_font_size_override("font_size", 11)
	_saving.add_theme_color_override("font_color", Color(0.83, 0.69, 0.22))
	_saving.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_saving.add_theme_constant_override("outline_size", 4)
	_saving.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_saving.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_saving.offset_left = -120.0
	_saving.offset_right = -16.0
	_saving.offset_top = 14.0
	_saving.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_saving.modulate.a = 0.0
	add_child(_saving)
	_where = Label.new()
	_where.add_theme_font_size_override("font_size", 12)
	_where.add_theme_color_override("font_color", Color(0.95, 0.95, 0.7, 0.9))
	_where.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_where.add_theme_constant_override("outline_size", 4)
	_where.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_where.position = Vector2(12, 54)
	add_child(_where)
	_keys = KeyList.new()
	_keys.font_size = 10
	_keys.max_rows_per_column = 12
	_keys.hide()
	add_child(_keys)
	_build_next_box()
	set_process(true)


func _build_next_box() -> void:
	_next_box = PanelContainer.new()
	_next_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.03, 0.88)
	sb.border_color = Color(0.95, 0.8, 0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	_next_box.add_theme_stylebox_override("panel", sb)
	_next_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_next_box.offset_top = 118.0
	_next_box.hide()
	add_child(_next_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_box.add_child(col)
	var head := Label.new()
	head.text = "NEXT STEP  (DEBUG - F8 HIDES)"
	head.add_theme_font_size_override("font_size", 11)
	head.add_theme_color_override("font_color", Color(0.95, 0.8, 0.2))
	col.add_child(head)
	_next_label = Label.new()
	_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_label.custom_minimum_size = Vector2(560, 0)
	_next_label.add_theme_font_size_override("font_size", 14)
	_next_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.9))
	_next_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_next_label.add_theme_constant_override("outline_size", 3)
	col.add_child(_next_label)


func _update_next_step() -> void:
	if _next_box == null:
		return
	if not (_show_next and OS.is_debug_build()):
		_next_box.hide()
		return
	var scene := get_tree().current_scene
	var t := ""
	if scene != null and scene.has_method("debug_next_step"):
		t = String(scene.call("debug_next_step"))
	elif scene != null:
		t = "This room doesn't list its next step yet (no debug_next_step())."
	if t == "":
		_next_box.hide()
		return
	_next_label.text = t
	_next_box.show()
	var w := _next_box.get_combined_minimum_size()
	_next_box.offset_left = -w.x * 0.5
	_next_box.offset_right = w.x * 0.5


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F8 and OS.is_debug_build():
		_show_next = not _show_next
		_timer = 0.0
		get_viewport().set_input_as_handled()
		return
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F3:
		if OS.is_debug_build():
			GameSettings.set_debug_overlay(not GameSettings.debug_overlay)
		else:
			_show_fps = not _show_fps
		_timer = 0.0
		get_viewport().set_input_as_handled()


## A small gold "SAVING" in the top-right corner that pulses and fades (called on every save).
func flash_saving() -> void:
	if _saving == null:
		return
	var tw := create_tween()
	tw.tween_property(_saving, "modulate:a", 1.0, 0.15)
	tw.tween_property(_saving, "modulate:a", 0.45, 0.3)
	tw.tween_property(_saving, "modulate:a", 1.0, 0.3)
	tw.tween_interval(0.6)
	tw.tween_property(_saving, "modulate:a", 0.0, 0.4)
