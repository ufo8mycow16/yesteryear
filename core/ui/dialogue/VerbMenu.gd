extends Control
class_name VerbMenu
## REV 148 (CLAUDE.md item 26, docs/design/CONTEXTUAL_INTERACTION_UI.md + INTERACTION_MODEL.md):
## the compact radial/arc menu of a hotspot's NATIVE verbs, drawn beside the thing itself.
##
##   [ BOWLING BALL RACK ] ·  ( hand )  PICK UP BALL
##                            ( eye )   EXAMINE
##
## The hotspot's name sits in a small dark label left of the target; the verbs orbit it on a short
## arc to the right, each a gold-ringed icon from Glen's set (VerbIcons) with its word beside it.
## The primary action comes first, EXAMINE last and a little quieter. It follows the target while
## the camera moves and stays on screen.
##
## Mouse: hover to highlight, click to choose, click anywhere else to dismiss.
## Keyboard / controller: up/down (or left/right) to move, confirm or the interact key to choose,
## cancel to dismiss (InteractionManager handles cancel). Items in hand never open this menu.

const NODE_SIZE := 46.0
const NODE_SIZE_SECONDARY := 38.0
const ARC_RADIUS := 92.0
const ARC_STEP_DEG := 32.0
const ARC_MAX_SPREAD_DEG := 150.0
const LABEL_GAP := 10.0
const TITLE_GAP := 22.0
const ANIM := 0.14
const ACTION_TEXT := Color(0.84, 0.9, 0.98)          # pale blue-white
const ACTION_TEXT_DIM := Color(0.66, 0.71, 0.78)

var _root: Control
var _title_panel: PanelContainer
var _title_label: Label
var _pivot: Control                       # small gold point the arc orbits
var _nodes: Array[Dictionary] = []        # {verb, box, ring, icon, label, secondary, disabled, size}
var _selected := 0
var _hotspot: Hotspot = null
var _tween: Tween
var _anchor := Vector2.ZERO


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	_title_label.add_theme_font_override("font", UITheme.font_bold)
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	_title_panel.add_child(_title_label)

	_pivot = Control.new()
	_pivot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pivot.custom_minimum_size = Vector2(6, 6)
	_pivot.size = Vector2(6, 6)
	_pivot.draw.connect(func():
		_pivot.draw_circle(Vector2(3, 3), 3.0, UITheme.GOLD_BRIGHT)
		_pivot.draw_arc(Vector2(3, 3), 6.0, 0.0, TAU, 24, Color(UITheme.GOLD, 0.45), 1.0, true))
	_root.add_child(_pivot)

	add_to_group(PadNav.MENU_GROUP)
	InteractionManager.verb_menu_opened.connect(_on_opened)
	InteractionManager.verb_menu_closed.connect(_on_closed)
	InteractionManager.focus_changed.connect(_on_focus_changed)


# ---------------------------------------------------------------- open / close

func _on_opened(verbs: Array) -> void:
	_hotspot = InteractionManager.get_focus()
	for n in _nodes:
		n["box"].queue_free()
	_nodes.clear()

	_title_label.text = (String(_hotspot.display_name) if _hotspot != null else "").to_upper()
	if InteractionManager.is_item_menu() and _title_label.text != "":      # REV 521: "SULPHUR  >  VENT"
		_title_label.text = "%s  >  %s" % [InteractionManager.held_source_name().to_upper(), _title_label.text]
	_title_panel.visible = _title_label.text != ""

	for verb in verbs:
		_nodes.append(_make_node(String(verb)))

	_selected = 0
	for i in _nodes.size():          # start on the first verb that can actually be done
		if not _nodes[i]["disabled"]:
			_selected = i
			break
	_layout()
	_update_selection(true)

	visible = true
	_root.pivot_offset = _anchor
	_root.modulate.a = 0.0
	_root.scale = Vector2.ONE if GameSettings.reduced_motion else Vector2(0.86, 0.86)   # REV 160: Reduced Motion
	_kill_tween()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_root, "modulate:a", 1.0, ANIM)
	_tween.tween_property(_root, "scale", Vector2.ONE, ANIM)
	SfxManager.ui("open", -3.0, 1.15)


func _on_closed() -> void:
	if not visible:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 0.0, ANIM * 0.7)
	_tween.tween_callback(func(): visible = false)
	_hotspot = null


## REV 214: while open, McCoy and the camera ignore the sticks.
func pad_menu_active() -> bool:
	return visible and _hotspot != null


func _on_focus_changed(hotspot: Hotspot) -> void:
	# Walking off (or to something else) dismisses the arc
	if visible and _hotspot != null and hotspot != _hotspot:
		InteractionManager.close_verb_menu()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


# ---------------------------------------------------------------- building

func _make_node(verb: String) -> Dictionary:
	var info := VerbIcons.present(_hotspot, verb)
	var secondary: bool = info["secondary"]
	var disabled: bool = info["disabled"]
	var s := NODE_SIZE_SECONDARY if secondary else NODE_SIZE

	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_root.add_child(box)

	# Glow ring behind the icon: only shows on the highlighted verb.
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

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = info["icon"]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(s, s)
	icon.pivot_offset = Vector2(s, s) * 0.5
	box.add_child(icon)
	if disabled:
		var no := TextureRect.new()      # the prohibited badge over the verb's own icon
		no.mouse_filter = Control.MOUSE_FILTER_IGNORE
		no.texture = VerbIcons.icon("disabled")
		no.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		no.size = Vector2(s, s) * 0.5
		no.position = Vector2(s * 0.55, s * 0.55)
		box.add_child(no)
		icon.modulate = Color(0.55, 0.55, 0.55)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = String(info["label"])
	label.add_theme_font_override("font", UITheme.font_bold)
	label.add_theme_font_size_override("font_size", 13 if secondary else 15)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(label.get_minimum_size().x, s)
	label.position = Vector2(s + LABEL_GAP, 0)
	box.add_child(label)

	box.size = Vector2(s + LABEL_GAP + label.size.x, s)
	var node := {"verb": verb, "box": box, "ring": ring, "icon": icon, "label": label,
		"secondary": secondary, "disabled": disabled, "size": s}
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


## Places the title, pivot and verb nodes around the anchor (the target on screen), then nudges
## the whole group so none of it leaves the screen.
func _layout() -> void:
	_anchor = _target_screen_point()
	var n := _nodes.size()
	var step := ARC_STEP_DEG
	var radius := ARC_RADIUS
	if n > 1 and step * (n - 1) > ARC_MAX_SPREAD_DEG:
		step = ARC_MAX_SPREAD_DEG / (n - 1)
		radius = ARC_RADIUS * (1.0 + 0.12 * (n - 5))
	var rect := Rect2(_anchor, Vector2.ZERO)
	for i in n:
		var node: Dictionary = _nodes[i]
		var s: float = node["size"]
		var ang := deg_to_rad((i - (n - 1) * 0.5) * step)
		var c := _anchor + Vector2(cos(ang), sin(ang)) * radius
		var box: Control = node["box"]
		box.position = c - Vector2(s, s) * 0.5
		rect = rect.merge(Rect2(box.position, box.size))
	_pivot.position = _anchor - Vector2(3, 3)
	var ts := _title_panel.get_combined_minimum_size()
	_title_panel.size = ts
	_title_panel.position = Vector2(_anchor.x - TITLE_GAP - ts.x, _anchor.y - ts.y * 0.5)
	if _title_panel.visible:
		rect = rect.merge(Rect2(_title_panel.position, ts))

	# Keep it all on screen, and clear of the HUD (REV 149: Glen's screenshot had the arc sitting on
	# the function bank when the target was close and low, e.g. Kirk right beside McCoy).
	var view := get_viewport_rect().size
	var m := float(UITheme.SCREEN_MARGIN)
	var top := m
	var bottom := view.y - m
	var blocks := _hud_blocks()
	for b in blocks:
		if b.get_center().y > view.y * 0.5:
			bottom = minf(bottom, b.position.y - HUD_GAP)       # bottom bar: stay above it
	var shift := Vector2.ZERO
	if rect.position.x < m:
		shift.x = m - rect.position.x
	elif rect.end.x > view.x - m:
		shift.x = (view.x - m) - rect.end.x
	if rect.end.y > bottom:
		shift.y = bottom - rect.end.y
	if rect.position.y + shift.y < top:
		shift.y = top - rect.position.y
	# Anything still in the way up top (the minimap): slide left of it
	var moved := Rect2(rect.position + shift, rect.size)
	for b in blocks:
		if b.get_center().y <= view.y * 0.5 and moved.intersects(b.grow(HUD_GAP)):
			shift.x += (b.position.x - HUD_GAP) - moved.end.x
			moved = Rect2(rect.position + shift, rect.size)
	if shift != Vector2.ZERO:
		for child in _root.get_children():
			(child as Control).position += shift
		_anchor += shift


const HUD_GAP := 12.0
const HUD_BLOCK_NAMES := ["FunctionBankRail", "GameFunctionsBank", "WhoCard", "MinimapFrame", "SubtitleBox", "ConsoleBar"]     # REV 301


## Screen rectangles of the HUD panels the arc must not cover.
func _hud_blocks() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return out
	for n in HUD_BLOCK_NAMES:
		var c := hud.find_child(n, true, false) as Control
		if c != null and c.is_visible_in_tree() and c.modulate.a > 0.05 and c != self:
			out.append(c.get_global_rect())
	return out


func _target_screen_point() -> Vector2:
	var view := get_viewport_rect().size
	var cam := get_viewport().get_camera_3d()
	if cam == null or _hotspot == null or not is_instance_valid(_hotspot):
		return view * 0.5
	# REV 149: a close target's middle can be below the screen (Kirk right beside McCoy). Then try
	# higher up the same thing (chest, head) so the arc sits by what the player can see.
	var base := _hotspot.global_transform * _hotspot.halo_center_offset
	var safe := Rect2(Vector2.ZERO, view).grow(-view.y * 0.12)
	var first := Vector2.INF
	for up in [0.0, 0.6, 1.1]:
		var p: Vector3 = base + Vector3.UP * up
		if cam.is_position_behind(p):
			continue
		var sp := cam.unproject_position(p)
		if first == Vector2.INF:
			first = sp
		if safe.has_point(sp):
			return sp
	return view * 0.5 if first == Vector2.INF else first


func _process(_delta: float) -> void:
	# Follow the target while the camera orbits or the player turns
	if visible and _hotspot != null and is_instance_valid(_hotspot) and not _nodes.is_empty():
		_layout()
		_root.pivot_offset = _anchor


# ---------------------------------------------------------------- selection / input

func _update_selection(instant: bool = false) -> void:
	for i in _nodes.size():
		var node: Dictionary = _nodes[i]
		var on := i == _selected
		var ring: Panel = node["ring"]
		var icon: TextureRect = node["icon"]
		var label: Label = node["label"]
		var colour: Color
		if node["disabled"]:
			colour = UITheme.TEXT_DISABLED
		elif on:
			colour = UITheme.GOLD_BRIGHT
		else:
			colour = ACTION_TEXT_DIM if node["secondary"] else ACTION_TEXT
		label.add_theme_color_override("font_color", colour)
		var target_scale := Vector2.ONE * (1.12 if on else 1.0)
		var ring_alpha := 1.0 if on else 0.0
		if instant:
			icon.scale = target_scale
			ring.modulate.a = ring_alpha
		else:
			var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			t.tween_property(icon, "scale", target_scale, UITheme.ANIM_SMALL)
			t.tween_property(ring, "modulate:a", ring_alpha, UITheme.ANIM_SMALL)


func _move(dir: int) -> void:
	if _nodes.is_empty():
		return
	_selected = (_selected + dir + _nodes.size()) % _nodes.size()
	_update_selection()
	SfxManager.ui("move")


func _choose(index: int) -> void:
	if index < 0 or index >= _nodes.size():
		return
	var verb: String = _nodes[index]["verb"]
	InteractionManager.choose_verb(verb)


func _input(event: InputEvent) -> void:
	# A click anywhere that isn't on a verb dismisses the arc (and does nothing else).
	if not visible or _hotspot == null:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	for node in _nodes:
		if (node["box"] as Control).get_global_rect().has_point(mb.position):
			return
	InteractionManager.close_verb_menu()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _hotspot == null or _nodes.is_empty():
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
