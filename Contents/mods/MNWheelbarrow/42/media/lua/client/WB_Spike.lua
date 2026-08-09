--[[
    SPIKE -- descartavel. So existe para provar a rota de objeto do mundo antes
    de construir o sistema de empurrar em cima dela.

    Tres perguntas que so a tela responde:
      1. O sprite do tileset renderiza no mundo?
      2. createContainersFromSpriteProperties() cria mesmo o container a partir
         das propriedades marcadas no TileZed?
      3. A capacidade resultante e 100, e nao 50 como no container de item?

    Se qualquer uma falhar, o desenho muda antes de eu escrever empurrar,
    colisao e sincronizacao de multiplayer.

    Fica atras de getDebug(): so aparece com o jogo iniciado com -debug, entao
    nao vaza para quem instalar o mod. Este arquivo sai quando a Fase de
    empurrar estiver pronta.
]]

local WB_Const = require "WB_Const"

-- Nomes gerados pelo PackTool a partir da folha mnwheelbarrow_01.png: a
-- posicao na primeira linha vira o sufixo. A ordem segue FACINGS do
-- tools_render_iso_sprites.py.
local SPRITE = {
    S = "mnwheelbarrow_01_0",
    W = "mnwheelbarrow_01_1",
    N = "mnwheelbarrow_01_2",
    E = "mnwheelbarrow_01_3",
}

local function place(square, spriteName)
    if square == nil then return end

    local object = IsoObject.new(getCell(), square, spriteName)

    -- E aqui que ContainerType e ContainerCapacity, marcados no TileZed, viram
    -- um ItemContainer de verdade. Sem esta chamada o objeto e so um desenho.
    object:createContainersFromSpriteProperties()

    square:AddTileObject(object)
    square:RecalcAllWithNeighbours(true)

    local container = object:getContainer()
    if container == nil then
        print("[Wheelbarrow][SPIKE] FALHOU: nenhum container foi criado")
        return
    end

    print("[Wheelbarrow][SPIKE] sprite   = " .. spriteName)
    print("[Wheelbarrow][SPIKE] tipo     = " .. tostring(container:getType()))
    print("[Wheelbarrow][SPIKE] CAPACIDADE = " .. tostring(container:getCapacity())
        .. "   (item era limitado a 50; esperado 100)")
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, _test)
    if not getDebug() then return end

    local square = nil
    for _, obj in ipairs(worldobjects) do
        if obj:getSquare() then square = obj:getSquare() end
    end
    if square == nil then return end

    local parent = context:addOption("[SPIKE] Colocar carrinho")
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)
    for _, face in ipairs({ "S", "W", "N", "E" }) do
        sub:addOption("face " .. face, nil, function() place(square, SPRITE[face]) end)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
