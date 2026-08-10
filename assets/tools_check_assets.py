"""Confere que todo `mesh =` e `texture =` dos scripts existe em disco.

POR QUE EXISTE: referencia quebrada nao aparece como erro. O modelo simplesmente
nao renderiza, ou renderiza sem textura, e o console fica em silencio -- este
projeto ja perdeu uma rodada de teste com o modelo de mao apontando para um .png
que eu tinha acabado de renomear.

Uso:
    python tools_check_assets.py [raiz]
"""
import os
import re
import sys

MEDIA = "Contents/mods/MNWheelbarrow/common/media"
SCRIPTS = "Contents/mods/MNWheelbarrow/42/media/scripts"

# Extensoes aceitas por tipo de referencia. O PZ resolve o caminho sem extensao,
# entao qualquer uma delas serve.
KINDS = (
    ("texture", "textures", (".png",)),
    ("mesh", "models_X", (".fbx", ".FBX", ".x", ".X")),
)


def main(root):
    media = os.path.join(root, MEDIA)
    scripts = os.path.join(root, SCRIPTS)

    problems, checked = 0, 0
    for name in sorted(os.listdir(scripts)):
        if not name.endswith(".txt"):
            continue
        source = open(os.path.join(scripts, name), encoding="utf-8").read()
        # Comentarios fora: eles citam nomes de arquivo como exemplo.
        source = re.sub(r"/\*.*?\*/", " ", source, flags=re.S)

        for kind, folder, exts in KINDS:
            for ref in re.findall(kind + r"\s*=\s*([\w/]+)\s*,", source):
                checked += 1
                if not any(os.path.exists(os.path.join(media, folder, ref + e))
                           for e in exts):
                    problems += 1
                    print("%s: %s = %s nao existe em %s/"
                          % (name, kind, ref, folder))

    print("%d referencias conferidas, %d quebradas" % (checked, problems))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
