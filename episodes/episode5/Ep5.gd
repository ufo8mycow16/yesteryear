extends RefCounted
class_name Ep5
## REV 489: Episode 5's data, started early for the Peacekeeper's memory ("Arena" - the Gorn fight),
## which Glen asked to build ahead of the rest of the episode (script: episodes/episode5/ARENA_MEMORY_SCRIPT.md).
## The rest of Episode 5 adds its rooms, speakers, flags and objectives here later.
##
## Rooms of the episode set `ep = Ep5` in _init() and EpisodeRoom asks this script for everything.
## Made from episodes/_template/EpN.gd (see docs/NEW_EPISODE.md).

const PREFIX := "EP5"
const EPISODE_TITLE := "FURY"
const SPEECH_ROOT := "res://episodes/episode5/audio/speech/"
## The redesign style: no Case File on screen (EpisodeRoom.case_file_on reads this).
const CASE_FILE := false

## who -> [voice folder, name shown in the subtitle]
## kirk_vo = Kirk remembering: his inner voice (V.O.), no lip movement (no figure carries that id).
const SPEAKERS := {
	"kirk": ["kirk", "Kirk"],
	"kirk_vo": ["kirk_vo", "Kirk (remembering)"],
	"gorn": ["gorn", "The Gorn"],
	"fury": ["fury", "Fury"],
	"spock": ["spock", "Spock"],
	"mccoy": ["mccoy", "McCoy"],
}

## room key -> [name shown on arrival and in the travel menu, scene]
## "peacekeeper" (the Peacekeeper's wing, the memory's way in and out) isn't built yet - the memory
## checks ResourceLoader.exists before going there.
const ROOMS := {
	"arena": ["A Memory", "res://episodes/episode5/scenes/ArenaMemory.tscn"],
	"peacekeeper": ["Fury - The Peacekeeper's Wing", "res://episodes/episode5/scenes/PeacekeeperWing.tscn"],
}

## Everything the episode remembers, IN STORY ORDER (DEBUG: SCENE SELECT sets every yes/no flag before
## a scene's "before" flag).
const DEFAULTS := {
	"EP5_STARTED": false,
	"EP5_ACTIVE_CHAR": "kirk",
	# --- the Peacekeeper's memory ("Arena")
	"EP5_ARENA_STARTED": false,
	"EP5_ARENA_TRANSLATOR": false,
	"EP5_ARENA_KNOCKDOWN": false,
	"EP5_ARENA_POWDER_IDEA": false,
	"EP5_ARENA_POWDER": false,
	"EP5_ARENA_CANNON_SET": false,
	"EP5_ARENA_FIRED": false,
	"EP5_ARENA_DONE": false,
	"EP5_ARENA_ASKED_WHY": false,
	"EP5_ARENA_TEMPTED": 0,
}

## objective key -> text (set with objective("KEY") in a room)
const OBJECTIVES := {
	"ARENA_SURVIVE": "Survive.",
	"ARENA_ANOTHER_WAY": "Find another way to win. Stay out of the Gorn's reach.",
	"ARENA_POWDER": "Make gunpowder.",           # REV 523: with a checklist (ArenaMemory._tracker_update)
	"ARENA_GRIND": "Grind the gunpowder.",
	"ARENA_BUILD": "Build a cannon.",
	"ARENA_SET": "Brace the cannon in the rocks.",   # (REV 523: no longer used - the cannon is built in place)
	"ARENA_LURE": "Lure the Gorn into the line of fire.",
}
const LOG_OBJECTIVE_ENTRY := "LOG_EP5_000"
const CASE_TITLE := "CAPTAIN'S LOG - FURY"
const COMPARE_RULES: Array = []

## REV 489: DEBUG: SCENE SELECT (MainMenu loads this script by path, like Episode 2's).
const DEBUG_SCENES := [
	{"label": "THE PEACEKEEPER'S MEMORY - ARENA (START)", "room": "arena", "objective": "ARENA_SURVIVE"},
	{"label": "ARENA - MAKE GUNPOWDER (AFTER THE FIRST FIGHT)", "room": "arena", "before": "EP5_ARENA_POWDER_IDEA", "objective": "ARENA_POWDER"},
	{"label": "ARENA - THE CANNON IS SET (LURE HIM IN)", "room": "arena", "before": "EP5_ARENA_FIRED", "objective": "ARENA_LURE"},
]


static func ensure_state() -> void:
	GameState.register_defaults(DEFAULTS)
	Case.register_defaults()
	Case.title_text = CASE_TITLE
	Case.log_id = Case.LOG_ENTRY_ID
	Case.refresh_log()
	_register_objectives()
	AudioSubtitleManager.speech_root = SPEECH_ROOT


static func new_game() -> void:
	Case.clear_definitions()
	GameState.reset_to_defaults(DEFAULTS)
	MissionLog.reset()
	ObjectiveManager.reset()
	InventoryManager.clear()
	Case.title_text = CASE_TITLE
	Case.log_id = Case.LOG_ENTRY_ID
	Case.register_defaults()
	GameState.set_var("EP5_STARTED", true)


## Sets the story up for DEBUG_SCENES[i] and returns the scene to open. The arena room rebuilds its
## backpack, grinding stone and cannon from these flags (ArenaMemory._restore_progress).
static func debug_scene(i: int) -> String:
	var s: Dictionary = DEBUG_SCENES[clampi(i, 0, DEBUG_SCENES.size() - 1)]
	new_game()
	if s.has("before"):
		var stop := String(s["before"])
		for key in DEFAULTS.keys():
			var k := String(key)
			if k == stop:
				break
			if typeof(DEFAULTS[key]) == TYPE_BOOL:
				set_flag(k)
	GameState.set_var("EP5_ARENA_DEBUG_START", true)     # the room fills the backpack to match
	ensure_state()
	if s.has("objective"):
		set_objective(String(s["objective"]))
	return String(ROOMS[String(s["room"])][1])


static func _register_objectives() -> void:
	if MissionLog.get_entry(LOG_OBJECTIVE_ENTRY) == null:
		var entry := MissionLogEntryData.new()
		entry.id = LOG_OBJECTIVE_ENTRY
		entry.title = EPISODE_TITLE
		entry.current_text = String(OBJECTIVES.values()[0])
		MissionLog.register_entry(entry)
	for id in OBJECTIVES.keys():
		var obj := ObjectiveData.new()
		obj.id = "OBJ_EP5_" + String(id)
		obj.text = String(OBJECTIVES[id])
		obj.mission_log_entry_id = LOG_OBJECTIVE_ENTRY
		ObjectiveManager.register_objective(obj)


static func set_objective(key: String) -> void:
	if not OBJECTIVES.has(key):
		push_warning("Ep5: unknown objective '%s'" % key)
		return
	ObjectiveManager.set_current_objective("OBJ_EP5_" + key)


## The voice file name for a line: KIRK_EP5_1A2B3C.mp3 (stable as long as the words don't change).
static func line_id(who: String, text: String) -> String:
	var folder: String = String(SPEAKERS.get(who, [who, who])[0])
	return folder.to_upper() + "_EP5_" + text.md5_text().substr(0, 6).to_upper()


static func flag(name: String) -> bool:
	return GameState.has_var(name) and bool(GameState.get_var(name))


static func set_flag(name: String, value: bool = true) -> void:
	GameState.set_var(name, value)


## Episode 5 moves by story only (no travel menu).
static func unlocked_rooms() -> Array:
	return []


# ---- the optional systems EpisodeRoom asks every episode for (Episode 5 has none) ----

static func clock_text() -> String:
	return ""


static func clock_alert() -> String:
	return ""


static func clock_penalty(_minutes: int = 15) -> int:
	return 0


static func pending_deduction() -> String:
	return ""


static func deduction_ready() -> bool:
	return false


static func run_compare(_room: EpisodeRoom, _rule: String) -> bool:
	return false


static func run_deduction(_room: EpisodeRoom) -> void:
	pass


static func deduction_noticed(_key: String) -> bool:
	return false


static func find_compare(_a: String, _b: String) -> String:
	return ""
