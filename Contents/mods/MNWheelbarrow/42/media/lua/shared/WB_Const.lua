--[[
    Identificadores do mod. NENHUM numero de balanceamento entra aqui.

    Regra rigida: tudo que o jogador pode ajustar mora em sandbox-options.txt e
    so la. Este arquivo guarda nomes e chaves -- coisas que, se mudassem,
    quebrariam saves ou o contrato com os scripts .txt.

    Havia aqui uma constante ENGINE_CAPACITY_CEILING = 50, e ela estava ERRADA.
    Ver WB_Weight.lua: o bytecode de ItemContainer.setCapacity mostra que 50 e
    apenas o limiar de um aviso de debug, nao um teto imposto.
]]

local WB_Const = {}

--- Itens que se comportam como carrinho.
---
--- NAO usamos hasTag() aqui. Na B42 a assinatura e hasTag(ItemTag), e passar
--- uma string levanta "No implementation found for function: hasTag(...,
--- java.lang.String)" -- o padrao hasTag("nome") que se ve em mods antigos e de
--- B41.
---
--- Um registro por fullType entrega o mesmo que a tag entregaria: adicionar um
--- segundo carrinho (de supermercado, carroca) e acrescentar uma linha de dado
--- aqui, sem tocar em logica nenhuma.
---
--- A linha `Tags = MNWheelbarrow:mnwbHauler` continua no script do item de
--- proposito: nao custa nada e deixa outros mods detectarem o carrinho.
--- O carrinho do mod. Nomeado porque o spawner precisa criar o item por tipo, e
--- uma segunda copia desta string e uma divergencia esperando acontecer.
WB_Const.CART_TYPE = "MNWheelbarrow.Wheelbarrow"

WB_Const.HAULER_TYPES = {
    [WB_Const.CART_TYPE] = true,
}

--- Namespace das sandbox options. Precisa bater com o "page" e com o prefixo
--- dos nomes de option em sandbox-options.txt.
WB_Const.SANDBOX_NS = "MNWheelbarrow"

--- Rooms onde o carrinho pode aparecer solto no mundo. Nomes reais da lista de
--- rooms da B42. Ainda nao usado -- e a Fase E do plano.
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

--- Chave de ModData que marca chunks ja processados pelo spawner, para o mesmo
--- lugar nunca gerar dois carrinhos. Fase E.
WB_Const.MODDATA_SPAWN_KEY = "MNWheelbarrow_spawnedChunks"

return WB_Const
