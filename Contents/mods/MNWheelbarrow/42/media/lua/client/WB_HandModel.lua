--[[
    Mantem o carrinho VISIVEL enquanto o personagem executa uma timed action.

    ----------------------------------------------------------------------
    O DEFEITO

    Com o carrinho equipado, mover qualquer item para dentro dele fazia o
    carrinho sumir durante a animacao e voltar no fim. Nao era o carrinho
    afundando no chao junto com o personagem agachado: ele deixava de ser
    desenhado.

    ----------------------------------------------------------------------
    A CAUSA, que esta escrita no jogo

        ISGrabItemAction:start()              self:setOverrideHandModels(nil, nil)
        ISInventoryTransferAction:doActionAnim()  self:setOverrideHandModels(nil, nil)

    e mais 50 acoes vanilla fazem o mesmo. A acao MANDA o engine nao desenhar
    nada nas maos, porque o normal e que a acao substitua o que esta na mao por
    uma ferramenta -- ou por nada, quando a mao precisa aparecer livre.

    Isso independe de COMO o modelo chega na mao. Foram gastas duas rodadas de
    teste em hipoteses que nao podiam funcionar, e as duas falharam identicamente
    por este motivo:

      1. mascara de animacao (o caminho que o mod usa): a suspeita era que
         maskingright/ nao tem variante para estados de acao. Nao era isso.

      2. modelo preso ao osso, por ReplaceInPrimaryHand com clothing item: nao
         depende de mascara nenhuma. Sumiu igual.

    As duas mudavam o desenho do carrinho. O problema era ele nao ser desenhado.

    ----------------------------------------------------------------------
    A CORRECAO

    Um unico embrulho em ISBaseTimedAction.setOverrideHandModels: quando a acao
    pede a mao primaria VAZIA e o personagem esta com um carrinho, entra o
    modelo do carrinho no lugar do nil.

    Envolver a classe base, e nao as duas acoes do caso relatado, e o que faz a
    correcao valer para as 52 -- e para acoes de outros mods, que nao teriamos
    como enumerar. Sao 52 chamadas e um ponto de intercepcao.
]]

local WB_Cart = require "WB_Cart"

Events.OnGameStart.Add(function()
    local original = ISBaseTimedAction.setOverrideHandModels

    ISBaseTimedAction.setOverrideHandModels = function(self, primary, secondary,
                                                       resetModel)
        -- So quando a acao pede a mao vazia. Se ela pos uma ferramenta ali, a
        -- ferramenta manda: e o que a animacao esta mostrando o personagem usar.
        if primary == nil then
            local cart = WB_Cart.equipped(self.character)
            if cart ~= nil then
                -- O NOME DO MODELO, nunca o item. Passar o item aplica junto a
                -- mascara de mao dele, e a mascara conflita com a animacao da
                -- acao. Nao e deducao: ISLightFromPetrol chega a comentar isso
                -- no jogo base, e passa getStaticModel() pelo mesmo motivo.
                --
                -- Ler do item em vez de fixar "MNWheelbarrow_Hand" tambem evita
                -- repetir aqui um nome que ja vive no script do item, e faz
                -- qualquer hauler futuro funcionar sem tocar neste arquivo.
                primary = cart:getStaticModel()
            end
        end

        return original(self, primary, secondary, resetModel)
    end
end)
