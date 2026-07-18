import matplotlib.pyplot as plt
from noise import pnoise2, snoise2
from functools import cmp_to_key
import numpy as np
import pprint

# screen dimension
WRITTER_WIDTH_IN_PIXELS = 96*2
WRITTER_HEIGHT_IN_PIXELS = 10*8

# blob to show dimension
# a square of the size of a mode 1 pixel
ATOMIC_UNIT_WIDTH_IN_PIXELS = 4
ATOMIC_UNIT_WIDTH_IN_BYTES = ATOMIC_UNIT_WIDTH_IN_PIXELS//2
ATOMIC_UNIT_HEIGHT_IN_PIXELS = 8


BUFFER_WIDTH_IN_BLOCS = WRITTER_WIDTH_IN_PIXELS // ATOMIC_UNIT_WIDTH_IN_PIXELS
BUFFER_HEIGHT_IN_BLOCS = WRITTER_HEIGHT_IN_PIXELS // ATOMIC_UNIT_HEIGHT_IN_PIXELS


def perlin(j, size, dens=128, octaves=1,):
    """
    Generate a 2D Perlin noise array.

    Parameters:
    - size: Tuple of (width, height) for the output array.
    - dens: Density of the noise (higher values produce more detail).
    - octaves: Number of octaves for the noise (higher values produce more complexity).

    Returns:
    - A 2D numpy array containing Perlin noise values.
    """
    import numpy as np
    from noise import pnoise2

    width, height = size
    noise_array = np.zeros((height, width))

    for y in range(height):
        for x in range(width):
            noise_array[y][x] = pnoise2(x / dens, y / dens, octaves=octaves,base=j)

    return noise_array

def build_table(buffer):
    """
    Build a table of pair (x,y) that represents the corrdinatees in the buffer
    from the smallest to largest value.
    A simple argsort is not enough here beacause it does not take into account positions proximities.
    We want close points ofthe same value sorted closely too and far point of the same value sorted far away.
    """

    ordered = []
    for y in range(buffer.shape[0]):
        for x in range(buffer.shape[1]):
            ordered.append((buffer[y][x], (x, y)))

    ordered = sorted(
        ordered, 
        key=cmp_to_key(lambda a, b: (a[0] - b[0]) if a[0] != b[0] else ((a[1][0] - b[1][0])**2 + (a[1][1] - b[1][1])**2))
    )
    return ordered


print(f"WRITTER_TRANSITION_ATOMIC_UNIT_WIDTH_IN_PIXELS equ {ATOMIC_UNIT_WIDTH_IN_PIXELS}")
print(f"WRITTER_TRANSITION_ATOMIC_UNIT_HEIGHT_IN_PIXELS equ {ATOMIC_UNIT_HEIGHT_IN_PIXELS}")

for j in range(4):
    p = perlin(j, (BUFFER_WIDTH_IN_BLOCS, BUFFER_HEIGHT_IN_BLOCS), dens=12, octaves=3)
    o = build_table(p)

    assert len(o) == len(p.flatten())
    assert len(o) == BUFFER_WIDTH_IN_BLOCS * BUFFER_HEIGHT_IN_BLOCS

    r = np.zeros((BUFFER_HEIGHT_IN_BLOCS, BUFFER_WIDTH_IN_BLOCS))
    for i, (value, (x, y)) in enumerate(o):
        r[y][x] = i

    plt.imshow(p, cmap="Blues")
    plt.title("Perlin Noise")
    plt.figure()

    plt.imshow(r, cmap="Reds")
    plt.title("Print order")
    plt.figure()

    print(f"WRITTER_TRANSITION_TABLE{j} equ [" + ", ".join(f"[{x*ATOMIC_UNIT_WIDTH_IN_BYTES},{y*ATOMIC_UNIT_HEIGHT_IN_PIXELS}]" for value, (x, y) in o) + "]")
print(f"WRITTER_TRANSITION_NB_STEPS equ {len(o)}")

plt.show()