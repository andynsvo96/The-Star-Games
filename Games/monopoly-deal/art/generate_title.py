"""Build the offline red/white/black wordmark, with no character illustration.

The editable source and previous wordmark are preserved in asset/. Expand SVG
references for Godot's SVG renderer and outline text for font-free exports.
"""
from copy import deepcopy
from pathlib import Path
import xml.etree.ElementTree as ET
from outline_text import convert, NS

root = Path(__file__).resolve().parents[3]
source = root / 'asset/monopoly-deal/originals/title-redesign-2026-10-16/title-source.svg'
target = Path(__file__).with_name('title.svg')
tree = ET.parse(source)
references = {element.get('id'): element for element in tree.iter() if element.get('id')}
for parent in tree.iter():
    for element in list(parent):
        if element.tag != '{' + NS + '}use':
            continue
        replacement = deepcopy(references[element.get('href')[1:]])
        replacement.attrib.pop('id', None)
        replacement.attrib.update({key: value for key, value in element.attrib.items() if key != 'href'})
        parent.insert(list(parent).index(element), replacement)
        parent.remove(element)
tree.write(target, encoding='unicode')
convert([target])
