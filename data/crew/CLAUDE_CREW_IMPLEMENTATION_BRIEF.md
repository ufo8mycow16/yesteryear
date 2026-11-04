# Vulcan Fury — Enterprise Personnel Data / Implementation Handoff
**Prepared for Claude by Glen and Tiffany · 14 October 2026**

## Deliverables
- `crew_posts.csv` — **430** permanent Constitution-class billets, exactly following the category counts in Glen's Franz Joseph personnel plate.
- `crew_people.csv` — **701** *fictional human candidates* (not the 430 currently serving), with complete names, male/female DAZ body selection, heritage hints, occupational field and rank band.
- UTF-8 CSV with a BOM for spreadsheet friendliness; standard comma-separated quoted CSV, one header row. The BOM should be stripped by the importer (Python `utf-8-sig` if relevant). All identifiers are permanent.

## IMPORTANT: schema additions we agreed to
`crew_posts.csv`:
`post_id,division,shirt_colour,department,rank,job_title,location,essential,canon`

`crew_people.csv`:
`person_id,first_name,surname,sex,heritage,species,career_field,rank_band,notes`

**New vs your original proposal:** `shirt_colour` on POSTS, `career_field` and `rank_band` on PEOPLE. `sex` was already in your original people schema; we explicitly need it for male/female DAZ base, uniform and hairstyle selection. We are deliberately telling you about all changes **before** implementation; these are the final intended CSV headers.

Allowed shirt colours: `gold`, `blue`, `red`. Derive from the CSV field rather than recalculating the shirt from department. TOS: command/helm/nav/ordnance gold, science/medical blue, engineering/security/communications/transporter red. Uniform rank braid and departmental insignia can remain separate assets.

`career_field` allowed values in this delivery: `command`, `helm_nav`, `ordnance`, `science`, `medical`, `engineering`, `transporter`, `communications`, `security`, `support`. **Do not** randomly assign a doctor to engineering or a transporter technician to security. Matching is by occupational eligibility, with a few explicit title-based exceptions described below.

`rank_band` allowed values: `junior`, `mid`, `senior`. This is an **eligibility / experience band**, NOT a literal Starfleet rank or promotion algorithm. Proposed: `junior` for crewman, specialist, petty officer, ensign, yeoman; `mid` for lieutenant junior grade/lieutenant and experienced NCOs; `senior` for lieutenant commander/commander and high-responsibility billets. To avoid impossible assignment, use a deterministic constrained matching algorithm, with a documented rank-band relaxation for underfilled fields, not random arbitrary job swaps. Canon rows bypass candidate matching.

`sex`: `male` or `female`; drives DAZ asset rig, hair, and uniform pool. Candidate pool has 455 male / 246 female (~35% female). It does **not** determine division, rank or job.

`heritage`: exactly `african`, `east_asian`, `south_asian`, `european`, `latin_american`, `middle_eastern`, `pacific`, `mixed`. This is a broad *visual preset hint*, not a strict biological definition, cultural stereotype or indication of citizenship. If corresponding morphs aren't available, default safely to `mixed` without breaking saves.

For this delivery the candidate pool retains an intentionally majority-European/Caucasian appearance mix: `european` 421, `east_asian` 59, `african` 48, `south_asian` 43, `latin_american` 38, `middle_eastern` 32, `pacific` 32, `mixed` 28 (701 total; European 60.1%). Glen wants the generated complement to retain the visibly majority-European/Caucasian character of the TOS Enterprise while still feeling international and diverse. These are game-generation weights, not a claim about future-Earth demographics.

`species`: all `human` for this release. Leave room for non-human assets later.

## Source and provenance
Glen provided the actual **Franz Joseph personnel-complement plate** as the authoritative billet-count reference. This is a 1970s licensed technical-manual design, not an on-screen staffing manifest; the billet titles and counts come from Glen's plate. Its totals are **55 command + 136 sciences + 239 engineering/other = 430**. The rank, location, essential flag and some modernized job titles in these CSVs are **our game-design interpretations**, not quotations of the plate. `canon` reservations are proposed on-screen-era continuity choices, some of which need Glen's final approval. Don't silently treat them as proven present on the same day in 2269.

The plate's engineering/other division includes transporter, communications and security. The game schema's `department` enum has no `transporter` or `ordnance` value, so transporter posts use `department=support` and ordnance uses `department=security`, but the precise `job_title` distinguishes them. `career_field` MUST be matched from the post's **job_title first** (`Transporter Specialist` => `transporter`, `Ordnance...` => `ordnance`), otherwise from `department`. `Command Yeoman`/`Science Yeoman`/`Operations Yeoman` may use `command`/`science`/`support` pools respectively.

## Exact billet counts
| Category | Count |
|---|---:|
| Captain | 1 |
| Executive Officer | 1 |
| Helmsman | 6 |
| Command Yeoman | 4 |
| Chief Navigator | 1 |
| Navigation Officer | 3 |
| Navigator | 6 |
| Ordnance Officer | 3 |
| Ordnance Specialist | 30 |
| Science Officer | 1 |
| Assistant Science Officer | 1 |
| Scientist | 4 |
| Laboratory Technician | 72 |
| Science Yeoman | 2 |
| Chief Surgeon | 1 |
| Doctor | 3 |
| Head Nurse | 1 |
| Nurse | 21 |
| Medical Technician | 30 |
| Chief Engineer | 1 |
| Assistant Chief Engineer | 1 |
| Engineering Officer | 4 |
| Engineering Specialist | 93 |
| Transporter Specialist | 33 |
| Operations Yeoman | 2 |
| Chief of Communications | 1 |
| Communications Officer | 5 |
| Communications Specialist | 9 |
| Chief of Security | 1 |
| Security Officer | 5 |
| Security Specialist | 84 |
| **Total** | **430** |

## Canon reserved posts — APPROVED DECISIONS (14 billets, 13 unique named people)
The `canon` field now reserves **14 billets**: Kirk, Sulu, Chekov, Spock (two billets), McCoy, M'Benga, Chapel, Scott, DeSalle, Kyle, Uhura, Palmer and Dickerson.

1. **Dickerson:** `SEC-001` Chief of Security is assigned `dickerson`. `SEC-002` Security Officer is now open for procedural staffing. This is **our chosen 2269 game continuity**, not proof that the original series definitively established Dickerson as permanent chief. The `rank` on `SEC-001` is the billet's Franz Joseph minimum (`lt_commander`), NOT an assertion about Dickerson's on-screen rank; if displaying his canonical rank, use a character-specific override after verification.
2. **Spock:** `CMD-002` Executive Officer and `SCI-001` Chief Science Officer both use `canon=spock`. These are **two duties held by one person**. Spawn only one Spock, one identity, one shore-leave status, one face and one save-state record. Two posts do not imply two NPCs.
3. **430 people vs 430 billets:** With dual-duty Spock, filling all 430 billets yields **429 distinct people**. To preserve the intended **430-person complement**, choose **one additional qualified relief/floating crew member** from the remaining candidate pool who is on the roster but not assigned to a permanent Franz Joseph billet. Give that member a stable supplemental assignment ID (e.g. `RELIEF-001`) in generated save state, **not** a 431st row in `crew_posts.csv`. Their career/rank and on/off-ship state must still be coherent. This is a deliberate exception and should be visible in code and QA.
4. **Other continuity choices:** Chekov as Chief Navigator and DeSalle as Assistant Chief Engineer are accepted game-continuity assignments. Kyle occupies a Transporter Specialist billet; use a named-character rank override if appropriate.
5. **Matching:** Added **15 junior transporter, 20 junior engineering, 15 junior security, and 1 mid helm/navigation** candidates. This eliminates the reported junior-security and mid-helm shortages and gives these pools more variety. Keep the **documented, deterministic upward-experience fallback** for any remaining exact-band mismatch; never silently swap careers. Don't promise every billet can be filled without testing the complete constrained matching.

## Procedural assignment and persistence
- Roll a `crew_seed` once at New Game and save it. Deterministically choose a **430-person actual complement** from 701 candidates **plus fixed canon people** (i.e., procedural picks fill only non-canon slots). Dual-duty Spock is approved; include one additional unposted relief member to reach 430 distinct people.
- Permanent `post_id` and `person_id`; derive assignment/appearance from stable IDs and seed, NEVER list row order. New Game may have different crew; same saved game must remain identical.
- Each procedural candidate's `career_field` restricts plausible billets; `rank_band` prevents junior personnel from receiving senior jobs without an explicit fallback. Candidate identities are complete first-name/surname combinations, never cross-mix names.
- On first sight, **pin** appearance/morph/hair/uniform decisions in the save so later asset additions don't change a previously seen person's face.
- Make a per-person shore-leave state derived once from seed, persisted/overridden for story events. Roughly **2/3 of the 430 are on Vulcan shore leave (~287)** and **1/3 aboard (~143)**; watch-standing essential posts should remain staffed. Note `essential=yes` currently marks more posts than may fit a 143-person shipboard target; treat it as **priority/required watch coverage**, not literally every such billet must be aboard simultaneously. If needed, propose a revised `duty_priority` column and let Glen approve it before changing CSVs.
- A shore-leave crew member can appear **on Vulcan**, and must be the same persistent identity/appearance if seen aboard later. Do not spawn the same person in two places at once.
- Most of the 430 should **never instantiate visually**. Glen expects only ~20–30 visible incidental crew NPCs across an ordinary playthrough, depending on accessible decks and Vulcan locations. This is a world population system, not a mandate to spawn 430 actors or 143 actors on accessible ship decks.
- Reuse existing `AmbientCrewAgent` walking/idle systems and existing Mixamo retargeted animations where appropriate. Do not overwrite established story actors or investigation NPCs.

## Appearance / asset inputs pending
Glen plans to export clean male and female DAZ bases with facial morphs, plus several hairstyles for each sex, and suitable TOS uniform meshes/textures. Avoid assuming female uniforms are available in all three colours yet. Hair/face generation must remain within modest believable morph limits. Rank, job and division should be readable in examine/nameplate where appropriate. The `shirt_colour` value drives uniform selection. No face sliders are encoded in these CSVs.

## Data QA
- Assert 430 unique post IDs and 701 unique candidate IDs and names.
- Assert exactly 55/136/239 posts by division and exact category counts above.
- Validate every enum against the schema; reject unknown columns only after explicitly supporting these extensions.
- Assert canon IDs are unique except for the explicitly approved Spock `CMD-002`/`SCI-001` dual assignment.
- Assert **430 distinct selected people** including the one relief/floating member; 430 permanent posts are filled but Spock occupies two. No duplicate identities except the approved Spock dual-duty mapping.
- Assert that each non-canon billet has a qualified candidate or a reported, deterministic relaxation; don't silently put a surgeon on a security post.
- Stable save/load, seed determinism, different New Game results, pinned face stability, shore leave placement, and no duplicate simultaneous appearances.

## Final creative authority
Glen and Tiffany handle story, character/continuity choices and asset research. Claude handles importer, constrained crew selection, persistent state, rendering, animation integration and technical validation. Please flag any assumptions or impossible constraints before implementation, rather than rewriting the story or the CSV semantics without telling us.
