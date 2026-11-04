extends Control
class_name InstrumentPanel
## REV 505 (Episode 2 redesign, EPISODE2_SCRIPT.md: "the deductions are things you DO"): one hands-on
## instrument screen for every "turn it until it fits" / "point at the part that matters" puzzle -
## Sickbay's neural monitor (lay one repetition over another), the scanner's resolution dial, Chapel's
## frame-by-frame recording and her curve test, Meld Two's calibration and rebound dials, the science
## station's three filters. A room opens it, draws its own picture into it, and listens.
##
## Works with a pad (Nikki plays with an Xbox pad only), the keyboard and the mouse:
##   DIALS mode  - left/right (d-pad, stick, arrows, A/D) chooses a control, up/down (W/S) turns it;
##                 the mouse: click a control to choose it, wheel or click its top/bottom half to turn it.
##   PICK mode   - left/right moves the cursor along the picture's regions, A / Enter / a click picks one.
##   Both        - B / Esc leaves (if allowed).
##
## cfg (Dictionary):
##   title        small heading, e.g. "NEURAL MONITOR - TURIAN"
##   mode         "dials" (default) or "pick"
##   dials        [{"name": "DAMPING", "steps": 7, "value": 3, "labels": [..] (optional)}, ...]
##   regions      PICK mode: how many regions across the picture (the cursor's stops)
##   region_names PICK mode: optional label per region, shown under the cursor
##   draw         Callable(panel, rect: Rect2) - draws the picture with the panel's draw_* calls
##   solved       Callable(values: Array) -> bool - DIALS mode: checked after every turn; true closes the
##                panel with result "solved" (after a short beat so the player SEES it lock)
##   changed      Callable(values: Array, which: int) - DIALS mode: told about every turn (no await)
##   cancel       true (default) = B / Esc leaves with result "cancel"
##   confirm      DIALS mode: a label for A (e.g. "PRINT") - A then closes with result "confirm"
##   height       picture height in pixels (default 220)
##   region_rects PICK mode (REV 643): [Rect2, ...] in fractions of the picture (0..1) - hand-placed regions
##                instead of equal strips (the cursor steps through them in this order)
##   picture      (REV 643) a Texture2D drawn filling the picture area (under `draw`); swap with p.cfg["picture"]
##   moved        PICK mode (REV 597): Callable(index) - told when the cursor lands on a region (a room can
##                say the choice aloud - Nikki doesn't read)
## Rooms: `var p := InstrumentPanel.open(ui_canvas, cfg)`, then either `await p.finished` (dials) or
## loop on `var i: int = await p.picked` (pick; -1 = left) and call `p.close()` when done.
## While it's open the sticks don't walk anyone (it's in PadNav's menu group).

signal finished(result: String)
signal picked(index: int)

const W := 640.0
const PAD := 14.0
const DIAL_H := 64.0
const LINE := Color(0.55, 0.85, 1.0)
const TARGET := Color(0.95, 0.80, 0.40)
const HOT := Color(1.0, 0.45, 0.35)
const GOOD := Color(0.45, 0.95, 0.55)

var cfg: Dictionary = {}
var values: Array = []
var selected := 0          # the chosen control (dials) or the cursor's region (pick)
var marks := {}            # region index -> Color: rooms highlight regions (a grabbed repetition, say)
var status := ""           # one short line under the picture, set by the room
var status_color := Color(0.92, 0.92, 0.9)
var result := ""
var _open := false
var _held := {}            # stick axis -> pushed
var _font: Font = null
var _locking := false      # solved: a short beat before closing


static func open(parent: Node, c: Dictionary) -> InstrumentPanel:
	var p := InstrumentPanel.new()
	p.cfg = c
	parent.add_child(p)
	return p


func _ready() -> void:
	add_to_group(PadNav.MENU_GROUP)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = UITheme.font_bold if UITheme.font_bold != null else ThemeDB.fallback_font
	for d in cfg.get("dials", []):
		values.append(int((d as Dictionary).get("value", 0)))
	var h := _height()
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -W * 0.5
	offset_right = W * 0.5
	offset_top = 40.0
	offset_bottom = 40.0 + h
	_open = true
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, UITheme.dur(0.18))
	SfxManager.ui("open")
	queue_redraw()


func pad_menu_active() -> bool:
	return _open


func is_pick() -> bool:
	return String(cfg.get("mode", "dials")) == "pick"


func _height() -> float:
	var h := PAD * 2.0 + 22.0 + float(cfg.get("height", 220.0)) + 26.0 + 22.0
	if not is_pick():
		h += DIAL_H + PAD
	return h


func picture_rect() -> Rect2:
	return Rect2(PAD, PAD + 22.0, W - PAD * 2.0, float(cfg.get("height", 220.0)))


func _dial_rect(i: int) -> Rect2:
	var n: int = maxi((cfg.get("dials", []) as Array).size(), 1)
	var pr := picture_rect()
	var top := pr.end.y + 26.0 + PAD * 0.5
	var w := (W - PAD * 2.0 - (n - 1) * PAD) / n
	return Rect2(PAD + i * (w + PAD), top, w, DIAL_H)


## Region i of the picture (PICK mode).
func region_rect(i: int) -> Rect2:
	var n: int = maxi(int(cfg.get("regions", 1)), 1)
	var pr := picture_rect()
	var rr: Array = cfg.get("region_rects", [])
	if i < rr.size():
		var f: Rect2 = rr[i]
		return Rect2(pr.position + f.position * pr.size, f.size * pr.size)
	var w := pr.size.x / n
	return Rect2(pr.position.x + i * w, pr.position.y, w, pr.size.y)


## A dial's value as 0..1 (rooms' drawing uses it).
func frac(i: int) -> float:
	var d: Dictionary = (cfg.get("dials", []) as Array)[i]
	return float(values[i]) / float(maxi(int(d.get("steps", 2)) - 1, 1))


func close(res: String = "") -> void:
	if not _open:
		return
	_open = false
	if res != "":
		result = res
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, UITheme.dur(0.15))
	t.tween_callback(queue_free)
	if is_pick():
		picked.emit(-1)
	finished.emit(result)


func set_status(text: String, color: Color = Color(0.92, 0.92, 0.9)) -> void:
	status = text
	status_color = color
	queue_redraw()


# ---- input ----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _open or _locking:
		return
	if AudioSubtitleManager.is_line_active():
		return     # someone's talking - wait for them (A skips the line, not the puzzle)
	var dx := 0
	var dy := 0
	var ok := false
	var back := false
	var jb := event as InputEventJoypadButton
	var jm := event as InputEventJoypadMotion
	if jb != null and jb.pressed:
		match jb.button_index:
			JOY_BUTTON_DPAD_LEFT: dx = -1
			JOY_BUTTON_DPAD_RIGHT: dx = 1
			JOY_BUTTON_DPAD_UP: dy = 1
			JOY_BUTTON_DPAD_DOWN: dy = -1
		if PadNav.confirm(event):
			ok = true
		elif event.is_action_pressed("menu_cancel") or jb.button_index == JOY_BUTTON_B:
			back = true
	elif jm != null:
		var key := "%d:%d" % [jm.device, jm.axis]
		if absf(jm.axis_value) < PadNav.RELEASE:
			_held.erase(key)
		elif absf(jm.axis_value) > PadNav.PUSH and not _held.has(key):
			_held[key] = true
			if jm.axis == JOY_AXIS_LEFT_X or jm.axis == JOY_AXIS_RIGHT_X:
				dx = 1 if jm.axis_value > 0.0 else -1
			elif jm.axis == JOY_AXIS_LEFT_Y or jm.axis == JOY_AXIS_RIGHT_Y:
				dy = -1 if jm.axis_value > 0.0 else 1
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_LEFT, KEY_A: dx = -1
			KEY_RIGHT, KEY_D: dx = 1
			KEY_UP, KEY_W: dy = 1
			KEY_DOWN, KEY_S: dy = -1
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E: ok = true
			KEY_ESCAPE, KEY_BACKSPACE: back = true
	elif event is InputEventMouseMotion:
		_mouse_hover((event as InputEventMouseMotion).position - global_position)
		return
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		var at := mb.position - global_position
		if not Rect2(Vector2.ZERO, size).has_point(at):
			return
		get_viewport().set_input_as_handled()
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_turn(1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_turn(-1)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_leave()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_mouse_click(at)
		return
	else:
		return
	if dx == 0 and dy == 0 and not ok and not back:
		return
	get_viewport().set_input_as_handled()
	if back:
		_leave()
	elif ok:
		_confirm()
	elif dx != 0:
		var n := int(cfg.get("regions", 1)) if is_pick() else (cfg.get("dials", []) as Array).size()
		if n > 0:
			selected = (selected + dx + n) % n
			SfxManager.ui("move")
			queue_redraw()
			_told_moved()
	elif dy != 0 and not is_pick():
		_turn(dy)


func _told_moved() -> void:
	var mv: Callable = cfg.get("moved", Callable())
	if is_pick() and mv.is_valid():
		mv.call(selected)


func _leave() -> void:
	if not bool(cfg.get("cancel", true)):
		return
	SfxManager.ui("back")
	close("cancel")


func _confirm() -> void:
	if is_pick():
		SfxManager.ui("confirm")
		picked.emit(selected)
		return
	if String(cfg.get("confirm", "")) != "":
		SfxManager.ui("confirm")
		close("confirm")


func _turn(dir: int) -> void:
	var dials: Array = cfg.get("dials", [])
	if is_pick() or dials.is_empty():
		return
	var d: Dictionary = dials[selected]
	var v := clampi(int(values[selected]) + dir, 0, int(d.get("steps", 2)) - 1)
	if v == int(values[selected]):
		SfxManager.ui("invalid", -8.0)
		return
	values[selected] = v
	SfxManager.ui("move")
	var ch: Callable = cfg.get("changed", Callable())
	if ch.is_valid():
		ch.call(values.duplicate(), selected)
	queue_redraw()
	var sv: Callable = cfg.get("solved", Callable())
	if sv.is_valid() and bool(sv.call(values.duplicate())):
		_lock_in()


func _lock_in() -> void:
	_locking = true
	SfxManager.ui("confirm")
	status_color = GOOD
	queue_redraw()
	await get_tree().create_timer(0.9, false).timeout
	_locking = false
	close("solved")


func _mouse_hover(at: Vector2) -> void:
	if is_pick():
		for i in int(cfg.get("regions", 1)):
			if region_rect(i).has_point(at) and selected != i:
				selected = i
				queue_redraw()
				_told_moved()
				return


func _mouse_click(at: Vector2) -> void:
	if is_pick():
		for i in int(cfg.get("regions", 1)):
			if region_rect(i).has_point(at):
				selected = i
				_confirm()
				return
		return
	for i in (cfg.get("dials", []) as Array).size():
		var r := _dial_rect(i)
		if r.has_point(at):
			if selected != i:
				selected = i
				SfxManager.ui("move")
				queue_redraw()
			else:
				_turn(1 if at.y < r.get_center().y else -1)
			return


# ---- drawing ----------------------------------------------------------------------------------

func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	draw_style_box(UITheme.panel_stylebox(UITheme.GOLD), full)
	draw_string(_font, Vector2(PAD, PAD + 12.0), String(cfg.get("title", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.GOLD_BRIGHT)
	var pr := picture_rect()
	draw_rect(pr, Color(0.0, 0.03, 0.04, 0.95))
	# a faint grid, like every TOS display
	for gx in range(1, 8):
		var x := pr.position.x + pr.size.x * gx / 8.0
		draw_line(Vector2(x, pr.position.y), Vector2(x, pr.end.y), Color(0.2, 0.35, 0.4, 0.25), 1.0)
	for gy in range(1, 4):
		var y := pr.position.y + pr.size.y * gy / 4.0
		draw_line(Vector2(pr.position.x, y), Vector2(pr.end.x, y), Color(0.2, 0.35, 0.4, 0.25), 1.0)
	var pic: Texture2D = cfg.get("picture", null)
	if pic != null:
		draw_texture_rect(pic, pr, false)
	if is_pick():
		for k in marks.keys():
			var mr := region_rect(int(k))
			draw_rect(mr, Color(marks[k], 0.18))
	var dr: Callable = cfg.get("draw", Callable())
	if dr.is_valid():
		dr.call(self, pr)
	if is_pick():
		var r := region_rect(selected)
		draw_rect(r, Color(UITheme.GOLD_BRIGHT, 0.12))
		draw_rect(r, UITheme.GOLD_BRIGHT, false, 2.0)
		var names: Array = cfg.get("region_names", [])
		if selected < names.size() and String(names[selected]) != "":
			draw_string(_font, Vector2(r.position.x + 4.0, r.end.y - 6.0), String(names[selected]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8.0, 11, UITheme.GOLD_BRIGHT)
	draw_rect(pr, UITheme.GOLD_DIM, false, 1.0)
	# the status line
	if status != "":
		draw_string(_font, Vector2(PAD, pr.end.y + 18.0), status, HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2.0, 12, status_color)
	# the controls
	if not is_pick():
		var dials: Array = cfg.get("dials", [])
		for i in dials.size():
			_draw_dial(i, dials[i])
	# what the buttons do
	var hint := ""
	if is_pick():
		hint = "< >  MOVE      " + InputHints.fill("{interact} PICK")
	else:
		hint = "< >  CHOOSE      ^ v  TURN"
		if String(cfg.get("confirm", "")) != "":
			hint += "      " + InputHints.fill("{interact} " + String(cfg["confirm"]))
	if bool(cfg.get("cancel", true)):
		hint += "      " + InputHints.fill("{menu_cancel} LEAVE")
	draw_string(_font, Vector2(PAD, size.y - PAD * 0.6), hint, HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2.0, 10, UITheme.TEXT_DIM)


func _draw_dial(i: int, d: Dictionary) -> void:
	var r := _dial_rect(i)
	var on := i == selected
	draw_style_box(UITheme.button_stylebox(on), r)
	draw_string(_font, r.position + Vector2(8.0, 16.0), String(d.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16.0, 11,
		UITheme.GOLD_BRIGHT if on else UITheme.TEXT_DIM)
	var steps: int = maxi(int(d.get("steps", 2)), 2)
	var v := int(values[i])
	var labels: Array = d.get("labels", [])
	if v < labels.size():
		draw_string(_font, r.position + Vector2(8.0, 34.0), String(labels[v]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16.0, 12, UITheme.TEXT_PRIMARY)
	# the scale: one tick per step, the setting lit
	var y := r.end.y - 14.0
	var x0 := r.position.x + 10.0
	var x1 := r.end.x - 10.0
	draw_line(Vector2(x0, y), Vector2(x1, y), UITheme.GOLD_DIM, 2.0)
	for s in steps:
		var x := lerpf(x0, x1, float(s) / float(steps - 1))
		draw_line(Vector2(x, y - 4.0), Vector2(x, y + 4.0), UITheme.GOLD_DIM, 1.0)
	var vx := lerpf(x0, x1, float(v) / float(steps - 1))
	draw_circle(Vector2(vx, y), 6.0, UITheme.GOLD_BRIGHT if on else UITheme.GOLD)


## Helpers for rooms' pictures -------------------------------------------------------------------

## A trace through the rect: f(t) gives 0..1 (bottom..top) for t 0..1; a negative value leaves a gap
## (nothing drawn there).
func draw_trace(rect: Rect2, f: Callable, color: Color = LINE, width: float = 2.0, samples: int = 160) -> void:
	var pts := PackedVector2Array()
	for s in samples + 1:
		var t := float(s) / float(samples)
		var raw := float(f.call(t))
		if raw < 0.0:
			if pts.size() > 1:
				draw_polyline(pts, color, width, true)
			pts = PackedVector2Array()
			continue
		var v := clampf(raw, 0.0, 1.0)
		pts.append(Vector2(rect.position.x + rect.size.x * t, rect.end.y - rect.size.y * v))
	if pts.size() > 1:
		draw_polyline(pts, color, width, true)


## A label inside the picture.
func draw_label(at: Vector2, text: String, color: Color = TARGET, font_size: int = 11) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## A smooth bump (0..1) centred on c, width w - for drawing pattern repeats.
static func bump(t: float, c: float, w: float) -> float:
	var x := (t - c) / maxf(w, 0.0001)
	return exp(-x * x * 4.0)
