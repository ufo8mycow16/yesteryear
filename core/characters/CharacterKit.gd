extends RefCounted
class_name CharacterKit
## CharacterKit — stand-in people for every scene, built from one file.
##
## assets/models/characters/captains_kit.glb holds six rigged, low-poly figures
## side by side (no textures, no animations, flat-colour parts). This class
## pulls ONE figure out of that file, recolours its parts (uniform, trousers,
## hair, skin, boots), lowers its arms from the stiff A-pose, and hands back a
## ready-to-place Node3D. Use it anywhere a character is needed:
##
##   var guard := CharacterKit.make(CharacterKit.Body.DS9_DARK, {
##       "uniform": Color(0.2, 0.22, 0.2), "solid": true})
##   guard.position = Vector3(3, 0, 5)
##   CharacterKit.face_toward(guard, Vector3(0, 0, 0))
##   add_child(guard)
##
## Everything is a stand-in: when real character art exists, only make() needs
## to change. The figure stands about 1.8 m tall with its feet at y = 0 and
## faces +Z (the same way the other character models in this project do).

enum Body { TOS_GOLD, ENT_DARK, ENT_PALE, TNG_MID, TNG_PALE, DS9_DARK }

const KIT_PATH := "res://assets/models/characters/captains_kit.glb"
## The file's figures are about 5.76 units tall; this brings them to ~1.79 m.
const KIT_SCALE := 0.311

## Position of each body in the file, left to right (0 = leftmost).
const BODY_RANK := {
	Body.ENT_PALE: 0,
	Body.ENT_DARK: 1,
	Body.TOS_GOLD: 2,
	Body.TNG_MID: 3,
	Body.TNG_PALE: 4,
	Body.DS9_DARK: 5,
}

const UNIFORM_GOLD := Color(0.93, 0.72, 0.10)
const UNIFORM_BLUE := Color(0.20, 0.45, 0.88)
const UNIFORM_RED := Color(0.80, 0.12, 0.10)
const PANTS_BLACK := Color(0.05, 0.05, 0.06)
const BOOTS_BLACK := Color(0.03, 0.03, 0.03)
const SKIN_DEFAULT := Color(1.0, 0.92, 0.72)


## Builds one character. Options (all optional):
##   "uniform", "pants", "hair", "skin", "boots" : Color  - recolour that part
##   "height"  : float - 1.0 = normal; 0.95..1.05 for variety
##   "solid"   : bool  - default true (REV 147): nobody walks through them; false for none
##   "arms_down": bool - lower the arms (default true)
##   "ears"    : bool  - Vulcan/Romulan pointed ears
static func make(body: int, opts: Dictionary = {}) -> Node3D:
	var wrapper := Node3D.new()
	wrapper.name = "Character"
	wrapper.add_to_group("speakers")   # REV 97: the conversation camera finds people this way
	if not ResourceLoader.exists(KIT_PATH):
		push_warning("CharacterKit: %s not found - using a plain stand-in." % KIT_PATH)
		_add_fallback(wrapper)
		return _finish(wrapper, opts)
	var packed: PackedScene = load(KIT_PATH)
	var inst: Node3D = null
	if packed != null:
		inst = packed.instantiate() as Node3D
	if inst == null:
		push_warning("CharacterKit: couldn't load %s - using a plain stand-in." % KIT_PATH)
		_add_fallback(wrapper)
		return _finish(wrapper, opts)

	var groups := _figure_groups(inst)
	if groups.is_empty():
		push_warning("CharacterKit: no figures found in the kit file.")
		inst.free()
		_add_fallback(wrapper)
		return _finish(wrapper, opts)
	var rank := clampi(int(BODY_RANK.get(body, 0)), 0, groups.size() - 1)
	var keep: Node3D = groups[rank]
	for g in groups:
		if g != keep:
			g.get_parent().remove_child(g)
			g.free()

	var s := KIT_SCALE * float(opts.get("height", 1.0))
	inst.scale = Vector3.ONE * s
	inst.position.x = -keep.position.x * s   # centre the figure on the wrapper
	wrapper.add_child(inst)

	_recolor(inst, opts)
	_matte(inst)
	if bool(opts.get("arms_down", true)):
		_lower_arms(inst)
	if bool(opts.get("ears", false)):
		_add_ears(wrapper, inst, opts.get("skin", SKIN_DEFAULT))
	if bool(opts.get("tellarite", false)):
		_add_tellarite_features(wrapper, inst, opts.get("skin", SKIN_DEFAULT), opts.get("hair", Color(0.3, 0.3, 0.3)))
	# REV 86: walking (and Spock's bowling) in code; see CharacterAnimator.gd. It watches how fast the figure moves.
	var animator := CharacterAnimator.new()
	animator.name = "Animator"
	wrapper.add_child(animator)
	animator.setup(wrapper, inst)
	return _finish(wrapper, opts)


## The animator inside a figure made by make() / make_named(), or null.
static func animator_of(figure: Node) -> CharacterAnimator:
	if figure == null:
		return null
	return figure.find_child("Animator", true, false) as CharacterAnimator


## REV 97: finished character models. When the file is in the project, make_named() returns it
## (rigged, walking, with a face) instead of the stand-in; without it, the stand-in as before.
## Add Kirk, Spock ... here as their models are done. {"stand_in": true} forces the stand-in.
const REAL_MODELS := {
	"mccoy": "res://assets/models/characters/McCoy_daz.fbx",   # REV 124: straight from Daz (face controls)
	"spock": "res://assets/models/characters/Spock_daz.fbx",   # REV 145: Glen's Daz Spock (same export as McCoy)
	"kirk": "res://assets/models/characters/Kirk_daz.fbx",     # REV 146: Glen's Daz Kirk
	"uhura": "res://assets/models/characters/Uhura_daz.fbx",   # REV 153: Glen's Daz Uhura (Genesis 8 Female)
	"ullus": "res://assets/models/characters/Ullus_daz.fbx",   # REV 176: Glen's Daz Tellarite (reshaped Genesis 8 Male)
	"scott": "res://assets/models/characters/Scotty_daz.fbx",  # REV 177: Glen's Daz Scotty, Sulu and Chekov
	"scotty": "res://assets/models/characters/Scotty_daz.fbx",
	"sulu": "res://assets/models/characters/Sulu_daz.fbx",
	"chekov": "res://assets/models/characters/Chekov_daz.fbx",
	"chapel": "res://assets/models/characters/Chapel_daz.fbx",   # REV 284: Glen's Daz Chapel (her REV 280 face, Uhura's dress)
	# REV 577: Glen's Lt T'Nal (Genesis 8.1) + FE Short Undercut Hair; dressed REV 733 ('Tuvall Robe', blue and
	# gold - she's Vulcan Security). Trimmed by tools/crew/fbx_trim.py (see REVISIONS 577 / 733).
	"tuvall": "res://assets/models/characters/Tuvall_daz.fbx",
	# REV 755: Varel (Genesis 9, FN Enzo HD) in Valiant for M4 + blubeetle3's Romulan commander textures, Space Elf ears,
	# painted brows - docs/DAZ_EXPORT_SETTINGS.md "Vulcans and Romulans on Genesis 9". senior_specialist = his Episode 2 disguise.
	"varel": "res://assets/models/characters/Varel_daz.fbx",
	"senior_specialist": "res://assets/models/characters/Varel_daz.fbx",
	# REV 845: Kovek (Genesis 9, RKS Becca 9 - Glen's pick) in the same Valiant kit with the LIEUTENANT's colours
	# (RomulanTunic03 + the blue RomulanTabbard03), Angel Bob hair thinned for the game (tools/crew/thin_daz_hair.py,
	# 623k -> 71k polygons), Space Elf ears, painted brows. tech_specialist = her Episode 2 cover (uniform for now, as Varel).
	"kovek": "res://assets/models/characters/Kovek_daz.fbx",
	"tovan": "res://assets/models/characters/Tovan_daz.fbx",              # REV 847: Matt 9, bald export + library hair
	"archive_specialist": "res://assets/models/characters/Tovan_daz.fbx",
	"tech_specialist": "res://assets/models/characters/Kovek_daz.fbx",
	# REV 759: Glen's Daz Lieutenant Kyle (Genesis 8 Male, Face Transfer face, his Daz hair (EDSH_ pack) turned sandy blond,
	# Scotty's red uniform with the broken stripe painted out = a lieutenant's single braid). Hair shapes trimmed.
	"kyle": "res://assets/models/characters/Kyle_daz.fbx",
}
## REV 751: Genesis 9 characters (added to REAL_MODELS like any other, alongside the Genesis 8 cast). G9 is ONE
## unisex figure - woman or man is only its shape - so the walk, sitting and talking styles can't tell from
## the mesh names as they do for Genesis 8 Female. Every G9 woman goes in here ("female"); men can be left
## out (or "male"). Export and trim: docs/DAZ_EXPORT_SETTINGS.md "Genesis 9".
const REAL_MODEL_SEX := {
	"kovek": "female",            # REV 845
	"tech_specialist": "female",
}
## REV 284: dress pictures for Daz figures wearing Uhura's dress in another division's colour
## (same picture layout as the crew women's dresses; the lieutenant's sleeve braid included).
const REAL_MODEL_DRESS := {
	"chapel": "res://assets/models/crew/uniforms/dress_blue.png",
}
## REV 318: hair colours for Daz exports whose hair comes out white. Daz keeps this hair's colour in its
## Iray hair shader, which an FBX export leaves out (Chapel's says 0.94 grey on every layer), so it is set
## here per material (lower-case start of the material name -> colour; the rest of the hair keeps its own).
const REAL_MODEL_HAIR := {
	"chapel": {   # strawberry blonde (Glen) - deeper at the roots layer, lighter on top
		"dark_hair": Color(0.56, 0.36, 0.24),
		"medium_hair": Color(0.72, 0.50, 0.34),
		"light_hair": Color(0.86, 0.66, 0.48),
		"flyaways": Color(0.80, 0.60, 0.43),
		"hair_cap": Color(0.50, 0.33, 0.22),   # REV 356: darker - it showed as a bald, skin-coloured patch
	},
	# REV 845: Kovek's dark brown is in her hair pictures themselves - white = use them as they are (the FBX's own
	# colours are Daz's grey tints and would darken them nearly black)
	"kovek": {"haircap": Color(1, 1, 1), "hairflyaways": Color(1, 1, 1), "hair": Color(1, 1, 1)},
	# REV 847: Tovan's Mavick hair (added from the Daz library, its pictures white/grey) - Romulan black
	"tovan": {"haircap": Color(0.11, 0.09, 0.08), "hair": Color(0.075, 0.065, 0.06)},
	"archive_specialist": {"haircap": Color(0.11, 0.09, 0.08), "hair": Color(0.075, 0.065, 0.06)},
	"tech_specialist": {"haircap": Color(1, 1, 1), "hairflyaways": Color(1, 1, 1), "hair": Color(1, 1, 1)},
	# REV 759: Kyle's blond is in the hair pictures themselves (REAL_MODEL_HAIR_ALPHA) - white = use them as they are
	"kyle": {"hair_sg": Color(1, 1, 1), "stray_sg": Color(1, 1, 1), "scalps_sg": Color(1, 1, 1)},
	# REV 838 (Glen: "I did want it brown"); REV 841: the REV 838 brown came out ginger-copper - now a cool ash
	# mid-brown like T'Nal's store picture, and the shaved side's stubble darker. Her hair pictures are blond, so
	# these TINT them (picture x colour). Lower = darker; more red = warmer.
	"tuvall": {
		"hairf": Color(0.36, 0.31, 0.34),
		"hairc": Color(0.36, 0.31, 0.34),
		"hairex": Color(0.36, 0.31, 0.34),
		"cap": Color(0.36, 0.32, 0.36),
	},
}
## REV 351 (Glen: "a solid bit at the front where the hair joins the face, and a bit at the bottom that
## sticks out"): Daz hair whose FBX export carries only black-and-white OPACITY maps (no colour picture) -
## they were drawn as the hair's colour with no see-through at all, so the cap ended in a solid band at the
## hairline and the cards showed hard edges. These pictures (made from the maps embedded in the export: white
## with a little strand shading, alpha = the opacity map, 2048 px) replace them, per material name start as in
## REAL_MODEL_HAIR. Hair pieces listed under "hide" are not drawn - Chapel's flyaways map is a flat grey
## square with no cut-out, so its strands drew as solid flat cards sticking out.
const REAL_MODEL_HAIR_ALPHA := {
	"chapel": {
		"hair_cap": "res://assets/models/characters/hair/chapel_haircap_alpha.png",
		"dark_hair": "res://assets/models/characters/hair/chapel_haircards_alpha.png",
		"medium_hair": "res://assets/models/characters/hair/chapel_haircards_alpha.png",
		"light_hair": "res://assets/models/characters/hair/chapel_haircards_alpha.png",
		"hide": ["flyaways"],
	},
	# REV 579 (Glen: "the undercut is all grainy and a little bit of her hair fades in and out"): FE Short
	# Undercut Hair. HairF = the mohawk's strand cards (colour picture + the pack's opacity map, cut out by
	# the hair shader - blended cards swapped places as she moved). Cap = the undercut stubble, a faint
	# haze over the scalp: under "soft" it stays blended (cut out it would shave her bald), with the speckle
	# smoothed and the colour a darker root blonde so it reads as stubble shadow, drawn before the strands.
	# HairC / HairEx have no cut-out and came through 1% see-through (sorted every frame) - "solid" makes them opaque.
	"tuvall": {
		"hairf": "res://assets/models/characters/hair/tuvall_haircards_alpha.png",
		"cap": "res://assets/models/characters/hair/tuvall_haircap_alpha.png",
		"soft": ["cap"],
		"solid": ["hairc", "hairex"],
		# REV 582 (Glen: "really noisy when she moves"): the pack's strands are drawn for 4K stills - thinner than
		# a pixel in game, so they flickered in and out. The picture's strands are fattened and softened, and
		# these keep more of each strand with distance and widen the smoothed edge.
		"mip_boost": 0.6,
		"edge_soft": 0.5,
	},
	# REV 759: Kyle's hair came out of Daz as grey colour-variation maps + separate opacity maps (an FBX material
	# can't carry the second one). These = the maps tinted sandy blond (dark golden roots -> light ends), alpha =
	# the pack's opacity, 2048 px. Hair_SG / Stray_SG = the strand cards, Scalps_SG = the cap under them.
	# REV 845: Kovek's Angel Bob - its colour picture with the pack's Wave_Alpha3 cut-out baked into its alpha
	# (tools/crew/daz_cutouts.py), and the cap = its CapTR3 cut-out over the hair's own brown. "haircap" and
	# "hairflyaways" must stay BEFORE "hair" (names are matched by how they start, first match wins).
	"kovek": {
		"haircap": "res://assets/models/characters/hair/kovek_haircap_alpha.png",
		"hairflyaways": "res://assets/models/characters/hair/kovek_haircards_alpha.png",
		"hair": "res://assets/models/characters/hair/kovek_haircards_alpha.png",
	},
	"tech_specialist": {
		"haircap": "res://assets/models/characters/hair/kovek_haircap_alpha.png",
		"hairflyaways": "res://assets/models/characters/hair/kovek_haircards_alpha.png",
		"hair": "res://assets/models/characters/hair/kovek_haircards_alpha.png",
	},
	# REV 847: Tovan's Mavick hair, built into his model from the Daz library (tools/crew/g9_library_hair.py).
	# HairCap = the scalp cap, Hair1-4 = the strand cards; "haircap" before "hair".
	"tovan": {
		"haircap": "res://assets/models/characters/hair/tovan_haircap_alpha.png",
		"hair": "res://assets/models/characters/hair/tovan_haircards_alpha.png",
	},
	"archive_specialist": {
		"haircap": "res://assets/models/characters/hair/tovan_haircap_alpha.png",
		"hair": "res://assets/models/characters/hair/tovan_haircards_alpha.png",
	},
	"kyle": {
		"hair_sg": "res://assets/models/characters/hair/kyle_haircards_alpha.png",
		"stray_sg": "res://assets/models/characters/hair/kyle_haircards_alpha.png",
		"scalps_sg": "res://assets/models/characters/hair/kyle_haircap_alpha.png",
	},
}
## REV 579: the reserved keys in a REAL_MODEL_HAIR_ALPHA entry (everything else is a material-name start).
const HAIR_ALPHA_LISTS := ["hide", "soft", "solid", "mip_boost", "edge_soft"]
## REV 356: how solid a hair pixel must be to be drawn (0-1). Lower = fuller hair, higher = wispier.
const HAIR_ALPHA_CUT := 0.30
const HAIR_ALPHA_CUT_CAP := 0.50
## REV 358: hair shader settings (core/characters/hair_cards.gdshader). MIP_BOOST = how much more solid
## strands are kept per halving of size with distance (stops far strands popping in and out); ROUND_NORMALS
## = how much each card is lit as "facing out from the head" instead of its own way (0-1; stops the glitter).
const HAIR_SHADER := preload("res://core/characters/hair_cards.gdshader")
const HAIR_MIP_BOOST := 0.30
const HAIR_ROUND_NORMALS := 0.55
## REV 330 (Glen): Daz figures whose hair hangs over a high collar - the collar (low-poly Uhura dress) sat
## inside the hanging strands and showed through them (Chapel). Hair points in the collar band that lie
## inside the collar are pushed out to just beyond it, so the hair rests on the collar. Value = gap in cm.
const REAL_MODEL_HAIR_OVER_COLLAR := {
	"chapel": 1.5,   # REV 332: 0.5 -> 1.5 (the head and the chest move apart a little when she moves)
}
static var _hair_over_collar_cache := {}   # original hair mesh -> fixed mesh (done once per session)
## Pieces of a Daz export that should not be seen (lower-case parts of the mesh name).
const REAL_MODEL_REMOVE := {
	"chapel": ["pcube"],   # a stray 1.6 cm cube in her export
	# REV 734 (Glen: her brows didn't match - one a solid black hook, the other a grainy smudge): Daz's fibre
	# brows are strands thinner than a pixel, so they read differently from every angle. They're painted
	# into her face picture instead (REAL_MODEL_SKIN) and the strand mesh is not drawn.
	"tuvall": ["eyebrows"],
}
## REV 734: skin pictures that replace a Daz export's own (surface name, lower case -> picture). Tuvall's
## face = her T'Nal face with the upswept Vulcan brows painted in, traced from where Daz's fibre brows sit
## (each strand projected onto the head's own picture coordinates).
const REAL_MODEL_SKIN := {
	# REV 754: Varel (Genesis 9, FN Enzo HD) - his face with painted Romulan brows (tools/crew/paint_vulcan_brows.py)
	"varel": {"head": "res://assets/models/characters/skin/varel_head.jpg"},
	"senior_specialist": {"head": "res://assets/models/characters/skin/varel_head.jpg"},
	# REV 845: Kovek - RKS Becca's face (the browless one is the same picture) with painted Romulan brows (--thick 0.6)
	"kovek": {"head": "res://assets/models/characters/skin/kovek_head.jpg"},
	"tovan": {"head": "res://assets/models/characters/skin/tovan_head.jpg"},
	"archive_specialist": {"head": "res://assets/models/characters/skin/tovan_head.jpg"},
	"tech_specialist": {"head": "res://assets/models/characters/skin/kovek_head.jpg"},
	"tuvall": {
		"face": "res://assets/models/characters/skin/tuvall_face.jpg",
		"lips": "res://assets/models/characters/skin/tuvall_face.jpg",
		"ears": "res://assets/models/characters/skin/tuvall_face.jpg",
		"eyesocket": "res://assets/models/characters/skin/tuvall_face.jpg",
		# REV 736: her export wore Daz's plain default skin everywhere but the face - now T'Nal's own
		# (from Glen's C:\daz\lt tnal for genesis 81 female; the face also got painted eye makeup,
		# tools/textures/paint_eye_makeup.py over skin/_originals/tuvall_face_nomakeup.jpg)
		"head": "res://assets/models/characters/skin/tuvall_head.jpg",
		"body": "res://assets/models/characters/skin/tuvall_body.jpg",
		"arms": "res://assets/models/characters/skin/tuvall_arms.jpg",
		"fingernails": "res://assets/models/characters/skin/tuvall_arms.jpg",
		"legs": "res://assets/models/characters/skin/tuvall_legs.jpg",
		"toenails": "res://assets/models/characters/skin/tuvall_legs.jpg",
		"mouth": "res://assets/models/characters/skin/tuvall_mouth.jpg",
		"teeth": "res://assets/models/characters/skin/tuvall_mouth.jpg",
		# REV 842: T'Nal's own light hazel eyes (her kit's Eyes1 - the store picture's), not the export's grey ones
		"irises": "res://assets/models/characters/skin/tuvall_eyes.jpg",
		"pupils": "res://assets/models/characters/skin/tuvall_eyes.jpg",
		"sclera": "res://assets/models/characters/skin/tuvall_eyes.jpg",
	},
}
## REV 293: REAL_MODEL_FALLBACKS is gone - its only entry was the old McCoy_rigged.glb, which is no
## longer in the project. A missing Daz model now simply means the stand-in, as for everyone else.


## The three main characters, as recoloured stand-ins on the TOS-style body
## (shirt + separate trousers). who = "kirk" | "spock" | "mccoy".
static func make_named(who: String, extra: Dictionary = {}) -> Node3D:
	var key := who.to_lower()
	var real_path := String(REAL_MODELS.get(key, ""))
	if real_path != "" and not bool(extra.get("stand_in", false)) and ResourceLoader.exists(real_path):
		var real := CharacterFace.make_model(real_path, null, key)
		if real != null:
			if REAL_MODEL_SEX.has(key):
				real.set_meta("sex", String(REAL_MODEL_SEX[key]))   # REV 751: Genesis 9 (believed first by the animator)
			_real_model_dress(real, key)
			RomulanBelt.add_to(real, key)     # REV 839: the TOS Romulan belt, cut from their own clothes
			_fix_jewellery(real)
			_soften_hair(real)
			CharacterLook.apply(real, "scotty" if key == "scott" else key)      # REV 736 (crease maps REV 740): eyes, skin, hair, face light - last, after every swap
			real.add_to_group("speakers")
			real.set_meta("speaker_id", key)
			return _finish(real, extra)
	# REV 280: a story person with a hand-picked crew-kit face (Chapel) until a Daz model of their own.
	# REV 616: and every other story person on a crew body (CrewRoster.STORY_PEOPLE - Kyle, Giotto, Pell...):
	# Kyle playing in Episode 3 came out as the low-poly box stand-in (Glen)
	if (CrewLooks.FIXED_LOOKS.has(key) or CrewRoster.STORY_PEOPLE.has(key)) and not bool(extra.get("stand_in", false)):
		var crew := CrewLooks.make(key, extra)
		if crew != null:
			crew.set_meta("speaker_id", key)
			crew.set_meta("display_name", GameNames.character(key, key.capitalize()))
			return crew
	# REV 881: Vulcan women of the city on a real body - a crew-kit face with Vulcan ears in Glen's converted Daz gown
	if VULCAN_WOMEN.has(key) and not bool(extra.get("stand_in", false)):
		var vw := CrewLooks.make_vulcan_woman(key, VULCAN_WOMEN[key])
		if vw != null:
			vw.set_meta("sex", "female")
			vw.add_to_group("speakers")
			vw.set_meta("speaker_id", key)
			vw.set_meta("display_name", GameNames.character(key, key.capitalize()))
			return _finish(vw, extra)
	# REV 717 (Glen: "remove ALL copies of that block man, and swap them for real crew"): Starfleet roles with no person
	# of their own get a real crew member from the roster's people at that post
	if CREW_ROLES.has(key) and not bool(extra.get("stand_in", false)):
		var role_crew := crew_for_role(key, String(extra.get("salt", key)), extra)
		if role_crew != null:
			return role_crew
	var figure := _make_named_stand_in(key, extra)
	figure.set_meta("speaker_id", key)
	return figure


## REV 881: Vulcan women with a real body and gown (CrewLooks.make_vulcan_woman options). Add more here as the city's
## women get one; the stand-in below each name stays as the fallback.
const VULCAN_WOMEN := {
	"tvora": {"variant": "sand", "hair_tint": [0.72, 0.72, 0.74], "height": 0.93, "cape": true},   # an elder, sitting in the shade with her sehlat
}


## REV 717: Starfleet voices with no person of their own (the guards, the crewmen) -> where on the roster their body
## comes from. Aliens and civilians keep their stand-ins until they have models and clothes.
const CREW_ROLES := {"crewman": "security", "ent_security": "security", "security_officer": "security",
	"ent_specialist": "science_labs", "engineer": "engineering", "crewwoman": "security"}


## A roster crew member standing in for a role (a different one per salt - each guard his own face), still
## speaking as the role.
static func crew_for_role(role: String, salt: String, extra: Dictionary = {}) -> Node3D:
	var loc := String(CREW_ROLES.get(role, "security"))
	var people := CrewRoster.people_for(loc, 1, salt)
	if people.is_empty():
		people = CrewRoster.people_for("off_duty", 1, salt)
	if people.is_empty():
		return null
	var fig := CrewLooks.make(people[0], extra)
	if fig != null:
		fig.set_meta("speaker_id", role)
	return fig


static func _make_named_stand_in(who: String, extra: Dictionary) -> Node3D:
	var opts: Dictionary = {"pants": PANTS_BLACK, "boots": BOOTS_BLACK}
	match who.to_lower():
		"kirk":
			opts["uniform"] = UNIFORM_GOLD
			opts["hair"] = Color(0.42, 0.27, 0.12)
		"spock":
			opts["uniform"] = UNIFORM_BLUE
			opts["hair"] = Color(0.02, 0.02, 0.025)
			opts["ears"] = true
		"mccoy":
			opts["uniform"] = UNIFORM_BLUE
			opts["hair"] = Color(0.30, 0.18, 0.08)
			opts["height"] = 0.98
		# --- Episode 1 stand-ins (robes are just recoloured shirts) ---
		"tuvall":      # Commander Tuvall - a Vulcan WOMAN (Glen's GAMEPLAY LOCKED document); this stand-in
		               # figure is the old one until her Daz model exists
			opts["uniform"] = Color(0.40, 0.11, 0.09)
			opts["pants"] = Color(0.16, 0.08, 0.07)
			opts["hair"] = Color(0.02, 0.02, 0.025)
			opts["skin"] = Color(0.93, 0.85, 0.62)
			opts["ears"] = true
			opts["height"] = 1.03
		"vulcan_guard", "vulcan_security":
			opts["uniform"] = Color(0.42, 0.36, 0.28)
			opts["pants"] = Color(0.20, 0.17, 0.13)
			opts["hair"] = Color(0.02, 0.02, 0.025)
			opts["skin"] = Color(0.93, 0.85, 0.62)
			opts["ears"] = true
			opts["solid"] = true
		"vulcan_custodian", "vulcan_aide", "vulcan_receptionist":
			opts["uniform"] = Color(0.52, 0.45, 0.32)
			opts["pants"] = Color(0.25, 0.21, 0.15)
			opts["hair"] = Color(0.04, 0.04, 0.04)
			opts["skin"] = Color(0.93, 0.85, 0.62)
			opts["ears"] = true
			opts["solid"] = true
		"otari", "romulan":   # Romulan diplomatic staff (stand-in)
			opts["uniform"] = Color(0.22, 0.30, 0.30)
			opts["pants"] = Color(0.12, 0.15, 0.15)
			opts["hair"] = Color(0.03, 0.03, 0.035)
			opts["skin"] = Color(0.86, 0.82, 0.66)
			opts["ears"] = true
			opts["solid"] = true
		"uhura":       # Enterprise communications officer (stand-in)
			opts["uniform"] = Color(0.62, 0.14, 0.12)
			opts["pants"] = Color(0.10, 0.08, 0.08)
			opts["hair"] = Color(0.03, 0.03, 0.035)
			opts["skin"] = Color(0.50, 0.34, 0.26)
			opts["solid"] = true
		"council_leader":   # Vulcan High Council leader (stand-in)
			opts["uniform"] = Color(0.50, 0.30, 0.12)
			opts["pants"] = Color(0.30, 0.18, 0.08)
			opts["hair"] = Color(0.62, 0.62, 0.64)
			opts["skin"] = Color(0.90, 0.82, 0.60)
			opts["ears"] = true
			opts["solid"] = true
		"darev":       # Romulan security chief (stand-in)
			opts["uniform"] = Color(0.16, 0.20, 0.22)
			opts["pants"] = Color(0.10, 0.12, 0.13)
			opts["hair"] = Color(0.03, 0.03, 0.035)
			opts["skin"] = Color(0.84, 0.80, 0.64)
			opts["ears"] = true
			opts["solid"] = true
			opts["height"] = 1.02
		# --- Episode 2 stand-ins (REV 270) ---
		"chapel":      # Nurse Chapel (blue, blonde) until her Daz model
			opts["uniform"] = UNIFORM_BLUE
			opts["hair"] = Color(0.86, 0.74, 0.46)
			opts["solid"] = true
			opts["height"] = 0.95
		"ent_security", "security_officer", "crewman", "giotto":     # Enterprise security / crew (red; Giotto as a lead, REV 513)
			opts["uniform"] = UNIFORM_RED
			opts["hair"] = Color(0.20, 0.14, 0.08)
			opts["solid"] = true
		"ent_specialist", "romaine":   # Enterprise computer specialist = Lt Romaine (REV 593: red, as in TOS - Glen)
			opts["uniform"] = UNIFORM_RED
			opts["hair"] = Color(0.24, 0.16, 0.10)
			opts["solid"] = true
		"turian", "romulan_rep", "romulan_official", "varel", "kovek", "tovan":   # Romulans (Turian's memory; the three operatives)
			opts["uniform"] = Color(0.24, 0.26, 0.30)
			opts["pants"] = Color(0.12, 0.13, 0.15)
			opts["hair"] = Color(0.03, 0.03, 0.035)
			opts["skin"] = Color(0.86, 0.82, 0.66)
			opts["ears"] = true
			opts["solid"] = true
		"archivist":   # the faceless Vulcan archivist in the meld
			opts["uniform"] = Color(0.52, 0.45, 0.32)
			opts["pants"] = Color(0.25, 0.21, 0.15)
			opts["skin"] = Color(0.93, 0.85, 0.62)
			opts["solid"] = true
		"senior_specialist", "archive_specialist", "tech_specialist":   # the "Vulcan" computer team
			opts["uniform"] = Color(0.36, 0.36, 0.40)
			opts["pants"] = Color(0.18, 0.18, 0.21)
			opts["hair"] = Color(0.02, 0.02, 0.025)
			opts["skin"] = Color(0.92, 0.85, 0.66)
			opts["ears"] = true
			opts["solid"] = true
		# --- Shi'Kahr streets (REV 279) ---
		"vulcan_civilian", "vendor", "attendant", "stallkeeper":
			opts["uniform"] = Color(0.58, 0.48, 0.36)
			opts["pants"] = Color(0.30, 0.24, 0.18)
			opts["hair"] = Color(0.05, 0.04, 0.04)
			opts["skin"] = Color(0.93, 0.85, 0.62)
			opts["ears"] = true
			opts["solid"] = true
		# REV 856: Shi'Kahr's people (SHIKAHR_SCRIPT.md) - robes in the city's colours until they have Daz models
		"tmir":        # a young licensed guide: a guide's sash colour
			opts["uniform"] = Color(0.66, 0.36, 0.20)
			opts["pants"] = Color(0.32, 0.20, 0.14)
			opts["hair"] = Color(0.04, 0.03, 0.03)
			opts["skin"] = Color(0.93, 0.85, 0.66)
			opts["ears"] = true
			opts["solid"] = true
			opts["height"] = 0.95
		"selt":        # "a scholar's robe" - grey-blue, a little too new
			opts["uniform"] = Color(0.34, 0.38, 0.46)
			opts["pants"] = Color(0.20, 0.22, 0.27)
			opts["hair"] = Color(0.03, 0.03, 0.035)
			opts["skin"] = Color(0.88, 0.83, 0.66)
			opts["ears"] = true
			opts["solid"] = true
		"sorev", "kuvak", "hall_keeper":   # elders: undyed robes, grey hair
			opts["uniform"] = Color(0.62, 0.56, 0.46)
			opts["pants"] = Color(0.36, 0.30, 0.24)
			opts["hair"] = Color(0.66, 0.66, 0.68)
			opts["skin"] = Color(0.90, 0.82, 0.62)
			opts["ears"] = true
			opts["solid"] = true
		"tvora":
			opts["uniform"] = Color(0.44, 0.26, 0.30)
			opts["pants"] = Color(0.26, 0.16, 0.18)
			opts["hair"] = Color(0.72, 0.72, 0.74)
			opts["skin"] = Color(0.90, 0.82, 0.62)
			opts["ears"] = true
			opts["solid"] = true
			opts["height"] = 0.93
		"student_a", "student_b":
			opts["uniform"] = Color(0.30, 0.30, 0.34) if who.to_lower() == "student_a" else Color(0.48, 0.42, 0.30)
			opts["pants"] = Color(0.18, 0.18, 0.20)
			opts["hair"] = Color(0.03, 0.03, 0.035)
			opts["skin"] = Color(0.93, 0.85, 0.64)
			opts["ears"] = true
			opts["solid"] = true
			opts["height"] = 0.97
		"andorian", "andorian_b":
			opts["uniform"] = Color(0.30, 0.32, 0.46)
			opts["pants"] = Color(0.16, 0.16, 0.24)
			opts["hair"] = Color(0.92, 0.92, 0.95)
			opts["skin"] = Color(0.42, 0.58, 0.86)
			opts["solid"] = true
		"tellarite_visitor":
			opts["uniform"] = Color(0.42, 0.30, 0.20)
			opts["pants"] = Color(0.20, 0.15, 0.10)
			opts["hair"] = Color(0.35, 0.30, 0.28)
			opts["skin"] = Color(0.66, 0.52, 0.47)
			opts["tellarite"] = true
			opts["height"] = 0.94
		"romulan_staff":
			opts["uniform"] = Color(0.22, 0.30, 0.30)
			opts["pants"] = Color(0.12, 0.15, 0.15)
			opts["hair"] = Color(0.03, 0.03, 0.035)
			opts["skin"] = Color(0.86, 0.82, 0.66)
			opts["ears"] = true
			opts["solid"] = true
		# REV 860: the delegates' lounge (stand-ins until Glen has models)
		"grath":       # Ullus' deputy: younger, broader, louder
			opts["uniform"] = Color(0.46, 0.24, 0.16)
			opts["pants"] = Color(0.20, 0.12, 0.09)
			opts["hair"] = Color(0.30, 0.22, 0.18)
			opts["skin"] = Color(0.68, 0.52, 0.46)
			opts["tellarite"] = true
			opts["height"] = 0.95
		"tellarite_delegate":   # the rest of the Tellarite delegation (packing)
			opts["uniform"] = Color(0.36, 0.30, 0.18)
			opts["pants"] = Color(0.18, 0.14, 0.09)
			opts["hair"] = Color(0.34, 0.30, 0.26)
			opts["skin"] = Color(0.64, 0.50, 0.46)
			opts["tellarite"] = true
			opts["height"] = 0.93
		"sevek":       # the conference's protocol officer: very old, undyed robe
			opts["uniform"] = Color(0.56, 0.52, 0.44)
			opts["pants"] = Color(0.32, 0.29, 0.24)
			opts["hair"] = Color(0.80, 0.80, 0.82)
			opts["skin"] = Color(0.90, 0.83, 0.64)
			opts["ears"] = true
			opts["solid"] = true
			opts["height"] = 0.96
		"shras":       # Andoria's ambassador (TOS: Journey to Babel)
			opts["uniform"] = Color(0.24, 0.30, 0.52)
			opts["pants"] = Color(0.12, 0.14, 0.26)
			opts["hair"] = Color(0.94, 0.94, 0.97)
			opts["skin"] = Color(0.40, 0.56, 0.86)
			opts["solid"] = true
		"coridanite":  # a mild man with a lot of paperwork
			opts["uniform"] = Color(0.50, 0.44, 0.30)
			opts["pants"] = Color(0.26, 0.22, 0.15)
			opts["hair"] = Color(0.22, 0.16, 0.12)
			opts["skin"] = Color(0.84, 0.70, 0.58)
			opts["solid"] = true
		"rigelian":    # the Rigelian observer, asleep
			opts["uniform"] = Color(0.44, 0.22, 0.34)
			opts["pants"] = Color(0.22, 0.12, 0.18)
			opts["hair"] = Color(0.12, 0.10, 0.10)
			opts["skin"] = Color(0.86, 0.76, 0.70)
			opts["solid"] = true
		"sarek":       # REV 862: Ambassador Sarek - a dark ambassador's robe, black-grey hair (stand-in until Glen has a model)
			opts["uniform"] = Color(0.20, 0.17, 0.22)
			opts["pants"] = Color(0.12, 0.10, 0.13)
			opts["hair"] = Color(0.12, 0.12, 0.13)
			opts["skin"] = Color(0.90, 0.83, 0.64)
			opts["ears"] = true
			opts["solid"] = true
			opts["height"] = 1.02
		"tlani":       # REV 864: a Vulcan girl of eight or nine
			opts["uniform"] = Color(0.40, 0.46, 0.52)
			opts["pants"] = Color(0.24, 0.27, 0.30)
			opts["hair"] = Color(0.03, 0.03, 0.035)
			opts["skin"] = Color(0.93, 0.86, 0.66)
			opts["ears"] = true
			opts["solid"] = true
			opts["height"] = 0.66
		"hooded_clerk":   # a Vulcan clerk's admin robe, hood up (the room adds the hood) - never a face
			opts["uniform"] = Color(0.30, 0.27, 0.24)
			opts["pants"] = Color(0.18, 0.16, 0.14)
			opts["hair"] = Color(0.03, 0.03, 0.03)
			opts["skin"] = Color(0.90, 0.84, 0.66)
			opts["ears"] = true
		"ullus":       # Tellarite ambassador
			opts["uniform"] = Color(0.26, 0.34, 0.22)
			opts["pants"] = Color(0.14, 0.16, 0.11)
			opts["hair"] = Color(0.40, 0.38, 0.36)
			opts["skin"] = Color(0.66, 0.52, 0.47)
			opts["tellarite"] = true
			opts["height"] = 0.94
	for key in extra:
		opts[key] = extra[key]
	return make(Body.TOS_GOLD, opts)


## Turns a character to face a point (ignores height). Works on a character that
## is already positioned; call it after setting .position.
static func face_toward(character: Node3D, target: Vector3) -> void:
	var d := target - character.position
	if Vector2(d.x, d.z).length() < 0.001:
		return
	character.rotation.y = atan2(d.x, d.z)


## A handful of random Starfleet officers standing around a scene, for the
## crew who are off the ship / off duty. spots = [[position, look_at_point], ...]
## in the parent's own coordinates. The same seed always gives the same crowd.
## REV 180: when the crew face kit is in the project, these are real crew members from the roster
## (CrewRoster / CrewLooks): people aboard and off duty (location "off_duty"), or on watch at a post
## location from crew_posts.csv ("sickbay", "engineering", "bridge"...). Each keeps their name, face
## and uniform for the whole playthrough. Without the kit, the old recoloured stand-ins.
static func add_background_officers(parent: Node3D, spots: Array, seed_value: int = 1, location: String = "off_duty") -> Array[Node3D]:
	if ResourceLoader.exists(CrewLooks.KIT["male"]) and ResourceLoader.exists(CrewRoster.PEOPLE_CSV):
		return add_crew(parent, spots, location, "%s/%d" % [parent.name, seed_value])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var made: Array[Node3D] = []
	var uniforms: Array[Color] = [UNIFORM_GOLD, UNIFORM_BLUE, UNIFORM_RED]
	var bodies: Array = [Body.TOS_GOLD, Body.ENT_DARK, Body.ENT_PALE, Body.TNG_MID, Body.TNG_PALE, Body.DS9_DARK]
	for spot in spots:
		var pos: Vector3 = spot[0]
		var look: Vector3 = spot[1]
		var officer := make(int(bodies[rng.randi() % bodies.size()]), {
			"uniform": uniforms[rng.randi() % uniforms.size()],
			"pants": PANTS_BLACK,
			"boots": BOOTS_BLACK,
			"height": rng.randf_range(0.95, 1.05),
			"solid": true,
		})
		officer.position = pos
		face_toward(officer, look)
		parent.add_child(officer)
		made.append(officer)
	return made


## REV 180: roster crew at the spots ([position, point to face]); salt picks a different set per room.
static func add_crew(parent: Node3D, spots: Array, location: String, salt: String) -> Array[Node3D]:
	var made: Array[Node3D] = []
	var people := CrewRoster.people_for(location, spots.size(), salt)
	for i in people.size():
		var fig := CrewLooks.make(people[i])
		if fig == null:
			continue
		fig.position = spots[i][0]
		face_toward(fig, spots[i][1])
		parent.add_child(fig)
		made.append(fig)
	return made


# ---------------------------------------------------------------------------

## REV 147 (item 21): every figure is solid unless asked not to be ({"solid": false}). The blocker
## switches itself off when the figure is a player/follower body's model (that body has its own
## capsule) - see CharacterBlocker.
## REV 168 (CLAUDE.md item 5): earrings get their own gold. Uhura's hoops ("BRINCOS" in her Daz file)
## came out of the export sharing one texture sheet with her ear communicator, and their texture
## coordinates land on its green patch, so they rendered green. TOS Uhura wears gold hoops: any mesh
## named as earrings is given polished gold metal instead.
## REV 231: Daz hair was imported fairly glossy (roughness 0.6, normal specular), so close lights put
## white glints along the edges of the hair strands (Glen: Kirk on the transporter pads). Hair gets a
## soft, low sheen instead - done here at runtime, so no character has to be re-imported.
const HAIR_ROUGHNESS := 0.82
const HAIR_SPECULAR := 0.18
const HAIR_NAMES := ["hair", "cabelo", "cabello"]

static func _soften_hair(model: Node) -> void:
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nn := String(mi.name).to_lower()
		var is_hair := false
		for h in HAIR_NAMES:
			if nn.contains(h):
				is_hair = true
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var sm := mi.get_active_material(i) as StandardMaterial3D
			if sm == null:
				continue
			if is_hair or sm.resource_name.to_lower().contains("hair"):
				sm.roughness = maxf(sm.roughness, HAIR_ROUGHNESS)
				sm.metallic_specular = minf(sm.metallic_specular, HAIR_SPECULAR)


const EARRING_NAMES := ["brinco", "earring", "hoop"]
const EARRING_GOLD := Color(0.83, 0.64, 0.3)

static func _fix_jewellery(model: Node) -> void:
	var gold: StandardMaterial3D = null
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var low := String(mi.name).to_lower()
		var hit := false
		for k in EARRING_NAMES:
			if k in low:
				hit = true
				break
		if not hit:
			continue
		if gold == null:
			gold = StandardMaterial3D.new()
			gold.albedo_color = EARRING_GOLD
			gold.metallic = 1.0
			gold.roughness = 0.28
			gold.metallic_specular = 0.7
		(mi as MeshInstance3D).material_override = gold


## REV 358: the middle of the head in the hair mesh's own space, for the hair shader's rounded lighting.
## Measured from the hair pieces' own points (works whatever units the export uses): across = the middle of
## the hair, height = one head-radius (half the hair's width) below its top, so long hanging hair doesn't
## drag it down. Returns null if the mesh has no hair points (the shader then lights each card its own way).
static func _hair_head_centre(mi: MeshInstance3D, keys: Array):
	var mesh := mi.mesh
	var xf := mi.transform   # measured the right way up (as _hair_over_collar), answered in the mesh's own space
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var found := false
	for s in mesh.get_surface_count():
		var mat := mi.get_active_material(s)
		if mat == null:
			continue
		var low := mat.resource_name.to_lower()
		var is_hair := false
		for k in keys:
			if not HAIR_ALPHA_LISTS.has(k) and low.begins_with(String(k)):
				is_hair = true
				break
		if not is_hair:
			continue
		var pts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for p in pts:
			var q := xf * p
			lo = lo.min(q)
			hi = hi.max(q)
			found = true
	if not found:
		return null
	var size := hi - lo
	var radius := 0.5 * minf(size.x, size.z)
	return xf.affine_inverse() * Vector3((lo.x + hi.x) * 0.5, hi.y - radius, (lo.z + hi.z) * 0.5)


## REV 751: a Daz figure's own meshes (body, lashes, and on Genesis 9 its separate eyes, mouth and tear film),
## not clothing or hair: Genesis8Male/Female..., Genesis9..., G9EyebrowCards.
static func _is_daz_body_name(mesh_name: String) -> bool:
	var n := mesh_name.to_lower()
	return n.begins_with("genesis8") or n.begins_with("genesis9") or n.begins_with("g9eyebrow")


static func _real_model_dress(model: Node3D, key: String) -> void:
	var drop: Array = REAL_MODEL_REMOVE.get(key, [])
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(m.name).to_lower()
		for bad in drop:
			if n.contains(String(bad)):
				(m as MeshInstance3D).visible = false
	var skin: Dictionary = REAL_MODEL_SKIN.get(key, {})
	if not skin.is_empty():
		for m in model.find_children("*", "MeshInstance3D", true, false):
			var sk := m as MeshInstance3D
			if sk.mesh == null or not _is_daz_body_name(String(sk.name)):
				continue
			for s in sk.mesh.get_surface_count():
				var tp := String(skin.get(String(sk.mesh.surface_get_name(s)).to_lower(), ""))
				var smat := sk.get_active_material(s) as StandardMaterial3D
				if tp == "" or smat == null or not ResourceLoader.exists(tp):
					continue
				var nm := smat.duplicate() as StandardMaterial3D
				nm.albedo_texture = load(tp)
				sk.set_surface_override_material(s, nm)
	var hair: Dictionary = REAL_MODEL_HAIR.get(key, {})
	if REAL_MODEL_HAIR_OVER_COLLAR.has(key):     # REV 330: before the hair colours (it swaps the hair mesh)
		_hair_over_collar(model, float(REAL_MODEL_HAIR_OVER_COLLAR[key]), hair.keys())
	var hair_alpha: Dictionary = REAL_MODEL_HAIR_ALPHA.get(key, {})
	if not hair_alpha.is_empty():
		var hide: Array = hair_alpha.get("hide", [])
		var soft: Array = hair_alpha.get("soft", [])
		var solid: Array = hair_alpha.get("solid", [])
		var clear := StandardMaterial3D.new()
		clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		clear.albedo_color = Color(0, 0, 0, 0)
		var colours: Dictionary = REAL_MODEL_HAIR.get(key, {})
		for m in model.find_children("*", "MeshInstance3D", true, false):
			var am := m as MeshInstance3D
			if am.mesh == null:
				continue
			var centre = null   # REV 358: middle of the head, measured once per hair mesh (see _hair_head_centre)
			for s in am.mesh.get_surface_count():
				var amat := am.get_active_material(s) as StandardMaterial3D
				if amat == null:
					continue
				var low := amat.resource_name.to_lower()
				var hidden := false
				for h in hide:
					if low.begins_with(String(h)):
						am.set_surface_override_material(s, clear)
						hidden = true
						break
				if hidden:
					continue
				var made_solid := false
				for h in solid:
					if low == String(h) or low.begins_with(String(h) + "."):
						var om := amat.duplicate() as StandardMaterial3D
						om.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
						om.albedo_color.a = 1.0
						am.set_surface_override_material(s, om)
						made_solid = true
						break
				if made_solid:
					continue
				for k in hair_alpha:
					if HAIR_ALPHA_LISTS.has(k) or not low.begins_with(String(k)):
						continue
					var tp := String(hair_alpha[k])
					if ResourceLoader.exists(tp) and soft.has(k):
						# REV 579: a stubble haze straight on the scalp - one layer, so blending is safe as long
						# as it draws before the hair (render_priority) and never writes depth
						var cm := StandardMaterial3D.new()
						cm.albedo_texture = load(tp)
						# REV 842: the REAL_MODEL_HAIR colour goes on here - this new material has no name, so the colour pass
						# below never found it (Tuvall's shaved side stayed pale)
						var cc: Color = colours.get(String(k), Color.WHITE)
						cm.albedo_color = Color(cc.r, cc.g, cc.b, 1.0)
						cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						cm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
						cm.render_priority = -1
						cm.cull_mode = BaseMaterial3D.CULL_BACK
						cm.roughness = 0.85
						cm.metallic_specular = 0.2
						cm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
						am.set_surface_override_material(s, cm)
					elif ResourceLoader.exists(tp):
						# REV 356 (Glen: "now it flickers"): cut-out, not blended - blended layers of hair cards
						# can't be sorted front-to-back, so they swapped every frame.
						# REV 358 (Glen: "still flickering ... catches the light"): the hair shader keeps distant
						# strands solid and lights every card as part of one rounded volume - see hair_cards.gdshader.
						# It carries the hair colour itself (the REAL_MODEL_HAIR pass below only recolours
						# standard materials).
						if centre == null:
							centre = _hair_head_centre(am, hair_alpha.keys())
						var sm := ShaderMaterial.new()
						sm.shader = HAIR_SHADER
						sm.set_shader_parameter("strands", load(tp))
						var c: Color = colours.get(String(k), amat.albedo_color)
						sm.set_shader_parameter("hair_color", Color(c.r, c.g, c.b, 1.0))
						sm.set_shader_parameter("cutoff", HAIR_ALPHA_CUT_CAP if String(k) == "hair_cap" else HAIR_ALPHA_CUT)
						sm.set_shader_parameter("mip_boost", float(hair_alpha.get("mip_boost", HAIR_MIP_BOOST)))
						if hair_alpha.has("edge_soft"):
							sm.set_shader_parameter("edge_soft", float(hair_alpha["edge_soft"]))
						sm.set_shader_parameter("round_normals", HAIR_ROUND_NORMALS)
						sm.set_shader_parameter("use_round_normals", centre is Vector3)
						if centre is Vector3:
							sm.set_shader_parameter("head_centre", centre)
						am.set_surface_override_material(s, sm)
					break
	if not hair.is_empty():
		for m in model.find_children("*", "MeshInstance3D", true, false):
			var hm := m as MeshInstance3D
			if hm.mesh == null:
				continue
			for s in hm.mesh.get_surface_count():
				var hmat := hm.get_active_material(s) as StandardMaterial3D
				if hmat == null:
					continue
				var low := hmat.resource_name.to_lower()
				for k in hair:
					if low.begins_with(String(k)):
						var nm := hmat.duplicate() as StandardMaterial3D
						var c: Color = hair[k]
						nm.albedo_color = Color(c.r, c.g, c.b, hmat.albedo_color.a)
						hm.set_surface_override_material(s, nm)
						break
	var path := String(REAL_MODEL_DRESS.get(key, ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if _is_daz_body_name(String(mi.name)) or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as StandardMaterial3D
			if mat != null and mat.resource_name.begins_with("40_model"):   # Uhura's dress and boots (as CrewLooks._uniform)
				var nm := mat.duplicate() as StandardMaterial3D
				nm.albedo_texture = tex
				mi.set_surface_override_material(s, nm)


## REV 330: see REAL_MODEL_HAIR_OVER_COLLAR. The collar is measured from the dress itself (its surfaces
## sampled across every triangle, binned by height and angle round the neck), so no numbers depend on
## the figure's units or size. Hair = surfaces whose material starts with one of hair_keys (not the cap).
static func _hair_over_collar(model: Node3D, gap_cm: float, hair_keys: Array) -> void:
	var dress: MeshInstance3D = null
	var dress_surf := -1
	var dress_top := -INF
	var hairs: Array = []          # [mesh instance, [surface, ...]]
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var hs: Array = []
		for s in mi.mesh.get_surface_count():
			# REV 332: the importer puts the materials on the instance, not the mesh - REV 330 looked at the
			# mesh only, found no dress and silently did nothing
			var mat := mi.get_active_material(s)
			var low := mat.resource_name.to_lower() if mat != null else ""
			# REV 334: the boots wear the same "40_model" material as the dress - REV 330-332 took whichever came
			# first (the boots: a "collar" at knee height, so the hair was never touched). The one reaching
			# highest is the dress.
			if low.begins_with("40_model") and not _is_daz_body_name(String(mi.name)):
				var top := -INF
				for v in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					top = maxf(top, (mi.transform * v).y)
				if dress == null or top > dress_top:
					dress = mi
					dress_surf = s
					dress_top = top
			for k in hair_keys:
				if low.begins_with(String(k)) and not low.begins_with("hair_cap"):
					hs.append(s)
					break
		if not hs.is_empty():
			hairs.append([mi, hs])
	if dress == null or hairs.is_empty():
		return
	# --- the collar, in the dress's parent space (the skeleton: hair and dress share it)
	var da: Array = dress.mesh.surface_get_arrays(dress_surf)
	var dv: PackedVector3Array = da[Mesh.ARRAY_VERTEX]
	var di: PackedInt32Array = da[Mesh.ARRAY_INDEX]
	var dx := dress.transform
	var ymin := INF
	var ymax := -INF
	for v in dv:
		var p := dx * v
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
	var cm := (ymax - ymin) / 71.6              # the dress is 71.6 cm tall in Glen's export
	if cm <= 0.0:
		return
	var band_lo := ymax - 10.0 * cm             # the collar band: the dress's top 10 cm
	var cx := 0.0
	var zmin := INF
	var zmax := -INF
	var n_top := 0
	for v in dv:
		var p := dx * v
		if p.y > ymax - 2.0 * cm:
			cx += p.x
			n_top += 1
			zmin = minf(zmin, p.z)
			zmax = maxf(zmax, p.z)
	if n_top == 0:
		return
	var centre := Vector2(cx / n_top, (zmin + zmax) * 0.5)
	const ANG := 36
	const HB := 12
	var radius := PackedFloat32Array()
	radius.resize(ANG * HB)
	radius.fill(-1.0)
	var hstep := (ymax - band_lo) / HB
	for t in range(0, di.size(), 3):
		var a := dx * dv[di[t]]
		var b := dx * dv[di[t + 1]]
		var c := dx * dv[di[t + 2]]
		if maxf(a.y, maxf(b.y, c.y)) < band_lo:
			continue
		for i in 9:
			for j in 9 - i:
				var u := i / 8.0
				var w := j / 8.0
				var p := a * (1.0 - u - w) + b * u + c * w
				if p.y < band_lo or p.y > ymax:
					continue
				var d := Vector2(p.x, p.z) - centre
				var ai := int(floor((atan2(d.y, d.x) + PI) / TAU * ANG)) % ANG
				var hi := clampi(int((p.y - band_lo) / hstep), 0, HB - 1)
				radius[hi * ANG + ai] = maxf(radius[hi * ANG + ai], d.length())
	# fill gaps from the neighbouring angles
	for hi in HB:
		for pass_i in 3:
			for ai in ANG:
				if radius[hi * ANG + ai] < 0.0:
					var l := radius[hi * ANG + (ai + ANG - 1) % ANG]
					var r := radius[hi * ANG + (ai + 1) % ANG]
					radius[hi * ANG + ai] = maxf(l, r)
	var gap := gap_cm * cm
	var fade := 2.0 * cm                         # above the collar top the push fades out over 2 cm
	# --- the hair
	for h in hairs:
		var hm: MeshInstance3D = h[0]
		var src: Mesh = hm.mesh
		if _hair_over_collar_cache.has(src):
			hm.mesh = _hair_over_collar_cache[src]
			continue
		if not (src is ArrayMesh):
			continue
		var am := src as ArrayMesh
		var hx := hm.transform
		var hinv := hx.affine_inverse()
		var out := ArrayMesh.new()
		out.blend_shape_mode = am.blend_shape_mode
		for bs in am.get_blend_shape_count():
			out.add_blend_shape(am.get_blend_shape_name(bs))
		var moved := 0
		for s in am.get_surface_count():
			var arrays: Array = am.surface_get_arrays(s)
			var shapes: Array = am.surface_get_blend_shape_arrays(s)
			if (h[1] as Array).has(s):
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var offs := PackedVector3Array()
				offs.resize(verts.size())
				moved = 0
				for k in verts.size():
					var p := hx * verts[k]
					if p.y < band_lo or p.y > ymax + fade:
						continue
					var d := Vector2(p.x, p.z) - centre
					var ln := d.length()
					if ln < 0.0001:
						continue
					var ai := int(floor((atan2(d.y, d.x) + PI) / TAU * ANG)) % ANG
					var hi := clampi(int((p.y - band_lo) / hstep), 0, HB - 1)
					var want := radius[hi * ANG + ai]
					if want < 0.0:
						continue
					want += gap
					if ln >= want:
						continue
					var amount := 1.0
					if p.y > ymax:
						amount = 1.0 - (p.y - ymax) / fade
					var np := d / ln * lerpf(ln, want, amount)
					var off := hinv.basis * Vector3(np.x - d.x, 0.0, np.y - d.y)
					verts[k] += off
					offs[k] = off
					moved += 1
				arrays[Mesh.ARRAY_VERTEX] = verts
				# blend shapes hold whole positions: move them by the same amounts
				if moved > 0:
					for sh in shapes:
						var sv: PackedVector3Array = sh[Mesh.ARRAY_VERTEX]
						for k in mini(sv.size(), offs.size()):
							sv[k] += offs[k]
						sh[Mesh.ARRAY_VERTEX] = sv
			out.add_surface_from_arrays(am.surface_get_primitive_type(s), arrays, shapes, {}, am.surface_get_format(s))
			out.surface_set_material(s, am.surface_get_material(s))
			out.surface_set_name(s, am.surface_get_name(s))
		_hair_over_collar_cache[src] = out
		hm.mesh = out


static func _finish(wrapper: Node3D, opts: Dictionary) -> Node3D:
	if bool(opts.get("solid", true)):
		CharacterBlocker.attach(wrapper)
	return wrapper


static func _add_fallback(wrapper: Node3D) -> void:
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	mesh.mesh = capsule
	mesh.position.y = 0.88
	wrapper.add_child(mesh)


## Finds the six figures inside the loaded file: the highest node above each
## skeleton that holds only that one skeleton, sorted left to right.
static func _figure_groups(root: Node3D) -> Array[Node3D]:
	var groups: Array[Node3D] = []
	for sk in root.find_children("*", "Skeleton3D", true, false):
		var g: Node = sk
		while g.get_parent() != null and g.get_parent() != root and _skeleton_count(g.get_parent()) == 1:
			g = g.get_parent()
		var g3 := g as Node3D
		if g3 != null and not groups.has(g3):
			groups.append(g3)
	groups.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.x < b.position.x)
	return groups


static func _skeleton_count(node: Node) -> int:
	var n := node.find_children("*", "Skeleton3D", true, false).size()
	if node is Skeleton3D:
		n += 1
	return n


static func _role(material_name: String) -> String:
	var n := material_name.to_lower()
	if n.contains("skin"):
		return "skin"
	if n.contains("hair"):
		return "hair"
	if n.contains("boots"):
		return "boots"
	if n.contains("pants"):
		return "pants"
	if n.contains("shirt"):
		return "uniform"
	return ""


static func _recolor(root: Node, opts: Dictionary) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(s)
			var role := _role(src.resource_name if src != null else "")
			if role == "" or not opts.has(role):
				continue
			var mat: StandardMaterial3D = null
			if src is StandardMaterial3D:
				mat = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				mat = StandardMaterial3D.new()
			mat.albedo_color = opts[role]
			mi.set_surface_override_material(s, mat)


## The kit's materials only give a colour, so Godot fills in glTF's default of fully metallic. A fully metallic
## surface has no diffuse light at all and only shows reflections of its surroundings, which here are dark, so
## people came out solid black (except the one white material) whatever the room's light. Make them matte.
static func _matte(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.get_surface_override_material(s)
			if src == null:
				src = mi.mesh.surface_get_material(s)
			if not (src is StandardMaterial3D):
				continue
			var mat := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.metallic = 0.0
			mat.metallic_specular = 0.35
			mat.roughness = maxf(mat.roughness, 0.8)
			mi.set_surface_override_material(s, mat)


# ---- posing: bring the arms down from the A-pose --------------------------------

static func _lower_arms(root: Node) -> void:
	for sk in root.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		if skel == null:
			continue
		for side in ["l", "r"]:
			var upper := _find_bone(skel, "u_a_%s_" % side)
			var lower := _find_bone(skel, "l_a_%s_" % side)
			var hand := _find_bone(skel, "middlefingerbase_%s_" % side)
			_aim_bone(skel, upper, lower, 0.05, 0.05)
			_aim_bone(skel, lower, hand, 0.05, 0.35)


static func _find_bone(skel: Skeleton3D, prefix: String) -> int:
	for i in skel.get_bone_count():
		var n := skel.get_bone_name(i).to_lower().replace(".", "_")
		if n.begins_with(prefix):
			return i
	return -1


## Rotates `bone` so the line from it to `child` points (almost) straight down,
## leaning slightly outward (`out`) and forward (`fwd`).
static func _aim_bone(skel: Skeleton3D, bone: int, child: int, out: float, fwd: float) -> void:
	if bone < 0 or child < 0:
		return
	var rest := skel.get_bone_global_rest(bone)
	var child_rest := skel.get_bone_global_rest(child)
	var dir := (child_rest.origin - rest.origin)
	if dir.length() < 0.0001:
		return
	dir = dir.normalized()
	var lateral := 1.0 if dir.x >= 0.0 else -1.0
	var target := Vector3(lateral * out, -1.0, fwd).normalized()
	var delta := Quaternion(dir, target)
	var new_global := Basis(delta) * rest.basis
	var parent := skel.get_bone_parent(bone)
	var parent_basis := Basis.IDENTITY
	if parent >= 0:
		parent_basis = skel.get_bone_global_pose(parent).basis
	var local_basis := parent_basis.inverse() * new_global
	skel.set_bone_pose_rotation(bone, local_basis.get_rotation_quaternion())


# ---- pointed ears ----------------------------------------------------------------

static func _add_ears(wrapper: Node3D, inst: Node3D, skin: Color) -> void:
	# Where the head is, in the wrapper's own space (feet at y = 0).
	var head_pos := Vector3(0.0, 1.56, 0.08)
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		var skel := skels[0] as Skeleton3D
		var head := _find_bone(skel, "head_")
		if skel != null and head >= 0:
			var xf := Transform3D.IDENTITY
			var n: Node = skel
			while n != null and n != wrapper:
				var n3 := n as Node3D
				if n3 != null:
					xf = n3.transform * xf
				n = n.get_parent()
			var computed := xf * skel.get_bone_global_rest(head).origin
			# Only trust it if it lands somewhere sensible for a ~1.8 m figure.
			if computed.y > 1.3 and computed.y < 1.8 and absf(computed.x) < 0.25:
				head_pos = computed
	var mat := StandardMaterial3D.new()
	mat.albedo_color = skin
	var ear_mesh := CylinderMesh.new()
	ear_mesh.top_radius = 0.0
	ear_mesh.bottom_radius = 0.02
	ear_mesh.height = 0.09
	for side in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		ear.mesh = ear_mesh
		ear.material_override = mat
		ear.position = head_pos + Vector3(0.09 * side, 0.09, 0.0)
		ear.rotation_degrees = Vector3(0.0, 0.0, -18.0 * side)
		wrapper.add_child(ear)


# ---- Tellarite features: snout, brow ridge, beard ----------------------------------

static func _head_position(wrapper: Node3D, inst: Node3D) -> Vector3:
	var head_pos := Vector3(0.0, 1.56, 0.08)
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		var skel := skels[0] as Skeleton3D
		var head := _find_bone(skel, "head_")
		if skel != null and head >= 0:
			var xf := Transform3D.IDENTITY
			var n: Node = skel
			while n != null and n != wrapper:
				var n3 := n as Node3D
				if n3 != null:
					xf = n3.transform * xf
				n = n.get_parent()
			var computed := xf * skel.get_bone_global_rest(head).origin
			if computed.y > 1.3 and computed.y < 1.8 and absf(computed.x) < 0.25:
				head_pos = computed
	return head_pos


static func _add_tellarite_features(wrapper: Node3D, inst: Node3D, skin: Color, hair: Color) -> void:
	var head_pos := _head_position(wrapper, inst)
	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = skin.darkened(0.12)
	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = hair
	# snout
	var snout := MeshInstance3D.new()
	var snout_mesh := CylinderMesh.new()
	snout_mesh.top_radius = 0.035
	snout_mesh.bottom_radius = 0.055
	snout_mesh.height = 0.09
	snout.mesh = snout_mesh
	snout.material_override = skin_mat
	snout.position = head_pos + Vector3(0.0, 0.0, 0.13)
	snout.rotation_degrees = Vector3(70.0, 0.0, 0.0)
	wrapper.add_child(snout)
	# heavy brow
	var brow := MeshInstance3D.new()
	var brow_mesh := BoxMesh.new()
	brow_mesh.size = Vector3(0.17, 0.035, 0.05)
	brow.mesh = brow_mesh
	brow.material_override = skin_mat
	brow.position = head_pos + Vector3(0.0, 0.07, 0.10)
	wrapper.add_child(brow)
	# beard
	var beard := MeshInstance3D.new()
	var beard_mesh := BoxMesh.new()
	beard_mesh.size = Vector3(0.12, 0.13, 0.07)
	beard.mesh = beard_mesh
	beard.material_override = hair_mat
	beard.position = head_pos + Vector3(0.0, -0.13, 0.09)
	wrapper.add_child(beard)


## REV 116: the top of a figure's head above its origin, in its own (local) space, measured once
## from its visible meshes and remembered on the figure. Used by the conversation camera and the
## name tags for figures without a CharacterFace (the stand-ins).
static func head_top_local(fig: Node3D) -> float:
	if fig == null:
		return 1.8
	if fig.has_meta("_head_top"):
		return float(fig.get_meta("_head_top"))
	var inv := fig.global_transform.affine_inverse()
	# REV 124: from the skeleton when there is one - a skinned mesh's bounding box can be far bigger
	# than the figure (the kit's measured over 5 m tall, which sent everyone's eyes upward)
	for sk in fig.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		var top_bone := -INF
		var head_y := -INF
		var neck_y := -INF
		for i in skel.get_bone_count():
			# REV 132: from the rest pose (standing) - measured from the current pose, a figure that was
			# sitting or bending the first time it was asked kept that low height for good
			var y := (inv * (skel.global_transform * skel.get_bone_global_rest(i).origin)).y
			top_bone = maxf(top_bone, y)
			var bn := skel.get_bone_name(i).to_lower()
			if bn.begins_with("head") and not bn.contains("top") and not bn.contains("end"):
				head_y = maxf(head_y, y)
			elif bn.begins_with("neck"):
				neck_y = maxf(neck_y, y)
		if top_bone > 0.3:
			var top_s := top_bone * 1.06       # the highest bone (head / its end) sits just under the crown
			# a head bone sits at the base of the skull: the crown is well above it
			if head_y > 0.0 and neck_y > 0.0 and head_y > neck_y:
				top_s = maxf(top_s, head_y + (head_y - neck_y) * 1.6)
			fig.set_meta("_head_top", top_s)
			return top_s
	var best := -INF
	for m in fig.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var box := mi.get_aabb()
		var xf := inv * mi.global_transform
		for i in 8:
			best = maxf(best, (xf * box.get_endpoint(i)).y)
	var top := best if best > 0.3 and best < 3.0 else 1.8
	fig.set_meta("_head_top", top)
	return top


## REV 132: where a figure's eyes are right now - following the head as they sit, kneel, bend or turn
## (the conversation camera and name tags used the standing height, so a seated Pell was framed at
## his belt once he stood up). Figures with a face rig use the face's own eye point.
static func eyes_world(fig: Node3D) -> Vector3:
	if fig == null:
		return Vector3.ZERO
	var face := CharacterFace.face_of(fig)
	if face != null and face.ready_to_use:
		return face.focus_point("eyes")
	var top := head_top_local(fig)
	var info: Array = fig.get_meta("_head_bone", [])
	if info.is_empty():
		info = [null, -1, 0.0]
		var inv := fig.global_transform.affine_inverse()
		for sk in fig.find_children("*", "Skeleton3D", true, false):
			var skel := sk as Skeleton3D
			for i in skel.get_bone_count():
				var bn := skel.get_bone_name(i).to_lower()
				if bn.begins_with("head") and not bn.contains("top") and not bn.contains("end"):
					info = [skel, i, (inv * (skel.global_transform * skel.get_bone_global_rest(i).origin)).y]
					break
			if int(info[1]) >= 0:
				break
		fig.set_meta("_head_bone", info)
	var skel2 := info[0] as Skeleton3D
	if skel2 != null and is_instance_valid(skel2) and int(info[1]) >= 0:
		var head := skel2.global_transform * skel2.get_bone_global_pose(int(info[1])).origin
		if head.is_finite():
			return head + fig.global_transform.basis.y * (top * 0.935 - float(info[2]))
	return fig.global_transform * Vector3(0.0, top * 0.935, 0.0)


## The top of the head right now (for name tags).
static func crown_world(fig: Node3D) -> Vector3:
	return eyes_world(fig) + fig.global_transform.basis.y * (head_top_local(fig) * 0.075)
