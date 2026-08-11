"""Gera o grid de calibracao LATERAL, para ajustar em jogo com uma tecla.

POR QUE UM GRID: a pose do carrinho na mao esta assada na malha, e malha so
recarrega no boot. Sem grid, cada tentativa custa um restart do jogo. Com ele, a
varredura inteira cabe numa sessao -- o Lua troca o ITEM, que e coisa que da para
fazer em runtime, e cada item aponta para uma malha diferente.

POR QUE SO O EIXO X AGORA: altura e avanco ja convergiram e nao sao mais duvida.
O lateral virou duvida de novo quando a animacao de dois bracos entrou, porque com
os dois bracos na pose o personagem ficou visivelmente descentrado em relacao ao
carrinho. Eu chutei a direcao do ajuste e errei o sinal; a saida honesta e medir
em vez de chutar de novo.

O intervalo cerca o valor atual DOS DOIS LADOS justamente por isso: varrer so um
lado repetiria o erro.

Uso:
    python tools_gen_pose_grid.py
"""
import os

from tools_build_models import HAND_OFFSET, HAND_ROTATION, OUT_MODELS, SOURCE
from tools_fbx_shift import shift

SCRIPTS = "../Contents/mods/MNWheelbarrow/42/media/scripts"
LUA = "../Contents/mods/MNWheelbarrow/42/media/lua/client"

AXIS_X = [0.16, 0.21, 0.26, 0.31, 0.36, 0.41, 0.46, 0.51]

HEADER = (
    "/*\n"
    " * GRID DE CALIBRACAO LATERAL -- gerado por assets/tools_gen_pose_grid.py.\n"
    " * DESCARTAVEL: sai junto com WB_PoseLab.lua antes de publicar.\n"
    " *\n"
    " * Uma malha por valor de X. Todas com o mesmo giro e a mesma altura do item\n"
    " * real; so o lateral muda, entao qualquer diferenca vista vem dele.\n"
    " */\n"
)


def main():
    for old in os.listdir(OUT_MODELS):
        if old.startswith("WB_PoseX"):
            os.remove(os.path.join(OUT_MODELS, old))

    rx, ry, rz = HAND_ROTATION
    _dx, dy, dz = HAND_OFFSET

    for i, x in enumerate(AXIS_X, 1):
        shift(SOURCE, os.path.join(OUT_MODELS, "WB_PoseX%02d.fbx" % i),
              x, dy, dz, rx, ry, rz)

    with open(os.path.join(SCRIPTS, "models_wheelbarrow_poses.txt"), "w",
              encoding="utf-8") as fh:
        fh.write("module Base\n{\n" + HEADER)
        for i, x in enumerate(AXIS_X, 1):
            fh.write("    /* X = %.2f */\n" % x)
            fh.write("    model WB_PoseX%02d { mesh = WorldItems/WB_PoseX%02d,"
                     " texture = WorldItems/Wheelbarrow_Hand, scale = 0.00499, }\n"
                     % (i, i))
        fh.write("}\n")

    with open(os.path.join(SCRIPTS, "items_wheelbarrow_poses.txt"), "w",
              encoding="utf-8") as fh:
        fh.write("module MNWheelbarrow\n{\n    imports { Base }\n" + HEADER)
        for i, x in enumerate(AXIS_X, 1):
            fh.write("    /* X = %.2f */\n" % x)
            fh.write("    item PoseX%02d { DisplayCategory = Container,"
                     " ItemType = base:container, Weight = 3.0, Icon = Toolbox,"
                     " Capacity = 50, WorldStaticModel = MNWheelbarrow_Ground,"
                     " StaticModel = WB_PoseX%02d,"
                     " primaryAnimMask = mnwb_holdingcart,"
                     " RequiresEquippedBothHands = TRUE, }\n" % (i, i))
        fh.write("}\n")

    with open(os.path.join(LUA, "WB_PoseGrid.lua"), "w", encoding="utf-8") as fh:
        fh.write("--[[ GERADO por assets/tools_gen_pose_grid.py; nao editar a mao.\n"
                 "     Descartavel: sai antes de publicar com WB_PoseLab.lua. ]]\n")
        fh.write("return {\n    prefix = \"MNWheelbarrow.PoseX\",\n    x = { %s },\n}\n"
                 % ", ".join("%.2f" % v for v in AXIS_X))

    print("%d variantes de X: %s" % (len(AXIS_X), AXIS_X))


if __name__ == "__main__":
    main()
