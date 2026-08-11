"""Confere os XML do mod: sintaxe, e registro dos clothing items.

POR QUE EXISTE: XML malformado nao aparece como erro util. A mascara de animacao
simplesmente nao carrega, o item fica sem pose e o console nao diz por que --
outro defeito da familia "funcionalidade que silenciosamente nao acontece", que
neste projeto ja custou varias rodadas de teste.

Dois casos concretos motivaram o arquivo, e os dois custaram rodada de teste:

  comentario XML nao pode conter `--`, e o estilo de comentario do resto do
  projeto usa `--` o tempo todo. O arquivo parecia certo na leitura e era
  invalido, e a mascara de animacao simplesmente nao carregava.

  clothing item que nao esta no fileGuidTable.xml e IGNORADO. O XML pode estar
  perfeito e o modelo nao renderiza, sem nada no log.

Uso:
    python tools_check_xml.py [raiz]
"""
import io
import os
import re
import sys
import xml.dom.minidom


def registered(root):
    """GUIDs declarados em qualquer fileGuidTable.xml do mod."""
    found = set()
    for dirpath, _dirs, files in os.walk(os.path.join(root, "Contents")):
        for name in files:
            if name.lower() == "fileguidtable.xml":
                text = io.open(os.path.join(dirpath, name), encoding="utf-8").read()
                found |= set(re.findall(r"<guid>([^<]+)</guid>", text))
    return found


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
                continue

            # Clothing item que nao esta no fileGuidTable e IGNORADO pelo jogo: o
            # modelo nao renderiza e nada aparece no log. Ja custou uma rodada de
            # teste aqui.
            if os.path.basename(os.path.dirname(path)) == "clothingItems":
                guid = re.search(r"<m_GUID>([^<]+)</m_GUID>",
                                 io.open(path, encoding="utf-8").read())
                if guid is None or guid.group(1) not in registered(root):
                    problems += 1
                    print("%s: nao esta registrado em fileGuidTable.xml, "
                          "entao o jogo ignora o clothing item"
                          % os.path.relpath(path, root))

    print("%d XML verificados, %d problemas" % (checked, problems))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
