extends TurboliftUI
class_name NewShipTurboliftUI
## REV 806 - the turbolift console for the NEW ship (the decks being rebuilt from Franz Joseph's plans). Glen (3 Nov):
## "use the existing turbo lift interface we have, but make a new copy of it ... if you click on deck 7, put locations
## the closest to each of those turbo lifts ... on the right-hand side of the map."
## Same console and cutaway as TurboliftUI (so it looks and handles the same, mouse and pad), but its own directory:
## the places come from set_places() instead of ShipDecks, and a deck with many stops lists them in two columns on
## the right-hand screen.
##
##     ui.set_places([{"deck": 7, "name": "Main Deck", "rooms": [["fj7:3", "Engineering"], ...]}, ...])
##     var key: String = await ui.run(7, "fj7:3")

const MANY := 6           # more places than this: two columns, the deck's description hidden to make room

var _places: Array = []


func set_places(places: Array) -> void:
	_places = places


func _build_entries() -> void:
	_entries.clear()
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	_clear_loc_buttons()
	_shown_row = -1
	_first = 0
	for p in _places:
		_entries.append({"deck": int(p["deck"]), "rooms": p["rooms"], "name": String(p["name"])})
	for i in range(_entries.size()):
		_buttons.append(_make_row(i))


func _show(i: int) -> void:
	super(i)
	_scr_text.visible = (_entries[i]["rooms"] as Array).size() <= MANY


func _place_loc_buttons() -> void:
	if _loc_buttons.size() <= MANY:
		super()
		return
	var cols := 2
	var rows := int(ceil(float(_loc_buttons.size()) / float(cols)))
	var top := _rundown.position.y + 92.0
	var bottom := _rundown.end.y - 8.0
	var h := clampf((bottom - top) / float(rows), 16.0, 26.0)
	var gap := 8.0
	var w := (_rundown.size.x - 24.0 - gap) / float(cols)
	for k in _loc_buttons.size():
		var b := _loc_buttons[k]
		var c := k / rows
		var r := k % rows
		b.position = Vector2(_rundown.position.x + 12.0 + c * (w + gap), top + r * h)
		b.size = Vector2(w, h - 2.0)
		_fit_button(b, w - 12.0, 12, 8)
	# pad / arrow keys: up and down within a column, left and right across
	for k in _loc_buttons.size():
		var b := _loc_buttons[k]
		var c := k / rows
		var r := k % rows
		if r > 0:
			b.focus_neighbor_top = _loc_buttons[k - 1].get_path()
		if r < rows - 1 and k + 1 < _loc_buttons.size():
			b.focus_neighbor_bottom = _loc_buttons[k + 1].get_path()
		if c > 0:
			b.focus_neighbor_left = _loc_buttons[k - rows].get_path()
		if k + rows < _loc_buttons.size():
			b.focus_neighbor_right = _loc_buttons[k + rows].get_path()
