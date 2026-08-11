"""Redimensiona as gravacoes para a largura util da descricao da Workshop.

POR QUE 630: a Steam renderiza [img]url[/img] como um <img src> puro, sem width, sem
height e sem style -- conferido no HTML da propria pagina do mod. Ela descarta
qualquer parametro de largura no BBCode. A unica coisa que decide o tamanho em tela e
o tamanho real do arquivo, limitado por uma regra da folha de estilo dela:

    .workshopItemDescription img { max-width: 630px; }

Entao imagem mais estreita que 630 aparece pequena com espaco sobrando, e mais larga e
reduzida pelo navegador a toa. 630 exato preenche a coluna sem desperdicio.

LANCZOS e nao NEAREST: a origem e captura de jogo, nao pixel art, e a escala e 1.48x --
nao inteira. NEAREST numa escala quebrada dobra alguns pixels e outros nao, o que
aparece como irregularidade nas bordas. Aqui interpolar e o certo.

PALETA GLOBAL, tirada de TODOS os quadros. Deixar o Pillow escolher uma paleta por
quadro custa 0.6 MB por arquivo: cada quadro carrega a propria tabela de cores e a
compressao entre quadros piora.

A paleta sai dos quadros empilhados num unico bitmap, e nao do primeiro quadro sozinho.
Sao duas medicoes: com a paleta do primeiro quadro o arquivo fica 1.90 MB, com a de
todos fica 1.84 MB, e a diferenca de cor para o original e a mesma nos dois -- 1.4 em
255 por canal. Usar todos os quadros e mais barato E cobre a cena inteira caso um
quadro futuro traga cor nova.

A comparacao visual me enganou aqui: a saida PARECE mais escura ao lado do original, e
nao e. O que muda e a textura do dithering. Medir resolveu o que olhar nao resolvia.

128 cores. Menos que isso economiza pouco e comeca a aparecer no gradiente do asfalto.

Uso:
    python tools_make_gifs.py
"""
import os

from PIL import Image, ImageSequence

#: Largura util da descricao, da folha de estilo da Steam.
WIDTH = 630

#: GIF ampliado engorda depressa e a pagina carrega dois deles.
COLORS = 128

SOURCES = ("andando", "deixarcair")


def resize(name):
    source = os.path.join("source", name + ".gif")
    target = os.path.join("source", "%s_%d.gif" % (name, WIDTH))

    original = Image.open(source)
    width, height = original.size
    size = (WIDTH, int(round(height * WIDTH / float(width))))

    rgb = [frame.convert("RGB").resize(size, Image.LANCZOS)
           for frame in ImageSequence.Iterator(original)]
    stacked = Image.new("RGB", (size[0], size[1] * len(rgb)))
    for index, frame in enumerate(rgb):
        stacked.paste(frame, (0, index * size[1]))
    palette = stacked.quantize(colors=COLORS, method=Image.MEDIANCUT)
    frames = [f.quantize(palette=palette, dither=Image.FLOYDSTEINBERG)
              for f in rgb]
    frames[0].save(target, save_all=True, append_images=frames[1:],
                   duration=original.info.get("duration", 70), loop=0,
                   optimize=True)
    return target, size, os.path.getsize(target)


def main():
    for name in SOURCES:
        target, size, written = resize(name)
        print("%-34s %dx%d  %.2f MB" % (target, size[0], size[1],
                                        written / 1048576.0))


if __name__ == "__main__":
    main()
