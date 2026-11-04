extends Resource
class_name InventoryItemData
## Data for one COLLECTED adventure-inventory item (INV_PRO_xxx, etc.).
##
## This is strictly for items the player physically picks up and that appear
## in the Inventory UI. Standard character equipment (tricorder, communicator)
## is NOT an InventoryItemData — see EquipmentItemData. The Prologue document
## tags the Medical Tricorder with an INV_ prefix in its Required Inventory
## list, but its own parenthetical explicitly says "not collected inventory" —
## that item is built as an EquipmentItemData, not one of these.

@export var id: String = ""           # e.g. "INV_PRO_001"
@export var display_name: String = ""
@export var description: String = ""
@export_multiline var examine_text: String = ""
@export var icon: Texture2D
