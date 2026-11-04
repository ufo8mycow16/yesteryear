extends Resource
class_name MissionLogEntryData
## One Mission Log entry (LOG_PRO_xxx). Entries are episode-scoped and evolve
## in place as an investigation progresses — there is one entry per
## investigation, not a new entry per clue. "Updated" means this entry's
## current_text changes; the entry's identity (id) never changes.

@export var id: String = ""          # e.g. "LOG_PRO_002"
@export var title: String = ""
@export_multiline var current_text: String = ""
