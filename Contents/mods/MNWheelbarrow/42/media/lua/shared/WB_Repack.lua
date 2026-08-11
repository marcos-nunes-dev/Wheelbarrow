--[[
    O carrinho REACONDICIONA a carga: item dentro pesa uma fracao, item fora pesa o
    que sempre pesou.

    ======================================================================
    POR QUE ISTO EXISTE

    A capacidade de um container que pertence a um ITEM tem teto de 50, imposto no
    LEITOR e nao no escritor:

        ItemContainer.getCapacity():
            if getVehiclePart() ~= nil                 -> min(cap, 1000)
            if containingItem instanceof InventoryItem -> min(cap, 50)   <- nos
            senao                                      -> min(cap, 100)

    setCapacity(200) grava 200 e getCapacity() devolve 50. O unico discriminante e
    ser container de item; nao ha tipo, tag ou campo que mude isso. Os mods que furam
    esse limite substituem o ItemContainer.class recompilado -- travam numa versao
    exata do jogo e nem funcionam em servidor, que tem teto proprio.

    Se a capacidade nao pode subir, o peso do conteudo desce. getCapacityWeight()
    soma getActualWeight() de cada item, e setActualWeight e publico.

    ======================================================================
    AS TRES REGRAS QUE FAZEM ISTO SER SEGURO

    1. O VALOR VEM DO SCRIPT, NUNCA DO ESTADO ANTERIOR.

       peso dentro = getScriptItem():getActualWeight() * FACTOR
       peso fora   = getScriptItem():getActualWeight()

       Nunca "peso atual * FACTOR". Isso torna a operacao IDEMPOTENTE: rodar duas
       vezes, dez vezes ou depois de trocar o FACTOR da o mesmo resultado. Sem isso,
       duas passadas comprimiriam o item a 0.04 do peso e a terceira a 0.008.

    2. A MARCA E UM BOOLEANO, NAO UM VALOR.

       O ModData do item guarda apenas "eu mexi neste". Se ela se perder, o item fica
       leve -- ruim, mas recuperavel. Se guardasse o peso original e o valor
       estivesse errado uma vez, o peso real estaria perdido PARA SEMPRE. Guardar o
       minimo e o que limita o dano do pior caso.

    3. SO REACONDICIONA ITEM CUJO PESO E O DO SCRIPT.

       Bebida pela metade, comida mordida e item alterado por outro mod tem peso
       legitimamente diferente do script. Restaurar "para o script" apagaria esse
       estado. Entao item cujo peso atual nao bate com o script fica intocado: ele
       ocupa o peso real e ninguem se machuca.

    ======================================================================
    POR QUE RECONCILIACAO POR REGIAO, E NAO GANCHO POR SAIDA

    Um item pode sair do carrinho por arrastar, menu de contexto, pegar tudo, largar
    no chao, tombamento, morte do jogador, fabricacao, outro jogador em MP, menu de
    debug, ou por um mod que nem existe hoje. Enumerar saidas e uma lista que envelhece
    -- e este arquivo existe justamente porque a regra NAO pode ser furada por uma via
    imprevista.

    Entao nao ha ganchos de saida. Ha uma INVARIANTE, reafirmada sobre uma regiao:

        item marcado dentro de um hauler  -> peso = script * FACTOR
        item marcado fora de um hauler    -> peso = script, e a marca sai

    A regiao e "onde o item obrigatoriamente esta depois de sair": o inventario do
    jogador (recursivo), os carrinhos por perto, e o chao ao redor. Qualquer saida
    iniciada por um jogador aterrissa em um desses tres, seja qual for o codigo que a
    executou.

    NAO usamos o container que OnContainerUpdate entrega: ISInventoryPage o recebe,
    mas forageSystem dispara o mesmo evento SEM argumento. Depender do parametro seria
    depender de quem disparou.

    ======================================================================
    LIMITE CONHECIDO

    Item que saia para um container distante, sem jogador por perto, e nunca mais se
    aproxime de um, continua leve. A marca garante que ele se conserta na primeira vez
    que voltar a uma regiao varrida. Nao e zero; e limitado e auto-curavel.
]]

local WB_Cart = require "WB_Cart"
local WB_Sandbox = require "WB_Sandbox"

local WB_Repack = {}

--- Marca de "este item esta reacondicionado". Booleano, nunca um peso -- ver a
--- regra 2 no cabecalho.
local MARK = "MNWB_repacked"

--- Fracao do peso real que o item ocupa dentro do carrinho.
---
--- 0.2 vem do alvo: 25 troncos sao 225 de peso real, e 225 * 0.2 = 45, que cabe nos
--- 50 do teto com folga para o portao de entrada, que soma o peso REAL do item que
--- esta entrando ao peso ja reacondicionado do conteudo.
local FACTOR = 0.2

--- Profundidade maxima da descida por containers aninhados.
---
--- Nao e paranoia: isto roda a cada mudanca de container, e estouro de pilha num
--- handler desses derruba o jogo inteiro em vez de falhar sozinho. WB_Legacy escolheu
--- o mesmo 3 pelo mesmo motivo, e nenhuma arvore real de inventario passa disso.
local MAX_DEPTH = 3

--- @return number|nil peso canonico do script, ou nil se nao houver
local function scriptWeight(item)
    local script = item ~= nil and item:getScriptItem()
    if script == nil then return nil end
    return script:getActualWeight()
end

--- @return boolean se este item pode ser reacondicionado sem perder estado
---
--- Regra 3 do cabecalho. Bebida, comida e roupa tem peso que muda com o uso, e um
--- item alterado por outro mod tambem. Se o peso atual nao e o do script, nao ha como
--- restaurar depois sem inventar um numero.
local function repackable(item)
    if item == nil then return false end

    local real = scriptWeight(item)
    if real == nil or real <= 0 then return false end

    --[[ SO CARGA PESADA. O reacondicionamento existe para vencer o teto de 50 no que
         e pesado; item leve nao precisa dele e nao deve receber.

         Duas razoes. O teto de carga leve continua sendo 50 em peso REAL (ver
         WB_AcceptItem), entao comprimir item leve nao aumentaria quanta tralha cabe --
         seria so trabalho. E cada item tocado e uma chance de vazamento: restringir ao
         que precisa reduz a superficie do unico risco real deste arquivo. ]]
    if real < WB_Sandbox.get("HeavyThreshold") then return false end

    -- Peso que muda com o uso: comprimir apagaria esse estado na restauracao, porque
    -- o valor de volta vem do script. Ver a regra 3 no cabecalho.
    if instanceof(item, "DrainableComboItem") then return false end
    if instanceof(item, "Food") then return false end
    if instanceof(item, "Clothing") then return false end
    if WB_Cart.is(item) then return false end

    local marked = item:hasModData() and item:getModData()[MARK] == true
    if marked then return true end
    -- Ainda nao mexemos: so aceita se o peso for exatamente o do script.
    return math.abs(item:getActualWeight() - real) < 0.001
end

--- @return number o peso REAL do item, ignorando o reacondicionamento
---
--- Existe para WB_Weight e WB_AcceptItem: os dois classificam pesado e leve, e um
--- tronco reacondicionado pesa 1.8, que cairia como carga leve e perderia a reducao
--- de peso -- invertendo justamente o que o mod faz.
function WB_Repack.realWeight(item)
    if item == nil then return 0 end
    if item:hasModData() and item:getModData()[MARK] == true then
        return scriptWeight(item) or item:getActualWeight()
    end
    return item:getActualWeight()
end

local function repack(item)
    local real = scriptWeight(item)
    if real == nil then return end
    -- Derivado do SCRIPT, e nao do peso atual: e o que torna isto idempotente.
    item:setActualWeight(real * FACTOR)
    item:getModData()[MARK] = true
end

local function restore(item)
    local real = scriptWeight(item)
    if real ~= nil then item:setActualWeight(real) end
    if item:hasModData() then item:getModData()[MARK] = nil end
end

--[[ Reafirma a invariante num container, descendo pela arvore.

     O ESTADO "dentro" E DECIDIDO NA DESCIDA, e nao pelo chamador. Ao entrar num item
     que e um hauler, `inside` passa a ser verdadeiro para tudo abaixo dele.

     A primeira versao recebia `inside` do chamador e tinha um defeito grave por isso:
     o carrinho EQUIPADO vive dentro do inventario do jogador, entao a passada que
     varria o inventario com inside=false descia no carrinho e RESTAURAVA o conteudo
     dele -- desfazendo o reacondicionamento. E rodava depois da passada que
     reacondicionava, entao ganhava. Carrinho na mao perdia o efeito inteiro.

     Decidir na descida tambem eliminou as passadas separadas por carrinho: uma
     varredura do inventario do jogador ja cobre carrinho na mao e bolsa dentro do
     carrinho, na profundidade que existir.

     @param inside boolean se algum ancestral ja e um hauler ]]
local function reconcile(container, inside, depth)
    depth = depth or 0
    if container == nil or depth > MAX_DEPTH then return end

    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)

        --[[ Um `elseif` cobre os tres casos, e o terceiro nao e obvio:

               dentro e reacondicionavel  -> comprime (rederivado, idempotente)
               dentro e marcado, mas ja NAO reacondicionavel -> restaura
               fora e marcado -> restaura

             O do meio acontece se o limite de peso pesado subir na sandbox: um item
             marcado que passou a contar como leve ficaria comprimido para sempre
             dentro do carrinho, porque a restauracao so olhava quem estava fora. ]]
        if inside and repackable(item) then
            repack(item)
        elseif item:hasModData() and item:getModData()[MARK] == true then
            restore(item)
        end

        if instanceof(item, "InventoryContainer") then
            reconcile(item:getInventory(), inside or WB_Cart.is(item), depth + 1)
        end
    end
end

--- Reafirma a invariante no que o jogador carrega.
---
--- Cobre carrinho na mao, bolsa dentro do carrinho e qualquer item marcado que tenha
--- acabado de sair para o inventario -- os destinos de toda saida iniciada por quem
--- esta segurando as coisas.
function WB_Repack.sweepCarried(character)
    if character == nil then return end
    reconcile(character:getInventory(), false)
end

--- Reafirma a invariante nos carrinhos e itens largados ao redor.
---
--- Separado de sweepCarried porque varrer o chao custa uma varredura de squares, e
--- WB_Weight ja decidiu estrangular isso -- esta funcao e chamada de dentro do trecho
--- estrangulado, e nao a cada mudanca de container.
---
--- @param radius number raio em squares
function WB_Repack.sweepGround(character, radius)
    if character == nil then return end

    WB_Cart.forEachOnGround(character, radius, function(cart)
        reconcile(cart:getInventory(), true)
    end)

    local square = character:getSquare()
    if square == nil then return end

    -- Largar no chao e um dos destinos de saida, e ali o item nao esta em container
    -- nenhum -- por isso a varredura de objetos de mundo, e nao de itens.
    local objects = square:getWorldObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if instanceof(object, "IsoWorldInventoryObject") then
            local item = object:getItem()
            if item ~= nil and not WB_Cart.is(item)
                and item:hasModData() and item:getModData()[MARK] == true then
                restore(item)
            end
        end
    end
end

return WB_Repack
