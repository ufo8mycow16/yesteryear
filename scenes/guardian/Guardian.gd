extends Node3D
## The Guardian of Forever.
##
## The ring model has no texture layout of its own (it came from a 3D-print kit), so the stone is wrapped on
## from all sides with a triplanar material. The doorway is centred on this node's origin, with its floor at
## ground level, so placing this node is placing the doorway. Travellers walk through along Z.
##
## Inside the ring: the time vortex (guardian_vortex.glb, shaped to the opening, with time_vortex.gdshader)
## and a soft light that lets it glow on the stone. flare_up() makes it blaze while someone passes through.

@export var stone_material: Material
## How far the ring is lifted (Glen: it looked pushed into the ground). 0.28 = its base sits on the ground.
@export var lift := 0.28

const VORTEX_MESH := "res://assets/models/guardian/guardian_vortex.glb"
const VORTEX_SHADER := "res://scenes/guardian/time_vortex.gdshader"

var _vortex_mat: ShaderMaterial = null
var _glow: OmniLight3D = null
var _flare := 0.0
var _flare_target := 0.0


func _ready() -> void:
	var model := get_node_or_null("Model") as Node3D
	if model != null:
		model.position.y = lift
		# the doorway floor rises with the ring, so the vortex goes up with it too
	if stone_material != null:
		for node in find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_override = stone_material
	_add_vortex()


func _add_vortex() -> void:
	if not ResourceLoader.exists(VORTEX_MESH) or not ResourceLoader.exists(VORTEX_SHADER):
		push_warning("Guardian: vortex files missing")
		return
	var packed := load(VORTEX_MESH) as PackedScene
	if packed == null:
		return
	var vortex := packed.instantiate() as Node3D
	vortex.name = "Vortex"
	vortex.position.y = lift
	add_child(vortex)
	_vortex_mat = ShaderMaterial.new()
	_vortex_mat.shader = load(VORTEX_SHADER)
	for node in vortex.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.material_override = _vortex_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow = OmniLight3D.new()
	_glow.name = "VortexGlow"
	_glow.light_color = Color(0.7, 0.72, 1.0)
	_glow.light_energy = 1.4
	_glow.omni_range = 7.0
	_glow.shadow_enabled = false
	_glow.position = Vector3(0.0, lift + 1.4, 0.0)
	add_child(_glow)


## Make the vortex blaze for a moment (someone stepping through). 1 = full, 0 = back to idle.
func flare_up(amount := 1.0) -> void:
	_flare_target = clampf(amount, 0.0, 1.0)


func _process(delta: float) -> void:
	_flare = move_toward(_flare, _flare_target, delta * 1.5)
	if _vortex_mat != null:
		_vortex_mat.set_shader_parameter("flare", _flare)
	if _glow != null:
		_glow.light_energy = 1.4 + _flare * 4.0 + sin(Time.get_ticks_msec() * 0.0013) * 0.15
