extends Control
class_name FullMapScreen
## FullMapScreen (REV 29) - the whole floor plan of the room's map, opened with M or the MAP button.
## It reuses the procedural floor plan the minimap is drawn from (ModelRoom.get_full_map_data()).
## On opening, the complete plan is fitted to the window. Wheel zooms (around the pointer), a left-button
## drag pans, RE-CENTRE puts the view back on the player. M, Escape or the close button shut it.
## A modal like the inventory: HUD suspends interaction while it is up. No quest or point-of-interest markers yet.

const RING_COLOR := Color(0.831, 0.686, 0.216)
const BACK_COLOR := Color(0.01, 0.03, 0.07, 0.94)
const MAP_BACK := Color(0.02, 0.06, 0.10, 1.0)
const GRID := Color(0.40, 0.78, 1.0, 0.07)
const TEXT_COLOR := Color(0.87, 0.86, 0.82)
const MARKER_COLOR := Color(0.98, 0.85, 0.40)
const MAX_PX_PER_METRE := 28.0

var _view: Control
var _title: Label
var _hint: Label
var _msg: Label
var _recentre: Button
var _close: Button
var _marker_box: CheckBox
var _tex: Texture2D = null
var _origin := Vector2.ZERO          # world (x, z) of the picture's top-left
var _ppm: float = 8.0                # picture pixels per metre
var _bounds := Rect2()
var _zoom: float = 4.0               # screen pixels per metre
var _fit_zoom: float = 4.0
var _centre := Vector2.ZERO          # world point at the middle of the map window
var _dragging := false
var _player: Node3D = null
var _clock: float = 0.0
var _frozen: Array = []
## REV 804: room names drawn as text, and the player's own notes (MapNotes)
var _labels: Array = []
var _map_id := ""
var _editor: PanelContainer = null
var _edit_line: LineEdit = null
var _edit_delete: Button = null
var _edit_index := -1                # the note being changed (-1 = a new one)
var _edit_pos := Vector2.ZERO        # world x,z of a new note


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_view = Control.new()
	_view.name = "MapView"
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_map)
	_view.gui_input.connect(_on_view_input)
	add_child(_view)

	_title = Label.new()
	UITheme.style_title(_title)
	add_child(_title)

	_hint = Label.new()
	UITheme.style_hint(_hint)
	_hint.text = "WHEEL: ZOOM      DRAG: PAN      RIGHT-CLICK: ADD / CHANGE A NOTE      M / ESC: CLOSE"
	add_child(_hint)

	_msg = Label.new()
	UITheme.style_hint(_msg)
	_msg.text = "NO CHART OF THIS AREA IS AVAILABLE"
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_msg)

	_recentre = Button.new()
	UITheme.style_function_button(_recentre, "RE-CENTRE", "", false)
	_recentre.custom_minimum_size = Vector2(110, 34)
	_recentre.pressed.connect(_centre_on_player)
	add_child(_recentre)

	# REV 741 (Glen: 'On the map, a checkbox "Show Map Objective Marker"')
	_marker_box = CheckBox.new()
	_marker_box.text = "SHOW MAP OBJECTIVE MARKER"
	_marker_box.button_pressed = GameSettings.objective_marker
	_marker_box.add_theme_font_size_override("font_size", 14)
	_marker_box.add_theme_color_override("font_color", UITheme.GOLD)
	_marker_box.toggled.connect(func(on: bool) -> void:
		GameSettings.set_objective_marker(on)
		_view.queue_redraw())
	add_child(_marker_box)

	_close = Button.new()
	UITheme.style_function_button(_close, "CLOSE", "[M]", false)
	var close_kb := _close.find_child("KeybindLabel", true, false) as Label
	if close_kb != null:
		InputHints.bind(close_kb, "{map_open}")
	_close.custom_minimum_size = Vector2(90, 34)
	_close.pressed.connect(close)
	add_child(_close)
	_build_editor()
	get_viewport().size_changed.connect(_layout)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible:
		return
	_player = PlayerController.current(get_tree())
	_tex = null
	_labels = []
	_map_id = ""
	var src := get_tree().get_first_node_in_group("minimap_source")
	if src != null and src.has_method("get_full_map_data"):
		var data: Dictionary = src.get_full_map_data()
		_tex = data.get("texture")
		if _tex != null:
			_origin = data.get("origin", Vector2.ZERO)
			_ppm = float(data.get("px_per_metre", 8.0))
			_bounds = data.get("bounds", Rect2())
			_labels = data.get("labels", [])
			_map_id = MapNotes.map_id(data)
			var deck_n: int = int(data.get("deck", -1))
			var room_name: String = String(data.get("room_name", ""))
			_title.text = ("DECK %d   -   %s" % [deck_n, room_name.to_upper()]) if deck_n >= 0 else room_name.to_upper()
	if _tex == null:
		_title.text = "SHIP'S CHART"
	_msg.visible = _tex == null
	CircularMinimapFrame.modal_open = true
	# gameplay input is suspended while the map is up
	_frozen.clear()
	for n in get_tree().get_nodes_in_group("player"):
		if n is PlayerController and (n as PlayerController).input_enabled:
			(n as PlayerController).input_enabled = false
			_frozen.append(n)
	visible = true
	_layout()
	_fit()
	SfxManager.ui("open")
	_view.queue_redraw()


func close() -> void:
	if not visible:
		return
	_close_editor()
	visible = false
	_dragging = false
	CircularMinimapFrame.modal_open = false
	for n in _frozen:
		if is_instance_valid(n):
			(n as PlayerController).input_enabled = true
	_frozen.clear()
	SfxManager.ui("close")


func _layout() -> void:
	if _view == null:
		return
	var v := get_viewport_rect().size
	var pad := 28.0
	_view.position = Vector2(pad, 64.0)
	_view.size = Vector2(maxf(v.x - pad * 2.0, 100.0), maxf(v.y - 64.0 - 52.0, 100.0))
	_title.position = Vector2(pad, 16.0)
	_hint.position = Vector2(pad, v.y - 36.0)
	_close.position = Vector2(v.x - pad - 90.0, 14.0)
	_recentre.position = Vector2(v.x - pad - 90.0 - 10.0 - 110.0, 14.0)
	if _marker_box != null:
		_marker_box.position = Vector2(_recentre.position.x - 10.0 - 290.0, 16.0)
		_marker_box.size = Vector2(290.0, 30.0)
	_msg.position = _view.position + Vector2(0.0, _view.size.y * 0.5 - 10.0)
	_msg.size = Vector2(_view.size.x, 20.0)
	if _tex != null and visible:
		_view.queue_redraw()
	queue_redraw()


## Fits the complete plan into the window.
func _fit() -> void:
	if _tex == null or _bounds.size.x <= 0.0:
		return
	_fit_zoom = minf((_view.size.x - 24.0) / _bounds.size.x, (_view.size.y - 24.0) / _bounds.size.y)
	_zoom = _fit_zoom
	_centre = _bounds.position + _bounds.size * 0.5
	_view.queue_redraw()


func _centre_on_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_centre = Vector2(_player.global_position.x, _player.global_position.z)
	_zoom = clampf(maxf(_zoom, _fit_zoom * 3.0), _fit_zoom * 0.5, MAX_PX_PER_METRE)
	_view.queue_redraw()


func _to_screen(world: Vector2) -> Vector2:
	return _view.size * 0.5 + (world - _centre) * _zoom


func _to_world(screen: Vector2) -> Vector2:
	return _centre + (screen - _view.size * 0.5) / _zoom


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	_player = PlayerController.current(get_tree())     # REV 772: whoever you're playing now
	_view.queue_redraw()   # the marker follows the player while the map is open


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _editor != null and _editor.visible:
		# typing a note: M is just a letter, Escape only shuts the note box
		if event.is_action_pressed("ui_cancel"):
			_close_editor()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("map_open") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_view_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and _tex != null:
			_open_editor(mb.position)
			accept_event()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var before := _to_world(mb.position)
			var f := 1.18 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.18
			_zoom = clampf(_zoom * f, _fit_zoom * 0.5, MAX_PX_PER_METRE)
			# keep the point under the pointer where it was
			_centre += before - _to_world(mb.position)
			accept_event()
			_view.queue_redraw()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _dragging:
		_centre -= mm.relative / _zoom
		accept_event()
		_view.queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var v := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, v), BACK_COLOR, true)
	# the frame round the map window
	var r := Rect2(_view.position - Vector2(3, 3), _view.size + Vector2(6, 6))
	draw_rect(r, RING_COLOR, false, 2.0)


func _draw_map() -> void:
	_view.draw_rect(Rect2(Vector2.ZERO, _view.size), MAP_BACK, true)
	if _tex == null:
		return
	# a faint 10 m graph paper under the plan
	var step := 10.0 * _zoom
	if step > 14.0:
		var wx := ceilf(_to_world(Vector2.ZERO).x / 10.0) * 10.0
		while _to_screen(Vector2(wx, 0.0)).x < _view.size.x:
			var sx := _to_screen(Vector2(wx, 0.0)).x
			_view.draw_line(Vector2(sx, 0.0), Vector2(sx, _view.size.y), GRID, 1.0)
			wx += 10.0
		var wz := ceilf(_to_world(Vector2.ZERO).y / 10.0) * 10.0
		while _to_screen(Vector2(0.0, wz)).y < _view.size.y:
			var sy := _to_screen(Vector2(0.0, wz)).y
			_view.draw_line(Vector2(0.0, sy), Vector2(_view.size.x, sy), GRID, 1.0)
			wz += 10.0
	var tsize := Vector2(_tex.get_width(), _tex.get_height()) / _ppm * _zoom
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_view.draw_texture_rect(_tex, Rect2(_to_screen(_origin), tsize), false)
	# REV 804: room names, then the player's notes
	var grow := clampf(_zoom / maxf(_fit_zoom, 0.001), 1.0, 1.7)
	for l in _labels:
		var at := _to_screen(l[0] as Vector2)
		if Rect2(Vector2.ZERO, _view.size).grow(60.0).has_point(at):
			MapNotes.draw_text(_view, at, String(l[1]), int(clampf(float(l[2]) * 0.9 * grow, 9.0, 24.0)), MapNotes.LABEL_COLOUR)
	if not _map_id.is_empty():
		var i := 0
		for n in MapNotes.notes(_map_id):
			if not (_editor.visible and i == _edit_index):
				MapNotes.draw_note(_view, _to_screen(n["pos"] as Vector2), String(n["text"]), 14)
			i += 1
	# the player: a gold arrow that points the way they face, with a slow ring round it
	if _player != null and is_instance_valid(_player):
		var p := _to_screen(Vector2(_player.global_position.x, _player.global_position.z))
		var ang := PI - _player.rotation.y
		var pulse := 0.5 + 0.5 * sin(_clock * 3.0)
		_view.draw_arc(p, 12.0 + 4.0 * pulse, 0.0, TAU, 32, Color(MARKER_COLOR.r, MARKER_COLOR.g, MARKER_COLOR.b, 0.55 - 0.3 * pulse), 1.5, true)
		var pts := PackedVector2Array([Vector2(0, -9), Vector2(-6, 7), Vector2(0, 3), Vector2(6, 7)])
		_view.draw_colored_polygon(Transform2D(ang, p) * pts, MARKER_COLOR)
		_view.draw_polyline(PackedVector2Array([Transform2D(ang, p) * pts[0], Transform2D(ang, p) * pts[1], Transform2D(ang, p) * pts[2], Transform2D(ang, p) * pts[3], Transform2D(ang, p) * pts[0]]), Color(0.1, 0.07, 0.0), 1.2, true)
	# REV 741 (item 6): the objective (or the lift to it)
	var t := ObjectiveMarker.target(get_tree())
	if not t.is_empty():
		var w: Vector3 = t["pos"]
		var at := _to_screen(Vector2(w.x, w.z))
		var inside := Rect2(Vector2.ZERO, _view.size).grow(-14.0)
		if inside.has_point(at):
			ObjectiveMarker.draw(_view, at, bool(t["lift"]), 1.4)
		else:
			var c := _view.size * 0.5
			var dir := (at - c).normalized()
			ObjectiveMarker.draw_edge_arrow(_view, c, minf(c.x, c.y) - 6.0, dir, bool(t["lift"]))


# =========================================================================
# REV 804: the player's own notes
# =========================================================================

func _build_editor() -> void:
	_editor = PanelContainer.new()
	_editor.name = "NoteEditor"
	UITheme.style_panel(_editor)
	_editor.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_editor.add_child(box)
	var head := Label.new()
	UITheme.style_hint(head)
	head.text = "MAP NOTE  (ENTER = SAVE, ESC = CANCEL)"
	box.add_child(head)
	_edit_line = LineEdit.new()
	_edit_line.custom_minimum_size = Vector2(320, 32)
	_edit_line.max_length = 80
	_edit_line.placeholder_text = "Type your note..."
	_edit_line.text_submitted.connect(func(_t: String) -> void: _save_note())
	box.add_child(_edit_line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var save := Button.new()
	UITheme.style_function_button(save, "SAVE", "", false)
	save.custom_minimum_size = Vector2(90, 30)
	save.pressed.connect(_save_note)
	row.add_child(save)
	_edit_delete = Button.new()
	UITheme.style_function_button(_edit_delete, "DELETE", "", false)
	_edit_delete.custom_minimum_size = Vector2(100, 30)
	_edit_delete.pressed.connect(func() -> void:
		if _edit_index >= 0:
			MapNotes.set_text(_map_id, _edit_index, "")
		_close_editor())
	row.add_child(_edit_delete)
	var cancel := Button.new()
	UITheme.style_function_button(cancel, "CANCEL", "", false)
	cancel.custom_minimum_size = Vector2(100, 30)
	cancel.pressed.connect(_close_editor)
	row.add_child(cancel)
	add_child(_editor)


## Right-click on the map: change the note under the pointer, or start a new one there.
func _open_editor(screen: Vector2) -> void:
	if _map_id.is_empty():
		return
	var world := _to_world(screen)
	_edit_index = MapNotes.nearest(_map_id, world, 14.0 / maxf(_zoom, 0.001))
	_edit_pos = world
	if _edit_index >= 0:
		var n: Dictionary = MapNotes.notes(_map_id)[_edit_index]
		_edit_line.text = String(n["text"])
		_edit_pos = n["pos"]
	else:
		_edit_line.text = ""
	_edit_delete.visible = _edit_index >= 0
	_editor.visible = true
	_editor.reset_size()
	var at := _view.position + _to_screen(_edit_pos) + Vector2(16, 8)
	var v := get_viewport_rect().size
	_editor.position = Vector2(clampf(at.x, 8.0, v.x - _editor.size.x - 8.0), clampf(at.y, 8.0, v.y - _editor.size.y - 8.0))
	_edit_line.grab_focus()
	_edit_line.caret_column = _edit_line.text.length()
	_view.queue_redraw()


func _save_note() -> void:
	var t := _edit_line.text.strip_edges()
	if _edit_index >= 0:
		MapNotes.set_text(_map_id, _edit_index, t)
	elif not t.is_empty():
		MapNotes.add(_map_id, _edit_pos, t)
	_close_editor()


func _close_editor() -> void:
	if _editor == null or not _editor.visible:
		return
	_editor.visible = false
	_edit_line.release_focus()
	_edit_index = -1
	_view.queue_redraw()
