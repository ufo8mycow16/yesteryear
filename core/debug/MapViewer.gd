extends Node3D
## REV 165: DEBUG: MAP VIEWER (main menu, debug builds only).
##
## Lists every .glb file under res://assets (grouped by folder, map folders first, with a search box),
## loads the one you pick and drops McCoy into it with the normal game controls: WASD, right-drag
## camera, mouse wheel zoom. He starts in fly mode (Shift+F), so he passes through walls, floors and
## ceilings, which all stay visible; Shift+F again makes them solid and he walks normally.
##
## Maps get the same treatment as in the game where the files exist: the <map>_extra.glb pieces, the
## upscaled textures (HdTextures), the pool water and the map's baked lightmap (ModelRoom's own code is
## borrowed for that, so the look matches the game). L switches to full-bright (the plain textures, no
## lighting at all), for maps that load too dark or have no lightmap.
##
## Nothing here touches the story: no hotspots, no Kirk, no saving (quick save is refused while here).

const KeyList := preload("res://core/ui/KeyListPanel.gd")
const MODEL_ROOM_SCRIPT := "res://episodes/episode1/ModelRoom.gd"
const MAIN_MENU_SCENE := "res://core/menu/MainMenu.tscn"
const SCAN_ROOT := "res://assets"
const CHAR_SCALE := 1.70 / 1.80     # same size as McCoy in Episode 1 rooms (EpisodeRoom.CHAR_SCALE)

## Lightmaps the game pairs with a map but that aren't named after it (see the Episode 1 room scripts).
const KNOWN_LIGHTMAPS := {
	"enterprise3_full.glb": "res://assets/models/enterprise/bridge_lightmap.png",
	"daedalus2_full.glb": "res://assets/models/rooms/daedalus_lightmap.png",
	"wreckdeck_up.glb": "res://assets/models/maps/wreckdeck_full_lightmap.png",
	"wreckdeck_down.glb": "res://assets/models/maps/wreckdeck_full_lightmap.png",
}

enum Mode { LIST, LOADING, VIEW }
var _mode: int = Mode.LIST

var _files: Array = []              # [{path, folder, name, size}], sorted for display
var _rig: OrbitCameraRig
var _mccoy: PlayerController
var _map: Node3D = null
var _map_entry: Dictionary = {}
var _start_pos := Vector3.ZERO
var _start_open := Vector3.BACK      # the most open direction at the start point (the camera goes that way)
var _full_bright := false
var _saved_overrides: Array = []    # [[MeshInstance3D, surface, Material]] put aside while full-bright
var _lighting_note := ""
var _loading_path := ""
var _last_selected := ""
var _first_load := true

var _ui: CanvasLayer
var _list_root: Control
var _search: LineEdit
var _tree: Tree
var _footer: Label
var _loading: Label
var _header: Label
var _keys: PanelContainer
var _keys_hidden := false


func _ready() -> void:
	SaveSystem.scene_state_provider = Callable()
	SaveSystem.busy_reason_provider = func(_for_load: bool) -> String: return "Saving is off in the map viewer."
	_setup_world()
	_setup_ui()
	_scan(SCAN_ROOT)
	_files.sort_custom(_file_order)
	_fill_tree()
	_show_list()


func _exit_tree() -> void:
	# The viewport outlives this scene: never leave the game drawing unshaded.
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


## BuildInfo (F3) shows this in the top-left, and leaves its own shortcut list out while we show ours.
func debug_where() -> String:
	if _mode != Mode.VIEW or _mccoy == null:
		return ""
	var p := _mccoy.global_position
	var lines: Array[String] = []
	lines.append("PLAYER  x %.2f  y %.2f  z %.2f" % [p.x, p.y, p.z])
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var c := cam.global_position
		lines.append("CAMERA  x %.2f  y %.2f  z %.2f" % [c.x, c.y, c.z])
	return "\n".join(lines)


func has_own_key_list() -> bool:
	return true


# ------------------------------------------------------------------ world --

func _setup_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.03, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 0.55
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy = 0.6
	add_child(sun)

	# The camera and McCoy exactly as an Episode 1 room makes them (EpisodeRoom._setup_characters / _make_body).
	_rig = OrbitCameraRig.new()
	_rig.name = "CameraRig"
	_rig.start_zoomed_in = false
	_rig.distance = 3.2 * CHAR_SCALE
	_rig.height *= CHAR_SCALE
	_rig.zoom_min *= CHAR_SCALE
	_rig.zoom_start *= CHAR_SCALE
	_rig.zoom_max = 30.0      # maps are big: let the wheel pull right back
	add_child(_rig)

	_mccoy = PlayerController.new()
	_mccoy.name = "McCoy"
	_mccoy.camera_rig = _rig
	var model := CharacterKit.make_named("mccoy")
	model.scale = Vector3.ONE * CHAR_SCALE
	_mccoy.add_child(model)
	_mccoy.body_scale = CHAR_SCALE
	_mccoy.move_speed = 4.0 * CHAR_SCALE
	_mccoy.interaction_range = 2.5 * CHAR_SCALE
	_mccoy.max_step_height = 0.75 * CHAR_SCALE
	var shape_node := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8 * CHAR_SCALE
	capsule.radius = 0.35 * CHAR_SCALE
	shape_node.shape = capsule
	shape_node.position.y = 0.9 * CHAR_SCALE
	_mccoy.add_child(shape_node)
	add_child(_mccoy)
	_mccoy.input_enabled = false
	_rig.set_target(_mccoy)
	_rig.set_orbit(0.0, 0.25)


func _process(_delta: float) -> void:
	if _keys != null and _keys.visible:
		var vp := get_viewport().get_visible_rect().size
		_keys.position = Vector2(vp.x - _keys.size.x - 16.0, roundf((vp.y - _keys.size.y) * 0.5))
	if _mode == Mode.LOADING:
		_poll_loading()
	elif _mode == Mode.VIEW:
		_refresh_view_keys()


# ------------------------------------------------------------ file list --

func _scan(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	var subs := d.get_directories()
	for sub in subs:
		if sub.begins_with("."):
			continue
		_scan(dir_path.path_join(sub))
	for f in d.get_files():
		var lower := f.to_lower()
		if not lower.ends_with(".glb"):
			continue
		if lower.ends_with("_extra.glb"):
			continue   # loaded together with its map, as in the game
		var path := dir_path.path_join(f)
		var size := 0
		var fa := FileAccess.open(path, FileAccess.READ)
		if fa != null:
			size = fa.get_length()
			fa.close()
		_files.append({"path": path, "folder": dir_path, "name": f, "size": size})


## Map folders first, then the rest of the folders, characters and props last; names in natural order.
static func _group_rank(folder: String) -> int:
	var f := folder.to_lower().trim_prefix(SCAN_ROOT)
	if f.contains("map") or f.contains("rec_deck") or f.contains("rooms") or f.contains("enterprise") or f.contains("sets"):
		return 0
	if f.contains("character") or f.contains("crew") or f.contains("prop") or f.contains("animation"):
		return 2
	return 1


func _file_order(a: Dictionary, b: Dictionary) -> bool:
	var ra := _group_rank(String(a["folder"]))
	var rb := _group_rank(String(b["folder"]))
	if ra != rb:
		return ra < rb
	if a["folder"] != b["folder"]:
		return String(a["folder"]).naturalnocasecmp_to(String(b["folder"])) < 0
	return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0


static func _size_text(bytes: int) -> String:
	if bytes >= 1024 * 1024:
		return "%.1f MB" % (bytes / 1048576.0)
	return "%d KB" % maxi(1, bytes / 1024)


func _matches(e: Dictionary, words: PackedStringArray) -> bool:
	var hay := (String(e["folder"]) + "/" + String(e["name"])).to_lower()
	for w in words:
		if not hay.contains(w):
			return false
	return true


func _fill_tree() -> void:
	_tree.clear()
	var root := _tree.create_item()
	var words := _search.text.strip_edges().to_lower().split(" ", false)
	var folder_item: TreeItem = null
	var last_folder := ""
	var shown := 0
	var keep: TreeItem = null
	for e in _files:
		if not _matches(e, words):
			continue
		if String(e["folder"]) != last_folder:
			last_folder = String(e["folder"])
			folder_item = _tree.create_item(root)
			folder_item.set_text(0, last_folder.trim_prefix("res://").to_upper() + "/")
			folder_item.set_selectable(0, false)
			folder_item.set_selectable(1, false)
			folder_item.set_custom_color(0, UITheme.GOLD)
			if UITheme.font_bold != null:
				folder_item.set_custom_font(0, UITheme.font_bold)
		var it := _tree.create_item(folder_item)
		it.set_text(0, String(e["name"]))
		it.set_text(1, _size_text(int(e["size"])))
		it.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
		it.set_custom_color(1, UITheme.TEXT_DIM)
		it.set_metadata(0, e)
		shown += 1
		if String(e["path"]) == _last_selected:
			keep = it
	var items := _selectable_items()
	if keep == null and not items.is_empty():
		keep = items[0]
	if keep != null:
		keep.select(0)
		_tree.scroll_to_item(keep)
	if _files.is_empty():
		_footer.text = "No .glb files found under assets/. Are the map files in the project folder?"
	elif shown == 0:
		_footer.text = "Nothing matches \"%s\"   (%d files in all)" % [_search.text.strip_edges(), _files.size()]
	else:
		_footer.text = "%d of %d .glb files" % [shown, _files.size()] if shown != _files.size() else "%d .glb files under assets/" % _files.size()


func _selectable_items() -> Array[TreeItem]:
	var out: Array[TreeItem] = []
	var root := _tree.get_root()
	if root == null:
		return out
	for folder in root.get_children():
		for it in folder.get_children():
			out.append(it)
	return out


func _move_selection(step: int) -> void:
	var items := _selectable_items()
	if items.is_empty():
		return
	var i := items.find(_tree.get_selected())
	i = 0 if i < 0 else clampi(i + step, 0, items.size() - 1)
	items[i].select(0)
	_tree.scroll_to_item(items[i])


func _load_selected() -> void:
	var it := _tree.get_selected()
	if it == null or it.get_metadata(0) == null:
		return
	_start_loading(it.get_metadata(0))


# ------------------------------------------------------------ loading --

func _start_loading(entry: Dictionary) -> void:
	if _mode == Mode.LOADING:
		return
	_mode = Mode.LOADING
	_map_entry = entry
	_last_selected = String(entry["path"])
	_loading_path = _last_selected
	_list_root.hide()
	_keys.hide()
	_header.text = ""
	_loading.text = "LOADING  %s   (%s)" % [String(entry["name"]), _size_text(int(entry["size"]))]
	_loading.show()
	_clear_map()
	if ResourceLoader.load_threaded_request(_loading_path) != OK:
		_finish_direct()


func _poll_loading() -> void:
	if _loading_path == "":
		return
	var prog: Array = []
	var st := ResourceLoader.load_threaded_get_status(_loading_path, prog)
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if not prog.is_empty():
			_loading.text = "LOADING  %s   %d%%" % [String(_map_entry["name"]), int(float(prog[0]) * 100.0)]
		return
	var path := _loading_path
	_loading_path = ""
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		var res: Resource = ResourceLoader.load_threaded_get(path)
		if res is PackedScene:
			_place_map((res as PackedScene).instantiate() as Node3D)
			return
	_finish_direct()


## Godot's imported copy didn't load: read the .glb itself (as ModelRoom does since REV 46).
func _finish_direct() -> void:
	_loading_path = ""
	var path := String(_map_entry["path"])
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var deck: Node3D = null
	if doc.append_from_file(ProjectSettings.globalize_path(path), state) == OK:
		deck = doc.generate_scene(state) as Node3D
	_place_map(deck)


func _place_map(deck: Node3D) -> void:
	if deck == null:
		_mode = Mode.LIST
		_loading.hide()
		_show_list()
		_footer.text = "COULD NOT LOAD %s - is it imported? (reopen Godot)" % String(_map_entry["name"])
		return
	var path := String(_map_entry["path"])
	deck.name = "Map"
	add_child(deck)
	_map = deck
	var extra_path := path.get_basename() + "_extra.glb"
	if ResourceLoader.exists(extra_path):
		var extra_packed: Resource = load(extra_path)
		if extra_packed is PackedScene:
			var extra := (extra_packed as PackedScene).instantiate() as Node3D
			extra.name = "MapExtra"
			deck.add_child(extra)
	_loading.text = "PREPARING  %s   (textures, walls, lighting)" % String(_map_entry["name"])
	await get_tree().process_frame
	await get_tree().process_frame
	if _map != deck:
		return
	HdTextures.apply(deck)
	# The game's own code for water, collision and baked light, so the map looks as it does in a room.
	var helper: Node = (load(MODEL_ROOM_SCRIPT) as GDScript).new()
	helper.call("_load_cfg")
	var lm := _find_lightmap(path)
	var cfg: Dictionary = helper.get("cfg")
	cfg["lightmap"] = lm
	helper.call("_setup_water", deck)
	helper.call("_add_collision", deck)
	if lm != "" and ResourceLoader.exists(String(helper.get("SHADER_PATH"))):
		helper.call("_apply_lighting", deck)
		_lighting_note = "baked light (%s)" % lm.get_file()
	else:
		_lighting_note = "no lightmap found - L for full-bright"
	helper.free()
	_saved_overrides.clear()
	if _full_bright:
		_set_full_bright(true, true)

	# Start point: the middle of the map, dropped onto the floor below it if there is one.
	var box := _mesh_aabb(deck)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _map != deck:
		return
	_find_start(box)
	_go_to_start()
	_loading.hide()
	_header.text = "%s     %s     %s     %s" % [String(_map_entry["name"]), String(_map_entry["folder"]).trim_prefix("res://") + "/", _size_text(int(_map_entry["size"])), _lighting_note]
	_mode = Mode.VIEW
	_keys.show()
	_keys_hidden = false
	_mccoy.input_enabled = true
	if _first_load:
		_first_load = false
		_mccoy.call("_set_flying", true)
	get_viewport().gui_release_focus()


func _find_lightmap(path: String) -> String:
	var known := String(KNOWN_LIGHTMAPS.get(path.get_file(), ""))
	if known != "" and ResourceLoader.exists(known):
		return known
	var base := path.get_basename()
	var cands: Array[String] = [base + "_lightmap.png"]
	var cut := base.rfind("_")
	if cut > 0:
		cands.append(base.substr(0, cut) + "_full_lightmap.png")
		cands.append(base.substr(0, cut) + "_lightmap.png")
	for p in cands:
		if ResourceLoader.exists(p):
			return p
	return ""


func _mesh_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out


func _clear_map() -> void:
	_saved_overrides.clear()
	if _map != null:
		remove_child(_map)
		_map.queue_free()
		_map = null


func _go_to_start() -> void:
	_mccoy.global_position = _start_pos
	_mccoy.velocity = Vector3.ZERO
	_mccoy.rotation.y = atan2(-_start_open.x, -_start_open.z)
	_mccoy.reset_physics_interpolation()
	_rig.set_orbit(atan2(_start_open.x, _start_open.z), 0.25)


## The start point: an indoor floor with room to stand and look around, as near the middle of the map as
## possible. Looks down a grid of columns over the whole map, tries every floor in each column (so every
## deck of a multi-level map counts), and scores each by how open it is around head height. A spot needs
## a ceiling somewhere above it, so the outside of a hull roof never wins. Falls back to the middle.
func _find_start(box: AABB) -> void:
	var space := get_world_3d().direct_space_state
	var mid := box.get_center()
	_start_pos = mid
	_start_open = Vector3.BACK
	var best := 0.0
	const N := 14
	for ix in N:
		for iz in N:
			var x := box.position.x + box.size.x * (ix + 0.5) / N
			var z := box.position.z + box.size.z * (iz + 0.5) / N
			var from := Vector3(x, box.end.y + 1.0, z)
			var bottom := Vector3(x, box.position.y - 1.0, z)
			for _floor in 16:
				var hit := _ray(space, from, bottom)
				if hit.is_empty():
					break
				var p: Vector3 = hit["position"]
				if Vector3(hit["normal"]).y > 0.7:
					var open := _openness(space, p)
					if open.w > 0.0:
						var score := open.w - p.distance_to(mid) * 0.02
						if score > best:
							best = score
							_start_pos = p + Vector3.UP * 0.05
							_start_open = Vector3(open.x, 0.0, open.z)
				from = p + Vector3.DOWN * 0.05


## How open a floor spot is: x, z = the most open direction, w = score (0 = no good: too low a ceiling,
## or no ceiling at all, i.e. outdoors on a roof).
func _openness(space: PhysicsDirectSpaceState3D, p: Vector3) -> Vector4:
	if not _ray(space, p + Vector3.UP * 0.1, p + Vector3.UP * 2.4).is_empty():
		return Vector4.ZERO
	if _ray(space, p + Vector3.UP * 2.4, p + Vector3.UP * 14.0).is_empty():
		return Vector4.ZERO
	var head := p + Vector3.UP * 1.3
	var total := 0.0
	var far := 0.0
	var far_dir := Vector3.BACK
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector3(sin(a), 0.0, cos(a))
		var h := _ray(space, head, head + d * 5.0)
		var clear := 5.0 if h.is_empty() else head.distance_to(Vector3(h["position"]))
		total += clear
		if clear > far:
			far = clear
			far_dir = d
	return Vector4(far_dir.x, 0.0, far_dir.z, total)


func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [_mccoy.get_rid()]
	return space.intersect_ray(q)


# ---------------------------------------------------------- full-bright --

## Full-bright: every surface drawn with its plain texture and no lighting at all. The game's baked-light
## materials are put aside while it is on (they do their own lighting) and put back when it goes off.
func _set_full_bright(on: bool, force: bool = false) -> void:
	if on == _full_bright and not force:
		return
	_full_bright = on
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_UNSHADED if on else Viewport.DEBUG_DRAW_DISABLED
	if _map == null:
		return
	if on:
		_saved_overrides.clear()
		for mi in _map.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			for s in m.mesh.get_surface_count():
				var o: Material = m.get_surface_override_material(s)
				if o is ShaderMaterial:
					_saved_overrides.append([m, s, o])
					m.set_surface_override_material(s, null)
	else:
		for rec in _saved_overrides:
			var m := rec[0] as MeshInstance3D
			if is_instance_valid(m):
				m.set_surface_override_material(int(rec[1]), rec[2])
		_saved_overrides.clear()


# --------------------------------------------------------------- input --

func _input(event: InputEvent) -> void:
	if _mode != Mode.LIST:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	match k.keycode:
		KEY_ESCAPE:
			if not k.echo:
				_leave_to_menu()
		KEY_UP:
			_move_selection(-1)
		KEY_DOWN:
			_move_selection(1)
		KEY_PAGEUP:
			_move_selection(-10)
		KEY_PAGEDOWN:
			_move_selection(10)
		KEY_ENTER, KEY_KP_ENTER:
			if not k.echo:
				_load_selected()
		_:
			return
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _mode != Mode.VIEW or PhotoMode.active:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.shift_pressed or k.ctrl_pressed or k.alt_pressed:
		return   # Shift+F (fly) and friends belong to McCoy
	match k.keycode:
		KEY_ESCAPE:
			_show_list()
		KEY_L:
			_set_full_bright(not _full_bright)
		KEY_HOME:
			_go_to_start()
		KEY_H:
			_keys_hidden = not _keys_hidden
			_keys.visible = not _keys_hidden
		_:
			return
	get_viewport().set_input_as_handled()


func _show_list() -> void:
	_mode = Mode.LIST
	_mccoy.input_enabled = false
	_mccoy.velocity = Vector3.ZERO
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_header.text = ""
	_list_root.show()
	_keys.show()
	(_keys as Object).call("set_rows", _list_keys())
	_fill_tree()
	_search.grab_focus.call_deferred()


func _leave_to_menu() -> void:
	_mode = Mode.LOADING     # no more input while we fade
	SaveSystem.return_to_main_menu(MAIN_MENU_SCENE)


# ------------------------------------------------------------------ UI --

func _setup_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)

	_list_root = Control.new()
	_list_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_list_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(_list_root)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.015, 0.022, 0.97)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_list_root.add_child(shade)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 48
	col.offset_top = 28
	col.offset_right = -340
	col.offset_bottom = -24
	col.add_theme_constant_override("separation", 8)
	_list_root.add_child(col)

	var title := Label.new()
	title.text = "MAP VIEWER"
	UITheme.style_title(title)
	title.add_theme_font_size_override("font_size", 22)
	col.add_child(title)
	var sub := Label.new()
	sub.text = "Every .glb file in the project's assets folder. Map folders are at the top."
	UITheme.style_hint(sub)
	col.add_child(sub)

	_search = LineEdit.new()
	_search.placeholder_text = "Type to search  (e.g. transporter, aedeck, enterprise)"
	_search.custom_minimum_size = Vector2(0, 34)
	if UITheme.font_body != null:
		_search.add_theme_font_override("font", UITheme.font_body)
	_search.add_theme_font_size_override("font_size", 15 + UITheme.body_size_bonus)
	_search.add_theme_stylebox_override("normal", UITheme.panel_stylebox(UITheme.GOLD_DIM))
	_search.add_theme_stylebox_override("focus", UITheme.panel_stylebox(UITheme.GOLD))
	_search.text_changed.connect(func(_t: String) -> void: _fill_tree())
	col.add_child(_search)

	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.columns = 2
	_tree.select_mode = Tree.SELECT_ROW
	_tree.focus_mode = Control.FOCUS_NONE     # the search box keeps the keyboard; arrows are passed on
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 110)
	if UITheme.font_body != null:
		_tree.add_theme_font_override("font", UITheme.font_body)
	_tree.add_theme_font_size_override("font_size", 14 + UITheme.body_size_bonus)
	_tree.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	_tree.add_theme_color_override("font_selected_color", Color(1, 1, 1))
	_tree.add_theme_stylebox_override("panel", UITheme.panel_stylebox(UITheme.GOLD_DIM))
	var sel := StyleBoxFlat.new()
	sel.bg_color = UITheme.BUTTON_BG_ACTIVE
	sel.border_color = UITheme.GOLD
	sel.set_border_width_all(1)
	_tree.add_theme_stylebox_override("selected", sel)
	_tree.add_theme_stylebox_override("selected_focus", sel)
	_tree.item_activated.connect(_load_selected)
	col.add_child(_tree)

	_footer = Label.new()
	UITheme.style_hint(_footer)
	col.add_child(_footer)

	_loading = Label.new()
	_loading.set_anchors_preset(Control.PRESET_CENTER)
	_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loading.offset_left = -400
	_loading.offset_right = 400
	UITheme.style_title(_loading)
	_loading.hide()
	_ui.add_child(_loading)

	_header = Label.new()
	_header.position = Vector2(12, 12)
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_heading(_header)
	_header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_header.add_theme_constant_override("outline_size", 4)
	_ui.add_child(_header)

	_keys = KeyList.new()
	_ui.add_child(_keys)


func _list_keys() -> Array:
	return [
		["# MAP LIST"],
		["TYPE", "Search by name or folder"],
		["UP / DOWN", "Choose a file"],
		["PAGE UP / DOWN", "Jump ten files"],
		["ENTER", "Load it"],
		["DOUBLE-CLICK", "Load it"],
		["ESC", "Back to the main menu"],
	]


func _move_keys() -> String:
	var parts: Array[String] = []
	for a in ["move_forward", "move_left", "move_back", "move_right"]:
		var k := InputHints.key(a)
		if k != "" and not parts.has(k):
			parts.append(k)
	return " ".join(parts)


func _pair(a: String, b: String) -> String:
	var ka := InputHints.key(a)
	var kb := InputHints.key(b)
	if ka == "" or kb == "":
		return ka + kb
	return ka + " / " + kb


func _refresh_view_keys() -> void:
	if _keys_hidden:
		return
	var flying := _mccoy.flying
	var pad := InputHints.using_gamepad
	var run := InputHints.key("run")
	var rows: Array = [
		["# EXPLORING"],
		[_move_keys(), "Move McCoy"],
		["" if pad else "RIGHT-DRAG", "Turn the camera"],
		[_pair("camera_orbit_left", "camera_orbit_right"), "Turn the camera (keys)"],
		["" if pad else "MOUSE WHEEL", "Zoom in / out"],
		[("" if pad else ("SHIFT" if flying else run)), "Fly 3x faster" if flying else "Run (hold)"],
	]
	if flying:
		rows.append(["R / PAGE UP", "Fly up"])
		rows.append(["V / PAGE DOWN", "Fly down"])
	else:
		rows.append(["" if pad else "BOTH BUTTONS", "Walk forward"])
	rows.append(["SHIFT + F", "Walls: FLY THROUGH  (now on)" if flying else "Walls: SOLID  (now on)"])
	rows.append(["# VIEW"])
	rows.append(["L", "Full-bright: " + ("ON" if _full_bright else "OFF")])
	rows.append(["HOME", "Back to the start point"])
	rows.append([InputHints.key("photo_mode"), "Photo mode"])
	rows.append(["F3", "Position read-out"])
	rows.append(["H", "Hide this list"])
	rows.append(["ESC", "Back to the map list"])
	(_keys as Object).call("set_rows", rows)
