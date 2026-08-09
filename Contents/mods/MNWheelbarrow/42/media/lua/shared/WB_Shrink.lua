--[[
    Reduz o peso real dos itens pesados enquanto eles estao dentro do carrinho.

    POR QUE ISTO EXISTE:
    a capacidade de um container tem teto de 50 no engine, validado em runtime --
    setCapacity acima disso e recusado. Dois geradores somam 80 e nunca caberiam.
    A unica forma de faze-los caber e diminuir o peso que eles declaram.

    A cadeia que o engine usa para contabilizar capacidade foi verificada no jar:

        ItemContainer.getCapacityWeight()
          -> ItemContainer.getContentsWeight()
            -> InventoryItem.getUnequippedWeight()
              -> InventoryItem.getActualWeight()
                -> campo actualWeight        <- que setActualWeight() escreve

    ISTO E DELIBERADAMENTE ARRISCADO. Alterar o peso de um item e uma mudanca de
    estado persistente: o valor vai para o save. Se o mod for removido enquanto
    houver itens encolhidos, eles ficam leves para sempre naquele save. Nao ha
    como evitar isso -- codigo removido nao roda. As protecoes abaixo cobrem tudo
    o que ainda e possivel cobrir.

    COMO ISTO SE AUTO-CORRIGE:
    guardamos o peso ORIGINAL no ModData do proprio item, nunca um multiplicador.
    Restaurar e sempre escrever o valor guardado de volta -- entao nao existe
    deriva por aplicar duas vezes, e a operacao e idempotente. A reconciliacao
    varre o inventario do jogador e restaura qualquer item marcado que nao esteja
    mais dentro de um carrinho. Um item largado no chao encolhido volta ao normal
    assim que alguem o pega, porque ai ele entra num inventario e e varrido.
]]

local WB_Const = require "WB_Const"

--- Chave no ModData do item. Guarda o peso ORIGINAL, nao o fator aplicado.
local ORIG_KEY = "MNWB_origWeight"

local WB_Shrink = {}

--- Peso que o item teria fora do carrinho.
--- Toda decisao de "isto e pesado?" precisa usar este valor, nunca
--- getActualWeight() direto: um tronco de 9 encolhido para 3.6 cairia abaixo do
--- limite de 8 e perderia a reducao de peso -- o item deixaria de ser tratado
--- como pesado justamente por estar sendo carregado como pesado.
function WB_Shrink.originalWeight(item)
    if item:hasModData() then
        local orig = item:getModData()[ORIG_KEY]
        if orig ~= nil then return orig end
    end
    return item:getActualWeight()
end

function WB_Shrink.isShrunk(item)
    return item:hasModData() and item:getModData()[ORIG_KEY] ~= nil
end

--- @param factor number fracao do peso original mantida dentro do carrinho
function WB_Shrink.apply(item, factor)
    if WB_Shrink.isShrunk(item) then return end
    local orig = item:getActualWeight()
    item:getModData()[ORIG_KEY] = orig
    item:setActualWeight(orig * factor)
end

function WB_Shrink.restore(item)
    if not item:hasModData() then return end
    local md = item:getModData()
    local orig = md[ORIG_KEY]
    if orig == nil then return end
    item:setActualWeight(orig)
    md[ORIG_KEY] = nil
end

--- Reconcilia um container inteiro, recursivamente.
---
--- A regra e escrita de forma que o estado correto seja sempre recalculado do
--- zero, nunca incrementado: dentro de carrinho e pesado -> encolhido; qualquer
--- outro caso -> restaurado. Isso faz a funcao se auto-corrigir depois de um
--- crash, de uma transferencia interrompida ou de o jogador mudar o limite de
--- peso nas opcoes no meio da partida.
---
--- @param insideHauler boolean se `container` pertence a um carrinho
function WB_Shrink.reconcile(container, insideHauler, factor, threshold, depth)
    depth = depth or 0
    if container == nil or depth > 3 then return end

    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)

        if insideHauler and WB_Shrink.originalWeight(it) >= threshold then
            WB_Shrink.apply(it, factor)
        else
            WB_Shrink.restore(it)
        end

        -- Uma mochila dentro do carrinho tem o proprio peso encolhido, mas o
        -- conteudo dela nao: a recursao passa insideHauler = false, entao os
        -- itens la dentro sao restaurados.
        if instanceof(it, "InventoryContainer") then
            local childIsHauler = WB_Const.HAULER_TYPES[it:getFullType()] == true
            WB_Shrink.reconcile(it:getInventory(), childIsHauler, factor, threshold, depth + 1)
        end
    end
end

return WB_Shrink
