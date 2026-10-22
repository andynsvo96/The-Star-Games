"""Deterministic, character-free Deal faces. Rules text is fixed; names stay live."""
from pathlib import Path
import json, math, html, textwrap, subprocess

ROOT = Path(__file__).resolve().parents[1]
INK = '#263126'
PAPER = '#fffef7'
PASTELS = {'money-1':'#e5df9b','money-2':'#e9c3a9','money-3':'#ced3b1',
 'money-4':'#abcfd9','money-5':'#b49ac6','money-10':'#f0c143',
 'deal-breaker':'#c0a7ca','just-say-no':'#abd4db','birthday':'#e6c6b2',
 'hotel':'#b8d5db','double-rent':'#eae0a4'}

def text(x,y,value,size=12,anchor='middle',fill=INK,weight='bold'):
 return f'<text x="{x}" y="{y}" font-family="Arial" font-weight="{weight}" font-size="{size}" text-anchor="{anchor}" fill="{fill}">{html.escape(str(value))}</text>'

def rect(x,y,w,h,fill,stroke=INK,rx=0):
 return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="1.2"/>'

def badge(x,y,value):
 return f'<circle cx="{x}" cy="{y}" r="18" fill="{PAPER}" stroke="{INK}" stroke-width="1.3"/>'+text(x,y+5,f'${value}',16)

def header_ink(color):
 rgb=[int(color[i:i+2],16)/255 for i in (1,3,5)]
 lum=sum((v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4)*weight for v,weight in zip(rgb,(.2126,.7152,.0722)))
 return '#ffffff' if lum < .20 else INK

def frame(tint=None):
 s=rect(1,1,238,358,PAPER,'#c7c8ba',12)+rect(14,14,212,332,tint or PAPER,INK,1)
 if tint:
  s+=rect(22,22,196,316,'none')+rect(27,27,186,306,'none')
  for x in range(30,209,6): s+=rect(x,24,3,4,'none')+rect(x,332,3,4,'none')
  for y in range(31,327,6): s+=rect(24,y,4,3,'none')+rect(212,y,4,3,'none')
 return s

def rent_table(group,groups,y=147):
 g=groups[group]; spacing=48; y=141
 s=text(184,y-30,'RENT',25)
 s+=text(59,y-29,'CARDS',12)+text(59,y-15,'IN SET',12)
 for i,value in enumerate(g['rent'],1):
  yy=y+(i-1)*spacing
  for j in range(i-1,-1,-1): s+=rect(45-j*4,yy-8-j*3,28,36,PAPER)+rect(45-j*4,yy-8-j*3,28,7,g['color'])
  s+=text(59,yy+20,i,24)
  s+=f'<path d="M83 {yy+11}H153" stroke="{INK}" stroke-width=".8" stroke-dasharray="2 2"/>'
  if i==len(g['rent']): s+=text(117,yy,'FULL SET',11)
  s+=text(184,yy+19,f'${value}',25)
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
     ink=header_ink(groups[color]['color'])
     half=rect(25,29,190,51,groups[color]['color'])+text(128,48,'PROPERTY',14,fill=ink)+text(128,71,'WILD CARD',23,fill=ink)
     g=groups[color]
     for i,value in enumerate(g['rent'],1):
      yy=102+(i-1)*21
      half+=rect(47,yy-14,23,19,PAPER)+text(59,yy+1,i,15)+text(181,yy+1,f'${value}',17)
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
    amount=text(120,180,f'${c["value"]}',94 if c['value']==10 else 104).replace('<text ', '<text data-center="true" ')
    s+='<g transform="rotate(90 120 180)">'+amount+'</g>'
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
    if kind=='pass-go':s+='<path d="M157 214H88V209L76 219L88 229V224H157L151 219Z" fill="#d53b2c" stroke="'+INK+'"/>'
    if kind=='birthday':
     s+='<path d="M106 207V224Q120 232 134 224V207ZM109 204V196M120 204V196M131 204V196" fill="none" stroke="'+INK+'" stroke-width="2"/>'
    detail={'deal-breaker':'Take a complete set from another player, including buildings.',
     'forced-deal':'Swap one of your properties for an opponent\'s property. Cannot take from a full set.',
     'sly-deal':'Steal one property. Cannot take from a full set.',
     'just-say-no':'Cancel an action against you. May counter another No.',
     'debt-collector':'Choose one player. They pay you $5.',
     'birthday':'Every other player pays you $2.',
     'double-rent':'Use with a Rent card. Double the amount owed. Uses one extra play.',
     'house':'Add to a full street set. Adds $3 to its rent.',
     'hotel':'Needs a House on a full street set. Adds $4 rent.',
     'pass-go':'Draw two cards.',
     'rent':'Every other player pays rent on one matching group.' if len(c['colors'])==2 else 'Choose one player to pay rent on any group you own.'}[kind]
    lines=textwrap.wrap(detail,23)
    assert len(lines)<=5,(key,lines)
    for i,line in enumerate(lines):s+=text(120,263+i*(15 if len(lines)>3 else 16),line,14 if len(lines)>3 else 15)
   s+=badge(29,30,c['value'])+'<g transform="rotate(180 120 180)">'+badge(29,30,c['value'])+'</g>'
  (ROOT/'art'/f'{key}.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="240" height="360" viewBox="0 0 240 360">'+s+'</svg>',encoding='utf-8')
 # Faces only: never regenerate the database, theme metadata, backs or scenery.
 generate_help()
 subprocess.run([__import__('sys').executable,str(ROOT/'art/outline_text.py'),
  *[str(ROOT/'art'/f'{key}.svg') for key in [*unique,'help-front','help-back']]],check=True)

def generate_help():
 pages=[('help-front','QUICK START RULES',[
  ('AIM','Be the first to collect 3 complete property sets of different colors.'),
  ('GET READY','Deal 5 cards to each player. Put the rest face down as the draw pile. The first seat starts; replay rotates the starter.'),
  ('PLAY! ON YOUR TURN','1. Draw 2 cards, or 5 if you begin with an empty hand.'),
  ('','2. Play up to 3 cards in any combination:'),
  ('','BANK money or action cards. Their printed value is added to your bank.'),
  ('','ADD property cards face up in front of you. Properties cannot be banked.'),
  ('','PLAY action cards into the center to use their effect.'),
  ('TIP','Keep your bank well stocked. You never know when you will need to pay!')]),
 ('help-back','ESSENTIAL RULES',[
  ('ENDING YOUR TURN','Press End Turn after up to 3 plays. Discard to 7. Default timer: 1 minute. At timeout, finish pending effects, discard excess lowest value first, then end. Settings and other players\' decisions pause time.'),
  ('1. CARDS ON THE TABLE','Never put banked or played cards back into your hand.'),
  ('2. PAYING OTHER PLAYERS','Pay from your bank, properties or buildings. Never pay from your hand. No change: owe $2, pay $3, they keep $3. If short, pay all assets with a value. If you have none, pay nothing.'),
  ('3. WILD PROPERTIES','Rearrange played properties on your turn without using a play. A zero-value wild cannot pay debts or be banked.'),
  ('4. BUILDINGS','Full street sets: House +$3 rent; Hotel +$4 more, needs a House. None on railroads or utilities.'),
  ('5. JUST SAY NO','Cancel an action or counter another No. Uses a play on your own turn.'),
  ('RENT DOUBLES','Choose Use with Rent, then open Rent. Each double uses another play.')])]
 for key,title,sections in pages:
  content=rect(2,2,476,716,PAPER,'#b6b8ad',22)+rect(21,22,438,54,'#e0e0da')+rect(21,22,14,54,'#c63232')+text(246,61,title,30)
  y=100
  for heading,body in sections:
   if heading:content+=text(30,y,heading,18,'start');y+=22
   for line in textwrap.wrap(body,49):content+=text(30,y,line,17,'start',weight='normal');y+=20
   y+=7
  assert y<714,(key,y)
  (ROOT/'art'/f'{key}.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="480" height="720">'+content+'</svg>',encoding='utf-8')

if __name__=='__main__': generate()
