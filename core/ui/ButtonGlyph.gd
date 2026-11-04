extends Control
## REV 160 (CLAUDE.md item 17): the picture of the button that does `action`, drawn in code so it
## matches whatever pad is in use - and follows rebinding and the device the moment either changes.
##   Xbox:        round face buttons, A green / B red / X blue / Y yellow
##   PlayStation: dark round buttons with the cross (blue), circle (red), square (pink), triangle (green)
##   Nintendo:    dark round buttons with their letters
##   all pads:    shoulder buttons, triggers, the D-pad, sticks and the small menu buttons as shapes
##   keyboard:    a key cap with the key's name, as before
## Use: var g := ButtonGlyph.make("interact", 22)   (loaded by path: preload("res://core/ui/ButtonGlyph.gd"))

const GOLD := Color(0.93, 0.78, 0.38)
const CAP_FILL := Color(0.08, 0.09, 0.12, 0.92)
const XBOX_COLOURS := {"A": Color(0.33, 0.72, 0.27), "B": Color(0.86, 0.22, 0.2), "X": Color(0.18, 0.45, 0.86), "Y": Color(0.95, 0.75, 0.15)}
const PS_COLOURS := {"CROSS": Color(0.45, 0.62, 0.95), "CIRCLE": Color(0.93, 0.33, 0.35), "SQUARE": Color(0.9, 0.5, 0.78), "TRIANGLE": Color(0.3, 0.8, 0.62)}

var action := ""
var size_px := 22.0
## Only shown while a gamepad is in use (where a screen keeps its own keyboard key cap).
var pad_only := false
var _font: Font


static func make(for_action: String, px: float = 22.0, only_on_pad: bool = false) -> Control:
	var g = load("res://core/ui/ButtonGlyph.gd").new()
	g.action = for_action
	g.size_px = px
	g.pad_only = only_on_pad
	return g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	var hints := get_node_or_null("/root/InputHints")
	if hints != null:
		hints.device_changed.connect(func(_g: bool) -> void: _relayout())
	var gs := get_node_or_null("/root/GameSettings")
	if gs != null and gs.has_signal("controls_changed"):
		gs.controls_changed.connect(_relayout)
	_relayout()


## What to draw: [kind, label]. kind: face | shoulder | trigger | dpad | stick | small | key | none.
func _what() -> Array:
	var hints := get_node_or_null("/root/InputHints")
	if hints == null:
		return ["none", ""]
	var k: String = hints.key(action)
	if k == "":
		return ["none", ""]
	if not hints.using_gamepad:
		return ["key", k]
	if k.begins_with("D-PAD"):
		return ["dpad", k.substr(6)]
	if k in ["LB", "RB", "L1", "R1", "L", "R"]:
		return ["shoulder", k]
	if k in ["LT", "RT", "L2", "R2", "ZL", "ZR"]:
		return ["trigger", k]
	if k.contains("STICK") or k in ["L3", "R3"]:
		return ["stick", "L" if (k.begins_with("L")) else "R"]
	if k in ["A", "B", "X", "Y", "CROSS", "CIRCLE", "SQUARE", "TRIANGLE"]:
		return ["face", k]
	return ["small", k]


func _relayout() -> void:
	var w := _what()
	var s := size_px
	match String(w[0]):
		"none":
			custom_minimum_size = Vector2.ZERO
		"key", "small":
			var text_w := _font.get_string_size(String(w[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.55)).x
			custom_minimum_size = Vector2(maxf(s, text_w + s * 0.55), s)
		"shoulder", "trigger":
			custom_minimum_size = Vector2(s * 1.5, s)
		_:
			custom_minimum_size = Vector2(s, s)
	var hints := get_node_or_null("/root/InputHints")
	visible = String(w[0]) != "none" and (not pad_only or (hints != null and hints.using_gamepad))
	queue_redraw()


func _draw() -> void:
	var w := _what()
	var kind := String(w[0])
	var label := String(w[1])
	var hints := get_node_or_null("/root/InputHints")
	var fam: String = hints.family if hints != null else "xbox"
	var r := Rect2(Vector2.ZERO, custom_minimum_size)
	var c := r.get_center()
	var s := size_px
	match kind:
		"key":
			_round_rect(r.grow(-1), s * 0.18, CAP_FILL, GOLD)
			_text(label, c, s * 0.52, GOLD)
		"small":
			_round_rect(r.grow(-1), s * 0.45, Color(0.2, 0.21, 0.25, 0.95), Color(0.75, 0.75, 0.78))
			_text(label, c, s * 0.42, Color(0.92, 0.92, 0.94))
		"face":
			_face(label, fam, c, s * 0.48)
		"shoulder":
			_round_rect(Rect2(r.position + Vector2(1, s * 0.22), r.size - Vector2(2, s * 0.3)), s * 0.22, Color(0.2, 0.21, 0.25, 0.95), Color(0.8, 0.8, 0.83))
			_text(label, c + Vector2(0, s * 0.05), s * 0.42, Color(0.95, 0.95, 0.97))
		"trigger":
			var pts := PackedVector2Array([r.position + Vector2(s * 0.18, r.size.y - 1), r.position + Vector2(s * 0.18, s * 0.38),
				r.position + Vector2(r.size.x * 0.5, 1), r.position + Vector2(r.size.x - s * 0.18, s * 0.38), r.position + Vector2(r.size.x - s * 0.18, r.size.y - 1)])
			draw_colored_polygon(pts, Color(0.2, 0.21, 0.25, 0.95))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.8, 0.8, 0.83), 1.2, true)
			_text(label, c + Vector2(0, s * 0.12), s * 0.38, Color(0.95, 0.95, 0.97))
		"dpad":
			var a := s * 0.17
			var cross := [Rect2(c.x - a, r.position.y + 1, a * 2, s - 2), Rect2(r.position.x + 1, c.y - a, s - 2, a * 2)]
			for q in cross:
				draw_rect(q, Color(0.2, 0.21, 0.25, 0.95))
			var dir := {"UP": Vector2(0, -1), "DOWN": Vector2(0, 1), "LEFT": Vector2(-1, 0), "RIGHT": Vector2(1, 0)}
			var d: Vector2 = dir.get(label, Vector2.ZERO)
			var arm := Rect2(c - Vector2(a, a) + d * (s * 0.3), Vector2(a * 2, a * 2))
			draw_rect(arm.grow(-0.5), GOLD)
			for q in cross:
				draw_rect(q, Color(0.8, 0.8, 0.83), false, 1.0)
		"stick":
			draw_circle(c, s * 0.48, Color(0.2, 0.21, 0.25, 0.95))
			draw_arc(c, s * 0.48, 0.0, TAU, 32, Color(0.8, 0.8, 0.83), 1.2, true)
			draw_arc(c, s * 0.3, 0.0, TAU, 24, Color(0.55, 0.55, 0.6), 1.0, true)
			_text(label, c, s * 0.42, Color(0.95, 0.95, 0.97))


func _face(label: String, fam: String, c: Vector2, rad: float) -> void:
	if fam == "playstation":
		draw_circle(c, rad, Color(0.13, 0.14, 0.17, 0.97))
		draw_arc(c, rad, 0.0, TAU, 32, Color(0.6, 0.6, 0.65), 1.0, true)
		var col: Color = PS_COLOURS.get(label, Color.WHITE)
		var m := rad * 0.48
		match label:
			"CROSS":
				draw_line(c + Vector2(-m, -m), c + Vector2(m, m), col, 2.2, true)
				draw_line(c + Vector2(-m, m), c + Vector2(m, -m), col, 2.2, true)
			"CIRCLE":
				draw_arc(c, m, 0.0, TAU, 28, col, 2.2, true)
			"SQUARE":
				draw_rect(Rect2(c - Vector2(m, m) * 0.9, Vector2(m, m) * 1.8), col, false, 2.0)
			"TRIANGLE":
				var t := PackedVector2Array([c + Vector2(0, -m), c + Vector2(m * 0.95, m * 0.7), c + Vector2(-m * 0.95, m * 0.7), c + Vector2(0, -m)])
				draw_polyline(t, col, 2.0, true)
		return
	if fam == "nintendo":
		draw_circle(c, rad, Color(0.13, 0.14, 0.17, 0.97))
		draw_arc(c, rad, 0.0, TAU, 32, Color(0.75, 0.75, 0.8), 1.0, true)
		_text(label, c, rad * 1.1, Color(0.96, 0.96, 0.97))
		return
	var fill: Color = XBOX_COLOURS.get(label, Color(0.4, 0.4, 0.45))
	draw_circle(c, rad, fill.darkened(0.15))
	draw_circle(c - Vector2(0, rad * 0.06), rad * 0.86, fill)
	_text(label, c, rad * 1.1, Color(1, 1, 1))


func _round_rect(r: Rect2, radius: float, fill: Color, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _text(t: String, centre: Vector2, px: float, col: Color) -> void:
	var fs := maxi(int(px), 6)
	var sz := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var asc := _font.get_ascent(fs)
	var desc := _font.get_descent(fs)
	draw_string(_font, Vector2(centre.x - sz.x * 0.5, centre.y + (asc - desc) * 0.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
