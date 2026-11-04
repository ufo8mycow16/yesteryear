extends Node3D
## REV 610: a look at the TOS communicator on its own (run this scene: core/props/communicator/
## CommunicatorPreview.tscn, F6 in the editor). The close-up model turns slowly on a stand; the lid flips open and
## shut every few seconds; the moire turns while it's open.
##   Space = open / shut now     1 / 2 = close-up / standard model     Q / E = turn it     mouse wheel = closer
##   Esc = quit

const PropScript := preload("res://core/props/communicator/CommunicatorProp.gd")

var _prop = null      # a CommunicatorProp
var _cam: Camera3D
var _spin := 0.0
var _dist := 0.26
var _auto := 0.0


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.11, 0.115, 0.13)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.56, 0.6)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 30, 0)
	key.light_energy = 1.6
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.7
	add_child(rim)
	var spot := OmniLight3D.new()
	spot.position = Vector3(0.12, 0.15, 0.25)
	spot.omni_range = 1.5
	spot.light_energy = 0.8
	add_child(spot)
	_cam = Camera3D.new()
	_cam.fov = 35.0
	_cam.near = 0.01
	add_child(_cam)
	_cam.make_current()
	_make(true)


func _make(closeup: bool) -> void:
	if _prop != null:
		_prop.queue_free()
	_prop = PropScript.new()
	_prop.closeup = closeup
	add_child(_prop)


func _process(delta: float) -> void:
	_spin += delta * 0.25
	if Input.is_key_pressed(KEY_Q): _spin -= delta * 1.5
	if Input.is_key_pressed(KEY_E): _spin += delta * 1.5
	_cam.position = Vector3(sin(_spin) * _dist, 0.05, cos(_spin) * _dist)
	_cam.look_at(Vector3(0, 0.01, 0), Vector3.UP)
	_auto += delta
	if _auto > 3.5 and _prop != null:
		_auto = 0.0
		_prop.set_open(not _prop.is_open)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_SPACE:
				_auto = 0.0
				if _prop != null: _prop.set_open(not _prop.is_open)
			KEY_1: _make(true)
			KEY_2: _make(false)
			KEY_ESCAPE: get_tree().quit()
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP: _dist = maxf(0.08, _dist * 0.9)
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN: _dist = minf(1.0, _dist / 0.9)
