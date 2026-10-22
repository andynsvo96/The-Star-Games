"""Original offline studio foley: pencil grain, paper, eraser and wooden taps.

Deterministic physical-style synthesis; no recordings or third-party samples.
The earlier mallet originals remain preserved in asset/pictionary/audio/.
"""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SAMPLE_RATE = 44100
randomizer = random.Random(37129)


def empty(seconds):
    return [0.0] * int(seconds * SAMPLE_RATE)


def mix(target, source, start=0.0, gain=1.0):
    offset = int(start * SAMPLE_RATE)
    for index, value in enumerate(source):
        if offset + index >= len(target):
            break
        target[offset + index] += value * gain


def tap(pitch=780, seconds=0.16):
    """Damped pencil-body resonances with a noisy contact transient."""
    result = empty(seconds)
    for index in range(len(result)):
        age = index / SAMPLE_RATE
        attack = min(1.0, age / 0.001)
        modes = sum(math.sin(math.tau * pitch * ratio * age) * level * math.exp(-age * decay)
                    for ratio, level, decay in [(1, .55, 48), (1.73, .28, 70), (2.81, .14, 95)])
        contact = randomizer.uniform(-1, 1) * .35 * math.exp(-age * 450)
        result[index] = attack * (modes + contact)
    return result


def friction(seconds, rate=28, softness=.15, pitch=2800):
    """Granular noise modulated like graphite or rubber on paper."""
    result = empty(seconds)
    low = previous = 0.0
    for index in range(len(result)):
        age = index / SAMPLE_RATE
        noise = randomizer.uniform(-1, 1)
        low += softness * (noise - low)
        grain = low - previous
        previous += .06 * (low - previous)
        gesture = math.sin(math.pi * age / seconds) ** .7
        tooth = .35 + .65 * abs(math.sin(math.tau * rate * age))
        resonance = 1 + .17 * math.sin(math.tau * pitch * age)
        result[index] = grain * gesture * tooth * resonance
    return result


def cue(kind):
    if kind == "countdown":
        result = empty(.12)
        mix(result, tap(1050, .10), gain=.52)
    elif kind == "wrong":
        result = empty(.29)
        mix(result, friction(.20, 22, .08, 1700), gain=1.7)
        mix(result, tap(490, .10), .17, .25)
    elif kind == "correct":
        result = empty(.55)
        mix(result, friction(.17, 38, .35), gain=1.25)
        mix(result, tap(830), .16, .60)
        mix(result, tap(1240), .25, .50)
        mix(result, tap(1660), .35, .36)
    elif kind == "turn":
        result = empty(.55)
        mix(result, friction(.30, 8, .07, 950), gain=1.65)
        mix(result, tap(690), .27, .62)
        mix(result, tap(940), .37, .34)
    elif kind == "time_up":
        result = empty(.66)
        mix(result, friction(.22, 16, .12, 1100), gain=.9)
        for start, pitch, gain in [(.08, 850, .5), (.24, 660, .55), (.43, 430, .7)]:
            mix(result, tap(pitch), start, gain)
    else:
        result = empty(1.0)
        mix(result, friction(.32, 11, .09, 1300), gain=1.1)
        for start, pitch, gain in [(.18, 620, .6), (.30, 830, .6), (.42, 1050, .55), (.56, 1240, .5), (.70, 1660, .35)]:
            mix(result, tap(pitch, .24), start, gain)
    return result


if __name__ == "__main__":
    for name in ["turn", "correct", "wrong", "countdown", "time_up", "match"]:
        samples = cue(name)
        # Leave headroom for overlapping effects in a busy room.
        mean = sum(samples) / len(samples)
        samples = [sample - mean for sample in samples]
        peak = max(abs(sample) for sample in samples) or 1
        gain = min(1.0, .58 / peak) * .8
        frames = b"".join(struct.pack("<h", round(sample * gain * 32767)) for sample in samples)
        with wave.open(str(ROOT / (name + ".wav")), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(SAMPLE_RATE)
            output.writeframes(frames)
