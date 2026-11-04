extends Node
## Evidence -> facts -> deductions. Backwards-compatible with Case/GameState.
signal evidence_recorded(id: String)
signal deduction_unlocked(id: String)
var _rules: Dictionary = {}
var _evaluating := false
func _ready() -> void:
	GameState.variable_changed.connect(_on_variable_changed)
func clear_rules(scope: String = "") -> void:
	if scope == "": _rules.clear(); return
	for id in _rules.keys():
		if String(_rules[id].get("scope", "")) == scope: _rules.erase(id)
func define_deduction(id: String, requires_all: Array[String] = [], requires_any: Array[String] = [], condition: String = "", scope: String = "", quiet := false) -> void:
	_rules[id] = {"all": requires_all.duplicate(), "any": requires_any.duplicate(), "condition": condition, "scope": scope, "quiet": quiet}
	_evaluate()
func note_evidence(id: String) -> void:
	evidence_recorded.emit(id); _evaluate()
func has_knowledge(id: String) -> bool:
	return Case.has(id) or (GameState.has_var("KNOWLEDGE_" + id) and bool(GameState.get_var("KNOWLEDGE_" + id)))
func _on_variable_changed(_n: String, _v: Variant) -> void: _evaluate()
func _evaluate() -> void:
	if _evaluating: return
	_evaluating = true
	var changed := true
	while changed:
		changed = false
		for id in _rules.keys():
			if Case.has(String(id)): continue
			var r: Dictionary = _rules[id]
			var ok := true
			for req in r.all:
				if not has_knowledge(String(req)): ok = false; break
			if ok and not r.any.is_empty():
				ok = false
				for req in r.any:
					if has_knowledge(String(req)): ok = true; break
			if ok and String(r.condition) != "": ok = GameState.evaluate_condition(String(r.condition))
			if ok and Case.is_defined(String(id)):
				Case.add(String(id), bool(r.quiet)); deduction_unlocked.emit(String(id)); changed = true
	_evaluating = false
func debug_rules() -> Dictionary: return _rules.duplicate(true)
