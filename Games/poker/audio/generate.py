"""Original offline paper/chip cues; deterministic, no downloaded recordings."""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 44100


def generate(kind, duration):
    rng = random.Random(47019)
    low = 0.0
    values = []
    for index in range(int(duration * RATE)):
        t = index / RATE
        low = low * .88 + rng.uniform(-1, 1) * .12
        if kind == 'deal':
            local = t % .12
            value = (rng.uniform(-1, 1) - low) * math.exp(-local * 65) * .2
        elif kind == 'chips':
            value = sum(math.sin(t * math.tau * f) * math.exp(-t * d) for f, d in [(1750, 45), (2840, 57), (3920, 72)]) * .09
            value += (rng.uniform(-1, 1) - low) * math.exp(-t * 80) * .11
        elif kind == 'reveal':
            value = low * math.sin(math.pi * min(1, t / duration)) * .5
        else:
            value = sum(math.sin(t * math.tau * f) * math.exp(-max(0, t - delay) * 9) * (t >= delay) for f, delay in [(523.25, 0), (659.25, .10), (783.99, .20), (1046.5, .32)]) * .08
        values.append(struct.pack('<h', round(max(-1, min(1, value)) * 32767)))
    return b''.join(values)


if __name__ == '__main__':
    for kind, duration in [('deal', .45), ('chips', .18), ('reveal', .22), ('win', .85)]:
        with wave.open(str(Path(__file__).with_name(kind + '.wav')), 'wb') as output:
            output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
            output.writeframes(generate(kind, duration))
