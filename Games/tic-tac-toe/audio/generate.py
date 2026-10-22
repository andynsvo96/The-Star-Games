"""Rebuild the original garden-themed effects with Python's standard library."""

import math
from pathlib import Path
import random
import struct
import wave


RATE = 44100
TAU = math.tau
OUTPUT = Path(__file__).resolve().parent


def note(track, start, frequency, length, volume, sparkle=False):
    """Soft mallet attack, wooden resonances, and an optional bell overtone."""
    offset = round(start * RATE)
    for index in range(round(length * RATE)):
        t = index / RATE
        attack = 1 - math.exp(-t / 0.002)
        release = min(1, (length - t) / 0.045)
        tone = math.sin(TAU * frequency * t) * math.exp(-t / (length * 0.23))
        tone += 0.30 * math.sin(TAU * frequency * 2.76 * t) * math.exp(-t / 0.032)
        tone += 0.13 * math.sin(TAU * frequency * 5.40 * t) * math.exp(-t / 0.018)
        if sparkle:
            tone += 0.22 * math.sin(TAU * frequency * 4 * t) * math.exp(-t / 0.19)
        track[offset + index] += volume * attack * release * tone


def save(name, track):
    # Keep headroom for the placement and result sounds playing together.
    assert max(abs(value) for value in track) < 0.6
    samples = b"".join(struct.pack("<h", round(value * 32767)) for value in track)
    with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(samples)


def generate():
    move = [0.0] * round(RATE * 0.20)
    note(move, 0, 620, 0.20, 0.38)
    rng = random.Random(7)
    for index in range(round(RATE * 0.035)):
        t = index / RATE
        move[index] += rng.uniform(-1, 1) * 0.035 * (1 - math.exp(-t / 0.001)) * math.exp(-t / 0.006)
    save("move", move)

    win = [0.0] * round(RATE * 1.25)
    for start, frequency, volume in [(0.04, 523.25, 0.27), (0.16, 659.25, 0.27), (0.28, 783.99, 0.28), (0.42, 1046.50, 0.30)]:
        note(win, start, frequency, 0.65, volume, sparkle=True)
    note(win, 0.42, 523.25, 0.75, 0.10)
    note(win, 0.57, 1567.98, 0.60, 0.09, sparkle=True)
    save("win", win)

    tie = [0.0] * round(RATE * 0.65)
    note(tie, 0.02, 587.33, 0.38, 0.27)
    note(tie, 0.18, 523.25, 0.45, 0.25)
    save("tie", tie)


if __name__ == "__main__":
    generate()
