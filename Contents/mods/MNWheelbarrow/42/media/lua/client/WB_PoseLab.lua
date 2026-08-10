--[[
    Laboratorio de pose: percorre as poses do carrinho com uma tecla.

    DESCARTAVEL. Sai do mod antes de publicar, junto com WB_PoseGrid.lua e os
    scripts items_wheelbarrow_poses.txt / models_wheelbarrow_poses.txt.

    POR QUE ISTO EXISTE:
    a pose do item na mao esta assada na malha -- o bloco `attachment
    Bip01_Prop2`, que seria o caminho declarativo, foi testado com oito rotacoes
    e as oito renderizaram identicas, entao o engine o ignora neste caminho.
    Malha e script so recarregam no boot, entao cada tentativa de pose custava um
    RESTART do jogo. Quatro rodadas foram gastas a tres variantes por rodada.

    A troca: assar todas as poses de uma vez (24 malhas, as rotacoes alinhadas
    aos eixos) e trocar o ITEM em runtime, que e coisa que o Lua faz. O custo do
    restart deixa de multiplicar pelo numero de tentativas.

    COMO USAR:
      1. equipar qualquer carrinho de teste, ou nenhum -- a primeira tecla ja
         entrega a pose 1 na mao
      2. ] avanca, [ volta
      3. os angulos aparecem na tela; anotar o numero da pose que ficar certa

    So roda com o jogo em debug: e ferramenta de desenvolvimento, e nao deve
    responder a teclas na maquina de um jogador.
]]

local POSES = require "WB_PoseGrid"

local WB_PoseLab = {}

local index = 0

local function announce(player, text)
    -- HaloTextHelper e o caminho do jogo para texto flutuante sobre o
    -- personagem. Guardado porque e UI e nao vale derrubar a ferramenta se a
    -- assinatura mudar; o print no console e o registro que sempre sobra.
    print("[Wheelbarrow][POSE] " .. text)
    if HaloTextHelper and HaloTextHelper.addText then
        local ok = pcall(HaloTextHelper.addText, player, text)
        if ok then return end
    end
    pcall(function() player:setHaloNote(text) end)
end

--- Remove da mao e do inventario qualquer pose que ja esteja em uso, para o
--- inventario nao encher de carrinhos ao longo da varredura.
local function clearPoses(player)
    local inv = player:getInventory()
    for _, pose in ipairs(POSES) do
        local item = inv:FindAndReturn(pose.id)
        while item ~= nil do
            if player:isPrimaryHandItem(item) then player:setPrimaryHandItem(nil) end
            if player:isSecondaryHandItem(item) then player:setSecondaryHandItem(nil) end
            inv:Remove(item)
            item = inv:FindAndReturn(pose.id)
        end
    end
end

function WB_PoseLab.show(player, step)
    if player == nil or #POSES == 0 then return end

    index = index + step
    if index < 1 then index = #POSES end
    if index > #POSES then index = 1 end

    local pose = POSES[index]
    clearPoses(player)

    local item = player:getInventory():AddItem(pose.id)
    if item == nil then
        announce(player, "pose " .. index .. ": item nao existe (script nao carregou?)")
        return
    end
    player:setPrimaryHandItem(item)
    -- Sem isto o modelo do personagem pode continuar mostrando a pose anterior:
    -- ele so e reconstruido quando alguem pede.
    player:resetModelNextFrame()

    announce(player, string.format("pose %d/%d  X=%d Y=%d Z=%d",
        index, #POSES, pose.rx, pose.ry, pose.rz))
end

Events.OnKeyPressed.Add(function(key)
    if not getCore():getDebug() then return end
    local player = getSpecificPlayer(0)
    if player == nil or player:isDead() then return end

    if key == Keyboard.KEY_RBRACKET then
        WB_PoseLab.show(player, 1)
    elseif key == Keyboard.KEY_LBRACKET then
        WB_PoseLab.show(player, -1)
    end
end)

return WB_PoseLab
