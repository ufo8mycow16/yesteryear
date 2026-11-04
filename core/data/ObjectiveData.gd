extends Resource
class_name ObjectiveData
## One objective (OBJ_PRO_xxx). Objectives have no permanent on-screen
## tracker — they live in the Mission Log, and a change surfaces only as a
## brief fading HUD notification (per the locked Game Systems Design HUD
## rules, reconciled again explicitly in the Prologue document).

@export var id: String = ""          # e.g. "OBJ_PRO_001"
@export_multiline var text: String = ""
@export var mission_log_entry_id: String = ""  # which LOG_PRO_xxx this writes to
