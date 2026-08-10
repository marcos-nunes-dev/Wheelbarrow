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

    ESTADO: rotacao resolvida em (270, 0, 0), e da translacao ja sairam Y = 0.80
    e Z = 0.64. Falta so o LATERAL, que caiu entre duas amostras da passada
    grossa -- por isso X tem doze valores aqui e os outros dois so tres, para
    confirmacao. Ver o cabecalho de tools_gen_pose_grid.py para a derivacao.

    TRES EIXOS INDEPENDENTES, um par de teclas cada. Isso importa mais do que
    parece: a primeira versao desta calibracao percorria uma lista linear, o que
    fazia cada passo mudar duas coisas ao mesmo tempo -- o mesmo defeito de
    metodo que custou as quatro primeiras rodadas. Mexer em um eixo e ver so
    aquilo mudar e o que torna o ajuste legivel.

      ]  [   Z -- altura. +Z DESCE (medido: a mao esta a 0.76 do chao)
      =  -   Y -- frente/tras, o eixo do comprimento do carrinho
      .  ;   X -- lateral

    TECLAS JA USADAS PELO JOGO: = e - sao Zoom in / Zoom out no padrao, e ] e
    Toggle Moveable Panel Mode. OnKeyPressed nao consome a tecla, entao a acao do
    jogo acontece junto -- ajustar Y vai dar zoom tambem. Nao vale codigo para
    contornar numa ferramenta descartavel; se incomodar, e so trocar o Zoom nas
    opcoes de controle. [ . e ; estao livres.

    Os tres valores aparecem na tela e no console a cada passo. O que interessa e
    a TRINCA, nao o indice da pose.

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

-- Ponto de partida: o melhor ponto da passada anterior, e nao um canto do grid.
-- Y = 0.80 e Z = 0.64 ja acertaram la; X = 0.37 e a estimativa entre as duas
-- amostras vizinhas que bracketaram o encaixe. Comecar aqui deixa o refino ser
-- so um passo para cada lado.
local ix = indexOf(GRID.x, 0.37)
local iy = indexOf(GRID.y, 0.80)
local iz = indexOf(GRID.z, 0.64)
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

    announce(player, string.format("X=%.2f  Y=%.2f  Z=%.2f   (pose %d)",
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
    elseif key == Keyboard.KEY_EQUALS then step("y", 1)
    elseif key == Keyboard.KEY_MINUS then step("y", -1)
    elseif key == Keyboard.KEY_PERIOD then step("x", 1)
    elseif key == Keyboard.KEY_SEMICOLON then step("x", -1)
    end
end)

return WB_PoseLab
