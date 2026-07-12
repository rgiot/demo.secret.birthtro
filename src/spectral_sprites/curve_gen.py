import numpy as np
import matplotlib.pyplot as plt


duration = 256
amplitude = (21*8-6*16) / 2

X = np.arange(0, duration, dtype=np.int16)
Y = amplitude * np.sin(2 * np.pi * X / duration) + amplitude
#Y = np.abs(2*amplitude * np.sin(2 * np.pi * X / duration))
Y = Y.astype(np.int16)


def follow_curve(Y):
    """Follow the curve with -1/0/+1 steps while tracking the position really
    reached: the quantization/clamping error is compensated on the next steps
    instead of accumulating, so the deltas sum to 0 by construction (the
    tracked position comes back to its start after one period).
    The wrap-around step (from Y[-1] back to Y[0]) is included: the table has
    exactly len(Y) entries.
    """
    cur = int(Y[0])
    # a steep curve may need a few laps before the tracking reaches its
    # periodic steady state; keep the first lap that closes on itself
    for _ in range(16):
        start = cur
        D = np.zeros(len(Y), dtype=np.int16)
        for i in range(len(Y)):
            target = int(Y[(i + 1) % len(Y)])
            D[i] = min(1, max(-1, target - cur))
            cur += D[i]
        if cur == start:
            return D
    raise ValueError("The curve cannot be followed with -1/0/+1 steps")


D = follow_curve(Y)

print("; 0 => decrease\n; 2=> nothing\n 4=> increase\ndelta_x_curve\n")
print("\tdb " + ", ".join([str((d+1)*2) for d in D]))

print(np.sum(D))
assert np.sum(D) == 0, "The curve should be balanced, otherwhise the logo will drift"

reached = Y[0] + np.concatenate(([0], np.cumsum(D[:-1])))
plt.plot(X, Y, label="ideal curve")
plt.plot(X, reached, label="curve followed with -1/0/+1 steps")
plt.legend()
plt.show()
