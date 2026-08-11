--[[
    Poe o carrinho NAS MAOS. O espelho de WB_Spill.placeOnGround.

    POR QUE E UMA FUNCAO SO: esta sequencia e delicada e ja provou custar caro
    quando escrita de novo. A versao original vivia dentro de
    ISWheelbarrowPickUp:perform, e quando o estacionamento durante acoes precisou
    do mesmo comportamento, copiar era o caminho obvio -- e teria repetido o
    defeito descrito abaixo, ou pior, divergido dele com o tempo.

    E o mesmo motivo pelo qual existe UMA funcao para colocar no chao: as duas
    primeiras copias daquela divergiram na direcao do carrinho.
]]

local WB_Tipping = require "WB_Tipping"
local WB_Transfer = require "WB_Transfer"
local WB_UI = require "WB_UI"

local WB_Equip = {}

--- @param worldItem IsoWorldInventoryObject|nil o objeto de mundo, quando o
---        chamador ja o tem em mao. Omitido, sai do proprio carrinho.
--- @return boolean se o carrinho foi para as maos
function WB_Equip.toHands(character, cart, worldItem)
    if character == nil or cart == nil then return false end

    -- Levanta ANTES de tudo. Um carrinho tombado que vai para a mao assim leva a
    -- inclinacao gravada no ModData, e reaparece torto na proxima vez que for
    -- largado -- um tombo que o jogador nunca causou.
    WB_Tipping.reset(cart)

    -- A rede de WB_Placement poe no chao todo carrinho desequipado que encontre
    -- num inventario, e equipar passa obrigatoriamente por esse estado: AddItem
    -- vem antes de setPrimaryHandItem. Sem suspender, a rede teleporta o carrinho
    -- para os pes do jogador no meio da operacao -- que foi o sintoma observado,
    -- "traz o carrinho ate onde estou mas nao equipa".
    WB_Transfer.begin()

    worldItem = worldItem or cart:getWorldItem()
    if worldItem ~= nil then
        --[[ A SEQUENCIA E COPIADA DE ISGrabItemAction:transferItem, e nao
             inventada -- a minha tinha tres passos a menos e o que faltava era
             justamente o ultimo:

                 setWorldItem(nil)

             Sem ele o item continua APONTANDO para o objeto de mundo que acabou
             de sair da square. getWorldItem() segue devolvendo algo, e tres
             lugares leem isso como "ja esta no chao": WB_Player desequipa por
             quadro, WB_Hands desequipa ao equipar, e WB_Spill.dropCart nao faz
             nada. O sintoma foi o carrinho cair no inventario desequipado e
             recusar qualquer tentativa de equipar. Uma referencia pendurada,
             tres defeitos. ]]
        local square = worldItem:getSquare()
        if square ~= nil then
            square:transmitRemoveItemFromSquare(worldItem)
        end
        worldItem:removeFromWorld()
        worldItem:removeFromSquare()
        worldItem:setSquare(nil)
        cart:setWorldItem(nil)
    end

    -- AddItem em vez do fluxo normal de transferencia de proposito: o carrinho
    -- cheio nao passaria no teste de capacidade do inventario do jogador, e e
    -- justamente isso que o carrinho existe para contornar. O peso continua
    -- contando -- o alivio vem da reducao calculada em WB_Weight, nao daqui.
    local inv = character:getInventory()
    if not inv:contains(cart) then
        inv:AddItem(cart)
    end

    -- A square do container so e verdade enquanto o carrinho esta no chao. Quem a
    -- escreve e WB_Corpse, para que throwGrappledIntoInventory ache a posicao; se
    -- ela sobrevivesse a subida para as maos, ItemContainer.getSquare passaria a
    -- mentir sobre onde o compartimento esta.
    local inventory = cart:getInventory()
    if inventory ~= nil then inventory:setSourceGrid(nil) end

    character:setPrimaryHandItem(cart)
    character:setSecondaryHandItem(cart)
    character:resetModelNextFrame()
    -- Sem isto o compartimento do carrinho so aparecia na barra de containers
    -- depois de o jogador clicar em alguma coisa.
    WB_UI.refreshContainers()

    WB_Transfer.finish()
    return true
end

return WB_Equip
