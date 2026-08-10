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

-- Sprites na ordem em que o PackTool os nomeou, que e a ordem das colunas na
-- folha: FACINGS[1..4] em tools_render_iso_sprites.py.
local SPRITES = {
    "mnwheelbarrow_01_0",
    "mnwheelbarrow_01_1",
    "mnwheelbarrow_01_2",
    "mnwheelbarrow_01_3",
}

local FACE_ORDER = { "N", "E", "S", "W" }

--- CALIBRACAO DA DIRECAO.
---
--- Eu nao consegui determinar em documentacao nenhuma como o azimute do render
--- corresponde as direcoes do jogo, e ja errei orientacao duas vezes tentando
--- deduzir (a camera olhando por baixo, e agora a face apontando errado). Entao
--- estes dois numeros existem para o jogo responder em vez de eu adivinhar:
---
---   ROTATION  desloca qual sprite serve cada direcao (0..3)
---   MIRRORED  inverte o sentido, para o caso de a malha estar espelhada
---
--- Existe uma opcao de debug que percorre as 8 combinacoes e imprime a atual.
--- Quando a certa for encontrada, os valores viram fixos aqui e a opcao sai.
--- Valores derivados, e nao encontrados por tentativa:
---
--- 1. A frente do modelo e o eixo +Z. Medido na malha: o extremo +Z tem
---    |x| medio 0.097 e encosta em y=0 -- e a roda, estreita e no chao. O
---    extremo -Z tem |x| medio 0.387 e nunca desce de y=0.588 -- sao os dois
---    cabos, afastados e suspensos.
---
--- 2. No render, +Z projeta para cima-esquerda em 45 graus, baixo-esquerda em
---    135, baixo-direita em 225 e cima-direita em 315.
---
--- 3. No PZ a tela e sx=(x-y), sy=(x+y), entao N vai para cima-direita, E para
---    baixo-direita, S para baixo-esquerda e W para cima-esquerda.
---
--- Cruzando 2 e 3: sprite 0 serve W, 1 serve S, 2 serve E, 3 serve N. Contra a
--- ordem N,E,S,W isso e a sequencia INVERTIDA, nao deslocada -- por isso
--- MIRRORED e nenhuma rotacao.
local ROTATION = 0
local MIRRORED = true

local function spriteForFace(face)
    local i
    for k, name in ipairs(FACE_ORDER) do
        if name == face then i = k break end
    end
    if i == nil then i = 1 end
    if MIRRORED then i = 5 - i end
    return SPRITES[((i - 1 + ROTATION) % 4) + 1]
end

-- O jogador tem 8 direcoes, o carrinho tem 4 sprites. As diagonais caem para a
-- cardinal anterior no sentido horario.
local FACE_BY_DIR = {
    N = "N", NE = "N",
    E = "E", SE = "E",
    S = "S", SW = "S",
    W = "W", NW = "W",
}

local OFFSET = {
    N = { 0, -1 },
    S = { 0, 1 },
    E = { 1, 0 },
    W = { -1, 0 },
}

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
    return FACE_BY_DIR[dir:toString()] or "S"
end

--- Square onde o carrinho deveria estar: uma a frente do jogador, na direcao
--- em que ele olha. E o que faz parecer empurrado, e nao arrastado.
local function targetSquare(player, face)
    local square = player:getSquare()
    if square == nil then return nil end
    local off = OFFSET[face]
    return getCell():getGridSquare(square:getX() + off[1], square:getY() + off[2], square:getZ())
end

local function moveCart(object, fromSquare, toSquare, face)
    if fromSquare == nil or toSquare == nil then return false end
    if fromSquare == toSquare then return false end

    fromSquare:RemoveTileObject(object)
    object:setSprite(spriteForFace(face))
    toSquare:AddTileObject(object)

    fromSquare:RecalcAllWithNeighbours(true)
    toSquare:RecalcAllWithNeighbours(true)
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
            object:setSprite(spriteForFace(face))
        end
        return
    end

    moveCart(object, current, target, face)
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

--- Calibrador de direcao. So com -debug. Percorre as 8 combinacoes possiveis de
--- ROTATION x MIRRORED e imprime a atual, para descobrir empiricamente qual
--- sprite corresponde a qual direcao do jogo. Sai quando os valores estiverem
--- fixados no topo do arquivo.
local function onFillDebugMenu(playerNum, context, worldobjects, _test)
    if not getDebug() then return end
    if not WB_Push.isPushing(playerNum) then return end

    context:addOption("[SPIKE] Proxima combinacao de face", nil, function()
        ROTATION = ROTATION + 1
        if ROTATION > 3 then
            ROTATION = 0
            MIRRORED = not MIRRORED
        end
        local player = getSpecificPlayer(playerNum)
        local dir = player and player:getDir() and player:getDir():toString() or "?"
        print(("[Wheelbarrow] ROTATION=%d MIRRORED=%s | olhando para %s -> sprite %s")
            :format(ROTATION, tostring(MIRRORED), dir, spriteForFace(faceOf(player))))
    end)
end

Events.OnFillWorldObjectContextMenu.Add(onFillDebugMenu)

return WB_Push
