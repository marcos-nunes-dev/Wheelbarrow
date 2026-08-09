"""Desloca a geometria de um FBX binario 7.x no eixo Y (vertical).

Por que isto existe: os modelos do PZ tem a origem no centro do mesh -- medi e
confirmei que o Log e o ToolBox_Ground vanilla tem a origem a 50% da altura --
e o engine assenta essa origem no nivel do chao, entao todo modelo afunda
metade da propria altura. Num tronco deitado, que e fino, isso e
imperceptivel; num carrinho de mao, que e alto, fica gritante.

O parametro `offset` do bloco `model` existe, mas a documentacao nao descreve
em que espaco ele opera e nenhum item vanilla o usa. Assar o deslocamento na
geometria e o caminho verificavel: da para reparsear o arquivo e conferir a
bounding box resultante, em vez de descobrir o resultado em tela.

Uso:
    python tools_fbx_shift_y.py entrada.fbx saida.fbx 0.380
"""
import struct
import sys
import zlib

from tools_fbx_strip_embedded import parse, size_of, write


def shift_y(src, dst, dy):
    data = open(src, 'rb').read()
    ver, roots, tail = parse(data)
    moved = [0]

    def walk(node):
        if node.name == b'Vertices':
            newprops = []
            for ptype, blob in node.props:
                if ptype in 'df':
                    alen, enc, clen = struct.unpack_from("<III", blob, 0)
                    raw = blob[12:12 + clen]
                    if enc == 1:
                        raw = zlib.decompress(raw)
                    fmt = "<%d%s" % (alen, ptype)
                    vals = list(struct.unpack(fmt, raw))
                    # Vertices vem como triplas planas x,y,z -- so o Y muda.
                    for i in range(1, len(vals), 3):
                        vals[i] += dy
                    packed = struct.pack(fmt, *vals)
                    # Regravado sem compressao (enc=0). O serializer recalcula
                    # todos os EndOffset a partir dos tamanhos reais, entao
                    # mudar o comprimento aqui e seguro.
                    newprops.append((ptype, struct.pack("<III", alen, 0, len(packed)) + packed))
                    moved[0] += alen // 3
                    continue
                newprops.append((ptype, blob))
            node.props = newprops
        for child in node.children:
            walk(child)

    for root in roots:
        walk(root)

    out = [data[:27]]
    cursor = 27
    for root in roots:
        write(root, out, cursor)
        cursor += size_of(root)
    out.append(b'\x00' * 13)
    out.append(tail)
    open(dst, 'wb').write(b''.join(out))
    return moved[0]


if __name__ == "__main__":
    count = shift_y(sys.argv[1], sys.argv[2], float(sys.argv[3]))
    print("%d vertices deslocados em Y por %s" % (count, sys.argv[3]))
