extends Resource
class_name CameraShotData
## One scripted cutscene camera shot (CAM_PRO_xxx). Data-driven so camera
## work for any episode is "author a shot resource," not new GDScript.

@export var id: String = ""                  # e.g. "CAM_PRO_004"
@export var target_position: Vector3 = Vector3.ZERO
@export var look_at_position: Vector3 = Vector3.ZERO
@export var blend_time: float = 1.2
