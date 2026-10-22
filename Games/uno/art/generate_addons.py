"""Extend UNO's existing offline vector faces; no source artwork is replaced."""
from pathlib import Path
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

ROOT = Path(__file__).parent / 'cards'
FONT = TTFont(sys.argv[1] if len(sys.argv) > 1 else 'C:/Windows/Fonts/arialbd.ttf')
GLYPHS = FONT.getGlyphSet()
CMAP = FONT.getBestCmap()
UNITS = FONT['head'].unitsPerEm
COLORS = ['red', 'yellow', 'green', 'blue']
WILDS = {
    'power_reverse': ('REVERSE', 'PLAY AGAIN'), 'no_u': ('NO U', 'RETURN DRAW'),
    'stack3': ('+3', 'STACK'), 'stack_number': ('+?', 'STACK'),
    'force_trade': ('TRADE', 'TWO HANDS'), 'pass_hands': ('PASS', 'ALL HANDS'),
    'double_speed': ('>>', 'SPEED +2'), 'pass_color': ('PASS', 'ONE COLOR'),
    'trick': ('TRICK', 'EXTRA TURN'), 'color_challenge': ('COLOR', 'CHALLENGE'),
    'nemesis': ('NEMESIS', 'ENEMY +2'), 'petty': ('+3', 'PETTY PLAY'),
    'eliminator': ('NO WILDS', 'ELIMINATOR'), 'instigator': ('+1-4', 'INSTIGATOR'),
    'block': ('BLOCK', 'NO PENALTY'), 'rebound': ('BACK +1', 'REBOUND'),
    'deflect': ('NEXT', 'DEFLECT'), 'redirect': ('TARGET', 'REDIRECT'),
    'swap_hands': ('SWAP', 'HANDS'), 'double_down': ('-1', 'DOUBLE DOWN'),
    'match_max': ('MATCH', 'THE MAX'), 'misery': ('ALL MATCH', 'THE MAX'),
    'coupled': ('COUPLED', 'HELP PARTNER'), 'chat': ('CHAT', 'PEEK & SWAP'),
    'eggs': ('EGGS', 'ONE BASKET'),
}
COLORED = {'reverse_draw2': ('+2', 'REVERSE'), 'reverse_skip': ('SKIP', 'REVERSE'),
           'stack1': ('+1', 'STACK'), 'stack2': ('+2', 'STACK'),
           'swap1': ('SWAP 1', 'ONE CARD'), 'refresh_hand': ('REFRESH', 'YOUR HAND'),
           'reveal_hands': ('REVEAL', 'ALL HANDS'), 'text': ('TEXT', 'CHOOSE RULE')}
LETTERS = {'swap_hands': 'U', 'double_down': 'N', 'match_max': 'O'}


def text_path(text, x, y, height, maximum=90, fill='#fff'):
    paths, advance = [], 0
    for char in text:
        name = CMAP[ord(char)]
        pen = SVGPathPen(GLYPHS)
        GLYPHS[name].draw(pen)
        paths.append(f'<path d="{pen.getCommands()}" transform="translate({advance} 0)"/>')
        advance += FONT['hmtx'][name][0]
    scale = min(height / UNITS, maximum / max(1, advance))
    return f'<g fill="{fill}" stroke="#171820" stroke-width="{0.65 / scale:.3f}" stroke-linejoin="round" paint-order="stroke fill" transform="translate({x - advance * scale / 2:.3f} {y}) scale({scale:.5f} {-scale:.5f})">' + ''.join(paths) + '</g>'


def symbol(kind):
    if kind in ['swap1', 'force_trade', 'swap_hands', 'pass_hands', 'refresh_hand', 'pass_color', 'chat', 'double_down', 'match_max', 'misery', 'reveal_hands']:
        return '<g fill="#fff" stroke="#171820" stroke-width="2"><rect x="34" y="67" width="25" height="39" rx="3" transform="rotate(-14 46 86)"/><rect x="56" y="67" width="25" height="39" rx="3" transform="rotate(14 68 86)"/></g><path d="M37 113H76L69 106M76 113L69 120" fill="none" stroke="#fff" stroke-width="4" stroke-linejoin="round"/>'
    if kind in ['block', 'rebound', 'deflect', 'redirect', 'no_u']:
        return '<path d="M60 66L82 74V89Q82 110 60 120Q38 110 38 89V74Z" fill="#fff" stroke="#171820" stroke-width="3"/>' + text_path({'block':'X','rebound':'+1','deflect':'>','redirect':'>','no_u':'U'}[kind], 60, 104, 29, 34, '#171820')
    if kind in ['reverse_draw2', 'reverse_skip', 'power_reverse']:
        original = (ROOT / 'red-reverse.svg').read_text(encoding='utf-8')
        return original[original.rfind('<g data-action-symbol='):original.rfind('</svg>')]
    if kind == 'coupled':
        return '<path d="M60 116L38 95C19 72 47 54 60 75C73 54 101 72 82 95Z" fill="#fff" stroke="#171820" stroke-width="3"/>'
    if kind == 'eggs':
        return '<path d="M35 86Q60 67 85 86L78 114H42Z" fill="#fff" stroke="#171820" stroke-width="3"/><g fill="#fff" stroke="#171820" stroke-width="2"><ellipse cx="48" cy="82" rx="7" ry="10"/><ellipse cx="62" cy="80" rx="7" ry="10"/><ellipse cx="75" cy="83" rx="6" ry="9"/></g>'
    if kind == 'text':
        return '<rect x="41" y="65" width="38" height="55" rx="6" fill="#fff" stroke="#171820" stroke-width="3"/><path d="M49 76H72V97H61L52 105V97H49Z" fill="#171820"/>'
    if kind == 'eliminator':
        return '<circle cx="60" cy="91" r="23" fill="#fff" stroke="#171820" stroke-width="3"/><path d="M44 107L76 75" stroke="#171820" stroke-width="6"/>'
    if kind in ['color_challenge', 'trick', 'nemesis']:
        return '<path d="M60 65L67 81L84 83L71 95L75 114L60 104L45 114L49 95L36 83L53 81Z" fill="#fff" stroke="#171820" stroke-width="3"/>'
    return text_path(WILDS.get(kind, COLORED.get(kind))[0], 60, 104, 42, 74)


def face(kind, suit='wild', chosen=False):
    base_name = f'{suit}-wild-chosen.svg' if chosen else ('wild-wild.svg' if suit == 'wild' else f'{suit}-0.svg')
    base = (ROOT / base_name).read_text(encoding='utf-8')
    # Retain the established casing and colored ellipse, replace only symbols.
    if suit != 'wild' and not chosen:
        base = base[:base.index('<path d=')]
    else:
        base = base[:base.index('<circle cx="25"')] if '<circle cx="25"' in base else base[:base.rfind('</svg>')]
    title, subtitle = WILDS.get(kind, COLORED.get(kind))
    art = symbol(kind)
    corner = text_path(title, 28, 30, 15, 28)
    bottom = f'<g transform="rotate(180 60 90)">{corner}</g>'
    caption = text_path(title, 60, 54, 12, 80) + text_path(subtitle, 60, 139, 9, 85)
    letter = text_path(LETTERS[kind], 26, 156, 18, 20) if kind in LETTERS else ''
    return base + corner + bottom + art + caption + letter + '</svg>\n'


def main():
    for kind in COLORED:
        for suit in COLORS: (ROOT / f'addon-{suit}-{kind}.svg').write_text(face(kind, suit), encoding='utf-8')
    for kind in WILDS:
        (ROOT / f'addon-wild-{kind}.svg').write_text(face(kind), encoding='utf-8')
        for suit in COLORS: (ROOT / f'addon-{suit}-{kind}-chosen.svg').write_text(face(kind, suit, True), encoding='utf-8')
    for index, suit in enumerate(['yellow', 'red', 'blue', 'green']):
        for number in range(1 + index * 2, 4 + index * 2):
            base = (ROOT / f'{suit}-{number}.svg').read_text(encoding='utf-8')
            arrows = '<path d="M44 127L51 133L44 139M57 127L64 133L57 139" fill="none" stroke="#fff" stroke-width="3"/>'
            (ROOT / f'addon-speed-{suit}-{number}.svg').write_text(base.replace('</svg>', arrows + '</svg>'), encoding='utf-8')
    print('Generated offline UNO add-on vectors.')


if __name__ == '__main__':
    main()
