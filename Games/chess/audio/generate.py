"""Create offline, deterministic wood/felt Foley cues. Run from any directory."""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 44100
ROOT = Path(__file__).resolve().parent
rng = random.Random(1047)


def wood(duration=0.18, weight=1.0):
    # An impact excites short, inharmonic wooden-body resonances, not notes.
    modes = [(287 * weight, .34, 41), (731 * weight, .19, 64),
             (1319 * weight, .11, 92), (2393 * weight, .07, 135)]
    phases = [rng.uniform(-.35, .35) for _ in modes]
    samples, filtered = [], 0.0
    for frame in range(int(RATE * duration)):
        t = frame / RATE
        noise = rng.uniform(-1, 1)
        filtered += .34 * (noise - filtered)
        attack = min(1.0, t / .0008)
        value = filtered * .52 * math.exp(-t * 190)
        for (frequency, amplitude, decay), phase in zip(modes, phases):
            value += amplitude * math.sin(math.tau * frequency * t + phase) * math.exp(-decay * t)
        samples.append(value * attack)
    return samples


def scrape(duration, strength=.16):
    samples, low, slower = [], 0.0, 0.0
    for frame in range(int(RATE * duration)):
        t = frame / RATE
        low += .12 * (rng.uniform(-1, 1) - low)
        slower += .016 * (low - slower)
        envelope = math.sin(math.pi * t / duration) ** 2
        roughness = .55 + .45 * math.sin(math.tau * 37.7 * t) ** 2
        samples.append((low - slower) * envelope * roughness * strength)
    return samples


def clap(duration=.13):
    samples, low = [], 0.0
    for frame in range(int(RATE * duration)):
        t = frame / RATE
        noise = rng.uniform(-1, 1)
        low += .22 * (noise - low)
        samples.append((noise * .20 + low * .8) * min(1.0, t / .0007) * math.exp(-t * 54))
    return samples


def cue(name, length, layers, volume=.6):
    signal = [0.0] * int(RATE * length)
    for offset, sample, level in layers:
        start = int(offset * RATE)
        for frame, value in enumerate(sample[:len(signal) - start]):
            signal[start + frame] += value * level
    # Quiet, diffuse room reflections; no rhythmic echo or pitched fanfare.
    dry = signal[:]
    for delay, gain in [(.017, .075), (.029, .05), (.047, .035), (.073, .018)]:
        shift = int(delay * RATE)
        for frame in range(shift, len(signal)):
            signal[frame] += dry[frame - shift] * gain
    peak = max(abs(value) for value in signal) or 1.0
    gain = min(volume, .78 / peak)
    # Remove DC and taper tails to avoid clicks.
    average = sum(signal) / len(signal)
    output = bytearray()
    for frame, value in enumerate(signal):
        fade = min(1.0, (len(signal) - frame - 1) / (RATE * .015))
        output += struct.pack('<h', round((value - average) * gain * fade * 32767))
    with wave.open(str(ROOT / f'{name}.wav'), 'wb') as sound:
        sound.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        sound.writeframes(output)


cue('move', .23, [(0, scrape(.065), 1), (.045, wood(weight=1.1), .7)])
cue('capture', .32, [(0, scrape(.085), 1.1), (.047, wood(weight=.86), .9), (.108, wood(weight=1.3), .45)])
cue('crown', .43, [(0, wood(weight=1.23), .55), (.095, wood(weight=1.07), .7), (.168, scrape(.18), .65)])
cue('win', .82, [(0, wood(weight=.9), .6), (.14, clap(), .7), (.26, clap(), .85), (.40, clap(), .75), (.53, clap(), .55)])
cue('tie', .40, [(0, scrape(.22), 1.2), (.13, wood(weight=.82), .48)], volume=.5)
print('Generated five natural wood/felt cues at 44.1 kHz.')
