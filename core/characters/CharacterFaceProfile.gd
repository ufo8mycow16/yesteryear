extends Resource
class_name CharacterFaceProfile
## CharacterFaceProfile (REV 97): what one character's face is made of, so CharacterFace can drive it.
##
## Nothing here is McCoy-specific. A profile names the bones that turn the eyes, head and neck, and
## the blend shapes for blinking, talking (visemes) and expressions. Every Daz Genesis 8 character
## (McCoy, and later Kirk, Spock, Uhura, Scotty, Sulu, Chekov ...) uses genesis8() unchanged; a rig
## from somewhere else only needs its own names filled in.
##
## A model can also carry its profile inside the .glb (glTF "extras" on a node, key
## "vulcan_fury_character"); from_model() reads that when it is there. (REV 293: the old
## McCoy_rigged.glb carried one; the Daz FBX exports don't, they get daz_genesis8().)

@export var character_id := ""

@export_group("Bones (exact names; case doesn't matter)")
@export var bone_head := "head"
## Neck bones from the body upwards. The head turn is shared between these and the head.
@export var bones_neck: PackedStringArray = PackedStringArray(["neckLower", "neckUpper"])
@export var bone_eye_left := "lEye"
@export var bone_eye_right := "rEye"
@export var bone_jaw := "lowerJaw"
@export var bone_chest := "chestUpper"

@export_group("Blend shapes")
@export var blink_left := "blink_L"
@export var blink_right := "blink_R"
@export var jaw_open := "jaw_open"
## REV 127: shapes always held a little, under everything else - the face's relaxed resting look
## (e.g. eyelids resting slightly lower than the sculpt's wide-open default).
@export var rest_shapes := {}
## Rhubarb Lip Sync mouth letters -> blend shape. "X" (mouth closed / resting) maps to nothing.
@export var visemes := {
	"A": "mouth_A_MBP", "B": "mouth_B_KST", "C": "mouth_C_EH", "D": "mouth_D_AA",
	"E": "mouth_E_AO", "F": "mouth_F_OO", "G": "mouth_G_FV", "H": "mouth_H_L", "X": "",
}
## Emotion name -> {blend shape: weight}. Used by CharacterFace.set_emotion() and by dialogue lines.
@export var emotions := {
	"neutral": {},
	"happy": {"mouth_smile": 0.85, "brow_raise": 0.15},
	"amused": {"mouth_smile": 0.5},
	"sad": {"mouth_frown": 0.6, "brow_worry": 0.85},
	"worried": {"brow_worry": 0.7, "mouth_frown": 0.25},
	"angry": {"brow_frown": 1.0, "mouth_frown": 0.4},
	"stern": {"brow_frown": 0.5, "mouth_frown": 0.3},
	"surprised": {"brow_raise": 1.0, "jaw_open": 0.2},
	"curious": {"brow_raise": 0.45},
	"skeptical": {"brow_frown": 0.35, "mouth_frown": 0.15},
}

@export_group("How far each part may turn (degrees)")
@export var eye_yaw_max := 28.0
@export var eye_pitch_up_max := 18.0
@export var eye_pitch_down_max := 24.0
@export var head_yaw_max := 55.0       # head + neck together
@export var head_pitch_max := 22.0
## How much of a look the head follows (the eyes do the rest). 0.5 = subtle, dialogue-style.
@export_range(0.0, 1.0) var head_share := 0.5
## Of the head's turn, how much the neck bones take between them.
@export_range(0.0, 1.0) var neck_share := 0.4
## Looks smaller than this (degrees) are done with the eyes only.
@export var head_dead_zone := 6.0

@export_group("Per-character corrections")
## REV 144: a fixed extra turn (yaw, pitch in degrees; +yaw = toward the character's left, +pitch =
## up) added to one eye, for a bought head whose eye sits slightly off and has no sliders to fix it.
## Character-specific ONLY - filled from EYE_CORRECTIONS by character id, never copied to everyone.
@export var eye_left_offset := Vector2.ZERO
@export var eye_right_offset := Vector2.ZERO
## REV 853: slide an eyeball sideways in its socket, millimetres, + = outward (away from the nose). For a face
## whose eye OPENINGS sit off-centre over the eyeballs - turning the eye only fakes it from one viewing angle.
## Character-specific ONLY (EYE_CORRECTIONS "shift_left" / "shift_right").
@export var eye_left_shift_mm := 0.0
@export var eye_right_shift_mm := 0.0

## REV 144: per-character eye corrections (CLAUDE.md item 2). McCoy's right eye looked a little off
## even with the eye turning set to zero; tuned from a close-up render of both eyes.
## REV 198: McCoy's REV 179 right-eye nudge (-6 yaw) removed - measured from the model, it turned his
## right eye 10 degrees out against the left eye's 4, which is what made him look cross-eyed (Glen,
## 21 Oct). CharacterFace._measure_eye_rest now evens up any eyes set differently from each other.
## REV 853 (Glen: "there's always been something off about his eye"): McCoy's eyeballs sit 1.5-2 mm too close
## to his nose for his eye OPENINGS (his face shape), so looking straight at someone his pupils sat 5-6% of the
## eye's width in towards the nose (right eye worst) - slightly cross-eyed. Turning the eyes out only fakes it from
## the front (7 degrees made him look past the camera from the side - Glen caught it), so each eyeball is SLID out
## in its socket (shift_left / shift_right, mm; more pokes the white through the outer corner) and the small rest
## is a gentle turn (left / right, degrees). Measured off renders: pupils centred head-on, aim checked from the
## side with lines drawn out of the pupils. "lids": his right eye is also built a touch wider open - lids matched.
const EYE_CORRECTIONS := {
	"mccoy": {"shift_left": 1.6, "shift_right": 2.0, "left": Vector2(2.5, 0.0), "right": Vector2(-3.5, 0.0),
		"lids": {"eCTRLEyelidsLowerUpDownR": 0.6, "eCTRLEyelidsUpperDownR": 0.05}},
}


## Fill in this character's own corrections (if any) from the table above.
func apply_character_corrections() -> void:
	var c: Dictionary = EYE_CORRECTIONS.get(character_id.to_lower(), {})
	eye_left_offset = c.get("left", Vector2.ZERO)
	eye_right_offset = c.get("right", Vector2.ZERO)
	eye_left_shift_mm = float(c.get("shift_left", 0.0))
	eye_right_shift_mm = float(c.get("shift_right", 0.0))
	var lids: Dictionary = c.get("lids", {})
	if not lids.is_empty() and not _lids_added:
		_lids_added = true
		for k in lids.keys():
			rest_shapes[k] = float(rest_shapes.get(k, 0.0)) + float(lids[k])


var _lids_added := false


## The default for a Genesis 8 figure with the plain bone names (REV 293: made for the old hand-rigged
## McCoy, since removed; the Daz FBX exports are switched to daz_genesis8() by CharacterFace.setup).
static func genesis8(id: String = "") -> CharacterFaceProfile:
	var p := CharacterFaceProfile.new()
	p.character_id = id
	return p


## REV 124: a Genesis 8 figure exported straight from Daz Studio as FBX with its face controls
## (eCTRL...): Daz's own viseme, blink and expression names.
static func daz_genesis8(id: String = "") -> CharacterFaceProfile:
	var p := genesis8(id)
	p.blink_left = "eCTRLEyesClosedL"
	p.blink_right = "eCTRLEyesClosedR"
	p.jaw_open = "eCTRLMouthOpen"
	# Tiffany's notes: a relaxed, intelligent look, not a stare - upper lids resting over the top of
	# the iris (more toward the outer corners), lower lids lifted a touch, the eye area relaxed
	# REV 140: eased off (upper lids 0.2 -> 0.08, relax 0.4 -> 0.25) - with the lids that low, McCoy
	# read as looking down in every close-up even when his eyes were level
	p.rest_shapes = {
		"eCTRLEyelidsUpperDownL": 0.08, "eCTRLEyelidsUpperDownR": 0.08,
		"eCTRLEyelidsLowerUpDown": 0.2,
		"eCTRLEyesRelax": 0.25,
	}
	p.visemes = {
		"A": "eCTRLvM",     # M B P - lips together
		"B": "eCTRLvK",     # K S T and most consonants - teeth nearly together
		"C": "eCTRLvEH",    # EH AE - open, wide
		"D": "eCTRLvAA",    # AA - wide open
		"E": "eCTRLvOW",    # AO ER - rounded
		"F": "eCTRLvUW",    # UW OW W - puckered
		"G": "eCTRLvF",     # F V - lower lip to teeth
		"H": "eCTRLvL",     # L - tongue up
		"X": "",
	}
	# Daz's full-face expressions (_HD) at part strength, with finer controls on top
	p.emotions = {
		"neutral": {},
		"happy": {"eCTRLSmileFullFace_HD": 1.0, "eCTRLMouthSmile": 0.35},
		"amused": {"eCTRLMouthSmileSimple": 0.6, "eCTRLSmileFullFace_HD": 0.2},
		"sad": {"eCTRLFrown_HD": 0.45, "eCTRLBrowInnerUp-Down": 0.5},
		"worried": {"eCTRLAfraid_HD": 0.3, "eCTRLBrowInnerUp-Down": 0.45},
		"angry": {"eCTRLAngry_HD": 0.65},
		"stern": {"eCTRLAngry_HD": 0.25, "eCTRLBrowSqueeze": 0.35},
		"surprised": {"eCTRLSurprised_HD": 0.65},
		"curious": {"eCTRLBrowOuterUp-Down": 0.5, "eCTRLBrowInnerUp-Down": 0.2},
		"skeptical": {"eCTRLBrowSqueeze": 0.35, "eCTRLEyesSquintL": 0.4, "eCTRLMouthSmileSimpleR": 0.2},
	}
	return p


## REV 577: a Genesis 8.1 figure (Tuvall). Its face controls export as FACS shapes (facs_ctrl_...) -
## the eCTRL dials of 8.1 only drive those, so they carry nothing of their own. The blinks keep their eCTRL
## names (they are real shapes on 8.1 too). Mouth and brows still run on the face bones, as for everyone.
static func daz_genesis81(id: String = "") -> CharacterFaceProfile:
	var p := genesis8(id)
	p.blink_left = "eCTRLEyesClosedL"
	p.blink_right = "eCTRLEyesClosedR"
	p.jaw_open = "facs_jnt_JawOpen"
	p.rest_shapes = {}
	p.visemes = {
		"A": "facs_ctrl_vM",
		"B": "facs_ctrl_vK",
		"C": "facs_ctrl_vEH",
		"D": "facs_ctrl_vAA",
		"E": "facs_ctrl_vOW",
		"F": "facs_ctrl_vUW",
		"G": "facs_ctrl_vF",
		"H": "facs_ctrl_vL",
		"X": "",
	}
	# the same moods as daz_genesis8(), in 8.1's names
	p.emotions = {
		"neutral": {},
		"happy": {"facs_ctrl_SmileFullFace": 1.0, "facs_ctrl_MouthSmile": 0.35},
		"amused": {"facs_ctrl_MouthSmile": 0.6, "facs_ctrl_SmileFullFace": 0.2},
		"sad": {"facs_ctrl_Frown": 0.45, "facs_ctrl_BrowInnerUp": 0.5},
		"worried": {"facs_ctrl_Afraid": 0.3, "facs_ctrl_BrowInnerUp": 0.45},
		"angry": {"facs_ctrl_Angry": 0.65},
		"stern": {"facs_ctrl_Angry": 0.25, "facs_ctrl_BrowDown": 0.35},
		"surprised": {"facs_ctrl_Surprised": 0.65},
		"curious": {"facs_ctrl_BrowUp": 0.5, "facs_ctrl_BrowInnerUp": 0.2},
		"skeptical": {"facs_ctrl_BrowDown": 0.35, "facs_bs_EyeSquintLeft_div2": 0.4, "facs_bs_MouthSmileRight_div2": 0.2},
	}
	return p


## REV 751: a Genesis 9 figure (alongside the Genesis 8 cast). Its own bone names (l_eye, neck1/neck2,
## lowerjaw, spine4), its blinks from the FACS shapes (facs_bs_EyeBlink...). The talking mouth needs nothing
## here: G9 exports the same facs_ctrl_v... visemes as Genesis 8.1, which CharacterFace already plays (shapes
## plus Daz's jaw amounts on lowerjaw). G9 has no whole-face mood presets (8.1's SmileFullFace, Angry ...),
## so the moods are built from its single controls. Brows are left to the brow bones (BROW_EMOTIONS) as on
## every Daz face - G9's brow shapes DO move (unlike G8's), so adding them too would lift the brows twice.
static func daz_genesis9(id: String = "") -> CharacterFaceProfile:
	var p := genesis8(id)
	p.bone_head = "head"
	p.bones_neck = PackedStringArray(["neck1", "neck2"])
	p.bone_eye_left = "l_eye"
	p.bone_eye_right = "r_eye"
	p.bone_jaw = "lowerjaw"
	p.bone_chest = "spine4"
	p.blink_left = "facs_bs_EyeBlinkLeft"
	p.blink_right = "facs_bs_EyeBlinkRight"
	p.jaw_open = "facs_bs_JawOpen"
	p.rest_shapes = {}
	p.visemes = {
		"A": "facs_ctrl_vM",
		"B": "facs_ctrl_vK",
		"C": "facs_ctrl_vEH",
		"D": "facs_ctrl_vAA",
		"E": "facs_ctrl_vOW",
		"F": "facs_ctrl_vUW",
		"G": "facs_ctrl_vF",
		"H": "facs_ctrl_vL",
		"X": "",
	}
	# the same moods as daz_genesis8(), from G9's single controls (brows: the bones, see above)
	p.emotions = {
		"neutral": {},
		"happy": {"facs_ctrl_MouthSmile": 0.75, "facs_ctrl_CheekSquint": 0.35, "facs_ctrl_EyeSquint": 0.12},
		"amused": {"facs_ctrl_MouthSmile": 0.45, "facs_ctrl_CheekSquint": 0.15},
		"sad": {"facs_ctrl_MouthFrown": 0.5, "facs_ctrl_MouthShrugLower": 0.2},
		"worried": {"facs_ctrl_MouthStretch": 0.18, "facs_ctrl_EyeWide": 0.15, "facs_ctrl_MouthFrown": 0.15},
		"angry": {"facs_ctrl_NoseSneer": 0.3, "facs_ctrl_MouthPress": 0.35, "facs_ctrl_EyeSquint": 0.25},
		"stern": {"facs_ctrl_MouthPress": 0.25, "facs_ctrl_EyeSquint": 0.12},
		"surprised": {"facs_ctrl_EyeWide": 0.5, "facs_ctrl_MouthLipsPart": 0.4},
		"curious": {"facs_ctrl_EyeWide": 0.12},
		"skeptical": {"facs_bs_EyeSquintLeft": 0.4, "facs_bs_MouthSmileRight": 0.2, "facs_bs_MouthPressLowerLeft": 0.15},
	}
	return p


## The profile stored inside an imported model (glTF extras), or null when it has none.
## Godot 4.3+ imports a glTF node's extras as that node's "extras" metadata.
static func from_model(model_root: Node) -> CharacterFaceProfile:
	if model_root == null:
		return null
	var stack: Array[Node] = [model_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.has_meta("extras"):
			var ex = n.get_meta("extras")
			if ex is Dictionary and (ex as Dictionary).has("vulcan_fury_character"):
				return from_dict((ex as Dictionary)["vulcan_fury_character"])
		for c in n.get_children():
			stack.push_back(c)
	return null


## Build a profile from the "vulcan_fury_character" block (the old McCoy_rigged.glb had one - REV 293: removed). Anything missing keeps
## the Genesis 8 default.
static func from_dict(d: Dictionary) -> CharacterFaceProfile:
	var p := genesis8(String(d.get("id", "")))
	var bones: Dictionary = d.get("bones", {})
	p.bone_head = String(bones.get("head", p.bone_head))
	if bones.has("neck"):
		p.bones_neck = PackedStringArray(bones["neck"])
	p.bone_eye_left = String(bones.get("eye_left", p.bone_eye_left))
	p.bone_eye_right = String(bones.get("eye_right", p.bone_eye_right))
	p.bone_jaw = String(bones.get("jaw", p.bone_jaw))
	p.bone_chest = String(bones.get("chest", p.bone_chest))
	if d.has("visemes_rhubarb"):
		p.visemes = (d["visemes_rhubarb"] as Dictionary).duplicate()
	return p
