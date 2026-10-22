"""Original offline cash-register and game-show buzzer cues; no sampled media."""
from array import array
from math import exp, pi, sin, tanh
from pathlib import Path
import random
import shutil
import wave

RATE = 44100
FOLDER = Path(__file__).resolve().parent
RUNTIME = FOLDER.parents[3] / 'Games' / 'monopoly-deal' / 'audio'


def write(name, samples):
    peak = max(abs(sample) for sample in samples) or 1
    pcm = array('h', (round(sample / peak * 0.82 * 32767) for sample in samples))
    source = FOLDER / name
    with wave.open(str(source), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    shutil.copyfile(source, RUNTIME / name)


rng = random.Random(470716)
cash = []
prior = 0.0
for index in range(round(RATE * 1.05)):
    t = index / RATE
    noise = rng.uniform(-1, 1)
    click = (noise - prior) * exp(-t * 75) * 0.18
    click += sin(2 * pi * 195 * t) * exp(-t * 42) * 0.3
    prior = noise
    bell = 0.0
    for start, frequency, gain in [(0.11, 1568, 0.55), (0.15, 2093, 0.38)]:
        u = t - start
        if u >= 0:
            attack = min(1, u / 0.003)
            bell += attack * gain * (sin(2*pi*frequency*u)*exp(-u*5.5)
                                    + 0.3*sin(2*pi*frequency*2.73*u)*exp(-u*13)
                                    + 0.14*sin(2*pi*frequency*4.12*u)*exp(-u*19))
    cash.append((click + bell) * min(1, max(0, (1.05-t) / 0.08)))
write('cash-register.wav', cash)

buzzer = []
phase = 0.0
for index in range(round(RATE * 0.72)):
    t = index / RATE
    frequency = 154 - 24 * min(1, t / 0.6)
    phase += 2*pi*frequency/RATE
    tone = sum(sin(phase*n)/n for n in [1, 2, 3, 5, 7, 9])
    tone += 0.35*sin(phase * 0.79) + 0.13*sin(phase * 2.07)
    envelope = min(1, t/0.018) * min(1, max(0, (0.72-t)/0.1))
    pulse = 0.84 + 0.16*sin(2*pi*24*t)
    buzzer.append(tanh(tone * 1.4) * envelope * pulse)
write('stop-buzzer.wav', buzzer)
