# O personagem invisivel era a tecla F3

## Resposta curta

Nao era defeito do jogo nem do mod. Em modo debug, **F3 esta ligada a duas coisas
ao mesmo tempo**:

| Tecla | Bind normal | Bind de debug |
|---|---|---|
| **F3** | Normal Speed | **ToggleModelsEnabled** |
| F6 | Fast Forward x3 | ToggleAnimationText |

Origem, no jogo instalado: `media/lua/shared/keyBinding.lua` -- `Normal Speed` em
`KEY_F3` (linha ~206) e `ToggleModelsEnabled` tambem em `KEY_F3` (linha ~368).

Com `-debug` ligado -- que este projeto exige para desenvolver -- mexer na
velocidade do tempo pelo teclado **desliga os modelos**. Apertar de novo religa.
Por isso o sintoma parecia alternar com a velocidade do tempo.

Modo debug e so de desenvolvimento. **Nenhum jogador do mod publicado passa por
isso.**

## O sintoma

Personagem sumia da tela deixando so a sombra, sem nada no log. Aconteceu varias
vezes ao longo do projeto e me levou a tres diagnosticos errados antes deste.

## As duas evidencias que ja apontavam para a resposta

Eu tinha as duas e nao dei peso a nenhuma:

1. **Os veiculos sumiam junto.** Alpha do jogador nunca afetaria um veiculo.
   `ToggleModelsEnabled` desliga todo modelo -- personagem, zumbi, veiculo -- e
   deixa sombra, piso e interface. Encaixe exato do que estava na tela.

2. **O vigia de alpha nunca consertou.** Foi escrito exatamente para isso e o
   sumico continuou acontecendo. Isso ja era o experimento respondendo que alpha
   nao era a causa, e eu tratei como ajuste pendente.

O que faltou foi um gatilho reproduzivel. Enquanto o sumico parecia aleatorio,
qualquer teoria servia; no momento em que virou "acontece quando eu mexo na
velocidade do tempo", a resposta apareceu em uma busca.

## O que foi removido

O vigia de alpha em `lua/client/WB_Player.lua`. Ele reafirmava
`setAlphaAndTarget(playerNum, 1.0)` quando o alpha ficava perto de zero por mais
de meio segundo.

Removido porque tratava um sintoma que nao conseguimos reproduzir, e o preco era
escrever no render do jogador a cada quadro -- que e justamente o tipo de coisa
que faz um mod brigar com outros. O comentario original dele dizia isso.

Se o sumico reaparecer **sem F3 envolvida**, o vigia volta com um `git revert`.

## Diagnosticos anteriores, e o que sobra deles

Tres teorias vieram antes, e o F3 provavelmente contaminou os testes das tres:

- encolher o peso do item enquanto equipado
- mudar o conteudo do carrinho com ele na mao
- **textura 1024x512 quebrar a passada de modelo do personagem**

A terceira teve teste controlado de quatro variantes com controle positivo, entao
nao esta descartada -- mas tambem nao esta confirmada. Nao vale uma rodada de
teste para reconferir: as texturas atuais sao 512x512 RGBA e funcionam. Fica
registrado como incerto, nao como fato.

## Licao

O sumico gerou mais retrabalho neste projeto do que qualquer outro problema, e a
causa era uma tecla. O que prolongou foi eu explicar um sintoma sem gatilho
reproduzivel: sem poder ligar e desligar o efeito, nenhuma teoria podia ser
refutada, entao todas sobreviviam. A pergunta que faltava nao era "por que o
personagem some", era **"o que eu faco imediatamente antes de ele sumir"**.
