--[[
    Derrama o conteudo do carrinho no chao.

    Usado quando o jogador CANCELA a acao de pegar ou de largar: o carrinho
    desequilibra e a carga vai ao chao. E a punicao por interromper a manobra, e
    o que da peso a decisao de parar no meio.

    POR QUE ESPALHA EM VEZ DE JOGAR TUDO NUMA SQUARE:

    O jogo limita o peso de itens no chao POR SQUARE. Esta em
    ISDropWorldItemAction:isValid():

        local ground = self.sq:getTotalWeightOfItemsOnFloor()
        if ground + self.item:getUnequippedWeight() > 50 then return false end

    Um carrinho cheio passa facil desse limite -- e o ponto dele e justamente
    carregar mais que isso. Despejar tudo numa square so criaria uma pilha que o
    proprio jogo considera invalida, e itens em square sobrecarregada tem
    comportamento imprevisivel ao salvar e recarregar.

    Entao o derrame respeita o mesmo orcamento que o jogo usa, e transborda para
    as squares vizinhas. Espalhar tambem e o que PARECE certo: carga que tomba
    de um carrinho rola para os lados.

    MULTIPLAYER: AddWorldInventoryItem e o caminho direto e e o que a maioria dos
    mods usa, mas nao passa pelo fluxo de acao do jogo. Num servidor dedicado
    vale conferir se os itens aparecem para os outros jogadores; se nao
    aparecerem, o conserto e enviar por comando cliente->servidor, e este arquivo
    e o unico lugar a mudar.
]]

local WB_Spill = {}
local WB_Tipping = require "WB_Tipping"
local WB_UI = require "WB_UI"

--- Mesmo teto que ISDropWorldItemAction usa para recusar um item no chao.
local SQUARE_WEIGHT_BUDGET = 50

--- Ordem de busca a partir da square de origem: o centro primeiro, depois os
--- oito vizinhos. Empilhar no centro ate o limite e so entao transbordar deixa a
--- pilha visualmente coerente com "caiu daqui".
local OFFSETS = {
    { 0, 0 },
    { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
    { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 },
}

--- @return IsoGridSquare|nil a primeira square com espaco para `weight`
local function squareWithRoom(origin, weight)
    local cell = getCell()
    if cell == nil then return nil end

    for _, offset in ipairs(OFFSETS) do
        local sq = cell:getGridSquare(
            origin:getX() + offset[1], origin:getY() + offset[2], origin:getZ())
        if sq ~= nil and not sq:isSolid() and not sq:isSolidTrans() then
            if sq:getTotalWeightOfItemsOnFloor() + weight <= SQUARE_WEIGHT_BUDGET then
                return sq
            end
        end
    end
    return nil
end

--- Esvazia o carrinho no chao ao redor de `origin`.
---
--- @param cart InventoryItem o carrinho
--- @param origin IsoGridSquare square de onde a carga cai
--- @return number quantos itens foram derramados
function WB_Spill.dump(cart, origin)
    if cart == nil or origin == nil then return 0 end
    local inv = cart:getInventory()
    if inv == nil then return 0 end

    -- Copia a lista ANTES de mexer: remover de um container enquanto se itera
    -- sobre ele pula elementos, porque os indices deslizam a cada remocao.
    local pending = {}
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        pending[#pending + 1] = items:get(i)
    end

    local dropped = 0
    for _, item in ipairs(pending) do
        local weight = item:getUnequippedWeight()
        local target = squareWithRoom(origin, weight) or origin
        inv:Remove(item)
        -- Deslocamento aleatorio dentro da square para a pilha nao virar uma
        -- coluna de itens exatamente sobrepostos.
        target:AddWorldInventoryItem(item, ZombRandFloat(0.1, 0.9),
            ZombRandFloat(0.1, 0.9), 0.0)
        dropped = dropped + 1
    end

    -- Registro so em debug. Existe porque "nao caiu nada" tem duas causas
    -- indistinguiveis em tela: a acao nao chegou a ser cancelada, ou foi
    -- cancelada e o carrinho estava vazio. O numero separa as duas.
    if dropped > 0 then
        -- O conteudo saiu do carrinho e foi para o chao: os dois paineis mudaram.
        WB_UI.refreshContainers()
    end

    if getDebug() then
        print(string.format("[Wheelbarrow][SPILL] %d itens derramados", dropped))
    end

    return dropped
end

--- Angulo do carrinho no chao, em graus, a partir de para onde o personagem olha.
---
--- worldZRotation e um float em GRAUS, e o engine o sorteia com Rand.Next(0,360)
--- quando ele chega negativo -- e por isso que item largado no chao aparece
--- torto. Definindo antes de por no mundo, o carrinho fica apontando para onde o
--- jogador estava virado, que e o que se espera de algo que acabou de ser
--- empurrado ate ali.
---
--- A conversao e a mesma que o jogo base usa em FishingRod e no forrageamento:
--- a direcao de frente vem em radianos com zero em outro eixo, dai o + pi/2.
---
--- GROUND_ROTATION_OFFSET alinha o eixo comprido da malha com a frente do
--- personagem. Comecou em zero e o carrinho saiu apontando para tras -- o eixo
--- comprido da malha aponta na direcao oposta a que eu supus. 180 inverte.
local GROUND_ROTATION_OFFSET = 180.0

local function facingDegrees(character)
    local forward = character and character:getForwardDirection()
    if forward == nil then return nil end
    local degrees = math.deg(forward:getDirection() + math.pi / 2)
        + GROUND_ROTATION_OFFSET
    return degrees % 360
end

--- Posicao DENTRO da square de destino, de 0 a 1 em cada eixo.
---
--- O centro (0.5, 0.5) deixava o carrinho longe: a square de destino e a da
--- FRENTE do personagem, entao o centro dela fica a uma tile inteira de
--- distancia. Encostar o carrinho na borda voltada para o personagem corta essa
--- distancia pela metade sem mudar de square -- e mudar de square nao serve,
--- porque na do proprio personagem o carrinho ficaria dentro dele.
---
--- Quando o destino E a square do personagem (a da frente estava bloqueada por
--- parede ou movel), o deslocamento inverte: ali o carrinho precisa ser
--- empurrado para LONGE do centro, senao nasce em cima de quem o largou.
local EDGE_PULL = 0.4

local function placementOffset(character, square)
    local forward = character and character:getForwardDirection()
    local here = character and character:getSquare()
    if forward == nil or here == nil then return 0.5, 0.5 end

    local sameSquare = (here:getX() == square:getX())
        and (here:getY() == square:getY())
    local pull = sameSquare and EDGE_PULL or -EDGE_PULL

    local ox = 0.5 + forward:getX() * pull
    local oy = 0.5 + forward:getY() * pull
    -- O engine espera a posicao dentro da square; sair de [0,1] a poria na
    -- vizinha, o que anularia a escolha de square feita por quem chamou.
    if ox < 0.05 then ox = 0.05 elseif ox > 0.95 then ox = 0.95 end
    if oy < 0.05 then oy = 0.05 elseif oy > 0.95 then oy = 0.95 end
    return ox, oy
end

--- Tira o carrinho das maos e do inventario e o poe no chao.
---
--- Mora aqui, e nao em WB_Placement, porque as timed actions tambem precisam
--- dele -- e elas vivem em shared/, enquanto WB_Placement e de cliente. Um
--- require de shared/ para client/ seria codigo morto num servidor dedicado.
---
--- @return boolean se o carrinho foi de fato para o chao
function WB_Spill.dropCart(character, cart, square)
    if character == nil or cart == nil then return false end
    square = square or character:getSquare()
    if square == nil then return false end

    -- Ja esta no chao: nada a fazer, e mexer criaria um segundo objeto.
    if cart:getWorldItem() ~= nil then return false end

    if character:isPrimaryHandItem(cart) then character:setPrimaryHandItem(nil) end
    if character:isSecondaryHandItem(cart) then character:setSecondaryHandItem(nil) end

    local container = cart:getContainer()
    if container ~= nil then container:Remove(cart) end

    -- Antes de entrar no mundo: depois de AddWorldInventoryItem o engine ja
    -- resolveu o angulo, e mudar o valor nao reposiciona o que ja foi criado.
    local degrees = facingDegrees(character)
    if degrees ~= nil then cart:setWorldZRotation(degrees) end

    local ox, oy = placementOffset(character, square)
    square:AddWorldInventoryItem(cart, ox, oy, 0.0)

    -- Toda colocacao por este caminho e NORMAL, de pe. Quem tomba chama
    -- WB_Tipping.start depois, e precisa ser depois: o construtor do objeto de
    -- mundo zera as rotacoes de inclinacao.
    WB_Tipping.reset(cart)

    character:resetModelNextFrame()
    -- O compartimento do carrinho tem de sumir da barra de containers agora, e
    -- nao no proximo clique do jogador.
    WB_UI.refreshContainers()
    return true
end

return WB_Spill
