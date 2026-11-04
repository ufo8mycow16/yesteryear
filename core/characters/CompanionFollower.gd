extends CharacterBody3D
class_name CompanionFollower
## REV 293: not used yet - nothing creates a CompanionFollower; companions are placed by the rooms.
@export var target: Node3D
@export var follow_distance := 1.7
@export var catchup_distance := 5.0
@export var walk_speed := 3.5
@export var catchup_speed := 5.0
@export var rotation_speed := 8.0
@export var enabled := true
func _ready() -> void:
	# REV 147 (item 21): people are solid - bump into the player and other characters, and be bumped
	collision_layer |= CharacterBlocker.LAYER
	collision_mask |= CharacterBlocker.LAYER
func _physics_process(delta: float) -> void:
	if not enabled or target == null: velocity = Vector3.ZERO; return
	var offset := target.global_position - global_position; offset.y = 0
	if offset.length() <= follow_distance: velocity.x = move_toward(velocity.x,0.0,walk_speed*delta*4); velocity.z = move_toward(velocity.z,0.0,walk_speed*delta*4)
	else:
		var d := offset.normalized(); var speed := catchup_speed if offset.length() > catchup_distance else walk_speed
		velocity.x = d.x*speed; velocity.z = d.z*speed; rotation.y = lerp_angle(rotation.y, atan2(d.x,d.z), rotation_speed*delta)
	if not is_on_floor(): velocity.y -= 9.8*delta
	move_and_slide()
