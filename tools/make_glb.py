import numpy as np, json, struct, sys
src, out = sys.argv[1], sys.argv[2]
d=np.load(src); V,T=d['V'].astype(np.float64),d['T'].astype(np.int64)
# remove exact duplicate triangles
st=np.sort(T,1); _,idx=np.unique(st,axis=0,return_index=True); T=T[np.sort(idx)]
# drop unused verts
used=np.unique(T); remap=-np.ones(len(V),np.int64); remap[used]=np.arange(len(used)); V=V[used]; T=remap[T]
# 3MF (mm, Z up) -> glTF (m, Y up); centre on the doorway, sink sill to ground
hole=np.load(src.replace('merged.npz','hole.npy'))
scale=2.7/(hole[3]-hole[2])  # metres per mm
cx=(hole[0]+hole[1])/2; cy=V[:,1].mean(); zbase=hole[2]
P=np.empty_like(V)
P[:,0]=(V[:,0]-cx)*scale
P[:,1]=(V[:,2]-zbase)*scale
P[:,2]=-(V[:,1]-cy)*scale
# area-weighted smooth normals
f=P[T]; fn=np.cross(f[:,1]-f[:,0],f[:,2]-f[:,0])
N=np.zeros_like(P)
for k in range(3): np.add.at(N,T[:,k],fn)
N/=np.maximum(np.linalg.norm(N,axis=1,keepdims=True),1e-12)
pos=P.astype(np.float32); nor=N.astype(np.float32); idx=T.astype(np.uint32).ravel()
b=pos.tobytes()+nor.tobytes()+idx.tobytes()
pad=(-len(b))%4; b+=b'\0'*pad
gl={"asset":{"version":"2.0","generator":"Yesteryear tidy-up"},
 "scene":0,"scenes":[{"nodes":[0]}],
 "nodes":[{"name":"GuardianOfForever-col","mesh":0}],
 "materials":[{"name":"guardian_stone","pbrMetallicRoughness":{"baseColorFactor":[0.47,0.44,0.41,1],"metallicFactor":0,"roughnessFactor":0.95}}],
 "meshes":[{"name":"GuardianOfForever","primitives":[{"attributes":{"POSITION":0,"NORMAL":1},"indices":2,"material":0}]}],
 "buffers":[{"byteLength":len(b)}],
 "bufferViews":[{"buffer":0,"byteOffset":0,"byteLength":pos.nbytes,"target":34962},
                {"buffer":0,"byteOffset":pos.nbytes,"byteLength":nor.nbytes,"target":34962},
                {"buffer":0,"byteOffset":pos.nbytes+nor.nbytes,"byteLength":idx.nbytes,"target":34963}],
 "accessors":[{"bufferView":0,"componentType":5126,"count":len(pos),"type":"VEC3","min":pos.min(0).tolist(),"max":pos.max(0).tolist()},
              {"bufferView":1,"componentType":5126,"count":len(nor),"type":"VEC3"},
              {"bufferView":2,"componentType":5125,"count":len(idx),"type":"SCALAR"}]}
j=json.dumps(gl,separators=(',',':')).encode(); j+=b' '*((-len(j))%4)
glb=struct.pack('<III',0x46546C67,2,12+8+len(j)+8+len(b))+struct.pack('<II',len(j),0x4E4F534A)+j+struct.pack('<II',len(b),0x004E4942)+b
open(out,'wb').write(glb)
print('tris',len(T),'verts',len(P),'size m',np.round(P.max(0)-P.min(0),2),'min',np.round(P.min(0),2),'max',np.round(P.max(0),2),'bytes',len(glb))
