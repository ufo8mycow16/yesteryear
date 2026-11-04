extends Control
class_name MissionLogUI
## "LOG" panel — opened by the HUD's LOG button. Same unwired-button bug as
## INVENTORY and SYSTEM before them: the button existed, nothing was
## connected to it. v1.2 is explicit the Mission Log is read-only and player-
## opened ("the player can open it when desired") — it never auto-opens
## itself, that's MissionLog.notification_requested's job (the fading
## "Mission Log Updated" banner HUD already shows).
##
## Unlike InventoryEquipmentUI/SettingsUI, entries aren't buttons — there's
## nothing to select, just text to read — so the keyboard-navigable list is
## just [Close]. Still rebuilt fresh on every open() so it always reflects
## MissionLog's current state.

const SELECTED_NAV_COLOR := Color(0.7, 0.7, 0.7)

var _panel: PanelContainer
var _entries_list: VBoxContainer
var _buttons: Array[Button] = []   # just [Close] — entries are read-only text
var _selected_index: int = 0
var _scroll: ScrollContainer      # REV 297: kept so the pad / arrow keys can scroll the entries

## REV 297: how far one push of the d-pad / stick scrolls, and how fast a held right stick scrolls.
const SCROLL_STEP := 60
const STICK_SCROLL_SPEED := 700.0


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(PadNav.MENU_GROUP)     # REV 297: the sticks scroll the log instead of walking McCoy

	_panel = PanelContainer.new()
	# Widened from the original 420 — v1 cramped a multi-paragraph entry
	# into a narrow column. This is the panel's own minimum; it still only
	# grows to fit actual content via get_combined_minimum_size() below.
	_panel.custom_minimum_size = Vector2(560, 0)
	UITheme.style_panel(_panel)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	# Major panel title (style_title) — distinct from each entry's own
	# heading (style_heading) below, so the panel doesn't read as one flat
	# wall of same-weight gold text.
	var title := Label.new()
	title.text = "MISSION LOG"
	UITheme.style_title(title)
	column.add_child(title)
	column.add_child(UITheme.make_separator())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_scroll = scroll

	_entries_list = VBoxContainer.new()
	_entries_list.add_theme_constant_override("separation", 16)
	_entries_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_entries_list)

	var close_btn := Button.new()
	close_btn.text = "CLOSE  [ESC]"
	InputHints.bind(close_btn, "CLOSE  {menu_cancel}")
	UITheme.style_button(close_btn)
	close_btn.pressed.connect(close)
	column.add_child(close_btn)
	_buttons.append(close_btn)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_rebuild_entries()
	visible = true
	_selected_index = 0
	_update_selection_highlight()
	UITheme.fade_in(_panel)


func close() -> void:
	visible = false


func _rebuild_entries() -> void:
	for child in _entries_list.get_children():
		child.queue_free()

	# REV 714: the CURRENT OBJECTIVE first - the goal right now, from the room's episode (EpisodeRoom.current_goal)
	var room := get_tree().current_scene
	var goal := String(room.call("current_goal")) if room != null and room.has_method("current_goal") else ""
	if goal == "":     # REV 715: no stage goal (the Prologue, between stages) - the tracker's objective
		var o := ObjectiveManager.get_current_objective()
		if o != null:
			goal = String(o.text)
	if goal != "":
		var head := Label.new()
		head.text = "CURRENT OBJECTIVE"
		UITheme.style_heading(head)
		_entries_list.add_child(head)
		var gl := Label.new()
		gl.text = goal
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD
		gl.custom_minimum_size = Vector2(520, 0)
		UITheme.style_body(gl)
		_entries_list.add_child(gl)
		# REV 741 (item 7): what to do next, under it
		var step := String(room.call("current_step")) if room != null and room.has_method("current_step") else ""
		if step != "" and step != goal:
			var sh := Label.new()
			sh.text = "NEXT STEP"
			UITheme.style_heading(sh)
			_entries_list.add_child(sh)
			var sl := Label.new()
			sl.text = step
			sl.autowrap_mode = TextServer.AUTOWRAP_WORD
			sl.custom_minimum_size = Vector2(520, 0)
			UITheme.style_body(sl)
			_entries_list.add_child(sl)
		_entries_list.add_child(UITheme.make_separator())

	var entries := MissionLog.get_all_entries()
	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(nothing logged yet)"
		UITheme.style_hint(empty_label)
		_entries_list.add_child(empty_label)
	else:
		for i in range(entries.size()):
			var entry = entries[i]
			# Thin horizontal divider between entries instead of nesting each
			# one in its own bordered box — the brief's explicit preference.
			if i > 0:
				_entries_list.add_child(UITheme.make_separator())

			var title_label := Label.new()
			title_label.text = entry.title
			UITheme.style_heading(title_label)
			_entries_list.add_child(title_label)

			var text_label := Label.new()
			text_label.text = entry.current_text
			text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			text_label.custom_minimum_size = Vector2(520, 0)
			UITheme.style_body(text_label)
			_entries_list.add_child(text_label)

	# Same centering idiom as InventoryEquipmentUI/SettingsUI.
	var content_size: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = content_size
	var viewport_size: Vector2 = get_viewport_rect().size
	_panel.position = (viewport_size - content_size) / 2.0


func pad_menu_active() -> bool:
	return is_visible_in_tree()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _buttons.is_empty():
		return

	# REV 297: d-pad / stick / arrow keys scroll the entries a step at a time (PadNav: one step per push).
	var nav := PadNav.step(event)
	if nav != 0:
		_scroll.scroll_vertical += nav * SCROLL_STEP
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_navigate_confirm"):
		_buttons[_selected_index].emit_signal("pressed")
	elif event.is_action_pressed("menu_cancel"):
		close()


## REV 297: holding the right stick up/down scrolls smoothly (as well as the one-step pushes above).
func _process(delta: float) -> void:
	if not visible or _scroll == null:
		return
	var y := 0.0
	for pad in Input.get_connected_joypads():
		var v := Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y)
		if absf(v) > absf(y):
			y = v
	if absf(y) > PadNav.PUSH:
		_scroll.scroll_vertical += int(y * STICK_SCROLL_SPEED * delta)


func _update_selection_highlight() -> void:
	for i in range(_buttons.size()):
		_buttons[i].modulate = Color.WHITE if i == _selected_index else SELECTED_NAV_COLOR
		if i == _selected_index:
			_buttons[i].grab_focus()
