extends CharacterBody3D
class_name PlayerController
## Third-person, directly-controlled McCoy. WASD/left-stick moves relative to
## the camera's flat forward/right (standard third-person scheme — this is
## NOT point-and-click; the mouse only participates in camera orbit and UI).

@export var move_speed: float = 4.0
## REV 158: McCoy WALKS by default and runs at move_speed while RUN (Shift) is held. On a stick a
## light push walks and a full push runs. walk_factor is the walking pace as a share of move_speed.
## REV 244 (Glen chose the Daz Relaxed walk at its natural pace): 0.45 -> 0.30, a third slower, the
## pace that walk was recorded at (MotionClips daz_walk_relaxed speed 0.653 vs Mixamo's 0.985).
@export var walk_factor: float = 0.30
## REV 158: how far the left stick must be pushed (0..1) before McCoy breaks into a run.
@export var stick_run_push: float = 0.85
@export var rotation_speed: float = 10.0
@export var interaction_range: float = 1.7
## Tallest step or kerb McCoy walks straight up without jumping (Godot's
## character body doesn't climb steps on its own). Stairs in the recreation
## deck are about 0.5 m per step.
@export var max_step_height: float = 0.75
## REV 373 (Glen: Spock standing on a console and on engineering's dilithium chamber): false = never step up
## onto a map PROP (the Elite Force furniture models - chambers, chairs, beds, tables), only onto the map's
## own floors and stairs. Map rooms (ModelRoom) turn it off.
var step_onto_props := true
## REV 346: how many heights (up to max_step_height) the step-up check tries, lowest first.
const STEP_TRIES := 5

var camera_rig: OrbitCameraRig
var _interaction_area: Area3D
var _nearby_hotspots: Array[Hotspot] = []

## False during a non-interactive beat (e.g. the Opening Banter cutscene) —
## _physics_process becomes a no-op so the player can't walk/rotate while
## they're not actually supposed to have control yet.
var input_enabled: bool = true

## REV 155: true while the character performs an action (e.g. a tricorder scan): no walking, but -
## unlike input_enabled - nothing else saves and restores it (a conversation starting mid-scan saves
## input_enabled and puts it back afterwards, which would otherwise leave him frozen).
var held_still: bool = false

## How much bigger than normal this character is drawn (Episode 1 sets it); footsteps follow it.
var body_scale: float = 1.0

## Distance walked since the last footstep sound; one step every STEP_LENGTH metres.
const STEP_LENGTH := 1.7
var _step_distance: float = 0.0


## REV 48: FLY MODE (debug builds only). Shift+F turns it on and off. Walls and floors stop mattering, so you can
## look at parts of a map you cannot normally reach. WASD move the way the camera faces, PAGE UP / PAGE DOWN go up and
## down, SHIFT is faster. (Plain F is still "interact".)
var flying: bool = false
var _fly_layer: int = 1
var _fly_mask: int = 1
const FLY_SPEED := 8.0


func _unhandled_input(event: InputEvent) -> void:
	# REV 576 (Glen): X kneels him down and sits him back on his heels; X again (or walking) gets him up
	if input_enabled and not _auto_on and not flying and event.is_action_pressed("sit_floor") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if floor_sitting:
			stand_from_floor()
		else:
			sit_on_floor()
		return
	if not input_enabled or not OS.is_debug_build():
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F and k.shift_pressed:
		_set_flying(not flying)
		get_viewport().set_input_as_handled()


func _set_flying(on: bool) -> void:
	if on == flying:
		return
	flying = on
	velocity = Vector3.ZERO
	if on:
		_fly_layer = collision_layer
		_fly_mask = collision_mask
		collision_layer = 0
		collision_mask = 0
		MissionLog.notification_requested.emit("FLY MODE ON   WASD move, PgUp / PgDn up and down, Shift faster, Shift+F off")
	else:
		collision_layer = _fly_layer
		collision_mask = _fly_mask
		MissionLog.notification_requested.emit("FLY MODE OFF")


func _ready() -> void:
	# Stay glued to the floor when walking down steps instead of floating off them.
	floor_snap_length = max_step_height
	add_to_group("player")  # lets presentation-only code (minimap heading) find us
	# REV 147 (item 21): people are solid - collide with every character's blocker, and be one too
	# (so a walking NPC body bumps into the player rather than through them)
	collision_layer |= CharacterBlocker.LAYER
	collision_mask |= CharacterBlocker.LAYER
	_setup_interaction_area()
	_enable_smoothing()


## REV 137: the player moves 60 times a second (physics ticks), but the screen draws at its own rate, so
## some frames saw two steps and some none. Close up, running at the camera, that read as a judder.
## Godot can draw a body smoothed between its ticks; it's switched on here for the player body only
## (everything else in the game stays exactly as it was), and only while the player is steering, so
## cutscenes that place the player by script are never smoothed or delayed.
func _enable_smoothing() -> void:
	# REV 138: smoothing is switched on for the whole game in project.godot and off again for everything
	# at the root (PauseKey, the first autoload), before any room loads. Turning it on here, mid-game,
	# left the already-loaded deck drawn in the wrong place (REV 137's missing room).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


var _last_tick_pos := Vector3.INF

func _update_smoothing() -> void:
	var want := Node.PHYSICS_INTERPOLATION_MODE_ON if ((input_enabled or _auto_on) and not flying) else Node.PHYSICS_INTERPOLATION_MODE_OFF
	var jumped := _last_tick_pos != Vector3.INF and _last_tick_pos.distance_to(global_position) > 1.0
	if physics_interpolation_mode != want:
		physics_interpolation_mode = want
		reset_physics_interpolation()
	elif jumped and want == Node.PHYSICS_INTERPOLATION_MODE_ON:
		reset_physics_interpolation()     # moved by a script (a new room, a load): don't glide across


## Kirk/McCoy switching: only the character being played reacts to the
## controls and spots interactable things. The other just stands there.
## REV 772 (Glen: "I'm playing scotty, but on the minimap, it's showing my kyle"): the body the player is driving
## RIGHT NOW - the room's active_body when the room has two playable leads, otherwise the first in the "player" group.
## Anything that follows the player every frame (minimap, full map) asks this instead of keeping the first body it found.
static func current(tree: SceneTree) -> Node3D:
	var scene := tree.current_scene
	if scene != null:
		var ab: Variant = scene.get("active_body")
		if ab is Node3D and is_instance_valid(ab):
			return ab as Node3D
	return tree.get_first_node_in_group("player") as Node3D


func set_active(active: bool) -> void:
	if not active:
		_set_flying(false)
		cancel_auto_walk()
	input_enabled = active
	if _interaction_area == null:
		return
	_nearby_hotspots.clear()
	_interaction_area.set_deferred("monitoring", active)
	if active:
		# Re-announce whatever is already in reach once the physics step runs.
		await get_tree().physics_frame
		await get_tree().physics_frame
		for area in _interaction_area.get_overlapping_areas():
			if area is Hotspot and not _nearby_hotspots.has(area):
				_nearby_hotspots.append(area)
		_update_focus()
	else:
		velocity = Vector3.ZERO


# ---- REV 147 (items 22 and 29): walking the player somewhere by script ---------------------------
## Used by Approach: walking up to whatever was clicked (a console, the intercom, someone to talk
## to), and stepping back to a comfortable distance when a conversation starts too close.

signal auto_walk_finished(reached: bool)

var _auto_on := false
var _auto_target := Vector3.ZERO
var _auto_face := Vector3.INF
var _auto_backwards := false
var _auto_cancellable := false
var _auto_time := 0.0
var _auto_limit := 0.0
var _auto_last := Vector3.ZERO
var _auto_still := 0.0


func is_auto_walking() -> bool:
	return _auto_on


## Walk (at walking pace, never running) to `target` on the floor, then turn to face `face_point`
## (Vector3.INF: don't turn). Returns true once he's there; false if something blocked the way or,
## when `cancellable`, the player took over by moving. A short step back is taken backwards, still
## facing `face_point` - a person making a little room, not turning round and walking off.
func walk_to(target: Vector3, face_point: Vector3 = Vector3.INF, cancellable: bool = false) -> bool:
	if _auto_on:
		_end_auto(false)
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if flat.length() < 0.06:
		if face_point != Vector3.INF:
			await turn_to(face_point)
		return true
	_auto_target = target
	_auto_face = face_point
	_auto_cancellable = cancellable
	_auto_backwards = false
	if face_point != Vector3.INF and flat.length() < 0.8 * maxf(body_scale, 0.1):
		var to_face := Vector3(face_point.x - global_position.x, 0.0, face_point.z - global_position.z)
		_auto_backwards = to_face.length() > 0.01 and to_face.normalized().dot(flat.normalized()) < -0.3
	_auto_time = 0.0
	_auto_limit = flat.length() / maxf(move_speed * walk_factor, 0.1) + 1.5
	_auto_last = global_position
	_auto_still = 0.0
	velocity = Vector3.ZERO
	_auto_on = true
	var reached: bool = await auto_walk_finished
	if reached and face_point != Vector3.INF and is_inside_tree():
		await turn_to(face_point)
	return reached


## Stop a scripted walk where he is (walk_to returns false).
func cancel_auto_walk() -> void:
	if _auto_on:
		_end_auto(false)


## Turn on the spot to face a point (a quick, natural turn; returns when done).
func turn_to(point: Vector3, seconds: float = 0.3) -> void:
	var d := point - global_position
	if Vector2(d.x, d.z).length() < 0.01 or not is_inside_tree():
		return
	var to := rotation.y + wrapf(atan2(d.x, d.z) - rotation.y, -PI, PI)
	if absf(to - rotation.y) < 0.05:
		return
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "rotation:y", to, seconds)
	await t.finished


func _auto_step(delta: float) -> void:
	_auto_time += delta
	var to := _auto_target - global_position
	to.y = 0.0
	var d := to.length()
	if d < 0.06:
		_end_auto(true)
		return
	if _auto_time > _auto_limit:
		_end_auto(d < 0.25 * maxf(body_scale, 0.1))
		return
	if _auto_cancellable and _move_input().length() > 0.35:
		_end_auto(false)          # the player took over
		return
	var spd := move_speed * walk_factor
	if _auto_backwards:
		spd *= 0.7                # stepping back is slower
	var ease_zone := 0.35 * maxf(body_scale, 0.1)
	if d < ease_zone:
		spd *= maxf(d / ease_zone, 0.4)
	var dir := to / d
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	var look := dir
	if _auto_backwards:
		var f := Vector3(_auto_face.x - global_position.x, 0.0, _auto_face.z - global_position.z)
		if f.length() > 0.01:
			look = f.normalized()
	rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), rotation_speed * delta)
	velocity.y -= 9.8 * delta
	_try_step_up(delta)
	move_and_slide()
	_update_footsteps(delta)
	# blocked (a wall, someone in the way): give up rather than walk on the spot
	if global_position.distance_to(_auto_last) < spd * delta * 0.25:
		_auto_still += delta
	else:
		_auto_still = 0.0
	_auto_last = global_position
	if _auto_still > 0.35:
		var left := Vector2(_auto_target.x - global_position.x, _auto_target.z - global_position.z).length()
		_end_auto(left < 0.25 * maxf(body_scale, 0.1))


func _end_auto(reached: bool) -> void:
	_auto_on = false
	velocity.x = 0.0
	velocity.z = 0.0
	auto_walk_finished.emit(reached)


## REV 576: sitting on the floor (kneeling, back on his heels). While down or getting there he doesn't move;
## a push on the move keys gets him up.
var floor_sitting := false
var _sit_busy := false


func sit_on_floor() -> void:
	if floor_sitting or _sit_busy or not is_on_floor():
		return
	var an := CharacterKit.animator_of(self)
	if an == null or not an.has_motion():
		return
	if get_node_or_null("/root/PhaserControl") != null and PhaserControl.is_drawn():
		return
	_sit_busy = true
	velocity = Vector3.ZERO
	if camera_rig != null and camera_rig.has_method("set_follow_eyes"):
		camera_rig.set_follow_eyes(true)
	var d: float = an.kneel_sit()
	await get_tree().create_timer(maxf(d, 0.1), false).timeout
	floor_sitting = true
	_sit_busy = false


func stand_from_floor() -> void:
	if not floor_sitting or _sit_busy:
		return
	var an := CharacterKit.animator_of(self)
	_sit_busy = true
	floor_sitting = false
	if an != null:
		var d: float = await an.stand_from_heels()
		if camera_rig != null and camera_rig.has_method("set_follow_eyes"):
			camera_rig.set_follow_eyes(false)
		await get_tree().create_timer(maxf(d, 0.1), false).timeout
	elif camera_rig != null and camera_rig.has_method("set_follow_eyes"):
		camera_rig.set_follow_eyes(false)
	_sit_busy = false


func _move_input() -> Vector2:
	return Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward"))


func refresh_focus() -> void:
	_update_focus()


func _setup_interaction_area() -> void:
	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionDetector"
	# Hotspots are placed on physics layer 2 (see BowlingAlley._make_hotspot).
	# This detector doesn't need to be detected by anything itself — only to
	# detect layer-2 hotspots — so layer is cleared and mask targets layer 2.
	_interaction_area.collision_layer = 0
	_interaction_area.collision_mask = 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = interaction_range
	shape.shape = sphere
	_interaction_area.add_child(shape)
	add_child(_interaction_area)
	_interaction_area.area_entered.connect(_on_area_entered)
	_interaction_area.area_exited.connect(_on_area_exited)


func _on_area_entered(area: Area3D) -> void:
	if area is Hotspot:
		_nearby_hotspots.append(area)
		_update_focus()


func _on_area_exited(area: Area3D) -> void:
	if area is Hotspot and _nearby_hotspots.has(area):
		_nearby_hotspots.erase(area)
		_update_focus()


## Nearest in-range hotspot becomes focused. Keyboard/controller-only and
## deliberately simple — no facing/line-of-sight requirement, so a player
## using digital movement input alone can always reach every interaction.
func _update_focus() -> void:
	if _nearby_hotspots.is_empty():
		InteractionManager.set_focus(null)
		return
	# REV 168 (item 32): the hotspot under the mouse pointer wins, if it is within reach
	var hov: Hotspot = InteractionManager.mouse_hover()
	if hov != null and _nearby_hotspots.has(hov):
		InteractionManager.set_focus(hov)
		return
	# REV 711 (Glen: you could pick things through walls - the evidence bag from the walkway, Cargo Bay 2 from the
	# briefing room): only what he can actually see from where he stands counts
	var nearest: Hotspot = null
	var nearest_dist := INF
	for h in _nearby_hotspots:
		if not is_instance_valid(h):
			continue
		# REV 727 (Glen: "Ullus isn't even in this room!"): a hidden or switched-off hotspot is never offered -
		# a hidden Area3D still counts as nearby, so Tuvall's office offered the Ullus who only comes for the demonstration
		if not h.is_visible_in_tree() or not h.monitorable or ("enabled" in h and not h.get("enabled")):
			continue
		var d := global_position.distance_to(h.global_position)
		# REV 741 (Glen: "a bug with EVERY hotspot though, they have too much diameter" - Kyle following behind
		# kept the prompt while Scotty stared at a wall): only what's in front of him, unless it's right at his
		# elbow; of those, the one he's looking at wins over one off to the side
		var to := h.global_position - global_position
		to.y = 0.0
		var facing := 1.0
		if to.length() > 0.05:
			facing = to.normalized().dot(Vector3(global_transform.basis.z.x, 0.0, global_transform.basis.z.z).normalized())
		if facing < FOCUS_MIN_FACING and to.length() > FOCUS_ELBOW * scale.y:
			continue
		var score := d * (1.6 - 0.6 * facing)
		if score < nearest_dist and _can_see(h):
			nearest = h
			nearest_dist = score
	InteractionManager.set_focus(nearest)


const FOCUS_MIN_FACING := 0.15     # REV 741: about 80 degrees either side of where he faces
const FOCUS_ELBOW := 0.8           # metres - this close, behind him still counts


## REV 711: a clear line from his chest to the hotspot - nothing solid (walls, floors, map pieces) in the way, or
## whatever is in the way is the thing itself (the line stops inside the hotspot's own box, 30 cm spare).
func _can_see(h: Hotspot) -> bool:
	var from := global_position + Vector3.UP * 1.3 * scale.y
	var to := h.global_position
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [get_rid()]
	q.hit_back_faces = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	var col: Object = hit.get("collider")
	if col is Node and (col as Node).is_in_group("see_through"):
		return true
	var local := h.to_local(hit["position"])
	for c in h.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			var half: Vector3 = ((c as CollisionShape3D).shape as BoxShape3D).size * 0.5 + Vector3.ONE * 0.3
			var p := local - (c as CollisionShape3D).position
			return absf(p.x) <= half.x and absf(p.y) <= half.y and absf(p.z) <= half.z
	return from.distance_to(hit["position"]) > from.distance_to(to) - 0.4


var _focus_tick := 0

func _physics_process(delta: float) -> void:
	_update_smoothing()
	_last_tick_pos = global_position
	# REV 711: what's in reach and in sight changes as he walks - looked at again a few times a second
	_focus_tick += 1
	if _focus_tick >= 8:
		_focus_tick = 0
		if input_enabled and not _nearby_hotspots.is_empty():
			_update_focus()
	if _auto_on:
		_auto_step(delta)
		return
	if not input_enabled or held_still:
		return
	if flying:
		_fly(delta)
		return

	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	# REV 214 (Nikki): steering a menu with the stick/d-pad doesn't walk McCoy about as well
	if PadNav.any_open(get_tree()):
		input_dir = Vector2.ZERO
	# REV 576: on the floor (or on the way down / up) he stays put; a push to walk gets him up
	if floor_sitting or _sit_busy:
		if floor_sitting and input_dir.length() > 0.3:
			stand_from_floor()
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y -= 9.8 * delta
		move_and_slide()
		return

	# Both mouse buttons held = walk forward in the direction the camera (and
	# therefore McCoy, since rotation below follows movement direction) is
	# facing — the classic WoW/KOTOR mouse-walk scheme, layered on top of
	# WASD/stick rather than replacing it. Forward takes priority over a
	# simultaneous S/move_back press rather than the two cancelling out.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		input_dir.y = -1.0

	var direction := Vector3.ZERO
	if camera_rig != null:
		direction = camera_rig.get_forward_flat() * -input_dir.y + camera_rig.get_right_flat() * input_dir.x
	else:
		direction = Vector3(input_dir.x, 0, input_dir.y)

	if direction.length_squared() > 0.001:
		direction = direction.normalized()
		var spd := move_speed * (1.0 if _wants_run() else walk_factor)
		velocity.x = direction.x * spd
		velocity.z = direction.z * spd

		var target_angle := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)

	velocity.y -= 9.8 * delta
	_try_step_up(delta)
	move_and_slide()
	_update_footsteps(delta)


## REV 158: walking is the default. Holding RUN (Shift, or whatever it is rebound to) runs; on a
## gamepad a full push of the left stick runs and a lighter push walks.
func _wants_run() -> bool:
	if InputMap.has_action("run") and Input.is_action_pressed("run"):
		return true
	var stick := 0.0
	for d in Input.get_connected_joypads():
		stick = maxf(stick, Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y)).length())
	return stick >= stick_run_push


## Footstep sounds: one per STEP_LENGTH metres of walking on the floor. The
## surface comes from the name of the floor collider (see SfxManager).
func _update_footsteps(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or speed < 0.6:
		_step_distance = STEP_LENGTH * body_scale * 0.5   # the first step lands soon after starting
		return
	_step_distance += speed * delta
	# REV 129: a walking step is shorter than a running one (matches the animations' feet)
	var step_len := lerpf(0.93, STEP_LENGTH, clampf((speed / maxf(body_scale, 0.01) - 2.2) / 1.3, 0.0, 1.0))
	if _step_distance < step_len * body_scale:
		return
	_step_distance = 0.0
	var floor_collider: Object = null
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if hit.get_normal().y > 0.7:
			floor_collider = hit.get_collider()
			break
	SfxManager.footstep(SfxManager.surface_for_collider(floor_collider))


## If the way ahead is blocked by something no taller than max_step_height
## (a step, a kerb, a seating riser) and there's flat ground on top, lift McCoy
## onto it so the normal movement can carry on over it.
func _try_step_up(delta: float) -> void:
	if not is_on_floor():
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z) * delta
	if flat.length() < 0.0005:
		return
	# Look a little further ahead than one frame so the check is reliable.
	var ahead := flat.normalized() * maxf(flat.length(), 0.12)
	if not test_move(global_transform, ahead):
		return  # nothing in the way
	# REV 346 (Glen: Spock couldn't get from the last step onto the transporter platform): the check used
	# to lift him the full max_step_height first, so a low overhang above a short step (the chamber's
	# top lip over the platform's edge) counted as "no room to step up" and he stopped dead. Now it tries
	# small lifts first and only as high as it needs: the first lift that clears the obstacle wins.
	for i in STEP_TRIES:
		var lift: float = max_step_height * float(i + 1) / STEP_TRIES
		var up := Vector3.UP * lift
		if test_move(global_transform, up):
			return  # a low ceiling above: nowhere to step up to
		var raised := global_transform.translated(up)
		if test_move(raised, ahead):
			continue  # still blocked at this height: try a little higher
		var landing := raised.translated(ahead)
		var hit := KinematicCollision3D.new()
		if test_move(landing, Vector3.DOWN * lift, hit):
			var drop: float = hit.get_travel().length()
			var rise: float = lift - drop
			if rise > 0.02 and hit.get_normal().y > 0.7 and _may_step_onto(hit) and _room_to_stand(landing, ahead, lift, rise):
				global_position.y += rise + 0.01
		return


## REV 368 (Glen: "it allows kirk to get up the rails! HE'LL HURT HIMSELF"): a step is only a step if
## there is somewhere to stand on it. A body-radius further on from the landing, at the same raised
## height, there must be floor about as high (or the way on is blocked - the next riser of a staircase,
## a wall at the top). A rail or a narrow ledge drops away again there, so it isn't climbed.
func _room_to_stand(landing: Transform3D, ahead: Vector3, lift: float, rise: float) -> bool:
	var on := ahead.normalized() * _body_radius()
	if test_move(landing, on):
		return true            # blocked further on: a higher step, or a wall - a real step
	# a thin ray straight down there (a body shape would catch the rail's own edge)
	var foot_y := global_position.y + rise          # where the feet would stand on the step
	var from := landing.origin + on + Vector3.UP * 0.05
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (lift + 0.3), 1)    # the world only, not people
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return false           # nothing under there: a thin edge
	return (hit["position"] as Vector3).y > foot_y - 0.06


## REV 373: what the feet would land on - a map prop (its collision body hangs off a MeshInstance3D named
## PROP_...) is furniture, not a step, unless step_onto_props.
## REV 641 (Glen: Spock standing on a chair in Auxiliary Control - "he shouldn't be allowed to do that"): the maps'
## OWN furniture (all of a map's chairs are one mesh, e.g. models_mapobjects_tos_tos_chair) counts too.
const FURNITURE_WORDS := ["chair", "stool", "table", "desk", "bench", "couch", "sofa", "_bed"]
const STEP_WORDS := ["podium", "platform", "dais", "_step"]

func _may_step_onto(hit: KinematicCollision3D) -> bool:
	if step_onto_props:
		return true
	var n: Node = hit.get_collider() as Node
	for _i in 3:
		if n == null:
			return true
		var nm := String(n.name).to_lower()
		# REV 741 (Glen: "i can't walk over that middle platform in front of the chair" - the bridge's command
		# platform is part of a map prop, PROP_2_aehelm_m0, with the helm on it): a room can say a prop's top at
		# a given height is floor (ModelRoom.STEP_TOPS) - the platform, not the console standing on it
		var room := get_tree().current_scene
		if room != null and room.has_method("prop_floor_at") and bool(room.call("prop_floor_at", nm, hit.get_position().y)):
			return true
		for w in STEP_WORDS:
			if nm.contains(w):
				return true
		if nm.begins_with("prop_"):
			return false
		for w in FURNITURE_WORDS:
			if nm.contains(w):
				return false
		n = n.get_parent()
	return true


## The radius of this body's own collision shape (world metres).
func _body_radius() -> float:
	for c in get_children():
		var cs := c as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var s := cs.global_transform.basis.get_scale().x
		if cs.shape is CapsuleShape3D:
			return (cs.shape as CapsuleShape3D).radius * s
		if cs.shape is CylinderShape3D:
			return (cs.shape as CylinderShape3D).radius * s
		if cs.shape is SphereShape3D:
			return (cs.shape as SphereShape3D).radius * s
	return 0.25


## REV 48: moving in fly mode. No gravity, no collision: the camera's flat forward / right, plus up and down.
func _fly(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	var dir := Vector3.ZERO
	if camera_rig != null:
		dir = camera_rig.get_forward_flat() * -input_dir.y + camera_rig.get_right_flat() * input_dir.x
	else:
		dir = Vector3(input_dir.x, 0.0, input_dir.y)
	if Input.is_physical_key_pressed(KEY_R) or Input.is_physical_key_pressed(KEY_PAGEUP):
		dir += Vector3.UP
	if Input.is_physical_key_pressed(KEY_V) or Input.is_physical_key_pressed(KEY_PAGEDOWN):
		dir += Vector3.DOWN
	if dir.length_squared() < 0.001:
		return
	var speed := FLY_SPEED * (3.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	global_position += dir.normalized() * speed * delta
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), rotation_speed * delta)
