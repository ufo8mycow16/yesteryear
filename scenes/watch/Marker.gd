extends Node3D
## A stand-in for a character we don't have a model for yet: a plain see-through post the person's height
## with their name floating above it. Deliberately not a figure - it only shows where they stand.

static func make(display_name: String, height := 1.8, colour := Color(0.55, 0.75, 1.0)) -> Node3D:
	var root := Node3D.new()
	root.name = display_name.replace(" ", "_")
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.22
	cyl.height = height
	post.mesh = cyl
	post.position.y = height * 0.5
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(colour.r, colour.g, colour.b, 0.35)
	mat.emission_enabled = true
	mat.emission = colour * 0.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	post.material_override = mat
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(post)
	var tag := Label3D.new()
	tag.text = display_name
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.004
	tag.font_size = 48
	tag.outline_size = 10
	tag.modulate = Color(1.0, 0.95, 0.8)
	tag.position.y = height + 0.25
	tag.no_depth_test = true
	root.add_child(tag)
	root.set_meta("marker", true)
	return root
