"""Independent US Classic data and portable vector art. Rules: Hasbro US C1009 (2017).

Development uses Windows GDI for outlined lettering. Runtime needs no fonts or
Python. No Deal deck data or face generator is used or modified.
"""
from pathlib import Path
import html, json, math, shutil, struct, subprocess, sys, textwrap, wave
ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT.parents[1]
ART=ROOT/'art'
ORIGINALS=PROJECT/'asset/monopoly-classic/originals'
PAPER,INK='#fffef7','#263126'
GROUPS={'brown':('#965b37',50),'light-blue':('#73c6e5',50),'pink':('#d7579e',100),'orange':('#ed922c',100),'red':('#d5393f',150),'yellow':('#f2d449',150),'green':('#279354',200),'dark-blue':('#244695',200),'railroad':('#343c46',0),'utility':('#a9b7a0',0)}
PROPERTIES=[
 (1,'Mediterranean Avenue','brown',60,[2,10,30,90,160,250]),
 (3,'Baltic Avenue','brown',60,[4,20,60,180,320,450]),
 (5,'Reading Railroad','railroad',200,[25,50,100,200]),
 (6,'Oriental Avenue','light-blue',100,[6,30,90,270,400,550]),
 (8,'Vermont Avenue','light-blue',100,[6,30,90,270,400,550]),
 (9,'Connecticut Avenue','light-blue',120,[8,40,100,300,450,600]),
 (11,'St. Charles Place','pink',140,[10,50,150,450,625,750]),
 (12,'Electric Company','utility',150,[4,10]),
 (13,'States Avenue','pink',140,[10,50,150,450,625,750]),
 (14,'Virginia Avenue','pink',160,[12,60,180,500,700,900]),
 (15,'Pennsylvania Railroad','railroad',200,[25,50,100,200]),
 (16,'St. James Place','orange',180,[14,70,200,550,750,950]),
 (18,'Tennessee Avenue','orange',180,[14,70,200,550,750,950]),
 (19,'New York Avenue','orange',200,[16,80,220,600,800,1000]),
 (21,'Kentucky Avenue','red',220,[18,90,250,700,875,1050]),
 (23,'Indiana Avenue','red',220,[18,90,250,700,875,1050]),
 (24,'Illinois Avenue','red',240,[20,100,300,750,925,1100]),
 (25,'B. & O. Railroad','railroad',200,[25,50,100,200]),
 (26,'Atlantic Avenue','yellow',260,[22,110,330,800,975,1150]),
 (27,'Ventnor Avenue','yellow',260,[22,110,330,800,975,1150]),
 (28,'Water Works','utility',150,[4,10]),
 (29,'Marvin Gardens','yellow',280,[24,120,360,850,1025,1200]),
 (31,'Pacific Avenue','green',300,[26,130,390,900,1100,1275]),
 (32,'North Carolina Avenue','green',300,[26,130,390,900,1100,1275]),
 (34,'Pennsylvania Avenue','green',320,[28,150,450,1000,1200,1400]),
 (35,'Short Line','railroad',200,[25,50,100,200]),
 (37,'Park Place','dark-blue',350,[35,175,500,1100,1300,1500]),
 (39,'Boardwalk','dark-blue',400,[50,200,600,1400,1700,2000])]

def event(deck,slug,name,detail,effect,**values):
 return dict(key=f'{deck}-{slug}',name=name,detail=detail,effect=effect,**values)

CHANCE=[
 event('chance','go','Advance to GO','Move to GO and collect $200.','move',destination=0),
 event('chance','illinois','Illinois Avenue','Advance to Illinois Avenue. Collect $200 if you pass GO.','move',destination=24),
 event('chance','st-charles','St. Charles Place','Advance to St. Charles Place. Collect $200 if you pass GO.','move',destination=11),
 event('chance','utility','Nearest Utility','Advance to the next utility. If owned, pay ten times a fresh dice roll.','utility'),
 event('chance','railroad-a','Nearest Railroad','Advance to the next railroad. If owned, pay twice its normal rent.','railroad'),
 event('chance','railroad-b','Nearest Railroad','Advance to the next railroad. If owned, pay twice its normal rent.','railroad'),
 event('chance','dividend','Bank Dividend','Receive a $50 dividend from the Bank.','receive',amount=50),
 event('chance','jail-free','Get Out of Jail Free','Keep this card until used or traded.','jail_free'),
 event('chance','back-three','Back Three Spaces','Move back three spaces and resolve that space.','back',amount=3),
 event('chance','jail','Go to Jail','Go directly to Jail. Do not collect money for passing GO.','jail'),
 event('chance','repairs','General Repairs','Pay $25 per house and $100 per hotel you own.','repairs',house=25,hotel=100),
 event('chance','fine','Speeding Fine','Pay a $15 fine to the Bank.','pay',amount=15),
 event('chance','reading','Reading Railroad','Advance to Reading Railroad. Collect $200 if you pass GO.','move',destination=5),
 event('chance','boardwalk','Boardwalk','Advance to Boardwalk.','move',destination=39),
 event('chance','chairman','Elected Chairman','Pay every other player $50.','pay_each',amount=50),
 event('chance','loan','Building Loan','Your building loan matures. Receive $150.','receive',amount=150)]
COMMUNITY=[
 event('community','go','Advance to GO','Move to GO and collect $200.','move',destination=0),
 event('community','bank-error','Bank Error','A bank error is in your favor. Receive $200.','receive',amount=200),
 event('community','doctor','Doctor Fee','Pay $50 for a doctor visit.','pay',amount=50),
 event('community','stock','Stock Sale','Receive $50 from selling stock.','receive',amount=50),
 event('community','jail-free','Get Out of Jail Free','Keep this card until used or traded.','jail_free'),
 event('community','jail','Go to Jail','Go directly to Jail. Do not collect money for passing GO.','jail'),
 event('community','holiday','Holiday Fund','Your holiday fund matures. Receive $100.','receive',amount=100),
 event('community','refund','Tax Refund','Receive a $20 income tax refund.','receive',amount=20),
 event('community','birthday','Birthday','Receive $10 from every other player.','receive_each',amount=10),
 event('community','insurance','Life Insurance','Your life insurance matures. Receive $100.','receive',amount=100),
 event('community','hospital','Hospital Fees','Pay $100 in hospital fees.','pay',amount=100),
 event('community','school','School Fees','Pay $50 in school fees.','pay',amount=50),
 event('community','consultancy','Consultancy Fee','Receive a $25 consultancy fee.','receive',amount=25),
 event('community','repairs','Street Repairs','Pay $40 per house and $115 per hotel you own.','repairs',house=40,hotel=115),
 event('community','beauty','Beauty Contest','Receive a $10 beauty contest prize.','receive',amount=10),
 event('community','inheritance','Inheritance','Receive an inheritance of $100.','receive',amount=100)]

def text(x,y,value,size=13,anchor='middle',fill=INK):
 if not str(value):return ''
 return f'<text x="{x}" y="{y}" font-family="Arial" font-weight="bold" font-size="{size}" text-anchor="{anchor}" fill="{fill}">{html.escape(str(value))}</text>'
def rect(x,y,w,h,fill,stroke=INK,rx=0):
 return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="1.2"/>'
def svg(body,w=240,h=360):
 return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>'
def write(name,body,w=240,h=360):
 (ART/name).write_text(svg(body,w,h),encoding='utf-8')
def frame(tint=PAPER):
 return rect(1,1,238,358,PAPER,'#c7c8ba',12)+rect(14,14,212,332,tint,INK,1)
def key(name):
 return name.lower().replace('b. & o.','b-and-o').replace('.','').replace(' ','-')

def generate():
 ORIGINALS.mkdir(parents=True,exist_ok=True)
 helper=ORIGINALS/'outline_text.py'
 if not helper.exists():shutil.copyfile(PROJECT/'Games/monopoly-deal/art/outline_text.py',helper)
 properties=[];board=[None]*40;slots=[]
 for index,name,group,price,rents in PROPERTIES:
  color,cost=GROUPS[group]
  p=dict(id=index,key=key(name),name=name,group=group,color=color,price=price,mortgage=price//2,building_cost=cost,rents=rents,kind='property',layout='deal',currency='USD',value=price,colors=[group],detail='US Classic title deed')
  properties.append(p);board[index]=dict(index=index,kind='property',property=index,name=name)
  body=frame()+rect(25,30,190,55,color)+text(120,111,'TITLE DEED',13)
  labels=['One railroad','Two railroads','Three railroads','Four railroads'] if group=='railroad' else ['RENT','With 1 House','With 2 Houses','With 3 Houses','With 4 Houses','With HOTEL']
  if group=='utility':
   body+=text(120,170,'One utility: 4 × dice',16)+text(120,208,'Both utilities: 10 × dice',16)+text(120,248,'Rent uses the current roll.',11)
  else:
   for row,(label,rent) in enumerate(zip(labels,rents)):
    y=141+row*(30 if group=='railroad' else 24);body+=text(29,y,label,12,'start')+text(208,y,f'${rent}',17,'end')
   if cost:body+=text(120,287,'Color set: double base rent',10)+text(120,306,f'House / Hotel cost: ${cost}',11)
  body+=text(120,326,f'PRICE ${price}   ·   MORTGAGE ${price//2}',10)
  write(p['key']+'.svg',body)
  slots.append(dict(id=p['key'],label=name,group='Properties / '+group,path=f'Games/monopoly-classic/art/{p["key"]}.svg',kind='image',display_name=name,preview=p))
 special={0:('go','GO'),2:('community','Community Chest'),4:('tax','Income Tax'),7:('chance','Chance'),10:('jail','Jail / Just Visiting'),17:('community','Community Chest'),20:('parking','Free Parking'),22:('chance','Chance'),30:('go_to_jail','Go to Jail'),33:('community','Community Chest'),36:('chance','Chance'),38:('tax','Luxury Tax')}
 for index,(kind,name) in special.items():board[index]=dict(index=index,kind=kind,name=name,amount=200 if index==4 else 100 if index==38 else 0)
 for deck,cards,tint in [('chance',CHANCE,'#f0cc9b'),('community',COMMUNITY,'#b8d9df')]:
  for item in cards:
   item.update(kind=deck,layout='deal',currency='USD',value=0,colors=[],color=tint)
   body=frame(tint)+text(120,63,'CHANCE' if deck=='chance' else 'COMMUNITY CHEST',15)+'<circle cx="120" cy="176" r="70" fill="'+PAPER+'" stroke="'+INK+'" stroke-width="2"/>'
   for row,line in enumerate(textwrap.wrap(item['detail'],28)):body+=text(120,273+row*16,line,12)
   write(item['key']+'.svg',body)
   slots.append(dict(id=item['key'],label=item['name'],group=deck.title(),path=f'Games/monopoly-classic/art/{item["key"]}.svg',kind='image',display_name=item['name'],preview=item))
  write(deck+'-back.svg',frame(tint)+text(120,157,'?',100)+text(120,229,'CHANCE' if deck=='chance' else 'COMMUNITY',19)+text(120,253,'' if deck=='chance' else 'CHEST',19))
  slots.append(dict(id=deck+'-back',label=deck.title()+' back',group='Card backs',path=f'Games/monopoly-classic/art/{deck}-back.svg',kind='image'))
 for amount,tint in zip([1,5,10,20,50,100,500],['#e5dfb9','#efc1c1','#e2d197','#b7dcb7','#c1bbdf','#acd8e1','#edc178']):
  body=frame(tint)+rect(22,22,196,316,'none')+rect(28,28,184,304,'none')+'<ellipse cx="120" cy="180" rx="75" ry="105" fill="none" stroke="'+INK+'" stroke-width="2"/>'
  body+=text(120,194,f'${amount}',64 if amount<100 else 48)+text(120,99,'MONOPOLY',16)+text(120,278,'CLASSIC',16)
  write(f'money-{amount}.svg',body)
  slots.append(dict(id=f'money-{amount}',label=f'${amount}',group='Money',path=f'Games/monopoly-classic/art/money-{amount}.svg',kind='image',preview=dict(kind='money',layout='deal',name=f'${amount}',value=amount,currency='USD',detail='Cosmetic banknote',color='#b7dcb7')))
 silver='<defs><linearGradient id="silver" x2="1" y2="1"><stop stop-color="#fafafa"/><stop offset=".28" stop-color="#b2bcc5"/><stop offset=".53" stop-color="#f4f7f8"/><stop offset=".8" stop-color="#626f7b"/><stop offset="1" stop-color="#d1d8dd"/></linearGradient></defs>'
 shapes={'hat':'<ellipse cx="60" cy="88" rx="47" ry="14"/><path d="M31 83L27 28Q60 17 93 28L89 83Q60 97 31 83Z"/><ellipse cx="60" cy="28" rx="33" ry="10"/>','car':'<path d="M15 75L21 55L40 50L52 33H80L94 52L106 60V81H15Z"/><circle cx="34" cy="81" r="13"/><circle cx="87" cy="81" r="13"/>','dog':'<path d="M18 62L30 46L54 47L61 32L79 24L94 33L104 46L85 54L79 67L82 92H69L63 72L45 73L38 94H24L27 68L12 54Z"/><path d="M65 35L71 12L81 29Z"/>','ship':'<path d="M12 69L108 64L94 93H28Z"/><path d="M35 66V44H84V66ZM46 44V27H58V44ZM70 44V19H81V44Z"/>','thimble':'<path d="M25 91L33 31Q60 8 87 31L95 91Q60 108 25 91Z"/><path d="M33 78Q60 91 87 78M37 62Q60 75 83 62M40 46Q60 58 80 46" fill="none"/>','boot':'<path d="M40 17H79L74 65L101 75Q112 84 102 96H24V80L39 67Z"/><path d="M47 34H73M46 45H72M44 56H71" fill="none"/>'}
 for name,shape in shapes.items():
  write('token-'+name+'.svg',silver+'<ellipse cx="60" cy="103" rx="45" ry="8" fill="#00000033"/><g fill="url(#silver)" stroke="#465560" stroke-width="2" stroke-linejoin="round">'+shape+'</g>',120,120)
  slots.append(dict(id='token-'+name,label=name.title(),group='Tokens',path=f'Games/monopoly-classic/art/token-{name}.svg',kind='image'))
 title='<defs><linearGradient id="word-gold" x2="0" y2="1"><stop stop-color="#fffce4"/><stop offset=".5" stop-color="#ffdf83"/><stop offset="1" stop-color="#d5992b"/></linearGradient><linearGradient id="ribbon" x2="0" y2="1"><stop stop-color="#b90c09"/><stop offset="1" stop-color="#650806"/></linearGradient></defs>'
 title+=rect(4,31,792,126,'#dca144','#ffe8a4',29)+rect(10,37,780,114,'url(#ribbon)','#8d4e13',23)+rect(17,43,766,101,'none','#e2ad4e',19)
 title+='<g fill="url(#word-gold)" stroke="#bb7c1c" stroke-width="2"><ellipse cx="400" cy="28" rx="43" ry="8"/><path d="M373 25L368 4Q400 -4 432 4L427 25Q400 33 373 25Z"/></g>'
 title+=text(400,127,'MONOPOLY',89,fill='#4e2305')+text(400,121,'MONOPOLY',89,fill='url(#word-gold)')
 write('collection-title.svg',title,800,172);write('title.svg',title+text(400,189,'C L A S S I C',29,fill='#f8ddb0'),800,204)
 write('board-surface.svg','<defs><linearGradient id="b" x2="0" y2="1"><stop stop-color="#dcebd9"/><stop offset="1" stop-color="#c4dcc7"/></linearGradient></defs>'+rect(1,1,998,998,'url(#b)','#4d6553',12),1000,1000)
 write('table.svg','<defs><radialGradient id="b"><stop stop-color="#31594e"/><stop offset="1" stop-color="#0d2522"/></radialGradient></defs>'+rect(0,0,1600,900,'url(#b)','none'),1600,900)
 for name,label,kind in [('title','Title','image'),('collection-title','Board wordmark','image'),('board-surface','Board surface','image'),('table','Background','background')]:slots.append(dict(id=name,label=label,group='Table & UI',path=f'Games/monopoly-classic/art/{name}.svg',kind=kind))
 (ROOT/'themes/default').mkdir(parents=True,exist_ok=True)
 (ROOT/'themes/default/theme.json').write_text(json.dumps(dict(schema_version=1,id='default',name='Classic',assets={},labels={}),indent=2)+'\n',encoding='utf-8')
 (ROOT/'audio').mkdir(exist_ok=True)
 for name,freq in [('roll',220),('move',430),('cash',880),('card',660),('build',550),('jail',190),('win',1050)]:
  with wave.open(str(ROOT/'audio'/f'{name}.wav'),'wb') as audio:
   audio.setnchannels(1);audio.setsampwidth(2);audio.setframerate(22050)
   duration=.7 if name=='win' else .24;frames=[]
   for i in range(int(duration*22050)):
    t=i/22050;envelope=math.exp(-t*(6 if name=='win' else 22))*min(1,t*500)
    value=(math.sin(math.tau*freq*t)+.28*math.sin(math.tau*freq*2.003*t))*.16*envelope
    if name=='roll':value*=.5+.5*math.cos(math.tau*32*t)
    frames.append(struct.pack('<h',int(value*32767)))
   audio.writeframes(b''.join(frames))
  slots.append(dict(id='sound-'+name,label=name.title(),group='Audio',path=f'Games/monopoly-classic/audio/{name}.wav',kind='audio'))
 (ROOT/'board.json').write_text(json.dumps(dict(schema_version=1,source='Hasbro US C1009 (2017)',board=board,properties=properties,chance=CHANCE,community=COMMUNITY),indent=2)+'\n',encoding='utf-8')
 from board_art import generate as generate_board_details
 generate_board_details(slots)
 (ROOT/'theme-slots.json').write_text(json.dumps(dict(schema_version=1,presentation='modern-table',preview_kind='portfolio',slots=slots),indent=2)+'\n',encoding='utf-8')
 subprocess.run([sys.executable,str(helper),*[str(p) for p in ART.glob('*.svg')]],check=True)
 shutil.copyfile(ART/'collection-title.svg',PROJECT/'Games/monopoly/art/title.svg')
 for name in ['title.svg','collection-title.svg']:shutil.copyfile(ART/name,ORIGINALS/name)
 thumb=svg(rect(4,4,392,242,'#173e31','#e7b75f',22)+text(200,106,'MONOPOLY',45,fill='#fff2cd')+text(200,162,'CLASSIC',31,fill='#fff2cd'),400,250)
 (ROOT/'thumbnail.svg').write_text(thumb,encoding='utf-8');(PROJECT/'Games/monopoly/thumbnail.svg').write_text(thumb.replace('CLASSIC','CLASSIC  ·  DEAL'),encoding='utf-8')
 subprocess.run([sys.executable,str(helper),str(ROOT/'thumbnail.svg'),str(PROJECT/'Games/monopoly/thumbnail.svg')],check=True)
 print(f'Generated {len(properties)} independent US deeds, 32 event cards and {len(slots)} cosmetic slots.')
if __name__=='__main__':generate()
