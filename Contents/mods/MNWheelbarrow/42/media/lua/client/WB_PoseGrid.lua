--[[ GERADO por assets/tools_gen_pose_grid.py -- nao editar a mao.
     Descartavel: sai antes de publicar com WB_PoseLab.lua.

     Este grid varre TRANSLACAO; a rotacao ja esta resolvida em
     (270, 0, 0). A ordem e X mais externo, Y no meio, Z mais interno,
     e o Lua recalcula o indice a partir dela -- mexer aqui sem
     mexer la faz o texto na tela mentir sobre a malha. ]]
return {
    prefix = "MNWheelbarrow.Pose",
    kind = "translacao",
    x = { 0.23, 0.25, 0.27, 0.29, 0.31, 0.33, 0.35, 0.37, 0.39, 0.41, 0.43, 0.45 },
    y = { 0.70, 0.80, 0.90 },
    z = { 0.56, 0.64, 0.72 },
}
