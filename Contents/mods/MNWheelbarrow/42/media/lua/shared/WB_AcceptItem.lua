--[[
    Guarda-corpo de conteudo do carrinho.

    Este e o UNICO lugar que declara a tabela global MNWheelbarrow, e ela
    existe por um motivo especifico: items_wheelbarrow.txt referencia
    "MNWheelbarrow.AcceptItem" por nome, e scripts .txt so alcancam globais.
    Todo o resto do codigo usa require/return e nao polui o global.

    Importante: isto NAO e o mecanismo que torna o carrinho inutil para itens
    leves. Itens leves entram normalmente -- eles so nao ganham reducao de peso
    nenhuma (ver WB_Weight.lua). Aqui so bloqueamos o que quebraria o jogo.
]]

local WB_Const = require "WB_Const"

local CORPSES = {
    ["Base.CorpseMale"] = true,
    ["Base.CorpseFemale"] = true,
    ["Base.CorpseAnimal"] = true,
}

MNWheelbarrow = MNWheelbarrow or {}

--- Chamado pelo engine para cada item que o jogador tenta colocar no carrinho.
--- @param container ItemContainer inventario do carrinho (nao usado hoje)
--- @param item InventoryItem item sendo inserido
--- @return boolean true se o item pode entrar
function MNWheelbarrow.AcceptItem(container, item)
    if item == nil then return false end

    -- Carrinho dentro de carrinho: recursao no calculo de peso e capacidade.
    -- Este e o unico bloqueio que existe por necessidade tecnica.
    if WB_Const.HAULER_TYPES[item:getFullType()] then
        return false
    end

    -- Cadaver e escolha de jogo, nao limitacao tecnica: tematicamente um
    -- carrinho de mao e exatamente o que alguem usaria. Fica desligado por
    -- padrao para nao mudar o equilibrio do jogo sem o jogador pedir.
    if CORPSES[item:getFullType()] then
        local sv = SandboxVars and SandboxVars[WB_Const.SANDBOX_NS]
        return sv ~= nil and sv.AllowCorpses == true
    end

    return true
end

return MNWheelbarrow
