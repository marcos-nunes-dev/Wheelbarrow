--[[
    Opcoes de menu para pegar e largar o carrinho com animacao.

    O jogo ja tem "pegar" e "largar" instantaneos, e eles continuam funcionando.
    Estas opcoes existem porque a versao cronometrada e a que pode ser
    CANCELADA -- e o cancelamento e o que derrama a carga. Sem uma acao que leve
    tempo nao existe momento em que interromper signifique alguma coisa.

    Fica em client/ porque menu de contexto e interface.
]]

require "TimedActions/ISWheelbarrowPickUp"
require "TimedActions/ISWheelbarrowPutDown"

local WB_Cart = require "WB_Cart"

local WB_ContextMenu = {}

local function startPickUp(_, player, worldItem)
    local character = getSpecificPlayer(player)
    if character == nil then return end
    -- Andar ate o carrinho antes de agachar. Sem isto a acao roda a distancia e
    -- o personagem pega no ar.
    ISTimedActionQueue.add(ISWalkToTimedAction:new(
        character, worldItem:getSquare()))
    ISTimedActionQueue.add(ISWheelbarrowPickUp:new(character, worldItem))
end

--[[
    Equipar pelo menu do jogo passa a usar a acao cronometrada.

    O primeiro corte deixou a acao so nas opcoes proprias, e o resultado foi o
    esperado em retrospecto: o jogador usou "Equip Two Hands", que e a opcao
    obvia e continua instantanea, e cancelar nao derramou nada. A punicao existia
    num caminho que ninguem percorria.

    Em vez de esconder a opcao do jogo -- que e a boa, e que o proprio Marcos
    preferiu por ser mais intuitiva -- trocamos o que ela FAZ quando o item e um
    carrinho. Assim so ha um jeito de por o carrinho nas maos, e ele leva tempo.

    O envelope preserva o comportamento original para todo o resto: qualquer
    outro item continua no caminho do jogo, e outros mods que tambem envolvam
    esta funcao continuam encadeados.
]]
Events.OnGameStart.Add(function()
    if ISInventoryPaneContextMenu == nil then return end

    local original = ISInventoryPaneContextMenu.OnTwoHandsEquip
    ISInventoryPaneContextMenu.OnTwoHandsEquip = function(items, player)
        local character = getSpecificPlayer(player)
        -- getActualItems desempacota os grupos empilhados da lista do menu; sem
        -- isso o primeiro elemento pode ser a tabela do grupo, e nao um item.
        local actual = ISInventoryPane.getActualItems(items)
        local first = actual and actual[1]

        if character ~= nil and WB_Cart.is(first) then
            ISTimedActionQueue.add(
                ISWheelbarrowPickUp:new(character, nil, first))
            return
        end
        return original(items, player)
    end
end)

local function startPutDown(_, player, item)
    local character = getSpecificPlayer(player)
    if character == nil then return end
    ISTimedActionQueue.add(ISWheelbarrowPutDown:new(character, item))
end

--- Carrinho largado numa square: oferece pegar com animacao.
Events.OnFillWorldObjectContextMenu.Add(function(player, context, worldobjects, _test)
    local seen = {}
    for _, obj in ipairs(worldobjects) do
        -- getWorldObjects entrega piso, parede e movel junto. Sem o teste de
        -- tipo, getItem levanta "No implementation found".
        if instanceof(obj, "IsoWorldInventoryObject") then
            local item = obj:getItem()
            if WB_Cart.is(item) and not seen[item] then
                seen[item] = true
                context:addOption(getText("ContextMenu_MNWB_PickUp"),
                    player, startPickUp, obj)
            end
        end
    end
end)

--- Carrinho no inventario: oferece largar com animacao.
Events.OnFillInventoryObjectContextMenu.Add(function(player, context, items)
    local character = getSpecificPlayer(player)
    if character == nil then return end

    local seen = {}
    for _, entry in ipairs(items) do
        -- A lista mistura itens soltos e grupos empilhados; grupo vem como uma
        -- tabela com .items. Sem tratar os dois, a opcao some quando o jogo
        -- decide agrupar.
        local item = (type(entry) == "table" and entry.items) and entry.items[1] or entry
        if WB_Cart.is(item) and not seen[item] then
            seen[item] = true
            context:addOption(getText("ContextMenu_MNWB_PutDown"),
                player, startPutDown, item)
        end
    end
end)

return WB_ContextMenu
