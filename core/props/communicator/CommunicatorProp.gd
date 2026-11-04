class_name CommunicatorProp
extends Node3D
## REV 610: Glen's TOS communicator (the Unimatrix Red kit he sent, assembled by tools/props/communicator/ -
## docs/systems/communicator-prop.md). Loads the model, puts the live moire on its speaker disc, and opens and
## closes the lid on its hinge.
##
##   var c := CommunicatorProp.new(); c.closeup = true; add_child(c)
##   await c.set_open(true)          # flip the lid open (LID_OPEN_SECONDS)
##
## The model: +Y = up the communicator (the hinge end), +Z = its front, origin = the middle of the closed body,
## real size (about 62 x 107 x 24 mm). LidPivot turns about its X: LID_CLOSED_DEG (resting shut - the kit's lid
## stops 3.25 degrees short of flat, on the bottom of the face recess) to LID_OPEN_DEG (flipped open).

const MODEL_CLOSEUP := "res://assets/models/props/communicator_tos/communicator_tos_closeup.glb"
const MODEL_STANDARD := "res://assets/models/props/communicator_tos/communicator_tos_standard.glb"
const MOIRE_SHADER := "res://core/props/communicator/moire_spokes.gdshader"

const LID_CLOSED_DEG := -3.25
const LID_OPEN_DEG := -115.0
const LID_OPEN_SECONDS := 0.32       # a flick of the wrist
const LID_CLOSE_SECONDS := 0.22
## The moire: one full turn of the offset wheel takes this long (Ron Logan's pattern: 50 s); it turns while
## the lid is open (MOIRE_ALWAYS = true: always).
const MOIRE_SECONDS_PER_TURN := 50.0
const MOIRE_ALWAYS := false

@export var closeup := false          # the full-detail model (close-ups); false = the lighter one for in hand

var model: Node3D = null
var lid: Node3D = null                # LidPivot
var is_open := false
var _moire: ShaderMaterial = null
var _turn := 0.0
var _tween: Tween = null


func _ready() -> void:
	var path := MODEL_CLOSEUP if closeup else MODEL_STANDARD
	if not ResourceLoader.exists(path):
		push_warning("CommunicatorProp: %s is missing" % path)
		return
	model = (load(path) as PackedScene).instantiate() as Node3D
	add_child(model)
	lid = model.find_child("LidPivot", true, false) as Node3D
	if lid != null:
		lid.rotation_degrees.x = LID_CLOSED_DEG
	if ResourceLoader.exists(MOIRE_SHADER):
		_moire = ShaderMaterial.new()
		_moire.shader = load(MOIRE_SHADER)
		_put_moire(model)


## The disc's surfaces (material "Moire" in the glb) get the live pattern.
func _put_moire(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m != null and m.resource_name == "Moire":
				mi.set_surface_override_material(i, _moire)
	for c in n.get_children():
		_put_moire(c)


## Flip the lid open (or shut). Await it to wait for the movement.
func set_open(on: bool, seconds: float = -1.0) -> void:
	is_open = on
	if lid == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var t := seconds if seconds >= 0.0 else (LID_OPEN_SECONDS if on else LID_CLOSE_SECONDS)
	var to := LID_OPEN_DEG if on else LID_CLOSED_DEG
	if t <= 0.0:
		lid.rotation_degrees.x = to
		return
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if on else Tween.EASE_IN)
	_tween.tween_property(lid, "rotation_degrees:x", to, t)
	await _tween.finished


func _process(delta: float) -> void:
	if _moire == null or not (is_open or MOIRE_ALWAYS):
		return
	_turn = fmod(_turn + delta * TAU / MOIRE_SECONDS_PER_TURN, TAU)
	_moire.set_shader_parameter("turn", _turn)
