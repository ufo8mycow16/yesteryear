extends Node3D
## REV 880: the LE-MATYA - Daz Big Cat 2's Sabertooth (Glen's pack), built straight from the Daz files by
## tools/creatures/daz_figure_to_gltf.py (recipe tools/creatures/lematya_recipe.json) and coloured after Glen's own
## green/yellow repaint (tools/creatures/lematya_recolour.py). Page: docs/systems/lematya.md.
##
##   var lm = LeMatya.make(parent, "LeMatya", position, facing_degrees)   # null if the model isn't there
##   lm.call("play_clip", "stalk")   # wary stalk pounce lunge circle sit sleep stretch trot fight gallop
##   lm.call("snarl")  / lm.call("roar")  / lm.call("yawn")
##   lm.call("look_toward", world_position)   (null = straight ahead again)
##   lm.call("fall_asleep")   # sits, yawns, curls up, eyes shut
##
## Head turns, breathing, a twitching tail and the odd blink run on a skeleton modifier over whatever clip plays.
## Head along the node's +Z, feet on its origin, the middle of the body over the origin.

const MODEL := "res://assets/models/creatures/lematya/lematya_bigcat.gltf"
const FUR_SHADER := "res://core/creatures/sehlat_fur.gdshader"
const SCALE := 1.2            # the Daz cat is 2.2 m nose to tail; a le-matya is a bit bigger (2.65 m, ~1 m at the shoulder)
const START_CLIP := "wary"     # crouched, head low, over her kill
const LOOPS := ["trot", "gallop"]
const SHELLS := 8
const FUR_LENGTH := 0.014      # short big-cat coat
const FUR_SURFACES := ["SkinBody", "SkinFace"]
const HEAD_TURN_MAX := 55.0
const BREATH_DEG := 1.0
const BREATH_RATE := 2.2      # faster than the sehlat: she's wound up
const TAIL_SWAY_DEG := 7.0    # the tip of an angry cat's tail never stops

var anim: AnimationPlayer
var skel: Skeleton3D
var body: MeshInstance3D
var pose: LeMatyaPose
var asleep := false


static func make(parent: Node, nm: String, at: Vector3, facing_deg: float) -> Node3D:
	if not ResourceLoader.exists(MODEL):
		return null
	var scene := load(MODEL) as PackedScene
	if scene == null:
		return null
	var s := (load("res://core/creatures/LeMatya.gd") as Script).new() as Node3D
	s.name = nm
	s.position = at
	s.rotation_degrees.y = facing_deg
	parent.add_child(s)
	s.call("_build", scene)
	return s


func _build(scene: PackedScene) -> void:
	var model := scene.instantiate() as Node3D
	model.scale = Vector3.ONE * SCALE
	add_child(model)
	anim = _find(model, "AnimationPlayer") as AnimationPlayer
	skel = _find(model, "Skeleton3D") as Skeleton3D
	body = _find(model, "MeshInstance3D") as MeshInstance3D
	if body != null:
		_dress(body)
	if skel != null:
		pose = LeMatyaPose.new()
		pose.name = "LeMatyaPose"
		pose.mesh = body
		pose.owner_node = self
		pose.breath_deg = BREATH_DEG
		pose.breath_rate = BREATH_RATE
		pose.tail_deg = TAIL_SWAY_DEG
		for b in ["Neck1", "Neck2", "head"]:
			var i := skel.find_bone(b)
			if i >= 0:
				pose.neck_bones.append(i)
		pose.chest = skel.find_bone("chest")
		for k in range(4, 13):
			var i := skel.find_bone("Tail%d" % k)
			if i >= 0:
				pose.tail_bones.append(i)
		skel.add_child(pose)
	if anim != null:
		for n in anim.get_animation_list():
			var a := anim.get_animation(n)
			if a != null:
				a.loop_mode = Animation.LOOP_LINEAR if LOOPS.has(String(n)) else Animation.LOOP_NONE
		play_clip(START_CLIP, 0.0)


func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var f := _find(c, cls)
		if f != null:
			return f
	return null


## Matte coat + short shell fur on the body and face; the cornea stays clear, the teeth a little glossy.
func _dress(mi: MeshInstance3D) -> void:
	var mesh := mi.mesh
	if mesh == null:
		return
	var shader := load(FUR_SHADER) as Shader
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if not (m is StandardMaterial3D):
			continue
		var nm := String(m.resource_name)
		var std := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
		if FUR_SURFACES.has(nm):
			std.roughness = 0.9
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
					sm.set_shader_parameter("density", 520.0)
					sm.set_shader_parameter("droop", 0.15)
					last.next_pass = sm
					last = sm
		elif nm == "Teeth":
			std.roughness = 0.3
		elif nm == "Whiskers":
			std.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.set_surface_override_material(i, std)


func play_clip(clip: String, blend := 0.5) -> void:
	if anim != null and anim.has_animation(clip):
		anim.play(clip, blend)


## Lips back over the fangs, ears flat, head up a touch - then back.
func snarl(hold := 1.2) -> void:
	_face({"snarl": 1.0, "ears_back": 1.0}, -6.0, 0.25, hold)


## Mouth wide open round the sabre teeth.
func roar(hold := 1.0) -> void:
	_face({"roar": 1.0, "ears_back": 0.7}, -14.0, 0.3, hold)


func yawn() -> void:
	_face({"open": 1.0}, -10.0, 0.9, 0.8)


func _face(shapes: Dictionary, pitch: float, rise: float, hold: float) -> void:
	if pose == null:
		return
	var t := create_tween()
	t.set_parallel(true)
	for k in shapes:
		t.tween_method(pose.set_shape.bind(String(k)), 0.0, float(shapes[k]), rise)
	t.tween_property(pose, "pitch_deg", pitch, rise)
	t.chain().tween_interval(hold)
	t.chain()
	for k in shapes:
		t.tween_method(pose.set_shape.bind(String(k)), float(shapes[k]), 0.0, 0.5)
	t.tween_property(pose, "pitch_deg", 0.0, 0.5)


func look_toward(target: Variant) -> void:
	if pose == null:
		return
	var yaw := 0.0
	if target is Vector3:
		var local := global_transform.affine_inverse() * (target as Vector3)
		yaw = clampf(rad_to_deg(atan2(local.x, local.z)), -HEAD_TURN_MAX, HEAD_TURN_MAX)
	create_tween().tween_property(pose, "yaw_deg", yaw, 0.6).set_trans(Tween.TRANS_SINE)


## The sedative: sits, yawns, curls up and shuts her eyes (awaitable - about 3.5 s).
func fall_asleep() -> void:
	look_toward(null)
	play_clip("sit", 0.9)
	await get_tree().create_timer(1.0).timeout
	yawn()
	await get_tree().create_timer(1.6).timeout
	sleep_now(1.4)
	await get_tree().create_timer(1.0).timeout


## Straight into the sleeping pose (a reload after the sedative): eyes shut, slow breath, tail still.
func sleep_now(blend := 0.0) -> void:
	asleep = true
	play_clip("sleep", blend)
	if pose != null:
		pose.asleep = true
		pose.breath_rate = 0.9
		pose.tail_deg = 0.0
		pose.yaw_deg = 0.0
		pose.pitch_deg = 0.0


## Runs after the animation every frame: head turn/pitch spread over the neck, a breath in the chest, the tail tip
## twitching, blinks - and the mouth/ear shapes the moves above set.
class LeMatyaPose extends SkeletonModifier3D:
	var neck_bones: Array[int] = []
	var tail_bones: Array[int] = []
	var chest := -1
	var mesh: MeshInstance3D
	var owner_node: Node3D
	var pitch_deg := 0.0
	var yaw_deg := 0.0
	var breath_deg := 1.0
	var breath_rate := 2.2
	var tail_deg := 7.0
	var asleep := false
	var shapes := {}
	var _t := 0.0
	var _blink_at := 3.0
	var _idx := {}

	func set_shape(v: float, key: String) -> void:
		shapes[key] = v

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null or owner_node == null:
			return
		var dt := get_process_delta_time() if is_inside_tree() else 0.0
		_t += dt
		var inv := sk.global_transform.basis.orthonormalized().inverse()
		var right := (inv * owner_node.global_transform.basis.x).normalized()
		var up := (inv * owner_node.global_transform.basis.y).normalized()
		if chest >= 0:
			_turn(sk, chest, right, -deg_to_rad(sin(_t * breath_rate) * breath_deg))
		var n := float(maxi(neck_bones.size(), 1))
		for b in neck_bones:
			_turn(sk, b, right, deg_to_rad(pitch_deg) / n)
			_turn(sk, b, up, deg_to_rad(yaw_deg) / n)
		if tail_deg > 0.0:
			var k := 0
			for b in tail_bones:
				k += 1
				_turn(sk, b, up, deg_to_rad(sin(_t * 1.7 - k * 0.45) * tail_deg * (0.4 + 0.6 * k / float(tail_bones.size()))) * 0.35)
		if mesh == null or mesh.mesh == null:
			return
		# blinks every few seconds while awake; shut while asleep
		var blink := 1.0 if asleep else 0.0
		if not asleep:
			if _t >= _blink_at + 0.16:
				_blink_at = _t + randf_range(2.5, 6.0)
			var p := (_t - _blink_at) / 0.16
			blink = sin(p * PI) if p >= 0.0 and p <= 1.0 else 0.0
		_shape(mesh, "blink", blink)
		for k in ["snarl", "roar", "open", "ears_back"]:
			_shape(mesh, k, float(shapes.get(k, 0.0)))

	func _shape(mi: MeshInstance3D, key: String, v: float) -> void:
		if not _idx.has(key):
			_idx[key] = mi.find_blend_shape_by_name(key)
		var i: int = _idx[key]
		if i >= 0:
			mi.set_blend_shape_value(i, v)

	func _turn(sk: Skeleton3D, b: int, axis: Vector3, ang: float) -> void:
		if b < 0 or absf(ang) < 0.00001:
			return
		var g := sk.get_bone_global_pose(b)
		g.basis = Basis(axis, ang) * g.basis
		sk.set_bone_global_pose(b, g)
