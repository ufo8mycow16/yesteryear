extends Control
class_name ChoiceMenu
## ChoiceMenu — one reusable "pick an answer" window, used for:
##   * dialogue choices   (McCoy's / Kirk's lines, Tuvall's questions)
##   * terminal screens   (a title, some text, and a list of things to open)
##   * "where to?" travel menus, equipment pickers, deduction questions
##
## It is awaited from a scene script:
##
##     var pick: int = await menu.ask("What do you say?", ["Only if you're sick.", "That depends."])
##
## `pick` is the number of the option chosen (0 = the first one), or -1 if the
## player pressed Esc on a menu that allows backing out.
##
## Controls: Up / Down + Enter (or Space), number keys 1-9, or the mouse.

signal chosen(index: int)

const WIDTH := 700.0
const TERMINAL_TEAL := Color(0.38, 0.68, 0.64)

var _open: bool = false
var _allow_cancel: bool = false
var _selected: int = 0
var _closed_at: int = -100000
var _buttons: Array[Button] = []
var _holder: VBoxContainer = null
var _places := {}     # REV 160: computer screen (title|prompt) -> the option picked last


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	add_to_group(PadNav.MENU_GROUP)


func is_open() -> bool:
	return _open


## REV 214: while open, McCoy and the camera ignore the sticks.
func pad_menu_active() -> bool:
	return _open


## prompt     : the question / line of narration shown above the options.
## options    : Array of Strings.
## title      : small heading (used for terminals: "TUVALL TERMINAL").
## allow_cancel: Esc returns -1.
## terminal   : teal "computer screen" look, centred on screen.
## body       : extra text block shown under the prompt (terminal readouts).
func ask(prompt: String, options: Array, title: String = "", allow_cancel: bool = false, terminal: bool = false, body: String = "") -> int:
	# REV 99: inside a letterboxed conversation, ordinary choices go in the letterbox's bottom bar.
	# Terminals and screens with a body of text keep this menu.
	if not terminal and body == "" and ConversationPresenter.letterboxed:
		return await ConversationPresenter.ask(options, prompt, allow_cancel)
	if _open:
		push_warning("ChoiceMenu: ask() called while a menu is already open.")
		return -1
	_allow_cancel = allow_cancel
	_build(prompt, options, title, terminal, body)
	# REV 160 (CLAUDE.md item 23): a computer screen opens on the option picked last time on that same
	# screen (same title and prompt), so backing out of a record leaves you on it
	var place_key := "%s|%s" % [title, prompt] if terminal else ""
	_selected = clampi(int(_places.get(place_key, 0)), 0, maxi(options.size() - 1, 0)) if place_key != "" else 0
	_refresh()
	_open = true
	visible = true
	# REV 168: the open sound only for a fresh screen, not for each page of one (a menu that follows
	# straight on from the last within half a second is the same screen moving on)
	UITheme.panel_open(_holder, Time.get_ticks_msec() - _closed_at > 500)     # REV 160 (item 21)
	var result: int = await chosen
	if place_key != "" and result >= 0 and result < options.size():
		# leaving a screen ("Log off", "Back") isn't a place to come back to
		if String(options[result]).strip_edges().to_lower() in ["log off", "back", "exit", "close", "cancel", "ok", "done"]:
			_places.erase(place_key)
		else:
			_places[place_key] = result
	_open = false
	visible = false
	_closed_at = Time.get_ticks_msec()
	_clear()
	return result


## REV 490: a {TIMED} choice ran out of time - the open menu returns -2.
func time_out() -> void:
	if _open:
		chosen.emit(-2)


## A single-button screen: show something and wait for OK.
func info(title: String, body: String, terminal: bool = true) -> void:
	await ask("", ["OK"], title, false, terminal, body)


func _clear() -> void:
	if _holder != null:
		remove_child(_holder)
		_holder.queue_free()
		_holder = null
	_buttons.clear()


func _build(prompt: String, options: Array, title: String, terminal: bool, body: String) -> void:
	_clear()
	_holder = VBoxContainer.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.offset_bottom = -126.0 if not terminal else -40.0
	_holder.offset_top = 40.0
	# REV 365 (Glen: Spock's "Fix the chronology" list ran under the conversation's top bar): during a
	# letterboxed conversation the menu keeps to the picture between the two bars
	var bar := ConversationPresenter.bar_height()
	if bar > 0.0:
		_holder.offset_top = maxf(_holder.offset_top, bar + 10.0)
		_holder.offset_bottom = minf(_holder.offset_bottom, -(bar + 10.0))
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.alignment = BoxContainer.ALIGNMENT_CENTER if terminal else BoxContainer.ALIGNMENT_END
	add_child(_holder)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(center)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(WIDTH, 0.0)
	if terminal:
		var style := UITheme.panel_stylebox(TERMINAL_TEAL)
		style.bg_color = Color(0.02, 0.05, 0.055, 0.96)
		panel.add_theme_stylebox_override("panel", style)
	else:
		UITheme.style_panel(panel)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	if title != "":
		var title_label := Label.new()
		title_label.text = title
		UITheme.style_title(title_label)
		title_label.add_theme_font_size_override("font_size", _px(13))
		if terminal:
			title_label.add_theme_color_override("font_color", TERMINAL_TEAL)
		column.add_child(title_label)
		column.add_child(UITheme.make_separator())

	if body != "":
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(WIDTH - 30.0, minf(60.0 + 22.0 * float(body.count("\n") + 1), 280.0))
		column.add_child(scroll)
		var body_label := Label.new()
		body_label.text = body
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_label.custom_minimum_size = Vector2(WIDTH - 50.0, 0.0)
		UITheme.style_body(body_label)
		body_label.add_theme_font_size_override("font_size", _px(14))
		if terminal:
			body_label.add_theme_color_override("font_color", Color(0.62, 0.95, 0.88))
		scroll.add_child(body_label)

	if prompt != "":
		var prompt_label := Label.new()
		prompt_label.text = prompt
		prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prompt_label.custom_minimum_size = Vector2(WIDTH - 30.0, 0.0)
		UITheme.style_body(prompt_label)
		prompt_label.add_theme_font_size_override("font_size", _px(14))
		column.add_child(prompt_label)

	for i in options.size():
		var btn := Button.new()
		var number := ("%d.  " % (i + 1)) if options.size() <= 9 else ""
		btn.text = number + String(options[i])
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(WIDTH - 30.0, 0.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", _px(14))
		btn.pressed.connect(_on_button_pressed.bind(i))
		btn.mouse_entered.connect(_on_button_hover.bind(i))
		column.add_child(btn)
		_buttons.append(btn)

	if _allow_cancel:
		var hint := Label.new()
		InputHints.bind(hint, "{menu_cancel}  to go back")     # REV 296: the pad's button on a pad
		UITheme.style_hint(hint)
		column.add_child(hint)


func _on_button_pressed(index: int) -> void:
	if not _open:
		return
	SfxManager.ui("confirm")
	chosen.emit(index)


func _on_button_hover(index: int) -> void:
	if not _open:
		return
	if _selected != index:
		SfxManager.ui("move")
	_selected = index
	_refresh()


func _refresh() -> void:
	for i in _buttons.size():
		UITheme.style_button(_buttons[i], i == _selected)
		_buttons[i].add_theme_font_size_override("font_size", _px(14))


## REV 297: menu and terminal text follows SUBTITLE TEXT SIZE (Settings > Accessibility), like the
## subtitles do - it is story text the player has to read. The buttons wrap, so bigger text just
## makes the panel taller.
static func _px(base: int) -> int:
	return int(round(float(base) * GameSettings.subtitle_scale()))


func _unhandled_input(event: InputEvent) -> void:
	if not _open or _buttons.is_empty():
		return
	# REV 214: gamepad - d-pad / either stick to move, A to choose, B to back out
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var nav := PadNav.step(event)
		if nav != 0:
			_selected = (_selected + nav + _buttons.size()) % _buttons.size()
			SfxManager.ui("move")
			_refresh()
		elif event is InputEventJoypadButton and PadNav.confirm(event):
			SfxManager.ui("confirm")
			chosen.emit(_selected)
		elif event is InputEventJoypadButton and event.is_action_pressed("menu_cancel") and _allow_cancel:
			SfxManager.ui("back")
			chosen.emit(-1)
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key == KEY_UP or key == KEY_W:
			_selected = (_selected - 1 + _buttons.size()) % _buttons.size()
			SfxManager.ui("move")
			_refresh()
		elif key == KEY_DOWN or key == KEY_S:
			_selected = (_selected + 1) % _buttons.size()
			SfxManager.ui("move")
			_refresh()
		elif key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE:
			SfxManager.ui("confirm")
			chosen.emit(_selected)
		elif key >= KEY_1 and key <= KEY_9 and (key - KEY_1) < _buttons.size():
			SfxManager.ui("confirm")
			chosen.emit(key - KEY_1)
		elif key == KEY_ESCAPE and _allow_cancel:
			SfxManager.ui("back")
			chosen.emit(-1)
		else:
			return
		get_viewport().set_input_as_handled()
