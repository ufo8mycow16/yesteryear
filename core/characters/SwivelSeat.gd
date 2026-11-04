class_name SwivelSeat
extends RefCounted
## REV 366 (Glen: "are we able to make chairs spin with people sitting on them? at the moment Chekov just
## spins... and eats a mouthful of chair" - all chairs, not just the helm; "and he's still doing his typing
## animation while turning too").
##
## A seated person can be linked to the chair they sit in (attach). When a conversation turns them to face
## someone (ConversationPresenter._turn_figure_toward), the person AND the chair turn together about the
## chair's own upright axis, as a swivel chair does, instead of the person spinning inside a chair that
## stays put. While they face away from their console they stop typing (the console work is put down);
## when the conversation ends they swivel back and go back to it.
##
## The chair's pieces are the map's own meshes (they are moved as they are; nothing is copied). The rest
## position of the person and the chair is taken fresh each time a swivel starts from rest, so a chair
## moved in the F4 prop editor, or a person re-seated, never jumps back somewhere old.

const META := "swivel_seat"
## REV 631: a seated console worker's typing strength (set by EnterpriseBridge._seat_worker) - they go back to it
## after a swivel even if a line took their arms first
const CONSOLE_META := "console_typing"
const MAX_FROM_AXIS := 0.6        # metres - farther than this from the chair's axis: not in it any more
const TYPING_OFF := 15.0          # degrees turned away before the console work is put down (REV 631: was 30 - exactly
                                  # the most a seated person turns in a story scene, so a turn just short of it kept them
                                  # typing while they talked to you - Glen's picture)


## Links `fig` (the seated model - the node the conversation turns) to the chair whose pieces are `meshes`.
## The chair turns about the middle of those pieces (or `axis` when given).
static func attach(fig: Node3D, meshes: Array, axis := Vector3.INF) -> void:
	if fig == null or meshes.is_empty():
		return
	var pieces: Array = []
	var sum := Vector3.ZERO
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		pieces.append(mi)
		sum += (mi.global_transform * mi.get_aabb()).get_center()
	if pieces.is_empty():
		return
	var at: Vector3 = axis if axis != Vector3.INF else sum / pieces.size()
	fig.set_meta(META, {
		"axis": at, "meshes": pieces, "angle": 0.0,
		"fig_rest": Transform3D(), "mesh_rest": [], "typing": -1.0,
	})


## The chair pieces of the map under `root` whose names contain `tag`, within `radius` (flat) of `centre`.
static func chair_meshes(root: Node, centre: Vector3, tag: String, radius := 0.4) -> Array:
	var out: Array = []
	if root == null or centre == Vector3.INF:
		return out
	var t := tag.to_lower()
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or mi.skin != null or not String(mi.name).to_lower().contains(t):
			continue
		var c := (mi.global_transform * mi.get_aabb()).get_center()
		if Vector2(c.x - centre.x, c.z - centre.z).length() <= radius:
			out.append(mi)
	return out


## True when `fig` is sitting in a linked chair right now (still seated, still in it).
static func active(fig: Node3D) -> bool:
	if fig == null or not is_instance_valid(fig) or not fig.has_meta(META):
		return false
	var d: Dictionary = fig.get_meta(META)
	var an := CharacterKit.animator_of(fig)
	if an == null or an.motion == null or String(an.motion.posture) != "sit":
		return false
	var axis: Vector3 = d["axis"]
	var p := fig.global_position
	if absf(float(d["angle"])) < 0.0001:
		return Vector2(p.x - axis.x, p.z - axis.z).length() <= MAX_FROM_AXIS
	return true


## How far the chair is turned from where it rests (radians).
static func angle(fig: Node3D) -> float:
	if fig == null or not fig.has_meta(META):
		return 0.0
	return float((fig.get_meta(META) as Dictionary)["angle"])


## Turns the person and their chair to `a` radians from rest (0 = back at the console).
static func set_angle(fig: Node3D, a: float) -> void:
	if fig == null or not is_instance_valid(fig) or not fig.has_meta(META):
		return
	var d: Dictionary = fig.get_meta(META)
	var was := float(d["angle"])
	if absf(was) < 0.0001 and absf(a) >= 0.0001:
		# starting from rest: take the rest positions as they are now
		d["fig_rest"] = fig.global_transform
		var rests: Array = []
		for mi in d["meshes"]:
			rests.append((mi as Node3D).global_transform if is_instance_valid(mi) else Transform3D())
		d["mesh_rest"] = rests
	if (d["mesh_rest"] as Array).is_empty():
		return
	var axis: Vector3 = d["axis"]
	var turn := Transform3D(Basis(Vector3.UP, a), Vector3.ZERO)
	var about := Transform3D(Basis(), axis) * turn * Transform3D(Basis(), -axis)
	fig.global_transform = about * (d["fig_rest"] as Transform3D)
	var meshes: Array = d["meshes"]
	var rests2: Array = d["mesh_rest"]
	for i in meshes.size():
		if is_instance_valid(meshes[i]) and i < rests2.size():
			(meshes[i] as Node3D).global_transform = about * (rests2[i] as Transform3D)
	d["angle"] = a
	_typing_for(fig, d, a)


## Put the console work down when turned well away from it; pick it up again back at rest.
static func _typing_for(fig: Node3D, d: Dictionary, a: float) -> void:
	var an := CharacterKit.animator_of(fig)
	if an == null or an.motion == null:
		return
	var m = an.motion
	var away := absf(a) >= deg_to_rad(TYPING_OFF)
	# REV 634 (Glen: the REV 631 fix "didn't work either" - Uhura's hands still up in the air facing Scotty): the arms
	# weren't the typing loop at all but the console worker's DESK HOLD (CharacterMotion._seat_drop with
	# seat_drop_hands false keeps both hands at least on the console top, hand_floor). Turned away from the console,
	# that hold is let go so the hands drop to the lap; back at rest it is put back exactly as it was.
	if away and not d.has("desk_hold"):
		d["desk_hold"] = [m.seat_drop_hands, m.hand_floor]
		m.seat_drop_hands = true
		m.hand_floor = INF
	elif absf(a) < 0.0001 and d.has("desk_hold"):
		var hold: Array = d["desk_hold"]
		m.seat_drop_hands = hold[0]
		m.hand_floor = hold[1]
		d.erase("desk_hold")
	if away and float(d["typing"]) < 0.0:
		var tl = m.talk_layer
		# REV 631 (Glen: "when a crew member spins around on the chair to talk to you, their hands stay in the typing
		# position"): a line starts the seated talking gestures BEFORE the chair turns, so by now the arms are on
		# talk_seated, not typing - and they were left there, low over the lap like typing in the air. A console
		# worker (CONSOLE_META, set by whoever seated them) puts the arms down whatever they were doing.
		var worker := fig.has_meta(CONSOLE_META)
		if tl != null and float(tl.fade) > 0.0 and (String(tl.id) == "typing" or (worker and String(tl.id) == "talk_seated")):
			d["typing"] = float(tl.strength) if String(tl.id) == "typing" else float(fig.get_meta(CONSOLE_META))
			an.stop_talk()
		elif worker:
			d["typing"] = float(fig.get_meta(CONSOLE_META))
	elif absf(a) < 0.0001 and float(d["typing"]) >= 0.0:
		var s := float(d["typing"])
		d["typing"] = -1.0
		var tl2 = m.talk_layer
		# only if nothing else took over the arms meanwhile (a talking loop still playing)
		if tl2 == null or float(tl2.fade_to) <= 0.0 or String(tl2.id) == "typing" or String(tl2.id) == "talk_seated":
			an.hold_loop("typing", s)
