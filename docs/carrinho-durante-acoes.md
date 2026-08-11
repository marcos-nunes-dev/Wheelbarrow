# O carrinho durante as timed actions

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

## A primeira correcao funcionou e ficou pior

Devolver o modelo do carrinho na chamada resolveu o sumico. E revelou o problema
real: a animacao `Loot` agacha e mexe as maos, e um carrinho grudado nelas
acompanha o agachamento inteiro. Visivel e errado e pior que invisivel -- parece
defeito, nao parece carrinho.

## Correcao atual: o carrinho vai para o chao

`lua/client/WB_Parking.lua`. Quando a acao pede as maos vazias, o carrinho **e
largado no chao**; quando a fila de acoes termina, volta para as maos. E o que uma
pessoa faz: apoia o carrinho, mexe nos itens, pega de volta.

O gancho continua sendo `ISBaseTimedAction.setOverrideHandModels`, e nao uma lista
de acoes, por dois motivos:

- cobre as 52 acoes vanilla e as de outros mods, que nao teriamos como enumerar;
- **o sinal e mais preciso do que parece.** `ISInventoryTransferAction:doActionAnim`
  sai **antes** da chamada quando o personagem esta andando -- ali ele usa
  `DropWhileMoving`, que nao agacha e nao tem o problema. Ou seja: o gancho dispara
  exatamente nos casos que precisam, e fica quieto nos outros, de graca.

### A volta e instantanea

Pegar o carrinho normalmente tem timed action e derrama a carga se cancelar. Na
volta do estacionamento, nao. O custo daquela mecanica existe porque interromper
uma manobra de erguer peso deve doer -- mas aqui o jogador nunca pediu para
soltar o carrinho. Cobrar tempo e risco por uma manobra que o mod inventou seria
puni-lo por uma decisao nossa.

### Quando o carrinho NAO volta

Tres casos, todos deliberados:

- o jogador **se afastou** mais de 2 squares. O carrinho fica onde foi deixado;
  o contrario seria ele voar de volta atravessando a distancia.
- o jogador **equipou outra coisa** durante a acao. A escolha dele vale mais que
  a nossa devolucao.
- **nao deu para largar** o carrinho (sem square valida). Ai ele fica na mao, e o
  modelo e mantido visivel -- o menos pior, porque passar o `nil` adiante e o
  defeito original.

## Detalhe que muda a implementacao

Passar o **item** para `setOverrideHandModels` aplica junto a mascara de mao dele,
e a mascara conflita com a animacao da acao. O jogo base comenta exatamente isso
em `ISLightFromPetrol`:

> Don't call setOverrideHandModels() with self.petrol, the right-hand mask will
> bork the animation.

Por isso o caminho de fallback passa `cart:getStaticModel()` -- o **nome do
modelo**. De quebra, ler do item evita repetir aqui um nome que ja vive no script
do item.

## Limitacao que continua de pe

Com o carrinho **equipado**, `ISGrabItemAction:isValid()` termina em
`destContainer:hasRoomFor(character, item)`, e num container equipado esse teste
exige que o item caiba tambem no inventario do jogador. Geladeira e gerador nao
cabem, entao a acao nunca comeca -- e o estacionamento, que acontece depois, nao
tem como ajudar. Carregar peso grande continua exigindo largar o carrinho antes,
com o `E`.
