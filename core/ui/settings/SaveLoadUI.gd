extends Control
class_name SaveLoadUI
## The SAVE GAME / LOAD GAME slot list, opened from the SYSTEM menu.
##
## SAVE mode lists the 20 manual slots. LOAD mode lists the quick save, the 5
## rotating autosaves and the 20 manual slots (empty ones are left out of the
## keyboard order, since there is nothing to load). Picking a slot asks for
## confirmation first when it would overwrite a save (SAVE) or throw away
## current progress (LOAD).
##
## Keyboard: Up/Down to move, confirm to pick, ESC to go back. Mouse works too.

signal closed()

enum Mode { SAVE, LOAD }

const PANEL_WIDTH := 720.0
const LIST_HEIGHT := 330.0
const SELECTED_NAV_COLOR := Color(0.7, 0.7, 0.7)
const SUMMARY_MAX_CHARS := 42

var _mode: int = Mode.SAVE
var _panel: PanelContainer
var _heading: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _status: Label
var _buttons: Array[Button] = []
var _selected_index: int = 0
var _confirming: bool = false


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(PadNav.MENU_GROUP)     # REV 297: the sticks move the list, not McCoy or the camera

	_panel = PanelContainer.new()
	UITheme.style_panel(_panel)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)

	_heading = Label.new()
	UITheme.style_title(_heading)
	column.add_child(_heading)
	column.add_child(UITheme.make_separator())

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(PANEL_WIDTH, LIST_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)

	_status = Label.new()
	UITheme.style_hint(_status)
	_status.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)


func open_save() -> void:
	_open(Mode.SAVE)


func open_load() -> void:
	_open(Mode.LOAD)


func _open(mode: int) -> void:
	_mode = mode
	_heading.text = "SAVE GAME" if mode == Mode.SAVE else "LOAD GAME"
	_confirming = false
	_show_list()
	visible = true
	UITheme.fade_in(_panel)


func close() -> void:
	visible = false
	closed.emit()


# ------------------------------------------------------------------- lists --

func _clear_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_buttons.clear()


func _show_list() -> void:
	_confirming = false
	_clear_rows()
	_status.text = ""

	if _mode == Mode.LOAD:
		var blocked := SaveSystem.get_busy_reason(true)
		if blocked != "":
			_status.text = "Can't load right now: " + blocked
		_add_slot_row("quick", 0, "QUICK SAVE  [F5]")
		for i in range(SaveSystem.AUTOSAVE_SLOT_COUNT):
			_add_slot_row("auto", i, "AUTOSAVE %d" % (i + 1))
	else:
		var blocked := SaveSystem.get_busy_reason(false)
		if blocked != "":
			_status.text = "Can't save right now: " + blocked
		else:
			_status.text = "Choose a slot to save into."
	for i in range(SaveSystem.MANUAL_SLOT_COUNT):
		_add_slot_row("manual", i, "SLOT %02d" % (i + 1))

	var back := Button.new()
	back.text = "BACK  [ESC]"
	InputHints.bind(back, "BACK  {menu_cancel}")
	back.custom_minimum_size = Vector2(PANEL_WIDTH - 20.0, 0)
	UITheme.style_button(back)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(close)
	_rows.add_child(back)
	_buttons.append(back)

	_selected_index = 0
	_layout_panel()
	_update_selection_highlight()


func _add_slot_row(kind: String, index: int, label: String) -> void:
	var info := SaveSystem.get_slot_info(kind, index)
	var exists: bool = info.get("exists", false)
	var text := label + "   "
	if exists:
		# REV 116: where you were first, then the objective, the date and the play time
		var where := String(info.get("location", "")).to_upper()
		text += "  %s%s   |   %s   |   %s" % [(where + "  -  ") if where != "" else "", _summary_text(info), _time_text(int(info.get("timestamp", 0))), _duration_text(float(info.get("play_time", 0.0)))]
	else:
		text += "  - empty -"

	var btn := Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = true
	btn.custom_minimum_size = Vector2(PANEL_WIDTH - 20.0, 0)
	btn.focus_mode = Control.FOCUS_NONE
	# LOAD can only pick a slot that has something in it; SAVE can pick any.
	var usable: bool = exists or _mode == Mode.SAVE
	UITheme.style_button(btn, false, not usable)
	# REV 116: the slot details are a sentence's worth of text - Barlow fits them, Microgramma didn't
	if UITheme.font_body != null:
		btn.add_theme_font_override("font", UITheme.font_body)
		btn.add_theme_font_size_override("font_size", 15)
	# REV 116: a little picture of where the save was made
	if exists:
		var thumb := SaveSystem.get_slot_thumb(kind, index)
		if thumb != null:
			btn.icon = thumb
			btn.expand_icon = false
			btn.add_theme_constant_override("icon_max_width", 96)
			btn.custom_minimum_size.y = 62.0
	_rows.add_child(btn)
	if usable:
		btn.pressed.connect(_on_slot_picked.bind(kind, index, exists))
		_buttons.append(btn)


func _summary_text(info: Dictionary) -> String:
	var text: String = info.get("summary", "")
	if text == "":
		text = String(info.get("checkpoint", "")).replace("_", " ")
	if text.length() > SUMMARY_MAX_CHARS:
		text = text.substr(0, SUMMARY_MAX_CHARS - 1) + "…"
	return text


func _time_text(unix: int) -> String:
	# Saved in UTC; shown in the player's local time.
	var bias_seconds: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var stamp: String = Time.get_datetime_string_from_unix_time(unix + bias_seconds, true)
	return stamp.substr(0, 16)


func _duration_text(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]


# ----------------------------------------------------------------- actions --

func _on_slot_picked(kind: String, index: int, exists: bool) -> void:
	if _mode == Mode.SAVE:
		var blocked := SaveSystem.get_busy_reason(false)
		if blocked != "":
			_status.text = "Can't save right now: " + blocked
			return
		if exists:
			_show_confirm("Overwrite SLOT %02d?" % (index + 1), _do_save.bind(index))
		else:
			_do_save(index)
	else:
		var blocked_load := SaveSystem.get_busy_reason(true)
		if blocked_load != "":
			_status.text = "Can't load right now: " + blocked_load
			return
		_show_confirm("Load this save? Progress since your last save will be lost.", _do_load.bind(kind, index))


func _do_save(index: int) -> void:
	var result := SaveSystem.save_manual(index)
	if result != "":
		_show_list()
		_status.text = "Couldn't save: " + result
		return
	_show_list()
	_status.text = "Saved to SLOT %02d." % (index + 1)


func _do_load(kind: String, index: int) -> void:
	var result := SaveSystem.load_slot(kind, index)
	if result != "":
		_show_list()
		_status.text = "Couldn't load: " + result
		return
	# Success: the scene is being replaced, menu and all.


func _show_confirm(message: String, on_yes: Callable) -> void:
	_confirming = true
	_clear_rows()

	var question := Label.new()
	question.text = message
	UITheme.style_body(question)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.custom_minimum_size = Vector2(PANEL_WIDTH - 20.0, 0)
	_rows.add_child(question)

	var yes := Button.new()
	yes.text = "YES"
	yes.custom_minimum_size = Vector2(PANEL_WIDTH - 20.0, 0)
	yes.focus_mode = Control.FOCUS_NONE
	UITheme.style_button(yes)
	yes.pressed.connect(on_yes)
	_rows.add_child(yes)
	_buttons.append(yes)

	var no := Button.new()
	no.text = "NO"
	no.custom_minimum_size = Vector2(PANEL_WIDTH - 20.0, 0)
	no.focus_mode = Control.FOCUS_NONE
	UITheme.style_button(no)
	no.pressed.connect(_show_list)
	_rows.add_child(no)
	_buttons.append(no)

	# Default to NO so a stray confirm key can't overwrite or discard anything.
	_selected_index = 1
	_status.text = ""
	_update_selection_highlight()


# --------------------------------------------------------------- navigation --

func _layout_panel() -> void:
	# Same centering idiom as the other panels: the size is taken from the
	# content, and the viewport rect is used because self.size isn't reliably
	# current the instant a menu opens.
	var content_size: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = content_size
	var viewport_size: Vector2 = get_viewport_rect().size
	_panel.position = (viewport_size - content_size) / 2.0


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _buttons.is_empty():
		return

	# REV 297: PadNav.step - d-pad, either stick (one row per push, so it never skips slots) and the arrow keys.
	var nav := PadNav.step(event)
	if nav != 0:
		_selected_index = (_selected_index + nav + _buttons.size()) % _buttons.size()
		SfxManager.ui("move")
		_update_selection_highlight()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		return
	elif event.is_action_pressed("ui_navigate_confirm"):
		_buttons[_selected_index].pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_cancel"):
		if _confirming:
			_show_list()
		else:
			close()
		get_viewport().set_input_as_handled()


func pad_menu_active() -> bool:
	return is_visible_in_tree()


func _update_selection_highlight() -> void:
	for i in range(_buttons.size()):
		_buttons[i].modulate = Color.WHITE if i == _selected_index else SELECTED_NAV_COLOR
	if _selected_index >= 0 and _selected_index < _buttons.size():
		# Wait a frame so freshly added rows have a size, then keep the
		# selected row inside the scrolled view.
		_scroll.ensure_control_visible.call_deferred(_buttons[_selected_index])
