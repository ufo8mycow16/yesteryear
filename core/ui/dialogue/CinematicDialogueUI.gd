extends CanvasLayer
class_name CinematicDialogueUI
## CinematicDialogueUI (REV 97): the letterboxed conversation mode.
##
## Bars slide in from the top and bottom edges over the live 3D scene; the middle of the
## screen stays clear for the characters and the dialogue camera.
##   TOP BAR    - the line being spoken, "McCOY: Jim, there's something ...". It stays up while the
##                player chooses, so they can always see what they're answering.
##   BOTTOM BAR - the player's choices, only when the player actually has a decision. About four
##                rows show; more scroll inside the same bar (wheel, arrows, controller). REV 139: big
##                gold up/down triangles at the right of the bar (click, or hold to keep going) replace
##                the thin scroll track; each dims when there's nothing more that way. REV 134: each choice keeps its own number as the list scrolls
##                (5, 6, 7 ... further down), and its number key picks it wherever the list is.
##
## Presentation only. It doesn't play audio, move cameras or decide anything: the conversation
## code calls enter(), show_line(), show_choices(), exit() and listens for choice_made. See
## docs/DIALOGUE_CAMERA_DESIGN.md for how it joins up with DialogueManager and the camera.
## REV 293: it is wired in and used - ConversationPresenter makes it (ConversationPresenter.ui) and drives
## every TALK conversation through it (the Prologue topics, the episode rooms). The old note here said it was
## added "unwired" in REV 97; that stopped being true when ConversationPresenter took it over.
## ConversationPresenter.enabled = false still falls back to TopicListUI + the HUD subtitle box.
##
## Input: 1-9 (top-row number keys and keypad) pick that choice; ui_navigate_up/down move;
## ui_navigate_confirm picks; mouse hover/click/wheel. Controller support = bind pad buttons to the
## same actions (ui_navigate_confirm already has pad button 0).

signal entered                     # bars fully in
signal exited                      # bars fully out
signal choice_made(choice_id: String)

## Bar height as a share of the screen height (each bar). 0.14 is close to a 2.39:1 frame on 16:9.
@export_range(0.08, 0.25) var bar_fraction := 0.14
@export var visible_choices := 4
@export var enter_seconds := 0.55
@export var exit_seconds := 0.45
@export var bar_color := Color(0.0, 0.0, 0.0, 1.0)

var active := false                # between enter() and the end of exit()
var choosing := false              # choices are up and waiting

var _top: Control
var _bottom: Control
var _line: RichTextLabel
var _said := ["", ""]      # REV 105: last speaker and line, redrawn when subtitle settings change
var _rows: Array[Button] = []      # the visible_choices row slots (reused)
var _row_labels: Array[Label] = []
var _row_markers: Array[ColorRect] = []
var _arrow_up: _Arrow
var _arrow_down: _Arrow
## REV 144: a solid scrollbar between the (now smaller) arrows showing where in the list you are
## and how much of it is on screen (Glen + Tiffany, 18 Oct brief).
var _track: _Track
var _choices: Array = []           # [{id, text}]
var _first := 0                    # index of the top visible choice
var _sel := 0                      # index of the selected choice (absolute)
var _bars_now := 0.0              # 0 = bars off screen, 1 = fully in
var _bar_tween: Tween
var _choice_tween: Tween


func _ready() -> void:
	layer = 35    # REV 318: above the HUD subtitle layer (34) and a room's black fade (30); below the loading card (40), DevMenu/PhotoMode/BuildInfo
	add_to_group(PadNav.MENU_GROUP)
	_top = _make_bar(true)
	_bottom = _make_bar(false)

	_line = RichTextLabel.new()
	_line.bbcode_enabled = true
	_line.fit_content = false
	_line.scroll_active = false
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if UITheme.font_body != null:
		_line.add_theme_font_override("normal_font", UITheme.font_body)   # the line: Barlow; the name: Microgramma bold
	if UITheme.font_bold != null:
		_line.add_theme_font_override("bold_font", UITheme.font_bold)
	_line.add_theme_color_override("default_color", UITheme.TEXT_PRIMARY)
	_top.add_child(_line)

	for i in visible_choices:
		_add_row(i)
	_arrow_up = _Arrow.new()
	_arrow_up.name = "ArrowUp"
	_arrow_up.up = true
	_arrow_up.stepped.connect(func(): _scroll(-1))
	_bottom.add_child(_arrow_up)
	_arrow_down = _Arrow.new()
	_arrow_down.name = "ArrowDown"
	_arrow_down.stepped.connect(func(): _scroll(1))
	_bottom.add_child(_arrow_down)
	_track = _Track.new()
	_track.name = "ScrollTrack"
	_track.jump_to.connect(func(first: int): _scroll(first - _first))
	_bottom.add_child(_track)

	_bottom.gui_input.connect(_on_bar_input)
	get_viewport().size_changed.connect(_layout)
	GameSettings.accessibility_changed.connect(_on_accessibility_changed)
	_layout()
	_set_bars(0.0)
	_set_choices_alpha(0.0)
	_top.visible = false
	_bottom.visible = false


# ---- what the conversation code calls ------------------------------------------------

## Slide the bars in (call when a conversation starts).
func enter() -> void:
	if active:
		return
	active = true
	_top.visible = true
	_bottom.visible = true
	_tween_bars(1.0, enter_seconds, Tween.EASE_OUT)
	_bar_tween.tween_callback(func(): entered.emit())


## Slide the bars out (call when the conversation ends). Clears the line and choices.
func exit() -> void:
	if not active:
		return
	hide_choices()
	_tween_bars(0.0, exit_seconds, Tween.EASE_IN)
	_bar_tween.tween_callback(func():
		active = false
		_top.visible = false
		_bottom.visible = false
		_line.text = ""
		exited.emit()
	)


## The line being spoken. It stays until the next show_line(), including while choosing.
## `recalled`: an earlier line shown again (the question the choices answer) - a little dimmer.
func show_line(speaker: String, text: String, recalled: bool = false) -> void:
	_said = [speaker, text]
	_render_line()
	_line.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_line, "modulate:a", 0.72 if recalled else 1.0, UITheme.dur(UITheme.ANIM_SMALL * 1.5))   # REV 297


## REV 365: how tall each letterbox bar is on screen (pixels; 0 when the bars are away).
func bar_px() -> float:
	return _top.size.y if active and _top != null else 0.0


func clear_line() -> void:
	_said = ["", ""]
	_line.text = ""


## The line with the speaker's name first - in their own colour, or gold - unless names are off
## (Settings > Accessibility).
func _render_line() -> void:
	var speaker := String(_said[0])
	var who := format_speaker(speaker) if GameSettings.speaker_names else ""
	var body := _escape(String(_said[1]))
	var colour := GameSettings.speaker_colour(speaker, UITheme.GOLD).to_html(false)
	_line.text = ("[b][color=#%s]%s:[/color][/b]  %s" % [colour, _escape(who), body]) if who != "" else body


func _on_accessibility_changed() -> void:
	_layout()
	if String(_said[1]) != "":
		_render_line()


## Offer the player's choices: [{"id": "...", "text": "What did you find, Bones?"}, ...].
func show_choices(choices: Array) -> void:
	_choices = choices.duplicate()
	_first = 0
	_sel = 0
	choosing = not _choices.is_empty()
	_refresh_rows()
	_kill(_choice_tween)
	_choice_tween = create_tween()
	_choice_tween.tween_method(_set_choices_alpha, _rows[0].modulate.a, 1.0 if choosing else 0.0, UITheme.dur(UITheme.ANIM_MODAL))   # REV 297


## Take the choices away (after one is picked, or for NPC-to-NPC talk). The bar itself stays.
func hide_choices() -> void:
	choosing = false
	_kill(_choice_tween)
	_choice_tween = create_tween()
	_choice_tween.tween_method(_set_choices_alpha, _rows[0].modulate.a, 0.0, UITheme.dur(UITheme.ANIM_SMALL))   # REV 297


## "McCoy" -> "McCOY", "Dr McCoy" -> "DR McCOY", "Captain Kirk" -> "CAPTAIN KIRK".
## REV 144: done per word, now that names carry a rank in front (GameNames).
static func format_speaker(speaker: String) -> String:
	var words := speaker.strip_edges().split(" ", false)
	for i in words.size():
		var up := words[i].to_upper()
		if up.begins_with("MC") and up.length() > 2:
			up = "Mc" + up.substr(2)
		elif up.begins_with("MAC") and up.length() > 3:
			up = "Mac" + up.substr(3)
		words[i] = up
	return " ".join(words)


# ---- input ------------------------------------------------------------------------------

## REV 214: while choosing, McCoy and the camera ignore the sticks (PadNav.any_open).
func pad_menu_active() -> bool:
	return choosing


func _unhandled_input(event: InputEvent) -> void:
	if not choosing:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		var n := _number_of(key)
		if n >= 1 and n <= _choices.size():
			_pick(n - 1)
			get_viewport().set_input_as_handled()
			return
	var nav := PadNav.step(event)     # REV 214: d-pad, either stick, arrows
	if nav != 0:
		_move(nav)
	elif event is InputEventJoypadMotion:
		return
	elif PadNav.confirm(event):
		_pick(_sel)
	else:
		var wheel := event as InputEventMouseButton
		if wheel != null and wheel.pressed and wheel.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_scroll(1 if wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		else:
			return
	get_viewport().set_input_as_handled()


## The mouse wheel over the bottom bar (the bar takes mouse events so clicks there don't reach the game).
func _on_bar_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if choosing and wheel != null and wheel.pressed and wheel.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_scroll(1 if wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		get_viewport().set_input_as_handled()


static func _number_of(key: InputEventKey) -> int:
	var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if code >= KEY_1 and code <= KEY_9:
		return int(code - KEY_1) + 1
	if code >= KEY_KP_1 and code <= KEY_KP_9:
		return int(code - KEY_KP_1) + 1
	return -1


func _pick(index: int) -> void:
	if not choosing or index < 0 or index >= _choices.size():
		return
	var id := String(_choices[index].get("id", str(index)))
	SfxManager.ui("confirm", -4.0)     # REV 168: quiet - a conversation is not a menu
	hide_choices()
	choice_made.emit(id)


func _move(step: int) -> void:
	var was := _sel
	_sel = clampi(_sel + step, 0, _choices.size() - 1)
	if _sel != was:
		SfxManager.ui("move", -4.0)
	if _sel < _first:
		_first = _sel
	elif _sel >= _first + visible_choices:
		_first = _sel - visible_choices + 1
	_refresh_rows()


func _scroll(step: int) -> void:
	var max_first := maxi(0, _choices.size() - visible_choices)
	_first = clampi(_first + step, 0, max_first)
	_sel = clampi(_sel, _first, _first + visible_choices - 1)
	_refresh_rows()


# ---- drawing ------------------------------------------------------------------------------

func _make_bar(is_top: bool) -> Control:
	var bar := ColorRect.new()
	bar.name = "TopBar" if is_top else "BottomBar"
	bar.color = bar_color
	bar.mouse_filter = Control.MOUSE_FILTER_STOP if not is_top else Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	# a hairline of dim gold on the inner edge: the only "frame" the bars get
	var edge := ColorRect.new()
	edge.color = Color(UITheme.GOLD_DIM.r, UITheme.GOLD_DIM.g, UITheme.GOLD_DIM.b, 0.45)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.name = "Edge"
	bar.add_child(edge)
	return bar


func _add_row(i: int) -> void:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE     # REV 214: a focused row swallowed d-pad presses (Nikki)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.0)
	sb.set_corner_radius_all(UITheme.BUTTON_CORNER_RADIUS)
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, sb)
	var marker := ColorRect.new()
	marker.color = UITheme.GOLD
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.anchor_bottom = 1.0
	marker.offset_left = 0.0
	marker.offset_right = 2.0
	marker.offset_top = 4.0
	marker.offset_bottom = -4.0
	btn.add_child(marker)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 14.0
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if UITheme.font_body != null:
		label.add_theme_font_override("font", UITheme.font_body)
	btn.add_child(label)
	btn.mouse_entered.connect(func():
		if choosing and _first + i < _choices.size() and _sel != _first + i:
			_sel = _first + i
			_refresh_rows()
	)
	btn.pressed.connect(func(): _pick(_first + i))
	_bottom.add_child(btn)
	_rows.append(btn)
	_row_labels.append(label)
	_row_markers.append(marker)


## Sizes everything from the screen height, so it looks the same at any resolution.
func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	# REV 297: the bars grow a little with SUBTITLE TEXT SIZE (up to 35% taller at HUGE), so the bigger
	# line and choice text have room instead of being capped at the EXTRA LARGE size.
	var grow := clampf(1.0 + (GameSettings.subtitle_scale() - 1.0) * 0.35, 1.0, 1.35)
	var h := roundf(vp.y * bar_fraction * grow)
	var margin_x := maxf(UITheme.SCREEN_MARGIN, vp.x * 0.12)   # keep text off the far edges
	for bar in [_top, _bottom]:
		bar.size = Vector2(vp.x, h)
		var edge := bar.get_node("Edge") as ColorRect
		edge.size = Vector2(vp.x * 0.6, 1.0)
		edge.position = Vector2(vp.x * 0.2, h - 1.0 if bar == _top else 0.0)
	var font_px := clampi(int(h / grow * 0.15), 13, 26)   # base size from the unscaled bar
	# REV 105: the spoken line follows SUBTITLE TEXT SIZE (the bar is tall enough for three lines at HUGE)
	# REV 297: cap raised from 27% to 25% of the (now taller) bar - HUGE is bigger than EXTRA LARGE again,
	# and two lines still fit in the line's area (80% of the bar).
	var line_px := clampi(int(round((font_px + 1) * GameSettings.subtitle_scale())), 13, int(h * 0.25))
	_line.add_theme_font_size_override("normal_font_size", line_px)
	_line.add_theme_font_size_override("bold_font_size", line_px)
	_line.position = Vector2(margin_x, h * 0.12)
	_line.size = Vector2(vp.x - margin_x * 2.0, h * 0.8)
	var pad := h * 0.08
	var row_h := (h - pad * 2.0) / float(visible_choices)
	# REV 144: small arrows at the top and bottom of the choices' right edge, with the scrollbar
	# track filling the space between them (was: two big triangles, each half the bar's height)
	var column_h := h - pad * 2.0
	var arrow := floorf(clampf(column_h * 0.2, 12.0, 26.0))
	# REV 297: the choice rows follow SUBTITLE TEXT SIZE too, as far as a row's height allows.
	var choice_px := clampi(int(round(font_px * GameSettings.subtitle_scale())), font_px, maxi(font_px, int(row_h * 0.72)))
	for i in _rows.size():
		_rows[i].position = Vector2(margin_x, pad + row_h * i)
		_rows[i].size = Vector2(vp.x - margin_x * 2.0 - arrow - 12.0, row_h)
		_row_labels[i].add_theme_font_size_override("font_size", choice_px)
	var x := vp.x - margin_x - arrow
	_arrow_up.position = Vector2(x, pad)
	_arrow_up.size = Vector2(arrow, arrow)
	_arrow_down.position = Vector2(x, pad + column_h - arrow)
	_arrow_down.size = Vector2(arrow, arrow)
	var gap := 4.0
	_track.position = Vector2(x, pad + arrow + gap)
	_track.size = Vector2(arrow, maxf(column_h - (arrow + gap) * 2.0, 8.0))
	_set_bars(_bars_now)
	_refresh_rows()


## 0 = bars fully off screen, 1 = fully in.
func _set_bars(amount: float) -> void:
	_bars_now = amount
	var h := _top.size.y
	_top.position.y = -h * (1.0 - amount)
	_bottom.position.y = get_viewport().get_visible_rect().size.y - h * amount


func _tween_bars(to: float, seconds: float, ease_dir: int) -> void:
	if GameSettings.reduced_motion:     # REV 296: the letterbox bars snap in/out under Reduced Motion
		seconds = 0.0
	_kill(_bar_tween)
	_bar_tween = create_tween()
	_bar_tween.set_trans(Tween.TRANS_SINE).set_ease(ease_dir)
	_bar_tween.tween_method(_set_bars, _bars_now, to, seconds)


func _set_choices_alpha(a: float) -> void:
	for r in _rows:
		r.modulate.a = a
		# PASS, not STOP: the wheel isn't used by a button, so it reaches the bar (_on_bar_input)
		r.mouse_filter = Control.MOUSE_FILTER_PASS if a > 0.5 else Control.MOUSE_FILTER_IGNORE
	for ar in [_arrow_up, _arrow_down, _track]:
		ar.modulate.a = a
		ar.mouse_filter = Control.MOUSE_FILTER_STOP if a > 0.5 else Control.MOUSE_FILTER_IGNORE


func _refresh_rows() -> void:
	if _rows.is_empty():
		return
	for i in _rows.size():
		var idx := _first + i
		var has := idx < _choices.size()
		_rows[i].visible = has
		if not has:
			continue
		var selected := idx == _sel
		_row_labels[i].text = "%d.   %s" % [idx + 1, String(_choices[idx].get("text", ""))]
		var used := bool(_choices[idx].get("used", false))   # REV 108: already asked - greyed
		var col: Color = UITheme.GOLD_BRIGHT if selected else (UITheme.TEXT_DIM if used else UITheme.TEXT_PRIMARY)
		_row_labels[i].add_theme_color_override("font_color", col)
		_row_markers[i].modulate.a = 1.0 if selected else 0.0
		var sb := _rows[i].get_theme_stylebox("normal") as StyleBoxFlat
		sb.bg_color.a = 0.10 if selected else 0.0
	# the arrows only when there's more than fits; each lit only if there's more that way
	var extra := _choices.size() > visible_choices
	_arrow_up.visible = extra
	_arrow_down.visible = extra
	_track.visible = extra
	if extra:
		_arrow_up.set_live(_first > 0)
		_arrow_down.set_live(_first + visible_choices < _choices.size())
		_track.set_range(_first, visible_choices, _choices.size())


static func _escape(s: String) -> String:
	return s.replace("[", "[lb]")


static func _kill(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()


## REV 139: a big triangle that scrolls the choices one row per click, and keeps going while held.
class _Arrow extends Control:
	signal stepped
	var up := false
	var live := true
	var _hot := false
	var _held := 0.0
	var _next := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_on_enter)
		mouse_exited.connect(_on_exit)
		set_process(false)

	func _on_enter() -> void:
		_hot = true
		queue_redraw()

	func _on_exit() -> void:
		_hot = false
		_held = 0.0
		queue_redraw()

	func set_live(v: bool) -> void:
		if v != live:
			live = v
			if not live:
				_held = 0.0
				set_process(false)
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if mb.pressed and live:
			stepped.emit()
			_held = 0.001
			_next = 0.4          # wait a moment before repeating
			set_process(true)
		elif not mb.pressed:
			_held = 0.0
			set_process(false)

	func _process(delta: float) -> void:
		if _held <= 0.0 or not live:
			set_process(false)
			return
		_held += delta
		if _held >= _next:
			_next += 0.12
			stepped.emit()

	func _draw() -> void:
		var w := size.x
		var hgt := size.y
		var inset := minf(w, hgt) * 0.1
		var pts: PackedVector2Array
		if up:
			pts = PackedVector2Array([Vector2(w * 0.5, inset), Vector2(w - inset, hgt - inset), Vector2(inset, hgt - inset)])
		else:
			pts = PackedVector2Array([Vector2(inset, inset), Vector2(w - inset, inset), Vector2(w * 0.5, hgt - inset)])
		var col: Color
		if not live:
			col = Color(UITheme.GOLD_DIM.r, UITheme.GOLD_DIM.g, UITheme.GOLD_DIM.b, 0.3)
		elif _hot:
			col = UITheme.GOLD_BRIGHT
		else:
			col = UITheme.GOLD
		draw_colored_polygon(pts, col)


## REV 144: the scrollbar between the arrows. A solid dim-gold track with a brighter thumb: the
## thumb's length is how much of the list is showing, its position is where you are in it. Click
## the track to jump there, or drag the thumb. Keys, wheel and controller scroll as before.
class _Track extends Control:
	signal jump_to(first: int)
	var first := 0
	var shown := 1
	var total := 1
	var _dragging := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func set_range(f: int, s: int, t: int) -> void:
		first = f
		shown = maxi(s, 1)
		total = maxi(t, 1)
		queue_redraw()

	func _thumb() -> Rect2:
		var w := size.x
		var bar_w := maxf(roundf(w * 0.32), 3.0)
		var bx := roundf((w - bar_w) * 0.5)
		var frac := clampf(float(shown) / float(total), 0.1, 1.0)
		var th := maxf(size.y * frac, 6.0)
		var max_first := maxi(total - shown, 1)
		var ty := (size.y - th) * clampf(float(first) / float(max_first), 0.0, 1.0)
		return Rect2(bx, ty, bar_w, th)

	func _first_at(y: float) -> int:
		var th := _thumb().size.y
		var u := clampf((y - th * 0.5) / maxf(size.y - th, 1.0), 0.0, 1.0)
		return roundi(u * float(maxi(total - shown, 0)))

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			_dragging = mb.pressed
			if mb.pressed:
				jump_to.emit(_first_at(mb.position.y))
			return
		var mm := event as InputEventMouseMotion
		if mm != null and _dragging:
			accept_event()
			jump_to.emit(_first_at(mm.position.y))

	func _draw() -> void:
		var t := _thumb()
		# the track: a solid, clearly visible channel the thumb runs in
		draw_rect(Rect2(t.position.x, 0.0, t.size.x, size.y), Color(UITheme.GOLD_DIM, 0.55))
		draw_rect(Rect2(t.position.x, 0.0, t.size.x, size.y), Color(UITheme.GOLD, 0.35), false, 1.0)
		# the thumb
		draw_rect(t, UITheme.GOLD_BRIGHT)

