extends CanvasLayer
## The watch-through's screen overlay: widescreen bars, subtitles at the bottom (speaker in gold, line in white),
## a title card in the middle, and a black fade. Same look as Vulcan Fury's cutscenes.

const BAR := 0.12          # letterbox bar height, share of the screen
var _top: ColorRect
var _bottom: ColorRect
var _sub: RichTextLabel
var _title: Label
var _fade: ColorRect


func _ready() -> void:
	layer = 50
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_top = _bar(root, true)
	_bottom = _bar(root, false)
	_sub = RichTextLabel.new()
	_sub.bbcode_enabled = true
	_sub.fit_content = true
	_sub.scroll_active = false
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.anchor_left = 0.12
	_sub.anchor_right = 0.88
	_sub.anchor_top = 1.0 - BAR + 0.012
	_sub.anchor_bottom = 1.0
	_sub.add_theme_font_size_override("normal_font_size", 26)
	_sub.add_theme_color_override("default_color", Color(1, 1, 1))
	_sub.add_theme_constant_override("outline_size", 6)
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	root.add_child(_sub)
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.45))
	_title.add_theme_constant_override("outline_size", 8)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_title.modulate.a = 0.0
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_title)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)


func _bar(root: Control, top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = 0.0 if top else 1.0 - BAR
	r.anchor_bottom = BAR if top else 1.0
	root.add_child(r)
	return r


func say(speaker: String, text: String) -> void:
	if speaker == "":
		_sub.text = "[center][i]%s[/i][/center]" % text
	else:
		_sub.text = "[center][color=#f2c75c]%s:[/color] %s[/center]" % [speaker.to_upper(), text]


func clear_line() -> void:
	_sub.text = ""


func fade_to(alpha: float, seconds: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", alpha, seconds)
	await t.finished


func title(text: String, seconds: float) -> void:
	_title.text = text
	var t := create_tween()
	t.tween_property(_title, "modulate:a", 1.0, 0.8)
	t.tween_interval(maxf(seconds - 1.6, 0.4))
	t.tween_property(_title, "modulate:a", 0.0, 0.8)
	await t.finished
