extends Node3D
class_name OrbitCameraRig
## Free-orbit third-person camera rig in the WoW/KOTOR tradition. Orbit
## position is computed directly from yaw/pitch/distance (spherical
## coordinates) rather than relying on SpringArm3D's collision-pushback
## behaviour, which keeps this rig's math fully deterministic and easy to
## verify without running the editor. A collision-avoidance spring arm is a
## reasonable later addition and would slot in without changing any other
## system — nothing outside this file depends on how the offset is computed.
##
## Orbit is never mouse-only: camera_orbit_left/right (keyboard/controller)
## always work, per the locked keyboard-only-playability rule. Mouse orbit is
## an added convenience on top, driven by right-click-drag rather than a
## persistently captured cursor: holding the right mouse button captures and
## hides the cursor for the duration of the drag (so motion isn't clipped at
## the screen edge) and releases it back to normal the moment the button is
## let go — the player never has to "escape" a captured mouse to use menus,
## HUD buttons, etc.

@export var distance: float = 2.5
# CORRECTION: the previous pass (height=2.0, pitch=+0.25) massively
# overshot — screenshots showed the camera sitting above McCoy's head
# entirely, staring down into her hair. Two compounding mistakes: (1) 2.0
# didn't account for McCoy now being scaled to ~1.83m tall (the character-
# scale fix landed in the same batch), so the pivot alone was already above
# head height before any camera offset; (2) the pitch flip then pushed the
# camera up and steeply down from there on top of that. Pulled back to
# just above eye height (~1.83m tall character, eye height ~1.7m) — pivot
# at the head/eye line rather than above it.
@export var height: float = 1.7
## Mouse-wheel zoom: how far each notch moves the camera, and how near / far it may go (metres).
@export var zoom_step: float = 0.3
@export var zoom_min: float = 0.06   # REV 326: 0.8 -> 0.45; REV 332: right in (Glen: "to the point where you don't see Spock's head")
## REV 332: closer than this the camera goes to the character's eyes (no shoulder offset) and the
## character's own body stops being drawn, so you look out through him.
@export var first_person_below: float = 0.32
## REV 326: where a room's camera starts (the old closest distance); the wheel can now come nearer.
@export var zoom_start: float = 0.8
@export var zoom_max: float = 9.0
@export var orbit_speed_keyboard: float = 1.8   # radians/sec
@export var orbit_speed_mouse: float = 0.004    # radians/pixel
@export var pitch_min: float = -0.6
@export var pitch_max: float = 0.8
@export var mouse_orbit_enabled: bool = true
## The camera is never allowed above this world height (set by scenes with a ceiling, so the camera can't poke through it).
@export var max_camera_height: float = 1000.0
## REV 99: the camera follows with a slight lag instead of being bolted to the character, so starting,
## stopping and turning feel smooth. Up/down is softer still, so steps and stairs don't jolt the view.
## Bigger = tighter. 0 = the old rigid follow.
@export var follow_smoothing: float = 14.0
@export var vertical_smoothing: float = 7.0
## REV 101: when walls push the camera in close, it eases up and over the right shoulder and looks a
## little ahead, instead of filling the screen with the back of the character's head.
@export var close_shoulder: float = 0.34   # metres to the side at the closest
@export var close_lift: float = 0.12       # and up
@export var close_start: float = 1.6       # starts below this distance from the pivot
## REV 137: rooms open with the camera zoomed all the way in (zoom_min). The mouse wheel still zooms out.
@export var start_zoomed_in: bool = true

var _yaw: float = 0.0
# Was +0.25 (way too steep — see height comment above). Much shallower now:
# camera sits only modestly above the pivot (distance * sin(0.08) ≈ 0.2m)
# for a gentle over-the-shoulder downward tilt instead of looking straight
# down at the top of McCoy's head.
var _pitch: float = 0.08
var _camera: Camera3D
var target: Node3D
var _cur_dist: float = 2.5
var _pivot := Vector3.INF      # where the camera orbits around (smoothed)
var _close := 0.0              # 0 = normal, 1 = pushed right in (smoothed)
var _side := -1.0              # how far over the shoulder there is room (smoothed; -1 = not worked out yet)

## True only while the right mouse button is held down — the sole condition
## under which mouse motion drives the orbit. Distinct from the engine-wide
## Input.get_mouse_mode() because this rig owns capture/release itself,
## scoped exactly to the drag gesture (see _unhandled_input below).
var _right_mouse_dragging: bool = false


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	# Locked spec: "the 3D world expands into ultrawide space rather than
	# stretching" — KEEP_HEIGHT holds vertical FOV fixed and lets horizontal
	# FOV grow with the window's aspect ratio (Hor+), so a wider window
	# reveals more scene instead of distorting it.
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	# Godot's default clip range (0.05 to 4000) leaves too little depth precision, so surfaces that
	# sit close together flicker as you move. A tighter range keeps them steady.
	_camera.near = 0.1
	_camera.far = 1200.0
	add_child(_camera)
	if start_zoomed_in:
		distance = clampf(zoom_start, zoom_min, zoom_max)
	_cur_dist = distance
	set_process(true)


## REV 576: the camera's height follows the player's eyes (sitting on the floor); off = back to standing.
var follow_eyes := false
var _stand_eyes := -1.0
var _eye_drop := 0.0
const EYE_FOLLOW_SPEED := 3.0

func set_follow_eyes(on: bool) -> void:
	if on and not follow_eyes and target != null:
		_stand_eyes = _eye_height(target.global_position)
	follow_eyes = on


## The target's eyes above its feet (metres), or -1 if it has no face.
func _eye_height(feet: Vector3) -> float:
	var face := CharacterFace.face_of(target)
	if face == null:
		return -1.0
	return face.focus_point("eyes").y - feet.y


func set_target(node: Node3D) -> void:
	# REV 580 (Glen: switched to Kirk and saw the inside of his head): first person hid only the person it
	# started on - show them again; the next frame hides the new target if still zoomed right in
	if node != target:
		_set_first_person(false)
	target = node


## Safety net: if the window loses focus while the right mouse button is
## still physically held (alt-tab mid-drag, a dialog stealing focus, etc.),
## release the capture anyway. Without this the cursor could stay hidden/
## captured with no InputEventMouseButton release ever arriving to clear it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _right_mouse_dragging:
			_right_mouse_dragging = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(delta: float) -> void:
	if target == null:
		return

	# REV 103: analogue on a stick (push further = turn faster), and the player's speed setting
	var turn := Input.get_action_strength("camera_orbit_left") - Input.get_action_strength("camera_orbit_right")
	if PadNav.any_open(get_tree()):
		turn = 0.0      # REV 214: the right stick steers the menu, not the camera
	if absf(turn) > 0.05:
		take_back_framing()     # REV 169: turning the camera ends a scan framing at once
	_yaw += turn * orbit_speed_keyboard * (GameSettings.camera_speed_keys / 100.0) * get_process_delta_time()
	if _camera.fov != float(GameSettings.camera_fov) and _camera.current:
		_camera.fov = float(GameSettings.camera_fov)

	_pitch = clamp(_pitch, pitch_min, pitch_max)

	# REV 137: the player moves on physics ticks, which don't line up with drawn frames. The player is
	# drawn smoothed between ticks (PlayerController), so the camera follows that smoothed position too;
	# following the raw one made a close camera judder against the character.
	var target_pos: Vector3 = target.global_position
	if target.is_physics_interpolated_and_enabled():
		target_pos = target.get_global_transform_interpolated().origin
	# REV 576 (Glen: sitting on the floor, the camera should come down with his eyes): while follow_eyes
	# is on, the pivot drops by however far his eyes are below where they were standing, eased
	var drop_want := 0.0
	if follow_eyes and _stand_eyes > 0.0:
		var eyes := _eye_height(target_pos)
		if eyes > 0.0:
			drop_want = maxf(0.0, _stand_eyes - eyes)
	_eye_drop = lerpf(_eye_drop, drop_want, 1.0 - exp(-EYE_FOLLOW_SPEED * delta))
	var want_pivot: Vector3 = target_pos + Vector3(0, height - _eye_drop, 0)
	# REV 381 (Glen, on engineering's upper level: "i can't swing the camera up or down much"): under a low
	# ceiling the pivot (head height) could sit at or above the ceiling, so every camera ray started inside it
	# and the camera jammed low. The pivot now stays HEADROOM_MARGIN under whatever is overhead.
	want_pivot.y = minf(want_pivot.y, _headroom(target_pos, height) - HEADROOM_MARGIN)
	if _pivot == Vector3.INF or follow_smoothing <= 0.0 or GameSettings.reduced_motion or _pivot.distance_to(want_pivot) > 8.0:
		_pivot = want_pivot      # first frame, rigid mode, or a teleport / new room: no glide
	else:
		var kh := 1.0 - exp(-follow_smoothing * delta)
		var kv := 1.0 - exp(-vertical_smoothing * delta)
		_pivot = Vector3(lerpf(_pivot.x, want_pivot.x, kh), lerpf(_pivot.y, want_pivot.y, kv), lerpf(_pivot.z, want_pivot.z, kh))
	# REV 169 (item 15): blend toward a held framing (the tricorder scan) and back
	_update_framing(delta)
	var fk := _frame_k
	var yaw := lerp_angle(_yaw, _fr_yaw, fk) if fk > 0.0 else _yaw
	var pitch := lerpf(_pitch, _fr_pitch, fk)
	var dist := lerpf(distance, _fr_dist, fk)
	var pivot: Vector3 = _pivot + _fr_shift * fk
	var offset := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)
	) * dist

	var dir: Vector3 = offset.normalized()
	var want: float = _clear_distance(pivot, dir, dist)
	# Pull in at once when something is in the way, ease back out when it clears.
	if want < _cur_dist:
		_cur_dist = want
	else:
		_cur_dist = minf(want, _cur_dist + 8.0 * delta)
	var cam_pos: Vector3 = pivot + dir * _cur_dist
	var look_at_point: Vector3 = pivot
	var closeness := clampf((close_start - _cur_dist) / maxf(close_start - 0.45, 0.01), 0.0, 1.0)
	if GameSettings.reduced_motion:
		closeness = 0.0
	_close = lerpf(_close, closeness, 1.0 - exp(-6.0 * delta))
	if _close > 0.01:
		var facing := -dir
		var right := facing.cross(Vector3.UP).normalized()
		var shift := right * close_shoulder * _close + Vector3.UP * close_lift * _close
		# only as far to the side as there is room
		var room_side := _side_room(cam_pos, shift.normalized(), shift.length()) if shift.length() > 0.001 else 0.0
		# REV 137: eased, so running past a pillar or a seat doesn't jolt the camera sideways
		# (quick to pull in, slower to swing back out)
		if _side < 0.0:
			_side = room_side
		else:
			var k := 18.0 if room_side < _side else 4.0
			_side = lerpf(_side, room_side, 1.0 - exp(-k * delta))
		shift = shift.normalized() * minf(_side, shift.length()) if shift.length() > 0.001 else Vector3.ZERO
		# REV 332: the shoulder offset slides away as the camera comes right in to the eyes
		shift *= clampf((_cur_dist - zoom_min) / maxf(first_person_below - zoom_min, 0.01), 0.0, 1.0)
		cam_pos += shift
		look_at_point = pivot + shift * 0.7 + Vector3(facing.x, 0.0, facing.z).normalized() * 0.8 * _close
	cam_pos.y = minf(cam_pos.y, max_camera_height)
	# REV 579 (Glen: McCoy missing from his own lines with Tuvall): only while this rig's camera is the one
	# drawing - zoomed right in, the body stayed hidden through conversations and cutscenes on other cameras
	_set_first_person(_cur_dist < first_person_below and _frame_k <= 0.0 and _camera.current)
	_camera.global_position = cam_pos
	_camera.look_at(look_at_point, Vector3.UP)
	_fade_people_near(cam_pos)


var _fp_on := false
var _fp_hidden: Array = []


## REV 579: another camera is taking over (a conversation, a cutscene) - show the character again now,
## not on the rig's next frame.
func release_first_person() -> void:
	_set_first_person(false)


## REV 332: hide / show the followed character's own meshes (the camera is inside his head).
func _set_first_person(on: bool) -> void:
	if on == _fp_on:
		# REV 580 (Glen: Kirk's head from the inside right after Episode 1's beam-in): the transporter fades
		# bodies in by switching their meshes on every frame, undoing the hiding - keep them hidden
		if on:
			for gi in _fp_hidden:
				if is_instance_valid(gi) and (gi as GeometryInstance3D).visible:
					(gi as GeometryInstance3D).visible = false
		return
	_fp_on = on
	if on and target != null:
		_fp_hidden.clear()
		for m in target.find_children("*", "GeometryInstance3D", true, false):
			var gi := m as GeometryInstance3D
			# REV 580: a body still being beamed in (hidden, made see-through by TransporterEffect) is part
			# of him too - the beam-in would switch it back on
			if gi.visible or gi.transparency > 0.0:
				gi.visible = false
				_fp_hidden.append(gi)
	else:
		for gi in _fp_hidden:
			if is_instance_valid(gi):
				(gi as GeometryInstance3D).visible = true
		_fp_hidden.clear()


## REV 581 (Glen: "when I get the angle right, I can see inside her head"): the camera doesn't bump into
## people (only walls - otherwise anyone walking behind you would shove it at your head), so whoever it
## comes this close to fades out: from FADE_START metres off their centre line, gone by FADE_GONE.
const PEOPLE_FADE_START := 0.60
const PEOPLE_FADE_GONE := 0.30
var _faded := {}    # figure -> [meshes, current fade 0-1]


func _fade_people_near(cam_pos: Vector3) -> void:
	var near := {}
	if _camera.current:
		for b in get_tree().get_nodes_in_group(CharacterBlocker.GROUP):
			var fig := (b as Node).get_parent() as Node3D
			if fig == null or not fig.is_visible_in_tree():
				continue
			if target != null and (fig == target or target.is_ancestor_of(fig) or fig.is_ancestor_of(target)):
				continue     # the player's own body: first person handles it
			var k := maxf(0.1, fig.global_transform.basis.get_scale().y)
			var feet := fig.global_position
			var y := clampf(cam_pos.y, feet.y, feet.y + CharacterBlocker.HEIGHT * k)
			var d := Vector2(cam_pos.x - feet.x, cam_pos.z - feet.z).length()
			d = maxf(d, absf(cam_pos.y - y))
			if d < PEOPLE_FADE_START * k:
				near[fig] = clampf((PEOPLE_FADE_START * k - d) / ((PEOPLE_FADE_START - PEOPLE_FADE_GONE) * k), 0.0, 1.0)
	for fig in near:
		if not _faded.has(fig):
			var meshes: Array = []
			for m in (fig as Node).find_children("*", "GeometryInstance3D", true, false):
				if (m as GeometryInstance3D).visible:
					meshes.append(m)
			_faded[fig] = [meshes, 0.0]
		_set_fade(fig, float(near[fig]))
	for fig in _faded.keys():
		if not near.has(fig):
			_set_fade(fig, 0.0)
			_faded.erase(fig)


func _set_fade(fig: Variant, f: float) -> void:
	var entry: Array = _faded[fig]
	if is_equal_approx(float(entry[1]), f):
		return
	entry[1] = f
	for m in entry[0]:
		if is_instance_valid(m):
			var gi := m as GeometryInstance3D
			gi.transparency = f
			gi.visible = f < 0.98


const HEADROOM_MARGIN := 0.22
var _head_clock := 0.0
var _head_cache := INF


## The height of whatever solid is overhead (world y), looked for up to height + 0.6 above the feet;
## INF if nothing. Re-measured every few frames (cheap enough, and the result moves slowly).
func _headroom(feet: Vector3, h: float) -> float:
	_head_clock -= get_process_delta_time()
	if _head_clock > 0.0 and _head_cache != INF and absf(_head_cache - feet.y) < 4.0:
		return _head_cache
	_head_clock = 0.1
	var space := get_world_3d().direct_space_state
	var from := feet + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(from, feet + Vector3.UP * (h + 0.6))
	q.collision_mask = 1
	q.exclude = _body_rids
	var hit: Dictionary = space.intersect_ray(q)
	_head_cache = (hit["position"] as Vector3).y if not hit.is_empty() and hit["collider"] is StaticBody3D else INF
	return _head_cache


## How far the camera can sit from the pivot along dir before a wall, floor or ceiling gets in the way.
## Only solid map geometry counts (static bodies); characters and trigger areas are ignored.
func _clear_distance(pivot: Vector3, dir: Vector3, wanted: float) -> float:
	var best: float = _ray_clear(pivot, dir, wanted)
	# A thin ray can slip through the cracks between a map's wall triangles, which let the camera
	# out beside a wall. A small ball swept along the same line cannot.
	var space := get_world_3d().direct_space_state
	if _bodies_dirty:
		_refresh_body_rids()
	var ball := SphereShape3D.new()
	ball.radius = 0.28
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = ball
	sq.transform = Transform3D(Basis.IDENTITY, pivot)
	sq.motion = dir * (wanted + 0.1)
	sq.collision_mask = 1
	sq.exclude = _body_rids
	var res: PackedFloat32Array = space.cast_motion(sq)
	if res.size() >= 2 and res[0] > 0.001 and res[0] < 1.0:
		best = minf(best, clampf(res[0] * (wanted + 0.1), 0.35, wanted))
	return best


var _body_rids: Array[RID] = []
var _body_clock: float = 0.0
## REV 681 (performance pass): the CharacterBody3Ds the camera ignores, kept up to date as they come and go -
## it used to search the whole scene for them every 30 frames (a small hitch twice a second on big decks).
var _bodies: Array[CharacterBody3D] = []
var _bodies_dirty := true
var _bodies_hooked := false


func _refresh_body_rids() -> void:
	if not _bodies_hooked:
		_bodies_hooked = true
		get_tree().node_added.connect(_on_tree_node_added)
		get_tree().node_removed.connect(_on_tree_node_removed)
		for b in get_tree().root.find_children("*", "CharacterBody3D", true, false):
			_bodies.append(b as CharacterBody3D)
	_bodies_dirty = false
	_body_rids.clear()
	for i in range(_bodies.size() - 1, -1, -1):
		if not is_instance_valid(_bodies[i]) or not _bodies[i].is_inside_tree():
			_bodies.remove_at(i)
			continue
		_body_rids.append(_bodies[i].get_rid())


func _on_tree_node_added(n: Node) -> void:
	if n is CharacterBody3D:
		if not _bodies.has(n):
			_bodies.append(n as CharacterBody3D)
		_bodies_dirty = true


func _on_tree_node_removed(n: Node) -> void:
	if n is CharacterBody3D:
		_bodies_dirty = true


## How far the camera can move sideways before a wall (with a 12 cm margin); 0 if none.
func _side_room(from: Vector3, dir: Vector3, wanted: float) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (wanted + 0.12))
	q.collision_mask = 1
	q.exclude = _body_rids
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return wanted
	return clampf(from.distance_to(hit["position"]) - 0.12, 0.0, wanted)


func _ray_clear(pivot: Vector3, dir: Vector3, wanted: float) -> float:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	var margin := 0.25
	for i in 6:
		var q := PhysicsRayQueryParameters3D.create(pivot, pivot + dir * (wanted + margin))
		q.collision_mask = 1
		q.exclude = exclude
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			return wanted
		if hit["collider"] is StaticBody3D:
			var d: float = pivot.distance_to(hit["position"]) - margin
			return clampf(d, 0.35, wanted)
		exclude.append(hit["rid"])
	return wanted


func _unhandled_input(event: InputEvent) -> void:
	# Mouse wheel: zoom in and out. Wheel-up brings the camera closer unless
	# GameSettings.invert_zoom is on (SYSTEM menu).
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var closer: bool = event.button_index == MOUSE_BUTTON_WHEEL_UP
		if GameSettings.invert_zoom:
			closer = not closer
		take_back_framing()
		distance = clampf(distance + (-zoom_step if closer else zoom_step), zoom_min, zoom_max)
		return

	if not mouse_orbit_enabled:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_right_mouse_dragging = event.pressed
		# Capture only for the drag's duration: hides the cursor and gives
		# unlimited relative motion (so spinning the camera doesn't hit the
		# edge of the window), then hands it straight back on release so
		# clicking HUD buttons etc. immediately after still works normally.
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if _right_mouse_dragging else Input.MOUSE_MODE_VISIBLE)
		return

	if event is InputEventMouseMotion and _right_mouse_dragging:
		take_back_framing()
		var mouse_speed := orbit_speed_mouse * (GameSettings.camera_speed_mouse / 100.0)
		_yaw -= event.relative.x * mouse_speed
		# GameSettings.invert_mouse_y flips only this vertical axis (what Glen
		# calls the orbit's "z-axis" — the drag axis that tilts the camera up/
		# down) via a SYSTEM-menu toggle; horizontal yaw is never affected.
		var vertical_sign := -1.0 if GameSettings.invert_mouse_y else 1.0
		_pitch -= event.relative.y * mouse_speed * vertical_sign
		_pitch = clamp(_pitch, pitch_min, pitch_max)


## Forward direction projected onto the horizontal plane, for movement
## relative to the camera (standard third-person control scheme).
func get_forward_flat() -> Vector3:
	var fwd := -_camera.global_transform.basis.z
	fwd.y = 0
	return fwd.normalized()


func get_right_flat() -> Vector3:
	var right := _camera.global_transform.basis.x
	right.y = 0
	return right.normalized()


## Orbit angles (yaw, pitch) for save/load.
func get_orbit() -> Vector2:
	return Vector2(_yaw, _pitch)


func set_orbit(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = clampf(pitch, pitch_min, pitch_max)


func get_camera() -> Camera3D:
	return _camera


# =========================================================================
# REV 169 (CLAUDE.md item 15): framing a moment - the tricorder scan
# =========================================================================
## A short, gentle glide to a side-on view of the character while he scans: his face, the tricorder
## in his hands and what he is scanning all in one picture. It eases back to the player's own camera
## when the scan ends. Touching the camera (turning, dragging, zooming) during it hands the camera
## straight back from where it is, with no jump. Reduced Motion cuts instead of gliding.

const FRAME_SIDE_DEG := 70.0     # how far round from straight in front of him the camera sits

var _frame_k := 0.0              # 0 = the player's own view, 1 = the framing
var _frame_to := 0.0
var _frame_secs := 0.7
var _fr_yaw := 0.0
var _fr_pitch := 0.0
var _fr_dist := 2.0
var _fr_shift := Vector3.ZERO    # moves the centre of the view (lower for kneeling, toward the target)


## Frame the target character scanning. `facing` is the way he faces (flat), `toward` is the
## thing being scanned (or Vector3.INF), `kneeling` lowers and steepens the view.
func frame_scan(facing: Vector3, toward: Vector3, kneeling := false, seconds := 0.7) -> void:
	if target == null or _camera == null or not _camera.current:
		return
	facing.y = 0.0
	if facing.length() < 0.01:
		return
	facing = facing.normalized()
	var right := facing.cross(Vector3.UP).normalized()
	var a := deg_to_rad(FRAME_SIDE_DEG)
	var dist := 1.7 if kneeling else 1.9
	var pivot := (_pivot if _pivot != Vector3.INF else target.global_position + Vector3(0, height, 0))
	# the centre of the picture: down toward his hands, and a little toward what he scans
	var shift := Vector3(0, -0.62 if kneeling else -0.32, 0)
	if toward != Vector3.INF:
		var flat := Vector3(toward.x - pivot.x, 0.0, toward.z - pivot.z)
		if flat.length() > 0.01:
			shift += flat.normalized() * minf(flat.length() * 0.35, 0.45)
	# his left side or his right: the one the camera is nearer, unless a wall is in the way there
	var cur := Vector3(sin(_yaw), 0, cos(_yaw))
	var best_dir := Vector3.ZERO
	var best := -INF
	for sgn in [-1.0, 1.0]:
		var d: Vector3 = facing * cos(a) + right * sin(a) * sgn
		var room := _clear_distance(pivot + shift, (d + Vector3.UP * 0.3).normalized(), dist)
		var score := cur.dot(d) + (0.0 if room > dist * 0.8 else -3.0) + room * 0.2
		if score > best:
			best = score
			best_dir = d
	_fr_yaw = atan2(best_dir.x, best_dir.z)
	_fr_pitch = 0.32 if kneeling else 0.16
	_fr_dist = dist
	_fr_shift = shift
	_frame_to = 1.0
	_frame_secs = maxf(seconds, 0.05)


## Ease back to the player's own camera.
func unframe(seconds := 0.8) -> void:
	_frame_to = 0.0
	_frame_secs = maxf(seconds, 0.05)


func is_framed() -> bool:
	return _frame_k > 0.001 or _frame_to > 0.0


## The player touched the camera during a framing: the framed view becomes their own view (no jump).
func take_back_framing() -> void:
	if _frame_k <= 0.0 and _frame_to <= 0.0:
		return
	var k := _frame_k
	_yaw = lerp_angle(_yaw, _fr_yaw, k)
	_pitch = clampf(lerpf(_pitch, _fr_pitch, k), pitch_min, pitch_max)
	distance = clampf(lerpf(distance, _fr_dist, k), zoom_min, zoom_max)
	_pivot += _fr_shift * k      # eases back to the normal centre through the usual follow smoothing
	_frame_k = 0.0
	_frame_lin = 0.0
	_frame_to = 0.0


var _frame_lin := 0.0            # linear progress; _frame_k is it eased

func _update_framing(delta: float) -> void:
	if GameSettings.reduced_motion:
		_frame_lin = _frame_to
	else:
		_frame_lin = move_toward(_frame_lin, _frame_to, delta / _frame_secs)
	_frame_k = smoothstep(0.0, 1.0, _frame_lin)
