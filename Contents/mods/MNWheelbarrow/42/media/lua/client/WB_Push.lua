--[[
    Empurrar o carrinho -- Parte 1: agarrar, seguir e virar de face.

    O carrinho e um IsoObject no mundo, nao um item na mao. Isso e o que permite
    a capacidade 100: o teto de 50 do engine vale so para container preso a
    item. Em troca, tudo que o item entregava de graca precisa ser reescrito
    aqui -- inclusive o bloqueio de arma, que vinha do RequiresEquippedBothHands.

    O QUE ESTA PARTE FAZ:
      agarrar e soltar, o carrinho seguir o jogador a cada square, e trocar o
      sprite conforme a direcao.

    O QUE AINDA NAO FAZ (proximas partes, uma de cada vez):
      colisao fina com parede e cerca, bloqueio de arma, tombamento ao ser
      interrompido, e sincronizacao de multiplayer.

    Enquanto isso este arquivo e client-only e vale para singleplayer. Num
    servidor dedicado o carrinho se moveria so na tela de quem empurra.
]]

local WB_Const = require "WB_Const"

local WB_Push = {}

-- OITO faces. O personagem do PZ tem 8 direcoes; com so as 4 cardinais, olhar
-- numa diagonal mostrava a face mais proxima e errava 45 graus na tela.
--
-- O mapeamento e derivado, nao tentado. A frente do modelo e o eixo +Z: medi a
-- malha e o extremo +Z tem |x| medio 0.097 e encosta em y=0 (a roda, estreita e
-- no chao), enquanto o extremo -Z tem |x| medio 0.387 e nunca desce de 0.588
-- (os dois cabos, afastados e suspensos).
--
-- +Z desloca na tela por (-sin(az), cos(az)*sin(30)). Cruzando com a tela do
-- PZ, onde sx = x-y e sy = x+y, cada azimute do render serve uma direcao:
--
--     az   0 -> reto para cima  -> NW      az 180 -> reto para baixo -> SE
--     az  45 -> cima-esquerda   -> W       az 225 -> baixo-direita   -> E
--     az  90 -> esquerda        -> SW      az 270 -> direita         -> NE
--     az 135 -> baixo-esquerda  -> S       az 315 -> cima-direita    -> N
--
-- O PackTool nomeia pela coluna na folha, e FACINGS em
-- tools_render_iso_sprites.py esta nessa mesma ordem.
local SPRITE_BY_DIR = {
    NW = "mnwheelbarrow_01_0",
    W  = "mnwheelbarrow_01_1",
    SW = "mnwheelbarrow_01_2",
    S  = "mnwheelbarrow_01_3",
    SE = "mnwheelbarrow_01_4",
    E  = "mnwheelbarrow_01_5",
    NE = "mnwheelbarrow_01_6",
    N  = "mnwheelbarrow_01_7",
}

--- A square a frente do jogador, por direcao. Agora com diagonais.
local OFFSET = {
    N  = {  0, -1 },  NE = {  1, -1 },
    E  = {  1,  0 },  SE = {  1,  1 },
    S  = {  0,  1 },  SW = { -1,  1 },
    W  = { -1,  0 },  NW = { -1, -1 },
}

--- Puxa o carrinho visualmente na direcao do jogador.
---
--- Em diagonal o problema e maior: o deslocamento {1,-1} coloca o carrinho a
--- 1.41 tiles de distancia, contra 1.0 nas cardinais -- por isso ele parece
--- mais longe em umas direcoes que em outras.
---
--- A UNIDADE DE setOffsetX/setOffsetY NAO E PIXEL.
---
--- Esses metodos nao aparecem em nenhum Lua do jogo base, entao supus pixels na
--- escala 1x e multipliquei por 32 e 16, gerando valores de ate 22. O carrinho
--- SUMIU da tela -- o log mostrava o objeto existindo e se movendo normalmente,
--- so que desenhado fora da area visivel. Um deslocamento de 22 pixels seria
--- imperceptivel; some so se a unidade for muito maior, quase certamente tiles.
---
--- Agora passo o valor em tiles direto, sem multiplicar. Isso e seguro nos dois
--- casos: se a unidade for tile, puxa os 0.35 pretendidos; se for pixel, o
--- deslocamento fica abaixo de um pixel e nao faz mal nenhum. O teste responde
--- qual dos dois sem risco de sumir de novo.
local PULL_TILES = 0.35

local function applyPullOffset(object, face)
    local off = OFFSET[face]
    if off == nil then return end
    local dx = -PULL_TILES * off[1]
    local dy = -PULL_TILES * off[2]
    object:setOffsetX(dx - dy)
    object:setOffsetY(dx + dy)
end

--- Estado por jogador. Chaveado pelo indice, nao pelo objeto, porque em
--- splitscreen cada jogador pode estar empurrando um carrinho diferente.
local pushing = {}

--- @return boolean se o IsoObject e um carrinho
--- Identificamos pelo tipo do container, e nao pelo nome do sprite: o sprite
--- muda a cada mudanca de direcao, o tipo nao.
function WB_Push.isCart(object)
    if object == nil then return false end
    local container = object:getContainer()
    return container ~= nil and container:getType() == "wheelbarrow"
end

local function faceOf(player)
    local dir = player:getDir()
    if dir == nil then return "S" end
    local name = dir:toString()
    return SPRITE_BY_DIR[name] and name or "S"
end

--- Square onde o carrinho deveria estar: uma a frente do jogador, na direcao
--- em que ele olha. E o que faz parecer empurrado, e nao arrastado.
local function targetSquare(player, face)
    local square = player:getSquare()
    if square == nil then return nil end
    local off = OFFSET[face]
    return getCell():getGridSquare(square:getX() + off[1], square:getY() + off[2], square:getZ())
end

--- Move o carrinho de uma square para outra.
---
--- CUIDADO -- esta funcao ja duplicou objetos e sujou saves. A versao anterior
--- fazia fromSquare:RemoveTileObject(object), pedindo a uma square que eu
--- ACHAVA ser a dona que removesse o objeto. Como o ponteiro de square do
--- objeto nao acompanhava o AddTileObject, getSquare() devolvia para sempre a
--- square original: a cada tick a remocao falhava e um AddTileObject inseria
--- mais uma copia numa square nova. O carrinho parecia parado na origem
--- enquanto um rastro de copias se acumulava -- e copias entram no save.
---
--- Agora usamos object:removeFromSquare(), que age a partir do proprio objeto
--- em vez de um palpite meu, e conferimos o resultado. Se o objeto nao acabar
--- onde deveria, paramos de empurrar em vez de tentar de novo: um loop que
--- duplica e pior do que um carrinho que nao se move.
--- Trocar o sprite usa setSpriteFromName, NAO setSprite.
---
--- Os dois aceitam string e fazem coisas diferentes, o que me custou uma rodada
--- inteira com o carrinho invisivel:
---
---   setSprite(String)         -> IsoSprite.CreateSprite + LoadSingleTexture,
---                                cria um sprite novo e procura uma textura
---                                SOLTA com aquele nome
---   setSpriteFromName(String) -> IsoSpriteManager.getSprite, busca o sprite ja
---                                registrado pelo tileset
---
--- Os nossos sprites vivem dentro do .pack, sob o tileset -- nao existem como
--- textura solta. Com setSprite o objeto ficava com um sprite sem textura: o
--- log mostrava ele existindo e se movendo, mas nada era desenhado. O jogo base
--- usa setSpriteFromName nesses casos (SCampfireGlobalObject, ISPaintAction).
local function moveCart(object, toSquare, face)
    if toSquare == nil then return false end

    object:removeFromSquare()
    object:setSpriteFromName(SPRITE_BY_DIR[face])
    toSquare:AddTileObject(object)
    object:setSquare(toSquare)

    applyPullOffset(object, face)
    toSquare:RecalcAllWithNeighbours(true)

    if object:getSquare() ~= toSquare then
        print("[Wheelbarrow] ABORTADO: o objeto nao ficou na square de destino")
        return false
    end
    return true
end

function WB_Push.stop(playerIndex)
    local entry = pushing[playerIndex]
    if entry == nil then return end
    pushing[playerIndex] = nil
end

function WB_Push.start(playerIndex, object)
    pushing[playerIndex] = { object = object }
end

function WB_Push.isPushing(playerIndex)
    return pushing[playerIndex] ~= nil
end

--- Roda por jogador a cada tick. Mantem barato: quase sempre o carrinho ja
--- esta no lugar certo e a funcao so compara duas squares e sai.
local function onPlayerUpdate(player)
    local index = player:getPlayerNum()
    local entry = pushing[index]
    if entry == nil then return end

    local object = entry.object
    local current = object:getSquare()

    -- Soltar sozinho quando o contexto deixa de fazer sentido. Entrar num
    -- carro ou mudar de andar sao os casos obvios; sem isto o carrinho ficaria
    -- preso a um jogador que nao pode mais empurra-lo.
    if player:getVehicle() ~= nil or current == nil or player:getSquare() == nil then
        WB_Push.stop(index)
        return
    end
    if current:getZ() ~= player:getSquare():getZ() then
        WB_Push.stop(index)
        return
    end

    local face = faceOf(player)
    local target = targetSquare(player, face)

    -- Diagnostico: imprime so quando a decisao MUDA, para nao inundar o console
    -- a 60 quadros por segundo. Existe porque o carrinho nao estava seguindo o
    -- jogador e nenhum erro aparecia no log -- sem ver qual guarda barra o
    -- movimento, so da para adivinhar, e adivinhar ja custou caro nesta sessao.
    local reason
    if target == nil then
        reason = "square alvo nao existe"
    elseif target == current then
        reason = "carrinho ja esta no alvo (so gira)"
    elseif not target:isFree(false) then
        reason = "alvo nao esta livre (isFree=false)"
    elseif current:isBlockedTo(target) then
        reason = "passagem bloqueada (isBlockedTo=true)"
    else
        reason = "MOVENDO"
    end

    if getDebug() and reason ~= entry.lastReason then
        entry.lastReason = reason
        print(("[Wheelbarrow] %s | face=%s jogador=(%d,%d) carrinho=(%d,%d) alvo=%s")
            :format(reason, face,
                player:getSquare():getX(), player:getSquare():getY(),
                current:getX(), current:getY(),
                target and (target:getX() .. "," .. target:getY()) or "nil"))
    end

    if reason ~= "MOVENDO" then
        if target == current then
            object:setSpriteFromName(SPRITE_BY_DIR[face])
            applyPullOffset(object, face)
        end
        return
    end

    if not moveCart(object, target, face) then
        WB_Push.stop(index)
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)

--- Menu de contexto no carrinho.
local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, _test)
    local player = getSpecificPlayer(playerNum)
    if player == nil then return end

    if WB_Push.isPushing(playerNum) then
        context:addOption(getText("ContextMenu_MNWB_Release"), nil, function()
            WB_Push.stop(playerNum)
        end)
        return
    end

    for _, object in ipairs(worldobjects) do
        if WB_Push.isCart(object) then
            context:addOption(getText("ContextMenu_MNWB_Push"), nil, function()
                WB_Push.start(playerNum, object)
            end)
            return
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

-- O calibrador de direcao foi removido: o mapeamento das 8 faces foi derivado
-- da geometria da malha e confirmado em tela.

--- Limpeza dos carrinhos duplicados que a versao anterior espalhou pelo save.
--- Remove TODO carrinho num raio ao redor do jogador, inclusive o conteudo --
--- e ferramenta de faxina de teste, nao de jogo. So com -debug.
local CLEANUP_RADIUS = 12

local function onFillCleanupMenu(playerNum, context, _worldobjects, _test)
    if not getDebug() then return end
    local player = getSpecificPlayer(playerNum)
    if player == nil or player:getSquare() == nil then return end

    context:addOption("[SPIKE] Limpar carrinhos ao redor", nil, function()
        local origin = player:getSquare()
        local cell = getCell()
        local removed = 0
        for dx = -CLEANUP_RADIUS, CLEANUP_RADIUS do
            for dy = -CLEANUP_RADIUS, CLEANUP_RADIUS do
                local sq = cell:getGridSquare(origin:getX() + dx, origin:getY() + dy, origin:getZ())
                if sq ~= nil then
                    -- Percorre de tras para frente: remover altera a lista.
                    local objects = sq:getObjects()
                    for i = objects:size() - 1, 0, -1 do
                        local obj = objects:get(i)
                        if WB_Push.isCart(obj) then
                            obj:removeFromSquare()
                            removed = removed + 1
                        end
                    end
                    sq:RecalcAllWithNeighbours(true)
                end
            end
        end
        WB_Push.stop(playerNum)
        print(("[Wheelbarrow] %d carrinho(s) removido(s) num raio de %d"):format(removed, CLEANUP_RADIUS))
    end)
end

Events.OnFillWorldObjectContextMenu.Add(onFillCleanupMenu)

return WB_Push
