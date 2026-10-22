"""Outline development SVG labels with installed Windows font data (no UI).

The resulting assets are portable SVG paths; runtime needs neither this helper
nor installed fonts. Native TrueType quadratic curves become SVG cubic curves.
"""
import ctypes as ct
from ctypes import wintypes as wt
from pathlib import Path
import struct
import sys
import xml.etree.ElementTree as ET

SCALE = 64
NS = 'http://www.w3.org/2000/svg'
ET.register_namespace('', NS)

class Fixed(ct.Structure):
 _fields_ = [('fraction', wt.WORD), ('value', ct.c_short)]

class Matrix(ct.Structure):
 _fields_ = [('m11', Fixed), ('m12', Fixed), ('m21', Fixed), ('m22', Fixed)]

class Metrics(ct.Structure):
 _fields_ = [('width', wt.UINT), ('height', wt.UINT), ('origin', wt.POINT), ('advance_x', ct.c_short), ('advance_y', ct.c_short)]

gdi = ct.WinDLL('gdi32', use_last_error=True)
gdi.CreateCompatibleDC.argtypes = [wt.HDC]; gdi.CreateCompatibleDC.restype = wt.HDC
gdi.CreateFontW.argtypes = [ct.c_int]*5 + [wt.DWORD]*8 + [wt.LPCWSTR]
gdi.CreateFontW.restype = wt.HANDLE
gdi.SelectObject.argtypes = [wt.HDC, wt.HANDLE]; gdi.SelectObject.restype = wt.HANDLE
gdi.DeleteObject.argtypes = [wt.HANDLE]; gdi.DeleteDC.argtypes = [wt.HDC]
gdi.GetGlyphOutlineW.argtypes = [wt.HDC, wt.UINT, wt.UINT, ct.POINTER(Metrics), wt.DWORD, ct.c_void_p, ct.POINTER(Matrix)]
gdi.GetGlyphOutlineW.restype = wt.DWORD
matrix = Matrix(Fixed(0,1), Fixed(0,0), Fixed(0,0), Fixed(0,1))

def point(data, offset):
 fx, x, fy, y = struct.unpack_from('<HhHh', data, offset)
 return x+fx/65536, y+fy/65536

def pair(p):
 return f'{p[0]:.3f},{p[1]:.3f}'

def outline(data):
 commands=[]; offset=0
 while offset < len(data):
  size, kind = struct.unpack_from('<II', data, offset)
  if kind != 24 or size < 16: raise ValueError('Invalid TrueType contour')
  current=point(data,offset+8); commands.append('M'+pair(current)); position=offset+16
  while position < offset+size:
   primitive,count=struct.unpack_from('<HH',data,position)
   points=[point(data,position+4+i*8) for i in range(count)]
   if primitive == 1:
    for p in points: commands.append('L'+pair(p)); current=p
   elif primitive == 2:
    for i,control in enumerate(points[:-1]):
     end=points[i+1] if i==len(points)-2 else tuple((a+b)/2 for a,b in zip(control,points[i+1]))
     first=tuple(a+(b-a)*2/3 for a,b in zip(current,control))
     second=tuple(a+(b-a)*2/3 for a,b in zip(end,control))
     commands.append('C'+pair(first)+' '+pair(second)+' '+pair(end)); current=end
   elif primitive == 3:
    for i in range(0,count,3): commands.append('C'+' '.join(pair(p) for p in points[i:i+3])); current=points[i+2]
   else: raise ValueError('Unknown TrueType curve')
   position += 4+count*8
  commands.append('Z'); offset += size
 return ' '.join(commands)

def convert(files):
 dc=gdi.CreateCompatibleDC(None); fonts={}; glyphs={}; initial=None
 try:
  for file in files:
   tree=ET.parse(file)
   for parent in tree.iter():
    for label in list(parent):
     if label.tag != '{'+NS+'}text': continue
     size=float(label.get('font-size')); weight=400 if label.get('font-weight')=='normal' else 700
     family=label.get('data-font-family','Arial')
     font_key=(size,weight,family)
     if font_key not in fonts:
      fonts[font_key]=gdi.CreateFontW(-round(size*SCALE),0,0,0,weight,0,0,0,1,0,0,0,0,family)
      if not fonts[font_key]: raise ct.WinError(ct.get_last_error())
     previous=gdi.SelectObject(dc,fonts[font_key])
     if initial is None: initial=previous
     parts=[]; advance=0; bounds=[]
     for character in ''.join(label.itertext()):
      cache_key=(*font_key,character)
      if cache_key not in glyphs:
       metrics=Metrics(); length=gdi.GetGlyphOutlineW(dc,ord(character),258,ct.byref(metrics),0,None,ct.byref(matrix))
       if length==0xffffffff: raise ct.WinError(ct.get_last_error())
       data=ct.create_string_buffer(length)
       if length: gdi.GetGlyphOutlineW(dc,ord(character),258,ct.byref(metrics),length,data,ct.byref(matrix))
       glyphs[cache_key]=(outline(data.raw) if length else '',metrics)
      path,metrics=glyphs[cache_key]
      if path:
       parts.append((advance,path))
       x=advance+metrics.origin.x/SCALE; y=-metrics.origin.y/SCALE
       bounds.append((x,y,x+metrics.width/SCALE,y+metrics.height/SCALE))
      advance+=metrics.advance_x/SCALE
     left=min(b[0] for b in bounds); right=max(b[2] for b in bounds)
     x=float(label.get('x'))-left
     if label.get('text-anchor')=='middle': x-=(right-left)/2
     y=float(label.get('y'))
     if label.get('data-center')=='true': y-=(min(b[1] for b in bounds)+max(b[3] for b in bounds))/2
     group=ET.Element('{'+NS+'}g',{'fill':label.get('fill','#263126'),'transform':f'translate({x:.3f} {y:.3f})'})
     for start,path in parts:
      ET.SubElement(group,'{'+NS+'}path',{'transform':f'translate({start:.3f} 0) scale({1/SCALE} {-1/SCALE})','d':path})
     parent.insert(list(parent).index(label),group); parent.remove(label)
   tree.write(file,encoding='unicode')
 finally:
  if initial: gdi.SelectObject(dc,initial)
  for font in fonts.values(): gdi.DeleteObject(font)
  gdi.DeleteDC(dc)

if __name__=='__main__': convert([Path(file) for file in sys.argv[1:]])
