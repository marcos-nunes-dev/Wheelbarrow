--[[
    Entrar no carrinho com a tecla de interagir.

    POR QUE ISTO PRECISA EXISTIR:
    o jogo oferece "Entrar no veiculo" pelo prompt de botao apenas quando
    BaseVehicle.getBestSeat devolve um assento valido. Desmontei esse metodo: o
    bytecode inteiro tem dois bytes --

        iconst_m1
        ireturn

    -- ou seja, ele SEMPRE devolve -1, para qualquer veiculo, na B42. E um stub.
    O caminho da tecla de interagir nunca funciona por conta propria, nem para
    carros do jogo base. Entrar so acontece pelo menu radial.

    Como a expectativa de quem joga e entrar apertando a tecla de interagir,
    registramos esse atalho aqui. Ele chama exatamente o mesmo fluxo que o menu
    radial usa, entao nao inventa comportamento novo -- so encurta o caminho.
]]

local WB_Const = require "WB_Const"

local WB_Enter = {}

--- Alcance em tiles para agarrar o carrinho. Curto de proposito: entrar num
--- carrinho a tres tiles de distancia seria estranho.
local REACH = 2.0

local function isWheelbarrow(vehicle)
    local script = vehicle and vehicle:getScript()
    return script ~= nil and script:getName() == "MNWheelbarrow"
end

--- @return BaseVehicle|nil o carrinho mais proximo dentro do alcance
function WB_Enter.findNearby(player)
    local cell = getCell()
    if cell == nil then return nil end
    local vehicles = cell:getVehicles()
    local best, bestDist = nil, REACH
    for i = 0, vehicles:size() - 1 do
        local vehicle = vehicles:get(i)
        if isWheelbarrow(vehicle) then
            local dx = vehicle:getX() - player:getX()
            local dy = vehicle:getY() - player:getY()
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < bestDist then
                best, bestDist = vehicle, dist
            end
        end
    end
    return best
end

local function onKeyPressed(key)
    if not getCore():isKey("Interact", key) then return end

    local player = getSpecificPlayer(0)
    if player == nil or player:isDead() then return end

    -- Ja dentro de algum veiculo: nao interferimos. Sair continua sendo pelo
    -- caminho normal do jogo.
    if player:getVehicle() ~= nil then return end

    local vehicle = WB_Enter.findNearby(player)
    if vehicle == nil then return end

    -- O assento 0 e o unico que existe no carrinho. Chamamos o fluxo do jogo em
    -- vez de BaseVehicle.enter: onEnter cuida do caminhar ate a posicao externa,
    -- da animacao e da sincronizacao.
    ISVehicleMenu.onEnter(player, vehicle, 0)
end

Events.OnKeyPressed.Add(onKeyPressed)

return WB_Enter
