extends Node
## EquipmentManager — fixed, non-collectible standard equipment per character.
##
## McCoy starts the Prologue already carrying his Medical Tricorder and
## Communicator; neither is ever picked up, dropped, or shown in the
## Inventory UI. They are selectable directly from the "WHAT YOU HAVE"
## bank's equipment page for use-on-hotspot interactions (e.g. USE Tricorder
## on the Bowling Lane).

## REV 293: not used yet - the backpack puts equipment in hand with InteractionManager.set_held_source.
signal equipment_use_requested(equipment_id: String, target_hotspot_id: String)

var _equipment_by_character: Dictionary = {}  # character_id -> {equip_id: EquipmentItemData}


func grant_equipment(character_id: String, equipment: EquipmentItemData) -> void:
	if not _equipment_by_character.has(character_id):
		_equipment_by_character[character_id] = {}
	_equipment_by_character[character_id][equipment.id] = equipment


func get_equipment_for(character_id: String) -> Array[EquipmentItemData]:
	var result: Array[EquipmentItemData] = []
	if _equipment_by_character.has(character_id):
		for equip in _equipment_by_character[character_id].values():
			result.append(equip)
	return result


## REV 634: anyone's kit item by id (Glen saw "USE EQUIP_SCOTTY_PHASER WITH..." - the name lookup only
## searched McCoy, Kirk and Spock).
func find_equipment(equipment_id: String) -> EquipmentItemData:
	for who in _equipment_by_character:
		var d: Dictionary = _equipment_by_character[who]
		if d.has(equipment_id):
			return d[equipment_id]
	return null


func has_equipment(character_id: String, equipment_id: String) -> bool:
	return _equipment_by_character.has(character_id) and _equipment_by_character[character_id].has(equipment_id)


## Equipment is fixed per episode setup, not saved/loaded as player-earned
## state — it is re-granted deterministically when the episode/scene loads.
## (If a future episode makes equipment acquisition itself a story beat,
## that's a new, deliberate system — not a retrofit of this one.)
func setup_prologue_equipment() -> void:
	var tricorder := EquipmentItemData.new()
	tricorder.id = "EQUIP_MCCOY_TRICORDER"
	tricorder.display_name = "Medical Tricorder"
	tricorder.description = "Standard-issue medical scanner. Use it on people and objects to check for injury, illness or anything unusual."
	tricorder.owner_character = "mccoy"
	grant_equipment("mccoy", tricorder)

	var communicator := EquipmentItemData.new()
	communicator.id = "EQUIP_MCCOY_COMMUNICATOR"
	communicator.display_name = "Communicator"
	communicator.description = "Starfleet hand communicator. Keeps you in touch with the ship."
	communicator.owner_character = "mccoy"
	grant_equipment("mccoy", communicator)


## REV 300 (design review 3.7): Episode rooms give every lead their OWN kit. Before, only McCoy was
## given anything, so Kirk, Spock and Chapel all scanned with "Medical Tricorder" while the rooms say
## Kirk has the engineering sensors and Episode 2 shows the SCIENCE TRICORDER. Keyed by the person
## (InteractionManager.kit_owner uses whoever is being played), so it works whichever slot they're in.
## The Prologue keeps setup_prologue_equipment (McCoy only).
const KITS := {
	"mccoy": [["EQUIP_MCCOY_TRICORDER", "Medical Tricorder", "Standard-issue medical scanner. Use it on people and objects to check for injury, illness or anything unusual."]],
	"kirk": [["EQUIP_KIRK_TRICORDER", "Tricorder", "Standard field tricorder - general sensors, tuned for systems and materials rather than people."]],
	"spock": [["EQUIP_SPOCK_TRICORDER", "Science Tricorder", "Spock's science tricorder. Sensitive, precise, and rarely wrong."]],
	"chapel": [["EQUIP_CHAPEL_TRICORDER", "Medical Tricorder", "Sickbay's medical tricorder."]],
	# REV 593 (Episode 3): Scotty's engineering tricorder and his phaser (the story's phaser: the plate cut, the
	# Matrix, the cargo bay door - the Z-key phaser gag is the same weapon); Kyle's tricorder.
	"scotty": [["EQUIP_SCOTTY_TRICORDER", "Tricorder", "Scotty's tricorder, tuned for engineering - circuits, power, the ship's own systems."],
		["EQUIP_SCOTTY_PHASER", "Phaser", "A standard hand phaser. Setting: whatever the job needs. Mind the conduits."]],
	"kyle": [["EQUIP_KYLE_TRICORDER", "Tricorder", "Kyle's tricorder. He knows exactly where every reading it has ever taken is kept."]],
}

func setup_episode_equipment() -> void:
	setup_prologue_equipment()      # McCoy's tricorder and communicator, as before
	for who in KITS:
		for k in KITS[who]:
			if has_equipment(who, String(k[0])):
				continue
			var e := EquipmentItemData.new()
			e.id = String(k[0])
			e.display_name = String(k[1])
			e.description = String(k[2])
			e.owner_character = String(who)
			grant_equipment(String(who), e)
		if who != "mccoy" and not has_equipment(who, "EQUIP_%s_COMMUNICATOR" % String(who).to_upper()):
			var c := EquipmentItemData.new()
			c.id = "EQUIP_%s_COMMUNICATOR" % String(who).to_upper()
			c.display_name = "Communicator"
			c.description = "Starfleet hand communicator."
			c.owner_character = String(who)
			grant_equipment(String(who), c)


## REV 293: not used yet (nothing calls it; see the signal above).
func request_use_on_hotspot(equipment_id: String, hotspot_id: String) -> void:
	equipment_use_requested.emit(equipment_id, hotspot_id)
