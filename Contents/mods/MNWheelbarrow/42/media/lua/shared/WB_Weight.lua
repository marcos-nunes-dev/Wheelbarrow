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

    O mesmo vale para Capacity: o script tem teto de 50 menos o peso do item,
    o que nao comporta dois geradores (80). setCapacity() em runtime contorna.

    POR QUE ESTE ARQUIVO ESTA EM shared/ E NAO EM server/:
    OnEquipPrimary/OnEquipSecondary sao eventos de cliente -- no jogo base so
    aparecem em arquivos de client/. Num servidor DEDICADO, server/ roda em
    outro processo e esses eventos nunca disparariam la, deixando o codigo
    morto. O calculo e deterministico a partir do conteudo do container, que ja
    e sincronizado nativamente, entao cada lado deriva o proprio estado.
]]

local WB_Const = require "WB_Const"
local WB_Shrink = require "WB_Shrink"

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

    -- Encolhe o peso real dos itens pesados ANTES de contabilizar, para caber
    -- dentro do teto de capacidade de 50 do engine (ver WB_Shrink.lua).
    WB_Shrink.reconcile(inv, true, sv.HeavyShrink / 100.0, threshold)

    local heavy, light = 0.0, 0.0
    local contents = inv:getItems()
    for i = 0, contents:size() - 1 do
        local it = contents:get(i)
        -- Classifica pelo peso ORIGINAL: um tronco encolhido de 9 para 3.6
        -- cairia abaixo do limite e perderia a reducao justamente por estar
        -- sendo carregado como carga pesada.
        local w = it:getActualWeight()
        if WB_Shrink.originalWeight(it) >= threshold then
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
--- Esta funcao tambem e a rede de seguranca do encolhimento de peso. A varredura
--- comeca com insideHauler = false, entao qualquer item marcado como encolhido
--- que ja nao esteja dentro de um carrinho tem o peso original restaurado aqui.
--- E por isso que um item largado no chao encolhido se conserta sozinho quando
--- alguem o pega: pegar o coloca num inventario, e o inventario e varrido.
function WB_Weight.refreshPlayer(player)
    if player == nil then return end
    local inv = player:getInventory()
    if inv == nil then return end

    local sv = sandbox()
    if sv ~= nil then
        WB_Shrink.reconcile(inv, false, sv.HeavyShrink / 100.0, sv.HeavyThreshold)
    end

    WB_Weight.refreshContainer(inv)
end

local function refreshLocalPlayers()
    for i = 0, getNumActivePlayers() - 1 do
        WB_Weight.refreshPlayer(getSpecificPlayer(i))
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
