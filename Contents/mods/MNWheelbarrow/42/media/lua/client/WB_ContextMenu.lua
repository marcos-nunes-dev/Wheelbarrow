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
