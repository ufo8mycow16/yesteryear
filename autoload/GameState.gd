extends Node
## GameState — the single VAR_* variable registry for the whole game.
##
## Every gameplay-relevant boolean/flag in the project is a VAR_[SCOPE]_[DESCRIPTION]
## entry in this dictionary. Nothing outside this autoload should keep its own
## shadow copy of puzzle state — hotspots, dialogue, and the save system all read
## and write through here so that one save/load round-trip captures everything.
##
## IDs are never renamed or reused once allocated (project-wide rule). Deprecating
## a variable means marking it in DEPRECATED_VARIABLES below with a replacement,
## not deleting its entry.

signal variable_changed(var_name: String, new_value: Variant)

var _variables: Dictionary = {}

## Deprecated variables: old_name -> {replacement: String, reason: String}
## Kept for save-compatibility/documentation; do not read/write these directly.
const DEPRECATED_VARIABLES: Dictionary = {}

## This autoload is intentionally episode-agnostic: it has no idea what a
## VAR_PRO_* variable means. Each episode's scene/content script calls
## register_defaults() with its own default table on load (several Prologue
## hotspot scripts already do this for their own variables) — values already
## present (e.g. loaded from a save) are never clobbered.

## Registers defaults without overwriting anything already set (e.g. after a load).
func register_defaults(defaults: Dictionary) -> void:
	for key in defaults.keys():
		_defaults[key] = defaults[key]      # REV 104: remembered, so a load can fill gaps correctly
		if not _variables.has(key):
			_variables[key] = defaults[key]


## REV 104: every default ever registered (all episodes so far this session).
var _defaults: Dictionary = {}


func get_var(var_name: String) -> Variant:
	if DEPRECATED_VARIABLES.has(var_name):
		push_warning("GameState: reading deprecated variable %s — use %s instead (%s)" % [
			var_name, DEPRECATED_VARIABLES[var_name].replacement, DEPRECATED_VARIABLES[var_name].reason
		])
	if not _variables.has(var_name):
		push_warning("GameState: variable %s read before it was registered; defaulting to false" % var_name)
		return false
	return _variables[var_name]


func set_var(var_name: String, value: Variant) -> void:
	if DEPRECATED_VARIABLES.has(var_name):
		push_warning("GameState: writing deprecated variable %s — use %s instead (%s)" % [
			var_name, DEPRECATED_VARIABLES[var_name].replacement, DEPRECATED_VARIABLES[var_name].reason
		])
	var old_value = _variables.get(var_name)
	_variables[var_name] = value
	if old_value != value:
		variable_changed.emit(var_name, value)


func has_var(var_name: String) -> bool:
	return _variables.has(var_name)


## Evaluates simple boolean condition strings from design-data Resources, e.g.:
##   "VAR_PRO_LANE_EXAMINED == TRUE AND VAR_PRO_LANE_HINT_UNLOCKED == FALSE"
## Supports a flat chain of AND / OR (left-to-right, no parentheses, no mixed
## precedence) because that is the only grammar the design documents use. If a
## future spec needs real precedence or NOT, extend this rather than special-case
## content.
func evaluate_condition(expression: String) -> bool:
	if expression.strip_edges().is_empty():
		return true

	# Normalize, then split on OR first (lowest precedence of the two we support),
	# each OR-segment is itself an AND-chain.
	var or_segments: PackedStringArray = expression.split(" OR ")
	for segment in or_segments:
		if _evaluate_and_chain(segment):
			return true
	return false


func _evaluate_and_chain(segment: String) -> bool:
	var and_parts: PackedStringArray = segment.split(" AND ")
	for part in and_parts:
		if not _evaluate_comparison(part.strip_edges()):
			return false
	return true


func _evaluate_comparison(part: String) -> bool:
	# Expected shape: VAR_NAME == TRUE | VAR_NAME == FALSE
	var tokens: PackedStringArray = part.split("==")
	if tokens.size() != 2:
		push_error("GameState: malformed condition fragment: '%s'" % part)
		return false

	var var_name: String = tokens[0].strip_edges()
	var expected_raw: String = tokens[1].strip_edges().to_upper()
	var expected: bool = (expected_raw == "TRUE")

	return bool(get_var(var_name)) == expected


## Full snapshot for save/load. SaveSystem owns persistence; GameState only
## owns the in-memory truth and the (de)serialization shape.
func get_snapshot() -> Dictionary:
	return _variables.duplicate(true)


## REV 104: the save's values laid over the registered defaults. A save made before a later episode
## added new story values gets those values' proper starting value (not "false"), and values the save
## has that this version no longer uses are kept, harmlessly. So saves survive game updates.
func load_snapshot(snapshot: Dictionary) -> void:
	_variables = _defaults.duplicate(true)
	for key in snapshot.keys():
		_variables[key] = snapshot[key]


## Resets to episode defaults — used when starting a fresh game, not on load.
func reset_to_defaults(defaults: Dictionary) -> void:
	_variables.clear()
	register_defaults(defaults)
	# REV 296: WorldState's own value is registered once at start-up; without this every new game
	# warned "unregistered" until something was written to it.
	register_defaults({"WORLD_STATE": {}})
