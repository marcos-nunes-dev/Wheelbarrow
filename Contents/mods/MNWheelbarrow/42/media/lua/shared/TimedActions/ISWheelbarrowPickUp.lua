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

    ANIMACAO: "Loot", a mesma de ISGrabItemAction. Nao e uma das constantes de
    CharacterActionAnims -- setActionAnim aceita o nome cru, e foi assim que o
    jogo base resolveu pegar coisa do chao. A primeira versao usava BuildLow, que
    e martelar agachado, e o Marcos descreveu como "pregar no chao".

    Fica em shared/ porque timed action do jogo base tambem fica -- o servidor
    precisa da classe para validar a acao em multiplayer.
]]

require "TimedActions/ISBaseTimedAction"

local WB_Equip = require "WB_Equip"
local WB_Sandbox = require "WB_Sandbox"
local WB_Spill = require "WB_Spill"
local WB_Tipping = require "WB_Tipping"

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
    -- "Loot" e a mesma animacao que ISGrabItemAction usa para pegar coisa do
    -- chao. A primeira versao usava BuildLow, que e martelar agachado -- nao ha
    -- prego nenhum em erguer um carrinho.
    self:setActionAnim("Loot")
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

--- Cancelar derruba TUDO: a carga e o proprio carrinho.
---
--- O carrinho ir junto nao e detalhe. Sem isso, cancelar deixava a carga no chao
--- e o carrinho na mao do jogador -- que e a metade estranha do resultado, e foi
--- o que apareceu no teste. Interromper uma manobra dessas derruba o conjunto.
---
--- E tambem o que sustenta a invariante das duas posicoes: no meio de equipar o
--- carrinho esta no inventario, e abandonar ali seria criar exatamente o estado
--- que WB_Placement existe para impedir.
function ISWheelbarrowPickUp:spillIfEnabled()
    if not WB_Sandbox.get("SpillOnCancel") then return end
    local square = self.worldItem and self.worldItem:getSquare()
    if square == nil then square = self.character:getSquare() end
    WB_Spill.dump(self.item, square)
    -- dropTipped faz a colocacao inteira, e nao so a inclinacao: a altura do
    -- carrinho tombado so pode ser dada na criacao do objeto de mundo.
    WB_Tipping.dropTipped(self.character, self.item, square)
end

function ISWheelbarrowPickUp:perform()
    self.item:setJobDelta(0.0)

    -- Toda a sequencia de equipar vive em WB_Equip, porque o estacionamento
    -- durante acoes precisa exatamente dela. Duas copias de um trecho que
    -- depende de ordem -- e este depende, ver o comentario de setWorldItem la --
    -- e o convite para uma delas perder um passo.
    WB_Equip.toHands(self.character, self.item, self.worldItem)

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
