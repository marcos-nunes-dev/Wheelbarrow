"""Renderiza sprites isometricos do modelo, no enquadramento que o PZ espera.

Objetos do mundo no Project Zomboid nao renderizam por modelo 3D: renderizam
por sprite de tile, um para cada face N/S/E/W. Este script tira essas quatro
imagens direto do FBX, sem Blender.

PROJECAO -- por que 30 graus e nao 26.57:
uma square do chao e um quadrado alinhado a X,Z do mundo. Com a camera a 45
graus de azimute, os quatro cantos projetam numa largura de 1.4142*s e numa
altura de 1.4142*s*sin(elevacao). A razao largura/altura e portanto
1/sin(elevacao). O PZ usa losango 2:1, logo sin(elevacao) = 0.5 e a elevacao
e exatamente 30 graus.

ANCORA -- medida, nao deduzida:
a primeira versao usava (64, 224), calculado supondo que o losango do chao
ocupasse exatamente os 64 pixels de baixo. Errado: medindo 213 celulas reais
de cinco folhas vanilla (moveis, eletrodomesticos, armazenamento), a base do
conteudo tem mediana em y = 245 e o centro horizontal em x = 63. Com 224 o
sprite flutuava 21 pixels acima do chao.

Para referencia, nessas mesmas amostras a largura do conteudo tem mediana 94
e maximo 126, e a altura mediana 117. O carrinho e um objeto comprido, entao
ficar perto do limite de largura e esperado.
"""
import json
import math
import struct
import sys

from PIL import Image

SPRITE_W, SPRITE_H = 128, 256
# Sprites do jogo base tem luminancia mediana ~79 (medido em 73 celulas de
# quatro folhas vanilla). A textura deste modelo e escura, entao o render
# cru saia escuro demais. Este ganho foi calibrado medindo o resultado.
BRIGHTNESS = 1.45
ANCHOR_X, ANCHOR_Y = 64, 245
ELEVATION = math.radians(30.0)

# Ordem das faces como o PZ nomeia: a camera olha o objeto de frente em cada uma.
FACINGS = [("S", 45.0), ("W", 135.0), ("N", 225.0), ("E", 315.0)]


def triangles(pvi):
    """FBX guarda poligonos num indice plano; o ultimo vertice de cada poligono
    vem negado (~i). Convertemos para triangulos em leque."""
    poly = []
    for k, idx in enumerate(pvi):
        if idx < 0:
            poly.append((~idx, k))
            for a in range(1, len(poly) - 1):
                yield poly[0], poly[a], poly[a + 1]
            poly = []
        else:
            poly.append((idx, k))


def render(mesh, texture, azimuth_deg):
    verts = mesh["V"]
    pvi = mesh["PVI"]
    uvs = mesh["UV"]
    uvi = mesh["UVI"]

    th = math.radians(azimuth_deg)
    ct, st = math.cos(th), math.sin(th)
    ce, se = math.cos(ELEVATION), math.sin(ELEVATION)

    n = len(verts) // 3
    sx = [0.0] * n
    sy = [0.0] * n
    depth = [0.0] * n
    for i in range(n):
        x, y, z = verts[3 * i], verts[3 * i + 1], verts[3 * i + 2]
        right = x * ct - z * st
        fwd = x * st + z * ct
        sx[i] = right
        # Camera ACIMA olhando para baixo: o que esta mais longe sobe na tela.
        # Com o sinal invertido aqui, a cena era vista por baixo -- dava para
        # ver o fundo da cacamba do carrinho em vez de dentro dela.
        sy[i] = y * ce + fwd * se
        # Profundidade ao longo da direcao de visao, que aponta para frente e
        # para baixo: ponto mais alto esta mais PERTO de uma camera elevada.
        depth[i] = fwd * ce - y * se

    minx, maxx = min(sx), max(sx)
    miny, maxy = min(sy), max(sy)
    span = max(maxx - minx, (maxy - miny) * 1.0)
    if span <= 0:
        raise SystemExit("modelo degenerado")

    # Deixa margem de 4px e ancora a base no ponto do losango.
    scale = (SPRITE_W - 8) / (maxx - minx)
    if (maxy - miny) * scale > (SPRITE_H - 8):
        scale = (SPRITE_H - 8) / (maxy - miny)
    cx = (minx + maxx) / 2.0

    px = [(v - cx) * scale + ANCHOR_X for v in sx]
    py = [ANCHOR_Y - (v - miny) * scale for v in sy]

    tw, th_ = texture.size
    tex = texture.load()

    img = Image.new("RGBA", (SPRITE_W, SPRITE_H), (0, 0, 0, 0))
    out = img.load()
    zbuf = [[1e30] * SPRITE_W for _ in range(SPRITE_H)]

    for (ia, ka), (ib, kb), (ic, kc) in triangles(pvi):
        x0, y0 = px[ia], py[ia]
        x1, y1 = px[ib], py[ib]
        x2, y2 = px[ic], py[ic]

        area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
        if abs(area) < 1e-9:
            continue

        # Sombreado simples pela normal da face, para o sprite nao ficar chapado.
        ax = verts[3 * ib] - verts[3 * ia]
        ay = verts[3 * ib + 1] - verts[3 * ia + 1]
        az = verts[3 * ib + 2] - verts[3 * ia + 2]
        bx = verts[3 * ic] - verts[3 * ia]
        by = verts[3 * ic + 1] - verts[3 * ia + 1]
        bz = verts[3 * ic + 2] - verts[3 * ia + 2]
        nx, ny, nz = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
        nl = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
        lam = (nx * -0.4 + ny * 0.85 + nz * -0.35) / nl
        shade = 0.72 + 0.38 * max(0.0, lam)

        uv = []
        for k in (ka, kb, kc):
            j = uvi[k]
            uv.append((uvs[2 * j], uvs[2 * j + 1]))

        lo_x = max(0, int(math.floor(min(x0, x1, x2))))
        hi_x = min(SPRITE_W - 1, int(math.ceil(max(x0, x1, x2))))
        lo_y = max(0, int(math.floor(min(y0, y1, y2))))
        hi_y = min(SPRITE_H - 1, int(math.ceil(max(y0, y1, y2))))

        for yy in range(lo_y, hi_y + 1):
            for xx in range(lo_x, hi_x + 1):
                cxp, cyp = xx + 0.5, yy + 0.5
                w0 = ((x1 - cxp) * (y2 - cyp) - (x2 - cxp) * (y1 - cyp)) / area
                w1 = ((x2 - cxp) * (y0 - cyp) - (x0 - cxp) * (y2 - cyp)) / area
                w2 = 1.0 - w0 - w1
                if w0 < 0 or w1 < 0 or w2 < 0:
                    continue
                zz = w0 * depth[ia] + w1 * depth[ib] + w2 * depth[ic]
                if zz >= zbuf[yy][xx]:
                    continue
                u = w0 * uv[0][0] + w1 * uv[1][0] + w2 * uv[2][0]
                v = w0 * uv[0][1] + w1 * uv[1][1] + w2 * uv[2][1]
                tx = int(u * (tw - 1)) % tw
                ty = int((1.0 - v) * (th_ - 1)) % th_
                r, g, b = tex[tx, ty][:3]
                zbuf[yy][xx] = zz
                s = shade * BRIGHTNESS
                out[xx, yy] = (
                    min(255, int(r * s)),
                    min(255, int(g * s)),
                    min(255, int(b * s)),
                    255,
                )
    return img


if __name__ == "__main__":
    mesh = json.load(open(sys.argv[1]))
    texture = Image.open(sys.argv[2]).convert("RGB")
    sheet = Image.new("RGBA", (1024, 2048), (0, 0, 0, 0))
    for col, (name, az) in enumerate(FACINGS):
        img = render(mesh, texture, az)
        img.save("sprite_%s.png" % name.lower())
        sheet.paste(img, (col * 128, 0))
        print("face %s (azimute %5.1f) -> sprite_%s.png" % (name, az, name.lower()))
    sheet.save(sys.argv[3])
    print("tilesheet 1024x2048 -> %s" % sys.argv[3])
