"""Marca propriedades de container nos primeiros N tiles de um arquivo .tiles.

Existe para nao obrigar uma volta ao TileZed toda vez que o numero de sprites
muda. Quando o carrinho passou de 4 para 8 faces, os quatro sprites novos
ficariam sem ContainerType e ContainerCapacity, e um carrinho colocado com eles
nasceria sem container nenhum.

FORMATO (decodificado do arquivo gerado pelo TileZed):

    "tdef"
    u32  versao            = 1
    u32  numero de tilesets
    por tileset:
        string  nome do tileset      terminada em \\n
        string  nome do arquivo png  terminada em \\n
        u32  colunas
        u32  linhas
        u32  desconhecido            = 1
        u32  total de tiles          = colunas * linhas
        por tile:
            u32  numero de propriedades
            por propriedade:
                string  nome   terminada em \\n
                string  valor  terminada em \\n

Tiles sem propriedade aparecem com contagem zero, entao o arquivo sempre lista
todos os tiles da folha.
"""
import struct
import sys

PROPS = [
    ("ContainerCapacity", "100"),
    ("CustomName", "Wheelbarrow"),
    # Minusculo de proposito: o jogo monta a chave de traducao do titulo como
    # IGUI_ContainerTitle_<valor>, e todos os valores do jogo base sao minusculos.
    ("container", "wheelbarrow"),
]


def _read_string(data, pos):
    end = data.index(b"\n", pos)
    return data[pos:end].decode("utf-8"), end + 1


def set_props(src, dst, count):
    data = open(src, "rb").read()
    assert data[:4] == b"tdef", "nao e um arquivo .tiles"

    out = bytearray(data[:8])
    pos = 8
    num_tilesets = struct.unpack_from("<I", data, pos)[0]
    out += data[pos:pos + 4]
    pos += 4

    for _ in range(num_tilesets):
        name, pos = _read_string(data, pos)
        filename, pos = _read_string(data, pos)
        out += name.encode() + b"\n" + filename.encode() + b"\n"

        cols, rows, unknown, total = struct.unpack_from("<4I", data, pos)
        out += data[pos:pos + 16]
        pos += 16
        print(f"tileset '{name}': {cols}x{rows}, {total} tiles")

        for tile in range(total):
            nprops = struct.unpack_from("<I", data, pos)[0]
            pos += 4
            existing = []
            for _ in range(nprops):
                key, pos = _read_string(data, pos)
                value, pos = _read_string(data, pos)
                existing.append((key, value))

            if tile < count:
                write = PROPS
            else:
                write = existing

            out += struct.pack("<I", len(write))
            for key, value in write:
                out += key.encode() + b"\n" + value.encode() + b"\n"

    open(dst, "wb").write(bytes(out))
    return len(data), len(out)


if __name__ == "__main__":
    src, dst, count = sys.argv[1], sys.argv[2], int(sys.argv[3])
    before, after = set_props(src, dst, count)
    print(f"{before} -> {after} bytes, propriedades aplicadas aos {count} primeiros tiles")
