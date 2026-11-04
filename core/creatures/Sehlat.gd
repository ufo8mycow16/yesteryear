extends Node3D
## REV 878: the SEHLAT - Glen's Daz 'Brown Bear by AM' made into a rigged, animated glTF by
## tools/creatures/daz_figure_to_gltf.py (recipe in docs/systems/sehlat.md), with six-inch fangs and shell fur.
## Brown on purpose (Glen: "Spock's bear was brown").
##
##   var s = Sehlat.make(parent, "Sehlat", position, facing_degrees)   # null if the model isn't there
##   s.call("show_teeth")    # jaw open + snarl, then back
##   s.call("head_down")     # lowers its head and keeps it down (calmed)
##   s.call("look_toward", world_position)   # turns its head (0 = straight ahead again: look_toward(null))
##   s.call("settle")        # curls up and goes to sleep
##   s.call("play_clip", "walk")   # any clip: idle walk run sit sleep relax stand_up attack roar dig defend rest
##
## Head, jaw and breathing are a skeleton modifier on top of whatever clip plays, so they work in every pose.

const MODEL := "res://assets/models/creatures/sehlat/sehlat.gltf"
const FUR_SHADER := "res://core/creatures/sehlat_fur.gdshader"
const SCALE := 1.35            # the bear is 2.4 m nose to tail; a sehlat is bigger (about 3.2 m, 2 m standing)
const BODY_MIDDLE := 0.8      # model metres from the tail-end origin to the middle of the lying body
const START_CLIP := "relax"    # lying down, head up, front paws out
const LOOPS := ["idle", "walk", "run"]
const SHELLS := 10             # fur layers (each one redraws the body's skin surface)
const FUR_LENGTH := 0.035
const SKIN_SURFACE := "bearSkin"
const TEETH_JAW_DEG := 40.0
const HEAD_DOWN_DEG := 22.0
const HEAD_TURN_MAX := 50.0
const BREATH_DEG := 1.2        # chest rise and fall
const BREATH_RATE := 1.4       # radians a second (a slow animal)

var anim: AnimationPlayer
var skel: Skeleton3D
var body: MeshInstance3D
var pose: SehlatPose


static func make(parent: Node, nm: String, at: Vector3, facing_deg: float) -> Node3D:
	if not ResourceLoader.exists(MODEL):
		return null
	var scene := load(MODEL) as PackedScene
	if scene == null:
		return null
	var s := (load("res://core/creatures/Sehlat.gd") as Script).new() as Node3D
	s.name = nm
	s.position = at
	s.rotation_degrees.y = facing_deg
	parent.add_child(s)
	s.call("_build", scene)
	return s


func _build(scene: PackedScene) -> void:
	var model := scene.instantiate() as Node3D
	model.scale = Vector3.ONE * SCALE
	model.position.z = -BODY_MIDDLE * SCALE      # the given spot is the middle of the lying body, not its tail
	add_child(model)
	anim = _find(model, "AnimationPlayer") as AnimationPlayer
	skel = _find(model, "Skeleton3D") as Skeleton3D
	body = _find(model, "MeshInstance3D") as MeshInstance3D
	if body != null:
		_dress(body)
	if skel != null:
		pose = SehlatPose.new()
		pose.name = "SehlatPose"
		pose.jaw = skel.find_bone("jaw")
		pose.head = skel.find_bone("head")
		pose.neck = skel.find_bone("neck")
		pose.chest = skel.find_bone("chest")
		pose.mesh = body
		pose.owner_node = self
		pose.breath_deg = BREATH_DEG
		pose.breath_rate = BREATH_RATE
		skel.add_child(pose)
	if anim != null:
		for n in anim.get_animation_list():
			var a := anim.get_animation(n)
			if a != null:
				a.loop_mode = Animation.LOOP_LINEAR if LOOPS.has(String(n)) else Animation.LOOP_NONE
		play_clip(START_CLIP, 0.0)
	# solid: a box round the lying body (it never gets up in Episode 1)
	var col := StaticBody3D.new()
	col.name = "Solid"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.7, 1.4, 3.2)
	cs.shape = bs
	cs.position = Vector3(0, 0.7, 0.1)
	col.add_child(cs)
	add_child(col)


func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var f := _find(c, cls)
		if f != null:
			return f
	return null


## Matte skin (Daz's preview material reads as wet plastic without Daz's renderer) + the fur shells.
func _dress(mi: MeshInstance3D) -> void:
	var mesh := mi.mesh
	if mesh == null:
		return
	var shader := load(FUR_SHADER) as Shader
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		var nm := String(m.resource_name) if m != null else ""
		if not (m is StandardMaterial3D):
			continue
		var std := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
		if nm.begins_with(SKIN_SURFACE):
			std.roughness = 0.92
			std.metallic_specular = 0.25
			if shader != null and std.albedo_texture != null:
				var last: Material = std
				for k in SHELLS:
					var sm := ShaderMaterial.new()
					sm.shader = shader
					sm.render_priority = k + 1
					sm.set_shader_parameter("albedo_tex", std.albedo_texture)
					sm.set_shader_parameter("layer", float(k + 1) / float(SHELLS))
					sm.set_shader_parameter("fur_length", FUR_LENGTH)
					last.next_pass = sm
					last = sm
		elif nm.contains("Teeth") or nm.begins_with("fang"):
			std.roughness = 0.35
		elif nm.contains("Claws") or nm.contains("Pads") or nm.contains("Nose"):
			std.roughness = 0.6
		mi.set_surface_override_material(i, std)


func play_clip(clip: String, blend := 0.6) -> void:
	if anim != null and anim.has_animation(clip):
		anim.play(clip, blend)


func show_teeth(hold := 1.4) -> void:
	if pose == null:
		return
	var t := create_tween()
	t.tween_property(pose, "jaw_deg", TEETH_JAW_DEG, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(pose, "snarl", 1.0, 0.3)
	t.parallel().tween_property(pose, "pitch_deg", -8.0, 0.35)
	t.tween_interval(hold)
	t.tween_property(pose, "jaw_deg", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(pose, "snarl", 0.0, 0.6)
	t.parallel().tween_property(pose, "pitch_deg", 0.0, 0.6)


func head_down() -> void:
	if pose == null:
		return
	var t := create_tween()
	t.tween_property(pose, "pitch_deg", HEAD_DOWN_DEG, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(pose, "yaw_deg", 0.0, 1.2)


func look_toward(target: Variant) -> void:
	if pose == null:
		return
	var yaw := 0.0
	if target is Vector3:
		var local := global_transform.affine_inverse() * (target as Vector3)
		yaw = clampf(rad_to_deg(atan2(local.x, local.z)), -HEAD_TURN_MAX, HEAD_TURN_MAX)
	create_tween().tween_property(pose, "yaw_deg", yaw, 0.7).set_trans(Tween.TRANS_SINE)


func settle() -> void:
	play_clip("sleep", 1.6)
	if pose != null:
		var t := create_tween()
		t.tween_property(pose, "pitch_deg", 0.0, 1.6)
		t.parallel().tween_property(pose, "yaw_deg", 0.0, 1.6)


## Runs after the animation every frame: head pitch/turn split over neck and head, the jaw, the snarl shape and a
## slow breath in the chest. Axis-free: everything turns about the creature's own right / up axes.
class SehlatPose extends SkeletonModifier3D:
	var jaw := -1
	var head := -1
	var neck := -1
	var chest := -1
	var mesh: MeshInstance3D
	var owner_node: Node3D
	var jaw_deg := 0.0
	var pitch_deg := 0.0
	var yaw_deg := 0.0
	var snarl := 0.0
	var breath_deg := 1.2
	var breath_rate := 1.4
	var _t := 0.0
	var _snarl_idx := -2
	var _jaw_idx := -2

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null or owner_node == null:
			return
		_t += get_process_delta_time() if is_inside_tree() else 0.0
		var inv := sk.global_transform.basis.orthonormalized().inverse()
		var right := (inv * owner_node.global_transform.basis.x).normalized()
		var up := (inv * owner_node.global_transform.basis.y).normalized()
		if chest >= 0:
			_turn(sk, chest, right, -deg_to_rad(sin(_t * breath_rate) * breath_deg))
		for b in [neck, head]:
			if b >= 0:
				_turn(sk, b, right, deg_to_rad(pitch_deg) * 0.5)
				_turn(sk, b, up, deg_to_rad(yaw_deg) * 0.5)
		if jaw >= 0 and jaw_deg > 0.01:
			_turn(sk, jaw, right, deg_to_rad(jaw_deg))
		if mesh != null and mesh.mesh != null:
			if _snarl_idx == -2:
				_snarl_idx = mesh.find_blend_shape_by_name("snarl")
				_jaw_idx = mesh.find_blend_shape_by_name("jaw_open")
			if _snarl_idx >= 0 and snarl > 0.0:
				mesh.set_blend_shape_value(_snarl_idx, maxf(mesh.get_blend_shape_value(_snarl_idx), snarl))
			if _jaw_idx >= 0 and jaw_deg > 0.01:
				mesh.set_blend_shape_value(_jaw_idx, maxf(mesh.get_blend_shape_value(_jaw_idx), jaw_deg / 60.0))

	func _turn(sk: Skeleton3D, b: int, axis: Vector3, ang: float) -> void:
		if absf(ang) < 0.00001:
			return
		var g := sk.get_bone_global_pose(b)
		g.basis = Basis(axis, ang) * g.basis
		sk.set_bone_global_pose(b, g)
