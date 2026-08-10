--[[
    Pegar o carrinho do chao, com animacao -- e derramando a carga se cancelar.

    POR QUE UMA ACAO PROPRIA E NAO O "pegar" do jogo: o pegar padrao e
    instantaneo para item de inventario e nao tem como falhar no meio. O custo de
    interromper e o que da peso a decisao de parar a manobra, e ele so existe se
    a manobra levar tempo.

    A carga sai pelo WB_Spill quando o jogador cancela. Nao e punicao gratuita: o
    carrinho carrega muito mais do que uma pessoa aguenta, e desequilibrar uma
    carga dessas no meio do movimento derruba tudo.

    ANIMACAO: BuildLow -- agachar e erguer. O jogo nao tem animacao de erguer
    carrinho; as opcoes de acao sao construir, criar, desmontar, cavar e derrubar
    arvore. BuildLow e a unica que comeca agachada, que e o gesto certo para
    pegar algo do chao.

    Fica em shared/ porque timed action do jogo base tambem fica -- o servidor
    precisa da classe para validar a acao em multiplayer.
]]

require "TimedActions/ISBaseTimedAction"

local WB_Sandbox = require "WB_Sandbox"
local WB_Spill = require "WB_Spill"

ISWheelbarrowPickUp = ISBaseTimedAction:derive("ISWheelbarrowPickUp")

function ISWheelbarrowPickUp:isValid()
    -- O objeto de mundo pode ter sumido no meio da acao: outro jogador pegou, o
    -- chunk descarregou, um zumbi empurrou. getSquare vira nil nesse caso.
    return self.worldItem ~= nil
        and self.worldItem:getSquare() ~= nil
        and self.item ~= nil
end

function ISWheelbarrowPickUp:update()
    self.character:faceThisObject(self.worldItem)
    self.item:setJobDelta(self:getJobDelta())
end

function ISWheelbarrowPickUp:start()
    self.item:setJobType(getText("IGUI_MNWB_PickingUp"))
    self.item:setJobDelta(0.0)
    self:setActionAnim(CharacterActionAnims.BuildLow)
    self:setOverrideHandModels(nil, nil)
end

function ISWheelbarrowPickUp:stop()
    self.item:setJobDelta(0.0)
    self:spillIfEnabled()
    ISBaseTimedAction.stop(self)
end

--- Derrama a carga, se a opcao estiver ligada.
---
--- Vive aqui e nao em stop() porque a mesma regra vale para largar: as duas
--- acoes derramam pelo mesmo motivo, e uma so definicao evita que so uma delas
--- respeite a opcao do jogador.
function ISWheelbarrowPickUp:spillIfEnabled()
    if not WB_Sandbox.get("SpillOnCancel") then return end
    local square = self.worldItem and self.worldItem:getSquare()
    if square == nil then square = self.character:getSquare() end
    WB_Spill.dump(self.item, square)
end

function ISWheelbarrowPickUp:perform()
    self.item:setJobDelta(0.0)

    local square = self.worldItem:getSquare()
    if square ~= nil then
        square:transmitRemoveItemFromSquare(self.worldItem)
        square:getWorldObjects():remove(self.worldItem)
        square:RemoveTileObject(self.worldItem)
    end

    -- AddItem em vez do fluxo normal de transferencia de proposito: o carrinho
    -- cheio nao passaria no teste de capacidade do inventario do jogador, e e
    -- justamente isso que o carrinho existe para contornar. O peso continua
    -- contando -- o alivio vem da reducao calculada em WB_Weight, nao daqui.
    local inv = self.character:getInventory()
    if not inv:contains(self.item) then
        inv:AddItem(self.item)
    end

    self.character:setPrimaryHandItem(self.item)
    self.character:setSecondaryHandItem(self.item)
    self.character:resetModelNextFrame()

    ISBaseTimedAction.perform(self)
end

function ISWheelbarrowPickUp:new(character, worldItem)
    local o = ISBaseTimedAction.new(self, character)
    o.worldItem = worldItem
    o.item = worldItem and worldItem:getItem()
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = WB_Sandbox.get("ActionDuration")
    return o
end

return ISWheelbarrowPickUp
