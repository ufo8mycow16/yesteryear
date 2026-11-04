extends Node
## Party registry + character-specific capabilities/reactions. Movement is supplied by CompanionFollower.
signal active_character_changed(id: String)
var members: Dictionary = {}
var active_id := ""
func register_member(id: String, body: Node3D, capabilities: Array[String] = []) -> void: members[id] = {"body": body, "capabilities": capabilities.duplicate()}
func unregister_member(id: String) -> void: members.erase(id)
func set_active(id: String) -> void:
	if not members.has(id): return
	active_id = id; active_character_changed.emit(id)
func get_active_body() -> Node3D: return members.get(active_id, {}).get("body", null)
func has_capability(id: String, capability: String) -> bool: return members.has(id) and capability in members[id].capabilities
func active_has(capability: String) -> bool: return has_capability(active_id, capability)
func clear() -> void: members.clear(); active_id = ""
