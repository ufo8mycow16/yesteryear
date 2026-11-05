extends CanvasLayer
## The watch-through's screen overlay: widescreen bars, subtitles low on the screen over a soft shadow (speaker's
## name in gold above the line, the line typing itself out), a "carry on" marker when the game is waiting for the
## player, title cards, the choice menu and the black fade. Title cards sit ABOVE the fade so they show on black.
## (The window scales from 1280 x 720, so sizes here are at that size.)

const BAR := 0.105          # letterbox bar height, share of the screen
const TYPE_RATE := 55.0     # letters per second as a line types out
const GOLD := Color(0.98, 0.84, 0.42)

var _root: Control
var _top: ColorRect
var _bottom: ColorRect
var _shade: TextureRect
var _name: Label
var _sub: RichTextLabel
var _more: Label
var _auto: Label
var _hint: Label
var _title: Label
var _fade: ColorRect
var _type_tween: Tween = null
var _more_tween: Tween = null
var _sub_tween: Tween = null
var _sfx_move: AudioStreamPlayer
var _sfx_pick: AudioStreamPlayer
signal _picked(index: int)


func _ready() -> void:
	layer = 50
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_top = _bar(true)
	_bottom = _bar(false)
	# a soft dark shadow rising from the bottom bar, so white words read over a bright desert
	_shade = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0, 0, 0, 0.72))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	_shade.texture = gt
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.anchor_left = 0.0
	_shade.anchor_right = 1.0
	_shade.anchor_top = 1.0 - BAR - 0.17
	_shade.anchor_bottom = 1.0 - BAR + 0.002
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.modulate.a = 0.0
	_root.add_child(_shade)
	_name = Label.new()
	_name.anchor_left = 0.14
	_name.anchor_right = 0.86
	_name.anchor_top = 1.0 - BAR - 0.135
	_name.anchor_bottom = 1.0 - BAR - 0.095
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 15)
	_name.add_theme_color_override("font_color", GOLD)
	_name.add_theme_constant_override("outline_size", 4)
	_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_name)
	_sub = RichTextLabel.new()
	_sub.bbcode_enabled = true
	_sub.scroll_active = false
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.anchor_left = 0.14
	_sub.anchor_right = 0.86
	_sub.anchor_top = 1.0 - BAR - 0.095
	_sub.anchor_bottom = 1.0 - BAR + 0.06
	_sub.add_theme_font_size_override("normal_font_size", 21)
	_sub.add_theme_font_size_override("italics_font_size", 20)
	_sub.add_theme_color_override("default_color", Color(1, 1, 1))
	_sub.add_theme_constant_override("outline_size", 5)
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_sub.add_theme_constant_override("line_separation", 3)
	_root.add_child(_sub)
	_more = Label.new()
	_more.text = "▼"
	_more.anchor_left = 0.87
	_more.anchor_right = 0.9
	_more.anchor_top = 1.0 - BAR - 0.035
	_more.anchor_bottom = 1.0 - BAR + 0.01
	_more.add_theme_font_size_override("font_size", 13)
	_more.add_theme_color_override("font_color", GOLD)
	_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more.modulate.a = 0.0
	_root.add_child(_more)
	_auto = Label.new()
	_auto.text = "AUTO"
	_auto.anchor_left = 0.86
	_auto.anchor_right = 0.98
	_auto.anchor_top = 0.025
	_auto.anchor_bottom = BAR - 0.02
	_auto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_auto.add_theme_font_size_override("font_size", 13)
	_auto.add_theme_color_override("font_color", Color(GOLD, 0.75))
	_auto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_auto.visible = false
	_root.add_child(_auto)
	_hint = Label.new()
	_hint.text = "Space or click to carry on     A  auto-play     Esc  quit"
	_hint.anchor_left = 0.02
	_hint.anchor_right = 0.98
	_hint.anchor_top = 0.025
	_hint.anchor_bottom = BAR - 0.02
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.modulate.a = 0.0
	_root.add_child(_hint)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	# the title goes on after the fade, so it shows over black
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", GOLD)
	_title.add_theme_constant_override("outline_size", 6)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_title.add_theme_constant_override("line_spacing", 6)
	_title.modulate.a = 0.0
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title)
	_sfx_move = _sfx("res://assets/audio/sfx/ui_move.wav", -14.0)
	_sfx_pick = _sfx("res://assets/audio/sfx/ui_confirm.wav", -8.0)


func _bar(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = 0.0 if top else 1.0 - BAR
	r.anchor_bottom = BAR if top else 1.0
	_root.add_child(r)
	return r


func _sfx(path: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if ResourceLoader.exists(path):
		p.stream = load(path)
	p.volume_db = db
	add_child(p)
	return p


# ------------------------------------------------------------------------------------------- lines --

## Show a line. It types itself out; is_typing() says whether it's still going, finish_typing() shows the rest.
## speaker "" = a stage direction or log entry, in italics with no name.
func say(speaker: String, text: String) -> void:
	_more_off()
	if speaker == "":
		_name.text = ""
		_sub.text = "[center][i]%s[/i][/center]" % text
	else:
		_name.text = speaker.to_upper()
		_sub.text = "[center]%s[/center]" % text
	if _sub_tween != null and _sub_tween.is_valid():
		_sub_tween.kill()
	_sub.modulate.a = 1.0
	_name.modulate.a = 1.0
	if _shade.modulate.a < 1.0:
		var s := create_tween()
		s.tween_property(_shade, "modulate:a", 1.0, 0.25)
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_sub.visible_ratio = 0.0
	_type_tween = create_tween()
	_type_tween.tween_property(_sub, "visible_ratio", 1.0, maxf(text.length() / TYPE_RATE, 0.15))


func is_typing() -> bool:
	return _type_tween != null and _type_tween.is_valid() and _type_tween.is_running()


func finish_typing() -> void:
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_sub.visible_ratio = 1.0


## The little marker that says the game is waiting for Space / a click.
func show_more(on: bool) -> void:
	if not on:
		_more_off()
		return
	if _more_tween != null and _more_tween.is_valid():
		return
	_more.modulate.a = 0.0
	_more_tween = create_tween().set_loops()
	_more_tween.tween_property(_more, "modulate:a", 1.0, 0.45)
	_more_tween.tween_property(_more, "modulate:a", 0.25, 0.45)


func _more_off() -> void:
	if _more_tween != null and _more_tween.is_valid():
		_more_tween.kill()
	_more_tween = null
	_more.modulate.a = 0.0


## Clear the line - gently (a quick fade) unless now is true.
func clear_line(now := false) -> void:
	_more_off()
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	if _sub_tween != null and _sub_tween.is_valid():
		_sub_tween.kill()
	if now or _sub.text == "":
		_sub.text = ""
		_name.text = ""
		_shade.modulate.a = 0.0
		return
	_sub_tween = create_tween().set_parallel(true)
	_sub_tween.tween_property(_sub, "modulate:a", 0.0, 0.2)
	_sub_tween.tween_property(_name, "modulate:a", 0.0, 0.2)
	_sub_tween.tween_property(_shade, "modulate:a", 0.0, 0.35)
	var wipe := func() -> void:
		_sub.text = ""
		_name.text = ""
	_sub_tween.chain().tween_callback(wipe)


func set_auto(on: bool) -> void:
	_auto.visible = on


## The controls, shown in the top bar for a few seconds at the start.
func show_hint(seconds := 7.0) -> void:
	var t := create_tween()
	t.tween_property(_hint, "modulate:a", 1.0, 1.0)
	t.tween_interval(seconds)
	t.tween_property(_hint, "modulate:a", 0.0, 1.5)


# --------------------------------------------------------------------------------- fades and titles --

func fade_to(alpha: float, seconds: float) -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_fade, "color:a", alpha, seconds)
	await t.finished


func title(text: String, seconds: float) -> void:
	_title.text = text
	var t := create_tween()
	t.tween_property(_title, "modulate:a", 1.0, 1.0)
	t.tween_interval(maxf(seconds - 2.0, 0.5))
	t.tween_property(_title, "modulate:a", 0.0, 1.0)
	await t.finished


# ---------------------------------------------------------------------------------------- choices --

## A choice: the question above a column of buttons in the middle of the screen. Click one, or press its number
## (or move with the arrow keys and press Space/Enter). Returns the index picked.
func choose(prompt: String, options: PackedStringArray) -> int:
	clear_line(true)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_root.move_child(dim, _fade.get_index())
	var box := VBoxContainer.new()
	box.anchor_left = 0.22
	box.anchor_right = 0.78
	box.anchor_top = 0.3
	box.anchor_bottom = 0.8
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	_root.add_child(box)
	_root.move_child(box, _fade.get_index())
	if prompt != "":
		var q := Label.new()
		q.text = prompt
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q.add_theme_font_size_override("font_size", 24)
		q.add_theme_color_override("font_color", GOLD)
		q.add_theme_constant_override("outline_size", 6)
		q.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		box.add_child(q)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 6)
		box.add_child(gap)
	var buttons: Array[Button] = []
	for i in options.size():
		var b := Button.new()
		b.text = "%d.   %s" % [i + 1, options[i]]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 19)
		b.custom_minimum_size = Vector2(0, 50)
		_style_button(b)
		var on_press := func() -> void:
			_sfx_pick.play()
			_picked.emit(i)
		b.pressed.connect(on_press)
		b.focus_entered.connect(func() -> void: _sfx_move.play())
		b.mouse_entered.connect(func() -> void: b.grab_focus())
		box.add_child(b)
		buttons.append(b)
	box.modulate.a = 0.0
	dim.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(box, "modulate:a", 1.0, 0.5)
	t.tween_property(dim, "modulate:a", 1.0, 0.5)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_sfx_move.volume_db = -80.0          # no click for the first button taking focus
	buttons[0].grab_focus()
	_sfx_move.volume_db = -14.0
	_keys = options.size()
	var pick: int = await _picked
	_keys = 0
	for b in buttons:
		b.disabled = b != buttons[pick]
	var out := create_tween().set_parallel(true)
	out.tween_property(box, "modulate:a", 0.0, 0.6).set_delay(0.35)
	out.tween_property(dim, "modulate:a", 0.0, 0.6).set_delay(0.35)
	await out.finished
	box.queue_free()
	dim.queue_free()
	return pick


func _style_button(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.03, 0.03, 0.06, 0.78)
	normal.border_color = Color(GOLD, 0.35)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hot := normal.duplicate() as StyleBoxFlat
	hot.bg_color = Color(0.16, 0.11, 0.04, 0.9)
	hot.border_color = GOLD
	hot.set_border_width_all(2)
	var gone := normal.duplicate() as StyleBoxFlat
	gone.bg_color = Color(0.03, 0.03, 0.06, 0.4)
	gone.border_color = Color(GOLD, 0.1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("focus", hot)
	b.add_theme_stylebox_override("pressed", hot)
	b.add_theme_stylebox_override("disabled", gone)
	b.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.65, 0.5))


var _keys := 0


func _input(event: InputEvent) -> void:
	if _keys <= 0 or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var k := (event as InputEventKey).keycode
	if k >= KEY_1 and k < KEY_1 + _keys:
		get_viewport().set_input_as_handled()
		_sfx_pick.play()
		_picked.emit(int(k - KEY_1))
