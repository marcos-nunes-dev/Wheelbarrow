"""Valida os scripts .txt do mod antes de o jogo tentar carrega-los.

POR QUE ISTO EXISTE:
erro em script do PZ nao e aviso, e fatal. ScriptManager.Load lanca IOException
e GameWindow morre no boot -- o jogo simplesmente nao abre, e a causa fica num
stack trace de Java no fim do console.txt. Um mod publicado com esse defeito
tira o jogo do ar do assinante, nao "quebra o carrinho".

Foi o que aconteceu com

    rotate =    0.0    0.0    0.0,

alinhado em colunas para ficar legivel. ModelScript.LoadVector3f separa os
componentes por espaco UNICO, entao o alinhamento produz tokens vazios e
Float.parseFloat estoura com NumberFormatException: empty String. Nenhum
arquivo vanilla usa espaco duplo nesses campos -- verificado nos scripts do
jogo inteiro -- o que confirma que espaco unico e a convencao exigida, e nao
uma preferencia.

O que este script NAO faz: nao entende a gramatica dos scripts do PZ nem
substitui abrir o jogo. Cobre os defeitos que sao invisiveis na leitura e
fatais na execucao.

Uso:
    python tools_check_scripts.py [raiz]
"""
import os
import re
import sys

# Campos que o engine le como vetor de floats separados por espaco unico.
VECTOR_FIELDS = ("offset", "rotate", "extents", "center", "scale3d")

CHECKS = (
    (re.compile(r'\b(?:%s)\s*=[^,\n]*\s{2,}' % "|".join(VECTOR_FIELDS)),
     "espaco duplo em campo de vetor -- o parser separa por espaco unico e "
     "gera token vazio, o que MATA o boot do jogo"),
    (re.compile(r'\b(?:%s)\s*=[^,\n]*[\t]' % "|".join(VECTOR_FIELDS)),
     "tab em campo de vetor -- mesmo efeito do espaco duplo"),
    (re.compile(r'=\s*,'),
     "valor vazio antes da virgula"),
    # Tooltips e nomes passam por String.format no jogo. Um % solto vira
    # UnknownFormatConversionException -- ja aconteceu com um tooltip que
    # escrevia "(%)".
    (re.compile(r'(?:Tooltip|DisplayName)\s*=[^,\n]*%(?![sdf%])'),
     "% solto em texto que passa por String.format"),
)


def check_file(path):
    problems = []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for lineno, line in enumerate(fh, 1):
            code = line.split("/*")[0]
            for pattern, why in CHECKS:
                if pattern.search(code):
                    problems.append((lineno, why, line.rstrip()))
    return problems


def main(root):
    total = 0
    checked = 0
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            if not name.endswith(".txt"):
                continue
            path = os.path.join(dirpath, name)
            checked += 1
            for lineno, why, line in check_file(path):
                total += 1
                rel = os.path.relpath(path, root)
                print("%s:%d: %s\n    %s" % (rel, lineno, why, line.strip()))
    print("%d arquivos verificados, %d problemas" % (checked, total))
    return 1 if total else 0


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else "Contents"
    sys.exit(main(root))
