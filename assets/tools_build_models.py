"""Constroi os dois modelos do carrinho a partir de UMA fonte imutavel.

POR QUE UM CONSTRUTOR EM VEZ DE COMANDOS SOLTOS:

Antes, o modelo de mao era gerado a partir do modelo de CHAO, e o de chao era
editado no lugar. Cada geracao partia do resultado da anterior: rodar a mesma
ferramenta duas vezes produzia coisas diferentes, e nao havia como voltar ao
ponto de partida sem o git. Aqui existe uma fonte -- assets/source/ -- e os dois
modelos sao derivados dela toda vez.

O QUE CADA UM RECEBE:

    chao      sombra de contato no plano do chao do MUNDO, onde a vertical e Y
    tombado   igual ao de chao, sem a sombra -- ela inclinaria junto e viraria
              uma mancha de contato de pe no ar
    mao    so a pose (giro 270 0 0, deslocamento 0.36 0.90 0.56). Sem sombra:
           o osso da mao inclina ao andar e levaria o quad junto -- ver build_hand

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
HAND_OFFSET = (0.36, 0.90, 0.56)

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

# MARGEM DE AMOSTRAGEM, em texels. A filtragem bilinear le meio texel para fora
# de cada borda, entao um UV que termina exatamente na emenda do atlas mistura
# com o que houver do outro lado. Foi isso que produziu uma linha fina no limite
# do modelo: a borda direita da textura do carrinho sangrava para dentro da faixa
# vazia. Recuar as duas regioes por um texel e meio resolve a causa, em vez de
# disfarcar o sintoma.
UV_INSET_TEXELS = 1.5

# A sombra cobre a pegada do carrinho com uma folga. Em unidades de malha.
# Folga menor deixa o quad mais colado ao objeto: quanto menos area de quad
# transparente sobrar, menos chance de ela aparecer como uma mancha de luz
# diferente no chao.
SHADOW_MARGIN = 0.06
# Distancia do plano do chao. Zero exato briga com o piso pelo mesmo pixel de
# profundidade e produz cintilacao; baixo o suficiente para o quad nao parecer
# flutuar sobre o piso.
SHADOW_LIFT = 0.0025
# Fracao do raio com alpha cheio antes de a borda desmanchar, e o expoente da
# queda.
#
# A primeira versao usava nucleo 0.55 com queda suave, e o resultado foi um HALO
# largo e fraco que o Marcos leu como "o chao tem uma iluminacao diferente fora
# da sombra". O olho nao interpreta alpha baixo espalhado como sombra -- ele
# interpreta como o chao ter mudado de cor. Nucleo maior e queda mais rapida
# concentram a mancha e encurtam esse halo.
SHADOW_CORE = 0.68
SHADOW_FALLOFF_POWER = 1.8
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
    inset = UV_INSET_TEXELS / TEXTURE_SIZE
    limit = ATLAS_SPLIT - inset
    uv, uv_type = _get(target, b"UV")
    for i in range(0, len(uv), 2):
        uv[i] = uv[i] * limit
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
    inset = UV_INSET_TEXELS / TEXTURE_SIZE
    u0, u1 = SHADOW_U0 + inset, SHADOW_U1 - inset
    v0, v1 = inset, 1.0 - inset
    uv_base = len(uv) // 2
    uv.extend([u0, v0, u1, v0, u1, v1, u0, v1])
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


def build_tipped(src, dst):
    """Modelo do carrinho TOMBADO: igual ao de chao, porem SEM o quad de sombra.

    A sombra e geometria assada na malha, entao ela inclina junto com o carrinho
    e deixa de fazer sentido: uma mancha de contato de pe no ar. Nao da para
    recalcular -- e um quad, nao um efeito.

    A saida e trocar o MODELO. InventoryItem.setWorldStaticModel aceita a troca
    em runtime, entao o carrinho usa o modelo com sombra enquanto esta de pe e
    este enquanto esta tombado. Assim a sombra nao se perde no estado comum, que
    e o de pe, e nao atrapalha no estado tombado, que e temporario.

    Os UVs sao encolhidos igual ao de chao: os dois compartilham a textura, e a
    faixa da sombra simplesmente fica sem uso aqui.
    """
    data, roots, tail, target = _open_geometry(src)
    _shrink_u(target)
    _save(data, roots, tail, dst)
    return 0


def build_hand(src, dst):
    """Modelo de mao: SO a pose. Sem sombra, e isso e geometria, nao preferencia.

    A sombra na mao foi implementada e removida, e o motivo esta na animacao de
    dois bracos: enquanto o personagem ANDA, o osso da mao inclina, e um quad
    assado na malha inclina junto. Ele deixa de ser um plano no chao -- metade
    afunda no piso, metade fica de pe. Parado ficava perfeito; andando, nao.

    Nao ha ajuste que resolva. Altura menor faz flutuar parado; quad menor so
    diminui o artefato. Um plano rigido nao pode permanecer paralelo ao chao
    quando o osso que o carrega gira, e a inclinacao e justamente o que faz a
    pose de empurrar parecer certa. Os dois recursos sao incompativeis e a
    animacao vale mais.

    A unica saida real seria prender a sombra a um osso que nao incline -- um
    segundo modelo via clothing item com m_AttachBone na raiz. Fica registrado
    como ideia, nao como pendencia: e bastante maquinario para uma sombra que so
    aparece enquanto o carrinho esta sendo carregado.

    Sem quad, o modelo tambem nao precisa da faixa de atlas: os UVs ficam
    inteiros e ele usa a textura original, sem alpha e em resolucao cheia.
    """
    shift(src, dst, HAND_OFFSET[0], HAND_OFFSET[1], HAND_OFFSET[2],
          HAND_ROTATION[0], HAND_ROTATION[1], HAND_ROTATION[2])
    return 0


def build_hand_texture(path):
    """A original, sem alpha e sem faixa: o modelo de mao nao tem sombra."""
    from PIL import Image

    Image.open(SOURCE_TEXTURE).convert("RGB").save(path)


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
                t = 1.0 - (d - SHADOW_CORE) / (1.0 - SHADOW_CORE)
                fade = (t * t * (3.0 - 2.0 * t)) ** SHADOW_FALLOFF_POWER
            px[x, y] = (0, 0, 0, int(SHADOW_ALPHA * fade))

    out.save(path)
    return out.size


def main():
    os.makedirs(TEXTURES, exist_ok=True)

    print("textura de chao %dx%d RGBA -> %s"
          % (build_texture(OUT_TEXTURE_GROUND) + (OUT_TEXTURE_GROUND,)))
    build_hand_texture(OUT_TEXTURE_HAND)
    print("textura de mao original, sem faixa de sombra -> %s" % OUT_TEXTURE_HAND)

    ground = os.path.join(OUT_MODELS, "Wheelbarrow.fbx")
    print("chao: %d vertices de sombra -> %s" % (build_ground(SOURCE, ground), ground))

    # O de mao sai da MESMA fonte, e nao do de chao: senao herdaria o quad do
    # chao, que no espaco da mao ficaria de pe ao lado do personagem.
    tipped = os.path.join(OUT_MODELS, "Wheelbarrow_Tipped.fbx")
    build_tipped(SOURCE, tipped)
    print("tombado: sem sombra -> %s" % tipped)

    hand = os.path.join(OUT_MODELS, "Wheelbarrow_Hand.fbx")
    build_hand(SOURCE, hand)
    print("mao: pose %s %s, sem sombra -> %s" % (HAND_ROTATION, HAND_OFFSET, hand))


if __name__ == "__main__":
    main()
