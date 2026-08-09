--[[
    Constantes que NAO sao ajustaveis pelo jogador.

    Regra rigida: nenhum numero de balanceamento entra aqui. Tudo que o
    jogador pode ajustar mora em sandbox-options.txt e so la. Este arquivo
    guarda identificadores e nomes -- coisas que, se mudassem, quebrariam
    saves ou o contrato com os scripts .txt.
]]

local WB_Const = {}

--- Itens que se comportam como carrinho.
---
--- NAO usamos hasTag() aqui. Na B42 a assinatura e hasTag(ItemTag), e passar
--- uma string levanta "No implementation found for function: hasTag(...,
--- java.lang.String)". O padrao hasTag("nomeDaTag") que se ve em mods antigos
--- e de B41. Existe ItemTag.register(String), mas depender dele custaria mais
--- uma rodada de tentativa e erro sem ganho real.
---
--- Um registro por fullType entrega o mesmo que a tag entregaria: adicionar um
--- segundo carrinho (de supermercado, carroca) continua sendo acrescentar uma
--- linha de dado aqui, sem tocar em logica.
---
--- A linha `Tags = MNWheelbarrow:mnwbHauler` continua no script do item de
--- proposito: nao custa nada e deixa outros mods detectarem o carrinho.
WB_Const.HAULER_TYPES = {
    ["MNWheelbarrow.Wheelbarrow"] = true,
}

--- Namespace das sandbox options. Precisa bater com o "page" e com o prefixo
--- dos nomes de option em sandbox-options.txt.
WB_Const.SANDBOX_NS = "MNWheelbarrow"

--- Teto de capacidade imposto pelo engine, verificado em runtime e nao so no
--- parser de script. O limite efetivo de um item e este valor menos o peso do
--- proprio item. Nao e ajustavel -- e um fato do jogo, nao uma escolha nossa,
--- e por isso mora aqui e nao em sandbox-options.txt.
WB_Const.ENGINE_CAPACITY_CEILING = 50

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
