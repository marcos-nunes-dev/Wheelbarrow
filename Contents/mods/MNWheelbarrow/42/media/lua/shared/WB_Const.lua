--[[
    Constantes que NAO sao ajustaveis pelo jogador.

    Regra rigida: nenhum numero de balanceamento entra aqui. Tudo que o
    jogador pode ajustar mora em sandbox-options.txt e so la. Este arquivo
    guarda identificadores e nomes -- coisas que, se mudassem, quebrariam
    saves ou o contrato com os scripts .txt.
]]

local WB_Const = {}

--- Tag declarada no script como "MNWheelbarrow:mnwbHauler".
--- O engine remove o prefixo de modulo na consulta, entao hasTag() usa o
--- nome puro. O prefixo "mnwb" evita colisao com tags de outros mods.
WB_Const.TAG = "mnwbHauler"

--- Namespace das sandbox options. Precisa bater com o "page" e com o prefixo
--- dos nomes de option em sandbox-options.txt.
WB_Const.SANDBOX_NS = "MNWheelbarrow"

--- ID completo do item. NUNCA mudar depois de publicado: saves guardam o item
--- por este nome, e renomear transforma carrinhos existentes em itens orfaos.
WB_Const.ITEM_FULL_TYPE = "MNWheelbarrow.Wheelbarrow"

--- Rooms onde o carrinho pode aparecer solto no mundo (Fase E).
--- Nomes reais da lista de rooms da B42.
WB_Const.SPAWN_ROOMS = {
    construction = true,
    warehouse = true,
    storageunit = true,
    shed = true,
    garage = true,
    garagestorage = true,
    toolstore = true,
    toolstorestorage = true,
    loggingwarehouse = true,
    factorystorage = true,
    metalfabricationstorage = true,
}

--- Chave de ModData usada para marcar chunks ja processados pelo spawner,
--- para o mesmo lugar nunca gerar dois carrinhos.
WB_Const.MODDATA_SPAWN_KEY = "MNWheelbarrow_spawnedChunks"

--- Nome do modulo de comandos cliente->servidor.
WB_Const.COMMAND_MODULE = "MNWheelbarrow"

return WB_Const
