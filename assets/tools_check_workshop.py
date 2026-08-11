"""Confere o pacote antes de enviar para a Steam Workshop.

POR QUE EXISTE: o uploader do jogo recusa o item DEPOIS de você abrir o jogo, entrar
no menu, escolher a pasta e preencher o formulário. Cada recusa e uma ida e volta de
minutos. E a mais cara delas nao e recusa nenhuma: descricao acima do limite da Steam
sobe TRUNCADA, sem erro.

Os testes aqui sao os mesmos que o jogo faz, tirados das mensagens de erro em
media/lua/shared/Translate/EN/UI.json (UI_WorkshopError_*), mais o limite da Steam.

Uso:
    python tools_check_workshop.py [raiz]
"""
import io
import os
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

#: Limite da Steam para descricao de item, em BYTES (k_cchPublishedDocumentDescription
#: Max). O jogo AINDA anexa "Workshop ID:" e "Mod ID:" ao final, entao a margem
#: reservada nao e luxo -- sem ela o texto sobe cortado no meio de uma frase.
DESCRIPTION_LIMIT = 8000
APPENDED_BY_GAME = 120

#: Preview: 256x256 imposto pelo jogo, e no maximo 1000KB.
PREVIEW_SIZE = (256, 256)
PREVIEW_MAX_BYTES = 1000 * 1024

#: Unicas pastas que o uploader aceita dentro de Contents/.
ALLOWED_IN_CONTENTS = {"mods", "maps"}

#: Tags que aparecem em pares. [*] e solto de proposito, como no BBCode da Steam.
PAIRED_TAGS = ("b", "i", "u", "h1", "h2", "h3", "hr", "list", "olist",
               "table", "tr", "th", "td", "url", "img", "quote", "spoiler")


def check_workshop_txt(root, problems):
    path = os.path.join(root, "workshop.txt")
    if not os.path.isfile(path):
        problems.append("falta workshop.txt")
        return

    lines = io.open(path, encoding="utf-8").read().splitlines()
    keys = [ln.split("=", 1)[0] for ln in lines if "=" in ln]

    for required in ("version", "title", "description", "tags", "visibility"):
        if required not in keys:
            problems.append("workshop.txt sem %s" % required)

    for single in ("version", "title", "tags", "visibility"):
        if keys.count(single) > 1:
            problems.append("workshop.txt com %s repetido %d vezes"
                            % (single, keys.count(single)))

    # id= so deve existir DEPOIS do primeiro envio. Sem ele a Steam cria um id novo;
    # com ele, atualiza. Um id errado publica em cima do item de outra pessoa.
    if "id" in keys:
        print("  nota: workshop.txt tem id= -- este envio ATUALIZA um item existente")
    else:
        print("  nota: workshop.txt sem id= -- este envio CRIA um item novo")

    body = "\n".join(ln[len("description="):] for ln in lines
                     if ln.startswith("description="))
    size = len(body.encode("utf-8"))
    budget = DESCRIPTION_LIMIT - APPENDED_BY_GAME
    if size > budget:
        problems.append("descricao com %d bytes; o limite util e %d "
                        "(%d da Steam menos %d que o jogo anexa). Sobe truncada."
                        % (size, budget, DESCRIPTION_LIMIT, APPENDED_BY_GAME))
    else:
        print("  descricao: %d bytes, %d de margem" % (size, budget - size))

    for tag in PAIRED_TAGS:
        opens = len(re.findall(r"\[%s\]" % tag, body))
        closes = len(re.findall(r"\[/%s\]" % tag, body))
        if opens != closes:
            problems.append("BBCode [%s] desbalanceado: %d abre, %d fecha"
                            % (tag, opens, closes))

    for url in re.findall(r"\[img\]([^\[]*)\[/img\]", body):
        if not url.startswith("http"):
            problems.append("[img] sem URL hospedada: %r. A Steam nao serve imagem "
                            "do repositorio." % url)


def check_preview(root, problems):
    path = os.path.join(root, "preview.png")
    if not os.path.isfile(path):
        problems.append("falta preview.png na raiz; a Steam exige um PNG 256x256")
        return

    size = os.path.getsize(path)
    if size > PREVIEW_MAX_BYTES:
        problems.append("preview.png tem %d bytes; o maximo e %d"
                        % (size, PREVIEW_MAX_BYTES))
    try:
        from PIL import Image
    except ImportError:
        print("  preview.png: %d bytes (sem PIL, dimensoes nao conferidas)" % size)
        return
    dimensions = Image.open(path).size
    if dimensions != PREVIEW_SIZE:
        problems.append("preview.png e %dx%d; o jogo exige %dx%d"
                        % (dimensions + PREVIEW_SIZE))
    else:
        print("  preview.png: %dx%d, %d bytes" % (dimensions + (size,)))


def check_contents(root, problems):
    contents = os.path.join(root, "Contents")
    if not os.path.isdir(contents):
        problems.append("falta a pasta Contents/")
        return

    entries = os.listdir(contents)
    if not entries:
        problems.append("Contents/ esta vazia")
    for name in entries:
        if os.path.isfile(os.path.join(contents, name)):
            problems.append("Contents/%s e arquivo; so pastas sao permitidas" % name)
        elif name not in ALLOWED_IN_CONTENTS:
            problems.append("Contents/%s nao e permitida; so %s"
                            % (name, " e ".join(sorted(ALLOWED_IN_CONTENTS))))

    mods = os.path.join(contents, "mods")
    if not os.path.isdir(mods):
        return
    if not os.listdir(mods):
        problems.append("Contents/mods/ esta vazia")
    for name in os.listdir(mods):
        if os.path.isfile(os.path.join(mods, name)):
            problems.append("Contents/mods/%s e arquivo; so pastas de mod" % name)


def check_mod_info(root, problems):
    found = []
    for dirpath, _dirs, files in os.walk(os.path.join(root, "Contents")):
        if "mod.info" in files:
            found.append(os.path.join(dirpath, "mod.info"))
    if not found:
        problems.append("nenhum mod.info em Contents/")
        return

    for path in found:
        raw = open(path, "rb").read()
        # BOM faria a primeira chave virar "﻿name" e o jogo nao acharia o nome.
        if raw.startswith(b"\xef\xbb\xbf"):
            problems.append("%s comeca com BOM" % os.path.relpath(path, root))
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            problems.append("%s nao e UTF-8" % os.path.relpath(path, root))
            continue
        # O .strip() do valor NAO e enfeite. Estes arquivos estao em CRLF, e o `$`
        # do re.MULTILINE casa antes do line feed, deixando o carriage return DENTRO
        # do grupo capturado. Sem o strip o nome do poster ganha um byte invisivel no
        # fim e o teste de existencia falha num arquivo que esta ali. Foi exatamente o
        # primeiro resultado deste verificador: ele acusou o repo, e o errado era ele.
        keys = dict((k, v.strip()) for k, v in
                    re.findall(r"^(\w+)=(.*)$", text, re.M))
        for required in ("name", "id", "poster", "pzversion", "modversion"):
            if required not in keys:
                problems.append("%s sem %s" % (os.path.relpath(path, root), required))
        poster = keys.get("poster")
        if poster and not os.path.isfile(os.path.join(os.path.dirname(path), poster)):
            problems.append("%s declara poster=%s e o arquivo nao existe"
                            % (os.path.relpath(path, root), poster))
        print("  %s: %s %s" % (os.path.relpath(path, root),
                               keys.get("id"), keys.get("modversion")))


def main(root):
    problems = []
    check_workshop_txt(root, problems)
    check_preview(root, problems)
    check_contents(root, problems)
    check_mod_info(root, problems)

    for problem in problems:
        print("PROBLEMA: %s" % problem)
    print("%d problemas" % len(problems))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
