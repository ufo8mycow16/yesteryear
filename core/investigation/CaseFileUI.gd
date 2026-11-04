extends Control
class_name CaseFileUI
## CaseFileUI — the window for the Case File. Press C to open or close it.
##
## Left: every clue found so far, under its heading. Click one to read it.
## Bottom: COMPARE EVIDENCE. Pick one clue, then a second. The window closes and
## the scene decides what the comparison means (see EpisodeRoom.resolve_compare)
## so a meaningful pairing can play out as a short scene and a meaningless one
## gets a brief shrug.

signal compare_requested(clue_a: String, clue_b: String)
signal closed()
## A big "something can be worked out now" button, shown only while the scene
## has set deduction_label to something. Pressing it closes the window and asks
## the scene to run that deduction.
signal deduction_requested()

var deduction_label: String = ""
var _deduction_button: Button

var _panel: PanelContainer
var _list: VBoxContainer
var _detail_title: Label
var _detail_text: Label
var _status: Label
var _compare_button: Button
var _compare_mode: bool = false
var _first_pick: String = ""
var _selected_id: String = ""
## REV 160 (CLAUDE.md item 23): the Case File opens where you left it - the clue you were reading and
## how far down the list you had scrolled - unless that clue is no longer there.
var _scroll: ScrollContainer
var _scroll_kept := 0
var _is_open: bool = false
## REV 215 (Nikki's playtest - the Case File was mouse-only, so the Prologue couldn't be finished on a
## pad): the clue the keyboard/gamepad cursor is on, in list order, and their buttons.
var _order: Array[String] = []
var _clue_buttons: Dictionary = {}     # clue id -> Button
var _close_button: Button
## REV 215: the first time it's opened, a short line explaining what it's for.
signal first_opened()
var _ever_opened := false
## REV 215: shown above the controls line the first time the Case File is opened.
var intro_text := ""
var _show_intro := false

## REV 302 (design review 2.1, Glen approved): the INVESTIGATION BOARD - a second page of the Case
## File that says where the case stands: ESTABLISHED (deductions held), DOESN'T ADD UP (the episode's
## contradiction clues held), OPEN QUESTIONS (unresolved-question clues + what the episode's own gates
## still need, by kind only), LEADS (the objective, the places open to you). Built ONLY from what has
## been found and from the gate checks the game already makes - it never names an undiscovered clue
## and never solves anything. board_source = the episode script (Ep1 / Ep2); it may add
## BOARD_CONFLICTS, board_open() and board_leads(). No source (the Prologue) = no board page.
var board_source: Variant = null
var _board_mode := false
var _board_button: Button
var _row: HBoxContainer
var _board_scroll: ScrollContainer
var _board: GridContainer


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dim := UITheme.make_blur_backdrop(0.5)   # REV 103: the room behind, blurred
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = true
	var dim_mat := dim.material as ShaderMaterial
	if dim_mat != null:
		dim_mat.set_shader_parameter("strength", 1.0)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(900, 520)
	UITheme.style_panel(_panel)
	center.add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_panel.add_child(outer)

	var title := Label.new()
	title.text = Case.title_text.replace(" - ", "  -  ")
	UITheme.style_title(title)
	title.add_theme_font_size_override("font_size", 16)
	outer.add_child(title)
	outer.add_child(UITheme.make_separator())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(row)
	_row = row

	# REV 302: the board page (shown instead of the clue list and reader)
	_board_scroll = ScrollContainer.new()
	_board_scroll.custom_minimum_size = Vector2(870, 380)
	_board_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_board_scroll.visible = false
	outer.add_child(_board_scroll)
	_board = GridContainer.new()
	_board.columns = 2
	_board.add_theme_constant_override("h_separation", 24)
	_board.add_theme_constant_override("v_separation", 16)
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_scroll.add_child(_board)

	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.custom_minimum_size = Vector2(430, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	detail.custom_minimum_size = Vector2(400, 0)
	row.add_child(detail)

	_detail_title = Label.new()
	UITheme.style_heading(_detail_title)
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_title.custom_minimum_size = Vector2(390, 0)
	detail.add_child(_detail_title)

	_detail_text = Label.new()
	UITheme.style_body(_detail_text)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.custom_minimum_size = Vector2(390, 0)
	detail.add_child(_detail_text)

	outer.add_child(UITheme.make_separator())

	_status = Label.new()
	UITheme.style_hint(_status)
	outer.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	outer.add_child(buttons)

	_compare_button = Button.new()
	_compare_button.text = "COMPARE EVIDENCE"
	_compare_button.focus_mode = Control.FOCUS_NONE
	UITheme.style_button(_compare_button)
	_compare_button.pressed.connect(_toggle_compare)
	buttons.add_child(_compare_button)

	_board_button = Button.new()
	_board_button.focus_mode = Control.FOCUS_NONE
	UITheme.style_button(_board_button)
	_board_button.pressed.connect(_toggle_board)
	buttons.add_child(_board_button)

	_deduction_button = Button.new()
	_deduction_button.focus_mode = Control.FOCUS_NONE
	UITheme.style_button(_deduction_button, true)
	_deduction_button.pressed.connect(_on_deduction_pressed)
	buttons.add_child(_deduction_button)

	var close_button := Button.new()
	_close_button = close_button
	close_button.focus_mode = Control.FOCUS_NONE
	UITheme.style_button(close_button)
	close_button.pressed.connect(close)
	buttons.add_child(close_button)
	add_to_group(PadNav.MENU_GROUP)
	InputHints.device_changed.connect(func(_pad: bool) -> void:
		if _is_open:
			_rebuild())


## REV 215: keeps McCoy and the camera still while it's open.
func pad_menu_active() -> bool:
	return _is_open


## "  [X]" on a pad (Xbox face-button names follow the pad family), "" with keyboard and mouse.
static func _pad_tag(button: int) -> String:
	if not InputHints.using_gamepad:
		return ""
	var names: Array = InputHints.BUTTONS.get(InputHints.family, InputHints.BUTTONS["xbox"])
	return "  [%s]" % String(names[button]) if button < names.size() else ""


func is_open() -> bool:
	return _is_open


func _on_deduction_pressed() -> void:
	close()
	deduction_requested.emit()


func open() -> void:
	_compare_mode = false
	_first_pick = ""
	if _selected_id != "" and not Case.has(_selected_id):
		_selected_id = ""
		_scroll_kept = 0
	_rebuild()
	if _scroll != null:
		_restore_scroll.call_deferred()
	visible = true
	_is_open = true
	UITheme.panel_open(_panel)      # REV 160 (item 21)
	if not _ever_opened:
		_ever_opened = true
		_show_intro = intro_text != ""
		_rebuild()
		first_opened.emit()
	else:
		_show_intro = false


func _restore_scroll() -> void:
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = _scroll_kept


func close() -> void:
	if not _is_open:
		return
	if _scroll != null:
		_scroll_kept = _scroll.scroll_vertical
	_is_open = false
	# REV 160 (item 21): closes with the shared quick fade; the Case File counts as closed at once
	UITheme.panel_close(_panel, func() -> void:
		if not _is_open:
			visible = false)
	closed.emit()


func _toggle_compare() -> void:
	if _board_mode:
		_board_mode = false     # REV 302: comparing happens on the clue page
	_compare_mode = not _compare_mode
	_first_pick = ""
	_rebuild()


func _toggle_board() -> void:
	if board_source == null:
		return
	_board_mode = not _board_mode
	_compare_mode = false
	_first_pick = ""
	SfxManager.ui("open" if _board_mode else "close")
	_rebuild()


## REV 302: the four sections as [heading, [lines]] - from what has been found only.
func _board_sections() -> Array:
	var src: Variant = board_source
	var consts: Dictionary = (src as Script).get_script_constant_map() if src is Script else {}
	var conflicts: Array = consts.get("BOARD_CONFLICTS", [])
	var established: Array = []
	var odd: Array = []
	for id in Case.known():
		var cid := String(id)
		if conflicts.has(cid):
			odd.append(Case.get_title(cid))
		elif Case.get_category(cid) == "DEDUCTIONS":
			established.append(Case.get_title(cid))
	var open_q: Array = []
	for id in Case.known_in_category("UNRESOLVED QUESTIONS"):
		open_q.append(Case.get_title(String(id)))
	if _src_has("board_open"):
		open_q.append_array((src as Object).call("board_open"))
	var leads: Array = []
	var obj: ObjectiveData = ObjectiveManager.get_current_objective()
	if obj != null and String(obj.text) != "":
		leads.append("OBJECTIVE:  " + String(obj.text))
	if _src_has("board_leads"):
		leads.append_array((src as Object).call("board_leads"))
	return [["ESTABLISHED", established, "Nothing proven yet."],
		["DOESN'T ADD UP", odd, "No contradictions found yet."],
		["OPEN QUESTIONS", open_q, "Nothing outstanding."],
		["LEADS", leads, "Nothing to follow right now."]]


## Whether the episode script has this (static) function - a Script's own has_method() doesn't see them.
func _src_has(fn: String) -> bool:
	if not (board_source is Script):
		return false
	for m in (board_source as Script).get_script_method_list():
		if String(m["name"]) == fn:
			return true
	return false


func _rebuild_board() -> void:
	for child in _board.get_children():
		_board.remove_child(child)
		child.queue_free()
	for sec in _board_sections():
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.custom_minimum_size = Vector2(420, 0)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var head := Label.new()
		head.text = String(sec[0])
		UITheme.style_heading(head)
		head.add_theme_font_size_override("font_size", 13)
		box.add_child(head)
		var lines: Array = sec[1]
		if lines.is_empty():
			var none := Label.new()
			none.text = String(sec[2])
			UITheme.style_dim(none)
			box.add_child(none)
		for l in lines:
			var lab := Label.new()
			lab.text = "•  " + String(l)
			UITheme.style_body(lab)
			lab.add_theme_font_size_override("font_size", 12)
			lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lab.custom_minimum_size = Vector2(410, 0)
			box.add_child(lab)
		_board.add_child(box)


func _rebuild() -> void:
	# REV 302: the board page or the clue page
	_board_button.visible = board_source != null
	if board_source == null:
		_board_mode = false
	_board_button.text = ("CLUES" if _board_mode else "INVESTIGATION BOARD") + (_pad_tag(JOY_BUTTON_RIGHT_SHOULDER) if InputHints.using_gamepad else "  [TAB]")
	UITheme.style_button(_board_button, _board_mode)
	_row.visible = not _board_mode
	_board_scroll.visible = _board_mode
	_compare_button.visible = not _board_mode
	if _board_mode:
		_rebuild_board()
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_order.clear()
	_clue_buttons.clear()

	var any := false
	for category in Case.CATEGORIES:
		var ids := Case.known_in_category(category)
		if ids.is_empty():
			continue
		any = true
		var heading := Label.new()
		heading.text = category
		UITheme.style_heading(heading)
		heading.add_theme_font_size_override("font_size", 11)
		_list.add_child(heading)
		for id in ids:
			var clue_id: String = String(id)
			var btn := Button.new()
			btn.text = Case.get_title(clue_id)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.custom_minimum_size = Vector2(400, 0)
			btn.focus_mode = Control.FOCUS_NONE
			var highlighted := clue_id == _first_pick or clue_id == _selected_id
			UITheme.style_button(btn, highlighted)
			if _compare_mode and clue_id == _first_pick:
				btn.text = "1 ▸  " + btn.text       # REV 215: the first clue of a comparison, marked
			btn.add_theme_font_size_override("font_size", 12)
			btn.pressed.connect(_on_clue_pressed.bind(clue_id))
			_list.add_child(btn)
			_order.append(clue_id)
			_clue_buttons[clue_id] = btn

	if not any:
		var empty := Label.new()
		empty.text = "Nothing recorded yet."
		UITheme.style_dim(empty)
		_list.add_child(empty)

	# REV 215: on a pad the cursor always sits on a clue (the first one to start with)
	if _selected_id == "" and not _order.is_empty() and InputHints.using_gamepad:
		_selected_id = _order[0]
		if _clue_buttons.has(_selected_id):
			UITheme.style_button(_clue_buttons[_selected_id], true)
	_deduction_button.visible = deduction_label != ""
	_deduction_button.text = deduction_label + _pad_tag(JOY_BUTTON_Y)
	UITheme.style_button(_compare_button, _compare_mode)
	_compare_button.text = ("CANCEL COMPARE" if _compare_mode else "COMPARE EVIDENCE") + _pad_tag(JOY_BUTTON_X)
	_close_button.text = "CLOSE" + (_pad_tag(JOY_BUTTON_B) if InputHints.using_gamepad else "  [C / ESC]")

	var pick := "press [A] on" if InputHints.using_gamepad else "click"
	if _compare_mode:
		if _first_pick == "":
			_status.text = "COMPARE: %s the first clue." % pick
		else:
			_status.text = "COMPARE: %s the clue to set against '%s'." % [pick, Case.get_title(_first_pick)]
	else:
		_status.text = "Move through your clues to read them. Two clues that belong together: COMPARE EVIDENCE." if InputHints.using_gamepad \
			else "Click a clue to read it (or use the arrow keys). Two clues that belong together: COMPARE EVIDENCE."

	if _board_mode:
		_status.text = "Where the case stands - only what you have found so far."
	if _show_intro:
		_status.text = intro_text + "\n" + _status.text

	if _selected_id != "" and Case.has(_selected_id):
		_detail_title.text = Case.get_title(_selected_id)
		_detail_text.text = Case.get_text(_selected_id)
	else:
		_detail_title.text = ""
		_detail_text.text = ""


func _on_clue_pressed(clue_id: String) -> void:
	if not _compare_mode:
		_selected_id = clue_id
		_rebuild()
		return
	if _first_pick == "":
		_first_pick = clue_id
		_selected_id = clue_id
		_rebuild()
		return
	if clue_id == _first_pick:
		# Clicking the same clue again just un-picks it.
		_first_pick = ""
		_rebuild()
		return
	var a := _first_pick
	_compare_mode = false
	_first_pick = ""
	close()
	compare_requested.emit(a, clue_id)


## REV 215: move the cursor through the clues (it shows each one as it lands on it).
func _move_cursor(step: int) -> void:
	if _order.is_empty():
		return
	var i := _order.find(_selected_id)
	i = 0 if i < 0 else clampi(i + step, 0, _order.size() - 1)
	if _order[i] == _selected_id:
		return
	_selected_id = _order[i]
	SfxManager.ui("move")
	_rebuild()
	var btn: Button = _clue_buttons.get(_selected_id)
	if btn != null and _scroll != null:
		_scroll.ensure_control_visible.call_deferred(btn)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	# REV 215: keyboard arrows and the whole gamepad. Stick/d-pad move; A reads (or picks, comparing);
	# X compare on/off; Y the deduction when there is one; B or the Case File button closes.
	# REV 302: RB / LB (or TAB) switch between the clues and the investigation board
	if board_source != null and ((event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed \
			and ((event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER or (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_SHOULDER)) \
			or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_TAB)):
		_toggle_board()
		get_viewport().set_input_as_handled()
		return
	var nav := PadNav.step(event)
	if nav != 0:
		if _board_mode:
			_board_scroll.scroll_vertical += nav * 60     # the board scrolls; there's no cursor on it
		else:
			_move_cursor(nav)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion:
		return
	var jb := event as InputEventJoypadButton
	if jb != null and jb.pressed:
		if jb.button_index == JOY_BUTTON_X:
			SfxManager.ui("confirm")
			_toggle_compare()
			get_viewport().set_input_as_handled()
			return
		if jb.button_index == JOY_BUTTON_Y and deduction_label != "":
			SfxManager.ui("confirm")
			_on_deduction_pressed()
			get_viewport().set_input_as_handled()
			return
	if (jb != null or event is InputEventKey) and (event.is_action_pressed("ui_navigate_confirm") or event.is_action_pressed("ui_accept")) \
			and not (jb != null and jb.button_index == JOY_BUTTON_B):
		if _selected_id != "" and Case.has(_selected_id) and _compare_mode:
			SfxManager.ui("confirm")
			_on_clue_pressed(_selected_id)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C or event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
			return
	# REV 103: the same with a gamepad (or a rebound key)
	if event.is_action_pressed("case_file_open") or (event is InputEventJoypadButton and event.is_action_pressed("menu_cancel")):
		close()
		get_viewport().set_input_as_handled()
