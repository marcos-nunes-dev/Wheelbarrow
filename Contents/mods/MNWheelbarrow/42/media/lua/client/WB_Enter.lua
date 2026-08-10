--[[
    Entrar no carrinho com a tecla de interagir, e ligar sozinho.

    POR QUE A TECLA PRECISA SER NOSSA:
    o jogo oferece "Entrar no veiculo" pelo prompt de botao apenas quando
    BaseVehicle.getBestSeat devolve um assento valido. Desmontei esse metodo: o
    bytecode inteiro tem dois bytes --

        iconst_m1
        ireturn

    -- ou seja, SEMPRE devolve -1, para qualquer veiculo, na B42. E um stub, e o
    caminho da tecla de interagir nunca funciona por conta propria, nem para
    carros do jogo base.

    POR QUE NAO EXISTE LIGAR E DESLIGAR:
    um carrinho de mao nao tem ignicao -- quem "liga" e a pessoa que segura os
    cabos. Entao o motor, que aqui e ficcao para representar o empurrao, e
    ligado ao entrar e desligado ao sair. O jogador nunca ve o conceito.

    Isso tambem resolve um efeito colateral de esconder o painel: era nele que
    ficava o botao de partida, e sem ele o carrinho simplesmente nao andava.

    A mesma tecla faz os dois sentidos: fora, pega o carrinho; dentro, solta.
]]

local WB_Const = require "WB_Const"

local WB_Enter = {}

local SCRIPT_NAME = "MNWheelbarrow"

local function isWheelbarrow(vehicle)
    local script = vehicle and vehicle:getScript()
    return script ~= nil and script:getName() == SCRIPT_NAME
end

--- Usa o helper do proprio jogo em vez de percorrer a lista de veiculos.
---
--- A primeira versao fazia getCell():getVehicles() e chamava :get(i) no
--- resultado, o que estourava com "tried to call nil": esse metodo devolve um
--- java.util.Set, e Set nao tem get por indice. O jogo base tem um helper que
--- ja resolve alcance e obstaculo, e usa-lo evita reimplementar isso errado.
function WB_Enter.findNearby(player)
    local vehicle = ISVehicleMenu.getVehicleToInteractWith(player)
    if isWheelbarrow(vehicle) then return vehicle end
    return nil
end

local function onKeyPressed(key)
    if not getCore():isKey("Interact", key) then return end

    local player = getSpecificPlayer(0)
    if player == nil or player:isDead() then return end

    local current = player:getVehicle()
    if current ~= nil then
        -- Dentro do carrinho: soltar. Desliga antes de sair para o motor nao
        -- ficar rodando sozinho com o carrinho parado.
        if not isWheelbarrow(current) then return end
        if current:isEngineRunning() then
            ISVehicleMenu.onShutOff(player)
        end
        ISVehicleMenu.onExit(player)
        return
    end

    local vehicle = WB_Enter.findNearby(player)
    if vehicle == nil then return end

    -- O assento 0 e o unico do carrinho. Chamamos o fluxo do jogo em vez de
    -- BaseVehicle.enter: onEnter cuida de caminhar ate a posicao externa, da
    -- animacao e da sincronizacao.
    ISVehicleMenu.onEnter(player, vehicle, 0)
end

Events.OnKeyPressed.Add(onKeyPressed)

--- Liga ao entrar, por qualquer caminho -- tecla, menu radial ou tecla
--- numerica na UI de assentos. Fica no evento, e nao no handler da tecla, para
--- valer em todos eles.
Events.OnEnterVehicle.Add(function(player)
    local vehicle = player and player:getVehicle()
    if not isWheelbarrow(vehicle) then return end
    if vehicle:isEngineRunning() then return end

    -- Partida FORCADA, e nao ISVehicleMenu.onStartEngine.
    --
    -- A partida normal enfileira uma acao que passa pelas checagens de carro:
    -- bateria, combustivel e estado do motor. O carrinho nao tem peca de
    -- bateria nem de tanque -- e nem deveria ter -- e existe ate um estado de
    -- falha chamado engineDoStartingFailedNoPower. Era o candidato mais
    -- provavel para ele nao andar.
    --
    -- engineDoStartingSuccess poe o motor em funcionamento sem essas
    -- checagens, o que e coerente: o "motor" aqui e ficcao para representar a
    -- pessoa empurrando, e pessoa nao precisa de bateria.
    vehicle:engineDoStartingSuccess()

    if getDebug() then
        print(("[Wheelbarrow][MOTOR] running=%s started=%s working=%s hotwired=%s")
            :format(tostring(vehicle:isEngineRunning()),
                tostring(vehicle:isEngineStarted()),
                tostring(vehicle:isEngineWorking()),
                tostring(vehicle:isHotwired())))
    end
end)

return WB_Enter
