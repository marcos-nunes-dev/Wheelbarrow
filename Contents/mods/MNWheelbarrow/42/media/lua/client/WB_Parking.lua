--[[
    Enquanto o personagem executa uma acao, o carrinho fica NO CHAO -- e volta
    para as maos sozinho quando a fila de acoes termina.

    ----------------------------------------------------------------------
    O CAMINHO ATE AQUI, porque ele explica o desenho

    Com o carrinho equipado, mover um item para dentro dele fazia o carrinho
    desaparecer durante a animacao. A causa esta escrita no jogo:

        ISGrabItemAction:start()                  setOverrideHandModels(nil, nil)
        ISInventoryTransferAction:doActionAnim()  setOverrideHandModels(nil, nil)

    e mais 50 acoes vanilla. A acao MANDA o engine nao desenhar nada nas maos.

    A primeira correcao foi devolver o modelo do carrinho nessa chamada. Funcionou
    -- e ficou pior. A animacao "Loot" agacha e mexe as maos, e um carrinho
    grudado nelas acompanha o agachamento inteiro. Visivel e errado e pior que
    invisivel: parece defeito, nao parece carrinho.

    O certo era o obvio depois de visto: o personagem LARGA o carrinho, mexe nos
    itens com as maos livres, e pega de volta. E o que uma pessoa faz.

    ----------------------------------------------------------------------
    POR QUE O GANCHO CONTINUA SENDO setOverrideHandModels

    Porque a chamada e exatamente o sinal de que precisamos: e a acao dizendo
    "quero as maos vazias". Nao ha lista de acoes para manter, e vale para acoes
    de outros mods.

    E o sinal e mais preciso do que parece. ISInventoryTransferAction:doActionAnim
    SAI ANTES da chamada quando o personagem esta andando -- nesse caso usa
    "DropWhileMoving", que nao agacha e nao tem o problema. Ou seja: o gancho
    dispara nos casos que precisam e fica quieto nos que nao precisam, de graca.

    ----------------------------------------------------------------------
    A VOLTA E INSTANTANEA, de proposito

    Pegar o carrinho tem timed action e derrama a carga se cancelar. Aqui nao:
    o custo daquela mecanica existe porque interromper uma manobra de erguer peso
    deve doer. Aqui o jogador nao pediu para pegar o carrinho -- ele nunca pediu
    para solta-lo. Cobrar tempo e risco por uma manobra que o mod inventou seria
    punir o jogador por uma decisao nossa.
]]

local WB_Cart = require "WB_Cart"
local WB_Equip = require "WB_Equip"
local WB_Spill = require "WB_Spill"

local WB_Parking = {}

--- Carrinhos estacionados por nos, por indice de jogador.
---
--- Chaveado por indice, e nao pelo personagem: a tabela e de vida longa e uma
--- chave por objeto de personagem vazaria memoria a cada morte ou troca de save.
--- Indice de jogador e limitado a tela dividida.
local parked = {}

--- Quantas squares de distancia ainda contam como "o carrinho esta aqui".
---
--- Existe porque o jogador PODE se afastar durante a acao: transferencia sem
--- stopOnWalk continua valendo enquanto ele anda. Se ele foi embora, o carrinho
--- fica onde foi deixado -- e o certo, e o contrario seria o carrinho voando de
--- volta atravessando a distancia.
local REACH = 2

--- @return boolean se ainda ha acao rodando ou na fila
---
--- As duas checagens importam. getCharacterActions e a acao EM EXECUCAO; a fila
--- do Lua guarda as que ainda vao comecar. Transferir dez itens sao dez acoes
--- enfileiradas, e olhar so a primeira faria o carrinho subir e descer dez vezes.
local function stillWorking(character)
    if not character:getCharacterActions():isEmpty() then return true end
    local queue = ISTimedActionQueue.queues[character]
    return queue ~= nil and queue.queue[1] ~= nil
end

--- @return boolean se o carrinho ainda esta no chao ao alcance do personagem
local function withinReach(character, cart)
    local worldItem = cart:getWorldItem()
    if worldItem == nil then return false end
    local from, to = character:getSquare(), worldItem:getSquare()
    if from == nil or to == nil then return false end
    if from:getZ() ~= to:getZ() then return false end
    return math.abs(from:getX() - to:getX()) <= REACH
        and math.abs(from:getY() - to:getY()) <= REACH
end

--- Devolve o carrinho as maos se a fila de acoes terminou.
---
--- Chamado do handler por quadro de WB_Player, e nao de um OnPlayerUpdate proprio:
--- o mod tem UM trabalho por quadro de proposito, e a ordem entre as regras
--- deixaria de ser legivel se cada arquivo registrasse o seu.
function WB_Parking.restoreIfIdle(character)
    local playerNum = character:getPlayerNum()
    local cart = parked[playerNum]
    if cart == nil then return end
    if stillWorking(character) then return end

    parked[playerNum] = nil

    if character:isDead() then return end

    -- Maos ocupadas: o jogador equipou outra coisa durante a acao. A escolha dele
    -- vale mais do que a nossa devolucao -- arrancar uma arma da mao de alguem
    -- porque o mod tinha um carrinho guardado seria indefensavel.
    if character:getPrimaryHandItem() ~= nil
        or character:getSecondaryHandItem() ~= nil then
        return
    end

    if not withinReach(character, cart) then return end

    WB_Equip.toHands(character, cart)
    if getDebug() then
        print("[Wheelbarrow][ESTACIONA] carrinho devolvido as maos")
    end
end

Events.OnGameStart.Add(function()
    local original = ISBaseTimedAction.setOverrideHandModels

    ISBaseTimedAction.setOverrideHandModels = function(self, primary, secondary,
                                                      resetModel)
        -- So quando a acao pede a mao vazia. Se ela pos uma ferramenta ali, a
        -- ferramenta manda: e o que a animacao esta mostrando o personagem usar.
        if primary == nil and instanceof(self.character, "IsoPlayer") then
            local cart = WB_Cart.equipped(self.character)
            local playerNum = self.character:getPlayerNum()

            -- Ja estacionado por nos: a fila enfileira uma acao por item, e cada
            -- uma chama isto. Sem esta saida, o segundo item recriaria o objeto de
            -- mundo a toa.
            if cart ~= nil and parked[playerNum] == nil then
                if WB_Spill.dropCart(self.character, cart, nil) then
                    parked[playerNum] = cart
                else
                    -- Nao deu para largar -- sem square valida, por exemplo.
                    -- O carrinho fica na mao, e ai o menos pior e ele aparecer:
                    -- passar o nil de volta o faria sumir, que era o defeito
                    -- original.
                    --
                    -- O NOME DO MODELO, nunca o item. Passar o item aplica junto a
                    -- mascara de mao dele, que conflita com a animacao da acao.
                    -- ISLightFromPetrol comenta exatamente isso no jogo base.
                    primary = cart:getStaticModel()
                end
            end
        end

        return original(self, primary, secondary, resetModel)
    end
end)

return WB_Parking
