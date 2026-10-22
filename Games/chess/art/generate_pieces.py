"""Deterministic Staunton SVG assets, matching the project's glossy vector pieces."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SHAPES = {
    'pawn': '<circle cx="48" cy="23" r="12"/><path d="M39 37H57L55 45C55 57 63 65 65 70H31C33 65 41 57 41 45Z"/><ellipse cx="48" cy="38" rx="15" ry="5"/>',
    'knight': '<path d="M28 69C28 49 37 41 47 36L34 35L29 39L22 33L30 21L45 16L51 7L58 18C74 24 77 46 66 67L64 71H28Z"/><path d="M37 21L50 21L42 27L34 28Z" fill="url(#shade)" stroke="none"/><circle cx="51" cy="25" r="2.4" fill="url(#shade)" stroke="none"/><path d="M60 26Q72 45 56 64" fill="none" stroke="url(#shine)" stroke-width="3"/>',
    'bishop': '<circle cx="48" cy="11" r="4"/><path d="M48 15C25 33 28 42 40 45H56C68 42 71 33 48 15Z"/><path d="M52 22L43 35" fill="none" stroke="url(#shade)" stroke-width="4"/><path d="M40 44H56L54 52L61 68H35L42 52Z"/><ellipse cx="48" cy="46" rx="15" ry="4"/>',
    'rook': '<path d="M27 15H37V24H43V15H53V24H59V15H69V33L61 38H35L27 33Z"/><path d="M36 37H60L57 58L63 69H33L39 58Z"/><ellipse cx="48" cy="39" rx="16" ry="4"/>',
    'queen': '<circle cx="25" cy="18" r="4"/><circle cx="39" cy="13" r="4"/><circle cx="57" cy="13" r="4"/><circle cx="71" cy="18" r="4"/><path d="M26 23L34 44H62L70 23L59 31L56 18L48 29L40 18L37 31Z"/><path d="M37 45H59L55 55L62 69H34L41 55Z"/><ellipse cx="48" cy="46" rx="17" ry="5"/>',
    'king': '<path d="M44 6H52V14H60V22H52V30H44V22H36V14H44Z"/><path d="M31 32Q48 25 65 32L60 46H36Z"/><path d="M38 46H58L55 57L62 69H34L41 57Z"/><ellipse cx="48" cy="47" rx="16" ry="5"/>',
}
for side in ('white', 'black'):
    light, middle, dark, outline = ('#fffdea', '#f7d493', '#b97733', '#875024') if side == 'white' else ('#727b85', '#282e35', '#0b1018', '#080d14')
    for name, shape in SHAPES.items():
        svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">
<defs><linearGradient id="body" x2="1" y2=".25"><stop stop-color="{dark}"/><stop offset=".25" stop-color="{light}"/><stop offset=".48" stop-color="{middle}"/><stop offset=".85" stop-color="{dark}"/><stop offset="1" stop-color="{middle}"/></linearGradient><linearGradient id="shade"><stop stop-color="{outline}"/><stop offset="1" stop-color="{dark}"/></linearGradient><linearGradient id="shine"><stop stop-color="{light}"/><stop offset="1" stop-color="{middle}"/></linearGradient></defs>
<ellipse cx="48" cy="86" rx="33" ry="7" fill="#28140e" opacity=".25"/>
<g fill="url(#body)" stroke="{outline}" stroke-width="1.8" stroke-linejoin="round">{shape}<ellipse cx="48" cy="70" rx="24" ry="5"/><path d="M25 72H71L77 82Q48 92 19 82Z"/><ellipse cx="48" cy="79" rx="28" ry="6"/></g><path d="M27 78Q48 83 69 78" fill="none" stroke="{light}" stroke-width="2" opacity=".7"/></svg>'''
        (ROOT / f'{side}-{name}.svg').write_text(svg, encoding='utf-8')
print('Generated twelve chess piece assets.')
