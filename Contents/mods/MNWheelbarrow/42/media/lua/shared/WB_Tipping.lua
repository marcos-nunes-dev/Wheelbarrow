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
    A QUEDA, E O QUE O ATLAS COBRA POR ELA

    O desenho do item no chao e cacheado num ATLAS indexado pelos parametros,
    inclusive a rotacao. Cada combinacao distinta de angulos tende a virar uma
    entrada nova, entao "quantos angulos diferentes" e uma decisao de custo e nao
    so de estetica.

    Duas escolhas mantem esse total limitado e reaproveitavel:

      passos fixos      dez posicoes, sempre as mesmas, em vez de interpolar por
                        quadro
      guinada em oito   a direcao da queda e arredondada para oito direcoes. A
                        guinada em si e continua, e sem arredondar cada tombo
                        geraria angulos ineditos para sempre. O erro maximo e
                        22.5 graus na direcao da queda -- invisivel em meio
                        segundo de movimento.

    Total possivel: dez passos x oito direcoes, e cada um so nasce quando e
    usado. A primeira versao tinha quatro passos e caia num eixo fixo do mundo;
    era barata e parecia travada, e ainda tombava na diagonal.
]]

local WB_Tipping = {}

--- Marca no ModData do item. Precisa persistir: a rotacao nao sobrevive ao
--- recarregamento, porque o objeto de mundo e recriado e o construtor a zera.
local TIPPED_KEY = "MNWB_tipped"

--- Angulo final da queda e quantos passos ate la.
local TIP_FINAL = 86
local TIP_STEPS = 10
local TIP_STEP_MS = 42

--- Fase entre a guinada do carrinho e o eixo em que ele deve tombar.
---
--- Se ele cair para a frente em vez de para o lado, somar ou subtrair 90 aqui.
local TIP_PHASE = 0.0

--- Direcoes distintas usadas ao decompor a queda.
---
--- A guinada e continua, mas os angulos de inclinacao vao para um ATLAS
--- indexado por eles: guinada continua geraria entradas novas a cada tombo, para
--- sempre. Arredondar para oito direcoes limita o total a passos x 8, e todas
--- viram cache depois do primeiro uso. O erro maximo e 22.5 graus na direcao da
--- queda, invisivel num movimento de meio segundo.
local TIP_DIRECTIONS = 8

--- Angulo do passo i, acelerando.
---
--- Quadratico e nao linear porque queda e acelerada: linear parecia o carrinho
--- sendo baixado por um cabo, e foi parte do que o Marcos leu como "nada
--- fluida". O resto era so a contagem de passos, que era quatro.
local function stepAngle(step)
    local t = step / TIP_STEPS
    return TIP_FINAL * t * t
end

--- Espalha a inclinacao entre os DOIS eixos horizontais, conforme a guinada.
---
--- Inclinar num eixo so do mundo faz a direcao da queda depender de para onde o
--- carrinho aponta -- foi por isso que ele tombava na diagonal. Decompondo a
--- inclinacao pela guinada, o eixo efetivo passa a ser o do proprio carrinho, e
--- ele tomba sempre para o mesmo lado em relacao a si mesmo.
local function applyAngle(cart, degrees)
    local step = 360.0 / TIP_DIRECTIONS
    local yaw = math.floor((cart:getWorldZRotation() + TIP_PHASE) / step + 0.5) * step
    local radians = math.rad(yaw)
    cart:setWorldXRotation(degrees * math.cos(radians))
    cart:setWorldYRotation(degrees * math.sin(radians))
end

--- Tombos em andamento.
---
--- LISTA, e nao tabela indexada pelo item, por um motivo concreto: a primeira
--- versao usava `next(falling)` para saber se havia trabalho, e isso quebrou em
--- jogo -- o depurador de Lua parou na linha. `next` aparece UMA vez em todo o
--- Lua do jogo base, e ainda assim na forma de dois argumentos; nao vale
--- depender de um canto do sandbox que o proprio jogo nao exercita.
---
--- Uma lista resolve sem construcao exotica: o tamanho responde "ha trabalho?" e
--- o laco de tras para frente permite remover durante a iteracao sem pular
--- elementos.
local falling = {}

--- @return number|nil indice do tombo em andamento deste carrinho
local function indexOf(cart)
    for i = 1, #falling do
        if falling[i].cart == cart then return i end
    end
    return nil
end

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

    local existing = indexOf(cart)
    local entry = { cart = cart, step = 0, due = getTimestampMs() }
    if existing then
        falling[existing] = entry
    else
        falling[#falling + 1] = entry
    end
end

--- Devolve o carrinho a posicao normal. Idempotente: chamar num carrinho que
--- nunca tombou nao custa nada.
function WB_Tipping.reset(cart)
    if cart == nil then return end

    local pending = indexOf(cart)
    if pending then table.remove(falling, pending) end
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
    -- Com um tombo em andamento, quem manda na rotacao e o laco de OnTick.
    if indexOf(cart) ~= nil then return end

    -- A soma das duas componentes so e zero quando o carrinho esta em pe, entao
    -- ela serve para detectar que a inclinacao foi perdida no recarregamento.
    local tilt = math.abs(cart:getWorldXRotation())
        + math.abs(cart:getWorldYRotation())
    if tilt < 0.5 then
        applyAngle(cart, TIP_FINAL)
    end
end

Events.OnTick.Add(function()
    if #falling == 0 then return end

    local now = getTimestampMs()
    -- De tras para frente: table.remove desloca os indices seguintes, e um laco
    -- crescente pularia o elemento logo apos cada remocao.
    for i = #falling, 1, -1 do
        local state = falling[i]
        local cart = state.cart

        -- O carrinho pode ter saido do chao no meio da queda, se o jogador o
        -- pegou. Sem esta checagem a rotacao continuaria avancando num item que
        -- ja esta na mao, e ele reapareceria torto ao ser largado.
        if cart:getWorldItem() == nil then
            table.remove(falling, i)
        elseif now >= state.due then
            state.step = state.step + 1
            applyAngle(cart, stepAngle(state.step))
            if state.step >= TIP_STEPS then
                table.remove(falling, i)
            else
                state.due = now + TIP_STEP_MS
            end
        end
    end
end)

return WB_Tipping
