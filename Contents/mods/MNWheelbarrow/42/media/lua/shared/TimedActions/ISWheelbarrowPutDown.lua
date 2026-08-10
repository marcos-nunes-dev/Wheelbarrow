--[[
    Largar o carrinho no chao, com animacao -- e derramando a carga se cancelar.

    Simetrica a ISWheelbarrowPickUp: mesma duracao, mesma animacao, mesma regra
    de derrame. Ver aquele arquivo para o porque de a acao ser cronometrada e de
    o cancelamento custar a carga.

    A square de destino e escolhida aqui e nao pelo jogador: o carrinho vai para
    a square a frente do personagem se ela estiver livre, senao para a dele. E o
    mesmo criterio que o jogo usa para largar movel, e evita a pergunta "onde?"
    numa acao que deve ser rapida de disparar.
]]

require "TimedActions/ISBaseTimedAction"

local WB_Sandbox = require "WB_Sandbox"
local WB_Spill = require "WB_Spill"
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
    return self.item ~= nil
        and self.character:getInventory():contains(self.item)
end

function ISWheelbarrowPutDown:update()
    self.item:setJobDelta(self:getJobDelta())
end

function ISWheelbarrowPutDown:start()
    self.item:setJobType(getText("IGUI_MNWB_PuttingDown"))
    self.item:setJobDelta(0.0)
    self:setActionAnim(CharacterActionAnims.BuildLow)
end

function ISWheelbarrowPutDown:stop()
    if getDebug() then
        print("[Wheelbarrow][ACAO] largar cancelado")
    end
    self.item:setJobDelta(0.0)
    if WB_Sandbox.get("SpillOnCancel") then
        local square = self.character:getSquare()
        WB_Spill.dump(self.item, square)
        -- O carrinho vai junto: cancelar no meio de largar e o carrinho tombando,
        -- nao o jogador se arrependendo. Simetrico ao cancelar de pegar.
        WB_Spill.dropCart(self.character, self.item, square)
    end
    ISBaseTimedAction.stop(self)
end

function ISWheelbarrowPutDown:perform()
    self.item:setJobDelta(0.0)

    local character = self.character
    -- Tirar das maos ANTES de largar: se o item sair do inventario enquanto
    -- ainda esta numa das maos, o modelo continua renderizado numa mao vazia --
    -- foi exatamente o carrinho-fantasma que WB_Hands teve de consertar.
    if character:isPrimaryHandItem(self.item) then
        character:setPrimaryHandItem(nil)
    end
    if character:isSecondaryHandItem(self.item) then
        character:setSecondaryHandItem(nil)
    end

    character:getInventory():Remove(self.item)

    local target = squareInFront(character) or character:getSquare()
    if target ~= nil then
        target:AddWorldInventoryItem(self.item, 0.5, 0.5, 0.0)
    end

    character:resetModelNextFrame()
    WB_UI.refreshContainers()
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
