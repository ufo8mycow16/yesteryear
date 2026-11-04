extends Control
class_name ExamineView
## Close-up view of a clue: a datapad, a scorecard, a scan readout. A framed
## card with a title, a picture area and the text you can read, like the zoomed
## evidence screens in classic detective adventures.
##
## From any hotspot script:
##
##     await show_closeup("SCOREBOARD REPLAY", "Seven frames.\nSeven strikes.", null, "SCAN")
##
## (Hotspot.show_closeup opens this card and waits until the player closes it; leave out
## the `await` to carry on straight away. Anything else holding this node can
## `await view.closed`. REV 293: the old note named a closeup_closed() that never existed.)
##
## `image` is any Texture2D (a photo, a drawing); without one, a datapad-style
## screen is drawn with the text on it. Close with interact (F / A), ENTER / SPACE,
## cancel (ESC / B), or a click. The hint at the bottom names the real keys or pad
## buttons (REV 293, InputHints). While it's open it is in PadNav's "pad_menus" group,
## so the sticks don't walk the player or turn the camera behind it (REV 293).

signal closed()

var _panel: PanelContainer
var _kind_label: Label
var _title_label: Label
var _image_rect: TextureRect
var _screen_panel: PanelContainer
var _screen_text: Label
var _body_label: Label
var _hint_label: Label


func _ready() -> void:
	add_to_group("examine_view")
	add_to_group(PadNav.MENU_GROUP)     # REV 293
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = PanelContainer.new()
	UITheme.style_panel(_panel)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(620, 0)
	_panel.add_child(column)

	_kind_label = Label.new()
	UITheme.style_dim(_kind_label)
	column.add_child(_kind_label)

	_title_label = Label.new()
	UITheme.style_title(_title_label)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title_label)
	column.add_child(UITheme.make_separator())

	# Picture area: either a real image or the drawn datapad screen.
	_image_rect = TextureRect.new()
	_image_rect.custom_minimum_size = Vector2(0, 260)
	_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(_image_rect)

	_screen_panel = PanelContainer.new()
	_screen_panel.custom_minimum_size = Vector2(0, 220)
	var screen_style := StyleBoxFlat.new()
	screen_style.bg_color = Color(0.02, 0.1, 0.11, 1.0)
	screen_style.border_color = Color(0.38, 0.68, 0.64)
	screen_style.set_border_width_all(3)
	screen_style.set_corner_radius_all(10)
	screen_style.set_content_margin_all(18)
	_screen_panel.add_theme_stylebox_override("panel", screen_style)
	column.add_child(_screen_panel)
	_screen_text = Label.new()
	_screen_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_screen_text.add_theme_color_override("font_color", Color(0.6, 1.0, 0.92))
	_screen_text.add_theme_font_size_override("font_size", 17)
	_screen_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen_panel.add_child(_screen_text)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_body(_body_label)
	column.add_child(_body_label)

	_hint_label = Label.new()
	UITheme.style_dim(_hint_label)
	column.add_child(_hint_label)
	_refresh_hint()
	InputHints.device_changed.connect(func(_pad: bool) -> void: _refresh_hint())   # REV 293


## REV 293: while the card is up, the player and the camera ignore the sticks (PadNav.any_open).
func pad_menu_active() -> bool:
	return visible


## REV 293: "[F] / CLICK  CLOSE" with keyboard and mouse, "[A]  CLOSE" on a pad (from the live bindings).
func _refresh_hint() -> void:
	if _hint_label == null:
		return
	if InputHints.using_gamepad:
		_hint_label.text = InputHints.fill("{interact}  CLOSE")
	else:
		_hint_label.text = InputHints.fill("{interact} / CLICK  CLOSE")


## image == null: the text is shown on a drawn datapad screen.
## image given:   the picture is shown, with the text beneath it.
func show_card(title: String, body: String, image: Texture2D = null, kind: String = "EXAMINE") -> void:
	_kind_label.text = kind.to_upper()
	_title_label.text = title.to_upper()
	if image != null:
		_image_rect.texture = image
		_image_rect.visible = true
		_screen_panel.visible = false
		_body_label.text = body
		_body_label.visible = body != ""
	else:
		_image_rect.visible = false
		_screen_panel.visible = true
		_screen_text.text = body
		_body_label.visible = false
	visible = true
	SfxManager.ui("open")
	await _fit_to_content()
	# REV 144: fade in only AFTER the card is placed - fade_in slides the panel back to wherever it
	# was when called, which on the first showing was the top-left corner (half the bug Glen saw)
	if visible:
		UITheme.fade_in(_panel)


## REV 144: the card is sized to what it holds. The wrapped text used to be measured with no width
## to wrap to, so every word counted as its own line - the card came out half the screen wide and
## nearly the full height, with a big empty block under the text (Glen's Scoreboard Replay screenshot).
## Now the text width is fixed first (about 38% of the screen, within sensible limits) and the height
## follows from the real wrapped lines; it is re-measured once layout has settled.
func _fit_to_content() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var width := clampf(viewport_size.x * 0.38, 520.0, 760.0)
	var column := _panel.get_child(0) as Control
	column.custom_minimum_size = Vector2(width, 0)
	# A wrapping Label measures its height from its CURRENT width, so give each one its final width
	# now (not just a minimum), or the first measurement wraps every word onto its own line.
	for label in [_title_label, _body_label]:
		(label as Label).custom_minimum_size = Vector2(width, 0)
		(label as Label).size = Vector2(width, 0)
	_screen_text.custom_minimum_size = Vector2(width - 36.0, 0)   # inside the screen's 18 px margins
	_screen_text.size = Vector2(width - 36.0, 0)
	_screen_panel.custom_minimum_size = Vector2(0, 90)   # a datapad, even for one line
	_panel.modulate.a = 0.0
	_center_panel()
	for _i in 2:     # let the containers settle, then measure for real
		await get_tree().process_frame
	if visible:
		_center_panel()


func _center_panel() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	_panel.reset_size()
	var content_size: Vector2 = _panel.get_combined_minimum_size()
	content_size.y = minf(content_size.y, viewport_size.y - 40.0)
	_panel.size = content_size
	_panel.position = ((viewport_size - content_size) / 2.0).round()


func close() -> void:
	if not visible:
		return
	visible = false
	SfxManager.ui("close")
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var close_now := event.is_action_pressed("interact") \
		or event.is_action_pressed("menu_cancel") \
		or event.is_action_pressed("ui_navigate_confirm")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_now = true
	if close_now:
		close()
		get_viewport().set_input_as_handled()
