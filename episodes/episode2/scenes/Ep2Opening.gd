extends RefCounted
class_name Ep2Opening
## REV 320: EPISODE 2's OPENING (script E2-R005, "THE STAR TREK OPENING" to "EXTERIOR - VULCAN ORBIT").
## Played by the Sickbay right after the continuity reprise (McCoy looks from the display to Turian -
## cut to black), through the shared EpisodeOpening, the same way as every episode:
##
##   1. the TOS main titles ("Space... the final frontier", STAR TREK / SECRET OF VULCAN FURY);
##   2. Vulcan fills the screen; the Enterprise moves slowly through orbit; the episode title; Kirk's
##      Captain's Log, Stardate 6420.3;
##   3. as the log ends, the camera closes on the ship - then CUT INSIDE (REV 336, Glen: "it should switch
##      to the bridge"): Uhura's call to Vulcan and the bridge exchange are played on the real bridge set by
##      the Bridge room (Bridge._opening_call);
##   4. back outside: wide - Enterprise, Vulcan, empty space - and for the briefest moment a distortion
##      against the stars (the cloaked third Bird-of-Prey; nobody notices it, nothing explains it).
##      This is the second part, make(2), played by the Bridge room over its black after the call.
##
## CHANGING THE SHOTS: debug build, F1 while it plays (the titles' shot editor); F5 saves this
## sequence's own cut to episodes/episode2/opening_layout.json (part 1) or opening_orbit_layout.json
## (part 2) - send it over, it goes in the repo.
##
## THE TWO DELEGATION SHIPS (REV 322, D7 from REV 353): Glen's classic TOS Romulan Bird-of-Prey (BOP_MODEL), two of them
## at BOP_SPOTS, sized so their wingspan is BOP_SIZE, nose toward the Enterprise. They hold position
## the whole sequence, so they can be seen in any shot that looks their way. Uhura's comms station and
## the bridge are heard, not seen, until those shots are wanted.

const LAYOUT_PATH := "res://episodes/episode2/opening_layout.json"
const ORBIT_LAYOUT_PATH := "res://episodes/episode2/opening_orbit_layout.json"
const BOP_MODEL := "res://assets/models/ships/romulan_bird_of_prey.glb"
## REV 359 (Glen: "off in the distance ... not so close to the Enterprise, and have a little bit of space
## between them - they're almost on top of each other"): was (10, 1.6, -9) / (13.5, 0.4, -5) - about 14 from
## the Enterprise and 5.4 apart. Now about 33-38 away and 13 apart; checked against every outside shot's
## camera: both are in frame at the end of shot 2, in shot 3 and in the orbit shot, Bird-of-Prey left, D7
## right, never overlapping, and well clear of Vulcan.
const BOP_SPOTS := [Vector3(12.0, -1.5, -31.0), Vector3(25.0, -3.5, -29.0)]
const BOP_SIZE := 6.0                  # wingspan in the space world (the Enterprise is about 10 long)
## REV 353 (Glen): the second of the two delegation ships is a Romulan-operated D7 - "The Enterprise
## Incident" (Romulans using Klingon designs; the remastered Blu-ray shows both), for visual variety.
## Drop Glen's D7 model at D7_MODEL and it replaces the Bird-of-Prey at BOP_SPOTS[D7_SPOT]; until then
## both are Birds-of-Prey. D7_SIZE = its longest side (about 0.8 of the Enterprise's length, as in TOS).
## D7_NOSE_PLUS_Z: true if the model's nose points +z (as Glen's Bird-of-Prey), false if -z.
const D7_MODEL := "res://assets/models/ships/romulan_d7.glb"
const D7_SPOT := 1
const D7_SIZE := 8.0
const D7_NOSE_PLUS_Z := true          # REV 354: Glen's "Stormbird" D7 (227 m model) - its command pod is at +z
## REV 359 (Glen): the D7 banks, to show off the Stormbird decal underneath and hide the Klingon emblem on
## top. It rolls D7_BANK_DEG about its own nose line, whichever way turns its underside toward D7_SHOW_TO
## (the cameras that see it: shot 2's end, shot 3 and the orbit shot all look from that side).
const D7_BANK_DEG := 45.0
const D7_SHOW_TO := Vector3(6.0, 2.0, 16.0)
const TITLE_COLOR := Color(0.98, 0.82, 0.32)     # TOS episode-title yellow (as Episode 1)

## The distortion: the orbit shot (part 2), this many seconds in, at SHIMMER_AT, for SHIMMER_SECONDS.
const SHIMMER_AFTER := 4.5
const SHIMMER_SECONDS := 0.9
const SHIMMER_AT := Vector3(-11.0, 2.5, -7.0)
const SHIMMER_SIZE := 7.0

## [when, [who, words]] (EpisodeOpening's "log" format). Recording names come from the words (Ep2.line_id),
## so reworded lines get new names (REV 329 reworded the McCoy/datapad part).
const LOG := [
	[7.0, ["kirk", "Captain's Log, Stardate 6420.3."]],
	[10.5, ["kirk", "The death of Ambassador Turian, a member of the Romulan delegation, has cast a shadow over the peace conference on Vulcan."]],
	# REV 329 (Glen): McCoy's call from Sickbay (Episode 1's last line) is answered here - he has found an anomaly.
	[19.0, ["kirk", "Doctor McCoy's investigation has determined the cause of death. However, he has now detected an anomaly within the Ambassador's body, which he is looking into."]],
	[30.0, ["kirk", "There is also the matter of Turian's encrypted datapad, which he entrusted to Darev shortly before his death and which is now secured aboard Enterprise."]],
	[44.0, ["kirk", "With our own computers unable to penetrate its security, I have decided to request assistance from the Vulcan government."]],
	[52.0, ["kirk", "We can only hope the information it contains will help us understand why a man who came to Vulcan in the name of peace is now lying dead aboard my ship."]],
]

const TITLES := [
	{"text": Ep2.EPISODE_TITLE, "start": 2.4, "end": 7.2, "fade": 1.0, "size": 26, "color": TITLE_COLOR, "bold": true, "area": "lower", "tracking": 4},
]

## Same keys as TitleSequence.SHOTS (Ep1Opening.gd has the notes on scale). Vulcan's radius is 20.
const SHOTS: Array[Dictionary] = [
	{
		# Vulcan fills the screen; the Enterprise moves slowly through orbit above the red desert world.
		# For several seconds only the ship, the planet and the stars - then the title, then the log.
		"name": "1 — VULCAN FILLS THE SCREEN", "start": 0.0, "dur": 22.0,
		"cam_from": Vector3(-7, 6.5, 19), "cam_to": Vector3(-5, 5.5, 17),
		"look_from": Vector3(0, -7, -5), "look_to": Vector3(1.5, -7.5, -6),
		"fov_from": 42.0, "fov_to": 40.0,
		"ship_from": Vector3(-8, 0.6, 0), "ship_to": Vector3(0.5, 0.3, -1.2),
		"ship_yaw_from": -87.0, "ship_yaw_to": -91.0, "ship_roll_from": 4.0, "ship_roll_to": 2.0,
		"ship_shadow": false,
		"planet": true, "planet_from": Vector3(1, -25, -9), "planet_lon": 40.0,
		"sun_pos": Vector3(28, 12, -26), "sun_from": 0.8, "sun_to": 0.75,
		"warm_from": 1.1, "glow_from": 1.35,
		"twins": 0.35, "twins_az": 24.0, "twins_el": 18.0,
		"neb": 0.25, "neb_az": -36.0, "neb_el": 10.0, "neb_size": 14.0,
		"ease": 0.25, "fade_in": 2.5, "fade_out": 0.0,
	},
	{
		# The Enterprise continues silently across the face of Vulcan (the rest of the log).
		"name": "2 — ACROSS THE FACE OF VULCAN", "start": 22.0, "dur": 40.0,
		"cam_from": Vector3(3, 1.2, 14), "cam_to": Vector3(5.5, 0.9, 12.5),
		"look_from": Vector3(-1, -2, 0), "look_to": Vector3(6, -2.2, -1),
		"fov_from": 36.0, "fov_to": 34.0,
		"ship_from": Vector3(-8, 0, 0), "ship_to": Vector3(8, -0.3, -1), "ship_yaw": -90.0,
		"planet": true, "planet_from": Vector3(6, -30, -28), "planet_lon": 25.0,
		"tkhut": true, "tkhut_from": Vector3(-170, 40, -260), "tkhut_size": 13.0,
		"sun_pos": Vector3(30, 8, -22), "sun_from": 0.7, "sun_to": 0.65,
		"warm_from": 1.1, "glow_from": 1.4,
		"twins": 0.45, "twins_az": -24.0, "twins_el": 12.0,
		"neb": 0.3, "neb_az": 28.0, "neb_el": 6.0, "neb_size": 15.0,
		"ease": 0.15, "fade_in": 0.0, "fade_out": 0.0,
	},
	{
		# As the log ends, closer toward the ship - over the saucer, toward the bridge - then cut inside
		# (REV 336: the call itself is on the bridge set now, so this is only the push in).
		"name": "3 — CLOSER: TOWARD THE BRIDGE", "start": 62.0, "dur": 11.0,
		"cam_from": Vector3(-5, 4, 13), "cam_to": Vector3(-1.6, 2.4, 6.5),
		"look_from": Vector3(0, 0, 0), "look_to": Vector3(0.6, 0.6, -0.4),
		"fov_from": 34.0, "fov_to": 29.0,
		"ship_from": Vector3(0, 0, 0), "ship_to": Vector3(0.3, 0, -0.15),
		"ship_yaw_from": -100.0, "ship_yaw_to": -101.0,
		"planet": true, "planet_from": Vector3(2, -30, -18), "planet_lon": 15.0,
		"sun_pos": Vector3(26, 10, -24), "sun_from": 0.75, "sun_to": 0.75,
		"warm_from": 1.0, "glow_from": 1.3,
		"twins": 0.4, "twins_az": 30.0, "twins_el": 14.0,
		"neb": 0.25, "neb_az": -20.0, "neb_el": 8.0, "neb_size": 14.0,
		"ease": 0.45, "fade_in": 0.0, "fade_out": 0.8,
	},
]

## REV 336: part 2 - back outside after the bridge: Vulcan orbit, wide, and the distortion.
const ORBIT_SHOTS: Array[Dictionary] = [
	{
		# Vulcan orbit, wide: Enterprise, Vulcan, empty space - and, for an instant, a distortion.
		"name": "4 — VULCAN ORBIT (WIDE)", "start": 0.0, "dur": 12.0,
		"cam_from": Vector3(13, 5, 30), "cam_to": Vector3(15, 6, 34),
		"look_from": Vector3(0, -2, 0), "look_to": Vector3(-2, -3, -2),
		"fov_from": 44.0, "fov_to": 48.0,
		"ship_from": Vector3(0, 0, 0), "ship_to": Vector3(2, 0, -1), "ship_yaw": -90.0,
		"planet": true, "planet_from": Vector3(-6, -32, -22), "planet_lon": 10.0,
		"sun_pos": Vector3(26, 10, -24), "sun_from": 0.75, "sun_to": 0.7,
		"warm_from": 1.0, "glow_from": 1.3,
		"twins": 0.4, "twins_az": 34.0, "twins_el": 12.0,
		"neb": 0.3, "neb_az": -30.0, "neb_el": 8.0, "neb_size": 16.0,
		"ease": 0.2, "fade_in": 1.2, "fade_out": 1.6,
	},
]

const SHIMMER_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;
void fragment() {
	vec2 c = UV - vec2(0.5);
	float r = length(c) * 2.0;
	float fall = smoothstep(1.0, 0.15, r);
	float ripple = sin(r * 16.0 - TIME * 7.0) + 0.6 * sin(c.x * 23.0 + TIME * 5.0) * sin(c.y * 19.0 - TIME * 4.0);
	vec2 off = normalize(c + vec2(0.0001)) * ripple * 0.006 * strength * fall;
	vec3 col = texture(screen_tex, SCREEN_UV + off).rgb;
	ALBEDO = col + vec3(0.02, 0.03, 0.04) * strength * fall * (0.5 + 0.5 * ripple);
	ALPHA = fall * strength;
}
"""


## The opening, ready to add to the room and run(). part 1 (Sickbay, after the reprise): the TOS
## titles, Vulcan, the title card, Kirk's log and the push in toward the bridge. part 2 (Bridge, after
## the call to Vulcan): the wide orbit shot with the distortion, no titles.
static func make(part: int = 1) -> EpisodeOpening:
	var op := EpisodeOpening.new()
	op.ep = Ep2
	var shimmer := {"node": null, "mat": null, "camera": null}
	var dress := func(vp: SubViewport, cam: Camera3D, _ship: Node3D) -> void:
		_dress_world(vp, cam, shimmer)
	if part == 2:
		op.main_titles = false
		op.settings = {
			"shots": ORBIT_SHOTS, "layout": ORBIT_LAYOUT_PATH,
			"on_world": dress,
			"each_frame": func(t: float, o: EpisodeOpening) -> void:
				_shimmer_frame(t, o, shimmer),
		}
	else:
		op.settings = {
			"shots": SHOTS, "titles": TITLES, "log": LOG, "layout": LAYOUT_PATH,
			"on_world": dress,
		}
	return op


## Puts the distortion (hidden) and, if the models exist, the two delegation ships (a Bird-of-Prey and,
## REV 353, a Romulan D7 once Glen's model is in) into the space world.
static func _dress_world(vp: SubViewport, cam: Camera3D, shimmer: Dictionary) -> void:
	var quad := MeshInstance3D.new()
	quad.name = "CloakShimmer"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(SHIMMER_SIZE, SHIMMER_SIZE * 0.55)
	quad.mesh = mesh
	var sh := Shader.new()
	sh.code = SHIMMER_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("strength", 0.0)
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.position = SHIMMER_AT
	quad.visible = false
	vp.add_child(quad)
	shimmer["node"] = quad
	shimmer["mat"] = mat
	shimmer["camera"] = cam
	for i in BOP_SPOTS.size():
		var spot: Vector3 = BOP_SPOTS[i]
		var path := BOP_MODEL
		var size := BOP_SIZE
		var nose_plus_z := true          # Glen's Bird-of-Prey: nose +z (bussards there)
		if i == D7_SPOT and ResourceLoader.exists(D7_MODEL):
			path = D7_MODEL
			size = D7_SIZE
			nose_plus_z = D7_NOSE_PLUS_Z
		if not ResourceLoader.exists(path):
			continue
		var ship: Node3D = (load(path) as PackedScene).instantiate()
		ship.name = "RomulanD7" if path == D7_MODEL else "RomulanBirdOfPrey"
		vp.add_child(ship)
		var aabb := _bounds(ship)
		var longest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		if longest > 0.0:
			ship.scale = Vector3.ONE * (size / longest)
		ship.position = spot
		ship.look_at(Vector3.ZERO, Vector3.UP)          # look_at points -z at the Enterprise
		if nose_plus_z:
			ship.rotate_object_local(Vector3.UP, PI)    # turn a +z nose to face it
		if path == D7_MODEL and D7_BANK_DEG != 0.0:
			_bank_toward(ship, D7_BANK_DEG, D7_SHOW_TO)


## REV 359: rolls a ship about its nose line (its own z) so that its underside turns toward `show_to`.
## Both directions are tried; the one whose belly (its own -y) faces `show_to` more is kept - so it works
## whichever way round the model was built.
static func _bank_toward(ship: Node3D, degrees: float, show_to: Vector3) -> void:
	var base := ship.transform
	var to := (show_to - base.origin).normalized()
	var best := base
	var best_dot := -INF
	for sgn in [1.0, -1.0]:
		var t := base
		t.basis = t.basis * Basis(Vector3(0, 0, 1), deg_to_rad(degrees * sgn))
		var belly := -t.basis.y.normalized()
		var d := belly.dot(to)
		if d > best_dot:
			best_dot = d
			best = t
	ship.transform = best


## The distortion, for a moment in the orbit shot, always facing the camera.
static func _shimmer_frame(t: float, op: EpisodeOpening, shimmer: Dictionary) -> void:
	var quad: MeshInstance3D = shimmer.get("node")
	if quad == null or not is_instance_valid(quad):
		return
	var t0 := op.shot_start(0) + SHIMMER_AFTER
	var k := (t - t0) / SHIMMER_SECONDS
	var on := k > 0.0 and k < 1.0
	quad.visible = on
	if not on:
		return
	(shimmer["mat"] as ShaderMaterial).set_shader_parameter("strength", sin(k * PI))
	var cam: Camera3D = shimmer.get("camera")
	if cam != null and is_instance_valid(cam):
		quad.look_at(cam.global_position, Vector3.UP)
		quad.rotate_object_local(Vector3.UP, PI)     # the quad's face toward the camera


static func _bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var b := mi.transform * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
