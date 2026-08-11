"""Renderiza o icone de inventario a partir do proprio modelo 3D.

POR QUE NAO REAPROVEITAR tools_render_iso_sprites.py: aquele renderiza SPRITE DE
TILE, e o enquadramento dele e a razao de existir -- ancora medida em 213 celulas
vanilla, escala comum entre as oito faces, sombra de contato assada. Um icone
quer o oposto: enquadramento justo no objeto, sem sombra, sem ancora. Forcar um
no outro so esconderia duas intencoes diferentes atras dos mesmos numeros.

O QUE MUDA EM RELACAO AO SPRITE:

  elevacao   35 graus em vez de 30. O sprite usa 30 porque e a elevacao que
             produz o losango 2:1 do PZ -- ali o numero e imposto pela projecao
             do jogo. O icone nao vive no mundo, entao pode usar o angulo que
             mostra melhor o objeto, e um pouco mais alto revela a cacamba.
  sombra     nenhuma. No inventario ela so sujaria a miniatura.
  recorte    justo no conteudo, com uma folga pequena. O icone e visto com 32
             pixels de lado; margem generosa aqui vira objeto minusculo la.

O icone e gerado do MESMO fbx que o jogo renderiza, entao ele nao pode divergir
do que o jogador ve no chao -- que e o defeito classico de icone desenhado a mao.

Uso:
    python tools_render_icon.py
"""
import json
import math
import os

from PIL import Image

from tools_render_iso_sprites import triangles

MESH = "wheelbarrow_mesh.json"
TEXTURE = "source/Wheelbarrow_raw.png"
OUT = "../Contents/mods/MNWheelbarrow/common/media/textures/Item_Wheelbarrow.png"

# Tres quartos, com o carrinho de lado: mostra o comprimento, a roda e a boca da
# cacamba ao mesmo tempo. De frente ele vira um retangulo sem leitura.
AZIMUTH = 215.0
ELEVATION = math.radians(35.0)

SUPERSAMPLE = 4      # rasteriza grande e reduz: e o que da a borda suave
ICON_SIZE = 64
PADDING = 2

# Mesmo ganho do renderizador de sprites: a textura deste modelo e escura e o
# render cru sai apagado ao lado dos icones do jogo.
BRIGHTNESS = 1.45
# Luz difusa simples, so para as faces nao ficarem todas com a mesma cor. O icone
# nao precisa de sombreamento correto, precisa de LEITURA de forma.
LIGHT = (-0.4, 0.8, 0.45)
AMBIENT = 0.55


def project(verts):
    th = math.radians(AZIMUTH)
    ct, st = math.cos(th), math.sin(th)
    ce, se = math.cos(ELEVATION), math.sin(ELEVATION)

    n = len(verts) // 3
    out = []
    for i in range(n):
        x, y, z = verts[3 * i], verts[3 * i + 1], verts[3 * i + 2]
        right = x * ct - z * st
        fwd = x * st + z * ct
        # Camera acima olhando para baixo: o que esta mais longe sobe na tela, e
        # o que esta mais alto esta mais PERTO dela.
        out.append((right, y * ce + fwd * se, fwd * ce - y * se))
    return out


def normal(a, b, c):
    ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
    nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    length = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
    return nx / length, ny / length, nz / length


def main():
    mesh = json.load(open(MESH))
    verts, pvi, uvs, uvi = mesh["V"], mesh["PVI"], mesh["UV"], mesh["UVI"]
    texture = Image.open(TEXTURE).convert("RGB")
    tex = texture.load()
    tw, th_ = texture.size

    points = project(verts)
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    span = max(max(xs) - min(xs), max(ys) - min(ys)) or 1.0

    size = ICON_SIZE * SUPERSAMPLE
    pad = PADDING * SUPERSAMPLE
    scale = (size - 2 * pad) / span
    ox = (size - (max(xs) + min(xs)) * scale) / 2.0
    oy = (size + (max(ys) + min(ys)) * scale) / 2.0

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = canvas.load()
    zbuf = [[-1e9] * size for _ in range(size)]

    for (ia, ka), (ib, kb), (ic, kc) in triangles(pvi):
        a, b, c = points[ia], points[ib], points[ic]
        nx, ny, nz = normal(a, b, c)
        shade = AMBIENT + (1.0 - AMBIENT) * max(
            0.0, nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2])

        sxa, sya = a[0] * scale + ox, oy - a[1] * scale
        sxb, syb = b[0] * scale + ox, oy - b[1] * scale
        sxc, syc = c[0] * scale + ox, oy - c[1] * scale

        area = (sxb - sxa) * (syc - sya) - (sxc - sxa) * (syb - sya)
        if abs(area) < 1e-9:
            continue

        lo_x = max(0, int(min(sxa, sxb, sxc)))
        hi_x = min(size - 1, int(max(sxa, sxb, sxc)) + 1)
        lo_y = max(0, int(min(sya, syb, syc)))
        hi_y = min(size - 1, int(max(sya, syb, syc)) + 1)

        for yy in range(lo_y, hi_y + 1):
            for xx in range(lo_x, hi_x + 1):
                cx, cy = xx + 0.5, yy + 0.5
                w0 = ((sxb - cx) * (syc - cy) - (sxc - cx) * (syb - cy)) / area
                w1 = ((sxc - cx) * (sya - cy) - (sxa - cx) * (syc - cy)) / area
                w2 = 1.0 - w0 - w1
                if w0 < 0 or w1 < 0 or w2 < 0:
                    continue

                depth = w0 * a[2] + w1 * b[2] + w2 * c[2]
                if depth <= zbuf[yy][xx]:
                    continue
                zbuf[yy][xx] = depth

                u = w0 * uvs[2 * uvi[ka]] + w1 * uvs[2 * uvi[kb]] + w2 * uvs[2 * uvi[kc]]
                v = w0 * uvs[2 * uvi[ka] + 1] + w1 * uvs[2 * uvi[kb] + 1] + w2 * uvs[2 * uvi[kc] + 1]
                tx = min(tw - 1, max(0, int(u * tw)))
                ty = min(th_ - 1, max(0, int((1.0 - v) * th_)))
                r, g, bl = tex[tx, ty]
                gain = shade * BRIGHTNESS
                px[xx, yy] = (min(255, int(r * gain)), min(255, int(g * gain)),
                              min(255, int(bl * gain)), 255)

    # Recorta no conteudo antes de reduzir: sem isso a folga do rasterizador
    # entraria na conta e o objeto sairia menor do que precisa.
    box = canvas.getbbox()
    if box:
        canvas = canvas.crop(box)

    icon = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
    inner = ICON_SIZE - 2 * PADDING
    w, h = canvas.size
    ratio = min(inner / w, inner / h)
    resized = canvas.resize((max(1, int(w * ratio)), max(1, int(h * ratio))),
                            Image.LANCZOS)
    icon.paste(resized, ((ICON_SIZE - resized.size[0]) // 2,
                         (ICON_SIZE - resized.size[1]) // 2), resized)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    icon.save(OUT)
    print("icone %dx%d -> %s" % (ICON_SIZE, ICON_SIZE, OUT))


if __name__ == "__main__":
    main()
