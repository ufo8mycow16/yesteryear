extends Control
class_name DialogueHistoryUI
## Dialogue history — press T (or the gamepad's LB) to read back what has been
## said recently, newest at the bottom. Handy after clicking through a line.
## UP / DOWN or the mouse wheel scroll; ESC, T or CLOSE leave.

const PANEL_WIDTH := 720.0

var _panel: PanelContainer
var _scroll: ScrollContainer
var _list: VBoxContainer

## REV 297: how far one push of the d-pad / stick scrolls, and how fast a held right stick scrolls.
const SCROLL_STEP := 60
const STICK_SCROLL_SPEED := 700.0


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(PadNav.MENU_GROUP)     # REV 297: the sticks scroll the history instead of walking McCoy

	_panel = PanelContainer.new()
	UITheme.style_panel(_panel)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)

	var title := Label.new()
	title.text = "DIALOGUE HISTORY"
	UITheme.style_title(title)
	column.add_child(title)
	column.add_child(UITheme.make_separator())

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	_list.custom_minimum_size = Vector2(PANEL_WIDTH - 30.0, 0)
	_scroll.add_child(_list)

	column.add_child(UITheme.make_separator())
	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	var hint := Label.new()
	InputHints.bind(hint, "UP / DOWN  SCROLL      {menu_cancel}  CLOSE")   # REV 297: the pad's button on a pad
	UITheme.style_dim(hint)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(hint)
	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(120, 0)
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
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var lines: Array[Dictionary] = AudioSubtitleManager.history
	if lines.is_empty():
		var empty := Label.new()
		empty.text = "(nothing has been said yet)"
		UITheme.style_dim(empty)
		_list.add_child(empty)
	for entry in lines:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 1)
		var who := Label.new()
		who.text = String(entry["speaker"]).to_upper()
		UITheme.style_heading(who)
		box.add_child(who)
		var said := Label.new()
		said.text = String(entry["text"])
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		said.custom_minimum_size = Vector2(PANEL_WIDTH - 60.0, 0)
		UITheme.style_body(said)
		box.add_child(said)
		_list.add_child(box)

	var viewport_size: Vector2 = get_viewport_rect().size
	_scroll.custom_minimum_size = Vector2(PANEL_WIDTH, minf(viewport_size.y * 0.6, 520.0))
	visible = true
	UITheme.fade_in(_panel)
	var content_size: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = content_size
	_panel.position = (viewport_size - content_size) / 2.0
	_scroll_to_bottom.call_deferred()
	SfxManager.ui("open")


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func close() -> void:
	if visible:
		SfxManager.ui("close")
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var nav := PadNav.step(event)     # REV 297: d-pad, either stick (one step per push), arrow keys
	if event.is_action_pressed("menu_cancel") or event.is_action_pressed("dialogue_history_open"):
		close()
	elif nav != 0:
		_scroll.scroll_vertical += nav * SCROLL_STEP
	else:
		return
	get_viewport().set_input_as_handled()


func pad_menu_active() -> bool:
	return is_visible_in_tree()


## REV 297: holding the right stick up/down scrolls smoothly.
func _process(delta: float) -> void:
	if not visible:
		return
	var y := 0.0
	for pad in Input.get_connected_joypads():
		var v := Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y)
		if absf(v) > absf(y):
			y = v
	if absf(y) > PadNav.PUSH:
		_scroll.scroll_vertical += int(y * STICK_SCROLL_SPEED * delta)
