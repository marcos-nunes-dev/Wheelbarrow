--[[
    Conserta estados de mao invalidos com o carrinho equipado.

    O carrinho usa RequiresEquippedBothHands, ou seja: o MESMO objeto precisa
    estar na mao primaria e na secundaria ao mesmo tempo. Itens pesados como
    gerador e cadaver tambem exigem a mao primaria para serem carregados. Se um
    deles entra numa das maos enquanto o carrinho ocupa as duas, o personagem
    fica num estado que o jogo nao sabe representar -- o sintoma observado foi o
    modelo do personagem sumir, restando so a sombra, sem nenhum erro no log.

    Este arquivo detecta a inconsistencia (uma mao com o carrinho e a outra com
    outra coisa) e desfaz de forma limpa, pedindo a reconstrucao do modelo.

    Fica em client/ porque e correcao de estado de apresentacao: modelo do
    personagem e maos sao coisa de cliente. Num servidor dedicado, cada cliente
    conserta o proprio personagem.
]]

local WB_Const = require "WB_Const"

local WB_Hands = {}

local function isCart(item)
    return item ~= nil
        and instanceof(item, "InventoryContainer")
        and WB_Const.HAULER_TYPES[item:getFullType()] == true
end

--- Se o carrinho estiver numa mao mas a outra tiver algo diferente, tira o
--- carrinho das maos. O carrinho continua no inventario -- nao o destruimos nem
--- o largamos no chao sem o jogador pedir.
function WB_Hands.repair(player)
    if player == nil then return end

    local primary = player:getPrimaryHandItem()
    local secondary = player:getSecondaryHandItem()

    local cart = nil
    if isCart(primary) then cart = primary
    elseif isCart(secondary) then cart = secondary end

    if cart == nil then return end

    -- Estado valido: o mesmo objeto nas duas maos. Qualquer outra combinacao
    -- com o carrinho envolvido e invalida.
    if primary == secondary then return end

    if player:isPrimaryHandItem(cart) then
        player:setPrimaryHandItem(nil)
    end
    if player:isSecondaryHandItem(cart) then
        player:setSecondaryHandItem(nil)
    end

    -- Sem isto o personagem pode continuar invisivel: o modelo so e reconstruido
    -- quando alguem pede.
    player:resetModelNextFrame()
end

Events.OnEquipPrimary.Add(function(player, _item) WB_Hands.repair(player) end)
Events.OnEquipSecondary.Add(function(player, _item) WB_Hands.repair(player) end)

return WB_Hands
