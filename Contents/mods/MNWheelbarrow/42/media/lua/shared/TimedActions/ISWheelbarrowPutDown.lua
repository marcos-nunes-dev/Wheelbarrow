--[[
    Largar o carrinho no chao, com animacao.

    O CARRINHO DESCE NO INICIO DA ACAO, NAO NO FIM. Essa e a diferenca em relacao
    a primeira versao, e ela conserta um artefato que o Marcos apontou: o
    carrinho SUMIA durante a animacao e reaparecia no chao no final.

    A causa e a mascara: o carrinho na mao e desenhado pela mascara de animacao
    mnwb_holdingcart, e uma acao cronometrada substitui a animacao do personagem
    enquanto roda. Sem a mascara, o modelo nao e desenhado -- o carrinho nao
    "some", ele nunca esteve na mao como objeto do mundo.

    Nao ha como manter o modelo de mao visivel durante a acao. Mas ha como o
    carrinho ficar visivel: pondo ele no CHAO logo no inicio. O personagem se
    abaixa ao lado de um carrinho que ja esta la, que e o que acontece na vida
    real e o que casa com a regra de o carrinho nunca ir para o inventario.

    Consequencia boa: cancelar deixa de ser caso especial. O carrinho ja esta no
    chao de qualquer jeito; cancelar so acrescenta o derrame da carga.

    ANIMACAO: "Loot", a mesma que ISGrabItemAction usa para pegar coisa do chao.
    A primeira versao usava BuildLow, que e martelar agachado -- o Marcos
    descreveu como "pregar no chao", e ele estava certo: nao ha prego nenhum
    nisto.
]]

require "TimedActions/ISBaseTimedAction"

local WB_Sandbox = require "WB_Sandbox"
local WB_Spill = require "WB_Spill"
local WB_Tipping = require "WB_Tipping"
local WB_Transfer = require "WB_Transfer"
local WB_UI = require "WB_UI"

ISWheelbarrowPutDown = ISBaseTimedAction:derive("ISWheelbarrowPutDown")

--- Square a frente do personagem, se der para pousar algo la.
---
--- getAdjacentSquare(dir) e o caminho do jogo -- e o que CFarming_Interact usa
--- com player:getDir(). A alternativa, somar dir:dx() e dir:dy() na mao, aparece
--- num unico arquivo do jogo inteiro; nao vale depender dela.
local function squareInFront(character)
    local here = character:getSquare()
    if here == nil then return nil end

    local dir = character:getDir()
    if dir == nil then return here end

    local target = here:getAdjacentSquare(dir)

    -- isBlockedTo cobre parede, janela fechada e movel no caminho. Sem ele o
    -- carrinho atravessaria a parede para a sala vizinha.
    if target == nil or target:isSolid() or target:isSolidTrans()
        or target:isBlockedTo(here) then
        return here
    end
    return target
end

function ISWheelbarrowPutDown:isValid()
    -- Vale enquanto o item existir. NAO da para exigir que ele esteja no
    -- inventario: a acao comeca justamente tirando ele de la.
    return self.item ~= nil
end

function ISWheelbarrowPutDown:update()
    self.item:setJobDelta(self:getJobDelta())
end

function ISWheelbarrowPutDown:start()
    self.item:setJobType(getText("IGUI_MNWB_PuttingDown"))
    self.item:setJobDelta(0.0)
    self:setActionAnim("Loot")

    -- Desce AGORA, para ficar visivel durante a animacao inteira. WB_Spill cuida
    -- de tirar das maos, remover do inventario e apontar o carrinho para onde o
    -- personagem esta virado.
    WB_Transfer.begin()
    WB_Spill.dropCart(self.character, self.item, squareInFront(self.character))
    WB_Transfer.finish()

    WB_UI.refreshContainers()
end

--- Square onde o carrinho esta agora, para o derrame cair ao redor dele.
local function cartSquare(item, character)
    local worldItem = item:getWorldItem()
    local square = worldItem and worldItem:getSquare()
    return square or character:getSquare()
end

function ISWheelbarrowPutDown:stop()
    if getDebug() then
        print("[Wheelbarrow][ACAO] largar cancelado")
    end
    self.item:setJobDelta(0.0)
    -- O carrinho ja esta no chao desde o start; cancelar so derruba a carga.
    if WB_Sandbox.get("SpillOnCancel") then
        local square = cartSquare(self.item, self.character)
        WB_Spill.dump(self.item, square)
        -- O carrinho ja esta no chao desde o start, mas dropTipped o recria: a
        -- altura do tombo so entra na criacao do objeto de mundo.
        WB_Tipping.dropTipped(self.character, self.item, square)
    end
    ISBaseTimedAction.stop(self)
end

function ISWheelbarrowPutDown:perform()
    self.item:setJobDelta(0.0)
    -- Nada a mover: o carrinho desceu no start. Terminar aqui e so soltar o
    -- personagem da animacao.
    ISBaseTimedAction.perform(self)
end

function ISWheelbarrowPutDown:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = WB_Sandbox.get("ActionDuration")
    return o
end

return ISWheelbarrowPutDown
