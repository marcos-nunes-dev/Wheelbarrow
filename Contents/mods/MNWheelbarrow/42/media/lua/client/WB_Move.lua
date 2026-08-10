--[[
    Impede correr com o carrinho equipado.

    POR QUE NAO DA PARA FAZER ISSO NO SCRIPT DO ITEM:
    RunSpeedModifier existe e ja esta em 0.80, mas ele so escala a velocidade --
    nao ha campo que PROIBA correr. E ele tambem nao pode virar sandbox option:
    InventoryItem nao expoe setRunSpeedModifier, entao o valor e lido uma vez no
    carregamento do script e nao muda em runtime.

    Entao a proibicao e por Lua, e ela e ajustavel: SandboxVars.BlockRunning.
    Desligada, o jogador volta a poder correr -- na velocidade reduzida pelo
    RunSpeedModifier, que continua valendo.

    A checagem roda em OnPlayerUpdate, e nao no evento da tecla, por dois
    motivos: correr tambem comeca por outros caminhos que nao a tecla (gamepad,
    fuga automatica), e o estado pode ser reposto pelo proprio jogo no meio do
    frame. Verificar o ESTADO cobre todos os caminhos de uma vez.

    Fica em client/ porque movimento do proprio personagem e decisao de cliente;
    num servidor dedicado cada cliente aplica a regra ao seu.
]]

local WB_Const = require "WB_Const"

local WB_Move = {}

local function isCart(item)
    return item ~= nil
        and instanceof(item, "InventoryContainer")
        and WB_Const.HAULER_TYPES[item:getFullType()] == true
end

function WB_Move.isHauling(player)
    if player == nil then return false end
    return isCart(player:getPrimaryHandItem())
        or isCart(player:getSecondaryHandItem())
end

local function blockRunning()
    local vars = SandboxVars[WB_Const.SANDBOX_NS]
    -- Antes do save carregar, SandboxVars pode nao existir. O padrao segue o do
    -- sandbox-options.txt.
    if vars == nil or vars.BlockRunning == nil then return true end
    return vars.BlockRunning == true
end

Events.OnPlayerUpdate.Add(function(player)
    if not blockRunning() then return end
    if not WB_Move.isHauling(player) then return end

    -- Sprint e run sao estados SEPARADOS no personagem, e desligar um nao
    -- desliga o outro. Cortar so um deixaria o outro passar.
    if player:isSprinting() then player:setSprinting(false) end
    if player:isRunning() then player:setRunning(false) end
end)

return WB_Move
