"""Generate original offline Spyfall clock, ballot and team-result cues."""
from pathlib import Path
import math
import struct
import wave

RATE = 44100
ROOT = Path(__file__).resolve().parent


def write_cue(name, duration, notes):
    samples = []
    for frame in range(int(RATE * duration)):
        t = frame / RATE
        value = 0.0
        for start, frequency, amplitude, decay in notes:
            age = t - start
            if age < 0:
                continue
            envelope = min(1, age / 0.004) * math.exp(-age * decay)
            value += envelope * amplitude * (
                math.sin(2 * math.pi * frequency * age)
                + 0.2 * math.sin(2 * math.pi * frequency * 2 * age)
            )
        samples.append(struct.pack("<h", int(max(-0.95, min(0.95, value)) * 32767)))
    with wave.open(str(ROOT / (name + ".wav")), "wb") as cue:
        cue.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        cue.writeframes(b"".join(samples))


write_cue("countdown", 0.16, [(0, 880, 0.35, 32)])
# A short ballot stamp, an urgent expiry bell, and descending minor / rising
# major fanfares. No voices or external recordings.
write_cue("vote", 0.22, [(0, 520, 0.28, 45), (0.035, 780, 0.16, 34)])
write_cue("timer_up", 0.85, [(0, 880, 0.25, 12), (0.18, 660, 0.25, 12), (0.36, 440, 0.3, 8)])
write_cue("spy_win", 1.4, [
    (0, 659.25, 0.2, 8), (0.14, 523.25, 0.2, 8),
    (0.28, 493.88, 0.2, 8), (0.42, 392, 0.2, 8),
    (0.58, 329.63, 0.2, 5), (0.58, 392, 0.1, 5), (0.58, 493.88, 0.1, 5),
])
write_cue("non_spies_win", 1.5, [
    (0, 523.25, 0.2, 8), (0.14, 659.25, 0.2, 8),
    (0.28, 783.99, 0.2, 8), (0.42, 1046.5, 0.24, 6),
    (0.62, 523.25, 0.15, 5), (0.62, 659.25, 0.12, 5), (0.62, 783.99, 0.12, 5),
])
