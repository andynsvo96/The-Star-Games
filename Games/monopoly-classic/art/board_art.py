"""Original offline vector board illustrations and physical dice/wood/steel cues."""
from pathlib import Path
import json
import math
import random
import shutil
import struct
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[1]
INK = '#24352f'


def generate(slots=None):
    art = ROOT / 'art'
    originals = PROJECT / 'asset/monopoly-classic/originals/board-details'
    originals.mkdir(parents=True, exist_ok=True)
    chest = '''<path d="M19 60L38 42H116L141 61V111L123 124H37L19 111Z" fill="#2486c6"/><path d="M19 61L37 73H123L141 61M37 73V124M123 73V124" fill="none"/><path d="M48 72V123M111 72V123" stroke="#fce4a0" stroke-width="9"/><path d="M69 72H89V93H69Z" fill="#f2c85f"/><circle cx="79" cy="82" r="3" fill="#24352f"/>'''
    lid = '''<path d="M19 61V46Q24 17 49 17H113Q137 20 141 46V61L123 73H37Z" fill="#39a4df"/><path d="M19 61H141M47 20V61M112 20V61" stroke="#fce4a0" stroke-width="8"/><path d="M26 46H134" fill="none" stroke="#d6f2ff" stroke-width="3"/>'''
    train = '''<g fill="#24352f"><path d="M14 78H148V102H17ZM35 42H83V80H35ZM24 30H47V78H29ZM87 50H118V80H87ZM107 31H122V63H107ZM117 61L145 48V94H117Z"/><path d="M24 34Q13 22 26 15Q13 6 29 3Q55 -1 58 14Q74 22 55 35Z"/><circle cx="41" cy="108" r="14"/><circle cx="85" cy="108" r="14"/><circle cx="128" cy="108" r="14"/></g><path d="M47 48H66V68H47Z" fill="#fffcef" stroke="none"/>'''
    bulb = '''<path d="M53 85Q23 61 41 29Q58 1 87 15Q120 31 107 61L88 85Z" fill="#ffdc54"/><path d="M54 85H89V100H54ZM59 101H84L79 112H64Z" fill="#6e7775"/><path d="M62 83L56 48L69 61L82 46L79 83" fill="none"/><path d="M72 2V-7M27 20L16 11M16 54H3M116 21L128 11M123 55H137M27 90L18 98M110 90L121 100" fill="none" stroke="#d59a23"/>'''
    tap = '''<path d="M32 43H121V60H96V83H75V60H32Z" fill="#b8d4dd"/><path d="M35 43V99H18V43ZM112 43V29H129V43Z" fill="#b8d4dd"/><path d="M82 15V41M64 16H102" fill="none" stroke-width="9"/><path d="M85 88Q60 114 85 122Q110 114 85 88Z" fill="#43b9e6"/>'''
    car = '''<path d="M17 66L27 47H53L66 24H104L121 47L142 56V96H17Z" fill="#d63a3c"/><path d="M62 46L73 30H98L108 46Z" fill="#e8f4f2"/><path d="M19 71H140" stroke="#ffcf57"/><circle cx="46" cy="98" r="17" fill="#263126"/><circle cx="115" cy="98" r="17" fill="#263126"/><circle cx="46" cy="98" r="7" fill="#ecece1"/><circle cx="115" cy="98" r="7" fill="#ecece1"/>'''
    prisoner = '''<rect x="19" y="7" width="122" height="114" rx="8" fill="#ee9d37"/><path d="M42 111Q40 67 80 66Q120 68 118 111Z" fill="#fffcef"/><path d="M46 89H116M44 104H118" stroke="#24352f" stroke-width="9"/><circle cx="80" cy="45" r="24" fill="#f1c599"/><path d="M56 28Q80 10 103 28V37H56Z" fill="#fffcef"/><path d="M63 25H97M68 48H71M89 48H92M72 59H88" fill="none"/><path d="M34 12V118M64 12V118M96 12V118M126 12V118" stroke="#536a70" stroke-width="7"/>'''
    police = '''<path d="M38 114L44 81Q78 59 113 82L122 114Z" fill="#235aab"/><circle cx="80" cy="46" r="25" fill="#f1c599"/><path d="M49 27L61 7H100L113 27L104 38H57Z" fill="#2365c2"/><path d="M53 29H107" stroke-width="9"/><path d="M80 11L88 15L85 25H75L72 15Z" fill="#ffcf57"/><path d="M69 50H72M90 50H93M74 63H90" fill="none"/><path d="M53 82L31 67L9 74L26 90L48 95" fill="#f1c599"/><path d="M99 89L107 94L104 103H94L91 94Z" fill="#ffcf57"/>'''
    ring = '''<ellipse cx="80" cy="86" rx="43" ry="32" fill="#edbd49"/><ellipse cx="80" cy="86" rx="29" ry="20" fill="#fffcef"/><path d="M48 31L64 13H96L112 31L80 69Z" fill="#d8f3fb"/><path d="M48 31H112M64 13L68 31L80 69L93 31L96 13M68 31H93" fill="none" stroke="#65a8c3"/>'''
    tax = '''<path d="M80 9L122 55L80 101L38 55Z" fill="#d9e9d8"/><path d="M80 26L105 55L80 84L55 55Z" fill="#fffcef"/><path d="M32 112H128M46 121H114" stroke="#9a743c"/>'''
    chance = '''<path d="M48 36Q48 6 80 6Q118 6 118 37Q118 55 97 66Q82 75 82 88H61Q58 66 80 52Q97 43 95 34Q92 24 80 25Q66 25 67 37Z" fill="#ed7935"/><circle cx="72" cy="111" r="12" fill="#ed7935"/>'''
    go = '''<path d="M147 83H49V66L13 94L49 122V105H147Z" fill="#d52b3b"/>'''
    icons = {'chest': chest + lid, 'chest-base': chest, 'chest-lid': lid, 'railroad': train, 'electric': bulb, 'water': tap, 'parking': car, 'jail': prisoner, 'go-to-jail': police, 'luxury-tax': ring, 'income-tax': tax, 'chance': chance, 'go': go}
    for name, body in icons.items():
        source = f'<svg xmlns="http://www.w3.org/2000/svg" width="160" height="130" viewBox="0 0 160 130"><g stroke="{INK}" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">{body}</g></svg>\n'
        filename = 'space-' + name + '.svg'
        (art / filename).write_text(source, encoding='utf-8')
        (originals / filename).write_text(source, encoding='utf-8')
    for deck, tint, symbol in [('community', '#b8d9df', chest + lid), ('chance', '#f0cc9b', chance)]:
        label = '<text x="120" y="67" font-family="Arial" font-weight="bold" font-size="30" text-anchor="middle" fill="#263126">COMMUNITY</text><text x="120" y="105" font-family="Arial" font-weight="bold" font-size="34" text-anchor="middle" fill="#263126">CHEST</text>' if deck == 'community' else '<text x="120" y="83" font-family="Arial" font-weight="bold" font-size="38" text-anchor="middle" fill="#263126">CHANCE</text>'
        source = f'<svg xmlns="http://www.w3.org/2000/svg" width="240" height="360" viewBox="0 0 240 360"><rect x="1" y="1" width="238" height="358" rx="12" fill="#fffef7" stroke="#c7c8ba"/><rect x="14" y="14" width="212" height="332" fill="{tint}" stroke="{INK}" stroke-width="2"/>{label}<g transform="translate(22 145) scale(1.22)" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round" stroke-linecap="round">{symbol}</g></svg>\n'
        filename = deck + '-back.svg'
        (art / filename).write_text(source, encoding='utf-8'); (originals / filename).write_text(source, encoding='utf-8')
    # Runtime SVGs use outlined standard lettering, with editable originals kept above.
    subprocess.run([sys.executable, str(PROJECT / 'asset/monopoly-classic/originals/outline_text.py'), str(art / 'community-back.svg'), str(art / 'chance-back.svg')], check=True)
    audio_dir = ROOT / 'audio'
    for cue, duration in [('roll', 1.05), ('jail', .95), ('chest', .85), ('doubles', .85)]:
        rng = random.Random(47017)
        rate = 44100
        samples = []
        impacts = [] if cue == 'doubles' else [.02, .08, .14, .21, .29, .40, .53, .69, .85] if cue == 'roll' else [.04, .13, .26, .31, .37] if cue == 'jail' else [.03, .16, .33]
        previous = 0.0
        for i in range(int(duration * rate)):
            t = i / rate
            noise = rng.uniform(-1, 1)
            high = noise - previous
            previous = noise
            value = 0.0
            for hit, onset in enumerate(impacts):
                age = t - onset
                if age < 0:
                    continue
                if cue == 'roll':
                    value += (.15 * high * math.exp(-age * 145) + .12 * math.sin(math.tau * (950 + hit * 117) * age) * math.exp(-age * 100)) * (1 - hit * .055)
                elif cue == 'jail':
                    value += .11 * high * math.exp(-age * 75)
                    for freq in [331, 887, 1433, 2399]:
                        value += .04 * math.sin(math.tau * freq * age) * math.exp(-age * (9 if hit == 2 else 28))
                else:
                    value += .14 * high * math.exp(-age * 90) + .09 * math.sin(math.tau * 164 * age) * math.exp(-age * 35)
            if cue == 'chest':
                value += .027 * math.sin(math.tau * (260 * t + 75 * t * t)) * math.sin(math.pi * min(1, t / .85))
            if cue == 'doubles':
                for onset, freq in [(0, 659.25), (.13, 830.61), (.26, 987.77)]:
                    age = t - onset
                    if age >= 0:
                        value += .15 * math.sin(math.tau * freq * age) * math.exp(-age * 8) * min(1, age * 180)
            value *= min(1, t * 500) * min(1, (duration - t) * 60)
            samples.append(struct.pack('<h', int(max(-.95, min(.95, value)) * 32767)))
        with wave.open(str(audio_dir / (cue + '.wav')), 'wb') as output:
            output.setnchannels(1); output.setsampwidth(2); output.setframerate(rate); output.writeframes(b''.join(samples))
        shutil.copyfile(audio_dir / (cue + '.wav'), originals / (cue + '.wav'))
    shutil.copyfile(PROJECT / 'Games/monopoly-deal/audio/card-slide-1.ogg', audio_dir / 'card-draw.ogg')
    if slots is None:
        manifest = json.loads((ROOT / 'theme-slots.json').read_text(encoding='utf-8'))
        slots = manifest['slots']
    else:
        manifest = None
    additions = [dict(id='space-' + name, label=name.replace('-', ' ').title(), group='Board illustrations', path=f'Games/monopoly-classic/art/space-{name}.svg', kind='image') for name in icons]
    additions.append(dict(id='sound-chest', label='Chest opening', group='Audio', path='Games/monopoly-classic/audio/chest.wav', kind='audio'))
    additions.append(dict(id='sound-card-draw', label='Card draw', group='Audio', path='Games/monopoly-classic/audio/card-draw.ogg', kind='audio'))
    additions.append(dict(id='sound-doubles', label='Doubles', group='Audio', path='Games/monopoly-classic/audio/doubles.wav', kind='audio'))
    existing = {slot['id'] for slot in slots}
    slots.extend(slot for slot in additions if slot['id'] not in existing)
    if manifest is not None:
        (ROOT / 'theme-slots.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    generate()
