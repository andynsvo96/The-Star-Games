"""Original offline vector art, fixed classic card inventory and cosmetic slots."""
from pathlib import Path
import json, math, wave, struct
ROOT = Path(__file__).resolve().parents[1]
GROUPS = {
 'brown': ('Brown', '#965b37', [1,2],1,['Mediterranean Avenue','Baltic Avenue']),
 'light-blue': ('Light blue','#65c7e8',[1,2,3],1,['Oriental Avenue','Vermont Avenue','Connecticut Avenue']),
 'pink': ('Pink','#cf559b',[1,2,4],2,['St. Charles Place','States Avenue','Virginia Avenue']),
 'orange': ('Orange','#ed952e',[1,3,5],2,['St. James Place','Tennessee Avenue','New York Avenue']),
 'red': ('Red','#dc403d',[2,3,6],3,['Kentucky Avenue','Indiana Avenue','Illinois Avenue']),
 'yellow': ('Yellow','#edcf3d',[2,4,6],3,['Atlantic Avenue','Ventnor Avenue','Marvin Gardens']),
 'green': ('Green','#299565',[2,4,7],4,['Pacific Avenue','North Carolina Avenue','Pennsylvania Avenue']),
 'dark-blue': ('Dark blue','#225392',[3,8],4,['Park Place','Boardwalk']),
 'railroad': ('Railroad','#3b4149',[1,2,3,4],2,['Reading Railroad','Pennsylvania Railroad','B. & O. Railroad','Short Line']),
 'utility': ('Utility','#8b9694',[1,2],2,['Electric Company','Water Works'])
}
cards=[]; slots=[]
def svg(name, content):
 path=ROOT/'art'/f'{name}.svg';path.parent.mkdir(parents=True,exist_ok=True)
 path.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="240" height="180" viewBox="0 0 240 180">'+content+'</svg>',encoding='utf-8')
def slot(key,label,group,path,kind='image',**extra):
 face=next((card for card in cards if card['key']==key),None)
 if face:
  extra['preview']=dict(name=face['name'],value=face['value'],detail=face['detail'],color=GROUPS[face['colors'][0]][1] if face['colors'] else '#17594d')
 slots.append(dict(id=key,label=label,group=group,path=f'Games/monopoly-deal/{path}',kind=kind,**extra))
def add(key,name,kind,value,n=1,colors=None,detail=''):
 for _ in range(n): cards.append(dict(id=len(cards),key=key,name=name,kind=kind,value=value,currency="USD",colors=colors or [],detail=detail))
def icon(key,color,mode):
 base='<defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#bce4e9"/><stop offset="1" stop-color="#fff0c9"/></linearGradient></defs><rect width="240" height="180" rx="8" fill="url(#sky)"/><circle cx="185" cy="35" r="20" fill="#ffedb1"/><path d="M0 142 Q45 125 90 144 T240 137 V180 H0" fill="#609889"/>'
 if mode=='railroad': shape='<path d="M38 157L82 100H158L203 157M66 145H175M77 128H162" fill="none" stroke="#745c46" stroke-width="8"/><rect x="74" y="58" width="91" height="71" rx="15" fill="#374b52"/><path d="M87 58V36H151V58" fill="#566e72"/><circle cx="120" cy="101" r="23" fill="#d6af62"/><circle cx="120" cy="101" r="14" fill="#4b5c5d"/><circle cx="96" cy="135" r="12" fill="#25373b"/><circle cx="148" cy="135" r="12" fill="#25373b"/>'
 elif mode=='utility': shape='<path d="M97 117C65 91 79 40 120 40S175 91 143 117L140 138H100Z" fill="#ffed98" stroke="#8a7943" stroke-width="5"/><path d="M101 144H140M105 154H136M114 163H129" stroke="#7c8683" stroke-width="7"/><path d="M110 126L104 91L120 101L136 91L130 126" fill="none" stroke="#bf9842" stroke-width="4"/>'
 else:
  shape=''
  for i,(x,h) in enumerate([(25,69),(74,96),(132,74),(181,108)]):
   shape+=f'<rect x="{x}" y="{150-h}" width="39" height="{h}" rx="2" fill="{color}"/><path d="M{x-4} {150-h}L{x+19} {132-h}L{x+43} {150-h}" fill="#79533a"/>'
   for y in range(160-h,137,21):
    shape+=f'<rect x="{x+8}" y="{y}" width="8" height="12" fill="#ffedb1"/><rect x="{x+25}" y="{y}" width="8" height="12" fill="#ffedb1"/>'
  shape+='<path d="M0 157H240" stroke="#d4b58c" stroke-width="18"/>'
 svg(key,base+shape)
for group,(label,color,rent,value,names) in GROUPS.items():
 for name in names:
  key=name.lower().replace(' & ','-and-').replace('.','').replace(' ','-')
  add(key,name,'property',value,colors=[group],detail=f'{len(rent)} for a full set')
  icon(key,color,group);slot(key,name,'Properties / '+label,'art/'+key+'.svg',display_name=name)
wilds=[(['light-blue','brown'],1,1),(['light-blue','railroad'],4,1),(['pink','orange'],2,2),(['red','yellow'],3,2),(['dark-blue','green'],4,1),(['green','railroad'],4,1),(['railroad','utility'],2,1),(list(GROUPS),0,2)]
for colors,value,count in wilds:
 key='wild-'+('-'.join(colors) if len(colors)==2 else 'any');name=' / '.join(GROUPS[c][0] for c in colors) if len(colors)==2 else 'Any Property'
 add(key,name,'wild',value,count,colors,'Choose a property group')
 content=''.join(f'<rect x="{i*240/len(colors):g}" width="{240/len(colors):g}" height="180" fill="{GROUPS[c][1]}"/>' for i,c in enumerate(colors))+'<path d="M120 30L137 70L183 74L148 104L159 149L120 125L81 149L92 104L57 74L103 70Z" fill="#fff3cf"/>'
 svg(key,content);slot(key,name,'Rent & Wilds','art/'+key+'.svg')
actions=[('deal-breaker','Deal Breaker',5,2,'Take a complete property set, including buildings.'),('forced-deal','Forced Deal',3,3,'Exchange one of your properties for an opponent\'s incomplete-set property.'),('sly-deal','Sly Deal',3,3,'Take one property outside a complete set.'),('just-say-no','Just Say No',4,3,'Cancel an action played against you, or counter a Just Say No. Uses a play on your own turn.'),('debt-collector','Debt Collector',3,3,'One opponent owes you $5.'),('birthday',"It’s My Birthday",2,3,'Every opponent owes you $2.'),('double-rent','Double the Rent',1,2,'Play with a Rent card. Each card uses one play.'),('house','House',3,3,'Add $3 rent to a complete street set.'),('hotel','Hotel',4,2,'Add $4 rent to a street set with a House.'),('pass-go','Pass Go',1,10,'Draw two cards.')]
for key,name,value,count,detail in actions:
 add(key,name,key,value,count,detail=detail)
 symbol={'deal-breaker':'★','forced-deal':'↔','sly-deal':'↗','just-say-no':'NO','debt-collector':'$5','birthday':'$2','double-rent':'×2','house':'⌂','hotel':'H','pass-go':'GO'}[key]
 svg(key,f'<rect width="240" height="180" rx="10" fill="#e2e8d5"/><circle cx="120" cy="90" r="67" fill="#135b4d"/><text x="120" y="112" text-anchor="middle" font-family="sans-serif" font-weight="bold" font-size="54" fill="#fff0cd">{symbol}</text>')
 slot(key,name,'Actions','art/'+key+'.svg',display_name=name)
for colors in [['light-blue','brown'],['pink','orange'],['red','yellow'],['dark-blue','green'],['railroad','utility'],list(GROUPS)]:
 key='rent-'+('-'.join(colors) if len(colors)==2 else 'any');name='Rent' if len(colors)==2 else 'Any Rent'
 add(key,name,'rent',1 if len(colors)==2 else 3,2 if len(colors)==2 else 3,colors,'All opponents pay' if len(colors)==2 else 'Choose one opponent')
 svg(key,''.join(f'<rect x="{i*240/len(colors):g}" width="{240/len(colors):g}" height="180" fill="{GROUPS[c][1]}"/>' for i,c in enumerate(colors))+'<circle cx="120" cy="90" r="55" fill="#fff4d5"/><text x="120" y="109" text-anchor="middle" font-family="sans-serif" font-size="48" fill="#294e44">M</text>');slot(key,name,'Rent & Wilds','art/'+key+'.svg')
for value,count in [(1,6),(2,5),(3,3),(4,3),(5,2),(10,1)]:
 key=f'money-{value}';add(key,f'${value}','money',value,count,detail='Add to your bank')
 svg(key,f'<rect width="240" height="180" rx="9" fill="#c5dfc2"/><rect x="10" y="10" width="220" height="160" rx="8" fill="none" stroke="#688c68" stroke-width="3"/><ellipse cx="120" cy="90" rx="80" ry="60" fill="#eff0ce"/><text x="120" y="111" text-anchor="middle" font-family="serif" font-weight="bold" font-size="64" fill="#215b44">${value}</text>');slot(key,f'${value}','Money','art/'+key+'.svg')
svg('back','<rect width="240" height="180" rx="10" fill="#183b48"/><rect x="10" y="10" width="220" height="160" rx="8" fill="none" stroke="#c8b27d" stroke-width="3"/><circle cx="120" cy="90" r="62" fill="none" stroke="#738e8f" stroke-width="2"/><text x="120" y="112" text-anchor="middle" font-family="serif" font-weight="bold" font-size="70" fill="#d8c899">M</text>');slot('back','Card back','Card backs','art/back.svg')
(ROOT/'art/back.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="180" height="270"><rect width="180" height="270" rx="12" fill="#183b48"/><rect x="10" y="10" width="160" height="250" rx="9" fill="none" stroke="#c8b27d" stroke-width="3"/><circle cx="90" cy="135" r="58" fill="none" stroke="#738e8f" stroke-width="2"/><path d="M57 167V103L90 145L123 103V167" fill="none" stroke="#d8c899" stroke-width="9" stroke-linejoin="round"/></svg>',encoding='utf-8')
table='<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1000"><defs><radialGradient id="felt"><stop stop-color="#14684f"/><stop offset="1" stop-color="#05392e"/></radialGradient><linearGradient id="wood" x2="0" y2="1"><stop stop-color="#71492d"/><stop offset=".5" stop-color="#39281c"/><stop offset="1" stop-color="#8e6138"/></linearGradient><pattern id="grain" width="11" height="11" patternUnits="userSpaceOnUse"><path d="M0 0L11 $11-5 5L5 15" stroke="#c5d7a4" stroke-opacity=".035"/></pattern></defs><rect width="1600" height="1000" fill="url(#wood)"/><rect x="22" y="22" width="1556" height="956" rx="45" fill="url(#felt)" stroke="#bd9660" stroke-width="4"/><rect x="26" y="26" width="1548" height="948" rx="43" fill="url(#grain)"/></svg>'
(ROOT/'art/table.svg').write_text(table,encoding='utf-8');slot('background','Table & background','Table & UI','art/table.svg','background')
title='<svg xmlns="http://www.w3.org/2000/svg" width="680" height="112"><rect x="4" y="4" width="672" height="104" rx="8" fill="#c92f35" stroke="#fff3d7" stroke-width="5"/><text x="340" y="77" text-anchor="middle" font-family="sans-serif" font-weight="bold" font-size="61" fill="#fffaf0">MONOPOLY DEAL</text></svg>'
(ROOT/'art/title.svg').write_text(title,encoding='utf-8');slot('title','Title','Table & UI','art/title.svg')
thumbnail='<svg xmlns="http://www.w3.org/2000/svg" width="240" height="180"><rect width="240" height="180" rx="22" fill="#135b4d"/><g transform="translate(33 30) rotate(-14 45 66)"><rect width="82" height="125" rx="8" fill="#fff1d1" stroke="#b38e57" stroke-width="3"/><rect x="6" y="7" width="70" height="25" rx="3" fill="#225392"/><path d="M20 92V63H61V92M14 63L41 42L68 63" fill="#225392"/></g><g transform="translate(119 29) rotate(13 45 66)"><rect width="82" height="125" rx="8" fill="#fff1d1" stroke="#b38e57" stroke-width="3"/><rect x="6" y="7" width="70" height="25" rx="3" fill="#ed952e"/><path d="M20 92V63H61V92M14 63L41 42L68 63" fill="#ed952e"/></g><circle cx="120" cy="116" r="33" fill="#d7b765" stroke="#fff0bd" stroke-width="4"/><path d="M106 133V100L120 119L134 100V133" fill="none" stroke="#765023" stroke-width="6"/></svg>'
(ROOT/'thumbnail.svg').write_text(thumbnail,encoding='utf-8');slot('thumbnail','Game icon','Table & UI','thumbnail.svg')
foley = {
 'deal': ('Shuffle / deal', 'card-shuffle.ogg'),
 'play': ('Play / discard', 'card-place-1.ogg'),
 'bank': ('Bank / payment', 'card-place-2.ogg'),
 'action': ('Draw / move', 'card-slide-1.ogg'),
}
for cue,freq in [('deal',420),('play',560),('bank',740),('action',330),('win',880)]:
 path=ROOT/'audio'/f'{cue}.wav';path.parent.mkdir(exist_ok=True)
 with wave.open(str(path),'wb') as sound:
  sound.setparams((1,2,22050,0,'NONE','not compressed'));duration=.5 if cue=='win' else .12
  data=[int(5000*math.exp(-7*i/(22050*duration))*math.sin(2*math.pi*freq*i/22050)) for i in range(int(22050*duration))]
  sound.writeframes(struct.pack('<'+'h'*len(data),*data))
 # Keep the original tones as source history; bundled CC0 recordings handle cards.
 label, filename = foley.get(cue, (cue.capitalize(), f'{cue}.wav'))
 slot('sound-'+cue,label,'Audio',f'audio/{filename}','audio')
groupdata={key:dict(name=v[0],color=v[1],rent=v[2],size=len(v[2])) for key,v in GROUPS.items()}
(ROOT/'cards.json').write_text(json.dumps(dict(groups=groupdata,cards=cards),indent=2)+'\n',encoding='utf-8')
(ROOT/'theme-slots.json').write_text(json.dumps(dict(schema_version=1,slots=slots),indent=2)+'\n',encoding='utf-8')
default=ROOT/'themes/default';default.mkdir(parents=True,exist_ok=True)
(default/'theme.json').write_text(json.dumps(dict(schema_version=1,id='default',name='Default',assets={},labels={}),indent=2)+'\n',encoding='utf-8')
assert len(cards)==106
from classic_faces import generate
generate()
print(f'Generated {len(cards)} cards and {len(slots)} cosmetic slots')
