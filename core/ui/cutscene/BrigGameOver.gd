extends Node3D
## REV 562 (Glen: shoot a crew member and "you're automatically transferred to the brig with a game over"):
## a TOS detention cell, built in code - grey walls, a bench, the real force field (ForceField) humming across
## the front - with whoever fired standing inside, seen from the corridor. After a moment the GAME OVER card
## (GameOverCard) comes up over it, with RETURN TO MAIN MENU.

const CELL_W := 2.6
const CELL_D := 2.2
const CELL_H := 2.7
const FIELD_H := 2.3
const CARD_AFTER := 2.4

var _cam: Camera3D


func _ready() -> void:
	_environment()
	_cell()
	_prisoner()
	_camera()
	SfxManager.play("forcefield_hum", -10.0)
	await get_tree().create_timer(CARD_AFTER).timeout
	GameOverCard.show_over(get_tree(), "ASSAULT ON A FELLOW OFFICER")


func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.9)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	we.environment = env
	add_child(we)
	# a cool key down into the cell and the field's own warm glow
	var key := SpotLight3D.new()
	key.light_color = Color(0.85, 0.9, 1.0)
	key.light_energy = 2.2
	key.spot_range = 6.0
	key.spot_angle = 40.0
	key.position = Vector3(0.0, CELL_H - 0.1, 0.3)
	key.rotation_degrees = Vector3(-80.0, 0.0, 0.0)
	add_child(key)
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.85, 0.7)
	fill.light_energy = 0.6
	fill.omni_range = 4.0
	fill.position = Vector3(0.0, 1.6, CELL_D * 0.5 + 1.4)
	add_child(fill)


func _mat(c: Color, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


## REV 574: the brig field's sparkle (the doorway default is 1.15 bright, every cell lit).
const BRIG_FLECKS := 0.5
const BRIG_FLECK_SHARE := 0.3


func _box(centre: Vector3, size: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = centre
	add_child(mi)


## The cell: floor, back and side walls, ceiling, the corridor floor outside, a bench, a door frame.
func _cell() -> void:
	var wall := _mat(Color(0.55, 0.56, 0.6))
	var floor_m := _mat(Color(0.32, 0.32, 0.34), 0.85)
	var trim := _mat(Color(0.18, 0.18, 0.2))
	var hw := CELL_W * 0.5
	_box(Vector3(0, -0.05, 0), Vector3(CELL_W + 4.0, 0.1, CELL_D + 4.0), floor_m)             # floor (cell + corridor)
	_box(Vector3(0, CELL_H * 0.5, -CELL_D * 0.5 - 0.05), Vector3(CELL_W, CELL_H, 0.1), wall)  # back
	_box(Vector3(-hw - 0.05, CELL_H * 0.5, 0), Vector3(0.1, CELL_H, CELL_D), wall)             # sides
	_box(Vector3(hw + 0.05, CELL_H * 0.5, 0), Vector3(0.1, CELL_H, CELL_D), wall)
	_box(Vector3(0, CELL_H + 0.05, 0), Vector3(CELL_W + 0.2, 0.1, CELL_D), wall)               # ceiling
	# the front wall round the doorway, and its dark frame
	var front_z := CELL_D * 0.5
	_box(Vector3(0, (FIELD_H + CELL_H) * 0.5, front_z), Vector3(CELL_W + 0.2, CELL_H - FIELD_H, 0.12), wall)
	_box(Vector3(-hw - 0.4, CELL_H * 0.5, front_z), Vector3(0.8, CELL_H, 0.12), wall)
	_box(Vector3(hw + 0.4, CELL_H * 0.5, front_z), Vector3(0.8, CELL_H, 0.12), wall)
	_box(Vector3(0, FIELD_H + 0.03, front_z + 0.07), Vector3(CELL_W, 0.06, 0.02), trim)
	# the bench along the back wall
	_box(Vector3(0, 0.42, -CELL_D * 0.5 + 0.25), Vector3(CELL_W - 0.3, 0.06, 0.45), _mat(Color(0.7, 0.68, 0.64)))
	_box(Vector3(0, 0.2, -CELL_D * 0.5 + 0.25), Vector3(CELL_W - 0.5, 0.4, 0.38), trim)
	# the force field across the doorway
	var field := ForceField.make(CELL_W, FIELD_H)
	add_child(field)
	field.position = Vector3(0, FIELD_H * 0.5, front_z)
	field.set_sparkle(BRIG_FLECKS, BRIG_FLECK_SHARE)    # REV 574 (Glen: the white flecks were far too intense)
	if field.has_method("set_on"):
		field.set_on(true, 0.6)


## Whoever fired, standing in the middle of the cell, looking out through the field.
func _prisoner() -> void:
	var who := "mccoy"
	if get_node_or_null("/root/PhaserControl") != null:
		who = String(PhaserControl.last_shooter)
	var fig := CharacterKit.make_named(who, {"solid": false})
	if fig == null:
		return
	add_child(fig)
	fig.position = Vector3(0.15, 0.0, -0.15)
	fig.rotation.y = 0.0          # figures face +Z: out through the field
	var an := CharacterKit.animator_of(fig)
	if an != null:
		an.wear_phaser(false)     # confiscated


func _camera() -> void:
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.position = Vector3(-0.9, 1.55, CELL_D * 0.5 + 2.6)
	add_child(_cam)
	_cam.look_at(Vector3(0.1, 1.25, -0.1), Vector3.UP)
	_cam.make_current()
	# a slow push in while it sinks in
	var tw := create_tween()
	tw.tween_property(_cam, "position", _cam.position + Vector3(0.35, -0.05, -0.8), 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
