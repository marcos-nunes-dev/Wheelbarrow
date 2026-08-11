# Changelog

O uploader do Project Zomboid sobrescreve a descrição da página da Steam a
cada envio, então **este arquivo é a única fonte estável de histórico de
versão**. Toda mudança de `modversion` em `mod.info` tem uma entrada aqui.

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

## [0.1.3] — 2026-08-11

### Adicionado

- **Cadáver no carrinho, de verdade.** A página prometia e o jogo não deixava. Com
  um cadáver arrastado, o clique direito passa a oferecer *"Drop Corpse Into
  Carrinho de mão"* quando há um carrinho no chão a até 2 squares e com espaço.
  A opção respeita a sandbox `AllowCorpses` e não aparece se o carrinho estiver
  cheio.

  Fazer isso funcionar exigiu três coisas que o jogo não faz sozinho para um
  compartimento que vem de item: dar uma square ao container de fora (o `"floor"`
  da square, que `getWorldPosition` consulta antes de qualquer outro), declarar o
  tipo do compartimento como `crate` (a lista de tipos que aceitam cadáver é fixa
  no engine e é conferida de novo no evento de animação do depósito), e usar o
  próprio texto do jogo para o menu — o que deixou a opção traduzida em mais
  idiomas do que os 23 que geramos.

## [0.1.2] — 2026-08-11

### Corrigido

- **O jogo travava ao andar pelo mapa.** O gerador de carrinhos no mundo criava o
  item com `InventoryItemFactory.CreateItem`. A classe existe no engine, mas o Lua
  do jogo não a chama em lugar nenhum — aparece uma vez, dentro de um comentário —
  e `CreateItem` tem dez sobrecargas genéricas que o Lua do Project Zomboid não
  resolve. Agora usa a sobrecarga de `AddWorldInventoryItem` que recebe o nome do
  tipo, que é o caminho que o próprio jogo usa.
- A direção sorteada do carrinho abandonado **não se perdeu**: o construtor de
  `IsoWorldInventoryObject` já sorteia a rotação de um item recém-criado. O código
  que quebrou fazia à mão o que o engine já dava de graça.

## [0.1.1] — 2026-08-11

### Corrigido

- **O jogo não carregava.** A receita de fabricação declarava a saída como
  `item 1 [MNWheelbarrow.Wheelbarrow]`, com colchetes. Colchete é sintaxe de
  **entrada**, onde lista alternativas; em `outputs` o parser lê o colchete como
  parte do nome do tipo, não acha o item, e o carregamento do mundo aborta com
  `WorldDictionaryException`. O jogador não chegava nem ao menu.

## [0.1.0] — 2026-08-11

Primeira versão enviada à Workshop, como item **privado** para verificação.

### O carrinho

- Item `MNWheelbarrow.Wheelbarrow`: compartimento que ocupa as duas mãos.
- Modelo 3D e textura próprios, com sombra de contato no chão.
- Ícone renderizado do próprio modelo.
- Animação de dois braços, por máscara de animação própria.
- Arma bloqueada e corrida impedida enquanto o carrinho está nas mãos.

### Peso e capacidade

- Redução de peso que **só** vale para itens pesados. Carga leve não ganha nada,
  e isso é de propósito: o carrinho existe para o que o jogo pune você por
  carregar, não para tralha.
- Capacidade elevada em runtime acima do teto que o script impõe.
- Teto separado, muito mais baixo, para carga leve — sem ele a capacidade total
  permitiria uma quantidade absurda de itens pequenos.

### O carrinho nunca fica no inventário

- Ele está sempre no chão ou nas mãos, como um veículo. `E` pega e larga.
- Pegar e largar são ações com animação. Interromper faz o carrinho **tombar**,
  derramando a carga e ele mesmo no chão.
- Durante qualquer ação do jogo o carrinho é apoiado no chão e volta às mãos
  sozinho quando a ação termina.
- A colocação recusa square ocupada por veículo, parede, árvore ou sem piso.

### O que o carrinho impede

- Escalar cerca, passar por janela, descer por lençol e entrar em veículo.
- Portão baixo passa a ser **aberto** em vez de pulado.

### Como consegui-lo

- Aparece largado pelo mundo em obras, galpões, garagens e lojas de ferramentas,
  e em obras de rua marcadas por cone. Um sorteio por lugar, uma vez por save.
- Receita de fabricação soldada, com `MetalWelding` nível 4.

### Configuração

- 12 opções de Sandbox cobrem todo o balanceamento: capacidade total, teto de
  carga leve, limite de peso pesado, redução, duração das ações, tombamento,
  bloqueio de arma e de corrida, corpos, spawn no mundo e fabricação.
- Em multiplayer o servidor decide para todos.

### Idiomas

- 23 idiomas. Rótulos curtos em todos; tooltips longas em inglês e português.
- **CN, CH, JP, KR, TH, VI e AF ainda não foram revisados por falante nativo.**

### Limitações conhecidas

- Carregar item muito pesado exige largar o carrinho no chão primeiro. É o
  próprio jogo: um compartimento equipado só aceita o que também caberia no
  inventário do jogador.
- Abrir porta com `E` larga o carrinho. Clicar com o mouse abre sem largar.
- A pose de mão tem um encaixe imperfeito: um dos cabos cruza a perna.
