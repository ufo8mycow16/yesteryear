extends RefCounted
class_name RoomLoader
## RoomLoader (REV 101): loads the next room while the screen is black, instead of freezing.
##
## The big maps (the Enterprise decks, the Daedalus) are separate .glb files that a room loads when
## it starts. Before, all of that was read and decoded in one go after the scene changed, so the
## game sat frozen on black. Now EpisodeRoom.go_to() asks for the room's scene AND its map files to
## be read in the background while the screen fades out, shows a small location card if that takes
## more than a moment, and only then changes scene - by which time the files are already in memory
## and the room's own load() calls return straight away.
##
## The loaded files are held (`_held`) until the next room change, so Godot's resource cache keeps
## them for the new room to pick up.

const CARD_DELAY := 0.25         # only show the card if loading takes longer than this (no flash)
static var _held: Array = []
static var _card_layer: CanvasLayer = null


## Every file a scene will need straight away: the scene itself, plus a model room's map, the map's
## extra pieces and its lightmap (asked for without starting the room: model_config() just reports).
static func files_for(scene_path: String) -> PackedStringArray:
	var out := PackedStringArray([scene_path])
	var packed: PackedScene = load(scene_path) as PackedScene   # the .tscn itself is tiny
	if packed == null:
		return out
	var probe: Node = packed.instantiate()
	if probe != null:
		if probe.has_method("model_config"):
			var cfg: Dictionary = probe.call("model_config")
			for key in ["model", "lightmap"]:
				var p := String(cfg.get(key, ""))
				if p != "" and ResourceLoader.exists(p):
					out.append(p)
			var model := String(cfg.get("model", ""))
			if model != "":
				var extra := model.get_basename() + "_extra.glb"
				if ResourceLoader.exists(extra):
					out.append(extra)
		probe.free()
	return out


## Read `scene_path` and its files in the background, showing `title` on the black screen if it takes
## a while, then change to it. Call with the screen already faded to black.
static func change_to(tree: SceneTree, scene_path: String, title: String = "") -> void:
	var files := files_for(scene_path)
	for p in files:
		ResourceLoader.load_threaded_request(p, "", true)
	var waited := 0.0
	while true:
		var busy := false
		for p in files:
			if ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				busy = true
		if not busy:
			break
		await tree.process_frame
		waited += tree.root.get_process_delta_time()
		if waited > CARD_DELAY and _card_layer == null:
			_show_card(tree, title)
		_animate_card(waited)
	# keep them in memory across the scene change (and drop the previous room's)
	var keep: Array = []
	var scene: PackedScene = null
	for p in files:
		if ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_LOADED:
			var r := ResourceLoader.load_threaded_get(p)
			keep.append(r)
			if p == scene_path:
				scene = r as PackedScene
	_held = keep
	if scene != null:
		tree.change_scene_to_packed(scene)
	else:
		tree.change_scene_to_file(scene_path)   # the old way, if the background read failed
	# the card goes once the new room has started (it fades itself up from black). Not awaited:
	# the caller's room is on its way out and must finish in this frame.
	if _card_layer != null:
		_hide_card_soon(tree)


static func _hide_card_soon(tree: SceneTree) -> void:
	await tree.process_frame
	await tree.process_frame
	_hide_card()


static func _show_card(tree: SceneTree, title: String) -> void:
	_card_layer = CanvasLayer.new()
	_card_layer.layer = 40      # above a room's own fade (30)
	tree.root.add_child(_card_layer)
	var box := VBoxContainer.new()
	box.name = "Card"
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.offset_left = -420.0
	box.offset_top = -96.0
	box.offset_right = -36.0
	box.offset_bottom = -36.0
	box.alignment = BoxContainer.ALIGNMENT_END
	_card_layer.add_child(box)
	if title != "":
		var t := Label.new()
		t.text = title.to_upper()
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if UITheme.font_bold != null:
			t.add_theme_font_override("font", UITheme.font_bold)
		t.add_theme_font_size_override("font_size", 16)
		t.add_theme_color_override("font_color", UITheme.GOLD)
		box.add_child(t)
	var l := Label.new()
	l.name = "Loading"
	l.text = "LOADING"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if UITheme.font_regular != null:
		l.add_theme_font_override("font", UITheme.font_regular)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	box.add_child(l)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, UITheme.ANIM_MODAL)


static func _animate_card(t: float) -> void:
	if _card_layer == null:
		return
	var l := _card_layer.get_node_or_null("Card/Loading") as Label
	if l != null:
		l.text = "LOADING" + ".".repeat(int(t * 3.0) % 4)


static func _hide_card() -> void:
	if _card_layer == null:
		return
	var layer := _card_layer
	_card_layer = null
	var box := layer.get_node_or_null("Card") as Control
	if box == null:
		layer.queue_free()
		return
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 0.0, UITheme.ANIM_MODAL)
	tw.tween_callback(layer.queue_free)
