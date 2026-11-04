extends Node
## Persistent state for rooms and stateful interactables, stored inside GameState.
const VAR := "WORLD_STATE"
signal state_changed(key: String, value: Variant)
func _ready() -> void: GameState.register_defaults({VAR: {}})
func _all() -> Dictionary:
	var v = GameState.get_var(VAR); return (v as Dictionary).duplicate(true) if v is Dictionary else {}
## REV 293: reads no longer deep-copy the whole world state every call (CrewRoster asks once per crew
## member). Only the one value asked for is copied, and only if it is a list or dictionary, so a
## caller changing what it got back still can't change the saved state - same as before.
func get_value(key: String, default: Variant = null) -> Variant:
	var v = GameState.get_var(VAR)
	if not (v is Dictionary) or not (v as Dictionary).has(key):
		return default
	var out = (v as Dictionary)[key]
	if out is Dictionary or out is Array:
		return out.duplicate(true)
	return out
func set_value(key: String, value: Variant) -> void:
	var d := _all(); d[key] = value; GameState.set_var(VAR, d); state_changed.emit(key, value)
func erase(key: String) -> void:
	var d := _all(); if d.erase(key): GameState.set_var(VAR, d); state_changed.emit(key, null)
func room_key(room: String, item: String) -> String: return "room/%s/%s" % [room, item]
func object_key(id: String, field: String = "state") -> String: return "object/%s/%s" % [id, field]

func snapshot() -> Dictionary: return _all()

## REV 254 (Glen): the ship's alert condition - "green" (normal, the default: every new game starts there)
## or "red". Rooms show it on their CONDITION ALERT panels (ModelRoom) and follow any change at once.
## Story scenes set it with WorldState.set_ship_condition("red") / ("green"); it is saved with the game.
const CONDITION_KEY := "ship/condition"
func ship_condition() -> String: return String(get_value(CONDITION_KEY, "green"))
func set_ship_condition(condition: String) -> void:
	var red := condition.to_lower() == "red"
	var was := ship_condition()
	set_value(CONDITION_KEY, "red" if red else "green")
	# REV 741 (Glen's bug list item 8: "when red alert is on ... there should be a red alert klaxon" - "a few times
	# and then stop is fine"): going to red sounds Glen's TOS klaxon, four whoops (red_alert_klaxon.mp3, cut from
	# assets/audio/sfx/_originals/tos_red_alert_full.mp3); the alert panels keep flashing after it (ModelRoom)
	if red and was != "red":
		SfxManager.play("red_alert_klaxon", -3.0)
