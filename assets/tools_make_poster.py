"""Gera preview.png e poster.png a partir de um quadro da gravacao em jogo.

POR QUE UM QUADRO DE JOGO E NAO UM RENDER: o icone do item ja e renderizado do FBX
(tools_render_icon.py), e para um icone isso e o certo -- fundo limpo, nenhuma
distracao. Para a pagina da Workshop e o contrario: o jogador quer ver a coisa
FUNCIONANDO, com personagem, chao e escala reais. Um render do modelo sozinho nao
responde "como isso fica no meu jogo".

POR QUE A GRAVACAO VIVE EM assets/source: sem ela nao ha como regerar as imagens, e
o uploader da Workshop sobrescreve coisas. Mesma razao pela qual o FBX de origem esta
versionado -- o repo tem de conseguir reconstruir tudo o que publica.

O QUADRO E O ENQUADRAMENTO foram escolhidos olhando: quadro 12 e o de passada mais
aberta, que le como "andando" numa imagem estatica, e o recorte e o unico dos tres
testados que nao corta a roda.

Uso:
    python tools_make_poster.py
"""
import io
import os

from PIL import Image

#: Gravacao em jogo, na propria arvore do repo.
SOURCE = os.path.join("source", "andando.gif")

#: Quadro escolhido: passada aberta, cacamba visivel, roda inteira.
FRAME = 12

#: Recorte quadrado no espaco do GIF (426x240). Centrado no conjunto
#: personagem + carrinho, com folga para a roda nao encostar na borda.
CROP = (146, 46, 302, 202)

#: 256x256 e o que o jogo impoe para o preview da Workshop, e e tambem o tamanho
#: mais comum de poster nos mods instalados -- 13 dos 23 conferidos.
SIZE = (256, 256)

TARGETS = (
    # preview da pagina da Workshop, ao lado de workshop.txt
    os.path.join("..", "preview.png"),
    # poster da lista de mods, ao lado de mod.info
    os.path.join("..", "Contents", "mods", "MNWheelbarrow", "42", "poster.png"),
)


def main():
    source = Image.open(SOURCE)
    source.seek(FRAME)
    image = source.convert("RGB").crop(CROP).resize(SIZE, Image.LANCZOS)

    for target in TARGETS:
        image.save(target)
        print("%s %dx%d" % (target, image.size[0], image.size[1]))


if __name__ == "__main__":
    main()
