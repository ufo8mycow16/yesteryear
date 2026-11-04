extends Hotspot
class_name StatefulInteractable
## Generic persistent hotspot state with optional character/capability/knowledge gates.
@export var initial_state := "unused"
@export var required_character := ""
@export var required_capability := ""
@export var required_knowledge: Array[String] = []
signal state_changed(old_state: String, new_state: String)
func persistent_key() -> String: return WorldState.object_key(hotspot_id)
func get_state() -> String: return String(WorldState.get_value(persistent_key(), initial_state))
func set_state(value: String) -> void:
	var old := get_state(); if old == value: return
	WorldState.set_value(persistent_key(), value); state_changed.emit(old, value)
func requirements_met() -> bool:
	if required_character != "" and CompanionManager.active_id != required_character: return false
	if required_capability != "" and not CompanionManager.active_has(required_capability): return false
	for id in required_knowledge:
		if not InvestigationSystem.has_knowledge(id): return false
	return true
