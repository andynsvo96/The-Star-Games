(function(global){
  "use strict";
  // Optional table chrome. Connections, rules, and legal commands stay callers'.
  global.StarGamesTableUI = {
    partySeat(element,color) {
      element.style.setProperty('--seat-color',color);
      if(element.dataset.partyColor===color)return;
      element.dataset.partyColor=color;
      let rgb=(color.replace('#','').match(/.{2}/g)||['24','63','eb']).map(value=>parseInt(value,16)/255);
      const contrast=values=>1.05/(values.map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4).reduce((sum,v,i)=>sum+v*[.2126,.7152,.0722][i],0)+.05);
      for(let step=0;step<40&&contrast(rgb)<5.6;step++)rgb=rgb.map(value=>value*.955);
      element.style.setProperty('--seat-face',`rgb(${rgb.map(value=>Math.round(value*255)).join(' ')})`);
    },
    partyAccent(color) {
      let rgb=(color.replace('#','').match(/.{2}/g)||['58','d6','ff']).map(value=>parseInt(value,16)/255);
      const luminance=values=>values.map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4).reduce((sum,v,i)=>sum+v*[.2126,.7152,.0722][i],0);
      for(let step=0;step<40&&(luminance(rgb)+.05)/.085<5.0;step++)rgb=rgb.map(value=>value+(1-value)*.05);
      return `rgb(${rgb.map(value=>Math.round(value*255)).join(' ')})`;
    },
    handBrowse(button,direction,amount) {
      button.classList.add('game-hand-browse');
      let cue=button.querySelector('.game-hand-browse-cue');
      if(!cue){cue=document.createElement('span');cue.className='game-hand-browse-cue';cue.setAttribute('aria-hidden','true');button.append(cue);}
      cue.textContent=direction<0?`‹ ${amount}`:`${amount} ›`;
      button.setAttribute('aria-label',`Show ${direction<0?'previous':'next'} cards; ${amount} stacked`);
    },
    range(input) {const min=Number(input.min)||0,max=Number(input.max)||0,value=Number(input.value)||0;input.style.setProperty('--range-progress',(max>min?Math.max(0,Math.min(1,(value-min)/(max-min)))*100:0)+'%');},
    sortGroups(groups) { return [...groups].sort((a,b)=>Number(!!b.complete)-Number(!!a.complete)||b.cards.length-a.cards.length||a.id-b.id); },
    ink(color) {const rgb=color.replace('#',''),luminance=[0,2,4].map(i=>parseInt(rgb.slice(i,i+2),16)/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4).reduce((sum,v,i)=>sum+v*[.2126,.7152,.0722][i],0);return luminance>.179?'#172d27':'#fff';},
    winner() {const badge=document.createElement('span');badge.className='game-winner-badge';badge.textContent='WINNER';return badge;},
    setBars(groups,colors) {const bars=document.createElement('span');bars.className='game-set-bars';bars.classList.toggle('is-dense',groups.length>3);for(const group of this.sortGroups(groups)){const bar=document.createElement('span'),spec=colors[group.color];bar.className='game-set-bar';bar.style.setProperty('--group-color',spec.color);bar.style.setProperty('--group-ink',this.ink(spec.color));bar.textContent=group.cards.length+'/'+spec.size;bar.setAttribute('aria-label',spec.name+', '+group.cards.length+' of '+spec.size+(group.complete?', complete':''));bars.append(bar);}return bars;},
    icon(kind) {
      if(['bank','cards','house','property'].includes(kind)){const image=document.createElement('img');image.className='game-table-icon';image.src='/ui/playful/table-'+(kind==='bank'?'cash':kind)+'.svg';image.alt='';image.setAttribute('aria-hidden','true');return image;}
      const paths={cards:'M7 5 18 4l2 15-11 1ZM5 7H3v14h11',bank:'m3 9 9-6 9 6ZM4 21h16M6 11v7m6-7v7m6-7v7',house:'m3 11 9-8 9 8M5 10v11h14V10M10 21v-7h4v7',eye:'M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12ZM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6',close:'m6 6 12 12M18 6 6 18',play:'m8 4 12 8-12 8Z',rotate:'M3 10a9 9 0 0 1 15-6l3 3M21 2v5h-5M21 14a9 9 0 0 1-15 6l-3-3m0 5v-5h5'};
      paths.hotel='M4 21V4h16v17ZM8 8h1m6 0h1M8 12h1m6 0h1M10 21v-5h4v5';
      paths.sort='M3 5h12M3 11h9M3 17h6M18 8v12m-4-4 4 4 4-4';
      const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('viewBox','0 0 24 24');svg.setAttribute('aria-hidden','true');
      const path=document.createElementNS(svg.namespaceURI,'path');path.setAttribute('d',paths[kind]||paths.cards);svg.append(path);return svg;
    },
    stat(kind,value,label) {
      const stat=document.createElement('span');stat.className='game-table-stat';stat.setAttribute('aria-label',label);stat.append(this.icon(kind),document.createTextNode(String(value)));return stat;
    },
    updateAvatar(badge,player) {
      badge.style.setProperty('--player-color',player.color||'#58d6ff');
      badge.style.setProperty('--pose',`url('/avatar-${Math.max(0,Math.min(5,Number(player.pose)||0))}.svg')`);
    },
    avatar(player,winner=false) {
      const badge=document.createElement('span');badge.className='avatar-badge';badge.setAttribute('aria-hidden','true');this.updateAvatar(badge,player);
      badge.append(document.createElement('span'));if(!winner)return badge;
      const wrap=document.createElement('span');wrap.className='game-avatar-winner';const crown=document.createElement('img');crown.src='/ui/playful/table-crown.svg';crown.alt='Winner';wrap.append(badge,crown);return wrap;
    },
    rent(label,base,bonus,buildings=[]) {
      const row=document.createElement('span'),amount=document.createElement('span');row.className='game-rent-summary';amount.textContent=label+' rent $'+base;row.append(amount);
      if(bonus){const extra=document.createElement('strong');extra.className='game-rent-bonus';extra.textContent='+ $'+bonus;row.append(extra);}
      for(const card of buildings){const badge=document.createElement('span');badge.className='game-building-icon is-'+card.kind;badge.setAttribute('role','img');badge.setAttribute('aria-label',card.kind==='hotel'?'Hotel':'House');badge.append(this.icon(card.kind));row.append(badge);}return row;
    },
    group({label,color,count,size,rent,complete,buildings=[],selected=false,rentOnly=false},cards,onSelect) {
      const button=document.createElement('button');button.type='button';button.className='group-button'+(selected?' is-selected':'');button.style.setProperty('--group-color',color);button.setAttribute('aria-label',`${label}, ${count} of ${size} properties, rent $${rent}${complete?', complete':''}`);
      const stack=document.createElement('span');stack.className='mini-stack';cards.slice().reverse().forEach((card,index)=>{card.style.setProperty('--stack-index',cards.length-index-1);stack.append(card);});
      button.style.setProperty('--group-ink',this.ink(color));const badge=document.createElement('span');badge.className='group-count';badge.textContent=`${count}/${size}`;stack.append(badge);
      if(buildings.length){const badges=document.createElement('span');badges.className='building-badges';for(const card of buildings){const building=document.createElement('span');building.className='building-badge is-'+card.kind;building.setAttribute('role','img');building.setAttribute('aria-label',card.kind==='hotel'?'Hotel':'House');building.append(this.icon(card.kind));badges.append(building);}stack.append(badges);}
      const name=document.createElement('span');name.className='group-name';name.textContent=label;const value=document.createElement('span');value.className='group-rent'+(complete?' complete':'');value.textContent=`Rent $${rent}`;button.append(stack);if(!rentOnly)button.append(name);button.append(value);button.addEventListener('click',onSelect);return button;
    }
  };
  global.StarGamesCardPlaceholder=()=>{const node=document.createElement('span');node.className='game-card-empty';node.setAttribute('aria-label','Missing property slot');return node;};
  global.StarGamesCardGrid=(nodes,{slots=0,cardWidth=108}={})=>{const grid=document.createElement('div');grid.className='game-card-grid';grid.style.setProperty('--card-width',Math.max(76,Math.min(220,Number(cardWidth)||108))+'px');if(slots){grid.classList.add('game-card-grid-fixed');grid.style.setProperty('--card-columns',slots);}grid.append(...nodes);return grid;};
  global.StarGamesCardStrip=(nodes,{cardWidth=108,visibleCards=4,label='Public cards'}={})=>{const strip=document.createElement('div');strip.className='game-card-strip';strip.style.setProperty('--card-width',Math.max(76,Math.min(220,Number(cardWidth)||108))+'px');strip.style.setProperty('--strip-visible',Math.max(1,Math.min(6,Number(visibleCards)||4)));strip.tabIndex=0;strip.setAttribute('role','group');strip.setAttribute('aria-label',label);strip.append(...nodes);new global.StarGamesDragScroll(strip);return strip;};
  global.StarGamesCardTile=(face,{label='',caption='',selected=false,onSelect}={})=>{const tile=document.createElement('button');tile.type='button';tile.className='game-card-tile';tile.setAttribute('aria-label',label);tile.setAttribute('aria-pressed',String(selected));tile.classList.toggle('is-selected',selected);tile.append(face);if(caption){const words=document.createElement('span');words.className='game-card-tile-caption';words.textContent=caption;tile.append(words);}tile.addEventListener('click',onSelect);return tile;};
  // Public cards stay in a five-card window; holding either end browses in threes.
  global.StarGamesCardFan=(nodes,{label='Bank cards'}={})=>{
    const fan=document.createElement('div');fan.className='game-card-fan';
    const strip=document.createElement('div');strip.className='game-card-fan-strip';strip.tabIndex=0;strip.setAttribute('role','group');strip.setAttribute('aria-label',label);strip.append(...nodes);fan.append(strip);
    let timer=0;const stop=()=>{clearInterval(timer);timer=0;};
    const ends=[-1,1].map(direction=>{const button=document.createElement('button');button.type='button';button.className='game-card-fan-end '+(direction<0?'is-previous':'is-next');button.setAttribute('aria-label',direction<0?'Previous bank cards':'Next bank cards');fan.append(button);return button;});
    const update=()=>{ends[0].hidden=strip.scrollLeft<1;ends[1].hidden=strip.scrollLeft>=strip.scrollWidth-strip.clientWidth-1;};
    const shift=direction=>{strip.scrollLeft+=direction*3*((nodes[0]?.getBoundingClientRect().width||44)+6);update();};
    ends.forEach((button,index)=>{const direction=index?1:-1;
      button.addEventListener('pointerdown',event=>{if(event.button!==0||!event.isPrimary)return;stop();event.preventDefault();event.stopPropagation();button.setPointerCapture(event.pointerId);shift(direction);timer=setInterval(()=>{if(!fan.isConnected||!fan.getClientRects().length){stop();return;}shift(direction);},310);});
      for(const type of ['pointerup','pointercancel','lostpointercapture'])button.addEventListener(type,stop);
      button.addEventListener('click',event=>{event.preventDefault();if(event.detail===0)shift(direction);});
    });
    new global.StarGamesDragScroll(strip,{onStart:stop});
    strip.addEventListener('scroll',update);strip.addEventListener('wheel',event=>{if(strip.scrollWidth<=strip.clientWidth)return;event.preventDefault();strip.scrollLeft+=event.deltaX||event.deltaY;},{passive:false});
    strip.addEventListener('keydown',event=>{if(['ArrowLeft','ArrowRight','Home','End'].includes(event.key)){event.preventDefault();if(event.key==='Home')strip.scrollLeft=0;else if(event.key==='End')strip.scrollLeft=strip.scrollWidth;else shift(event.key==='ArrowLeft'?-1:1);update();}});
    const hidden=()=>{if(document.hidden)stop();};window.addEventListener('blur',stop);document.addEventListener('visibilitychange',hidden);
    const resize=new ResizeObserver(update);resize.observe(strip);
    fan.dispose=()=>{stop();resize.disconnect();window.removeEventListener('blur',stop);document.removeEventListener('visibilitychange',hidden);};fan.stop=stop;
    return fan;
  };
  global.StarGamesActionPreview=(items,{selected=0,onSelect,presentation='default'}={})=>{
    const panel=document.createElement('aside');panel.className='game-action-preview';const title=document.createElement('h3');title.textContent='Action preview';panel.append(title);
    if(presentation==='cards'){
      const groups=[],tiles=[],buckets=new Map();
      const same=(a,b)=>a.key===b.key&&a.value===b.value&&a.owner===b.owner;
      for(const item of items)for(const group of item.groups||[])if(!groups.some(prior=>same(prior,group)))groups.push(group);
      const exchange=groups.some(group=>group.key==='give'),categories=new Map();if(exchange)groups.sort((a,b)=>Number(b.key==='give')-Number(a.key==='give'));
      const outcome=document.createElement('div');outcome.className='game-preview-outcome';
      const select=index=>{selected=index;const item=items[selected];for(const {tile,group}of tiles){const active=!!item&&group.key!=='affected'&&(item.groups||[]).some(other=>same(other,group));tile.classList.toggle('is-selected',active);tile.setAttribute('aria-pressed',String(active));}outcome.replaceChildren();const summary=document.createElement('p');summary.textContent=item?.summary||'Choose the player or card for this action.';outcome.append(summary);for(const player of item?.players||[]){const row=document.createElement('div'),name=document.createElement('span');row.className='game-preview-player';name.textContent=player.display_name;row.append(global.StarGamesTableUI.avatar(player),name);if(player.amount!==undefined){const amount=document.createElement('b');amount.className='game-owed';amount.textContent='$'+player.amount;row.append(amount);}outcome.append(row);}};
      const choose=group=>{if(group.key==='affected')return;let best=-1,score=-1;items.forEach((item,index)=>{if(!(item.groups||[]).some(other=>same(other,group)))return;const matches=(items[selected]?.groups||[]).filter(current=>(item.groups||[]).some(other=>same(current,other))).length;if(matches>score){best=index;score=matches;}});if(best>=0){select(best);onSelect?.(best);}};
      for(const group of groups){const key=group.key+':'+group.owner;if(!buckets.has(key))buckets.set(key,[]);buckets.get(key).push(group);}
      for(const list of buckets.values()){
        const first=list[0],section=document.createElement('section'),heading=document.createElement('div'),name=document.createElement('span');section.className='game-preview-card-group';heading.className='game-preview-player';name.textContent=first.player.display_name;heading.append(global.StarGamesTableUI.avatar(first.player),name);section.append(heading);
        const nodes=[];for(const group of list){for(const face of group.cards||[]){const tile=global.StarGamesCardTile(face,{label:group.label+', '+face.getAttribute('aria-label'),caption:group.label,onSelect:()=>choose(group)});tiles.push({tile,group});nodes.push(tile);}if(!group.cards?.length){const tile=document.createElement('button');tile.type='button';tile.className='game-preview-empty-choice';tile.textContent=group.label+' · No bank cards';tile.addEventListener('click',()=>choose(group));tiles.push({tile,group});section.append(tile);}}
        if(nodes.length)section.append(global.StarGamesCardGrid(nodes));if(exchange){if(!categories.has(first.key)){const category=document.createElement('section'),title=document.createElement('h4');category.className='game-preview-category';category.dataset.previewCategory=first.key;title.textContent=first.key==='give'?'Your cards to give':"Opponents' cards to take";category.append(title);categories.set(first.key,category);panel.append(category);}categories.get(first.key).append(section);}else panel.append(section);
      }
      panel.append(outcome);select(Math.max(-1,Math.min(selected,items.length-1)));return panel;
    }
    if(presentation==='players'){
      panel.classList.add('game-action-player-options');const buttons=[],fans=[];
      const select=index=>{selected=index;buttons.forEach((button,slot)=>{button.setAttribute('aria-pressed',String(slot===index));button.classList.toggle('is-selected',slot===index);});};
      items.forEach((item,index)=>{const player=item.players[0],group=document.createElement('section'),button=document.createElement('button');group.className='game-action-player-option';button.type='button';button.className='game-preview-player game-preview-player-choice';button.setAttribute('aria-label',player.display_name+', Bank: $'+player.bank_total);
        const name=document.createElement('span');name.textContent=player.display_name;button.append(global.StarGamesTableUI.avatar(player),name,global.StarGamesTableUI.stat('bank','$'+player.bank_total,'Bank: $'+player.bank_total));
        button.addEventListener('click',()=>{select(index);onSelect?.(index);});buttons.push(button);group.append(button);
        if(item.cards?.length){const fan=global.StarGamesCardFan(item.cards,{label:player.display_name+' bank cards'});fans.push(fan);group.append(fan);}panel.append(group);
      });
      panel.stop=()=>fans.forEach(fan=>fan.stop());panel.dispose=()=>fans.forEach(fan=>fan.dispose());select(selected);return panel;
    }
    const choice=document.createElement('select');choice.className='game-choice';choice.setAttribute('aria-label','Action option');items.forEach(item=>{const option=document.createElement('option');option.textContent=item.label;choice.append(option);});choice.value=String(selected);choice.selectedIndex=selected;choice.hidden=items.length<2;panel.append(choice);
    const body=document.createElement('div');panel.append(body);const render=()=>{body.replaceChildren();const item=items[choice.selectedIndex]||items[0];if(!item)return;const summary=document.createElement('p');summary.textContent=item.summary;body.append(summary);for(const player of item.players||[]){const row=document.createElement('div');row.className='game-preview-player';const name=document.createElement('span');name.textContent=player.display_name;row.append(global.StarGamesTableUI.avatar(player),name);if(player.amount!==undefined){const amount=document.createElement('b');amount.className='game-owed';amount.textContent='$'+player.amount;row.append(amount);}body.append(row);}if(item.cards?.length)body.append(global.StarGamesCardGrid(item.cards));if(item.note){const note=document.createElement('p');note.className='game-preview-note';note.textContent=item.note;body.append(note);}};
    choice.addEventListener('change',()=>{render();onSelect?.(choice.selectedIndex);});render();return panel;
  };
  global.StarGamesTurnStrip=(players,active,{tracked=false,actions=[]}={})=>{
    const row=document.createElement('div');row.className='game-turn-strip'+(tracked?' game-turn-strip-track':'');row.style.setProperty('--turn-seats',Math.max(1,players.length));row.setAttribute('aria-label','Player turn order');
    players.forEach((player,index)=>{
      const name=document.createElement('span'),eliminated=player.alive===false,current=index===active&&!eliminated;
      name.className='game-turn-name';name.dataset.seat=index;name.textContent=player.display_name;
      if(actions.length){const caption=document.createElement('small');caption.className='game-turn-action';caption.textContent=actions[index]||'';name.append(caption);row.classList.add('has-turn-actions');}
      if(!tracked)name.style.color=current?player.color:'#fff';
      name.classList.toggle('is-active',current);name.classList.toggle('game-seat-eliminated',eliminated);
      name.setAttribute('aria-label',player.display_name+(eliminated?', eliminated':current?', current turn':'')+(actions[index]?', '+actions[index]:''));
      if(current)name.setAttribute('aria-current','step');row.append(name);
    });return row;
  };
  // Reusable composed cards. Skin images never determine accessible rules text.
  global.StarGamesCard = function(data, options = {}) {
    const card = document.createElement(options.onSelect ? 'button' : 'div');
    card.className = 'game-playing-card';
    const accent=data.layout==='symbol'?(data.back?'#617c76':data.accent||options.color||'#617c76'):(options.color||'#617c76');
    card.style.setProperty('--card-accent',accent);
    const rgb=accent.replace('#','');
    const luminance=[0,2,4].map(i=>parseInt(rgb.slice(i,i+2),16)/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4).reduce((sum,v,i)=>sum+v*[.2126,.7152,.0722][i],0);
    card.style.setProperty('--card-ink',luminance>.179?'#172d27':'#ffffff');
    card.classList.toggle('is-selected', !!options.selected);
    if(options.compact) card.classList.add('game-card-small');
    const name=data.display_name || data.name || '';
    if(data.layout==='symbol'){
      if(data.back){card.classList.add('game-symbol-card');card.style.setProperty('--symbol-accent','#131820');card.setAttribute('aria-label','Card back');return card;}
      card.classList.add('game-symbol-card');card.style.setProperty('--symbol-accent',data.accent||options.color||'#617c76');card.setAttribute('aria-label',`${name}. ${data.detail||''} ${data.foot||''}`);
      const title=document.createElement('strong'),detail=document.createElement('span'),foot=document.createElement('small');title.className='game-symbol-title';detail.className='game-symbol-detail';foot.className='game-symbol-foot';title.textContent=name;detail.textContent=data.detail||'';foot.textContent=data.foot||'';
      card.append(title);
      if(options.art){const ns='http://www.w3.org/2000/svg',art=document.createElementNS(ns,'svg'),image=document.createElementNS(ns,'image'),region=data.art_region||[0,0,1,1],size=data.art_size||[1,1];art.classList.add('game-symbol-art');art.setAttribute('viewBox',`${region[0]*size[0]} ${region[1]*size[1]} ${region[2]*size[0]} ${region[3]*size[1]}`);art.setAttribute('aria-hidden','true');image.setAttribute('href',options.art);image.setAttribute('width',size[0]);image.setAttribute('height',size[1]);image.setAttribute('preserveAspectRatio','none');art.append(image);card.append(art);}
      card.append(detail,foot);if(options.onSelect)card.addEventListener('click',options.onSelect);card.disabled=!!options.disabled;return card;
    }
    if(data.layout==='character'){
      card.classList.add('game-character-card');
      card.classList.toggle('game-character-paper',data.caption_style==='paper');
      card.setAttribute('aria-label',data.back?'Hidden influence':`${name}. ${data.detail||''} ${data.foot||''}`);
      if(options.art){const art=document.createElement('img');art.src=options.art;art.alt='';art.draggable=false;card.append(art);}
      if(!data.back){const band=document.createElement('span');band.className='game-character-caption';for(const [tag,text] of [['strong',name],['small',data.detail],['small',data.foot]]){const line=document.createElement(tag);line.textContent=text||'';band.append(line);}card.append(band);}
      if(options.onSelect)card.addEventListener('click',options.onSelect);card.disabled=!!options.disabled;return card;
    }
    if(data.layout==='standard'){
      card.classList.add('game-standard-card');card.classList.toggle('is-red',data.suit==='hearts'||data.suit==='diamonds');
      card.setAttribute('aria-label',data.back?'Card back':name);
      const symbol={clubs:'♣',diamonds:'♦',hearts:'♥',spades:'♠'}[data.suit]||'♠';
      if(data.back)card.classList.add('game-standard-back');
      else for(const position of ['top','bottom']){const corner=document.createElement('span'),rank=document.createElement('b'),suit=document.createElement('span');corner.className='game-card-corner is-'+position;rank.textContent=data.rank;suit.textContent=symbol;corner.append(rank,suit);card.append(corner);}
      const pip=document.createElement('span');pip.className='game-card-pip';pip.textContent=data.back?'♠':symbol;pip.setAttribute('aria-hidden','true');card.append(pip);
      if(options.onSelect)card.addEventListener('click',options.onSelect);card.disabled=!!options.disabled;return card;
    }
    if(data.back){card.classList.add('game-card-back');card.setAttribute('aria-label','Card back');if(options.art){const art=document.createElement('img');art.src=options.art;art.alt='';art.draggable=false;card.append(art);}return card;}
    const valueLabel=data.currency==='USD'?'$'+(data.value||0):(data.value||0)+'M';
    card.setAttribute('aria-label',`${name}, ${valueLabel}${data.detail ? ', '+data.detail : ''}${data.mortgaged?', mortgaged':''}`);
    if(data.layout==='deal'){
      card.classList.add('game-deal-face',`game-deal-${data.kind}`);
      if(data.face_side%2===1)card.style.transform='rotate(180deg)';
      if(options.art){const art=document.createElement('img');art.src=options.art;art.alt='';art.draggable=false;card.append(art);}
      if(data.kind!=='money'&&(data.kind!=='wild'||name!==data.name)){
        const title=document.createElement('span');title.className='game-deal-name';title.textContent=data.kind==='rent'?'RENT':name;
        const property=data.kind==='property',building=['house','hotel'].includes(data.kind),wild=data.kind==='wild';
        const width=240*(property ? .68 : wild ? .72 : data.kind==='pass-go' ? .48 : data.kind==='birthday' ? .52 : .54),height=360*(property ? .132 : building ? .10 : wild ? .065 : data.kind==='pass-go' ? .20 : data.kind==='birthday' ? .18 : .22);
        const measure=document.createElement('canvas').getContext('2d');let font=property?21:building?24:wild?11:32;
        const words=title.textContent.toUpperCase().split(/\s+/);
        for(;font>8;font--){measure.font=`900 ${font}px Arial`;let line='',lines=1,wide=false;for(const word of words){if(measure.measureText(word).width>width)wide=true;const next=line?line+' '+word:word;if(line&&measure.measureText(next).width>width){lines++;line=word;}else line=next;}if(!wide&&lines*font*1.3<=height)break;}
        const content=document.createElement('span');content.textContent=title.textContent;content.style.width='100%';title.replaceChildren(content);title.style.fontSize=`${font/2.4}cqw`;card.append(title);
      }
      if(data.deed_state){const state=data.deed_state,rows=document.createElement('div');rows.className='game-deed-state';rows.style.cssText=`left:${state.area[0]/2.4}%;top:${state.area[1]/3.6}%;width:${state.area[2]/2.4}%;height:${state.area[3]/3.6}%`;for(const entry of state.rows){const row=document.createElement('div'),label=document.createElement('span'),value=document.createElement('b');row.className='game-deed-row';row.classList.toggle('is-active',entry.active);label.textContent=entry.label;value.textContent=entry.value;row.append(label,value);rows.append(row);}card.append(rows);if(state.badge){const badge=document.createElement('div'),icon=document.createElement('img'),label=document.createElement('b');badge.className='game-deed-upgrade';icon.src='/ui/playful/table-'+state.icon+'.svg';icon.alt='';label.textContent=state.badge;badge.append(icon,label);card.append(badge);}}
      if(data.mortgaged){card.classList.add('is-mortgaged');const stamp=document.createElement('span');stamp.className='game-mortgage-stamp';stamp.textContent='MORTGAGED';card.append(stamp);}
      if(options.onSelect)card.addEventListener('click',options.onSelect);
      card.disabled=!!options.disabled;return card;
    }
    const title=document.createElement('span');title.className='game-playing-card-name';title.textContent=name;card.append(title);
    if(options.art){const art=document.createElement('img');art.src=options.art;art.alt='';art.draggable=false;card.append(art);}
    const value=document.createElement('strong');value.className='game-playing-card-value';value.textContent=valueLabel;card.append(value);
    if(options.foot){const foot=document.createElement('small');foot.textContent=options.foot;card.append(foot);}
    if(options.onSelect)card.addEventListener('click',options.onSelect);
    card.disabled=!!options.disabled;
    return card;
  };
  global.StarGamesHandDock = class {
    // A single dock may contain the owner's public assets above private cards.
    static combine(surface,dock) {
      surface.classList.add('game-hand-combined');dock.classList.add('game-hand-dock-combined');
      const fit=()=>{const height=Math.ceil(dock.getBoundingClientRect().height)+'px';if(surface.style.getPropertyValue('--game-hand-dock-height')!==height)surface.style.setProperty('--game-hand-dock-height',height);};
      const observer=new ResizeObserver(fit);observer.observe(dock);fit();return ()=>observer.disconnect();
    }
    constructor(hand, toolbar) {
      this.hand=hand;this.toolbar=toolbar;this.anchor=document.createComment('hand actions');toolbar.before(this.anchor);
      this.media=matchMedia('(orientation: portrait)');this.fit=()=>{
        if(this.media.matches)hand.prepend(toolbar);else this.anchor.after(toolbar);
      };
      this.media.addEventListener('change',this.fit);this.fit();
    }
  };
  global.StarGamesReferenceCard = (topic,{label=topic.label}={}) => {
    const tile=document.createElement('section'),header=document.createElement('div'),caption=document.createElement('span'),image=document.createElement('img'),flip=document.createElement('button');
    tile.className='game-reference-card';tile.setAttribute('aria-label',label);header.className='game-reference-card-header';caption.textContent=label;
    image.draggable=false;flip.className='game-secondary game-compact-control game-icon-only';flip.dataset.referenceFlip='';flip.append(global.StarGamesTableUI.icon('rotate'));
    let side=0,wide=false;
    tile.updateReference=useWide=>{wide=useWide;const face=topic.pages[side];image.src=wide?(face.wideSrc||face.src):face.src;image.alt=face.alt||face.label||label;flip.setAttribute('aria-label','Flip '+label+' to '+(topic.pages[1-side].label||(side?'front':'back')));tile.dataset.referenceSide=String(side);};
    flip.addEventListener('click',()=>{side=1-side;tile.updateReference(wide);});
    header.append(caption,flip);tile.append(header,image);tile.updateReference(false);return tile;
  };
  global.StarGamesCardReader = class {
    constructor(onClose=()=>{}) {
      this.dialog=document.createElement('dialog');this.dialog.className='game-dialog game-card-reader';this.dialog.setAttribute('aria-label','Card reader');
      this.header=document.createElement('header');this.topBack=this.button('Back',()=>this.back());this.heading=document.createElement('h2');this.flip=this.button('Flip to back',()=>this.flipPage());this.flip.dataset.readerFlip='';this.header.append(this.topBack,this.heading,this.flip);
      this.subtitle=document.createElement('p');this.subtitle.className='game-reader-subtitle';this.subtitle.hidden=true;
      this.referenceMenu=document.createElement('div');this.referenceMenu.className='game-reference-menu';this.referenceMenu.hidden=true;
      this.referenceGroup=document.createElement('select');this.referenceGroup.className='game-choice';this.referenceGroup.setAttribute('aria-label','Reference collection');
      this.referenceTopic=document.createElement('select');this.referenceTopic.className='game-choice';this.referenceTopic.setAttribute('aria-label','Reference topic');
      this.referenceMenu.append(this.referenceGroup,this.referenceTopic);
      this.galleryTabs=document.createElement('nav');this.galleryTabs.className='game-reference-collections';this.galleryTabs.setAttribute('aria-label','Reference collections');this.galleryTabs.hidden=true;
      this.referenceGroup.addEventListener('change',()=>this.referenceTopics());this.referenceTopic.addEventListener('change',()=>this.referencePage());
      this.stage=document.createElement('div');this.stage.className='game-card-reader-stage';this.footer=document.createElement('footer');
      this.rotateRow=document.createElement('div');this.rotateRow.className='game-card-rotate';this.rotateRow.hidden=true;
      this.rotate=this.button('',()=>this.onRotate?.());this.rotate.setAttribute('aria-label','Rotate card');this.rotate.dataset.readerRotate='';
      const icon=document.createElement('img');icon.src='/ui/playful/control-rotate.svg';icon.alt='';this.rotate.append(icon);this.rotateLabel=document.createElement('span');this.rotateRow.append(this.rotate,this.rotateLabel);
      this.dialog.append(this.header,this.subtitle,this.referenceMenu,this.galleryTabs,this.stage,this.rotateRow,this.footer);document.body.append(this.dialog);
      global.StarGamesDismissOnOutside(this.dialog,{contains:target=>this.backOnly||!!target.closest('.game-reader-card,.game-action-preview,button,.game-card-rotate,.game-reference-menu')});
      this.dialog.addEventListener('close',onClose);this.dialog.addEventListener('cancel',event=>{event.preventDefault();if(!this.backOnly)this.close();});
      this.referenceObserver=new ResizeObserver(()=>{this.fitReference();this.fitGallery();});this.referenceObserver.observe(this.stage);
    }
    button(label,callback,primary=false){const node=document.createElement('button');node.textContent=label;node.className=(primary?'game-primary':'game-secondary')+' game-compact-control';node.addEventListener('click',callback);return node;}
    showCard(node,{heading='',actions=[],back}={}){
      this.clearGallery();this.backOnly=false;this.referenceTopicData=null;
      this.referenceMenu.hidden=true;this.referenceLibrary=null;this.dialog.classList.remove('has-reference-menu');
      this.heading.hidden=false;this.dialog.classList.remove('is-wide-reference');
      this.clearPreview();
      this.setSubtitle('');
      this.dialog.classList.remove('has-action-preview','has-reference','has-fitted-reference');this.previewIndex=0;
      this.rotateRow.hidden=true;
      this.pages=null;this.topBack.hidden=true;this.flip.hidden=true;this.header.append(this.flip);this.heading.textContent=heading;this.footer.hidden=false;node.classList.add('game-reader-card');this.stage.replaceChildren(node);this.setActions(actions,back);if(!this.dialog.open)this.dialog.showModal();
    }
    setSubtitle(text){this.subtitle.textContent=text;this.subtitle.hidden=!text;this.dialog.classList.toggle('has-subtitle',!!text);}
    setActions(actions=[],back){this.footer.style.setProperty('--reader-columns',actions.length>2?2:actions.length+1);this.footer.replaceChildren(this.button('Back',back||(()=>this.close())));for(const action of actions){const node=this.button(action.label,action.onSelect,true);node.disabled=!!action.disabled;node.dataset.invalid=String(!!action.disabled);node.dataset.readerAction=action.action||'';this.footer.append(node);}}
    clearPreview(){const preview=this.stage.querySelector('.game-action-preview');preview?.dispose?.();preview?.remove();}
    setPreview(items,{selected=0,presentation='default',onSelect}={}){this.clearPreview();this.previewIndex=selected;this.dialog.classList.toggle('has-action-preview',!!items.length);if(items.length)this.stage.append(global.StarGamesActionPreview(items,{selected,presentation,onSelect:index=>{this.previewIndex=index;onSelect?.(index);}}));}
    setRotation({side=0,label='',onRotate,reduced=false,animate=false}={}){this.rotateRow.hidden=false;this.rotateLabel.textContent=label;this.onRotate=onRotate;const node=this.stage.firstElementChild;if(!node)return;node.style.transition='none';node.style.transform='rotate('+side*180+'deg)';if(animate&&!reduced&&!matchMedia('(prefers-reduced-motion: reduce)').matches)node.animate([{transform:'rotate('+(side*180-180)+'deg)'},{transform:'rotate('+side*180+'deg)'}],{duration:380,easing:'cubic-bezier(.65,0,.35,1)'});}
    showReference(pages,{fit=false,backOnly=false}={}){this.clearGallery();this.referenceTopicData=null;this.presentReference(pages,{fit,backOnly});}
    presentReference(pages,{fit=false,backOnly=false}={}){this.backOnly=backOnly;this.galleryShowing=false;this.galleryTabs.hidden=true;this.dialog.classList.remove('has-reference-gallery','has-reference-collections');this.referenceMenu.hidden=true;this.dialog.classList.remove('has-reference-menu');this.clearPreview();this.setSubtitle('');this.dialog.classList.remove('has-action-preview');this.dialog.classList.add('has-reference');this.dialog.classList.toggle('has-fitted-reference',fit);this.rotateRow.hidden=true;this.pages=pages;this.page=0;this.topBack.hidden=false;this.flip.hidden=false;this.heading.textContent='';this.footer.hidden=true;this.renderPage();if(!this.dialog.open)this.dialog.showModal();requestAnimationFrame(()=>{this.stage.scrollTop=0;this.fitReference();});}
    showReferenceGallery(groups,{heading='Help',browse=false,group=0,inlineFlip=false}={}){if(!groups?.length)return;this.clearPreview();this.referenceLibrary=null;this.referenceTopicData=null;this.galleryGroups=groups;this.galleryHeading=heading;this.galleryBrowse=browse;this.galleryInline=inlineFlip;this.galleryGroup=Math.max(0,Math.min(group,groups.length-1));this.galleryTabs.replaceChildren(...groups.map((item,index)=>{const button=this.button(item.label,()=>{this.galleryGroup=index;this.presentGallery();});button.setAttribute('aria-pressed',String(index===this.galleryGroup));return button;}));this.presentGallery();}
    presentGallery(){
      this.backOnly=true;this.galleryShowing=true;this.pages=null;this.referenceTopicData=null;this.referenceMenu.hidden=true;this.flip.hidden=true;this.header.append(this.flip);this.rotateRow.hidden=true;this.footer.hidden=true;this.topBack.hidden=false;this.heading.hidden=false;this.heading.textContent=this.galleryHeading;this.setSubtitle('');
      this.dialog.classList.remove('has-reference','has-fitted-reference','has-reference-menu','is-wide-reference','has-action-preview');this.dialog.classList.add('has-reference-gallery');this.dialog.classList.toggle('has-inline-references',!!this.galleryInline);
      this.galleryTabs.hidden=!this.galleryBrowse||this.galleryGroups.length<2;this.dialog.classList.toggle('has-reference-collections',!this.galleryTabs.hidden);[...this.galleryTabs.children].forEach((button,index)=>button.setAttribute('aria-pressed',String(index===this.galleryGroup)));
      const groups=this.galleryBrowse?[this.galleryGroups[this.galleryGroup]]:this.galleryGroups,nodes=[];
      for(const group of groups)for(const topic of group.pages){
        const label=topic.galleryLabel||(topic.id==='overview'?group.label+(group.id==='base'?'':' overview'):topic.label);let tile;
        if(this.galleryInline)tile=global.StarGamesReferenceCard(topic,{label});
        else{const face=document.createElement('img');face.src=topic.pages[0].src;face.alt='';face.draggable=false;tile=global.StarGamesCardTile(face,{label,caption:label,onSelect:()=>this.openGalleryPage(topic)});}
        tile.dataset.referenceId=(group.id||group.label)+'/'+(topic.id||topic.label);nodes.push(tile);
      }
      this.galleryGrid=global.StarGamesCardGrid(nodes,{cardWidth:240});this.galleryGrid.classList.add('game-reference-gallery');this.stage.replaceChildren(this.galleryGrid);if(!this.dialog.open)this.dialog.showModal();requestAnimationFrame(()=>{this.stage.scrollTop=0;this.fitGallery();});
    }
    openGalleryPage(topic){this.referenceWide=innerWidth>=650&&innerHeight<=540;this.presentReference(topic.pages.map(face=>({...face,src:this.referenceWide?(face.wideSrc||face.src):face.src})),{fit:true,backOnly:true});this.referenceTopicData=topic;}
    fitGallery(){
      if(!this.dialog.open||!this.galleryShowing||!this.galleryGrid)return;
      const count=this.galleryGrid.children.length,available=this.stage.clientWidth-8;let width=0,columns=1;
      if(this.galleryInline){const wide=innerWidth>=650&&innerHeight<=540,gap=24,preferred=Math.min(wide?1050:500,Math.max(wide?560:360,(this.stage.clientHeight-52)*(wide?1280/500:640/900)));columns=wide?1:Math.max(1,Math.min(count,Math.floor((available+gap)/384)));width=Math.min(preferred,(available-(columns-1)*gap)/columns);for(const tile of this.galleryGrid.children)tile.updateReference(wide);}
      else{const gap=10,caption=36,height=this.stage.clientHeight-8;for(let candidate=1;candidate<=Math.min(6,count);candidate++){const rows=Math.ceil(count/candidate),fitted=Math.min(240,(available-(candidate-1)*gap)/candidate,((height-(rows-1)*gap)/rows-caption)/1.5);if(fitted>=width){width=fitted;columns=candidate;}}}
      this.galleryGrid.style.setProperty('--reference-columns',columns);this.galleryGrid.style.setProperty('--reference-width',Math.max(4,width)+'px');
    }
    clearGallery(){this.galleryGroups=null;this.galleryShowing=false;this.galleryTabs.hidden=true;this.dialog.classList.remove('has-reference-gallery','has-reference-collections','has-inline-references');}
    back(){if(this.galleryGroups&&!this.galleryShowing)this.presentGallery();else this.close();}
    showReferenceLibrary(groups,{group=0,topic=0}={}){if(!groups?.length)return;this.clearGallery();this.referenceLibrary=groups;this.referenceGroup.replaceChildren(...groups.map(item=>{const option=document.createElement('option');option.textContent=item.label;return option;}));this.referenceGroup.selectedIndex=Math.max(0,Math.min(group,groups.length-1));this.referenceTopics(topic);}
    referenceTopics(selected=0){const group=this.referenceLibrary?.[this.referenceGroup.selectedIndex];if(!group)return;this.referenceTopic.replaceChildren(...group.pages.map(item=>{const option=document.createElement('option');option.textContent=item.label;return option;}));this.referenceTopic.selectedIndex=Math.max(0,Math.min(selected,group.pages.length-1));this.referencePage();}
    referencePage(){const topic=this.referenceLibrary?.[this.referenceGroup.selectedIndex]?.pages[this.referenceTopic.selectedIndex];if(!topic)return;this.referenceTopicData=topic;this.referenceWide=innerWidth>=650&&innerHeight<=540;this.presentReference(topic.pages.map(face=>({...face,src:this.referenceWide?(face.wideSrc||face.src):face.src})),{fit:true});this.referenceMenu.hidden=false;this.dialog.classList.add('has-reference-menu');this.referenceTopic.hidden=this.referenceTopic.options.length<2;this.layoutReferenceMenu();requestAnimationFrame(()=>this.fitReference());}
    layoutReferenceMenu(){const wide=innerWidth>=650&&innerHeight<=540;if(this.referenceMenu.hidden){this.heading.hidden=false;this.dialog.classList.remove('is-wide-reference');}else{this.dialog.classList.toggle('is-wide-reference',wide);this.heading.hidden=wide;if(wide){if(this.referenceMenu.parentElement!==this.header)this.header.append(this.referenceMenu);}else if(this.referenceMenu.parentElement!==this.dialog)this.dialog.insertBefore(this.referenceMenu,this.stage);}if(wide!==this.referenceWide&&this.referenceTopicData){this.referenceWide=wide;this.pages=this.referenceTopicData.pages.map(face=>({...face,src:wide?(face.wideSrc||face.src):face.src}));this.renderPage();}}
    renderPage(){const wrap=document.createElement('div'),img=document.createElement('img');wrap.className='game-reader-card game-reader-reference-wrap';img.className='game-reader-reference';img.onload=()=>this.fitReference();img.src=this.pages[this.page].src;img.alt=this.pages[this.page].alt;this.flip.replaceChildren(global.StarGamesTableUI.icon('rotate'));this.flip.setAttribute('aria-label',this.page===0?'Flip to back':'Flip to front');wrap.append(img,this.flip);this.stage.replaceChildren(wrap);this.stage.scrollTop=0;}
    fitReference(){if(!this.dialog.open||!this.dialog.classList.contains('has-reference')||!this.dialog.classList.contains('has-fitted-reference'))return;this.layoutReferenceMenu();const wrap=this.stage.querySelector('.game-reader-reference-wrap'),img=wrap?.firstChild;if(!img?.naturalHeight)return;const ratio=img.naturalWidth/img.naturalHeight,width=Math.max(1,Math.min(ratio>1?880:500,this.stage.clientWidth-48,(this.stage.clientHeight-48)*ratio));wrap.style.width=width+'px';wrap.style.height=width/ratio+'px';this.stage.scrollTop=0;}
    flipPage(){if(this.pages){this.page=1-this.page;this.renderPage();}}
    close(){this.stage.querySelector('.game-action-preview')?.stop?.();this.dialog.close();}
    get open(){return this.dialog.open;}
  };
  global.StarGamesDismissOnOutside=(dialog,{contains=target=>target!==dialog}={})=>{
    let origin=null;
    dialog.addEventListener('pointerdown',event=>{origin=event.isPrimary&&event.button===0&&!contains(event.target)?{x:event.clientX,y:event.clientY}:null;});
    dialog.addEventListener('pointercancel',()=>{origin=null;});
    dialog.addEventListener('click',event=>{if(origin&&!contains(event.target)&&Math.hypot(event.clientX-origin.x,event.clientY-origin.y)<8){dialog.close();event.stopPropagation();}origin=null;});
    dialog.addEventListener('close',()=>{origin=null;});
  };
  // Pointer capture starts only after a drag, preserving simple taps and keys.
  global.StarGamesDragScroll = class {
    constructor(element,options={}){
      this.element=element;let gesture=null,suppress=false;
      const read=options.getOffset||(()=>element.scrollLeft),write=options.setOffset||(value=>{element.scrollLeft=value;}),enabled=options.isEnabled||(()=>true);
      element.classList.add('game-drag-scroll');
      element.addEventListener('pointerdown',event=>{if(!event.isPrimary||event.button!==0)return;suppress=false;gesture={id:event.pointerId,x:event.clientX,y:event.clientY,left:read(),drag:false};});
      element.addEventListener('pointermove',event=>{if(!gesture||event.pointerId!==gesture.id)return;const dx=event.clientX-gesture.x,dy=event.clientY-gesture.y;if(!gesture.drag&&Math.abs(dx)>8&&Math.abs(dx)>Math.abs(dy)){gesture.drag=true;suppress=true;element.classList.add('is-dragging');element.setPointerCapture(event.pointerId);options.onStart?.();}if(gesture.drag){if(enabled())write(gesture.left-dx);event.preventDefault();}});
      const finish=event=>{if(!gesture||event.pointerId!==gesture.id)return;const dragged=gesture.drag;gesture=null;if(element.hasPointerCapture(event.pointerId))element.releasePointerCapture(event.pointerId);element.classList.remove('is-dragging');if(dragged)options.onEnd?.();};
      element.addEventListener('pointerup',finish);element.addEventListener('pointercancel',finish);element.addEventListener('lostpointercapture',event=>{if(event.target===element)finish(event);});
      element.addEventListener('click',event=>{if(suppress&&event.detail!==0){event.preventDefault();event.stopImmediatePropagation();}},true);
      element.addEventListener('dragstart',event=>event.preventDefault());
    }
  };
  // Shared finite card flights; modules map authoritative zones to live rectangles.
  global.StarGamesCardMotion = class {
    constructor(resolve,face){this.resolve=resolve;this.face=face;this.layer=document.createElement('div');this.layer.className='game-card-flights';this.layer.setAttribute('aria-hidden','true');document.body.append(this.layer);this.event=null;this.clock=0;this.frame=0;}
    update(event,{paused=false,reduced=false}={}){cancelAnimationFrame(this.frame);this.layer.replaceChildren();this.event=event;this.clock=performance.now();this.paused=paused;if(!event?.active||reduced||matchMedia('(prefers-reduced-motion: reduce)').matches)return;this.tick();}
    elapsed(){return (this.event?.elapsed||0)+(this.paused?0:(performance.now()-this.clock)/1000);}
    pending(id){return this.event?.active&&this.event.flights.some(f=>f.card.id===id&&this.elapsed()<f.delay+f.duration);}
    tick(){const e=this.event,t=this.elapsed();this.layer.replaceChildren();if(!e?.active||t>=e.duration)return;
      if(t<e.shuffle){const deck=this.resolve({zone:'deck',seat:-1});if(deck)for(let i=0;i<5;i++){const node=this.face({back:true});node.style.cssText+=';position:fixed;left:'+(deck.x+Math.sin(t*24+i*1.9)*(18+i*3))+'px;top:'+(deck.y-i*1.5)+'px;width:'+deck.width+'px;height:'+deck.height+'px;transform:rotate('+Math.sin(t*16+i)*14+'deg)';this.layer.append(node);}}
      for(const f of e.flights){const hold=Math.max(0,Math.min(f.hold||0,Math.max(0,f.duration-.001))),p=Math.max(0,Math.min(1,(t-f.delay-hold)/Math.max(.001,f.duration-hold)));if(t<f.delay||p>=1)continue;const from=this.resolve(f.from,f.card,true),to=this.resolve(f.to,f.card);if(!from||!to)continue;const q=f.easing==='smooth'?p*p*(3-2*p):1-(1-p)**3,node=this.face(f.card),mix=(a,b)=>a+(b-a)*q;node.style.cssText+=';position:fixed;left:'+mix(from.x,to.x)+'px;top:'+(mix(from.y,to.y)-Math.sin(p*Math.PI)*24)+'px;width:'+mix(from.width,to.width)+'px;height:'+mix(from.height,to.height)+'px;transform:rotate('+(180*(f.card.face_side||0)+Math.sin(p*Math.PI)*(f.to.zone==='discard'?12:-8))+'deg)';this.layer.append(node);}
      if(!this.paused)this.frame=requestAnimationFrame(()=>this.tick());
    }
  };
  // Public money feedback shares host timing; resolving a hidden name returns null.
  global.StarGamesMoneyEffect = class {
    constructor(resolve, {amountPrefix = '$', icon = '/ui/playful/table-cash.svg', amountBadge = true, showTransfers = true, changePlacement = 'vertical', resolveFontSize = null, resolveFont = null} = {}) {
      this.resolve = resolve; this.key = -1; this.frame = 0;
      this.amountPrefix = amountPrefix; this.icon = icon;
      this.amountBadge = amountBadge; this.showTransfers = showTransfers; this.changePlacement = changePlacement;
      this.resolveFontSize = resolveFontSize;
      this.resolveFont = resolveFont;
      this.layer = document.createElement('div'); this.layer.className = 'game-money-effect';
      this.layer.setAttribute('aria-hidden', 'true'); document.body.append(this.layer);
    }
    update(event, {paused = false, reduced = false} = {}) {
      cancelAnimationFrame(this.frame);
      const fresh = this.key >= 0 && event?.revision !== this.key;
      if (event && event.revision === this.key && this.event) event = {...event,elapsed:Math.max(event.elapsed || 0,this.event.elapsed || 0)};
      this.reduced = reduced || matchMedia('(prefers-reduced-motion: reduce)').matches;
      if (fresh) this.staticLeft = this.reduced && event?.money?.length ? .85 : 0;
      this.key = event?.revision ?? -1; this.event = event; this.paused = paused;
      this.clock = performance.now(); this.tick();
    }
    clear() { cancelAnimationFrame(this.frame); this.event = null; this.staticLeft = 0; this.layer.replaceChildren(); }
    amountText(amount) { return (amount > 0 ? '+' : '−') + this.amountPrefix + Math.abs(amount); }
    tick() {
      this.layer.replaceChildren(); const now = performance.now(), delta = (now - this.clock) / 1000;
      this.clock = now; if (!this.paused) { this.staticLeft = Math.max(0, (this.staticLeft || 0) - delta); if (this.event) this.event = {...this.event, elapsed: (this.event.elapsed || 0) + delta}; }
      const event = this.event, time = event?.elapsed || 0;
      for (const payment of event?.money || []) {
        const p = Math.max(0, Math.min(1, (time - payment.start) / payment.duration));
        if (this.reduced ? !this.staticLeft : !event.active || time < payment.start || p >= 1) continue;
        const alpha = this.reduced ? 1 : Math.min(1, p * 8) * Math.min(1, (1 - p) * 5);
        for (const change of payment.changes) {
          const rect = this.resolve(change.seat); if (!rect) continue;
          const node = document.createElement('strong'); node.className = 'game-cash-change ' + (change.amount > 0 ? 'is-gain' : 'is-loss');
          node.classList.toggle('game-cash-number', !this.amountBadge);
          node.textContent = this.amountText(change.amount);
          const distance=this.reduced?0:p*18;
          const fontSize=this.resolveFontSize?Math.max(8,Math.min(96,Number(this.resolveFontSize(change.seat))||22)):null;
          const width=this.changePlacement==='right'?Math.max(20,(fontSize||16)*1.6):this.amountBadge?92:Math.max(fontSize?fontSize*2:44,node.textContent.length*(fontSize?fontSize*.64:14));
          const height=fontSize&&!this.amountBadge?Math.ceil(fontSize*1.3):28;
          const rise=fontSize?height+4:32;
          node.style.cssText = `width:${width}px;left:${Math.min(innerWidth - width - 3, Math.max(4, this.changePlacement==='right'?rect.x+rect.width+3:rect.x + rect.width / 2 - width / 2))}px;top:${this.changePlacement==='right'?rect.y+rect.height/2-height/2-distance*.3:change.amount>0?rect.y-rise-distance:rect.y+rect.height+4+distance}px;opacity:${alpha}${fontSize?';font-size:'+fontSize+'px;line-height:1.2;height:'+height+'px':''}`;
          if(this.resolveFont)node.style.font=String(this.resolveFont(change.seat)||'');
          this.layer.append(node);
        }
        if (!this.showTransfers || this.reduced || payment.target < 0) continue;
        const from = this.resolve(payment.seat), to = this.resolve(payment.target); if (!from || !to) continue;
        for (let i = 0; i < 5; i++) {
          const travel = Math.max(0, Math.min(1, p * 1.6 - i * .12)); if (travel <= 0 || travel >= 1) continue;
          const note = document.createElement('img'); note.src = this.icon; note.alt = '';
          note.style.cssText = `left:${from.x + from.width / 2 + (to.x + to.width / 2 - from.x - from.width / 2) * travel + Math.sin(travel * Math.PI) * 62}px;top:${from.y + (to.y - from.y) * travel}px;opacity:${alpha}`;
          this.layer.append(note);
        }
      }
      if (!this.paused && (this.reduced ? this.staticLeft > 0 : event?.active && time < event.duration)) this.frame = requestAnimationFrame(() => this.tick());
    }
  };
  global.StarGamesCardEffect=class{
    constructor(face){this.face=face;this.layer=document.createElement('div');this.layer.className='game-card-effect';this.layer.setAttribute('aria-hidden','true');document.body.append(this.layer);this.key=-1;this.frame=0;}
    update(event,{paused=false,reduced=false}={}){cancelAnimationFrame(this.frame);const fresh=event?.revision!==this.key,initial=this.key<0;this.key=event?.revision??-1;this.event=event;this.clock=performance.now();this.paused=paused;this.reduced=reduced||matchMedia('(prefers-reduced-motion: reduce)').matches;if(fresh)this.staticUntil=this.reduced&&!initial&&event?.effects?.length?performance.now()+850:0;this.tick();}
    tick(){
      this.layer.replaceChildren();const e=this.event,time=(e?.elapsed||0)+(this.paused?0:(performance.now()-this.clock)/1000);
      const fx=this.reduced?e?.effects?.[0]:e?.effects?.find(effect=>time>=(effect.start||0)&&time<(effect.start||0)+(effect.duration||1.25));
      if(!fx){if(!this.paused&&e?.active&&time<e.duration)this.frame=requestAnimationFrame(()=>this.tick());return;}
      const elapsed=time-(fx.start||0),duration=fx.duration||1.25;
      if((!e.active||elapsed<0||elapsed>=duration)&&!(this.reduced&&performance.now()<this.staticUntil))return;
      const p=this.reduced ? .4 : Math.max(0,Math.min(1,elapsed/duration)),node=document.createElement('div');
      node.className='game-card-impact'+(fx.card.kind==='just-say-no'?' is-counter':'')+(this.reduced?' is-static':'');
      node.style.opacity=this.reduced?'1':String(Math.min(1,p*8)*Math.min(1,(1-p)*6));
      node.style.transform='scale('+(this.reduced?1:.85+Math.sin(Math.min(1,p*3)*Math.PI/2)*.15)+') rotate('+(this.reduced?0:Math.sin(p*Math.PI*2)*(fx.card.kind==='just-say-no'?8:4))+'deg)';
      const words=document.createElement('strong');words.textContent=fx.label;node.append(this.face(fx.card),words);this.layer.append(node);
      if(!this.paused)this.frame=requestAnimationFrame(()=>this.tick());
    }
  };
  global.StarGamesRankedResults=class{
    constructor(element,{renderCard=card=>global.StarGamesCard(card),amountIcon=''}={}){
      this.element=element;this.renderCard=renderCard;this.amountIcon=amountIcon;this.entries=[];this.maximumHeight=420;
      element.classList.add('game-ranked-results');this.observer=new ResizeObserver(()=>this.fit());this.observer.observe(element);
    }
    setEntries(entries){
      this.entries=entries;this.element.replaceChildren();
      for(const entry of entries){
        const row=document.createElement('section'),rank=document.createElement('strong'),name=document.createElement('h3'),category=document.createElement('p'),cards=document.createElement('div');
        row.className='game-ranked-result surface';row.dataset.rank=entry.rank;row.dataset.seat=entry.seat;rank.className='game-ranked-rank';rank.textContent=entry.rank;
        name.className='game-ranked-name';name.textContent=entry.name;category.className='game-ranked-category';category.textContent=entry.category;
        row.append(rank,name,category);
        if(entry.amount){const amount=document.createElement('strong');amount.className='game-ranked-amount';amount.classList.toggle('is-loss',entry.amount<0);if(this.amountIcon){const icon=document.createElement('img');icon.src=this.amountIcon;icon.alt='';amount.append(icon);}amount.append(document.createTextNode(entry.amount_text||(entry.amount>0?'+':'')+Number(entry.amount).toLocaleString('en-US')));row.append(amount);}
        cards.className='game-ranked-cards';cards.setAttribute('aria-label','Best five cards');
        cards.append(...entry.cards.map((card,index)=>{const node=this.renderCard(card);if(entry.marked_cards?.includes(index)){node.classList.add('is-selected','is-marked');if(entry.card_mark){const mark=document.createElement('span');mark.className='game-ranked-card-mark';mark.textContent=entry.card_mark;node.append(mark);node.setAttribute('aria-label',(node.getAttribute('aria-label')||card.name||'Card')+' · '+entry.card_mark);}}return node;}));
        row.append(cards);this.element.append(row);
      }
      this.fit();
    }
    fit(maximumHeight=this.maximumHeight){
      this.maximumHeight=maximumHeight;const width=this.element.clientWidth,count=this.entries.length;
      let columns=count<=4?1:2;if(width>=1000&&maximumHeight<360&&count>6)columns=3;
      const rows=Math.ceil(count/columns),cellWidth=(width-(columns-1)*8)/columns,compact=cellWidth<310;
      const height=Math.min(compact?86:80,Math.max(56,(maximumHeight-Math.max(0,rows-1)*6)/Math.max(1,rows)));
      const cardWidth=compact?Math.min(34,(cellWidth-24)/5,Math.max(12,height-50)/1.5):Math.min(46,(height-14)/1.5,(cellWidth*.49-12)/5);
      this.element.style.gridTemplateColumns='repeat('+columns+', minmax(0,1fr))';
      this.element.style.setProperty('--result-height',height+'px');this.element.style.setProperty('--result-card-width',Math.max(8,cardWidth)+'px');this.element.classList.toggle('is-compact',compact);
    }
    destroy(){this.observer.disconnect();}
  };
  // A light scrim preserves eligible player badges and leaves board fitting alone.
  global.StarGamesPlayerFocus=class {
    constructor({onConfirm=()=>{},onAction=()=>{}}={}){
      this.element=document.createElement('div');this.element.className='game-player-focus';this.element.hidden=true;
      this.svg=document.createElementNS('http://www.w3.org/2000/svg','svg');this.svg.setAttribute('aria-hidden','true');
      this.path=document.createElementNS('http://www.w3.org/2000/svg','path');this.path.setAttribute('fill-rule','evenodd');this.svg.append(this.path);
      this.prompt=document.createElement('aside');this.prompt.className='game-dialog game-table-feedback game-player-focus-prompt';
      this.message=document.createElement('p');this.message.setAttribute('role','status');
      this.confirm=document.createElement('button');this.confirm.type='button';this.confirm.className='game-compact-control';this.confirm.textContent='CONFIRM';this.confirm.addEventListener('click',onConfirm);
      this.commands=document.createElement('div');this.commands.className='game-player-focus-actions';this.onAction=onAction;this.commandsKey='';
      this.prompt.append(this.message,this.confirm,this.commands);this.element.append(this.svg,this.prompt);document.body.append(this.element);
      this.targets=[];this.avoid=[];this.counters=[];this.frame=0;
    }
    update({targets=[],prompt='',multiple=false,reducedMotion=false,avoid=[],protect=[],context=false,actions=[]}={}){
      this.targets=targets;this.avoid=avoid;this.protect=protect;this.element.hidden=!targets.length&&!context;this.svg.toggleAttribute('hidden',!targets.length);
      this.element.classList.toggle('has-reduced-motion',reducedMotion);
      if(this.message.textContent!==prompt)this.message.textContent=prompt;
      this.message.hidden=!prompt;
      this.confirm.hidden=!multiple;
      this.multiple=multiple;
      const key=JSON.stringify(actions);
      if(key!==this.commandsKey){this.commandsKey=key;this.commands.replaceChildren(...actions.map(action=>{const button=document.createElement('button');button.type='button';button.className='game-compact-control';button.textContent=action.label;button.disabled=Boolean(action.disabled);button.dataset.contextAction=action.id;button.addEventListener('click',()=>this.onAction(action.id));return button;}));}
      this.commands.hidden=!actions.length;
      this.counters.forEach(counter=>counter.remove());this.counters=[];
      for(const target of targets){
        if(!target.caption)continue;
        const counter=document.createElement('span');counter.className='game-player-focus-counter';counter.textContent=target.caption;counter.setAttribute('aria-hidden','true');this.element.append(counter);this.counters.push(counter);target.counter=counter;
      }
      if(this.element.hidden){cancelAnimationFrame(this.frame);this.frame=0;return;}
      this.layout();
      if(!this.frame)this.frame=requestAnimationFrame(()=>this.tick());
    }
    tick(){this.frame=0;if(this.element.hidden)return;this.layout();this.frame=requestAnimationFrame(()=>this.tick());}
    layout(){
      const width=innerWidth,height=innerHeight,short=height<500;
      this.svg.setAttribute('viewBox',`0 0 ${width} ${height}`);
      const rects=this.targets.map(target=>target.element.getBoundingClientRect());
      let path=`M0 0H${width}V${height}H0Z`;
      rects.forEach((rect,index)=>{
        path+=`M${rect.left-2} ${rect.top-2}H${rect.right+2}V${rect.bottom+2}H${rect.left-2}Z`;
        const counter=this.targets[index].counter;if(counter){counter.style.left=rect.right-44+'px';counter.style.top=rect.top-12+'px';}
      });
      this.path.setAttribute('d',path);
      this.prompt.classList.toggle('is-short',short);
      const horizontal=short&&(this.multiple||!this.commands.hidden);
      this.prompt.classList.toggle('is-horizontal',horizontal);
      const panelWidth=Math.min(width-32,Math.max(160,Math.min(horizontal&&!this.commands.hidden?420:300,width*(horizontal&&!this.commands.hidden?.55:horizontal?.47:short?.32:width<600?.47:.23))));
      this.prompt.style.width=panelWidth+'px';
      const panelHeight=this.prompt.getBoundingClientRect().height,preferred=short?12:height*(width<600?.26:.64);
      const obstacles=this.avoid.filter(Boolean).map(element=>element.getBoundingClientRect());
      const protectedRects=this.protect.filter(Boolean).map(element=>element.getBoundingClientRect());
      const overlap=(a,b,grow=4)=>Math.max(0,Math.min(a.right,b.right+grow)-Math.max(a.left,b.left-grow))*Math.max(0,Math.min(a.bottom,b.bottom+grow)-Math.max(a.top,b.top-grow));
      let best={x:width-panelWidth-16,y:12},score=Infinity;
      for(const inset of short?[16,86,112]:[16])for(let y=12;y<Math.max(13,height-panelHeight-12);y+=8){
        const x=Math.max(16,width-panelWidth-inset),candidate={left:x,right:x+panelWidth,top:y,bottom:y+panelHeight};
        const value=Math.abs(y-preferred)*.05+obstacles.reduce((sum,rect)=>sum+overlap(candidate,rect),0)+rects.reduce((sum,rect)=>sum+overlap(candidate,rect,18)*100,0)+protectedRects.reduce((sum,rect)=>sum+overlap(candidate,rect,6)*1000,0);
        if(value<score){best={x,y};score=value;}
      }
      this.prompt.style.left=best.x+'px';this.prompt.style.top=best.y+'px';
    }
    destroy(){cancelAnimationFrame(this.frame);this.element.remove();}
  };
  global.StarGamesProgressTrack = class {
    constructor({marker='',goal=''}={}){
      this.element=document.createElement('div');this.element.className='game-progress-track';this.element.setAttribute('role','img');
      this.dots=document.createElement('div');this.dots.className='game-progress-dots';
      const make=(icon,kind)=>{const box=document.createElement('span');box.className='game-progress-marker '+kind;const image=document.createElement('img');image.src=icon;image.alt='';image.hidden=!icon;const count=document.createElement('strong');box.append(image,count);return box;};
      this.marker=make(marker,'is-approaching');this.goal=make(goal,'is-goal');this.element.append(this.dots,this.marker,this.goal);
    }
    update({progress=0,steps=7,approaching=0,defending=0,label=''}){
      steps=Math.max(1,steps);progress=Math.max(0,Math.min(steps,progress));
      if(this.dots.children.length!==steps+1)this.dots.replaceChildren(...Array.from({length:steps+1},()=>document.createElement('i')));
      [...this.dots.children].forEach((dot,index)=>dot.classList.toggle('is-passed',index<progress));
      this.marker.style.setProperty('--progress',progress/steps);this.marker.classList.toggle('is-arrived',progress===steps);
      this.marker.lastChild.textContent=approaching;this.goal.lastChild.textContent=defending;this.element.setAttribute('aria-label',label);
    }
  };
})(window);
