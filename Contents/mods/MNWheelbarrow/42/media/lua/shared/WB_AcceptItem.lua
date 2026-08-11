--[[
    Guarda-corpo de conteudo do carrinho.

    Este e o UNICO lugar que declara a tabela global MNWheelbarrow, e ela
    existe por um motivo especifico: items_wheelbarrow.txt referencia
    "MNWheelbarrow.AcceptItem" por nome, e scripts .txt so alcancam globais.
    Todo o resto do codigo usa require/return e nao polui o global.

    Duas coisas moram aqui: o que quebraria o jogo, e o TETO DE CARGA LEVE.

    POR QUE O TETO DE CARGA LEVE NAO E A CAPACIDADE: o engine tem UM numero de
    capacidade, comparado contra o peso bruto total. Ele nao consegue dizer "leve
    ate 50, total ate 200". Tentar simular isso mexendo na capacidade conforme o
    conteudo tem um defeito que so aparece na ordem errada: um carrinho com 50 kg
    de livros passaria a recusar um gerador, porque a capacidade teria encolhido
    para 50. Aqui a pergunta e feita por item, e a ordem deixa de importar.

    Item leve nao ganha reducao de peso (ver WB_Weight.lua) -- isso continua sendo
    o que torna o carrinho pouco atraente para tralha. O teto e o que impede o
    absurdo aritmetico de 200 livros.
]]

local WB_Const = require "WB_Const"
local WB_Repack = require "WB_Repack"
local WB_Sandbox = require "WB_Sandbox"

local CORPSES = {
    ["Base.CorpseMale"] = true,
    ["Base.CorpseFemale"] = true,
    ["Base.CorpseAnimal"] = true,
}

--- @return number peso bruto dos itens LEVES ja dentro do container
local function lightWeightInside(container, threshold)
    if container == nil then return 0.0 end
    local total = 0.0
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        -- Peso REAL: dentro do carrinho os itens estao reacondicionados, e somar o
        -- peso comprimido faria o teto de carga leve deixar entrar cinco vezes mais.
        local w = WB_Repack.realWeight(items:get(i))
        if w < threshold then total = total + w end
    end
    return total
end

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

    -- TETO DE CARGA LEVE. O limite de capacidade continua valendo para o total;
    -- este e um segundo teto, so para o que nao conta como pesado.
    local threshold = WB_Sandbox.get("HeavyThreshold")
    -- O item que esta ENTRANDO ainda nao foi reacondicionado, mas realWeight cobre os
    -- dois casos e deixa a regra insensivel a ordem.
    local weight = WB_Repack.realWeight(item)
    if weight < threshold then
        local budget = WB_Sandbox.get("LightCapacity")
        if budget > 0
            and lightWeightInside(container, threshold) + weight > budget then
            return false
        end
    end

    return true
end

return MNWheelbarrow
