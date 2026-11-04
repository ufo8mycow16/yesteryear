extends Area3D
class_name Hotspot
## Base class for every interactable world object (HOT_PRO_xxx, and future
## episodes' hotspots). Concrete hotspots extend this and override the do_*
## virtuals; the shared sequential-dialogue-bank helper covers the common
## "first time / second time / third time / repeat" pattern seen throughout
## the Interaction Bible so each hotspot script only supplies its own line data.
##
## REV 148 (INTERACTION_MODEL.md): with hands empty a hotspot offers its NATIVE verbs - TALK,
## EXAMINE, OPERATE, OPEN, PICK UP..., whatever will actually happen right now. The radial menu
## shows each with its icon (VerbIcons). Items are never verbs here: an item in hand goes straight
## to do_use(item_id). EXAMINE/LOOK -> do_examine(), TALK -> do_talk(), any other native verb ->
## do_verb(verb), which by default is do_use("") (the hands-empty action).

@export var hotspot_id: String = ""
@export var display_name: String = ""
## Native verbs, e.g. ["TALK", "EXAMINE"], ["OPERATE", "EXAMINE"]. "!VERB" = shown but unavailable.
@export var interaction_types: Array[String] = ["EXAMINE"]
## Optional on-screen word for a verb this hotspot supplies, e.g. {"USE": "OPEN"}.
@export var verb_labels: Dictionary = {}
## Optional icon family for a verb, e.g. {"ANSWER": "press"} (families: VerbIcons.FILES).
@export var verb_icon_overrides: Dictionary = {}

## Where HotspotHalo scatters its twinkling points, relative to this
## hotspot's own origin — the generic default ("a little above wherever
## the Area3D's origin is") works for most placements; nudge per-instance
## in the editor for anything where that lands somewhere odd (very tall or
## very low/wide objects).
@export var halo_center_offset: Vector3 = Vector3(0, 0.4, 0)
@export var halo_radius: float = 0.3

## REV 147 (item 29): where the player stands to use this, in the hotspot's own space, and the
## point they face from there. Leave use_approach_point off to have Approach work a spot out from
## the hotspot's box; set walk_up false for things used from wherever you stand (looking at a
## distant scoreboard, a whole room area).
@export var use_approach_point: bool = false
@export var approach_point: Vector3 = Vector3.ZERO
@export var approach_face: Vector3 = Vector3.ZERO
@export var walk_up: bool = true
## REV 215 (Nikki's playtest): show SCAN (tricorder icon) in this thing's verb arc while the player
## carries a tricorder - it does exactly what using the tricorder on it from the backpack does. The
## arc itself teaches that the tricorder is how you investigate.
@export var scan_verb: bool = false
## REV 215: verbs that use an item, shown in the arc while the player has that item (and isn't
## already holding something): {"BOWL": "INV_PRO_001"}. Same as using that item on this from the backpack.
@export var item_verbs: Dictionary = {}
## REV 155: how the character scans this with the tricorder: "" (standing) or "kneel" (Lane 3).
@export var scan_pose: String = ""
## REV 169 (item 15): the gameplay camera glides to a side-on view while this is scanned. Off for a
## hotspot whose scene films its own scan shot (Lane 3).
@export var scan_framing: bool = true
## REV 160 (item 20): which of the character's refusal pools answers a USE that does nothing here:
## "" = "nothing_useful"; "cant_operate" for a device or control he can't work; "unreachable".
@export var refusal_category: String = ""

## REV 199 (CLAUDE.md item 9): where the character's fingers go when using this, in world space, so
## they reach out and touch it (a panel's button, a ball on a rack). INF = no reach (the old generic
## gesture). A scene can instead give `touch_picker`, a Callable(verb) -> Vector3, to choose the spot
## at the moment of use (e.g. the nearest ball). `touch_verbs`: which verbs reach (empty = every
## hands-empty use - USE and native verbs like ANSWER, OPERATE, PICK UP...).
var touch_point := Vector3.INF
var touch_picker := Callable()
@export var touch_verbs: Array[String] = []
## Fires when the fingers arrive, just before the verb itself runs.
signal touched(verb: String)


func touch_point_for(verb: String) -> Vector3:
	if not touch_verbs.is_empty() and not verb in touch_verbs:
		return Vector3.INF
	if touch_picker.is_valid():
		return touch_picker.call(verb)
	return touch_point

func has_approach_point() -> bool:
	return use_approach_point


## Give this hotspot its own standing spot (`mark`) and the point to face from it (`face`), both in
## world coordinates (e.g. in front of a wall panel, far enough back to raise an arm to it).
func set_approach(mark: Vector3, face: Vector3) -> void:
	var inv := global_transform.affine_inverse() if is_inside_tree() else transform.affine_inverse()
	approach_point = inv * mark
	approach_face = inv * face
	use_approach_point = true


## Per-instance progress through a sequential dialogue bank (see
## play_sequential_bank). Keyed by an arbitrary bank name so one hotspot can
## run more than one independent sequence (e.g. examine-bank vs repeat-bank).
var _bank_progress: Dictionary = {}


## Per-hotspot progress that is not a GameState variable: how far through each
## "first time / second time / repeat" bank it is, and (for talkable hotspots
## that own a `_dialogue`) which conversation topics have been used. Saved and
## restored by id so a loaded game doesn't replay first-time lines.
func get_save_state() -> Dictionary:
	var state := {"bank": _bank_progress.duplicate()}
	var dialogue: Variant = get("_dialogue")
	if dialogue is DialogueData:
		var topics := {}
		for topic in dialogue.topics:
			topics[topic.id] = int(topic.state)
		state["topics"] = topics
	return state


func load_save_state(state: Dictionary) -> void:
	_bank_progress.clear()
	var bank: Dictionary = state.get("bank", {})
	for key in bank.keys():
		_bank_progress[key] = int(bank[key])
	var dialogue: Variant = get("_dialogue")
	if dialogue is DialogueData:
		var topics: Dictionary = state.get("topics", {})
		for topic in dialogue.topics:
			if topics.has(topic.id):
				topic.state = int(topics[topic.id])


## Spawns the shared twinkling-star interactable indicator on every
## hotspot without any concrete hotspot script needing to know it exists.
## Deliberately _enter_tree(), not _ready(): every HOT_PRO_* subclass
## already overrides _ready() for its own setup, which would silently
## shadow a base-class _ready() unless each one remembered to call
## super._ready() — _enter_tree() isn't overridden anywhere, so this
## fires unconditionally with no other file needing to change.
func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	var halo := HotspotHalo.new()
	halo.name = "HotspotHalo"
	add_child(halo)


func get_available_verbs(_held_item_id: String, _held_equipment_id: String) -> Array[String]:
	# Default: whatever this hotspot declares. Override to conditionally hide
	# a verb (e.g. USE hidden once a one-shot pickup is already collected).
	return interaction_types.duplicate()


## Shared helper for the "First Time / Second Time / Third Time / Repeat"
## dialogue-bank pattern used by almost every EXAMINE entry in the Interaction
## Bible. `entries` is an ordered Array[Dictionary], each either:
##   {line: DialogueLineData}                         — unconditional
##   {condition: String, line: DialogueLineData}       — only offered if true
## The first not-yet-played entry whose condition (if any) currently holds
## plays; once the bank is exhausted, the LAST entry repeats indefinitely —
## matching e.g. HOT_PRO_007/008's "Repeat" behaviour.
func play_sequential_bank(bank_name: String, entries: Array) -> void:
	var progress: int = _bank_progress.get(bank_name, 0)

	# Find the next eligible entry starting at progress.
	var index := progress
	while index < entries.size():
		var entry: Dictionary = entries[index]
		var condition: String = entry.get("condition", "")
		if condition == "" or GameState.evaluate_condition(condition):
			_play_bank_line(entry.line)
			if index < entries.size() - 1:
				_bank_progress[bank_name] = index + 1
			# else: stays at the last index, so it repeats on every future call.
			return
		index += 1

	# Nothing new was eligible (e.g. all remaining entries are condition-gated
	# and not yet true) — repeat the last entry that *did* play.
	if progress > 0:
		_play_bank_line(entries[progress - 1].line)


func _play_bank_line(line: DialogueLineData) -> void:
	for var_name in line.variables_set.keys():
		GameState.set_var(var_name, line.variables_set[var_name])
	AudioSubtitleManager.play_line(line.character_folder, line.filename, line.speaker_display_name, line.subtitle, line.audio_bus)


## For playing more than one line back to back (e.g. a 3-line tricorder scan
## readout). Waits for each line to actually finish before starting the
## next — without this, a second play_line() call in the same frame
## overwrites the first line's subtitle/audio before it's ever seen.
func _play_bank_line_and_wait(line: DialogueLineData) -> void:
	_play_bank_line(line)
	await AudioSubtitleManager.line_finished


## Convenience constructor so concrete hotspot scripts can build their
## dialogue-bank arrays inline instead of hand-authoring a .tres per line.
static func make_line(character_folder: String, speaker: String, filename: String, subtitle: String, variables_set: Dictionary = {}, audio_bus: String = "Dialogue") -> DialogueLineData:
	var line := DialogueLineData.new()
	line.character_folder = character_folder
	line.speaker_display_name = speaker
	line.filename = filename
	line.subtitle = subtitle
	line.variables_set = variables_set
	line.audio_bus = audio_bus
	return line


## Opens the close-up examine card (see ExamineView) — a datapad, readout or
## picture the player reads. `image` may be null. Returns when the player closes
## it, so a hotspot can `await show_closeup(...)`.
func show_closeup(title: String, body: String, image: Texture2D = null, kind: String = "EXAMINE") -> void:
	var view := get_tree().get_first_node_in_group("examine_view")
	if view == null:
		return
	view.show_card(title, body, image, kind)
	await view.closed


## --- Virtuals: override in each concrete hotspot script. ---

func do_examine() -> void:
	pass

func do_talk() -> void:
	pass

## A native verb other than EXAMINE/LOOK/TALK (OPERATE, OPEN, PICK UP BALL, ANSWER...). Override
## to tell them apart; by default it is the hands-empty use.
func do_verb(_verb: String) -> void:
	do_use("")

## source_id is an InventoryItemData.id, an EquipmentItemData.id, or "" for a
## bare USE with nothing selected.
func do_use(source_id: String) -> void:
	pass
