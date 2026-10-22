(() => {
  'use strict';
  const $=id=>document.getElementById(id);
  const reader=new StarGamesCardReader(()=>{});reader.dialog.id='card-reader';
  let state=null, selected=-1, key='', connected=false, payment=new Set(), movingUntil=0, paymentRevision=-1, doubles=[];
  let selectedSide=0, priorRects=new Map(), publicSeat, publicGroup, clockReceived=performance.now();
  let noticeId=-1,noticeUntil=0;
  let previewCard=-1,celebratedKey='';
  let decisionKey='';
  const tableUI=StarGamesTableUI;
  new StarGamesDragScroll($('hand'));
  const releaseDock=StarGamesHandDock.combine(document.querySelector('main'),$('private'));
  const motion=new StarGamesCardMotion(flightRect,card=>card.back?StarGamesCard({back:true},{art:art('back')}):face(card));
  const cardEffect=new StarGamesCardEffect(card=>face(card));
  const winSurface=document.createElement('div');winSurface.className='game-win-surface';document.body.append(winSurface);const winEffect=new StarGamesCelebration(winSurface);
  const controller=new StarGamesController('monopoly-deal',{
    connected:player=>{connected=true;key='';$('connection').textContent=`Connected as ${player.display_name}`;controller.send({action:'sync'});},
    disconnected:()=>{if(state?.clock){const clock=state.clock;state.clock={...clock,remaining:Math.max(0,clock.remaining-(clock.running&&!state.paused?(performance.now()-clockReceived)/1000:0)),running:false};clockReceived=performance.now();}connected=false;renderClock();key='';$('connection-overlay').hidden=false;$('decision').close();decisionKey='';$('connection').textContent='Reconnecting…';if(motion.event?.active){const event={...motion.event,elapsed:motion.elapsed()};motion.update(event,{paused:true,reduced:state?.reduced_motion});for(const node of document.querySelectorAll('.deal-controller [data-card]'))for(const animation of node.getAnimations())animation.pause();}lock();},
    message:view=>{if(view.type==='turn_clock'){if(state&&view.clock.key===state.clock?.key){state.clock=view.clock;clockReceived=performance.now();renderClock();}return;}if(view.viewer<0)return;render(view);},
    error:error=>{$('connection').textContent=error.message;}
  });
  const name=card=>state.theme.labels?.[card.key]||card.name;
  const art=key=>`/game/monopoly-deal/art/${key}.svg?v=${encodeURIComponent(state.theme.revision)}`;
  const color=card=>card.colors?.length?state.colors[card.colors[0]].color:'#17594d';
  const highestValue=cards=>[...cards].sort((a,b)=>b.value-a.value||a.id-b.id);
  const locked=()=>!connected||!state||state.paused||(state.animating&&!state.decisions_ready)||performance.now()<movingUntil;
  function send(command,revision=state.revision){if(locked()||(revision!==state.revision&&command.effect!==state.pending?.effect))return;if(selected>=0){selected=-1;reader.close();renderSelection();}controller.send({...command,revision});movingUntil=performance.now()+180;lock();setTimeout(lock,190);}
  function button(text,fn,primary=false){const b=document.createElement('button');b.textContent=text;b.className=(primary?'game-primary':'game-secondary')+' game-compact-control action-button'+(primary?'':' slate');b.addEventListener('click',fn);return b;}
  function face(card,onSelect,compact=false){const node=StarGamesCard({...card,display_name:name(card)},{art:art(card.key),color:color(card),onSelect,compact,selected:selected===card.id});node.dataset.card=card.id;return node;}
  function flightRect(zone,card,source=false){
    if(zone.zone==='deck'||zone.zone==='discard'){const rect=$('logo').getBoundingClientRect();return {x:rect.x+rect.width/2-22,y:rect.y-72,width:44,height:66};}
    if(source&&priorRects.has(card?.id))return priorRects.get(card.id);
    const node=document.querySelector('.deal-controller [data-card="'+card?.id+'"]');
    if(node&&zone.seat===state.viewer)return node.getBoundingClientRect();
    if(zone.zone==='hand'&&zone.seat===state.viewer){const rect=$('hand').getBoundingClientRect();return {x:rect.x+rect.width/2-35,y:rect.y,width:70,height:105};}
    const rect=$('players').querySelector('[data-seat="'+zone.seat+'"]')?.getBoundingClientRect();return rect?{x:rect.x+rect.width/2-22,y:rect.y,width:44,height:66}:null;
  }
  function animateState(){
    for(const node of document.querySelectorAll('.deal-controller [data-card]'))for(const animation of node.getAnimations())animation.cancel();
    motion.update(state.motion,{paused:state.paused||!connected,reduced:state.reduced_motion});
    cardEffect.update(state.motion,{paused:state.paused||!connected,reduced:state.reduced_motion});
    if(!state.motion?.active||state.reduced_motion||matchMedia('(prefers-reduced-motion: reduce)').matches)return;
    for(const flight of state.motion.flights){const remaining=(flight.delay+flight.duration-state.motion.elapsed)*1000;if(remaining<=0||flight.card.id===undefined)continue;
      for(const node of document.querySelectorAll('.deal-controller [data-card="'+flight.card.id+'"]')){const animation=node.animate([{opacity:0},{opacity:0}],{duration:remaining});if(state.paused||!connected)animation.pause();}
    }
  }
  function lock(){
    const disabled=locked();
    for(const name of $('status').querySelectorAll('.game-turn-name')){const active=connected&&!state?.paused&&state?.winner<0&&Number(name.dataset.seat)===state.turn;name.classList.toggle('is-active',active);if(active)name.setAttribute('aria-current','step');else name.removeAttribute('aria-current');}
    document.body.classList.toggle('game-table-paused',!connected||!!state?.paused);
    if(!connected||state?.paused)reader.stage.querySelector('.game-action-preview')?.stop?.();
    if(state&&(!connected||state.paused))cardEffect.update({...state.motion,elapsed:motion.elapsed()},{paused:true,reduced:state.reduced_motion});
    for(const element of document.querySelectorAll('[data-input]'))element.disabled=disabled||element.dataset.invalid==='true';
    $('end').disabled=disabled;for(const node of reader.footer.querySelectorAll('[data-reader-action]'))node.disabled=disabled||node.dataset.invalid==='true';
  }
  function input(button,invalid=false){button.dataset.input='';button.dataset.invalid=String(invalid);return button;}
  function caption(choice){const target=choice.payload.target;return choice.label+(target===undefined?'':` · ${state.players[target].display_name}`);}
  function tapChoices(card){
    let choices=state.actions.filter(c=>c.payload.card===card.id);
    if(!state.hand.some(c=>c.id===card.id))return choices;
    if(card.kind==='money')return [];
    choices=choices.filter(c=>c.payload.action!=='bank');
    choices=choices.filter(choice=>{
      const p=choice.payload;
      if(p.action==='rent'&&JSON.stringify([...p.double].sort((a,b)=>a-b))!==JSON.stringify([...doubles].sort((a,b)=>a-b)))return false;
      if(p.action==='property'||p.action==='move'){
        const same=choices.filter(c=>c.payload.color===p.color);
        const count=c=>state.table[state.viewer].groups.find(g=>g.id===c.payload.group)?.cards.length||0;
        same.sort((a,b)=>count(b)-count(a));return choice===same[0];
      }
      return true;
    });
    if(card.kind==='rent')choices.sort((a,b)=>(b.preview?.amount||0)-(a.preview?.amount||0)||a.payload.group-b.payload.group||(a.payload.target??-1)-(b.payload.target??-1));
    if(card.kind==='wild'&&card.colors.length>2){const completed=color=>state.table[state.viewer].groups.some(group=>group.color===color&&group.complete),colors=Object.keys(state.colors);choices.sort((a,b)=>Number(completed(a.payload.color))-Number(completed(b.payload.color))||state.colors[b.payload.color].rent.at(-1)-state.colors[a.payload.color].rent.at(-1)||colors.indexOf(a.payload.color)-colors.indexOf(b.payload.color));}
    return choices;
  }
  function rentCardsForDouble(card){const armed=[...new Set([...doubles,card.id])].sort((a,b)=>a-b),key=JSON.stringify(armed);return state.hand.filter(held=>held.kind==='rent').flatMap(held=>{const choices=state.actions.filter(choice=>choice.payload.card===held.id&&choice.payload.action==='rent'&&JSON.stringify([...choice.payload.double].sort((a,b)=>a-b))===key);return choices.length?[{card:held,amount:Math.max(...choices.map(choice=>choice.preview.amount)),doubles:armed}]:[];}).sort((a,b)=>b.amount-a.amount||a.card.id-b.card.id);}
  function lookup(id){return [...state.hand,...state.table.flatMap(t=>[...t.bank,...t.loose,...t.groups.flatMap(g=>[...g.cards,...g.buildings])])].find(c=>c.id===id);}
  function selectCard(card){if(!state)return;selected=card.id;selectedSide=card.face_side||0;previewCard=-1;reader.stage.scrollTop=0;renderSelection();renderSelected(card);requestAnimationFrame(()=>{reader.stage.scrollTop=0;});}
  function renderSelected(card,rotate=false){
    const mine=state.hand.some(c=>c.id===card.id)||state.table[state.viewer].groups.some(g=>[...g.cards,...g.buildings].some(c=>c.id===card.id));
    const canPlay=mine&&state.turn===state.viewer&&state.phase==='play'&&state.winner<0;
    const actions=[],revision=state.revision;
    if(canPlay){
      const bank=state.actions.find(c=>c.payload.card===card.id&&c.payload.action==='bank');
      if(bank)actions.push({label:card.kind==='money'?'BANK':`Bank $${card.value}`,action:'bank',onSelect:()=>send(bank.payload,revision)});
      const applicable=tapChoices(card).length>0,actionCard=!['money','property','wild'].includes(card.kind),pairedRent=card.kind==='double-rent'&&rentCardsForDouble(card).length>0;
      if(card.kind!=='money'&&(applicable||(actionCard&&!pairedRent)))actions.push({label:card.kind==='pass-go'?'Draw 2 cards':state.hand.some(c=>c.id===card.id)?(card.kind==='property'||card.kind==='wild'?'Add property':'Play card'):'Move card',action:'play',disabled:!applicable,onSelect:()=>{if(revision===state.revision&&selected===card.id)choosePlay(card);}});
    }
    const previousIndex=previewCard===card.id?reader.previewIndex||0:0;previewCard=card.id;
    reader.showCard(face({...card,face_side:0}),{heading:card.kind==='money'?'':name(card),actions});
    if(card.kind==='double-rent'){
      const rentals=rentCardsForDouble(card),previews=rentals.map(candidate=>({label:'Rent $'+candidate.amount,summary:'Choose a Rent card',players:[],groups:[{key:'rent-card',value:candidate.card.id,owner:state.viewer,label:'Rent $'+candidate.amount,player:state.players[state.viewer],cards:[face(candidate.card)]}]}));
      if(previews.length)reader.setPreview(previews,{presentation:'cards',onSelect:index=>{if(locked()||revision!==state.revision||selected!==card.id||!rentals[index])return;doubles=[...rentals[index].doubles];selectCard(rentals[index].card);}});
    }else if(!['money','property','wild'].includes(card.kind)||(card.kind==='wild'&&card.colors.length>2)){
      const choices=tapChoices(card),debt=card.kind==='debt-collector',previews=choices.map(choice=>{const p=choice.preview||{summary:choice.label,targets:[],cards:[]};return {label:caption(choice),summary:debt?'':p.summary,players:(p.targets||[]).map(seat=>({...state.players[seat],...(debt?{bank_total:state.table[seat].total}:p.amount?{amount:p.amount}:{})})),cards:(debt?highestValue(state.table[choice.payload.target].bank):p.cards||[]).map(card=>face(card)),groups:(p.groups||[]).map(group=>({...group,player:state.players[group.owner],cards:group.cards.map(card=>face(card))})),note:!debt&&p.counterable?'Just Say No may counter this action.':''};});
      if(previews.length)reader.setPreview(previews,{selected:Math.min(previousIndex,previews.length-1),presentation:debt?'players':'cards'});
    }
    if(card.kind==='wild'&&card.colors.length===2)reader.setRotation({side:selectedSide,label:'Use as '+state.colors[card.colors[selectedSide]].name,reduced:state.reduced_motion,animate:rotate,onRotate:()=>{selectedSide=1-selectedSide;renderSelected(card,true);}});
    lock();
  }
  function choosePlay(card){
    if(locked())return;let list=tapChoices(card);const revision=state.revision;
    if(card.kind==='wild'&&card.colors.length===2)list=list.filter(choice=>choice.payload.color===card.colors[selectedSide]);
    if(reader.dialog.classList.contains('has-action-preview')&&list.length&&(!['property','wild'].includes(card.kind)||(card.kind==='wild'&&card.colors.length>2))){send(list[Math.min(reader.previewIndex||0,list.length-1)].payload,revision);return;}
    if(list.length===1){send(list[0].payload,revision);return;}
    if(!reader.open)renderSelected(card);
    reader.setActions(list.map(choice=>({label:choice.payload.action==='property'?state.colors[choice.payload.color].name:caption(choice),action:'target',onSelect:()=>send(choice.payload,revision)})),()=>renderSelected(card));lock();
  }
  function publicZone(seat,parent,full=false){
    const data=state.table[seat],player=state.players[seat];
    const heading=button('',()=>showPublic(seat));heading.className='player-heading';
    const info=document.createElement('div');info.className='player-info';
    const who=document.createElement('div');who.className='player-name';who.textContent=(seat+1)+'  '+player.display_name;
    const stats=document.createElement('div');stats.className='player-stats';stats.append(tableUI.stat('bank','$'+data.total,'Bank: $'+data.total),tableUI.stat('cards',data.count,data.count+' cards in hand'),tableUI.stat('house',data.sets+'/3',data.sets+' of 3 complete sets'));
    const summary=document.createElement('span');summary.className='player-public-summary';if(!full&&seat!==state.viewer)summary.append(tableUI.setBars(data.groups,state.colors));info.append(who,stats);heading.append(tableUI.avatar(player,state.winner===seat),info,summary);if(state.winner===seat)(!full&&seat!==state.viewer?heading:stats).append(tableUI.winner());parent.append(heading);
    if(!full){parent.tabIndex=0;parent.setAttribute('role','button');parent.setAttribute('aria-label',player.display_name+' public table');parent.onclick=event=>{if(!event.target.closest('button'))showPublic(seat);};parent.onkeydown=event=>{if(event.target===parent&&['Enter',' '].includes(event.key)){event.preventDefault();showPublic(seat);}};}
    const groups=document.createElement('div');groups.className='group-grid deal-property-groups';parent.append(groups);
    if(!data.groups.length){const empty=document.createElement('p');empty.className='game-empty-properties';empty.textContent='No properties yet';groups.append(empty);}
    for(const group of tableUI.sortGroups(data.groups)){
      const cards=group.cards.map(card=>face({...card,face_side:card.kind==='wild'&&card.colors.length===2&&group.color===card.colors[1]?1:0}));
      if(full){const collection=document.createElement('section'),title=document.createElement('p');title.textContent=state.colors[group.color].name+' · Rent $'+group.rent+' ['+group.cards.length+'/'+state.colors[group.color].size+']';const spread=group.cards.map(card=>{const oriented={...card,face_side:card.kind==='wild'&&card.colors.length===2&&group.color===card.colors[1]?1:0};return face(oriented,()=>{closePublic();selectCard(oriented);});});while(spread.length<state.colors[group.color].size)spread.push(StarGamesCardPlaceholder());for(const card of group.buildings)spread.push(face(card,()=>{closePublic();selectCard(card);}));const strip=StarGamesCardStrip(spread,{label:state.colors[group.color].name+' properties'});strip.dataset.collection=seat+':'+group.id;collection.append(title,strip);groups.append(collection);}
      else groups.append(tableUI.group({label:state.colors[group.color].name,color:state.colors[group.color].color,count:group.cards.length,size:state.colors[group.color].size,rent:group.rent,complete:group.complete,buildings:group.buildings,rentOnly:true},cards,()=>showPublic(seat)));
    }
    if(full){
      groups.className='game-public-collections';const bank=document.createElement('section'),label=document.createElement('p');bank.className='public-bank';label.textContent='Bank $'+data.total;bank.append(label);
      const bankStrip=StarGamesCardStrip(highestValue(data.bank).map(card=>face(card,()=>{closePublic();selectCard(card);})),{label:player.display_name+' bank, highest value first'});bankStrip.dataset.collection=seat+':bank';bank.append(bankStrip);parent.append(bank);
      if(data.loose.length){const title=document.createElement('p');title.textContent='Unattached buildings';const strip=StarGamesCardStrip(data.loose.map(card=>face(card,()=>{closePublic();selectCard(card);})),{label:'Unattached buildings'});strip.dataset.collection=seat+':loose';parent.append(title,strip);}
    }
  }

  function showPublic(seat){
    const offsets=publicSeat===seat&&publicGroup===undefined?collectionOffsets():new Map();
    publicSeat=seat;publicGroup=undefined;$('public-body').replaceChildren();$('public-heading').textContent='Public table';
    for(let i=0;i<state.players.length;i++)if(seat===undefined||seat===i){const section=document.createElement('section');section.className='public-player';publicZone(i,section,true);$('public-body').append(section);}
    if(!$('public').open)$('public').showModal();
    restoreCollections(offsets);
  }
  function collectionOffsets(){return new Map([...$('public-body').querySelectorAll('[data-collection]')].map(node=>[node.dataset.collection,node.scrollLeft]));}
  function restoreCollections(offsets){for(const node of $('public-body').querySelectorAll('[data-collection]'))node.scrollLeft=offsets.get(node.dataset.collection)||0;}
  function closePublic(){$('public').close();publicGroup=undefined;publicSeat=undefined;}
  function renderSelection(){
    const card=lookup(selected);
    for(const node of $('hand').children){const chosen=Number(node.dataset.card)===selected;node.classList.toggle('is-selected',chosen);node.setAttribute('aria-pressed',String(chosen));node.style.transform=chosen?'translateY(-8px)'+(card?.kind==='wild'&&card.colors.length===2?' rotate('+selectedSide*180+'deg)':''):'';}
    lock();
  }

  function renderClock(){
    if(!state)return;const clock=state.clock;
    const seconds=Math.ceil(Math.max(0,(clock?.remaining??60)-(connected&&clock?.running&&!state.paused?(performance.now()-clockReceived)/1000:0)));
    $('turn-clock').hidden=clock?.enabled===false||state.winner>=0;$('turn-clock').textContent=Math.floor(seconds/60)+':'+String(seconds%60).padStart(2,'0');
    $('turn-clock').classList.toggle('game-danger-text',seconds<=10);$('turn-clock').setAttribute('aria-label','Turn time remaining, '+seconds+' seconds'+(clock&&!clock.running?', paused':''));
    if(noticeUntil&&performance.now()>=noticeUntil){$('notice').textContent='';noticeUntil=0;}
  }
  const clockInterval=setInterval(renderClock,200);
  addEventListener('pagehide',()=>{releaseDock();clearInterval(clockInterval);motion.update(null);cardEffect.update(null);winEffect.clear();});

  function actionContext(details){
    const actor=state.players[details.actor].display_name,target=details.target===state.viewer?'You were':state.players[details.target].display_name+' was';
    const card=details.card?name(details.card):details.kind.replaceAll('-',' ');
    let text=actor+' used '+card+'. '+target+' chosen.';
    if(details.modifiers?.length)text+=' With '+details.modifiers.map(name).join(', ')+'.';
    if(details.responder>=0){const responder=state.players[details.responder].display_name;text+=' '+responder+' played Just Say No'+(details.canceled?' to cancel it.':' as a counter; the action continues.');}
    if(details.outcome==='paid')return text+(details.paid?' Paid $'+details.paid+' to '+actor+'.':' No payable assets.');
    if(!details.canceled){
      if(details.amount)text+=' Pay $'+details.amount+' to '+actor+'.';
      else if(details.take_card){text+=' '+actor+' takes '+name(details.take_card);if(details.give_card)text+=' and gives '+name(details.give_card);text+='.';}
      else if(details.set_color)text+=' '+actor+' takes the '+state.colors[details.set_color].name+' set and its buildings.';
    }
    return text;
  }

  function renderActionNotice(){
    for(const details of state.action_notices||[]){
      if(details.id<=noticeId||(details.target!==state.viewer&&details.responder!==state.viewer&&!(details.actor===state.viewer&&details.responder>=0)))continue;
      noticeId=details.id;noticeUntil=performance.now()+8000;$('notice').textContent=actionContext(details);
    }
  }

  function renderDecision(force=false){
    const mine=(state.phase==='response'&&state.pending.ask===state.viewer)||(state.phase==='pay'&&state.pending.target===state.viewer)||(state.phase==='discard'&&state.turn===state.viewer);
    $('decision-open').hidden=!mine;$('decision-open').textContent=state.phase==='pay'?'Pay $'+state.pending.amount:'Resolve action';
    if(!mine||state.paused||(state.animating&&!state.decisions_ready)){$('decision').close();decisionKey='';return;}
    const stamp=state.phase+':'+(state.pending.effect??state.revision)+':'+state.theme.revision;
    if(!force&&decisionKey===stamp)return;
    decisionKey=stamp;
    if(reader.open)reader.close();$('public').close();
    $('decision-heading').textContent=state.phase==='discard'?'Discard to 7 cards':state.phase==='pay'?state.players[state.pending.actor].display_name+' used '+(state.pending.card?name(state.pending.card):state.pending.kind):state.pending.target===state.viewer?'You were chosen':'Just Say No played';
    $('decision-body').replaceChildren();$('decision-actions').replaceChildren();
    if(state.phase==='response'){const context=document.createElement('p');context.className='game-action-context';context.textContent=actionContext(state.pending);$('decision-body').append(context);}
    if(state.phase==='pay'){
      if(paymentRevision!==(state.pending.effect??state.revision)){payment.clear();paymentRevision=state.pending.effect??state.revision;}
      const total=document.createElement('div');total.className='payment-summary';const owed=document.createElement('div'),selectedTotal=document.createElement('div');selectedTotal.className='pay-total';const oweLabel=document.createElement('span'),oweValue=document.createElement('b'),selectLabel=document.createElement('span'),selectValue=document.createElement('b');oweLabel.textContent='YOU OWE';oweValue.textContent='$'+state.payment.amount;selectLabel.textContent='SELECTED';owed.append(oweLabel,oweValue);selectedTotal.append(selectLabel,selectValue);total.append(owed,selectedTotal);$('decision-body').append(total);
      const note=document.createElement('p');note.className='payment-note';$('decision-body').append(note);
      const command={...(state.payment.command||{action:'pay'})},revision=state.revision;const confirm=input(button('Confirm Payment',()=>send({...command,cards:[...payment]},revision),true));$('decision-actions').append(confirm);
      const own=state.table[state.viewer],all=[...own.bank,...own.loose,...own.groups.flatMap(group=>[...group.cards,...group.buildings])];
      owed.classList.add('game-owed');
      const update=()=>{const amount=all.filter(card=>payment.has(card.id)).reduce((sum,card)=>sum+card.value,0);selectValue.textContent='$'+amount;total.classList.toggle('is-covered',amount>=state.payment.amount);note.classList.toggle('game-success-text',amount>=state.payment.amount);note.textContent=amount>state.payment.amount?'Overpaid: $'+(amount-state.payment.amount):'Remaining: $'+Math.max(0,state.payment.amount-amount);confirm.dataset.invalid=String(amount<state.payment.amount&&payment.size!==state.payment.assets.length);lock();};
      const tiles=[];for(const id of state.payment.assets){const card=all.find(card=>card.id===id);if(!card)continue;let tile;tile=StarGamesCardTile(face(card),{label:'Pay with '+name(card)+', $'+card.value,caption:'$'+card.value+' · '+(own.bank.some(c=>c.id===id)?'Bank':'Property'),selected:payment.has(id),onSelect:()=>{if(payment.has(id))payment.delete(id);else payment.add(id);tile.classList.toggle('is-selected',payment.has(id));tile.setAttribute('aria-pressed',String(payment.has(id)));update();}});input(tile);tile.dataset.payCard=id;tiles.push(tile);}$('decision-body').append(StarGamesCardGrid(tiles));update();
    }else if(state.phase==='response'){
      const info=document.createElement('p');info.textContent=state.pending.canceled?'Play Just Say No to restore the action, or keep the cancellation.':'Play Just Say No to counter, or let the action continue.';$('decision-body').append(info);
      for(const choice of state.actions){const node=input(button(choice.label,()=>send(choice.payload),choice.payload.action==='no'));if(choice.payload.action==='no')node.classList.add('purple');$('decision-actions').append(node);}
    }else for(const card of state.hand){const item=input(button('Discard '+name(card),()=>send({action:'discard',card:card.id})));$('decision-body').append(item);}
    if(!$('decision').open)$('decision').showModal();lock();
  }

  function render(view){
    if(!state||view.revision!==state.revision)priorRects=new Map([...document.querySelectorAll('.deal-controller [data-card]')].map(node=>[Number(node.dataset.card),node.getBoundingClientRect()]));
    const before=state;state=view;
    document.body.classList.toggle('game-winner-table',state.winner>=0);
    if(before&&before.round!==state.round){selected=-1;selectedSide=0;doubles=[];noticeUntil=0;$('notice').textContent='';$('hand').scrollLeft=0;reader.close();closePublic();}
    clockReceived=performance.now();renderClock();$('status').replaceChildren(StarGamesTurnStrip(state.players,state.winner>=0||state.paused||!connected?-1:state.turn,{tracked:true}));$('status').setAttribute('aria-label',state.status.split('\n')[0]);document.body.classList.toggle('has-reduced-motion',!!state.reduced_motion);controller.setThemeRevision?.(state.theme.revision);
    $('logo').src='/game/monopoly-deal/art/title.svg?v='+encodeURIComponent(state.theme.revision);
    $('connection-overlay').hidden=connected&&!state.paused;$('connection-overlay').querySelector('h2').textContent=connected?(state.pause_reason||'Game paused'):'Reconnecting…';
    const nextKey=[state.revision,state.viewer,state.animating,state.paused,state.theme.revision,connected].join(':');
    if(key===nextKey){animateState();lock();return;}key=nextKey;
    if(before&&before.revision!==state.revision&&!(state.decisions_ready&&before.pending?.effect===state.pending?.effect)&&!state.reduced_motion&&!matchMedia('(prefers-reduced-motion: reduce)').matches){movingUntil=performance.now()+180;setTimeout(lock,190);}
    $('players').replaceChildren();state.players.forEach((player,index)=>{
      if(index===state.viewer)return;
      const zone=document.createElement('section');zone.className='player-zone surface';zone.dataset.seat=index;zone.classList.toggle('is-winner',index===state.winner);zone.classList.toggle('is-active',index===state.turn&&state.winner<0&&!state.paused);publicZone(index,zone);
      if(index===state.winner)$('players').prepend(zone);else $('players').append(zone);
    });
    if(state.winner>=0&&before?.winner!==state.winner){reader.close();closePublic();$('players').scrollLeft=0;}
    $('mine').classList.toggle('is-winner',state.viewer===state.winner);$('mine').classList.toggle('is-active',state.turn===state.viewer&&state.winner<0&&!state.paused);$('mine').replaceChildren();publicZone(state.viewer,$('mine'));
    $('identity').textContent=state.players[state.viewer].display_name+' · '+state.hand.length+' cards · '+state.session_wins[state.viewer]+' wins';$('hand-count').textContent=state.hand.length;
    const scroll=$('hand').scrollLeft;$('hand').replaceChildren();for(const card of state.hand){const node=face(card,()=>selectCard(card));node.dataset.card=card.id;$('hand').append(node);}$('hand').scrollLeft=scroll;
    $('end').hidden=state.turn!==state.viewer||state.phase!=='play'||state.winner>=0;
    $('end').textContent='End Turn ('+state.plays_left+'/3)';
    $('result').hidden=state.winner<0;$('result').textContent=state.winner>=0?state.players[state.winner].display_name+' wins! Waiting for the host to Play Again.':'';
    if(before&&before.revision!==state.revision){doubles=[];if(!noticeUntil)$('notice').textContent='';}
    renderActionNotice();
    const winnerKey=state.round+':'+state.winner;if(state.winner<0){winEffect.clear();celebratedKey='';}else if(!state.animating&&winnerKey!==celebratedKey){celebratedKey=winnerKey;winEffect.show([],state.players[state.winner].display_name+' WINS!',state.players[state.winner].color,!!before&&!state.reduced_motion&&!matchMedia('(prefers-reduced-motion: reduce)').matches);}
    if(selected>=0){const card=lookup(selected);if(!card){selected=-1;reader.close();}else if(reader.open)renderSelected(card);}
    renderSelection();renderDecision();if($('public').open)showPublic(publicSeat);animateState();lock();
  }

  $('end').addEventListener('click',()=>send({action:'end'}));$('show-table').addEventListener('click',()=>showPublic());$('close-public').addEventListener('click',closePublic);
  $('decision-open').addEventListener('click',()=>renderDecision(true));
  StarGamesDismissOnOutside($('public'));StarGamesDismissOnOutside($('decision'));
  $('help').addEventListener('click',()=>{selected=-1;if(state)renderSelection();reader.showReference([{src:art('help-front'),alt:'Quick Start Rules: aim, setup, your turn and ending your turn.'},{src:art('help-back'),alt:'Essential Rules: paying players, no change, wild properties, buildings, Just Say No and rent doubles.'}]);});
  controller.connect();
})();
