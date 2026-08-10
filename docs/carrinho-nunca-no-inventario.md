# Estudo: o carrinho como objeto do mundo, não como item de bolsa

O pedido: *"de preferência o carrinho nunca poder ir para o inventário. o usuário
tem que carregar ele quando ele está no chão, equipar ele direto do chão e ao
soltar ele vai direto para o chão."*

Este documento existe porque a resposta honesta começa com uma limitação, e ela
muda o que dá para prometer.

---

## O que não dá para fazer, e por quê

**Um item equipado ESTÁ no inventário do personagem.** No PZ,
`setPrimaryHandItem(item)` opera sobre um item que pertence ao inventário; mão é
um *slot que aponta* para um item de lá, não um lugar separado. Não existe estado
"nas mãos e fora do inventário".

Então "nunca no inventário" não é implementável ao pé da letra. O que é
implementável — e entrega tudo que o pedido quer na prática — é uma invariante
mais estreita:

> **O carrinho só existe em dois lugares: no chão, ou nas mãos.
> Nunca no inventário desequipado.**

É essa a diferença que resolve os três incômodos relatados: guardar o carrinho
na mochila, o "pegar" que burla a animação, e o carrinho que fica na bolsa
enquanto a carga cai no chão.

---

## As quatro regras

**R1 — O carrinho não entra em container nenhum.**
Nem mochila, nem baú, nem outro carrinho. Vale para o inventário principal
também, exceto de passagem: ele só está lá porque a mão exige.

**R2 — Chão → mãos passa pela ação cronometrada.**
A opção "Pegar" do jogo era o furo: punha o carrinho na bolsa sem animação, e de
lá o jogador equipava — nunca passando pela ação que pode ser cancelada.

A primeira tentativa **removia a opção do menu por nome, e não funcionou**. O
nome não é único: oito pontos do jogo criam uma opção "Pegar", e o menu do chão
não é o mesmo do painel de chão do inventário. Pior, remover por nome é
grosseiro — "Pegar" vale para a square inteira, então tirá-la com outros itens
caídos ali deixaria o jogador sem como pegar aquilo.

O que funciona é interceptar a **ação**, não o menu: todos os oito caminhos
terminam em `ISGrabItemAction:new`, então o construtor é envolvido e devolve a
nossa ação quando o objeto é um carrinho. O menu fica intacto; só o que a opção
faz muda.

**R3 — Mãos → chão também.**
Desequipar não devolve para a bolsa: larga no chão, com animação.

**R4 — Rede de segurança: carrinho desequipado em inventário vai para o chão.**
As três primeiras regras cobrem os caminhos que eu conheço. R4 cobre os que eu
não conheço — spawn pelo menu de debug, morte, transferência por outro mod, um
caminho do jogo que eu não mapeei. Sem ela, a invariante seria "verdadeira nos
casos que eu lembrei", que é o tipo de garantia que quebra depois de publicado.

R4 é o que torna as outras três *reforço de experiência* em vez de *a única
defesa*.

---

## Por que a invariante conserta cada incômodo

| Incômodo relatado | Regra que resolve |
|---|---|
| Guardar o carrinho na mochila | R1 |
| "Pegar" burla o derrame ao cancelar | R2 — a opção deixa de existir |
| Cancelar equipar deixa a carga no chão e o carrinho na bolsa | R3 e R4 — o carrinho não fica na bolsa |
| Ter que pegar antes de equipar | R2 — equipar direto do chão |

---

## O que a rede não podia adivinhar

R4 põe no chão todo carrinho desequipado que encontre num inventário — e
**equipar passa exatamente por esse estado**, porque o item precisa entrar no
inventário antes de ir para a mão. Sem um aviso, a rede desfazia a própria ação
de equipar: em jogo, a tecla de interagir teleportava o carrinho para os pés do
jogador em vez de equipá-lo.

`WB_Transfer` é o aviso. As ações do mod levantam o sinalizador enquanto movem o
carrinho de propósito, e a rede se cala. É um contador e não um booleano, porque
ações podem se aninhar e a primeira a terminar liberaria a rede no meio da
segunda.

## Cancelar derruba o conjunto

Cancelar derrama a carga **e o próprio carrinho** no chão. Deixar o carrinho na
mão era a metade estranha do resultado, e também criaria o estado que R4 existe
para impedir.

## Tecla E

`getCore():isKey("Interact", key)` é o mesmo teste que o jogo usa para
interagir. Com ela:

- carrinho na mão → larga no chão
- carrinho perto, mãos livres → pega

Repare que isso **não** é o caminho de veículo. Em veículo, a tecla é atendida
por `BaseVehicle.getBestSeat`, cujo bytecode inteiro é `iconst_m1; ireturn` — ele
sempre devolve -1, na B42, para qualquer veículo. Aquele caminho nunca funciona
sozinho, o que já custou três rodadas de investigação neste projeto. Aqui a tecla
é tratada por nós, sem depender dele.

---

## O que continua diferente de um veículo, e é aceitável

- **Peso.** O carrinho e a carga contam no peso do personagem, com o alívio de
  `WB_Weight`. Veículo não pesa em ninguém. Manter o peso é o que preserva o
  custo de usar o carrinho.
- **Colisão.** O carrinho no chão é um item de chão, não um obstáculo físico.
- **Um por vez.** Não há reboque nem empurrar dois.

Nada disso apareceu no pedido, e cada um custaria outra rota inteira — as rotas
de veículo e de objeto de mundo já foram tentadas e abandonadas neste projeto,
por razões registradas no histórico do git.
