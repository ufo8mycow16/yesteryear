extends Node
## SaveSystem — the one save/load system for the whole game.
##
## The Prologue's four narrative checkpoints (AUTO_SAVE_PRO_001-004) are
## TRIGGER POINTS into this generic system, not a separate save mechanism.
## Save files live under user://saves/ — Godot's user:// maps to the
## platform's standard per-user data directory (on Linux,
## ~/.local/share/godot/app_userdata/<project name>/saves/), which already
## satisfies the locked "stable, persistent, user-accessible location outside
## the installation directory" requirement without any custom path logic.
##
## SLOT KINDS
##   "manual"  20 player-chosen slots (SYSTEM menu > SAVE GAME)
##   "auto"    5 rotating slots written at story checkpoints
##   "quick"   the single F5 / F6 slot
##
## HOW A LOAD WORKS
## A load never patches a running scene. It stores the save as the "pending
## load", clears transient state (voice lines, conversation, interaction), and
## reloads the scene; the scene's _ready() then calls take_pending_load() and
## rebuilds itself from the save instead of playing its opening. That is what
## makes loading identical whether it is the first thing you do or deep into a
## session.
##
## WHAT A SAVE HOLDS
##   game_state    every VAR_* flag (GameState)
##   mission_log   mission log entry text
##   objective     the current objective id
##   inventory     collected item ids
##   scene_state   scene-specific extras given by the running scene through
##                 scene_state_provider (player position, camera, per-hotspot
##                 progress...)
##   play_time     seconds played

const SAVE_ROOT := "user://saves/"
## REV 104: where saves go. The automatic testers (tools/qa) point this at user://qa_saves/ so a test
## run never touches the player's real saves or autosaves.
var save_root: String = SAVE_ROOT
const MANUAL_SLOT_COUNT := 20
const AUTOSAVE_SLOT_COUNT := 5
const SAVE_VERSION := 2

## Episode content modules register a resolver so save data (which stores
## item ids as plain strings) can be turned back into the actual
## InventoryItemData Resources on load.
## REV 293: optional now. Without one (or when it doesn't know an id) the item is still found:
## see resolve_inventory_item. So no backpack item vanishes on load.
var inventory_item_resolver: Callable = Callable()

## Registered by the running scene (and cleared when a load replaces it):
##   scene_state_provider  () -> Dictionary    scene-specific data to save
##   busy_reason_provider  (for_load: bool) -> String
##                         "" if saving/loading is fine right now, otherwise a
##                         short player-facing reason it isn't (a cutscene is
##                         playing, a conversation is open, etc.)
var scene_state_provider: Callable = Callable()
var busy_reason_provider: Callable = Callable()

var play_time_seconds: float = 0.0

var _autosave_cursor: int = 0
var _pending_load: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(save_root)
	# Continue the autosave rotation after the newest existing slot, so a
	# restart doesn't overwrite a newer autosave while older ones survive.
	var newest_time := -1
	for i in range(AUTOSAVE_SLOT_COUNT):
		var info := get_slot_info("auto", i)
		if info.get("exists", false) and int(info.get("timestamp", 0)) > newest_time:
			newest_time = int(info.get("timestamp", 0))
			_autosave_cursor = (i + 1) % AUTOSAVE_SLOT_COUNT


func _process(delta: float) -> void:
	# Only counts while a scene is actually registered as running.
	if busy_reason_provider.is_valid():
		play_time_seconds += delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		quick_save()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		quick_load()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- paths ----

func _slot_path(kind: String, index: int) -> String:
	return save_root.path_join("%s_%02d.json" % [kind, index])


func _quick_path() -> String:
	return save_root.path_join("quicksave.json")


func path_for(kind: String, index: int) -> String:
	if kind == "quick":
		return _quick_path()
	return _slot_path(kind, index)


# ----------------------------------------------------------- read / write ---

func _build_save_blob(checkpoint_id: String) -> Dictionary:
	var objective_text := ""
	var objective: ObjectiveData = ObjectiveManager.get_current_objective()
	if objective != null:
		objective_text = objective.text
	var scene_state := {}
	if scene_state_provider.is_valid():
		scene_state = scene_state_provider.call()
	return {
		"version": SAVE_VERSION,
		"checkpoint_id": checkpoint_id,
		"timestamp_unix": Time.get_unix_time_from_system(),
		"play_time": play_time_seconds,
		"summary": objective_text,
		"location": String(get_tree().current_scene.call("location_name")) if get_tree().current_scene != null and get_tree().current_scene.has_method("location_name") else "",
		"current_scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else "",
		"game_state": GameState.get_snapshot(),
		"mission_log": MissionLog.get_snapshot(),
		"objective": ObjectiveManager.get_snapshot(),
		"inventory_item_ids": InventoryManager.get_snapshot(),
		"inventory_items": _inventory_details(),     # REV 293: names etc., so any item can be rebuilt
		"scene_state": scene_state,
	}


## REV 116: the picture shown beside a save in the Save/Load list - what was on screen just
## before the pause menu opened (remember_screen), or the current frame for quick saves and
## autosaves. 320 x 180, saved next to the save as <name>.png.
const THUMB_SIZE := Vector2i(320, 180)
var _screen_shot: Image = null
var _screen_shot_time := -1.0


## Called as a menu opens: the frame on screen right now is the game without the menu over it.
func remember_screen() -> void:
	var vp := get_viewport()
	if vp == null or DisplayServer.get_name() == "headless":
		return
	var img := vp.get_texture().get_image()
	if img != null and not img.is_empty():
		_screen_shot = img
		_screen_shot_time = Time.get_ticks_msec() / 1000.0


func thumb_path(save_path: String) -> String:
	return save_path.get_basename() + ".png"


func _write_thumb(save_path: String) -> void:
	var img: Image = null
	if _screen_shot != null and Time.get_ticks_msec() / 1000.0 - _screen_shot_time < 600.0:
		img = _screen_shot.duplicate()
	elif DisplayServer.get_name() != "headless":
		img = get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	# crop to 16:9 from the middle, then shrink
	var w := img.get_width()
	var h := img.get_height()
	var want_h := int(w * 9.0 / 16.0)
	if want_h < h:
		img = img.get_region(Rect2i(0, (h - want_h) / 2, w, want_h))
	elif want_h > h:
		var want_w := int(h * 16.0 / 9.0)
		img = img.get_region(Rect2i((w - want_w) / 2, 0, want_w, h))
	img.resize(THUMB_SIZE.x, THUMB_SIZE.y, Image.INTERPOLATE_LANCZOS)
	img.save_png(thumb_path(save_path))


## The thumbnail for a slot, or null.
func get_slot_thumb(kind: String, index: int) -> Texture2D:
	var p := thumb_path(path_for(kind, index))
	if not FileAccess.file_exists(p):
		return null
	var img := Image.load_from_file(p)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


func _write(path: String, blob: Dictionary) -> bool:
	# Written to a temporary file first and then moved into place, so a crash
	# or power cut mid-save can never leave a half-written (corrupt) save.
	BuildInfo.flash_saving()   # REV 102: the little SAVING badge
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: failed to open %s for writing (%s)" % [temp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(blob, "\t"))
	file.close()
	var dir := DirAccess.open(save_root)
	if dir == null:
		return false
	if FileAccess.file_exists(path):
		dir.remove(path.get_file())
	var err := dir.rename(temp_path.get_file(), path.get_file())
	if err != OK:
		push_error("SaveSystem: could not finish writing %s (%s)" % [path, error_string(err)])
		return false
	_write_thumb(path)
	return true


func _read(path: String, quiet: bool = false) -> Dictionary:
	if not FileAccess.file_exists(path):
		if not quiet:
			push_warning("SaveSystem: no save file at %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		if not quiet:
			push_error("SaveSystem: save file at %s is not valid JSON" % path)
		return {}
	return parsed


## What the load/save lists show for one slot. {} fields absent when empty.
func get_slot_info(kind: String, index: int) -> Dictionary:
	var blob := _read(path_for(kind, index), true)
	if blob.is_empty():
		return {"exists": false}
	return {
		"exists": true,
		"timestamp": int(blob.get("timestamp_unix", 0)),
		"play_time": float(blob.get("play_time", 0.0)),
		"summary": String(blob.get("summary", "")),
		"checkpoint": String(blob.get("checkpoint_id", "")),
		"location": String(blob.get("location", "")),
	}


# -------------------------------------------------------------- toasts -----

func _toast(message: String) -> void:
	# The HUD already shows MissionLog notifications as a brief fading banner.
	MissionLog.notification_requested.emit(message)


func get_busy_reason(for_load: bool) -> String:
	if busy_reason_provider.is_valid():
		return String(busy_reason_provider.call(for_load))
	return ""


# ------------------------------------------------------------------ saving --

## Returns "" on success, otherwise a short message saying why not.
func save_slot(kind: String, index: int, checkpoint_id: String = "") -> String:
	var reason := get_busy_reason(false)
	if reason != "":
		return reason
	var label := "MANUAL_SAVE" if kind == "manual" else checkpoint_id
	if not _write(path_for(kind, index), _build_save_blob(label)):
		return "The save could not be written."
	return ""


func save_manual(slot: int) -> String:
	assert(slot >= 0 and slot < MANUAL_SLOT_COUNT)
	var result := save_slot("manual", slot)
	if result == "":
		_toast("Game Saved")
	return result


func quick_save() -> bool:
	var result := save_slot("quick", 0, "QUICK_SAVE")
	if result == "":
		_toast("Quick Saved")
		return true
	_toast("Can't save: " + result)
	return false


## Called at the four Prologue checkpoints (and by every future episode's
## equivalent checkpoints): AUTO_SAVE_PRO_001 .. AUTO_SAVE_PRO_004. Writes
## regardless of the busy state: a story checkpoint is never refused.
func checkpoint(checkpoint_id: String) -> bool:
	var ok := _write(_slot_path("auto", _autosave_cursor), _build_save_blob(checkpoint_id))
	_autosave_cursor = (_autosave_cursor + 1) % AUTOSAVE_SLOT_COUNT
	return ok


# ----------------------------------------------------------------- loading --

## Returns "" on success (the scene is then being reloaded), otherwise a
## short message saying why not.
func load_slot(kind: String, index: int) -> String:
	var reason := get_busy_reason(true)
	if reason != "":
		return reason
	var blob := _read(path_for(kind, index))
	if blob.is_empty():
		return "That save could not be read."
	var problem := check_compatible(blob)
	if problem != "":
		return problem
	_begin_load(_migrate(blob))
	return ""


## REV 104: can this version of the game load that save? "" = yes, else a short reason for the player.
func check_compatible(blob: Dictionary) -> String:
	if int(blob.get("version", 1)) > SAVE_VERSION:
		return "That save was made by a newer version of the game. Please update."
	var scene_path := String(blob.get("current_scene", ""))
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return "That save's location isn't in this version of the game."
	return ""


## REV 104: brings a save from an older SAVE_VERSION up to date. Nothing has needed converting yet
## (story values that are new since the save get their defaults - see GameState.load_snapshot).
## When the save format changes, bump SAVE_VERSION and add a step here, e.g.
##     if int(blob.get("version", 1)) < 3:  ...convert...;  blob["version"] = 3
func _migrate(blob: Dictionary) -> Dictionary:
	var b := blob.duplicate(true)
	b["version"] = SAVE_VERSION
	return b


func quick_load() -> bool:
	if not FileAccess.file_exists(_quick_path()):
		_toast("No quick save to load")
		return false
	var result := load_slot("quick", 0)
	if result != "":
		_toast("Can't load: " + result)
		return false
	return true


func load_latest_autosave() -> bool:
	var newest_index := -1
	var newest_time := -1
	for i in range(AUTOSAVE_SLOT_COUNT):
		var info := get_slot_info("auto", i)
		if info.get("exists", false) and int(info.get("timestamp", 0)) > newest_time:
			newest_time = int(info.get("timestamp", 0))
			newest_index = i
	if newest_index < 0:
		return false
	return load_slot("auto", newest_index) == ""


func _begin_load(blob: Dictionary) -> void:
	_pending_load = blob
	play_time_seconds = float(blob.get("play_time", 0.0))
	# Whatever the old scene was doing is over: silence its voice line, drop
	# its conversation and interaction state, and stop counting play time until
	# the new scene registers itself.
	AudioSubtitleManager.stop_all()
	DialogueManager.reset()
	InteractionManager.reset_for_load()
	scene_state_provider = Callable()
	busy_reason_provider = Callable()
	get_tree().paused = false      # REV 105: loading from the pause menu - the new scene must run
	var scene_path := String(blob.get("current_scene", ""))
	if scene_path != "" and ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		get_tree().reload_current_scene()


## Leaves the running game for the main menu, clearing the same live state a
## load clears (voice line, conversation, interaction, scene hooks).
func return_to_main_menu(menu_scene_path: String) -> void:
	_pending_load = {}
	AudioSubtitleManager.stop_all()
	DialogueManager.reset()
	InteractionManager.reset_for_load()
	scene_state_provider = Callable()
	busy_reason_provider = Callable()
	get_tree().paused = false
	get_tree().change_scene_to_file(menu_scene_path)


## The freshly loaded scene calls this first thing in _ready(). Returns the
## save to restore from, or {} for a normal new start. Cleared once taken.
func take_pending_load() -> Dictionary:
	var blob := _pending_load
	_pending_load = {}
	return blob


## Step 1 for the scene, BEFORE it builds anything that reads variables.
func restore_game_state(blob: Dictionary) -> void:
	var state: Dictionary = _whole_numbers(blob.get("game_state", {}))
	GameState.load_snapshot(state)


## Step 2 for the scene, AFTER it has registered its mission log entries,
## objectives and item resolver.
func restore_managers(blob: Dictionary) -> void:
	MissionLog.load_snapshot(blob.get("mission_log", {}))
	ObjectiveManager.load_snapshot(String(blob.get("objective", "")))
	# REV 293: every saved item comes back, whether or not this room registered a resolver
	var details: Dictionary = {}
	for d in blob.get("inventory_items", []):
		if d is Dictionary and String(d.get("id", "")) != "":
			details[String(d["id"])] = d
	var items: Array[InventoryItemData] = []
	for id in blob.get("inventory_item_ids", []):
		var item := resolve_inventory_item(String(id), details.get(String(id), {}))
		if item != null:
			items.append(item)
	InventoryManager.load_snapshot(items)


## REV 293: what the save keeps about each backpack item besides its id - enough to rebuild it if
## nothing else knows it (an item a room made in code and has no resolver for).
func _inventory_details() -> Array:
	var out: Array = []
	for item in InventoryManager.get_all_items():
		if item == null:
			continue
		var icon_path := ""
		if item.icon != null and item.icon.resource_path.begins_with("res://"):
			icon_path = item.icon.resource_path
		out.append({"id": item.id, "display_name": item.display_name, "description": item.description,
			"examine_text": item.examine_text, "icon": icon_path})
	return out


## REV 293: turns a saved item id back into the item. Tried in order:
##   1. the room's own inventory_item_resolver (if it set one),
##   2. InventoryManager.find_known_item (items seen this session, or data/items/<id>.tres),
##   3. rebuilt from what the save itself wrote down about it (name, description, picture),
##   4. last resort for old saves with only the id: a plain item with that id, so it isn't lost.
func resolve_inventory_item(id: String, saved: Dictionary = {}) -> InventoryItemData:
	if id == "":
		return null
	if inventory_item_resolver.is_valid():
		var from_room = inventory_item_resolver.call(id)
		if from_room is InventoryItemData:
			return from_room
	var known := InventoryManager.find_known_item(id)
	if known != null:
		return known
	var item := InventoryItemData.new()
	item.id = id
	item.display_name = String(saved.get("display_name", ""))
	if item.display_name == "":
		item.display_name = id      # (old save: the id is all we have)
	item.description = String(saved.get("description", ""))
	item.examine_text = String(saved.get("examine_text", ""))
	var icon_path := String(saved.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		item.icon = load(icon_path) as Texture2D
	InventoryManager.register_item(item)
	return item


## JSON turns every number into a float; put whole numbers back as ints so
## counters (failed attempts, etc.) behave exactly as they did before saving.
func _whole_numbers(value: Variant) -> Variant:
	if value is float and is_equal_approx(value, roundf(value)) and absf(value) < 1.0e9:
		return int(value)
	if value is Dictionary:
		var result := {}
		for key in value.keys():
			result[key] = _whole_numbers(value[key])
		return result
	if value is Array:
		var result_array := []
		for entry in value:
			result_array.append(_whole_numbers(entry))
		return result_array
	return value
