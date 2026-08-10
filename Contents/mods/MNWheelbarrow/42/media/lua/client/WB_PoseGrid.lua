--[[ GERADO por assets/tools_gen_pose_grid.py -- nao editar a mao.
     Descartavel: sai antes de publicar com WB_PoseLab.lua.

     A ordem e X mais externo, Y no meio, Z mais interno. O Lua
     recalcula o indice a partir dela, entao mexer aqui sem mexer
     la faz o texto na tela mentir sobre a malha mostrada. ]]
return {
    prefix = "MNWheelbarrow.Pose",
    x = { 90, 270 },
    y = { -20, 0, 20 },
    z = { 0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330 },
}
