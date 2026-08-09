--[[
    Migracao: desfaz o encolhimento de peso de versoes anteriores do mod.

    HISTORICO -- por que isto existe e nao deve ser removido tao cedo:

    Uma versao anterior contornava o teto de capacidade de 50 do engine
    reduzindo o peso REAL dos itens dentro do carrinho, via setActualWeight().
    A ideia funcionava na aritmetica e a cadeia de contabilizacao foi conferida
    no bytecode. Na pratica ela quebrou o jogo de um jeito que so aparece em
    tela: o modelo do personagem sumia, restando so a sombra, sem nenhum erro
    no console.

    A causa: em B42 itens pesados -- gerador, cadaver -- sao carregados com uma
    animacao propria, e o jogo decide essa animacao PELO PESO do item. Como
    esses itens obrigatoriamente passam pela mao do personagem para entrar ou
    sair do carrinho, alterar o peso deles acontecia sempre com o item na mao,
    deixando a maquina de estados de animacao inconsistente.

    Ou seja: a tecnica era perigosa exatamente com os itens para os quais ela
    tinha sido criada. Foi abandonada.

    Este arquivo existe porque saves criados com aquela versao tem itens com o
    peso alterado gravado. Sem esta restauracao, um gerador de 40 ficaria
    pesando 6 para sempre naquele save. A varredura roda junto com o resto e se
    apaga sozinha: assim que um item e restaurado, a marca sai do ModData e ele
    nunca mais e tocado.
]]

local ORIG_KEY = "MNWB_origWeight"

local WB_Legacy = {}

--- Devolve o peso original de um item marcado por uma versao antiga.
--- @return boolean true se algo foi restaurado
function WB_Legacy.restore(item)
    if item == nil or not item:hasModData() then return false end
    local md = item:getModData()
    local original = md[ORIG_KEY]
    if original == nil then return false end

    item:setActualWeight(original)
    md[ORIG_KEY] = nil
    return true
end

--- Varre um container recursivamente restaurando o que estiver marcado.
function WB_Legacy.sweep(container, depth)
    depth = depth or 0
    if container == nil or depth > 3 then return end

    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        WB_Legacy.restore(item)
        if instanceof(item, "InventoryContainer") then
            WB_Legacy.sweep(item:getInventory(), depth + 1)
        end
    end
end

return WB_Legacy
