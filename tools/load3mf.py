import re, numpy as np
def load(path):
    s=open(path).read()
    objs={}
    for m in re.finditer(r'<object id="(\d+)"[^>]*>(.*?)</object>', s, re.S):
        oid, body = m.groups()
        if '<vertex ' in body:
            v=np.array(re.findall(r'<vertex x="([^"]+)" y="([^"]+)" z="([^"]+)"', body),float)
            t=np.array(re.findall(r'<triangle v1="(\d+)" v2="(\d+)" v3="(\d+)"', body),int)
            objs[oid]=('mesh',v,t)
        else:
            comps=[(c[0],np.array(c[1].split(),float)) for c in re.findall(r'<component objectid="(\d+)" transform="([^"]+)"', body)]
            objs[oid]=('comp',comps)
    return objs
def mat(a):
    M=np.eye(4); M[:3,:3]=a[:9].reshape(4,3)[:3].T if False else np.array([[a[0],a[3],a[6]],[a[1],a[4],a[7]],[a[2],a[5],a[8]]]); M[:3,3]=a[9:12]; return M
def xf(M,v): return v@M[:3,:3].T+M[:3,3]
