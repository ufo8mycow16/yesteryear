extends Control
class_name TurboliftUI
## TurboliftUI — the turbolift control console. A cutaway of the whole Enterprise fills
## the top of the screen; below it is a 1960s-style wall panel with a "Ship's Directory"
## screen: one row (with a round lamp button) per place you can go. Only decks that have
## a room in the game are listed.
## Pointing at a row (mouse, or the arrow keys) lights that deck on the cutaway and
## shows what is on it on the second screen. Click (or ENTER) to go there.
##
##     var key: String = await turbolift_ui.run(current_deck)
##
## Returns the Ep1.ROOMS key of the chosen room, or "" if the player backed out.
## The decks and their rooms come from ShipDecks.gd, so a new room gets a new button
## by itself.

signal finished(room_key: String)

# ---- the cutaway: a cleaned-up copy of the Franz Joseph "Inboard Profile" (sheet 5) --------
# assets/ui/turbolift/ship_clean.png is the ship with every deck blank; deck_00.png ..
# deck_24.png are one-deck cut-outs used to light a deck up. All are the same size.
const SHIP_DIR := "res://assets/ui/turbolift/"
const IMG_W := 2172.0            # the supplied Enterprise profile artwork, used as it is (its own pixels)
const IMG_H := 724.0
const IMG_X0 := 0.0
const IMG_Y0 := 0.0
# Deck n's band on the artwork (pixels of the picture): the middle height, and the left- and right-most points of
# the hull inside that band. deck_NN.png are the matching cut-outs, same size as the picture, used only to light a
# deck up over the untouched artwork. Deck 0 is the dome cap, Deck 1 the bridge module under it.
const DECK_MID_Y := [108.0, 137.5, 162.0, 184.0, 206.0, 228.0, 250.0, 272.0, 294.0, 316.0, 338.0, 360.0, 382.0, 403.5, 425.0, 447.0, 469.0, 491.0, 513.0, 535.0, 557.0, 579.0, 601.0, 623.0, 645.0]
const DECK_LEFT_X := [472.0, 434.0, 403.0, 390.0, 281.0, 59.0, 60.0, 75.0, 247.0, 335.0, 393.0, 448.0, 506.0, 901.0, 872.0, 818.0, 766.0, 766.0, 768.0, 764.0, 769.0, 766.0, 816.0, 833.0, 844.0]
const DECK_RIGHT_X := [617.0, 653.0, 696.0, 711.0, 803.0, 1052.0, 1052.0, 1041.0, 1033.0, 1057.0, 1081.0, 1105.0, 1129.0, 1152.0, 1451.0, 1648.0, 1654.0, 1667.0, 1668.0, 1674.0, 1670.0, 1539.0, 1493.0, 1430.0, 1227.0]

const BLUEPRINT := Color(0.40, 0.78, 1.0)
const GRID := Color(0.40, 0.78, 1.0, 0.10)
const LAMP_COLOURS := [
	Color(0.88, 0.24, 0.20), Color(0.96, 0.64, 0.20), Color(0.97, 0.86, 0.34),
	Color(0.30, 0.76, 0.42), Color(0.30, 0.58, 0.92), Color(0.86, 0.86, 0.84)]
const CREAM := Color(0.87, 0.86, 0.82)
const BRONZE := Color(0.84, 0.56, 0.28)
const BRONZE_BRIGHT := Color(0.95, 0.67, 0.35)

var _open: bool = false
var _entries: Array = []          # {deck, rooms, name}: one per deck that has a room
var _loc_buttons: Array[Button] = []
var _shown_row: int = -1
var _first: int = 0                # the first deck row showing (the list scrolls)
var _vis_rows: int = 8
var _up_rect: Rect2 = Rect2()
var _dn_rect: Rect2 = Rect2()
var _buttons: Array[Button] = []
var _here_deck: int = -1
var _here_key: String = ""
var _hover_deck: int = -1

var _ship_scale: float = 1.0
var _ship_origin: Vector2 = Vector2.ZERO
var _console: Rect2 = Rect2()
var _screen: Rect2 = Rect2()
var _rundown: Rect2 = Rect2()
var _grille: Rect2 = Rect2()
var _rail: Rect2 = Rect2()
var _row_h: float = 24.0
var _rows_top: float = 0.0
var _hover_row: int = -1
var _tex_ship: Texture2D = null
var _tex_deck: Array = []

var _dim: ColorRect
var _view: Control
var _title: Label
var _hint: Label
var _scr_head: Label
var _scr_name: Label
var _scr_parts: Label
var _scr_text: Label
var _scr_go: Label
var _scr_title: Label
var _scr_dir: Label
var _scr_cols: Label
var _scr_cols2: Label


func _ready() -> void:
	visible = false
	add_to_group(PadNav.MENU_GROUP)     # REV 297: McCoy and the camera ignore the sticks while it's open
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex_ship = _load_tex(SHIP_DIR + "ship_clean.png")
	for n in range(ShipDecks.COUNT):
		_tex_deck.append(_load_tex(SHIP_DIR + "deck_%02d.png" % n))

	_dim = ColorRect.new()
	_dim.color = Color(0.01, 0.03, 0.07, 1.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_all)
	add_child(_view)

	_title = Label.new()
	UITheme.style_title(_title)
	_title.text = "U.S.S. ENTERPRISE  NCC-1701"
	_title.position = Vector2(30.0, 12.0)
	add_child(_title)

	_hint = Label.new()
	UITheme.style_hint(_hint)
	_hint.text = "UP / DOWN: choose      ENTER / CLICK: go      MOUSE WHEEL: scroll      ESC: stay here"
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 34.0
	_hint.offset_top = -24.0
	add_child(_hint)

	_scr_head = _screen_label(12, BRONZE, false)
	_scr_name = _screen_label(19, BRONZE_BRIGHT, true)
	_scr_parts = _screen_label(11, BRONZE, false)
	_scr_text = _screen_label(12, Color(0.94, 0.80, 0.63), false)
	_scr_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scr_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_scr_text.clip_text = true
	_scr_go = _screen_label(12, Color(0.98, 0.85, 0.40), true)
	_scr_go.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scr_title = _screen_label(15, BRONZE_BRIGHT, true)
	_scr_title.text = "TURBOSHAFT NETWORK STATUS"
	_scr_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scr_dir = _screen_label(13, BRONZE, true)
	_scr_dir.text = "SHIP'S DIRECTORY"
	_scr_dir.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scr_cols = _screen_label(11, BRONZE, true)
	_scr_cols.text = "DECK"
	_scr_cols2 = _screen_label(11, BRONZE, true)
	_scr_cols2.text = "LOCATION"


func _screen_label(size: int, colour: Color, bold: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	var f: Font = UITheme.font_bold if bold else UITheme.font_regular
	if f != null:
		l.add_theme_font_override("font", f)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func is_open() -> bool:
	return _open


## REV 297: PadNav asks this - true while the console is up, so the sticks only move the list.
func pad_menu_active() -> bool:
	return _open and is_visible_in_tree()


## Opens the console and waits for a choice. current_deck / current_key mark where you are.
func run(current_deck: int, current_key: String = "") -> String:
	_here_deck = current_deck
	_here_key = current_key
	_hover_deck = -1
	_hover_row = -1
	_build_entries()
	_layout()
	visible = true
	_open = true
	SfxManager.ui("open")
	UITheme.fade_in(self)
	var first := 0
	for i in range(_entries.size()):
		for r in (_entries[i]["rooms"] as Array):
			if String(r[0]) == current_key:
				first = i
	if not _buttons.is_empty():
		_scroll_to(first)
		_buttons[first].grab_focus()
		_show(first)
	var result: String = await finished
	_open = false
	visible = false
	return result


# =========================================================================
# Directory rows: one per DECK (a round lamp button each). A deck with several places in
# it shows them as a short list on the second screen.
# =========================================================================

func _build_entries() -> void:
	_entries.clear()
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	_clear_loc_buttons()
	_shown_row = -1
	_first = 0
	for d in ShipDecks.DECKS:
		# REV 593: rooms from a later episode (a third value) aren't listed by earlier episodes' lifts
		var rooms: Array = []
		for r in (d["rooms"] as Array):
			if (r as Array).size() < 3 or int(r[2]) <= ShipDecks.episode:
				rooms.append(r)
		if rooms.is_empty():
			continue
		_entries.append({"deck": int(d["n"]), "rooms": rooms, "name": String(d["name"])})
	for i in range(_entries.size()):
		_buttons.append(_make_row(i))


func _row_text(e: Dictionary) -> String:
	var rooms: Array = e["rooms"]
	var txt: String = String(rooms[0][1]).to_upper() if rooms.size() == 1 else "%s  (%d PLACES)" % [String(e["name"]).to_upper(), rooms.size()]
	for r in rooms:
		if String(r[0]) == _here_key:
			txt += "     < YOU ARE HERE"
	return txt


func _make_row(i: int) -> Button:
	var e: Dictionary = _entries[i]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	var none := StyleBoxEmpty.new()
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(0.28, 0.17, 0.06)
	b.add_theme_stylebox_override("normal", none)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("focus", lit)
	b.add_theme_stylebox_override("pressed", lit)
	add_child(b)
	var num := Label.new()
	num.name = "Num"
	num.text = "%d" % int(e["deck"])
	var loc := Label.new()
	loc.name = "Loc"
	loc.text = _row_text(e)
	for l in [num, loc]:
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", BRONZE)
		if UITheme.font_bold != null:
			l.add_theme_font_override("font", UITheme.font_bold)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
	b.mouse_entered.connect(_on_hover.bind(i))
	b.focus_entered.connect(_on_hover.bind(i))
	b.pressed.connect(_row_pressed.bind(i))
	return b


func _row_pressed(i: int) -> void:
	var rooms: Array = _entries[i]["rooms"]
	if rooms.size() == 1:
		_finish(String(rooms[0][0]))
		return
	_show(i)
	if not _loc_buttons.is_empty():
		_loc_buttons[0].grab_focus()


func _on_hover(i: int) -> void:
	if i < 0 or i >= _entries.size():
		return
	if i != _hover_row:
		SfxManager.ui("move")
	_show(i)


func _clear_loc_buttons() -> void:
	for b in _loc_buttons:
		b.queue_free()
	_loc_buttons.clear()


func _show(i: int) -> void:
	var e: Dictionary = _entries[i]
	var n := int(e["deck"])
	_hover_row = i
	_hover_deck = n
	var d: Dictionary = ShipDecks.deck(n)
	var rooms: Array = e["rooms"]
	var here_here := false
	for r in rooms:
		if String(r[0]) == _here_key:
			here_here = true
	_scr_head.text = "DECK %d" % n + ("      YOU ARE HERE" if here_here else "")
	_scr_name.text = String(d["name"]).to_upper()
	_fit_label(_scr_name, maxf(_rundown.size.x - 32.0, 40.0), 19, 10)
	var names: Array = []
	for p in d["parts"]:
		names.append({"saucer": "PRIMARY HULL", "dorsal": "DORSAL", "hull": "SECONDARY HULL"}.get(String(p), String(p)))
	_scr_parts.text = "  /  ".join(names)
	_scr_text.text = String(d["text"])
	_scr_go.text = ""
	for k in range(_buttons.size()):
		var row := _buttons[k]
		var colour := BRONZE_BRIGHT if k == i else BRONZE
		(row.get_node("Num") as Label).add_theme_color_override("font_color", colour)
		(row.get_node("Loc") as Label).add_theme_color_override("font_color", colour)
	if _shown_row != i:
		_shown_row = i
		_clear_loc_buttons()
		for r in rooms:
			_loc_buttons.append(_make_loc_button(String(r[0]), String(r[1])))
		_place_loc_buttons()
	_view.queue_redraw()


func _make_loc_button(key: String, label: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "GO TO:  " + label.to_upper() + ("   (HERE)" if key == _here_key else "")
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color(0.98, 0.85, 0.40))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.6))
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.6))
	if UITheme.font_bold != null:
		b.add_theme_font_override("font", UITheme.font_bold)
	var none := StyleBoxEmpty.new()
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(0.28, 0.17, 0.06)
	b.add_theme_stylebox_override("normal", none)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("focus", lit)
	b.add_theme_stylebox_override("pressed", lit)
	b.pressed.connect(_finish.bind(key))
	add_child(b)
	return b


func _place_loc_buttons() -> void:
	var h := 26.0
	var x := _rundown.position.x + 12.0
	var w := _rundown.size.x - 24.0
	var y := _rundown.end.y - 10.0 - h * float(_loc_buttons.size())
	for b in _loc_buttons:
		b.position = Vector2(x, y)
		b.size = Vector2(w, h - 2.0)
		_fit_button(b, w - 16.0, 13, 9)
		y += h


func _finish(room_key: String) -> void:
	if not _open:
		return
	SfxManager.ui("confirm")
	finished.emit(room_key)


## Moves the highlighted deck up or down the list, scrolling it if need be.
func _nav(delta: int) -> void:
	if _buttons.is_empty():
		return
	var i := clampi((_hover_row if _hover_row >= 0 else 0) + delta, 0, _buttons.size() - 1)
	_scroll_to(i)
	_buttons[i].grab_focus()
	_show(i)


func _scroll_to(i: int) -> void:
	if i < _first:
		_first = i
	elif i >= _first + _vis_rows:
		_first = i - _vis_rows + 1
	_place_rows()


func _scroll_by(delta: int) -> void:
	var maxfirst := maxi(_buttons.size() - _vis_rows, 0)
	_first = clampi(_first + delta, 0, maxfirst)
	_place_rows()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var focus := get_viewport().gui_get_focus_owner()
	var in_loc := focus != null and _loc_buttons.has(focus)
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if in_loc and _hover_row >= 0 and _hover_row < _buttons.size():
			_buttons[_hover_row].grab_focus()   # back from the list of places to the list of decks
			return
		SfxManager.ui("back")
		finished.emit("")
		return
	# REV 297: up/down through PadNav.step - one deck per stick push (the stick used to fire ui_up/ui_down
	# on every movement event and skip several decks). Left/right still swap between the two lists.
	var dir := 0
	if event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		if jm.axis == JOY_AXIS_LEFT_Y or jm.axis == JOY_AXIS_RIGHT_Y:
			dir = PadNav.step(event)
			get_viewport().set_input_as_handled()     # never let Godot's own focus moving see the stick
			if dir == 0:
				return
	elif event.is_action_pressed("ui_up"):
		dir = -1
	elif event.is_action_pressed("ui_down"):
		dir = 1
	if dir != 0:
		if in_loc:
			var j := clampi(_loc_buttons.find(focus) + dir, 0, _loc_buttons.size() - 1)
			_loc_buttons[j].grab_focus()
		else:
			_nav(dir)
		get_viewport().set_input_as_handled()
		return
	if in_loc and event.is_action_pressed("ui_left"):
		_buttons[_hover_row].grab_focus()
		get_viewport().set_input_as_handled()
		return
	if not in_loc and event.is_action_pressed("ui_right") and _hover_row >= 0 and _hover_row < _entries.size():
		if (_entries[_hover_row]["rooms"] as Array).size() > 1 and not _loc_buttons.is_empty():
			_loc_buttons[0].grab_focus()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and _screen.has_point(mb.position):
			_scroll_by(-1)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and _screen.has_point(mb.position):
			_scroll_by(1)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if _up_rect.has_point(mb.position):
				_scroll_by(-1)
				get_viewport().set_input_as_handled()
			elif _dn_rect.has_point(mb.position):
				_scroll_by(1)
				get_viewport().set_input_as_handled()


# =========================================================================
# Layout
# =========================================================================

func _layout() -> void:
	var v := get_viewport_rect().size
	# Ship: the top.
	var ship_h := v.y * 0.44
	_ship_scale = clampf(minf(ship_h / IMG_H, (v.x - 60.0) / IMG_W), 0.2, 1.6)
	var sw := IMG_W * _ship_scale
	_ship_origin = Vector2((v.x - sw) * 0.5, 50.0)
	var ship_bottom := _ship_origin.y + IMG_H * _ship_scale
	# The wall panel: the rest.
	var top := ship_bottom + 22.0
	var bottom := v.y - 30.0
	_console = Rect2(30.0, top, v.x - 60.0, maxf(bottom - top, 160.0))
	_rail = Rect2(_console.position.x, top + 8.0, _console.size.x, 34.0)
	var by := _rail.end.y + 10.0
	var sy1 := _console.end.y - 12.0
	var sh := maxf(sy1 - by, 100.0)
	_grille = Rect2(_console.position.x + 22.0, by + 4.0, 120.0, 62.0)
	var sx0 := _console.position.x + 172.0
	var sw2 := minf(480.0, (_console.size.x - 172.0 - 60.0) * 0.5)
	_screen = Rect2(sx0, by, sw2, sh)
	_rundown = Rect2(_screen.end.x + 16.0, by, _console.end.x - 22.0 - (_screen.end.x + 16.0), sh)

	# Directory text and rows.
	_scr_title.position = Vector2(_screen.position.x + 14.0, by + 17.0)
	_scr_title.size = Vector2(_screen.size.x - 28.0, 22.0)
	_scr_dir.position = Vector2(_screen.position.x, by + 54.0)
	_scr_dir.size = Vector2(_screen.size.x, 20.0)
	_scr_cols.position = Vector2(_screen.position.x + 70.0, by + 76.0)
	_scr_cols2.position = Vector2(_screen.position.x + 140.0, by + 76.0)
	var rows_top := by + 104.0
	var avail := _screen.end.y - rows_top - 8.0
	_row_h = clampf(avail / float(maxi(_buttons.size(), 1)), 22.0, 28.0)
	_vis_rows = maxi(int(floor(avail / _row_h)), 1)
	_rows_top = rows_top
	_first = clampi(_first, 0, maxi(_buttons.size() - _vis_rows, 0))
	_place_rows()
	var ax := _screen.end.x - 46.0
	_up_rect = Rect2(ax, rows_top - 4.0, 30.0, 22.0)
	_dn_rect = Rect2(ax, rows_top + float(_vis_rows) * _row_h - 22.0, 30.0, 22.0)

	# The rundown screen.
	var x := _rundown.position.x + 16.0
	var w := _rundown.size.x - 32.0
	_scr_head.position = Vector2(x, by + 12.0)
	_scr_head.size = Vector2(w, 18.0)
	_scr_head.clip_text = true
	_scr_name.position = Vector2(x, by + 32.0)
	_scr_name.size = Vector2(w, 24.0)
	_scr_parts.position = Vector2(x, by + 60.0)
	_scr_parts.size = Vector2(w, 18.0)
	_scr_parts.clip_text = true
	_scr_text.position = Vector2(x, by + 94.0)
	_scr_text.size = Vector2(w, maxf(sh - 140.0, 20.0))
	_scr_go.position = Vector2(x, _rundown.end.y - 30.0)
	_scr_go.size = Vector2(w, 24.0)
	_place_loc_buttons()
	_view.queue_redraw()


## Shrinks a label's font until its text fits max_w (down to min_size), then clips what still does not fit.
func _fit_label(l: Label, max_w: float, base_size: int, min_size: int) -> void:
	var font: Font = l.get_theme_font("font") if l.has_theme_font_override("font") else UITheme.font_bold
	var size := base_size
	if font != null:
		while size > min_size and font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x > max_w:
			size -= 1
	l.add_theme_font_size_override("font_size", size)
	l.custom_minimum_size = Vector2(0.0, 0.0)
	l.size = Vector2(max_w, l.size.y)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _fit_button(b: Button, max_w: float, base_size: int, min_size: int) -> void:
	var font: Font = UITheme.font_bold
	var size := base_size
	if font != null:
		while size > min_size and font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x > max_w:
			size -= 1
	b.add_theme_font_size_override("font_size", size)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


## Puts the deck rows in place: only those inside the scrolled window show.
func _place_rows() -> void:
	for i in range(_buttons.size()):
		var b := _buttons[i]
		var shown := i >= _first and i < _first + _vis_rows
		b.visible = shown
		b.position = Vector2(_screen.position.x + 16.0, _rows_top + float(i - _first) * _row_h)
		b.size = Vector2(_screen.size.x - 78.0, _row_h - 2.0)
		var num := b.get_node("Num") as Label
		var loc := b.get_node("Loc") as Label
		num.position = Vector2(54.0, (b.size.y - 18.0) * 0.5 - 1.0)
		loc.position = Vector2(124.0, (b.size.y - 18.0) * 0.5 - 1.0)
		# REV 29: the text must stay inside the screen: shrink it, then cut it with "..." as a last resort.
		_fit_label(loc, b.size.x - 124.0 - 6.0, 13, 9)
	_view.queue_redraw()


# =========================================================================
# Drawing
# =========================================================================

func _load_tex(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## A point on the picture (its own units) as a screen position.
func _pt(x: float, y: float) -> Vector2:
	return _ship_origin + Vector2(x - IMG_X0, y - IMG_Y0) * _ship_scale


func _deck_mid_y(n: int) -> float:
	return float(DECK_MID_Y[clampi(n, 0, DECK_MID_Y.size() - 1)])


func _draw_all() -> void:
	_view.draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.01, 0.03, 0.07, 1.0), true)
	_draw_ship()
	_draw_console()


func _draw_ship() -> void:
	var area := Rect2(_ship_origin, Vector2(IMG_W, IMG_H) * _ship_scale)
	if _tex_ship != null:
		_view.draw_texture_rect(_tex_ship, area, false)
	# Where you are, then the deck under the pointer.
	if _here_deck >= 0 and _here_deck < _tex_deck.size() and _tex_deck[_here_deck] != null:
		_view.draw_texture_rect(_tex_deck[_here_deck], area, false, Color(0.3, 1.0, 0.5, 0.40))
	if _hover_deck >= 0 and _hover_deck < _tex_deck.size() and _tex_deck[_hover_deck] != null:
		_view.draw_texture_rect(_tex_deck[_hover_deck], area, false, Color(1.0, 0.85, 0.35, 0.75))
	var font: Font = UITheme.font_bold
	if font == null:
		return
	if _here_deck >= 0:
		var y := _pt(0.0, _deck_mid_y(_here_deck)).y
		var left_edge := _pt(float(DECK_LEFT_X[_here_deck]), 0.0).x
		var right_edge := _pt(float(DECK_RIGHT_X[_here_deck]), 0.0).x
		var text_w := 112.0
		var green := Color(0.4, 1.0, 0.6)
		# the label sits in the open space beside the deck: on its left if there is room, else on its right
		if left_edge - area.position.x > text_w + 14.0:
			var tx := left_edge - text_w - 10.0
			_view.draw_string(font, Vector2(tx, y + 4.0), "YOU ARE HERE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, green)
			_view.draw_line(Vector2(tx + text_w + 2.0, y), Vector2(left_edge, y), Color(green.r, green.g, green.b, 0.85), 1.5)
		else:
			var tx2 := right_edge + 12.0
			_view.draw_line(Vector2(right_edge, y), Vector2(tx2 - 2.0, y), Color(green.r, green.g, green.b, 0.85), 1.5)
			_view.draw_string(font, Vector2(tx2, y + 4.0), "YOU ARE HERE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, green)


func _lamp(centre: Vector2, radius: float, colour: Color, lit: bool) -> void:
	_view.draw_circle(centre, radius + 3.0, Color(0.58, 0.58, 0.56))
	_view.draw_arc(centre, radius + 3.0, 0.0, TAU, 24, Color(0.36, 0.36, 0.35), 1.0)
	if lit:
		_view.draw_circle(centre, radius * 2.0, Color(colour.r, colour.g, colour.b, 0.14))
		_view.draw_circle(centre, radius * 1.5, Color(colour.r, colour.g, colour.b, 0.22))
	var fill := colour if lit else colour.darkened(0.4)
	_view.draw_circle(centre, radius, fill)
	_view.draw_circle(centre + Vector2(-radius * 0.25, -radius * 0.35), radius * 0.38, Color(1, 1, 1, 0.6 if lit else 0.25))


func _draw_console() -> void:
	var c := _console
	# Cream wall with a soft shadow along the bottom.
	_view.draw_rect(c, CREAM, true)
	for i in range(40):
		_view.draw_line(Vector2(c.position.x, c.end.y - float(i)), Vector2(c.end.x, c.end.y - float(i)), Color(0, 0, 0, float(i) * 0.0035), 1.0)
	# Copper rail.
	var r := _rail
	var bands := int(r.size.y)
	for i in range(bands):
		var t := float(i) / float(bands)
		var k := 0.55 + 0.45 * absf(fposmod(t * 3.0, 1.0) - 0.5) * 2.0
		_view.draw_line(Vector2(r.position.x, r.position.y + float(i)), Vector2(r.end.x, r.position.y + float(i)), Color(0.75 * k, 0.46 * k, 0.20 * k), 1.0)
	_view.draw_rect(Rect2(c.position, Vector2(c.size.x, 3.0)), Color(0.47, 0.46, 0.44), true)
	_view.draw_rect(c, Color(0.35, 0.35, 0.34), false, 2.0)
	# Speaker grille and four decoration lamps.
	var g := _grille
	_view.draw_rect(g, Color(0.66, 0.74, 0.84), true)
	_view.draw_rect(g, Color(0.47, 0.55, 0.65), false, 1.0)
	var mesh := Rect2(g.position + Vector2(12.0, 10.0), Vector2(74.0, 42.0))
	_view.draw_rect(mesh, Color(0.80, 0.84, 0.88), true)
	var mx := mesh.position.x
	while mx < mesh.end.x:
		_view.draw_line(Vector2(mx, mesh.position.y), Vector2(mx, mesh.end.y), Color(0.58, 0.64, 0.72, 0.65), 1.0)
		mx += 4.0
	_view.draw_rect(Rect2(g.position + Vector2(94.0, 22.0), Vector2(14.0, 24.0)), Color(0.66, 0.74, 0.84), true)
	_view.draw_rect(Rect2(g.position + Vector2(94.0, 22.0), Vector2(14.0, 24.0)), Color(0.43, 0.51, 0.59), false, 1.0)
	var deco := [Color(0.86, 0.16, 0.16), Color(0.80, 0.80, 0.80), Color(0.16, 0.66, 0.27), Color(0.16, 0.27, 0.78)]
	for i in range(4):
		_lamp(Vector2(g.position.x + 30.0, g.end.y + 36.0 + float(i) * 38.0), 12.0, deco[i], i == 0)
	# Screens.
	for sc in [_screen, _rundown]:
		_view.draw_rect(sc, Color(0.016, 0.016, 0.02), true)
		_view.draw_rect(sc, Color(0.32, 0.32, 0.31), false, 2.0)
	# Directory frame, title box, column rule, lamps.
	var s := _screen
	_view.draw_rect(Rect2(s.position + Vector2(14.0, 10.0), Vector2(s.size.x - 28.0, 34.0)), BRONZE, false, 2.0)
	var rule_y := s.position.y + 100.0
	_view.draw_line(Vector2(s.position.x + 14.0, rule_y), Vector2(s.end.x - 14.0, rule_y), Color(0.92, 0.92, 0.92), 1.0)
	for i in range(_buttons.size()):
		var b := _buttons[i]
		if not b.visible:
			continue
		var centre := Vector2(s.position.x + 38.0, b.position.y + b.size.y * 0.5)
		_lamp(centre, minf(9.0, _row_h * 0.5 - 4.0), LAMP_COLOURS[i % LAMP_COLOURS.size()], i == _hover_row)
	# Scroll arrows, when the list is longer than the screen.
	if _buttons.size() > _vis_rows:
		var can_up := _first > 0
		var can_dn := _first + _vis_rows < _buttons.size()
		var cu := BRONZE_BRIGHT if can_up else Color(0.30, 0.20, 0.10)
		var cd := BRONZE_BRIGHT if can_dn else Color(0.30, 0.20, 0.10)
		var u := _up_rect
		_view.draw_colored_polygon(PackedVector2Array([Vector2(u.position.x + 15.0, u.position.y + 3.0), Vector2(u.end.x - 3.0, u.end.y - 3.0), Vector2(u.position.x + 3.0, u.end.y - 3.0)]), cu)
		var dd := _dn_rect
		_view.draw_colored_polygon(PackedVector2Array([Vector2(dd.position.x + 3.0, dd.position.y + 3.0), Vector2(dd.end.x - 3.0, dd.position.y + 3.0), Vector2(dd.position.x + 15.0, dd.end.y - 3.0)]), cd)
	# Rundown rule.
	_view.draw_line(Vector2(_rundown.position.x + 16.0, _rundown.position.y + 84.0), Vector2(_rundown.end.x - 16.0, _rundown.position.y + 84.0), Color(0.92, 0.92, 0.92), 1.0)
