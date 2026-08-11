--[[
    Capacidade do carrinho e alivio de peso so para carga pesada.

    ======================================================================
    O TETO DE 50 NAO EXISTE. Esta e a correcao mais importante deste arquivo.
    ======================================================================

    Este mod passou muito tempo com a regra "container de item nao passa de 50
    de capacidade", e ela estava errada. O bytecode de ItemContainer.setCapacity
    mostra tres comparacoes -- 1000 para peca de veiculo, 50 para container de
    item, 100 para o resto -- e TODAS as tres levam ao mesmo lugar:

        invokevirtual zombie/debug/DebugType.warn
        ...
        103: aload_0
        104: iload_1
        105: putfield capacity:I      <- a atribuicao acontece sempre
        108: return

    Sao avisos de debug, nao rejeicoes. O valor e sempre gravado. A conclusao
    antiga veio de ver o aviso no console e ler como bloqueio.

    Isso muda o desenho inteiro: da para levar geladeira, cama de casal, dois
    geradores e vinte troncos so subindo a capacidade. Nao e preciso encolher o
    peso dos itens -- tecnica que uma versao antiga tentou e que quebrava o
    modelo do personagem (ver WB_Legacy.lua).

    ONDE A CARGA E FEITA, e por que nao e uma escolha nossa: em
    ItemContainer.hasRoomFor, um container EQUIPADO exige que o item tambem
    caiba no inventario do JOGADOR --

        inventarioDoJogador.getCapacityWeight() + item.getUnequippedWeight()
            <= inventarioDoJogador.getEffectiveCapacity(jogador)

    Uma geladeira nunca passa nesse teste. Com o carrinho no CHAO o engine usa
    outro ramo, que compara so contra a capacidade do proprio carrinho. Ou seja
    o jogo ja obriga o fluxo realista: pousar o carrinho para carregar. Nao ha
    nada a implementar para isso, so a nao atrapalhar.

    ----------------------------------------------------------------------
    ALIVIO DE PESO

    O engine oferece UMA alavanca: uma porcentagem unica sobre o peso total.

        pesoEfetivo = pesoTotal * (1 - weightReduction / 100)

    Como a regra do mod e "alivia so o que e pesado", resolvemos a cada mudanca
    a porcentagem equivalente:

        efetivo = leve + pesado * (1 - reducao)
        pct     = 100 * (1 - efetivo / total)

    So leve    -> pct 0        carrinho inutil, exatamente o desenho pedido
    So pesado  -> pct = reducao
    Misturado  -> proporcional, matematicamente exato

    E por isso que encher o carrinho de livros nao compensa: 200 de capacidade
    permite pegar 200 de livro, e os 200 continuam pesando 200 nas costas.

    ----------------------------------------------------------------------
    POR QUE shared/ E NAO server/: OnEquipPrimary e OnEquipSecondary sao eventos
    de cliente. Num servidor DEDICADO, server/ roda em outro processo e eles
    nunca disparam la -- o codigo seria morto. O calculo e deterministico a
    partir do conteudo, que o jogo ja sincroniza, entao cada lado deriva o
    proprio estado.
]]

local WB_Cart = require "WB_Cart"
local WB_Legacy = require "WB_Legacy"
local WB_Sandbox = require "WB_Sandbox"
local WB_Tipping = require "WB_Tipping"

local WB_Weight = {}

--- Raio da varredura de chao, em squares.
local GROUND_RADIUS = 2

--- Intervalo minimo entre varreduras de chao, em milissegundos.
---
--- A varredura olha (2*2+1)^2 = 25 squares e todo IsoObject de cada uma. Antes
--- disto ela rodava em OnContainerUpdate E em
--- OnRefreshInventoryWindowContainers, que disparam varias vezes por segundo
--- enquanto a janela de loot esta aberta -- exatamente quando o jogador esta
--- mexendo no carrinho. O estrangulamento nao muda o resultado, so evita repetir
--- a mesma varredura dezenas de vezes por segundo.
local GROUND_SCAN_INTERVAL_MS = 250

local lastGroundScan = 0

--- Recalcula reducao de peso e capacidade de UM carrinho.
--- @return boolean se algum valor mudou de fato
function WB_Weight.refresh(item)
    if not WB_Cart.is(item) then return false end

    local inv = item:getInventory()
    if inv == nil then return false end

    local threshold = WB_Sandbox.get("HeavyThreshold")
    local reduction = WB_Sandbox.get("HeavyReduction") / 100.0

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

    -- Escrever so quando muda importa: cada setCapacity acima de 50 imprime um
    -- aviso de debug no console, e escrever a cada evento inundaria o log.
    local changed = false
    if item:getWeightReduction() ~= pct then
        item:setWeightReduction(pct)
        inv:setWeightReduction(pct)
        changed = true
    end

    local capacity = math.floor(WB_Sandbox.get("Capacity"))
    if capacity > 0 and inv:getCapacity() ~= capacity then
        item:setCapacity(capacity)
        inv:setCapacity(capacity)
        changed = true
    end

    return changed
end

--- Carrinhos no inventario do jogador.
---
--- Se o carrinho que mudou estiver NAS MAOS, pede a reconstrucao do modelo do
--- personagem. O motivo e um sintoma observado: por o conteudo no carrinho fez o
--- personagem E os veiculos ao redor sumirem da tela, sem erro nenhum no log.
--- Mudar peso de item equipado ja tinha deixado o personagem invisivel neste
--- projeto antes -- o modelo fica com estado velho e nada pede para refaze-lo.
---
--- So quando algo mudou de fato, e so com o carrinho na mao: e raro, entao nao
--- ha custo por evento.
function WB_Weight.refreshPlayer(player)
    if player == nil then return end

    local touched = false
    WB_Cart.forEachIn(player:getInventory(), function(item)
        if WB_Weight.refresh(item) then touched = true end
    end)

    if touched and WB_Cart.inHands(player) then
        player:resetModelNextFrame()
    end
end

--- Carrinhos largados no chao ao redor do jogador, no maximo a cada
--- GROUND_SCAN_INTERVAL_MS.
--- @param force boolean ignora o estrangulamento (uso: carregar o save)
function WB_Weight.refreshNearbyGround(player, force)
    local now = getTimestampMs()
    if not force and now - lastGroundScan < GROUND_SCAN_INTERVAL_MS then return end
    lastGroundScan = now

    WB_Cart.forEachOnGround(player, GROUND_RADIUS, function(cart)
        WB_Weight.refresh(cart)
        -- Recarregar o save recria o objeto de mundo, e o construtor zera as
        -- rotacoes de inclinacao -- sem isto um carrinho tombado se levantaria
        -- sozinho ao voltar ao jogo. A marca de tombado vive no ModData, que
        -- persiste; aqui ela vira rotacao de novo.
        WB_Tipping.restore(cart)
    end)
end

local function refreshLocalPlayers(force)
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player ~= nil then
            WB_Weight.refreshPlayer(player)
            WB_Weight.refreshNearbyGround(player, force)
        end
    end
end

--- Uma vez por carregamento: restaura itens que a tecnica abandonada de
--- encolher peso deixou alterados. Ver WB_Legacy.lua.
---
--- So no load, e nao em toda atualizacao de container como antes: era uma
--- varredura recursiva da arvore inteira do inventario, para sempre, por causa
--- de uma migracao de um mod que nunca chegou a ser publicado.
local function migrateOnce(player)
    if player == nil then return end
    WB_Legacy.sweep(player:getInventory())
end

Events.OnEquipPrimary.Add(function(player, _item) WB_Weight.refreshPlayer(player) end)
Events.OnEquipSecondary.Add(function(player, _item) WB_Weight.refreshPlayer(player) end)

-- Conteudo mudou. Os argumentos sao ignorados de proposito: a varredura do
-- inventario e barata e nao depende da assinatura exata do evento.
Events.OnContainerUpdate.Add(function() refreshLocalPlayers(false) end)

-- OnContainerUpdate nem sempre dispara para container que esta no chao. A
-- janela de loot reconstruindo e o sinal mais confiavel de que o jogador esta
-- mexendo num carrinho largado.
Events.OnRefreshInventoryWindowContainers.Add(function() refreshLocalPlayers(false) end)

-- setWeightReduction e setCapacity sao estado de RUNTIME: ao recarregar um save
-- os valores do script voltam. Sem estes dois, um carrinho salvo cheio
-- reapareceria com a capacidade do script e o conteudo nao caberia.
--
-- OnCreatePlayer entrega o INDICE do jogador, nao o objeto -- confirmado em
-- ISSearchManager.createUI, que faz getSpecificPlayer(_player). O segundo
-- parametro e aceito caso a assinatura mude.
Events.OnCreatePlayer.Add(function(playerIndex, player)
    local obj = player or getSpecificPlayer(playerIndex)
    migrateOnce(obj)
    WB_Weight.refreshPlayer(obj)
    WB_Weight.refreshNearbyGround(obj, true)
end)

Events.OnGameStart.Add(function()
    migrateOnce(getSpecificPlayer(0))
    refreshLocalPlayers(true)
end)

return WB_Weight
