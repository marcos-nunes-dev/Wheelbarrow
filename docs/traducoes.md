# Traducoes

23 idiomas, 35 chaves cada, geradas de UMA tabela em `assets/tools_gen_translations.py`.

## Por que um gerador

Sao 23 idiomas x 6 arquivos. Editar 138 JSON a mao garante que um deles fique com
uma chave a menos, e **chave faltando nao da erro**: o jogo cai para o ingles em
silencio, entao o defeito so aparece para quem joga naquele idioma. Aqui a lista de
chaves e uma so.

## Por que um verificador tambem

`assets/tools_check_translations.py`. O gerador garante que os idiomas sejam iguais
entre si; ele nao garante que o conjunto de chaves corresponda ao que o mod
**usa**. Sao dois defeitos diferentes:

- chave **ausente** cai para o ingles em silencio;
- chave **a mais** nunca sera lida, e nada indica isso.

O verificador confere:

1. todo idioma tem o mesmo conjunto de arquivos e chaves que o EN;
2. toda chave usada -- `getText` no Lua, `Tooltip` nos scripts, `translation` no
   sandbox -- existe;
3. toda chave fornecida e usada por alguem;
4. nenhum valor vazio, e `language.json` com `version` e `language_name`;
5. a mensagem de recusa fala do carrinho com a **mesma palavra** do nome do item.

### Os dois defeitos que ele achou

**Chave morta.** `IGUI_ContainerTitle_wheelbarrow` existia nos 23 idiomas e nunca
foi lida. O sufixo dessa chave e um **tipo de container** (`cupboard`, `bin`,
`trough`), e ela so vale para container de objeto de mundo e de corpo -- confirmado
em `ISInventoryPage`, que para um container vindo de ITEM passa `item:getName()`
direto. O jogo base nao define nenhuma para bolsa. Passou por revisao humana sem ser
notada.

**Vocabulario inconsistente.** O vietnamita chamava o item de "Xe cút kít" e dizia
"xe rùa" na mensagem de recusa -- dois termos para a mesma coisa no mesmo idioma. Da
para pegar sem falar a lingua comparando o radical das duas strings, e nenhuma
revisao daqui notaria isso em 23 arquivos.

## Escopo: rotulos curtos em tudo, tooltip longa em portugues

Traduzidos em todos os idiomas: nome do item, menu de contexto, rotulos de acao,
nome da receita, mensagem de recusa e os rotulos das opcoes de sandbox.

**Tooltips longas so em portugues** (PTBR e PT). A razao nao e preguica, e como o
fallback funciona: chave **ausente** cai para o ingles, chave **errada** nao cai para
nada -- fica errada para sempre. Um paragrafo tecnico em tailandes escrito por quem
nao fala a lingua e risco puro por pouco ganho.

Portugues e a excecao pela mesma razao que criou a regra: aqui a revisao existe. Onde
ha quem revise, o motivo da regra desaparece. As demais linguas entram quando houver
revisao de quem fala o idioma.

## Acento

Comentario de codigo neste projeto e ASCII de proposito. **Texto que o jogador le nao
e.** Traducao da B42 e JSON em UTF-8 justamente para que acento deixe de ser
problema -- na B41 era `.txt` com charset por idioma, e ai acento em portugues doia.

## Confianca por idioma

| Confianca | Idiomas |
|---|---|
| alta | ES, FR, IT, DE, NL, PT, PTBR, CA |
| media | PL, RU, UA, CS, HU, NO, TR |
| **baixa** | **CN, CH, JP, KR, TH, VI, AF** |

Os de confianca baixa **merecem revisao de falante nativo antes de publicar**. Eles
nao estao errados por saber -- estao sem verificacao, o que e diferente de estar
certo.
