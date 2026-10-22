(() => {
  "use strict";
  const $ = id => document.getElementById(id);
  let ruleCatalog=null;
  let state=null,online=false,selected=null,restoring=true,flights=[],flightUntil=0,settleTimer=0,winShown="",heldDiscard=null;
  const motion=matchMedia("(prefers-reduced-motion: reduce)");
  const suitColors={red:"#ed202e",yellow:"#f7cf05",green:"#08a750",blue:"#0869db",pink:"#f03b8b",teal:"#00a99d",orange:"#f58220",purple:"#8a4ed2"};
  let flipAnimations=[],flipVisual=null,flipFaceTimer=0;
  let effects=[];
  let sortMode="color";
  let orbitFrame=0,orbitPhase=0,orbitLast=0,orbitGeometry=null;
  let handTransfers=[];
  const celebration=new StarGamesCelebration($("board"));
  const prefix=card=>state?.gamemode==="no_mercy"?"no-mercy-":card.addon?(card.addon==="speed"&&/^\d+$/.test(card.kind)?"addon-speed-":"addon-"):card.side==="dark"?"flip-dark-":"";
  const source=card=>card.color==="wild"&&card.selected_color?`art/cards/${prefix(card)}${card.selected_color}-${card.kind}-chosen.svg`:`art/cards/${prefix(card)}${card.color}-${card.kind}.svg`;
  const addonLabels={reverse_draw2:"Reverse Draw 2",reverse_skip:"Reverse Skip",power_reverse:"Wild Power Reverse",no_u:"Wild No U",stack1:"Stack 1",stack2:"Stack 2",stack3:"Wild Stack 3",stack_number:"Wild Stack Number",swap1:"Swap 1",refresh_hand:"Refresh Hand",force_trade:"Wild Force Trade",pass_hands:"Wild Pass Hands",double_speed:"Wild Double Speed Up",pass_color:"Wild Pass Color",trick:"Trick Wild Card",color_challenge:"Wild Color Challenge",reveal_hands:"Reveal Hands",nemesis:"Wild Nemesis",petty:"Wild Petty Play",eliminator:"Wild Eliminator",instigator:"Wild Instigator",block:"Wild Block",rebound:"Wild Block & Rebound",deflect:"Wild Block & Deflect",redirect:"Wild Redirect",swap_hands:"Wild Swap Hands",double_down:"Wild Double Down",match_max:"Wild Match the Max",misery:"Wild Misery Loves Company",coupled:"Wild Coupled Up",chat:"Wild Pull You for a Chat",eggs:"Wild Eggs in One Basket",text:"I've Got a Text"};
  const label=card=>addonLabels[card.kind]?(card.color==="wild"?"":card.color+" ")+addonLabels[card.kind]:card.addon==="speed"?`${card.color} Speed Up ${card.kind}`:card.color==="wild"?({wild:"Wild",draw2:"Wild Draw Two",draw4:"Wild Draw Four",draw_color:"Wild Draw Color",reverse_draw4:"Wild Reverse Draw Four",draw6:"Wild Draw Six",draw10:"Wild Draw Ten",color_roulette:"Wild Color Roulette"})[card.kind]:`${card.color} ${({draw1:"Draw One",draw2:"Draw Two",draw5:"Draw Five",draw4:"Draw Four",discard_all:"Discard All",skip:"Skip",skip_all:"Skip Everyone",reverse:"Reverse",flip:"Flip"})[card.kind]||card.kind}`;
  let dealBase=0,dealStarted=0,dealFrame=0,dealKey=-1;
  const dealElapsed=()=>Math.min(state?.deal?.duration||0,dealBase+(state?.paused||!online?0:(performance.now()-dealStarted)/1000));
  const dealing=()=>Boolean(state?.deal&&!motion.matches&&!state.reduced_motion&&dealElapsed()<state.deal.duration);
  const localLock=()=>flightUntil>performance.now()||dealing();
  let handStart=0,handUntil=0,handTimer=0,handPosition=0,handSpacing=1,handDragging=false,dragRevision=-1;
  const handLock=()=>handUntil>performance.now();
  const send=(action,extra={})=>{
    if(!state||!online||restoring||state.paused||state.animating||localLock())return;
    controller.send({action,revision:state.revision,...extra});
  };
  function sortedHand(hand,palette=["red","yellow","green","blue"],legal=[]){
    const actions=["skip","reverse","draw1","draw2","draw4","draw5","skip_all","discard_all","flip","wild","reverse_draw4","draw6","draw10","draw_color","color_roulette",...Object.keys(addonLabels)];
    const color=card=>card.color==="wild"?palette.length:palette.indexOf(card.color);
    const rank=card=>/^\d+$/.test(card.kind)?Number(card.kind):10+actions.indexOf(card.kind);
    return [...hand].sort((a,b)=>(sortMode==="playable"?Number(legal.includes(b.id))-Number(legal.includes(a.id)):0)||color(a)-color(b)||rank(a)-rank(b)||a.id-b.id);
  }
  function playerChoice(){
    if(state.player_choice)return state.player_choice;
    if(state.phase==='swap'&&state.swap_seat===state.viewer)return {targets:state.swap_targets||[],prompt:'Choose a player to swap hands with.',action:'swap',amounts:{}};
    const offered=state.addon_choice||{};
    if(state.phase!=='addon_choice'||offered.owner!==state.viewer||!offered.targets?.length)return {};
    const multiple=offered.kind==='instigator';
    return {targets:offered.targets,prompt:multiple?'Tap players to set 0–4 cards each.':offered.prompt,compact_prompt:multiple?'Tap players: 0–4 cards.':offered.prompt,action:'addon_choose',multiple,amounts:offered.amounts||{}};
  }
  function handChoices(){const offered=state.addon_choice||{};return state.phase==='addon_choice'&&offered.owner===state.viewer&&['give','double','combo_keep'].includes(offered.kind)?(offered.cards||[]).map(card=>card.id):[];}
  function relationships(){
    const effects=[];
    for(const [title,seats,icon] of [['Coupled',state.couple,'addon-love-island'],['Basket',state.basket,'addon-love-island'],...Object.entries(state.enemies||{}).map(([owner,target])=>['Nemesis',[Number(owner),Number(target)],'addon-frenemies'])]){
      if(seats?.length===2&&seats.every(seat=>seat>=0&&seat<state.players.length))effects.push({title,seats,detail:state.players[seats[0]].display_name+' → '+state.players[seats[1]].display_name,icon:'art/rules/'+icon+'.svg',section:'Active Effects'});
    }
    return effects;
  }
  const ready=()=>online&&!restoring&&!state.paused&&!state.animating&&!localLock();
  const badgeViewable=seat=>ready()&&state.phase!=='finished'&&(state.addon_choice?.kind==='chat_take'?state.addon_choice.target===seat:!state.addon_choice?.kind&&Object.hasOwn(state.revealed_cards||{},seat));
  const discardChoice=()=>ready()&&state.turn===state.viewer&&(['opening_color','drawn_color','flip_color','roulette_color'].includes(state.phase)||['text','combo_color'].includes(state.addon_choice?.kind));
  function contextActions(){
    const actions=[],offered=state.addon_choice||{};
    if(state.phase==='finished')return {prompt:'',actions};
    if(state.addon_accept)actions.push({id:'accept',label:state.addon_accept});
    if(state.addon_decline)actions.push({id:'decline',label:'LET PARTNER DRAW'});
    if(state.can_combo)actions.push({id:'combo',label:'U-N-O COMBO'});
    if(state.can_end_enemy)actions.push({id:'end_enemy',label:'END NEMESIS'});
    let prompt='';
    if(handChoices().length)prompt=offered.prompt+' Tap a card in your hand.';
    else if(offered.kind==='chat_take')prompt="Tap "+state.players[offered.target].display_name+"'s badge to view the exchange cards.";
    else if(offered.kind==='text')prompt='Tap the discard card to choose a rule.';
    else if(offered.kind==='combo_color'||['opening_color','drawn_color','flip_color','roulette_color'].includes(state.phase))prompt='Tap the discard card to choose a color.';
    else if(Object.keys(state.revealed_cards||{}).length)prompt='Tap a highlighted player badge to view Color Challenge results.';
    return {prompt,actions};
  }
  function contextAction(id){if(contextActions().actions.some(action=>action.id===id))send(({accept:'draw',decline:'addon_decline',combo:'addon_combo',end_enemy:'addon_end_enemy'})[id]);}
  const playerTarget=seat=>online&&!restoring&&!state.paused&&!state.animating&&!localLock()&&!dealing()&&(playerChoice().targets||[]).includes(seat);
  function choosePlayer(seat){
    if(badgeViewable(seat)){if(!$('addon-view').open)$('addon-view').showModal();renderPlayerFocus();return;}
    if(!playerTarget(seat))return;
    const choice=playerChoice(),input={target:seat};
    if(choice.multiple)input.amount=((choice.amounts?.[seat]||0)+1)%5;
    send(choice.action,input);
  }
  const playerFocus=new StarGamesPlayerFocus({onConfirm:()=>{const choice=playerChoice();if(choice.multiple&&(choice.targets||[]).some(playerTarget))send('addon_choose',{value:'done'});},onAction:contextAction});
  function targetBadge(box,seat){
    const target=playerTarget(seat),viewable=badgeViewable(seat),choice=playerChoice();
    if(box.tagName==='BUTTON')box.disabled=!target&&!viewable;
    else{box.setAttribute('role','button');box.setAttribute('aria-disabled',String(!target&&!viewable));}
    box.tabIndex=target||viewable?0:-1;box.classList.toggle('is-player-target',target);box.classList.toggle('is-swap-target',target&&choice.action==='swap');box.classList.toggle('game-turn-glow',target||viewable);
    let name=state.players[seat].display_name+', '+(state.eliminated?.[seat]?'out':state.counts[seat]+' cards');
    if(target)name=(choice.action==='swap'?'Swap hands with ':'Choose ')+name+(choice.multiple?', draw '+(choice.amounts?.[seat]||0)+'; press to cycle from zero to four':'');
    if(viewable)name='View cards shown by '+name;
    const effects=relationships().filter(effect=>effect.seats.includes(seat));
    if(effects.length)name+=', '+effects.map(effect=>effect.title+': '+effect.detail).join(', ');
    box.setAttribute('aria-label',name);
    let icons=box.querySelector('.uno-seat-effects');if(!icons){icons=document.createElement('span');icons.className='uno-seat-effects';icons.setAttribute('aria-hidden','true');box.append(icons);}
    const sources=[...new Set([...effects.map(effect=>effect.icon),...(viewable?['art/rules/addon-billie-eilish.svg']:[])])],key=JSON.stringify(sources);
    if(icons.dataset.icons!==key){icons.dataset.icons=key;icons.replaceChildren(...sources.map(src=>{const icon=document.createElement('img');icon.src=src;icon.alt='';return icon;}));}
  }
  function renderPlayerFocus(){
    if(!state||!ready()||$('addon-view').open||$('colors').open){playerFocus.update();return;}
    const choice=playerChoice(),targets=(choice.targets||[]).filter(playerTarget).map(seat=>({element:seat===state.viewer?$('local-player'):document.querySelector('#players .uno-player[data-seat="'+seat+'"] .uno-player-box'),caption:choice.multiple?'+'+(choice.amounts?.[seat]||0):''}));
    const context=targets.length?{prompt:(innerHeight<500?choice.compact_prompt||choice.prompt:choice.prompt)||'',actions:[]}:contextActions();
    playerFocus.update({targets,prompt:context.prompt,actions:context.actions,context:!targets.length&&Boolean(context.prompt||context.actions.length),multiple:choice.multiple,reducedMotion:motion.matches||state.reduced_motion,avoid:[...document.querySelectorAll('.uno-player-box,.uno-backs'),$('local-player'),$('piles')],protect:[$('hand-actions'),$('active-rules'),$('hand'),document.querySelector('header')]});
  }
  const transferring=seat=>handTransfers.some(item=>(item.seat===seat||item.target===seat)&&item.until>performance.now());
  const transferCount=seat=>handTransfers.find(item=>item.seat===seat&&item.until>performance.now())?.count;
  const visualFace=card=>flipVisual&&card.id!==undefined?(flipVisual.prior.hand.find(face=>face.id===card.id)||card.opposite||card):card;
  function image(card){const img=document.createElement("img");img.src=source(visualFace(card));img.alt=label(card);return img;}
  function identity(box,seat){
    const player=state.players[seat];StarGamesTableUI.partySeat(box,player.color);box.dataset.seat=seat;
    if(!box.querySelector(".uno-player-name")){
      const name=document.createElement("span");name.className="uno-player-name";
      const count=document.createElement("span");count.className="uno-player-count game-table-stat";
      const value=document.createElement("output");value.className="uno-card-count";
      count.append(StarGamesTableUI.icon("cards"),value);box.append(StarGamesTableUI.avatar(player),name,count);
    }
    StarGamesTableUI.updateAvatar(box.querySelector('.avatar-badge'),player);
    box.querySelector(".uno-player-name").textContent=player.display_name;
    updateCount(box,seat,state.counts[seat]);
    box.setAttribute("aria-label",player.display_name+", "+(state.eliminated?.[seat]?"out":state.counts[seat]+" cards"));
    box.classList.toggle("is-current",state.turn===seat&&!state.paused&&online&&state.winner<0&&!dealing());
    box.classList.toggle("is-winner",state.winner===seat&&!state.animating&&!localLock());
  }
  function updateCount(box,seat,count){
    box.querySelector(".uno-card-count").textContent=state.eliminated?.[seat]?"OUT":String(count);
    box.querySelector(".uno-player-count").setAttribute("aria-label",count+" cards");
  }
  function renderRules(){
    const mode=ruleCatalog?.modes[state.gamemode||"classic"]||["Classic UNO","Standard rules","classic"];
    const definitions=[[...mode,"Game Mode"]];
    for(const [key,item] of Object.entries(ruleCatalog?.options||{}))if(state.options?.[key]&&(key!=="allow_mercy"||state.gamemode==="no_mercy"))definitions.push([...item,"House Rules"]);
    for(const name of state.active_addons||[])definitions.push([name,ruleCatalog?.addons[name]||"Extra action cards",ruleCatalog?.addon_icons?.[name]||"addon","Add-Ons"]);
    const items=state.active_rule_items||[...definitions.map(([title,detail,icon,section])=>({title,detail,icon:`art/rules/${icon}.svg`,section})),...relationships()];
    const key=JSON.stringify(items),panel=$("active-rules");
    if(panel.dataset.rules!==key){
      panel.dataset.rules=key;const rows=[];let section="";
      for(const item of items){
        if(item.section&&item.section!==section){const heading=document.createElement("h3");heading.className="game-rule-section";heading.textContent=item.section;rows.push(heading);}
        section=item.section||"";
        const row=document.createElement("div");row.className="game-rule-item";
        const icon=document.createElement("img");icon.src=item.icon.replace("res://Games/uno/","");icon.alt="";
        const copy=document.createElement("div"),title=document.createElement("strong"),detail=document.createElement("small");
        title.textContent=item.title;detail.textContent=item.detail;copy.append(title,detail);row.append(icon,copy);rows.push(row);
      }
      $("rules-list").replaceChildren(...rows);
    }
    panel.hidden=state.phase==="finished";
    if(panel.hidden&&$("rules-dialog").open)$("rules-dialog").close();
  }
  function renderBacks(panel,seat){
    let fan=panel.querySelector(".uno-backs");
    if(!fan){fan=document.createElement("div");fan.className="uno-backs";fan.setAttribute("aria-hidden","true");panel.append(fan);}
    const backs=state.revealed_hands?.length?state.revealed_hands:(flipVisual?flipVisual.prior.backs:state.backs);
    const count=state.eliminated?.[seat]?0:Math.min(7,state.counts[seat]);
    const cards=Array.from({length:count},(_,i)=>backs?.[seat]?.[i]||{color:"wild",kind:"back"});
    const key=JSON.stringify(cards);
    if(fan.dataset.cards!==key){fan.dataset.cards=key;fan.replaceChildren(...cards.map((card,index)=>{
      const img=image(card),offset=index-(count-1)/2;img.alt="";img.classList.add("game-table-card");
      img.style.setProperty("--back-offset",offset);img.style.setProperty("--back-curve",offset*offset*.65+"px");
      img.style.setProperty("--back-angle",offset*2+"deg");return img;
    }));}
    fan.style.setProperty("--back-count",count);fan.classList.toggle("is-transferring",transferring(seat));
    if(innerWidth>=1000&&innerHeight>560&&count){
      // Fit the rotated artwork itself directly beneath its player's stats.
      fan.style.setProperty("--back-lift","0px");fan.style.setProperty("--back-shift","0px");
      const badge=panel.querySelector('.uno-player-box').getBoundingClientRect(),rects=[...fan.children].map(card=>card.getBoundingClientRect());
      const left=Math.min(...rects.map(rect=>rect.left)),right=Math.max(...rects.map(rect=>rect.right));
      fan.style.setProperty("--back-lift",badge.bottom+6-Math.min(...rects.map(rect=>rect.top))+"px");
      fan.style.setProperty("--back-shift",(badge.left+badge.right-left-right)/2+"px");
    }
  }
  function choose(card){
    if(!ready()||handLock()||handDragging)return;
    if(handChoices().includes(card.id)){send('addon_choose',{card:card.id});return;}
    if(!state.legal_cards.includes(card.id))return;
    selected={card:card.id,revision:state.revision,color:""};
    if(card.color==="wild"&&card.kind!=="color_roulette")openColors(card);
    else playSelected();
  }
  function playSelected(){
    if(!selected)return;
    const input=selected;selected=null;
    send("play",{card:input.card,color:input.color,revision:input.revision});render();
  }
  function cardButton(card){
    const button=document.createElement("button");button.className="uno-card game-table-card";button.dataset.card=card.id;button.setAttribute("aria-label","Play "+label(card));button.append(image(card));button.addEventListener("click",()=>{if(!button.disabled)choose(card);});return button;
  }
  function updateCards(container){
    const choices=handChoices(),available=choices.length?choices:state.legal_cards;
    const active=ready()&&!handLock()&&(["play","addon_response","addon_assist"].includes(state.phase)||choices.length);
    container.querySelectorAll("[data-card]").forEach(button=>{
      const legal=active&&!button.classList.contains("is-piled")&&available.includes(Number(button.dataset.card));button.disabled=!legal;button.classList.toggle("is-playable",legal);button.classList.toggle("is-selected",Number(button.dataset.card)===selected?.card);
      button.classList.toggle("is-unplayable",ready()&&state.turn===state.viewer&&(state.phase==="play"||choices.length)&&!available.includes(Number(button.dataset.card)));
      const jump=legal&&(state.jump_cards||[]).includes(Number(button.dataset.card));button.classList.toggle("is-jump-in",jump);button.setAttribute("aria-label",(choices.length?'Choose ':jump?"Jump in with ":"Play ")+label(state.hand.find(card=>card.id===Number(button.dataset.card))));
    });
  }
  function shiftHand(direction){
    if(!state||state.paused||!online||state.animating||localLock()||handLock()||state.drawn>=0)return;
    const next=Math.max(0,Math.min(state.hand.length-7,handStart+direction));
    if(next===handStart)return;
    handStart=next;handPosition=next;handUntil=motion.matches||state.reduced_motion?0:performance.now()+260;
    clearTimeout(handTimer);render();handTimer=setTimeout(()=>{handUntil=0;render();},270);
  }
  function layoutOrbit(){
    const board=$('board').getBoundingClientRect(),piles=$('piles').getBoundingClientRect(),svg=$('table-direction');
    const scale=board.width/1000,half=Math.max(5,8.5*scale),headroom=half*3.3+Math.max(4,4*scale);
    const cx=piles.width/2,cy=piles.height*.86;
    let rx=piles.width*1.10;
    if(innerWidth>=1000&&innerHeight>560){
      for(const badge of document.querySelectorAll('#players .uno-player-box')){
        const rect=badge.getBoundingClientRect(),x=(rect.left+rect.right)/2-board.left;
        if(x<board.width*.3||x>board.width*.7)rx=Math.min(rx,Math.abs(x-(piles.left-board.left+cx))-rect.width/2-headroom-10);
      }
      rx=Math.max(rx,piles.width/2+headroom);
    }
    const centerX=piles.left-board.left+cx;
    rx=Math.min(rx,Math.max(piles.width/2+headroom,Math.min(centerX,board.width-centerX)-headroom));
    let ry=rx*.38;
    for(const label of document.querySelectorAll('.uno-pile-label')){
      const range=document.createRange();range.selectNodeContents(label);const rect=range.getBoundingClientRect();
      for(const x of [rect.left-piles.left-4,rect.right-piles.left+4]){
        const factor=Math.sqrt(Math.max(.1,1-((x-cx)/rx)**2));
        ry=Math.max(ry,(rect.bottom-piles.top-cy+half*3.3*.38+4*scale)/factor);
      }
    }
    const extentX=rx+half*3.3,extentY=ry*(1+half*3.3/rx),width=extentX*2,height=extentY*2;
    orbitGeometry={rx,ry,half,cx:extentX,cy:extentY,width,height};
    svg.setAttribute('viewBox',`0 0 ${width} ${height}`);
    svg.style.left=cx-extentX+'px';svg.style.top=cy-extentY+'px';
    svg.style.width=width+'px';svg.style.height=height+'px';
    $('orbit-shape').setAttribute('transform',state.direction<0?`translate(${width} 0) scale(-1 1)`:'');
    paintOrbit();
    return piles.top-board.top+cy+extentY;
  }
  function paintOrbit(now){
    if(!orbitGeometry)return;
    const moving=online&&!restoring&&!state.paused&&!motion.matches&&!state.reduced_motion&&!document.hidden;
    if(now&&orbitLast&&moving)orbitPhase+=(now-orbitLast)/1000*.32;
    orbitLast=moving?(now||performance.now()):0;
    const {rx,ry,half,cx,cy}=orbitGeometry,thickness=half/rx;
    const point=(angle,radius=1,tangent=0)=>[cx+(Math.cos(angle)*radius-Math.sin(angle)*tangent)*rx,cy+(Math.sin(angle)*radius+Math.cos(angle)*tangent)*ry];
    document.querySelectorAll('#orbit-shape > path').forEach((path,section)=>{
      const outer=[],inner=[],phase=-2.35+(motion.matches||state.reduced_motion?0:orbitPhase)+section*Math.PI;
      for(let step=0;step<=64;step++){const angle=phase+step/64*2.35;outer.push(point(angle,1+thickness));inner.unshift(point(angle,1-thickness));}
      const angle=phase+2.35;
      outer.push(point(angle,1+thickness*2.15),point(angle,1,thickness*3.3),point(angle,1-thickness*2.15));
      path.setAttribute('d','M'+[...outer,...inner].map(pair=>pair.map(value=>value.toFixed(2)).join(' ')).join('L')+'Z');
    });
    if(moving&&!orbitFrame)orbitFrame=requestAnimationFrame(time=>{orbitFrame=0;paintOrbit(time);});
    else if(!moving&&orbitFrame){cancelAnimationFrame(orbitFrame);orbitFrame=0;}
  }
  function layoutHand(){
    const board=$("board").getBoundingClientRect(),toolbar=$("hand-actions").getBoundingClientRect();
    const landscape=matchMedia('(max-height: 560px) and (min-width: 650px)').matches;
    const availableWidth=board.width*(landscape?.45:.92),bottom=toolbar.top-board.top-(landscape?8:18);
    const orbitBottom=layoutOrbit(),pileBottom=$("piles").getBoundingClientRect().bottom-board.top;
    const own=$("local-player");own.style.top=(landscape?Math.max(56,board.height*.22):Math.max(pileBottom+28,orbitBottom+8))+"px";
    const ownerBottom=own.getBoundingClientRect().bottom-board.top;
    const preferred=Math.min(180,board.width*(landscape?.09:.245),board.height*(landscape?.25:.24));
    const width=Math.max(44,Math.min(preferred,(bottom-ownerBottom-(landscape?34:46))/1.5));
    const count=state.hand.length,large=count>7,shown=Math.min(7,count),reserve=large?18:0,edge=width*.18;
    const spacing=Math.min(width*.68,Math.max(5,(availableWidth-reserve*2-edge*2-width)/Math.max(1,shown-1)));
    const windowWidth=width+Math.max(0,shown-1)*spacing,totalWidth=windowWidth+reserve*2+edge*2,height=width*1.5+24;
    handStart=Math.max(0,Math.min(handStart,Math.max(0,count-7)));
    handSpacing=spacing;if(!handDragging)handPosition=handStart;
    const fan=$("hand"),left=(landscape?board.width*.73:board.width*.5)-totalWidth/2,top=bottom-height;
    fan.dataset.start=handStart;fan.dataset.position=handPosition;fan.style.width=totalWidth+"px";fan.style.height=height+"px";fan.style.left=left+"px";fan.style.top=top+"px";
    [...$("hand-cards").children].forEach((button,index)=>{
      const relative=index-handPosition,piled=index<handStart||index>=handStart+7;
      const distance=relative<0?relative:relative>6?relative-6:0,depth=Math.min(4,Math.abs(distance));
      button.style.width=width+"px";button.style.left=edge+reserve+Math.max(0,Math.min(6,relative))*spacing+Math.sign(distance)*depth*Math.min(4,width*.06)+"px";
      const fanOffset=Math.max(0,Math.min(shown-1,relative))-(shown-1)/2;
      button.style.top=14+fanOffset*fanOffset*(landscape?1:1.4)+depth*1.5+"px";button.style.zIndex=piled?5-depth:10+index;
      button.style.setProperty("--fan-angle",fanOffset*(landscape?1.4:2)+"deg");
      button.classList.toggle("is-piled",piled);button.setAttribute("aria-hidden",String(piled));button.tabIndex=piled?-1:0;
    });
    for(const [id,amount] of [["hand-left",handStart],["hand-right",Math.max(0,count-handStart-7)]]){
      const button=$(id);button.hidden=!large||amount===0;button.disabled=!online||state.paused||state.animating||localLock()||state.drawn>=0;
      StarGamesTableUI.handBrowse(button,id==='hand-left'?-1:1,amount);
      button.style.top="14px";button.style.width="44px";button.style.height=Math.max(44,width*1.5)+"px";
    }
    const drawnWidth=Math.min(height*.66,Math.max(64,board.width*.1)),preview=$("draw-preview"),previewWidth=drawnWidth+110;
    preview.style.width=previewWidth+"px";preview.style.left=(landscape?board.width*.73:board.width*.5)-previewWidth/2+"px";preview.style.top=Math.max($("local-player").getBoundingClientRect().bottom-board.top+8,bottom-Math.max(drawnWidth*1.5,94))+"px";
    preview.style.setProperty("--drawn-width",drawnWidth+"px");
    positionEffects();
  }
  function render(){
    if(!state)return;
    const blocked=!online||restoring||state.paused,active=!blocked&&!state.animating&&!localLock()&&state.turn===state.viewer;
    $("status").textContent=state.status;$("event").textContent=state.last_event;
    $("board").setAttribute("aria-busy",String(state.animating||localLock()));
    $("board").setAttribute("aria-label",state.gamemode==="flip"?`UNO Flip table, ${state.side} side`:state.gamemode==="no_mercy"?"UNO No Mercy table":"UNO table");
    $("deck").querySelector("img").src=source((flipVisual?flipVisual.prior.deck_back:state.deck_back)||{color:"wild",kind:"back"});
    $("board").classList.toggle("has-reduced-motion",motion.matches||state.reduced_motion);
    $("board").classList.toggle("is-paused",blocked);
    state.hand=sortedHand(state.hand,state.colors,state.legal_cards);
    const opponents=new Set();
    state.players.forEach((player,seat)=>{
      if(seat===state.viewer)return;
      opponents.add(String(seat));

      let panel=$("players").querySelector('[data-seat="'+seat+'"]');
      if(!panel){
        panel=document.createElement("div");panel.className="uno-player";panel.dataset.seat=seat;
        const box=document.createElement("button");box.type="button";box.className="uno-player-box game-seat-badge";
        box.addEventListener("click",()=>choosePlayer(seat));
        panel.append(box);$("players").append(panel);
      }
      panel.style.order=String((seat-state.viewer+state.players.length)%state.players.length);
      const rim=state.players.length===4?[[14,17],[50,-9],[86,17]]:state.players.length===5?[[12,47],[13,6],[87,6],[88,47]]:[[12,47],[13,6],[50,-9],[87,6],[88,47]];
      const point=rim[(seat-state.viewer-1+state.players.length)%state.players.length];
      panel.classList.toggle("is-top-seat",point[0]===50);
      panel.style.setProperty("--seat-angle",(point[0]<30?-16:point[0]>70?16:0)+"deg");
      const boardArea=$("board").getBoundingClientRect(),seatY=point[0]===50?(Math.max(24,boardArea.top-boardArea.height*.16)-boardArea.top)/boardArea.height*100:point[1];
      panel.style.setProperty("--seat-x",point[0]+"%");panel.style.setProperty("--seat-y",seatY+"%");
      const box=panel.querySelector(".uno-player-box");identity(box,seat);renderBacks(panel,seat);targetBadge(box,seat);

    });
    for(const panel of [...$("players").children])if(!opponents.has(panel.dataset.seat))panel.remove();
    $("hand-cards").classList.toggle("is-transferring",transferring(state.viewer));
    identity($("local-player"),state.viewer);
    targetBadge($('local-player'),state.viewer);
    $("your-turn").hidden=blocked||state.turn!==state.viewer||state.winner>=0||dealing()||state.drawn>=0;
    $('waiting-turn').hidden=blocked||state.turn===state.viewer||state.winner>=0||dealing()||state.phase!=='play';
    $('waiting-turn').textContent=state.players[state.turn].display_name+"'s turn";
    renderRules();
    $("table-direction").classList.toggle("is-counterclockwise",state.direction<0);
    $("board").style.setProperty("--uno-color",suitColors[state.color]||suitColors.yellow);
    $("table-direction").setAttribute("aria-label",state.direction===1?"Clockwise turn order":"Counterclockwise turn order");
    const discard=heldDiscard&&heldDiscard.until>performance.now()?heldDiscard.card:flipVisual?.played||state.top;
    $("discard").src=source(discard);$("discard").alt=label(discard);
    $("draw-total").hidden=!(state.pending_draw>0);$("draw-total").textContent=state.pending_draw>0?"+"+state.pending_draw:"";
    const handKey=JSON.stringify(state.hand),large=state.hand.length>7;
    if($("hand").dataset.cards!==handKey){
      $("hand").dataset.cards=handKey;$("hand-cards").replaceChildren(...state.hand.map(cardButton));
      handUntil=0;clearTimeout(handTimer);
    }
    $("hand-cards").querySelectorAll("[data-card]").forEach(button=>{const card=state.hand.find(face=>face.id===Number(button.dataset.card));button.querySelector("img").src=source(visualFace(card));});
    $("hand").classList.toggle("is-large-hand",large);$("hand").tabIndex=large?0:-1;layoutHand();updateCards($("hand"));
    if(selected&&(blocked||selected.revision!==state.revision)){selected=null;$("colors").close();}
    const unoReady=!blocked&&!state.animating&&!localLock()&&(state.can_uno??(["play","drawn_color"].includes(state.phase)&&state.hand.length===2))&&!state.uno_armed&&(state.turn===state.viewer||(state.jump_cards||[]).length>0);
    $("uno").disabled=!unoReady;
    $("uno").classList.toggle("game-turn-glow",unoReady);
    const drawnCard=state.hand.find(card=>card.id===state.drawn),drawDecision=Boolean(drawnCard&&state.viewer===state.turn&&state.phase==="play"&&!blocked);
    $("draw-preview").hidden=!drawDecision;$("hand").classList.toggle("is-draw-decision",drawDecision);
    $("hand-actions").classList.toggle("is-draw-action",drawDecision);
    if(drawDecision){$("drawn-card").src=source(drawnCard);$("drawn-card").alt="Drawn card: "+label(drawnCard);}
    $("play-drawn").disabled=!active||!state.legal_cards.includes(state.drawn);
    $("hand-actions").style.zIndex=drawDecision?"11":"";
    const penaltyDraw=state.phase==="addon_response"&&state.addon_draw;
    const normalDraw=state.phase==="play"&&state.drawn<0&&!state.pending_color&&!state.auto_draw&&!(state.pending_draw>0&&!state.legal_cards.length)&&!(state.speed>1);
    $("deck").disabled=$("draw").disabled=!active||!(penaltyDraw||normalDraw);
    $("draw-label").textContent=state.pending_draw>0?"DRAW "+state.pending_draw:"DRAW";
    $("deck").setAttribute("aria-label",state.pending_draw>0?"Draw "+state.pending_draw+" cards":"Draw one card");
    $("pass").hidden=state.drawn<0||state.viewer!==state.turn||state.options?.force_play;$("pass").disabled=!active;
    $("replay").hidden=state.phase!=="finished";$("replay").disabled=blocked||state.animating||localLock();
    $('sort').hidden=state.phase==='finished';
    const canChooseDiscard=discardChoice();$('discard').tabIndex=canChooseDiscard?0:-1;$('discard').setAttribute('aria-disabled',String(!canChooseDiscard));$('discard').setAttribute('aria-label',canChooseDiscard?"Reopen this card's choice":'Top discard: '+label(discard));$('discard').classList.toggle('game-turn-glow',canChooseDiscard);
    $("actions").hidden=false;
    // Sorting only changes presentation, so it stays available through turns and motion.
    $("sort-label").textContent=sortMode==="color"?"COLOR":"PLAYABLE";
    $("sort").setAttribute("aria-label","Sort hand: "+(sortMode==="color"?"color, numbers, actions, then Wilds; switch to playable first":"playable cards first; switch to color order"));
    $("turn-arrow").hidden=true;
    let notice="";
    if(state.paused)notice=state.status;
    else if(state.winner>=0&&!state.animating&&!localLock())notice=state.players[state.winner].display_name+" WINS!";
    else if(state.eliminated?.[state.viewer])notice="You are out · watching this hand";
    else if(playerChoice().targets?.length)notice='';
    else if((state.phase==='roulette_color'||state.phase.startsWith('addon_'))&&!contextActions().prompt)notice=state.status;
    else if(state.speed>1)notice=`Speed ${state.speed} · ${state.speed_remaining} cards left this turn`;
    $("notice").textContent=notice;$("notice").hidden=!notice;

    const winKey=state.round_id+":"+state.winner;
    if(state.winner>=0&&!state.animating&&!localLock()&&winShown!==winKey){
      winShown=winKey;const player=state.players[state.winner];celebration.show([],player.display_name+" WINS!",player.color,!motion.matches&&!state.reduced_motion);
    }
    paintDeal();
    syncUnoMarkers();positionEffects();
    const forcedColor=active&&["drawn_color","roulette_color"].includes(state.phase);
	$("cancel-color").hidden=["drawn_color","roulette_color"].includes(state.phase);
    $("color-uno").hidden=!forcedColor||state.phase!=="drawn_color"||state.hand.length!==2||state.uno_armed;
    const needsColor=active&&(['opening_color','drawn_color','flip_color','roulette_color'].includes(state.phase)||state.addon_choice?.kind==='combo_color');
    const colorKey=needsColor?state.phase+':'+state.revision:'';
    if(colorKey!==colorChoiceKey){colorChoiceKey=colorKey;if(needsColor)openDiscardChoice();}
    layoutColors();
    renderPrivateView();
    renderPlayerFocus();
  }
  let addonViewKey='',colorChoiceKey='';
  function openDiscardChoice(){
    if(!discardChoice())return;
    if(state.addon_choice?.kind==='text'){if(!$('addon-view').open)$('addon-view').showModal();}
    else{selected={card:-1,revision:state.revision,color:''};openColors(state.phase==='drawn_color'?state.hand.find(card=>card.id===state.drawn):state.top);}
    renderPlayerFocus();
  }
  function renderPrivateView(){
    const dialog=$('addon-view');
    if(!ready()||state.phase==='finished'){addonViewKey='';if(dialog.open)dialog.close();return;}
    const offered=state.addon_choice||{},seen=state.revealed_cards||{};
    const kind=['chat_take','text'].includes(offered.kind)?offered.kind:Object.keys(seen).length&&!offered.kind?'proof':'';
    const key=JSON.stringify([kind,['chat_take','text'].includes(kind)?offered:kind==='proof'?seen:{}]);
    if(key===addonViewKey)return;addonViewKey=key;if(dialog.open)dialog.close();
    const body=$('addon-view-body'),actions=$('addon-view-actions');body.replaceChildren();actions.replaceChildren($('close-addon-view'));
    if(!kind)return;
    $('addon-view-heading').textContent=kind==='proof'?'COLOR CHALLENGE':kind==='text'?'CHOOSE A RULE':'CHOOSE AN EXCHANGE CARD';
    const add=(parent,caption,extra)=>{const button=document.createElement('button');button.type='button';button.className='game-compact-control';button.textContent=caption;button.addEventListener('click',()=>send('addon_choose',extra));parent.append(button);};
    if(kind==='text')for(const [value,caption] of [['draw','OTHERS DRAW 1'],['swap','SWAP HANDS'],['color','COLOR REVEAL']])add(body,caption,{value});
    else{
      const groups=kind==='chat_take'?{[offered.target]:offered.cards}:seen;
      for(const [target,cards] of Object.entries(groups)){
        const name=document.createElement('h3');name.textContent=state.players[target].display_name;body.append(name);
        body.append(StarGamesCardGrid(cards.map(card=>{const tile=StarGamesCardTile(image(card),{label:label(card),caption:label(card),onSelect:()=>{if(state.addon_choice?.kind==='chat_take')send('addon_choose',{card:card.id});}});tile.disabled=kind==='proof';if(kind==='chat_take')tile.dataset.addonCard=card.id;return tile;})));
      }
      if(kind==='chat_take')add(actions,'SKIP EXCHANGE',{value:'skip'});
    }
    dialog.showModal();
  }
  function openColors(card){
    const palette=state.colors||(card.side==="dark"?["pink","teal","orange","purple"]:["red","yellow","green","blue"]);
    const ordered=[palette[0],palette[3],palette[2],palette[1]];
    document.querySelectorAll("#color-sectors [data-color]").forEach((sector,index)=>{sector.dataset.color=ordered[index];sector.setAttribute("aria-label","Choose "+ordered[index][0].toUpperCase()+ordered[index].slice(1));});
    $("color-card").src=card.addon?"art/cards/wild-wild.svg":state.gamemode==="no_mercy"?source(card).replace(".svg","-picker.svg"):source(card);$("color-card").alt=label(card);
    if(!$("colors").open)$("colors").showModal();
    layoutColors();
  }
  function layoutColors(){
    if(!$("colors").open)return;
    const hand=$("hand").getBoundingClientRect(),landscape=innerHeight<560&&innerWidth>=650;
    const area=landscape?{left:16,top:56,width:Math.max(120,hand.left-32),height:innerHeight-72}:{left:16,top:56,width:innerWidth-32,height:Math.max(100,hand.top-72)};
    const cardWidth=Math.min(area.width*.7,Math.min(270,Math.max(90,area.height-44))/1.5);
    $("color-card-wrap").style.width=cardWidth+"px";
    const buttons=[...$("colors").querySelectorAll("button")].filter(button=>!button.hidden);
    const rowWidth=buttons.reduce((width,button)=>width+button.offsetWidth+12,0);
    const dialog=$("colors");dialog.style.width=Math.max(cardWidth,rowWidth)+"px";
    const rect=dialog.getBoundingClientRect();
    dialog.style.left=area.left+(area.width-rect.width)/2+"px";
    dialog.style.top=area.top+Math.max(0,(area.height-rect.height)/2)+"px";
  }

  function moveArrow(){ $("turn-arrow").hidden=true; }
  function center(element){const rect=element.getBoundingClientRect(),board=$("board").getBoundingClientRect();return [rect.left-board.left+rect.width/2,rect.top-board.top+rect.height/2];}
  function handCenter(seat){return center(seat===state.viewer?$("hand"):document.querySelector(`.uno-player[data-seat="${seat}"] .uno-backs`));}
  function dealtCount(seat){
    if(!dealing())return state.counts[seat];
    const deal=state.deal,order=(seat-deal.dealer-1+deal.seats)%deal.seats;
    return Math.max(0,Math.min(7,Math.floor((dealElapsed()-deal.shuffle-order*deal.step-deal.flight)/(deal.seats*deal.step))+1));
  }
  function clearDeal(){cancelAnimationFrame(dealFrame);dealFrame=0;$("deal-cards").replaceChildren();}
  function syncDeal(payload){
    const elapsed=dealElapsed(),fresh=dealKey!==payload.deal?.revision;
    dealKey=payload.deal?.revision??-1;dealBase=fresh?(payload.deal?.elapsed||0):Math.max(elapsed,payload.deal?.elapsed||0);dealStarted=performance.now();
    cancelAnimationFrame(dealFrame);dealFrame=0;if(fresh)$("deal-cards").replaceChildren();
  }
  function paintDeal(){
    if(!state)return;
    const running=dealing(),deal=state.deal;
    $("board").classList.toggle("is-dealing",running);
    state.players.forEach((player,seat)=>{
      const panel=seat===state.viewer?$("local-player"):document.querySelector('.uno-player[data-seat="'+seat+'"]');
      const count=transferCount(seat)??dealtCount(seat);updateCount(panel,seat,count);
      panel.querySelectorAll('.uno-backs img').forEach((img,index)=>img.classList.toggle('is-undealt',index>=count));
    });
    $("hand-cards").querySelectorAll('[data-card]').forEach((button,index)=>button.classList.toggle('is-undealt',index>=dealtCount(state.viewer)));
    if(!running){$("discard").style.visibility='';$("discard").style.transform='';$("deal-cards").replaceChildren();return;}
    $("turn-arrow").hidden=true;$("local-player").classList.remove('game-turn-glow');$("draw-total").hidden=true;
    const elapsed=dealElapsed(),reveal=Math.max(0,Math.min(1,(elapsed-deal.duration+deal.reveal)/deal.reveal));
    $("discard").style.visibility=reveal>0?'':'hidden';$("discard").style.transform='scaleX('+reveal+')';
    const layer=$("deal-cards"),board=$("board").getBoundingClientRect(),from=center($("deck")),width=$("deck").getBoundingClientRect().width;
    if(!layer.children.length){
      for(let index=0;index<deal.seats*7+4;index++){const img=image({color:'wild',kind:'back'});img.alt='';img.className='uno-dealt-card';img.style.width=width/board.width*100+'%';layer.append(img);}
    }
    [...layer.children].forEach((img,index)=>{
      let point,rotation=0;
      if(index<4){
        img.hidden=elapsed>=deal.shuffle;
        const wave=Math.sin(elapsed*26+index*Math.PI/2);point=[from[0]+wave*width*.22,from[1]-index*2];rotation=wave*7;
      }else{
        const flight=index-4,age=elapsed-deal.shuffle-flight*deal.step,t=age/deal.flight;
        img.hidden=t<0||t>=1;if(img.hidden)return;
        const seat=(deal.dealer+1+flight)%deal.seats,to=handCenter(seat),eased=t*t*(3-2*t);
        img.src=source(state.backs?.[seat]?.[Math.floor(flight/deal.seats)]||{color:'wild',kind:'back'});
        point=[from[0]+(to[0]-from[0])*eased,from[1]+(to[1]-from[1])*eased-Math.sin(t*Math.PI)*board.height*.08];rotation=Math.sin(t*Math.PI)*10;
      }
      img.style.left=point[0]/board.width*100+'%';img.style.top=point[1]/board.height*100+'%';img.style.transform='translate(-50%,-50%) rotate('+rotation+'deg)';
    });
    if(!dealFrame&&!state.paused&&online)dealFrame=requestAnimationFrame(()=>{dealFrame=0;paintDeal();if(!dealing())render();});
  }
  function positionEffects(){
    if(!state)return;
    const board=$("board").getBoundingClientRect();
    effects.forEach(({element,seat,settled})=>{
      let point=handCenter(seat);
      if(element.dataset.kind==="uno"&&settled){
        const card=seat===state.viewer?$("hand-cards").firstElementChild:document.querySelector(`.uno-player[data-seat="${seat}"] .uno-backs img`);
        if(card){const rect=card.getBoundingClientRect();point=[rect.left+rect.width/2-board.left,rect.top-board.top+(seat===state.viewer?-element.offsetHeight/2-8:element.offsetHeight/2+2)];}
        else if(seat!==state.viewer){const rect=document.querySelector(`.uno-player[data-seat="${seat}"] .uno-player-box`).getBoundingClientRect();point=[rect.left+rect.width/2-board.left,rect.bottom-board.top+element.offsetHeight/2+4];}
      }
      if(element.dataset.kind!=="uno"&&effects.some(item=>item.seat===seat&&item.element.dataset.kind==="uno"))point[1]+=Math.max(26,board.width*.035);
      element.style.left=point[0]/board.width*100+"%";element.style.top=point[1]/board.height*100+"%";
    });
  }
  const unoActive=seat=>Boolean(online&&!restoring&&state?.phase!=="finished"&&state?.uno_players?.[seat]&&state.counts[seat]===1);
  function removeEffect(item){clearTimeout(item.timer);item.animation?.cancel();item.element.remove();effects=effects.filter(value=>value!==item);}
  function settleUno(item){item.settled=true;item.element.classList.add("is-uno-hover");positionEffects();}
  function syncUnoMarkers(){
    for(const item of [...effects])if(item.element.dataset.kind==="uno"&&(state.phase==="finished"||item.settled&&!unoActive(item.seat)))removeEffect(item);
    state.players.forEach((_,seat)=>{if(unoActive(seat)&&!effects.some(item=>item.seat===seat&&item.element.dataset.kind==="uno")){
      const item=unoEffect(seat);settleUno(item);
    }});
  }
  function unoEffect(seat){
    const element=document.createElement("div"),logo=document.createElement("img");element.className="uno-player-effect";element.dataset.kind="uno";element.dataset.seat=seat;
    element.classList.toggle("is-own-uno",seat===state.viewer);
    logo.src="art/uno-logo.webp";logo.alt="";logo.addEventListener("load",positionEffects);element.append(logo);$("player-effects").append(element);
    const item={element,seat,timer:0,animation:null,settled:false};effects.push(item);return item;
  }
  function clearEffects(){effects.forEach(({element,timer,animation})=>{clearTimeout(timer);animation?.cancel();element.remove();});effects=[];}
  function freezeEffects(){effects.forEach(item=>{item.animation?.cancel();item.animation=null;});}
  function showEffects(event){
    for(const effect of event.events||[]){
      if(effect.kind==="uno"){
        effects.filter(item=>item.seat===effect.seat&&item.element.dataset.kind==="uno").forEach(removeEffect);
        const item=unoEffect(effect.seat);positionEffects();
        item.timer=setTimeout(()=>{if(unoActive(item.seat))settleUno(item);else removeEffect(item);},750);
        continue;
      }
      const element=document.createElement("div");element.className="uno-player-effect";element.dataset.kind=effect.kind;element.dataset.seat=effect.seat;
      element.classList.add("uno-effect-badge");element.style.setProperty("--effect-color",suitColors[effect.color]);element.textContent=({skip:"⊘ SKIPPED",reverse:"↔ REVERSE",wild:String(effect.color).toUpperCase(),stack:"+"+effect.amount,draw:"+"+effect.amount+" · SKIPPED",jump:"JUMP-IN",seven:"7 · SWAP",swap:"SWAPPED",pass:"PASSED",out:"OUT",flip:state.side?.toUpperCase()+" SIDE"})[effect.kind]||"";
      $("player-effects").append(element);
      const duration=1100,item={element,seat:effect.seat,timer:0,animation:null};effects.push(item);positionEffects();
      if(!motion.matches&&!state.reduced_motion)item.animation=element.animate([{transform:"translate(-50%,-50%) scale(.65)",opacity:0},{transform:"translate(-50%,-50%) scale(1.12)",opacity:1,offset:.16},{transform:"translate(-50%,-50%) scale(1)",opacity:1,offset:.75},{transform:"translate(-50%,-50%) scale(1)",opacity:0}],{duration,easing:"ease-out"});
      item.timer=setTimeout(()=>{element.remove();effects=effects.filter(value=>value!==item);},duration);
    }
  }
  function cancelFlights(){clearTimeout(flipFaceTimer);flipVisual=null;flipAnimations.forEach(animation=>animation.cancel());flipAnimations=[];flights.forEach(({animation,img})=>{animation.cancel();img.remove();});flights=[];handTransfers=[];flightUntil=0;heldDiscard=null;clearTimeout(settleTimer);}
  function animateCards(prior,event,origin,handOrigins){
    const now=performance.now(),base=Math.max(0,flightUntil-now);let delay=base,handDelay=null;
    event.flights.forEach(flight=>{
      if(flight.kind==="hand"){
        if(handDelay===null)handDelay=delay;
        const start=flight.start===undefined?handDelay:base+flight.start*1000,duration=(flight.duration??.72)*1000;
        animateHand(flight,prior,handOrigins[flight.seat],start,duration,now);
        delay=Math.max(delay,start+duration);return;
      }
      handDelay=null;
      if(flight.kind==="flip"){
        flipVisual={prior,played:event.flights.find(item=>item.kind==="play")?.card};
        clearTimeout(flipFaceTimer);flipFaceTimer=setTimeout(()=>{flipVisual=null;render();},delay+240);
        for(const element of document.querySelectorAll("#hand-cards img,.uno-backs img,#deck img,#discard")){
          const animation=element.animate([{scale:"1 1"},{scale:".015 1",offset:.5},{scale:"1 1"}],{duration:480,delay,easing:"ease-in-out"});
          flipAnimations.push(animation);animation.finished.then(()=>{flipAnimations=flipAnimations.filter(item=>item!==animation);}).catch(()=>{});
        }
        delay+=480;return;
      }
      if(flight.kind==="play")heldDiscard={card:prior.top,until:now+delay+480};
      for(let i=0;i<flight.count;i++){
        const img=image(flight.kind==="play"?flight.card:flight.backs?.[i]||prior.deck_back||{color:"wild",kind:"back"});img.alt="";img.className="uno-flying-card";$("card-flights").append(img);
        const from=flight.kind==="play"?(origin||handCenter(flight.seat)):flight.kind==="hand"?handCenter(flight.seat):center($("deck")),to=flight.kind==="play"?center($("discard")):handCenter(flight.kind==="hand"?flight.target:flight.seat);
        const board=$("board").getBoundingClientRect(),width=$("discard").getBoundingClientRect().width;img.style.width=width/board.width*100+"%";
        const frame=(p,rotation=0,scale=1)=>({left:p[0]/board.width*100+"%",top:p[1]/board.height*100+"%",transform:`translate(-50%,-50%) rotate(${rotation}deg) scale(${scale})`,opacity:1});
        const middle=[(from[0]+to[0])/2,(from[1]+to[1])/2-$("board").clientHeight*.13];
        const animation=img.animate([frame(from),frame(middle,10*state.direction,1.12),frame(to)],{duration:480,delay:delay+i*100,easing:"cubic-bezier(.3,0,.3,1)",fill:"both"});
        flights.push({animation,img});animation.finished.then(()=>{img.remove();flights=flights.filter(item=>item.img!==img);render();}).catch(()=>{});
      }
      delay+=480+Math.max(0,flight.count-1)*100;
    });
    flightUntil=now+delay;clearTimeout(settleTimer);settleTimer=setTimeout(()=>{flightUntil=0;render();},delay+15);
  }
  function animateHand(flight,prior,origin,delay,duration,now){
    const count=flight.hand_count??prior.counts[flight.seat],shown=Math.min(7,count);
    const fan=document.createElement("div");fan.className="uno-flying-hand";fan.dataset.seat=flight.seat;fan.dataset.target=flight.target;
    const board=$("board").getBoundingClientRect(),from=origin.point,to=handCenter(flight.target);
    const destination=flight.target===state.viewer?$("hand-cards").querySelector("img"):document.querySelector('.uno-player[data-seat="'+flight.target+'"] .uno-player-box');
    const endWidth=destination?.getBoundingClientRect().width||origin.width,width=origin.width;
    const spread=flight.seat===state.viewer ? .68 : .34,endSpread=flight.target===state.viewer ? .68 : .34;
    const span=width*(1+Math.max(0,shown-1)*spread),endSpan=endWidth*(1+Math.max(0,shown-1)*endSpread);
    fan.style.width=span+"px";fan.style.height=width*1.5+"px";
    for(let i=0;i<shown;i++){
      const card=flight.backs?.[i]||prior.backs?.[flight.seat]?.[i]||{color:"wild",kind:"back"};
      const img=image(card);img.alt="";img.style.width=width+"px";img.style.left=i*width*spread+"px";img.style.transform="rotate("+(i-(shown-1)/2)*4+"deg)";fan.append(img);
      img.animate([{left:i*width*spread+"px",width:width+"px"},{left:i*endWidth*endSpread+"px",width:endWidth+"px"}],{duration,delay,easing:"ease-in-out",fill:"both"});
      if(count>7&&i===shown-1)for(let depth=1;depth<=Math.min(4,count-7);depth++){
        const stacked=image(card);stacked.alt="";stacked.className="uno-transfer-stack";stacked.style.width=width+"px";stacked.style.left=(i*width*spread+(i===0?-1:1)*depth*3)+"px";stacked.style.top=depth*1.5+"px";fan.prepend(stacked);
        stacked.animate([{left:stacked.style.left,width:width+"px"},{left:(i*endWidth*endSpread+(i===0?-1:1)*depth*3)+"px",width:endWidth+"px"}],{duration,delay,easing:"ease-in-out",fill:"both"});
      }
    }
    $("card-flights").append(fan);
    const frame=(point,span,width)=>({left:(point[0]-span/2)+"px",top:(point[1]-width*.75)+"px"});
    const middle=[(from[0]+to[0])/2,(from[1]+to[1])/2-board.height*.10];
    const animation=fan.animate([frame(from,span,width),frame(middle,(span+endSpan)/2,(width+endWidth)/2),frame(to,endSpan,endWidth)],{duration,delay,easing:"cubic-bezier(.3,0,.3,1)",fill:"both"});
    const transfer={seat:flight.seat,target:flight.target,count,until:now+delay+duration};handTransfers.push(transfer);flights.push({animation,img:fan});
    animation.finished.then(()=>{fan.remove();flights=flights.filter(item=>item.img!==fan);handTransfers=handTransfers.filter(item=>item!==transfer);render();}).catch(()=>{});
  }
  const controller=new StarGamesController("uno",{
    connected:player=>{online=true;restoring=true;$("connection").textContent="Connected as "+player.display_name;$("connection").classList.add("sr-only");controller.send({action:"sync"});render();},
    disconnected:()=>{dealBase=dealElapsed();online=false;restoring=true;selected=null;cancelFlights();clearEffects();clearDeal();stopStackHold();$("colors").close();$("rules-dialog").close();$('addon-view').close();addonViewKey='';$("connection").textContent="Reconnecting…";$("connection").classList.remove("sr-only");render();},
    message:payload=>{
      if(payload.viewer<0||!Array.isArray(payload.hand)||state&&payload.revision<state.revision)return;
      const prior=state,initialSync=restoring;restoring=false;
      const reset=initialSync||!prior||prior.round_id!==payload.round_id;
      if(reset){addonViewKey='';colorChoiceKey='';}
      if(reset||payload.paused||prior.revision!==payload.revision)stopStackHold();
      let origin=null;
      const event=payload.motion,handOrigins={};
      if(prior&&!reset)for(const flight of event?.flights||[])if(flight.kind==="hand"){
        const element=flight.seat===prior.viewer?$("hand-cards").querySelector("img"):document.querySelector('.uno-player[data-seat="'+flight.seat+'"] .uno-player-box');
        handOrigins[flight.seat]={point:handCenter(flight.seat),width:element?.getBoundingClientRect().width||30};
      }
      if(event?.flights?.[0]?.kind==="play"&&event.flights[0].seat===payload.viewer){
        const card=$("hand").querySelector(`[data-card="${event.flights[0].card.id}"]`);if(card)origin=center(card);
      }
      if(reset||payload.paused){clearEffects();}
      if(reset||payload.paused||motion.matches||payload.reduced_motion){cancelFlights();handUntil=0;clearTimeout(handTimer);if(reset){selected=null;$("colors").close();celebration.clear();winShown="";handStart=0;}}
      if(handDragging&&(payload.revision!==dragRevision||payload.paused||payload.animating)){handDragging=false;handPosition=handStart;}
      syncDeal(payload);state={...payload,hand:sortedHand(payload.hand,payload.colors,payload.legal_cards)};
      if(sortMode==="playable"&&prior&&(JSON.stringify(prior.hand.map(card=>card.id))!==JSON.stringify(state.hand.map(card=>card.id))||JSON.stringify(prior.legal_cards)!==JSON.stringify(state.legal_cards)||(prior.turn!==state.turn&&state.turn===state.viewer)))handStart=0;
      render();
      if(payload.reduced_motion||motion.matches)freezeEffects();
      if(!reset&&!payload.paused&&payload.feedback?.revision!==prior.feedback?.revision)showEffects(payload.feedback||{});
      if(reset||prior.turn!==state.turn)moveArrow(reset?null:prior);
      if(!reset&&!payload.paused&&!motion.matches&&!payload.reduced_motion&&event?.flights&&event.revision!==prior.motion?.revision){animateCards(prior,event,origin,handOrigins);render();}
    },
    error:error=>{$("connection").textContent=error.message;$("connection").classList.remove("sr-only");}
  });
  for(const id of ["draw","pass"])$(id).addEventListener("click",()=>send(id));
  $("draw").prepend(StarGamesTableUI.icon("cards"));
  $("sort").prepend(StarGamesTableUI.icon("sort"));
  $("sort").addEventListener("click",()=>{if($("sort").disabled)return;sortMode=sortMode==="color"?"playable":"color";handStart=0;stopStackHold();render();});
  $("uno").addEventListener("click",()=>send("uno"));
  $("active-rules").querySelector("summary").addEventListener("click",event=>{event.preventDefault();if(!$("rules-dialog").open)$("rules-dialog").showModal();});
  $("close-rules").addEventListener("click",()=>$("rules-dialog").close());
  StarGamesDismissOnOutside($("rules-dialog"));
  $("deck").addEventListener("click",()=>send("draw"));$("replay").addEventListener("click",()=>send("play_again"));
  $("play-drawn").addEventListener("click",()=>{const card=state.hand.find(card=>card.id===state.drawn);if(card)choose(card);});
  $('discard').addEventListener('click',openDiscardChoice);
  $('discard').addEventListener('keydown',event=>{if(['Enter',' '].includes(event.key)&&discardChoice()){event.preventDefault();openDiscardChoice();}});
  $('close-addon-view').addEventListener('click',()=>$('addon-view').close());
  $('addon-view').addEventListener('close',renderPlayerFocus);
  StarGamesDismissOnOutside($('addon-view'));
  document.querySelectorAll("[data-color]").forEach(button=>{
    button.addEventListener("keydown",event=>{if(["Enter"," "].includes(event.key)){event.preventDefault();button.dispatchEvent(new MouseEvent("click",{bubbles:true}));}});
    button.addEventListener("click",()=>{
    if(!selected)return;selected.color=button.dataset.color;$("colors").close();
    if(selected.card<0){if(state.addon_choice?.kind==='combo_color')send('addon_choose',{value:selected.color,revision:selected.revision});else send("color",{color:selected.color,revision:selected.revision});selected=null;}
    else playSelected();
    });
  });
  $("color-uno").addEventListener("click",()=>send("uno"));
  $("cancel-color").addEventListener("click",()=>{selected=null;$("colors").close();render();});$("colors").addEventListener("cancel",()=>{selected=null;render();});
  let stackHold=null;
  function stopStackHold(){if(stackHold)clearInterval(stackHold.timer);stackHold=null;}
  for(const [id,direction] of [["hand-left",-3],["hand-right",3]]){
    $(id).addEventListener('pointerdown',event=>{
      if(event.button!==0||$(id).disabled)return;
      stopStackHold();event.preventDefault();event.stopPropagation();$(id).setPointerCapture(event.pointerId);
      shiftHand(direction);stackHold={id:event.pointerId,timer:setInterval(()=>shiftHand(direction),310)};
    });
    $(id).addEventListener('click',event=>{event.preventDefault();if(event.detail===0)shiftHand(direction);});
  }
  for(const event of ['pointerup','pointercancel','blur'])window.addEventListener(event,stopStackHold);
  document.addEventListener('visibilitychange',()=>{if(document.hidden)stopStackHold();paintOrbit();});
  // Browse cues keep the full end stacks tappable; a gesture never plays a card.
  // A gesture cannot also play a card on release.
  new StarGamesDragScroll($("hand"),{
    getOffset:()=>handPosition*handSpacing,
    isEnabled:()=>state&&online&&!restoring&&!state.paused&&!state.animating&&!localLock()&&!handLock()&&state.drawn<0&&state.revision===dragRevision,
    onStart:()=>{handDragging=true;dragRevision=state?.revision;stopStackHold();},
    setOffset:value=>{handPosition=Math.max(0,Math.min(state.hand.length-7,value/handSpacing));handStart=Math.round(handPosition);layoutHand();},
    onEnd:()=>{const snap=Math.abs(handPosition-handStart)>.001;handDragging=false;handPosition=handStart;if(!state)return;
      handUntil=snap&&!motion.matches&&!state.reduced_motion?performance.now()+260:0;
      clearTimeout(handTimer);layoutHand();updateCards($("hand"));if(handUntil)handTimer=setTimeout(()=>{handUntil=0;render();},270);
    }
  });
  $("hand").addEventListener("wheel",event=>{if($("hand").classList.contains("is-large-hand")){event.preventDefault();shiftHand((event.deltaX||event.deltaY)<0?-3:3);}},{passive:false});
  $("hand").addEventListener("keydown",event=>{if(event.target===$("hand")&&["ArrowLeft","ArrowRight"].includes(event.key)){event.preventDefault();shiftHand(event.key==="ArrowLeft"?-3:3);}});
  window.addEventListener("resize",()=>{cancelFlights();render();});
  window.addEventListener("gameboardresize",render);
  $('local-player').addEventListener('click',()=>choosePlayer(state.viewer));
  $('local-player').addEventListener('keydown',event=>{if(['Enter',' '].includes(event.key)&&(playerTarget(state.viewer)||badgeViewable(state.viewer))){event.preventDefault();choosePlayer(state.viewer);}});
  motion.addEventListener("change",()=>{if(motion.matches){cancelFlights();freezeEffects();handUntil=0;clearTimeout(handTimer);}render();});
  fetch("art/rules/catalog.json").then(response=>response.json()).then(catalog=>{ruleCatalog=catalog;}).finally(()=>controller.connect());
})();
