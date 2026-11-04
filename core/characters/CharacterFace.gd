extends Node
class_name CharacterFace
## CharacterFace (REV 97): eyes, head and neck look-at, blinking, lip sync and expressions for one
## character. It is the character-side half of the dialogue camera: a dialogue system only has to say
## "look at X", "say this line with these mouth cues", "be worried", and ask "where are your eyes?" to
## frame a shot. Written for McCoy (Genesis 8) but nothing in it is McCoy-specific; the bone and
## blend-shape names come from a CharacterFaceProfile.
##
## UNTESTED IN GODOT when written (no Godot available to the author). The maths was checked by hand.
##
##   var mccoy := CharacterFace.make_model("res://assets/models/characters/McCoy_daz.fbx", null, "mccoy")   # REV 293
##   add_child(mccoy)
##   var face := CharacterFace.face_of(mccoy)
##   face.look_at_node(kirk_face.focus_node())   # McCoy looks at Kirk's eyes and keeps following
##   face.set_emotion("worried")
##   face.play_lipsync(CharacterFace.load_rhubarb("res://.../mccoy_0042.json"), $Voice)
##
## It owns the neck, head and eye bones (and nothing else): CharacterAnimator moves the body and
## must not be given a "head" role for the same rig. It runs after the animator (process_priority).
## Angles: yaw is turning left/right, pitch is up (+) / down (-), both in the character's own space,
## where the character faces +Z.

signal blinked

@export var profile: CharacterFaceProfile
## Turn the automatic parts on and off (a cutscene may want full manual control).
@export var auto_blink := true
@export var micro_saccades := true
@export var lid_follows_gaze := true
## How fast things move toward where they're going (bigger = snappier).
@export var eye_speed := 22.0
@export var head_speed := 5.0
@export var shape_speed := 10.0
# REV 293: viseme_speed went with the old Daz-viseme layer (see _update_shapes)

var ready_to_use := false
var _wrapper: Node3D
var _skel: Skeleton3D
var _to_model: Basis                 # skeleton space -> character space
var _up_s := Vector3.UP              # character up / right, in skeleton space
var _right_s := Vector3.RIGHT
var _b := {}                         # "head", "eye_l", "eye_r", "jaw", "chest" -> bone index
var _neck: Array[int] = []
var _rest_q := {}                    # bone index -> local rotation when set up
var _shapes := {}                    # shape name -> Array of [MeshInstance3D, index]

# looking
var _look_node: Node3D = null
var _look_point := Vector3.ZERO
var _looking := false
var _head_yaw := 0.0                 # current (smoothed) head+neck turn, degrees
var _head_pitch := 0.0
var _eye_l := Vector2.ZERO          # current eye (yaw, pitch), relative to the head
var _eye_r := Vector2.ZERO
var _saccade := Vector2.ZERO
var _saccade_t := 0.0
var _head_override := Vector2(INF, INF)   # an explicit head pose (yaw, pitch) instead of following

# blinking
var _blink_t := 0.0                  # time left until the next automatic blink
var _blink_phase := -1.0             # -1 = not blinking, else 0..1 through the blink
const BLINK_LENGTH := 0.16
var _last_want := Vector2.ZERO

# blend-shape layers: shape -> weight
var _emotion_target := {}
var _emotion_now := {}
var _manual_target := {}
var _manual_now := {}
# REV 293: the old viseme layer (_viseme_now) is gone - empty since REV 142, when talking moved to the mouth bones
var _cues: Array = []                # Rhubarb mouth cues: [{start, end, value}]
var _cue_clock := -1.0
var _cue_player: Node = null
var _talk_bus := -1
var _jaw_level := 0.0
## REV 142: talking moves the face's own mouth bones. Daz's mouth shapes can't be used: in the export
## they only carry their corrective part (in Daz they also drive these bones), so alone they bare the
## teeth. REV 196 (Glen: better mouths, ready for Rhubarb): eight controls instead of five, moving more of
## Genesis 8's face bones - the skin above the upper lip, the creases beside the mouth, the cheeks and
## the tongue. Each Rhubarb mouth letter -> how much of each control, 0-1:
##   [open (jaw), round (lips pushed out, corners in), spread (corners out), press (lips together),
##    tuck (F/V: lower lip under the top teeth), upper (upper lip lifts off the teeth),
##    lower (lower lip drops off the teeth), tongue (tip up to the ridge behind the teeth)]
const MOUTH_POSES := {
	"X": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	"A": [0.0, 0.0, 0.05, 1.0, 0.0, 0.0, 0.0, 0.0],      # M B P - lips pressed
	"B": [0.12, 0.0, 0.3, 0.0, 0.0, 0.3, 0.25, 0.35],    # K S T, most consonants - teeth nearly together
	"C": [0.42, 0.0, 0.3, 0.0, 0.0, 0.05, 0.1, 0.0],    # EH AE - open, a little wide
	"D": [0.9, 0.15, 0.05, 0.0, 0.0, 0.05, 0.1, 0.0],    # AA - wide open
	"E": [0.3, 0.85, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],      # AO ER - rounded
	"F": [0.08, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],     # UW OW W - puckered
	"G": [0.1, 0.0, 0.1, 0.0, 1.0, 0.35, 0.0, 0.0],      # F V - lower lip under the top teeth
	"H": [0.38, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0],    # L - tongue up
}
const MOUTH_CONTROLS := 8
## How fast each control moves (bigger = snappier); closing the lips (press) is the quickest.
const MOUTH_SPEEDS := [20.0, 15.0, 17.0, 34.0, 26.0, 22.0, 22.0, 24.0]
## Rhubarb cues are looked up this far ahead: the mouth starts making a sound just before it is heard.
const CUE_LEAD := 0.035
const JAW_MAX_DEG := 10.0
var _jaw_deg := 0.0
var _mouth_now := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

## REV 735 (Glen: no puckers, no proper lip presses): the mouth now plays DAZ'S OWN viseme recipes -
## the bone moves each eCTRLv dial makes in Daz (read from Glen's library, Base Pose Head/eCTRLv*.dsf,
## by tools/crew/daz_visemes.py; same numbers for G8 Male and Female) - plus the exported eCTRLv
## shape on top (in the FBX it only carries the leftover corrective part, which is why it bared the
## teeth alone; with the bones it completes Daz's shape). The 8 mouth controls still decide what the
## mouth is doing; each frame they're read as a blend of the Rhubarb letters, and each letter is a
## mix of Daz visemes. Figures without Daz lip bones keep the REV 196 hand-made mouth.
## REV 738: OFF again (Glen: "those mouth shapes now look absolutely terrible" - Spock grimacing with bared
## teeth, McCoy's "oo" a tiny pushed-out hole). Back to the REV 196 hand mouth until the recipe mouth is
## checked in renders.
@export var daz_mouth := true
## REV 739 (Glen: his Daz export rules export every viseme dial in full - the shapes ALREADY hold the whole
## lip and jaw movement; adding the recipe bones on top played every mouth twice). So: the exported
## viseme shapes alone (`daz_mouth_shapes`), no recipe bones (`daz_mouth_bones`, kept for figures exported
## without viseme shapes - off by default), jaw left to the shapes. A figure with neither gets the hand mouth.
@export var daz_mouth_bones := false
@export var daz_mouth_shapes := true
## REV 739: how far the jaw opens ON TOP of the shapes (x Daz's own amount per viseme) and how strongly the
## shapes play. Chosen from test renders of McCoy (0 = lips round clenched teeth; 1.0+ = gaping, every lower
## tooth showing): 0.35. Only used with the recipe bones off.
@export var daz_jaw_gain := 1.3     # REV 853 (Glen: open the jaw more): was 0.35 - teeth nearly shut all line long
@export var daz_shape_strength := 1.0
## REV 853 (Glen: open the jaw more, soften the lip stretch, send each sound straight to Daz's own visemes).
## With a Rhubarb file, each mouth letter now goes STRAIGHT to its Daz viseme mix (LETTER_VISEMES) and each
## viseme eases on its own (VISEME_SPEEDS) - no round trip through the 8 mouth controls, which blurred every
## shape into its neighbours (an "M" only reached ~half a lip press). Listening/miming have no letters, so
## they still go through the controls. false = the REV 739 route (kept for comparing).
@export var daz_direct_visemes := true
## REV 853: how much the lips cover the teeth as the jaw opens (Daz-shape mouths; see _mouth_update).
@export var daz_lip_cover := 1.9
## REV 853: how strongly each Daz viseme plays. In the export the open shapes peel the lips back off the teeth
## (a grimace - both rows of teeth showing), so they're played softer and the jaw does more of the opening; the
## lip closures (M B P, F V) and the rounding (OO, W) stay at full strength. Picked from test stills of McCoy.
const VISEME_GAIN := {"vS": 0.55, "vK": 0.6, "vEH": 0.6, "vAA": 0.75, "vOW": 0.8, "vL": 0.75}
## REV 853: how fast each viseme comes and goes (bigger = snappier). Lip closures (M B P, F V) are quickest.
const VISEME_SPEEDS := {"vM": 34.0, "vF": 28.0, "vUW": 16.0, "vOW": 16.0, "vW": 16.0}
const VISEME_SPEED_DEFAULT := 20.0
## REV 853: Genesis 9's own viseme shapes already keep the lips over the teeth and open further, so its jaw
## opens a little less than Genesis 8's (Kovek's "oh" gaped at the full amount).
const G9_JAW_SCALE := 0.75
var _genesis9 := false
var _vis_target := {}         # REV 853: Daz viseme -> where it's heading (direct route)
var _vis_now := {}            # REV 853: Daz viseme -> eased weight now (direct route)
var _direct_frame := false    # REV 853: this frame's visemes came straight from a Rhubarb letter
const VISEME_FILE := "res://core/characters/daz_visemes.json"
const LETTER_VISEMES := {
	"X": {},
	"A": {"vM": 1.0},                      # M B P - lips pressed
	"B": {"vS": 0.65, "vK": 0.35},         # K S T and most consonants - teeth nearly together
	"C": {"vEH": 1.0},                     # EH AE
	"D": {"vAA": 1.0},                     # AA
	"E": {"vOW": 1.0},                     # AO ER - rounded
	"F": {"vUW": 0.85, "vW": 0.35},        # UW OW W - puckered (a touch past Daz's full "oo" on purpose)
	"G": {"vF": 1.0},                      # F V
	"H": {"vL": 1.0},                      # L
}
## How sharply the mouth controls are read as letters (smaller = cleaner shapes, larger = more blending).
const LETTER_SPREAD := 0.12
## Daz's visemes open the jaw only a little (AA is under 5 degrees) - real speech opens more.
const DAZ_JAW_GAIN := 1.6
static var _vis_bones := {}      # viseme -> {bone name: [tx, ty, tz, rx, ry, rz]} (cm, degrees, Daz axes)
static var _vis_jaw := {}        # viseme -> lowerJaw rotation x (degrees, + opens)
static var _vis_loaded := false
var _use_recipes := false
var _use_shapes := false         # REV 739: the export's own viseme shapes drive the mouth
var _shape_prefix := ""          # "eCTRL" (Genesis 8) or "facs_ctrl_" (Genesis 8.1)
var _viseme_w := {}              # Daz viseme -> weight this frame (also drives the eCTRLv shapes)
var _syll_t := 0.0          # REV 140: time left on the current made-up mouth shape (no Rhubarb file yet)
var _syll_shape := ""
var _anim_look := Vector2.ZERO   # REV 140: which way the body animation itself points the head (smoothed)
var _applied := {}                   # shape -> last value written (to skip unchanged writes)


# ---- making a character ----------------------------------------------------------------

## Load a rigged character model, give it a walking animator and a face, and return the wrapper
## (feet at y = 0, facing +Z), ready to place like a CharacterKit figure. null if it won't load.
const DAZ_FIXES_NEEDED := 240
const DAZ_FIXES_NEEDED_G9 := 849

static func make_model(path: String, face_profile: CharacterFaceProfile = null, character_id: String = "") -> Node3D:
	var packed: PackedScene = load(path) if ResourceLoader.exists(path) else null
	var inst: Node3D = packed.instantiate() as Node3D if packed != null else null
	if inst == null:
		push_warning("CharacterFace: couldn't load %s" % path)
		return null
	# REV 131: a Daz model imported before the latest import fixes (skin showing through clothes, speckled
	# hair) - Godot only reimports when the model or its import settings change, not the fix script
	var needed := DAZ_FIXES_NEEDED
	if path.ends_with(".fbx") and not inst.find_children("Genesis9*", "MeshInstance3D", true, false).is_empty():
		needed = DAZ_FIXES_NEEDED_G9   # REV 842: Genesis 9 figures need the import with their joint corrections
	if path.ends_with(".fbx") and int(inst.get_meta("daz_fixes", 0)) < needed:
		push_warning("%s was imported before the latest Daz fixes. In Godot's FileSystem panel select it, open the Import tab and press Reimport (or delete the .godot/imported folder)." % path.get_file())
	CharacterDetail.apply(inst, path.get_file().get_basename())   # REV 221: skin detail from the Daz library
	var wrapper := Node3D.new()
	wrapper.name = "Character"
	wrapper.add_child(inst)
	var animator := CharacterAnimator.new()
	animator.name = "Animator"
	wrapper.add_child(animator)
	animator.setup(wrapper, inst)
	attach(wrapper, inst, face_profile, character_id)
	return wrapper


## Add a face to an existing figure. profile: given > stored in the model > Genesis 8 default.
static func attach(wrapper: Node3D, model_root: Node, face_profile: CharacterFaceProfile = null, character_id: String = "") -> CharacterFace:
	var face := CharacterFace.new()
	face.name = "Face"
	face.add_to_group("vf_faces")      # REV 736: FaceLight finds the faces near the camera by this
	wrapper.add_child(face)
	var p := face_profile
	if p == null:
		p = CharacterFaceProfile.from_model(model_root)
	if p == null:
		p = CharacterFaceProfile.genesis8()
	if p.character_id == "" and character_id != "":
		p.character_id = character_id    # REV 144: so per-character corrections can find their character
	face.setup(wrapper, model_root, p)
	if model_root is Node3D:
		JointCorrectives.attach_to(wrapper, model_root as Node3D)   # REV 240 (Daz figures only)
	return face


## The face inside a figure, or null.
static func face_of(figure: Node) -> CharacterFace:
	if figure == null:
		return null
	return figure.find_child("Face", true, false) as CharacterFace


func setup(wrapper: Node3D, model_root: Node, p: CharacterFaceProfile) -> void:
	_wrapper = wrapper
	profile = p
	process_priority = 10      # after CharacterAnimator
	var skels := model_root.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		push_warning("CharacterFace: no skeleton in %s" % model_root.name)
		return
	_skel = skels[0] as Skeleton3D
	var by_name := {}
	for i in _skel.get_bone_count():
		by_name[_skel.get_bone_name(i).to_lower()] = i
	var find := func(nm: String) -> int: return int(by_name.get(nm.to_lower(), -1))
	_genesis9 = by_name.has("l_eye") and by_name.has("neck1")      # REV 853
	# REV 751: a Genesis 9 skeleton (l_eye, neck1 ...) with no profile of its own gets G9's (before the bones are looked up)
	if by_name.has("l_eye") and by_name.has("neck1") and not by_name.has(p.bone_eye_left.to_lower()):
		p = CharacterFaceProfile.daz_genesis9(p.character_id)
		profile = p
	_b = {"head": find.call(p.bone_head), "eye_l": find.call(p.bone_eye_left), "eye_r": find.call(p.bone_eye_right),
		"jaw": find.call(p.bone_jaw), "chest": find.call(p.bone_chest)}
	_neck.clear()
	for nm in p.bones_neck:
		var b: int = find.call(nm)
		if b >= 0:
			_neck.append(b)
	for key in _b.keys():
		if int(_b[key]) < 0:
			push_warning("CharacterFace: bone for '%s' not found (%s)" % [key, p.character_id])
	for b in _controlled():
		_rest_q[b] = _skel.get_bone_pose_rotation(b)

	# skeleton space -> character space (same way CharacterAnimator does it)
	var xf := Transform3D.IDENTITY
	var n: Node = _skel
	while n != null and n != wrapper:
		var n3 := n as Node3D
		if n3 != null:
			xf = n3.transform * xf
		n = n.get_parent()
	_to_model = xf.basis
	var inv := _to_model.orthonormalized().inverse()
	_up_s = (inv * Vector3.UP).normalized()
	_right_s = (inv * Vector3.RIGHT).normalized()

	# blend shapes, on every mesh that has them (body, and eyelashes/brows if they're separate)
	_shapes.clear()
	for m in model_root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for k in mi.get_blend_shape_count():
			var nm := _shape_name(mi, k)
			if not _shapes.has(nm):
				_shapes[nm] = []
			(_shapes[nm] as Array).append([mi, k])
	# REV 124: a Daz export (eCTRL... controls) with the old McCoy names in its profile: use Daz's
	if not _shapes.has(profile.blink_left) and _shapes.has("eCTRLEyesClosedL"):
		var id := profile.character_id
		profile = CharacterFaceProfile.daz_genesis8(id)
	# REV 577: Genesis 8.1 (Tuvall) - expressions under the FACS names
	if _shapes.has("facs_ctrl_SmileFullFace") and not _shapes.has("eCTRLSmileFullFace_HD"):
		profile = CharacterFaceProfile.daz_genesis81(profile.character_id)
	profile.apply_character_corrections()
	_measure_eye_rest(model_root)
	_blink_t = randf_range(1.0, 4.0)
	ready_to_use = int(_b["head"]) >= 0
	_darken_mouth(model_root)
	set_process(true)


# ---- REV 197: which way each eye points at rest --------------------------------------------------

## REV 197: (yaw, pitch) in degrees to take off each eye, from the way it points at rest, measured from
## the model itself (pupil vs eyeball centre). Genesis 8 eyes are made turned 4 degrees outward each -
## the natural slight outward set of real eyes - and they look right with it (checked: taking it out
## made McCoy look cross-eyed), so only what is NOT that is taken out: one eye set differently from the
## other, or both turned the same way sideways. McCoy measures exactly 4 / 4, so nothing changes for him;
## his trouble was the REV 179 nudge on his right eye, now removed (CharacterFaceProfile.EYE_CORRECTIONS).
var _eye_rest_l := Vector2.ZERO
var _eye_rest_r := Vector2.ZERO
## Surface names of the pupil and of the eyeball (Daz Genesis 8).
## How much of that difference to take out (1 = all of it).
const EYE_REST_CANCEL := 1.0
const EYE_PUPIL_SURFACE := "Pupils"
const EYE_BALL_SURFACE := "Sclera"


func _measure_eye_rest(model_root: Node) -> void:
	_eye_rest_l = Vector2.ZERO
	_eye_rest_r = Vector2.ZERO
	var bl := int(_b["eye_l"])
	var br := int(_b["eye_r"])
	if _skel == null or bl < 0 or br < 0:
		return
	var at_l := _skel.get_bone_global_rest(bl).origin
	var at_r := _skel.get_bone_global_rest(br).origin
	# sums per [surface][side]: [position sum, count]
	var sums := {}
	for m in model_root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue
		for si in mi.mesh.get_surface_count():
			var sn := String(mi.mesh.surface_get_name(si))
			if sn != EYE_PUPIL_SURFACE and sn != EYE_BALL_SURFACE:
				continue
			var arr := mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bn: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var wt: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			if vs.is_empty() or bn.is_empty():
				continue
			var per := bn.size() / vs.size()
			var xf_cache := {}
			for i in vs.size():
				var pos := Vector3.ZERO
				for j in per:
					var w := wt[i * per + j]
					if w <= 0.0:
						continue
					var bi := bn[i * per + j]
					if not xf_cache.has(bi):
						var bone := mi.skin.get_bind_bone(bi)
						if bone < 0:
							bone = _skel.find_bone(mi.skin.get_bind_name(bi))
						xf_cache[bi] = _skel.get_bone_global_rest(bone) * mi.skin.get_bind_pose(bi) if bone >= 0 else Transform3D.IDENTITY
					pos += w * ((xf_cache[bi] as Transform3D) * vs[i])
				var side := "l" if pos.distance_squared_to(at_l) < pos.distance_squared_to(at_r) else "r"
				var key := sn + side
				if not sums.has(key):
					sums[key] = [Vector3.ZERO, 0]
				sums[key][0] += pos
				sums[key][1] += 1
	var rest := {}
	for side in ["l", "r"]:
		if not sums.has(EYE_PUPIL_SURFACE + side) or not sums.has(EYE_BALL_SURFACE + side):
			continue
		var pupil: Vector3 = sums[EYE_PUPIL_SURFACE + side][0] / float(sums[EYE_PUPIL_SURFACE + side][1])
		var ball: Vector3 = sums[EYE_BALL_SURFACE + side][0] / float(sums[EYE_BALL_SURFACE + side][1])
		var d: Vector3 = (_to_model.orthonormalized() * (pupil - ball)).normalized()    # character space, faces +Z
		var a := Vector2(rad_to_deg(atan2(d.x, d.z)), rad_to_deg(asin(clampf(d.y, -1.0, 1.0))))
		if a.length() > 15.0:
			continue      # something odd about this model: leave it alone
		rest[side] = a
	if not rest.has("l") or not rest.has("r"):
		return
	var l: Vector2 = rest["l"]
	var r: Vector2 = rest["r"]
	var outward := (l.x - r.x) * 0.5          # the natural outward set (left eye +, right eye -)
	var lift := (l.y + r.y) * 0.5             # both eyes set up or down together: kept, like the outward set
	_eye_rest_l = (l - Vector2(outward, lift)) * EYE_REST_CANCEL
	_eye_rest_r = (r - Vector2(-outward, lift)) * EYE_REST_CANCEL
	if _eye_rest_l.length() > 0.2 or _eye_rest_r.length() > 0.2:
		print("CharacterFace: %s eyes evened up by %s / %s degrees" % [profile.character_id, _eye_rest_l, _eye_rest_r])


static func _shape_name(mi: MeshInstance3D, k: int) -> String:
	var mesh := mi.mesh as ArrayMesh
	if mesh == null:
		return ""
	# REV 124: Daz FBX names shapes "Genesis8Male__eCTRLvAA" - use the part after the mesh name
	var n := String(mesh.get_blend_shape_name(k))
	var cut := n.rfind("__")
	return n.substr(cut + 2) if cut >= 0 else n


## REV 142: inside a real mouth it's dark - the lips, cheeks and tongue shade it. Without that shading
## the gums and tongue rendered bright pink and the teeth glowed whenever the mouth opened. Darken the
## Daz "Mouth" (gums, tongue, inside) and "Teeth" surfaces a little to stand in for it.
const MOUTH_SHADE := {"Mouth": 0.38, "Teeth": 0.58,     # REV 196: teeth 0.72 -> 0.58 (they sit in the mouth's shade)
	"Mouth Cavity": 0.38}     # REV 751: Genesis 9's mouth lining is on the body mesh under this name

static func _darken_mouth(model_root: Node) -> void:
	for n in model_root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var surf := String(mi.mesh.surface_get_name(i))
			if not MOUTH_SHADE.has(surf):
				continue
			var mat := mi.get_active_material(i) as BaseMaterial3D
			if mat == null or mat.has_meta("mouth_shaded"):
				continue
			var dark := mat.duplicate() as BaseMaterial3D
			var f: float = MOUTH_SHADE[surf]
			dark.albedo_color = Color(mat.albedo_color.r * f, mat.albedo_color.g * f, mat.albedo_color.b * f, mat.albedo_color.a)
			dark.set_meta("mouth_shaded", true)
			mi.set_surface_override_material(i, dark)


func _controlled() -> Array[int]:
	var out: Array[int] = []
	for b in _neck:
		out.append(b)
	for key in ["head", "eye_l", "eye_r", "jaw"]:
		if int(_b[key]) >= 0:
			out.append(int(_b[key]))
	return out


# ---- what the dialogue system calls -----------------------------------------------------

## Keep looking at a node (e.g. another character's focus_node(), or the camera).
func look_at_node(target: Node3D) -> void:
	_look_node = target
	_looking = target != null


## Look at a fixed point in the world.
func look_at_point(world_point: Vector3) -> void:
	_look_node = null
	_look_point = world_point
	_looking = true


## REV 160: whether something (a conversation, a cutscene, a glance) has them looking somewhere.
func is_looking() -> bool:
	return _looking


## REV 160: what they're looking at right now (null for a fixed point or nothing).
func look_target() -> Node3D:
	return _look_node if _looking else null


## Look straight ahead again.
func clear_look() -> void:
	_look_node = null
	_looking = false


## Hold the head at an explicit turn (degrees), e.g. for a scripted pose; the eyes still follow the
## look target. clear_head_pose() goes back to following.
func set_head_pose(yaw_deg: float, pitch_deg: float) -> void:
	_head_override = Vector2(yaw_deg, pitch_deg)


func clear_head_pose() -> void:
	_head_override = Vector2(INF, INF)


## REV 116: a small listening reaction on top of whatever the head is doing - "nod" (a little dip
## of the head), "tilt" (a slight sideways turn, thinking) or "blink". Used by the conversation
## camera so the person listening never looks frozen.
func react(kind: String = "nod") -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	match kind:
		"nod":
			tw.tween_property(self, "_react_offset", Vector2(0.0, -7.0), 0.22)
			tw.tween_property(self, "_react_offset", Vector2(0.0, 1.5), 0.2)
			tw.tween_property(self, "_react_offset", Vector2.ZERO, 0.25)
		"tilt":
			var side := 5.0 if randf() < 0.5 else -5.0
			tw.tween_property(self, "_react_offset", Vector2(side, -2.0), 0.5)
			tw.tween_interval(0.9)
			tw.tween_property(self, "_react_offset", Vector2.ZERO, 0.6)
		_:
			tw.kill()
	blink()


var _react_offset := Vector2.ZERO

## REV 129: when the body is animated from the Mixamo clips, the neck and head already have a pose
## each frame (a nod, a look over the shoulder, the walk's bob); the look is added on top of that pose
## instead of the rest pose. look_weight < 1 while a move turns the head itself.
var look_weight := 1.0
## REV 575: lift the body clips' chin-down tip back toward eye level when not looking at anything.
var level_gaze := true
var _anim_q := {}


func animated_base(sk: Skeleton3D) -> void:
	if sk != _skel:
		return
	for b in _neck:
		_anim_q[b] = sk.get_bone_pose_rotation(b)
	var h := int(_b["head"])
	if h >= 0:
		_anim_q[h] = sk.get_bone_pose_rotation(h)


## Blink now (both eyes).
func blink() -> void:
	_blink_phase = 0.0


## An emotion from the profile ("happy", "worried", ...), at a strength 0..1. "" or "neutral" clears it.
func set_emotion(emotion: String, strength: float = 1.0) -> void:
	_emotion_target.clear()
	var preset: Dictionary = profile.emotions.get(emotion.to_lower(), {}) if profile != null else {}
	for shape in preset.keys():
		_emotion_target[shape] = float(preset[shape]) * strength
	# REV 235: and the brows, with the brow bones (the shapes alone hardly move them)
	var brows: Array = BROW_EMOTIONS.get(emotion.to_lower(), [0.0, 0.0, 0.0])
	_brow_emotion = [float(brows[0]) * strength, float(brows[1]) * strength, float(brows[2]) * strength]


## One blend shape directly, on top of the emotion (fades there at shape_speed).
func set_shape(shape: String, weight: float) -> void:
	_manual_target[shape] = weight


func has_shape(shape: String) -> bool:
	return _shapes.has(shape)


## Every blend shape this character has (for tools and checks).
func shape_names() -> PackedStringArray:
	return PackedStringArray(_shapes.keys())


## Lip sync from Rhubarb mouth cues ([{start, end, value}] in seconds). If `player` is an
## AudioStreamPlayer(3D) the mouth follows its playback position; otherwise it starts now.
func play_lipsync(cues: Array, player: Node = null) -> void:
	_cues = cues
	_cue_player = player
	_cue_clock = 0.0


func stop_lipsync() -> void:
	_cues = []
	_cue_clock = -1.0
	_cue_player = null


## No mouth cues for a line? Move the jaw with the loudness of an audio bus instead (rougher).
## Pass "" to stop.
func talk_from_bus(bus_name: String) -> void:
	_talk_bus = AudioServer.get_bus_index(bus_name) if bus_name != "" else -1


func is_talking() -> bool:
	return _cue_clock >= 0.0 or _talk_bus >= 0 or _mime


## REV 235: talk without a sound to follow - quiet chatter in the background, where the voice (if any)
## is too faint or too far away to drive the mouth. Made-up syllables in phrases, with breaths between.
## `softly` keeps the mouth smaller (murmuring). Pass false to stop.
func talk_mime(on: bool, softly: bool = true) -> void:
	_mime = on
	_mime_soft = softly
	_mime_t = 0.0
	_mime_phrase = randf_range(0.8, 2.2)


var _mime := false
var _mime_soft := true
var _mime_t := 0.0
var _mime_level := 0.0
var _mime_phrase := 0.0       # time left in the current phrase (then a short breath)


func _mime_level_now(delta: float) -> float:
	_mime_phrase -= delta
	if _mime_phrase < -0.25:
		_mime_phrase = randf_range(0.8, 2.2)       # the breath is over: a new phrase
	if _mime_phrase < 0.0:
		return 0.0
	_mime_t -= delta
	if _mime_t <= 0.0:
		_mime_t = randf_range(0.09, 0.2)
		_mime_level = 0.04 if randf() < 0.18 else randf_range(0.25, 0.7)
	return _mime_level * (0.6 if _mime_soft else 1.0)


## Read a Rhubarb Lip Sync JSON file (rhubarb -f json) into mouth cues.
static func load_rhubarb(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary and (data as Dictionary).has("mouthCues"):
		return (data as Dictionary)["mouthCues"]
	return []


## Points for a camera to frame or for another character to look at, in world space:
## "eyes" (between the eyes), "mouth", "head" (head pivot), "chest".
func focus_point(what: String = "eyes") -> Vector3:
	if _skel == null:
		return _wrapper.global_position + Vector3(0, 1.65, 0) if _wrapper != null else Vector3.ZERO
	match what:
		"eyes":
			if int(_b["eye_l"]) >= 0 and int(_b["eye_r"]) >= 0:
				return (_bone_world(int(_b["eye_l"])) + _bone_world(int(_b["eye_r"]))) * 0.5
		"mouth":
			if int(_b["jaw"]) >= 0 and int(_b["eye_l"]) >= 0 and int(_b["eye_r"]) >= 0:
				var eyes := (_bone_world(int(_b["eye_l"])) + _bone_world(int(_b["eye_r"]))) * 0.5
				var jaw := _bone_world(int(_b["jaw"]))
				# the jaw pivot sits behind the mouth: drop from the eyes to jaw height, keep the face's depth
				return Vector3(eyes.x, jaw.y - 0.02, eyes.z) + facing() * -0.01
		"chest":
			if int(_b["chest"]) >= 0:
				return _bone_world(int(_b["chest"]))
	return _bone_world(int(_b["head"])) if int(_b["head"]) >= 0 else _wrapper.global_position


## A node that sits between the eyes and moves with the head: give it to another character's
## look_at_node() so they meet this character's eyes.
func focus_node() -> Node3D:
	var marker := get_node_or_null("EyesMarker") as Node3D
	if marker == null:
		marker = Marker3D.new()
		marker.name = "EyesMarker"
		add_child(marker)
		marker.top_level = true
	marker.global_position = focus_point("eyes")
	return marker


## The way the character's body faces, in world space (horizontal).
func facing() -> Vector3:
	if _wrapper == null:
		return Vector3.FORWARD
	var f := _wrapper.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.BACK


## Where the eyes are actually pointing, in world space (for over-the-shoulder framing and checks).
func gaze_direction() -> Vector3:
	var avg := (_eye_l + _eye_r) * 0.5
	var yaw := _head_yaw + avg.x
	var pitch := _head_pitch + avg.y
	var local := Quaternion(Vector3.UP, deg_to_rad(yaw)) * Quaternion(Vector3.RIGHT, deg_to_rad(-pitch)) * Vector3.BACK
	return (_wrapper.global_transform.basis.orthonormalized() * local).normalized()


# ---- every frame -----------------------------------------------------------------------

func _process(delta: float) -> void:
	if not ready_to_use:
		return
	var marker := get_node_or_null("EyesMarker") as Node3D
	if marker != null:
		marker.global_position = focus_point("eyes")
	_update_look(delta)
	_update_blink(delta)
	_update_shapes(delta)


func _update_look(delta: float) -> void:
	var p := profile
	var target_ok := _looking and (_look_node == null or is_instance_valid(_look_node))
	var tgt := _look_point
	if _look_node != null and is_instance_valid(_look_node):
		tgt = _look_node.global_position

	# where the target is, from between the eyes, in the character's own space
	var want := Vector2.ZERO
	if target_ok:
		want = _angles_to(tgt, focus_point("eyes"))

	# REV 140: the body animations (idle, talking) carry their own head pose, often tipped down a few
	# degrees. The look is added on top of that, so it has to take it into account, or a character
	# talking to someone at eye level ends up looking at their chest. The slow part of the animation's
	# head pose is cancelled while looking at someone; its quick nods and tilts are kept.
	var anim := _animated_head_angles()
	# REV 171: 0.8 s let a talking clip's big head dips through for long enough that the eyes rolled up
	# under the brows to stay on the listener; the head now corrects within about a quarter second
	_anim_look = _anim_look.lerp(anim, 1.0 - exp(-delta / ANIM_LOOK_SECONDS))

	# head + neck: a share of the look, nothing for small looks, within limits
	# REV 171 (Glen: Spock's eyes "roll upwards" as he moves his head): the limits are for the LOOK
	# only. Cancelling the animation's own head pose (REV 140) used to count against them too, so a
	# talking clip that tips the head well down ran the head out of room and the eyes turned far up
	# to make up the rest - eyes rolled up under the lids. Now the cancel goes on top of the limited
	# look, and whatever the eyes would still need above a comfortable angle, the chin lifts for.
	var head_want := Vector2.ZERO
	if _head_override.x != INF:
		head_want = _head_override * look_weight + _react_offset
		head_want.x = clampf(head_want.x, -p.head_yaw_max, p.head_yaw_max)
		head_want.y = clampf(head_want.y, -p.head_pitch_max, p.head_pitch_max)
	else:
		if target_ok:
			head_want.x = _dead(want.x, p.head_dead_zone) * p.head_share
			head_want.y = _dead(want.y, p.head_dead_zone) * p.head_share
		head_want *= look_weight       # REV 129: a move that turns the head itself (looking behind) wins
		head_want += _react_offset     # REV 116: nods and tilts while listening
		head_want.x = clampf(head_want.x, -p.head_yaw_max, p.head_yaw_max)
		head_want.y = clampf(head_want.y, -p.head_pitch_max, p.head_pitch_max)
		if target_ok:
			head_want -= _anim_look * look_weight
			var eye_up := want.y - head_want.y - _anim_look.y
			if eye_up > EYE_UP_COMFORT:
				head_want.y += (eye_up - EYE_UP_COMFORT) * look_weight
			# REV 175 (Glen: McCoy's eyes look weird scanning): looking down at something in his hands
			# the eyes turned far down with the lids open, showing a lot of white. People bow the head
			# instead; past a comfortable angle down, the head takes the rest.
			elif eye_up < -EYE_DOWN_COMFORT:
				head_want.y += (eye_up + EYE_DOWN_COMFORT) * look_weight
			head_want.x = clampf(head_want.x, -p.head_yaw_max - 40.0, p.head_yaw_max + 40.0)
			head_want.y = clampf(head_want.y, -p.head_pitch_max - 30.0, p.head_pitch_max + 30.0)
		elif level_gaze:
			# REV 575 (Glen: "everybody just seems to be looking down almost all the time"): the Mixamo
			# clips, moved onto the Daz skeletons, tip the head chin-down a few degrees, and with nobody to
			# look at nothing took it out. The slow part of the clip's downward tip is lifted back toward
			# eye level now (quick nods stay); clips that turn the head themselves (look_weight down:
			# bowling, picking up, consoles, looking behind) keep theirs, and a deep look down
			# (past LEVEL_MAX) is left as meant.
			var tip := -minf(0.0, _anim_look.y)
			if tip <= LEVEL_MAX:
				head_want.y += tip * LEVEL_SHARE * look_weight
	var k := 1.0 - exp(-head_speed * delta)
	_head_yaw = lerpf(_head_yaw, head_want.x, k)
	_head_pitch = lerpf(_head_pitch, head_want.y, k)
	# REV 171: a quick, deep dip of the head in the body animation (Spock's talking clip drops it up to
	# 30 degrees) is taken out at once, beyond a small nod - smoothing alone always lagged it, and in
	# that lag the eyes rolled up to hold the look. Only while looking at someone.
	var dip := 0.0
	if target_ok and _head_override.x == INF:
		dip = -minf(0.0, (anim.y - _anim_look.y) + NOD_KEEP) * look_weight
	_head_dip = lerpf(_head_dip, dip, 1.0 - exp(-30.0 * delta))

	# small eye flicks while holding a look
	if micro_saccades and target_ok:
		_saccade_t -= delta
		if _saccade_t <= 0.0:
			_saccade = Vector2(randf_range(-0.9, 0.9), randf_range(-0.6, 0.6))
			_saccade_t = randf_range(0.35, 1.4)
	else:
		_saccade = Vector2.ZERO

	# each eye: whatever the head isn't doing, from that eye's own position (so they converge)
	# REV 127: with nothing to look at, the eyes still focus on a point a little way ahead, the way
	# a person's do - parallel eyes read as unfocused
	var eye_tgt := tgt
	var eye_ok := target_ok
	if not target_ok and int(_b["eye_l"]) >= 0 and int(_b["eye_r"]) >= 0:
		eye_tgt = focus_point("eyes") + facing() * 1.8
		eye_ok = true
	var ke := 1.0 - exp(-eye_speed * delta)
	for side in ["l", "r"]:
		var bone := int(_b["eye_" + side])
		var e := Vector2.ZERO
		if eye_ok and bone >= 0:
			e = _angles_to(eye_tgt, _bone_world(bone)) - Vector2(_head_yaw, _head_pitch + _head_dip) - anim + (_saccade if target_ok else Vector2.ZERO)
		e.x = clampf(e.x, -p.eye_yaw_max, p.eye_yaw_max)
		e.y = clampf(e.y, -p.eye_pitch_down_max, p.eye_pitch_up_max)
		if side == "l":
			_eye_l = _eye_l.lerp(e, ke)
		else:
			_eye_r = _eye_r.lerp(e, ke)

	# a big change of where to look (a new target) usually comes with a blink
	if auto_blink and _blink_phase < 0.0 and (want - _last_want).length() > 25.0:
		_blink_phase = 0.0
	_last_want = want

	# write the bones: neck(s), head, then eyes; each turn is given in skeleton space and converted
	# into the bone's own frame, so it works whichever way the rig's bones point
	var neck_each := p.neck_share / maxf(1.0, float(_neck.size()))
	var hp := _head_pitch + _head_dip
	for b in _neck:
		_turn_bone(b, _head_yaw * neck_each, hp * neck_each)
	_turn_bone(int(_b["head"]), _head_yaw * (1.0 - p.neck_share), hp * (1.0 - p.neck_share))
	# REV 144: plus any fixed per-character correction (e.g. McCoy's right eye)
	# REV 197: and minus the way each eye already points at rest (see _measure_eye_rest)
	_turn_bone(int(_b["eye_l"]), _eye_l.x + p.eye_left_offset.x - _eye_rest_l.x, _eye_l.y + p.eye_left_offset.y - _eye_rest_l.y)
	_turn_bone(int(_b["eye_r"]), _eye_r.x + p.eye_right_offset.x - _eye_rest_r.x, _eye_r.y + p.eye_right_offset.y - _eye_rest_r.y)
	# REV 853: and any sideways slide of the eyeball in its socket (McCoy)
	_shift_eye(int(_b["eye_l"]), p.eye_left_shift_mm, 1.0)
	_shift_eye(int(_b["eye_r"]), p.eye_right_shift_mm, -1.0)


# ---- REV 142: the mouth, moved with the face's own bones ---------------------------------------

## Bones under the lower lip go round with the jaw (1 = fully); in this rig they hang off the head,
## not the jaw, so turning the jaw alone opened the teeth but left the lips where they were.
const MOUTH_FOLLOW_JAW := {
	"LipLowerMiddle": 1.0, "lLipLowerInner": 1.0, "rLipLowerInner": 1.0, "lLipLowerOuter": 0.95,
	"rLipLowerOuter": 0.95, "LipBelow": 1.0, "Chin": 1.0, "BelowJaw": 1.0, "lLipCorner": 0.45,
	"rLipCorner": 0.45, "lNasolabialLower": 0.55, "rNasolabialLower": 0.55,
	"lNasolabialMouthCorner": 0.3, "rNasolabialMouthCorner": 0.3, "lCheekLower": 0.2,
	"rCheekLower": 0.2, "lJawClench": 0.35, "rJawClench": 0.35,
}
const UPPER_LIP := ["LipUpperMiddle", "lLipUpperInner", "rLipUpperInner", "lLipUpperOuter", "rLipUpperOuter"]
const LOWER_LIP := ["LipLowerMiddle", "lLipLowerInner", "rLipLowerInner", "lLipLowerOuter", "rLipLowerOuter"]
const LIP_CORNERS := ["lLipCorner", "rLipCorner"]
## REV 196: the skin around the lips, which goes with them.
const ABOVE_LIP := ["lLipBelowNose", "rLipBelowNose"]       # between the nose and the upper lip
const BELOW_LIP := ["LipBelow"]                               # between the lower lip and the chin
const MOUTH_CREASES := ["lNasolabialMouthCorner", "rNasolabialMouthCorner", "lNasolabialLower", "rNasolabialLower"]
const CHEEKS := ["lCheekLower", "rCheekLower"]
## The tongue, root to tip (children of the jaw, so it opens with it); how far each lifts for the
## "tongue" control, in degrees.
const TONGUE := ["tongue01", "tongue02", "tongue03", "tongue04"]
const TONGUE_LIFT := [0.0, 12.0, 22.0, 26.0]
## Movement sizes, metres (the rig is in metres).
const LIP_OPEN_UPPER := 0.004       # the top lip relaxes down over the teeth as the jaw opens
const LIP_OPEN_LOWER := 0.0055      # the bottom lip rides up over the lower teeth
const LIP_ROUND_IN := 0.016        # the corners, towards the middle
const ROUND_CORNER_FWD := 0.008
## REV 196 rounding, per lip part [middle, inner, outer]: how far it arches away from the other lip
## (makes the oval), comes in towards the middle, pushes forward, and rolls outward (degrees).
const ROUND_ARCH := [0.0025, 0.0016, -0.0012]
const ROUND_IN := [0.0, 0.004, 0.010]
const ROUND_FWD := [0.011, 0.010, 0.007]
const ROUND_CURL := [22.0, 18.0, 10.0]
## Which way a positive roll turns the lip in this rig (checked on McCoy: -1 rolls the lips out).
const LIP_CURL_SIGN := -1.0
const LIP_SPREAD := 0.003
const LIP_UPPER_UP := 0.0028
const LIP_LOWER_DOWN := 0.003

var _mouth_bones := []      # [{i, name, rest (local Transform3D), pivot, axis, up, fwd, side (all in parent space), follow}]
var _tongue := []           # [{i, rest (local Quaternion), lift (degrees)}]
var _mouth_set := false


func _mouth_setup() -> void:
	_mouth_set = true
	_mouth_bones.clear()
	_tongue.clear()
	var jaw := int(_b["jaw"])
	if _skel == null or jaw < 0:
		return
	var fwd_s := _right_s.cross(_up_s).normalized()
	var names := {}
	for n in MOUTH_FOLLOW_JAW.keys():
		names[n] = true
	for n in UPPER_LIP + LOWER_LIP + LIP_CORNERS + ABOVE_LIP + BELOW_LIP + MOUTH_CREASES + CHEEKS:
		names[n] = true
	# REV 735: Daz's recipes, when this is a Daz face with lip bones
	_load_visemes()
	_shape_prefix = _viseme_prefix()
	_use_shapes = daz_mouth and daz_mouth_shapes and _shape_prefix != ""
	_use_recipes = daz_mouth and daz_mouth_bones and not _vis_bones.is_empty() and _skel.find_bone("LipUpperMiddle") >= 0
	if _use_recipes:
		for v in _vis_bones.keys():
			for n in (_vis_bones[v] as Dictionary).keys():
				names[n] = true
	var pivot_s := _skel.get_bone_global_rest(jaw).origin
	for n in names.keys():
		var i := _skel.find_bone(String(n))
		if i < 0:
			continue
		var par := _skel.get_bone_parent(i)
		var gp := _skel.get_bone_global_rest(par) if par >= 0 else Transform3D.IDENTITY
		var inv_b := gp.basis.orthonormalized().inverse()
		_mouth_bones.append({
			"i": i, "name": String(n),
			"rest": Transform3D(Basis(_skel.get_bone_pose_rotation(i)), _skel.get_bone_pose_position(i)),
			"pivot": gp.affine_inverse() * pivot_s,
			"axis": (inv_b * _right_s).normalized(),
			"up": (inv_b * _up_s).normalized(),
			"fwd": (inv_b * fwd_s).normalized(),
			"lat": (inv_b * _right_s).normalized(),     # toward the character's left
			"side": signf(_skel.get_bone_global_rest(i).origin.dot(_right_s) - pivot_s.dot(_right_s)),
			"follow": float(MOUTH_FOLLOW_JAW.get(n, 0.0)),
		})
	for k in TONGUE.size():
		var t := _skel.find_bone(TONGUE[k])
		if t >= 0:
			_tongue.append({"i": t, "rest": _skel.get_bone_pose_rotation(t), "lift": float(TONGUE_LIFT[k])})


## REV 196: ease toward `want` (the eight mouth controls, see MOUTH_POSES) and pose the jaw, lip,
## skin and tongue bones. Each control moves at its own speed (MOUTH_SPEEDS).
func _mouth_update(want: Array, delta: float) -> void:
	if not _mouth_set:
		_mouth_setup()
	var resting := true
	for j in MOUTH_CONTROLS:
		var k := 1.0 - exp(-float(MOUTH_SPEEDS[j]) * delta)
		_mouth_now[j] = lerpf(float(_mouth_now[j]), float(want[j]) if j < want.size() else 0.0, k)
		if absf(float(_mouth_now[j])) > 0.002:
			resting = false
	# REV 853: with a Rhubarb file (or at rest) the visemes come straight from the letter and ease on their
	# own; listening and miming have no letters, so they're still read off the 8 controls
	_direct_frame = daz_direct_visemes and _talk_bus < 0 and not _mime
	if _use_recipes or _use_shapes:
		if _direct_frame:
			for v in _vis_target.keys():
				if not _vis_now.has(v):
					_vis_now[v] = 0.0
			for v in _vis_now.keys():
				var sp := float(VISEME_SPEEDS.get(v, VISEME_SPEED_DEFAULT))
				var goal := float(_vis_target.get(v, 0.0))
				var cur := float(_vis_now[v])
				_vis_now[v] = lerpf(cur, goal, 1.0 - exp(-sp * delta))
				if absf(float(_vis_now[v])) > 0.002:
					resting = false
			for v in _vis_now.keys().duplicate():
				if absf(float(_vis_now[v])) < 0.001 and float(_vis_target.get(v, 0.0)) == 0.0:
					_vis_now.erase(v)
			_viseme_w = _vis_now.duplicate()
		else:
			_viseme_w = _visemes_for(_mouth_now)
			_vis_now = _viseme_w.duplicate()     # so a switch back to the direct route carries on from here
	if _use_recipes or _use_shapes:
		# REV 739: the exported shapes move the lips but NOT the jaw (renders: lips parted round clenched
		# teeth = a snarl), so the jaw opens by Daz's own amount for each viseme, and the lower lip bones go
		# round with it (MOUTH_FOLLOW_JAW) as they do in Daz, where they hang off the jaw
		var jr := 0.0
		for v in _viseme_w.keys():
			jr += float(_viseme_w[v]) * float(_vis_jaw.get(v, 0.0))
		_jaw_deg = maxf(jr * daz_jaw_gain * (G9_JAW_SCALE if _genesis9 and daz_direct_visemes else 1.0), 0.0)
	else:
		_jaw_deg = float(_mouth_now[0]) * JAW_MAX_DEG
	var jaw := int(_b["jaw"])
	if jaw >= 0:
		_turn_bone(jaw, 0.0, -_jaw_deg)
	if resting and not _mouth_dirty:
		return
	_mouth_dirty = not resting
	var open: float = _mouth_now[0]
	var rnd: float = _mouth_now[1]
	var spread: float = _mouth_now[2]
	var press: float = _mouth_now[3]
	var tuck: float = _mouth_now[4]
	var upper: float = _mouth_now[5]
	var lower: float = _mouth_now[6]
	var tongue: float = 0.0 if _use_shapes else float(_mouth_now[7])   # REV 739: the L shape has its own tongue
	# REV 853: how far the lips close back over the teeth (0..daz_lip_cover), from how open the jaw is
	var lip_cover := clampf(_jaw_deg / JAW_MAX_DEG, 0.0, 1.0) * daz_lip_cover if daz_direct_visemes else 0.0
	# the oval opens with the jaw: a tight "oo" is a small hole, an "oh" a bigger one
	var arch_k := clampf(0.3 + open * 2.0, 0.0, 1.0)
	for m in _mouth_bones:
		var rest: Transform3D = m["rest"]
		var n: String = m["name"]
		var up: Vector3 = m["up"]
		var fwd: Vector3 = m["fwd"]
		var lat: Vector3 = m["lat"]
		var side: float = m["side"]
		var o := Vector3.ZERO
		var curl := 0.0          # degrees the lip rolls outward (REV 196)
		var turn := Quaternion.IDENTITY
		if _use_recipes:
			# REV 735: Daz's own moves for this bone, summed over the visemes in play. Daz's lip bones
			# have no orientation of their own, so its x/y/z are the figure's left/up/forward.
			var tt := Vector3.ZERO
			var rr := Vector3.ZERO
			for v in _viseme_w.keys():
				var b = (_vis_bones[v] as Dictionary).get(n)
				if b == null:
					continue
				var k := float(_viseme_w[v])
				tt += Vector3(float(b[0]), float(b[1]), float(b[2])) * k
				rr += Vector3(float(b[3]), float(b[4]), float(b[5])) * k
			o = (lat * tt.x + up * tt.y + fwd * tt.z) * 0.01
			# Daz rotation order ZYX: x is turned first
			turn = Quaternion(fwd, deg_to_rad(rr.z)) * Quaternion(up, deg_to_rad(rr.y)) * Quaternion(lat, deg_to_rad(rr.x))
		elif _use_shapes:
			# REV 739: the exported shapes move the lips. REV 853 (Glen: soften the lip stretch): as the jaw drops,
			# both lips relax back over the teeth as in the hand mouth below - without it the lower lip fell with
			# the jaw and every open sound showed both rows of teeth, like dentures
			if n in UPPER_LIP or n in LOWER_LIP:
				var part := _lip_part(n)
				var k := lip_cover * (1.0 if part == 0 else (0.85 if part == 1 else 0.6))
				if n in UPPER_LIP:
					o += -up * LIP_OPEN_UPPER * k
				else:
					o += up * LIP_OPEN_LOWER * k + fwd * 0.001 * k
			elif n in LIP_CORNERS:
				o += -lat * side * 0.0015 * lip_cover      # corners in a touch: less of a grimace
		elif n in UPPER_LIP:
			# relaxes down over the teeth as the mouth opens, lifts off them for "ee" and "s", rolls in a
			# touch when pressed. REV 196 rounding (Glen: no O shapes): the lip arches up into an oval, the
			# outer parts come in towards the middle, and the whole lip pushes out and flares (curls out)
			var part := _lip_part(n)
			o += -up * (LIP_OPEN_UPPER * open + 0.001 * press) + up * (LIP_UPPER_UP * upper * (1.0 if part == 0 else 0.6))
			o += up * float(ROUND_ARCH[part]) * rnd * arch_k
			o += fwd * (float(ROUND_FWD[part]) * rnd - 0.0008 * press)
			o += -lat * side * float(ROUND_IN[part]) * rnd + lat * side * (0.0012 if part == 2 else 0.0) * spread
			curl = float(ROUND_CURL[part]) * rnd
		elif n in LOWER_LIP:
			# rides up over the lower teeth; tucks under the top teeth for F and V; drops and curls out
			# a little to show the lower teeth; rounding mirrors the upper lip (arches down, in, out)
			var part := _lip_part(n)
			o += up * (LIP_OPEN_LOWER * open + 0.0015 * press + 0.0025 * tuck) - up * (LIP_LOWER_DOWN * lower * (1.0 if part == 0 else 0.6))
			o += -up * float(ROUND_ARCH[part]) * 0.8 * rnd * arch_k
			o += fwd * (float(ROUND_FWD[part]) * rnd + 0.0015 * open - 0.003 * tuck + 0.001 * lower - 0.0008 * press)
			o += -lat * side * float(ROUND_IN[part]) * rnd + lat * side * (0.0012 if part == 2 else 0.0) * spread
			curl = -float(ROUND_CURL[part]) * rnd
		elif n in LIP_CORNERS:
			o += lat * side * (LIP_SPREAD * spread - LIP_ROUND_IN * rnd) + fwd * (ROUND_CORNER_FWD * rnd - 0.001 * spread)
			o += up * 0.0006 * spread
		elif n in ABOVE_LIP:
			o += up * (0.0012 * upper) + fwd * (0.0018 * rnd) - lat * side * 0.002 * rnd
		elif n in BELOW_LIP:
			o += fwd * (0.0018 * rnd + 0.0006 * lower) - up * (0.001 * lower) + up * 0.0008 * tuck
		elif n in MOUTH_CREASES:
			var w := 1.0 if n.contains("MouthCorner") else 0.5
			o += (lat * side * (0.0015 * spread - 0.004 * rnd) + fwd * (0.0015 * rnd)) * w
		elif n in CHEEKS:
			o += up * 0.0008 * spread - lat * side * 0.0008 * rnd
		var origin := rest.origin + o
		var basis := rest.basis
		if absf(curl) > 0.01:
			basis = Basis(Quaternion(lat, deg_to_rad(curl * LIP_CURL_SIGN))) * basis
		if _use_recipes:
			basis = Basis(turn) * basis
		var follow: float = m["follow"]
		if follow > 0.0 and _jaw_deg > 0.001:
			var q := Quaternion(m["axis"] as Vector3, deg_to_rad(_jaw_deg * follow))
			var pivot: Vector3 = m["pivot"]
			origin = pivot + q * (origin - pivot)
			basis = Basis(q) * basis
		_skel.set_bone_pose_position(int(m["i"]), origin)
		_skel.set_bone_pose_rotation(int(m["i"]), basis.get_rotation_quaternion())
	# the tongue: each part lifts a little more than the one before, curling the tip up behind the teeth
	for t in _tongue:
		var bi := int(t["i"])
		var base: Quaternion = t["rest"]
		var deg: float = float(t["lift"]) * tongue * TONGUE_SIGN
		if absf(deg) < 0.01:
			_skel.set_bone_pose_rotation(bi, base)
			continue
		var parent := _skel.get_bone_parent(bi)
		var pq := _skel.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
		var turn := Quaternion(_right_s, deg_to_rad(-deg))
		_skel.set_bone_pose_rotation(bi, ((pq.inverse() * turn * pq) * base).normalized())

## REV 735: Daz's viseme recipes (core/characters/daz_visemes.json), loaded once for every face.
static func _load_visemes() -> void:
	if _vis_loaded:
		return
	_vis_loaded = true
	var f := FileAccess.open(VISEME_FILE, FileAccess.READ)
	if f == null:
		push_warning("CharacterFace: no %s - hand-made mouths" % VISEME_FILE)
		return
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary) or not (d as Dictionary).has("visemes"):
		return
	_vis_bones = d["visemes"]
	_vis_jaw = d.get("jaw", {})


## REV 739: which name the export's viseme shapes go by ("eCTRL" + vM on Genesis 8, "facs_ctrl_" + vM on
## Genesis 8.1), or "" when it has none of them.
func _viseme_prefix() -> String:
	for pre in ["eCTRL", "facs_ctrl_"]:
		if _shapes.has(pre + "vM") and _shapes.has(pre + "vUW") and _shapes.has(pre + "vAA"):
			return pre
	return ""


## REV 735: the 8 mouth controls read as a blend of the Rhubarb letters (nearest letters weigh most),
## turned into Daz viseme weights. A half-closed "oo" on its way to rest is half Daz's "oo".
func _visemes_for(c: Array) -> Dictionary:
	var lw := {}
	var sum := 0.0
	for letter in MOUTH_POSES.keys():
		var p: Array = MOUTH_POSES[letter]
		var d2 := 0.0
		for j in MOUTH_CONTROLS:
			var e := float(c[j]) - float(p[j])
			d2 += e * e
		var x := exp(-d2 / LETTER_SPREAD)
		lw[letter] = x
		sum += x
	var out := {}
	for letter in lw.keys():
		var w := float(lw[letter]) / maxf(sum, 1e-9)
		if w < 0.01:
			continue
		var mix: Dictionary = LETTER_VISEMES.get(letter, {})
		for v in mix.keys():
			out[v] = float(out.get(v, 0.0)) + w * float(mix[v])
	return out


## 0 = the middle of a lip, 1 = inner, 2 = outer.
static func _lip_part(n: String) -> int:
	return 2 if n.contains("Outer") else (1 if n.contains("Inner") else 0)


## Which way "up" turns the tongue in this rig (checked on McCoy).
const TONGUE_SIGN := 1.0

var _mouth_dirty := true


# ---- REV 235: the eyebrows, moved with the face's own bones -------------------------------------
## Glen: Spock's eyebrow didn't go up after McCoy's strike. Like the mouth (REV 142), Daz's brow shapes
## (eCTRLBrowUp-Down...) only carry their corrective part in the export - in Daz the real lift comes
## from the brow bones - so on their own they barely move. The brows are posed with those bones now.
## Each side has three controls, inner / middle / outer, from -1 (pulled down and in: a frown) to +1
## (raised). Two layers add up: the emotion's brows (BROW_EMOTIONS, from set_emotion) and a manual one
## (raise_brow / set_brow, e.g. Spock's single raised eyebrow).
const BROW_BONES := {
	"l": ["lBrowInner", "lBrowMid", "lBrowOuter"],
	"r": ["rBrowInner", "rBrowMid", "rBrowOuter"],
}
## REV 751: Genesis 9's brow bones - inner and outer only (no middle one; its skin follows the two ends).
const BROW_BONES_G9 := {
	"l": ["l_browinner", "", "l_browouter"],
	"r": ["r_browinner", "", "r_browouter"],
}
## Metres up at +1, for inner / middle / outer (the rig is in metres; Genesis 8's own full brow raise
## lifts the middle of the brow about a centimetre).
const BROW_RAISE := [0.0055, 0.0085, 0.0075]
## Metres down at -1, and how far the inner ends draw toward the nose with it (a knitted brow).
const BROW_LOWER := [0.0035, 0.0025, 0.0012]
const BROW_KNIT := 0.0028
const BROW_SPEED := 9.0
## The brows each emotion brings, [inner, middle, outer] on both sides (the shapes still add their part).
const BROW_EMOTIONS := {
	"happy": [0.15, 0.2, 0.15],
	"amused": [0.1, 0.25, 0.3],
	"sad": [0.65, 0.15, -0.25],
	"worried": [0.75, 0.3, -0.05],
	"angry": [-1.0, -0.6, -0.1],
	"stern": [-0.55, -0.35, -0.05],
	"annoyed": [-0.45, -0.2, 0.05],
	"surprised": [0.9, 1.0, 0.9],
	"curious": [0.2, 0.5, 0.6],
	"skeptical": [-0.4, -0.15, 0.1],
}
var _brow_set := false
var _brows := []                 # [{i, side ("l"/"r"), part (0 inner, 1 mid, 2 outer), rest, up, lat, lr}]
var _brow_emotion := [0.0, 0.0, 0.0]
var _brow_manual := {"l": [0.0, 0.0, 0.0], "r": [0.0, 0.0, 0.0]}
var _brow_now := {"l": [0.0, 0.0, 0.0], "r": [0.0, 0.0, 0.0]}
var _brow_dirty := false


## Raise one eyebrow ("l" = the character's left, "r" = their right) by `amount` (0-1; negative lowers
## it): the arched, Vulcan kind - the middle and outer end go up most. 0 puts it back.
func raise_brow(side: String, amount: float = 1.0) -> void:
	set_brow(side, 0.35 * amount, amount, 0.9 * amount)


## One brow's three controls directly (-1..1): inner, middle, outer. "both" sets the two sides.
func set_brow(side: String, inner: float, mid: float, outer: float) -> void:
	for s in (["l", "r"] if side == "both" else [side]):
		if _brow_manual.has(s):
			_brow_manual[s] = [inner, mid, outer]


## True if this face has brow bones to move (Genesis 8 does).
func has_brow_bones() -> bool:
	if not _brow_set:
		_brow_setup()
	return not _brows.is_empty()


func _brow_setup() -> void:
	_brow_set = true
	_brows.clear()
	if _skel == null:
		return
	var table: Dictionary = BROW_BONES_G9 if _skel.find_bone("l_browinner") >= 0 else BROW_BONES   # REV 751
	for side in table.keys():
		var names: Array = table[side]
		for part in names.size():
			if String(names[part]) == "":
				continue
			var i := _skel.find_bone(String(names[part]))
			if i < 0:
				continue
			var par := _skel.get_bone_parent(i)
			var gp := _skel.get_bone_global_rest(par) if par >= 0 else Transform3D.IDENTITY
			var inv_b := gp.basis.orthonormalized().inverse()
			# which way is "toward the nose" for this bone: the character's left is +right_s (see the mouth)
			var lr := 1.0 if String(side) == "l" else -1.0
			_brows.append({
				"i": i, "side": String(side), "part": part,
				"rest": _skel.get_bone_pose_position(i),
				"up": (inv_b * _up_s).normalized(),
				"lat": (inv_b * _right_s).normalized(),
				"lr": lr,
			})


func _brow_update(delta: float) -> void:
	if not _brow_set:
		_brow_setup()
	if _brows.is_empty():
		return
	var k := 1.0 - exp(-BROW_SPEED * delta)
	var resting := true
	for side in ["l", "r"]:
		var now: Array = _brow_now[side]
		var man: Array = _brow_manual[side]
		for p in 3:
			var want := clampf(float(_brow_emotion[p]) + float(man[p]), -1.0, 1.0)
			now[p] = lerpf(float(now[p]), want, k)
			if absf(float(now[p])) > 0.002:
				resting = false
	if resting and not _brow_dirty:
		return
	_brow_dirty = not resting
	for b in _brows:
		var v: float = float((_brow_now[b["side"]] as Array)[int(b["part"])])
		var part := int(b["part"])
		var o := Vector3.ZERO
		if v >= 0.0:
			o = (b["up"] as Vector3) * float(BROW_RAISE[part]) * v
		else:
			o = (b["up"] as Vector3) * float(BROW_LOWER[part]) * v
			if part == 0:
				# a frown draws the inner ends together, toward the nose
				o += -(b["lat"] as Vector3) * float(b["lr"]) * BROW_KNIT * -v
		_skel.set_bone_pose_position(int(b["i"]), (b["rest"] as Vector3) + o)


## REV 140: (yaw, pitch) in degrees of where the body animation alone points the head, relative to the
## body's facing. Worked out from the animated rotations saved by animated_base(), not the bones as
## they stand (those already carry last frame's look). Zero for a figure with no body animation.
func _animated_head_angles() -> Vector2:
	var hb := int(_b["head"])
	if hb < 0 or _anim_q.is_empty() or _skel == null:
		return Vector2.ZERO
	# head -> up through the neck bones, to the first bone the look doesn't touch
	var chain: Array[int] = []
	var b := hb
	while b >= 0 and (b == hb or _neck.has(b)):
		chain.push_front(b)
		b = _skel.get_bone_parent(b)
	var rot := Quaternion.IDENTITY
	if b >= 0:
		rot = _skel.get_bone_global_pose(b).basis.orthonormalized().get_rotation_quaternion()
	for c in chain:
		rot = rot * (_anim_q.get(c, _rest_q[c]) as Quaternion)
	var rest := _skel.get_bone_global_rest(hb).basis.orthonormalized().get_rotation_quaternion()
	var sk_basis := _skel.global_transform.basis.orthonormalized()
	var fwd_s := sk_basis.inverse() * facing()
	if fwd_s.length() < 0.001:
		return Vector2.ZERO
	var v := sk_basis * ((rot * rest.inverse()) * fwd_s.normalized())
	var a := _angles_to(focus_point("eyes") + v, focus_point("eyes"))
	return Vector2(clampf(a.x, -40.0, 40.0), clampf(a.y, -30.0, 30.0))


## REV 171: how far up (degrees, relative to the head) the eyes turn before the head lifts instead.
const EYE_UP_COMFORT := 7.0
## REV 175: and how far down before the head bows instead.
const EYE_DOWN_COMFORT := 12.0
## REV 171: how quickly the head undoes the body animation's own head pose while looking at someone.
const ANIM_LOOK_SECONDS := 0.22
## REV 171: how much of a quick downward head dip (degrees) is left in as a nod; deeper is taken out.
const NOD_KEEP := 5.0
## REV 575: lifting a clip's chin-down head back toward level when there's nobody to look at - the share
## of the tip taken out, and the deepest tip still treated as a slouch (deeper = meant, left alone).
const LEVEL_SHARE := 0.85
const LEVEL_MAX := 24.0
var _head_dip := 0.0


## Turn one bone by (yaw, pitch) degrees in the character's space, on top of its set-up rotation.
func _turn_bone(bone: int, yaw_deg: float, pitch_deg: float) -> void:
	if bone < 0:
		return
	var turn := Quaternion(_up_s, deg_to_rad(yaw_deg)) * Quaternion(_right_s, deg_to_rad(-pitch_deg))
	var parent := _skel.get_bone_parent(bone)
	var pq := Quaternion.IDENTITY
	if parent >= 0:
		pq = _skel.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion()
	var local_turn := pq.inverse() * turn * pq
	var base: Quaternion = _anim_q.get(bone, _rest_q[bone])
	_skel.set_bone_pose_rotation(bone, (local_turn * base).normalized())


## REV 853: move an eye bone `mm` millimetres outward from its rest place (`outward` = +1 for the left eye,
## -1 for the right: _right_s points to the character's left).
var _eye_rest_pos := {}
func _shift_eye(bone: int, mm: float, outward: float) -> void:
	if bone < 0:
		return
	if not _eye_rest_pos.has(bone):
		_eye_rest_pos[bone] = _skel.get_bone_pose_position(bone)
	if absf(mm) < 0.001:
		return
	var parent := _skel.get_bone_parent(bone)
	var pb := _skel.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var d := pb.inverse() * (_right_s * outward * mm * 0.001)
	_skel.set_bone_pose_position(bone, (_eye_rest_pos[bone] as Vector3) + d)


## (yaw, pitch) in degrees from `from` to `to`, measured in the character's own space.
func _angles_to(to: Vector3, from: Vector3) -> Vector2:
	var d := _wrapper.global_transform.basis.orthonormalized().inverse() * (to - from)
	if d.length() < 0.001:
		return Vector2.ZERO
	var yaw := rad_to_deg(atan2(d.x, d.z))
	var pitch := rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))
	return Vector2(yaw, pitch)


static func _dead(v: float, zone: float) -> float:
	return signf(v) * maxf(absf(v) - zone, 0.0)


func _bone_world(bone: int) -> Vector3:
	return _skel.global_transform * _skel.get_bone_global_pose(bone).origin


func _update_blink(delta: float) -> void:
	if auto_blink and _blink_phase < 0.0:
		_blink_t -= delta
		if _blink_t <= 0.0:
			_blink_phase = 0.0
	if _blink_phase >= 0.0:
		_blink_phase += delta / BLINK_LENGTH
		if _blink_phase >= 1.0:
			_blink_phase = -1.0
			_blink_t = randf_range(2.0, 6.0) if randf() > 0.15 else 0.25   # now and then a double blink
			blinked.emit()


func _blink_amount() -> float:
	if _blink_phase < 0.0:
		return 0.0
	# closes quickly, opens a little slower
	return _blink_phase / 0.4 if _blink_phase < 0.4 else 1.0 - (_blink_phase - 0.4) / 0.6


func _update_shapes(delta: float) -> void:
	var p := profile
	var ks := 1.0 - exp(-shape_speed * delta)
	_ease_layer(_emotion_now, _emotion_target, ks)
	_ease_layer(_manual_now, _manual_target, ks)

	# talking: Rhubarb cues, or listening to the voice as it plays
	var want: Array = MOUTH_POSES["X"]
	_vis_target = {}
	if _cue_clock >= 0.0:
		var t := _cue_time(delta) + CUE_LEAD
		var letter := "X"
		var finished := true
		for c in _cues:
			if t < float(c.get("end", 0.0)):
				finished = false
				if t >= float(c.get("start", 0.0)):
					letter = String(c.get("value", "X"))
				break
		# REV 142: the mouth bones make the shape (see _mouth_update); Daz's mouth shapes aren't used
		want = MOUTH_POSES.get(letter, MOUTH_POSES["X"])
		# REV 853: and the letter goes straight to Daz's visemes (used when the face has them)
		_vis_target = LETTER_VISEMES.get(letter, {})
		if finished and t - CUE_LEAD > _cues_end():
			stop_lipsync()
			_vis_target = {}
	elif _talk_bus >= 0:
		want = _listen(delta)
	elif _mime:
		want = _guess(_mime_level_now(delta), delta)     # REV 235: background chatter
	_mouth_update(want, delta)
	_brow_update(delta)      # REV 235

	# add the layers up
	var total := {}
	for s in p.rest_shapes.keys():
		total[s] = float(p.rest_shapes[s])
	for layer in [_emotion_now, _manual_now]:
		for s in layer.keys():
			total[s] = float(total.get(s, 0.0)) + float(layer[s])
	# REV 735: Daz's own viseme shapes ride along with the viseme bones (Genesis 8 eCTRL names; on 8.1
	# the facs_ctrl shapes are left alone until they're checked)
	if _use_shapes:
		for v in _viseme_w.keys():
			var vs := _shape_prefix + String(v)
			var g := float(VISEME_GAIN.get(v, 1.0)) if daz_direct_visemes else 1.0      # REV 853
			total[vs] = float(total.get(vs, 0.0)) + float(_viseme_w[v]) * daz_shape_strength * g
	var lid := _blink_amount()
	var follow := 0.0
	if lid_follows_gaze:
		var down := -(_eye_l.y + _eye_r.y) * 0.5
		follow = clampf(down / maxf(p.eye_pitch_down_max, 1.0), 0.0, 1.0) * 0.6   # REV 175: was 0.35
	total[p.blink_left] = maxf(lid, follow) + float(total.get(p.blink_left, 0.0))
	total[p.blink_right] = maxf(lid, follow) + float(total.get(p.blink_right, 0.0))

	# write (and zero anything that dropped out of every layer)
	for s in _applied.keys():
		if not total.has(s):
			total[s] = 0.0
	for s in total.keys():
		var v := clampf(float(total[s]), 0.0, 1.0)
		if absf(v - float(_applied.get(s, -1.0))) < 0.002:
			continue
		_applied[s] = v
		for pair in _shapes.get(s, []):
			(pair[0] as MeshInstance3D).set_blend_shape_value(int(pair[1]), v)


func _cues_end() -> float:
	return float((_cues[_cues.size() - 1] as Dictionary).get("end", 0.0)) if not _cues.is_empty() else 0.0


# ---- REV 196: talking without a Rhubarb file - listen to the voice ------------------------------

## Eight slices of the voice's sound, Hz (low hum ... hiss).
const VOICE_BANDS := [Vector2(90, 250), Vector2(250, 500), Vector2(500, 800), Vector2(800, 1200),
	Vector2(1200, 1800), Vector2(1800, 2600), Vector2(2600, 3800), Vector2(3800, 8000)]
## How the eight mouth controls follow the voice: worked out (tools/tune_mouth_listen.py) by fitting
## all 101 recorded Prologue lines (McCoy, Kirk, Spock, Uhura) to what Rhubarb makes of them. Rows: bias, loudness, loudness
## squared, then loudness x log(share of each slice). Columns: the eight mouth controls.
const LISTEN_WEIGHTS := [
	[0.0900, 0.0640, 0.0907, 0.0403, -0.0038, 0.0720, 0.0662, 0.0828],   # bias
	[0.3686, 0.1354, 0.3231, -0.1864, 0.3768, 0.3255, 0.1875, 0.2639],   # level
	[-0.1770, -0.1301, -0.1620, 0.0787, -0.2724, -0.2071, -0.1006, -0.1614],   # level squared
	[0.0086, -0.0259, 0.0080, 0.0080, 0.0006, -0.0016, 0.0009, -0.0114],   # level x log(share of slice 1)
	[-0.0212, 0.0391, -0.0081, -0.0142, 0.0057, 0.0027, -0.0026, 0.0119],   # level x log(share of slice 2)
	[0.0191, -0.0210, 0.0079, -0.0149, -0.0008, -0.0037, -0.0001, 0.0017],   # level x log(share of slice 3)
	[0.0102, 0.0273, -0.0200, 0.0096, 0.0036, -0.0097, -0.0101, -0.0031],   # level x log(share of slice 4)
	[0.0045, -0.0206, 0.0105, 0.0018, 0.0042, 0.0039, 0.0038, -0.0154],   # level x log(share of slice 5)
	[-0.0065, -0.0044, 0.0064, -0.0087, 0.0010, 0.0050, 0.0039, -0.0018],   # level x log(share of slice 6)
	[0.0090, -0.0190, 0.0046, 0.0011, -0.0114, 0.0012, 0.0051, 0.0131],   # level x log(share of slice 7)
	[-0.0114, 0.0009, 0.0029, -0.0132, 0.0142, 0.0079, 0.0014, 0.0033],   # level x log(share of slice 8)
]
## The fit's average for each control, and how much to widen the fit's (cautious) swings around it
## so the mouth moves as much as Rhubarb's does. 0 = that control isn't taken from the voice
## (press: from the quiet gaps instead; tuck: F/V can't be heard reliably).
const LISTEN_MEAN := [0.203, 0.168, 0.179, 0.064, 0.027, 0.139, 0.120, 0.162]
const LISTEN_GAIN := [2.2, 1.4, 1.8, 0.0, 0.0, 1.4, 1.5, 0.8]
const LISTEN_FLOOR_DB := -40.0               # quieter than this is silence (mouth at rest)
const LISTEN_RANGE_DB := 28.0                # and this much louder is full volume

static var _analysers := {}                  # bus index -> AudioEffectSpectrumAnalyzerInstance


## The eight mouth controls for what the voice sounds like right now. Falls back to the loudness-only
## guesswork (REV 140) when the bus can't be listened to.
func _listen(delta: float) -> Array:
	var db := AudioServer.get_bus_peak_volume_left_db(_talk_bus, 0)
	var level := clampf((db - LISTEN_FLOOR_DB) / LISTEN_RANGE_DB, 0.0, 1.0)
	var an := _analyser(_talk_bus)
	if an == null:
		return _guess(level, delta)
	var shares: Array[float] = []
	var total := 0.0
	for band: Vector2 in VOICE_BANDS:
		var m: Vector2 = an.get_magnitude_for_frequency_range(band.x, band.y, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)
		var mag: float = (m.x + m.y) * 0.5
		var en: float = mag * mag * (band.y - band.x)
		shares.append(en)
		total += en
	for j in shares.size():
		shares[j] = shares[j] / maxf(total, 1e-18)
	return listen_pose(level, shares)


## The mouth for a sound this loud (0-1) with this share of its energy in each of VOICE_BANDS.
## Static, so tools can run exactly the same sums on a recording.
static func listen_pose(level: float, shares: Array) -> Array:
	if level < 0.04:
		return MOUTH_POSES["X"]
	var x: Array[float] = [1.0, level, level * level]
	for sh in shares:
		x.append(level * log(float(sh) + 1e-4))
	var out: Array = []
	for j in MOUTH_CONTROLS:
		var v := 0.0
		for i in x.size():
			v += x[i] * float(LISTEN_WEIGHTS[i][j])
		var g: float = LISTEN_GAIN[j]
		out.append(clampf(float(LISTEN_MEAN[j]) + (v - float(LISTEN_MEAN[j])) * g, 0.0, 1.0) if g > 0.0 else 0.0)
	# quiet but not silent - the closing consonants between syllables (m, b, p...)
	out[3] = clampf((0.2 - level) / 0.16, 0.0, 1.0) * 0.7
	return out


## The REV 140 guesswork: a made-up shape about every syllable, sized by the loudness.
func _guess(level: float, delta: float) -> Array:
	var k := 1.0 - exp(-(24.0 if level > _jaw_level else 16.0) * delta)
	_jaw_level = lerpf(_jaw_level, level, k)
	_syll_t -= delta
	if _syll_t <= 0.0:
		_syll_t = randf_range(0.07, 0.13)
		if _jaw_level < 0.12:
			_syll_shape = ""
		elif _jaw_level < 0.3 or randf() < 0.3:
			_syll_shape = ["A", "B", "B", "G", "H", "B"][randi() % 6]
		else:
			_syll_shape = ["D", "C", "E", "F", "D", "C", "E"][randi() % 7]
	var pose: Array = MOUTH_POSES.get(_syll_shape if _syll_shape != "" else "X", MOUTH_POSES["X"])
	var lv := clampf(_jaw_level * 1.3, 0.0, 1.0)
	var out: Array = pose.duplicate()
	out[0] = float(out[0]) * lv
	for j in range(1, MOUTH_CONTROLS):
		out[j] = float(out[j]) * minf(1.0, lv * 2.0)
	return out


## A spectrum analyser on `bus` (added once, at the end of the bus, where it changes nothing heard).
static func _analyser(bus: int) -> AudioEffectSpectrumAnalyzerInstance:
	if bus < 0:
		return null
	if _analysers.has(bus):
		return _analysers[bus]
	var at := -1
	for e in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, e) is AudioEffectSpectrumAnalyzer:
			at = e
			break
	if at < 0:
		var fx := AudioEffectSpectrumAnalyzer.new()
		fx.buffer_length = 0.1
		fx.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048     # about 46 ms, as tuned
		AudioServer.add_bus_effect(bus, fx)
		at = AudioServer.get_bus_effect_count(bus) - 1
	var inst := AudioServer.get_bus_effect_instance(bus, at) as AudioEffectSpectrumAnalyzerInstance
	_analysers[bus] = inst
	return inst


func _cue_time(delta: float) -> float:
	if _cue_player != null and is_instance_valid(_cue_player) and _cue_player.has_method("get_playback_position"):
		if bool(_cue_player.get("playing")):
			# REV 196: what is being heard right now (minus the sound card's delay)
			_cue_clock = maxf(0.0, float(_cue_player.call("get_playback_position")) + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())
			return _cue_clock
	_cue_clock += delta
	return _cue_clock


static func _ease_layer(now: Dictionary, target: Dictionary, k: float) -> void:
	for s in target.keys():
		now[s] = lerpf(float(now.get(s, 0.0)), float(target[s]), k)
	for s in now.keys():
		if not target.has(s):
			now[s] = lerpf(float(now[s]), 0.0, k)
	for s in now.keys().duplicate():
		if not target.has(s) and float(now[s]) < 0.001:
			now.erase(s)
