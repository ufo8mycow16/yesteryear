extends Camera3D
## Simple look-around camera for viewing a model.
## Hold the left or right mouse button and drag to swing around it,
## mouse wheel to zoom in and out.

@export var target := Vector3(-0.3, 1.6, 0.0)
@export var distance := 9.0

var _yaw := 0.0
var _pitch := -0.12
var _dragging := false

func _ready() -> void:
	_place()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT or b.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = b.pressed
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(2.0, distance * 0.9)
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(60.0, distance * 1.1)
		_place()
	elif event is InputEventMouseMotion and _dragging:
		var m := event as InputEventMouseMotion
		_yaw -= m.relative.x * 0.005
		_pitch = clampf(_pitch - m.relative.y * 0.005, -1.4, 0.05)
		_place()

func _place() -> void:
	var offset := Vector3(0, 0, distance).rotated(Vector3.RIGHT, _pitch).rotated(Vector3.UP, _yaw)
	global_position = target + offset
	look_at(target, Vector3.UP)
