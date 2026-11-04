extends Node3D
class_name EpisodeRoom
## EpisodeRoom — the shared machinery for every Episode 1 location. Each room
## (TuvallOffice.gd, HoldingCell.gd, ...) extends this and only has to say:
##
##   * how big the room is and what furniture is in it   (build_room)
##   * what happens when you walk in                      (arrival)
##   * what each object / person does when used           (add_spot(...) handlers)
##
## This file provides everything else: Kirk and McCoy (switch with TAB), the
## camera, the HUD, subtitles/voice, choice menus, the Case File (press C),
## travel between rooms, saving and loading.
##
## Writing a scene in a room script looks like this:
##
##     await say("tuvall", "Ambassador Turian was found dead two hours ago.")
##     var pick: int = await choose(["Where was he found?", "Why me?"])
##     Case.add("DEATH_LOCATION")
##
## Voice: every spoken line gets a stable ID made from the speaker and the words
## (see Ep1.line_id). If a recording with that name exists in
## episodes/episode1/audio/speech/<speaker folder>/ it plays; otherwise the
## subtitle alone shows for a reading-length pause.

const WALL_THICKNESS := 0.3

# ---- room description (override in each room) ------------------------------------
## REV 120: the episode this room belongs to - its rooms, speakers, flags, objectives, clock and
## deductions. Episode One's rooms leave it as Ep1; a later episode's rooms set it first thing:
##     func _init() -> void:
##         ep = Ep2
## (see episodes/_template/ and docs/NEW_EPISODE.md). Everything below goes through `ep`.
var ep: Variant = Ep1


## "EP1", "EP2"... - the start of this episode's saved names (its script's PREFIX, else EP1).
func ep_prefix() -> String:
	var consts: Dictionary = (ep as Script).get_script_constant_map() if ep is Script else {}
	return String(consts.get("PREFIX", "EP1"))
var room_key: String = "office"
var room_size: Vector3 = Vector3(10.0, 3.4, 8.0)   # width (x), height (y), depth (z)
var floor_color: Color = Color(0.46, 0.34, 0.24)
var wall_color: Color = Color(0.62, 0.45, 0.30)
var ceiling_color: Color = Color(0.36, 0.28, 0.22)
var ambient_color: Color = Color(0.82, 0.70, 0.58)
var ambient_energy: float = 0.75
var kirk_start: Vector3 = Vector3(-1.0, 0.05, 2.5)
var mccoy_start: Vector3 = Vector3(1.0, 0.05, 2.5)
## Both Kirk and McCoy are in the room and the player may swap between them.
var allow_switching: bool = true

## Outdoor rooms (desert, city edge): no ceiling or walls, a sky colour, a sun,
## invisible boundaries, and a camera that can rise high.
var outdoor: bool = false
## REV 871: Shi'Kahr's warm plaster-and-timber interiors (AdobeLook) - set true in describe_room().
var adobe_look: bool = false
var sky_color: Color = Color(0.80, 0.54, 0.38)
var sun_color: Color = Color(1.0, 0.88, 0.70)
var sun_energy: float = 1.5
## Which of the two the player controls when the room opens. REV 293: now actually used. "" (the
## default, every Episode 1 room) = whoever was being played last (the saved <PREFIX>_ACTIVE_CHAR).
## A room that sets it ("mccoy" / "kirk") AND doesn't allow switching starts a new arrival with that
## slot instead - e.g. Episode 2's rooms always start on Spock, even if Chapel was played last.
## (A loaded save always keeps whoever was being played when it was made.)
var default_character: String = ""

# ---- running state ------------------------------------------------------------------
var camera_rig: OrbitCameraRig
var kirk_body: PlayerController
var mccoy_body: PlayerController
var active_body: PlayerController

## REV 29: one physical metre. The maps are built at 0.03 m per map unit (a lift's handle rail is 41 units = 1.23 m up,
## a standard 56-unit person is 1.68 m), so the kit's 1.8 m figure is scaled to Kirk's 1.70 m, not by a guessed factor.
## Collision, camera, speed, reach and footsteps follow it.
const CHAR_SCALE := 1.70 / 1.80
var current: String = "mccoy"
## REV 268: who fills the two playable slots. The slots keep their names ("kirk", "mccoy") everywhere in
## the room code and the saves; this is who is actually drawn, named and heard in them. Episode 1 leaves
## it as Kirk and McCoy. A later episode's room sets it in _init() - Episode 2:
##     lead_people = {"kirk": "chapel", "mccoy": "spock"}
var lead_people := {"kirk": "kirk", "mccoy": "mccoy"}

## The person in a playable slot ("kirk" / "mccoy" -> e.g. "spock").
func lead(slot: String) -> String:
	return String(lead_people.get(slot, slot))


## The short name of the person in a slot, for the HUD ("Kirk", "Spock", "Chapel").
func lead_name(slot: String) -> String:
	var who := lead(slot)
	var info: Array = ep.SPEAKERS.get(who, [who, who.capitalize()])
	return String(info[1])

var ui_canvas: CanvasLayer
var hud: Control
var menu: ChoiceMenu
var case_ui: CaseFileUI
var partner_spot: SpotHotspot = null
var _fade: ColorRect
var _banner: Label
var _clock_label: Label
var _hint: Label
var _busy: bool = false
var _control_begun: bool = false
var _leaving: bool = false


# =========================================================================
# Startup
# =========================================================================

func _ready() -> void:
	var loaded: Dictionary = SaveSystem.take_pending_load()
	if not loaded.is_empty():
		SaveSystem.restore_game_state(loaded)
		# REV 293: a save brings its own Mission Log and objective (laid back on in _restore_from_save);
		# clear what this session had first, so another episode's entries don't hang about in the LOG
		MissionLog.reset()
		ObjectiveManager.reset()
	describe_room()
	Case.silent = not case_file_on()     # REV 476
	ep.ensure_state()
	EquipmentManager.setup_episode_equipment()   # REV 300: every lead's own tricorder + communicator
	_setup_environment()
	build_shell()
	build_room()
	if adobe_look and not outdoor:
		AdobeLook.apply(self, room_size)     # REV 871: Shi'Kahr's guest rooms
	build_shared()   # REV 666: what every room on the deck gets (ModelRoom/MapRoom)
	_setup_characters(loaded)
	CompanionManager.clear()
	CompanionManager.register_member("kirk", kirk_body, ["command", "diplomacy"])
	CompanionManager.register_member("mccoy", mccoy_body, ["medical", "tricorder"])
	_setup_ui()
	InteractionManager.communicator_handler = Callable(self, "_on_communicator_opened")     # REV 490
	SaveSystem.scene_state_provider = Callable(self, "_collect_save_state")
	SaveSystem.busy_reason_provider = Callable(self, "_save_busy_reason")
	_start(loaded)


## REV 476 (the redesign): does this room's episode still put a Case File on screen? An episode says
## no with `const CASE_FILE := false` (Episode 1 since REV 476). Then: no C key, no CASE FILE key on the
## console bar, no clue pop-ups, and the characters make the connections and deductions themselves
## after each scene (_auto_reason).
func case_file_on() -> bool:
	var consts: Dictionary = (ep as Script).get_script_constant_map() if ep is Script else {}
	return bool(consts.get("CASE_FILE", true))


## The HUD asks (REV 475): hide the console bar's CASE FILE key when there's no Case File.
func hud_case_file() -> bool:
	return case_file_on()


## Rooms set room_key, room_size, colours, start positions here.
func describe_room() -> void:
	pass


## Rooms put furniture, hotspots and NPCs here.
## REV 666: runs right after build_room() - what every room on the same deck gets (ModelRoom fills it in).
func build_shared() -> void:
	pass


func build_room() -> void:
	pass


## Runs once when the room opens normally (not when a save is loaded): an entry
## scene, a prompt, an objective. Control is given back when it returns.
func arrival() -> void:
	pass


## REV 227: true while this room was arrived at by transporter (set before arrival() runs).
var beaming_in := false


## Where Kirk and McCoy materialise when they beam into this room: who -> [position, point to face].
## Rooms override it; the default is where they would normally start.
func beam_in_spots() -> Dictionary:
	var ahead := Vector3(0.0, 0.0, -room_size.z * 0.5)
	return {"kirk": [kirk_start, ahead], "mccoy": [mccoy_start, ahead]}


## Anyone else who beams in with them (already placed by build_room), e.g. Spock.
func beam_in_others() -> Array:
	return []


## Runs once they are solid, before arrival() (Spock walking to his place, say).
func after_beam_in() -> void:
	pass


## The arrival half of the transport: the beam is covering the screen as the room starts; everyone
## who came down is hidden, the beam clears and they materialise where beam_in_spots() says.
func _beam_in() -> void:
	var spots := beam_in_spots()
	for who in ["kirk", "mccoy"]:
		if spots.has(who):
			var sp: Array = spots[who]
			teleport(who, sp[0], sp[1])
	var figures: Array = [kirk_body, mccoy_body]
	figures.append_array(beam_in_others())
	for f in figures:
		TransporterEffect.on(f).hide_now()
	await get_tree().process_frame
	TransporterEffect.play_sound()
	TransporterEffect.beam_in(figures, TransporterEffect.MAT_SECONDS, false)
	await TransporterEffect.screen_to(0.0, TransporterEffect.MAT_SECONDS * 0.45)
	await get_tree().create_timer(TransporterEffect.MAT_SECONDS * 0.6, false).timeout
	await after_beam_in()


## REV 336: true when this arrival's scene starts on black (a cutscene) - the room then doesn't fade
## up or show its name first. Rooms override it.
func opens_black() -> bool:
	return false


## REV 604: an arrival that carries straight on from the scene before, on the same picture (Episode 3's bridge,
## out of the teaser's dive): no fade, no black, no room name - arrival() sets up its first frame itself.
func opens_seamless() -> bool:
	return false


## Runs after a save is loaded into this room.
func after_load() -> void:
	pass


func _start(loaded: Dictionary) -> void:
	_set_active_character(_starting_character(), true)
	# REV 593: an episode whose two leads can be in different rooms (Episode 3: Scotty and Kyle) places them here
	if _script_has(ep, "room_opened"):
		ep.room_opened(self, not loaded.is_empty())
	if _script_has(ep, "refresh_tracker"):
		ep.refresh_tracker()     # REV 490: the one-line tracker (ticks, live text) matches the story
	if not loaded.is_empty():
		_restore_from_save(loaded)
		if _script_has(ep, "refresh_tracker"):
			ep.refresh_tracker()
		_fade_in()
		_show_banner()
		_end_scene()
		_control_begun = true
		after_load()
		return
	# New arrival: fade up from black and play whatever the room opens with.
	# REV 227: or, beamed down (the transporter's beam is covering the screen), materialise here.
	beaming_in = TransporterEffect.pending_arrival
	TransporterEffect.pending_arrival = false
	if beaming_in:
		_fade.modulate.a = 0.0
		_begin_scene()
		await _beam_in()
		_show_banner()
	elif opens_seamless():
		_fade.modulate.a = 0.0
		_begin_scene()
	elif opens_black():
		# REV 336: an arrival scene that starts on black (a cutscene): no fade-up, no room name
		fade_black()
		_begin_scene()
		await get_tree().create_timer(0.6, false).timeout
	else:
		_fade_in()
		_show_banner()
		_begin_scene()
		await get_tree().create_timer(0.6, false).timeout
	await arrival()
	if _leaving:
		return    # REV 277: the arrival scene moved on to another room - no autosave of a room being left
	if _script_has(ep, "after_arrival"):
		await ep.after_arrival(self)     # REV 593: calls that come in as you arrive somewhere (Episode 3)
		if _leaving:
			return
	_end_scene()
	_control_begun = true
	SaveSystem.checkpoint("AUTO_SAVE_" + ep_prefix() + "_" + room_key.to_upper())


## REV 293: who is played when the room opens. Whoever was played last (saved), unless this room
## has its own default_character and doesn't let the player switch (see default_character).
## A loaded save puts its own back afterwards (_restore_from_save).
func _starting_character() -> String:
	var saved := String(GameState.get_var(ep_prefix() + "_ACTIVE_CHAR")) if GameState.has_var(ep_prefix() + "_ACTIVE_CHAR") else ""
	var valid := saved == "kirk" or saved == "mccoy"
	if default_character != "" and (not allow_switching or not valid):
		return default_character
	return saved


# =========================================================================
# Building blocks for rooms
# =========================================================================

func _setup_environment() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = sky_color if outdoor else Color(0.03, 0.02, 0.02)
	if outdoor:
		environment.fog_enabled = true
		environment.fog_light_color = sky_color
		environment.fog_density = 0.004
		var sun := DirectionalLight3D.new()
		sun.name = "Sun"
		sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
		sun.light_color = sun_color
		sun.light_energy = sun_energy
		sun.shadow_enabled = true
		add_child(sun)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = ambient_color
	environment.ambient_light_energy = ambient_energy
	if not outdoor and has_method("_apply_lighting"):
		environment.set_meta("_vf_ship", true)    # REV 640: a ship map room - LookEnhancer's ENHANCED look is a touch dimmer here
	env.environment = environment
	add_child(env)


## Floor, ceiling and four walls around a room centred on x = 0, z = 0 with the
## floor at y = 0.
func build_shell() -> void:
	if outdoor:
		_build_outdoor_shell()
		return
	var w := room_size.x
	var h := room_size.y
	var d := room_size.z
	var t := WALL_THICKNESS
	box("Floor", Vector3(0.0, -0.1, 0.0), Vector3(w + t * 2.0, 0.2, d + t * 2.0), floor_color)
	box("Ceiling", Vector3(0.0, h + 0.1, 0.0), Vector3(w + t * 2.0, 0.2, d + t * 2.0), ceiling_color)
	box("WallN", Vector3(0.0, h * 0.5, -d * 0.5 - t * 0.5), Vector3(w + t * 2.0, h, t), wall_color)
	box("WallS", Vector3(0.0, h * 0.5, d * 0.5 + t * 0.5), Vector3(w + t * 2.0, h, t), wall_color)
	box("WallW", Vector3(-w * 0.5 - t * 0.5, h * 0.5, 0.0), Vector3(t, h, d), wall_color)
	box("WallE", Vector3(w * 0.5 + t * 0.5, h * 0.5, 0.0), Vector3(t, h, d), wall_color)


## Ground plus invisible boundary walls (collision only, no ceiling).
func _build_outdoor_shell() -> void:
	var w := room_size.x
	var d := room_size.z
	box("Ground", Vector3(0.0, -0.1, 0.0), Vector3(w + 60.0, 0.2, d + 60.0), floor_color)
	for entry in [
		[Vector3(0.0, 3.0, -d * 0.5 - 0.5), Vector3(w + 2.0, 6.0, 1.0)],
		[Vector3(0.0, 3.0, d * 0.5 + 0.5), Vector3(w + 2.0, 6.0, 1.0)],
		[Vector3(-w * 0.5 - 0.5, 3.0, 0.0), Vector3(1.0, 6.0, d + 2.0)],
		[Vector3(w * 0.5 + 0.5, 3.0, 0.0), Vector3(1.0, 6.0, d + 2.0)],
	]:
		invisible_wall(entry[0], entry[1])


## A collision-only barrier (the player can't see it). Returns it so a room can
## remove it later (e.g. when a path is opened).
func invisible_wall(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Barrier"
	body.position = pos
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	add_child(body)
	return body


## REV 605: the wall behind a force field - it stops feet, but you can SEE through a force field, so the
## pointer, the name tags and the dialogue camera look straight through it (group "see_through", skipped by
## InteractionManager._hotspot_under_pointer, NameTags and ConversationPresenter._clear). Before this nobody
## behind a field could be named, pointed at or talked to (Glen, Episode 3 Deck 7).
func field_wall(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := invisible_wall(pos, size)
	body.name = "FieldBarrier"
	body.add_to_group("see_through")
	return body


## A solid coloured block. Returns the StaticBody3D.
## REV 753 (Glen: "put a random crew member under the force field for the moment"): a body lying on its back -
## a roster crew member (the same one every time for the same salt), laid flat with its middle at `middle`
## and its head toward `head_dir` (world), arms in at its sides, animator and face stopped, eyes shut, not
## solid, not a speaker. Turian's stand-in until his own model. Null (and the caller keeps its boxes) if the
## crew kit isn't in the project.
const BODY_LIE_RAISE := 0.11          # its middle this far above the surface it lies on (its own metres)
const BODY_ARMS_IN := 20.0            # degrees the arms come in from the standing rest toward the sides
const BODY_HEIGHT := 1.75             # metres from feet to the top of the head at scale 1

func lay_body(node_name: String, middle: Vector3, head_dir: Vector3, salt: String) -> Node3D:
	if not ResourceLoader.exists(CrewRoster.PEOPLE_CSV) or not ResourceLoader.exists(CrewLooks.KIT["male"]):
		return null
	var people: Array = CrewRoster.people_for("off_duty", 1, salt)
	if people.is_empty():
		people = CrewRoster.people_for("security", 1, salt)
	if people.is_empty():
		return null
	var fig := CrewLooks.make(String(people[0]), {"solid": false})
	if fig == null:
		return null
	fig.name = node_name
	add_child(fig)
	fig.remove_from_group("speakers")
	var hd := Vector3(head_dir.x, 0.0, head_dir.z).normalized()
	var side := hd.cross(Vector3.UP)
	var s := fig.scale.y
	var feet := Vector3(middle.x, middle.y, middle.z) - hd * (BODY_HEIGHT * 0.5 * s)
	fig.global_transform = Transform3D(Basis(side, hd, Vector3.UP) * Basis.from_scale(fig.scale), feet + Vector3.UP * (BODY_LIE_RAISE * s))
	var an := CharacterKit.animator_of(fig)
	if an != null:
		an.set_process(false)
		if an.ready_to_animate:
			an._restore()
			an._set_rot("head", 0.0, 0.0, 0.0)
			an._set_rot("ua_l", 0.0, 0.0, -BODY_ARMS_IN)
			an._set_rot("la_l", 0.0, 0.0, -BODY_ARMS_IN)
			an._set_rot("ua_r", 0.0, 0.0, BODY_ARMS_IN)
			an._set_rot("la_r", 0.0, 0.0, BODY_ARMS_IN)
	var face := CharacterFace.face_of(fig)
	if face != null:
		face.set_process(false)
		var shut: Array = [face.profile.blink_left, face.profile.blink_right] if face.profile != null else []
		for m in fig.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null:
				continue
			for k in mi.mesh.get_blend_shape_count():
				var nm := String(mi.mesh.get_blend_shape_name(k))
				for want in shut:
					if want != "" and nm.ends_with(String(want)):
						mi.set_blend_shape_value(k, 1.0)
	return fig


func box(node_name: String, pos: Vector3, size: Vector3, color: Color, solid: bool = true, glow: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	mesh_instance.material_override = mat
	body.add_child(mesh_instance)
	if solid:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
	add_child(body)
	return body


func omni(pos: Vector3, color: Color = Color(1.0, 0.86, 0.68), energy: float = 1.2, light_range: float = 7.0) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	add_child(light)
	return light


## A glowing panel (screen, window, strip light) with no collision.
func glow_panel(pos: Vector3, size: Vector3, color: Color, strength: float = 1.5) -> StaticBody3D:
	return box("Glow", pos, size, color, false, strength)


## REV 643: a picture hung flat on a wall (Glen's Auxiliary Control patch board): the picture on the front of a
## thin dark backing plate, `width` metres wide (its height follows the picture), facing `facing_y_degrees`
## (0 = toward +z, 90 = toward +x). Swap the picture with set_wall_picture(); light a lamp painted in it
## with picture_lamp().
func wall_picture(node_name: String, pos: Vector3, width: float, tex_path: String, facing_y_degrees: float = 0.0) -> MeshInstance3D:
	var tex: Texture2D = load(tex_path) if ResourceLoader.exists(tex_path) else null
	var aspect := 2.4
	if tex != null and tex.get_width() > 0:
		aspect = float(tex.get_width()) / float(tex.get_height())
	var h := width / aspect
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	root.rotation_degrees = Vector3(0.0, facing_y_degrees, 0.0)
	add_child(root)
	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width + 0.06, h + 0.06, 0.04)
	back.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.30, 0.32, 0.36)
	bmat.roughness = 0.8
	back.material_override = bmat
	back.position = Vector3(0.0, 0.0, -0.022)
	root.add_child(back)
	var pic := MeshInstance3D.new()
	pic.name = "Picture"
	var qm := QuadMesh.new()
	qm.size = Vector2(width, h)
	pic.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.75
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	pic.material_override = mat
	root.add_child(pic)
	return pic


func set_wall_picture(pic: MeshInstance3D, tex_path: String) -> void:
	if pic == null or not ResourceLoader.exists(tex_path):
		return
	(pic.material_override as StandardMaterial3D).albedo_texture = load(tex_path)


## A lamp painted in a wall_picture lit up: `uv` = where it is in the picture (0..1, left->right, top->bottom),
## `radius` as a share of the picture's width, `blink` = seconds per on/off (0 = steady). lamp_blink() changes it.
func picture_lamp(pic: MeshInstance3D, uv: Vector2, radius: float, color: Color, blink: float = 0.0) -> MeshInstance3D:
	var qs: Vector2 = (pic.mesh as QuadMesh).size
	var lamp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = qs.x * radius
	sm.height = qs.x * radius * 2.0
	lamp.mesh = sm
	lamp.scale = Vector3(1.0, 1.0, 0.45)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	lamp.material_override = mat
	lamp.position = Vector3(qs.x * (uv.x - 0.5), qs.y * (0.5 - uv.y), 0.003)
	pic.add_child(lamp)
	lamp_blink(lamp, blink)
	return lamp


func lamp_blink(lamp: MeshInstance3D, seconds: float) -> void:
	if lamp == null:
		return
	var old: Tween = lamp.get_meta("blink") if lamp.has_meta("blink") else null
	if old != null and old.is_valid():
		old.kill()
	lamp.visible = true
	if seconds <= 0.0:
		return
	var t := create_tween().bind_node(lamp).set_loops()
	t.tween_interval(seconds)
	t.tween_callback(func() -> void: lamp.visible = not lamp.visible)
	lamp.set_meta("blink", t)


## A wall-mounted label so the player can read what a door or console is.
## REV 711 (Glen: words "floating" in the air on the ship): plate = true mounts the words on a TOS-style plaque - a
## black plate with a thin bright rim, the words on it - so they read as a sign fixed to the thing, not floating text.
func sign_text(text: String, pos: Vector3, facing_y_degrees: float = 0.0, pixel_size: float = 0.004, plate: bool = false) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.rotation_degrees = Vector3(0.0, facing_y_degrees, 0.0)
	label.pixel_size = pixel_size
	label.modulate = Color(1.0, 0.9, 0.6)
	label.outline_size = 6
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	label.double_sided = true
	add_child(label)
	if plate:
		label.modulate = Color(0.95, 0.86, 0.45)
		label.outline_size = 0
		var lines := text.split("\n")
		var longest := 0
		for l in lines:
			longest = maxi(longest, l.length())
		var size := Vector2(float(longest) * 0.62 + 1.4, float(lines.size()) * 1.25 + 0.7) * float(label.font_size) * pixel_size
		var back := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = size
		back.mesh = qm
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.albedo_color = Color(0.03, 0.03, 0.035)
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		back.material_override = bm
		back.position = Vector3(0.0, 0.0, -0.004)
		label.add_child(back)
		var rim := MeshInstance3D.new()
		var rq := QuadMesh.new()
		rq.size = size + Vector2.ONE * 0.012
		rim.mesh = rq
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.albedo_color = Color(0.62, 0.63, 0.66)
		rm.cull_mode = BaseMaterial3D.CULL_DISABLED
		rim.material_override = rm
		rim.position = Vector3(0.0, 0.0, -0.006)
		label.add_child(rim)
	return label


## REV 742: a floating collector card (core/props/FloatingCard.gd) at pos, chest height - walk through it to take it.
## Nothing appears once the player already has it. reaction (optional, may await) runs after it's taken - a line from
## whoever's there; the first card the player ever takes also says where the collection lives.
func float_card(card_id: String, pos: Vector3, reaction: Callable = Callable()) -> FloatingCard:
	if CollectorCards.is_unlocked(card_id):
		return null
	var c := FloatingCard.make(card_id)
	c.position = pos
	add_child(c)
	c.collected.connect(func(_id: String) -> void: _card_taken(reaction))
	return c


func _card_taken(reaction: Callable) -> void:
	if CollectorCards.unlocked_count() == 1:
		await note(InputHints.fill("(A COLLECTOR CARD - one of a set hidden round the ship. Walk through them to collect them; your collection is under COLLECTION in the pause menu.)"), 3.4)
	if reaction.is_valid():
		await reaction.call()


## Adds an interactable. verbs is a subset of ["LOOK", "TALK", "USE"].
## handler is a function(verb: String, source: String) that may await dialogue.
func add_spot(id: String, display: String, pos: Vector3, size: Vector3, verbs: Array, handler: Callable) -> SpotHotspot:
	var spot := SpotHotspot.new()
	spot.hotspot_id = id
	spot.display_name = display
	spot.interaction_types.assign(verbs)
	spot.position = pos
	spot.room = self
	spot.handler = handler
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	spot.add_child(shape)
	spot.collision_layer = 2
	spot.collision_mask = 0
	spot.halo_center_offset = Vector3(0.0, maxf(size.y * 0.5, 0.2), 0.0)
	spot.halo_radius = clampf(maxf(size.x, size.z) * 0.5, 0.2, 0.8)
	# REV 300: SCAN on the verb wheel whenever the played character carries a tricorder (the tricorder is
	# universal - INTERACTION_MODEL.md), so a pad player never has to dig it out of the backpack first.
	# Only on things you can LOOK at (they already open the wheel) - a single-verb spot (a lever, a
	# panel) keeps working with one press. Doors turn it off (add_door).
	spot.scan_verb = verbs.has("LOOK")
	add_child(spot)
	return spot


## A person standing in the room, talkable. who = a CharacterKit.make_named name.
## Returns the spot (spot.get_node("Model") is the figure).
func add_npc(id: String, display: String, who: String, pos: Vector3, look_at: Vector3, verbs: Array, handler: Callable) -> SpotHotspot:
	display = GameNames.character(who, display)   # REV 144: rank + surname from the names table
	var spot := add_spot(id, display, Vector3(pos.x, 0.0, pos.z), Vector3(0.7, 1.8, 0.7), verbs, handler)
	spot.accepts_items = false      # REV 296: scanning a person doesn't start their conversation
	var model := CharacterKit.make_named(who, {"solid": true})
	model.name = "Model"
	model.scale = Vector3.ONE * CHAR_SCALE
	spot.add_child(model)
	var d := look_at - pos
	if Vector2(d.x, d.z).length() > 0.001:
		model.rotation.y = atan2(d.x, d.z)
	spot.halo_center_offset = Vector3(0.0, 1.0, 0.0)
	spot.halo_radius = 0.45
	return spot


## REV 511: a named story person on a crew-kit body (CrewRoster.STORY_PEOPLE / the roster - Kyle, Giotto, the
## Fizzbin engineers): the real Daz model if there is one, else their crew-kit face, else a red-shirt stand-in.
func add_crew_npc(id: String, display: String, who: String, pos: Vector3, look_at: Vector3, verbs: Array, handler: Callable) -> SpotHotspot:
	var spot := add_spot(id, GameNames.character(who, display), Vector3(pos.x, 0.0, pos.z), Vector3(0.7, 1.8, 0.7), verbs, handler)
	spot.accepts_items = false
	var fig: Node3D = null
	if CharacterKit.REAL_MODELS.has(who):
		fig = CharacterKit.make_named(who, {"solid": true})
	elif ResourceLoader.exists(CrewLooks.KIT["male"]):
		fig = CrewLooks.make(who)
		# REV 717: a role with no person of its own (every "crewman" guard) - a real roster crew member, one per spot
		if fig == null and CharacterKit.CREW_ROLES.has(who):
			fig = CharacterKit.crew_for_role(who, id, {"solid": true})
	if fig == null:
		fig = CharacterKit.make(CharacterKit.Body.ENT_PALE, {"uniform": CharacterKit.UNIFORM_RED, "pants": CharacterKit.PANTS_BLACK,
			"boots": CharacterKit.BOOTS_BLACK, "hair": Color(0.18, 0.12, 0.08), "solid": true})
	fig.name = "Model"
	fig.scale = Vector3.ONE * CHAR_SCALE
	fig.set_meta("speaker_id", who)
	spot.add_child(fig)
	var d := look_at - pos
	if Vector2(d.x, d.z).length() > 0.001:
		fig.rotation.y = atan2(d.x, d.z)
	spot.halo_center_offset = Vector3(0.0, 1.0, 0.0)
	spot.halo_radius = 0.45
	return spot


## REV 592: a story person's crew-kit body (CrewRoster.STORY_PEOPLE `body`) shown under another name and
## heard in another speaker's voice folder (`voice` - a key of ep.SPEAKERS). Episode 2's unnamed Enterprise
## computer specialist is Lieutenant Romaine's body, still called "Computer Specialist" and still voiced
## from Episode 2's ent_specialist folder (her name is first said in Episode 3).
func add_person_as(id: String, display: String, body: String, voice: String, pos: Vector3, look_at: Vector3, verbs: Array, handler: Callable) -> SpotHotspot:
	var spot := add_crew_npc(id, display, body, pos, look_at, verbs, handler)
	spot.display_name = display
	var fig := spot.get_node_or_null("Model")
	if fig != null:
		var info: Array = ep.SPEAKERS.get(voice, [voice])
		fig.set_meta("speaker_id", String(info[0]))
		fig.set_meta("display_name", display)
	return spot


## A doorway the player can use to travel to another room. The door is drawn on
## the wall at `pos` (the centre of the door panel).
func add_door(id: String, display: String, pos: Vector3, panel_size: Vector3, handler: Callable) -> SpotHotspot:
	glow_panel(pos, panel_size, Color(0.25, 0.55, 0.55), 0.8)
	var reach := Vector3(maxf(panel_size.x, 1.4), panel_size.y, maxf(panel_size.z, 1.4))
	var door := add_spot(id, display, pos, reach, ["USE"], handler)
	door.accepts_items = false      # REV 296: scanning a door doesn't open the travel menu
	door.scan_verb = false          # REV 300
	return door


# =========================================================================
# Characters
# =========================================================================

func _setup_characters(loaded: Dictionary) -> void:
	camera_rig = OrbitCameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.max_camera_height = room_size.y - 0.15
	camera_rig.distance = 2.8 * CHAR_SCALE
	camera_rig.height *= CHAR_SCALE
	camera_rig.zoom_min *= CHAR_SCALE
	camera_rig.zoom_start *= CHAR_SCALE
	camera_rig.zoom_max *= CHAR_SCALE
	add_child(camera_rig)

	kirk_body = _make_body("Kirk", lead("kirk"), kirk_start)
	mccoy_body = _make_body("McCoy", lead("mccoy"), mccoy_start)
	var look := Vector3(0.0, 0.0, -room_size.z * 0.5)
	kirk_body.rotation.y = atan2(look.x - kirk_start.x, look.z - kirk_start.z)
	mccoy_body.rotation.y = atan2(look.x - mccoy_start.x, look.z - mccoy_start.z)
	camera_rig.set_orbit(0.0, 0.1)   # camera on the +Z side, looking toward -Z

	# The character you are NOT playing can be talked to; this spot follows them.
	# REV 293: named after the room's episode (EP1_PARTNER, EP2_PARTNER...), not always Episode 1's
	partner_spot = add_spot(ep_prefix() + "_PARTNER", "", Vector3.ZERO, Vector3(0.9, 1.8, 0.9), ["TALK"], Callable(self, "_partner_handler"))
	partner_spot.halo_center_offset = Vector3(0.0, 0.2, 0.0)
	partner_spot.halo_radius = 0.4


func _make_body(body_name: String, who: String, start: Vector3) -> PlayerController:
	var body := PlayerController.new()
	body.name = body_name
	body.camera_rig = camera_rig
	var model := CharacterKit.make_named(who)
	model.scale = Vector3.ONE * CHAR_SCALE
	body.add_child(model)
	body.body_scale = CHAR_SCALE
	body.move_speed = 4.0 * CHAR_SCALE
	body.interaction_range = 2.0 * CHAR_SCALE     # REV 741 (Glen: hotspots reach too far): was 2.5
	body.max_step_height = 0.75 * CHAR_SCALE
	var shape_node := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8 * CHAR_SCALE
	# REV 365 (Glen couldn't get round the 80% bridge's upper walkway to Spock - its narrowest point, by the
	# science station, left 34 cm each side for a 33 cm-radius body): in a room drawn smaller than the map
	# (ModelRoom.ms(): the bridge, Deck 7 at 80%) the body's width follows it, down to 75%. 0.35 is wider
	# than a person (shoulders are ~0.23 either side), so at 80% (0.26 m) the arms still don't enter walls.
	var room_k := clampf(float(call("ms")), 0.75, 1.0) if has_method("ms") else 1.0
	capsule.radius = 0.35 * CHAR_SCALE * room_k
	shape_node.shape = capsule
	shape_node.position.y = 0.9 * CHAR_SCALE
	body.add_child(shape_node)
	body.position = start
	add_child(body)
	return body


var _item_sync_t := 0.0

func _process(delta: float) -> void:
	# REV 306: the backpack follows the story flags (Ep1.ITEMS) - checked twice a second
	_item_sync_t -= delta
	if _item_sync_t <= 0.0:
		_item_sync_t = 0.5
		if _script_has(ep, "sync_items"):
			ep.sync_items()
	if partner_spot != null and kirk_body != null and mccoy_body != null:
		var idle := body_of(other_character())
		partner_spot.global_position = idle.global_position + Vector3(0.0, 0.9, 0.0)
	_party_follow()
	_tag_along_tick(delta)
	_stuck_tick(delta)


# REV 862: someone who TAGS ALONG - not a lead, never played (Spock in Shi'Kahr and the desert, SPOCK ON VULCAN).
# They walk after whoever you're playing, along your own footsteps, a little further back than your partner, and
# stop when you stop. tag_along() makes them; tag_stay(true) leaves them where they are ("Wait here").
const TAG_BACK := 2.8          # metres of your path between you and them
const TAG_SPEED := 1.5
var tag_spot: SpotHotspot = null
var _tag_staying := false
var _tag_prints: Array = []


func tag_along(id: String, display: String, who: String, pos: Vector3, handler: Callable) -> SpotHotspot:
	tag_spot = add_npc(id, display, who, pos, pos + Vector3(0.0, 0.0, -1.0), ["TALK", "LOOK"], handler)
	tag_spot.position.y = pos.y
	var fig := tag_spot.get_node_or_null("Model") as Node3D
	if fig != null:
		CharacterBlocker.set_solid(fig, false)
		tag_spot.rotation.y += fig.rotation.y
		fig.rotation.y = 0.0
	_tag_prints.clear()
	_tag_prints.append(pos)
	_tag_staying = false
	return tag_spot


func tag_stay(stay: bool) -> void:
	_tag_staying = stay
	if not stay and tag_spot != null:
		_tag_prints.clear()
		_tag_prints.append(tag_spot.global_position)


func tag_following() -> bool:
	return tag_spot != null and tag_spot.visible and not _tag_staying


func _tag_along_tick(delta: float) -> void:
	if tag_spot == null or not is_instance_valid(tag_spot) or not tag_spot.visible or _tag_staying or active_body == null:
		return
	var lp := active_body.global_position
	if _tag_prints.is_empty() or Vector2(lp.x - _tag_prints[-1].x, lp.z - _tag_prints[-1].z).length() >= 0.25:
		_tag_prints.append(lp)
		while _tag_prints.size() > 400:
			_tag_prints.pop_front()
	# the point TAG_BACK metres back along the path
	var left := TAG_BACK * CHAR_SCALE
	var goal := lp
	var p := lp
	var found := false
	for k in range(_tag_prints.size() - 1, -1, -1):
		var q: Vector3 = _tag_prints[k]
		var seg := Vector2(p.x - q.x, p.z - q.z).length()
		if seg >= left:
			goal = p.lerp(q, left / maxf(seg, 0.0001))
			found = true
			break
		left -= seg
		p = q
	if not found:
		return     # you haven't walked far enough from them yet - they stay put
	var here := tag_spot.global_position
	var to := Vector3(goal.x - here.x, 0.0, goal.z - here.z)
	var dist := to.length()
	if dist < 0.05:
		return
	if dist > 25.0:
		tag_spot.global_position = goal     # you rode the transit (or similar): they catch up
		return
	var speed := TAG_SPEED * (1.0 + clampf((dist - 0.8) * 0.6, 0.0, 1.5))
	var stride := minf(dist, speed * delta)
	tag_spot.global_position = Vector3(here.x + to.x / dist * stride, goal.y, here.z + to.z / dist * stride)
	tag_spot.rotation.y = lerp_angle(tag_spot.rotation.y, atan2(to.x, to.z), 1.0 - exp(-6.0 * delta))


# REV 490: the stuck timer. If nothing has happened for STUCK_SECONDS of free play, the partner says the
# next line of THE PARTNER table unasked (once per quiet spell - any scene resets it).
const STUCK_SECONDS := 120.0
var _quiet := 0.0

func _stuck_tick(delta: float) -> void:
	if not _control_begun or _busy or _leaving or not _script_has(ep, "partner_stage"):
		return
	if InteractionManager.is_locked() or InteractionManager.is_modal_suspended() or (menu != null and menu.is_open()):
		return
	_quiet += delta
	if _quiet >= STUCK_SECONDS:
		# REV 524 (Glen: puzzles must make sense to a NEW player): the nudge comes back every STUCK_SECONDS
		# while nothing happens, each one plainer (the partner table's three levels), and the first one in an
		# episode also says out loud that the partner is there to ask.
		_quiet = 0.0
		run_scene(func(): await _stuck_nudge())


func _stuck_nudge() -> void:
	var hud := get_tree().get_first_node_in_group("hud")     # REV 528: the mission line comes back when you're stuck
	if hud != null and hud.has_method("peek_tracker"):
		hud.call("peek_tracker", 8.0)
	if not await partner_hint(true):
		return
	var key := ep_prefix() + "_HELP_TAUGHT"
	if GameState.has_var(key) and bool(GameState.get_var(key)):
		return
	var helper := _helper_name()
	if helper == "":
		return     # inside a meld (Spock thinks aloud): taught the next time there is someone to ask
	GameState.set_var(key, true)
	await note(InputHints.fill("(Stuck? Talk to " + helper + " any time - each time you ask, the hint gets plainer. Hold {highlight_hotspots} to see your mission and everything you can use.)"), 4.0)


## Who gives the hints right now, by name (the partner table's speaker, or the other lead).
func _helper_name() -> String:
	var stage: String = ep.partner_stage(room_key) if _script_has(ep, "partner_stage") else ""
	var table: Dictionary = (ep as Script).get_script_constant_map().get("PARTNER", {})
	var who := lead(other_character())
	if stage != "" and table.has(stage) and table[stage] is Dictionary:
		who = String((table[stage] as Dictionary).get("who", who))
	if who == lead(current):
		return ""
	return GameNames.character(who, who.capitalize())


# =========================================================================
# REV 301: the party (Glen, 24 Oct). The console bar shows who's in it; PARTY / SOLO says whether the
# others follow you. In a party they walk after you (at walking pace, keeping a little distance), unless
# the room pins them (party_pinned() - offices and interviews where people stand where the scene puts
# them, e.g. Tuvall's office) or a scene, conversation, menu or cutscene is running. Solo: they stay
# where you left them. Rooms still place everyone themselves on arrival - nobody follows through a door.
# =========================================================================

const FOLLOW_START := 2.6      # metres (x CHAR_SCALE) apart before the other sets off after you
const FOLLOW_STOP := 1.5       # how close they come
var _following := false


## The party, the played person first (people ids, e.g. ["spock", "chapel"]); a hidden spare body
## (Episode 2's melds, the transporter room) isn't in it.
func party_members() -> Array:
	var out: Array = [lead(current)]
	if kirk_body != null and mccoy_body != null:
		var idle := body_of(other_character())
		if idle.visible and idle.is_inside_tree():
			out.append(lead(other_character()))
	return out


## Rooms where the others must stay where the scene put them override this to return true.
func party_pinned() -> bool:
	return false


func set_party_mode(mode: String) -> void:
	GameState.set_var("PARTY_MODE", "solo" if mode == "solo" else "party")
	MissionLog.notification_requested.emit("Party: your crew follow you" if mode != "solo" else "Solo: your crew stay where they are")
	if mode == "solo":
		var idle := body_of(other_character()) if kirk_body != null and mccoy_body != null else null
		if idle != null and idle.is_auto_walking():
			idle.cancel_auto_walk()


func _party_follow() -> void:
	if kirk_body == null or mccoy_body == null or active_body == null:
		return
	if _following:
		# a scene, menu or conversation started while they were walking after you: they stop where they are
		if _busy or _leaving or InteractionManager.is_locked() or ConversationPresenter.letterboxed or DialogueManager.is_busy():
			var walker := body_of(other_character())
			if walker != null and walker.is_auto_walking():
				walker.cancel_auto_walk()
		return
	if ConsoleBar.party_mode() != "party" or party_pinned() or _busy or _leaving or not _control_begun:
		return
	if InteractionManager.is_locked() or InteractionManager.is_modal_suspended() or ConversationPresenter.letterboxed \
			or DialogueManager.is_busy() or (menu != null and menu.is_open()) or (case_ui != null and case_ui.is_open()):
		return
	var idle := body_of(other_character())
	if idle == null or not idle.visible or idle.is_auto_walking():
		return
	var gap := Vector3(active_body.global_position.x - idle.global_position.x, 0.0, active_body.global_position.z - idle.global_position.z)
	if gap.length() < FOLLOW_START * CHAR_SCALE:
		return
	var goal := active_body.global_position - gap.normalized() * FOLLOW_STOP * CHAR_SCALE
	goal.y = idle.global_position.y
	_following = true
	_walk_after(idle, goal)


func _walk_after(idle: PlayerController, goal: Vector3) -> void:
	await idle.walk_to(goal, active_body.global_position if is_instance_valid(active_body) else Vector3.INF, false)
	_following = false


func _partner_handler(verb: String, _source: String) -> void:
	if _source != "":
		# REV 500: an item used on your partner - rooms can answer it (partner_item); otherwise a shrug
		if await partner_item(_source):
			return
		await say(lead(other_character()), "What am I supposed to do with that?" if other_character() == "mccoy" else "Not now, Bones.")
		return
	if verb == "TALK":
		await partner_talk()


## REV 500: an item used on the other of Kirk / McCoy. Return true when the room answered it.
func partner_item(_source: String) -> bool:
	# REV 597: an episode can answer it for every room (Episode 3: Kyle and Scotty hand things over)
	if _script_has(ep, "partner_item"):
		return await ep.partner_item(self, _source)
	return false


## What the other of Kirk / McCoy says when you talk to him. Rooms override this
## to give a hint that fits where the investigation is up to.
func partner_talk() -> void:
	if await partner_hint():     # REV 490: the episode's partner table (THE PARTNER)
		return
	if lead_people != {"kirk": "kirk", "mccoy": "mccoy"}:
		await say(lead(other_character()), "Yes?")
		return
	if is_mccoy():
		await say("kirk", "Take your time, Bones. Nobody's going anywhere.")
	else:
		await say("mccoy", "Well, Jim? I'm all ears.")


func body_of(who: String) -> PlayerController:
	return kirk_body if who == "kirk" else mccoy_body


func other_character() -> String:
	return "mccoy" if current == "kirk" else "kirk"


func _set_active_character(who: String, silent: bool = false) -> void:
	if who != "kirk" and who != "mccoy":
		who = "mccoy"
	current = who
	active_body = body_of(who)
	if _following and active_body.is_auto_walking():
		active_body.cancel_auto_walk()     # REV 301: was following you - now it's you, so it stops
	var idle := body_of(other_character())
	idle.set_active(false)
	if idle.is_in_group("player"):
		idle.remove_from_group("player")
	if not active_body.is_in_group("player"):
		active_body.add_to_group("player")
	active_body.set_active(true)
	if _busy:
		active_body.input_enabled = false   # still in a scripted moment: hands off until it ends
	camera_rig.set_target(active_body)
	GameState.set_var(ep_prefix() + "_ACTIVE_CHAR", who)
	# REV 505: who is being played as a PERSON (Episode 2: Spock, Chapel, Giotto, Kirk) - each lead carries
	# their own things (Ep2.ITEMS' owner column), so the backpack is matched to them at once
	GameState.set_var(ep_prefix() + "_ACTIVE_LEAD", lead(who))
	if _script_has(ep, "sync_items"):
		ep.sync_items()
	CompanionManager.set_active(who)
	if partner_spot != null:
		partner_spot.display_name = GameNames.character(lead("mccoy" if who == "kirk" else "kirk"))
	_update_who_label()


## Swap which of the two is controlled. The other stays where they are.
func switch_to(who: String) -> void:
	if who == current:
		return
	# REV 593: the other lead is somewhere else on the ship (Episode 3) - go to them
	if _script_has(ep, "switch_lead") and ep.switch_lead(self, who):
		return
	_set_active_character(who)
	MissionLog.notification_requested.emit("Now playing: " + lead_name(who))
	if not _busy:
		_end_scene()  # makes sure input/focus belong to the new character


func _update_who_label() -> void:
	if hud == null:
		return
	var who_label: Label = hud.get("who_label")
	if who_label != null:
		who_label.text = lead_name(current)
	var frame := hud.find_child("McCoyPortrait", true, false)
	if frame != null and frame.has_method("setup"):     # REV 301: the console bar draws its own portraits
		var path := "res://assets/portraits/%s.png" % lead(current)
		if ResourceLoader.exists(path):
			for child in frame.get_children():
				child.queue_free()
			frame.call("setup", load(path), Vector2(52, 52), UITheme.GOLD, 10.0, 2.0, 1.5, 0.8, 0.2)


func teleport(who: String, pos: Vector3, look_at: Vector3 = Vector3.INF) -> void:
	var body := body_of(who)
	body.global_position = pos
	body.velocity = Vector3.ZERO
	if look_at != Vector3.INF:
		var d := look_at - pos
		body.rotation.y = atan2(d.x, d.z)


# =========================================================================
# UI
# =========================================================================

func _setup_ui() -> void:
	ui_canvas = CanvasLayer.new()
	ui_canvas.name = "UICanvas"
	add_child(ui_canvas)

	var hud_scene: PackedScene = load("res://core/ui/hud/HUD.tscn")
	hud = hud_scene.instantiate()
	ui_canvas.add_child(hud)

	_hint = Label.new()
	if case_file_on():
		_hint.text = "[C] CASE FILE      [TAB] SWITCH KIRK / McCOY" if allow_switching else "[C] CASE FILE"
		InputHints.bind(_hint, "{case_file_open} CASE FILE|{switch_character} SWITCH KIRK / McCOY" if allow_switching else "{case_file_open} CASE FILE")
	else:
		# REV 476: no Case File - only the switch hint (none at all in rooms that don't switch)
		_hint.text = "[TAB] SWITCH KIRK / McCOY" if allow_switching else ""
		if allow_switching:
			InputHints.bind(_hint, "{switch_character} SWITCH %s / %s" % [lead_name("kirk").to_upper(), lead_name("mccoy").to_upper()])
	UITheme.style_hint(_hint)
	_hint.position = Vector2(20.0, 14.0)
	ui_canvas.add_child(_hint)

	case_ui = CaseFileUI.new()
	case_ui.board_source = ep     # REV 302: the INVESTIGATION BOARD page, from this episode's data
	ui_canvas.add_child(case_ui)
	case_ui.compare_requested.connect(_on_compare_requested)
	case_ui.closed.connect(_on_case_closed)
	case_ui.deduction_requested.connect(_on_deduction_requested)

	menu = ChoiceMenu.new()
	ui_canvas.add_child(menu)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 30
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.offset_top = 60.0
	_banner.offset_bottom = 110.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_title(_banner)
	_banner.add_theme_font_size_override("font_size", 18)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_banner)

	_clock_label = Label.new()
	UITheme.style_hint(_clock_label)
	_clock_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock_label.anchor_left = 1.0
	_clock_label.anchor_right = 1.0
	_clock_label.offset_left = -420.0
	_clock_label.offset_right = -20.0
	_clock_label.offset_top = 14.0
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_canvas.add_child(_clock_label)
	_refresh_clock()

	_update_who_label()


## Refreshes the Council countdown (top right) and speaks any one-off warning.
func _refresh_clock() -> void:
	if _clock_label == null:
		return
	_clock_label.text = ep.clock_text()
	_clock_label.visible = _clock_label.text != ""
	var alert: String = ep.clock_alert()
	if alert != "":
		_clock_label.text = ep.clock_text()
		MissionLog.notification_requested.emit(alert)


## A wrong idea was followed up: it costs story time on the Council clock.
func wrong_idea() -> void:
	var lost: int = ep.clock_penalty()
	if lost > 0:
		MissionLog.notification_requested.emit("WRONG IDEA  -%d MIN" % lost)
	_refresh_clock()


func _fade_in(seconds: float = 0.7) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade.modulate.a = 1.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_fade, "modulate:a", 0.0, seconds)
	_fade_tween = tween


var _fade_tween: Tween = null


## REV 273: go to black and STAY black (stops the room's opening fade-in, which would otherwise pull the
## screen clear again under an arrival scene that wants to start on black).
func fade_black() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade.modulate.a = 1.0


## REV 105: where we are, for the pause menu.
func location_name() -> String:
	var info: Array = ep.ROOMS.get(room_key, [room_key, ""])
	return String(info[0])


## REV 144: the label under the HUD minimap (and in the debug overlay). Rooms aboard the Enterprise
## get "Deck N - " in front, per Glen's label format; rooms on Vulcan are just their name.
func room_display_name() -> String:
	var deck_n := ShipDecks.deck_of_room(ship_key(room_key))
	return ("Deck %d - %s" % [deck_n, location_name()]) if deck_n >= 0 else location_name()


func _show_banner() -> void:
	var info: Array = ep.ROOMS.get(room_key, [room_key, ""])
	_banner.text = String(info[0]).to_upper()
	var tween := create_tween()
	tween.tween_interval(0.5)
	# REV 297: with Reduced Motion the room name simply appears and disappears (it still stays 2.2 s)
	tween.tween_property(_banner, "modulate:a", 1.0, UITheme.dur(0.5))
	tween.tween_interval(2.2)
	tween.tween_property(_banner, "modulate:a", 0.0, UITheme.dur(0.8))


func _unhandled_input(event: InputEvent) -> void:
	# REV 103: actions (rebindable, and with gamepad buttons), not fixed keys
	var case_pressed := event.is_action_pressed("case_file_open")
	var switch_pressed := event.is_action_pressed("switch_character")
	var party_pressed := event.is_action_pressed("party_toggle")     # REV 301
	if not case_pressed and not switch_pressed and not party_pressed:
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if InteractionManager.is_modal_suspended():
		return   # an inventory / log / settings screen is up: its own buttons, not ours
	if _leaving or not _control_begun or _busy:
		return
	if menu != null and menu.is_open():
		return
	if case_ui != null and case_ui.is_open():
		return
	if case_pressed:
		if not case_file_on():
			return     # REV 476
		_open_case_file()
		get_viewport().set_input_as_handled()
	elif party_pressed:
		if party_members().size() > 1:
			set_party_mode("solo" if ConsoleBar.party_mode() == "party" else "party")
			get_viewport().set_input_as_handled()
	elif switch_pressed and allow_switching and can_switch():
		switch_to(other_character())
		get_viewport().set_input_as_handled()


## Rooms may override to forbid switching during a scripted moment.
func can_switch() -> bool:
	if _script_has(ep, "can_switch"):
		return bool(ep.can_switch(self))     # REV 593 (Episode 3: Kyle is playable from 3.06)
	return true


func _open_case_file() -> void:
	case_ui.deduction_label = "NEW DEDUCTION POSSIBLE" if ep.deduction_ready() else ""
	active_body.input_enabled = false
	InteractionManager.set_modal_suspended(true)
	case_ui.open()
	get_tree().call_group("hud", "case_file_opened")     # REV 301: the bar's new-clue count resets


func _on_case_closed() -> void:
	InteractionManager.set_modal_suspended(false)
	if not _busy:
		active_body.input_enabled = true
		active_body.refresh_focus()


# =========================================================================
# Running scenes (conversations, terminals, scans)
# =========================================================================

## keep_held (REV 293): true when the scene is only the room's reply to using something (run_spot) -
## the item in hand stays in hand afterwards (INTERACTION_MODEL.md: an item stays in hand after use).
## Cutscenes, compares and arrivals leave it false and put the item away as before.
func _begin_scene(keep_held: bool = false) -> void:
	_busy = true
	_quiet = 0.0     # REV 490: something is happening - the stuck timer starts again
	if active_body != null:
		active_body.input_enabled = false
	InteractionManager.set_locked(true, keep_held)


func _end_scene() -> void:
	if _script_has(ep, "refresh_tracker") and not _leaving:
		ep.refresh_tracker()
	if case_file_on():
		_check_deduction_notice()
	elif not _leaving:
		await _auto_reason()     # REV 476: still locked - the connections play as part of the scene
	if not _leaving and _script_has(ep, "after_scene"):
		await ep.after_scene(self)     # REV 593: a story call due now (Episode 3's communicator calls)
	_refresh_clock()
	_busy = false
	InteractionManager.set_locked(false)
	if active_body != null and not _leaving:
		active_body.input_enabled = true
		active_body.refresh_focus()
	# REV 741 (Glen: "If the story means I have to switch to another character, it should automatically put me in
	# control of that character. Remember it's story first."): an episode can ask for the hand-over during a scene;
	# it happens here, the moment the scene is over
	if not _leaving and _script_has(ep, "take_pending_switch"):
		var slot := String(ep.take_pending_switch())
		if slot != "" and slot != current:
			switch_to(slot)


func _check_deduction_notice() -> void:
	var key: String = ep.pending_deduction()
	if key == "":
		return
	# REV 293: the episode itself shows the notice once - it knows its own "already told" flag names
	# and any objective that goes with it (Ep1: EP1_DEDUCTION_NOTICED ... and DEDUCE for hub1)
	ep.deduction_noticed(key)


## REV 476 (no Case File): after a scene, Kirk and McCoy make any connection whose facts are now all
## known (ep.next_auto_connection), then play any big deduction that's ready (ep.pending_deduction_auto),
## one after another, while the player is still locked out. Nothing to read, nothing to pick.
func _auto_reason() -> void:
	for _guard in 12:
		if _leaving:
			return
		if _script_has(ep, "next_auto_connection"):
			var rule: String = ep.next_auto_connection()
			if rule != "":
				if not _busy:
					_begin_scene()
				await pause(0.3)
				await ep.run_compare(self, rule)
				ep.mark_connection(rule)
				continue
		var key: String = ep.pending_deduction_auto() if _script_has(ep, "pending_deduction_auto") else ep.pending_deduction()
		if key == "":
			return
		if not _busy:
			_begin_scene()
		await pause(0.3)
		await ep.run_deduction(self)
		var after: String = ep.pending_deduction_auto() if _script_has(ep, "pending_deduction_auto") else ep.pending_deduction()
		if after == key:
			return     # it couldn't finish yet (it says why); don't loop
	return


## REV 524: override to answer an item used on ANY spot in the room (true = answered; the spot's handler is skipped).
## For items whose handlers would otherwise ignore the item and act as if it were a plain USE.
func intercept_item(_verb: String, _source: String) -> bool:
	return false


## Called by SpotHotspot. Runs the handler with the player locked out.
func run_spot(handler: Callable, verb: String, source: String) -> void:
	if _busy or _leaving or not _control_begun:
		return
	if menu.is_open() or case_ui.is_open():
		return
	_begin_scene(true)   # REV 293: the item in hand survives using it
	# REV 490: SHOW from the verb wheel - which thing from the backpack?
	if verb == "SHOW" and source == "":
		source = await pick_item_to_show()
		if source == "":
			if not _leaving:
				_end_scene()
			return
	# REV 97: talking to someone is a letterboxed conversation; looking at things is not
	# (REV 490: showing someone something is a conversation too)
	var talk := verb == "TALK" or verb == "SHOW"
	if talk:
		ConversationPresenter.begin()
	# REV 741 (Glen's bug list item 18): did the item DO anything? Any story state that changes while it is used
	# (a flag, the item leaving the backpack) counts as success - the item goes back in the backpack; a try that
	# changes nothing ("that won't work") leaves it in hand to try on something else.
	var worked := [false]
	var watch := func(var_name: String, _v: Variant) -> void:
		if not var_name.contains("_PARTNER_") and not var_name.ends_with("_LAST_CALL") and not var_name.begins_with("EP3_POS_") \
				and not var_name.begins_with("EP3_ROOM_"):
			worked[0] = true
	if source != "":
		GameState.variable_changed.connect(watch)
	# REV 524: a room may answer an item used on something before the spot's own handler sees it
	if source != "" and await intercept_item(verb, source):
		pass
	else:
		await handler.call(verb, source)
	if source != "":
		if GameState.variable_changed.is_connected(watch):
			GameState.variable_changed.disconnect(watch)
		if not InventoryManager.has_item(source) and not source.begins_with("EQUIP_"):
			worked[0] = true
		if worked[0] and InteractionManager.get_held_source() == source:
			InteractionManager.set_held_source("")
	if talk:
		ConversationPresenter.end()
	if not _leaving:
		_end_scene()


## Runs any coroutine as a locked-out scene (used by compare results etc.).
func run_scene(scene: Callable) -> void:
	if _busy or _leaving:
		return
	_begin_scene()
	await scene.call()
	if not _leaving:
		_end_scene()


# ---- speaking ----------------------------------------------------------------------

## One spoken line. who is a key of ep.SPEAKERS ("mccoy", "tuvall", ...).
## REV 293: a line can also say how it's staged, the same way the Prologue's lines do
## (BowlingAlley._say): a Dictionary {to, shot, emotion, gesture}, given in place of the bus or after it:
##     await say("tuvall", "Ambassador Turian is dead.", {"to": "mccoy", "shot": "CU", "emotion": "grave"})
##   to       who it's said to (an ep.SPEAKERS key) - the conversation camera and eyes turn to them
##   shot     how it's filmed: CU, MCU, MS, OTS, TWO
##   emotion  the face to wear;  gesture  a move to go with it ("point", "shrug", "head_shake"...)
## Without it the line plays exactly as before.
func say(who: String, text: String, bus: Variant = "Dialogue", opts: Dictionary = {}) -> void:
	if bus is Dictionary:
		opts = bus
		bus = "Dialogue"
	var info: Array = ep.SPEAKERS.get(who, [who, who.capitalize()])
	var file_name: String = String(ep.line_id(who, text)) + ".mp3"
	if not opts.is_empty():
		var hint := DialogueLineData.new()
		hint.character_folder = String(info[0])
		hint.speaker_display_name = String(info[1])
		hint.filename = file_name
		hint.subtitle = text
		var to := String(opts.get("to", ""))
		if to != "":
			var to_info: Array = ep.SPEAKERS.get(to, [to])
			to = String(to_info[0])        # the figure is found by its voice folder, like the speaker
		hint.target_id = to
		hint.shot = String(opts.get("shot", ""))
		hint.emotion = String(opts.get("emotion", ""))
		hint.gesture = String(opts.get("gesture", ""))
		DialogueManager.line_starting.emit(hint)    # ConversationPresenter picks it up for this line
	AudioSubtitleManager.play_line(String(info[0]), file_name, String(info[1]), text, String(bus))
	await AudioSubtitleManager.line_finished


## The same remark from either of them: McCoy's wording and, optionally, Kirk's
## (if Kirk's is left out, Kirk says McCoy's wording).
func me_say(mccoy_text: String, kirk_text: String = "") -> void:
	if is_kirk():
		await say(lead("kirk"), kirk_text if kirk_text != "" else mccoy_text)
	else:
		await say(lead("mccoy"), mccoy_text)


## A back-and-forth: lines is an Array of [who, text] pairs (REV 293: or [who, text, staging] - as for say).
func say_all(lines: Array) -> void:
	for line in lines:
		var staging: Dictionary = line[2] if line.size() > 2 and line[2] is Dictionary else {}
		await say(String(line[0]), String(line[1]), "Dialogue", staging)


# =========================================================================
# REV 490 (the redesign): shared helpers for every episode's rooms
# =========================================================================

## SHOW: this person takes items from the backpack (the wheel gets SHOW while you carry anything; an item
## used on them is shown). Their handler gets verb "SHOW" and the item's id as source.
func takes_shown(spot: SpotHotspot) -> SpotHotspot:
	spot.shows_items = true
	spot.verb_icon_overrides["SHOW"] = "id_card"
	return spot


## Which backpack item to show (pad-friendly menu). "" = never mind.
func pick_item_to_show() -> String:
	var ids: Array = []
	var labels: Array = []
	for it in InventoryManager.get_all_items():
		if it == null:
			continue
		ids.append(String(it.id))
		labels.append(String(it.display_name))
	if ids.is_empty():
		return ""
	labels.append("Never mind")
	var pick: int = await menu.ask("Show what?", labels, "SHOW", true, true)
	if pick < 0 or pick >= ids.size():
		return ""
	return String(ids[pick])


## A remembered choice. The choice is kept in a GameState var (flag_name) that later scenes and episodes read.
## REV 528: no words on screen - a small Starfleet delta glints in the corner (RememberDelta), instead of
## Telltale's "ULLUS WILL REMEMBER THAT." (Tiffany: keep the consequences, lose the borrowed language).
## `who` is kept for the code's own record of whose memory it is.
func remember(flag_name: String, _who: String) -> void:
	GameState.set_var(flag_name, true)
	if ui_canvas == null:
		return
	RememberDelta.flash(ui_canvas)


## A {TIMED} choice: a shrinking bar under the options. Returns the pick, or -1 if the time ran out
## (saying nothing is an answer too - the scene plays its silence).
func choose_timed(options: Array, seconds: float = 6.0, prompt: String = "") -> int:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.custom_minimum_size = Vector2(360.0, 6.0)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -180.0
	bar.offset_right = 180.0
	bar.offset_top = -40.0
	bar.offset_bottom = -34.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = UITheme.GOLD
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override("background", back)
	if ui_canvas != null:
		ui_canvas.add_child(bar)
	var state := {"open": true}
	var t := create_tween()
	t.tween_property(bar, "value", 0.0, seconds)
	t.tween_callback(func():
		if state["open"]:
			if ConversationPresenter.letterboxed:
				ConversationPresenter.time_out_ask()
			else:
				menu.time_out())
	var pick: int = await choose(options, prompt)
	state["open"] = false
	if t.is_valid():
		t.kill()
	bar.queue_free()
	return pick if pick >= 0 else -1


## REV 537: the F8 debug box (BuildInfo) for every episode room - the current objective, the PLAINEST line of
## the partner table for where the story is (each stage ends with a plain instruction - the new-player rule),
## and the usable things in this room with their map positions (as F3's PLAYER line shows them). A room with
## its own puzzle state (Episode 5's Arena) overrides this.
func debug_next_step() -> String:
	var out: Array[String] = []
	var o := ObjectiveManager.get_current_objective()
	if o != null and String(o.text) != "":
		out.append("OBJECTIVE: " + String(o.text))
	var plain := ""
	var stage := ""
	if _script_has(ep, "partner_stage"):
		stage = String(ep.partner_stage(room_key))
		var table: Dictionary = (ep as Script).get_script_constant_map().get("PARTNER", {})
		if stage != "" and table.has(stage):
			var entry: Variant = table[stage]
			var lines: Array = (entry as Dictionary).get("lines", []) if entry is Dictionary else entry
			if not lines.is_empty():
				plain = String(lines[lines.size() - 1]).replace("{name}", "").replace(", .", ".").replace(" ,", ",").replace("  ", " ")
	if plain != "":
		out.append("DO THIS: " + plain + "   [stage " + stage + "]")
	else:
		out.append("DO THIS: (no partner hint for this room right now - the objective above, or a door to another room)")
	var things: Array[String] = []
	for n in find_children("*", "", true, false):
		if not (n is SpotHotspot):
			continue
		var h := n as SpotHotspot
		if not h.visible or not h.monitorable or String(h.display_name) == "" or h == partner_spot:
			continue
		if "enabled" in h and not bool(h.get("enabled")):
			continue
		var gp := h.global_position
		things.append("%s (x %d, z %d)" % [String(h.display_name), roundi(gp.x), roundi(gp.z)])
	if not things.is_empty():
		things.sort()
		out.append("HERE: " + ", ".join(things.slice(0, 14)) + (" ..." if things.size() > 14 else ""))
	return "\n".join(out)


## The partner's recap (THE PARTNER table of each episode's script): talk to whoever you're not playing
## and they say where you are, plainer each time you ask (3 levels per stage). The same lines play unasked
## when the player has been stuck for a while (_process). An episode provides partner_stage() and PARTNER.
## REV 714 (Glen: "I thought we decided in the mission log, it would show you what to do for the next mission"):
## the goal right now, for the Mission Log's CURRENT OBJECTIVE - the episode's GOALS line for the partner-hint stage
## ("" when the episode has none for it).
func current_goal() -> String:
	if ep == null or not _script_has(ep, "partner_stage"):
		return ""
	var goals: Dictionary = (ep as Script).get_script_constant_map().get("GOALS", {})
	if goals.is_empty():
		return ""
	var stage: String = ep.partner_stage(room_key)
	return String(goals.get(stage, ""))


## REV 741 (Glen's bug list item 6): where the map marker goes. The episode's MARKERS table names, per partner
## stage, the hotspot id(s) the goal is at; the first one in THIS scene is the target (Vector3), and when none of
## them is here the marker points at the nearest turbolift ("lift"). No entry (or "") = no marker.
func objective_target() -> Variant:
	if ep == null or not _script_has(ep, "partner_stage"):
		return null
	var table: Dictionary = (ep as Script).get_script_constant_map().get("MARKERS", {})
	if table.is_empty():
		return null
	var stage: String = ep.partner_stage(room_key)
	var want: Variant = table.get(stage, "")
	var ids: Array = want if want is Array else ([want] if String(want) != "" else [])
	if ids.is_empty():
		return null
	var way_out: Variant = null
	for n in find_children("*", "Area3D", true, false):
		var hid: Variant = n.get("hotspot_id")
		if hid == null or not (n as Node3D).is_visible_in_tree():
			continue
		if ids.has(String(hid)):
			return (n as Node3D).global_position
		if way_out == null and String(hid).ends_with("_EXIT"):
			way_out = (n as Node3D).global_position
	# REV 745: not in this room - its way out (Vulcan's rooms, sickbay's corridor), else the nearest turbolift
	return way_out if way_out != null else "lift"


## REV 741 (Glen's bug list item 7: the "what to do next" lines "need to all be done again, with more details"):
## the NEXT STEP under the current objective (Mission Log, H) - the stage's partner hint, as a plain line: the
## pointer (where / which) at first, the plain instruction once the player has heard the partner's first two.
func current_step() -> String:
	if ep == null or not _script_has(ep, "partner_stage"):
		return ""
	var stage: String = ep.partner_stage(room_key)
	var table: Dictionary = (ep as Script).get_script_constant_map().get("PARTNER", {})
	if stage == "" or not table.has(stage):
		return ""
	var entry: Variant = table[stage]
	var lines: Array = (entry as Dictionary).get("lines", []) if entry is Dictionary else entry
	if lines.is_empty():
		return ""
	var key := ep_prefix() + "_PARTNER_" + stage
	var heard := int(GameState.get_var(key)) if GameState.has_var(key) else 0
	var i := mini(2 if heard >= 2 else 1, lines.size() - 1)
	return plain_step(String(lines[i]))


## A spoken hint as a written step: no "{name}", no "sir" / "laddie" / "Doctor" forms of address, capitalised.
static func plain_step(t: String) -> String:
	t = t.replace("{name}", "")
	for w in [", sir", " sir", "Sir, ", "Sir - ", ", laddie", "laddie, ", ", Montgomery", "Montgomery, ", ", Mister Scott",
			", Mister Kyle", ", Captain", ", Jim", ", Bones", ", Doctor", ", Spock", ", Mister Spock"]:
		t = t.replace(w, "")
	t = t.replace(", .", ".").replace(" ,", ",").replace(" .", ".").replace(",,", ",").strip_edges()
	while t.begins_with(",") or t.begins_with("-") or t.begins_with("."):
		t = t.substr(1).strip_edges()
	if t.length() > 0:
		t = t.substr(0, 1).to_upper() + t.substr(1)
	return t


func partner_hint(unasked: bool = false) -> bool:
	if not _script_has(ep, "partner_stage"):
		return false
	var stage: String = ep.partner_stage(room_key)
	var table: Dictionary = (ep as Script).get_script_constant_map().get("PARTNER", {})
	if stage == "" or not table.has(stage):
		return false
	var key := ep_prefix() + "_PARTNER_" + stage
	var level := int(GameState.get_var(key)) if GameState.has_var(key) else 0
	# REV 505: an entry is either the three lines, or {"who": speaker, "lines": [...]} when the partner is a
	# person in the room rather than the other playable lead (Episode 2: McCoy for Spock, Scotty on the comm
	# for Giotto, Spock to himself inside a meld)
	var entry: Variant = table[stage]
	var lines: Array = (entry as Dictionary).get("lines", []) if entry is Dictionary else entry
	var text := String(lines[mini(level, lines.size() - 1)])
	GameState.set_var(key, level + 1)
	var idle_body := body_of(other_character())
	var partner_here := idle_body != null and idle_body.visible and allow_switching
	var who := lead(other_character()) if partner_here else lead(current)
	if entry is Dictionary and String((entry as Dictionary).get("who", "")) != "":
		who = String(entry["who"])
		partner_here = who != lead(current)
	# REV 505: asked (not unasked), the played lead may say a line first - Spock's "Summarise, Doctor."
	if not unasked and who != lead(current) and _script_has(ep, "partner_ask"):
		var ask: String = ep.partner_ask(who, lead(current))
		if ask != "":
			await say(lead(current), ask)
	# the name the speaker uses for the one being played ("{name}": Bones / Jim / Doctor / Captain)
	var name := ""
	if _script_has(ep, "partner_name"):
		name = ep.partner_name(who, lead(current))
	text = text.replace("{name}", name).replace(", .", ".").replace(" ,", ",")
	if unasked and partner_here:
		face_partner()
	# REV 599: alone, the lead thinks aloud first (Episode 3: "Think, Montgomery." / "Think, Kyle.")
	if not unasked and who == lead(current) and _script_has(ep, "think_line"):
		await say(who, String(ep.think_line(who)))
	await say(who, text)
	return true


## REV 490 (EPISODE1_SCRIPT.md: the Tellarite argument duel - Monkey Island's insult sword-fighting, our
## own fiction). SHORT, by design (edit pass, 27 Oct - Tiffany: "get out while it's still funny"): the
## barbs come in order; each offers its winning comeback, the weak ones and the OTHER barbs' comebacks as
## decoys. A wrong answer gets the opponent's reply, greys that option out, and the same barb comes again
## (the referee whispers the line after a miss). No score, no lost rounds, no restart - about a minute.
## Reusable: a Klingon version, surely.
##   d = {
##     "opponent": "ullus", "player": "mccoy", "teacher": "kirk",
##     "barbs": [[barb, winning comeback, teacher's whisper], ...],
##     "weak": [weak comebacks always on offer],
##     "scored": [the opponent's lines when the player scores, rotating],
##     "gloat": [the opponent's lines for a wrong comeback, rotating],
##     "weak_reply": the opponent's line for a weak comeback,
##   }
## Returns true when the player wins (always, eventually - it can't be lost).
func argument_duel(d: Dictionary) -> bool:
	var barbs: Array = d["barbs"]
	var scored_i := 0
	var gloat_i := 0
	for b in barbs:
		var options: Array = [String(b[1])]
		for o in barbs:
			if o != b and not options.has(String(o[1])):
				options.append(String(o[1]))
		for w in d.get("weak", []):
			if not options.has(w):
				options.append(w)
		options.shuffle()
		var tried: Array = []
		var whispered := false
		while true:
			await say(String(d["opponent"]), String(b[0]))
			var offer: Array = []
			for o in options:
				if not tried.has(o):
					offer.append(o)
			var pick: int = await choose(offer, String(d.get("player", "mccoy")).to_upper() + ":")
			var said := String(offer[clampi(pick, 0, offer.size() - 1)])
			await say(String(d["player"]), said)
			if said == String(b[1]):
				var sc: Array = d.get("scored", [])
				if not sc.is_empty():
					await say(String(d["opponent"]), String(sc[scored_i % sc.size()]))
					scored_i += 1
				break
			tried.append(said)
			if (d.get("weak", []) as Array).has(said) and d.has("weak_reply"):
				await say(String(d["opponent"]), String(d["weak_reply"]))
			else:
				var gl: Array = d.get("gloat", [])
				if not gl.is_empty():
					await say(String(d["opponent"]), String(gl[gloat_i % gl.size()]))
					gloat_i += 1
			if not whispered and b.size() > 2:
				whispered = true
				await say(String(d["teacher"]), String(b[2]))     # the referee whispers the line that wins
	return true


## REV 490: the communicator, opened from the backpack. Rooms list who can be called (communicator_calls):
## [[label, Callable], ...]; with nobody to call, the played character says so.
func _on_communicator_opened() -> void:
	if _busy or _leaving or not _control_begun:
		return
	await run_scene(func(): await open_communicator())


func open_communicator() -> void:
	var calls: Array = communicator_calls()
	SfxManager.ui("open")
	if calls.is_empty():
		await say(lead(current), "Nobody needs calling right now.")
		return
	var labels: Array = []
	for c in calls:
		labels.append(String(c[0]))
	labels.append("Close it")
	var pick: int = await menu.ask("Call whom?", labels, "COMMUNICATOR", true, true)
	if pick < 0 or pick >= calls.size():
		return
	await (calls[pick][1] as Callable).call()


## Who this room lets you call: [[label, Callable], ...]. Rooms override.
func communicator_calls() -> Array:
	return []


## The partner turns to face you (a hint said unasked).
func face_partner() -> void:
	var idle := body_of(other_character())
	if idle == null or active_body == null:
		return
	var d := active_body.global_position - idle.global_position
	if Vector2(d.x, d.z).length() > 0.01:
		idle.rotation.y = atan2(d.x, d.z)


## Narration / system message in the subtitle box (no voice).
## REV 306: whether an episode script has this (static) function (a Script's own has_method() can't see them).
static func _script_has(script: Variant, fn: String) -> bool:
	if not (script is Script):
		return false
	for m in (script as Script).get_script_method_list():
		if String(m["name"]) == fn:
			return true
	return false


## REV 306: a backpack item used on another (InteractionManager.combine_items). The episode answers
## (Ep1.combine_items); anything it has nothing to say about gets the played character's own line.
func combine_items(a: String, b: String) -> void:
	await run_scene(func():
		var done := false
		if _script_has(ep, "combine_items"):
			done = await ep.combine_items(self, a, b)
		if not done:
			var line: Array = LinePools.pick(lead(current), "wrong_item")
			if line.is_empty():
				line = LinePools.pick("mccoy", "wrong_item")
			var id := String(line[0])
			var folder: String = LinePools.speaker_of(id)
			SfxManager.ui("invalid", -3.0)
			AudioSubtitleManager.play_line(folder, String(LinePools.POOL_SPEECH_ROOT).path_join(folder).path_join(id + ".mp3"),
				GameNames.character(folder, folder.capitalize()), String(line[1]), "Dialogue")
			await AudioSubtitleManager.line_finished)


## REV 303 (design review 3.5, the design's "USE one inventory object ON another"): the ONE way rooms
## put two things together. Two menu picks (Back steps back; Back on the first pick leaves), then:
##   recipes   [[part, part, result key], ...]   - a match returns its result key
##   pair_says [[part, part, who, line], ...]     - a particular wrong pair gets its own line
##   part_says {part: [who, line]}                - anything combined with this part (evidence, say)
## Any other wrong pair gets the played character's own "that won't work" line (LinePools, voiced).
## Nothing is used up here - the room sets its flags from the key it gets back. "" = backed out.
## Works with a pad (ChoiceMenu: d-pad/stick, A, B).
func combine(title: String, parts: Array, recipes: Array, pair_says: Array = [], part_says: Dictionary = {}, prompt: String = "Combine what?") -> String:
	while true:
		var a: int = await menu.ask(prompt, parts, title, true, true)
		if a < 0:
			return ""
		var rest: Array = parts.duplicate()
		rest.remove_at(a)
		var b: int = await menu.ask(String(parts[a]) + "  +", rest, title, true, true)
		if b < 0:
			continue
		var x := String(parts[a])
		var y := String(rest[b])
		var said := false
		for r in recipes:
			if (String(r[0]) == x and String(r[1]) == y) or (String(r[0]) == y and String(r[1]) == x):
				await note("%s + %s  ->  %s" % [x, y, String(r[2]).replace("_", " ")], 2.6)
				return String(r[2])
		for ps in pair_says:
			if not said and ((String(ps[0]) == x and String(ps[1]) == y) or (String(ps[0]) == y and String(ps[1]) == x)):
				await say(String(ps[2]), String(ps[3]))
				said = true
		for part in [x, y]:
			if not said and part_says.has(part):
				await say(String(part_says[part][0]), String(part_says[part][1]))
				said = true
		if not said:
			var line: Array = LinePools.pick(lead(current), "wrong_item")
			if line.is_empty():
				await say(lead(current), "No.")
			else:
				var id := String(line[0])
				var folder: String = LinePools.speaker_of(id)
				AudioSubtitleManager.play_line(folder, String(LinePools.POOL_SPEECH_ROOT).path_join(folder).path_join(id + ".mp3"),
					GameNames.character(folder, folder.capitalize()), String(line[1]), "Dialogue")
				await AudioSubtitleManager.line_finished
	return ""


## REV 300: the played character really scans (tricorder up, kneels for a low target, the camera frames
## it) before the room shows its result - replaces the old "SCANNING ..." captions, which showed no
## tricorder at all. Safe inside a scan that is already running (a tricorder used on the spot). The
## tricorder stays up while this scene runs and is put away after it (InteractionManager.scan_motion).
## text: an optional caption that says WHAT is being scanned ("SCANNING PATH A ...").
func scan_begin(text: String = "", seconds: float = 1.2) -> void:
	await InteractionManager.begin_scan()
	if text != "":
		await note(text, seconds)


func note(text: String, seconds: float = 2.4) -> void:
	# REV 476: with no Case File, the old "go and compare these" prompts are never shown (the characters
	# make the connection themselves straight after - _auto_reason)
	if not case_file_on() and (text.begins_with("COMPARE AVAILABLE") or text.begins_with("NEW DEDUCTION POSSIBLE") or text.contains("(Case File)") or text.contains("Case File.")):
		return
	# REV 297: long notes stay up long enough to read - at least 1 s plus 0.05 s per character
	# (a 120-character evidence note now shows for 7 s instead of 2.4 s).
	seconds = maxf(seconds, 1.0 + text.length() * 0.05)
	AudioSubtitleManager.subtitle_requested.emit("", text, seconds)
	await get_tree().create_timer(seconds, false).timeout


func pause(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


## Shows a menu and returns the index of the pick.
func choose(options: Array, prompt: String = "") -> int:
	if ConversationPresenter.letterboxed:
		return await ConversationPresenter.ask(options, prompt)   # REV 97: in the letterbox's bottom bar
	return await menu.ask(prompt, options)


## A terminal screen with a list of things to open. Esc/-1 means "log off".
func terminal(title: String, body: String, options: Array) -> int:
	return await menu.ask("", options, title, true, true, body)


func terminal_info(title: String, body: String) -> void:
	await menu.info(title, body, true)


## A choice where one answer is correct. Returns true if the player picked
## options[correct]. (Wrong answers are handled by the caller, since each wrong
## answer usually has its own reply.)
func choose_correct(options: Array, correct: int, prompt: String = "") -> Dictionary:
	var pick: int = await choose(options, prompt)
	return {"pick": pick, "correct": pick == correct}


## Whoever the player is NOT controlling, for lines that depend on it.
func is_kirk() -> bool:
	return current == "kirk"


func is_mccoy() -> bool:
	return current == "mccoy"


func is_tricorder(source: String) -> bool:
	return source.contains("TRICORDER")


## REV 293: true for every verb that means "use it" - USE and any native verb a hotspot may offer
## (OPEN, OPERATE, ANSWER, PICK UP...). Only LOOK / EXAMINE / TALK are not. Handlers should test
## this rather than verb == "USE".
func is_use(verb: String) -> bool:
	return verb != "LOOK" and verb != "EXAMINE" and verb != "TALK"


# ---- objectives / case ---------------------------------------------------------------

func objective(key: String) -> void:
	ep.set_objective(key)


## Adds a clue and returns true if it was new.
func clue(id: String) -> bool:
	return Case.add(id)


# =========================================================================
# Comparing clues / deducing in the Case File
# =========================================================================

## REV 293: compares and deductions go to the room's episode (ep.run_compare / ep.run_deduction);
## Episode 1 hands them to Ep1Compare exactly as before.
func _on_deduction_requested() -> void:
	await run_scene(func(): await ep.run_deduction(self))


func _on_compare_requested(a: String, b: String) -> void:
	await run_scene(func(): await resolve_compare(a, b))


func resolve_compare(a: String, b: String) -> void:
	var rule: String = ep.find_compare(a, b)
	if rule == "":
		await _shrug(a, b)
		return
	var done: bool = await ep.run_compare(self, rule)
	if not done:
		await _shrug(a, b, true)


## REV 299 (design review 2.3): a comparison that leads nowhere is answered by whoever is being played,
## from their own rotating pool (LinePools), never naming or hinting at a clue the player hasn't found:
##   "compare_half" - one of the two clues belongs to some comparison (just not this pair), or the pair
##                    is right but a third piece is still missing
##   "compare_miss" - neither does
## Lines are voiced from assets/audio/speech/pools/<who>/ like the refusal pools; subtitles either way.
func _shrug(a: String, b: String, partial: bool = false) -> void:
	var rules: Array = (ep as Script).get_script_constant_map().get("COMPARE_RULES", [])
	var half := partial
	for r in rules:
		if String(r[0]) in [a, b] or String(r[1]) in [a, b]:
			half = true
	var who := lead(current)
	var line: Array = LinePools.pick(who, "compare_half" if half else "compare_miss")
	if line.is_empty():
		line = LinePools.pick(who, "compare_miss")
	if line.is_empty():
		line = LinePools.pick("mccoy" if who != "kirk" else "kirk", "compare_miss")
	var id := String(line[0])
	var folder: String = LinePools.speaker_of(id)
	var path: String = String(LinePools.POOL_SPEECH_ROOT).path_join(folder).path_join(id + ".mp3")
	SfxManager.ui("invalid", -3.0)
	AudioSubtitleManager.play_line(folder, path, GameNames.character(folder, folder.capitalize()), String(line[1]), "Dialogue")
	await AudioSubtitleManager.line_finished


# =========================================================================
# Travel between rooms
# =========================================================================

## REV 593: the ship's name (a ShipDecks key) for one of this episode's rooms - Episode 3's rooms have their
## own keys ("deck7", "core") and map back through Ep3.ship_key; Episodes 1-2 use the ship's keys already.
func ship_key(key: String) -> String:
	if _script_has(ep, "ship_key"):
		return String(ep.ship_key(key))
	return key


## Opens the "where to?" menu and, if the player picks a place, goes there.
func travel_menu() -> void:
	var keys: Array = []
	var labels: Array = []
	for key in ep.unlocked_rooms():
		if key == room_key:
			continue
		keys.append(key)
		labels.append(String(ep.ROOMS[key][0]))
	if keys.is_empty():
		await say(lead(current), "Better find out why they dragged me down here first.")
		return
	labels.append("Stay here")
	var pick: int = await menu.ask("Where to?", labels, "", true)
	if pick < 0 or pick >= keys.size():
		return
	await go_to(String(keys[pick]))


## The turbolift deck menu, used by every lift's control levers. Picking a place takes you
## there and you step out of that room's lift.
var _lift_ui: TurboliftUI = null


func open_turbolift_menu() -> void:
	ShipDecks.episode = int(ep_prefix().substr(2)) if ep_prefix().substr(2).is_valid_int() else 1     # REV 593
	if _lift_ui == null:
		_lift_ui = TurboliftUI.new()
		ui_canvas.add_child(_lift_ui)
	var here := ShipDecks.deck_of_room(ship_key(room_key))
	var from_key := ship_key(room_key)
	if room_key == "turbolift":
		from_key = ShipDecks.came_from
		here = ShipDecks.deck_of_room(from_key)
	var key: String = await _lift_ui.run(here, from_key)
	if key == "":
		return
	key = String(ShipDecks.LIFT_REDIRECT.get(key, key))   # REV 55: engineering has no lift; you arrive at the nearest one
	var upper := ShipDecks.LIFT_UPPER.has(key)              # REV 308: Deck 7 engineering's upper level (Deck 6)
	key = String(ShipDecks.LIFT_UPPER.get(key, key))
	var spot: Array = ShipDecks.LIFT_SPOTS.get(key, [])     # REV 617: a lift on another level of the same map
	var picked := key
	if not spot.is_empty():
		key = String(spot[0])
	# REV 593: a later episode's own room for this ship place (Episode 3: Ep3.LIFT_ROOMS). REV 625: asked about the
	# lift stop itself first (Episode 3 has its own room for "ae_deck8_aux" - Deck 15, Auxiliary Control)
	if _script_has(ep, "lift_room"):
		var own := String(ep.lift_room(picked))
		key = own if own != picked else String(ep.lift_room(key))
	SfxManager.play("door")
	SfxManager.play("turbolift", -2.0)   # keeps playing as you arrive
	await pause(1.6)
	ShipDecks.came_from = room_key
	ShipDecks.arrive_by_lift = true
	ShipDecks.eng_upper = upper
	if not spot.is_empty():
		ShipDecks.arrive_spot_on = true
		ShipDecks.arrive_spot = spot[1]
		ShipDecks.arrive_z = float(spot[2])
		ShipDecks.arrive_face = spot[3]
	# REV 101: the flag used to be cleared straight after this line, which runs BEFORE the new room
	# is built (Godot changes scene at the end of the frame), so lift arrivals never stepped out of
	# the lift. The room that arrives clears it; here only if that room could not be opened.
	var opened: bool = await go_to(key)
	if not opened:
		ShipDecks.arrive_by_lift = false
		ShipDecks.eng_upper = false


## REV 293: leave by transporter. The figures dematerialise, the beam's glow covers the screen, and
## room `key` opens under it with TransporterEffect.pending_arrival set - so it materialises everyone
## where its beam_in_spots() says (the same way Episode 1's opening beams into Tuvall's office).
## figures: the bodies / models to beam out (default: the one being played). Returns false (and the
## screen clears again here) if that room isn't built.
## materialise_there = false: they only dematerialise here and room `key` opens the ordinary way
## (a beam-up to a room that isn't the transporter room, e.g. Episode 2's Vulcan -> Sickbay).
func beam_to(key: String, figures: Array = [], materialise_there: bool = true) -> bool:
	var info: Array = ep.ROOMS.get(key, [])
	# REV 375 (Glen: lift levers always work): a turbolift destination this episode has no room of its own for
	# (Episode 2 has only its story rooms) goes to the ship's walk-around deck room - the same ship.
	if info.is_empty() and ep != Ep1:
		info = Ep1.ROOMS.get(key, [])
	if info.is_empty() or not ResourceLoader.exists(String(info[1])):
		return await go_to(key)      # says "(X isn't built yet.)" and stays - nobody beams anywhere
	if figures.is_empty() and active_body != null:
		figures = [active_body]
	if not materialise_there:
		await TransporterEffect.beam_out(figures)
		var went: bool = await go_to(key)
		if not went:
			for f in figures:
				if f != null:
					TransporterEffect.on(f).materialise(0.6)
		return went
	TransporterEffect.beam_out(figures)
	await pause(TransporterEffect.DEMAT_SECONDS * 0.35)
	await TransporterEffect.screen_to(1.0, TransporterEffect.DEMAT_SECONDS * 0.55)
	TransporterEffect.pending_arrival = true
	var opened: bool = await go_to(key)
	if not opened:
		TransporterEffect.pending_arrival = false
		await TransporterEffect.screen_to(0.0, 0.4)
		for f in figures:
			if f != null:
				TransporterEffect.on(f).materialise(0.6)
	return opened


const _ROOM_LOADER := preload("res://core/systems/RoomLoader.gd")


## Returns false (and stays here) if the room isn't built; otherwise the room changes.
func go_to(key: String) -> bool:
	var info: Array = ep.ROOMS.get(key, [])
	if info.is_empty() or not ResourceLoader.exists(String(info[1])):
		await note("(" + String(info[0] if not info.is_empty() else key) + " isn't built yet.)", 2.5)
		return false
	if _script_has(ep, "room_leaving"):
		ep.room_leaving(self)     # REV 593: remember where each lead in this room stood (Episode 3)
	_leaving = true
	active_body.input_enabled = false
	GameState.set_var("ep_came_from", room_key)   # REV 283: the streets put you outside the door you came out of
	GameState.set_var("EP_WALK_LEADS", lead_people.duplicate())   # REV 640: a walk-around deck keeps the same pair
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)   # REV 99: eased, not linear
	tween.tween_property(_fade, "modulate:a", 1.0, 0.45)
	await tween.finished
	AudioSubtitleManager.stop_all()
	InteractionManager.reset_for_load()
	# REV 101: read the next room and its map in the background (with a location card if it takes a
	# moment) instead of freezing on black
	await _ROOM_LOADER.change_to(get_tree(), String(info[1]), String(info[0]))
	return true


# =========================================================================
# Saving / loading
# =========================================================================

func _save_busy_reason(_for_load: bool) -> String:
	if _leaving:
		return "Moving to another room."
	if not _control_begun:
		return "Please wait a moment."
	if _busy or InteractionManager.is_locked():
		return "A scene is playing."
	if menu != null and menu.is_open():
		return "Finish what you're doing first."
	return ""


func _collect_save_state() -> Dictionary:
	var orbit: Vector2 = camera_rig.get_orbit()
	return {
		"kirk": [kirk_body.position.x, kirk_body.position.y, kirk_body.position.z, kirk_body.rotation.y],
		"mccoy": [mccoy_body.position.x, mccoy_body.position.y, mccoy_body.position.z, mccoy_body.rotation.y],
		"camera_yaw": orbit.x,
		"camera_pitch": orbit.y,
	}


func _restore_from_save(blob: Dictionary) -> void:
	ep.ensure_state()
	SaveSystem.restore_managers(blob)
	var state: Dictionary = blob.get("scene_state", {})
	for who in ["kirk", "mccoy"]:
		var arr: Array = state.get(who, [])
		if arr.size() == 4:
			var body := body_of(who)
			body.position = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
			body.rotation.y = float(arr[3])
	if state.has("camera_yaw"):
		camera_rig.set_orbit(float(state.get("camera_yaw", 0.0)), float(state.get("camera_pitch", 0.1)))
	_set_active_character(String(GameState.get_var(ep_prefix() + "_ACTIVE_CHAR")), true)
	MissionLog.notification_requested.emit.call_deferred("Game Loaded")
