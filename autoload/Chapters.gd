extends Node
## Chapters (REV 117): the main menu's CHAPTERS list - replay any part of the game you have reached.
##
## A chapter unlocks the first time you get there (remembered in user://chapters.cfg, separate from
## saves, so it survives starting a new game). Reaching is noticed from the room you're in, so
## scene scripts don't need to report it; the opening titles report themselves.
## For a new episode: add its entries to CHAPTERS and a line to _chapter_for_scene().

const FILE := "user://chapters.cfg"
const CHAPTERS := [
	{"id": "cold_open", "title": "COLD OPEN: KI BARATAN", "scene": "res://episodes/prologue/scenes/ColdOpen.tscn"},
	{"id": "prologue", "title": "PROLOGUE: THE BOWLING ALLEY", "scene": "res://episodes/prologue/scenes/BowlingAlley.tscn"},
	{"id": "titles", "title": "OPENING TITLES", "scene": "res://core/ui/cutscene/TitlesPreview.tscn"},
	{"id": "ep1", "title": "EPISODE ONE: IN SHEEP'S CLOTHING", "scene": "res://episodes/episode1/scenes/Ep1Opening.tscn", "episode1": true},
	{"id": "ep1_credits", "title": "EPISODE ONE: END CREDITS", "credits": "IN SHEEP'S CLOTHING"},
	{"id": "ep2", "title": "EPISODE TWO: ECHOES OF THE DEAD", "scene": "res://episodes/episode2/scenes/Sickbay.tscn", "episode2": true},
	{"id": "ep2_credits", "title": "EPISODE TWO: END CREDITS", "credits": "ECHOES OF THE DEAD"},
	{"id": "ep3", "title": "EPISODE THREE: GHOST IN THE MACHINE", "scene": "res://episodes/episode3/scenes/Ep3Opening.tscn", "episode3": true},
	{"id": "ep3_credits", "title": "EPISODE THREE: END CREDITS", "credits": "GHOST IN THE MACHINE"},
]

var _reached := {"cold_open": true}
var _last_scene: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(FILE) == OK:
		for id in cfg.get_section_keys("reached") if cfg.has_section("reached") else []:
			_reached[String(id)] = bool(cfg.get_value("reached", id, false))


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == _last_scene or scene == null:
		return
	_last_scene = scene
	var id := _chapter_for_scene(scene.scene_file_path)
	if id != "":
		reach(id)


static func _chapter_for_scene(path: String) -> String:
	if path.ends_with("ColdOpen.tscn"):
		return "cold_open"
	if path.ends_with("BowlingAlley.tscn"):
		return "prologue"
	if path.ends_with("EpisodeOneEnd.tscn"):
		return "ep1_credits"
	if path.begins_with("res://episodes/episode1/"):
		return "ep1"
	if path.ends_with("EpisodeTwoEnd.tscn"):
		return "ep2_credits"
	if path.begins_with("res://episodes/episode2/"):
		return "ep2"
	if path.ends_with("EpisodeThreeEnd.tscn"):
		return "ep3_credits"
	if path.begins_with("res://episodes/episode3/"):
		return "ep3"
	return ""


## Mark a chapter as reached (also unlocks everything before it - you can't reach Episode One
## without passing the titles).
func reach(id: String) -> void:
	var changed := false
	for c in CHAPTERS:
		if not bool(_reached.get(c["id"], false)):
			_reached[c["id"]] = true
			changed = true
		if c["id"] == id:
			break
	if changed:
		var cfg := ConfigFile.new()
		for k in _reached.keys():
			cfg.set_value("reached", String(k), bool(_reached[k]))
		cfg.save(FILE)


func is_reached(id: String) -> bool:
	return bool(_reached.get(id, false))
