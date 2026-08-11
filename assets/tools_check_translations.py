"""Confere as traducoes contra o que o mod realmente usa.

POR QUE EXISTE: chave de traducao errada ou faltando nao da erro. Chave AUSENTE cai
para o ingles em silencio -- o defeito so aparece para quem joga naquele idioma.
Chave A MAIS e pior de achar: ela nunca sera lida, e nada indica isso. Este arquivo
existe porque uma chave morta passou por revisao humana sem ser notada
(IGUI_ContainerTitle_wheelbarrow, que so vale para container de objeto de mundo).

O QUE ELE CONFERE

  1. todo idioma tem o MESMO conjunto de arquivos e chaves que o EN, que e o
     fallback do jogo e portanto a referencia;
  2. toda chave usada pelo codigo -- getText no Lua, Tooltip nos scripts -- existe;
  3. toda chave fornecida e usada por alguem. Chave orfa e defeito silencioso;
  4. cada `translation = X` de sandbox-options.txt tem Sandbox_X e o _tooltip;
  5. nenhum valor vazio, e language.json com version e language_name;
  6. a mensagem de recusa fala do carrinho com a MESMA palavra do nome do item.
     Parece detalhe e nao e: o VI dizia "Xe cut kit" no nome e "xe rua" na recusa --
     dois termos para a mesma coisa no mesmo idioma. Da para pegar sem falar a
     lingua comparando o radical, e nenhuma revisao humana daqui notaria isso em 23
     arquivos.

Uso:
    python tools_check_translations.py [raiz]
"""
import io
import json
import os
import re
import sys

# O console do Windows e cp1252 e engasga ao imprimir os proprios valores que este
# arquivo compara -- e todos os problemas interessantes envolvem texto acentuado ou
# CJK. Sem isto o verificador morre justamente quando acha algo.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

MOD = os.path.join("Contents", "mods", "MNWheelbarrow", "42", "media")
TRANSLATE = os.path.join(MOD, "lua", "shared", "Translate")
REFERENCE = "EN"

#: Chaves que o ENGINE le sozinho, sem passar por getText no nosso codigo. Cada uma
#: precisa de justificativa, senao esta lista vira o lugar onde chave morta se
#: esconde.
ENGINE_KEYS = {
    # Nome do item: lido pelo engine a partir do tipo completo. Formato sem prefixo,
    # conferido no ItemName.json do jogo base ("Base.3030Box": "...").
    "MNWheelbarrow.Wheelbarrow",
    # Nome da craftRecipe: a chave E o nome da receita, tambem sem prefixo. Conferido
    # no Recipes.json do jogo base ("Forge_Block_From_Chunk": "...").
    "MakeWheelbarrow",
    # Nome da pagina de sandbox, montado como Sandbox_<page>.
    "Sandbox_MNWheelbarrow",
    "version",
    "language_name",
}


def read_json(path):
    with io.open(path, encoding="utf-8") as fh:
        return json.load(fh)


def provided(root, language):
    """Chaves de um idioma, e de onde cada uma vem."""
    folder = os.path.join(root, TRANSLATE, language)
    keys = {}
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".json"):
            continue
        for key, value in read_json(os.path.join(folder, name)).items():
            keys[key] = (name, value)
    return keys


def used(root):
    """Chaves que o codigo e os scripts referenciam."""
    found = set()

    lua_root = os.path.join(root, MOD, "lua")
    for dirpath, _dirs, files in os.walk(lua_root):
        # Nao varre as proprias traducoes: um valor que por acaso contenha
        # getText("...") viraria uma chave inventada.
        if "Translate" in dirpath:
            continue
        for name in files:
            if not name.endswith(".lua"):
                continue
            text = io.open(os.path.join(dirpath, name), encoding="utf-8").read()
            found |= set(re.findall(r'getText\("([^"]+)"', text))

    scripts = os.path.join(root, MOD, "scripts")
    for name in sorted(os.listdir(scripts)):
        if not name.endswith(".txt"):
            continue
        text = io.open(os.path.join(scripts, name), encoding="utf-8").read()
        found |= set(re.findall(r'Tooltip\s*=\s*([A-Za-z_][\w.]*)', text))

    return found


def sandbox_options(root):
    """Nomes de `translation =` em sandbox-options.txt."""
    path = os.path.join(root, MOD, "sandbox-options.txt")
    text = io.open(path, encoding="utf-8").read()
    return set(re.findall(r'translation\s*=\s*(\w+)', text))


def main(root):
    problems = []

    reference = provided(root, REFERENCE)
    languages = sorted(d for d in os.listdir(os.path.join(root, TRANSLATE))
                       if os.path.isdir(os.path.join(root, TRANSLATE, d)))

    # 1. todo idioma espelha o EN
    for language in languages:
        keys = provided(root, language)
        for missing in sorted(set(reference) - set(keys)):
            problems.append("%s: falta a chave %s" % (language, missing))
        for extra in sorted(set(keys) - set(reference)):
            problems.append("%s: chave %s nao existe no %s"
                            % (language, extra, REFERENCE))
        for key, (origin, value) in sorted(keys.items()):
            if not str(value).strip():
                problems.append("%s/%s: %s esta vazia" % (language, origin, key))
        for required in ("version", "language_name"):
            if required not in keys:
                problems.append("%s: language.json sem %s" % (language, required))

    # 2 e 3. o que o codigo usa contra o que existe
    referenced = used(root)
    for option in sandbox_options(root):
        referenced.add("Sandbox_" + option)
        referenced.add("Sandbox_" + option + "_tooltip")
    referenced |= ENGINE_KEYS

    for missing in sorted(referenced - set(reference)):
        problems.append("usada no mod e ausente no %s: %s" % (REFERENCE, missing))
    for orphan in sorted(set(reference) - referenced):
        problems.append("fornecida e nunca usada: %s (de %s)"
                        % (orphan, reference[orphan][0]))

    # 6. consistencia de vocabulario entre o nome do item e a mensagem de recusa
    for language in languages:
        keys = provided(root, language)
        name = keys.get("MNWheelbarrow.Wheelbarrow", (None, ""))[1]
        refuse = keys.get("IGUI_MNWB_Refuse", (None, ""))[1]
        # Quatro caracteres cobrem a flexao das linguas eslavas e ugro-finicas
        # ("taczka" -> "taczka", "Tachka" -> "tachkoy") sem virar coincidencia.
        stem = name[:4].lower()
        if stem and stem not in refuse.lower():
            problems.append("%s: a recusa nao usa a palavra do nome do item "
                            "(%s vs %s)" % (language, name, refuse))

    for problem in problems:
        print(problem)
    print("%d idiomas, %d chaves cada, %d problemas"
          % (len(languages), len(reference), len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
