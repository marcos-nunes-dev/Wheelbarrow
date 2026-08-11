--[[
    Calibracao da pose do carrinho TOMBADO, ao vivo.

    DESCARTAVEL. Sai antes de publicar; os valores achados viram os padroes em
    WB_Tipping.

    POR QUE ESTE LABORATORIO NAO PRECISA DE MALHAS, ao contrario do da pose de
    mao: inclinacao e altura sao valores de RUNTIME, nao geometria assada. Da
    para mudar os dois e reaplicar no mesmo quadro, sem reiniciar o jogo e sem os
    megabytes de variantes que a calibracao lateral custou.

      ]  [   inclinacao, 4 graus por passo
      .  ,   altura, 0.02 por passo
      =  -   direcao do carrinho deitado, 15 graus por passo

    AS TECLAS SAO POR POSICAO FISICA, nao pelo simbolo impresso: os codigos do
    LWJGL sao de scancode. Num teclado ABNT2, a posicao que o layout americano
    chama de ";" e onde fica o C-cedilha, entao KEY_SEMICOLON nunca disparava --
    era o que fazia a altura so subir. Ponto e virgula ocupam a mesma posicao nos
    dois layouts, e por isso sao o par usado aqui.

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
local YAW_STEP = 15.0
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

--- @param keepHeading boolean manter a direcao atual em vez de recalcular
local function adjust(character, angleDelta, heightDelta, yawDelta, keepHeading)
    local target = nearestTipped(character)
    if target == nil then
        announce(character, "nenhum carrinho tombado por perto")
        return
    end

    WB_Tipping.setAngle(WB_Tipping.getAngle() + angleDelta)
    WB_Tipping.setHeight(WB_Tipping.getHeight() + heightDelta)
    WB_Tipping.setYawOffset(WB_Tipping.getYawOffset() + yawDelta)

    -- GUARDA A DIRECAO ao ajustar inclinacao ou altura. Recolocar o carrinho o
    -- reorienta para onde o PERSONAGEM esta virado, que e o certo ao larga-lo de
    -- verdade e atrapalha aqui: durante a calibracao o jogador anda em volta para
    -- ver a pose de varios angulos, e o carrinho girava junto a cada tecla.
    --
    -- Ao ajustar a DIRECAO, o oposto: e preciso deixar o valor novo valer, senao
    -- a tecla nao faria nada visivel. Fique parado olhando para um lado ao usar
    -- essas duas.
    local heading = keepHeading and target.cart:getWorldZRotation() or nil

    WB_Tipping.dropTipped(character, target.cart, target.square)

    if heading ~= nil then
        target.cart:setWorldZRotation(heading)
    end

    announce(character, string.format("inclinacao %.0f  altura %.2f  direcao %.0f",
        WB_Tipping.getAngle(), WB_Tipping.getHeight(), WB_Tipping.getYawOffset()))
end

Events.OnKeyPressed.Add(function(key)
    if not getCore():getDebug() then return end

    local character = getSpecificPlayer(0)
    if character == nil or character:isDead() then return end

    if key == Keyboard.KEY_RBRACKET then adjust(character, ANGLE_STEP, 0, 0, true)
    elseif key == Keyboard.KEY_LBRACKET then adjust(character, -ANGLE_STEP, 0, 0, true)
    elseif key == Keyboard.KEY_PERIOD then adjust(character, 0, HEIGHT_STEP, 0, true)
    elseif key == Keyboard.KEY_COMMA then adjust(character, 0, -HEIGHT_STEP, 0, true)
    elseif key == Keyboard.KEY_EQUALS then adjust(character, 0, 0, YAW_STEP, false)
    elseif key == Keyboard.KEY_MINUS then adjust(character, 0, 0, -YAW_STEP, false)
    end
end)

return WB_TipLab
