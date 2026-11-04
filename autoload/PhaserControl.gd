extends Node
## REV 562 (Glen): "Can we always have that worn, please? When you hit Z, I want McCoy to whip it out and the
## cursor change to a crosshair. If you shoot a crew member, I want you to automatically be transferred to the
## brig with a game over."
##
## - Whoever you're playing always wears Glen's phaser on the belt (CharacterAnimator.wear_phaser).
## - Z (action phaser_toggle) draws it - the aim comes up - and the pointer becomes a crosshair; Z again
##   holsters it. Only in free play: never in conversations, cutscenes or menus (it holsters itself then).
## - Left click while drawn fires: the player turns to the point, a beam from the muzzle, the TOS whine.
##   Hit a PERSON (anyone with a body - crew, captain, anyone) -> they glow, the screen fades, and it's the
##   brig and GAME OVER (core/ui/cutscene/BrigGameOver.gd). Anything else: a harmless scorch flash.
## - A room can say no: give it `func phaser_allowed() -> bool` returning false (away missions, the
##   Bird-of-Prey, Fury - Glen: "we'll think about all the rest of that later"). A room can also take over
##   what a hit person means with `func phaser_hit(person: Node3D) -> bool` (true = handled, no brig).

const CROSSHAIR_PX := 40
const BEAM_COLOUR := Color(0.55, 0.75, 1.0)        # TOS stun blue-white
const BEAM_SECONDS := 0.45
const BRIG_SCENE := "res://core/ui/cutscene/BrigGameOver.tscn"
const SHOT_RANGE := 40.0
## Collision layers a shot can hit: the map (1), hotspots (2, people's talk boxes), character bodies (3).
const SHOT_MASK := 1 | 2 | 4

enum { HOLSTERED, DRAWING, DRAWN, HOLSTERING, FIRING, CAUGHT }
var _state := HOLSTERED
var _animator: CharacterAnimator = null
var _player: Node3D = null
var _crosshair: Texture2D = null
var _tick := 0.0
var _ready_at := 0.0
## Who was playing when the shot went home (for the brig scene).
var last_shooter := "mccoy"
var last_victim := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_crosshair = _make_crosshair()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.4
		_keep_worn()
	# never stay drawn into a conversation, a cutscene or a menu
	if (_state == DRAWN or _state == DRAWING) and not _free_play():
		holster()


## The player character always wears it (a new room, or a switch to the other lead, gets it too).
func _keep_worn() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		_player = null
		_animator = null
		return
	var an := CharacterKit.animator_of(p)
	if p != _player or an != _animator:
		if _state != HOLSTERED and _state != CAUGHT:
			_cursor(false)
			_state = HOLSTERED
		_player = p
		_animator = an
	if _animator != null and _animator.ready_to_animate and _allowed():
		_animator.wear_phaser(true)


func _allowed() -> bool:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("phaser_allowed"):
		return bool(scene.call("phaser_allowed"))
	return true


func _free_play() -> bool:
	if get_tree().paused or _player == null or _animator == null:
		return false
	if DialogueManager.is_busy() or InteractionManager.is_locked():
		return false
	if PadNav.any_open(get_tree()):
		return false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud is CanvasItem and not (hud as CanvasItem).visible:
		return false       # the HUD hides itself for cutscenes
	return _allowed()


func _input(event: InputEvent) -> void:
	if _state == CAUGHT:
		return
	if event.is_action_pressed("phaser_toggle") and not event.is_echo():
		if _state == DRAWN or _state == DRAWING:
			get_viewport().set_input_as_handled()
			holster()
		elif _state == HOLSTERED and _free_play():
			get_viewport().set_input_as_handled()
			draw()
		return
	# while it's drawn the left button fires (and the click never reaches the hotspots underneath)
	if _state == DRAWN or _state == DRAWING:
		var mb := event as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			if mb.pressed and _state == DRAWN and Time.get_ticks_msec() / 1000.0 >= _ready_at:
				_fire(mb.position)


func draw() -> void:
	if _animator == null:
		return
	_state = DRAWING
	var t := _animator.draw_phaser()
	SfxManager.play("phaser_draw", -6.0)
	_cursor(true)
	await get_tree().create_timer(maxf(t, 0.05), false).timeout
	if _state == DRAWING:
		_state = DRAWN
		_ready_at = Time.get_ticks_msec() / 1000.0


func holster() -> void:
	_cursor(false)
	if _animator == null or not is_instance_valid(_animator):
		_state = HOLSTERED
		return
	_state = HOLSTERING
	var t := _animator.holster_phaser()
	await get_tree().create_timer(maxf(t, 0.05), false).timeout
	if _state == HOLSTERING:
		_state = HOLSTERED


func is_drawn() -> bool:
	return _state == DRAWN or _state == DRAWING or _state == FIRING


# ---- firing -------------------------------------------------------------------------------------

func _fire(screen_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _player == null:
		return
	_state = FIRING
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	# REV 574 (Glen: "I had to shoot Spock about 8 times and nothing happened"): the first collider on the
	# line was often an invisible hotspot box or blocker in front of him. Now every person's body is tested
	# against the shot line, and only solid room geometry (not hotspot boxes) can stand in the way.
	var to := from + dir * SHOT_RANGE
	var wall := _cast(from, to, true)
	var wall_d: float = from.distance_to(wall["position"]) if not wall.is_empty() else INF
	var point: Vector3 = wall.get("position", to)
	var person: Node3D = null
	var aimed := _person_along(from, to)
	if not aimed.is_empty() and float(aimed["dist"]) < wall_d + 0.05:
		person = aimed["person"]
		point = aimed["point"]
	elif not wall.is_empty():
		person = _person_of(wall.get("collider") as Node)
	# turn to face it, then the shot
	if _player.has_method("turn_to"):
		_player.call("turn_to", point, 0.12)
	await get_tree().create_timer(0.14, false).timeout
	if not is_instance_valid(_animator):
		_state = HOLSTERED
		return
	var muzzle := _animator.phaser_muzzle()
	if muzzle == Vector3.INF:
		muzzle = _player.global_position + Vector3(0.0, 1.3, 0.0)
	SfxManager.play("phaser_fire", -3.0)
	_beam(muzzle, point)
	if person != null:
		await _caught(person, point)
		return
	_flash(point, 0.6)
	await get_tree().create_timer(0.3, false).timeout
	if _state == FIRING:
		_state = DRAWN


## The first thing along the line that isn't the player himself (`solid`: room geometry only - no
## hotspot boxes or other areas, and nothing on the character-blocker layer).
func _cast(from: Vector3, to: Vector3, solid := false) -> Dictionary:
	var space := _player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 if solid else SHOT_MASK)
	q.collide_with_areas = not solid
	var exclude: Array[RID] = []
	for i in 16:
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return {}
		var c := hit.get("collider") as Node
		if c != null and (c == _player or _player.is_ancestor_of(c)):
			exclude.append(hit["rid"])
			continue
		if solid and _is_invisible(c):
			exclude.append(hit["rid"])
			continue
		return hit
	return {}


## REV 574: an invisible wall or blocker (a body with nothing drawn on it or beside it) - shots pass it.
func _is_invisible(c: Node) -> bool:
	if c == null:
		return false
	var p := c.get_parent()
	if p is VisualInstance3D or c is VisualInstance3D:
		return false
	for n in c.get_children():
		if n is VisualInstance3D:
			return false
	if p != null:
		for n in p.get_children():
			if n is MeshInstance3D and (n as MeshInstance3D).visible:
				return false
	return true


## REV 574: the nearest person whose body the line passes through: {person, point, dist}, or {}.
## Bodies are the skinned meshes' boxes, trimmed a little at the sides so a near miss stays a miss.
func _person_along(from: Vector3, to: Vector3) -> Dictionary:
	var scene := get_tree().current_scene
	if scene == null:
		return {}
	var best := {}
	var seen := {}
	for sk in scene.find_children("*", "Skeleton3D", true, false):
		var person := _person_of(sk)
		if person == null or seen.has(person) or not (sk as Node3D).is_visible_in_tree():
			continue
		seen[person] = true
		var box := AABB()
		var first := true
		for m in (sk as Node).find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var b: AABB = mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		if first:
			continue
		var trim := Vector3(box.size.x * 0.15, 0.0, box.size.z * 0.15)
		box = AABB(box.position + trim, box.size - trim * 2.0)
		var at = box.intersects_segment(from, to)
		if at == null:
			continue
		var d := from.distance_to(at)
		if best.is_empty() or d < float(best["dist"]):
			best = {"person": person, "point": at, "dist": d}
	return best


## The person a collider belongs to (a hotspot holding a character model, a character's own body or
## blocker), or null for the room and its props.
func _person_of(c: Node) -> Node3D:
	var n := c
	var scene := get_tree().current_scene
	for i in 6:
		if n == null or n == scene:
			return null
		if n == _player:
			return null
		if n.has_meta("speaker_id"):
			return n as Node3D
		if n is Hotspot or n is CharacterBody3D or n is PhysicsBody3D:
			if not n.find_children("*", "Skeleton3D", true, false).is_empty():
				return n as Node3D
		n = n.get_parent()
	return null


func _caught(person: Node3D, point: Vector3) -> void:
	_state = CAUGHT
	_cursor(false)
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("phaser_hit") and bool(scene.call("phaser_hit", person)):
		_state = DRAWN
		return
	last_victim = String(person.get_meta("speaker_id", person.name))
	last_shooter = _player_id()
	# the stun: a blue glow over them, a stagger of light
	_flash(point, 1.4)
	var glow := OmniLight3D.new()
	glow.light_color = BEAM_COLOUR
	glow.omni_range = 1.6
	glow.light_energy = 0.0
	person.add_child(glow)
	glow.position = Vector3(0.0, 1.1, 0.0)
	var tw := create_tween()
	tw.tween_property(glow, "light_energy", 3.0, 0.15)
	tw.tween_property(glow, "light_energy", 0.0, 0.6)
	# fade to black, then the brig
	var layer := CanvasLayer.new()
	layer.layer = 110
	get_tree().root.add_child(layer)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(black)
	await get_tree().create_timer(0.9, false).timeout
	var fade := create_tween()
	fade.tween_property(black, "color:a", 1.0, 0.7)
	await fade.finished
	InteractionManager.reset_for_load()
	get_tree().paused = false
	get_tree().change_scene_to_file(BRIG_SCENE)
	await get_tree().process_frame
	await get_tree().process_frame
	layer.queue_free()
	_state = HOLSTERED
	_player = null
	_animator = null


## Who the player is (the speaker id on their figure), for the brig.
func _player_id() -> String:
	if _player == null:
		return "mccoy"
	if _player.has_meta("speaker_id"):
		return String(_player.get_meta("speaker_id"))
	for n in _player.find_children("*", "", true, false):
		if n.has_meta("speaker_id"):
			return String(n.get_meta("speaker_id"))
	return "mccoy"


# ---- the look -----------------------------------------------------------------------------------

func _beam(from: Vector3, to: Vector3) -> void:
	var len := from.distance_to(to)
	if len < 0.05:
		return
	var root := get_tree().current_scene as Node3D
	if root == null:
		return
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = len
	cyl.radial_segments = 8
	beam.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(BEAM_COLOUR.r, BEAM_COLOUR.g, BEAM_COLOUR.b, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = BEAM_COLOUR
	m.emission_energy_multiplier = 4.0
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	var mid := (from + to) * 0.5
	var up := (to - from).normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	beam.global_transform = Transform3D(Basis(side, up, side.cross(up)), mid)
	var glow := OmniLight3D.new()
	glow.light_color = BEAM_COLOUR
	glow.omni_range = 2.5
	glow.light_energy = 1.5
	beam.add_child(glow)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, BEAM_SECONDS).set_delay(0.12)
	tw.parallel().tween_property(glow, "light_energy", 0.0, BEAM_SECONDS).set_delay(0.12)
	tw.tween_callback(beam.queue_free)


func _flash(at: Vector3, energy: float) -> void:
	var root := get_tree().current_scene as Node3D
	if root == null:
		return
	var l := OmniLight3D.new()
	l.light_color = Color(0.75, 0.85, 1.0)
	l.omni_range = 1.2
	l.light_energy = energy
	root.add_child(l)
	l.global_position = at
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.35)
	tw.tween_callback(l.queue_free)


func _cursor(on: bool) -> void:
	if on:
		Input.set_custom_mouse_cursor(_crosshair, Input.CURSOR_ARROW, Vector2(CROSSHAIR_PX, CROSSHAIR_PX) * 0.5)
	else:
		Input.set_custom_mouse_cursor(null)


## A gold targeting reticle: a ring, four ticks and a centre dot, drawn once.
func _make_crosshair() -> Texture2D:
	var n := CROSSHAIR_PX
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(n, n) * 0.5
	var gold := Color(0.98, 0.82, 0.35, 1.0)
	var dark := Color(0, 0, 0, 0.75)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(c)
			var on := absf(d - 12.0) < 1.1
			var tick := (absf(p.x - c.x) < 1.0 and d > 14.0 and d < 19.0) or (absf(p.y - c.y) < 1.0 and d > 14.0 and d < 19.0)
			var dot := d < 1.8
			if on or tick or dot:
				img.set_pixel(x, y, gold)
			elif absf(d - 12.0) < 2.2 or d < 2.8:
				img.set_pixel(x, y, dark)     # a thin dark edge so it reads on light walls too
	return ImageTexture.create_from_image(img)
