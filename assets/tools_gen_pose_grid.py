"""Gera um grid de poses pre-assadas para calibrar a pose da mao em jogo.

POR QUE UM GRID EM VEZ DE TENTATIVAS:

A pose do item na mao e assada na malha. Nao ha como mudar em runtime: o bloco
`attachment Bip01_Prop2` -- que seria o caminho declarativo -- foi testado com
oito rotacoes e as oito renderizaram IDENTICAS, provando que o engine ignora
attachment no caminho StaticModel-na-mao.

Como a transformacao esta na malha e script so recarrega no boot, cada tentativa
custava um restart do jogo. Quatro rodadas foram gastas assim, tres variantes
por vez, e cada rodada media um espaco diferente da anterior porque rotacoes nao
comutam.

A saida e desacoplar o custo do restart da quantidade de tentativas: assar TODAS
as poses de uma vez, uma malha por pose, e trocar o ITEM em runtime -- isso o
Lua faz. Um restart, e a varredura inteira vira uma tecla.

As 24 rotacoes usadas sao o grupo proprio de rotacoes do cubo, ou seja todas as
orientacoes alinhadas aos eixos, sem repeticao. Elas cobrem toda pose "reta"; a
pose certa de um carrinho e quase certamente uma delas, e nao um angulo
quebrado. Angulo fino, se precisar, e um segundo grid mais estreito.

Uso:
    python tools_gen_pose_grid.py
"""
import itertools
import os

import numpy as np

from tools_fbx_shift import shift

SRC = "../Contents/mods/MNWheelbarrow/common/media/models_X/WorldItems/Wheelbarrow.fbx"
OUT_DIR = "../Contents/mods/MNWheelbarrow/common/media/models_X/WorldItems"
SCRIPTS = "../Contents/mods/MNWheelbarrow/42/media/scripts"


def euler_matrix(rx, ry, rz):
    """Mesma ordem que tools_fbx_shift.py aplica: X, depois Y, depois Z."""
    out = np.eye(3)
    for axis, ang in ((0, rx), (1, ry), (2, rz)):
        c, s = np.cos(np.radians(ang)), np.sin(np.radians(ang))
        if axis == 0:
            m = np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
        elif axis == 1:
            m = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
        else:
            m = np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
        out = m @ out
    return out


def distinct_axis_rotations():
    """As 24 rotacoes proprias do cubo, deduplicadas pela MATRIZ.

    Enumerar (rx, ry, rz) em multiplos de 90 da 64 combinacoes, das quais so 24
    sao distintas -- Euler nao e injetivo. Deduplicar pela matriz, e nao pelos
    angulos, e o que garante 24 poses realmente diferentes na tela.
    """
    seen = {}
    for rx, ry, rz in itertools.product((0, 90, 180, 270), repeat=3):
        key = tuple(np.round(euler_matrix(rx, ry, rz), 6).flatten())
        if key not in seen:
            seen[key] = (rx, ry, rz)
    return sorted(seen.values())


def main():
    poses = distinct_axis_rotations()
    print("%d rotacoes distintas" % len(poses))

    for i, (rx, ry, rz) in enumerate(poses, 1):
        dst = os.path.join(OUT_DIR, "WB_Pose%02d.fbx" % i)
        shift(SRC, dst, 0.0, 0.0, 0.0, rx, ry, rz)

    header = (
        "/*\n"
        " * GRID DE POSES -- gerado por assets/tools_gen_pose_grid.py, DESCARTAVEL.\n"
        " *\n"
        " * Uma malha por orientacao alinhada aos eixos (as 24 rotacoes proprias do\n"
        " * cubo). Existe porque a pose da mao e assada na malha e script so recarrega\n"
        " * no boot: sem o grid, cada tentativa custa um restart. Com ele, a varredura\n"
        " * inteira e uma tecla -- ver WB_PoseLab.lua.\n"
        " *\n"
        " * NAO EDITAR A MAO: regerar pelo script. E NAO PUBLICAR: sai junto com\n"
        " * WB_PoseLab.lua e items_wheelbarrow_test.txt antes do upload.\n"
        " */\n"
    )

    with open(os.path.join(SCRIPTS, "models_wheelbarrow_poses.txt"), "w",
              encoding="utf-8") as fh:
        fh.write("module Base\n{\n")
        fh.write(header)
        for i, (rx, ry, rz) in enumerate(poses, 1):
            fh.write("    /* %3d,%4d,%4d */\n" % (rx, ry, rz))
            fh.write("    model WB_Pose%02d { mesh = WorldItems/WB_Pose%02d,"
                     " texture = WorldItems/Wheelbarrow, scale = 0.0057, }\n"
                     % (i, i))
        fh.write("}\n")

    with open(os.path.join(SCRIPTS, "items_wheelbarrow_poses.txt"), "w",
              encoding="utf-8") as fh:
        fh.write("module MNWheelbarrow\n{\n    imports { Base }\n")
        fh.write(header)
        for i, (rx, ry, rz) in enumerate(poses, 1):
            fh.write("    /* %3d,%4d,%4d */\n" % (rx, ry, rz))
            fh.write("    item Pose%02d { DisplayCategory = Container,"
                     " ItemType = base:container, Weight = 3.0, Icon = Toolbox,"
                     " Capacity = 20, WorldStaticModel = MNWheelbarrow_Ground,"
                     " StaticModel = WB_Pose%02d,"
                     " primaryAnimMask = holdingbagright, }\n" % (i, i))
        fh.write("}\n")

    # A tabela que o Lua le para mostrar os angulos na tela. Gerada aqui, no
    # mesmo lugar que assa as malhas, para os numeros nao poderem divergir.
    with open("../Contents/mods/MNWheelbarrow/42/media/lua/client/WB_PoseGrid.lua",
              "w", encoding="utf-8") as fh:
        fh.write("--[[ GERADO por assets/tools_gen_pose_grid.py -- nao editar a mao.\n"
                 "     Descartavel: sai antes de publicar, junto com WB_PoseLab.lua. ]]\n")
        fh.write("return {\n")
        for i, (rx, ry, rz) in enumerate(poses, 1):
            fh.write("    { id = \"MNWheelbarrow.Pose%02d\", rx = %d, ry = %d, rz = %d },\n"
                     % (i, rx, ry, rz))
        fh.write("}\n")

    print("gerados %d .fbx, 2 scripts e WB_PoseGrid.lua" % len(poses))


if __name__ == "__main__":
    main()
