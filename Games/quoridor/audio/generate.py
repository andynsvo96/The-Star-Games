"""Original offline wood taps and victory chime. No third-party sound sources."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
random.seed(47)
DEST = Path(__file__).parent


def write(name, duration, sample):
	with wave.open(str(DEST / (name + '.wav')), 'wb') as sound:
		sound.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
		sound.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, sample(i / RATE))) * 27000)) for i in range(int(RATE * duration))))


def wood(time, frequency, decay):
	return (math.sin(2 * math.pi * frequency * time) * .55 + math.sin(2 * math.pi * frequency * 2.71 * time) * .2 + random.uniform(-1, 1) * .2) * math.exp(-decay * time)


write('move', .16, lambda time: wood(time, 420, 36))
write('wall', .22, lambda time: wood(time, 235, 25))
notes = [(0, 523.25), (.11, 659.25), (.22, 783.99), (.34, 1046.5)]
write('win', 1.1, lambda time: sum(math.sin(2 * math.pi * hz * (time - start)) * math.exp(-6 * (time - start)) * .24 for start, hz in notes if time >= start))
