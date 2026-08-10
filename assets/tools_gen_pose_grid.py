"""Gera o grid de poses que o laboratorio em jogo percorre.

POR QUE UM GRID EM VEZ DE TENTATIVAS:

A pose do item na mao e assada na malha. Nao ha caminho declarativo: o bloco
`attachment Bip01_Prop2` foi testado com oito rotacoes e as oito renderizaram
IDENTICAS, provando que o engine o ignora no caminho StaticModel-na-mao. E malha
e script so recarregam no boot, entao cada tentativa custava um RESTART.

A saida e desacoplar o custo do restart do numero de tentativas: assar todas as
poses de uma vez e trocar o ITEM em runtime, que e coisa que o Lua faz.

POR QUE O GRID NAO E MAIS AS 24 ROTACOES ALINHADAS AOS EIXOS:

A primeira versao gerava o grupo proprio de rotacoes do cubo -- as 24
orientacoes retas. Nenhuma das 24 ficou correta em jogo, e isso era previsivel:
a pose vista e B . R . malha, e B e a orientacao do osso da mao, que e a pose de
um BRACO numa animacao. B nao esta alinhado aos eixos, logo R = B^-1 . desejado
tambem nao esta. Um grid alinhado aos eixos nunca podia conter a resposta,
exceto por sorte.

Duas medicoes sobreviveram daquela rodada, e sao elas que definem este grid:

  pose  1 (identidade)  o carrinho pendurado, cabos para cima, eixo comprido
                        na diagonal -- logo B leva o eixo comprido da malha para
                        perto de baixo, mas NAO exatamente (a diagonal na tela
                        prova a inclinacao residual)
  pose 17 (Rx 90)       deitado no chao de barriga para cima -- eixo comprido ja
                        na horizontal, e o eixo de cima da malha invertido

Ou seja Rx(270) e a familia certa em X, e o que falta e um giro de CABECEIRA no
plano do chao mais uma inclinacao residual, ambos em angulo quebrado. Este grid
varre exatamente isso: X fixo nas duas escolhas plausiveis, inclinacao fina e
cabeceira em passo de 30 graus.

Uso:
    python tools_gen_pose_grid.py
"""
import os

import numpy as np

from tools_fbx_shift import shift

SRC = "../Contents/mods/MNWheelbarrow/common/media/models_X/WorldItems/Wheelbarrow.fbx"
OUT_DIR = "../Contents/mods/MNWheelbarrow/common/media/models_X/WorldItems"
SCRIPTS = "../Contents/mods/MNWheelbarrow/42/media/scripts"
LUA = "../Contents/mods/MNWheelbarrow/42/media/lua/client"

# Os tres eixos do grid, cada um navegavel por um par de teclas proprio.
#
# X: as duas escolhas plausiveis. 90 foi medido deitado de barriga para cima,
#    270 e o mesmo de barriga para baixo. Uma das duas e a certa; manter as duas
#    custa o dobro de malhas e elimina a chance de eu ter errado o sinal.
# Y: inclinacao residual. A diagonal da pose 1 na tela mostra que existe, e que
#    e pequena -- por isso passo fino e alcance curto.
# Z: cabeceira no plano do chao. Alcance completo, porque nao ha medicao dela.
AXIS_X = [90, 270]
AXIS_Y = [-20, 0, 20]
AXIS_Z = [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330]

HEADER = (
    "/*\n"
    " * GRID DE POSES -- gerado por assets/tools_gen_pose_grid.py. DESCARTAVEL.\n"
    " *\n"
    " * Uma malha por pose, porque a pose e assada na malha e script so recarrega\n"
    " * no boot. O grid existe para que a varredura inteira caiba em UM restart:\n"
    " * o Lua troca o item, ver WB_PoseLab.lua.\n"
    " *\n"
    " * NAO EDITAR A MAO: regerar pelo script -- os angulos aqui e os assados nas\n"
    " * malhas tem de continuar sendo os mesmos.\n"
    " * NAO PUBLICAR: sai junto com WB_PoseLab.lua antes do upload.\n"
    " */\n"
)


def poses():
    """Ordem estavel: X mais externo, depois Y, Z mais interno.

    O Lua recalcula o indice a partir dos tres eixos, entao a ordem aqui e o
    layout de la precisam bater. Uma funcao unica define as duas coisas.
    """
    out = []
    for rx in AXIS_X:
        for ry in AXIS_Y:
            for rz in AXIS_Z:
                out.append((rx, ry, rz))
    return out


def main():
    grid = poses()
    print("%d poses (%d x %d x %d)"
          % (len(grid), len(AXIS_X), len(AXIS_Y), len(AXIS_Z)))

    for old in os.listdir(OUT_DIR):
        if old.startswith("WB_Pose"):
            os.remove(os.path.join(OUT_DIR, old))

    for i, (rx, ry, rz) in enumerate(grid, 1):
        shift(SRC, os.path.join(OUT_DIR, "WB_Pose%03d.fbx" % i),
              0.0, 0.0, 0.0, rx, ry, rz)

    with open(os.path.join(SCRIPTS, "models_wheelbarrow_poses.txt"), "w",
              encoding="utf-8") as fh:
        fh.write("module Base\n{\n" + HEADER)
        for i, (rx, ry, rz) in enumerate(grid, 1):
            fh.write("    /* X %3d  Y %4d  Z %4d */\n" % (rx, ry, rz))
            fh.write("    model WB_Pose%03d { mesh = WorldItems/WB_Pose%03d,"
                     " texture = WorldItems/Wheelbarrow, scale = 0.0057, }\n"
                     % (i, i))
        fh.write("}\n")

    with open(os.path.join(SCRIPTS, "items_wheelbarrow_poses.txt"), "w",
              encoding="utf-8") as fh:
        fh.write("module MNWheelbarrow\n{\n    imports { Base }\n" + HEADER)
        for i, (rx, ry, rz) in enumerate(grid, 1):
            fh.write("    /* X %3d  Y %4d  Z %4d */\n" % (rx, ry, rz))
            fh.write("    item Pose%03d { DisplayCategory = Container,"
                     " ItemType = base:container, Weight = 3.0, Icon = Toolbox,"
                     " Capacity = 20, WorldStaticModel = MNWheelbarrow_Ground,"
                     " StaticModel = WB_Pose%03d,"
                     " primaryAnimMask = holdingbagright, }\n" % (i, i))
        fh.write("}\n")

    with open(os.path.join(LUA, "WB_PoseGrid.lua"), "w", encoding="utf-8") as fh:
        fh.write("--[[ GERADO por assets/tools_gen_pose_grid.py -- nao editar a mao.\n"
                 "     Descartavel: sai antes de publicar com WB_PoseLab.lua.\n\n"
                 "     A ordem e X mais externo, Y no meio, Z mais interno. O Lua\n"
                 "     recalcula o indice a partir dela, entao mexer aqui sem mexer\n"
                 "     la faz o texto na tela mentir sobre a malha mostrada. ]]\n")
        fh.write("return {\n")
        fh.write("    prefix = \"MNWheelbarrow.Pose\",\n")
        for name, values in (("x", AXIS_X), ("y", AXIS_Y), ("z", AXIS_Z)):
            fh.write("    %s = { %s },\n" % (name, ", ".join(str(v) for v in values)))
        fh.write("}\n")

    print("gerados %d .fbx, 2 scripts e WB_PoseGrid.lua" % len(grid))


if __name__ == "__main__":
    main()
