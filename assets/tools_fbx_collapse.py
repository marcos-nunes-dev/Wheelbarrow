"""Colapsa todos os vertices de um FBX na origem, produzindo uma malha INVISIVEL.

PARA QUE SERVE:
o braco esquerdo do personagem nao entra na pose de segurar. A causa e o que
secondaryAnimMask realmente e: a mascara de quando o item esta na mao SECUNDARIA,
e nao a segunda metade de uma pose de duas maos. Com o mesmo objeto nas duas maos
o jogo aplica so uma.

O caminho que o jogo base usa para os dois bracos e `ReplaceInSecondHand = <item
de roupa> <mascara>`, e a mascara vem colada no item de roupa. O item de roupa
aponta para uma malha SKINNED -- rigging, que e o que nos fez escolher StaticModel
desde o inicio.

A saida: a malha desse item de roupa nao precisa ser vista. O carrinho ja aparece
pelo StaticModel; o segundo modelo existe so para carregar a mascara. Uma malha
com todos os vertices no mesmo ponto tem triangulos de area zero e nao desenha
NADA -- e continua sendo um arquivo FBX valido, com a mesma estrutura de nos que o
carregador espera. Sem rigging, sem Blender.

Se o pulo do gato nao funcionar, o modo de falha e barato: ou o item de roupa nao
carrega (e o braco fica como esta hoje), ou aparece um ponto unico de um pixel.
Nao ha caminho em que isso desenhe algo grande na tela.

Uso:
    python tools_fbx_collapse.py entrada.fbx saida.fbx
"""
import struct
import sys
import zlib

from tools_fbx_strip_embedded import parse, size_of, write


def collapse(src, dst):
    data = open(src, 'rb').read()
    _ver, roots, tail = parse(data)
    count = [0]

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
                    # Mantem a CONTAGEM de vertices e os indices de poligono
                    # intactos: mexer neles exigiria reescrever a topologia, e
                    # zerar as posicoes ja basta para nada ter area.
                    packed = struct.pack(fmt, *([0.0] * alen))
                    newprops.append((ptype, struct.pack("<III", alen, 0, len(packed)) + packed))
                    count[0] += alen // 3
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
    return count[0]


if __name__ == "__main__":
    print("%d vertices colapsados na origem" % collapse(sys.argv[1], sys.argv[2]))
