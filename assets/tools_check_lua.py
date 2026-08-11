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
    """Remove comentarios e strings, que podem conter palavras-chave soltas."""
    out = source
    out = re.sub(r'--\[\[.*?\]\]', ' ', out, flags=re.S)
    out = re.sub(r'--[^\n]*', ' ', out)
    out = re.sub(r'\[\[.*?\]\]', ' " " ', out, flags=re.S)
    out = re.sub(r'"(?:\\.|[^"\\])*"', ' " " ', out)
    out = re.sub(r"'(?:\\.|[^'\\])*'", " ' ' ", out)
    return out


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
    print("%d arquivos Lua verificados, %d problemas" % (checked, total))
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "Contents"))
