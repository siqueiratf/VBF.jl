#!/usr/bin/env python3
"""Cross-language reader for the .anf quadratic-APN catalog format.

A quadratic vectorial function over F_2^8 is stored as 37 ANF coefficient bytes
(1 constant + 8 linear + 28 quadratic monomials); the Mobius transform below
reconstructs the 256-byte look-up table losslessly.

    from load_anf import iter_luts
    for lut in iter_luts("catalogs/apn8_blp2025.anf"):
        ...  # lut is a list of 256 ints
"""
import struct

MAGIC = b"QAPN8\0"
# 37 monomial masks: const, 8 singletons, 28 pairs  (must match anf.jl)
MASKS = [0] + [1 << i for i in range(8)] + \
        [(1 << i) | (1 << j) for i in range(8) for j in range(i + 1, 8)]


def unpack(coeff):
    """37 ANF coeff bytes -> 256-entry LUT."""
    lut = [0] * 256
    for x in range(256):
        acc = 0
        for k, m in enumerate(MASKS):
            if (x & m) == m:
                acc ^= coeff[k]
        lut[x] = acc
    return lut


def iter_luts(path):
    with open(path, "rb") as f:
        if f.read(len(MAGIC)) != MAGIC:
            raise ValueError("bad .anf magic")
        f.read(1)                         # version
        nb = f.read(1)[0]                 # bytes/function
        (count,) = struct.unpack("<I", f.read(4))
        for _ in range(count):
            yield unpack(f.read(nb))


if __name__ == "__main__":
    import sys
    n = sum(1 for _ in iter_luts(sys.argv[1]))
    print(f"{sys.argv[1]}: {n} functions")
