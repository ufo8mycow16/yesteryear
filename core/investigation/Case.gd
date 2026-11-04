extends RefCounted
class_name Case
## Case — the investigation notebook ("CASE FILE — TURIAN").
##
## Everything the player has found out lives here as CLUES. A clue is only ever
## added by something the player actually DID (scanned it, asked about it,
## compared two things) — never by walking past it.
##
## All state is stored in GameState (variables named CLUE_<ID>, plus two small
## bookkeeping entries), so saving and loading the game keeps the Case File
## with no extra work.
##
## This file is only helpers (static functions). The window the player sees is
## CaseFileUI.gd.

const ORDER_VAR := "CASE_ORDER"          # Array of clue ids, in the order found
const OVERRIDE_VAR := "CASE_OVERRIDES"   # Dictionary id -> [title, text] (re-labelled clues)
const LOG_ENTRY_ID := "LOG_EP1_001"

## The window / log heading and the Mission Log entry id. Episode 1 uses these
## defaults; the Prologue sets its own for the length of the scene.
static var title_text: String = "CASE FILE - TURIAN"
static var log_id: String = LOG_ENTRY_ID
## REV 476 (the redesign): true in rooms whose episode has no Case File on screen (EpisodeRoom sets it
## from the episode's CASE_FILE). Clues are still kept - they are what the characters remember and what
## the story checks - but nothing pops up when one is added or re-labelled.
static var silent: bool = false

## The headings the Case File is sorted under, in display order.
const CATEGORIES: Array = [
	"VICTIM",
	"SUSPECT",
	"PHYSICAL EVIDENCE",
	"WITNESS STATEMENTS",
	"MEDICAL FINDINGS",
	"UNRESOLVED QUESTIONS",
	"PERSONS OF INTEREST",
	"DEDUCTIONS",
]

## id -> {"cat": String, "title": String, "text": String}
static var _defs: Dictionary = {}


## Registers one clue. Called once for each clue when an episode scene starts.
static func define(id: String, category: String, title: String, text: String) -> void:
	_defs[id] = {"cat": category, "title": title, "text": text}


static func clear_definitions() -> void:
	_defs.clear()


static func is_defined(id: String) -> bool:
	return _defs.has(id)


## Makes sure every clue has a GameState variable (false until found). Never
## overwrites anything already there (a loaded save).
static func register_defaults() -> void:
	var defaults := {}
	for id in _defs.keys():
		defaults["CLUE_" + String(id)] = false
	defaults[ORDER_VAR] = []
	defaults[OVERRIDE_VAR] = {}
	GameState.register_defaults(defaults)


static func has(id: String) -> bool:
	return GameState.has_var("CLUE_" + id) and bool(GameState.get_var("CLUE_" + id))


## Adds a clue. Returns true if it was new (so callers can react only once).
static func add(id: String, quiet: bool = false) -> bool:
	if not _defs.has(id):
		push_warning("Case: unknown clue id '%s'" % id)
		return false
	if has(id):
		return false
	GameState.set_var("CLUE_" + id, true)
	var order_v: Variant = GameState.get_var(ORDER_VAR)
	var order: Array = []
	if order_v is Array:
		order = (order_v as Array).duplicate()
	order.append(id)
	GameState.set_var(ORDER_VAR, order)
	# Notify the generic deduction layer; existing Case behaviour remains authoritative.
	InvestigationSystem.note_evidence(id)
	refresh_log()
	if not quiet and not silent:
		last_added_id = id
		MissionLog.notification_requested.emit("Case File Updated: " + get_title(id))
	return true


## REV 160 (item 24): the clue whose "Case File Updated" notice was sent last, so the notice can say
## what kind of thing was added.
static var last_added_id: String = ""

## What the notice's last line says for each Case File heading.
const ADDED_LINES := {
	"VICTIM": "VICTIM DETAILS ADDED",
	"SUSPECT": "SUSPECT DETAILS ADDED",
	"PHYSICAL EVIDENCE": "EVIDENCE ADDED",
	"WITNESS STATEMENTS": "STATEMENT ADDED",
	"MEDICAL FINDINGS": "MEDICAL FINDING ADDED",
	"UNRESOLVED QUESTIONS": "QUESTION ADDED",
	"PERSONS OF INTEREST": "PERSON OF INTEREST ADDED",
	"DEDUCTIONS": "DEDUCTION MADE",
}


## "EVIDENCE ADDED" and so on, for a clue ("" if unknown).
static func added_line(id: String) -> String:
	return String(ADDED_LINES.get(get_category(id), "ADDED TO THE CASE FILE")) if _defs.has(id) else ""


## Gives a clue a new heading/wording (e.g. "INCRIMINATING" becomes
## "CONSISTENT WITH ULLUS' STATEMENT") without losing it.
static func relabel(id: String, new_title: String, new_text: String) -> void:
	if not _defs.has(id):
		return
	var overrides_v: Variant = GameState.get_var(OVERRIDE_VAR)
	var overrides: Dictionary = {}
	if overrides_v is Dictionary:
		overrides = (overrides_v as Dictionary).duplicate()
	overrides[id] = [new_title, new_text]
	GameState.set_var(OVERRIDE_VAR, overrides)
	refresh_log()
	if not silent:
		MissionLog.notification_requested.emit("Case File Updated")


static func get_title(id: String) -> String:
	var overrides: Variant = GameState.get_var(OVERRIDE_VAR)
	if overrides is Dictionary and overrides.has(id):
		return String(overrides[id][0])
	return String(_defs.get(id, {}).get("title", id))


static func get_text(id: String) -> String:
	var overrides: Variant = GameState.get_var(OVERRIDE_VAR)
	if overrides is Dictionary and overrides.has(id):
		return String(overrides[id][1])
	return String(_defs.get(id, {}).get("text", ""))


static func get_category(id: String) -> String:
	return String(_defs.get(id, {}).get("cat", ""))


## Clue ids found so far, oldest first.
static func known() -> Array:
	var order: Variant = GameState.get_var(ORDER_VAR)
	if order is Array:
		return order
	return []


static func known_in_category(category: String) -> Array:
	var result: Array = []
	for id in known():
		if get_category(String(id)) == category:
			result.append(id)
	return result


## A plain-text summary for the Mission Log entry, so the player can also read
## their notes from the normal LOG screen.
static func summary_text() -> String:
	var lines: Array[String] = []
	for category in CATEGORIES:
		var ids := known_in_category(category)
		if ids.is_empty():
			continue
		lines.append(category)
		for id in ids:
			lines.append("  - " + get_title(String(id)))
		lines.append("")
	if lines.is_empty():
		return "Nothing recorded yet."
	return "\n".join(lines).strip_edges()


## Creates the Mission Log entry on first use and rewrites it on later calls.
static func refresh_log() -> void:
	if MissionLog.get_entry(log_id) == null:
		var entry := MissionLogEntryData.new()
		entry.id = log_id
		entry.title = title_text
		entry.current_text = summary_text()
		MissionLog.register_entry(entry)
		return
	var existing: MissionLogEntryData = MissionLog.get_entry(log_id)
	existing.title = title_text      # REV 293: Episodes 1 and 2 share this entry - keep its heading current
	existing.current_text = summary_text()


## Puts the Episode 1 heading back (the Prologue calls this when it ends).
static func reset_to_episode_defaults() -> void:
	title_text = "CASE FILE - TURIAN"
	log_id = LOG_ENTRY_ID
