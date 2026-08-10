"""Confere que os defaults do Lua batem com os do sandbox-options.txt.

POR QUE EXISTE: WB_Sandbox.lua guarda um espelho dos defaults, porque
SandboxVars nao existe antes de o save carregar e uma option nova e nil em saves
antigos. Espelho e duas fontes de verdade -- e nada no jogo reclama se elas
divergirem. O sintoma seria silencioso e enganoso: a option apareceria com um
valor no menu e o mod se comportaria como outro.

Roda junto com os outros verificadores antes de abrir o jogo.

Uso:
    python tools_check_sandbox.py [raiz]
"""
import io
import os
import re
import sys

OPTIONS = "Contents/mods/MNWheelbarrow/42/media/sandbox-options.txt"
MIRROR = "Contents/mods/MNWheelbarrow/42/media/lua/shared/WB_Sandbox.lua"


def normalise(value):
    value = value.strip()
    if value in ("true", "false"):
        return value
    return "%g" % float(value)


def main(root):
    opts = io.open(os.path.join(root, OPTIONS), encoding="utf-8").read()
    lua = io.open(os.path.join(root, MIRROR), encoding="utf-8").read()

    declared = dict(re.findall(
        r'option MNWheelbarrow\.(\w+)\s*\{[^}]*default\s*=\s*([^,}\s]+)', opts, re.S))
    mirrored = dict(re.findall(r'^\s{4}(\w+)\s*=\s*([^,]+),$', lua, re.M))

    problems = 0
    for name, value in sorted(declared.items()):
        other = mirrored.get(name)
        if other is None:
            problems += 1
            print("%s: existe em sandbox-options.txt e falta no espelho do Lua"
                  % name)
        elif normalise(value) != normalise(other):
            problems += 1
            print("%s: sandbox-options diz %s, o Lua diz %s"
                  % (name, value, other.strip()))

    for name in sorted(set(mirrored) - set(declared)):
        problems += 1
        print("%s: esta no espelho do Lua e nao existe como option" % name)

    print("%d options conferidas, %d divergencias" % (len(declared), problems))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
