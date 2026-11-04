extends Hotspot
class_name SpotHotspot
## SpotHotspot — a generic interactable for Episode 1 rooms. It has no content of
## its own: whatever the player does to it (LOOK / TALK / USE) is handed to the
## room that owns it, which runs a short script (lines of dialogue, a terminal,
## a scan...) written in that room's own file.
##
## verb is "LOOK", "TALK" or "USE" - or, REV 293, any other native verb the spot offers (OPEN,
## OPERATE, ANSWER...), passed through as it is (it used to arrive as "USE"). Handlers test
## room.is_use(verb) for "any kind of use". source is the id of the equipment selected in the HUD
## (e.g. the tricorder) or "" for a bare USE.

var room = null            # the EpisodeRoom that owns this spot
var handler: Callable = Callable()
## false = present but not interactable right now. REV 727: also takes it off the pointer's and the player's
## pick (monitorable), so a switched-off spot is never offered.
var enabled: bool = true:
	set(v):
		enabled = v
		monitorable = v


func _ready() -> void:
	# hotspot_id / display_name / interaction_types are filled in by EpisodeRoom.add_spot().
	pass


## REV 490 (the redesign: "evidence is things you SHOW to people"): this person (or thing) can be shown
## items from the backpack. A SHOW verb appears on the wheel while the backpack holds anything; picking it
## asks which item (EpisodeRoom.run_spot). Using a backpack item on it directly is the same SHOW.
## The handler gets verb "SHOW" and source = the item's id.
var shows_items := false


func get_available_verbs(_held_item_id: String, _held_equipment_id: String) -> Array[String]:
	if not enabled:
		var none: Array[String] = []
		return none
	var out: Array[String] = interaction_types.duplicate()
	if shows_items and not out.has("SHOW") and not InventoryManager.get_all_items().is_empty():
		out.append("SHOW")
	return out


func do_examine() -> void:
	_dispatch("LOOK", "")


func do_talk() -> void:
	_dispatch("TALK", "")


## REV 296: people and doors (add_npc / add_door) don't take items. Their handlers treat anything
## but LOOK as TALK / leave, so scanning Tuvall started the negotiation under the scan animation and
## scanning a door opened the travel menu. With an item, nothing is dispatched here and
## InteractionManager answers with its usual "nothing unusual" / wrong-item line instead.
var accepts_items := true

func do_use(source_id: String) -> void:
	if source_id != "" and shows_items and InventoryManager.has_item(source_id):
		_dispatch("SHOW", source_id)     # REV 490: an item used on someone who takes SHOW is shown to them
		return
	if source_id != "" and not accepts_items:
		return
	_dispatch("USE", source_id)


## REV 293: a native verb other than LOOK / TALK / USE reaches the room's handler by its own name
## (Hotspot's default would have turned it into a bare USE).
func do_verb(verb: String) -> void:
	_dispatch(verb, "")


func _dispatch(verb: String, source: String) -> void:
	if room == null or not handler.is_valid():
		return
	room.run_spot(handler, verb, source)
