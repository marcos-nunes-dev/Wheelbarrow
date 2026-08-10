--[[ GERADO por assets/tools_gen_pose_grid.py -- nao editar a mao.
     Descartavel: sai antes de publicar com WB_PoseLab.lua.

     Este grid varre TRANSLACAO; a rotacao ja esta resolvida em
     (270, 0, 0). A ordem e X mais externo, Y no meio, Z mais interno,
     e o Lua recalcula o indice a partir dela -- mexer aqui sem
     mexer la faz o texto na tela mentir sobre a malha. ]]
return {
    prefix = "MNWheelbarrow.Pose",
    kind = "translacao",
    x = { -0.40, 0.00, 0.40 },
    y = { -0.80, -0.40, 0.00, 0.40, 0.80 },
    z = { 0.52, 0.64, 0.76, 0.88, 1.00, 1.12 },
}
