"""Pre-visualiza a pose do modelo de mao SEM abrir o jogo.

Cada rodada de calibracao visual custa um restart do jogo, spawnar itens e uma
bateria de screenshots -- e devolve pouca informacao por rodada. Tres rodadas
foram gastas assim.

O renderizador de sprites deste repo (tools_render_iso_sprites.py) ja projeta a
malha na MESMA camera do PZ: azimute 45 graus, elevacao exatamente 30 (a que
produz o losango 2:1). Entao ele serve para prever a pose: se a projecao de uma
rotacao candidata bate com o que apareceu em jogo, o modelo esta calibrado e as
rotacoes seguintes podem ser escolhidas aqui.

O passo de VALIDACAO nao e opcional. A malha e girada em espaco de malha, e o
osso da mao pode adicionar uma rotacao fixa propria que este script nao conhece.
Reproduzir uma pose observada e o que prova que essa rotacao extra e identidade
-- sem isso, as previsoes daqui sao chute com aparencia de medicao.

Uso:
    python tools_preview_hand_pose.py saida.png rx1,ry1,rz1 rx2,ry2,rz2 ...
"""
import json
import math
import sys

from PIL import Image, ImageDraw

import tools_render_iso_sprites as iso

# So os quatro azimutes cardinais. O objetivo aqui e julgar a POSE, e oito
# vistas em uma folha deixam cada uma pequena demais para isso.
VIEWS = [("NW", 0.0), ("SW", 90.0), ("SE", 180.0), ("NE", 270.0)]

LABEL_H = 18


def rotate(verts, rx, ry, rz):
    """Mesma convencao de tools_fbx_shift.py: X, depois Y, depois Z.

    Duplicada de proposito em vez de importada: lá a rotacao esta acoplada a
    reescrita do FBX. O que precisa casar entre os dois arquivos e a ORDEM dos
    eixos, e e nela que um erro passaria despercebido -- um numero escolhido
    aqui seria aplicado torto la.
    """
    ax, ay, az = (math.radians(v) for v in (rx, ry, rz))
    out = list(verts)
    for i in range(0, len(out) - 2, 3):
        x, y, z = out[i], out[i + 1], out[i + 2]
        if ax:
            c, s = math.cos(ax), math.sin(ax)
            y, z = y * c - z * s, y * s + z * c
        if ay:
            c, s = math.cos(ay), math.sin(ay)
            x, z = x * c + z * s, -x * s + z * c
        if az:
            c, s = math.cos(az), math.sin(az)
            x, y = x * c - y * s, x * s + y * c
        out[i], out[i + 1], out[i + 2] = x, y, z
    return out


def sheet(mesh_path, texture_path, poses, out_path):
    base = json.load(open(mesh_path))
    texture = Image.open(texture_path).convert("RGB")

    cell_w, cell_h = iso.SPRITE_W, iso.SPRITE_H
    img = Image.new("RGB",
                    (cell_w * len(VIEWS), (cell_h + LABEL_H) * len(poses)),
                    (58, 58, 62))
    draw = ImageDraw.Draw(img)

    for row, (rx, ry, rz) in enumerate(poses):
        mesh = dict(base)
        mesh["V"] = rotate(base["V"], rx, ry, rz)
        # Escala comum entre TODAS as vistas e poses seria o ideal, mas
        # common_scale ja resolve por pose -- e comparar poses entre si e
        # comparar orientacao, nao tamanho.
        scale = iso.common_scale(mesh)
        y0 = row * (cell_h + LABEL_H)
        draw.text((6, y0 + 4),
                  "X=%.0f  Y=%.0f  Z=%.0f" % (rx, ry, rz), fill=(235, 235, 235))
        for col, (name, az) in enumerate(VIEWS):
            cell = iso.render(mesh, texture, az, scale)
            img.paste(cell.convert("RGB"), (col * cell_w, y0 + LABEL_H), cell)
            draw.text((col * cell_w + 6, y0 + LABEL_H + 4), name,
                      fill=(255, 210, 120))
    img.save(out_path)
    return img.size


if __name__ == "__main__":
    poses = [tuple(float(v) for v in a.split(",")) for a in sys.argv[4:]]
    print("preview %dx%d -> %s" % (
        sheet(sys.argv[1], sys.argv[2], poses, sys.argv[3]) + (sys.argv[3],)))
