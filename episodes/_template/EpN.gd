extends RefCounted
class_name EpN
## TEMPLATE (REV 120) - the data for one episode. tools/new_episode.py copies this folder to
## episodes/episodeN/ and renames EpN -> Ep2 (and EPN_ -> EP2_), so don't edit it here: edit the copy.
##
## Every room of the episode sets `ep = EpN` (see scenes/StartRoom.gd) and EpisodeRoom asks this
## script for everything below - rooms, speakers, flags, objectives, the clock and deductions.
## Episode One's Ep1.gd is the full worked example of each part.

const PREFIX := "EPN"          # every saved name of this episode starts with this
const EPISODE_TITLE := "EPISODE N TITLE"
const SPEECH_ROOT := "res://episodes/_template/audio/speech/"

## who -> [voice folder, name shown in the subtitle]
const SPEAKERS := {
	"mccoy": ["mccoy", "McCoy"],
	"kirk": ["kirk", "Kirk"],
	"spock": ["spock", "Spock"],
}

## room key -> [name shown on arrival and in the travel menu, scene]
const ROOMS := {
	"start": ["Start Room", "res://episodes/_template/scenes/StartRoom.tscn"],
}

## Everything the episode remembers (saved with the game). Prefix them all EPN_.
const DEFAULTS := {
	"EPN_STARTED": false,
	"EPN_ACTIVE_CHAR": "mccoy",
	"EPN_INTRO_DONE": false,
	"EPN_MET_CONTACT": false,
}

## objective key -> text (set with ep.set_objective("KEY") / objective("KEY") in a room)
const OBJECTIVES := {
	"BEGIN": "Find out what's going on.",
	"REPORT": "Report back to the Captain.",
}
const LOG_OBJECTIVE_ENTRY := "LOG_EPN_000"

## REV 293: the Case File's heading for this episode (Episode 1 "CASE FILE - TURIAN", Episode 2
## "SCIENCE OFFICER'S LOG - SPOCK"). Set by ensure_state() and new_game().
const CASE_TITLE := "CASE FILE - EPISODE N TITLE"

## Case File: two clues the player can compare -> the comparison's key (see Ep1.COMPARE_RULES)
const COMPARE_RULES: Array = []


static func ensure_state() -> void:
	_define_clues()
	GameState.register_defaults(DEFAULTS)
	Case.register_defaults()
	Case.title_text = CASE_TITLE      # REV 293: this episode's heading, not the last episode's
	Case.log_id = Case.LOG_ENTRY_ID   # the Case File's Mission Log entry (the Prologue uses its own)
	Case.refresh_log()
	_register_objectives()
	AudioSubtitleManager.speech_root = SPEECH_ROOT


## Wipes everything and starts the episode fresh (the Chapters menu and the previous episode's
## ending call this).
## REV 293: also starts the Case File, the Mission Log and the objective afresh (as the Prologue and
## Ep1.new_game do) - no clues, log entries or objective of another episode left over this session.
static func new_game() -> void:
	Case.clear_definitions()
	_define_clues()
	GameState.reset_to_defaults(DEFAULTS)
	MissionLog.reset()
	ObjectiveManager.reset()
	Case.title_text = CASE_TITLE
	Case.log_id = Case.LOG_ENTRY_ID
	Case.register_defaults()
	GameState.set_var("EPN_STARTED", true)


static func _define_clues() -> void:
	if Case.is_defined("EPN_FIRST_CLUE"):
		return
	# The heading must be one of Case.CATEGORIES (VICTIM, SUSPECT, PHYSICAL EVIDENCE, WITNESS STATEMENTS,
	# MEDICAL FINDINGS, UNRESOLVED QUESTIONS, PERSONS OF INTEREST, DEDUCTIONS) or the clue never shows.
	# (REV 293: this sample used "EVIDENCE", which isn't one.)
	Case.define("EPN_FIRST_CLUE", "PHYSICAL EVIDENCE", "THE FIRST CLUE",
		"What the player learned, written as McCoy would put it in his notes.")


static func _register_objectives() -> void:
	if MissionLog.get_entry(LOG_OBJECTIVE_ENTRY) == null:
		var entry := MissionLogEntryData.new()
		entry.id = LOG_OBJECTIVE_ENTRY
		entry.title = EPISODE_TITLE
		entry.current_text = String(OBJECTIVES.values()[0])
		MissionLog.register_entry(entry)
	for id in OBJECTIVES.keys():
		var obj := ObjectiveData.new()
		obj.id = "OBJ_EPN_" + String(id)
		obj.text = String(OBJECTIVES[id])
		obj.mission_log_entry_id = LOG_OBJECTIVE_ENTRY
		ObjectiveManager.register_objective(obj)


static func set_objective(key: String) -> void:
	if not OBJECTIVES.has(key):
		push_warning("EpN: unknown objective '%s'" % key)
		return
	ObjectiveManager.set_current_objective("OBJ_EPN_" + key)


## The voice file name for a line: MCCOY_EPN_1A2B3C.mp3 (stable as long as the words don't change).
static func line_id(who: String, text: String) -> String:
	var folder: String = String(SPEAKERS.get(who, [who, who])[0])
	return folder.to_upper() + "_EPN_" + text.md5_text().substr(0, 6).to_upper()


static func flag(name: String) -> bool:
	return GameState.has_var(name) and bool(GameState.get_var(name))


static func set_flag(name: String, value: bool = true) -> void:
	GameState.set_var(name, value)


## Which rooms the travel menu offers right now.
static func unlocked_rooms() -> Array:
	return ["start"]


# ---- optional systems (Episode One has a story clock and deductions; return "" to have none) ----

static func clock_text() -> String:
	return ""


static func clock_alert() -> String:
	return ""


static func clock_penalty(_minutes: int = 15) -> int:
	return 0


static func pending_deduction() -> String:
	return ""


static func deduction_ready() -> bool:
	return pending_deduction() != ""


## REV 293: EpisodeRoom hands the Case File's results to the room's episode. With comparisons, write a compare script like Ep1Compare and call it here (see Ep1.run_compare).
static func run_compare(_room: EpisodeRoom, _rule: String) -> bool:
	return false     # false = "not a rule I know" (the lead shrugs)


static func run_deduction(_room: EpisodeRoom) -> void:
	pass


## Shows "NEW DEDUCTION POSSIBLE" once per deduction key (when pending_deduction() returns one);
## true if it was shown now. (See Ep1.deduction_noticed for an episode that has deductions.)
static func deduction_noticed(key: String) -> bool:
	var flag_name := PREFIX + "_" + key.to_upper() + "_NOTICED"
	if flag(flag_name):
		return false
	set_flag(flag_name)
	MissionLog.notification_requested.emit("NEW DEDUCTION POSSIBLE  (press C)")
	return true


static func find_compare(a: String, b: String) -> String:
	for rule in COMPARE_RULES:
		if (rule[0] == a and rule[1] == b) or (rule[0] == b and rule[1] == a):
			return String(rule[2])
	return ""
