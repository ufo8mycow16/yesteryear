extends CanvasLayer
## DevMenu — a developer-only panel for testing. Press F9 to open or close it.
## It only works in the Godot editor and debug runs (it is switched off in a
## release export), so players never see it.
##
##   JUMP TO SCENE   pick any scene in the game and go straight there
##   VARIABLES       read or change a game variable (e.g. VAR_PRO_HAS_BOWLING_BALL = true)
##   TOOLS           give the bowling ball, unlock every collector card, skip the line playing
##
## Jumping straight into an episode scene skips whatever set-up the earlier
## scenes did, so a scene may need a variable or two set first.

const SCENE_FOLDERS := ["res://episodes/", "res://core/menu/", "res://core/ui/cutscene/"]

var _root: Control
var _scene_list: OptionButton
var _scene_paths: Array[String] = []
var _var_name: LineEdit
var _var_value: LineEdit
var _status: Label
var _info: Label
var _clue_id: LineEdit
var _teleport_xyz: LineEdit


func _ready() -> void:
	if not OS.is_debug_build():
		set_process_unhandled_input(false)
		return
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var panel := PanelContainer.new()
	UITheme.style_panel(panel)
	panel.position = Vector2(20, 20)
	_root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(520, 0)
	panel.add_child(col)

	var title := Label.new()
	title.text = "DEVELOPER MENU   (F9 CLOSES)"
	UITheme.style_title(title)
	col.add_child(title)
	_info = Label.new()
	UITheme.style_dim(_info)
	col.add_child(_info)
	col.add_child(UITheme.make_separator())

	col.add_child(_heading("JUMP TO SCENE"))
	_scene_list = OptionButton.new()
	_scene_list.fit_to_longest_item = false
	_scene_list.custom_minimum_size = Vector2(500, 0)
	col.add_child(_scene_list)
	col.add_child(_button("GO TO SELECTED SCENE", _jump))

	col.add_child(_heading("VARIABLES"))
	var row := HBoxContainer.new()
	col.add_child(row)
	_var_name = LineEdit.new()
	_var_name.placeholder_text = "VARIABLE NAME"
	_var_name.custom_minimum_size = Vector2(300, 0)
	row.add_child(_var_name)
	_var_value = LineEdit.new()
	_var_value.placeholder_text = "VALUE"
	_var_value.custom_minimum_size = Vector2(120, 0)
	row.add_child(_var_value)
	var row2 := HBoxContainer.new()
	col.add_child(row2)
	row2.add_child(_button("READ", _read_var))
	row2.add_child(_button("SET", _set_var))

	col.add_child(_heading("INVESTIGATION / WORLD"))
	var clue_row := HBoxContainer.new()
	col.add_child(clue_row)
	_clue_id = LineEdit.new()
	_clue_id.placeholder_text = "CLUE ID (e.g. PRO_LANE)"
	_clue_id.custom_minimum_size = Vector2(300, 0)
	clue_row.add_child(_clue_id)
	clue_row.add_child(_button("GRANT", _grant_clue))
	col.add_child(_button("DUMP GAME / WORLD / INVESTIGATION STATE", _dump_state))

	col.add_child(_heading("PLAYER"))
	var tp_row := HBoxContainer.new()
	col.add_child(tp_row)
	_teleport_xyz = LineEdit.new()
	_teleport_xyz.placeholder_text = "X, Y, Z"
	_teleport_xyz.custom_minimum_size = Vector2(300, 0)
	tp_row.add_child(_teleport_xyz)
	tp_row.add_child(_button("TELEPORT", _teleport_player))

	col.add_child(_heading("TOOLS"))
	col.add_child(_button("GIVE BOWLING BALL", _give_ball))
	col.add_child(_button("UNLOCK ALL COLLECTOR CARDS", _unlock_cards))
	col.add_child(_button("SKIP THE LINE THAT IS PLAYING", AudioSubtitleManager.skip_current_line))
	col.add_child(_button("DEBUG INFO ON / OFF  [F3]", func() -> void: GameSettings.set_debug_overlay(not GameSettings.debug_overlay)))

	_status = Label.new()
	UITheme.style_hint(_status)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	UITheme.style_heading(l)
	return l


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	UITheme.style_button(b)
	b.pressed.connect(callback)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_menu"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	_root.visible = not _root.visible
	if _root.visible:
		_refresh_scenes()
		_update_info()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	if _root != null and _root.visible:
		_update_info()


func _update_info() -> void:
	var scene := get_tree().current_scene
	var where := String(scene.scene_file_path) if scene != null else "(none)"
	_info.text = "%d FPS    %s" % [Engine.get_frames_per_second(), where]


func _refresh_scenes() -> void:
	_scene_paths.clear()
	for folder in SCENE_FOLDERS:
		_collect(folder)
	_scene_paths.sort()
	_scene_list.clear()
	for p in _scene_paths:
		_scene_list.add_item(p.trim_prefix("res://"))


func _collect(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect(folder.path_join(sub))
	for f in dir.get_files():
		var name_clean := f.trim_suffix(".remap")
		if name_clean.ends_with(".tscn"):
			_scene_paths.append(folder.path_join(name_clean))


func _jump() -> void:
	var i := _scene_list.selected
	if i < 0 or i >= _scene_paths.size():
		return
	var path := _scene_paths[i]
	_root.visible = false
	get_tree().paused = false
	InteractionManager.reset_for_load()
	AudioSubtitleManager.stop_all()
	DialogueManager.reset()
	get_tree().change_scene_to_file(path)


func _parse(text: String) -> Variant:
	var t := text.strip_edges()
	if t.to_lower() == "true":
		return true
	if t.to_lower() == "false":
		return false
	if t.is_valid_int():
		return int(t)
	if t.is_valid_float():
		return float(t)
	return t


func _read_var() -> void:
	var n := _var_name.text.strip_edges()
	if not GameState.has_var(n):
		_status.text = "%s: NOT DEFINED" % n
		return
	_status.text = "%s = %s" % [n, str(GameState.get_var(n))]


func _set_var() -> void:
	var n := _var_name.text.strip_edges()
	if n == "":
		return
	GameState.set_var(n, _parse(_var_value.text))
	_status.text = "SET %s = %s" % [n, str(GameState.get_var(n))]


func _give_ball() -> void:
	var ball := InventoryItemData.new()
	ball.id = "INV_PRO_001"
	ball.display_name = "Bowling Ball"
	ball.description = "A regulation Starfleet bowling ball."
	var added := InventoryManager.add_item(ball)
	GameState.set_var("VAR_PRO_HAS_BOWLING_BALL", true)
	_status.text = "BOWLING BALL ADDED" if added else "ALREADY HAVE THE BOWLING BALL"


func _unlock_cards() -> void:
	for card in CollectorCards.CARDS:
		CollectorCards.unlock(String(card["id"]))
	_status.text = "ALL COLLECTOR CARDS UNLOCKED"


func _grant_clue() -> void:
	var id := _clue_id.text.strip_edges()
	if id == "": return
	if not Case.is_defined(id):
		_status.text = "CLUE NOT DEFINED IN CURRENT CASE: " + id
		return
	_status.text = ("GRANTED " if Case.add(id) else "ALREADY KNOWN ") + id


func _dump_state() -> void:
	print("=== VF QA STATE ===")
	print("GameState: ", GameState.get_snapshot())
	print("WorldState: ", WorldState.snapshot())
	print("Investigation rules: ", InvestigationSystem.debug_rules())
	print("Active companion: ", CompanionManager.active_id)
	_status.text = "STATE DUMPED TO DEBUG OUTPUT"


func _teleport_player() -> void:
	var parts := _teleport_xyz.text.replace(" ", "").split(",")
	if parts.size() != 3 or not parts[0].is_valid_float() or not parts[1].is_valid_float() or not parts[2].is_valid_float():
		_status.text = "USE X, Y, Z"
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		_status.text = "NO ACTIVE PLAYER NODE"
		return
	player.global_position = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	_status.text = "TELEPORTED TO " + str(player.global_position)
