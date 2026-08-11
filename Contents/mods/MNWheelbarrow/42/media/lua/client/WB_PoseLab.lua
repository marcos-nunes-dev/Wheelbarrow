--[[
    Calibracao lateral em jogo: [ e ] percorrem os valores de X.

    DESCARTAVEL. Sai do mod antes de publicar, junto com WB_PoseGrid.lua e os
    scripts *_poses.txt.

    POR QUE EXISTE: a pose do carrinho na mao esta assada na malha, e malha so
    recarrega no boot -- entao cada tentativa custaria um restart. Nao da para
    mudar a transformacao em runtime, mas da para trocar o ITEM, e cada item
    aponta para uma malha com um X diferente.

    So o eixo LATERAL. Altura e avanco ja convergiram; o lateral voltou a ser
    duvida quando a animacao de dois bracos mudou a pose do braco, e na tentativa
    de corrigir a olho eu errei o SINAL. Medir custa menos que chutar de novo.

      ]  aumenta X      [  diminui X

    O valor aparece na tela e no console a cada passo. Anotar o X que
    centralizar o personagem no carrinho; ele vira HAND_OFFSET em
    assets/tools_build_models.py.

    So responde a teclas com o jogo em debug: e ferramenta de desenvolvimento.
]]

local GRID = require "WB_PoseGrid"

local WB_PoseLab = {}

--- Comeca no valor que o item real usa hoje, e nao numa ponta do intervalo:
--- assim o primeiro passo para cada lado ja e comparavel com o que esta em uso.
local function startIndex()
    for i, v in ipairs(GRID.x) do
        if math.abs(v - 0.26) < 0.001 then return i end
    end
    return 1
end

local index = startIndex()
local started = false

local function announce(character, text)
    print("[Wheelbarrow][LATERAL] " .. text)
    if HaloTextHelper and HaloTextHelper.addText then
        if pcall(HaloTextHelper.addText, character, text) then return end
    end
    pcall(function() character:setHaloNote(text) end)
end

--- Tira do inventario as variantes anteriores, para a varredura nao encher o
--- inventario de carrinhos.
local function clearVariants(character)
    local inv = character:getInventory()
    for i = 1, #GRID.x do
        local id = string.format("%s%02d", GRID.prefix, i)
        local item = inv:FindAndReturn(id)
        while item ~= nil do
            if character:isPrimaryHandItem(item) then character:setPrimaryHandItem(nil) end
            if character:isSecondaryHandItem(item) then character:setSecondaryHandItem(nil) end
            inv:Remove(item)
            item = inv:FindAndReturn(id)
        end
    end
end

function WB_PoseLab.apply(character)
    clearVariants(character)

    local id = string.format("%s%02d", GRID.prefix, index)
    local item = character:getInventory():AddItem(id)
    if item == nil then
        announce(character, id .. " nao existe; o script de poses nao carregou")
        return
    end

    character:setPrimaryHandItem(item)
    character:setSecondaryHandItem(item)
    character:resetModelNextFrame()

    announce(character, string.format("X = %.2f  (%d/%d)",
        GRID.x[index], index, #GRID.x))
end

local function step(delta)
    if not getCore():getDebug() then return end

    local character = getSpecificPlayer(0)
    if character == nil or character:isDead() then return end

    -- O primeiro toque so entrega a variante inicial, sem andar: assim o ponto de
    -- partida e o mesmo independente de qual tecla foi apertada primeiro.
    if not started then
        started = true
    else
        index = ((index - 1 + delta) % #GRID.x) + 1
    end

    WB_PoseLab.apply(character)
end

Events.OnKeyPressed.Add(function(key)
    if key == Keyboard.KEY_RBRACKET then step(1)
    elseif key == Keyboard.KEY_LBRACKET then step(-1)
    end
end)

return WB_PoseLab
