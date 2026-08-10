--[[
    O carrinho so existe em dois lugares: no chao, ou nas maos.

    NUNCA no inventario desequipado. Ver docs/carrinho-nunca-no-inventario.md
    para o estudo; o resumo do que importa aqui:

    "Nunca no inventario" nao e implementavel ao pe da letra -- no PZ, mao e um
    slot que APONTA para um item do inventario, nao um lugar separado, entao um
    item equipado esta no inventario por definicao. A invariante que da para
    sustentar, e que entrega o mesmo na pratica, e a de duas posicoes.

    QUATRO REGRAS, e as tres primeiras existem pela experiencia enquanto a quarta
    existe pela garantia:

      R1  o carrinho nao entra em container nenhum
      R2  chao -> maos so pela acao cronometrada; a opcao "Pegar" do jogo some
      R3  maos -> chao tambem pela acao cronometrada
      R4  carrinho desequipado em inventario vai para o chao

    R4 e a rede. As outras cobrem os caminhos que eu conheco; R4 cobre os que eu
    nao conheco -- spawn pelo menu de debug, morte, outro mod transferindo, algum
    fluxo do jogo que nao mapeei. Sem ela a invariante seria "verdadeira nos casos
    que eu lembrei", que e o tipo de garantia que quebra depois de publicada.

    POR QUE TUDO NUM ARQUIVO: as quatro sao uma invariante so, vista de quatro
    lados. Separadas por arquivo, a proxima pessoa mexe numa e deixa as outras
    contradizendo -- que e exatamente como o WB_Hands quebrou duas vezes.
]]

require "TimedActions/ISWheelbarrowPickUp"
require "TimedActions/ISWheelbarrowPutDown"

local WB_Cart = require "WB_Cart"

local WB_Placement = {}

--- Evita reentrancia: largar dispara eventos que voltam para ca.
local settling = false

--- Larga o carrinho no chao imediatamente, sem animacao.
---
--- Este e o caminho da REDE (R4), nao o do jogador. O caminho do jogador tem
--- animacao e pode ser cancelado; aqui o estado ja e invalido e o objetivo e
--- so sair dele.
function WB_Placement.forceToGround(character, cart)
    if settling or character == nil or cart == nil then return end
    local square = character:getSquare()
    if square == nil then return end

    settling = true
    if character:isPrimaryHandItem(cart) then character:setPrimaryHandItem(nil) end
    if character:isSecondaryHandItem(cart) then character:setSecondaryHandItem(nil) end

    local container = cart:getContainer()
    if container ~= nil then container:Remove(cart) end

    square:AddWorldInventoryItem(cart, 0.5, 0.5, 0.0)
    character:resetModelNextFrame()
    settling = false
end

--- R1 + R4: procura carrinho desequipado no inventario do jogador, em qualquer
--- profundidade, e poe no chao.
---
--- A busca e recursiva porque R1 tem de valer para mochila dentro de mochila. O
--- custo e baixo: so entra em containers, e o caso comum -- nenhum carrinho solto
--- -- termina na primeira varredura rasa.
local function settleLoose(character, container, depth)
    if container == nil or depth > 3 then return end

    local items = container:getItems()
    local loose = nil
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if WB_Cart.is(item) then
            -- Equipado e o unico estado valido dentro do inventario.
            if not character:isPrimaryHandItem(item)
                and not character:isSecondaryHandItem(item) then
                loose = item
                break
            end
        elseif instanceof(item, "InventoryContainer") then
            settleLoose(character, item:getInventory(), depth + 1)
        end
    end

    -- Um por passada, e o laco recomeca: largar altera a lista que esta sendo
    -- percorrida, e continuar iterando depois disso pula elementos.
    if loose ~= nil then
        WB_Placement.forceToGround(character, loose)
        settleLoose(character, container, depth)
    end
end

function WB_Placement.enforce(character)
    if settling or character == nil then return end
    settleLoose(character, character:getInventory(), 0)
end

local function enforceAll()
    for i = 0, getNumActivePlayers() - 1 do
        WB_Placement.enforce(getSpecificPlayer(i))
    end
end

Events.OnContainerUpdate.Add(enforceAll)

-- R3 por tabela: desequipar deixa o carrinho no inventario, e OnContainerUpdate
-- nem sempre dispara nesse caminho. Estes dois pegam o momento exato em que a
-- mao esvazia.
Events.OnEquipPrimary.Add(function(character, _item) WB_Placement.enforce(character) end)
Events.OnEquipSecondary.Add(function(character, _item) WB_Placement.enforce(character) end)

--[[
    R2: tira a opcao "Pegar" do jogo do menu do carrinho no chao.

    Era o furo que o Marcos encontrou: "Pegar" punha o carrinho na bolsa sem
    animacao, e de la o jogador equipava -- nunca passando pela acao que pode ser
    cancelada. Removendo, sobra um caminho so, e ele custa tempo.

    Roda DEPOIS do jogo montar o menu, porque so da para remover o que ja existe.
    Nosso proprio handler adiciona a opcao de pegar em WB_ContextMenu; a ordem
    entre os dois nao importa, porque removemos por nome e o nome e outro.
]]
Events.OnFillWorldObjectContextMenu.Add(function(_player, context, worldobjects, _test)
    local carts, others = 0, 0
    for _, obj in ipairs(worldobjects) do
        if instanceof(obj, "IsoWorldInventoryObject") then
            if WB_Cart.is(obj:getItem()) then carts = carts + 1 else others = others + 1 end
        end
    end
    if carts == 0 then return end

    -- SO quando o carrinho esta sozinho na square.
    --
    -- Remover por NOME e grosseiro: "Pegar" e "Pegar tudo" valem para a square
    -- inteira, nao por item. Se houver outra coisa caida ali, tira-las deixaria
    -- o jogador sem como pegar aquilo -- consertar o furo do carrinho quebrando o
    -- resto do chao e um mau negocio.
    --
    -- Com outros itens presentes, quem segura a regra e a rede: pegar o carrinho
    -- o poe no inventario, e R4 o devolve ao chao no mesmo evento. O furo fecha
    -- de qualquer jeito; so nao fica tao limpo na tela.
    if others > 0 then return end

    context:removeOptionByName(getText("ContextMenu_Grab"))
    context:removeOptionByName(getText("ContextMenu_Grab_all"))
end)

--[[
    Tecla de interagir: pega o carrinho perto, ou larga o que esta na mao.

    A mesma tecla nos dois sentidos, como num veiculo. E ela e tratada por NOS,
    de proposito: o caminho de veiculo do jogo depende de BaseVehicle.getBestSeat,
    cujo bytecode inteiro e `iconst_m1; ireturn` -- sempre -1, para qualquer
    veiculo, na B42. Aquele caminho nunca funciona sozinho, e isso ja custou tres
    rodadas de investigacao neste projeto.
]]
local SEARCH_RADIUS = 1

local function nearestCartOnGround(character)
    local best, bestObject = nil, nil
    WB_Cart.forEachOnGround(character, SEARCH_RADIUS, function(item, obj, _sq)
        if best == nil then
            best, bestObject = item, obj
        end
    end)
    return best, bestObject
end

Events.OnKeyPressed.Add(function(key)
    if not getCore():isKey("Interact", key) then return end

    local character = getSpecificPlayer(0)
    if character == nil or character:isDead() then return end
    -- Nao atropela outra acao em andamento: a tecla de interagir e compartilhada
    -- com o resto do jogo.
    if ISTimedActionQueue.isPlayerDoingAction(character) then return end

    local carried = WB_Cart.equipped(character)
    if carried ~= nil then
        ISTimedActionQueue.add(ISWheelbarrowPutDown:new(character, carried))
        return
    end

    local _item, worldItem = nearestCartOnGround(character)
    if worldItem ~= nil then
        ISTimedActionQueue.add(ISWheelbarrowPickUp:new(character, worldItem))
    end
end)

return WB_Placement
