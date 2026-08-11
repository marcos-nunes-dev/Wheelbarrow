# O carrinho sumia durante as timed actions

## Sintoma

Com o carrinho equipado, mover um item do chao para dentro dele fazia o carrinho
desaparecer durante toda a animacao e voltar no fim.

A leitura natural era "ele afunda no chao junto com o personagem agachado",
porque o reaparecimento coincidia com o personagem se levantar. Era coincidencia:
o carrinho nao estava em lugar nenhum, simplesmente nao era desenhado.

## Causa

Esta escrita no jogo base, sem ambiguidade:

```lua
-- ISGrabItemAction:start()
self:setOverrideHandModels(nil, nil)

-- ISInventoryTransferAction:doActionAnim()
self:setOverrideHandModels(nil, nil)
```

Sao **52 acoes vanilla** que fazem essa chamada. A acao manda o engine nao
desenhar nada nas maos -- comportamento certo para o caso normal, em que a acao
troca o que esta na mao por uma ferramenta, ou precisa da mao aparecendo vazia.

## Duas hipoteses erradas, e por que erraram junto

Cada uma custou uma rodada de teste, e as duas falharam de forma identica:

1. **Faltava variante de mascara para estados de acao.** `maskingright/` de fato
   so tem variantes para andar, correr, agachar, mirar e cair. A observacao
   estava certa; a conclusao, nao.

2. **Prender o modelo ao osso**, via `ReplaceInPrimaryHand` com clothing item em
   `Bip01_Prop1`. Esse caminho nao passa por mascara nenhuma, entao deveria
   escapar do problema 1. Sumiu igual.

O ponto: as duas mudavam **como** o carrinho e desenhado, e a causa era ele **nao
ser desenhado**. Duas rotas independentes falhando do mesmo jeito era a evidencia
de que a hipotese estava no nivel errado -- e foi so ai que a busca virou para o
que a acao faz, em vez de para como o modelo chega na mao.

## Correcao

Um embrulho unico em `ISBaseTimedAction.setOverrideHandModels`
(`lua/client/WB_HandModel.lua`): quando a acao pede a mao primaria vazia e o
personagem esta com um carrinho, entra o modelo do carrinho no lugar do `nil`.

Envolver a **classe base** cobre as 52 acoes e as de outros mods, que nao teriamos
como enumerar. 52 chamadas, um ponto de intercepcao.

## Detalhe que muda a implementacao

Passar o **item** aplica junto a mascara de mao dele, e a mascara conflita com a
animacao da acao. O jogo base comenta exatamente isso em `ISLightFromPetrol`:

> Don't call setOverrideHandModels() with self.petrol, the right-hand mask will
> bork the animation.

Por isso passamos `cart:getStaticModel()` -- o **nome do modelo**. De quebra, ler
do item evita repetir aqui um nome que ja vive no script do item, e faz qualquer
hauler futuro funcionar sem tocar no arquivo.
