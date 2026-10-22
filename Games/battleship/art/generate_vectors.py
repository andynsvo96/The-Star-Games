"""Rebuild the module-owned board geometry and markers (no external assets)."""
from pathlib import Path

ART = Path(__file__).resolve().parent
for name, light, mid, dark in [('blue', '#2bdfff', '#008eee', '#0053ac'), ('red', '#ff8588', '#fa303b', '#a60926')]:
    (ART / f'board-{name}.svg').write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" width="424" height="456" viewBox="0 0 424 456">
<defs><linearGradient id="shell" x2="0" y2="1"><stop stop-color="{light}"/><stop offset=".18" stop-color="{mid}"/><stop offset=".7" stop-color="{dark}"/><stop offset="1" stop-color="{mid}"/></linearGradient><linearGradient id="plate" x2="0" y2="1"><stop stop-color="#1e3d72"/><stop offset="1" stop-color="#081c46"/></linearGradient><linearGradient id="tab" x2="0" y2="1"><stop stop-color="{mid}"/><stop offset="1" stop-color="{dark}"/></linearGradient></defs>
<rect x="4" y="7" width="416" height="446" rx="24" fill="#08172c"/>
<rect x="4" y="3" width="416" height="444" rx="24" fill="url(#shell)" stroke="#082352" stroke-width="6"/>
<rect x="13" y="10" width="398" height="429" rx="18" fill="none" stroke="{light}" stroke-width="3"/>
<rect x="22" y="60" width="380" height="376" rx="11" fill="url(#plate)" stroke="#061a38" stroke-width="4"/>
<rect x="27" y="7" width="370" height="45" rx="10" fill="url(#tab)" stroke="{light}" stroke-width="3"/>
<rect x="35" y="13" width="354" height="33" rx="7" fill="{dark}" stroke="#082b59" stroke-width="2"/>
<path d="M24 62H400" stroke="#ffffff66" stroke-width="3"/>
<rect x="55" y="93" width="322" height="322" rx="5" fill="#0476b3" stroke="{light}" stroke-width="3"/>
<g fill="#0b2444" stroke="#d8efff77" stroke-width="1.5"><circle cx="17" cy="26" r="4"/><circle cx="407" cy="26" r="4"/><circle cx="17" cy="432" r="4"/><circle cx="407" cy="432" r="4"/></g>
</svg>''', encoding='utf8')

shapes = {
    'miss': '<defs><radialGradient id="p" cx=".35" cy=".3"><stop stop-color="#fff"/><stop offset=".5" stop-color="#ccfaff"/><stop offset="1" stop-color="#39addc"/></radialGradient></defs><circle cx="32" cy="35" r="19" fill="#073d7399"/><circle cx="32" cy="31" r="18" fill="url(#p)" stroke="#e5ffff" stroke-width="3"/><ellipse cx="27" cy="23" rx="7" ry="4" fill="#fff" opacity=".8"/>',
    'hit': '<path d="M17 19L48 50M48 19L17 50" stroke="#07304b88" stroke-width="13" stroke-linecap="round"/><path d="M17 15L47 45M47 15L17 45" stroke="#9d1225" stroke-width="12" stroke-linecap="round"/><path d="M17 13L47 43M47 13L17 43" stroke="#ff403d" stroke-width="8" stroke-linecap="round"/><path d="M17 11L28 22M47 11L36 22" stroke="#ffaaa0" stroke-width="3" stroke-linecap="round"/>',
    'cannon': '<defs><linearGradient id="steel" x2="0" y2="1"><stop stop-color="#aebed8"/><stop offset=".5" stop-color="#344d70"/><stop offset="1" stop-color="#111f3b"/></linearGradient><linearGradient id="gold" x2="0" y2="1"><stop stop-color="#fff3a0"/><stop offset=".4" stop-color="#ffba24"/><stop offset="1" stop-color="#a45407"/></linearGradient></defs><ellipse cx="28" cy="52" rx="23" ry="8" fill="#0a1a38"/><path d="M15 52L20 29H38L43 52Z" fill="url(#steel)" stroke="#123558" stroke-width="2"/><rect x="17" y="12" width="44" height="22" rx="6" fill="url(#steel)" stroke="#d1dbe8" stroke-width="2" transform="rotate(-18 20 25)"/><path d="M45 5L51 27" stroke="url(#gold)" stroke-width="8"/><ellipse cx="58" cy="12" rx="5" ry="11" fill="#07152b" stroke="#f9c139" stroke-width="3" transform="rotate(-18 58 12)"/>',
}
for name, shape in shapes.items():
    (ART / f'{name}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{shape}</svg>', encoding='utf8')

# Common scale and waterline; lengths follow the five fleet sizes (5/4/3/3/2).
# Both native and browser monitors use these same side-profile silhouettes.
fleet_shapes = {
    'carrier': (180, '<path d="M4 25H176L160 35H20Z M5 20H175V24H5Z M111 20V11H126V6H140V20Z"/><path d="M132 6V2" stroke="#b3e9ff" stroke-width="2"/><path d="M30 20L36 15H46L52 20Z M65 20L71 15H81L87 20Z"/>'),
    'battleship': (144, '<path d="M4 25H140L126 35H18Z M52 25V17H60V10H73V6H83V13H92V25Z M20 25V20H37V25Z M105 25V20H122V25Z"/><path d="M28 20L12 16M113 20L132 16M77 6V2" stroke="#b3e9ff" stroke-width="3"/>'),
    'cruiser': (108, '<path d="M4 25H104L91 35H17Z M38 25V17H46V11H62V17H69V25Z M18 25V21H29V25Z M77 25V21H88V25Z M70 25V14H77V25Z"/><path d="M54 11V2M49 7H61M23 21L10 18M82 21L98 18" stroke="#b3e9ff" stroke-width="2"/>'),
    'submarine': (108, '<path d="M4 27Q4 21 15 21H93Q104 21 104 27Q104 35 93 35H15Q4 35 4 27Z M43 21V14Q43 11 47 11H59Q63 11 63 14V21Z"/><path d="M53 11V5H61" fill="none" stroke="#b3e9ff" stroke-width="3"/>'),
    'destroyer': (72, '<path d="M4 25H68L57 35H14Z M25 25V16H31V10H42V16H47V25Z M12 25V21H20V25Z M49 25V22H58V25Z"/><path d="M36 10V3M16 21L7 18M53 22L64 19" stroke="#b3e9ff" stroke-width="2"/>'),
}
for name, (width, shape) in fleet_shapes.items():
    (ART / f'fleet-{name}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="38" viewBox="0 0 {width} 38"><g fill="#b3e9ff">{shape}</g></svg>', encoding='utf8')
(ART / 'fleet-console.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" width="240" height="180" viewBox="0 0 240 180"><defs><linearGradient id="steel" x2="0" y2="1"><stop stop-color="#8caccd"/><stop offset=".2" stop-color="#456787"/><stop offset="1" stop-color="#183553"/></linearGradient><linearGradient id="screen" x2="1" y2="1"><stop stop-color="#103960"/><stop offset="1" stop-color="#081c39"/></linearGradient></defs><rect x="3" y="4" width="234" height="174" rx="16" fill="url(#steel)" stroke="#071c36" stroke-width="5"/><rect x="14" y="13" width="212" height="152" rx="11" fill="url(#screen)" stroke="#50c7df" stroke-width="2"/><path d="M25 39H215" stroke="#55bdd577"/><g fill="#12283d" stroke="#b8cfde"><circle cx="10" cy="10" r="3"/><circle cx="230" cy="10" r="3"/><circle cx="10" cy="170" r="3"/><circle cx="230" cy="170" r="3"/></g></svg>''', encoding='utf8')

(ART.parent / 'thumbnail.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" width="320" height="180" viewBox="0 0 320 180"><defs><linearGradient id="sea" x2="0" y2="1"><stop stop-color="#3bdcff"/><stop offset="1" stop-color="#0060aa"/></linearGradient></defs><rect width="320" height="180" rx="16" fill="#0d2851"/><rect x="8" y="8" width="304" height="164" rx="12" fill="url(#sea)"/><g stroke="#a4faff77" stroke-width="1"><path d="M40 65V163M64 65V163M88 65V163M112 65V163M136 65V163M160 65V163M184 65V163M208 65V163M232 65V163M256 65V163M280 65V163M16 89H304M16 113H304M16 137H304M16 161H304"/></g><path d="M49 118L81 104H214L267 118L242 141H72Z" fill="#acbfd6" stroke="#152f51" stroke-width="4"/><path d="M135 109V83H173V109M143 83V72H165V83" fill="#8197b7" stroke="#153455" stroke-width="3"/><path d="M94 110V99H116V110M196 110V99H218V110" fill="#526d90"/><path d="M103 100V89M207 100V89M154 74V63" stroke="#dfe9ef" stroke-width="5"/><text x="160" y="43" text-anchor="middle" font-family="Arial Black,Arial,sans-serif" font-size="32" font-weight="900" fill="#fff" stroke="#082151" stroke-width="5" paint-order="stroke">BATTLE<tspan fill="#ff4147">SHIP</tspan></text><path d="M258 74L273 89M273 74L258 89" stroke="#ff4b48" stroke-width="8" stroke-linecap="round"/><circle cx="41" cy="82" r="7" fill="#d3fbff"/></svg>''', encoding='utf8')
