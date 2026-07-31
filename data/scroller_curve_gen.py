import numpy as np
import matplotlib.pyplot as plt


duration = 256
amplitude = 30

X = np.arange(0, duration, dtype=np.int16)
Y = amplitude * np.sin(2 * np.pi * X / duration) + amplitude + 1 # NEVER 0
#Y = np.abs(2*amplitude * np.sin(2 * np.pi * X / duration))
Y = Y.astype(np.int16)


print(" SCROLLER_SINE equ [" + ", ".join([str(y) for y in Y]) + "]")

plt.plot(X, Y)
plt.legend()
plt.show()
