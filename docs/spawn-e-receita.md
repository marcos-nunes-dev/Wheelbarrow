# Como o carrinho entra no mundo

## Spawn: raro como gerador, e pelo mesmo mecanismo

O alvo era "raro como achar um gerador". Fui ver **por que** o gerador e raro, e a
resposta mudou o desenho: ele nao tem chance baixa espalhada pelo mapa. Ele existe
em UMA tabela de distribuicao, `CrateGenerator`, com `onlyOne = true` -- ou seja, e
raro por estar preso a um **lugar** especifico e aparecer uma vez por lugar.

E o formato copiado aqui: **um sorteio por lugar, uma vez na vida do save**. A
chance nao e por square. Se fosse, um galpao de cem squares teria cem sorteios e a
raridade viraria abundancia.

Padrao: **3%** por lugar elegivel (`SpawnChance`). Eram 8% no plano original, que
foram pensados como "por comodo"; por celula rendem demais.

### Dois tipos de lugar

| Tipo | Como e reconhecido |
|---|---|
| comodo | nome do room em `WB_Const.SPAWN_ROOMS` -- obra, galpao, garagem, loja de ferramentas, serraria, fabrica |
| rua | **cone de obra** (`street_decoration_01_27`), porque ao ar livre nao existe room |

O cone foi encontrado extraindo os `CustomName` das tiledefs: o unico item de obra
de rua com sprite propria e o "Road Cone".

### A chave e a CELULA DE MAPA, e isso evita uma armadilha

O obvio seria chavear o registro por room. `IsoRoom` **nao expoe coordenada** -- so
`getName`, `getSquares` e `getBuilding`. A saida seguinte seria o menor x,y das
squares do room, e ela e **instavel**: chunk carrega em partes, entao um galpao que
atravessa dois chunks daria chaves diferentes em momentos diferentes e sortearia
duas vezes. `building.id` tambem nao serve, porque e contador de carregamento.

Coordenada absoluta de mapa nao tem nenhum desses problemas, e resolve o aglomerado
de cones pelo mesmo mecanismo: uma fila deles cai na mesma celula e rende um
sorteio. Celula de 10x10 squares; um galpao grande pode ocupar duas e ter dois
sorteios, o que e razoavel.

### O registro marca o sorteio, nao o sucesso

`claimPlace` grava a chave **antes** de sortear. Gravar so no sucesso faria todo
lugar sem carrinho sortear de novo a cada recarregamento de chunk, e ai nao
existiria raridade nenhuma -- o jogador acabaria achando um carrinho em todo galpao
que visitasse duas vezes.

### Custo

`LoadGridsquare` dispara por square no carregamento de chunk, o que sao milhares de
chamadas. Os testes estao ordenados do mais barato para o mais caro, e o registro
corta o trabalho na primeira square de cada lugar. A varredura de objetos -- a parte
cara -- so acontece ao ar livre e depois de um filtro de tamanho: o piso ja e um
objeto, entao square de rua vazia tem tamanho 1 e sai antes do laco.

### A rotacao vem antes de entrar no mundo

`InventoryItemFactory.CreateItem`, gira, e so entao `AddWorldInventoryItem`. A
sobrecarga que recebe um nome de tipo criaria e posicionaria num passo so, e ai
seria tarde: depois de entrar no mundo o engine ja resolveu o angulo. E a mesma
regra que `WB_Spill.placeOnGround` respeita, e ela ja custou uma rodada de teste.

### Nasce no chao

Nunca em container. E a invariante do mod, e vale tambem para como ele nasce. Um
carrinho dentro de um armario seria empurrado para o chao pela rede de
`WB_Placement` -- funcionaria, e pareceria defeito.

### O teste de "cabe aqui" e o mesmo do resto do mod

`WB_Spill.canRest` expoe o teste que o carrinho e o derrame ja usam, para o spawner
nao ter uma terceira versao dele. A primeira duplicacao desse teste deixou carga
cair debaixo de carro.

## Receita: meio de jogo, soldada

`MetalWelding:4` e o portao. Nivel 4 nao sai de pratica casual: pede revista ou
livro mais tempo de bancada, e e o mesmo patamar em que o jogo base libera
estrutura de metal.

| Entrada | Quantidade |
|---|---|
| Sheet Metal | 2 |
| Metal Pipe | 2 |
| pneu de carro (Old, Normal ou Modern) | 1 |
| Screws | 4 |
| Blow Torch | ferramenta, nao consome |
| Welding Mask | ferramenta, nao consome |
| Welding Rods | 1 |

600 de tempo, categoria Metalworking, `AnySurfaceCraft`, 50 de XP em MetalWelding.

A **roda** veio de pneu de carro porque nao existe roda avulsa no jogo -- conferido
em `generated/items`. Aceita os tres tipos para nao amarrar o jogador a um carro
especifico.

### O resultado vai para o inventario, e esta certo

A rede de `WB_Placement` poe no chao qualquer carrinho que apareca num inventario, e
ela existe justamente para cobrir caminhos que nao controlamos: craft, spawn de
admin, menu de debug, outro mod. Tratar o craft como caso especial seria duplicar
uma regra que ja e geral.

### O portao da sandbox nao esta no script

Script `.txt` nao le `SandboxVars`, e o `craftRecipe` nao tem portao proprio --
procurei. Os callbacks que ele aceita sao `OnTest`, `OnStart`, `OnUpdate`,
`OnCreate` e `OnFailed`, e o `OnTest`, candidato obvio pelo nome, e
`OnTestItem(item, character)`: um teste por **item de entrada**, nao da receita.
Usa-lo para desligar o craft faria a receita aparecer como "faltam ingredientes",
que mente sobre o motivo.

Entao a receita **nao tem AutoLearn** e nunca e conhecida por conta propria.
`WB_Recipe.lua` a ensina quando `EnableCrafting` esta ligada, mexendo em
`getKnownRecipes()` -- o mesmo caminho que profissao e tracos usam no engine.
Desligar a opcao tambem **remove** a receita de quem ja a tinha, senao a opcao so
valeria para personagem novo.

O nivel de MetalWelding continua no script, em `SkillRequired`. Cada portao no seu
lugar: o de jogo onde a interface o mostra, o de configuracao no Lua.

### A chave de traducao do nome

E o **nome da receita, sem prefixo**, em `Recipes.json` -- conferido no
`Recipes.json` do jogo base, onde `"Forge_Block_From_Chunk"` e a chave.
