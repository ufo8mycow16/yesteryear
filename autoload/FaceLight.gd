extends Node
## REV 736 (Glen, comparing Tuvall with her Daz store picture): film-style lighting on faces in close-up.
## Daz's pictures are lit like a portrait - a soft main light from one side, a gentle fill on the other,
## a light from behind catching the hair and the edge of the face. In the game a face was lit only by the
## room, often flat from all sides (Tuvall's office: orange on everything, no shape to the face at all).
##
## Whenever the camera is close on a face that's turned toward it (a conversation, a cutscene close-up,
## walking up to someone), this brings in three lights on that face - and only on people: they light the
## people-only layer (CharacterLook.CHAR_LAYER), never the room, so a set's look never changes. The lights
## follow the camera, so every angle is lit like a portrait, and fade in and out softly.
## Off at the LOW graphics preset. Tune by eye with the numbers below.

const CHAR_LAYER := 1 << 19
const ON_DISTANCE := 2.6          # metres from the camera to the eyes: closer = a close-up worth lighting
const FACING_MIN := 0.25          # how squarely the face must turn toward the camera (-1..1)
const FADE := 0.45                # seconds to fade in/out
const PICK_EVERY := 0.2           # seconds between choosing which face to light

## Key: soft, slightly warm, above and to one side of the camera.
const KEY_ENERGY := 0.7          # REV 741 (pale, chalky faces): was 1.0
const KEY_COLOUR := Color(1.0, 0.95, 0.88)
const KEY_SIDE_DEG := 52.0         # REV 740: further round (was 38) - a real modelling shadow beside the nose
const KEY_UP_DEG := 30.0
const KEY_DIST := 1.4
## Fill: dimmer, from the other side, a little below the key.
const FILL_ENERGY := 0.2          # REV 740: less fill (was 0.3), so the shadow side keeps its shape
const FILL_COLOUR := Color(0.92, 0.95, 1.0)
const FILL_SIDE_DEG := -55.0
const FILL_UP_DEG := 0.0
const FILL_DIST := 1.6
## Rim: from behind and above the head, toward the camera - an edge of light on hair, ears and cheek.
const RIM_ENERGY := 0.75         # REV 741: was 1.1
const RIM_COLOUR := Color(0.82, 0.88, 1.0)
const RIM_SIDE_DEG := 150.0
const RIM_UP_DEG := 35.0
const RIM_DIST := 1.2
## When the enhanced room look's own people light (ModernLighting "CharacterKey") is on, ease ours down.
const WITH_MODERN_KEY := 0.6

var enabled := true
var _key: SpotLight3D
var _fill: SpotLight3D
var _rim: SpotLight3D
var _w := 0.0
var _face: Node = null
var _pick_t := 0.0
var _side := 1.0                  # which side of the camera the key comes from (+1 = camera left)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_key = _light("FaceKey", KEY_COLOUR, 32.0)
	_fill = _light("FaceFill", FILL_COLOUR, 40.0)
	_rim = _light("FaceRim", RIM_COLOUR, 30.0)


func _light(n: String, colour: Color, angle: float) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.name = n
	l.light_color = colour
	l.light_cull_mask = CHAR_LAYER
	l.spot_angle = angle
	l.spot_angle_attenuation = 0.8
	l.spot_range = 4.0
	l.spot_attenuation = 0.6
	l.light_energy = 0.0
	l.light_specular = 0.25      # REV 737: softer highlights (faces read as plastic at 0.6)
	l.shadow_enabled = false
	l.visible = false
	add_child(l)
	return l


func _preset() -> int:
	var gs: Node = get_node_or_null("/root/GameSettings")
	return int(gs.get("quality_preset")) if gs != null else 2


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var on := enabled and cam != null and _preset() >= 1
	_pick_t -= delta
	if on and _pick_t <= 0.0:
		_pick_t = PICK_EVERY
		_pick(cam)
	if not on or not is_instance_valid(_face):
		_face = null
	_w = move_toward(_w, 1.0 if _face != null else 0.0, delta / FADE)
	var vis := _w > 0.001
	for l in [_key, _fill, _rim]:
		(l as Light3D).visible = vis
	if not vis or _face == null:
		return
	# the key's shadow (the nose, the cheekbones) only on HIGH - one shadowed spot light
	_key.shadow_enabled = _preset() >= 2
	var eyes: Vector3 = _face.focus_point("eyes")
	var k := _w * (WITH_MODERN_KEY if _modern_key_on() else 1.0)
	_place(_key, cam, eyes, KEY_SIDE_DEG * _side, KEY_UP_DEG, KEY_DIST)
	_place(_fill, cam, eyes, FILL_SIDE_DEG * _side, FILL_UP_DEG, FILL_DIST)
	_place(_rim, cam, eyes, RIM_SIDE_DEG * _side, RIM_UP_DEG, RIM_DIST)
	_key.light_energy = KEY_ENERGY * k
	_fill.light_energy = FILL_ENERGY * k
	_rim.light_energy = RIM_ENERGY * k


## The light at `dist` from the eyes, swung `side_deg` round from the camera's direction and `up_deg` above
## it, pointing at the eyes.
func _place(l: SpotLight3D, cam: Camera3D, eyes: Vector3, side_deg: float, up_deg: float, dist: float) -> void:
	var to_cam := cam.global_position - eyes
	to_cam.y = 0.0
	if to_cam.length() < 0.001:
		to_cam = Vector3.BACK
	to_cam = to_cam.normalized()
	var d := to_cam.rotated(Vector3.UP, deg_to_rad(side_deg))
	d = (d * cos(deg_to_rad(up_deg)) + Vector3.UP * sin(deg_to_rad(up_deg))).normalized()
	var pos := eyes + d * dist
	var fwd := (eyes - pos).normalized()
	var up := Vector3.UP if absf(fwd.y) < 0.98 else Vector3.FORWARD
	l.global_transform = Transform3D(Basis.looking_at(fwd, up), pos)


## The face to light: the nearest one in front of the camera, close enough and turned toward it.
func _pick(cam: Camera3D) -> void:
	var best: Node = null
	var best_score := INF
	var cam_pos := cam.global_position
	var cam_fwd := -cam.global_transform.basis.z
	var half := deg_to_rad(cam.fov * 0.5) * 1.1
	for f in get_tree().get_nodes_in_group("vf_faces"):
		if not is_instance_valid(f) or not f.has_method("focus_point"):
			continue
		var fig := f.get_parent() as Node3D
		if fig == null or not fig.is_visible_in_tree():
			continue
		var eyes: Vector3 = f.focus_point("eyes")
		var to := eyes - cam_pos
		var dist := to.length()
		if dist > ON_DISTANCE or dist < 0.05:
			continue
		var dir := to / dist
		var off := acos(clampf(dir.dot(cam_fwd), -1.0, 1.0))
		if off > half:
			continue
		var facing: Vector3 = f.facing() if f.has_method("facing") else Vector3.ZERO
		var flat := -dir
		flat.y = 0.0
		if facing != Vector3.ZERO and flat.length() > 0.001 and facing.dot(flat.normalized()) < FACING_MIN:
			continue
		var score := dist * (1.0 + off)
		if score < best_score:
			best_score = score
			best = f
	if best != _face:
		_face = best
		if best != null:
			# key on the side the face is turned toward (short of the camera) - reads as a portrait, not a mugshot
			var facing2: Vector3 = best.facing() if best.has_method("facing") else Vector3.ZERO
			var right := cam.global_transform.basis.x
			_side = -1.0 if facing2.dot(right) > 0.0 else 1.0


## Looked up once per room (never a whole-scene search every frame - REV 681 rule).
var _key_scene: Node = null
var _modern_key: Light3D = null

func _modern_key_on() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	if scene != _key_scene:
		_key_scene = scene
		_modern_key = scene.find_child("CharacterKey", true, false) as Light3D
	return is_instance_valid(_modern_key) and _modern_key.visible
