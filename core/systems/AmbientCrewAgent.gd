extends CharacterBody3D
class_name AmbientCrewAgent
## Lightweight visible-life agent: walks authored waypoints, pauses, repeats.
@export var waypoint_root: NodePath
@export var speed := 2.2
@export var wait_seconds := 2.0
@export var loop := true
var _points: Array[Node3D] = []
var _index := 0
var _waiting := false
func _ready() -> void:
	# REV 147 (item 21): people are solid; background crew don't step aside, they wait
	collision_layer |= CharacterBlocker.LAYER
	collision_mask |= CharacterBlocker.LAYER
	var root := get_node_or_null(waypoint_root)
	if root != null:
		for child in root.get_children():
			if child is Node3D: _points.append(child)
func _physics_process(delta: float) -> void:
	if _waiting or _points.is_empty(): return
	var target := _points[_index].global_position
	var direction := target - global_position
	direction.y = 0.0
	if direction.length() < 0.15:
		_arrive()
		return
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor(): velocity.y -= 9.8 * delta
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 8.0 * delta)
	move_and_slide()
func _arrive() -> void:
	velocity = Vector3.ZERO
	_waiting = true
	await get_tree().create_timer(wait_seconds, false).timeout
	if _index + 1 < _points.size(): _index += 1
	elif loop: _index = 0
	_waiting = false
