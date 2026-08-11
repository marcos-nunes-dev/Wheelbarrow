# A tecla de interagir com o carrinho na mao

## Os dois defeitos eram o mesmo defeito

1. dava para pular cerca baixa com o carrinho nas maos;
2. apertar `E` perto de uma porta **largava o carrinho** em vez de abrir.

Causa comum: o nosso handler de `E` vivia em `Events.OnKeyPressed` e nao
conversava com as acoes contextuais do engine. Os dois disputavam a mesma tecla
sem arbitro.

## Um comportamento que parecia projetado e era acidente

"Cerca alta larga o carrinho antes de escalar" -- ninguem escreveu isso.
`ISClimbOverFence` nao toca em item de mao; conferido. Escalar cerca alta exige
**segurar** o `E`, e o nosso largar disparava no **apertar**. O carrinho caia
primeiro por diferenca de tempo, nao por regra.

Vale registrar porque e o tipo de coisa que passa por qualidade: o resultado
estava certo, entao ninguem investiga. Um acidente que da o resultado certo
continua sendo um acidente -- ele some no dia em que o tempo da tecla mudar. Agora
o mesmo resultado acontece de proposito.

## Como o arbitrio funciona

O engine decide sozinho o que o `E` faz e despacha por **um** ponto em Lua:

```
Hook.ContextualAction  ->  ContextualActionHandlers[nome](...)
```

O despachante resolve `ContextualActionHandlers[nome]` **na hora da chamada**
(`ISContextualActions.lua`), entao trocar um campo da tabela intercepta a acao.
Isso da duas capacidades com um mecanismo:

- **recusar** escalar cerca, janela e lencol com o carrinho na mao;
- **observar** quando o engine reivindicou o `E`, para nao largar o carrinho em
  cima de uma porta que ele ja vai abrir.

Consequencia de nao marcar a acao recusada como reivindicada: o mesmo aperto larga
o carrinho. O jogador aperta `E` uma vez e o carrinho desce, aperta de novo e
escala.

## Por que a nossa acao espera dois quadros

Nao ha garantia de ordem entre `Events.OnKeyPressed` e o despacho do engine dentro
do mesmo quadro. Em vez de apostar numa ordem -- que muda entre versoes e nao da
para verificar sem o jogo aberto -- registramos a intencao e resolvemos depois: se
uma acao contextual apareceu nesse meio, ela ganha.

Dois quadros e nao um para tolerar o engine despachar um quadro atras. A trinta
quadros por segundo sao menos de setenta milesimos, e a acao de largar tem animacao
de segundos.

O relogio de quadros fica em `Events.OnTick`, nao em `OnPlayerUpdate`: a disputa e
pela **tecla**, que e uma so para o jogo inteiro. Em `OnPlayerUpdate` o relogio
andaria uma vez por jogador em tela dividida e a janela encurtaria sem ninguem
notar.

## O que passou a ser recusado

| Acao | Por que |
|---|---|
| escalar cerca baixa | tirar os pes do chao com um carrinho carregado |
| passar por janela | passar o corpo por um vao |
| descer por lencol | as duas maos estao ocupadas |
| entrar em veiculo | o carrinho nao cabe num assento |

A recusa usa `HaloTextHelper.addBadText`, que e como o jogo base recusa -- texto
curto acima do personagem, sem janela e sem som de erro. Ver `ISVehicleMenu.onEnter`
para "tem alguem nesse assento".

Veiculo nao passa pelo despachante contextual, entao tem gancho proprio em
`ISVehicleMenu.onEnter` e `onEnter2`, os dois funis por onde todo caminho de
entrada passa. Recusar em `ISEnterVehicle:isValid()` seria mais fundo e mais
silencioso: a acao falharia sem dizer por que.

## Onde o carrinho para

O primeiro teste real disto foi recusar a entrada num carro: o carrinho era largado
na square do jogador, e ao lado de um veiculo essa square esta **debaixo** dele. O
carrinho desaparecia sob a carroceria.

`WB_Spill.pickSquare` passou a tratar a square pedida como **preferencia**. Ela
continua sendo a primeira escolha, porque carrega intencao -- "na frente do
personagem" ao largar de proposito -- e so e trocada quando nao serve:

| Recusa | Teste |
|---|---|
| veiculo em cima | `square:isVehicleIntersecting()` |
| parede, movel, sem piso | `square:isFree(false)` |
| parede entre o jogador e a square | `from:isBlockedTo(square)` |

`isFree(false)` e o teste que o jogo base usa para "cabe algo nesta square" -- ver
`ISWorldObjectContextMenu` ao pendurar cortina e `ISFarmingMenu` ao arar. Ele **nao
sabe de veiculo**, e era exatamente o furo do defeito.

Duas passadas, e a ordem importa: primeiro uma square livre **e sem itens**, depois
qualquer uma livre. Assim o carrinho evita pousar sobre coisa alheia quando ha
escolha, e nunca deixa de ser colocado por nao achar o lugar ideal -- carrinho mal
posicionado se resolve com um `E`; carrinho nao colocado desaparece da mao do
jogador.

O mesmo teste vale para a **carga derramada**. Antes o derrame tinha o proprio
teste, mais fraco (`isSolid` e `isSolidTrans` apenas), e o resultado era carga
caindo em lugar que o carrinho recusaria -- debaixo de carro, ou atravessando parede
para o comodo vizinho. Uma pergunta, uma resposta.

O derrame nao usa a preferencia por square vazia: empilhar e o ponto dele, e a ordem
de busca (centro primeiro, depois os oito vizinhos) e o que faz a pilha parecer
"caiu daqui". Ele tem o proprio limite de peso por square, e guarda a primeira
square valida como reserva -- se todas estiverem acima do limite, empilhar demais num
lugar valido e melhor que deixar a carga cair onde o carrinho nao pousaria.

O `false` de `isFree(false)` e carga util, nao enfeite. Lido no bytecode: com `true`
a primeira coisa que a funcao faz e recusar square que tenha personagem em cima -- o
que incluiria a square do proprio jogador, justamente a que mais usamos.

A varredura ignora o **proprio carrinho**. `pickSquare` roda antes de o objeto de
mundo antigo ser removido, entao um carrinho que ja esta no chao aparece na conta de
"tralha" e se expulsaria da propria square a cada recolocacao -- e recolocar sobre
si mesmo e o caso normal ao tombar.

## O que ficou de fora

Abrir porta e portao com o `E` **continua largando o carrinho**. A consulta a
`getContextDoorOrWindowOrWindowFrame(getDir())` nao devolveu nada em jogo, e a causa
nao foi investigada porque o clique do mouse abre porta e portao sem largar o
carrinho -- aceito como suficiente pelo Marcos. Se voltar a incomodar, o print de
`[Wheelbarrow][CONTEXTO]` diz se a porta chega ao Lua como acao contextual.
