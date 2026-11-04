"""Thelin for Yesteryear: an Andorian head on Spock's body.

Reads Glen's Andorian For G8M bundle (bryanthefigureman morph + Ryselle antennae) and Spock's Daz export,
and writes everything Thelin.gd needs into assets/models/characters/thelin/:
  head.bin    - per mesh group (body, lashes, hair, clothes): Spock's rest points that move (cm) and how far
                (cm), plus the normal change; the game matches them to the imported meshes by position.
  head.json   - the face bones' moves (cm), the antenna mesh's place in head.bin, and the group table.
  *.jpg/png   - the Andorian skin, eye and antenna pictures, sized for the game, normal maps from bumps.
The new head is the plain Genesis 8 Male face + the Andorian morph (as in the product picture), lined up
on Spock's head and faded out down the neck, so his body and shirt stay exactly as they are.

python3 tools/thelin/build_thelin.py <andorian bundle dir> <g8m_blank.fbx> <vulcan-fury tools/crew dir>
"""
import sys, os, json, gzip, struct
import numpy as np
from PIL import Image

BUNDLE, BLANK, CREW = sys.argv[1], sys.argv[2], sys.argv[3]
sys.path.insert(0, CREW)
import extract_face_shapes as efs
import fbx_bind_pose as fbp
import make_detail_maps as mdm

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(os.path.dirname(HERE))
SPOCK = os.path.join(PROJ, 'assets/models/characters/Spock_daz.fbx')
OUT = os.path.join(PROJ, 'assets/models/characters/thelin')
TEX = os.path.join(BUNDLE, 'Runtime/Textures/Andorian For G8M')
os.makedirs(OUT, exist_ok=True)


def load(p):
    b = open(p, 'rb').read()
    if b[:2] == b'\x1f\x8b':
        b = gzip.decompress(b)
    return json.loads(b)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# --- the meshes, in Daz's own point order -------------------------------------------------------------
def all_geoms(path):
    """name -> (points (N,3) cm, polygon vertex index list) for every non-shape geometry in the FBX."""
    out = {}
    for n, p, k in fbp.parse(path):
        if n != 'Objects':
            continue
        for nn, pp, kk in k:
            if nn != 'Geometry':
                continue
            name = pp[1].split(b'\x00')[0].decode('latin1')
            if '__' in name:      # blend shape targets
                continue
            d = {c[0]: c[1] for c in kk}
            if 'Vertices' in d:
                out[name] = (np.array(d['Vertices'][0], np.float64).reshape(-1, 3), np.array(d['PolygonVertexIndex'][0]))
    return out


sp_geoms = all_geoms(SPOCK)
bl_geoms = all_geoms(BLANK)
print('Spock meshes:', {k: len(v[0]) for k, v in sp_geoms.items()})
sp_body, sp_pvi = sp_geoms['Genesis8Male']
bl_body = bl_geoms['Genesis8Male'][0]
sp_lash = sp_geoms['Genesis8MaleEyelashes'][0]
bl_lash = bl_geoms['Genesis8MaleEyelashes'][0]

# --- the Andorian morph -------------------------------------------------------------------------------
mor = load(os.path.join(BUNDLE, 'data/DAZ 3D/Genesis 8/Male/Morphs/bryanthefigureman/Andorian For Genesis 8 Male/Andorian For G8M V1.dsf'))['modifier_library'][0]
dv = np.array(mor['morph']['deltas']['values'])
target = bl_body.copy()
target[dv[:, 0].astype(int)] += dv[:, 1:]
bone_d = {}
for fm in mor['formulas']:
    out = fm['output']
    ch = out.split('?')[1]
    if not ch.startswith('center_point/'):
        continue
    bone = out.split(':')[0]
    val = [x['val'] for x in fm['operations'] if 'val' in x][0]
    bone_d.setdefault(bone, np.zeros(3))['xyz'.index(ch[-1])] += val

# --- line the new head up on Spock's ------------------------------------------------------------------
sb = fbp.bind_positions(SPOCK)
bb = fbp.bind_positions(BLANK)
top = sp_body[:, 1].max()
core = sp_body[:, 1] > top - 22.0
shift = (target[core] - sp_body[core]).mean(0)
print('head shift (cm):', np.round(shift, 3))
y0 = sb['neckLower'][1]
y1 = sb['neckUpper'][1] + 2.0


def head_w(y):
    return smoothstep(y0, y1, y)


w = head_w(sp_body[:, 1])
body_off = w[:, None] * (target - shift - sp_body)

# normals before/after, for the shading
sp_n = efs.normals(sp_body, sp_pvi)
new_n = efs.normals(sp_body + body_off, sp_pvi)
body_dn = new_n - sp_n


def nearest_offsets(pts, k=6, reach=6.0):
    """Offsets for points off the body (lashes, hair, clothes): the inverse-distance mean of the nearest moved
    body points' offsets, fading out past <reach> cm from the skin."""
    hp = np.where(w > 0.0)[0]
    src = sp_body[hp]
    so = body_off[hp]
    out = np.zeros_like(pts)
    for s in range(0, len(pts), 2000):
        p = pts[s:s + 2000]
        d2 = ((p[:, None, :] - src[None, :, :]) ** 2).sum(-1)
        nn = np.argpartition(d2, k, axis=1)[:, :k]
        dd = np.sqrt(np.take_along_axis(d2, nn, 1))
        wt = 1.0 / np.maximum(dd, 0.05)
        o = (so[nn] * wt[:, :, None]).sum(1) / wt.sum(1)[:, None]
        fade = 1.0 - smoothstep(reach * 0.5, reach, dd.min(1))
        out[s:s + 2000] = o * fade[:, None]
    return out


# the lashes: the plain figure's lashes, lined up and faded in with the head
lw = head_w(sp_lash[:, 1])
lash_off = lw[:, None] * (bl_lash - shift - sp_lash)

groups = [('body', 'Genesis8Male', sp_body, body_off, body_dn), ('lash', 'Genesis8MaleEyelashes', sp_lash, lash_off, None)]
for name, (pts, _) in sp_geoms.items():
    if name in ('Genesis8Male', 'Genesis8MaleEyelashes'):
        continue
    off = nearest_offsets(pts)
    kind = 'hair' if 'CABELO' in name.upper() else 'cloth'
    groups.append((kind, name, pts, off, None))

# --- face bones ---------------------------------------------------------------------------------------
bones = {}
for b, p in sb.items():
    p = np.asarray(p, np.float64)
    if b == 'head' or p[1] < y1 or b not in bb:
        continue
    t = np.asarray(bb[b], np.float64) + bone_d.get(b, 0.0) - shift
    d = head_w(p[1]) * (t - p)
    if np.linalg.norm(d) > 0.02:
        bones[b] = [round(float(x), 4) for x in d]
print('face bones moved:', len(bones))

# --- antennae -----------------------------------------------------------------------------------------
adir = os.path.join(BUNDLE, 'data/Ryselle/Andorian_Antenna/G8M_Andorian_Antennas')
ant = load(os.path.join(adir, 'Andorian_Antenna_4450.dsf'))
ag = ant['geometry_library'][0]
AV = np.array(ag['vertices']['values'], np.float64)
# the product's own preset moves each antenna in and forward on the head (Andorian Antennas G8M.duf)
AV[AV[:, 0] > 0] += np.array([-1.6, 0.2, 2.3])
AV[AV[:, 0] < 0] += np.array([1.6, 0.2, 2.3])
AV += bone_d.get('head', 0.0) - shift
# sit the roots on the new scalp: the lowest ring of each antenna a few millimetres into the skin
new_body = sp_body + body_off
scalp = new_body[new_body[:, 1] > top - 8.0]
for side in (1, -1):
    m = AV[:, 0] * side > 0
    low = AV[m][AV[m][:, 1] < AV[m][:, 1].min() + 0.4]
    c = low.mean(0)
    near = scalp[np.argsort(((scalp[:, [0, 2]] - c[[0, 2]]) ** 2).sum(1))[:8]]
    drop = c[1] - (near[:, 1].mean() - 0.3)
    AV[m, 1] -= drop
    print('antenna side %d: root moved down %.2f cm' % (side, drop))
uvs = load(os.path.join(adir, 'UV Sets/Ryselle/Base/default.dsf'))['uv_set_library'][0]
UV = np.array(uvs['uvs']['values'], np.float64)
pvi = {}
for poly, vert, uvi in uvs['polygon_vertex_indices']:
    pvi[(poly, vert)] = uvi
verts, tris, seen = [], [], {}
for pi, pl in enumerate(ag['polylist']['values']):
    corners = []
    for v in pl[2:]:
        uvi = pvi.get((pi, v), v)
        key = (v, uvi)
        if key not in seen:
            seen[key] = len(verts)
            verts.append(key)
        corners.append(seen[key])
    for t in range(1, len(corners) - 1):
        tris.append((corners[0], corners[t], corners[t + 1]))
tris = np.array(tris, np.int64)
ap = AV[[v for v, _ in verts]]
auv = UV[[u for _, u in verts]]
auv[:, 1] = 1.0 - auv[:, 1]
f = ap[tris]
fn = np.cross(f[:, 1] - f[:, 0], f[:, 2] - f[:, 0])
an = np.zeros_like(ap)
for k in range(3):
    np.add.at(an, tris[:, k], fn)
# Daz winding is counter-clockwise; Godot's front faces are clockwise
tris = tris[:, [0, 2, 1]]
an /= np.maximum(np.linalg.norm(an, axis=1, keepdims=True), 1e-9)

# --- write head.bin ------------------------------------------------------------------------------------
blob = bytearray()
table = []
for kind, name, pts, off, dn in groups:
    mv = np.where(np.linalg.norm(off, axis=1) > 0.003)[0]
    if len(mv) == 0:
        continue
    rec = {'kind': kind, 'mesh': name, 'offset': len(blob), 'count': int(len(mv)), 'normals': dn is not None}
    arr = [pts[mv], off[mv]] + ([dn[mv]] if dn is not None else [])
    blob += np.concatenate(arr, axis=1).astype('<f4').tobytes()
    table.append(rec)
    print('%-6s %-28s %6d points move, most %.2f cm' % (kind, name, len(mv), np.linalg.norm(off[mv], axis=1).max()))
ant_rec = {'offset': len(blob), 'verts': len(ap), 'tris': int(len(tris))}
blob += np.concatenate([ap, an, auv], axis=1).astype('<f4').tobytes()
blob += tris.astype('<i4').tobytes()
open(os.path.join(OUT, 'head.bin'), 'wb').write(bytes(blob))

json.dump({'groups': table, 'bones_cm': bones, 'antennae': ant_rec, 'body_points': int(len(sp_body)), 'body_top_cm': float(top),
           'note': 'tools/thelin/build_thelin.py - Andorian For G8M on Spock_daz'},
          open(os.path.join(OUT, 'head.json'), 'w'), indent=1)

# --- pictures ------------------------------------------------------------------------------------------
def pic(src, dst, size, normal_from_bump=False):
    if normal_from_bump:
        mdm.bump_to_normal(os.path.join(TEX, src), size).save(os.path.join(OUT, dst), quality=95)
    else:
        im = Image.open(os.path.join(TEX, src)).convert('RGB').resize((size, size), Image.LANCZOS)
        im.save(os.path.join(OUT, dst), quality=92)
    print('picture', dst)


pic('Andorian Male Face Diff 2.jpg', 'face.jpg', 2048)
pic('Andorian Male Arms Diff 2.jpg', 'arms.jpg', 2048)
pic('Andorian Male Torso Diff 2.jpg', 'torso.jpg', 1024)
pic('Andorian Male Legs Diff 2.jpg', 'legs.jpg', 1024)
pic('Andorian Male Mouth Diff 1.jpg', 'mouth.jpg', 1024)
pic('Andorian Male Eyes Brown.jpg', 'eyes.jpg', 1024)
pic('Andorian Male Face Bump 1.jpg', 'face_normal.jpg', 2048, True)
pic('Andorian Male Arms Bump 1.jpg', 'arms_normal.jpg', 1024, True)
pic('Andorian Antenna Skin Diff.jpg', 'antenna.jpg', 1024)


print('done ->', OUT)
