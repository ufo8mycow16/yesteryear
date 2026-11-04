extends Control
class_name CollectionUI
## The COLLECTION screen (HUD button, K, or the main menu): every collector card in CollectorCards.
## REV 742: the cards are floating cards hidden round the rooms (walk through one to take it); one you have shows
## its front art, one you haven't shows the Vulcan emblem back, dimmed, with its episode.
##
## REV 293: the main menu's COLLECTION opens this same screen. Pad: up/down (d-pad or either
## stick) scrolls the cards, A or B closes it; keyboard: arrows scroll, Enter / Esc / K close.

## Emitted when the screen closes (the main menu listens, to take back the keys).
signal closed()

const CARD_SIZE := Vector2(150, 262)      # REV 742: room for the whole card picture
const COLUMNS := 6

var _panel: PanelContainer
var _count_label: Label
var _grid: GridContainer
var _scroll: ScrollContainer


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(PadNav.MENU_GROUP)     # REV 293: while it's open the sticks don't walk or turn the camera

	_panel = PanelContainer.new()
	UITheme.style_panel(_panel)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)

	var head := HBoxContainer.new()
	column.add_child(head)
	var title := Label.new()
	title.text = "COLLECTION"
	UITheme.style_title(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_count_label = Label.new()
	UITheme.style_heading(_count_label)
	head.add_child(_count_label)
	column.add_child(UITheme.make_separator())

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_scroll.add_child(_grid)

	column.add_child(UITheme.make_separator())
	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	var hint := Label.new()
	hint.text = "WALK THROUGH A FLOATING CARD TO COLLECT IT  -  CLICK A CARD (PAD: X) TO LOOK CLOSER"
	UITheme.style_dim(hint)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(hint)
	var close_btn := Button.new()
	close_btn.text = "CLOSE  [ESC]"
	InputHints.bind(close_btn, "CLOSE  {menu_cancel}")
	close_btn.custom_minimum_size = Vector2(150, 0)
	close_btn.focus_mode = Control.FOCUS_NONE
	UITheme.style_button(close_btn)
	close_btn.pressed.connect(close)
	bottom.add_child(close_btn)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_rebuild()
	visible = true
	UITheme.fade_in(_panel)
	SfxManager.ui("open")


func close() -> void:
	_close_viewer()
	var was_open := visible
	if was_open:
		SfxManager.ui("close")
	visible = false
	if was_open:
		closed.emit()


## PadNav asks this: true while the screen is up.
func pad_menu_active() -> bool:
	return visible


func _rebuild() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_count_label.text = "%d / %d" % [CollectorCards.unlocked_count(), CollectorCards.total()]
	for card in CollectorCards.CARDS:
		_grid.add_child(_make_card(card, CollectorCards.is_unlocked(String(card["id"]))))

	var viewport_size: Vector2 = get_viewport_rect().size
	var rows := int(ceil(CollectorCards.total() / float(COLUMNS)))
	var wanted_h := rows * (CARD_SIZE.y + 10.0)
	_scroll.custom_minimum_size = Vector2(COLUMNS * (CARD_SIZE.x + 10.0), minf(wanted_h, viewport_size.y * 0.62))
	var content_size: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = content_size
	_panel.position = (viewport_size - content_size) / 2.0


func _make_card(card: Dictionary, unlocked: bool) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = CARD_SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.085, 0.95) if unlocked else Color(0.025, 0.025, 0.03, 0.8)
	sb.border_color = UITheme.GOLD_BRIGHT if unlocked else Color(UITheme.GOLD_DIM.r, UITheme.GOLD_DIM.g, UITheme.GOLD_DIM.b, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	frame.add_child(box)

	# REV 742: the card itself - Glen's front art once you have it, the Vulcan emblem back (dimmed) until then
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 186)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture = CollectorCards.front(String(card["id"])) if unlocked else CollectorCards.back()
	if not unlocked:
		art.modulate = Color(0.35, 0.35, 0.38, 0.9)
	else:
		# REV 767: click a card you have to see it big, and turn it over to read its back
		art.mouse_filter = Control.MOUSE_FILTER_STOP
		art.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var cid := String(card["id"])
		art.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_open_viewer(cid))
	box.add_child(art)
	if unlocked and art.texture == null:
		art.add_child(_glyph(String(card["name"]).substr(0, 1)))
	elif art.texture == null:
		art.add_child(_glyph("?"))

	var name_label := Label.new()
	name_label.text = String(card["name"]).to_upper() if unlocked else "EPISODE %d" % int(card.get("episode", 0))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_heading(name_label)
	name_label.add_theme_font_size_override("font_size", 10)
	box.add_child(name_label)

	var kind_label := Label.new()
	kind_label.text = String(card["kind"]) if unlocked else ""
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_dim(kind_label)
	kind_label.add_theme_font_size_override("font_size", 9)
	box.add_child(kind_label)

	if unlocked:
		var blurb := Label.new()
		blurb.text = String(card["blurb"])
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.style_body(blurb)
		blurb.add_theme_font_size_override("font_size", 10)
		box.add_child(blurb)
	return frame


func _glyph(letter: String) -> Label:
	var l := Label.new()
	l.text = letter
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_theme_font_size_override("font_size", 46)
	l.add_theme_color_override("font_color", UITheme.GOLD_DIM)
	return l


# ---- REV 767: the card viewer - one card big, turned over to read its back (Glen's A&BC-style cards have their own
# printed backs). Click / A / Enter turns it over, left / right goes to the next card you have, B / Esc goes back.
var _viewer: Control = null
var _view_art: TextureRect
var _view_label: Label
var _view_ids: Array = []
var _view_i := 0
var _view_back := false


func _open_viewer(card_id: String) -> void:
	_view_ids.clear()
	for c in CollectorCards.CARDS:
		if CollectorCards.is_unlocked(String(c["id"])):
			_view_ids.append(String(c["id"]))
	if _view_ids.is_empty():
		return
	_view_i = maxi(0, _view_ids.find(card_id))
	_view_back = false
	if _viewer == null:
		_viewer = Control.new()
		_viewer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_viewer.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_viewer)
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.82)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_viewer.add_child(dim)
		_view_art = TextureRect.new()
		_view_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_view_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_view_art.set_anchors_preset(Control.PRESET_FULL_RECT)
		_view_art.offset_left = 60
		_view_art.offset_right = -60
		_view_art.offset_top = 50
		_view_art.offset_bottom = -90
		_view_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_viewer.add_child(_view_art)
		_view_label = Label.new()
		_view_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_view_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_view_label.offset_top = -70
		_view_label.offset_bottom = -30
		UITheme.style_dim(_view_label)
		_viewer.add_child(_view_label)
		_viewer.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
				if (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
					_flip_viewer()
				elif (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
					_close_viewer())
	_viewer.visible = true
	_show_viewer()
	SfxManager.ui("open")


func _show_viewer() -> void:
	var cid := String(_view_ids[_view_i])
	var tex := CollectorCards.back(cid) if _view_back else CollectorCards.front(cid)
	_view_art.texture = tex if tex != null else CollectorCards.front(cid)
	var info := CollectorCards.card(cid)
	_view_label.text = "%s  -  %s     %d / %d\nCLICK TO TURN OVER   -   LEFT / RIGHT: NEXT CARD   -   RIGHT CLICK / ESC: BACK" % [
		String(info.get("name", "")).to_upper(), "BACK" if _view_back else "FRONT", _view_i + 1, _view_ids.size()]


func _flip_viewer() -> void:
	_view_back = not _view_back
	SfxManager.ui("focus")
	if _view_art != null:
		var tw := create_tween()
		_view_art.pivot_offset = _view_art.size * 0.5
		tw.tween_property(_view_art, "scale:x", 0.0, 0.09)
		tw.tween_callback(_show_viewer)
		tw.tween_property(_view_art, "scale:x", 1.0, 0.09)
	else:
		_show_viewer()


func _step_viewer(d: int) -> void:
	_view_i = (_view_i + d + _view_ids.size()) % _view_ids.size()
	_view_back = false
	SfxManager.ui("focus")
	_show_viewer()


func _close_viewer() -> void:
	if _viewer != null and _viewer.visible:
		_viewer.visible = false


func _viewer_open() -> bool:
	return _viewer != null and _viewer.visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _viewer_open():
		var back_btn: bool = event is InputEventJoypadButton and event.is_pressed() \
			and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B
		if event.is_action_pressed("menu_cancel") or event.is_action_pressed("collection_open") or back_btn:
			_close_viewer()
		elif PadNav.confirm(event) or event.is_action_pressed("ui_accept"):
			_flip_viewer()
		elif event.is_action_pressed("ui_left"):
			_step_viewer(-1)
		elif event.is_action_pressed("ui_right"):
			_step_viewer(1)
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.is_pressed() and (event as InputEventJoypadButton).button_index == JOY_BUTTON_X:
		for c in CollectorCards.CARDS:
			if CollectorCards.is_unlocked(String(c["id"])):
				_open_viewer(String(c["id"]))
				get_viewport().set_input_as_handled()
				return
	var pad_back: bool = event is InputEventJoypadButton and event.is_pressed() \
		and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B
	if event.is_action_pressed("menu_cancel") or event.is_action_pressed("collection_open") or pad_back \
			or PadNav.confirm(event):
		close()
		get_viewport().set_input_as_handled()
		return
	# REV 293: up / down scroll one row of cards (d-pad, either stick once per push, arrow keys)
	var step := PadNav.step(event)
	if step != 0:
		_scroll.scroll_vertical += int(step * (CARD_SIZE.y + 10.0))
		get_viewport().set_input_as_handled()
