extends RefCounted
class_name BlinkingLamps
## REV 255 (Glen: "can we get some of those lights on the panels in the background blinking?"):
## brings the lit buttons and lamps painted on the bridge's panels to life.
##
## For each panel picture it finds the lamps themselves - the small bright, coloured spots on the dark
## panel - as separate blobs, and gives a share of them their own blink: a steady on/off at its own
## speed, a busy random flicker (computers working), or an occasional wink. Each lamp blinks as one
## piece. It works from the picture the room actually uses (Glen's HD textures included), so the lamps
## line up whatever resolution the picture is.
##
## It draws as a second pass over the panel (the material's next_pass): where a lamp is "off" it darkens
## that lamp, where it is "on" it lifts it a little - everything else on the panel is left exactly as the
## room drew it (baked lighting and all).
##
## Use: BlinkingLamps.add_to(room_node) after the map has its materials. Returns how many surfaces got it.

## Which map pictures are panels with lamps (lower-case parts of the material names).
const PANEL_KEYS := [
	"tos/bridge/p",          # the wall displays round the bridge (p1, P2 ... P8)
	"tos/cp",                # the station consoles (cp0 ... cp6)
	"tos/inst",              # instrument strips
	"helmcontrols",          # the helm/navigation console
	"astrogator",
	"uhura_intercom",
	"tos_bridgecomputer",
]
## REV 539 (Glen: "every panel and board across the Enterprise to have blinking lights"): the lamp panels on
## every other deck - engineering, sickbay, both transporter rooms, the briefing room, security, the Jefferies-tube
## junction boxes, auxiliary control, the food dispensers. ModelRoom adds these to every map it loads, in STRICT
## mode (see _lamp_ids). Screens (the security maps, viewers, the condition alert) are left off on purpose: they
## are pictures, not lamps. enl/enr (engineering's wall panels) only blink if the picture in use has lit lamps
## painted in - the original Elite Force ones have dark sockets, so nothing is found there and nothing changes.
const SHIP_KEYS := [
	"eng_console",           # engineering consoles (both models)
	"square_panel",
	"tos/engconl", "tos/engconr", "tos/engup", "tos/enl", "tos/enr",
	"engineeringpanel_tws",
	"tos/blkpan",            # black lamp panels (engineering, Jefferies tubes)
	"mapobjects/tos/circuit",  # circuit + circuitbox (not the circuit bay plaque)
	"med_buttons", "med_analyser", "med_computer", "sickpanelbase", "tos/med_panel",
	"transporter_console", "tos/transcan",
	"tosswitches", "spock_computer",   # briefing room
	"tossecurity/screen4",   # the security office's lamp board (screens 1-3 and 5 are maps - left off)
	"aux_cont",              # auxiliary control
	"wallthing_atmospheric", "wallthing_chamber",
	"tos/k7cont",            # K-7-style control boards
	"glass_buttons",         # food dispensers
	"eng-console5_dis",      # the old big map's engineering displays
]
## The share of lamps that blink (the rest stay lit, as painted).
const BLINK_SHARE := 0.45
## Lamps are found on a copy of the picture no larger than this (pixels on its long side).
const SCAN_SIDE := 320
## A blob bigger than this share of the picture's width/height is not a lamp (a screen, a label, a frame).
const MAX_LAMP_W := 0.14
const MAX_LAMP_H := 0.30
## Strict mode: a lamp fills at least this share of its box, and is no longer than this times its width.
const STRICT_FILL := 0.55
const STRICT_ASPECT := 3.0

static var _ids: Dictionary = {}          # "texture instance id/strict" -> ImageTexture of lamp ids (null = no lamps)
static var _shader: Shader


## strict (REV 539, used ship-wide): only compact blobs count as lamps, and a blob in a row of same-height
## neighbours is lettering, not a lamp (stops "ATMOSPHERIC SYSTEM" twinkling letter by letter).
static func add_to(root: Node, keys: Array = PANEL_KEYS, share: float = BLINK_SHARE, strict: bool = false) -> int:
	var count := 0
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(s)
			if src == null or not _matches(src.resource_name.to_lower(), keys):
				continue
			var mat: Material = mi.get_surface_override_material(s)
			if mat == null:
				mat = src
			if mat.next_pass != null:
				continue
			var tex := _picture_of(mat)
			if tex == null:
				continue
			var ids := _lamp_ids(tex, share, strict)
			if ids == null:
				continue
			var over := ShaderMaterial.new()
			over.shader = _overlay_shader()
			over.set_shader_parameter("base_tex", tex)
			over.set_shader_parameter("id_tex", ids)
			over.render_priority = 1
			mat.next_pass = over
			count += 1
	return count


static func _matches(name: String, keys: Array) -> bool:
	for k in keys:
		if name.contains(String(k)):
			return true
	return false


## The picture a material draws: the baked-lighting shader's albedo_tex, or a standard material's texture.
static func _picture_of(mat: Material) -> Texture2D:
	if mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		if sm.shader == null:
			return null
		var t = sm.get_shader_parameter("albedo_tex")
		var use = sm.get_shader_parameter("use_albedo_tex")
		if t is Texture2D and (use == null or float(use) > 0.5):
			return t
		return null
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).albedo_texture
	return null


## A small picture the same shape as the panel's: 0 where there's no blinking lamp, otherwise a number
## (1-255) that is that lamp's own - the shader turns it into the lamp's speed, rhythm and start.
static func _lamp_ids(tex: Texture2D, share: float, strict: bool = false) -> ImageTexture:
	var key := str(tex.get_instance_id(), "/", strict)
	if _ids.has(key):
		return _ids[key]
	_ids[key] = null
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return null
	if img.is_compressed():
		if img.decompress() != OK:
			return null
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var f := minf(1.0, float(SCAN_SIDE) / float(maxi(w, h)))
	if f < 1.0:
		w = maxi(8, int(round(w * f)))
		h = maxi(8, int(round(h * f)))
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var data := img.get_data()
	var n := w * h
	# 1. which pixels are lamp: bright and coloured, or very bright
	var lamp := PackedByteArray()
	lamp.resize(n)
	for i in n:
		var r := data[i * 4]
		var g := data[i * 4 + 1]
		var b := data[i * 4 + 2]
		var v := maxi(r, maxi(g, b))
		var mn := mini(r, mini(g, b))
		if (v >= 110 and (v - mn) * 100 >= v * 35) or v >= 200:
			lamp[i] = 1
	# 2. each lamp as one blob (4-connected)
	var label := PackedInt32Array()
	label.resize(n)
	var out := PackedByteArray()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(tex.resource_path, w, h))
	var next_label := 0
	var stack := PackedInt32Array()
	var blob := PackedInt32Array()
	var lamps := 0
	var found: Array = []      # [x, y, w, h, pixels] per lamp-like blob
	for start in n:
		if lamp[start] == 0 or label[start] != 0:
			continue
		next_label += 1
		label[start] = next_label
		stack.clear()
		blob.clear()
		stack.append(start)
		var x0 := w
		var x1 := -1
		var y0 := h
		var y1 := -1
		while not stack.is_empty():
			var p := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			blob.append(p)
			var px := p % w
			var py := p / w
			x0 = mini(x0, px)
			x1 = maxi(x1, px)
			y0 = mini(y0, py)
			y1 = maxi(y1, py)
			if px > 0 and lamp[p - 1] == 1 and label[p - 1] == 0:
				label[p - 1] = next_label
				stack.append(p - 1)
			if px < w - 1 and lamp[p + 1] == 1 and label[p + 1] == 0:
				label[p + 1] = next_label
				stack.append(p + 1)
			if py > 0 and lamp[p - w] == 1 and label[p - w] == 0:
				label[p - w] = next_label
				stack.append(p - w)
			if py < h - 1 and lamp[p + w] == 1 and label[p + w] == 0:
				label[p + w] = next_label
				stack.append(p + w)
		# not a lamp: a stray pixel, or something big (a screen, a label, a frame)
		var bw := x1 - x0 + 1
		var bh := y1 - y0 + 1
		if blob.size() < 2 or bw > w * MAX_LAMP_W or bh > h * MAX_LAMP_H:
			continue
		if strict:
			# a lamp is a compact blob: mostly filled, not a thin stroke
			if float(blob.size()) / float(bw * bh) < STRICT_FILL or float(maxi(bw, bh)) / float(mini(bw, bh)) > STRICT_ASPECT:
				continue
		found.append([x0, y0, bw, bh, blob.duplicate()])
	for i in found.size():
		var b: Array = found[i]
		if strict and _in_lettering(found, i):
			continue
		if rng.randf() >= share:
			continue
		var id := rng.randi_range(1, 255)
		for p in b[4]:
			out[p] = id
		lamps += 1
	if lamps == 0:
		return null
	# 3. grow each lamp by a pixel, so its soft edge at full size is covered too
	var grown := out.duplicate()
	for i in n:
		if out[i] != 0:
			continue
		var px := i % w
		var py := i / w
		if px > 0 and out[i - 1] != 0:
			grown[i] = out[i - 1]
		elif px < w - 1 and out[i + 1] != 0:
			grown[i] = out[i + 1]
		elif py > 0 and out[i - w] != 0:
			grown[i] = out[i - w]
		elif py < h - 1 and out[i + w] != 0:
			grown[i] = out[i + w]
	var id_img := Image.create_from_data(w, h, false, Image.FORMAT_R8, grown)
	var it := ImageTexture.create_from_image(id_img)
	_ids[key] = it
	return it


## Strict mode: is blob i a letter in a line of text - a neighbour of about its height sitting right
## beside it (within 2 pixels, same line)? Single round lamps in a row are spaced further apart than that.
static func _in_lettering(found: Array, i: int) -> bool:
	var b: Array = found[i]
	var bh: int = b[3]
	if bh < 3:
		return false
	var tol := maxi(1, bh / 3)
	for j in found.size():
		if j == i:
			continue
		var o: Array = found[j]
		if absi(int(o[1]) - int(b[1])) > tol or absi(int(o[3]) - bh) > tol:
			continue
		var gap_right := int(o[0]) - (int(b[0]) + int(b[2]))
		var gap_left := int(b[0]) - (int(o[0]) + int(o[2]))
		if (gap_right >= 0 and gap_right <= 2) or (gap_left >= 0 and gap_left <= 2):
			return true
	return false


static func _overlay_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = OVERLAY_SHADER
	return _shader


const OVERLAY_SHADER := """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform sampler2D base_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D id_tex : filter_nearest, repeat_enable;

// REV 293: sin-free hash (Dave Hoskins' "hash without sine", as WarpTunnel's NOISE_LIB since REV 239);
// fract(sin(x) * 43758) is worked out roughly on real graphics cards and can repeat in patches.
float h1(float n) {
	float x = fract(n * 0.1031);
	x *= x + 33.33;
	x *= x + x;
	return fract(x);
}

void fragment() {
	float id = texture(id_tex, UV).r * 255.0;
	if (id < 0.5) {
		discard;
	}
	vec3 c = texture(base_tex, UV).rgb;
	// how much of this point is lamp (its own glow, not the dark panel round it)
	float v = max(c.r, max(c.g, c.b));
	float sat = (v - min(c.r, min(c.g, c.b))) / max(v, 0.001);
	float lamp = max(smoothstep(0.28, 0.45, v) * smoothstep(0.15, 0.35, sat), smoothstep(0.65, 0.85, v));
	if (lamp < 0.01) {
		discard;
	}
	// this lamp's rhythm
	float kind = h1(id);
	float rate = mix(0.45, 1.8, h1(id + 1.7));
	float t = TIME * rate + h1(id + 3.1) * 10.0;
	float on;
	if (kind < 0.5) {
		on = step(0.38, fract(t));                              // a steady blink, mostly on
	} else if (kind < 0.85) {
		on = step(0.45, h1(floor(t * 2.6) + id * 7.31));        // a busy random flicker
	} else {
		on = step(0.10, fract(t * 0.3));                         // lit, with the odd wink off
	}
	ALBEDO = mix(c * 0.10, c * 1.30, on);
	ALPHA = lamp * mix(0.9, 0.35, on);
}
"""
