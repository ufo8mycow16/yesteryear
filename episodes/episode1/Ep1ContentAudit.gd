extends RefCounted
class_name Ep1ContentAudit
## REV 95 structural QA for Episode 1. Kept separate from Ep1.gd so the audit
## can evolve without touching the authored investigation data itself.

static var _content_validated := false

static func validate_once() -> void:
	if _content_validated:
		return
	_content_validated = true
	var errors := validate_content()
	if errors.is_empty():
		print("Episode 1 content audit: OK (%d rooms, %d clues, %d comparisons)." % [Ep1.ROOMS.size(), Case._defs.size(), Ep1.COMPARE_RULES.size()])
		return
	for message in errors:
		push_error("Episode 1 content audit: " + String(message))


## Public entry point for headless QA. Empty means the Episode 1 gameplay graph
## is internally consistent. Asset/model availability is deliberately outside
## this audit.
static func validate_content() -> Array[String]:
	Ep1._define_clues()
	var errors: Array[String] = []

	for key in Ep1.ROOMS.keys():
		var room: Array = Ep1.ROOMS[key]
		if room.size() < 2:
			errors.append("ROOMS[%s] is malformed." % String(key))
			continue
		var scene_path := String(room[1])
		if not ResourceLoader.exists(scene_path):
			errors.append("ROOMS[%s] points to missing scene: %s" % [String(key), scene_path])

	for rule_v in Ep1.COMPARE_RULES:
		var rule: Array = rule_v
		if rule.size() != 3:
			errors.append("Malformed COMPARE_RULES entry: %s" % str(rule))
			continue
		for clue_index in [0, 1]:
			var clue_id := String(rule[clue_index])
			if not Case.is_defined(clue_id):
				errors.append("Comparison '%s' references undefined clue %s." % [String(rule[2]), clue_id])

	for gate_v in Ep1.DESERT_GATE:
		var gate: Array = gate_v
		if gate.is_empty() or not Case.is_defined(String(gate[0])):
			errors.append("DESERT_GATE references undefined clue: %s" % str(gate))

	for section_v in Ep1.RECON:
		var section: Array = section_v
		if section.size() < 6:
			errors.append("Malformed RECON section: %s" % str(section))
			continue
		for bucket_index in [3, 4, 5]:
			for clue_v in section[bucket_index]:
				var clue_id := String(clue_v)
				if not Case.is_defined(clue_id):
					errors.append("RECON '%s' references undefined clue %s." % [String(section[0]), clue_id])

	for clue_id in [
		"COD_NEURAL", "EVIDENCE_NO_EXPLAIN", "DATAPAD_MISSING",
		"TERMINAL_POSTMORTEM", "ENCRYPTED_COPY", "OTARI_STATEMENT",
		"DELETED_ENTRY", "DELEGATION_ACCESS", "COUNCIL_LEADER_MISSING",
		# REV 293: was NEURAL_CONFIRMED, which nothing ever adds - Sickbay rewords DAREV_NEURAL
		# ("...CONFIRMED / CAUSE UNKNOWN") instead, so DAREV_NEURAL is the clue the story needs
		"DAREV_NEURAL"
	]:
		if not Case.is_defined(clue_id):
			errors.append("Required progression clue is undefined: %s" % clue_id)

	return errors
