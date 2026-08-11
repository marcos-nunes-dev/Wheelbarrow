# Traduções: escopo e confiança

23 idiomas. Todos gerados por `assets/tools_gen_translations.py` a partir de uma
tabela única — editar 115 arquivos JSON à mão garantiria que um deles ficasse com
uma chave a menos, e **chave faltando não dá erro**: o jogo cai para o inglês em
silêncio, então o defeito só apareceria para quem joga naquele idioma.

---

## O que está traduzido, e o que não está

**Traduzido:** nome do item, título do compartimento, opção de menu, rótulos das
ações e os 11 rótulos das opções de sandbox. São as strings que o jogador vê o
tempo todo.

**Não traduzido — em inglês de propósito:** as 11 tooltips longas das opções de
sandbox e a tooltip do item.

A razão é como o fallback funciona:

> Chave **ausente** cai para o inglês. Chave **errada** não cai para nada — fica
> errada para sempre.

Um rótulo curto é verificável. Um parágrafo técnico em tailandês escrito por quem
não fala tailandês é risco puro por pouco ganho. As tooltips entram quando
houver revisão de quem fala o idioma.

---

## Confiança por idioma

Isto existe para você saber o que pedir para revisar antes de publicar, em vez de
tratar 23 idiomas como se tivessem a mesma qualidade.

| Confiança | Idiomas |
|---|---|
| **Alta** | ES, FR, IT, DE, NL, PT, PTBR, CA |
| **Média** | PL, RU, UA, CS, HU, NO, TR |
| **Baixa — revisar antes de publicar** | CN, CH, JP, KR, TH, VI, AF |

Nos de confiança baixa, o risco não é o significado estar errado; é o termo não
ser o que um jogador daquele idioma usaria para "carrinho de mão", ou o registro
soar estranho num menu de jogo.

---

## Como corrigir ou acrescentar

Tudo mora em `LANGUAGES`, dentro de `assets/tools_gen_translations.py`: um idioma
por linha, 15 strings na ordem de `FIELDS`. Depois de editar:

```
cd assets && python tools_gen_translations.py
```

O gerador recusa um idioma com número errado de strings, então esquecer uma falha
alto em vez de gerar um arquivo silenciosamente incompleto.
