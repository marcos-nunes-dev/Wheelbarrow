"""Constroi os dois modelos do carrinho a partir de UMA fonte imutavel.

POR QUE UM CONSTRUTOR EM VEZ DE COMANDOS SOLTOS:

Antes, o modelo de mao era gerado a partir do modelo de CHAO, e o de chao era
editado no lugar. Ou seja, cada geracao partia do resultado da anterior: rodar a
mesma ferramenta duas vezes produzia coisas diferentes, e nao havia como voltar
ao ponto de partida sem o git. Aqui existe uma fonte -- assets/source/ -- e os
dois modelos sao derivados dela toda vez.

O QUE CADA UM RECEBE:

    chao   sombra de contato assada na malha, e nada mais
    mao    giro 270 0 0 e deslocamento (0.31, 0.90, 0.56), sem sombra

A sombra so entra no de chao porque ela e um quad deitado no plano do chao. No
modelo de mao ele acompanharia o carrinho no ar, virando uma placa escura
flutuando ao lado do personagem.

A SOMBRA, e por que ela precisa existir na malha: o engine nao tem sombra para
item. shadowExtents e shadowOffset existem so em script de VEICULO; item e model
nao tem campo nenhum, e das 568 chaves de TilePropertyKey nenhuma trata sombra.
No PZ, objeto do mundo que tem sombra tem ela PINTADA no sprite. Como o carrinho
renderiza por modelo 3D, a unica via equivalente e um quad no chao com textura
que desvanece nas bordas.

Isso depende de o shader de item respeitar alpha, e ele respeita -- medido nas
texturas do jogo base: ChristmasTree_Branch.png vai de alpha 0 a 255 com milhares
de pixels intermediarios, e BowlWater.png e semitransparente. Nao e suposicao.

A TEXTURA DOBRA DE LARGURA, nao de altura: a metade esquerda e a original e a
direita recebe a sombra, e os UVs existentes sao comprimidos com u' = u / 2. Em
LARGURA porque a orientacao de U e a mesma em toda convencao, enquanto V pode
estar invertido entre o FBX e o carregador do jogo -- comprimir em V exigiria
saber de que lado a textura e lida, e errar significaria a textura inteira de
cabeca para baixo.

Uso:
    python tools_build_models.py
"""
import math
import os
import struct
import zlib

from tools_fbx_shift import shift
from tools_fbx_strip_embedded import parse, size_of, write

SOURCE = "source/Wheelbarrow_raw.fbx"
SOURCE_TEXTURE = "source/Wheelbarrow_raw.png"
OUT_MODELS = "../Contents/mods/MNWheelbarrow/common/media/models_X/WorldItems"
# UMA TEXTURA POR MODELO, com o mesmo conteudo. Parece desperdicio de 300 KB e
# nao e: as duas nascem da mesma funcao, mas ter arquivos separados permite
# apontar o modelo de mao de volta para uma versao SEM alpha sem tocar no de
# chao. Isso importa porque ja aconteceu de personagem e veiculos sumirem da tela
# com alpha no passe de modelo, e a reversao precisa ser de uma linha.
OUT_TEXTURE_HAND = "../Contents/mods/MNWheelbarrow/common/media/textures/WorldItems/Wheelbarrow_Hand.png"
OUT_TEXTURE_GROUND = "../Contents/mods/MNWheelbarrow/common/media/textures/WorldItems/Wheelbarrow_Ground.png"

# Pose da mao, medida em jogo. Ver o cabecalho de models_wheelbarrow.txt.
HAND_ROTATION = (270, 0, 0)
HAND_OFFSET = (0.31, 0.90, 0.56)

# A sombra cobre a pegada do carrinho com uma folga. Em unidades de malha.
SHADOW_MARGIN = 0.12
# Altura acima de y=0. Zero exato briga com o piso pelo mesmo pixel de
# profundidade e produz cintilacao; um valor pequeno resolve sem ser visivel.
SHADOW_LIFT = 0.004
# Fracao do raio que fica com alpha cheio antes de a borda comecar a desmanchar.
SHADOW_CORE = 0.55
SHADOW_ALPHA = 170


# --------------------------------------------------------------------------
# leitura e escrita de arrays do FBX


def _decode(blob, ptype):
    alen, enc, clen = struct.unpack_from("<III", blob, 0)
    raw = blob[12:12 + clen]
    if enc == 1:
        raw = zlib.decompress(raw)
    return list(struct.unpack("<%d%s" % (alen, ptype), raw))


def _encode(values, ptype):
    packed = struct.pack("<%d%s" % (len(values), ptype), *values)
    return struct.pack("<III", len(values), 0, len(packed)) + packed


def _array_node(root, name):
    """Primeiro no com este nome que carregue um array."""
    found = []

    def walk(node):
        if found:
            return
        if node.name == name:
            for ptype, _blob in node.props:
                if ptype in "dfil":
                    found.append(node)
                    return
        for child in node.children:
            walk(child)

    walk(root)
    return found[0] if found else None


def _get(root, name):
    node = _array_node(root, name)
    if node is None:
        return None, None
    for ptype, blob in node.props:
        if ptype in "dfil":
            return _decode(blob, ptype), ptype
    return None, None


def _set(root, name, values, ptype):
    node = _array_node(root, name)
    node.props = [(ptype, _encode(values, ptype))]


def _save(src_bytes, roots, tail, dst):
    out = [src_bytes[:27]]
    cursor = 27
    for root in roots:
        write(root, out, cursor)
        cursor += size_of(root)
    out.append(b"\x00" * 13)
    out.append(tail)
    open(dst, "wb").write(b"".join(out))


# --------------------------------------------------------------------------


def _add_quad(target, corners):
    """Junta um quad de sombra a geometria, em DOIS poligonos de giros opostos.

    Um quad tem uma face so. Se o sentido de giro nao casar com a convencao de
    descarte do renderizador, ele fica invisivel justamente de cima -- que e de
    onde a camera olha, e foi assim que a primeira versao ficou sem sombra
    nenhuma. Nao da para testar isso aqui, e acertar por forca bruta custa quatro
    vertices.
    """
    verts, v_type = _get(target, b"Vertices")
    pvi, pvi_type = _get(target, b"PolygonVertexIndex")
    normals, n_type = _get(target, b"Normals")
    nidx, nidx_type = _get(target, b"NormalsIndex")
    uv, uv_type = _get(target, b"UV")
    uvidx, uvidx_type = _get(target, b"UVIndex")

    base = len(verts) // 3
    for x, y, z in corners:
        verts.extend([x, y, z])

    pvi.extend([base, base + 1, base + 2, ~(base + 3)])
    pvi.extend([base + 3, base + 2, base + 1, ~base])

    # Normais sao ByVertice/IndexToDirect: uma por vertice novo e um indice para
    # cada. A direcao nao importa para o resultado -- os dois giros ja garantem
    # que a face aparece dos dois lados.
    for _ in range(4):
        normals.extend([0.0, 1.0, 0.0])
    start_normal = len(normals) // 3 - 4
    nidx.extend([start_normal + i for i in range(4)])

    # UVs sao ByPolygonVertex/IndexToDirect: os cantos caem na metade DIREITA da
    # textura, onde a mancha foi pintada. Oito indices, um jogo por poligono.
    uv_base = len(uv) // 2
    uv.extend([0.5, 0.0, 1.0, 0.0, 1.0, 1.0, 0.5, 1.0])
    uvidx.extend([uv_base + i for i in range(4)])
    uvidx.extend([uv_base + 3, uv_base + 2, uv_base + 1, uv_base])

    _set(target, b"Vertices", verts, v_type)
    _set(target, b"PolygonVertexIndex", pvi, pvi_type)
    _set(target, b"Normals", normals, n_type)
    _set(target, b"NormalsIndex", nidx, nidx_type)
    _set(target, b"UV", uv, uv_type)
    _set(target, b"UVIndex", uvidx, uvidx_type)


def _open_geometry(src):
    data = open(src, "rb").read()
    _ver, roots, tail = parse(data)
    for candidate in roots:
        if _array_node(candidate, b"Vertices") is not None:
            return data, roots, tail, candidate
    raise SystemExit("nenhuma geometria encontrada em %s" % src)


def _halve_u(target):
    """Comprime os UVs para a metade esquerda da textura.

    Acompanha a TEXTURA, nao o modelo. Foi essa distincao que me escapou: comprimi
    os UVs dos dois modelos quando so a textura do chao tinha dobrado, e o modelo
    de mao passou a amostrar metade de uma textura inteira.
    """
    uv, uv_type = _get(target, b"UV")
    for i in range(0, len(uv), 2):
        uv[i] = uv[i] * 0.5
    _set(target, b"UV", uv, uv_type)


def build_ground(src, dst):
    """Modelo de chao: UVs comprimidos e o quad deitado no plano do chao.

    Aqui a malha ainda esta no espaco original, onde Y e a vertical e o chao e
    Y = 0.
    """
    data, roots, tail, target = _open_geometry(src)
    _halve_u(target)

    verts, _ = _get(target, b"Vertices")
    xs, zs = verts[0::3], verts[2::3]
    x0, x1 = min(xs) - SHADOW_MARGIN, max(xs) + SHADOW_MARGIN
    z0, z1 = min(zs) - SHADOW_MARGIN, max(zs) + SHADOW_MARGIN

    _add_quad(target, [(x0, SHADOW_LIFT, z0), (x1, SHADOW_LIFT, z0),
                       (x1, SHADOW_LIFT, z1), (x0, SHADOW_LIFT, z1)])
    _save(data, roots, tail, dst)
    return 4


def build_hand(src, dst):
    """Modelo de mao: o giro e o deslocamento da pose, mais o quad de sombra.

    O PLANO DO CHAO AQUI E OUTRO. Depois da pose, a malha esta no espaco do osso
    da mao, e nesse espaco +Z aponta para BAIXO -- medido em jogo comparando duas
    poses que diferiam so no sinal de Z: uma flutuava na altura do ombro e a
    outra encostava no chao. Entao o chao e um plano de Z constante, e o quad
    varia em X e Y, ao contrario do modelo de chao.
    """
    tmp = "source/_hand_posed.fbx"
    shift(src, tmp, HAND_OFFSET[0], HAND_OFFSET[1], HAND_OFFSET[2],
          HAND_ROTATION[0], HAND_ROTATION[1], HAND_ROTATION[2])

    data, roots, tail, target = _open_geometry(tmp)
    _halve_u(target)

    verts, _ = _get(target, b"Vertices")
    xs, ys, zs = verts[0::3], verts[1::3], verts[2::3]
    x0, x1 = min(xs) - SHADOW_MARGIN, max(xs) + SHADOW_MARGIN
    y0, y1 = min(ys) - SHADOW_MARGIN, max(ys) + SHADOW_MARGIN
    # O ponto mais BAIXO e o maior Z, porque +Z desce. E onde a roda toca o chao.
    ground = max(zs) - SHADOW_LIFT

    _add_quad(target, [(x0, y0, ground), (x1, y0, ground),
                       (x1, y1, ground), (x0, y1, ground)])
    _save(data, roots, tail, dst)
    os.remove(tmp)
    return 4


def build_texture():
    """Dobra a largura: original a esquerda, mancha de sombra a direita."""
    from PIL import Image

    original = Image.open(SOURCE_TEXTURE).convert("RGBA")
    w, h = original.size
    out = Image.new("RGBA", (w * 2, h), (0, 0, 0, 0))
    out.paste(original, (0, 0))

    # Elipse com queda suave, desenhada por pixel. Um desfoque gaussiano daria
    # borda mais macia, mas deixaria alpha residual ate a borda do quadrante, e
    # esse residuo aparece como um retangulo fantasma no chao.
    px = out.load()
    cx, cy = w * 1.5, h * 0.5
    rx, ry = w * 0.46, h * 0.46
    for y in range(h):
        for x in range(w, w * 2):
            nx = (x - cx) / rx
            ny = (y - cy) / ry
            d = math.sqrt(nx * nx + ny * ny)
            if d >= 1.0:
                continue
            # Queda suave (smoothstep ao quadrado): centro cheio, borda em zero,
            # sem aresta visivel.
            # Nucleo CHEIO ate SHADOW_CORE e so entao a queda. A primeira versao
            # usava (1-d)^2 desde o centro, o que fazia a mancha valer 25% do
            # alpha ja na metade do raio -- em tela ela parecia bem menor que o
            # carrinho, que foi exatamente o que apareceu no teste. Sombra de
            # contato e quase chapada, com a borda desmanchando.
            if d <= SHADOW_CORE:
                fade = 1.0
            else:
                fade = 1.0 - (d - SHADOW_CORE) / (1.0 - SHADOW_CORE)
                fade = fade * fade * (3.0 - 2.0 * fade)
            px[x, y] = (0, 0, 0, int(SHADOW_ALPHA * fade))
    out.save(OUT_TEXTURE_GROUND)

    # A textura do modelo de MAO e a original, sem alpha e sem a metade extra.
    out.save(OUT_TEXTURE_HAND)
    return out.size


def main():
    os.makedirs(os.path.dirname(OUT_TEXTURE_HAND), exist_ok=True)

    print("texturas %dx%d com alpha -> chao e mao" % build_texture())

    ground = os.path.join(OUT_MODELS, "Wheelbarrow.fbx")
    added = build_ground(SOURCE, ground)
    print("chao: %d vertices de sombra -> %s" % (added, ground))

    # O de mao sai da MESMA fonte, e nao do de chao: senao herdaria o quad do
    # chao, que no espaco da mao ficaria de pe ao lado do personagem.
    hand = os.path.join(OUT_MODELS, "Wheelbarrow_Hand.fbx")
    print("mao: %d vertices de sombra -> %s" % (build_hand(SOURCE, hand), hand))



if __name__ == "__main__":
    main()
