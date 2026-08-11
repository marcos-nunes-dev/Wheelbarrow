"""Confere a estrutura dos arquivos Lua do mod, sem interpretador Lua.

POR QUE EXISTE: nao ha Lua instalado nesta maquina, e erro de sintaxe num
arquivo do mod nao aparece como erro de sintaxe -- aparece como uma
funcionalidade que simplesmente nao acontece, porque o jogo aborta o
carregamento daquele arquivo e segue. Isso ja custou rodadas de teste neste
projeto por outros motivos; nao vale repetir por um `end` faltando.

O QUE ELE NAO E: um parser de Lua. Ele nao valida expressoes nem escopo. Cobre a
classe de erro que da para pegar contando: blocos desbalanceados, parenteses e
chaves desbalanceados, e `ipairs` sobre tabela literal -- este ultimo porque uma
tabela que comece com nil faz ipairs parar no indice 1, defeito que ja apareceu
aqui e que nenhum verificador de sintaxe pegaria. Cobre tambem `require` sem uso,
que carrega um modulo sem que nada no arquivo o mencione.

Uso:
    python tools_check_lua.py [raiz]
"""
import io
import os
import re
import sys

# `elseif` e `until` nao abrem bloco. `for` e `while` tambem nao -- quem abre e o
# `do` deles, contado separadamente. `then` nao abre: o `if` ja abriu.
OPENERS = re.compile(r'\b(function|if|do)\b')
CLOSERS = re.compile(r'\bend\b')
REPEATS = re.compile(r'\brepeat\b')
UNTILS = re.compile(r'\buntil\b')


def strip_noise(source):
    """Remove comentarios e strings, que podem conter palavras-chave soltas.

    VARREDURA, E NAO REGEX, e a razao e um defeito que este arquivo teve:

    a versao anterior removia comentarios de linha ANTES das strings. Uma string
    contendo `--` -- e este projeto escreve `--` como travessao o tempo todo --
    tinha o proprio miolo removido como se fosse comentario, sobrava uma aspa
    orfa, e o removedor de strings emparelhava essa aspa com outra 30 linhas
    adiante, engolindo o codigo entre as duas. O resultado foram DOIS problemas
    inventados num arquivo correto: blocos desbalanceados e um require "sem uso"
    cujo uso tinha sido comido.

    Inverter a ordem nao resolve: aspa dentro de comentario quebraria do outro
    lado. Comentario e string so se distinguem lendo da esquerda para a direita,
    uma vez, sabendo em que estado se esta. E o que esta funcao faz.
    """
    out = []
    i, n = 0, len(source)

    while i < n:
        two = source[i:i + 2]

        if two == "--":
            if source[i + 2:i + 4] == "[[":            # comentario de bloco
                end = source.find("]]", i + 4)
                i = n if end < 0 else end + 2
            else:                                       # comentario de linha
                end = source.find("\n", i)
                i = n if end < 0 else end
            out.append(" ")
            continue

        if two == "[[":                                 # string longa
            end = source.find("]]", i + 2)
            i = n if end < 0 else end + 2
            out.append(' " " ')
            continue

        if source[i] in '"\'':                          # string comum
            quote = source[i]
            i += 1
            while i < n and source[i] != quote:
                # Uma string nao atravessa linha em Lua; parar na quebra evita
                # que uma aspa desbalanceada engula o resto do arquivo.
                if source[i] == "\n":
                    break
                i += 2 if source[i] == "\\" else 1
            i += 1
            out.append(' " " ')
            continue

        out.append(source[i])
        i += 1

    return "".join(out)


def check(path):
    source = open(path, encoding="utf-8").read()
    code = strip_noise(source)
    problems = []

    opens = len(OPENERS.findall(code))
    closes = len(CLOSERS.findall(code))
    if opens != closes:
        problems.append("blocos desbalanceados: %d aberturas (function/if/do) "
                        "para %d `end`" % (opens, closes))

    if len(REPEATS.findall(code)) != len(UNTILS.findall(code)):
        problems.append("repeat/until desbalanceados")

    for open_ch, close_ch, label in (("(", ")", "parenteses"),
                                     ("{", "}", "chaves"),
                                     ("[", "]", "colchetes")):
        if code.count(open_ch) != code.count(close_ch):
            problems.append("%s desbalanceados: %d x %d"
                            % (label, code.count(open_ch), code.count(close_ch)))

    if re.search(r'ipairs\s*\(\s*\{', code):
        problems.append("ipairs sobre tabela literal -- se o primeiro elemento "
                        "puder ser nil, a iteracao para no indice 1")

    # `next` com um argumento so, o idioma comum para "tabela vazia?", quebrou em
    # jogo: o depurador de Lua parou na linha. Ele aparece UMA vez em todo o Lua
    # do jogo base, e ainda assim com dois argumentos -- nao vale depender de um
    # canto do sandbox que o proprio jogo nao exercita. Usar #tabela ou um
    # contador.
    if re.search(r'(?<![\w.:])next\s*\([^,)]*\)', code):
        problems.append("next() com um argumento -- quebrou em jogo; usar "
                        "#tabela ou um contador")

    # `require` que ninguem usa. Nao e so sujeira: o require CARREGA o modulo, e
    # um modulo com efeito colateral no topo passa a ser executado por um arquivo
    # que nao tem mais nada a ver com ele -- dependencia invisivel que nao aparece
    # em nenhuma leitura do codigo. Os dois casos aqui vieram de mover codigo para
    # outro arquivo e esquecer a linha para tras.
    for name in re.findall(r'local\s+(\w+)\s*=\s*require\b', code):
        uses = len(re.findall(r'(?<![\w.:])' + re.escape(name) + r'\b', code))
        if uses < 2:
            problems.append("require sem uso: %s" % name)

    return problems


#: Onde procurar o Lua do jogo. A checagem de API desconhecida so roda se achar.
GAME_LUA = (
    r"C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid/media/lua",
    r"D:/SteamLibrary/steamapps/common/ProjectZomboid/media/lua",
)

#: Globais nossos, que naturalmente nao aparecem no Lua do jogo.
OURS = {"MNWheelbarrow"}


def strip_all(path):
    return strip_noise(io.open(path, encoding="utf-8", errors="replace").read())


def game_lua():
    """Todo o Lua do jogo concatenado, sem comentarios. Vazio se nao achar."""
    for root in GAME_LUA:
        if not os.path.isdir(root):
            continue
        chunks = []
        for dirpath, _dirs, files in os.walk(root):
            for name in files:
                if name.endswith(".lua"):
                    chunks.append(strip_all(os.path.join(dirpath, name)))
        return "\n".join(chunks)
    return ""


def check_unknown_apis(root):
    """Globais que o nosso Lua chama e o jogo base nunca chama.

    POR QUE: as duas ultimas falhas em jogo vieram de eu presumir que uma API
    funciona. A pior foi InventoryItemFactory.CreateItem -- a classe existe no
    engine, mas o Lua do jogo nao a chama em lugar nenhum (aparece uma vez, dentro
    de um comentario), e CreateItem tem dez sobrecargas genericas que o Lua do PZ
    nao resolve. O jogo travava ao andar pelo mapa.

    A heuristica e simples e vale pelo que implica: se o proprio jogo nunca chama
    aquilo de Lua, voce esta em terreno nao exercitado. Nao prova que quebra --
    prova que ninguem testou por voce.
    """
    game = game_lua()
    if not game:
        print("  (Lua do jogo nao encontrado; checagem de API desconhecida pulada)")
        return []

    modules, used = set(), {}
    for dirpath, _dirs, files in os.walk(root):
        if "Translate" in dirpath:
            continue
        for name in sorted(files):
            if not name.endswith(".lua"):
                continue
            modules.add(name[:-4])
            code = strip_all(os.path.join(dirpath, name))
            for call in re.findall(r"(?<![\w.:])([A-Z]\w+)\s*[.:]\s*\w+\s*\(", code):
                used.setdefault(call, set()).add(name)

    problems = []
    for name in sorted(used):
        if name in modules or name in OURS:
            continue
        if not re.search(r"(?<![\w.:])%s\s*[.:]" % re.escape(name), game):
            problems.append("%s: o Lua do jogo nunca chama %s -- API nao exercitada"
                            % (", ".join(sorted(used[name])), name))
    return problems


def main(root):
    total, checked = 0, 0
    for dirpath, _dirs, files in os.walk(root):
        for name in sorted(files):
            if not name.endswith(".lua"):
                continue
            path = os.path.join(dirpath, name)
            checked += 1
            for problem in check(path):
                total += 1
                print("%s: %s" % (os.path.relpath(path, root), problem))

    for problem in check_unknown_apis(root):
        total += 1
        print(problem)

    print("%d arquivos Lua verificados, %d problemas" % (checked, total))
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "Contents"))
