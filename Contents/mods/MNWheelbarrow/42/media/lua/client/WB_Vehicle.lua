--[[
    Faz o carrinho se comportar como carrinho, e nao como carro.

    A rota de veiculo entrega o que nenhuma outra entregava -- movimento suave,
    capacidade acima de 50 e sistema nativo de pneu com condicao. Mas ela traz
    junto pressupostos de automovel que nao fazem sentido aqui, e que o Marcos
    apontou: chave e gasolina.

    CHAVE: setHotwired(true) marca o veiculo como ligado direto, e o jogo deixa
    de exigir chave para dar partida. E o mesmo mecanismo que o jogador usa ao
    fazer ligacao direta num carro -- nao estamos inventando comportamento, so
    partindo dele ja aplicado.

    GASOLINA: o carrinho nao declara peca GasTank, entao nao ha tanque para
    esvaziar. Se ainda assim o motor reclamar de combustivel, este arquivo e o
    lugar de tratar.

    O "motor" e uma ficcao para representar a pessoa empurrando: forca baixa,
    velocidade de caminhada e ruido zero, definidos no script do veiculo.
]]

local WB_Const = require "WB_Const"

local WB_Vehicle = {}

local SCRIPT_NAME = "MNWheelbarrow"

function WB_Vehicle.isWheelbarrow(vehicle)
    local script = vehicle and vehicle:getScript()
    return script ~= nil and script:getName() == SCRIPT_NAME
end

--- Deixa o carrinho pronto para uso: sem chave e sem partida a dar.
function WB_Vehicle.prepare(vehicle)
    if not WB_Vehicle.isWheelbarrow(vehicle) then return end

    if not vehicle:isHotwired() then
        vehicle:setHotwired(true)
    end
end

--- getCell():getVehicles() devolve um java.util.Set, e chamar :get(i) nele
--- estoura com "tried to call nil". Usamos o helper do jogo, que ja resolve
--- alcance e obstaculo.
local function prepareNearby(player)
    if player == nil then return end
    WB_Vehicle.prepare(ISVehicleMenu.getVehicleToInteractWith(player))
end

Events.OnEnterVehicle.Add(function(player)
    WB_Vehicle.prepare(player:getVehicle())
end)

--[[
    Silencia o som de motor.

    Um carrinho de mao nao faz barulho de carro. engineLoudness = 0 no script
    reduz o quanto o som ATRAI zumbis, mas nao impede o som de tocar -- sao
    coisas diferentes, e foi por isso que o ruido continuou.

    Nao existe som silencioso no jogo base para apontar no bloco sound, entao
    calamos o emissor do veiculo direto. So roda enquanto o jogador esta dentro
    de um carrinho, entao nao pesa e nao afeta outros veiculos.
]]
Events.OnPlayerUpdate.Add(function(player)
    local vehicle = player and player:getVehicle()
    if not WB_Vehicle.isWheelbarrow(vehicle) then return end
    local emitter = vehicle:getVehicleSoundEmitter()
    if emitter ~= nil then
        emitter:stopAll()
    end
end)

-- Tambem ao criar o personagem, para carrinhos que ja existiam no save.
Events.OnCreatePlayer.Add(function(playerIndex, player)
    prepareNearby(player or getSpecificPlayer(playerIndex))
end)

--[[
    Esconde o painel de carro quando o veiculo e o carrinho.

    Velocimetro, medidor de gasolina, farois, portas e aquecedor nao fazem
    sentido num carrinho de mao -- e o painel some inteiro em vez de mostrar
    medidores vazios.

    O proprio ISVehicleDashboard ja sabe se remover: setVehicle(nil) chama
    removeFromUIManager. Reaproveitamos esse caminho em vez de inventar outro.
]]
Events.OnGameStart.Add(function()
    if ISVehicleDashboard == nil then return end

    local originalSetVehicle = ISVehicleDashboard.setVehicle
    ISVehicleDashboard.setVehicle = function(self, vehicle)
        if WB_Vehicle.isWheelbarrow(vehicle) then
            self.vehicle = vehicle
            for _, gauge in ipairs(self.gauges or {}) do
                gauge:setVisible(false)
            end
            self.gauges = {}
            self:removeFromUIManager()
            return
        end
        return originalSetVehicle(self, vehicle)
    end
end)

return WB_Vehicle
