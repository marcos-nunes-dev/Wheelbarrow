--[[
    Poe o personagem na animacao de corpo inteiro de carregar com os DOIS bracos.

    POR QUE MASCARA NAO RESOLVE, E ERA O CAMINHO ERRADO DESDE O INICIO:

    primaryAnimMask e secondaryAnimMask sao mascaras POR MAO -- a segunda e a
    mascara de quando o item esta na mao secundaria, e nao a segunda metade de uma
    pose de duas maos. Com o mesmo objeto nas duas maos o jogo aplica uma so, e o
    resultado era o braco direito segurando e o esquerdo fazendo a animacao de
    andar. Somar as duas mascaras nunca ia produzir uma pose coerente: sao dois
    retalhos por cima da animacao de andar, e nao uma animacao de carregar.

    O jogo tem a animacao certa, e ela e de corpo inteiro. Em
    media/AnimSets/player existe a familia 2H_Heavy completa -- Bob_Idle2H_Heavy,
    Bob_Walk2H_Heavy, com variantes de manqueira, de furtivo, de correr e as
    transicoes entre elas. E a pose de quem carrega algo pesado com as duas maos.

    A condicao de entrada de todos esses nos NAO e mascara nem tipo de item: e a
    variavel de animacao `Weapon` valendo a string "heavy".

        <m_Conditions>
            <m_Name>Weapon</m_Name>
            <m_Type>STRING</m_Type>
            <m_Value>heavy</m_Value>
        </m_Conditions>

    Entao basta setar a variavel. Nao ha nada a modelar, nem rigging, nem malha
    invisivel de apoio -- a animacao ja existe e e melhor do que qualquer soma de
    mascaras.

    POR QUE POR QUADRO, e nao uma vez ao equipar: o sistema de animacao recalcula
    `Weapon` a partir do item equipado. Setar so no evento de equipar seria
    sobrescrito no quadro seguinte. Limpar ao desequipar tambem e necessario,
    senao o personagem fica preso na pose de carregar de maos vazias.

    Chamar "Weapon" de arma nao incomoda aqui: o carrinho toma as duas maos e
    WB_Hands impede arma junto, entao nao ha conflito com combate.

    Fica em client/ porque animacao e apresentacao. Num servidor dedicado cada
    cliente anima o proprio personagem.
]]

local WB_Const = require "WB_Const"

local WB_Anim = {}

local VARIABLE = "Weapon"
local HEAVY = "heavy"

local function isCart(item)
    return item ~= nil
        and instanceof(item, "InventoryContainer")
        and WB_Const.HAULER_TYPES[item:getFullType()] == true
end

function WB_Anim.isHauling(player)
    if player == nil then return false end
    return isCart(player:getPrimaryHandItem())
        or isCart(player:getSecondaryHandItem())
end

Events.OnPlayerUpdate.Add(function(player)
    if player == nil then return end

    if WB_Anim.isHauling(player) then
        -- Comparar antes de escrever: setVariable dispara reavaliacao da maquina
        -- de estados, e reescrever o mesmo valor a cada quadro faria a animacao
        -- reiniciar sem parar.
        if player:getVariableString(VARIABLE) ~= HEAVY then
            player:setVariable(VARIABLE, HEAVY)
        end
    elseif player:getVariableString(VARIABLE) == HEAVY then
        -- Sem isto o personagem fica preso na pose de carregar depois de largar o
        -- carrinho -- o mesmo tipo de estado orfao que causou o carrinho-fantasma
        -- na mao.
        player:clearVariable(VARIABLE)
    end
end)

return WB_Anim
