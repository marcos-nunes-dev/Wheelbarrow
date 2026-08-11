--[[
    O carrinho fica TOMBADO quando a manobra e interrompida, e se levanta ao ser
    pego.

    Cancelar ja derramava a carga, mas o carrinho continuava de pe no meio dos
    itens espalhados -- o resultado nao se lia como "tombou", se lia como "os
    itens sairam sozinhos". A inclinacao e o que conta a historia.

    ----------------------------------------------------------------------
    NAO HA ANIMACAO DE QUEDA, e a tentativa de fazer uma fracassou por razao
    estrutural, nao por falta de ajuste.

    O desenho de item no chao e cacheado num ATLAS indexado pelos parametros de
    render, inclusive as rotacoes. Cada angulo distinto vira uma entrada nova, e
    criar a entrada aparece em tela como um PISCA. Uma queda animada e, por
    definicao, uma sequencia de angulos distintos -- ou seja, uma sequencia de
    piscas. Foi exatamente o que apareceu em jogo: "parece baixo fps e ele pisca
    quando atualiza cada posicao".

    Passos maiores diminuem os piscas e pioram a fluidez; passos menores fazem o
    contrario. Nao ha ponto bom nesse eixo, porque o custo E a mudanca de angulo.
    Entao a pose e uma so, aplicada de uma vez.

    ----------------------------------------------------------------------
    COMO O ENGINE DESENHA ITEM NO CHAO

    InventoryItem tem tres rotacoes de mundo, lidas em
    WorldItemAtlas.ItemParams.init:

        worldXRotation  -> angle.x
        worldZRotation  -> angle.y   (a guinada, que WB_Spill usa)
        worldYRotation  -> angle.z

    Duas restricoes saem do bytecode:

    1. O construtor de IsoWorldInventoryObject ZERA worldXRotation e
       worldYRotation. A inclinacao tem de ser aplicada DEPOIS de o objeto
       existir. (A guinada escapa porque o construtor so a sorteia quando ela
       chega negativa.)

    2. Isso vale a cada criacao do objeto, e recarregar o save recria. Por isso o
       estado tombado vive no ModData do ITEM, que persiste, e a rotacao e
       reaplicada por WB_Tipping.restore.
]]

local WB_Tipping = {}

--- Marca no ModData do item. Precisa persistir: a rotacao nao sobrevive ao
--- recarregamento, porque o objeto de mundo e recriado e o construtor a zera.
local TIPPED_KEY = "MNWB_tipped"

--- Quanto o carrinho deita, em graus, e a que altura fica na square.
---
--- Ajustaveis em jogo por WB_TipLab enquanto a calibracao nao fechar. Noventa
--- graus seria deitado exato; menos deixa o carrinho apoiado, o que costuma ler
--- melhor do que perfeitamente plano.
local tipAngle = 72.0
local tipHeight = 0.0

--- Fase entre a guinada do carrinho e o eixo em que ele deve tombar.
local TIP_PHASE = 0.0

--- Direcoes distintas usadas ao decompor a inclinacao.
---
--- Inclinar num eixo fixo do MUNDO faz a direcao da queda depender de para onde
--- o carrinho aponta -- ele tombava na diagonal. Decompor pela guinada resolve,
--- mas guinada e continua e cada combinacao vira entrada de atlas. Arredondar
--- para oito direcoes limita o total e todas viram cache. O erro maximo e 22.5
--- graus na direcao da queda, invisivel num objeto deitado.
local TIP_DIRECTIONS = 8

local function applyAngle(cart, degrees)
    local step = 360.0 / TIP_DIRECTIONS
    local yaw = math.floor((cart:getWorldZRotation() + TIP_PHASE) / step + 0.5) * step
    local radians = math.rad(yaw)
    cart:setWorldXRotation(degrees * math.cos(radians))
    cart:setWorldYRotation(degrees * math.sin(radians))
end

--- @return boolean se o carrinho esta marcado como tombado
function WB_Tipping.isTipped(cart)
    return cart ~= nil and cart:hasModData()
        and cart:getModData()[TIPPED_KEY] == true
end

--- Valores atuais, para o laboratorio de calibracao mostrar.
function WB_Tipping.getAngle() return tipAngle end
function WB_Tipping.getHeight() return tipHeight end

--- Ajusta em runtime. Existe para WB_TipLab; quando a calibracao fechar, os
--- numeros viram os padroes acima e isto sai junto com o laboratorio.
function WB_Tipping.setAngle(value) tipAngle = value end
function WB_Tipping.setHeight(value) tipHeight = value end

--- Poe o carrinho no chao JA TOMBADO.
---
--- Faz a colocacao inteira em vez de so inclinar um carrinho que ja esta la, e o
--- motivo e a ALTURA: o deslocamento vertical so pode ser dado em
--- AddWorldInventoryItem, na criacao do objeto. Inclinar sem poder ajustar a
--- altura deixaria o carrinho enterrado no piso, sem conserto possivel.
function WB_Tipping.dropTipped(character, cart, square)
    if character == nil or cart == nil then return end
    square = square or character:getSquare()
    if square == nil then return end

    -- Pode ja estar no chao: cancelar o LARGAR poe o carrinho la logo no inicio
    -- da acao. Recriar mesmo assim, porque a altura so entra na criacao.
    local worldItem = cart:getWorldItem()
    if worldItem ~= nil then
        local from = worldItem:getSquare()
        if from ~= nil then
            from:transmitRemoveItemFromSquare(worldItem)
        end
        worldItem:removeFromWorld()
        worldItem:removeFromSquare()
        worldItem:setSquare(nil)
        cart:setWorldItem(nil)
    end

    if character:isPrimaryHandItem(cart) then character:setPrimaryHandItem(nil) end
    if character:isSecondaryHandItem(cart) then character:setSecondaryHandItem(nil) end
    local container = cart:getContainer()
    if container ~= nil then container:Remove(cart) end

    cart:getModData()[TIPPED_KEY] = true
    square:AddWorldInventoryItem(cart, 0.5, 0.5, tipHeight)
    -- Sempre depois da criacao: o construtor zera as duas rotacoes de inclinacao.
    applyAngle(cart, tipAngle)

    character:resetModelNextFrame()
end

--- Devolve o carrinho a posicao normal. Idempotente.
function WB_Tipping.reset(cart)
    if cart == nil then return end
    if cart:hasModData() then
        cart:getModData()[TIPPED_KEY] = nil
    end
    cart:setWorldXRotation(0.0)
    cart:setWorldYRotation(0.0)
end

--- Reaplica a inclinacao de um carrinho que ja estava tombado.
---
--- Necessario porque o construtor do objeto de mundo zera as rotacoes, e ele
--- roda de novo a cada recarregamento do save ou retorno do chunk. Sem isto, um
--- carrinho tombado se levantaria sozinho ao voltar ao jogo.
function WB_Tipping.restore(cart)
    if not WB_Tipping.isTipped(cart) then return end

    -- A soma das componentes so e zero com o carrinho em pe, entao ela detecta
    -- que a inclinacao foi perdida.
    local tilt = math.abs(cart:getWorldXRotation())
        + math.abs(cart:getWorldYRotation())
    if tilt < 0.5 then
        applyAngle(cart, tipAngle)
    end
end

return WB_Tipping
