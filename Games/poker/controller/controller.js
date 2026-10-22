(() => {
  'use strict';
  const id=window.pokerGameId, $=name=>document.getElementById(name), motionPreference=matchMedia('(prefers-reduced-motion: reduce)');
  const ranks=['2','3','4','5','6','7','8','9','10','J','Q','K','A'], suits=['clubs','diamonds','hearts','spades'];
  let state=null, online=false, renderKey='', turnKey=-1, clockReceived=0, motionKey=-1, localUntil=0, effectKey=-1,liveEffectKey=-1;
  let reviewKey='', reviewAutomatic=false;
  let clockStoppedAt=0;
  const chips=value=>Math.max(0,Number(value)||0).toLocaleString('en-US');
  const cardData=value=>({id:value,layout:'standard',rank:ranks[value%13],suit:suits[Math.floor(value/13)],name:ranks[value%13]+' of '+suits[Math.floor(value/13)]});
  const face=data=>StarGamesCard({...data,layout:'standard'});
  const reduced=()=>!!state?.reduced_motion||motionPreference.matches;
  const cardMotion=new StarGamesCardMotion(zone=>{
    if(zone.zone==='board')return $('community').children[zone.index]?.getBoundingClientRect();
    if(zone.zone==='hand'&&zone.seat===state?.viewer)return $('hand').children[zone.index]?.getBoundingClientRect();
    if(zone.zone==='hand')return null;
    const rect=$('pot').getBoundingClientRect();return {x:rect.x+rect.width/2-20,y:rect.y+rect.height,width:40,height:60};
  },face);
  const money=new StarGamesMoneyEffect(seat=>seat===state?.viewer?$('identity').getBoundingClientRect():null);
  const celebration=new StarGamesCelebration($('private'));
  for(const side of ['left','right']){const pile=document.createElement('span');pile.className='poker-pot-chips is-'+side;pile.setAttribute('aria-hidden','true');for(let index=0;index<3;index++){const image=document.createElement('img');image.src='/game/poker/art/chip.svg';image.alt='';image.style.setProperty('--chip-index',index);pile.append(image);}$('table').append(pile);}
  const rankedResults=new StarGamesRankedResults($('showdown-hands'),{renderCard:face,amountIcon:'/game/poker/art/chip.svg'});
  let chipAnimations=[];
  function clearEffects(){cardMotion.update(null);money.clear();celebration.clear();for(const item of chipAnimations){item.animation.cancel();item.node.remove();}chipAnimations=[];}
  function locked(){return !online||!state||state.type!=='state'||state.paused||state.animating||(!reduced()&&performance.now()<localUntil)||state.phase!=='betting'||state.turn!==state.viewer||document.hidden;}
  function send(action,amount){if(locked())return;const command={action,revision:state.revision};if(amount!==undefined)command.amount=amount;controller.send(command);}
  function updateControls(){
    const legal=state?.legal||{},disabled=locked(),value=Number($('raise-value').value);
    $('fold').disabled=disabled||!legal.fold;$('call').disabled=disabled||(!legal.check&&legal.call<0);
    for(const name of ['raise-value','raise-slider'])$(name).disabled=disabled||!legal.can_raise;
    $('bet').disabled=disabled||!legal.can_raise||!Number.isSafeInteger(value)||value<legal.min_raise_to||value>legal.max_raise_to;
  }
  function updateAmountLabel(){
    StarGamesTableUI.range($('raise-slider'));
    const player=state?.players?.[state.viewer],value=Number($('raise-value').value);
    $('bet').textContent=player&&state.legal.all_in&&value===player.stack+player.street?'ALL IN':'BET';
  }
  function setAmount(value){if(!state?.legal.can_raise)return;const amount=Math.max(state.legal.min_raise_to,Math.min(state.legal.max_raise_to,Math.round(Number(value)||state.legal.min_raise_to)));$('raise-value').value=amount;$('raise-slider').value=amount;updateAmountLabel();updateControls();}
  $('fold').addEventListener('click',()=>send('fold'));
  $('call').addEventListener('click',()=>send(state.legal.check?'check':'call'));
  $('bet').addEventListener('click',()=>{const value=Number($('raise-value').value);if(Number.isSafeInteger(value)&&value>=state.legal.min_raise_to&&value<=state.legal.max_raise_to)send('raise',value);});
  $('raise-slider').addEventListener('input',()=>setAmount($('raise-slider').value));
  $('raise-value').addEventListener('input',()=>{$('raise-slider').value=$('raise-value').value;updateAmountLabel();updateControls();});
  $('raise-value').addEventListener('change',()=>setAmount($('raise-value').value));
  $('help-open').addEventListener('click',()=>$('help').showModal());$('help-close').addEventListener('click',()=>$('help').close());StarGamesDismissOnOutside($('help'));
  $('showdown-open').addEventListener('click',()=>{reviewAutomatic=false;$('showdown').showModal();updateClock();});
  $('showdown-close').addEventListener('click',()=>$('showdown').close());
  $('showdown').addEventListener('cancel',event=>{if(reviewAutomatic&&state?.phase_remaining>0)event.preventDefault();});
  function renderResults(){
    const winners=state.phase==='finished'?[state.winner]:state.hand_winners;
    $('showdown-heading').textContent=winners.map(seat=>{const result=state.hand_results.find(entry=>entry.seat===seat);return state.identities[seat].display_name+(state.showdown&&result?' with '+result.category:' wins uncontested');}).join(' & ');
    rankedResults.setEntries(state.hand_results.filter(entry=>entry.rank>0).map(entry=>({...entry,amount:entry.net??entry.amount,name:state.identities[entry.seat].display_name,marked_cards:entry.cards.flatMap((card,index)=>state.players[entry.seat].hand.includes(card)?[index]:[]),card_mark:'HOLE',cards:entry.cards.map(cardData)})));
    fitResults();
  }
  function fitResults(){
    $('showdown').style.width=Math.min(innerWidth-32,rankedResults.entries.length<=4?740:1100)+'px';
    rankedResults.fit(Math.max(140,innerHeight-214));
  }

  function render(value){
    if(value.type!=='state') {state=value;$('status').textContent=value.pause_reason||'Waiting for the host';$('hand').replaceChildren();updateControls();return;}
    const initial=state===null||state.type!=='state';state=value;clockReceived=performance.now();clockStoppedAt=online?0:clockReceived;
    controller.setBackgroundVariant('',false,!!state.reduced_motion);
    document.body.classList.toggle('has-reduced-motion',reduced());document.body.classList.toggle('game-table-paused',state.paused);
    if(motionKey!==state.motion.revision){motionKey=state.motion.revision;localUntil=performance.now()+Math.max(0,state.motion.duration-state.motion.elapsed)*1000;}
    cardMotion.update(state.motion,{paused:state.paused,reduced:reduced()});
    const key=[state.revision,state.phase,state.paused,state.animating,state.viewer,state.awaiting_resume].join(':');
    if(key!==renderKey){
      renderKey=key;
      $('mode').textContent=state.variant==='omaha'?'OMAHA HOLD’EM':'TEXAS HOLD’EM';
      document.title=$('mode').textContent;
      $('mode-rules').textContent=state.variant==='omaha'?'Pot-Limit Omaha High: exactly two of your four private cards and exactly three community cards make your five-card hand. Raises cannot exceed the pot limit shown.':'No-Limit Texas Hold’em: make the best five-card hand from your two private cards and the five community cards. You may use two, one, or none of your private cards.';
      $('pot-value').textContent=chips(state.pot);
      const winning=new Set(state.hand_winners.flatMap(seat=>state.winning_cards[String(seat)]||[]));
      $('community').replaceChildren(...Array.from({length:5},(_,index)=>{const shown=index<state.board.length,node=face(shown?cardData(state.board[index]):{back:true});node.classList.toggle('is-selected',shown&&winning.has(state.board[index]));node.dataset.index=index;return node;}));
      $('hand').classList.toggle('is-omaha',state.variant==='omaha');$('hand').replaceChildren(...state.hand.map((value,index)=>{const node=face(cardData(value));node.classList.toggle('is-selected',state.hand_winners.includes(state.viewer)&&winning.has(value));node.dataset.index=index;return node;}));
      const mine=state.identities[state.viewer],player=state.players[state.viewer],identity=$('identity');identity.replaceChildren();identity.style.setProperty('--player-color',mine.color);identity.classList.toggle('is-current',state.turn===state.viewer&&state.phase==='betting'&&!state.paused&&!player.out&&!player.folded);
      const details=document.createElement('span'),name=document.createElement('span');details.className='poker-name';name.textContent=mine.display_name;details.append(name);identity.classList.add('game-casino-player');identity.append(StarGamesTableUI.avatar(mine),details);identity.classList.toggle('is-eliminated',player.out||player.folded);
      const wager=document.createElement('span'),chip=document.createElement('img'),value=document.createElement('output');wager.className='poker-seat-bet';chip.src='/game/poker/art/chip.svg';chip.alt='';value.id='your-bet';wager.append(chip,value);wager.setAttribute('aria-label','Your current bet');identity.append(wager);
      $('category').textContent=player.out?'ELIMINATED · Spectating':player.folded?'FOLDED':state.board.length>=3?state.hand_category:'';
      $('current-bet').textContent=chips(state.current_bet);$('to-call').textContent=chips(Math.max(0,state.legal.call));$('your-bet').textContent=chips(player.street);
      $('call').textContent=state.legal.check?'✓ CHECK':'✓ '+(state.legal.call===player.stack?'ALL IN ':'CALL ')+chips(Math.max(0,state.legal.call));
      if(turnKey!==state.turn_serial){turnKey=state.turn_serial;for(const name of ['raise-value','raise-slider']){$(name).min=state.legal.min_raise_to;$(name).max=state.legal.max_raise_to;$(name).value=state.legal.min_raise_to;}}
      updateAmountLabel();
      $('raise-limit').textContent=state.legal.can_raise?'Legal total: '+chips(state.legal.min_raise_to)+'–'+chips(state.legal.max_raise_to):'Waiting for a legal betting decision';
      $('hand-info').textContent='HAND '+state.hand_number+' · BLINDS '+chips(state.small_blind)+' / '+chips(state.big_blind);
      for(const [index,node]of [...$('stages').children].entries()){const active=['preflop','flop','turn','river','showdown'].indexOf(state.stage);node.classList.toggle('is-current',index===active);if(index===active)node.setAttribute('aria-current','step');else node.removeAttribute('aria-current');}
      $('showdown-open').hidden=!['hand_over','finished'].includes(state.phase);
      $('awards').textContent='';
      const action=$('my-action');action.textContent=player.last_action==='raise'&&player.last_amount>0?'RAISED +'+chips(player.last_amount):player.last_action==='call'&&player.last_amount>0?'CALLED '+chips(player.last_amount):player.last_action==='check'?'CHECKED':'';action.classList.toggle('game-raised',player.last_action==='raise');
      if(['hand_over','finished'].includes(state.phase))renderResults();
    }
    if(['hand_over','finished'].includes(state.phase)){
      const nextReview=state.motion.revision+':'+state.hand_number;
      if(!state.animating&&!state.paused&&nextReview!==reviewKey){reviewKey=nextReview;reviewAutomatic=true;if($('help').open)$('help').close();if(!$('showdown').open)$('showdown').showModal();}
    }else if($('showdown').open){$('showdown').close();reviewAutomatic=false;}
    let status=state.pause_reason;
    if(!status){if(state.phase==='finished')status=state.identities[state.winner].display_name+' wins the tournament!';else if(state.phase==='hand_over')status='Hand complete';else if(state.phase==='runout')status='All-in runout';else status='';}
    $('status').textContent=status;$('status').hidden=!status;
    if(!initial&&effectKey!==state.motion.revision){
      effectKey=state.motion.revision;liveEffectKey=effectKey;
      for(const change of state.motion.chips||[]){if(change.seat!==state.viewer||reduced()||!state.motion.active)continue;const from=(change.award?$('pot'):$('identity')).getBoundingClientRect(),to=(change.award?$('identity'):$('pot')).getBoundingClientRect(),node=document.createElement('img');node.className='poker-chip-flight';node.src='/game/poker/art/chip.svg';node.alt='';node.style.left=(from.x+from.width/2-16)+'px';node.style.top=(from.y+from.height/2-16)+'px';document.body.append(node);const animation=node.animate([{transform:'translate(0,0)'},{transform:'translate('+(to.x+to.width/2-from.x-from.width/2)+'px,'+(to.y+to.height/2-from.y-from.height/2)+'px)'}],{duration:Math.max(0,600-state.motion.elapsed*1000),easing:'ease-out'});animation.onfinish=()=>node.remove();chipAnimations.push({animation,node});}
      if(state.phase==='finished'&&state.winner===state.viewer)celebration.show([], 'CHAMPION',mineColor(),!reduced());
      else if(state.phase==='betting')celebration.clear();
    }else if(initial)effectKey=state.motion.revision;
    if(liveEffectKey===state.motion.revision){const moneyEvent={...state.motion,money:(state.motion.chips||[]).map(change=>({start:0,duration:.6,seat:change.seat,target:-1,changes:[{seat:change.seat,amount:change.amount*(change.award?1:-1)}]}))};money.update(moneyEvent,{paused:state.paused,reduced:reduced()});}
    for(const item of chipAnimations)if(state.paused)item.animation.pause();else if(item.animation.playState==='paused')item.animation.play();
    chipAnimations=chipAnimations.filter(item=>item.animation.playState!=='finished'&&item.animation.playState!=='idle');
    updateControls();updateClock();
  }
  function mineColor(){return state?.identities[state.viewer]?.color||'#ffd77b';}
  function updateClock(){
    if(!state||state.type!=='state')return;
    const elapsed=((clockStoppedAt||performance.now())-clockReceived)/1000,remaining=Math.max(0,state.clock.remaining-(state.clock.running?elapsed:0));
    $('clock').textContent=state.clock.enabled&&state.phase==='betting'?'◷ '+Math.ceil(remaining)+'s':'';$('clock').setAttribute('aria-label','Action time remaining: '+Math.ceil(remaining)+' seconds');
    const review=Math.max(0,state.phase_remaining-(!state.paused&&!state.animating?elapsed:0));
    $('review-countdown').textContent=state.phase==='hand_over'?'◷ NEXT HAND IN '+Math.ceil(review)+' s':review>0?'◷ REVIEW · '+Math.ceil(review)+' s':'TOURNAMENT COMPLETE';
    if(state.paused&&review>0)$('review-countdown').textContent+=' · PAUSED';
    else if(!online&&review>0)$('review-countdown').textContent+=' · RECONNECTING';
    $('showdown-close').disabled=reviewAutomatic&&state.phase_remaining>0;
  }
  function tick(){
    if(state?.type==='state'){
      updateControls();updateClock();
      for(const zone of ['board','hand']){const parent=zone==='board'?$('community'):$('hand');for(const node of parent.children){const pending=!reduced()&&state.motion.active&&state.motion.flights.some(f=>f.to.zone===zone&&f.to.index===Number(node.dataset.index)&&(zone!=='hand'||f.to.seat===state.viewer)&&cardMotion.elapsed()<f.delay+f.duration);node.style.visibility=pending?'hidden':'';}}
    }
  }
  const controller=new StarGamesController(id,{connected:()=>{online=true;controller.send({action:'sync'});updateControls();},disconnected:()=>{clockStoppedAt=performance.now();online=false;$('status').textContent='Reconnecting…';$('hand').style.visibility='hidden';clearEffects();updateControls();updateClock();},message:value=>{if(online)$('hand').style.visibility='';render(value);},error:error=>{$('status').textContent=error.message;}});
  document.addEventListener('visibilitychange',()=>{$('hand').style.visibility=document.hidden?'hidden':'';if(document.hidden){clearEffects();for(const name of ['help','showdown'])if($(name).open)$(name).close();}else controller.send({action:'sync'});updateControls();});
  window.addEventListener('pagehide',clearEffects);motionPreference.addEventListener('change',()=>{clearEffects();if(state)render(state);});
  window.addEventListener('resize',()=>{fitResults();if(state?.motion)cardMotion.update(state.motion,{paused:state.paused,reduced:reduced()});});
  setInterval(tick,100);updateControls();controller.connect();
})();
