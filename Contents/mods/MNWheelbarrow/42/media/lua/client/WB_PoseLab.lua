--[[
    Laboratorio de pose: ajusta a pose do carrinho na mao, em jogo, por tecla.

    DESCARTAVEL. Sai do mod antes de publicar, junto com WB_PoseGrid.lua e os
    scripts *_poses.txt.

    POR QUE ISTO EXISTE:
    a pose do item na mao esta assada na malha. Nao ha caminho declarativo -- o
    bloco `attachment Bip01_Prop2` foi testado com oito rotacoes e as oito
    renderizaram identicas, entao o engine o ignora neste caminho. E malha e
    script so recarregam no boot, logo cada tentativa custava um RESTART do jogo.
    Quatro rodadas foram gastas a tres variantes por rodada.

    Nao da para mudar a transformacao em runtime, mas da para trocar o ITEM.
    Entao todas as poses vem assadas e este arquivo navega entre elas: o custo do
    restart deixa de multiplicar pelo numero de tentativas.

    TRES EIXOS INDEPENDENTES, um par de teclas cada. Isso importa mais do que
    parece: rotacoes nao comutam, e a versao anterior desta calibracao percorria
    uma lista linear de orientacoes, o que fazia cada passo mudar duas coisas ao
    mesmo tempo. Separar os eixos e o que torna o ajuste legivel -- mexer em um e
    ver so aquilo mudar.

      ]  [   cabeceira (giro no plano do chao, eixo Z)
      '  ;   inclinacao (eixo Y)
      .  ,   familia em X (as duas escolhas plausiveis)

    Os tres angulos aparecem na tela e no console a cada passo. O numero que
    interessa e a TRINCA, nao o indice da pose.

    So responde a teclas com o jogo em debug: e ferramenta de desenvolvimento.
]]

local GRID = require "WB_PoseGrid"

local WB_PoseLab = {}

local function wrap(value, count)
    return ((value - 1) % count) + 1
end

--- Indice de um valor no eixo, com queda para o primeiro se nao existir.
local function indexOf(values, wanted)
    for i, v in ipairs(values) do
        if v == wanted then return i end
    end
    return 1
end

-- Ponto de partida: NAO e o primeiro item de cada eixo, e sim a pose que a
-- medicao aponta como provavel -- X = 270 (a pose 17 antiga, Rx 90, apareceu
-- deitada de barriga para CIMA, logo o giro oposto e o candidato), inclinacao
-- zero e cabeceira zero. Comecar no candidato em vez de num canto do grid
-- economiza passos e deixa claro o que esta sendo testado.
local ix = indexOf(GRID.x, 270)
local iy = indexOf(GRID.y, 0)
local iz = indexOf(GRID.z, 0)
local started = false

--- O indice linear tem de casar com a ordem em que tools_gen_pose_grid.py assou
--- as malhas: X mais externo, Y no meio, Z mais interno. Errar isto nao gera
--- erro -- gera texto na tela mentindo sobre a malha mostrada.
local function poseId()
    local ny, nz = #GRID.y, #GRID.z
    local linear = ((ix - 1) * ny + (iy - 1)) * nz + iz
    return string.format("%s%03d", GRID.prefix, linear), linear
end

local function announce(player, text)
    print("[Wheelbarrow][POSE] " .. text)
    if HaloTextHelper and HaloTextHelper.addText then
        if pcall(HaloTextHelper.addText, player, text) then return end
    end
    pcall(function() player:setHaloNote(text) end)
end

--- Tira do inventario a pose anterior, para a varredura nao encher o inventario
--- de carrinhos. Busca pelo prefixo em vez de guardar o item numa variavel: se o
--- jogador largar ou perder o item no meio, a limpeza continua valendo.
local function clearPoses(player)
    local inv = player:getInventory()
    local total = #GRID.x * #GRID.y * #GRID.z
    for i = 1, total do
        local id = string.format("%s%03d", GRID.prefix, i)
        local item = inv:FindAndReturn(id)
        while item ~= nil do
            if player:isPrimaryHandItem(item) then player:setPrimaryHandItem(nil) end
            if player:isSecondaryHandItem(item) then player:setSecondaryHandItem(nil) end
            inv:Remove(item)
            item = inv:FindAndReturn(id)
        end
    end
end

function WB_PoseLab.apply(player)
    local id, linear = poseId()
    clearPoses(player)

    local item = player:getInventory():AddItem(id)
    if item == nil then
        announce(player, id .. " nao existe -- o script de poses nao carregou")
        return
    end
    player:setPrimaryHandItem(item)
    -- Sem isto o personagem pode continuar mostrando a pose anterior: o modelo
    -- so e reconstruido quando alguem pede.
    player:resetModelNextFrame()

    announce(player, string.format("X=%d  Y=%d  Z=%d   (pose %d)",
        GRID.x[ix], GRID.y[iy], GRID.z[iz], linear))
end

local function step(axis, delta)
    local player = getSpecificPlayer(0)
    if player == nil or player:isDead() then return end

    -- O primeiro toque em qualquer tecla so entrega a pose inicial, sem andar:
    -- assim o ponto de partida e sempre o mesmo, independente de qual tecla foi
    -- apertada primeiro.
    if not started then
        started = true
    elseif axis == "x" then
        ix = wrap(ix + delta, #GRID.x)
    elseif axis == "y" then
        iy = wrap(iy + delta, #GRID.y)
    else
        iz = wrap(iz + delta, #GRID.z)
    end

    WB_PoseLab.apply(player)
end

Events.OnKeyPressed.Add(function(key)
    if not getCore():getDebug() then return end

    if key == Keyboard.KEY_RBRACKET then step("z", 1)
    elseif key == Keyboard.KEY_LBRACKET then step("z", -1)
    elseif key == Keyboard.KEY_APOSTROPHE then step("y", 1)
    elseif key == Keyboard.KEY_SEMICOLON then step("y", -1)
    elseif key == Keyboard.KEY_PERIOD then step("x", 1)
    elseif key == Keyboard.KEY_COMMA then step("x", -1)
    end
end)

return WB_PoseLab
