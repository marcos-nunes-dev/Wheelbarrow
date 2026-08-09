--[[
    O carrinho alivia carga pesada e nao faz nada por carga leve.

    O engine so oferece UMA alavanca: uma porcentagem unica aplicada sobre o
    peso total do conteudo --

        pesoEfetivo = pesoTotal * (1 - weightReduction / 100)

    Como a regra do mod e "alivia so o que e pesado", resolvemos a porcentagem
    equivalente a cada mudanca de conteudo. Separamos o conteudo em pesado e
    leve, calculamos o peso efetivo que QUEREMOS, e derivamos a porcentagem
    unica que produz exatamente esse resultado:

        efetivo = leve + pesado * (1 - reducao)
        pct     = 100 * (1 - efetivo / total)

    So itens leves  -> efetivo == total -> pct 0   (carrinho inutil, de proposito)
    So itens pesados-> pct == reducao               (alivio total)
    Misturado       -> proporcional, matematicamente exato

    CAPACIDADE: o teto de 50 do engine e absoluto -- validado no parser de
    script E em runtime. Nao ha como contornar. O limite real de um carrinho e
    50 menos o proprio peso, e ponto. Uma versao anterior tentou driblar isso
    reduzindo o peso real dos itens; a tecnica quebrava o modelo do personagem
    e foi abandonada (ver WB_Legacy.lua).

    POR QUE ESTE ARQUIVO ESTA EM shared/ E NAO EM server/:
    OnEquipPrimary/OnEquipSecondary sao eventos de cliente -- no jogo base so
    aparecem em arquivos de client/. Num servidor DEDICADO, server/ roda em
    outro processo e esses eventos nunca disparariam la, deixando o codigo
    morto. O calculo e deterministico a partir do conteudo do container, que ja
    e sincronizado nativamente, entao cada lado deriva o proprio estado.
]]

local WB_Const = require "WB_Const"
local WB_Legacy = require "WB_Legacy"

local WB_Weight = {}

--- Le as sandbox options. Retorna nil se ainda nao carregaram -- nesse caso
--- nao fazemos nada, em vez de inventar numeros. As options tem "default" no
--- script, entao elas sao a unica fonte de verdade de balanceamento.
local function sandbox()
    local sv = SandboxVars and SandboxVars[WB_Const.SANDBOX_NS]
    if sv == nil or sv.HeavyThreshold == nil then return nil end
    return sv
end

--- @return boolean se o item e um carrinho (ou qualquer "hauler" futuro)
function WB_Weight.isHauler(item)
    if item == nil then return false end
    if not instanceof(item, "InventoryContainer") then return false end
    return WB_Const.HAULER_TYPES[item:getFullType()] == true
end

--- Recalcula reducao de peso e capacidade de UM carrinho.
function WB_Weight.refresh(item)
    if not WB_Weight.isHauler(item) then return end

    local sv = sandbox()
    if sv == nil then return end

    local inv = item:getInventory()
    if inv == nil then return end

    local threshold = sv.HeavyThreshold
    local reduction = sv.HeavyReduction / 100.0

    -- Desfaz o encolhimento de peso de versoes antigas do mod, se houver.
    -- Ver WB_Legacy.lua para por que aquela tecnica foi abandonada.
    WB_Legacy.sweep(inv)

    local heavy, light = 0.0, 0.0
    local contents = inv:getItems()
    for i = 0, contents:size() - 1 do
        local w = contents:get(i):getActualWeight()
        if w >= threshold then
            heavy = heavy + w
        else
            light = light + w
        end
    end

    local total = heavy + light
    local pct = 0
    if total > 0 then
        local effective = light + heavy * (1.0 - reduction)
        pct = math.floor(100.0 * (1.0 - effective / total) + 0.5)
        if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
    end

    -- Setados no item e no container: ambos expoem os setters, e qual deles o
    -- engine consulta depende do caminho de codigo. Escrever nos dois e barato
    -- e elimina a duvida.
    if item:getWeightReduction() ~= pct then
        item:setWeightReduction(pct)
        inv:setWeightReduction(pct)
    end

    -- CAPACIDADE: o teto de 50 do engine NAO e so do parser de script -- e
    -- validado em runtime tambem. setCapacity acima disso e recusado e cospe
    -- "Attempting to set capacity ... over maximum capacity" no console a cada
    -- chamada. O limite real do item e 50 menos o proprio peso.
    --
    -- Ou seja: a sandbox option so consegue ABAIXAR a capacidade, nunca subir
    -- alem do teto. Clampamos para respeitar isso em silencio, e so escrevemos
    -- quando o valor muda de fato, para nao inundar o log.
    local ceiling = WB_Const.ENGINE_CAPACITY_CEILING - item:getActualWeight()
    local target = math.floor(math.min(sv.Capacity, ceiling))
    if target > 0 and inv:getCapacity() ~= target then
        item:setCapacity(target)
        inv:setCapacity(target)
    end
end

--- Varre um container e atualiza todo carrinho encontrado nele.
function WB_Weight.refreshContainer(container)
    if container == nil then return end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        WB_Weight.refresh(items:get(i))
    end
end

--- Varre o inventario do jogador. E o caminho que importa: um carrinho no chao
--- nao pesa em ninguem, so o que esta sendo carregado.
---
--- Tambem restaura itens que uma versao antiga do mod deixou com o peso
--- alterado, para saves criados naquela epoca voltarem ao normal.
function WB_Weight.refreshPlayer(player)
    if player == nil then return end
    local inv = player:getInventory()
    if inv == nil then return end

    WB_Legacy.sweep(inv)

    WB_Weight.refreshContainer(inv)
end

--- Carrinhos largados no chao ao redor do jogador.
---
--- Isto nao e um detalhe: carregar o carrinho com ele NO CHAO e o fluxo
--- principal, nao a excecao. Itens pesados como gerador e cadaver so podem ser
--- pegos com as maos, e o carrinho ja ocupa as duas -- entao a unica forma de
--- carrega-lo e larga-lo, pegar o item e depositar. Varrer so o inventario do
--- jogador deixava exatamente esse caso de fora, e itens colocados num carrinho
--- no chao nao encolhiam.
local SEARCH_RADIUS = 2

function WB_Weight.refreshNearbyGround(player)
    local square = player:getSquare()
    if square == nil then return end
    local cell = getCell()
    if cell == nil then return end

    local px, py, pz = square:getX(), square:getY(), square:getZ()
    for dx = -SEARCH_RADIUS, SEARCH_RADIUS do
        for dy = -SEARCH_RADIUS, SEARCH_RADIUS do
            local sq = cell:getGridSquare(px + dx, py + dy, pz)
            if sq ~= nil then
                local objects = sq:getWorldObjects()
                for i = 0, objects:size() - 1 do
                    local obj = objects:get(i)
                    -- getWorldObjects devolve todo IsoObject da square: piso,
                    -- parede, movel. Chamar getItem() num deles levanta
                    -- "No implementation found", entao o teste de tipo nao e
                    -- defensivo por precaucao -- e obrigatorio.
                    if instanceof(obj, "IsoWorldInventoryObject") then
                        local item = obj:getItem()
                        if WB_Weight.isHauler(item) then
                            WB_Weight.refresh(item)
                        end
                    end
                end
            end
        end
    end
end

local function refreshLocalPlayers()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        WB_Weight.refreshPlayer(player)
        if player ~= nil then
            WB_Weight.refreshNearbyGround(player)
        end
    end
end

-- Equipar/desequipar: assinatura confirmada no jogo base e (player, item).
Events.OnEquipPrimary.Add(function(player, _item)
    WB_Weight.refreshPlayer(player)
end)
Events.OnEquipSecondary.Add(function(player, _item)
    WB_Weight.refreshPlayer(player)
end)

-- Conteudo mudou. Ignoramos os argumentos de proposito: a varredura e barata
-- (dezenas de itens) e nao depende da assinatura exata do evento.
Events.OnContainerUpdate.Add(refreshLocalPlayers)

-- OnContainerUpdate nem sempre dispara para container que esta no chao. A
-- janela de loot reconstruindo e o sinal mais confiavel de que o jogador esta
-- mexendo num carrinho largado.
Events.OnRefreshInventoryWindowContainers.Add(refreshLocalPlayers)

-- setWeightReduction/setCapacity sao estado de runtime: ao recarregar um save
-- os valores do script voltam. Sem estes dois, um carrinho salvo cheio
-- reapareceria com a capacidade errada.
-- OnCreatePlayer entrega o INDICE do jogador, nao o objeto (ver
-- ISSearchManager.createUI no jogo base, que faz getSpecificPlayer(_player)).
-- O segundo parametro e aceito por seguranca caso a assinatura mude.
Events.OnCreatePlayer.Add(function(playerIndex, player)
    WB_Weight.refreshPlayer(player or getSpecificPlayer(playerIndex))
end)
Events.OnGameStart.Add(refreshLocalPlayers)

return WB_Weight
