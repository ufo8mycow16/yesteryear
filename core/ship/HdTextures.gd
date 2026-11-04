extends RefCounted
class_name HdTextures
## HdTextures - lets upscaled textures replace the ones inside the map models.
##
## Put an upscaled picture in  res://assets/hd_textures/  using the SAME path and name as the
## original in the map_textures folder (for example
## assets/hd_textures/models/mapobjects/tos/chair_metal.png). When a map loads, every material
## with a matching name gets the new picture. Anything you do not provide stays as it was.
## The picture can be any size, as long as it has the same shape as the original.

const DIR := "res://assets/hd_textures/"
static var _cache: Dictionary = {}


static func apply(root: Node) -> void:
	if not DirAccess.dir_exists_absolute(DIR) and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(DIR)):
		return
	_walk(root)


static func _walk(node: Node) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var m: Material = mesh.surface_get_material(s)
			if m is StandardMaterial3D and (m as StandardMaterial3D).resource_name != "":
				var std := m as StandardMaterial3D
				var tex := _find(std.resource_name)
				if tex != null:
					if std.albedo_texture == null:
						std.albedo_color = Color.WHITE   # a stand-in flat colour must not tint the real picture
					std.albedo_texture = tex
					std.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC     # REV 444: floors at a low angle stay crisp, not crawling
					_dress(std, std.resource_name, tex)
	for c in node.get_children():
		_walk(c)


## REV 100: surfaces that were never plain paint in the original game. Their pictures came back
## from the game files (tools/restore_textures.py), but a picture alone would draw glass as a dark
## solid panel and lights as flat grey, so each kind gets the treatment the original gave it:
##   glass           - a faint reflection on clear glass (the picture is ADDED to what's behind it)
##   lights          - glow (the picture is also the emission, so the enhanced lighting blooms it)
##   effects         - transporter shimmer / fire: added light, no shading, both sides
##   see-through art - pictures with an alpha channel (water, curtains): blended
##   screens         - a soft glow
const GLASS_KEYS := ["textures/engineering/glass"]
const LIGHT_KEYS := ["light", "basiclt", "conflight"]
## REV 444: "textures/tos/tran" used to be matched as a prefix, so a remade transwall (the transporter room
## walls) turned into see-through glow. Exact names now, plus the lit shimmer panel.
const EFFECT_KEYS := ["fire"]
const EFFECT_NAMES := ["textures/tos/tran", "textures/tos/transpanellit"]
const SCREEN_KEYS := ["screen"]
static var _alpha: Dictionary = {}


static func _has_key(n: String, keys: Array) -> bool:
	for k in keys:
		if n.contains(String(k)):
			return true
	return false


static func _dress(std: StandardMaterial3D, mat_name: String, tex: Texture2D) -> void:
	var n := mat_name.to_lower()
	if _has_key(n, GLASS_KEYS) and not n.contains("opaque"):
		std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		std.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		std.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		std.cull_mode = BaseMaterial3D.CULL_DISABLED
		std.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		std.no_depth_test = false
	elif _has_key(n, EFFECT_KEYS) or EFFECT_NAMES.has(n):
		std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		std.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		std.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		std.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif _has_key(n, LIGHT_KEYS) and not n.contains("lightmap"):
		std.emission_enabled = true
		std.emission_texture = tex
		std.emission = Color.WHITE
		std.emission_energy_multiplier = 0.9
	elif bool(_alpha.get(mat_name, false)):
		std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# REV 444: the grates are thin brushes with the grate on BOTH faces - drawn two-sided you see two
		# layers of mesh at once (moire). One-sided, each side shows just the face towards you.
		std.cull_mode = BaseMaterial3D.CULL_BACK if n.contains("grate") else BaseMaterial3D.CULL_DISABLED
	elif _has_key(n, SCREEN_KEYS):
		std.emission_enabled = true
		std.emission_texture = tex
		std.emission = Color.WHITE
		std.emission_energy_multiplier = 0.6


static func _find(mat_name: String) -> Texture2D:
	if _cache.has(mat_name):
		return _cache[mat_name]
	var tex: Texture2D = null
	# REV 100: the imported copy first (works in an exported game too, and is GPU-compressed)
	for ext in ["png", "webp", "jpg"]:
		var res_path: String = DIR + mat_name + "." + String(ext)
		if ResourceLoader.exists(res_path):
			tex = load(res_path) as Texture2D
			if tex != null:
				var img := tex.get_image()
				_alpha[mat_name] = _has_alpha(img)
				# REV 444: Godot imports these pictures as 2D (no mipmaps), and they are only put on 3D
				# surfaces at run time, so the editor never notices they need them. Without mipmaps fine
				# detail sparkles and crawls as you walk (Glen: the new carpet "looks like it's vibrating").
				if img != null and not img.has_mipmaps() and not img.is_compressed():
					img.generate_mipmaps()
					tex = ImageTexture.create_from_image(img)
				_cache[mat_name] = tex
				return tex
	for ext in ["png", "webp", "jpg"]:
		var p := ProjectSettings.globalize_path(DIR + mat_name + "." + ext)
		if FileAccess.file_exists(p):
			var img := Image.load_from_file(p)
			if img != null and not img.is_empty():
				_alpha[mat_name] = img.detect_alpha() != Image.ALPHA_NONE
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
				break
	# REV 427: maps spell some folders in capitals (textures/TOSsecurity/...) while hd_textures keeps them
	# lower case (textures/tossecurity/...); res:// is case-sensitive in an exported game, so try lower case too.
	if tex == null and mat_name != mat_name.to_lower():
		tex = _find(mat_name.to_lower())
		if tex != null:
			_alpha[mat_name] = _alpha.get(mat_name.to_lower(), false)
	_cache[mat_name] = tex
	return tex


## REV 681: does this picture have see-through parts? The HD remakes are now imported GPU-compressed with mipmaps
## (tools/textures/fix_texture_imports.py) and detect_alpha() can't read a compressed picture: the compressed
## formats without an alpha channel answer at once, the rest are looked at on a small uncompressed copy.
static func _has_alpha(img: Image) -> bool:
	if img == null or img.is_empty():
		return false
	if not img.is_compressed():
		return img.detect_alpha() != Image.ALPHA_NONE
	match img.get_format():
		Image.FORMAT_DXT1, Image.FORMAT_RGTC_R, Image.FORMAT_RGTC_RG, Image.FORMAT_BPTC_RGBF, \
				Image.FORMAT_BPTC_RGBFU, Image.FORMAT_ETC, Image.FORMAT_ETC2_RGB8:
			return false
	var copy := img.duplicate() as Image
	if copy.decompress() != OK:
		return true          # can't tell: treat it as see-through (the safe choice - it still draws)
	copy.clear_mipmaps()
	if copy.get_width() > 256:
		copy.resize(256, maxi(1, int(256.0 * copy.get_height() / copy.get_width())), Image.INTERPOLATE_NEAREST)
	return copy.detect_alpha() != Image.ALPHA_NONE

