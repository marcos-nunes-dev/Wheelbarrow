"""Constroi os dois modelos do carrinho a partir de UMA fonte imutavel.

POR QUE UM CONSTRUTOR EM VEZ DE COMANDOS SOLTOS:

Antes, o modelo de mao era gerado a partir do modelo de CHAO, e o de chao era
editado no lugar. Cada geracao partia do resultado da anterior: rodar a mesma
ferramenta duas vezes produzia coisas diferentes, e nao havia como voltar ao
ponto de partida sem o git. Aqui existe uma fonte -- assets/source/ -- e os dois
modelos sao derivados dela toda vez.

O QUE CADA UM RECEBE:

    chao   sombra de contato no plano do chao do MUNDO, onde a vertical e Y
    mao    a pose (giro 270 0 0, deslocamento 0.31 0.90 0.56) mais a sombra no
           plano do chao do OSSO DA MAO, onde a vertical e Z -- planos
           diferentes, ver build_hand

A SOMBRA precisa existir na malha porque o engine nao tem sombra para item:
shadowExtents e shadowOffset so existem em script de VEICULO, e das 568 chaves de
TilePropertyKey nenhuma trata sombra. No PZ, objeto do mundo que tem sombra tem
ela PINTADA no sprite; como o carrinho renderiza por modelo 3D, o equivalente e
geometria com uma textura que desvanece nas bordas.

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

# Uma textura por modelo, com o mesmo conteudo. Nao e desperdicio: arquivos
# separados permitem mexer num modelo sem tocar no outro, e ja foi isso que
# tornou uma reversao de emergencia uma linha em vez de refazer tudo.
TEXTURES = "../Contents/mods/MNWheelbarrow/common/media/textures/WorldItems"
OUT_TEXTURE_GROUND = os.path.join(TEXTURES, "Wheelbarrow_Ground.png")
OUT_TEXTURE_HAND = os.path.join(TEXTURES, "Wheelbarrow_Hand.png")

# Pose da mao, medida em jogo. Ver o cabecalho de models_wheelbarrow.txt.
HAND_ROTATION = (270, 0, 0)
HAND_OFFSET = (0.31, 0.90, 0.56)

# TAMANHO DA TEXTURA: 512x512, e este numero e MEDIDO, nao escolhido.
#
# Personagem e veiculos sumiam da tela -- e so eles; o cenario, que e sprite,
# continuava. Tres ocorrencias, todas com o modelo de mao usando textura com
# alpha, o que me fez culpar o canal alpha e reverter a sombra na mao. Errado.
#
# Um teste controlado de quatro variantes, mesma malha e so a textura mudando,
# deu a resposta:
#
#     512x512  RGBA opaco        funciona
#     512x512  RGBA translucido  funciona
#    1024x512  RGBA translucido  QUEBRA
#
# A culpa e do TAMANHO. Transparencia em 512x512 e segura, e por isso a sombra na
# mao voltou. O gatilho da falha, quando ela acontece, e a RECONSTRUCAO do modelo
# (resetModelNextFrame) -- com o modelo em cache nada acontece, o que fazia o
# defeito parecer intermitente.
TEXTURE_SIZE = 512

# A faixa da sombra e reservada DENTRO dos 512, encolhendo os UVs do carrinho.
# A alternativa -- achar espaco livre no atlas -- foi tentada e nao existe: 72.5%
# dele esta ocupado e o maior retangulo vazio tem 4x116 texels. Encolher custa 20%
# da resolucao horizontal, imperceptivel num objeto que renderiza pequeno.
ATLAS_SPLIT = 0.78
SHADOW_U0, SHADOW_U1 = 0.80, 1.0

# A sombra cobre a pegada do carrinho com uma folga. Em unidades de malha.
SHADOW_MARGIN = 0.12
# Distancia do plano do chao. Zero exato briga com o piso pelo mesmo pixel de
# profundidade e produz cintilacao.
SHADOW_LIFT = 0.004
# Fracao do raio com alpha cheio antes de a borda desmanchar. Queda desde o
# centro fazia a mancha parecer bem menor que o carrinho em tela.
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
    _array_node(root, name).props = [(ptype, _encode(values, ptype))]


def _save(src_bytes, roots, tail, dst):
    out = [src_bytes[:27]]
    cursor = 27
    for root in roots:
        write(root, out, cursor)
        cursor += size_of(root)
    out.append(b"\x00" * 13)
    out.append(tail)
    open(dst, "wb").write(b"".join(out))


def _open_geometry(src):
    data = open(src, "rb").read()
    _ver, roots, tail = parse(data)
    for candidate in roots:
        if _array_node(candidate, b"Vertices") is not None:
            return data, roots, tail, candidate
    raise SystemExit("nenhuma geometria encontrada em %s" % src)


# --------------------------------------------------------------------------


def _shrink_u(target):
    """Encolhe os UVs do carrinho, liberando a faixa da sombra a direita.

    Acompanha a TEXTURA, nao o modelo -- distincao que ja me escapou uma vez:
    encolhi os UVs de um modelo cuja textura nao tinha mudado, e ele passou a
    amostrar so um pedaco da imagem inteira.
    """
    uv, uv_type = _get(target, b"UV")
    for i in range(0, len(uv), 2):
        uv[i] = uv[i] * ATLAS_SPLIT
    _set(target, b"UV", uv, uv_type)


def _add_quad(target, corners):
    """Junta o quad de sombra em DOIS poligonos, com giros opostos.

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

    # Normais sao ByVertice/IndexToDirect: uma por vertice novo, e um indice para
    # cada. A direcao nao importa -- os dois giros ja garantem os dois lados.
    for _ in range(4):
        normals.extend([0.0, 1.0, 0.0])
    start_normal = len(normals) // 3 - 4
    nidx.extend([start_normal + i for i in range(4)])

    # UVs sao ByPolygonVertex/IndexToDirect: os cantos caem na faixa reservada.
    uv_base = len(uv) // 2
    uv.extend([SHADOW_U0, 0.0, SHADOW_U1, 0.0,
               SHADOW_U1, 1.0, SHADOW_U0, 1.0])
    uvidx.extend([uv_base + i for i in range(4)])
    uvidx.extend([uv_base + 3, uv_base + 2, uv_base + 1, uv_base])

    _set(target, b"Vertices", verts, v_type)
    _set(target, b"PolygonVertexIndex", pvi, pvi_type)
    _set(target, b"Normals", normals, n_type)
    _set(target, b"NormalsIndex", nidx, nidx_type)
    _set(target, b"UV", uv, uv_type)
    _set(target, b"UVIndex", uvidx, uvidx_type)


def build_ground(src, dst):
    """Modelo de chao. Aqui a vertical e Y e o chao e Y = 0."""
    data, roots, tail, target = _open_geometry(src)
    _shrink_u(target)

    verts, _ = _get(target, b"Vertices")
    xs, zs = verts[0::3], verts[2::3]
    x0, x1 = min(xs) - SHADOW_MARGIN, max(xs) + SHADOW_MARGIN
    z0, z1 = min(zs) - SHADOW_MARGIN, max(zs) + SHADOW_MARGIN

    _add_quad(target, [(x0, SHADOW_LIFT, z0), (x1, SHADOW_LIFT, z0),
                       (x1, SHADOW_LIFT, z1), (x0, SHADOW_LIFT, z1)])
    _save(data, roots, tail, dst)
    return 4


def build_hand(src, dst):
    """Modelo de mao: a pose, mais a sombra no plano do chao do OSSO.

    O PLANO DO CHAO AQUI E OUTRO. Depois da pose, a malha esta no espaco do osso
    da mao, e nesse espaco +Z aponta para BAIXO -- medido em jogo comparando duas
    poses que diferiam so no sinal de Z: uma flutuava na altura do ombro e a
    outra encostava no chao. Entao o chao e um plano de Z constante e o quad varia
    em X e Y, ao contrario do modelo de chao. Copiar o quad de um para o outro o
    deixaria de pe ao lado do personagem.
    """
    tmp = "source/_hand_posed.fbx"
    shift(src, tmp, HAND_OFFSET[0], HAND_OFFSET[1], HAND_OFFSET[2],
          HAND_ROTATION[0], HAND_ROTATION[1], HAND_ROTATION[2])

    data, roots, tail, target = _open_geometry(tmp)
    _shrink_u(target)

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


def build_texture(path):
    """512x512 RGBA: o carrinho encolhido a esquerda, a sombra na faixa direita."""
    from PIL import Image

    original = Image.open(SOURCE_TEXTURE).convert("RGBA")
    size = TEXTURE_SIZE
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(original.resize((int(size * ATLAS_SPLIT), size), Image.LANCZOS), (0, 0))

    x0, x1 = int(size * SHADOW_U0), int(size * SHADOW_U1)
    cx, cy = (x0 + x1) / 2.0, size / 2.0
    rx, ry = (x1 - x0) / 2.0, size / 2.0

    px = out.load()
    for y in range(size):
        for x in range(x0, x1):
            d = math.hypot((x - cx) / rx, (y - cy) / ry)
            if d >= 1.0:
                continue
            if d <= SHADOW_CORE:
                fade = 1.0
            else:
                fade = 1.0 - (d - SHADOW_CORE) / (1.0 - SHADOW_CORE)
                fade = fade * fade * (3.0 - 2.0 * fade)
            px[x, y] = (0, 0, 0, int(SHADOW_ALPHA * fade))

    out.save(path)
    return out.size


def main():
    os.makedirs(TEXTURES, exist_ok=True)

    for path in (OUT_TEXTURE_GROUND, OUT_TEXTURE_HAND):
        print("textura %dx%d RGBA -> %s" % (build_texture(path) + (path,)))

    ground = os.path.join(OUT_MODELS, "Wheelbarrow.fbx")
    print("chao: %d vertices de sombra -> %s" % (build_ground(SOURCE, ground), ground))

    # O de mao sai da MESMA fonte, e nao do de chao: senao herdaria o quad do
    # chao, que no espaco da mao ficaria de pe ao lado do personagem.
    hand = os.path.join(OUT_MODELS, "Wheelbarrow_Hand.fbx")
    print("mao: %d vertices de sombra -> %s" % (build_hand(SOURCE, hand), hand))


if __name__ == "__main__":
    main()
