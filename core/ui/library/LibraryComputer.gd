class_name LibraryComputer
extends Control
## REV 746 (Glen's bug list item 13): the LIBRARY COMPUTER at Spock's station, like Star Trek 25th Anniversary and
## Judgment Rites - browse by subject or type to search; choosing an entry shows it on a TOS screen and the computer
## (Majel, through the ShipComputer bus - the Episode 3 computer filter) reads the whole entry.
##
## Everything it shows comes from ONE file Glen can edit: data/computer/library.csv - columns file, category, title,
## entry, unlock (see tools/make_library_csv.py). Add a line and it's in the game.
##   unlock: blank = always; "ep:N" = from Episode N on; any other word = a story flag (GameState) that must be set.
## Voices: assets/audio/computer/library/<file>.mp3 (.ogg/.wav) - low-quality mono mp3s are fine.
##
##   var lib := LibraryComputer.open(ui_canvas, 3)      # the episode being played
##   await lib.closed
##
## Pad: up/down move, right / A goes into a subject, A reads an entry, left / B goes back, B on the subjects closes.
## Keyboard: arrows, Enter, Esc; just start typing to search.

signal closed()

const CSV_PATH := "res://data/computer/library.csv"
const VOICE_DIR := "res://assets/audio/computer/library/"
const AMBER := Color(1.0, 0.72, 0.22)
const CYAN := Color(0.45, 0.85, 0.95)
const RED := Color(0.86, 0.22, 0.16)
const SCREEN := Color(0.01, 0.015, 0.02, 0.97)

var episode := 1
var _entries: Array = []             # Dictionaries: file, category, title, entry
var _categories: Array[String] = []
var _shown: Array = []               # the entries in the middle list right now
var _cats: ItemList
var _list: ItemList
var _text: RichTextLabel
var _heading: Label
var _search: LineEdit
var _count: Label
var _voice: AudioStreamPlayer
var _reveal: Tween
var _open := false


static func open(parent: Node, ep: int) -> LibraryComputer:
	var l := LibraryComputer.new()
	l.episode = ep
	parent.add_child(l)
	return l


static func load_entries(ep: int) -> Array:
	var out: Array = []
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		return out
	var head := f.get_csv_line()
	var col := {}
	for i in head.size():
		col[String(head[i]).strip_edges().to_lower()] = i
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 2:
			continue
		var e := {}
		for k in ["file", "category", "title", "entry", "unlock"]:
			e[k] = String(row[int(col[k])]).strip_edges() if col.has(k) and int(col[k]) < row.size() else ""
		if String(e["title"]) == "" or not _unlocked(String(e["unlock"]), ep):
			continue
		out.append(e)
	return out


static func _unlocked(u: String, ep: int) -> bool:
	if u == "":
		return true
	if u.begins_with("ep:"):
		return ep >= int(u.substr(3))
	return GameState.has_var(u) and bool(GameState.get_var(u))


func _ready() -> void:
	add_to_group(PadNav.MENU_GROUP)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_entries = load_entries(episode)
	for e in _entries:
		if not _categories.has(String(e["category"])):
			_categories.append(String(e["category"]))
	_build()
	_voice = AudioStreamPlayer.new()
	_voice.bus = "ShipComputer" if AudioServer.get_bus_index("ShipComputer") >= 0 else ("Dialogue" if AudioServer.get_bus_index("Dialogue") >= 0 else "Master")
	add_child(_voice)
	_open = true
	UITheme.fade_in(self)
	SfxManager.ui("open")
	_fill_categories()
	if _cats.item_count > 0:
		_cats.select(0)
		_on_category(0)
	_cats.grab_focus()
	_show_text("LIBRARY COMPUTER", "Working. Select a subject, then an entry - or begin typing to search. %d entries on file." % _entries.size())


func pad_menu_active() -> bool:
	return _open


func _label(text: String, size: int, colour: Color, bold := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	var f: Font = UITheme.font_bold if bold else UITheme.font_body
	if f != null:
		l.add_theme_font_override("font", f)
	return l


func _list_style(l: ItemList, accent: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.border_color = accent * Color(1, 1, 1, 0.6)
	bg.set_border_width_all(2)
	bg.set_content_margin_all(6)
	l.add_theme_stylebox_override("panel", bg)
	l.add_theme_stylebox_override("focus", bg)
	var sel := StyleBoxFlat.new()
	sel.bg_color = accent * Color(1, 1, 1, 0.35)
	l.add_theme_stylebox_override("selected", sel)
	l.add_theme_stylebox_override("selected_focus", sel)
	l.add_theme_stylebox_override("cursor", StyleBoxEmpty.new())
	l.add_theme_stylebox_override("cursor_unfocused", StyleBoxEmpty.new())
	l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82))
	l.add_theme_color_override("font_selected_color", Color(1, 1, 1))
	l.add_theme_font_size_override("font_size", 14)
	if UITheme.font_bold != null:
		l.add_theme_font_override("font", UITheme.font_bold)
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 40
	frame.offset_top = 32
	frame.offset_right = -40
	frame.offset_bottom = -32
	var sb := StyleBoxFlat.new()
	sb.bg_color = SCREEN
	sb.border_color = AMBER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	frame.add_theme_stylebox_override("panel", sb)
	add_child(frame)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	frame.add_child(col)

	# the header bar: TOS blocks of colour, the title, the search line
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	for c in [RED, AMBER, CYAN]:
		var b := ColorRect.new()
		b.color = c
		b.custom_minimum_size = Vector2(26, 26)
		top.add_child(b)
	var title := _label("LIBRARY COMPUTER  -  U.S.S. ENTERPRISE", 22, AMBER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(_label("SEARCH:", 16, CYAN))
	_search = LineEdit.new()
	_search.custom_minimum_size = Vector2(260, 0)
	_search.placeholder_text = "type to search"
	_search.add_theme_color_override("font_color", CYAN)
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0, 0, 0, 0.7)
	ss.border_color = CYAN * Color(1, 1, 1, 0.6)
	ss.set_border_width_all(2)
	ss.set_content_margin_all(4)
	_search.add_theme_stylebox_override("normal", ss)
	_search.add_theme_stylebox_override("focus", ss)
	_search.text_changed.connect(_on_search)
	top.add_child(_search)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.9
	row.add_child(left)
	left.add_child(_label("SUBJECTS", 14, RED))
	_cats = ItemList.new()
	_list_style(_cats, AMBER)
	_cats.item_selected.connect(_on_category)
	_cats.item_activated.connect(func(_i: int) -> void: _into_entries())
	left.add_child(_cats)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	_count = _label("ENTRIES", 14, RED)
	mid.add_child(_count)
	_list = ItemList.new()
	_list_style(_list, CYAN)
	_list.item_selected.connect(_on_entry)
	_list.item_activated.connect(_read)
	mid.add_child(_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.4
	row.add_child(right)
	_heading = _label("", 18, CYAN)
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_heading)
	var tf := PanelContainer.new()
	tf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.0, 0.03, 0.04, 0.9)
	tsb.border_color = CYAN * Color(1, 1, 1, 0.5)
	tsb.set_border_width_all(2)
	tsb.set_content_margin_all(12)
	tf.add_theme_stylebox_override("panel", tsb)
	right.add_child(tf)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.scroll_active = true
	_text.focus_mode = Control.FOCUS_NONE
	_text.add_theme_color_override("default_color", Color(0.86, 0.95, 0.9))
	_text.add_theme_font_size_override("normal_font_size", 17)
	if UITheme.font_body != null:
		_text.add_theme_font_override("normal_font", UITheme.font_body)
	tf.add_child(_text)

	var foot := _label(InputHints.fill("{ui_accept}  READ|{menu_cancel}  BACK / CLOSE|TYPE TO SEARCH"), 13, Color(0.6, 0.6, 0.58), false)
	col.add_child(foot)


func _fill_categories() -> void:
	_cats.clear()
	for c in _categories:
		_cats.add_item(c)


func _on_category(i: int) -> void:
	if i < 0 or i >= _categories.size():
		return
	SfxManager.ui("move")
	var c := _categories[i]
	_fill_entries(_entries.filter(func(e: Dictionary) -> bool: return String(e["category"]) == c), c)


func _fill_entries(list: Array, heading: String) -> void:
	_shown = list
	_list.clear()
	for e in _shown:
		_list.add_item(String(e["title"]))
	_count.text = "%s  (%d)" % [heading, _shown.size()]


func _into_entries() -> void:
	if _list.item_count == 0:
		return
	_list.grab_focus()
	if _list.get_selected_items().is_empty():
		_list.select(0)
		_on_entry(0)


func _on_entry(i: int) -> void:
	if i < 0 or i >= _shown.size():
		return
	SfxManager.ui("move")
	_stop_voice()
	var e: Dictionary = _shown[i]
	_show_text(String(e["title"]), String(e["entry"]), false)


func _read(i: int) -> void:
	if i < 0 or i >= _shown.size():
		return
	SfxManager.ui("confirm")
	var e: Dictionary = _shown[i]
	_show_text(String(e["title"]), String(e["entry"]), true)
	_play(String(e["file"]))


func _show_text(head: String, body: String, reveal := false) -> void:
	_heading.text = head
	_text.text = body
	_text.scroll_to_line(0)
	if _reveal != null:
		_reveal.kill()
	if reveal and not GameSettings.get("reduced_motion"):
		_text.visible_ratio = 0.0
		_reveal = create_tween()
		_reveal.tween_property(_text, "visible_ratio", 1.0, clampf(body.length() / 70.0, 0.6, 6.0))
	else:
		_text.visible_ratio = 1.0


func _play(file: String) -> void:
	_stop_voice()
	if file == "":
		return
	for ext in [".mp3", ".ogg", ".wav"]:
		var p: String = VOICE_DIR + file + String(ext)
		if ResourceLoader.exists(p):
			_voice.stream = load(p)
			_voice.play()
			return


func _stop_voice() -> void:
	if _voice != null and _voice.playing:
		_voice.stop()


func _on_search(t: String) -> void:
	var q := t.strip_edges().to_lower()
	if q == "":
		var i := _cats.get_selected_items()
		_on_category(i[0] if not i.is_empty() else 0)
		return
	_cats.deselect_all()
	_fill_entries(_entries.filter(func(e: Dictionary) -> bool:
		return String(e["title"]).to_lower().contains(q) or String(e["entry"]).to_lower().contains(q)), "FOUND")


func _input(event: InputEvent) -> void:
	if not _open or not is_visible_in_tree():
		return
	# typing anywhere starts a search
	if event is InputEventKey and event.pressed and not event.echo and not _search.has_focus():
		var k := event as InputEventKey
		if k.unicode >= 32 and k.unicode != 127 and not k.ctrl_pressed and not k.alt_pressed:
			_search.grab_focus()
			_search.text += char(k.unicode)
			_search.caret_column = _search.text.length()
			_on_search(_search.text)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		get_viewport().set_input_as_handled()
		if _search.has_focus():
			if _search.text != "":
				_search.text = ""
				_on_search("")
			_cats.grab_focus()
		elif _list.has_focus():
			_stop_voice()
			_cats.grab_focus()
			SfxManager.ui("back")
		else:
			close()
		return
	if event.is_action_pressed("ui_right") and _cats.has_focus():
		_into_entries()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") and _list.has_focus():
		_cats.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") and _search.has_focus() and _list.item_count > 0:
		_into_entries()
		get_viewport().set_input_as_handled()


func close() -> void:
	if not _open:
		return
	_open = false
	_stop_voice()
	SfxManager.ui("close")
	closed.emit()
	queue_free()
