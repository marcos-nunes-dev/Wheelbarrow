# Wheelbarrow — Project Zomboid Build 42

A construction wheelbarrow for hauling loads the game normally punishes you for
carrying: generators, logs, propane tanks.

*[Versão em português abaixo.](#português)*

## Design

The wheelbarrow is **deliberately useless for ordinary loot**. Weight reduction
only applies to items at or above a weight threshold — filling it with nails and
canned food gains you nothing. Its purpose is a small number of very heavy
objects, and it charges you for that: it takes **both hands**, so no weapon while
you push it, and it slows you down.

Picking it up and setting it down is a timed action. Interrupt it and the
wheelbarrow tips over, dumping everything on the ground.

The wheelbarrow is **never in your inventory**. It is always either on the
ground or in your hands, like a vehicle — `E` picks it up and sets it down. It
also stops you climbing fences, going through windows and getting into cars.

Find one lying around construction sites, warehouses, garages and tool stores,
or weld your own at `MetalWelding` level 4.

Everything above is tunable in the Sandbox options — 12 of them, including
whether the tip over happens at all.

## Requirements

- Project Zomboid **Build 42**
- No other mods required

## Multiplayer

Supported. Balance values come from the server's sandbox settings, so the admin
decides for everyone.

## Languages

23 languages. Short labels are translated in all of them; the long tooltips are
in English and Portuguese only.

Chinese, Japanese, Korean, Thai, Vietnamese and Afrikaans **have not been
reviewed by a native speaker** yet. The game falls back to English for any
language not shipped here.

## ⚠️ Removing the mod

Removing the mod from a save that already has wheelbarrows in the world can
cause errors when the save loads. This is how Project Zomboid handles items
whose definition disappeared — it is not specific to this mod. Empty and delete
your wheelbarrows before uninstalling.

## Development

The repository root doubles as the mod's Workshop folder. Link it into the game:

```
mklink /J "%UserProfile%\Zomboid\Workshop\Wheelbarrow" "<path to this repo>"
```

Only `Contents/` is uploaded to the Steam Workshop — `assets/`, `.git/` and this
README stay local.

Add `-debug` to the game's Steam launch options to spawn the item from the debug
menu. Lua errors land in `%UserProfile%\Zomboid\console.txt`.

Changes to `.lua` files can be reloaded in game. Changes to `scripts/*.txt`,
`sandbox-options.txt`, translations or `mod.info` need a game restart.

## License

MIT — see [LICENSE](LICENSE).

---

## Português

Um carrinho de mão de construção para transportar o que o jogo normalmente
pune você por carregar: geradores, troncos, botijões de gás.

### Design

O carrinho é **inútil de propósito para loot comum**. A redução de peso só vale
para itens a partir de um limite de peso — enchê-lo de pregos e comida enlatada
não adianta nada. Ele existe para poucos objetos muito pesados, e cobra por
isso: ocupa **as duas mãos**, então nada de arma enquanto você empurra, e te
deixa mais lento.

Pegar e largar é uma ação com animação. Interrompa e o carrinho tomba,
derrubando tudo no chão.

O carrinho **nunca fica no inventário**. Ele está sempre no chão ou nas mãos,
como um veículo — `E` pega e larga. Ele também impede escalar cerca, passar por
janela e entrar em carro.

Ache um largado em obras, galpões, garagens e lojas de ferramentas, ou solde o
seu com `MetalWelding` nível 4.

Tudo isso é ajustável nas opções de Sandbox — 12 delas, inclusive se o
tombamento acontece ou não.

### Requisitos

- Project Zomboid **Build 42**
- Nenhum outro mod necessário

### Multiplayer

Suportado. Os valores de balanceamento vêm das configurações de sandbox do
servidor, então o admin decide para todo mundo.

### ⚠️ Removendo o mod

Remover o mod de um save que já tem carrinhos no mundo pode gerar erro no
carregamento. É assim que o Project Zomboid lida com itens cuja definição
desapareceu — não é específico deste mod. Esvazie e destrua seus carrinhos antes
de desinstalar.
