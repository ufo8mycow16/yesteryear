class_name EarpieceProp
extends RefCounted
## REV 791 (Glen, 2 Nov - UnimatrixRed's "Star Trek TOS Comms Earpiece" kit): Uhura's communications earpiece, worn
## when she sits at her station (EnterpriseBridge._seat_uhura, the teasers' _seat). Model:
## assets/models/props/earpiece_tos/earpiece.glb (tools/props/earpiece/build.sh) - origin = the end of the clear tip
## (what goes in the ear); TIP_AXIS / STACK_DIR are its parts.json "measured" values.
##
## It rides on the head bone (BoneAttachment3D), so it turns with her head. Where her ear is comes from her own eye
## bones (rest pose): behind and to the side of the eyes and a little lower, in eye-spacings - so it fits any head
## size or skeleton units. The tip points into the ear; the finned stack hangs down and back from it.
## All the numbers here are first guesses until Glen sees it - tune EAR_* / STACK_* from his pictures.

const MODEL := "res://assets/models/props/earpiece_tos/earpiece.glb"
const EAR_SIDE := "left"          # her left ear (Glen to confirm)
const EAR_BACK := 1.30            # eye-spacings behind the eyes
const EAR_OUT := 1.12             # ... out to the side
const EAR_DOWN := 0.42            # ... below them
const TIP_IN := 0.06              # ... how far the tip's end sits inside the ear
const STACK_DOWN := 0.85          # the stack's lean: mostly down ...
const STACK_BACK := 0.45          # ... and somewhat back
const TIP_AXIS := Vector3(0.0, 0.81915, 0.57358)   # model space, joint -> tip end
const STACK_DIR := Vector3(0.0, -1.0, 0.0)         # model space, joint -> down the discs
const EYE_SPACING_M := 0.063      # an adult's eye spacing - the model is real size in metres
const NODE_NAME := "Earpiece"

static var _scene: PackedScene = null


## Puts the earpiece on `fig` (once). False when the model or the bones aren't there.
static func attach(fig: Node3D) -> bool:
	if fig == null or not ResourceLoader.exists(MODEL):
		return false
	if not fig.find_children(NODE_NAME, "Node3D", true, false).is_empty():
		return true
	var skel: Skeleton3D = null
	for s in fig.find_children("*", "Skeleton3D", true, false):
		skel = s as Skeleton3D
		break
	if skel == null:
		return false
	var head := -1
	var le := -1
	var re := -1
	for i in skel.get_bone_count():
		var bn := skel.get_bone_name(i).to_lower()
		if head < 0 and bn.begins_with("head") and not bn.contains("top") and not bn.contains("end"):
			head = i
		elif le < 0 and (bn == "leye" or bn == "l_eye" or bn.begins_with("leye")):
			le = i
		elif re < 0 and (bn == "reye" or bn == "r_eye" or bn.begins_with("reye")):
			re = i
	if head < 0 or le < 0 or re < 0:
		return false
	if _scene == null:
		_scene = load(MODEL)
		if _scene == null:
			return false
	var pl := skel.get_bone_global_rest(le).origin
	var pr := skel.get_bone_global_rest(re).origin
	var e := pl.distance_to(pr)
	if e < 0.0001:
		return false
	var left := (pl - pr) / e
	var up := Vector3.UP
	left = (left - up * left.dot(up)).normalized()
	var fwd := left.cross(up).normalized()
	var side := left if EAR_SIDE == "left" else -left
	var mid := (pl + pr) * 0.5
	var ear := mid - fwd * EAR_BACK * e + side * EAR_OUT * e - up * EAR_DOWN * e
	# model frame (tip axis, stack) -> skeleton frame (into the head, down-and-back)
	var a1 := TIP_AXIS.normalized()
	var a2 := (STACK_DIR - a1 * STACK_DIR.dot(a1)).normalized()
	var b1 := -side
	var want := -up * STACK_DOWN - fwd * STACK_BACK
	var b2 := (want - b1 * want.dot(b1)).normalized()
	var A := Basis(a1, a2, a1.cross(a2))
	var B := Basis(b1, b2, b1.cross(b2))
	var k := e / EYE_SPACING_M
	var xf := Transform3D((B * A.inverse()).scaled(Vector3.ONE * k), ear + b1 * TIP_IN * e)
	var att := BoneAttachment3D.new()
	att.name = NODE_NAME
	skel.add_child(att)
	att.bone_idx = head
	var model := _scene.instantiate() as Node3D
	att.add_child(model)
	model.transform = skel.get_bone_global_rest(head).affine_inverse() * xf
	return true
