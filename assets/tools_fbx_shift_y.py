"""Compatibilidade: use tools_fbx_shift.py, que desloca nos tres eixos."""
import sys
from tools_fbx_shift import shift

if __name__ == "__main__":
    n = shift(sys.argv[1], sys.argv[2], 0.0, float(sys.argv[3]), 0.0)
    print("%d vertices deslocados em Y por %s" % (n, sys.argv[3]))
