--[[
    Faz o carrinho ocupar as DUAS maos, e conserta estados de mao invalidos.

    POR QUE A REGRA VIVE AQUI E NAO NO SCRIPT:
    RequiresEquippedBothHands seria o caminho natural, e nao funciona -- com ele
    o item nao equipava de forma nenhuma. O jogo base aponta na mesma direcao:
    dos containers que aparecem na mao, todos usam ReplaceInPrimaryHand, e o
    unico que usa StaticModel -- o livro oco -- nao exige as duas maos. A
    combinacao container + StaticModel + duas maos nao tem precedente vanilla.

    Entao as duas maos sao impostas por Lua, com o padrao que o jogo usa para
    item de duas maos: o MESMO objeto na mao primaria e na secundaria.

    ESTADO VALIDO, unico:  o carrinho nas duas maos.

    Qualquer outra combinacao com o carrinho envolvido e desfeita. Isso cobre
    dois problemas distintos:

      - arma ou item pesado entrando na mao livre, o que anularia o custo de
        usar o carrinho;
      - o modelo do PERSONAGEM sumir, restando so a sombra, sem erro no log --
        sintoma observado quando um item pesado (gerador, cadaver) disputava a
        mao com o carrinho.

    CUIDADO AO EDITAR -- ja quebrou uma vez: a primeira versao exigia o mesmo
    objeto nas duas maos porque nasceu junto com RequiresEquippedBothHands.
    Quando aquele campo saiu do script, a invariante virou impossivel de
    satisfazer e este codigo passou a desequipar o carrinho no mesmo frame em que
    ele era equipado -- o item simplesmente nao aparecia na mao, sem nenhum erro.
    Se mudar a forma de equipar, mudar a invariante aqui na mesma passada.

    Fica em client/ porque e correcao de estado de apresentacao: modelo do
    personagem e maos sao coisa de cliente. Num servidor dedicado, cada cliente
    conserta o proprio personagem.
]]

local WB_Const = require "WB_Const"

local WB_Hands = {}

-- Guarda de reentrancia. setPrimaryHandItem dispara OnEquipPrimary, que chama
-- repair de volta: sem isto, a primeira correcao entra em recursao infinita e
-- trava o jogo. Nao e defensividade -- e consequencia direta de corrigir maos
-- de dentro do evento de equipar.
local repairing = false

local function isCart(item)
    return item ~= nil
        and instanceof(item, "InventoryContainer")
        and WB_Const.HAULER_TYPES[item:getFullType()] == true
end

local function blockWeapons()
    local vars = SandboxVars[WB_Const.SANDBOX_NS]
    -- Antes do save carregar, SandboxVars pode nao existir ainda. O padrao segue
    -- o do sandbox-options.txt.
    if vars == nil or vars.BlockWeapons == nil then return true end
    return vars.BlockWeapons == true
end

--- Restaura o estado valido: o carrinho nas duas maos.
---
--- Nunca destroi nem larga nada no chao -- o que sai da mao volta para o
--- inventario, que e o que o jogo faz ao trocar de arma.
function WB_Hands.repair(player)
    if repairing or player == nil then return end

    local primary = player:getPrimaryHandItem()
    local secondary = player:getSecondaryHandItem()

    local cart = nil
    if isCart(primary) then cart = primary
    elseif isCart(secondary) then cart = secondary end
    if cart == nil then return end

    if primary == cart and secondary == cart then return end

    local other = (primary ~= nil and primary ~= cart) and primary
        or ((secondary ~= nil and secondary ~= cart) and secondary or nil)

    if other ~= nil and not blockWeapons() then
        -- O jogador desligou o bloqueio de armas: a outra mao continua dela, e o
        -- carrinho fica so na primaria. Sem isto a opcao nao teria efeito
        -- nenhum, porque o carrinho tomaria as duas maos de qualquer jeito.
        if not player:isPrimaryHandItem(cart) then
            repairing = true
            player:setSecondaryHandItem(nil)
            player:setPrimaryHandItem(cart)
            repairing = false
            player:resetModelNextFrame()
        end
        return
    end

    repairing = true
    -- O carrinho reivindica as duas maos: quem perde a mao e a outra coisa, e
    -- nao o carrinho. Assim um clique numa arma nao interrompe quem ja esta
    -- empurrando.
    player:setPrimaryHandItem(cart)
    player:setSecondaryHandItem(cart)
    repairing = false

    -- Sem isto o personagem pode continuar invisivel: o modelo so e reconstruido
    -- quando alguem pede.
    player:resetModelNextFrame()
end

Events.OnEquipPrimary.Add(function(player, _item) WB_Hands.repair(player) end)
Events.OnEquipSecondary.Add(function(player, _item) WB_Hands.repair(player) end)

return WB_Hands
