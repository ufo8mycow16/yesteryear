extends Control
class_name AimChoiceMenu
## Authored-choice menu for PUZ_PRO_002's bowling aim (and reusable for any future "pick one of N
## authored options" puzzle beat). NOT a parameter-tuning widget - DR-0004 rules out Aim/Release/Spin
## or a precision aiming marker. The player picks one discrete option; the engine resolves it.
##
## REV 213 (Glen): drawn in the same gold radial style as the verb menu (VerbMenu) instead of the
## old plain button list - a small title, a gold pivot, and the options on an arc, each a gold-ringed
## icon with its word beside it. Centred on screen (it isn't attached to one object).
##
## Icons: assets/ui/aim/<option id>.png (aim_left.png, aim_right.png, aim_straight.png,
## nudge_left.png, nudge_right.png) when they exist. Until Glen's icons arrive, the verb set's aim
## icon is used with a small gold arrow drawn over it showing the direction (a short arrow for the
## nudges).
##
## Mouse: hover to highlight, click to choose. Keyboard / gamepad: up/down (or left/right) to move,
## confirm or interact to choose. One selection only - the highlight IS the choice (REV 212's
## gamepad mismatch can't happen: there are no Godot buttons holding focus of their own).

signal choice_made(choice_id: String)

const ICON_DIR := "res://assets/ui/aim/"
const NODE_SIZE := 46.0
const ARC_RADIUS := 110.0
const ARC_STEP_DEG := 30.0
const ARC_MAX_SPREAD_DEG := 150.0
const LABEL_GAP := 10.0
const TITLE_GAP := 22.0
const ANIM := 0.14
const TITLE := "LANE 3"
const ACTION_TEXT := Color(0.84, 0.9, 0.98)
## option id -> placeholder arrow: [direction in degrees (0 = right, -90 = up), long arrow?]
const ARROWS := {
	"left": [180.0, true], "right": [0.0, true], "straight": [-90.0, true],
	"nudge_left": [-125.0, false], "nudge_right": [-55.0, false],
}

var _root: Control
var _title_panel: PanelContainer
var _title_label: Label
var _pivot: Control
var _nodes: Array[Dictionary] = []       # {id, box, ring, icon, label}
var _selected := 0
var _anchor := Vector2.ZERO
var _tween: Tween


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(PadNav.MENU_GROUP)

	_root = Control.new()
	_root.name = "Arc"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_title_panel = PanelContainer.new()
	_title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.03, 0.72)
	sb.border_color = Color(UITheme.GOLD_DIM, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_title_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_title_panel)
	_title_label = Label.new()
	_title_label.text = TITLE
	_title_label.add_theme_font_override("font", UITheme.font_bold)
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	_title_panel.add_child(_title_label)

	_pivot = Control.new()
	_pivot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pivot.size = Vector2(6, 6)
	_pivot.draw.connect(func():
		_pivot.draw_circle(Vector2(3, 3), 3.0, UITheme.GOLD_BRIGHT)
		_pivot.draw_arc(Vector2(3, 3), 6.0, 0.0, TAU, 24, Color(UITheme.GOLD, 0.45), 1.0, true))
	_root.add_child(_pivot)


## options: Array[Dictionary] of {id: String, label: String}
func open(options: Array) -> void:
	for n in _nodes:
		n["box"].queue_free()
	_nodes.clear()
	for option in options:
		_nodes.append(_make_node(String(option.id), String(option.label)))
	_selected = 0
	_layout()
	_update_selection(true)

	visible = true
	_root.pivot_offset = _anchor
	_root.modulate.a = 0.0
	_root.scale = Vector2.ONE if GameSettings.reduced_motion else Vector2(0.86, 0.86)
	_kill_tween()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_root, "modulate:a", 1.0, ANIM)
	_tween.tween_property(_root, "scale", Vector2.ONE, ANIM)
	SfxManager.ui("open", -3.0, 1.15)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


# ---------------------------------------------------------------- building

static func _icon_for(id: String) -> Texture2D:
	var path := ICON_DIR + id + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		# not imported yet (fresh copy before the editor has run): read the PNG directly
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


func _make_node(id: String, text: String) -> Dictionary:
	var s := NODE_SIZE
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_root.add_child(box)

	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0, 0, 0, 0)
	rs.border_color = UITheme.GOLD_BRIGHT
	rs.set_border_width_all(2)
	rs.set_corner_radius_all(int(s))
	rs.shadow_color = Color(UITheme.GOLD_BRIGHT, 0.45)
	rs.shadow_size = 8
	rs.anti_aliasing = true
	ring.add_theme_stylebox_override("panel", rs)
	ring.size = Vector2(s + 6, s + 6)
	ring.position = Vector2(-3, -3)
	box.add_child(ring)

	var own := _icon_for(id)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = own if own != null else VerbIcons.icon("aim")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(s, s)
	icon.pivot_offset = Vector2(s, s) * 0.5
	box.add_child(icon)
	if own == null and ARROWS.has(id):
		# placeholder: a gold arrow over the aim icon showing which way
		var arrow := Control.new()
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow.size = Vector2(s, s)
		var a: Array = ARROWS[id]
		arrow.draw.connect(_draw_arrow.bind(arrow, deg_to_rad(float(a[0])), bool(a[1]), s))
		icon.add_child(arrow)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text.to_upper()
	label.add_theme_font_override("font", UITheme.font_bold)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(label.get_minimum_size().x, s)
	label.position = Vector2(s + LABEL_GAP, 0)
	box.add_child(label)

	box.size = Vector2(s + LABEL_GAP + label.size.x, s)
	var node := {"id": id, "box": box, "ring": ring, "icon": icon, "label": label}
	box.mouse_entered.connect(func():
		var i := _nodes.find(node)
		if i >= 0 and i != _selected:
			_selected = i
			_update_selection())
	box.gui_input.connect(func(ev: InputEvent):
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			box.accept_event()
			_choose(_nodes.find(node)))
	return node


func _draw_arrow(c: Control, ang: float, long: bool, s: float) -> void:
	var mid := Vector2(s, s) * 0.5
	var dir := Vector2(cos(ang), sin(ang))
	var length := s * (0.62 if long else 0.4)
	var tail := mid - dir * length * 0.5
	var tip := mid + dir * length * 0.5
	var head := s * 0.14
	var side := dir.orthogonal()
	var shade := Color(0, 0, 0, 0.7)
	c.draw_line(tail, tip, shade, 6.0, true)
	c.draw_line(tail, tip, UITheme.GOLD_BRIGHT, 3.0, true)
	var pts := PackedVector2Array([tip + dir * head * 0.6, tip - dir * head + side * head, tip - dir * head - side * head])
	c.draw_colored_polygon(pts, UITheme.GOLD_BRIGHT)
	c.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), shade, 1.0, true)


## The arc sits a little left of screen centre, the title to its left, all kept on screen.
func _layout() -> void:
	var view := get_viewport_rect().size
	_anchor = Vector2(view.x * 0.42, view.y * 0.5)
	var n := _nodes.size()
	var step := ARC_STEP_DEG
	if n > 1 and step * (n - 1) > ARC_MAX_SPREAD_DEG:
		step = ARC_MAX_SPREAD_DEG / (n - 1)
	for i in n:
		var node: Dictionary = _nodes[i]
		var ang := deg_to_rad((i - (n - 1) * 0.5) * step)
		var c := _anchor + Vector2(cos(ang), sin(ang)) * ARC_RADIUS
		(node["box"] as Control).position = c - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
	_pivot.position = _anchor - Vector2(3, 3)
	var ts := _title_panel.get_combined_minimum_size()
	_title_panel.size = ts
	_title_panel.position = Vector2(_anchor.x - TITLE_GAP - ts.x, _anchor.y - ts.y * 0.5)


func _process(_delta: float) -> void:
	if visible and not _nodes.is_empty():
		_layout()
		_root.pivot_offset = _anchor


# ---------------------------------------------------------------- selection / input

func _update_selection(instant: bool = false) -> void:
	for i in _nodes.size():
		var node: Dictionary = _nodes[i]
		var on := i == _selected
		(node["label"] as Label).add_theme_color_override("font_color", UITheme.GOLD_BRIGHT if on else ACTION_TEXT)
		var icon: TextureRect = node["icon"]
		var ring: Panel = node["ring"]
		var target_scale := Vector2.ONE * (1.12 if on else 1.0)
		var ring_alpha := 1.0 if on else 0.0
		if instant:
			icon.scale = target_scale
			ring.modulate.a = ring_alpha
		else:
			var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			t.tween_property(icon, "scale", target_scale, UITheme.ANIM_SMALL)
			t.tween_property(ring, "modulate:a", ring_alpha, UITheme.ANIM_SMALL)


## REV 214: while open, McCoy and the camera ignore the sticks.
func pad_menu_active() -> bool:
	return visible


func _move(dir: int) -> void:
	if _nodes.is_empty():
		return
	_selected = (_selected + dir + _nodes.size()) % _nodes.size()
	_update_selection()
	SfxManager.ui("move")


func _choose(index: int) -> void:
	if not visible or index < 0 or index >= _nodes.size():
		return
	var id: String = _nodes[index]["id"]
	visible = false
	choice_made.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _nodes.is_empty():
		return
	var nav := PadNav.step(event)     # REV 214: d-pad, either stick, arrows
	if nav != 0:
		_move(nav)
	elif event is InputEventJoypadMotion:
		return
	elif PadNav.confirm(event):
		_choose(_selected)
	else:
		return
	get_viewport().set_input_as_handled()
