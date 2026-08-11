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

local WB_Sandbox = require "WB_Sandbox"
local WB_Spill = require "WB_Spill"
local WB_Tipping = require "WB_Tipping"
local WB_Transfer = require "WB_Transfer"
local WB_UI = require "WB_UI"

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

    -- Levanta antes de tudo. Se o carrinho estava tombado e fosse para a mao
    -- assim, a inclinacao ficaria gravada no ModData e ele reapareceria torto na
    -- proxima vez que fosse largado -- um tombo que o jogador nunca causou.
    WB_Tipping.reset(self.item)

    -- A rede de WB_Placement poe no chao todo carrinho desequipado que encontre
    -- num inventario, e para equipar o carrinho precisa passar por esse estado:
    -- AddItem vem antes de setPrimaryHandItem. Sem suspender, a rede o teleporta
    -- para os pes do jogador no meio da acao -- que foi exatamente o sintoma
    -- observado, "traz o carrinho ate onde estou mas nao equipa".
    WB_Transfer.begin()

    if self.worldItem ~= nil then
        --[[ A SEQUENCIA E COPIADA DE ISGrabItemAction:transferItem, e nao
             inventada -- a minha tinha tres passos a menos e o que faltava era
             justamente o ultimo:

                 setWorldItem(nil)

             Sem ele o item continua APONTANDO para o objeto de mundo que acabou
             de sair da square. getWorldItem() segue devolvendo algo, e tres
             lugares leem isso como "ja esta no chao": WB_Player desequipa por
             quadro, WB_Hands desequipa ao equipar, e WB_Spill.dropCart nao faz
             nada. O sintoma foi o carrinho cair no inventario desequipado e
             recusar qualquer tentativa de equipar. Uma referencia pendurada,
             tres defeitos. ]]
        local square = self.worldItem:getSquare()
        if square ~= nil then
            square:transmitRemoveItemFromSquare(self.worldItem)
        end
        self.worldItem:removeFromWorld()
        self.worldItem:removeFromSquare()
        self.worldItem:setSquare(nil)
        self.item:setWorldItem(nil)
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
    -- Sem isto o compartimento do carrinho so aparecia na barra de containers
    -- depois de o jogador clicar em alguma coisa.
    WB_UI.refreshContainers()

    WB_Transfer.finish()

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
