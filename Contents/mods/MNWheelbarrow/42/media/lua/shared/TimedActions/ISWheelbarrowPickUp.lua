--[[
    Tomar o carrinho nas maos, com animacao -- derramando a carga se cancelar.

    Serve aos DOIS caminhos, e por isso o worldItem e opcional:

        do chao        worldItem preenchido, o objeto sai da square
        do inventario  worldItem nil, so as maos mudam

    Um caminho so, porque a regra e a mesma nos dois: erguer o carrinho leva
    tempo e desistir no meio derruba a carga. Duas classes quase iguais era o
    convite para uma delas esquecer o derrame.

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
    if self.item == nil then return false end
    if self.worldItem == nil then
        -- Vindo do inventario: basta o item continuar sendo do jogador.
        return self.character:getInventory():contains(self.item)
    end
    -- Vindo do chao: o objeto pode ter sumido no meio da acao -- outro jogador
    -- pegou, o chunk descarregou, um zumbi empurrou. getSquare vira nil.
    return self.worldItem:getSquare() ~= nil
end

function ISWheelbarrowPickUp:update()
    if self.worldItem ~= nil then
        self.character:faceThisObject(self.worldItem)
    end
    self.item:setJobDelta(self:getJobDelta())
end

function ISWheelbarrowPickUp:start()
    self.item:setJobType(getText("IGUI_MNWB_PickingUp"))
    self.item:setJobDelta(0.0)
    self:setActionAnim(CharacterActionAnims.BuildLow)
    self:setOverrideHandModels(nil, nil)
end

function ISWheelbarrowPickUp:stop()
    if getDebug() then
        print("[Wheelbarrow][ACAO] pegar cancelado, do "
            .. (self.worldItem ~= nil and "chao" or "inventario"))
    end
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

    if self.worldItem ~= nil then
        local square = self.worldItem:getSquare()
        if square ~= nil then
            square:transmitRemoveItemFromSquare(self.worldItem)
            square:getWorldObjects():remove(self.worldItem)
            square:RemoveTileObject(self.worldItem)
        end
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

--- @param worldItem IsoWorldInventoryObject|nil nil quando vem do inventario
--- @param item InventoryItem obrigatorio quando worldItem e nil
function ISWheelbarrowPickUp:new(character, worldItem, item)
    local o = ISBaseTimedAction.new(self, character)
    o.worldItem = worldItem
    o.item = item or (worldItem and worldItem:getItem())
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = WB_Sandbox.get("ActionDuration")
    return o
end

return ISWheelbarrowPickUp
