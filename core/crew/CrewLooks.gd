class_name CrewLooks
extends RefCounted
## REV 180: a background crew member's body, built from the face kit (tools/crew/build_face_kit.gd).
##
## Men are the crew_male figure (a blank Genesis 8 Male in uniform); women are Uhura's figure with her
## dress in their division's colour and her hair, earrings and ear communicator taken off. Every head
## is a mix of Glen's faces, region by region (eyes, brow, nose, mouth, jaw, cheeks, ears, rest): each
## region has its own blend of two or three faces, no single face more than half of any region, so
## nobody in the corridors looks like a bridge officer. Then a skin, a hairstyle and its colour, and a
## little height variety. The face bones (eye pivots, jaw, lips) move with the face, so blinking,
## looking and talking still line up.
##
## A person's look is worked out from their id and the crew seed, and saved ("pinned") the first time
## they are built, so adding faces to the kit later never changes someone you have already met.

const KIT := {
	"male": "res://assets/models/crew/kit/face_kit_male.res",
	"female": "res://assets/models/crew/kit/face_kit_female.res",
}
const BASE := {
	"male": "res://assets/models/crew/crew_male.fbx",
	"female": "res://assets/models/characters/Uhura_daz.fbx",
}
const UNIFORM := {
	"male": "res://assets/models/crew/uniforms/uniform_%s.png",
	"female": "res://assets/models/crew/uniforms/dress_%s.png",
}
const KEY_LOOK := "crew/look/"
const MAX_SHARE := 0.5           # the most any one face gives to a region
## REV 325: men's skins that already are a heritage's colour (no extra tint on top).
const MALE_OWN_SKINS := {"african": ["branton", "lorenz"]}
## REV 325: faces marked "likeness" in the kit (game characters, actor likenesses: Agent 47, Hackerman,
## Laurent, Owen, Alistair, Mason, Drake, Verso) give at most this much to a region, so nobody in the crew
## turns out recognisable as them.
const LIKENESS_SHARE := 0.22
## Uhura's own pieces that are hers alone (the female crew wear her dress, not her jewellery or hair).
const FEMALE_REMOVE := ["brinco", "comunicador", "earring", "cabelo"]
## Skin surfaces (tinted for heritage when the skin itself is lighter than the person).
const SKIN_SURF := ["Face", "Lips", "Ears", "EyeSocket", "Torso", "Arms", "Legs", "Fingernails", "Toenails"]

## Faces that suit a heritage (they are favoured, never the only choice). Uhura is the women's base face.
const HERITAGE_FACES := {
	"male": {"east_asian": ["sulu", "kwon"], "pacific": ["sulu", "kwon"], "african": ["branton", "lorenz"]},
	"female": {"east_asian": ["hikari", "hinako", "rinko", "li_mei", "mikari", "izuko"], "pacific": ["lukka", "lina", "hikari"], "south_asian": ["lukka", "lina", "zoya"], "european": [], "african": []},
}
## Faces that read clearly as another heritage: kept to a small share.
const HERITAGE_AVOID := {
	"male": {"european": ["sulu", "kwon"], "african": ["sulu", "kwon"], "latin_american": ["sulu", "kwon"], "middle_eastern": ["sulu", "kwon"], "south_asian": ["sulu", "kwon"],
		"east_asian": ["branton", "lorenz"], "pacific": ["branton", "lorenz"]},
	"female": {"european": ["hikari", "hinako", "rinko", "li_mei", "mikari", "izuko"], "african": ["hikari", "hinako", "rinko", "li_mei", "mikari", "izuko"], "latin_american": ["hikari", "hinako", "rinko", "li_mei", "mikari", "izuko"], "middle_eastern": ["hikari", "hinako", "rinko", "li_mei", "mikari", "izuko"]},
}
## Skins by heritage ("" = the base figure's own skin). T'Pol's skin is never used for humans
## (her Vulcan brows are painted on it).
const HERITAGE_SKINS := {
	"male": {"european": ["", "hans", "felix", "james", "dion", "anatoly", "nathanael", "mason", "alistair"],
		"african": ["branton", "lorenz"],
		"latin_american": ["", "nathanael", "anatoly"], "middle_eastern": ["", "nathanael", "anatoly"],
		"mixed": ["", "hans", "felix", "james", "dion", "nathanael", "mason"],
		"_": ["", "hans", "felix", "james"]},
	"female": {"african": [""], "east_asian": ["hikari", "hinako", "rinko", "li_mei", "mikari", "izuko"], "pacific": ["lukka", "lina", "hikari"], "south_asian": ["lukka", "lina", "zoya", "helena"],
		"european": ["alexia", "imel", "vox", "ashley", "jessie", "amelie", "darinka", "blake", "kate", "colette", "liliana", "ires", "joanna", "celeste", "sliva", "courtney", "elena", "khyla", "reyna", "octavia", "sherry", "tilly", "khinaya", "tatiana_i3d", "astrid", "charissa", "jasmin", "indie", "lieke", "julyanna", "leanne", "bosah", "meena", "eiriana", "evelyn", "anade", "tatiana", "tammy", "danielle", "tsunade"],
		"latin_american": ["zoya", "delphine", "ashley_graham", "laura", "evelyn_rs3d", "flower", "shopia", "austine", "an53"],
		"middle_eastern": ["delphine", "cressida", "kitana", "helena", "an53", "laura"], "mixed": ["", "kate", "laura", "austine", "imel", "flower", "delphine", "shopia"]},
}
## Until there are skins for every heritage, a lighter skin is tinted toward the person's tone.
## (men: all four skins are light; women: only where a skin is borrowed.)
const TINT := {
	"male": {"african": Color(0.52, 0.40, 0.33), "south_asian": Color(0.76, 0.62, 0.50), "middle_eastern": Color(0.88, 0.76, 0.64),
		"latin_american": Color(0.86, 0.73, 0.60), "pacific": Color(0.80, 0.66, 0.53), "east_asian": Color(0.98, 0.91, 0.80), "mixed": Color(0.85, 0.72, 0.60)},
	"female": {},   # REV 221: every heritage has skins of its own now
}
## Hair colour (multiplies the hair texture): darker for most heritages, a range for Europeans.
const HAIR_TINTS_DARK := [Color(0.35, 0.33, 0.32), Color(0.45, 0.42, 0.40), Color(0.55, 0.50, 0.46)]
const HAIR_TINTS_ANY := [Color(1, 1, 1), Color(0.85, 0.78, 0.70), Color(0.65, 0.58, 0.52), Color(0.45, 0.42, 0.40), Color(1.0, 0.82, 0.62), Color(0.80, 0.80, 0.80)]

static var _kits := {}
static var _vmaps := {}         # "sex/surface index" -> PackedInt32Array (game vertex -> kit point, -1 = not head)
static var _lmaps := {}
static var _shape_cache := {}
static var _bases := {}   # "mesh id/surface" -> the kept expression shape arrays


## A finished, animated, solid crew member for CrewRoster person_id (feet at 0, facing +Z), or null.
static func make(person_id: String, extra: Dictionary = {}) -> Node3D:
	var p := CrewRoster.person(person_id)
	if p.is_empty():
		return null
	var sex := String(p.get("sex", "male"))
	if not ResourceLoader.exists(BASE[sex]):
		return null
	if not _bases.has(sex):
		_bases[sex] = load(BASE[sex])     # kept: otherwise the whole Daz file is read again for every person
	var inst: Node3D = (_bases[sex] as PackedScene).instantiate() as Node3D
	var look := look_of(person_id)
	apply(inst, sex, look, CrewRoster.shirt_of(person_id), not CrewRoster.wears_braid(person_id))
	inst.scale = Vector3.ONE * float(look.get("height", 1.0))
	# REV 182: say outright who is a woman (the animator used to guess from the body mesh's name, which
	# missed the crew women built on Uhura's figure - Petty Officer Gray sat like a man)
	inst.set_meta("sex", sex)
	var wrapper := Node3D.new()
	wrapper.name = "Crew_" + person_id
	wrapper.set_meta("sex", sex)
	wrapper.add_child(inst)
	var animator := CharacterAnimator.new()
	animator.name = "Animator"
	wrapper.add_child(animator)
	animator.setup(wrapper, inst)
	CharacterFace.attach(wrapper, inst, null, "crew")
	wrapper.add_to_group("speakers")
	wrapper.set_meta("speaker_id", "crew")
	wrapper.set_meta("crew_id", person_id)
	wrapper.set_meta("display_name", CrewRoster.display_name(person_id))
	if bool(extra.get("solid", true)):
		CharacterBlocker.attach(wrapper)
	return wrapper


## REV 881 (Glen: Vulcan women in gowns): a Vulcan woman for the city - a crew-kit face (the same region mixing as
## the crew, from `salt`), Vulcan ears from a Vulcan face in the kit, and a converted Daz outfit instead of the
## Starfleet dress (DazOutfit; Glen's Royal Elf gown in rust / sand / plum). opts: "variant", "hair_tint",
## "height", "cape" (true only for women who stand still - the cape has a train), "hair" (a kit name).
static func make_vulcan_woman(salt: String, opts: Dictionary = {}) -> Node3D:
	if not ResourceLoader.exists(BASE["female"]):
		return null
	var kit := _kit("female")
	var look := _derive("vulcan_" + salt, {"sex": "female", "heritage": "mixed"}, kit)
	var vulcan := ""
	for f in kit.get("faces", []):
		if String(f.get("species", "human")) == "vulcan" or String(f["name"]) == "tpol":
			vulcan = String(f["name"])
			break
	if vulcan != "":
		var mix: Dictionary = (look["mix"] as Dictionary).duplicate(true)
		mix["ears"] = {vulcan: 1.0}
		look["mix"] = mix
	for k in ["hair_tint", "hair", "height"]:
		if opts.has(k):
			look[k] = opts[k]
	var fig := make_with_look("female", look, "red")
	if fig == null:
		return null
	if fig.get_child_count() > 0 and fig.get_child(0) is Node3D:
		(fig.get_child(0) as Node3D).scale = Vector3.ONE * float(look.get("height", 1.0))
	var variants: Array = DazOutfit.VARIANTS["royal_gown"]
	var variant := String(opts.get("variant", variants[CrewRoster._h(salt, 7) % variants.size()]))
	DazOutfit.wear(fig, "royal_gown", variant, {} if bool(opts.get("cape", false)) else {"leave_off": ["cape"]})
	return fig


## REV 221: a figure with a look given outright (the crew viewer's hair / skin / face catalogue).
static func make_with_look(sex: String, look: Dictionary, shirt: String = "blue") -> Node3D:
	if not ResourceLoader.exists(BASE[sex]):
		return null
	if not _bases.has(sex):
		_bases[sex] = load(BASE[sex])
	var inst: Node3D = (_bases[sex] as PackedScene).instantiate() as Node3D
	apply(inst, sex, look, shirt, true)
	inst.set_meta("sex", sex)
	var wrapper := Node3D.new()
	wrapper.set_meta("sex", sex)
	wrapper.add_child(inst)
	var animator := CharacterAnimator.new()
	animator.name = "Animator"
	wrapper.add_child(animator)
	animator.setup(wrapper, inst)
	CharacterFace.attach(wrapper, inst, null, "crew")
	return wrapper


## REV 280: story people whose face is chosen by hand, region by region, from the kit faces (never
## pinned in a save, so a better recipe later simply replaces it). Shares per region add up to 1.0, so
## none of Uhura's base face shows. Chapel: picked by Claude from Glen's photos of her (24 Oct).
const FIXED_LOOKS := {
	# Chapel: Kate's high cheekbones and tapered chin as the frame; Austine's slightly hooded, older
	# eyes; Kate/Sarah Morgan's straight nose with the softly rounded tip; Celeste/Cressida's thin
	# upper lip and fuller lower lip; a long oval head (Celeste/Kate). MEGA Updo (the beehive), strawberry
	# blonde; blue sciences dress with a lieutenant's braid (REV 281, Glen: she is a lieutenant).
	"chapel": {
		"mix": {
			"eyes": {"austine": 0.55, "kate": 0.45},
			"brow": {"kate": 0.6, "julyanna": 0.4},
			"nose": {"kate": 0.5, "sarah_morgan": 0.5},
			"mouth": {"celeste": 0.6, "cressida": 0.4},
			"jaw": {"kate": 0.5, "celeste": 0.5},
			"cheeks": {"kate": 0.5, "austine": 0.5},
			"ears": {"kate": 1.0},
			"rest": {"celeste": 0.5, "kate": 0.5},
		},
		"skin": "kate", "hair": "mega_updo_0",
		"hair_tint": [1.0, 0.86, 0.66], "skin_tint": [1.0, 1.0, 1.0], "height": 0.97,
	},
}


## Names in the kit, for the viewer: "hair", "skins" or "faces". (REV 293: comment moved here from
## above FIXED_LOOKS, where it had ended up by mistake.)
static func kit_names(sex: String, what: String) -> Array:
	var out: Array = []
	for e in _kit(sex).get(what, []):
		out.append(String(e["name"]))
	if what == "hair" and sex == "female":
		out.append("base")
	return out


## This person's look: pinned in the save, or worked out now (and pinned).
static func look_of(person_id: String) -> Dictionary:
	if FIXED_LOOKS.has(person_id):
		return FIXED_LOOKS[person_id]
	var pinned = WorldState.get_value(KEY_LOOK + person_id, null)
	var p := CrewRoster.person(person_id)
	var sex := String(p.get("sex", "male"))
	var kit := _kit(sex)
	if pinned is Dictionary and _still_valid(pinned, kit):
		return _story_overrides(person_id, pinned, kit)
	var look := _derive(person_id, p, kit)
	WorldState.set_value(KEY_LOOK + person_id, look)
	return _story_overrides(person_id, look, kit)


## REV 610: a story person can pin a hairstyle (and its colour) in CrewRoster.STORY_PEOPLE - "hair" (a kit name)
## and "hair_tint" ([r, g, b]) - whatever was rolled for them, saved games included. (Giotto drew one of the
## kit's broken, dotty styles - Glen.)
static func _story_overrides(person_id: String, look: Dictionary, kit: Dictionary) -> Dictionary:
	var sp: Dictionary = CrewRoster.STORY_PEOPLE.get(person_id, {})
	if not sp.has("hair"):
		return look
	var want := String(sp["hair"])
	var found := false
	for h in kit.get("hair", []):
		if String(h["name"]) == want:
			found = true
	if not found:
		return look
	var out := look.duplicate()
	out["hair"] = want
	if sp.has("hair_tint"):
		out["hair_tint"] = sp["hair_tint"]
	return out


static func _derive(person_id: String, p: Dictionary, kit: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = CrewRoster._h(person_id + "look", CrewRoster.crew_seed())
	var sex := String(p.get("sex", "male"))
	var her := String(p.get("heritage", "mixed"))
	var names: Array[String] = []
	var likeness := {}
	for f in kit.get("faces", []):
		# REV 221: alien faces (Tellarite, Andorian) never blend into humans; Vulcan faces do (their
		# ears are kept out below)
		if String(f.get("species", "human")) in ["human", "vulcan"]:
			names.append(String(f["name"]))
			if bool(f.get("likeness", false)):
				likeness[String(f["name"])] = true
	var favoured: Array = (HERITAGE_FACES[sex] as Dictionary).get(her, [])
	var avoid: Array = (HERITAGE_AVOID[sex] as Dictionary).get(her, [])
	var mix := {}
	for r in kit.get("regions", []):
		var pool := names.duplicate()
		if r == "ears":
			for f in kit.get("faces", []):     # Vulcan ears are for Vulcans
				if String(f.get("species", "human")) == "vulcan" or String(f["name"]) == "tpol":
					pool.erase(String(f["name"]))
		var w := {}
		# how much of the region comes from the kit faces (the rest is the base face)
		var total := rng.randf_range(0.6, 0.95)
		if sex == "female" and her == "african":
			total = rng.randf_range(0.5, 0.65)  # Uhura's base face shows more (still under half)
		var picks: Array[String] = []
		for f in favoured:
			if pool.has(f):
				picks.append(f)
		while picks.size() < 3 and not pool.is_empty():
			var f2: String = pool[rng.randi() % pool.size()]
			pool.erase(f2)
			if not picks.has(f2):
				picks.append(f2)
		var raw := []
		var s := 0.0
		for i in picks.size():
			var v := rng.randf_range(0.3, 1.0) + (1.2 if favoured.has(picks[i]) else 0.0)
			if avoid.has(picks[i]):
				v *= 0.2
			raw.append(v)
			s += v
		for i in picks.size():
			# rounded: a save keeps exactly what was stored (JSON would nudge the last digits)
			w[picks[i]] = snappedf(minf(LIKENESS_SHARE if likeness.has(picks[i]) else MAX_SHARE, total * raw[i] / s), 0.0001)
		mix[r] = w
	var skins: Dictionary = HERITAGE_SKINS[sex]
	var skin_pool: Array = skins.get(her, skins.get("_", [""]))
	var have := {"": true}
	for sk in kit.get("skins", []):
		have[String(sk["name"])] = true
	var usable: Array = []
	for sname in skin_pool:
		if have.has(sname):
			usable.append(sname)
	if usable.is_empty():
		usable = [""]
	var skin: String = usable[rng.randi() % usable.size()]
	var hairs := _hair_choices(sex, kit)
	if sex == "female":
		hairs.append("base")                    # Uhura's own hair, recoloured
	var hair: String = hairs[rng.randi() % hairs.size()] if not hairs.is_empty() else ""
	if sex == "male" and (her == "east_asian" or her == "pacific") and hairs.has("sulu_0") and rng.randf() < 0.5:
		hair = "sulu_0"
	var tints: Array = HAIR_TINTS_ANY if her == "european" or her == "mixed" else HAIR_TINTS_DARK
	var hc: Color = tints[rng.randi() % tints.size()]
	var tint: Color = (TINT[sex] as Dictionary).get(her, Color.WHITE)
	if sex == "female" and skin != "" and (HERITAGE_SKINS["female"] as Dictionary).get(her, []).has(skin) and not (TINT["female"] as Dictionary).has(her):
		tint = Color.WHITE
	# REV 325: a man's skin that is already his heritage's own colour isn't darkened again
	if sex == "male" and (MALE_OWN_SKINS.get(her, []) as Array).has(skin):
		tint = Color.WHITE
	return {
		"mix": mix, "skin": skin, "hair": hair,
		"hair_tint": [snappedf(hc.r, 0.001), snappedf(hc.g, 0.001), snappedf(hc.b, 0.001)],
		"skin_tint": [snappedf(tint.r, 0.001), snappedf(tint.g, 0.001), snappedf(tint.b, 0.001)],
		"height": snappedf(rng.randf_range(0.96, 1.04) if sex == "male" else rng.randf_range(0.93, 0.99), 0.001),
	}


## A pinned look stays only while every face and skin it uses is still in the kit; anyone pinned
## with a part the kit no longer has is worked out again without it. (Added in REV 220 when Hikari was
## taken out; REV 293 note: she came back in the REV 222 recipe rebuild, so today this only matters
## when a future kit drops a face or skin.)
static func _still_valid(look: Dictionary, kit: Dictionary) -> bool:
	if not (look.has("mix") and look.has("skin") and look.has("hair")):
		return false
	for sx in RETIRED_HAIR:     # REV 445: a look saved with a hairstyle retired since gets a new one
		if (RETIRED_HAIR[sx] as Array).has(String(look["hair"])):
			return false
	if kit.is_empty():
		return true
	var faces := {}
	for f in kit.get("faces", []):
		faces[String(f["name"])] = true
	for r in (look["mix"] as Dictionary).values():
		for fname in (r as Dictionary).keys():
			if not faces.has(String(fname)):
				return false
	var skin := String(look["skin"])
	if skin != "":
		var ok := false
		for sk in kit.get("skins", []):
			if String(sk["name"]) == skin:
				ok = true
		if not ok:
			return false
	return true


# ---------------------------------------------------------------------------

## Reshape and dress a freshly instanced base figure.
static func apply(inst: Node3D, sex: String, look: Dictionary, shirt: String, plain_sleeves: bool = true) -> void:
	var kit := _kit(sex)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var body: MeshInstance3D = null
	var lashes: MeshInstance3D = null
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var n := String(m.name).to_lower()
		if n.begins_with("genesis8male_shape") or n.begins_with("genesis8female_shape"):
			body = m
		elif n.begins_with("genesis8") and n.contains("eyelashes"):
			lashes = m
	if sex == "female":
		_strip_uhura(inst, look)
	if not kit.is_empty() and body != null:
		_look_now = look
		var coef := _coefficients(kit, look.get("mix", {}))
		_reshape_body(body, kit, coef, sex)
		if lashes != null:
			_reshape_lashes(lashes, kit, coef, sex)
		_move_bones(inst, sk, kit, coef)
	_skin(body, kit, look)
	# REV 221: the skin's own detail (pores, shine, glow), from the export the skin came from
	var skin_name := String(look.get("skin", ""))
	CharacterDetail.apply(inst, ("%s_%s" % [sex, skin_name]) if skin_name != "" else ("Uhura_daz" if sex == "female" else ""))
	_uniform(inst, sex, shirt, plain_sleeves)
	_hair(inst, sk, kit, look)
	CharacterLook.apply(inst, "crew_" + sex)      # REV 736 (crease maps REV 740): eyes, skin, hair, face light - last, after every swap


## For each kit face, how much it counts in each region: coef[face index][region index].
static func _coefficients(kit: Dictionary, mix: Dictionary) -> Array:
	var regions: Array = kit["regions"]
	var out := []
	for f in kit["faces"]:
		var row := PackedFloat32Array()
		row.resize(regions.size())
		for ri in regions.size():
			var w: Dictionary = mix.get(regions[ri], {})
			row[ri] = float(w.get(String(f["name"]), 0.0))
		out.append(row)
	return out


## How much each face counts at each point: k[face][j] = that face's region shares . point j's
## region weights. Worked out once, used for both the shape and the shading.
static func _point_k(kit_faces: Array, coef: Array, w: PackedFloat32Array, nreg: int, count: int) -> Array:
	var out := []
	for fi in kit_faces.size():
		var c: PackedFloat32Array = coef[fi]
		var k := PackedFloat32Array()
		var any := false
		for v0 in c:
			if v0 > 0.0:
				any = true
		if not any:
			out.append(k)
			continue
		k.resize(count)
		for j in count:
			var o := j * nreg
			var v := 0.0
			for r in nreg:
				v += c[r] * w[o + r]
			k[j] = v
		out.append(k)
	return out


static func _blend(kit_faces: Array, key: String, ks: Array, count: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(count)
	for fi in kit_faces.size():
		var k: PackedFloat32Array = ks[fi]
		if k.is_empty():
			continue
		var d: PackedVector3Array = kit_faces[fi][key]
		for j in count:
			if k[j] > 0.0005:
				out[j] += d[j] * k[j]
	return out


static func _reshape_body(body: MeshInstance3D, kit: Dictionary, coef: Array, sex: String) -> void:
	var nreg: int = (kit["regions"] as Array).size()
	var pts: PackedVector3Array = kit["pts"]
	var ks := _point_k(kit["faces"], coef, kit["w"], nreg, pts.size())
	var dp := _blend(kit["faces"], "pos", ks, pts.size())
	var dn := _blend(kit["faces"], "nrm", ks, pts.size())
	body.mesh = _rebuild(body.mesh as ArrayMesh, "%s/body" % sex, pts, dp, dn, _scalp_colour(_look_now, _kit(sex)))


static func _reshape_lashes(lashes: MeshInstance3D, kit: Dictionary, coef: Array, sex: String) -> void:
	var nreg: int = (kit["regions"] as Array).size()
	var pts: PackedVector3Array = kit["lash_pts"]
	if pts.is_empty():
		return
	var ks := _point_k(kit["faces"], coef, kit["lash_w"], nreg, pts.size())
	var dp := _blend(kit["faces"], "lash", ks, pts.size())
	lashes.mesh = _rebuild(lashes.mesh as ArrayMesh, "%s/lash" % sex, pts, dp, PackedVector3Array())


## A copy of the mesh with every point that is a kit point moved by its offset (and its normal
## turned), expression shapes kept working.
## REV 712 (Glen, Crewman Taylor in the security office: "she has a bald patch too"): REV 368's under-layer fills the
## hair cards where the strands are dense, but where the cards don't reach - a parting, the crown - the pale scalp still
## showed. The head's skin is now shaded towards the hair's own colour over the scalp (vertex colours on the Face
## surface, used as an albedo multiplier): the frontal hairline about 6 cm below the crown, sweeping down to the
## nape at the back, feathered so there's no line.
## REV 729 (handoff: Lt Moreau and Crewman Fraser still bald-patched): two gaps closed. (1) The shaded cap only
## dropped toward the nape at the very back, so the SIDES of the head (above and behind the ears - where the long
## women's styles thin out) stayed skin: behind the temples the hairline now drops to SCALP_SIDE (just above the
## ear) before sweeping on to the nape. The front stays at SCALP_FRONT and the temple drop starts behind the outer
## brow (SCALP_SIDE_FROM), so faces and brows are never touched. (2) The scalp took a flat fraction of the hair
## TINT - pale against a picture-coloured hair: it now takes the hair picture's own average colour (alpha-weighted,
## from the style's albedo picture, cached per style) times the tint, a shade darker (SCALP_SHADE), like the
## REV 368 under-layer - so the whole crown under the hair reads as hair, whatever the style.
const SCALP_SHADE := 0.62          # the scalp against the hair's real colour (multiplies the skin picture)
const SCALP_SHADE_TINT_ONLY := 0.42   # fallback when the style has no readable picture (the REV 712 value)
const SCALP_FRONT := 0.058         # metres below the top of the head: the hairline at the front
const SCALP_SIDE := 0.105          # ... over the sides, behind the temples (just above the ear)
const SCALP_BACK := 0.17           # ... and at the back (the nape)
const SCALP_SIDE_FROM := Vector2(0.30, 0.44)   # REV 740: was (0.36, 0.50) - a bare wedge of skin showed at the temples (Giotto)   # depth fraction (0 nose, 1 back) where the sides start dropping / are down
const SCALP_FEATHER := 0.014       # metres: the soft edge
static var _look_now: Dictionary = {}
static var _hair_avg: Dictionary = {}      # style name -> its picture's average colour (REV 729)


static func _scalp_colour(look: Dictionary, kit: Dictionary = {}) -> Color:
	var style := String(look.get("hair", ""))
	if style == "":
		return Color.WHITE
	var t: Array = look.get("hair_tint", [1, 1, 1])
	var tint := Color(float(t[0]), float(t[1]), float(t[2]))
	var base := _hair_colour(kit, style)
	var shade := SCALP_SHADE if base.a > 0.0 else SCALP_SHADE_TINT_ONLY
	if base.a <= 0.0:
		base = Color.WHITE
	return Color(clampf(base.r * tint.r * shade, 0.0, 1.0), clampf(base.g * tint.g * shade, 0.0, 1.0), clampf(base.b * tint.b * shade, 0.0, 1.0))


## The average colour of a hair style's own picture (the main surface's albedo, times its albedo colour), weighted by
## how solid each pixel is so the transparent card edges don't wash it out. Alpha 0 = no picture found.
static func _hair_colour(kit: Dictionary, style: String) -> Color:
	if _hair_avg.has(style):
		return _hair_avg[style]
	var out := Color(1, 1, 1, 0)
	for h in kit.get("hair", []):
		if String(h["name"]) != style or not ResourceLoader.exists(String(h["file"])):
			continue
		var mesh := load(String(h["file"])) as ArrayMesh
		if mesh == null:
			break
		var tex: Array = mesh.get_meta("tex", [])
		var sum := Vector3.ZERO
		var wsum := 0.0
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as StandardMaterial3D
			var spec: Dictionary = tex[s] if s < tex.size() else {}
			var pic: Texture2D = null
			if spec.has("albedo_texture") and ResourceLoader.exists(String(spec["albedo_texture"])):
				pic = load(String(spec["albedo_texture"])) as Texture2D
			elif mat != null:
				pic = mat.albedo_texture
			if pic == null:
				continue
			var img := pic.get_image()
			if img == null or img.is_empty():
				continue
			img = img.duplicate() as Image
			if img.is_compressed() and img.decompress() != OK:
				continue
			img.convert(Image.FORMAT_RGBA8)
			img.resize(16, 16, Image.INTERPOLATE_BILINEAR)
			var ac := mat.albedo_color if mat != null else Color.WHITE
			for y in 16:
				for x in 16:
					var c := img.get_pixel(x, y)
					var w := c.a * c.a          # solid strands count, fringes hardly
					sum += Vector3(c.r * ac.r, c.g * ac.g, c.b * ac.b) * w
					wsum += w
		if wsum > 0.01:
			out = Color(sum.x / wsum, sum.y / wsum, sum.z / wsum, 1.0)
		break
	_hair_avg[style] = out
	return out


## Per-vertex shade for the Face surface: 1 on the face, the scalp colour under the hair.
static func _scalp_colours(v: PackedVector3Array, scalp: Color) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(v.size())
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for p in v:
		lo = lo.min(p)
		hi = hi.max(p)
	# the Face surface is a head (and maybe some neck) - over 5 units tall means the file is in centimetres
	var unit := 100.0 if hi.y - lo.y > 5.0 else 1.0
	var depth := maxf(hi.z - lo.z, 0.001)
	for i in v.size():
		var p := v[i]
		var t := clampf((hi.z - p.z) / depth, 0.0, 1.0)          # 0 at the front (the nose), 1 at the back
		# REV 729: front hairline -> down over the sides behind the temples -> down to the nape at the back
		var side := lerpf(SCALP_FRONT, SCALP_SIDE, smoothstep(SCALP_SIDE_FROM.x, SCALP_SIDE_FROM.y, t))
		var d := unit * lerpf(side, SCALP_BACK, smoothstep(0.6, 0.95, t))
		var m := clampf((p.y - (hi.y - d)) / (unit * SCALP_FEATHER), 0.0, 1.0)
		out[i] = Color.WHITE.lerp(scalp, m)
	return out


static func _rebuild(am: ArrayMesh, cache_key: String, pts: PackedVector3Array, dp: PackedVector3Array, dn: PackedVector3Array, scalp: Color = Color.WHITE) -> ArrayMesh:
	var nm := ArrayMesh.new()
	nm.resource_name = am.resource_name
	nm.blend_shape_mode = am.blend_shape_mode
	# only the expression shapes the face actually uses (blinks, resting lids, mouth, expressions):
	# all 140 of Daz's would cost ~100 MB per crew member
	var keep := PackedInt32Array()
	var used := _used_shapes()
	for i in am.get_blend_shape_count():
		if used.has(String(am.get_blend_shape_name(i))):
			keep.append(i)
			nm.add_blend_shape(am.get_blend_shape_name(i))
	for s in am.get_surface_count():
		var arr := am.surface_get_arrays(s)
		var vmap := _vertex_map(cache_key + "/%d/%d" % [s, am.get_instance_id()], arr[Mesh.ARRAY_VERTEX], pts)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var moved := PackedVector3Array()
		moved.resize(v.size())
		for i in v.size():
			var j := vmap[i]
			if j < 0:
				continue
			v[i] += dp[j]
			moved[i] = dp[j]
			if not dn.is_empty() and i < n.size():
				n[i] = (n[i] + dn[j]).normalized()
		arr[Mesh.ARRAY_VERTEX] = v
		if not n.is_empty():
			arr[Mesh.ARRAY_NORMAL] = n
		var smat := am.surface_get_material(s)
		if scalp != Color.WHITE and smat != null and smat.resource_name == "Face":
			arr[Mesh.ARRAY_COLOR] = _scalp_colours(v, scalp)      # REV 712
		# the kept expression shapes of this base surface, fetched once (fetching all 140 every time
		# was most of the cost of building a person)
		var skey := "%d/%d" % [am.get_instance_id(), s]
		if not _shape_cache.has(skey):
			var all_shapes := am.surface_get_blend_shape_arrays(s)
			var kept := []
			for i in keep:
				kept.append(all_shapes[i])
			_shape_cache[skey] = kept
		var shapes := []
		for sh in _shape_cache[skey]:
			shapes.append((sh as Array).duplicate() if am.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED else sh)
		if am.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED:
			# shapes are whole positions: move them with the face
			for sh in shapes:
				var sv: PackedVector3Array = sh[Mesh.ARRAY_VERTEX]
				for i in sv.size():
					sv[i] += moved[i]
				sh[Mesh.ARRAY_VERTEX] = sv
				sh[Mesh.ARRAY_NORMAL] = arr[Mesh.ARRAY_NORMAL]
		nm.add_surface_from_arrays(am.surface_get_primitive_type(s), arr, shapes)
		nm.surface_set_name(s, am.surface_get_name(s))
		nm.surface_set_material(s, am.surface_get_material(s))
	return nm


static var _used: Dictionary = {}


## The expression shapes CharacterFace drives on a Daz figure.
static func _used_shapes() -> Dictionary:
	if not _used.is_empty():
		return _used
	var p := CharacterFaceProfile.daz_genesis8()
	for n in [p.blink_left, p.blink_right, p.jaw_open]:
		_used[String(n)] = true
	for n in p.rest_shapes:
		_used[String(n)] = true
	for k in p.visemes:
		if String(p.visemes[k]) != "":
			_used[String(p.visemes[k])] = true
	for e in p.emotions:
		for n in p.emotions[e]:
			_used[String(n)] = true
	return _used


## Which kit point each vertex of this surface is (by position: the base figure IS the kit's base),
## worked out once per base mesh surface and kept.
static func _vertex_map(key: String, verts: PackedVector3Array, pts: PackedVector3Array) -> PackedInt32Array:
	if _vmaps.has(key):
		return _vmaps[key]
	var grid := {}
	for j in pts.size():
		var c := Vector3i((pts[j] * 2000.0).floor())       # 0.5 mm cells
		if not grid.has(c):
			grid[c] = PackedInt32Array()
		(grid[c] as PackedInt32Array).append(j)
	var out := PackedInt32Array()
	out.resize(verts.size())
	for i in verts.size():
		out[i] = -1
		var c := Vector3i((verts[i] * 2000.0).floor())
		var best := 0.00035 * 0.00035     # within 0.35 mm
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var cell := c + Vector3i(dx, dy, dz)
					if not grid.has(cell):
						continue
					for j in grid[cell]:
						var d := verts[i].distance_squared_to(pts[j])
						if d < best:
							best = d
							out[i] = j
	_vmaps[key] = out
	return out


## Move the face bones (eye pivots, jaw, lips...) with the face, and re-fit every skinned piece to them.
static func _move_bones(inst: Node3D, sk: Skeleton3D, kit: Dictionary, coef: Array) -> void:
	var bone_w: Dictionary = kit.get("bone_w", {})
	var nreg: int = (kit["regions"] as Array).size()
	var delta := {}
	for bn in bone_w:
		var w: PackedFloat32Array = bone_w[bn]
		var d := Vector3.ZERO
		for fi in (kit["faces"] as Array).size():
			var fd: Vector3 = (kit["faces"][fi]["bones"] as Dictionary).get(bn, Vector3.ZERO)
			if fd == Vector3.ZERO:
				continue
			var k := 0.0
			for r in nreg:
				k += coef[fi][r] * w[r]
			d += fd * k
		if d.length() > 0.0002:
			var b := sk.find_bone(bn)
			if b >= 0:
				delta[b] = d
	if delta.is_empty():
		return
	var old_global := {}
	for b in sk.get_bone_count():
		old_global[b] = sk.get_bone_global_rest(b)
	var new_global := {}
	for b in sk.get_bone_count():          # parents come before children in a Godot skeleton
		var g: Transform3D = old_global[b]
		if delta.has(b):
			g.origin += delta[b]
		var parent := sk.get_bone_parent(b)
		var pg: Transform3D = new_global[parent] if parent >= 0 else Transform3D()
		if delta.has(b) or (parent >= 0 and new_global[parent] != old_global[parent]):
			# a moved bone goes to its new place; a bone under a moved one stays where it was
			# (the face's own offsets already put its points right)
			sk.set_bone_rest(b, pg.affine_inverse() * g)
			sk.reset_bone_pose(b)
		new_global[b] = g
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.skin == null:
			continue
		var skin := mi.skin.duplicate() as Skin
		for i in skin.get_bind_count():
			var b := skin.get_bind_bone(i)
			if b < 0:
				b = sk.find_bone(String(skin.get_bind_name(i)))
			if b < 0 or not delta.has(b):
				continue
			var gn: Transform3D = new_global[b]
			var go: Transform3D = old_global[b]
			skin.set_bind_pose(i, gn.affine_inverse() * go * skin.get_bind_pose(i))
		mi.skin = skin


static func _skin(body: MeshInstance3D, kit: Dictionary, look: Dictionary) -> void:
	if body == null:
		return
	var tex := {}
	for sk in kit.get("skins", []):
		if String(sk["name"]) == String(look.get("skin", "")):
			tex = sk["tex"]
	var t: Array = look.get("skin_tint", [1, 1, 1])
	var tint := Color(float(t[0]), float(t[1]), float(t[2]))
	var am := body.mesh as ArrayMesh
	for s in am.get_surface_count():
		var mat := am.surface_get_material(s) as StandardMaterial3D
		if mat == null:
			continue
		var name := mat.resource_name
		var changed := false
		var nm := mat.duplicate() as StandardMaterial3D
		if tex.has(name) and ResourceLoader.exists(String(tex[name])):
			nm.albedo_texture = load(String(tex[name]))
			changed = true
			if name == "Irises":
				nm.albedo_color = Color.WHITE      # the skin's own eye colour, not the importer's grey
		if SKIN_SURF.has(name) and tint != Color.WHITE:
			nm.albedo_color = nm.albedo_color * tint
			changed = true
		if name == "Face" and (am.surface_get_format(s) & Mesh.ARRAY_FORMAT_COLOR) != 0:
			nm.vertex_color_use_as_albedo = true      # REV 712: the scalp shade
			changed = true
		if changed:
			am.surface_set_material(s, nm)


static func _uniform(inst: Node3D, sex: String, shirt: String, plain_sleeves: bool) -> void:
	var path := String(UNIFORM[sex]) % shirt
	if plain_sleeves:
		# crewmen, yeomen, petty officers and ensigns wear no sleeve braid (tools/textures/plain_sleeves.py)
		path = path.replace(".png", "_plain.png")
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var n := String(mi.name).to_lower()
		if n.begins_with("genesis8"):
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if mat != null and mat.resource_name.begins_with("40_model"):
				var nm := mat.duplicate() as StandardMaterial3D
				nm.albedo_texture = tex
				mi.set_surface_override_material(s, nm)


static func _strip_uhura(inst: Node3D, look: Dictionary) -> void:
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var n := String(m.name).to_lower()
		for bad in FEMALE_REMOVE:
			if n.contains(bad):
				if bad == "cabelo" and String(look.get("hair", "")) == "base":
					_tint_hair(m as MeshInstance3D, look)     # her hair, recoloured, is one of the styles
					continue
				var holder: Node = m
				if m.get_parent() is BoneAttachment3D:
					holder = m.get_parent()
				holder.get_parent().remove_child(holder)
				holder.queue_free()
				break


## REV 187 (Glen: Pell's hair "looks funky"): styles the crew no longer wear. felix_0 is a long, modern,
## feathered cut - wrong for TOS - that sat off the reshaped heads (a bare patch at the parting).
## REV 221 (Glen agreed): Mystery Woman's cap, Lara Croft's and Kara's broken pieces, and the long,
## loose or modern cuts (Ironside, Mystery Woman's curls, Sorceress, Evelyn) - not TOS.
## REV 392 (Glen, Crewman Meyer walking Deck 7: "her hair was off"): lou_0 - thin curly strands with the
## scalp showing through.
const RETIRED_HAIR := {"male": ["felix_0", "mason_slick_0"], "female": ["mystery_woman_0", "lara_croft_0", "kara_0", "ironside_0", "mystery_woman_1", "sorceress_0", "evelyn_0", "lou_0"]}


static func _hair_choices(sex: String, kit: Dictionary) -> Array:
	var hairs: Array = []
	for h in kit.get("hair", []):
		var nm := String(h["name"])
		if not (RETIRED_HAIR.get(sex, []) as Array).has(nm):
			hairs.append(nm)
	return hairs


static func _hair(inst: Node3D, sk: Skeleton3D, kit: Dictionary, look: Dictionary) -> void:
	var want := String(look.get("hair", ""))
	# someone already met with a retired style (pinned in a save) gets a fixed replacement of their own
	for sx in RETIRED_HAIR:
		if (RETIRED_HAIR[sx] as Array).has(want):
			var choices := _hair_choices(String(sx), kit)
			if not choices.is_empty():
				want = String(choices[CrewRoster._h(JSON.stringify(look.get("hair_tint", [])) + str(look.get("height", 1.0)), 31) % choices.size()])
	for h in kit.get("hair", []):
		if String(h["name"]) != want or not ResourceLoader.exists(String(h["file"])):
			continue
		var mesh := (load(String(h["file"])) as ArrayMesh).duplicate() as ArrayMesh
		var tex: Array = mesh.get_meta("tex", [])
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as StandardMaterial3D
			if mat == null:
				continue
			var nm := mat.duplicate() as StandardMaterial3D
			var spec: Dictionary = tex[s] if s < tex.size() else {}
			for slot in spec:
				if ResourceLoader.exists(String(spec[slot])):
					nm.set(slot, load(String(spec[slot])))
			mesh.surface_set_material(s, nm)
		var mi := MeshInstance3D.new()
		mi.name = "CrewHair"
		mi.mesh = mesh
		var skin: Skin = mesh.get_meta("skin", null)
		if skin != null:
			mi.skin = skin.duplicate() as Skin
			sk.add_child(mi)
			mi.skeleton = NodePath("..")
		elif mesh.has_meta("bone") and sk.find_bone(String(mesh.get_meta("bone"))) >= 0:
			# a rigid piece pinned to a bone
			var att := BoneAttachment3D.new()
			att.bone_name = String(mesh.get_meta("bone"))
			sk.add_child(att)
			att.add_child(mi)
			mi.transform = mesh.get_meta("rel", Transform3D())
		else:
			continue
		_tint_hair(mi, look)


static func _tint_hair(mi: MeshInstance3D, look: Dictionary) -> void:
	var t: Array = look.get("hair_tint", [1, 1, 1])
	var c := Color(float(t[0]), float(t[1]), float(t[2]))
	for s in mi.mesh.get_surface_count():
		var mat := mi.get_active_material(s) as StandardMaterial3D
		if mat == null:
			continue
		var nm := mat.duplicate() as StandardMaterial3D
		nm.albedo_color = Color(mat.albedo_color.r * c.r, mat.albedo_color.g * c.g, mat.albedo_color.b * c.b, mat.albedo_color.a)
		# REV 234: the same soft sheen as the main cast's hair (CharacterKit._soften_hair) - glossy crew
		# hair showed white glints under close lights (Glen: Kyle's stand-in in the transporter room)
		nm.roughness = maxf(nm.roughness, CharacterKit.HAIR_ROUGHNESS)
		nm.metallic_specular = minf(nm.metallic_specular, CharacterKit.HAIR_SPECULAR)
		# REV 368 (Glen: "ensign walker is going bald!"): see-through hair cards let the pale scalp show
		# where the strands thin out (from above most of all - the "pale parting" on some styles). A solid
		# under-layer: the same cards, cut out where the strands are reasonably dense (HAIR_FILL_CUT), a
		# shade darker (HAIR_FILL_SHADE), drawn with the opaque things - the soft hair is laid over it.
		if nm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS or nm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
			var fill := nm.duplicate() as StandardMaterial3D
			fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			fill.alpha_scissor_threshold = HAIR_FILL_CUT
			fill.albedo_color = Color(nm.albedo_color.r * HAIR_FILL_SHADE, nm.albedo_color.g * HAIR_FILL_SHADE, nm.albedo_color.b * HAIR_FILL_SHADE, 1.0)
			fill.next_pass = null
			nm.next_pass = fill
		mi.set_surface_override_material(s, nm)

const HAIR_FILL_CUT := 0.4        # strands at least this solid get the under-layer (lower = fuller, harder tips)
const HAIR_FILL_SHADE := 0.72     # the under-layer's colour against the hair's own


static func _kit(sex: String) -> Dictionary:
	if _kits.has(sex):
		return _kits[sex]
	var kit := {}
	if ResourceLoader.exists(KIT[sex]):
		var r: Resource = load(KIT[sex])
		if r != null and r.has_meta("kit"):
			kit = r.get_meta("kit")
	else:
		push_warning("CrewLooks: face kit %s missing - crew get the plain base face" % KIT[sex])
	_kits[sex] = kit
	return kit
