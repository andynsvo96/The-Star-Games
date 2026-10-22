"""Outline our SVG lettering using a local TrueType font, with no build dependency.

Godot's SVG importer omits text nodes. The finished SVGs contain paths only and
need no system fonts at runtime. Original editable vectors stay beside this file.
"""
from pathlib import Path
import struct
import xml.etree.ElementTree as ET


class TrueType:
    def __init__(self, filename):
        self.data = Path(filename).read_bytes()
        self.tables = {}
        for index in range(self.u16(4)):
            tag, _, offset, length = struct.unpack_from('>4sIII', self.data, 12 + index * 16)
            self.tables[tag.decode()] = offset
        head = self.tables['head']
        self.units = self.u16(head + 18)
        self.long_locations = self.i16(head + 50) == 1
        self.metrics = self.u16(self.tables['hhea'] + 34)
        cmap = self.tables['cmap']
        candidates = []
        for index in range(self.u16(cmap + 2)):
            platform, encoding, offset = struct.unpack_from('>HHI', self.data, cmap + 4 + index * 8)
            start = cmap + offset
            if self.u16(start) == 4 and platform in [0, 3]:
                candidates.append(start)
        self.cmap = candidates[-1]

    def u16(self, offset): return struct.unpack_from('>H', self.data, offset)[0]
    def i16(self, offset): return struct.unpack_from('>h', self.data, offset)[0]
    def u32(self, offset): return struct.unpack_from('>I', self.data, offset)[0]

    def glyph_id(self, char):
        code, start = ord(char), self.cmap
        count = self.u16(start + 6) // 2
        ends, starts = start + 14, start + 16 + count * 2
        deltas, offsets = starts + count * 2, starts + count * 4
        for index in range(count):
            if self.u16(starts + index * 2) <= code <= self.u16(ends + index * 2):
                delta = self.i16(deltas + index * 2)
                location = offsets + index * 2
                distance = self.u16(location)
                if not distance: return (code + delta) & 65535
                glyph = self.u16(location + distance + 2 * (code - self.u16(starts + index * 2)))
                return (glyph + delta) & 65535 if glyph else 0
        return 0

    def advance(self, glyph):
        return self.u16(self.tables['hmtx'] + min(glyph, self.metrics - 1) * 4)

    def contours(self, glyph, depth=0):
        if depth > 8: raise ValueError('Recursive font component')
        loca = self.tables['loca']
        location = self.u32(loca + glyph * 4) if self.long_locations else self.u16(loca + glyph * 2) * 2
        following = self.u32(loca + (glyph + 1) * 4) if self.long_locations else self.u16(loca + (glyph + 1) * 2) * 2
        if location == following: return []
        start = self.tables['glyf'] + location
        number = self.i16(start)
        if number < 0:
            cursor, result = start + 10, []
            while True:
                flags, child = self.u16(cursor), self.u16(cursor + 2); cursor += 4
                fmt = '>hh' if flags & 1 else '>bb'
                first, second = struct.unpack_from(fmt, self.data, cursor); cursor += 4 if flags & 1 else 2
                if not flags & 2: raise ValueError('Point-matched composite is not used by this artwork')
                a, b, c, d = 1, 0, 0, 1
                if flags & 8: a = d = self.i16(cursor) / 16384; cursor += 2
                elif flags & 64: a, d = self.i16(cursor) / 16384, self.i16(cursor + 2) / 16384; cursor += 4
                elif flags & 128: a, b, c, d = [self.i16(cursor + index * 2) / 16384 for index in range(4)]; cursor += 8
                result += [[(a*x+c*y+first, b*x+d*y+second, on) for x,y,on in contour] for contour in self.contours(child, depth + 1)]
                if not flags & 32: return result
        ends = [self.u16(start + 10 + index * 2) for index in range(number)]
        cursor = start + 10 + number * 2
        cursor += 2 + self.u16(cursor)
        flags = []
        while len(flags) <= ends[-1]:
            flag = self.data[cursor]; cursor += 1; flags.append(flag)
            if flag & 8:
                repeat = self.data[cursor]; cursor += 1; flags += [flag] * repeat
        coordinates = []
        for short_bit, same_bit in [(2, 16), (4, 32)]:
            values, value = [], 0
            for flag in flags:
                if flag & short_bit:
                    delta = self.data[cursor]; cursor += 1
                    value += delta if flag & same_bit else -delta
                elif not flag & same_bit: value += self.i16(cursor); cursor += 2
                values.append(value)
            coordinates.append(values)
        result, first = [], 0
        for end in ends:
            result.append([(coordinates[0][index], coordinates[1][index], bool(flags[index] & 1)) for index in range(first, end + 1)])
            first = end + 1
        return result

    def path(self, glyph):
        commands = []
        point = lambda value: f'{value[0]:g},{value[1]:g}'
        for contour in self.contours(glyph):
            expanded = []
            for index, current in enumerate(contour):
                expanded.append(current); following = contour[(index + 1) % len(contour)]
                if not current[2] and not following[2]: expanded.append(((current[0]+following[0])/2, (current[1]+following[1])/2, True))
            index = next(index for index, value in enumerate(expanded) if value[2])
            expanded = expanded[index:] + expanded[:index]
            commands.append('M' + point(expanded[0])); control = None
            for current in expanded[1:] + expanded[:1]:
                if current[2]:
                    commands.append(('Q' + point(control) + ' ' if control else 'L') + point(current)); control = None
                else: control = current
            commands.append('Z')
        return ''.join(commands)


def main():
    root = Path(__file__).resolve().parents[2]
    font = TrueType('C:/Windows/Fonts/georgiab.ttf')
    symbols = TrueType('C:/Windows/Fonts/seguisym.ttf')
    ns = '{http://www.w3.org/2000/svg}'
    sources = Path(__file__).with_name('vector-sources'); sources.mkdir(exist_ok=True)
    targets = [root/'Games/poker/art/title.svg', root/'Games/poker/art/chip.svg'] + list((root/'Games').glob('poker*/thumbnail.svg'))
    for target in targets:
        source = sources / str(target.relative_to(root)).replace('\\', '-').replace('/', '-')
        if not source.exists(): source.write_text(target.read_text(encoding='utf-8'), encoding='utf-8')
        document = ET.fromstring(source.read_text(encoding='utf-8'))
        for parent in document.iter():
            for node in list(parent):
                if node.tag != ns+'text': continue
                glyphs = []
                for char in node.text or '':
                    selected = font if font.glyph_id(char) else symbols
                    glyphs.append((selected, selected.glyph_id(char), font.units / selected.units))
                if any(glyph == 0 for _,glyph,_ in glyphs): raise ValueError('Artwork fonts lack a character')
                scale = float(node.get('font-size', '16')) / font.units
                spacing = float(node.get('letter-spacing', '0')) / scale
                width = sum(selected.advance(glyph)*factor+spacing for selected,glyph,factor in glyphs)-spacing
                x, y = float(node.get('x', '0')), float(node.get('y', '0'))
                if node.get('text-anchor') == 'middle': x -= width * scale / 2
                group = ET.Element(ns+'g', {key:value for key,value in node.attrib.items() if key in ['fill','stroke','stroke-width','opacity']})
                group.set('transform', f'translate({x:g} {y:g}) scale({scale:g} {-scale:g})')
                if group.get('stroke-width'): group.set('stroke-width', str(float(group.get('stroke-width')) / scale))
                cursor = 0
                for selected,glyph,factor in glyphs:
                    ET.SubElement(group, ns+'path', {'d':selected.path(glyph),'transform':f'translate({cursor:g} 0) scale({factor:g})'})
                    cursor += selected.advance(glyph)*factor+spacing
                parent.remove(node); parent.append(group)
        ET.register_namespace('', ns[1:-1]); target.write_text(ET.tostring(document, encoding='unicode'), encoding='utf-8')
        print(target.relative_to(root))


if __name__ == '__main__': main()
