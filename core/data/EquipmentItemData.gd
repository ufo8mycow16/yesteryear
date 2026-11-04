extends Resource
class_name EquipmentItemData
## Data for one FIXED, non-collectible piece of standard character equipment
## (e.g. McCoy's Medical Tricorder, Communicator). These are always available
## to the character who owns them from the start of the episode — they are
## never picked up, dropped, or shown in the Inventory UI. They appear in the
## GAME FUNCTIONS / equipment-use side of the HUD "WHAT YOU HAVE" bank instead.

@export var id: String = ""           # e.g. "EQUIP_MCCOY_TRICORDER"
@export var display_name: String = ""
@export var owner_character: String = "" # e.g. "mccoy"
@export var description: String = ""
@export var icon: Texture2D
