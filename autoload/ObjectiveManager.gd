extends Node
## ObjectiveManager — the current objective.
##
## A change surfaces as a brief fading notification ("New Objective: ...") and, since REV 475 (the
## redesign, Glen: "World of Warcraft style"), as ONE line in the HUD's mission tracker under the
## minimap (HUD._build_objective_tracker) that ticks off when complete_current_objective() is called.
## The tracker hides in conversations and cutscenes.

signal objective_changed(objective: ObjectiveData)
signal notification_requested(message: String)
## REV 475: the current objective was finished (the HUD's mission tracker ticks it off).
signal objective_completed(objective: ObjectiveData)
## REV 475: there is no current objective any more (the tracker hides).
signal objective_cleared

var _objectives: Dictionary = {}   # id -> ObjectiveData
var _current_id: String = ""


## REV 293: no current objective (a new game, or a save about to put its own back). The objectives
## themselves stay registered - each episode registers its own again when its rooms start.
func reset() -> void:
	_current_id = ""
	objective_cleared.emit()


## REV 475: a quick way for a room to make and show an objective in one call:
## ObjectiveManager.show_objective("OBJ_PRO_2001", "Bowl a strike on Lane 3", "LOG_PRO_002").
## Re-showing the current one with the same text does nothing (no repeat notice).
func show_objective(objective_id: String, text: String, log_entry_id: String = "") -> void:
	if _current_id == objective_id and _objectives.has(objective_id) and String(_objectives[objective_id].text) == text:
		return
	var o := ObjectiveData.new()
	o.id = objective_id
	o.text = text
	o.mission_log_entry_id = log_entry_id
	register_objective(o)
	set_current_objective(objective_id)


func register_objective(objective: ObjectiveData) -> void:
	_objectives[objective.id] = objective


func set_current_objective(objective_id: String) -> void:
	if not _objectives.has(objective_id):
		push_error("ObjectiveManager: unknown objective %s" % objective_id)
		return
	_current_id = objective_id
	var objective: ObjectiveData = _objectives[objective_id]

	if objective.mission_log_entry_id != "":
		MissionLog.update_entry(objective.mission_log_entry_id, objective.text)

	objective_changed.emit(objective)
	notification_requested.emit("Objective Updated")


## For the (common) case where an objective is finished but there is no
## next objective to move to yet (e.g. the Prologue ends right after this
## one) — fires the fading notification without changing _current_id.
func complete_current_objective() -> void:
	notification_requested.emit("Objective Complete")
	var o := get_current_objective()
	if o != null:
		objective_completed.emit(o)


## REV 475: true if objective_id is the one on screen now.
func is_current(objective_id: String) -> bool:
	return _current_id == objective_id


func get_current_objective() -> ObjectiveData:
	if _current_id == "":
		return null
	return _objectives.get(_current_id)


func get_snapshot() -> String:
	return _current_id


func load_snapshot(objective_id: String) -> void:
	if objective_id != "" and _objectives.has(objective_id):
		_current_id = objective_id
		objective_changed.emit(_objectives[objective_id])     # REV 475: the tracker shows it again
