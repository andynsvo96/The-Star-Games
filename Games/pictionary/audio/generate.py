"""Assemble the active offline cues from their preserved original sources.

Correct guesses and new turns use the original mallet sounds. Countdown,
time expiry and match completion retain their studio cues. Wrong guesses use
one quiet, short tone. The historical studio script remains in studio-v2/.
"""
import math
import struct
import wave
from pathlib import Path
from shutil import copyfile

ROOT = Path(__file__).resolve().parent
SOURCES = ROOT.parents[2] / "asset" / "pictionary" / "audio"


def generate_wrong(path):
    """One damped low note, with smooth edges and no layered sounds."""
    sample_rate = 44100
    duration = .14
    frames = []
    for index in range(int(sample_rate * duration)):
        age = index / sample_rate
        edge = min(1.0, age / .004, (duration - age) / .012)
        envelope = edge * math.exp(-age * 20)
        sample = .20 * envelope * math.sin(math.tau * 185 * age)
        frames.append(struct.pack("<h", round(sample * 32767)))
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        output.writeframes(b"".join(frames))


if __name__ == "__main__":
    for name in ["turn", "correct"]:
        copyfile(SOURCES / (name + ".wav"), ROOT / (name + ".wav"))
    for name in ["countdown", "time_up", "match"]:
        copyfile(SOURCES / "studio-v2" / (name + ".wav"), ROOT / (name + ".wav"))
    generate_wrong(ROOT / "wrong.wav")
