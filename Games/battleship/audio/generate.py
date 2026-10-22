"""Build offline naval Foley from preserved CC0 sources; FFmpeg is build-time only."""
from pathlib import Path, PurePosixPath
import math
import struct
import subprocess
import tempfile
import wave

OUTPUT = Path(__file__).resolve().parent
SOURCES = OUTPUT.parents[2] / 'asset' / 'battleship' / 'audio'
RATE = 44100


def unpack(archive, destination):
    names = subprocess.check_output(['tar', '-tf', str(archive)], text=True).splitlines()
    if any(name.startswith('/') or ':' in name or '..' in PurePosixPath(name.replace('\\', '/')).parts for name in names):
        raise ValueError('Unsafe source archive path')
    subprocess.run(['tar', '-xf', str(archive), '-C', str(destination)], check=True)


def render(name, sources, duration, mixing=None, gain=1.0):
    command = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y']
    for source in sources:
        command.extend(['-i', str(source)])
    filters = f'highpass=f=45,lowpass=f=8000,volume={gain},alimiter=limit=.88:level=false:attack=1:release=40,afade=t=in:d=0.004,afade=t=out:st={duration - .20}:d=0.20'
    if mixing:
        command.extend(['-filter_complex', mixing + ',' + filters])
    else:
        command.extend(['-af', filters])
    command.extend(['-t', str(duration), '-ac', '1', '-ar', str(RATE), '-c:a', 'pcm_s16le', '-map_metadata', '-1', str(OUTPUT / f'{name}.wav')])
    subprocess.run(command, check=True)


with tempfile.TemporaryDirectory(prefix='star-games-naval-audio-') as temporary:
    folder = Path(temporary)
    unpack(SOURCES / 'qubodup-NavalBattleSoundSet-cc0.7z', folder)
    unpack(SOURCES / 'water-splash-slime-sfx.zip', folder)
    naval = folder / 'qubodup-NavalBattleSoundSet-cc0'
    render('place', [folder / 'splash_04.ogg'], .40, gain=.26)
    render('cannon', [naval / 'GunShot.wav'], .95, gain=.75)
    render('miss', [naval / 'Splash.wav'], 1.15, gain=.82)
    render('hit', [naval / 'ExplosionMetal.wav'], .95, gain=.65)
    render('sunk', [naval / 'ExplosionMetalGverb.wav', naval / 'Splash.wav'], 1.35,
           '[0:a]volume=.65[steel];[1:a]adelay=160,volume=.48[water];[steel][water]amix=inputs=2:normalize=0', gain=.8)

# A soft bronze ship bell replaces the electronic victory arpeggio.
duration = 1.35
frames = []
partials = [(660, .28, 2.7), (1140, .12, 4.8), (1550, .075, 6.2), (2140, .035, 8.1), (3300, .012, 13)]
for index in range(int(RATE * duration)):
    time = index / RATE
    sample = sum(amplitude * math.sin(2 * math.pi * frequency * time) * math.exp(-decay * time) for frequency, amplitude, decay in partials)
    sample *= min(1, time / .003, (duration - time) / .20)
    frames.append(struct.pack('<h', int(max(-.9, min(.9, sample)) * 32767)))
with wave.open(str(OUTPUT / 'win.wav'), 'wb') as target:
    target.setnchannels(1)
    target.setsampwidth(2)
    target.setframerate(RATE)
    target.writeframes(b''.join(frames))
