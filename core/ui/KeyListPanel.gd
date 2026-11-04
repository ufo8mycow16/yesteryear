extends PanelContainer
## REV 165: a small on-screen list of keys, used by the in-game shortcut list (BuildInfo, F3) and the
## debug map viewer. Give it rows with set_rows():
##     ["# HEADING"]                 a gold section heading
##     ["W A S D", "Move"]           a key (left, gold) and what it does (right)
## A row whose key is "" is left out (an action with no key on the current device).

const KEY_WIDTH := 112.0

var font_size := 11
## 0 = one column. Otherwise a new column starts at a heading once a column has this many rows.
var max_rows_per_column := 0
var _cols: HBoxContainer
var _box: VBoxContainer
var _last: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.03, 0.72)
	sb.border_color = Color(UITheme.GOLD_DIM, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	sb.content_margin_top = 7
	sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", sb)
	_cols = HBoxContainer.new()
	_cols.add_theme_constant_override("separation", 22)
	_cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cols)


func _new_column() -> void:
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 0)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cols.add_child(_box)


func set_rows(rows: Array) -> void:
	if rows == _last:
		return
	_last = rows.duplicate(true)
	for c in _cols.get_children():
		_cols.remove_child(c)
		c.queue_free()
	_new_column()
	var first := true
	var count := 0
	for r in rows:
		var row: Array = r
		var text := String(row[0])
		if row.size() == 1 and text.begins_with("#"):
			if max_rows_per_column > 0 and count >= max_rows_per_column:
				_new_column()
				first = true
				count = 0
			var head := _label(text.substr(1).strip_edges(), UITheme.GOLD, true)
			if not first:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(0, 5)
				gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_box.add_child(gap)
			_box.add_child(head)
			first = false
			count += 1
			continue
		if row.size() < 2 or text == "":
			continue
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 8)
		var k := _label(text, UITheme.GOLD_BRIGHT, false)
		k.custom_minimum_size = Vector2(KEY_WIDTH, 0)
		line.add_child(k)
		line.add_child(_label(String(row[1]), UITheme.TEXT_PRIMARY, false))
		_box.add_child(line)
		first = false
		count += 1
	reset_size()


func _label(text: String, color: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	var f: Font = UITheme.font_bold if bold else UITheme.font_body
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", font_size + (0 if bold else UITheme.body_size_bonus))
	return l
