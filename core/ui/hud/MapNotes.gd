class_name MapNotes
extends RefCounted
## REV 804 - map labels and the player's own map notes (Glen, 3 Nov: "include those labels on the mini map and allow
## you to choose a part of the mini map and add your own notes").
##
## LABELS: a room can hand the maps a list of names (get_minimap_data / get_full_map_data "labels": an Array of
## [Vector2 world x,z, String text, int size]). Both the HUD minimap and the M map draw them as crisp text at a fixed
## screen size, so they read at any zoom.
## NOTES: right-click a spot on the M map to write a note there (right-click a note to change or delete it). Notes are
## kept per map ("map_id" in the data, else the map's title) in user://map_notes.json and shown on both maps.

const FILE := "user://map_notes.json"
const PIN := Color(0.98, 0.62, 0.22)          # orange: stands apart from the gold player arrow and turbolifts
const LABEL_COLOUR := Color(1.0, 0.965, 0.84)
const NOTE_TEXT := Color(1.0, 0.86, 0.62)
const SHADOW := Color(0.0, 0.0, 0.0, 0.8)

static var _all: Dictionary = {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(FILE):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if d is Dictionary:
			_all = d


static func _save() -> void:
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_all, "\t"))


## The map's id from its data (rooms may give "map_id"; otherwise the title it shows).
static func map_id(data: Dictionary) -> String:
	if data.has("map_id"):
		return String(data["map_id"])
	return "deck%d:%s" % [int(data.get("deck", -1)), String(data.get("room_name", ""))]


## [{pos: Vector2, text: String}, ...]
static func notes(id: String) -> Array:
	_load()
	var out: Array = []
	for n in _all.get(id, []):
		out.append({"pos": Vector2(float(n["x"]), float(n["z"])), "text": String(n["text"])})
	return out


static func add(id: String, pos: Vector2, text: String) -> void:
	_load()
	var list: Array = _all.get(id, [])
	list.append({"x": snappedf(pos.x, 0.01), "z": snappedf(pos.y, 0.01), "text": text})
	_all[id] = list
	_save()


## Changes note i's words; empty words delete it.
static func set_text(id: String, i: int, text: String) -> void:
	_load()
	var list: Array = _all.get(id, [])
	if i < 0 or i >= list.size():
		return
	if text.strip_edges().is_empty():
		list.remove_at(i)
	else:
		list[i]["text"] = text
	_all[id] = list
	_save()


## The note nearest a world point within `reach` metres (-1 if none).
static func nearest(id: String, world: Vector2, reach: float) -> int:
	var best := -1
	var best_d := reach
	var list := notes(id)
	for i in list.size():
		var d: float = (list[i]["pos"] as Vector2).distance_to(world)
		if d <= best_d:
			best_d = d
			best = i
	return best


static func font() -> Font:
	var ui: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("UITheme") if Engine.get_main_loop() is SceneTree else null
	if ui != null and ui.get("font_body_strong") != null:
		return ui.get("font_body_strong")
	return ThemeDB.fallback_font


## Text centred on a point, with a dark outline so it reads over any floor.
static func draw_text(ci: CanvasItem, at: Vector2, text: String, size: int, col: Color) -> void:
	var f := font()
	var lines := text.split("\n")
	var lh := f.get_height(size)
	var top := at.y - lh * lines.size() * 0.5 + f.get_ascent(size)
	for i in lines.size():
		var w := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var p := Vector2(at.x - w * 0.5, top + lh * i)
		ci.draw_string_outline(f, p, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, SHADOW)
		ci.draw_string(f, p, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## A note pin (a little flag) with its words beside it.
static func draw_note(ci: CanvasItem, at: Vector2, text: String, size: int, show_text := true) -> void:
	ci.draw_line(at, at + Vector2(0, -14), SHADOW, 3.0)
	ci.draw_line(at, at + Vector2(0, -14), PIN, 1.6)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -14), at + Vector2(10, -10.5), at + Vector2(0, -7)]), PIN)
	ci.draw_circle(at, 2.2, PIN)
	if show_text and not text.is_empty():
		var f := font()
		var p := at + Vector2(13, -6)
		ci.draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, SHADOW)
		ci.draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, NOTE_TEXT)
