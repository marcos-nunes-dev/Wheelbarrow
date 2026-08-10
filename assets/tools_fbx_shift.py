"""Desloca e gira a geometria de um FBX binario 7.x.

Por que isto existe: os modelos do PZ tem a origem no centro do mesh -- medi e
confirmei que o Log e o ToolBox_Ground vanilla tem a origem a 50% da altura --
e o engine assenta essa origem no nivel do chao, entao todo modelo afunda
metade da propria altura. Num tronco deitado, que e fino, isso e
imperceptivel; num carrinho de mao, que e alto, fica gritante.

O parametro `offset` do bloco `model` existe, mas a documentacao nao descreve
em que espaco ele opera e nenhum item vanilla o usa. Assar o deslocamento na
geometria e o caminho verificavel: da para reparsear o arquivo e conferir a
bounding box resultante, em vez de descobrir o resultado em tela.

Alem de assentar o modelo de chao, serve para produzir o modelo de MAO: os
modelos de mao do PZ nao tem bloco de offset -- o deslocamento em relacao ao
osso da mao esta assado na malha. Foi assim que o mod Carry Visible Items fez,
e e por isso que os arquivos dele tem sufixo _Hand.

A rotacao existe porque o modelo de mao nasceu apontando para baixo: o osso da
mao tem orientacao propria, diferente da do mundo, e o mesh precisa ser girado
para ficar de pe em relacao a ela.

Uso:
    python tools_fbx_shift.py entrada.fbx saida.fbx dx dy dz [rotX] [rotY] [rotZ]
"""
import math
import struct
import sys
import zlib

from tools_fbx_strip_embedded import parse, size_of, write


def shift(src, dst, dx, dy, dz, rx=0.0, ry=0.0, rz=0.0):
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
                    # Vertices vem como triplas planas x,y,z.
                    # Gira primeiro, em torno da origem, depois translada --
                    # inverter a ordem faria a rotacao arrastar o deslocamento.
                    ax, ay, az = (math.radians(v) for v in (rx, ry, rz))
                    for i in range(0, len(vals) - 2, 3):
                        x, y, z = vals[i], vals[i + 1], vals[i + 2]
                        if ax:
                            c, s = math.cos(ax), math.sin(ax)
                            y, z = y * c - z * s, y * s + z * c
                        if ay:
                            c, s = math.cos(ay), math.sin(ay)
                            x, z = x * c + z * s, -x * s + z * c
                        if az:
                            c, s = math.cos(az), math.sin(az)
                            x, y = x * c - y * s, x * s + y * c
                        vals[i] = x + dx
                        vals[i + 1] = y + dy
                        vals[i + 2] = z + dz
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
    dx, dy, dz = (float(v) for v in sys.argv[3:6])
    rot = [float(v) for v in sys.argv[6:9]] + [0.0, 0.0, 0.0]
    count = shift(sys.argv[1], sys.argv[2], dx, dy, dz, rot[0], rot[1], rot[2])
    print("%d vertices: giro (%.0f, %.0f, %.0f) e deslocamento (%.2f, %.2f, %.2f)"
          % (count, rot[0], rot[1], rot[2], dx, dy, dz))
