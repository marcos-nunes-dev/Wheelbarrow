"""Gera as texturas do teste controlado do passe de modelo do personagem.

A PERGUNTA: por que uma textura faz o PERSONAGEM e os VEICULOS sumirem da tela?

Tres ocorrencias no projeto, todas com o modelo de mao usando textura com canal
alpha, nenhuma sem. Mas "com alpha" mudou tres coisas ao mesmo tempo -- o canal,
a transparencia de verdade, e o tamanho, que passou de 512x512 para 1024x512.
Culpar o alpha com esses dados e adivinhar com cara de conclusao.

O DESENHO. Quatro texturas, uma variavel de cada vez, e a MESMA malha nas quatro
-- os quatro modelos apontam para Wheelbarrow_Hand.fbx. Assim a unica diferenca
entre os casos e o arquivo de textura.

    A   512x512   RGBA   alpha todo 255      o canal existe, mas nada e translucido
    B   512x512   RGBA   com area translucida  transparencia de verdade
    C  1024x512   RGB    sem canal alpha     so o tamanho muda
    D  1024x512   RGBA   com area translucida  a combinacao conhecida-ruim

O que cada resultado significa:

    so D quebra          e a COMBINACAO; alpha em 512 e seguro, e a sombra na
                         mao volta a ser possivel com uma textura 512
    B e D quebram        e a transparencia real, independente do tamanho
    A, B e D quebram     e a presenca do canal; nem RGBA opaco serve
    C e D quebram        e o TAMANHO, e o alpha e inocente -- a sombra volta
                         cabendo dentro de 512x512
    nenhuma quebra       a causa esta na geometria do quad, nao na textura, e o
                         proximo teste e outro

O controle negativo ja existe e e o item real: 512x512 RGB, que o Marcos
confirmou funcionando.

Uso:
    python tools_gen_texture_test.py
"""
import math
import os

from PIL import Image

SOURCE = "source/Wheelbarrow_raw.png"
OUT = "../Contents/mods/MNWheelbarrow/common/media/textures/WorldItems"

# Alpha da area translucida. Baixo o bastante para ser inegavelmente translucido.
HOLE_ALPHA = 90


def widen(image):
    """Dobra a largura repetindo o conteudo, sem mexer nos UVs.

    Repetir em vez de deixar metade vazia e proposital: os UVs dos modelos de
    teste NAO sao comprimidos, entao eles varrem a largura inteira. Com metade
    vazia o carrinho apareceria pela metade e o teste ficaria dificil de ler --
    e a pergunta aqui e se RENDERIZA, nao se fica bonito.
    """
    w, h = image.size
    out = Image.new(image.mode, (w * 2, h))
    out.paste(image, (0, 0))
    out.paste(image, (w, 0))
    return out


def punch_hole(image):
    """Abre uma area translucida no centro, com borda suave."""
    out = image.copy()
    px = out.load()
    w, h = out.size
    cx, cy = w * 0.5, h * 0.5
    radius = min(w, h) * 0.25
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - cx, y - cy) / radius
            if d >= 1.0:
                continue
            fade = 1.0 - d
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, int(a - (a - HOLE_ALPHA) * fade))
    return out


def main():
    original = Image.open(SOURCE).convert("RGB")

    variants = {
        # A: o canal existe e esta todo opaco.
        "MNWB_TexA": original.convert("RGBA"),
        # B: mesmo tamanho, transparencia de verdade.
        "MNWB_TexB": punch_hole(original.convert("RGBA")),
        # C: so o tamanho muda; sem canal alpha nenhum.
        "MNWB_TexC": widen(original),
        # D: a combinacao que quebrou em jogo.
        "MNWB_TexD": punch_hole(widen(original.convert("RGBA"))),
    }

    for name, image in variants.items():
        path = os.path.join(OUT, name + ".png")
        image.save(path)
        print("%-12s %-9s %s -> %s"
              % (name, "x".join(str(v) for v in image.size), image.mode, path))


if __name__ == "__main__":
    main()
