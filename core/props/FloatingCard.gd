class_name FloatingCard
extends Node3D
## REV 742 (Glen, 31 Oct: "spinning, floating in rooms, like the Simpsons Hit and Run ones" - walk through to collect,
## never unlocked by talking or by carrying an item; 5-8 per episode; Glen makes the front art).
##
## A collector card hovering at chest height: it turns slowly (front, back, front), bobs, glows gold, sparkles, and
## shimmers quietly when you're near. Walk through it and it whips up into the air, bursts into sparks, chimes, and
## the card is yours (CollectorCards.unlock -> the NEW COLLECTOR CARD notice). Works the same with a pad - no button.
##
##   var c := FloatingCard.make("card_scotty")
##   room.add_child(c); c.global_position = somewhere
##   c.collected.connect(func(id): ...)          # the room's own reaction line, if any
##   c.reachable = false                          # e.g. behind a force field until it drops
##
## Pictures: assets/ui/cards/front_<id>.png (Glen's art; the stand-ins come from tools/make_collector_cards.py) and
## card_back.png (his Vulcan emblem). Sounds: assets/audio/sfx/card_chime.wav (loop), card_collect.wav.

signal collected(card_id: String)

const CARD_DIR := "res://assets/ui/cards/"
const SIZE := Vector2(0.26, 0.364)        # a 2.5 x 3.5 trading card, drawn big enough to read across a room
## REV 767: Glen's cards are WIDE (1960s A&BC gum cards) - each card takes the shape of its own front picture, its
## long side SIZE.y; the stand-ins stay upright. Each card shows its own back (back_<id>.png) when it has one.
var _size := SIZE
const SPIN_SPEED := 1.5                   # radians a second
const BOB_HEIGHT := 0.06
const BOB_SPEED := 1.7
const REACH := 0.8                        # how close (across the floor) the player's middle must come to take it
const REACH_HIGH := 1.6                   # ... and within this much up or down
const GLOW := Color(1.0, 0.78, 0.32)

var card_id := ""
var reachable := true

var _spin: Node3D
var _glow: MeshInstance3D
var _light: OmniLight3D
var _sparks: CPUParticles3D
var _hum: AudioStreamPlayer3D
var _t := 0.0
var _taken := false


static func make(id: String) -> FloatingCard:
	var c := FloatingCard.new()
	c.card_id = id
	c.name = "FloatingCard_" + id
	return c


func _ready() -> void:
	if CollectorCards.is_unlocked(card_id):
		queue_free()
		return
	_t = randf() * TAU
	_spin = Node3D.new()
	add_child(_spin)
	var front_path := CARD_DIR + "front_%s.png" % card_id
	var back_tex: Texture2D = CollectorCards.back(card_id)
	var front_tex: Texture2D = load(front_path) if ResourceLoader.exists(front_path) else back_tex
	if front_tex != null and front_tex.get_width() > front_tex.get_height():
		_size = Vector2(SIZE.y, SIZE.y * float(front_tex.get_height()) / float(front_tex.get_width()))
	_spin.add_child(_face(front_tex, 0.0))
	_spin.add_child(_face(back_tex, PI))
	_spin.add_child(_edge())
	_glow = _make_glow()
	add_child(_glow)
	_light = OmniLight3D.new()
	_light.light_color = GLOW
	_light.light_energy = 0.55
	_light.omni_range = 1.4
	_light.shadow_enabled = false
	add_child(_light)
	_sparks = _make_sparks(false)
	add_child(_sparks)
	_hum = AudioStreamPlayer3D.new()
	var chime := _sound("card_chime")
	if chime is AudioStreamWAV:
		var w := chime as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * float(w.mix_rate))
	_hum.stream = chime
	_hum.volume_db = -16.0
	_hum.unit_size = 1.2
	_hum.max_distance = 7.0
	_hum.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_hum)
	if chime != null:
		_hum.play()


func _face(tex: Texture2D, yaw: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = _size
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR      # the rounded corners
	m.alpha_scissor_threshold = 0.5
	m.emission_enabled = true                                        # readable in a dim cabin
	m.emission_texture = tex
	m.emission_energy_multiplier = 0.45
	m.roughness = 0.35
	m.metallic_specular = 0.7
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.rotation.y = yaw
	mi.position.z = 0.0015 if yaw == 0.0 else -0.0015
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _edge() -> MeshInstance3D:
	# a thin gold card edge, so it never vanishes when it's side-on
	var b := BoxMesh.new()
	b.size = Vector3(_size.x * 0.97, _size.y * 0.97, 0.0025)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.66, 0.28)
	m.metallic = 0.8
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = Color(0.5, 0.36, 0.1)
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _make_glow() -> MeshInstance3D:
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(0.5, 0.0)
	g.width = 128
	g.height = 128
	var grad := Gradient.new()
	grad.set_color(0, Color(GLOW.r, GLOW.g, GLOW.b, 0.55))
	grad.set_color(1, Color(GLOW.r, GLOW.g * 0.8, GLOW.b * 0.6, 0.0))
	g.gradient = grad
	var q := QuadMesh.new()
	q.size = Vector2(0.75, 0.75)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = g
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = false
	m.disable_receive_shadows = true
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _make_sparks(burst: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.006
	dot.height = 0.012
	dot.radial_segments = 6
	dot.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.9, 0.6)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot.material = m
	p.mesh = dot
	p.color = Color(1.0, 0.86, 0.5)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	if burst:
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = 48
		p.lifetime = 0.9
		p.emission_sphere_radius = 0.08
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = 0.6
		p.initial_velocity_max = 1.6
		p.gravity = Vector3(0, -1.2, 0)
		p.scale_amount_min = 0.8
		p.scale_amount_max = 1.6
	else:
		p.amount = 10
		p.lifetime = 1.6
		p.emission_sphere_radius = 0.2
		p.direction = Vector3.UP
		p.spread = 25.0
		p.initial_velocity_min = 0.05
		p.initial_velocity_max = 0.15
		p.gravity = Vector3.ZERO
	return p


func _sound(n: String) -> AudioStream:
	for ext: String in [".wav", ".ogg", ".mp3"]:
		var path := "res://assets/audio/sfx/" + n + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	_spin.rotation.y = fmod(_spin.rotation.y + SPIN_SPEED * delta, TAU)
	_spin.position.y = sin(_t * BOB_SPEED) * BOB_HEIGHT
	var pulse := 0.5 + 0.5 * sin(_t * 2.3)
	_glow.scale = Vector3.ONE * (0.9 + 0.15 * pulse)
	_light.light_energy = 0.4 + 0.25 * pulse
	if reachable and _player_near():
		_take()


func _player_near() -> bool:
	var me := global_position
	for n in get_tree().get_nodes_in_group("player"):
		if not (n is Node3D) or not (n as Node3D).is_visible_in_tree():
			continue
		var at := (n as Node3D).global_position + Vector3(0, 1.0, 0)      # the body's middle, not its feet
		var flat := Vector2(at.x - me.x, at.z - me.z).length()
		if flat <= REACH and absf(at.y - me.y) <= REACH_HIGH:
			return true
	return false


func _take() -> void:
	_taken = true
	_hum.stop()
	_sparks.emitting = false
	var burst := _make_sparks(true)
	add_child(burst)
	burst.emitting = true
	var ding := AudioStreamPlayer.new()
	ding.stream = _sound("card_collect")
	ding.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	ding.volume_db = -3.0
	add_child(ding)
	if ding.stream != null:
		ding.play()
	CollectorCards.unlock(card_id)
	collected.emit(card_id)
	# the flourish: up, spinning fast, shrinking to nothing, the glow flaring then gone
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_spin, "position:y", _spin.position.y + 0.45, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_spin, "rotation:y", _spin.rotation.y + TAU * 3.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_spin, "scale", Vector3.ONE * 0.05, 0.55).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(_glow, "scale", Vector3.ONE * 2.2, 0.3)
	tw.tween_property(_light, "light_energy", 2.0, 0.15)
	tw.chain().tween_property(_light, "light_energy", 0.0, 0.4)
	tw.parallel().tween_property(_glow, "scale", Vector3.ONE * 0.01, 0.4)
	await get_tree().create_timer(1.4).timeout
	queue_free()
