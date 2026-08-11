"""Gera preview.png e poster.png a partir da capa.

DUAS RESOLUCOES, E NAO E ESCOLHA:

  preview.png  256x256 EXATO. O jogo recusa qualquer outra dimensao -- ver
               UI_WorkshopError_PreviewDimensions, "must be exactly 256x256 pixels".
               Tambem tem de ficar abaixo de 1000KB.

  poster.png   sem regra de dimensao. Ele aparece na lista de mods do jogo, e os mods
               instalados usam de 256x256 a 1129x1129. Em 512 o texto da capa
               sobrevive; em 256 o subtitulo comeca a virar borrao.

A CAPA E ARTE, e nao um render nem um quadro de jogo. Antes daqui o preview era um
quadro da gravacao, que mostrava o mod funcionando mas nao dizia o nome dele. Uma capa
com o nome nos dois idiomas resolve as duas coisas na miniatura da Workshop, que e onde
a decisao de clicar acontece.

LANCZOS e nao NEAREST: a reducao e grande (1254 -> 256) e o texto e o que mais sofre.
NEAREST preservaria a aparencia de pixel art e destruiria as letras.

Uso:
    python tools_make_poster.py
"""
import os

from PIL import Image

SOURCE = os.path.join("source", "capa.png")

TARGETS = (
    # preview da pagina da Workshop, ao lado de workshop.txt
    (os.path.join("..", "preview.png"), 256),
    # poster da lista de mods, ao lado de mod.info
    (os.path.join("..", "Contents", "mods", "MNWheelbarrow", "42", "poster.png"), 512),
)

#: Limite da Steam para o preview.
MAX_BYTES = 1000 * 1024


def main():
    source = Image.open(SOURCE).convert("RGB")
    if source.size[0] != source.size[1]:
        raise SystemExit("a capa precisa ser quadrada; esta %dx%d" % source.size)

    for target, size in TARGETS:
        source.resize((size, size), Image.LANCZOS).save(target)
        written = os.path.getsize(target)
        if written > MAX_BYTES:
            raise SystemExit("%s ficou com %d bytes, acima do limite de %d"
                             % (target, written, MAX_BYTES))
        print("%s %dx%d  %d bytes" % (target, size, size, written))


if __name__ == "__main__":
    main()
