--[[
    Largar um cadaver arrastado dentro do carrinho.

    ----------------------------------------------------------------------
    O DEFEITO: a pagina da Workshop promete carregar cadaver e o jogo nao deixava.

    O carrinho ACEITA cadaver -- WB_AcceptItem libera quando a sandbox permite. O
    que faltava era um caminho para o jogador pedir isso. Cadaver no chao nao e item
    de inventario: e um IsoDeadBody, objeto de mundo. Nao existe no painel do chao,
    entao nao ha o que arrastar para dentro do carrinho.

    ----------------------------------------------------------------------
    O JOGO JA TEM O FLUXO, e ele nao alcanca o carrinho

    Arrastando um cadaver, o clique direito oferece "largar cadaver em <container>".
    Isso e corpseStorageCheck.lua, e ele nunca mostra o nosso carrinho por DOIS
    motivos independentes, os dois medidos no bytecode:

      1. a lista de containers vem de IsoGridSquare.getAllContainers, que varre
         getObjectContainers e getVehicleItemContainers -- objeto de mundo e
         veiculo. Item largado no chao nao entra nessa varredura.

      2. o teste ItemContainer.canHumanCorpseFit exige que o TIPO do container
         esteja numa lista fixa: bin, cardboardbox, crate, coffin, dumpster,
         fridge, freezer e mais alguns. Container que vem de item nao esta la.

    Consertar qualquer um dos dois exigiria mexer no que e do jogo. Adicionar a
    nossa opcao ao mesmo menu nao exige nada disso.

    ----------------------------------------------------------------------
    NAO PRECISOU DE ACAO CUSTOMIZADA

    ISDropCorpseIntoContainer nao refaz nenhum dos dois testes: ela so chama
    throwGrappledIntoInventory, que checa se o personagem esta agarrando e usa a
    posicao do container para virar o corpo. Conferido no bytecode -- nenhuma
    chamada a canHumanCorpseFit ali dentro. O filtro estava no menu, nao na acao.

    ----------------------------------------------------------------------
    O TEXTO E O DO JOGO, de proposito

    IGUI_Option_DropCorpseIntoContainerName ("Drop Corpse Into ") existe em todos os
    idiomas que o jogo suporta. Concatenado com o nome do item, que ja traduzimos,
    a opcao fica traduzida sem uma unica string nova -- e em mais idiomas do que os
    23 que geramos.
]]

require "TimedActions/ISDropCorpseIntoContainer"

local WB_Cart = require "WB_Cart"
local WB_Sandbox = require "WB_Sandbox"

local WB_Corpse = {}

--- Distancia, em squares, para o carrinho aparecer no menu.
---
--- Dois porque e o alcance com que o jogador enxerga o carrinho como "aquele ali",
--- e porque a caminhada ate ele e curta o bastante para nao virar uma viagem.
local REACH = 2

--- Peso de um cadaver humano. Usado so para nao oferecer a opcao quando nao cabe.
--- Bate com Base.CorpseMale e Base.CorpseFemale em generated/items/normal.txt.
local CORPSE_WEIGHT = 20

--- @return InventoryItem|nil carrinho no chao ao alcance, com espaco
local function reachableCart(character)
    local found = nil
    WB_Cart.forEachOnGround(character, REACH, function(cart)
        if found ~= nil then return end
        local inventory = cart:getInventory()
        if inventory == nil then return end
        -- Capacidade e teto sobre o peso BRUTO do conteudo; a reducao nao entra
        -- aqui. Ver o cabecalho de WB_Weight.
        if inventory:getCapacityWeight() + CORPSE_WEIGHT > inventory:getCapacity() then
            return
        end
        found = cart
    end)
    return found
end

local function onDropCorpse(playerNum, cart)
    local character = getSpecificPlayer(playerNum)
    if character == nil or cart == nil then return end

    local worldItem = cart:getWorldItem()
    local square = worldItem and worldItem:getSquare()
    if square == nil then return end

    -- walkAdj e nao walkToContainer: walkToContainer chega em
    -- container:getParent():getSquare(), e o parent de um container que vem de item
    -- nao e um IsoObject. walkAdj recebe a square direto e e o idioma que o jogo
    -- usa em 282 lugares.
    luautils.walkAdj(character, square)

    ISTimedActionQueue.add(
        ISDropCorpseIntoContainer:new(character, cart:getInventory()))
end

function WB_Corpse.onFillWorldObjectContextMenu(playerNum, context, _worldObjects)
    local character = getSpecificPlayer(playerNum)
    if character == nil or not character:isDraggingCorpse() then return end

    -- O portao da sandbox vive AQUI, e nao so em WB_AcceptItem: nao ficou
    -- estabelecido que throwGrappledIntoInventory consulte AcceptItemFunction, e
    -- uma opcao que nao deveria existir e pior do que uma que falha -- ela promete.
    if WB_Sandbox.get("AllowCorpses") ~= true then return end

    local cart = reachableCart(character)
    if cart == nil then return end

    context:addOptionOnTop(
        getText("IGUI_Option_DropCorpseIntoContainerName") .. cart:getName(),
        playerNum, onDropCorpse, cart)
end

Events.OnFillWorldObjectContextMenu.Add(WB_Corpse.onFillWorldObjectContextMenu)

return WB_Corpse
