"""Deterministic, character-free Deal faces. Rules text is fixed; names stay live."""
from pathlib import Path
import json, math, html, textwrap

ROOT = Path(__file__).resolve().parents[1]
INK = '#263126'
PAPER = '#fffef7'
PASTELS = {'money-1':'#e5df9b','money-2':'#e9c3a9','money-3':'#ced3b1',
 'money-4':'#abcfd9','money-5':'#b49ac6','money-10':'#f0c143',
 'deal-breaker':'#c0a7ca','just-say-no':'#abd4db','birthday':'#e6c6b2',
 'hotel':'#b8d5db','double-rent':'#eae0a4'}

def text(x,y,value,size=12,anchor='middle',fill=INK):
 return f'<text x="{x}" y="{y}" font-family="Arial" font-weight="bold" font-size="{size}" text-anchor="{anchor}" fill="{fill}">{html.escape(str(value))}</text>'

def rect(x,y,w,h,fill,stroke=INK,rx=0):
 return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="1.2"/>'

def badge(x,y,value):
 return f'<circle cx="{x}" cy="{y}" r="18" fill="{PAPER}" stroke="{INK}" stroke-width="1.3"/>'+text(x,y+5,f'M{value}',13)

def frame(tint=None):
 s=rect(1,1,238,358,PAPER,'#c7c8ba',12)+rect(14,14,212,332,tint or PAPER,INK,1)
 if tint:
  s+=rect(22,22,196,316,'none')+rect(27,27,186,306,'none')
  for x in range(30,209,6): s+=rect(x,24,3,4,'none')+rect(x,332,3,4,'none')
  for y in range(31,327,6): s+=rect(24,y,4,3,'none')+rect(212,y,4,3,'none')
 return s

def rent_table(group,groups,y=142,spacing=41):
 g=groups[group]; s=text(188,y-21,'RENT',18)
 s+=text(57,y-20,'PROPERTIES',7)+text(57,y-10,'IN THIS SET',7)
 for i,value in enumerate(g['rent'],1):
  yy=y+(i-1)*spacing
  for j in range(i-1,-1,-1): s+=rect(49-j*4,yy-8-j*3,20,26,PAPER)+rect(49-j*4,yy-8-j*3,20,5,g['color'])
  s+=text(59,yy+12,i,13)
  s+=f'<path d="M77 {yy+7}H162" stroke="{INK}" stroke-width=".8" stroke-dasharray="2 2"/>'
  if i==len(g['rent']): s+=text(111,yy+2,'FULL SET',8)
  s+=text(184,yy+12,f'M{value}',16)
 return s

def generate():
 definition=json.loads((ROOT/'cards.json').read_text(encoding='utf-8'))
 groups=definition['groups']; unique={c['key']:c for c in definition['cards']}
 for key,c in unique.items():
  kind=c['kind']; s=frame()
  if kind=='property':
   s+=rect(25,30,190,55,groups[c['colors'][0]]['color'])
   s+=badge(32,32,c['value'])+rent_table(c['colors'][0],groups)
  elif kind=='wild':
   if len(c['colors'])==2:
    for index,color in enumerate(c['colors']):
     half=rect(25,29,190,51,groups[color]['color'])+text(120,48,'PROPERTY',10)+text(120,66,'WILD CARD',20)
     g=groups[color]
     for i,value in enumerate(g['rent'],1):
      yy=103+(i-1)*18
      half+=text(63,yy,i,10)+text(183,yy,f'M{value}',11)
      half+=f'<path d="M77 {yy-3}H152" stroke="{INK}" stroke-dasharray="2 2"/>'
     half+=badge(30,30,c['value'])
     s+=f'<g transform="rotate({180*index} 120 180)">{half}</g>'
    s+='<path d="M43 180H197" stroke="#aaa99a" stroke-width=".7"/>'
   else:
    for yy in [33,80]:
     for i,g in enumerate(groups.values()):s+=rect(26+i*18.8,yy,18.8,17,g['color'])
    s+=text(120,71,'PROPERTY WILD CARD',16)
    s+='<g fill="none" stroke="#70835c" stroke-width="2">'
    for i,g in enumerate(groups.values()):
     s+=f'<g transform="rotate({(i-4.5)*9} 120 254)">'+rect(82,143,76,109,PAPER)+rect(88,150,64,23,g['color'])+'</g>'
    s+='</g>'+text(120,293,'ANY PROPERTY SET',13)+text(120,311,'NO MONETARY VALUE',10)
  else:
   s=frame(PASTELS.get(key,'#d9dec1' if kind!='rent' else '#e9e0ac'))
   if kind=='money':
    s+='<ellipse cx="120" cy="180" rx="73" ry="93" fill="none" stroke="'+INK+'" stroke-width="2"/>'
    s+='<g transform="rotate(90 120 180)">'+text(120,195,f'M{c["value"]}',55)+'</g>'
   else:
    s+=text(120,67,'ACTION CARD',14)
    s+='<circle cx="120" cy="177" r="69" fill="'+PAPER+'" stroke="'+INK+'" stroke-width="3"/>'
    if kind=='rent':
     colors=c['colors']
     for i,color in enumerate(colors):
      a=i*math.tau/len(colors)-math.pi/2;b=(i+1)*math.tau/len(colors)-math.pi/2
      x,y=120+62*math.cos(a),177+62*math.sin(a);xx,yy=120+62*math.cos(b),177+62*math.sin(b)
      s+=f'<path d="M{x} {y}A62 62 0 0 1 {xx} {yy}" stroke="{groups[color]["color"]}" fill="none" stroke-width="13"/>'
    if kind in ['house','hotel']:
     color='#228147' if kind=='house' else '#da4233'
     s+=f'<path d="M79 169L120 143L161 169L151 176V198H89V176Z" fill="{color}"/>'
    if kind=='pass-go':s+='<path d="M167 215H81V209L64 221L81 233V227H167L160 221Z" fill="#d53b2c" stroke="'+INK+'"/>'
    if kind=='birthday':
     s+='<path d="M106 207V224Q120 232 134 224V207ZM109 204V196M120 204V196M131 204V196" fill="none" stroke="'+INK+'" stroke-width="2"/>'
    detail={'just-say-no':'Use against an action played against you. Play into the center.',
     'double-rent':'Play with a Rent card. Each card uses one play.',
     'rent':'All players pay rent on properties you own in one of these colors.' if len(c['colors'])==2 else 'Choose one player to pay rent on any property set you own.'}.get(kind,c['detail'])
    for i,line in enumerate(textwrap.wrap(detail,33)[:4]):s+=text(120,270+i*13,line,9)
   s+=badge(29,30,c['value'])+'<g transform="rotate(180 120 180)">'+badge(29,30,c['value'])+'</g>'
  (ROOT/'art'/f'{key}.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="240" height="360" viewBox="0 0 240 360">'+s+'</svg>',encoding='utf-8')
 for c in definition['cards']:c['layout']='deal'
 (ROOT/'cards.json').write_text(json.dumps(definition,indent=2)+'\n',encoding='utf-8')
 slots=json.loads((ROOT/'theme-slots.json').read_text(encoding='utf-8'))
 for slot in slots['slots']:
  if slot['id'] in unique:slot['preview']={**unique[slot['id']], 'layout':'deal','color':groups[unique[slot['id']]['colors'][0]]['color'] if unique[slot['id']]['colors'] else '#17594d'}
 (ROOT/'theme-slots.json').write_text(json.dumps(slots,indent=2)+'\n',encoding='utf-8')
 back=rect(1,1,238,358,PAPER,'#a9a18a',12)+rect(11,11,218,338,'#192c41','#bca36a',7)+rect(18,18,204,324,'none','#bca36a',4)
 back+='<defs><pattern id="weave" width="12" height="12" patternUnits="userSpaceOnUse"><path d="M0 0L12 12M0 12L12 0" stroke="#85939c" stroke-width=".55" opacity=".35"/></pattern></defs>'+rect(24,24,192,312,'url(#weave)','#526478',2)
 back+=rect(33,137,174,81,'#c93336','#fffaf0',2)+text(120,169,'MONOPOLY',24,fill='#fffaf0')+text(120,204,'DEAL',35,fill='#fffaf0')
 (ROOT/'art/back.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="240" height="360">'+back+'</svg>',encoding='utf-8')
 title=rect(3,3,465,106,'#cb3035','#fffaf0',3)+rect(480,3,197,106,'#cb3035','#fffaf0',3)
 title+=text(235,79,'MONOPOLY',62,fill='#fffaf0')+text(578,79,'DEAL',61,fill='#fffaf0')
 (ROOT/'art/title.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="680" height="112">'+title+'</svg>',encoding='utf-8')

if __name__=='__main__': generate()
