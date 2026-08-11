--[[
    O carrinho TOMBA quando a manobra e interrompida, e se levanta ao ser pego.

    Cancelar ja derramava a carga, mas o carrinho continuava de pe no meio dos
    itens espalhados -- o resultado nao se lia como "tombou", se lia como "os
    itens sairam sozinhos". A inclinacao e o que conta a historia.

    ----------------------------------------------------------------------
    COMO O ENGINE DESENHA ITEM NO CHAO, e o que isso permite

    InventoryItem tem tres rotacoes de mundo, e o atlas de itens as le em
    WorldItemAtlas.ItemParams.init:

        worldXRotation  -> angle.x
        worldZRotation  -> angle.y   (a guinada, que WB_Spill ja usa)
        worldYRotation  -> angle.z

    DUAS restricoes saem do bytecode, e as duas moldaram este arquivo:

    1. O construtor de IsoWorldInventoryObject ZERA worldXRotation e
       worldYRotation do item. Definir a inclinacao antes de por no mundo nao
       funciona -- tem de ser depois. (A guinada escapa porque o construtor so a
       sorteia quando ela chega negativa.)

    2. Zerar acontece a cada criacao do objeto de mundo, e recarregar o save
       recria. Por isso o estado tombado vive no ModData do ITEM, que persiste, e
       a rotacao e reaplicada quando necessario -- ver WB_Tipping.restore.

    ----------------------------------------------------------------------
    POR QUE A QUEDA E EM PASSOS FIXOS

    O desenho do item no chao e cacheado num ATLAS, indexado pelos parametros --
    inclusive a rotacao. Cada angulo distinto tende a virar uma entrada nova.

    Uma queda suave, interpolada por quadro, geraria dezenas de entradas por
    tombo. Com passos FIXOS sao quatro entradas no total, reaproveitadas em todo
    tombo seguinte. A diferenca visual entre quatro passos e trinta, num
    movimento de um terco de segundo, e pequena; a diferenca de custo nao e.
]]

local WB_Tipping = {}

--- Marca no ModData do item. Precisa persistir: a rotacao nao sobrevive ao
--- recarregamento, porque o objeto de mundo e recriado e o construtor a zera.
local TIPPED_KEY = "MNWB_tipped"

--- Angulos da queda, em graus. Fixos de proposito -- ver o cabecalho.
local TIP_ANGLES = { 24, 48, 70, 86 }
local TIP_STEP_MS = 70

--- Qual eixo derruba o carrinho DE LADO.
---
--- angle.x e angle.z sao os dois eixos horizontais; qual deles e "de lado"
--- depende de como a guinada e composta antes deles, o que o bytecode nao diz de
--- forma legivel. Se o carrinho tombar para a frente em vez de para o lado, a
--- correcao e trocar por "y" aqui -- e so isso.
local TIP_AXIS = "x"

local function applyAngle(cart, degrees)
    if TIP_AXIS == "x" then
        cart:setWorldXRotation(degrees)
    else
        cart:setWorldYRotation(degrees)
    end
end

--- Tombos em andamento: item -> { passo, quando o proximo passo vence }.
local falling = {}

--- @return boolean se o carrinho esta marcado como tombado
function WB_Tipping.isTipped(cart)
    return cart ~= nil and cart:hasModData()
        and cart:getModData()[TIPPED_KEY] == true
end

--- Comeca a queda. Chamar DEPOIS de o carrinho estar no chao: antes disso a
--- rotacao seria zerada pelo construtor do objeto de mundo.
function WB_Tipping.start(cart)
    if cart == nil or cart:getWorldItem() == nil then return end

    cart:getModData()[TIPPED_KEY] = true
    falling[cart] = { step = 0, due = getTimestampMs() }
end

--- Devolve o carrinho a posicao normal. Idempotente: chamar num carrinho que
--- nunca tombou nao custa nada.
function WB_Tipping.reset(cart)
    if cart == nil then return end
    falling[cart] = nil
    if cart:hasModData() then
        cart:getModData()[TIPPED_KEY] = nil
    end
    cart:setWorldXRotation(0.0)
    cart:setWorldYRotation(0.0)
end

--- Reaplica a inclinacao de um carrinho que ja estava tombado.
---
--- Necessario porque o construtor do objeto de mundo zera as rotacoes, e ele
--- roda de novo toda vez que o save e recarregado ou o chunk volta. Sem isto, um
--- carrinho tombado se levantaria sozinho ao recarregar o jogo.
function WB_Tipping.restore(cart)
    if not WB_Tipping.isTipped(cart) then return end
    if falling[cart] ~= nil then return end

    local final = TIP_ANGLES[#TIP_ANGLES]
    local current = (TIP_AXIS == "x") and cart:getWorldXRotation()
        or cart:getWorldYRotation()
    if math.abs(current - final) > 0.5 then
        applyAngle(cart, final)
    end
end

Events.OnTick.Add(function()
    if next(falling) == nil then return end

    local now = getTimestampMs()
    for cart, state in pairs(falling) do
        -- O carrinho pode ter saido do chao no meio da queda, se o jogador o
        -- pegou. Sem esta checagem a rotacao continuaria avancando num item que
        -- ja esta na mao, e reapareceria torto ao ser largado.
        if cart:getWorldItem() == nil then
            falling[cart] = nil
        elseif now >= state.due then
            state.step = state.step + 1
            applyAngle(cart, TIP_ANGLES[state.step])
            if state.step >= #TIP_ANGLES then
                falling[cart] = nil
            else
                state.due = now + TIP_STEP_MS
            end
        end
    end
end)

return WB_Tipping
