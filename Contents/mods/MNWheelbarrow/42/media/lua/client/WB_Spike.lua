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

--- SPIKE DO VEICULO.
---
--- Spawna o carrinho como veiculo para responder tres coisas que so a tela
--- responde: se um veiculo customizado minimo carrega, se a capacidade do
--- porta-malas passa mesmo de 50, e como o personagem aparece "dirigindo".
---
--- A terceira decide se vale investir em animacao customizada de empurrar --
--- possivel, o mod de cavalos faz com AnimSets/player e anims_X proprios, e e a
--- parte mais pesada daquele mod.
local function onFillVehicleSpike(playerNum, context, _worldobjects, _test)
    if not getDebug() then return end
    local player = getSpecificPlayer(playerNum)
    if player == nil then return end

    context:addOption("[SPIKE] Spawnar carrinho como VEICULO", nil, function()
        local vehicle = addVehicle("Base.MNWheelbarrow", player:getX() + 1, player:getY(), player:getZ())
        if vehicle == nil then
            print("[Wheelbarrow][VEICULO] addVehicle devolveu nil -- o script nao carregou")
            return
        end
        local script = vehicle:getScript()
        print("[Wheelbarrow][VEICULO] spawnado: " .. tostring(script:getName()))

        -- E este numero que libera a opcao de entrar. ISVehicleMenu so mostra
        -- "Entrar no veiculo" se getPassengerCount() > 0, e essa contagem vem
        -- dos blocos passenger do script. Zero aqui significa que o bloco nao
        -- foi lido; maior que zero significa que o problema e outro -- por
        -- exemplo estar procurando a opcao no lugar errado, ja que ela fica no
        -- menu radial (tecla V), nao no clique direito.
        print(("[Wheelbarrow][VEICULO] passageiros no script: %d   (precisa ser > 0 para entrar)")
            :format(script:getPassengerCount()))
        print(("[Wheelbarrow][VEICULO] assentos: %d"):format(vehicle:getMaxPassengers()))
        -- Lista TODAS as pecas e se cada uma esta instalada. Uma peca sem item
        -- instalado nao conta: assento sem banco faz getBestSeat() devolver -1,
        -- e ai nao ha entrada nem prompt da tecla E.
        for i = 0, vehicle:getPartCount() - 1 do
            local part = vehicle:getPartByIndex(i)
            if part ~= nil then
                local container = part:getItemContainer()
                print(("[Wheelbarrow][VEICULO] peca %-16s instalada=%s  capacidade=%s")
                    :format(tostring(part:getId()),
                        tostring(part:getInventoryItem() ~= nil),
                        container and tostring(container:getCapacity()) or "-"))
            end
        end
        -- getBestSeat devolve -1 mesmo com a peca instalada, entao o bloqueio
        -- esta em outra condicao. Estas tres sao as candidatas diretas, e a
        -- ultima linha tenta entrar SEM passar pelo menu -- se funcionar, o
        -- problema e so o caminho ate o assento, nao o assento em si.
        print(("[Wheelbarrow][VEICULO] getBestSeat      = %d"):format(vehicle:getBestSeat(player)))
        print(("[Wheelbarrow][VEICULO] isSeatInstalled  = %s"):format(tostring(vehicle:isSeatInstalled(0))))
        print(("[Wheelbarrow][VEICULO] isSeatOccupied   = %s"):format(tostring(vehicle:isSeatOccupied(0))))
        print(("[Wheelbarrow][VEICULO] isEnterBlocked   = %s   <- se for true, e este o bloqueio")
            :format(tostring(vehicle:isEnterBlocked(player, 0))))
    end)
end

Events.OnFillWorldObjectContextMenu.Add(onFillVehicleSpike)

--- Entrada FORCADA, sem menu e sem pathfinding.
---
--- O menu radial mostra o assento e clicar nao faz nada, o que aponta para a
--- ação de caminhar ate a posicao externa falhando em silencio. Chamar
--- vehicle:enter direto separa as duas coisas: se o personagem entrar por aqui,
--- o assento esta bom e o problema e so a posicao externa/pathfinding; se nem
--- assim entrar, o bloqueio e no proprio assento.
local function onFillForceEnter(playerNum, context, _worldobjects, _test)
    if not getDebug() then return end
    local player = getSpecificPlayer(playerNum)
    if player == nil then return end

    context:addOption("[SPIKE] Forcar entrar no carrinho", nil, function()
        local nearest, bestDist = nil, 9999
        for v = 0, getCell():getVehicles():size() - 1 do
            local veh = getCell():getVehicles():get(v)
            if veh:getScript() and veh:getScript():getName() == "MNWheelbarrow" then
                local d = math.abs(veh:getX() - player:getX()) + math.abs(veh:getY() - player:getY())
                if d < bestDist then nearest, bestDist = veh, d end
            end
        end
        if nearest == nil then
            print("[Wheelbarrow][VEICULO] nenhum carrinho por perto")
            return
        end
        local ok = nearest:enter(0, player)
        print(("[Wheelbarrow][VEICULO] enter(0) devolveu %s | jogador esta em veiculo: %s")
            :format(tostring(ok), tostring(player:getVehicle() ~= nil)))
    end)
end

Events.OnFillWorldObjectContextMenu.Add(onFillForceEnter)
