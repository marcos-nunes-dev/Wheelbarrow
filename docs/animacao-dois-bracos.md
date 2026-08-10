# Pendência: animação de carregar com os dois braços

**Estado:** não resolvido, adiado. O carrinho equipa nas duas mãos e funciona,
mas o personagem anima como se segurasse com **um braço só** — o direito reto
para baixo segurando, o esquerdo fazendo o balanço normal de caminhada.

Este arquivo existe para a próxima tentativa não repetir o que já foi medido.
Fica em `docs/`, que **não** sobe para a Workshop (só `Contents/` é enviado).

---

## O que o problema é, exatamente

Não é "falta uma máscara". É que máscara é a ferramenta errada.

`primaryAnimMask` e `secondaryAnimMask` são **por mão**, e a secundária é a
máscara de quando o item está na **mão secundária** — não a segunda metade de uma
pose de duas mãos. Com o mesmo objeto nas duas mãos, o jogo aplica só uma. Somar
as duas nunca produziria uma pose coerente: são dois remendos sobre a animação de
andar, não uma animação de carregar.

O correto, como o Marcos apontou, é **uma** animação de corpo com os dois braços.

---

## Caminhos já testados, e por que cada um falhou

| Caminho | Resultado |
|---|---|
| `secondaryAnimMask = holdingbagleft` | Aceito, sem efeito. Só uma máscara é aplicada. |
| Tag `base:heavyitem` | Sem efeito na animação. É a tag do Gerador, que É carregado com dois braços — mas ela sozinha não basta. Removida também por ser semanticamente errada num item de 3 kg e por tocar caminhos de item-pesado que já deixaram o personagem invisível neste projeto. |
| `ReplaceInSecondHand` com malha invisível | Abandonado antes de testar, quando a variável de animação apareceu como caminho melhor. A ideia era um FBX com todos os vértices na origem (triângulos de área zero) só para carregar a máscara, evitando rigging. Continua sendo um plano B viável. |
| Variável de animação `Weapon = "heavy"` via `setVariable` | **Não funcionou.** Ver abaixo. |

---

## A pista mais forte, e por que ainda vale

O jogo base **tem** a animação. Em `media/AnimSets/player` existe a família
`2H_Heavy` inteira: `Bob_Idle2H_Heavy`, `Bob_Walk2H_Heavy`, mais corrida,
sprint, furtivo, manqueira, pular cerca, ser empurrado por zumbi e as transições
entre todas — **177 nós** dependem dela.

A condição de entrada de todos esses nós não é máscara nem tipo de item:

```xml
<m_Conditions>
    <m_Name>Weapon</m_Name>
    <m_Type>STRING</m_Type>
    <m_Value>heavy</m_Value>
</m_Conditions>
```

Setar essa variável por Lua a cada quadro (`player:setVariable("Weapon",
"heavy")`, comparando antes para não reiniciar a animação) **não** levou o
personagem para esses nós.

### Hipóteses para a próxima tentativa, em ordem de custo

1. **A variável é sobrescrita depois do nosso `OnPlayerUpdate`.** O sistema de
   animação recalcula `Weapon` a partir do item equipado. Testar em outro evento,
   ou usar `OnPlayerMove`, ou verificar com `getVariableString` no quadro seguinte
   se o valor sobreviveu — isso distingue "não fui aplicado" de "fui aplicado e a
   máquina de estados não transitou".

2. **Há uma condição AND que não foi satisfeita.** Os nós herdam de pais
   (`x_extends`) que trazem as próprias condições. `IdleHeavy` estende `Idle.xml`;
   se o pai exigir algo mais — por exemplo um tipo de item equipado — a variável
   sozinha não basta. **Ler as condições herdadas é o próximo passo mais barato**,
   e não foi feito.

3. **`Weapon` pode precisar vir do item, não do Lua.** O campo de script que
   normalmente produz esse valor é do tipo arma (`SwingAnim`). Vale checar se um
   `base:container` aceita `SwingAnim` sem erro de parse — lembrando que erro de
   script no PZ é **fatal no boot**, então testar em item descartável.

---

## Restrição vizinha, descoberta depois

Textura com **canal alpha** no modelo de mão faz o personagem e os veículos
sumirem da tela — só eles; o cenário, que é sprite, continua. Aconteceu três
vezes, todas com alpha presente, nenhuma sem. O gatilho é a **reconstrução** do
modelo (`resetModelNextFrame`), não o render em si: com o modelo em cache nada
acontece.

Isso matou a sombra do carrinho enquanto carregado, e vale para qualquer coisa
que a próxima tentativa queira acrescentar ao modelo de mão. Antes de tentar de
novo, descobrir **por quê**: se é o canal alpha, o tamanho 1024x512, ou não ser
potência de dois nos dois lados.

## Restrição que qualquer solução precisa respeitar

Está **medido neste projeto**: `StaticModel` só renderiza quando existe uma
máscara de animação declarada. Sem `primaryAnimMask`, o carrinho desaparece da
mão. Qualquer solução que remova as máscaras precisa resolver a renderização
junto.

---

## Efeito colateral a lembrar

A animação move os braços, logo move a **mão** — e a pose do carrinho está
calibrada em `(0.31, 0.90, 0.56)` contra a animação atual, de um braço.
**Trocar a animação invalida a calibração.** O laboratório de pose
(`assets/tools_gen_pose_grid.py`) regenera o grid com um comando; a varredura em
jogo é por tecla, não um restart por tentativa.
