"""Resolve a transformacao do osso da mao MEDINDO um caso que funciona.

Tres rodadas de calibracao visual foram gastas adivinhando em que espaco vive o
modelo de mao de um item: se +Z sobe ou desce, qual eixo e frente/tras, qual
inclinacao deixa o objeto deitado. Cada rodada custa um restart do jogo e uma
bateria de screenshots, e entrega um bit de informacao.

Existe uma medicao no disco que dispensa isso. O mod Carry Visible Items
transforma itens do jogo base em itens visiveis na mao, e para varios deles ele
ship DUAS versoes do MESMO objeto:

    media/models_X/WorldItems/CarDoor.FBX        <- malha do jogo base
    .../CarriableItems/.../WorldItems/CarDoor_Hand.fbx  <- a mesma, posta na mao

A diferenca entre as duas E a transformacao do osso da mao, ja resolvida por
alguem que acertou. Se os vertices mantiveram a ordem, ela sai exata: e o
problema de Umeyama (Kabsch com escala), que da a rotacao, a escala e a
translacao que levam uma nuvem de pontos na outra, junto com o residuo -- e o
residuo e o que prova que a resposta esta certa, em vez de plausivel.

Uso:
    python tools_fbx_solve_hand.py vanilla.fbx mao_do_mod.fbx
"""
import math
import struct
import sys
import zlib

from tools_fbx_strip_embedded import parse


def read_vertices(path):
    """Devolve a primeira lista de Vertices do arquivo, como triplas."""
    data = open(path, 'rb').read()
    _, roots, _ = parse(data)
    found = []

    def walk(node):
        if found:
            return
        if node.name == b'Vertices':
            for ptype, blob in node.props:
                if ptype not in 'df':
                    continue
                alen, enc, clen = struct.unpack_from("<III", blob, 0)
                raw = blob[12:12 + clen]
                if enc == 1:
                    raw = zlib.decompress(raw)
                vals = struct.unpack("<%d%s" % (alen, ptype), raw)
                found.extend(
                    (vals[i], vals[i + 1], vals[i + 2])
                    for i in range(0, len(vals) - 2, 3)
                )
                return
        for child in node.children:
            walk(child)

    for root in roots:
        walk(root)
    return found


def centroid(pts):
    n = float(len(pts))
    return [sum(p[i] for p in pts) / n for i in range(3)]


def umeyama(src, dst):
    """Resolve dst ~= s * R * src + t. Devolve (s, R, t, residuo_rms).

    Implementado a mao porque numpy nao e dependencia deste repo e a matriz e
    3x3: a SVD sai da iteracao de Jacobi sobre H^T H, que converge em poucas
    voltas nesse tamanho.
    """
    cs, cd = centroid(src), centroid(dst)
    a = [[p[i] - cs[i] for i in range(3)] for p in src]
    b = [[p[i] - cd[i] for i in range(3)] for p in dst]

    # H = A^T B, a matriz de covariancia cruzada.
    h = [[sum(a[k][i] * b[k][j] for k in range(len(a))) for j in range(3)]
         for i in range(3)]

    # R otima = V U^T de H = U S V^T. Obtida por iteracao ortogonal: repetir
    # R <- polar(H) converge para a parte rotacional de H.
    r = [row[:] for row in h]
    for _ in range(200):
        inv = invert3(transpose(r))
        if inv is None:
            break
        r = [[0.5 * (r[i][j] + inv[i][j]) for j in range(3)] for i in range(3)]
    r = transpose(r)

    # Escala: razao entre a variancia projetada e a variancia da origem.
    var_src = sum(sum(v * v for v in p) for p in a)
    num = sum(sum(b[k][i] * sum(r[i][j] * a[k][j] for j in range(3))
                  for i in range(3)) for k in range(len(a)))
    s = num / var_src if var_src else 1.0

    t = [cd[i] - s * sum(r[i][j] * cs[j] for j in range(3)) for i in range(3)]

    err = 0.0
    for k in range(len(a)):
        for i in range(3):
            pred = s * sum(r[i][j] * src[k][j] for j in range(3)) + t[i]
            err += (pred - dst[k][i]) ** 2
    return s, r, t, math.sqrt(err / len(a))


def transpose(m):
    return [[m[j][i] for j in range(3)] for i in range(3)]


def invert3(m):
    det = (m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
           - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
           + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]))
    if abs(det) < 1e-14:
        return None
    c = [[0.0] * 3 for _ in range(3)]
    for i in range(3):
        for j in range(3):
            a = [[m[r][col] for col in range(3) if col != j]
                 for r in range(3) if r != i]
            minor = a[0][0] * a[1][1] - a[0][1] * a[1][0]
            c[j][i] = ((-1) ** (i + j)) * minor / det
    return c


def to_euler_xyz(r):
    """Angulos que tools_fbx_shift.py aplica, na ordem em que ele aplica (X,Y,Z).

    Precisa casar com a convencao daquele arquivo, senao o numero medido aqui
    nao e utilizavel la.
    """
    sy = -r[2][0]
    sy = max(-1.0, min(1.0, sy))
    ry = math.asin(sy)
    if abs(sy) < 0.99999:
        rx = math.atan2(r[2][1], r[2][2])
        rz = math.atan2(r[1][0], r[0][0])
    else:
        rx = math.atan2(-r[1][2], r[1][1])
        rz = 0.0
    return [math.degrees(v) for v in (rx, ry, rz)]


def bbox(pts):
    return [(min(p[i] for p in pts), max(p[i] for p in pts)) for i in range(3)]


if __name__ == "__main__":
    src = read_vertices(sys.argv[1])
    dst = read_vertices(sys.argv[2])
    print("vertices: vanilla=%d  mao=%d" % (len(src), len(dst)))
    if len(src) != len(dst):
        print("ORDEM DIFERENTE -- Umeyama nao se aplica; compare so a bbox.")
    else:
        s, r, t, res = umeyama(src, dst)
        span = max(hi - lo for lo, hi in bbox(src))
        print("escala    %.6f" % s)
        print("rotacao   X=%.2f  Y=%.2f  Z=%.2f  (ordem de tools_fbx_shift)"
              % tuple(to_euler_xyz(r)))
        print("translacao %.4f %.4f %.4f" % tuple(t))
        print("residuo RMS %.6g  (%.4f%% da maior dimensao)"
              % (res, 100.0 * res / span if span else 0.0))
    for name, pts in (("vanilla", src), ("mao", dst)):
        print("bbox %-8s " % name + "  ".join(
            "%s[%8.3f,%8.3f]" % (ax, lo, hi)
            for ax, (lo, hi) in zip("XYZ", bbox(pts))))
