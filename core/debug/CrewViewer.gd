extends Node3D
## REV 180: DEBUG: CREW VIEWER (main menu, debug builds only).
##
## A line-up of the generated background crew (CrewRoster + CrewLooks), six at a time, each with their
## name, job and shirt as the game shows them. For judging faces, skins, hair and uniforms without
## walking the ship.
##   Left / Right   previous / next six          F   faces close-up / whole figures
##   N              a new crew (a new seed)      Esc back to the main menu
##   1 / 2 / 3      everyone / aboard on watch / aboard off duty
##   T              REV 221: the kit catalogue - crew / every hair style / every skin / every face
##                  (each on its own, on the plain base face), M switches women / men there
## Nothing here is saved.

const MAIN_MENU_SCENE := "res://core/menu/MainMenu.tscn"
const PER_PAGE := 6
const GAP := 0.9

var _ids: Array = []
var _page := 0
var _close := false
var _filter := 0
const MODES := ["crew", "hair", "skins", "faces"]
var _mode := 0
var _sex := "female"
var _row: Node3D
var _cam: Camera3D
var _label: Label


func _ready() -> void:
	SaveSystem.scene_state_provider = Callable()
	SaveSystem.busy_reason_provider = func(_for_load: bool) -> String: return "Saving is off in the crew viewer."
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.14, 0.17)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 25, 0)
	key.light_energy = 1.2
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -140, 0)
	fill.light_energy = 0.35
	add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 10)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.22, 0.22, 0.25)
	floor_mesh.material_override = fm
	add_child(floor_mesh)
	_cam = Camera3D.new()
	_cam.fov = 35
	add_child(_cam)
	_cam.current = true
	var ui := CanvasLayer.new()
	add_child(ui)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 16)
	ui.add_child(_label)
	_refresh_ids()
	_show()


func _refresh_ids() -> void:
	if _mode > 0:
		_ids = CrewLooks.kit_names(_sex, MODES[_mode])
		_page = clampi(_page, 0, maxi(0, (_ids.size() - 1) / PER_PAGE))
		return
	var crew := CrewRoster.roster()
	_ids = []
	for pid in crew:
		var c: Dictionary = crew[pid]
		match _filter:
			1:
				if not (CrewRoster.is_aboard(pid) and bool(c["on_watch"])):
					continue
			2:
				if not (CrewRoster.is_aboard(pid) and not bool(c["on_watch"])):
					continue
		_ids.append(pid)
	_ids.sort()
	_page = clampi(_page, 0, maxi(0, (_ids.size() - 1) / PER_PAGE))


func _show() -> void:
	if _row != null:
		_row.queue_free()
	_row = Node3D.new()
	add_child(_row)
	var start := _page * PER_PAGE
	var shown := _ids.slice(start, start + PER_PAGE)
	for i in shown.size():
		var pid: String = shown[i]
		var fig: Node3D
		if _mode > 0:
			fig = _catalogue_figure(pid)
			if fig == null:
				continue
			fig.position = Vector3((i - (shown.size() - 1) * 0.5) * GAP, 0, 0)
			_row.add_child(fig)
			var t2 := Label3D.new()
			t2.text = "%s\n%s" % [pid, MODES[_mode]]
			t2.font_size = 22
			t2.pixel_size = 0.0016
			t2.position = fig.position + Vector3(0, 2.02, 0)
			t2.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_row.add_child(t2)
			continue
		fig = CrewLooks.make(pid, {"solid": false})
		if fig == null:
			continue
		fig.position = Vector3((i - (shown.size() - 1) * 0.5) * GAP, 0, 0)
		_row.add_child(fig)
		var tag := Label3D.new()
		var post := CrewRoster.post_of(pid)
		var p := CrewRoster.person(pid)
		tag.text = "%s\n%s\n%s %s, %s" % [CrewRoster.display_name(pid), CrewRoster.job_line(pid), p.get("first_name", ""), p.get("surname", ""), String(p.get("heritage", "")).replace("_", " ")]
		tag.font_size = 22
		tag.pixel_size = 0.0016
		tag.position = fig.position + Vector3(0, 2.02, 0)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_row.add_child(tag)
	_frame()
	if _mode > 0:
		_label.text = "CREW VIEWER - %s %s (%d)   page %d / %d\nLeft/Right page   F faces / figures   T crew/hair/skins/faces   M women/men   Esc menu" % [
			"women's" if _sex == "female" else "men's", MODES[_mode], _ids.size(), _page + 1, maxi(1, (_ids.size() + PER_PAGE - 1) / PER_PAGE)]
		return
	var names := ["everyone", "aboard, on watch", "aboard, off duty"]
	_label.text = "CREW VIEWER - %s (%d people)   page %d / %d   seed %d\nLeft/Right page   F faces / figures   N new crew   1/2/3 everyone / on watch / off duty   Esc menu" % [
		names[_filter], _ids.size(), _page + 1, maxi(1, (_ids.size() + PER_PAGE - 1) / PER_PAGE), CrewRoster.crew_seed()]


func _catalogue_figure(item: String) -> Node3D:
	var look := {"mix": {}, "skin": "", "hair": "", "hair_tint": [0.55, 0.45, 0.35], "skin_tint": [1, 1, 1], "height": 1.0}
	match MODES[_mode]:
		"hair":
			look["hair"] = item
		"skins":
			look["skin"] = item
			look["hair"] = "base" if _sex == "female" else ""
		"faces":
			var mix := {}
			for r in ["eyes", "brow", "nose", "mouth", "jaw", "cheeks", "ears", "rest"]:
				mix[r] = {item: 1.0}
			look["mix"] = mix
			look["skin"] = item if CrewLooks.kit_names(_sex, "skins").has(item) else ""
			look["hair"] = "base" if _sex == "female" else ""
	return CrewLooks.make_with_look(_sex, look)


func _frame() -> void:
	if _close:
		_cam.position = Vector3(0, 1.62, 2.4)
		_cam.look_at(Vector3(0, 1.6, 0))
	else:
		_cam.position = Vector3(0, 1.15, 5.6)
		_cam.look_at(Vector3(0, 1.0, 0))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_RIGHT:
			_page = mini(_page + 1, maxi(0, (_ids.size() - 1) / PER_PAGE))
			_show()
		KEY_LEFT:
			_page = maxi(_page - 1, 0)
			_show()
		KEY_F:
			_close = not _close
			_frame()
		KEY_N:
			# a new crew: new seed, forget the looks pinned for the old one
			for k in WorldState.snapshot().keys():
				if String(k).begins_with(CrewLooks.KEY_LOOK):
					WorldState.erase(k)
			WorldState.erase(CrewRoster.KEY_SEED)
			_page = 0
			_refresh_ids()
			_show()
		KEY_1, KEY_2, KEY_3:
			_filter = int((event as InputEventKey).keycode - KEY_1)
			_page = 0
			_refresh_ids()
			_show()
		KEY_T:
			_mode = (_mode + 1) % MODES.size()
			_page = 0
			_refresh_ids()
			_show()
		KEY_M:
			_sex = "male" if _sex == "female" else "female"
			_page = 0
			_refresh_ids()
			_show()
		KEY_ESCAPE:
			SaveSystem.return_to_main_menu(MAIN_MENU_SCENE)
	get_viewport().set_input_as_handled()
