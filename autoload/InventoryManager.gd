extends Node
## InventoryManager — collected adventure-inventory items only.
##
## Equipment (tricorder, communicator) does NOT live here — see EquipmentManager.
## This keeps the three-tier separation (standard equipment / collected
## inventory / collector cards) structural instead of a naming convention
## someone can accidentally violate.

signal item_added(item: InventoryItemData)
## REV 293: an item left the backpack (used up, combined, handed over). The backpack screen redraws and
## InteractionManager puts it away if it was in hand.
signal item_removed(item_id: String)
## REV 293: not used yet - the backpack puts items in hand with InteractionManager.set_held_source instead.
signal item_use_requested(item_id: String, target_hotspot_id: String)

var _items: Dictionary = {}   # id -> InventoryItemData
var _order: Array[String] = []  # preserves pickup order for UI display

## REV 293: every item this game session has ever seen, by id (kept when an item is removed or a save
## is loaded). A save only stores ids, so this is one of the ways SaveSystem turns them back into items
## when the room has no resolver of its own (see SaveSystem.resolve_inventory_item).
var _known: Dictionary = {}   # id -> InventoryItemData

## REV 293: where an item can live as a resource file, so it can always be found again by id:
## res://data/items/<id>.tres (e.g. data/items/INV_EP1_004.tres). Optional - items built in code work too.
const ITEM_FOLDER := "res://data/items/"


## quiet (REV 306): no pickup sound - for items that appear because the story already gave them to
## you (Episode 1's backpack is rebuilt from its story flags when a room loads).
func add_item(item: InventoryItemData, quiet: bool = false) -> bool:
	if _items.has(item.id):
		# Matches documented behaviour, e.g. HOT_PRO_003 "Attempt Acquire Again":
		# re-acquiring an already-held item is a no-op with its own flavour line,
		# not a duplicate inventory entry.
		return false
	_items[item.id] = item
	_order.append(item.id)
	_known[item.id] = item     # REV 293
	item_added.emit(item)
	if not quiet:
		SfxManager.play("pickup", -4.0)
	return true


## REV 293: takes an item out of the backpack (used up, combined into something else, given away).
## Returns false if it wasn't there. The item stays "known" so a later save/load can still name it.
func remove_item(item_id: String) -> bool:
	if not _items.has(item_id):
		return false
	_items.erase(item_id)
	_order.erase(item_id)
	item_removed.emit(item_id)
	return true


## REV 293: tells the game about an item without putting it in the backpack, so saves can bring it back
## even before the player has picked it up this session (rooms may call it from their setup).
func register_item(item: InventoryItemData) -> void:
	if item != null and item.id != "":
		_known[item.id] = item


## REV 293: an item by id from anything the game knows - the backpack, items seen this session, or a
## resource file in ITEM_FOLDER. null if none of those has it.
func find_known_item(item_id: String) -> InventoryItemData:
	if _items.has(item_id):
		return _items[item_id]
	if _known.has(item_id):
		return _known[item_id]
	var path := ITEM_FOLDER + item_id + ".tres"
	if ResourceLoader.exists(path):
		var res := load(path) as InventoryItemData
		if res != null:
			_known[item_id] = res
			return res
	return null


## REV 296: empties the backpack for a genuinely new game (the Prologue's, or an episode's from
## CHAPTERS / the end card), so items from an earlier run - the bowling ball - never ride along.
## Goes through remove_item so item_removed fires and a held item is put away with it.
func clear() -> void:
	for id in _order.duplicate():
		remove_item(String(id))


# =========================================================================
# REV 475: COMBINE - the backpack's "use one item with another" (the redesign's LucasArts puzzles).
# A room registers its recipes in its setup:
#   InventoryManager.add_recipe(self, "INV_PRO_003", "INV_PRO_002", full_bag, handler)
# Order doesn't matter (a+b == b+a). When the player uses one on the other, InteractionManager asks
# try_combine first: the two ingredients leave the backpack (unless keep_a/keep_b), the result goes
# in, then the handler runs (await-able - a line, a sound). A recipe belongs to the node that made it
# and is ignored once that node is gone, so a room's recipes never leak into the next room.
# No recipe -> the room's own combine_items(a, b), then a "that doesn't work" pool line.
# =========================================================================
var _recipes: Dictionary = {}    # "a|b" (sorted) -> {owner, a, b, result, handler, keep_a, keep_b}


func _recipe_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


func add_recipe(owner: Node, a: String, b: String, result: InventoryItemData = null,
		handler: Callable = Callable(), keep_a: bool = false, keep_b: bool = false) -> void:
	_recipes[_recipe_key(a, b)] = {"owner": owner, "a": a, "b": b, "result": result,
		"handler": handler, "keep_a": keep_a, "keep_b": keep_b}
	if result != null:
		register_item(result)


func remove_recipe(a: String, b: String) -> void:
	_recipes.erase(_recipe_key(a, b))


func has_recipe(a: String, b: String) -> bool:
	var r: Variant = _recipes.get(_recipe_key(a, b))
	if r == null:
		return false
	var owner: Variant = r["owner"]
	if owner != null and not is_instance_valid(owner):
		_recipes.erase(_recipe_key(a, b))
		return false
	return true


## Combines a and b if a recipe exists and both are in the backpack. Returns true if it did.
func try_combine(a: String, b: String) -> bool:
	if not has_recipe(a, b) or not has_item(a) or not has_item(b):
		return false
	var r: Dictionary = _recipes[_recipe_key(a, b)]
	if not bool(r["keep_a"]):
		remove_item(String(r["a"]))
	if not bool(r["keep_b"]):
		remove_item(String(r["b"]))
	var result: InventoryItemData = r["result"]
	if result != null:
		add_item(result, true)
		SfxManager.play("pickup", -4.0)
	var h: Callable = r["handler"]
	if h.is_valid():
		await h.call()
	return true


func has_item(item_id: String) -> bool:
	return _items.has(item_id)


func get_item(item_id: String) -> InventoryItemData:
	return _items.get(item_id)


func get_all_items() -> Array[InventoryItemData]:
	var result: Array[InventoryItemData] = []
	for id in _order:
		result.append(_items[id])
	return result


## REV 293: not used yet (the backpack uses InteractionManager.set_held_source + interact instead).
## Called by the Inventory UI when the player selects an item then targets a
## hotspot with it (item-first USE flow). The hotspot itself decides whether
## it has a USE-with-this-item behaviour defined.
func request_use_on_hotspot(item_id: String, hotspot_id: String) -> void:
	item_use_requested.emit(item_id, hotspot_id)


func get_snapshot() -> Array[String]:
	return _order.duplicate()


## Snapshot restore needs the actual Resources re-resolved by id by whoever
## owns the item registry (episode data), since Resources aren't trivially
## serializable to a save file. SaveSystem calls this with the resolved list.
func load_snapshot(items: Array[InventoryItemData]) -> void:
	_items.clear()
	_order.clear()
	for item in items:
		if item == null or _items.has(item.id):
			continue
		_items[item.id] = item
		_order.append(item.id)
		_known[item.id] = item     # REV 293
