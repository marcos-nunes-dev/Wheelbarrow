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
# DUAS texturas, e a separacao nao e organizacao -- e isolamento.
#
# Na primeira versao os dois modelos dividiam uma textura com canal alpha, e o
# resultado em jogo foi personagem E VEICULOS sumindo da tela. Os dois sao
# desenhados pelo mesmo passe de modelo 3D, e o modelo de MAO faz parte do
# personagem: uma textura que aquele passe nao digira derruba o passe inteiro,
# nao so o carrinho. O cenario, que e sprite, continuava aparecendo -- e foi
# esse recorte que apontou a causa.
#
# Agora a alpha existe SO na textura do modelo de chao. O personagem volta a
# usar a textura original, sem alpha, exatamente como antes da sombra.
OUT_TEXTURE_HAND = "../Contents/mods/MNWheelbarrow/common/media/textures/WorldItems/Wheelbarrow.png"
OUT_TEXTURE_GROUND = "../Contents/mods/MNWheelbarrow/common/media/textures/WorldItems/Wheelbarrow_Ground.png"

# Pose da mao, medida em jogo. Ver o cabecalho de models_wheelbarrow.txt.
HAND_ROTATION = (270, 0, 0)
HAND_OFFSET = (0.31, 0.90, 0.56)

# A sombra cobre a pegada do carrinho com uma folga. Em unidades de malha.
SHADOW_MARGIN = 0.12
# Altura acima de y=0. Zero exato briga com o piso pelo mesmo pixel de
# profundidade e produz cintilacao; um valor pequeno resolve sem ser visivel.
SHADOW_LIFT = 0.004


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


def halve_u_and_add_shadow(src, dst, add_shadow):
    """Comprime os UVs para a metade esquerda e, se pedido, junta o quad.

    Os dois modelos precisam da compressao de U, porque compartilham a textura.
    So o de chao recebe o quad.
    """
    data = open(src, "rb").read()
    _ver, roots, tail = parse(data)
    root = roots[0] if len(roots) == 1 else None
    # A geometria vive num unico no Objects/Geometry; procurar em todas as
    # raizes evita depender de qual delas e.
    target = None
    for candidate in roots:
        if _array_node(candidate, b"Vertices") is not None:
            target = candidate
            break
    if target is None:
        raise SystemExit("nenhuma geometria encontrada em %s" % src)

    uv, uv_type = _get(target, b"UV")
    for i in range(0, len(uv), 2):
        uv[i] = uv[i] * 0.5

    if not add_shadow:
        _set(target, b"UV", uv, uv_type)
        _save(data, roots, tail, dst)
        return 0

    verts, v_type = _get(target, b"Vertices")
    pvi, pvi_type = _get(target, b"PolygonVertexIndex")
    normals, n_type = _get(target, b"Normals")
    nidx, nidx_type = _get(target, b"NormalsIndex")
    uvidx, uvidx_type = _get(target, b"UVIndex")

    xs = verts[0::3]
    zs = verts[2::3]
    x0, x1 = min(xs) - SHADOW_MARGIN, max(xs) + SHADOW_MARGIN
    z0, z1 = min(zs) - SHADOW_MARGIN, max(zs) + SHADOW_MARGIN

    base = len(verts) // 3
    quad = [(x0, SHADOW_LIFT, z0), (x1, SHADOW_LIFT, z0),
            (x1, SHADOW_LIFT, z1), (x0, SHADOW_LIFT, z1)]
    for x, y, z in quad:
        verts.extend([x, y, z])

    # DOIS poligonos sobre os mesmos quatro cantos, com sentidos de giro
    # OPOSTOS. Um quad so tem uma face; se o sentido nao casar com a convencao de
    # descarte do renderizador, ele e invisivel justamente de cima -- que e de
    # onde a camera olha. Nao da para testar isso aqui, e o custo de acertar por
    # forca bruta e quatro vertices. Foi assim que a primeira versao ficou sem
    # sombra nenhuma.
    pvi.extend([base, base + 1, base + 2, ~(base + 3)])
    pvi.extend([base + 3, base + 2, base + 1, ~base])

    # Normais sao ByVertice/IndexToDirect: uma por vertice novo, apontando para
    # cima, e uma entrada de indice para cada.
    for _ in range(4):
        normals.extend([0.0, 1.0, 0.0])
    start_normal = len(normals) // 3 - 4
    nidx.extend([start_normal + i for i in range(4)])

    # UVs sao ByPolygonVertex/IndexToDirect: os quatro cantos caem na metade
    # DIREITA da textura, que e onde a mancha de sombra foi pintada. Os oito
    # indices cobrem os dois poligonos.
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

    _save(data, roots, tail, dst)
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
            fade = (1.0 - d) ** 2
            px[x, y] = (0, 0, 0, int(150 * fade))
    out.save(OUT_TEXTURE_GROUND)

    # A textura do modelo de MAO e a original, sem alpha e sem a metade extra.
    original.convert("RGB").save(OUT_TEXTURE_HAND)
    return out.size


def main():
    os.makedirs(os.path.dirname(OUT_TEXTURE_HAND), exist_ok=True)

    print("textura de chao %dx%d (com alpha) -> %s"
          % (build_texture() + (OUT_TEXTURE_GROUND,)))
    print("textura de mao   original, sem alpha -> %s" % OUT_TEXTURE_HAND)

    ground = os.path.join(OUT_MODELS, "Wheelbarrow.fbx")
    added = halve_u_and_add_shadow(SOURCE, ground, add_shadow=True)
    print("chao: %d vertices de sombra -> %s" % (added, ground))

    # O modelo de mao parte da MESMA fonte, nao do de chao: senao herdaria o quad.
    tmp = "source/_hand_uv.fbx"
    halve_u_and_add_shadow(SOURCE, tmp, add_shadow=False)
    hand = os.path.join(OUT_MODELS, "Wheelbarrow_Hand.fbx")
    shift(tmp, hand, HAND_OFFSET[0], HAND_OFFSET[1], HAND_OFFSET[2],
          HAND_ROTATION[0], HAND_ROTATION[1], HAND_ROTATION[2])
    os.remove(tmp)
    print("mao: giro %s deslocamento %s -> %s"
          % (HAND_ROTATION, HAND_OFFSET, hand))


if __name__ == "__main__":
    main()
