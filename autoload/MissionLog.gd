extends Node
## MissionLog — episode-scoped, evolving single-entry-per-investigation log.
##
## Never auto-opens. Updating an entry fires a brief fading "Mission Log
## Updated" HUD notification only; the full log is read in the dedicated
## Mission Log UI (opened on player input), not pushed onto the player.

signal entry_updated(entry_id: String)
signal notification_requested(message: String)

var _entries: Dictionary = {}  # id -> MissionLogEntryData


## REV 77: wipes every entry (a genuinely new game must not show a previous run's log).
func reset() -> void:
	_entries.clear()


func register_entry(entry: MissionLogEntryData) -> void:
	if not _entries.has(entry.id):
		_entries[entry.id] = entry


## Updates an existing entry's text in place (the normal case — an
## investigation progressing) and fires the fading notification. Does NOT
## open the Mission Log UI.
func update_entry(entry_id: String, new_text: String) -> void:
	if not _entries.has(entry_id):
		push_error("MissionLog: update_entry called for unregistered entry %s" % entry_id)
		return
	_entries[entry_id].current_text = new_text
	entry_updated.emit(entry_id)
	notification_requested.emit("Mission Log Updated")


func get_entry(entry_id: String) -> MissionLogEntryData:
	return _entries.get(entry_id)


func get_all_entries() -> Array[MissionLogEntryData]:
	var result: Array[MissionLogEntryData] = []
	for e in _entries.values():
		result.append(e)
	return result


func get_snapshot() -> Dictionary:
	var snap := {}
	for id in _entries.keys():
		snap[id] = _entries[id].current_text
	return snap


func load_snapshot(snapshot: Dictionary) -> void:
	for id in snapshot.keys():
		if _entries.has(id):
			_entries[id].current_text = snapshot[id]
