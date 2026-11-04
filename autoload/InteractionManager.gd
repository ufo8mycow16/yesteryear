extends Node
## InteractionManager — INTERACT focus/target resolution and the contextual
## TALK / LOOK / USE / EXAMINE menu. Supports both interaction orders the
## design documents use: hotspot-first (focus an object, press INTERACT,
## choose USE, the currently-held source item/equipment — if any — applies)
## and item-first (select an item/equipment from the HUD, then target a
## hotspot and press INTERACT).

signal focus_changed(hotspot: Hotspot)
signal verb_menu_opened(verbs: Array[String])
signal verb_menu_closed()
## Fired only on an actual change — lets HotspotHalo (and anything else that
## needs to visually suppress itself while a modal panel is open) subscribe
## without this autoload needing to know HUD or any UI node exists.
signal modal_suspended_changed(suspended: bool)
## Fired only when the cutscene lock actually changes — presentation-only
## (HUD fades, HotspotHalo hides); independent of modal suspension.
signal lock_changed(locked: bool)
## REV 103: something was just used (LOOK / TALK / USE, or an item on it). HotspotHalo pings.
signal verb_used(hotspot: Hotspot, verb: String)
## REV 148: the item in hand changed ("" = hands empty). HUD prompt and inventory listen.
signal held_source_changed(source_id: String)

var _focused_hotspot: Hotspot = null
var _held_source_id: String = ""   # InventoryItemData.id or EquipmentItemData.id, "" = bare hand
var _menu_open: bool = false

## True during a non-interactive beat (e.g. the Opening Banter cutscene) —
## INTERACT does nothing and focus is cleared, so the player can't open a
## hotspot's verb menu while they're not supposed to have control yet.
var _locked: bool = false

## True while a HUD modal panel (Inventory/Mission Log/System) is open —
## kept as its own flag rather than reusing _locked so the two sources
## never clobber each other: closing a modal mid-cutscene must not
## re-enable interaction, and a cutscene ending while a modal happens to
## be open must not either. HUD drives this via set_modal_suspended();
## nothing else should touch it.
var _modal_suspended: bool = false


func _ready() -> void:
	InventoryManager.item_use_requested.connect(_on_item_use_requested)
	EquipmentManager.equipment_use_requested.connect(_on_equipment_use_requested)
	# REV 103: anything that counts as "the game responded" to an interaction
	AudioSubtitleManager.subtitle_requested.connect(func(_s, _t, _d): _responded = true)
	AudioSubtitleManager.line_started.connect(func(_f, _s, _t, _p, _b): _responded = true)
	MissionLog.notification_requested.connect(func(_m): _responded = true)
	DialogueManager.conversation_started.connect(func(_d): _responded = true)
	lock_changed.connect(func(on): _responded = _responded or on)
	modal_suspended_changed.connect(func(on): _responded = _responded or on)
	verb_menu_opened.connect(func(_v): _responded = true)
	# REV 148 (INTERACTION_MODEL.md 2.6): a conversation or cutscene starting puts the held item away
	DialogueManager.conversation_started.connect(func(_d): set_held_source(""))
	lock_changed.connect(_on_lock_changed_put_away)
	# REV 293: an item used up / taken out of the backpack can't stay in hand
	InventoryManager.item_removed.connect(func(id: String) -> void:
		if id != "" and id == _held_source_id:
			set_held_source(""))
	(func(): SfxManager.played.connect(_on_sfx_played)).call_deferred()   # SfxManager loads after this


func _on_lock_changed_put_away(on: bool) -> void:
	if on and not _keep_held_on_lock:
		set_held_source("")


## REV 293: set by set_locked(true, true) - a lock that is only "the result of using the item is
## playing" (an Episode room's run_spot), which must not put a non-tricorder item away
## (INTERACTION_MODEL.md 2.7: it stays in hand after use).
var _keep_held_on_lock := false


# ---- REV 103: feedback when using something --------------------------------
## If using something gets no response at all (no line, no sound, no scene, no menu, no notice)
## within RESPONSE_WINDOW, a soft "can't" tone and a short line say so, instead of silence.
const RESPONSE_WINDOW := 0.9
const NO_RESPONSE_LINES := {
	"LOOK": "Nothing more to see there.",
	"EXAMINE": "Nothing more to see there.",
	"TALK": "Nothing more to say right now.",
	"USE": "Nothing happens.",
	"PICK UP BALL": "Nothing happens.",
	"ITEM": "That doesn't work there.",
	"SCAN": "Readings are normal. Nothing unusual.",   # REV 155; REV 160: only if the character has no "nothing unusual" pool
}
var _responded := false
var _response_serial := 0


func _on_sfx_played(sfx_name: String) -> void:
	if sfx_name != "interact" and sfx_name != "deny":
		_responded = true


## REV 160: loaded by path (not by class name) so this autoload never depends on Godot having
## rescanned the project for new script names.
const Pools := preload("res://core/data/LinePools.gd")

func _feedback(hotspot: Hotspot, verb: String, item_id: String = "") -> void:
	verb_used.emit(hotspot, verb)
	_response_serial += 1
	var serial := _response_serial
	_responded = false
	var scene := get_tree().current_scene
	await get_tree().create_timer(RESPONSE_WINDOW, false).timeout
	if serial != _response_serial or _responded:
		return
	if get_tree().current_scene != scene or is_locked() or is_modal_suspended() or DialogueManager.is_busy() \
			or AudioSubtitleManager.is_line_active():
		return
	# REV 160 (item 20): USE, an item or a scan that gets nothing back is answered by the character
	# himself, from his own rotating pool (LinePools) - item and item-on-target lines first.
	var category := ""
	match verb:
		"ITEM":
			category = "wrong_item"
		"SCAN":
			category = "nothing_unusual"
		"USE", "PICK UP BALL":
			category = hotspot.refusal_category if is_instance_valid(hotspot) and hotspot.refusal_category != "" else "nothing_useful"
	# REV 299 (Glen approved Tiffany's item 9): an item that gets nothing back goes back in the backpack
	# instead of staying in hand. Never the tricorder - a scan has its own rule (it always puts it away).
	if verb == "ITEM" and item_id != "" and _held_source_id == item_id and not is_tricorder(item_id):
		set_held_source("")
	if category != "":
		var hid := hotspot.hotspot_id if is_instance_valid(hotspot) else ""
		if say_pool_line(category, item_id, hid):
			return
	if verb != "SCAN":      # a scan that finds nothing still worked: no "can't" tone
		SfxManager.ui("invalid")
	var text := String(NO_RESPONSE_LINES.get(verb, "Nothing happens."))
	AudioSubtitleManager.subtitle_requested.emit("", text, 1.6)


## REV 160: who the player is controlling right now ("mccoy", "kirk", ...), "" if nobody.
func controlled_character() -> String:
	var player := get_tree().get_first_node_in_group("player")
	return ConversationPresenter._speaker_id_of_body(player) if player != null else ""


## REV 160 (item 20): the controlled character says the next line from a pool (see LinePools), with
## the quiet "invalid" sound unless it's a scan (a scan that finds nothing still worked). Returns
## false if he has nothing for it.
func say_pool_line(category: String, item_id: String = "", hotspot_id: String = "") -> bool:
	var who := controlled_character()
	if who == "":
		who = "mccoy"
	var line: Array = Pools.pick(who, category, item_id, hotspot_id)
	if line.is_empty():
		return false
	if category != "nothing_unusual":
		SfxManager.ui("invalid", -3.0)
	var id := String(line[0])
	var folder: String = Pools.speaker_of(id)
	var path: String = String(Pools.POOL_SPEECH_ROOT).path_join(folder).path_join(id + ".mp3")
	AudioSubtitleManager.play_line(folder, path, folder.capitalize(), String(line[1]), "Dialogue")
	return true


## keep_held (REV 293): true = don't put the item in hand away for this lock. Use it when the lock is
## just the response to a USE (a room's short scripted reply), not a real cutscene. A tricorder is
## still put away by the scan itself.
func set_locked(locked: bool, keep_held: bool = false) -> void:
	var changed := locked != _locked
	_locked = locked
	_keep_held_on_lock = keep_held and locked
	if changed:
		lock_changed.emit(locked)
	if locked and _focused_hotspot != null:
		_focused_hotspot = null
		focus_changed.emit(null)


## Called by the HUD whenever a modal panel's open/closed state changes.
## Suspending blocks INTERACT and hides the target presentation (prompt,
## halo's "targeted" boost) by announcing focus_changed(null) — but, unlike
## set_locked(true), it does NOT forget which hotspot is actually nearest.
## _focused_hotspot stays the real answer the whole time. That matters
## because focus is only recomputed when the player walks into/out of a
## hotspot's range: an earlier version cleared it here, so opening the
## inventory at the Bowling Lane to pick the Tricorder left nothing for
## the item-first USE to fire against, and nothing ever restored it
## afterward. On resume the real focus is simply re-announced.
func set_modal_suspended(suspended: bool) -> void:
	if suspended == _modal_suspended:
		return
	_modal_suspended = suspended
	modal_suspended_changed.emit(suspended)
	if _focused_hotspot != null:
		focus_changed.emit(null if suspended else _focused_hotspot)


func is_modal_suspended() -> bool:
	return _modal_suspended


func is_locked() -> bool:
	return _locked


## Back to a clean slate when a save is loaded and the scene is replaced.
## Nothing is emitted: the nodes that would listen are being freed anyway.
func reset_for_load() -> void:
	_locked = false
	_menu_open = false
	_modal_suspended = false
	_focused_hotspot = null
	# REV 296: the held item's picture is the mouse pointer (HUD._set_item_cursor), and nothing is told
	# here - so put the normal pointer back, or it stayed a tricorder after a load or room change.
	if _held_source_id != "":
		Input.set_custom_mouse_cursor(null)
	_held_source_id = ""
	_acting = false
	_keep_held_on_lock = false
	# REV 296: a quick-load during an automatic walk-up left this true for good (the walk never
	# finished), and every interact press was ignored for the rest of the session.
	_approaching = false


func _is_interaction_locked() -> bool:
	return _locked or _modal_suspended


func _unhandled_input(event: InputEvent) -> void:
	if _is_interaction_locked():
		return
	if event is InputEventMouseButton:
		if _unhandled_input_mouse(event as InputEventMouseButton):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		_on_interact_pressed()
	elif event.is_action_pressed("menu_cancel") and _menu_open:
		close_verb_menu()
		get_viewport().set_input_as_handled()   # (so Esc doesn't also open the pause menu)
	elif event.is_action_pressed("menu_cancel") and _held_source_id != "":
		# REV 148: Esc with an item in hand only puts it away; a second Esc pauses
		set_held_source("")
		SfxManager.ui("back", -2.0)
		get_viewport().set_input_as_handled()


## Called by the player controller / focus-detection Area3D each time the
## nearest in-range, facing-appropriate hotspot changes (including becoming
## null when nothing is in range — fully keyboard/controller driven, no
## mouse-dependent raycast required).
func set_focus(hotspot: Hotspot) -> void:
	if hotspot == _focused_hotspot:
		return
	_focused_hotspot = hotspot
	# While a modal is open the new target is remembered (so it's correct
	# the moment the modal closes) but not announced — the world prompt
	# and halo emphasis stay suppressed until set_modal_suspended(false).
	if _modal_suspended:
		return
	focus_changed.emit(hotspot)


func get_focus() -> Hotspot:
	return _focused_hotspot


## Set by the HUD "WHAT YOU HAVE" bank when the player selects an inventory
## item or equipment to use (item-first flow). Empty string clears selection.
## REV 490 (the redesign: "USE COMMUNICATOR -> Spock"): picking the communicator in the backpack opens it
## - the room decides who can be called (EpisodeRoom.open_communicator) - instead of putting it in hand.
## A room that has nothing to say about it leaves this empty and the communicator is held as before.
var communicator_handler: Callable = Callable()


func set_held_source(source_id: String) -> void:
	if source_id == _held_source_id:
		return
	if source_id.contains("COMMUNICATOR") and communicator_handler.is_valid() and not _locked:
		communicator_handler.call_deferred()
		return
	_held_source_id = source_id
	if source_id != "" and _menu_open:
		close_verb_menu()
	held_source_changed.emit(source_id)
	_sync_sling()


## REV 148: the on-screen name of the item in hand ("" when hands are empty).
func held_source_name() -> String:
	return source_name(_held_source_id)


func source_name(source_id: String) -> String:
	if source_id == "":
		return ""
	if InventoryManager.has_item(source_id):
		return InventoryManager.get_item(source_id).display_name
	var equip := EquipmentManager.find_equipment(source_id)
	if equip != null:
		return equip.display_name
	return source_id


static func is_tricorder(source_id: String) -> bool:
	return source_id.to_upper().contains("TRICORDER")


## REV 148 (INTERACTION_MODEL.md 2.2): what trying the held item on `target_name` reads as -
## always the same wording whether or not it will work (never reveal validity in advance).
func held_action_text(target_name: String) -> String:
	if _held_source_id == "":
		return target_name
	if is_tricorder(_held_source_id):
		return "SCAN %s" % target_name.to_upper()
	return "USE %s WITH %s" % [held_source_name().to_upper(), target_name.to_upper()]


func get_held_source() -> String:
	return _held_source_id


func _on_interact_pressed() -> void:
	if _focused_hotspot == null or _approaching or _acting:
		return

	if _menu_open:
		return

	# REV 521 (docs/design/HELD_ITEM_INTERACTION.md): F / A with an item in hand opens the ITEM arc
	# (USE first, so pressing twice uses it). A left click uses it straight away (use_held_on_focus).
	if _held_source_id != "":
		_open_item_menu()
		return

	var verbs := _focused_hotspot.get_available_verbs("", "")
	verbs.append_array(extra_verbs(_focused_hotspot))      # REV 215: SCAN / BOWL on the thing itself
	if verbs.is_empty():
		return

	if verbs.size() == 1 and not verbs[0].begins_with("!"):
		_execute_verb(verbs[0])
	else:
		_menu_open = true
		verb_menu_opened.emit(VerbIcons.ordered(verbs))


## REV 293: whose standard kit the player has right now - the controlled character's, or McCoy's if
## the controlled character has no kit of their own granted (today only McCoy's kit is ever granted,
## EquipmentManager.setup_prologue_equipment, so Kirk in Episode 1 and Spock in Episode 2 use it, as
## the backpack always let them). The backpack (InventoryEquipmentUI) and carried_tricorder both ask
## this, so the backpack's tricorder and the arc's SCAN always agree.
func kit_owner() -> String:
	var who := controlled_character()
	if who != "" and not EquipmentManager.get_equipment_for(who).is_empty():
		return who
	return "mccoy"


## REV 215: the tricorder of whoever the player is controlling, "" if they carry none.
## REV 293: through kit_owner(), the same kit the backpack shows.
func carried_tricorder() -> String:
	var who := kit_owner()
	for e in EquipmentManager.get_equipment_for(who):
		if e != null and is_tricorder(String(e.id)):
			return String(e.id)
	return ""


## REV 215 (Nikki's playtest): item actions offered on the thing itself - SCAN while carrying a
## tricorder (Hotspot.scan_verb), and Hotspot.item_verbs for items in the backpack.
func extra_verbs(hotspot: Hotspot) -> Array[String]:
	var out: Array[String] = []
	if hotspot == null:
		return out
	if hotspot.scan_verb and carried_tricorder() != "":
		out.append("SCAN")
	for v in hotspot.item_verbs.keys():
		if InventoryManager.has_item(String(hotspot.item_verbs[v])):
			out.append(String(v))
	return out


## REV 521: the arc you get with an item in hand - what can be done WITH it to the target.
## item_verb tells the room which word was chosen ("USE", "GIVE", "SHOW"); most rooms ignore it.
var item_verb := "USE"
var _item_menu := false
var _item_menu_map := {}      # shown verb -> "USE" / "GIVE" / "SHOW" / "SCAN" / "LOOK"


func is_item_menu() -> bool:
	return _item_menu and _menu_open


func _open_item_menu() -> void:
	if _focused_hotspot == null:
		return
	var nm := held_source_name().to_upper()
	_item_menu_map.clear()
	var verbs: Array[String] = []
	if is_tricorder(_held_source_id):
		verbs.append("SCAN")
		_item_menu_map["SCAN"] = "SCAN"
	else:
		var use := "USE %s" % nm
		verbs.append(use)
		_item_menu_map[use] = "USE"
		if _is_person(_focused_hotspot):
			for w in ["GIVE", "SHOW"]:
				var v := "%s %s" % [w, nm]
				verbs.append(v)
				_item_menu_map[v] = w
	verbs.append("LOOK")
	_item_menu_map["LOOK"] = "LOOK"
	_item_menu = true
	_menu_open = true
	verb_menu_opened.emit(verbs)


func _is_person(h: Hotspot) -> bool:
	if h == null:
		return false
	for v in h.get_available_verbs("", ""):
		if String(v).trim_prefix("!") == "TALK":
			return true
	return false


## REV 521: a left click on a thing with an item in hand - use it on that thing at once (the classic click).
func use_held_on_focus() -> void:
	if _focused_hotspot == null or _held_source_id == "" or _approaching or _acting or _menu_open:
		return
	item_verb = "USE"
	_use_source_on_focus(_held_source_id, _focused_hotspot.hotspot_id)


## Called by the radial menu when the player picks a verb (mouse, keyboard or controller).
func choose_verb(verb: String) -> void:
	if verb.begins_with("!"):
		SfxManager.ui("invalid")     # shown so the player knows it exists; not possible yet
		return
	var was_item := _item_menu
	var mapped := String(_item_menu_map.get(verb, ""))
	close_verb_menu()
	if was_item and mapped != "" and _focused_hotspot != null:
		match mapped:
			"LOOK":
				_execute_verb("LOOK")
			_:
				item_verb = "USE" if mapped == "SCAN" else mapped
				_use_source_on_focus(_held_source_id, _focused_hotspot.hotspot_id)
		return
	_execute_verb(verb)


func close_verb_menu() -> void:
	_menu_open = false
	_item_menu = false
	verb_menu_closed.emit()


func _execute_verb(verb: String) -> void:
	if _focused_hotspot == null or _approaching or verb.begins_with("!"):
		return
	# REV 215: SCAN / item verbs are the backpack's "use X on this", started from the arc
	if verb == "SCAN" and _focused_hotspot.scan_verb:
		var tri := carried_tricorder()
		if tri != "":
			_use_source_on_focus(tri, _focused_hotspot.hotspot_id)
			return
	if _focused_hotspot.item_verbs.has(verb):
		_use_source_on_focus(String(_focused_hotspot.item_verbs[verb]), _focused_hotspot.hotspot_id)
		return
	var hotspot := _focused_hotspot
	# REV 103: a slightly different note for looking, talking and using
	var pitch := 1.06
	match verb:
		"TALK":
			pitch = 0.9
		"EXAMINE", "LOOK":
			pitch = 1.0
		"USE":
			pitch = 1.12
	SfxManager.play("interact", -6.0, pitch)
	# REV 147 (item 29): walk up to it first (and face it), then do it
	if not await _approach(hotspot, verb):
		return
	_feedback(hotspot, verb)
	match verb:
		"EXAMINE", "LOOK":
			hotspot.do_examine()  # LOOK and EXAMINE share the same flavour-text pathway
		"TALK":
			hotspot.do_talk()
		"USE":
			await _touch_or_act(hotspot, verb)
			if is_instance_valid(hotspot):
				hotspot.do_use("")
		_:
			# REV 148: any native verb (OPERATE, OPEN, PICK UP BALL, ANSWER...): the hotspot decides
			await _touch_or_act(hotspot, verb)
			if is_instance_valid(hotspot):
				hotspot.do_verb(verb)


## REV 199 (item 9): if the hotspot says where to touch it, the player reaches out and touches that
## spot (looking at it), and the action happens as the fingers arrive; otherwise the old gesture.
func _touch_or_act(hotspot: Hotspot, verb: String) -> void:
	var at := hotspot.touch_point_for(verb)
	if not at.is_finite():
		_act("")
		return
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	var an := CharacterKit.animator_of(player)
	if player == null or an == null or not an.has_motion() or an.is_busy():
		_act("")
		return
	var t := an.reach_to(at)
	if t <= 0.0:
		_act("")
		return
	var face := CharacterFace.face_of(player)
	if face != null and face.ready_to_use:
		face.look_at_point(at)
	var was := player.input_enabled
	player.input_enabled = false
	_acting = true
	await get_tree().create_timer(t, false).timeout
	_acting = false
	if is_instance_valid(player):
		player.input_enabled = was
	if is_instance_valid(hotspot):
		hotspot.touched.emit(verb)
	if face != null and is_instance_valid(face):
		# eyes back to normal a moment later, unless something else has given them a new target
		get_tree().create_timer(1.0, false).timeout.connect(func() -> void:
			if is_instance_valid(face) and face.is_looking() and face.look_target() == null and face._look_point.is_equal_approx(at):
				face.clear_look())


# ---- REV 147 (items 22 and 29): walking up to things ------------------------------------------
var _approaching := false


## True while the player is walking up to something they chose to use or talk to.
func is_approaching() -> bool:
	return _approaching


## Walk the player to where they'd stand to `verb` the hotspot (talking: a comfortable distance
## from the person; using: in front of it), turned to face it. Looking/examining happens from where
## they stand; they just turn towards it. Returns false if the player took over by moving off (the
## action is dropped); if the spot can't be reached the action happens from where they are.
func _approach(hotspot: Hotspot, verb: String) -> bool:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player == null or not player.input_enabled or not is_instance_valid(hotspot):
		return true
	var spot := {}
	var who: Node3D = null
	if verb == "TALK":
		who = Approach.figure_for(hotspot)
	if who != null:
		spot = Approach.talk_spot(player, who, "approach")
		if spot.is_empty():
			spot = {"pos": player.global_position, "face": who.global_position}
	elif verb == "LOOK" or verb == "EXAMINE":
		var edge := Approach.use_spot(player, hotspot)
		if not edge.is_empty():
			spot = {"pos": player.global_position, "face": edge["face"]}
	elif hotspot.walk_up:
		spot = Approach.use_spot(player, hotspot)
	if spot.is_empty():
		return true
	_approaching = true
	player.input_enabled = false
	var reached: bool = await player.walk_to(spot["pos"], spot.get("face", Vector3.INF), true)
	if is_instance_valid(player):
		player.input_enabled = true
	_approaching = false
	if not reached and is_instance_valid(player) and player._move_input().length() > 0.35:
		return false          # they walked off instead
	return is_instance_valid(hotspot)


## Item-first flow: player selected an inventory item from the HUD, then
## targeted a hotspot and confirmed. Only fires if that hotspot is currently
## focused — this keeps targeting keyboard/controller-driven rather than
## needing a mouse-drop target.
func _on_item_use_requested(item_id: String, hotspot_id: String) -> void:
	_use_source_on_focus(item_id, hotspot_id)


func _on_equipment_use_requested(equipment_id: String, hotspot_id: String) -> void:
	_use_source_on_focus(equipment_id, hotspot_id)


func _use_source_on_focus(source_id: String, hotspot_id: String) -> void:
	if _focused_hotspot == null or _focused_hotspot.hotspot_id != hotspot_id or _approaching or _acting:
		return
	var hotspot := _focused_hotspot
	SfxManager.play("interact", -6.0, 1.12)
	if not await _approach(hotspot, "USE"):     # REV 147: walk up to it first
		return
	if is_tricorder(source_id):
		await _scan(hotspot, source_id)
		return
	_feedback(hotspot, "ITEM", source_id)
	_act(source_id)
	hotspot.do_use(source_id)
	# REV 674 (Glen: "once a successful use has been done, the item should no longer be held"): used on something,
	# it goes back in the backpack - the LucasArts way (the pointer is the plain pointer again after any use)
	# REV 741 (item 18): an episode room decides after the use plays out - put away if it worked, kept in hand if
	# it didn't (EpisodeRoom.run_spot); other scenes keep REV 674's rule
	var room := get_tree().current_scene
	if _held_source_id == source_id and not (room != null and room.has_method("run_spot") and hotspot.get("room") != null):
		set_held_source("")


# ---- REV 155: the tricorder scan as one physical action ---------------------------------------
## Selecting the tricorder slings it on (strap over the shoulder, hanging at the hip). Scanning a target
## (after walking up to it): McCoy holds still, kneels first if the target asks for it (Lane 3), lifts
## the tricorder off the strap into his hands, scans while the result plays (at least ~2.5 s), lowers it
## back onto the strap, stands, and puts it away: tricorder and strap disappear and the tricorder is
## no longer selected (Glen, 19 Oct - supersedes "stays in hand after use" for the tricorder).

var _acting := false
var _sling_fig: Node = null


func is_acting() -> bool:
	return _acting


func _process(_delta: float) -> void:
	# a new room means a new player figure: sling the tricorder on that one too
	var player := get_tree().get_first_node_in_group("player")
	if player != _sling_fig:
		_sync_sling()
	_update_mouse_hover(player as Node3D)


# ---- mouse targeting (REV 168, CLAUDE.md item 32) -------------------------------------------------
## The hotspot under the mouse pointer becomes the target when it is within reach (the same reach as
## the nearest-target rule, which still decides for keyboard and controller). A left click on it does
## what F does (the verb menu, or the item in hand tried on it); with an item in hand a quick right
## click does too (a right DRAG still turns the camera), and a left click on empty space puts the item
## away (INTERACTION_MODEL.md mode 2). The pointer only counts after the mouse has moved: walking with
## the keys hands targeting back to "nearest", so a resting pointer never steals it.
var _mouse_hover: Hotspot = null
var _mouse_active := false
var _mouse_pos := Vector2.ZERO        # where the pointer is, from the last mouse event (viewport space)
var _left_down_at := -1
var _right_down_at := -1
var _right_down_pos := Vector2.ZERO
const CLICK_MS := 300
const RIGHT_CLICK_SLOP := 6.0

## The hotspot under the pointer, or null (also null when the mouse isn't being used).
func mouse_hover() -> Hotspot:
	return _mouse_hover if _mouse_hover != null and is_instance_valid(_mouse_hover) else null


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			_mouse_active = true
			_mouse_pos = (event as InputEventMouseMotion).position
	elif event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		_mouse_pos = (event as InputEventMouseButton).position
	elif event is InputEventKey and event.pressed and not event.echo:
		for a in ["move_forward", "move_back", "move_left", "move_right"]:
			if event.is_action(a):
				_mouse_active = false
				break


func _update_mouse_hover(player: Node3D) -> void:
	var h: Hotspot = null
	if _mouse_active and player != null and not InputHints.using_gamepad \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not _is_interaction_locked() \
			and not _menu_open and not _acting and get_viewport().gui_get_hovered_control() == null:
		h = _hotspot_under_pointer(player)
	if h == _mouse_hover:
		return
	_mouse_hover = h
	if player != null and player.has_method("refresh_focus"):
		player.refresh_focus()


## Every hotspot the pointer's ray passes through before it meets a wall or floor; the most specific
## one (smallest) wins, so the intercom beats the seating area it sits in.
func _hotspot_under_pointer(player: Node3D) -> Hotspot:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mp := _mouse_pos
	var from := cam.project_ray_origin(mp)
	var to := from + cam.project_ray_normal(mp) * 40.0
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var exclude: Array[RID] = []
	var best: Hotspot = null
	var best_vol := INF
	for i in 8:
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var col: Object = hit.get("collider")
		if col is Hotspot:
			var hs := col as Hotspot
			if hs.visible and hs.monitorable:
				var v := _hotspot_volume(hs)
				if v < best_vol:
					best_vol = v
					best = hs
			exclude.append(hit["rid"])
			continue
		if col is CollisionObject3D and ((col as CollisionObject3D).collision_layer & 1 == 0 or (col as Node).is_in_group("see_through")):
			exclude.append(hit["rid"])     # not a wall or floor (e.g. the player himself), or a force field's wall (REV 605)
			continue
		break      # a wall, floor or prop: nothing behind it counts
	return best


func _hotspot_volume(hs: Hotspot) -> float:
	for c in hs.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			var sz: Vector3 = ((c as CollisionShape3D).shape as BoxShape3D).size * hs.global_transform.basis.get_scale().abs()
			return sz.x * sz.y * sz.z
	return 1000.0


func _unhandled_input_mouse(event: InputEventMouseButton) -> bool:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event.button_index != MOUSE_BUTTON_RIGHT:
		return false
	var now := Time.get_ticks_msec()
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_left_down_at = now if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else -1
			return false
		var quick := _left_down_at >= 0 and now - _left_down_at < CLICK_MS
		_left_down_at = -1
		if not quick or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or InputHints.using_gamepad:
			return false
		var hov := mouse_hover()
		if hov != null and hov == _focused_hotspot:
			if _held_source_id != "":
				use_held_on_focus()        # REV 521: holding something - a left click uses it on that
			else:
				_on_interact_pressed()
			return true
		if hov == null and _held_source_id != "" and not _acting and not _approaching:
			set_held_source("")       # click on empty space puts the item away
			SfxManager.ui("back", -2.0)
			return true
		return false
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_right_down_at = now
			_right_down_pos = event.position
			return false
		var was := _right_down_at
		_right_down_at = -1
		if _held_source_id == "" or was < 0 or now - was > CLICK_MS:
			return false
		if event.position.distance_to(_right_down_pos) > RIGHT_CLICK_SLOP:
			return false
		var hov2 := mouse_hover()
		if hov2 != null and hov2 == _focused_hotspot and not _menu_open:
			_open_item_menu()               # REV 521: right click with an item = what to do with it
			return true
	return false


func _sync_sling() -> void:
	var player := get_tree().get_first_node_in_group("player")
	_sling_fig = player
	var an := CharacterKit.animator_of(player)
	if an != null:
		an.set_slung(is_tricorder(_held_source_id) or _acting)


func _scan(hotspot: Hotspot, source_id: String) -> void:
	await scan_motion(hotspot, func() -> void:
		if is_instance_valid(hotspot):
			_feedback(hotspot, "SCAN")
			hotspot.do_use(source_id))


## REV 306: one backpack item used on another (the backpack's USE WITH). The room/scene answers
## (EpisodeRoom.combine_items); a scene without it gets the played character's "that won't work" line.
## REV 521: no longer drops the held item first - an ingredient used up leaves the hand as it leaves the
## backpack (item_removed); a try that doesn't work keeps it in hand to try on something else.
func combine_items(a: String, b: String) -> void:
	if a == "" or b == "" or a == b:
		return
	# REV 475: the registered recipes first (InventoryManager.add_recipe)
	if InventoryManager.has_recipe(a, b):
		await InventoryManager.try_combine(a, b)
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("combine_items"):
		scene.call("combine_items", a, b)
	else:
		say_pool_line("wrong_item", a)


## REV 300: a scan a ROOM starts itself (EpisodeRoom.scan_begin) - a handler that scans something on a
## plain USE, or from a menu row ("Scan the cable"). Starts the real scan (tricorder up, kneel for a
## floor target, the camera framing it) unless one is already running - a tricorder used on the spot
## got here through _scan - and returns once the tricorder is up, so the room then shows its result.
## The tricorder stays up while the room's scene is still running and comes down after it.
func begin_scan(hotspot: Hotspot = null) -> void:
	if _acting:
		return
	if hotspot == null:
		hotspot = _focused_hotspot
	scan_motion(hotspot)
	await get_tree().create_timer(0.9, false).timeout


## REV 300: the whole tricorder scan as one move, for _scan (a tricorder used on a hotspot) and
## begin_scan (a room scanning on its own): lift, kneel if the target is low (hotspot.scan_pose),
## frame it (hotspot.scan_framing), run on_result once the tricorder is up, keep scanning while any
## line plays or the room's scene is still running (REV 300 - the tricorder used to come down while a
## read-out was still on screen; scan_action's own 12 s cap still ends it), then lower, stand, and put
## the tricorder away (Glen's rule: a completed scan always deselects it).
func scan_motion(hotspot: Hotspot, on_result: Callable = Callable()) -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	var an := CharacterKit.animator_of(player)
	if an == null or not an.has_motion():
		if on_result.is_valid():
			await on_result.call()
		# REV 296: a completed scan always puts the tricorder away (Glen's rule), also for box stand-ins
		if is_tricorder(_held_source_id):
			set_held_source("")
		return
	if not is_instance_valid(hotspot):
		hotspot = null
	_acting = true
	_sync_sling()
	if player != null:
		player.held_still = true
		player.velocity = Vector3.ZERO
	if _menu_open:
		close_verb_menu()
	var kneel := hotspot != null and String(hotspot.scan_pose) == "kneel"
	# REV 300: an Episode room's spot that sets no pose kneels when what's scanned is down near the
	# floor (a body, a track, a stain) - the Prologue's hotspots keep their own authored poses.
	if hotspot != null and String(hotspot.scan_pose) == "" and player != null \
			and hotspot.get_script() != null and String(hotspot.get_script().resource_path).ends_with("SpotHotspot.gd") \
			and hotspot.global_position.y + hotspot.halo_center_offset.y < player.global_position.y + 0.55:
		kneel = true
	_scan_gaze_id += 1
	if hotspot != null:
		_scan_gaze(player, an, hotspot, _scan_gaze_id)   # REV 167 (item 45): eyes on the job throughout
	if hotspot != null and hotspot.scan_framing:
		_frame_scan(player, an, _scan_look_point(player, hotspot), kneel)
	if kneel:
		var d := an.kneel()
		if d > 0.0:
			await get_tree().create_timer(d, false).timeout
	# keep scanning while the result is being spoken (with a little grace between lines)
	var state := {"last": 0.0, "result": false}
	var busy := func() -> bool:
		var now := Time.get_ticks_msec() / 1000.0
		if AudioSubtitleManager.is_line_active() or _locked or bool(state["result"]):
			state["last"] = now
		return now - float(state["last"]) < 0.5
	an.scan_action(2.6, busy)
	# the result comes once the tricorder is up
	await get_tree().create_timer(0.8, false).timeout
	if on_result.is_valid():
		state["result"] = true
		await on_result.call()
		state["result"] = false
	# wait for it to be back on the strap (polled, so a figure freed by a room change can't strand us)
	var t := 0.0
	while _is_scanning(an) and t < 25.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	if kneel and is_instance_valid(an):
		var d2 := an.stand()
		if d2 > 0.0:
			await get_tree().create_timer(d2, false).timeout
	_scan_gaze_id += 1     # REV 167: let the eyes go
	_unframe_scan(player)
	if is_tricorder(_held_source_id):
		set_held_source("")
	if is_instance_valid(player):
		player.held_still = false
	_acting = false
	_sync_sling()


## REV 293: whether the figure's tricorder is still out (lifted, scanning or being lowered). Asks the
## animator's own is_scanning() if it has one, else reads its private _scanning flag carefully, so this
## keeps working whichever way CharacterAnimator provides it. A freed figure counts as done.
func _is_scanning(an: Object) -> bool:
	if an == null or not is_instance_valid(an):
		return false
	if an.has_method("is_scanning"):
		return bool(an.call("is_scanning"))
	var v = an.get("_scanning")
	return v is bool and v


## REV 169 (CLAUDE.md item 15): the camera glides round to a side-on view of the scan - his face,
## the tricorder and what he is scanning together - and back afterwards (OrbitCameraRig.frame_scan).
func _frame_scan(player: PlayerController, an: CharacterAnimator, toward: Vector3, kneel: bool) -> void:
	if player == null or player.camera_rig == null:
		return
	var f := -player.global_transform.basis.z
	if an != null and an._model != null:
		f = an._model.global_transform.basis.z      # the way his figure faces
	player.camera_rig.frame_scan(f, toward, kneel, 0.8)


func _unframe_scan(player: PlayerController) -> void:
	if is_instance_valid(player) and player.camera_rig != null:
		player.camera_rig.unframe(0.9)


## REV 167 (Glen, item 45): during a scan the eyes (and head, within its limits) look at the job, not
## at wherever they were last pointed - kneeling at Lane 3 that was someone's head height, so McCoy
## seemed to stare at the sky. While he gets down: at the thing being scanned (a spot on the floor
## in front of him for something big like a lane); once the tricorder is up in his hands: at the
## tricorder. Runs until a newer scan or the end of this one (the id changes), then lets go.
var _scan_gaze_id := 0

func _scan_gaze(player: Node3D, an: CharacterAnimator, hotspot: Hotspot, my: int) -> void:
	var face := CharacterFace.face_of(player)
	if face == null:
		return
	while my == _scan_gaze_id and is_instance_valid(face) and is_instance_valid(player):
		var tgt := Vector3.INF
		if is_instance_valid(an) and an.slung != null and an.slung.hold > 0.3:
			tgt = an.slung.device_position()
		if tgt == Vector3.INF:
			tgt = _scan_look_point(player, hotspot)
		if tgt != Vector3.INF:
			face.look_at_point(tgt)
		await get_tree().process_frame
	if is_instance_valid(face):
		face.clear_look()     # not back to an old target - that stale look is what pointed his eyes skyward


## The spot to look at on something being scanned: its middle, unless that is far off or above him
## (a long lane's middle), then the floor about a metre in front of him toward it.
## REV 503: the hotspot is taken untyped - a room may free it mid-scan (Episode 5's Arena drops a spot the
## moment its thing is picked up), and a typed Hotspot argument made the debugger stop on the freed object
## before the is_instance_valid check below could run.
func _scan_look_point(player: Node3D, hotspot_v: Variant) -> Vector3:
	if hotspot_v == null or not is_instance_valid(hotspot_v):
		return Vector3.INF
	var hotspot: Hotspot = hotspot_v as Hotspot
	if hotspot == null:
		return Vector3.INF
	var p := player.global_position
	var h := hotspot.global_position
	var flat := Vector3(h.x - p.x, 0.0, h.z - p.z)
	if flat.length() < 1.6 and h.y < p.y + 1.2:
		return h
	if flat.length() < 0.01:
		return Vector3.INF
	return p + flat.normalized() * 1.0 + Vector3.UP * 0.05


## REV 160 (CLAUDE.md item 32, INTERACTION_MODEL.md "The tricorder is universal"): scanning something
## in the backpack. Tricorder in hand, choose an item: the backpack closes, the character lifts the
## tricorder and scans it where he stands. A scene can register what an item's scan finds
## (register_item_scan); anything else gets his "nothing unusual" line. Ends like every scan: the
## tricorder back on the strap and put away.
var _item_scans := {}     # item id -> Callable (may await)

func register_item_scan(item_id: String, what_it_finds: Callable) -> void:
	_item_scans[item_id] = what_it_finds


func scan_item(item_id: String) -> void:
	if _acting or _locked:
		return
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	var an := CharacterKit.animator_of(player)
	_acting = true
	_sync_sling()
	if player != null:
		player.held_still = true
		player.velocity = Vector3.ZERO
	if _menu_open:
		close_verb_menu()
	var state := {"last": 0.0}
	var busy := func() -> bool:
		var now := Time.get_ticks_msec() / 1000.0
		if AudioSubtitleManager.is_line_active():
			state["last"] = now
		return now - float(state["last"]) < 0.5
	if an != null and an.has_motion():
		_frame_scan(player, an, Vector3.INF, false)    # REV 169
		an.scan_action(2.6, busy)
		await get_tree().create_timer(0.8, false).timeout
	var c: Callable = _item_scans.get(item_id, Callable())
	if c.is_valid():
		await c.call()
	else:
		say_pool_line("nothing_unusual")
	var t := 0.0
	while _is_scanning(an) and t < 25.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	_unframe_scan(player)
	if is_tricorder(_held_source_id):
		set_held_source("")
	if is_instance_valid(player):
		player.held_still = false
	_acting = false
	_sync_sling()


## REV 129: the player's body does what they chose: a tricorder comes out to scan, anything else is a
## reach to press or use.
func _act(source_id: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var an := CharacterKit.animator_of(player)
	if an == null or not an.has_motion() or an.is_busy():
		return
	if source_id.to_lower().contains("tricorder"):
		an.scan(2.8)
	else:
		an.play("button", {"strength": 0.9})
