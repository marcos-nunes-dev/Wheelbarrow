--[[
    SPIKE -- rastreia o fluxo de entrada no veiculo do jogo base.

    Sintoma: clicar no assento pelo menu radial nao faz nada, sem erro nenhum no
    console. Ja corrigi tres coisas reais por deducao (peca sem itemType, peca
    sem lua/create, passageiro sem blocos anim) e o sintoma continua igual --
    entao parei de deduzir.

    Este arquivo embrulha as funcoes do jogo que levam da UI ate a entrada e
    imprime por onde a execucao passa. Onde os prints pararem, esta a causa.

    Descartavel: sai junto com o resto do spike.
]]

local function wrap(tableName, holder, fnName)
    local original = holder[fnName]
    if type(original) ~= "function" then
        print(("[WB-trace] AVISO: %s.%s nao existe"):format(tableName, fnName))
        return
    end
    holder[fnName] = function(...)
        print(("[WB-trace] -> %s.%s"):format(tableName, fnName))
        return original(...)
    end
end

Events.OnGameStart.Add(function()
    if not getDebug() then return end

    -- Da UI ate a acao. Se "onEnter" imprimir mas "onEnterAux" nao, o desvio
    -- esta nas condicoes de processEnter; se onEnterAux imprimir mas a acao de
    -- entrar nunca comecar, o problema e o pathfinding ate o assento.
    if ISVehicleMenu then
        wrap("ISVehicleMenu", ISVehicleMenu, "onEnter")
        wrap("ISVehicleMenu", ISVehicleMenu, "processEnter")
        wrap("ISVehicleMenu", ISVehicleMenu, "onEnterAux")
    else
        print("[WB-trace] ISVehicleMenu nao carregado")
    end

    -- A acao de andar ate o assento. isValid false a cada tick significa que o
    -- personagem nao consegue chegar ao ponto de entrada.
    if ISPathFindAction then
        local origStart = ISPathFindAction.start
        ISPathFindAction.start = function(self, ...)
            print("[WB-trace] -> ISPathFindAction.start")
            return origStart(self, ...)
        end
        local origStop = ISPathFindAction.stop
        ISPathFindAction.stop = function(self, ...)
            print("[WB-trace] -> ISPathFindAction.STOP (cancelada -- nao chegou)")
            return origStop(self, ...)
        end
        local origPerform = ISPathFindAction.perform
        ISPathFindAction.perform = function(self, ...)
            print("[WB-trace] -> ISPathFindAction.perform (chegou ao destino)")
            return origPerform(self, ...)
        end
    end

    -- A entrada propriamente dita.
    if ISEnterVehicle then
        local origValid = ISEnterVehicle.isValid
        ISEnterVehicle.isValid = function(self, ...)
            local ok = origValid(self, ...)
            if self._wbLogged ~= ok then
                self._wbLogged = ok
                print(("[WB-trace] ISEnterVehicle.isValid = %s"):format(tostring(ok)))
            end
            return ok
        end
        local origStart = ISEnterVehicle.start
        ISEnterVehicle.start = function(self, ...)
            print("[WB-trace] -> ISEnterVehicle.start")
            return origStart(self, ...)
        end
        local origPerform = ISEnterVehicle.perform
        ISEnterVehicle.perform = function(self, ...)
            print("[WB-trace] -> ISEnterVehicle.perform (ENTROU)")
            return origPerform(self, ...)
        end
    end

    print("[WB-trace] rastreamento de entrada em veiculo ativo")
end)
