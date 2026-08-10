--[[
    Faz o carrinho ocupar as duas maos, e conserta estados de mao invalidos.

    POR QUE A REGRA VIVE AQUI E NAO NO SCRIPT:
    RequiresEquippedBothHands seria o caminho natural, mas com ele o item nao
    equipava de forma nenhuma. O jogo base aponta na mesma direcao: dos
    containers que aparecem na mao, todos usam ReplaceInPrimaryHand, e o unico
    que usa StaticModel -- o livro oco -- nao exige as duas maos. A combinacao
    container + StaticModel + duas maos nao tem precedente, e nao funciona.

    Entao a exigencia e emulada: o carrinho fica na mao PRIMARIA e a secundaria
    e mantida VAZIA. Do ponto de vista do jogador o efeito e o mesmo -- nao da
    para empunhar arma junto -- e o modelo continua renderizando.

    ESTADO VALIDO, unico:  carrinho na mao primaria, secundaria vazia.

    Qualquer outra combinacao com o carrinho envolvido e desfeita. Isso cobre
    dois problemas distintos:

      - arma ou item pesado entrando na mao livre, o que anularia o custo de
        usar o carrinho;
      - o modelo do PERSONAGEM sumir, restando so a sombra, sem erro no log --
        sintoma observado quando um item pesado (gerador, cadaver) disputava a
        mao com o carrinho.

    CUIDADO AO EDITAR: a versao anterior deste arquivo exigia o mesmo objeto nas
    DUAS maos, porque nasceu junto com RequiresEquippedBothHands. Quando aquele
    campo saiu do script, a invariante daqui virou impossivel de satisfazer e
    este codigo passou a desequipar o carrinho no mesmo frame em que ele era
    equipado -- o item simplesmente nao aparecia na mao, e sem nenhum erro. Se
    mudar a forma de equipar, mudar a invariante aqui na mesma passada.

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

--- Restaura o estado valido: carrinho na primaria, secundaria vazia.
---
--- Nunca destroi nem larga nada no chao -- o que sai da mao volta para o
--- inventario, que e o que o jogo faz ao trocar de arma.
function WB_Hands.repair(player)
    if player == nil then return end

    local primary = player:getPrimaryHandItem()
    local secondary = player:getSecondaryHandItem()

    local cartInPrimary = isCart(primary)
    local cartInSecondary = isCart(secondary)

    if not cartInPrimary and not cartInSecondary then return end

    local changed = false

    if cartInPrimary and secondary ~= nil and secondary ~= primary then
        -- O carrinho reivindica as duas maos: quem perde a mao e a outra coisa,
        -- nao o carrinho. Assim o jogador que ja estava empurrando nao e
        -- interrompido por um clique numa arma.
        player:setSecondaryHandItem(nil)
        changed = true
    elseif cartInSecondary then
        -- Carrinho na mao errada. O modelo de mao foi assado para a direita
        -- (primaryAnimMask = holdingbagright), entao a esquerda nunca renderiza
        -- direito. Passa para a primaria se ela estiver livre; se nao, sai das
        -- maos e volta para o inventario.
        player:setSecondaryHandItem(nil)
        if primary == nil then
            player:setPrimaryHandItem(secondary)
        end
        changed = true
    end

    if changed then
        -- Sem isto o personagem pode continuar invisivel: o modelo so e
        -- reconstruido quando alguem pede.
        player:resetModelNextFrame()
    end
end

Events.OnEquipPrimary.Add(function(player, _item) WB_Hands.repair(player) end)
Events.OnEquipSecondary.Add(function(player, _item) WB_Hands.repair(player) end)

return WB_Hands
