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
      R2  chao -> maos so pela acao cronometrada; o "Pegar" do jogo e desviado
          para ela, por qualquer caminho de menu
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
local WB_Spill = require "WB_Spill"
local WB_Transfer = require "WB_Transfer"

local WB_Placement = {}

--- Evita reentrancia: largar dispara eventos que voltam para ca.
local settling = false

--- Larga o carrinho no chao imediatamente, sem animacao.
---
--- Este e o caminho da REDE (R4), nao o do jogador. O caminho do jogador tem
--- animacao e pode ser cancelado; aqui o estado ja e invalido e o objetivo e so
--- sair dele.
---
--- A colocacao em si e de WB_Spill, que e quem as timed actions tambem usam ao
--- cancelar. Duas copias divergiriam no dia em que uma delas ganhasse um passo a
--- mais -- e aqui esquecer de tirar das maos deixaria o carrinho-fantasma.
function WB_Placement.forceToGround(character, cart)
    if settling then return end
    settling = true
    WB_Spill.dropCart(character, cart)
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
    if settling or WB_Transfer.active() or character == nil then return end
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
    R2: pegar um carrinho do chao vira a NOSSA acao, por qualquer caminho.

    A primeira tentativa removia a opcao "Pegar" do menu por NOME, e nao
    funcionou por dois motivos. O nome nao e unico -- ha oito pontos no jogo que
    criam essa opcao, e o menu do chao nao e o mesmo do painel de chao do
    inventario. E remover por nome e grosseiro: "Pegar" vale para a square
    inteira, entao tira-la com outros itens caidos ali deixaria o jogador sem
    como pegar aquilo.

    Interceptar a ACAO resolve os dois de uma vez. Todos os oito caminhos
    terminam em ISGrabItemAction:new, entao envolvemos o construtor: quando o
    objeto e um carrinho, devolvemos a nossa acao no lugar. Ela deriva da mesma
    base, entao a fila trata as duas igual, e quem chamou nao precisa saber.

    O menu continua com as opcoes do jogo, no lugar de sempre -- so o que elas
    fazem muda.
]]
Events.OnGameStart.Add(function()
    if ISGrabItemAction ~= nil then
        local original = ISGrabItemAction.new
        ISGrabItemAction.new = function(self, character, worldItem, time)
            if worldItem ~= nil and instanceof(worldItem, "IsoWorldInventoryObject")
                and WB_Cart.is(worldItem:getItem()) then
                return ISWheelbarrowPickUp:new(character, worldItem)
            end
            return original(self, character, worldItem, time)
        end
    end

    --[[ SEGUNDO caminho, e foi por ele que o "Pegar" continuou funcionando: o
         painel de CHAO do inventario nao usa ISGrabItemAction. Ele chama
         onGrabItems, que enfileira uma transferencia comum. Dois menus com o
         mesmo rotulo e implementacoes diferentes -- razao a mais para o desvio
         ser por acao e nao por nome de opcao.

         Aqui a lista e PARTIDA: carrinhos vao para a nossa acao e o resto segue
         pelo caminho do jogo. Desviar a lista inteira faria pegar um carrinho
         junto com outros itens deixar os outros para tras. ]]
    if ISInventoryPaneContextMenu ~= nil and ISInventoryPaneContextMenu.onGrabItems then
        local original = ISInventoryPaneContextMenu.onGrabItems
        ISInventoryPaneContextMenu.onGrabItems = function(items, player)
            local character = getSpecificPlayer(player)
            local actual = ISInventoryPane.getActualItems(items)
            local rest = {}

            for _, item in ipairs(actual or {}) do
                local worldItem = WB_Cart.is(item) and item:getWorldItem() or nil
                if character ~= nil and worldItem ~= nil then
                    ISTimedActionQueue.add(
                        ISWheelbarrowPickUp:new(character, worldItem))
                else
                    rest[#rest + 1] = item
                end
            end

            if #rest > 0 then return original(rest, player) end
        end
    end
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
