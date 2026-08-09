"""Remove o payload das texturas embutidas de um FBX binario 7.x.

Nao remove os nos Video/Texture -- so esvazia o blob Content. A arvore e as
conexoes ficam intactas, entao o risco de corromper o arquivo e minimo. O PZ
carrega a textura pelo campo `texture` do script de modelo, nunca de dentro
do FBX, entao o payload embutido e puro peso morto no download do mod.
"""
import struct

class Node:
    __slots__ = ("name","props","children")
    def __init__(s,name): s.name=name; s.props=[]; s.children=[]

def parse(data):
    assert data[:20]==b'Kaydara FBX Binary  ', "nao e FBX binario"
    ver = struct.unpack_from("<I", data, 23)[0]
    assert ver < 7500, "FBX 7.5+ usa offsets 64-bit; este script e 32-bit"
    pos = 27
    roots = []
    def rd(pos):
        end,np_,pl = struct.unpack_from("<III",data,pos); pos+=12
        nlen=data[pos]; pos+=1
        name=data[pos:pos+nlen]; pos+=nlen
        if end==0: return None,pos
        n=Node(name)
        for _ in range(np_):
            t=data[pos:pos+1]; pos+=1
            c=t.decode()
            if c in 'CB': n.props.append((c,data[pos:pos+1])); pos+=1
            elif c=='Y': n.props.append((c,data[pos:pos+2])); pos+=2
            elif c in 'IF': n.props.append((c,data[pos:pos+4])); pos+=4
            elif c in 'DL': n.props.append((c,data[pos:pos+8])); pos+=8
            elif c in 'fdlbic':
                al,en,cl=struct.unpack_from("<III",data,pos)
                blk=data[pos:pos+12+cl]; pos+=12+cl
                n.props.append((c,blk))
            elif c in 'SR':
                sl=struct.unpack_from("<I",data,pos)[0]
                blk=data[pos:pos+4+sl]; pos+=4+sl
                n.props.append((c,blk))
            else: raise ValueError("tipo "+c)
        while pos<end:
            ch,pos=rd(pos)
            if ch is None: break
            n.children.append(ch)
        return n,end
    while pos < len(data)-30:
        n,pos = rd(pos)
        if n is None: break
        roots.append(n)
    return ver, roots, data[pos:]

def size_of(n):
    plen = sum(1+len(b) for _,b in n.props)
    total = 12 + 1 + len(n.name) + plen
    if n.children:
        total += sum(size_of(c) for c in n.children) + 13
    return total

def write(n, out, offset):
    plen = sum(1+len(b) for _,b in n.props)
    end = offset + size_of(n)
    out.append(struct.pack("<III", end, len(n.props), plen))
    out.append(bytes([len(n.name)])); out.append(n.name)
    for t,b in n.props:
        out.append(t.encode()); out.append(b)
    if n.children:
        cur = offset + 12 + 1 + len(n.name) + plen
        for c in n.children:
            write(c, out, cur); cur += size_of(c)
        out.append(b'\x00'*13)
    return end

def strip(src, dst):
    data = open(src,'rb').read()
    ver, roots, tail = parse(data)
    removed = [0]
    def walk(n, parent_name=b''):
        if n.name==b'Content' and parent_name==b'Video':
            newp=[]
            for t,b in n.props:
                if t=='R':
                    sl=struct.unpack_from("<I",b,0)[0]
                    if sl>1000:
                        removed[0]+=sl
                        newp.append(('R', struct.pack("<I",0)))
                        continue
                newp.append((t,b))
            n.props=newp
        for c in n.children: walk(c, n.name)
    for r in roots: walk(r)
    out=[data[:27]]
    cur=27
    for r in roots:
        write(r,out,cur); cur+=size_of(r)
    out.append(b'\x00'*13)
    out.append(tail)
    blob=b''.join(out)
    open(dst,'wb').write(blob)
    return len(data), len(blob), removed[0]

if __name__=="__main__":
    import sys
    a,b,r = strip(sys.argv[1], sys.argv[2])
    print(f"origem {a/1048576:.1f} MB -> destino {b/1048576:.2f} MB  (removidos {r/1048576:.1f} MB de textura embutida)")
