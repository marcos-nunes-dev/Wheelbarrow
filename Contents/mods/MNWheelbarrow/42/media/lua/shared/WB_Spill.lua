--[[
    Derrama o conteudo do carrinho no chao.

    Usado quando o jogador CANCELA a acao de pegar ou de largar: o carrinho
    desequilibra e a carga vai ao chao. E a punicao por interromper a manobra, e
    o que da peso a decisao de parar no meio.

    POR QUE ESPALHA EM VEZ DE JOGAR TUDO NUMA SQUARE:

    O jogo limita o peso de itens no chao POR SQUARE. Esta em
    ISDropWorldItemAction:isValid():

        local ground = self.sq:getTotalWeightOfItemsOnFloor()
        if ground + self.item:getUnequippedWeight() > 50 then return false end

    Um carrinho cheio passa facil desse limite -- e o ponto dele e justamente
    carregar mais que isso. Despejar tudo numa square so criaria uma pilha que o
    proprio jogo considera invalida, e itens em square sobrecarregada tem
    comportamento imprevisivel ao salvar e recarregar.

    Entao o derrame respeita o mesmo orcamento que o jogo usa, e transborda para
    as squares vizinhas. Espalhar tambem e o que PARECE certo: carga que tomba
    de um carrinho rola para os lados.

    MULTIPLAYER: AddWorldInventoryItem e o caminho direto e e o que a maioria dos
    mods usa, mas nao passa pelo fluxo de acao do jogo. Num servidor dedicado
    vale conferir se os itens aparecem para os outros jogadores; se nao
    aparecerem, o conserto e enviar por comando cliente->servidor, e este arquivo
    e o unico lugar a mudar.
]]

local WB_Spill = {}

--- Mesmo teto que ISDropWorldItemAction usa para recusar um item no chao.
local SQUARE_WEIGHT_BUDGET = 50

--- Ordem de busca a partir da square de origem: o centro primeiro, depois os
--- oito vizinhos. Empilhar no centro ate o limite e so entao transbordar deixa a
--- pilha visualmente coerente com "caiu daqui".
local OFFSETS = {
    { 0, 0 },
    { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
    { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 },
}

--- @return IsoGridSquare|nil a primeira square com espaco para `weight`
local function squareWithRoom(origin, weight)
    local cell = getCell()
    if cell == nil then return nil end

    for _, offset in ipairs(OFFSETS) do
        local sq = cell:getGridSquare(
            origin:getX() + offset[1], origin:getY() + offset[2], origin:getZ())
        if sq ~= nil and not sq:isSolid() and not sq:isSolidTrans() then
            if sq:getTotalWeightOfItemsOnFloor() + weight <= SQUARE_WEIGHT_BUDGET then
                return sq
            end
        end
    end
    return nil
end

--- Esvazia o carrinho no chao ao redor de `origin`.
---
--- @param cart InventoryItem o carrinho
--- @param origin IsoGridSquare square de onde a carga cai
--- @return number quantos itens foram derramados
function WB_Spill.dump(cart, origin)
    if cart == nil or origin == nil then return 0 end
    local inv = cart:getInventory()
    if inv == nil then return 0 end

    -- Copia a lista ANTES de mexer: remover de um container enquanto se itera
    -- sobre ele pula elementos, porque os indices deslizam a cada remocao.
    local pending = {}
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        pending[#pending + 1] = items:get(i)
    end

    local dropped = 0
    for _, item in ipairs(pending) do
        local weight = item:getUnequippedWeight()
        local target = squareWithRoom(origin, weight) or origin
        inv:Remove(item)
        -- Deslocamento aleatorio dentro da square para a pilha nao virar uma
        -- coluna de itens exatamente sobrepostos.
        target:AddWorldInventoryItem(item, ZombRandFloat(0.1, 0.9),
            ZombRandFloat(0.1, 0.9), 0.0)
        dropped = dropped + 1
    end

    return dropped
end

return WB_Spill
