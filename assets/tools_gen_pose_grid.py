"""Gera o grid de poses que o laboratorio em jogo percorre.

POR QUE UM GRID EM VEZ DE TENTATIVAS:

A pose do item na mao e assada na malha. Nao ha caminho declarativo: o bloco
`attachment Bip01_Prop2` foi testado com oito rotacoes e as oito renderizaram
IDENTICAS, provando que o engine o ignora no caminho StaticModel-na-mao. E malha
e script so recarregam no boot, entao cada tentativa custava um RESTART. A saida
e assar todas as poses de uma vez e trocar o ITEM em runtime, que o Lua faz.

ESTADO: a ROTACAO esta resolvida. Este grid varre a TRANSLACAO.

Como a rotacao foi fechada, e por que a translacao e o que resta:

  1. As 24 rotacoes alinhadas aos eixos falharam todas -- previsivel, porque a
     pose e B . R . malha e B e a orientacao do osso da mao, a pose de um BRACO
     numa animacao. B nao e alinhado, logo R nao e.

  2. Do grid de 72 (X nas duas escolhas plausiveis, inclinacao fina, cabeceira em
     passo de 30) saiu X = 270, Y = 0, Z = 0 como melhor orientacao.

  3. Duas observacoes fecharam a geometria, e elas sao MEDICAO. As poses 49 e 19
     daquele grid diferem apenas no SINAL DE Z:

         pose 49  (270, 0,   0)   corpo em Z [-0.76, 0]   de pe, flutuando
         pose 19  ( 90, 0, 180)   corpo em Z [ 0, 0.76]   de cabeca para baixo,
                                                          encostado no chao

     X e Y sao identicos nas duas. Entao:

       - +Z e a direcao PARA BAIXO no mundo. A pose 49 fica no ar porque o corpo
         inteiro dela esta do lado negativo, ou seja acima do ponto de apoio.
       - o eixo de cima da malha aponta para -Z na 49 (de pe) e para +Z na 19
         (invertido), o que explica as duas de uma vez.
       - a pose 19 pendura 0.76 abaixo da mao e ENCOSTA no chao, logo a mao esta
         a 0.76 unidades de malha do chao. Esse e o deslocamento que a pose 49
         precisa, e ele foi medido, nao estimado.

     Isso confirma a leitura da rodada 1 -- "+Z afundou o carrinho" -- que na
     epoca eu descartei por achar que contradizia as outras observacoes.

O grid abaixo cerca 0.76 em Z e varre os dois eixos horizontais, que nao tem
medicao: Y (o comprimento do carrinho, logo frente/tras) e X (lateral).

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

# Rotacao resolvida -- ver o cabecalho. Nao varia mais neste grid.
ROTATION = (270, 0, 0)

# Os tres eixos do grid, cada um com um par de teclas proprio.
#
# Z: altura. +Z desce. 0.76 e a altura medida da mao, entao a base do carrinho
#    encosta no chao ali. O alcance so cerca esse valor, para absorver o erro de
#    onde exatamente fica a base do modelo.
# Y: frente/tras. E o eixo do COMPRIMENTO do carrinho nesta rotacao, logo e o que
#    tira o carrinho de dentro do personagem e o poe a frente. Sem medicao, entao
#    alcance simetrico.
# X: lateral. A mao e a direita, entao provavelmente precisa de correcao para
#    centralizar -- mas pouca.
AXIS_Z = [0.52, 0.64, 0.76, 0.88, 1.00, 1.12]
AXIS_Y = [-0.8, -0.4, 0.0, 0.4, 0.8]
AXIS_X = [-0.4, 0.0, 0.4]

HEADER = (
    "/*\n"
    " * GRID DE POSES -- gerado por assets/tools_gen_pose_grid.py. DESCARTAVEL.\n"
    " *\n"
    " * Uma malha por pose, porque a pose e assada na malha e script so recarrega\n"
    " * no boot. O grid existe para que a varredura inteira caiba em UM restart:\n"
    " * o Lua troca o item, ver WB_PoseLab.lua.\n"
    " *\n"
    " * NAO EDITAR A MAO: regerar pelo script -- os numeros aqui e os assados nas\n"
    " * malhas tem de continuar sendo os mesmos.\n"
    " * NAO PUBLICAR: sai junto com WB_PoseLab.lua antes do upload.\n"
    " */\n"
)


def poses():
    """Ordem estavel: X mais externo, Y no meio, Z mais interno.

    O Lua recalcula o indice a partir dela, entao esta funcao e o layout de la
    precisam bater. Uma unica definicao para as duas coisas.
    """
    return [(dx, dy, dz)
            for dx in AXIS_X
            for dy in AXIS_Y
            for dz in AXIS_Z]


def main():
    grid = poses()
    print("%d poses (%d x %d x %d), rotacao fixa %s"
          % (len(grid), len(AXIS_X), len(AXIS_Y), len(AXIS_Z), ROTATION))

    for old in os.listdir(OUT_DIR):
        if old.startswith("WB_Pose"):
            os.remove(os.path.join(OUT_DIR, old))

    rx, ry, rz = ROTATION
    for i, (dx, dy, dz) in enumerate(grid, 1):
        shift(SRC, os.path.join(OUT_DIR, "WB_Pose%03d.fbx" % i),
              dx, dy, dz, rx, ry, rz)

    def label(i, t):
        return "    /* %3d:  X %+5.2f  Y %+5.2f  Z %+5.2f */\n" % ((i,) + t)

    with open(os.path.join(SCRIPTS, "models_wheelbarrow_poses.txt"), "w",
              encoding="utf-8") as fh:
        fh.write("module Base\n{\n" + HEADER)
        for i, t in enumerate(grid, 1):
            fh.write(label(i, t))
            fh.write("    model WB_Pose%03d { mesh = WorldItems/WB_Pose%03d,"
                     " texture = WorldItems/Wheelbarrow, scale = 0.0057, }\n"
                     % (i, i))
        fh.write("}\n")

    with open(os.path.join(SCRIPTS, "items_wheelbarrow_poses.txt"), "w",
              encoding="utf-8") as fh:
        fh.write("module MNWheelbarrow\n{\n    imports { Base }\n" + HEADER)
        for i, t in enumerate(grid, 1):
            fh.write(label(i, t))
            fh.write("    item Pose%03d { DisplayCategory = Container,"
                     " ItemType = base:container, Weight = 3.0, Icon = Toolbox,"
                     " Capacity = 20, WorldStaticModel = MNWheelbarrow_Ground,"
                     " StaticModel = WB_Pose%03d,"
                     " primaryAnimMask = holdingbagright, }\n" % (i, i))
        fh.write("}\n")

    with open(os.path.join(LUA, "WB_PoseGrid.lua"), "w", encoding="utf-8") as fh:
        fh.write("--[[ GERADO por assets/tools_gen_pose_grid.py -- nao editar a mao.\n"
                 "     Descartavel: sai antes de publicar com WB_PoseLab.lua.\n\n"
                 "     Este grid varre TRANSLACAO; a rotacao ja esta resolvida em\n"
                 "     %s. A ordem e X mais externo, Y no meio, Z mais interno,\n"
                 "     e o Lua recalcula o indice a partir dela -- mexer aqui sem\n"
                 "     mexer la faz o texto na tela mentir sobre a malha. ]]\n"
                 % (ROTATION,))
        fh.write("return {\n")
        fh.write("    prefix = \"MNWheelbarrow.Pose\",\n")
        fh.write("    kind = \"translacao\",\n")
        for name, values in (("x", AXIS_X), ("y", AXIS_Y), ("z", AXIS_Z)):
            fh.write("    %s = { %s },\n"
                     % (name, ", ".join("%.2f" % v for v in values)))
        fh.write("}\n")

    print("gerados %d .fbx, 2 scripts e WB_PoseGrid.lua" % len(grid))


if __name__ == "__main__":
    main()
