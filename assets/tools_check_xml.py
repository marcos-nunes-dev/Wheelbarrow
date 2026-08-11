"""Confere que os XML do mod sao bem formados.

POR QUE EXISTE: XML malformado nao aparece como erro util. A mascara de animacao
simplesmente nao carrega, o item fica sem pose e o console nao diz por que --
outro defeito da familia "funcionalidade que silenciosamente nao acontece", que
neste projeto ja custou varias rodadas de teste.

O caso concreto que motivou o arquivo: comentario XML nao pode conter `--`, e o
estilo de comentario usado no resto do projeto usa `--` o tempo todo. O arquivo
parecia certo na leitura e era invalido.

Uso:
    python tools_check_xml.py [raiz]
"""
import os
import sys
import xml.dom.minidom


def main(root):
    checked, problems = 0, 0
    for dirpath, _dirs, files in os.walk(os.path.join(root, "Contents")):
        for name in sorted(files):
            if not name.endswith(".xml"):
                continue
            path = os.path.join(dirpath, name)
            checked += 1
            try:
                xml.dom.minidom.parse(path)
            except Exception as error:
                problems += 1
                print("%s: %s" % (os.path.relpath(path, root), error))

    print("%d XML verificados, %d malformados" % (checked, problems))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
