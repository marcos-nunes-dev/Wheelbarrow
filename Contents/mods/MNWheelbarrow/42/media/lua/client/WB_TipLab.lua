--[[
    Calibracao da pose do carrinho TOMBADO, ao vivo.

    DESCARTAVEL. Sai antes de publicar; os valores achados viram os padroes em
    WB_Tipping.

    POR QUE ESTE LABORATORIO NAO PRECISA DE MALHAS, ao contrario do da pose de
    mao: inclinacao e altura sao valores de RUNTIME, nao geometria assada. Da
    para mudar os dois e reaplicar no mesmo quadro, sem reiniciar o jogo e sem os
    megabytes de variantes que a calibracao lateral custou.

      ]  [   inclinacao, 4 graus por passo
      .  ;   altura, 0.02 por passo

    Cada tecla reaplica no carrinho tombado mais proximo. Nao ha nenhum por
    perto? Derrube um: equipe o carrinho, aperte E para largar e cancele a acao.

    Os dois valores aparecem na tela e no console. Anotar a dupla que ficar boa.

    So responde a teclas com o jogo em debug.
]]

local WB_Cart = require "WB_Cart"
local WB_Tipping = require "WB_Tipping"

local WB_TipLab = {}

local ANGLE_STEP = 4.0
local HEIGHT_STEP = 0.02
local SEARCH_RADIUS = 2

local function announce(character, text)
    print("[Wheelbarrow][TOMBO] " .. text)
    if HaloTextHelper and HaloTextHelper.addText then
        if pcall(HaloTextHelper.addText, character, text) then return end
    end
    pcall(function() character:setHaloNote(text) end)
end

--- Carrinho TOMBADO mais proximo. So os tombados: reaplicar num carrinho de pe
--- o derrubaria, o que nao e o que a tecla deve fazer.
local function nearestTipped(character)
    local found = nil
    WB_Cart.forEachOnGround(character, SEARCH_RADIUS, function(cart, _obj, square)
        if found == nil and WB_Tipping.isTipped(cart) then
            found = { cart = cart, square = square }
        end
    end)
    return found
end

local function adjust(character, angleDelta, heightDelta)
    local target = nearestTipped(character)
    if target == nil then
        announce(character, "nenhum carrinho tombado por perto")
        return
    end

    WB_Tipping.setAngle(WB_Tipping.getAngle() + angleDelta)
    WB_Tipping.setHeight(WB_Tipping.getHeight() + heightDelta)

    -- Recria com os valores novos. A altura so pode ser dada na criacao, entao
    -- nao ha como ajusta-la sem repor o objeto -- ver WB_Tipping.dropTipped.
    WB_Tipping.dropTipped(character, target.cart, target.square)

    announce(character, string.format("inclinacao %.0f  altura %.2f",
        WB_Tipping.getAngle(), WB_Tipping.getHeight()))
end

Events.OnKeyPressed.Add(function(key)
    if not getCore():getDebug() then return end

    local character = getSpecificPlayer(0)
    if character == nil or character:isDead() then return end

    if key == Keyboard.KEY_RBRACKET then adjust(character, ANGLE_STEP, 0)
    elseif key == Keyboard.KEY_LBRACKET then adjust(character, -ANGLE_STEP, 0)
    elseif key == Keyboard.KEY_PERIOD then adjust(character, 0, HEIGHT_STEP)
    elseif key == Keyboard.KEY_SEMICOLON then adjust(character, 0, -HEIGHT_STEP)
    end
end)

return WB_TipLab
