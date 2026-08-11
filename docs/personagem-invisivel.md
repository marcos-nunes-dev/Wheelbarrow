# O personagem invisível: o que é, e o que não é

Este arquivo existe porque eu diagnostiquei esse sintoma **errado três vezes** ao
longo do projeto, e cada erro custou rodadas de teste. Ele registra o que ficou
estabelecido, para a próxima suspeita não recomeçar do zero.

---

## O sintoma

O personagem some da tela deixando só a sombra. Veículos e outros objetos 3D
somem junto; o cenário, que é sprite, continua. **Nada aparece no console** — nem
erro de Lua, nem exceção Java.

---

## A causa, até onde se sabe

Não é do nosso mod. É um defeito conhecido da B42 em que o engine força o
**alpha de render do jogador a zero** e o reafirma a cada quadro.

Existe um mod dedicado exclusivamente a isso —
[PlayerModelReloadUtil](https://github.com/dataterminals/PlayerModelReloadUtil) —
e o próprio autor registra que **o gatilho exato é desconhecido**, tendo
capturado o estado travado *"em campo aberto, sem nada acima"*. Ou seja: nem a
teoria de "ficou preso atrás de uma parede" se sustenta.

Há também relatos de jogadores sem mod nenhum, em multiplayer, com
[personagens, zumbis e veículos sumindo e só as sombras aparecendo](https://steamcommunity.com/app/108600/discussions/1/800091475572493518/).

---

## Meus três diagnósticos errados

Vale a lista, porque todos pareciam sólidos na hora:

| Suspeito | Por que parecia certo | Por que não era |
|---|---|---|
| Encolher o peso dos itens | Sumia ao mexer no peso de item na mão | O sumiço continuou depois de a técnica ser abandonada |
| Mudar peso/capacidade com o carrinho equipado | Sumia logo após transferir itens | Idem — e a "correção" (`resetModelNextFrame`) nunca foi comprovada |
| Textura com canal alpha | Um teste controlado confirmou a quebra | Aquilo era **um segundo defeito, real e separado**: textura 1024x512 quebra o passe de modelo. Consertar aquilo não fez este sumir |

O padrão do erro foi sempre o mesmo: **correlação num sintoma que não deixa
rastro**. Sem erro no log, qualquer coisa que eu tivesse mexido por último
virava suspeita.

O caso da textura merece nota: aquele teste controlado estava **certo** — 1024x512
com alpha realmente derruba o render de modelos, e o controle positivo provou.
Só não era a causa *deste* sintoma. Dois defeitos com a mesma aparência.

---

## O que o mod faz a respeito

`WB_Player` vigia o alpha do jogador **enquanto o carrinho está na mão** e o
devolve a 1 quando ele fica preso perto de zero.

Três decisões, e as razões:

**Trata o sintoma, não a causa.** Não sei a causa raiz, e ninguém sabe. O
comentário no código diz isso; não vale fingir conserto.

**Com atraso de meio segundo.** Alpha também é usado em transições legítimas.
Reafirmar 1 a cada quadro atropelaria qualquer desvanecimento do jogo. Estado
*travado* dura; transição passa.

**Só com o carrinho na mão.** O defeito é do jogo base e acontece sem mod nenhum.
Consertar o jogo inteiro não é papel deste mod, e um mod que mexe no render do
jogador o tempo todo é um mod que briga com outros. Quem quiser cobertura geral
tem o utilitário dedicado acima.

---

## Se aparecer de novo

1. Confirme se é isto: com `-debug`, existe um atalho **Toggle Models Enabled**
   que desliga o render de modelos 3D e produz exatamente esta aparência. Se os
   modelos voltarem ao apertá-lo, foi a tecla, não o defeito.
2. Veja se o vigia agiu: em debug ele imprime
   `[Wheelbarrow][ALPHA] personagem estava invisivel; alpha restaurado`.
   Linha presente significa que o alpha era mesmo a causa.
3. **Sem essa linha, o alpha não era a causa** — e aí a investigação recomeça em
   outro lugar, provavelmente no passe de modelo.
