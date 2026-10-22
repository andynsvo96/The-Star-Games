// Offline Chromium fixtures using the real SDK and module scripts.
import {createServer} from 'node:http';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {resolve,join,extname,sep} from 'node:path';
import {spawn} from 'node:child_process';
const root=resolve(import.meta.dirname,'..'), output=join(root,'.test_data','uno-controller');
const chrome=process.argv[2]||process.env.CHROME_BIN||'C:/Program Files/Google/Chrome/Application/chrome.exe';
const initial={"viewer":0,"hand":[{"id":9,"color":"red","kind":"5"},{"id":13,"color":"red","kind":"7"},{"id":30,"color":"yellow","kind":"3"},{"id":42,"color":"yellow","kind":"9"},{"id":79,"color":"blue","kind":"2"},{"id":97,"color":"blue","kind":"draw2"},{"id":59,"color":"green","kind":"5"},{"id":100,"color":"wild","kind":"wild"}],"counts":[8,6,5,7,6,5],"top":{"id":44,"color":"yellow","kind":"draw2"},"color":"yellow","direction":1,"turn":0,"phase":"play","winner":-1,"revision":1,"round_id":"1","round":1,"session_wins":[0,0,0,0,0,0],"history":[],"catch_target":-1,"uno_armed":false,"drawn":-1,"legal_cards":[30,42,97,100],"last_event":"Seven cards dealt.","deck_count":65,"motion":{},"paused":false,"animating":false,"reduced_motion":false,"status":"Player 1's turn","players":[{"id":"phone-0","display_name":"Player 1","color":"#ed202e","ai":false},{"id":"phone-1","display_name":"Player 2","color":"#0869db","ai":false},{"id":"phone-2","display_name":"Player 3","color":"#08a750","ai":false},{"id":"phone-3","display_name":"Player 4","color":"#f7cf05","ai":false},{"id":"phone-4","display_name":"Player 5","color":"#ae39f2","ai":false},{"id":"phone-5","display_name":"Player 6","color":"#f52191","ai":false}]};
const boot=`
window.qaState=${JSON.stringify(initial)};window.qaSent=[];
class StarGamesController extends window.StarGamesController {
 constructor(id,handlers){super(id,handlers);window.qaHandlers=handlers;this.handlers=handlers;}
 connect(){this.handlers.connected(qaState.players[0]);this.handlers.message(structuredClone(qaState));}
 send(input){qaSent.push(input);}
}
window.StarGamesController=StarGamesController;
`;
const assertions=`
(async()=>{
 let checks=0;const check=(ok,message)=>{checks++;if(!ok)throw Error(message);};
 const capture=async name=>{window.qaCapture=name;while(window.qaCapture)await new Promise(resolve=>setTimeout(resolve,25));};
 const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms)),frames=()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
 const arrowTouches=rect=>[...document.querySelectorAll('#orbit-shape > path')].some(path=>{
  const inverse=path.getScreenCTM().inverse();
  for(let x=rect.left;x<=rect.right;x+=Math.min(6,rect.width/4))for(let y=rect.top;y<=rect.bottom;y+=Math.min(6,rect.height/4))if(path.isPointInFill(new DOMPoint(x,y).matrixTransform(inverse)))return true;
  return false;
 });
 const $=id=>document.getElementById(id),publish=(patch,advance=true)=>{qaState={...qaState,...patch,revision:qaState.revision+(advance?1:0)};qaHandlers.message(structuredClone(qaState));};
 const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
 const hand=${JSON.stringify(initial.hand)},players=${JSON.stringify(initial.players)};
 const toggleSort=message=>{
  const mode=$('sort-label').textContent,sent=qaSent.length;
  check(!$('sort').hidden&&!$('sort').disabled,'Sort stays available '+message);
  $('sort').click();check($('sort-label').textContent!==mode&&qaSent.length===sent,'Sort toggles locally '+message);
  $('sort').click();check($('sort-label').textContent===mode,'Sort restores its chosen order '+message);
 };
 const clickCard=id=>{const card=$('hand').querySelector('[data-card="'+id+'"]');card.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true}));card.click();card.dispatchEvent(new PointerEvent('pointerup',{bubbles:true}));};
 try{
  await pause(200);await frames();
  for(const count of [4,5,6]){
   publish({players:players.slice(0,count),counts:[8,6,5,7,6,5].slice(0,count)});await frames();
   const ring=$("table-direction").getBoundingClientRect(),intersects=(a,b)=>a.left<b.right&&a.right>b.left&&a.top<b.bottom&&a.bottom>b.top;
   check([...document.querySelectorAll("#players .uno-player")].every(player=>!intersects(player.querySelector('.uno-player-box').getBoundingClientRect(),$('piles').getBoundingClientRect())),count+" players stay clear of the center cards and arrows: "+JSON.stringify({ring:ring.toJSON(),players:[...document.querySelectorAll("#players .uno-player")].map(player=>({seat:player.dataset.seat,rect:player.getBoundingClientRect().toJSON()}))}));
   check([...document.querySelectorAll("#players .uno-player-box")].every(box=>box.getBoundingClientRect().top>=0),count+" player identities remain on screen");
   check([...document.querySelectorAll('#players .uno-player-box')].every(box=>!arrowTouches(box.getBoundingClientRect())),count+' player badges have a clear arrow path');
   check([...document.querySelectorAll('.uno-pile-label')].every(label=>{const range=document.createRange();range.selectNodeContents(label);return !arrowTouches(range.getBoundingClientRect());}),count+' players keep both pile captions clear of the arrows');
   if(innerWidth>=1000&&innerHeight>560){
    const piles=$('piles').getBoundingClientRect(),cx=(piles.left+piles.right)/2,cy=(piles.top+piles.bottom)/2;
    const angles=Array.from({length:count},(_,seat)=>{const rect=(seat===0?$('local-player'):document.querySelector('#players .uno-player[data-seat="'+seat+'"] .uno-player-box')).getBoundingClientRect();return Math.atan2((rect.top+rect.bottom)/2-cy,(rect.left+rect.right)/2-cx);});
    check(angles.every((angle,index)=>(angles[(index+1)%count]-angle+Math.PI*2)%(Math.PI*2)<Math.PI),count+' seats follow the clockwise arrow order around the table');
   }
   const turn=$('your-turn').getBoundingClientRect();
   check($('your-turn').hidden||[...$('hand-cards').children].every(card=>!intersects(card.getBoundingClientRect(),turn)),count+' players keep the turn tab clear of the private hand: '+JSON.stringify({tab:turn.toJSON(),owner:$('local-player').getBoundingClientRect().toJSON(),hand:$('hand').getBoundingClientRect().toJSON(),cards:[...$('hand-cards').children].map(card=>card.getBoundingClientRect().toJSON())}));
   await capture("table-"+count);
  }
  publish({players,counts:[8,6,5,7,6,5]});await frames();
  const beforeForce=qaSent.length;publish({options:{force_play:true},forced_play:false,drawn:-1});await pause(120);
  check(qaSent.length===beforeForce&&!$('hand').querySelector('[data-card="30"]').disabled&&$('draw-preview').hidden,'Force Play leaves existing playable cards manual');
  publish({options:{force_play:false}});
  check(document.querySelectorAll('#players .uno-player-box').length===5,'Only opponents appear around the table');
  check($('local-player').dataset.seat==='0'&&$('local-player').querySelector('.uno-card-count').textContent==='8','Local player appears once with a card icon and exact count');
  check(document.querySelectorAll('.uno-backs img').length===29&&document.querySelectorAll('#players .uno-card-count').length===5,'Opponents show card backs beneath exact card counts');
  check(!$('uno').hidden&&$('uno').disabled&&!$('uno').classList.contains('game-turn-glow'),'UNO remains visible and grey for an eight-card hand');
  const inactiveUnoSent=qaSent.length;$('uno').click();check(qaSent.length===inactiveUnoSent,'A disabled UNO button cannot send a declaration');
  check(!$('color-indicator')&&!$('color-label'),'The standalone center color label is removed');
  const ownRect=$('local-player').getBoundingClientRect(),pileRect=$('piles').getBoundingClientRect();
  if(innerHeight>560)check(ownRect.top>pileRect.bottom&&$('hand').getBoundingClientRect().top>ownRect.bottom,'The owner status sits between the piles and private cards');
  check([...document.querySelectorAll('.uno-backs')].every(fan=>Math.min(...[...fan.children].map(card=>card.getBoundingClientRect().top))>fan.previousElementSibling.getBoundingClientRect().bottom),'Opponent card artwork appears below player stats');
  if(innerWidth>=1000&&innerHeight>560)check([...document.querySelectorAll('.uno-backs')].every(fan=>{
    const badge=fan.previousElementSibling.getBoundingClientRect(),cards=[...fan.children].map(card=>card.getBoundingClientRect());
    const top=Math.min(...cards.map(rect=>rect.top)),left=Math.min(...cards.map(rect=>rect.left)),right=Math.max(...cards.map(rect=>rect.right));
    return Math.abs(top-badge.bottom-6)<1&&Math.abs((left+right-badge.left-badge.right)/2)<1;
  }),'Rotated card artwork hugs and centers directly beneath each opponent badge');
  check(!document.querySelector('.is-winner')&&[...document.querySelectorAll('.uno-player-box')].every(box=>getComputedStyle(box,'::before').content==='none'),'Active players have no winner crown');
  check([...$('hand-cards').children].every(card=>getComputedStyle(card).outlineStyle==='none'),'Playable cards have no gold outline');
  check([...$('hand-cards').children].filter(card=>!qaState.legal_cards.includes(Number(card.dataset.card))).every(card=>card.classList.contains('is-unplayable')&&getComputedStyle(card).filter.includes('brightness(0.7)')),'Unplayable cards dim on your turn');
  check(document.querySelector('#local-player .game-table-icon')&&document.querySelectorAll('#players .game-table-icon').length===5,'All card counts use shared icons');
  const plaque=$('local-player'),identityColor=plaque.style.getPropertyValue('--seat-color');StarGamesTableUI.partySeat(plaque,'#ffffff');
  const gradientColors=[...getComputedStyle(plaque).backgroundImage.matchAll(/color\\(srgb ([^)]+)\\)/g)].map(match=>match[1].trim().split(/\\s+/).slice(0,3).map(Number));
  const luminance=rgb=>rgb.map(value=>value<=.04045?value/12.92:((value+.055)/1.055)**2.4).reduce((sum,value,index)=>sum+value*[.2126,.7152,.0722][index],0);
  check(gradientColors.length===2&&gradientColors.every(rgb=>1.05/(luminance(rgb)+.05)>=4.5),'White player identities keep readable white names across both gradient ends');
  for(const color of ['#ffffff','#000000','#e5e7eb','#f7cf05']){
    StarGamesTableUI.partySeat(plaque,color);
    const colors=[...getComputedStyle(plaque.querySelector('.avatar-badge')).backgroundImage.matchAll(/color\\(srgb ([^)]+)\\)/g)].map(match=>match[1].trim().split(/\\s+/).slice(0,3).map(Number));
    check(colors.length>0&&colors.every(rgb=>1.05/(luminance(rgb)+.05)>=4.5),'The shared white avatar is visible on '+color+' identities');
  }
  StarGamesTableUI.partySeat(plaque,identityColor);
  const waitingPlayers=structuredClone(players);waitingPlayers[0].color='#ffffff';waitingPlayers[0].pose=5;waitingPlayers[1].display_name='Jack <b>literal</b>';
  publish({players:waitingPlayers,turn:1,legal_cards:[]});await frames();
  toggleSort("during another player's turn");
  check(!document.querySelector('#hand .is-unplayable'),'Cards keep normal brightness while waiting for another turn');
  check(!$('waiting-turn').hidden&&$('waiting-turn').textContent==="Jack <b>literal</b>'s turn"&&!$('waiting-turn').children.length&&!$('draw').hidden&&$('draw').disabled,'Waiting players see the current name literally while Draw stays visible and grey');
  const waitingDrawSent=qaSent.length;$('draw').click();check(qaSent.length===waitingDrawSent,'A grey Draw button cannot submit a draw');
  check($('local-player').querySelector('.avatar-badge').style.getPropertyValue('--player-color')==='#ffffff'&&$('local-player').querySelector('.avatar-badge').style.getPropertyValue('--pose').includes('avatar-5.svg'),'Identity snapshots refresh the existing avatar color and pose');
  const waitingRange=document.createRange();waitingRange.selectNodeContents($('waiting-turn'));const waitingRect=waitingRange.getBoundingClientRect();
  check([...$('hand-cards').children].filter(card=>!card.classList.contains('is-piled')).every(card=>{const rect=card.getBoundingClientRect();return rect.top>=waitingRect.bottom||rect.right<=waitingRect.left||rect.left>=waitingRect.right;}),'Waiting text remains clear of the private fan');
  if(innerWidth<600&&innerHeight>560)check($('hand').getBoundingClientRect().top-$('local-player').getBoundingClientRect().bottom<70,'Portrait waiting state keeps the private hand near its badge');
  await capture('waiting-light-avatar');publish({players,turn:0,legal_cards:[30,42,97,100]});
  const initialOrder=[...$('hand-cards').children].map(card=>Number(card.dataset.card));
  $('sort').click();check($('sort-label').textContent==='PLAYABLE','Sort switches to playable-first mode');
  check([...$('hand-cards').children].slice(0,4).every(card=>qaState.legal_cards.includes(Number(card.dataset.card))),'Playable-first puts all legal cards first');
  $("hand-right").click();publish({legal_cards:[100]});check($("hand").dataset.start==="0","Changed playable cards restore the first hand window");check(Number($('hand-cards').firstElementChild.dataset.card)===100,'Playable sorting follows new authoritative legal cards');
  $('sort').click();publish({legal_cards:[30,42,97,100]});
  check([...$('hand-cards').children].map(card=>Number(card.dataset.card)).join()===initialOrder.join(),'Color mode restores stable number/action ordering with Wilds last');
  publish({options:{allow_stacking:true,allow_seven_zero:true},active_addons:['Speed']});
  check(['Classic UNO','Stacking On','7-0','Speed'].every(label=>$('rules-dialog').textContent.includes(label)),'Illustrated rules panel shows applied mode, house rules and add-ons');
  check(document.querySelectorAll('.game-rule-item img').length===4&&document.querySelector('.game-rule-item small').textContent==='Standard rules','Each rule has an illustrated icon, title and description');
  check([...$('rules-list').querySelectorAll('.game-rule-section')].map(heading=>heading.textContent).join('|')==='Game Mode|House Rules|Add-Ons','Mode, house rules and add-ons have separate headings');
  check(Math.abs($('active-rules').getBoundingClientRect().left+$('active-rules').getBoundingClientRect().width/2-innerWidth/2)<2,'The phone rules panel is centered');
  const rulesBoard=$('board').getBoundingClientRect();$('active-rules').querySelector('summary').click();await frames();
  const rulesRect=$('rules-dialog').getBoundingClientRect(),closeRules=$('close-rules').getBoundingClientRect();
  check($('rules-dialog').open&&rulesRect.left>=0&&rulesRect.right<=innerWidth&&rulesRect.top>=0&&rulesRect.bottom<=innerHeight&&closeRules.bottom<=innerHeight,'Rules open in a fitted shared dialog with a reachable Close action');
  await capture('rules-expanded');$('close-rules').click();await frames();
  check(!$('rules-dialog').open&&Math.abs($('board').getBoundingClientRect().top-rulesBoard.top)<1,'Closing rules restores the same fitted table and hand controls');
  publish({options:{allow_stacking:false,allow_seven_zero:false},active_addons:[]});
  check(!$('rules-dialog').textContent.includes('Stacking'),'Disabled house rules disappear from the panel');
  const composition=document.querySelector('.game-playfield').getBoundingClientRect();
  check(Math.abs((composition.top+composition.bottom)/2-innerHeight/2)<4,'Complete player UI is centered on first entry');
  const recent={number:1,seat:1,card:{id:23,color:'red',kind:'reverse'},color:'red',note:'Direction is now clockwise.'};
  publish({latest_play:recent});await frames();
  check(!$('play-feedback'),'Accepted plays do not add a redundant player action indicator');
  const afterFeedback=document.querySelector('.game-playfield').getBoundingClientRect();
  check(Math.abs(afterFeedback.top-composition.top)<2&&Math.abs(afterFeedback.bottom-composition.bottom)<2,'The play message preserves the fitted composition');
  await capture('recent-play');publish({},false);
  qaHandlers.disconnected();qaHandlers.connected(players[0]);publish({});
  check(!$('play-feedback'),'Reconnect preserves the table without a player action indicator');

  check(!$('challenge')&&!$('accept')&&!$('proof'),'Challenge UI is removed');
  check(!document.querySelector('[title]'),'No hover popups');
  check([...document.images].every(img=>img.complete&&img.naturalWidth>0),'Artwork loads offline');
  check(!document.querySelector('.game-title-art')&&$('status').classList.contains('sr-only'),'Top logo is removed and turn text stays accessible');
  check(!$('direction')&&!$('current-color')&&$('table-direction'),'Table direction and color text are replaced by table arrows');
  check(!reduced||getComputedStyle(document.querySelector('.uno-orbit-arrows')).animationName==='none','Device reduced motion also keeps table arrows static');
  const orbitBefore=document.querySelector('#orbit-shape > path').getAttribute('d');await pause(120);
  check((document.querySelector('#orbit-shape > path').getAttribute('d')===orbitBefore)===reduced,'Arrow geometry rotates in ordinary play and stays still under reduced motion');
  check(!$('all-cards')&&!$('expand-hand'),'Large-hand popup and caption are removed');
  publish({direction:-1});check($('table-direction').classList.contains('is-counterclockwise')&&$('orbit-shape').getAttribute('transform').includes('scale(-1 1)'),'Reverse flips the arrow heads and orbit direction');
  publish({direction:1});
  check($('hand-right').textContent.includes('1 ›')&&getComputedStyle($('hand-right')).backgroundColor==='rgba(0, 0, 0, 0)','End stacks show a small count and chevron without covering the whole stack');
  check($('hand-right').getBoundingClientRect().width>=44&&$('hand-right').getBoundingClientRect().height>=44,'Browse cues retain full touch targets');
  check($('hand').querySelectorAll('[data-card]').length===8&&getComputedStyle($('hand')).overflowX==='visible','Every card stays in the fan without clipping or a scrollbar');
  check([...$('hand').querySelectorAll('[data-card]')].filter(button=>!button.disabled).length===3,'Only legal cards in the seven-card window can be played');
  const deal={revision:1,active:true,elapsed:0,duration:3.755,dealer:5,seats:6,shuffle:.55,step:.065,flight:.36,reveal:.18};
  publish({round_id:'opening',deal,animating:true,hand:hand.slice(0,7),counts:Array(6).fill(7)});
  toggleSort('during the opening deal');
  check(reduced?document.querySelectorAll('#hand .is-undealt').length===0:document.querySelectorAll('#hand .is-undealt').length===7,'Opening deal hides cards until landing, respecting reduced motion');
  check($('deck').disabled,'Opening deal locks player input');
  check([...$('deal-cards').querySelectorAll('img')].every(img=>img.src.endsWith('wild-back.svg')),'Opening flights reveal only card backs');
  if(!reduced){
   await pause(1250);check(document.querySelectorAll('#hand .is-undealt').length>0&&document.querySelectorAll('#hand .is-undealt').length<7,'Seven-card hands appear progressively');
   await capture('opening-deal');
   const firstDealCard=$('deal-cards').firstElementChild;publish({},false);check($('deal-cards').firstElementChild===firstDealCard,'Duplicate snapshots preserve the opening animation');
   publish({paused:true,deal:{...deal,elapsed:1.25}});const pausedCount=$('local-player').textContent;await pause(160);check($('local-player').textContent===pausedCount,'Pause freezes the deal');
   qaHandlers.disconnected();qaHandlers.connected(players[0]);publish({paused:false,deal:{...deal,elapsed:2.4}});
   check([...$('deal-cards').children].slice(0,4).every(img=>img.hidden)&&document.querySelectorAll('#hand .is-undealt').length<7,'Reconnect resumes the remaining deal without restarting the shuffle');
   await pause(1450);
  }
  publish({animating:false,deal:{...deal,active:false,elapsed:deal.duration}});
  check(!document.querySelector('#hand .is-undealt')&&!$('deck').disabled&&$('local-player').querySelector('.uno-card-count').textContent==='7','Deal finishes with seven cards and unlocks input');
  publish({round_id:'1',deal:{},hand,counts:[8,6,5,7,6,5],animating:false});
  const beforeTap=qaSent.length;window.qaHandTapReady=true;
  while(!window.qaHandTapDone)await pause(25);
  check(window.qaMouseStart===1&&qaSent.length===beforeTap,'A real mouse click opens the right stack without playing a card');
  check(window.qaTouchStart===0&&qaSent.length===beforeTap,'A real touch tap opens the left stack without playing a card');
  $('hand-right').click();check($('hand').dataset.start==='1','Tapping the stack moves the fan window');
  check(reduced||$('hand').querySelectorAll('[data-card]:not([disabled])').length===0,'Card selection waits for the fan to settle');
  const piled=$('hand').querySelector('.is-piled');check(piled&&piled.getBoundingClientRect().left>=$('hand').getBoundingClientRect().left-1,'Previous cards remain in a visible left stack');
  await pause(300);
  check([...$('hand-cards').querySelectorAll('.is-piled')].every(card=>card.disabled),'Piled cards cannot be played until they are brought into the fan');
  check(!$('hand').querySelector('[data-card="100"]').classList.contains('is-piled'),'Tapping reveals the last card');
  check($('local-player').classList.contains('is-current')&&!document.querySelector('#players .is-current')&&getComputedStyle($('local-player')).outlineStyle==='solid','Only your own identity has the active gold outline on your turn');
  clickCard(30);
  check(qaSent.at(-1).action==='play'&&qaSent.at(-1).card===30&&qaSent.at(-1).revision===qaState.revision,'Inline card selection sends exactly the selected legal card');
  clickCard(100);check($('colors').open,'Wild opens the color dialog');
  check($('color-card').src.endsWith('wild-wild.svg')&&document.querySelectorAll('#color-sectors [role=button]').length===4,'Compact Wild artwork contains four accessible pie regions');
  const colorRect=$('colors').getBoundingClientRect(),visibleHand=$('hand').getBoundingClientRect();
  check(!(colorRect.left<visibleHand.right&&colorRect.right>visibleHand.left&&colorRect.top<visibleHand.bottom&&colorRect.bottom>visibleHand.top),'The color picker and its controls leave your own cards visible');
  await capture('wild-color-picker');window.qaColorReady=true;while(!window.qaColorDone)await pause(25);check(window.qaRealColor==='green'&&qaSent.at(-1).card===100,'A real held tap on the green pie selects green and plays the Wild');
  clickCard(100);document.querySelector('[data-color="blue"]').dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true}));check(qaSent.at(-1).color==='blue','A keyboard activation selects the blue pie');
  clickCard(100);publish({});check(!$('colors').open,'Stale color selection is cancelled');
  publish({hand:hand.slice(0,2),counts:[2,6,5,7,6,5],legal_cards:[9,13]});
  check(!$('hand').classList.contains('is-large-hand')&&$('hand-left').hidden&&$('hand-right').hidden,'Seven or fewer cards need no end-stack controls');
  check(!$('uno').hidden&&!$('uno').disabled&&$('uno').classList.contains('game-turn-glow'),'Two cards enable UNO before selecting a card');
  const beforeSelection=qaSent.length;$('uno').click();
  check(qaSent.length===beforeSelection+1&&qaSent.at(-1).action==='uno'&&!('card' in qaSent.at(-1)),'UNO declares without selecting or playing a card');
  check($('uno').closest('#board')&&$('uno').getBoundingClientRect().top> $('board').getBoundingClientRect().top,'UNO sits beside the private hand');
  publish({uno_armed:true});check(!$('uno').hidden&&$('uno').disabled&&!$('uno').classList.contains('game-turn-glow'),'Acknowledged declarations grey out the UNO button');
  clickCard(9);check(qaSent.at(-1).action==='play'&&qaSent.at(-1).card===9&&!('call_uno' in qaSent.at(-1)),'Selecting the card sends a separate immediate play');
  publish({hand:hand.slice(1,2),counts:[1,6,5,7,6,5],turn:1,legal_cards:[]});check(!$('uno').hidden&&$('uno').disabled,'UNO stays grey when one card remains');
  check(!document.querySelector('.uno-player-box.game-turn-glow'),'No names glow when another player owns the turn');
  publish({hand:hand.slice(0,2),counts:[2,6,5,7,6,5],turn:0,legal_cards:[9,13],uno_armed:false});
  const beforeMiss=qaSent.length;clickCard(13);
  check(qaSent.length===beforeMiss+1&&qaSent.at(-1).action==='play'&&qaSent.at(-1).card===13&&!('call_uno' in qaSent.at(-1)),'Skipping UNO still plays immediately so the host can apply the penalty');
  check(!document.getElementById('play-selected')&&!document.getElementById('catch'),'There is no penultimate confirmation or opponent catch control');
  publish({hand,counts:[8,6,5,7,6,5],catch_target:-1,legal_cards:[30,42,97,100]});
  check($('turn-arrow').hidden&&document.querySelector('#local-player.is-current'),'The active player plaque replaces the traveling pointer');
  for(let viewer=0;viewer<6;viewer++){
   publish({viewer,turn:viewer});await frames();
   check($('local-player').dataset.seat===String(viewer)&&!document.querySelector('#players [data-seat="'+viewer+'"]'),'Every player owns the personal badge with no duplicate');
   check(document.querySelector('#players .uno-player[data-seat="'+((viewer+1)%6)+'"]').style.order==='1','Opponent ordering rotates with the viewer');
  }
  publish({viewer:0,turn:0,catch_target:-1});await pause(1000);
  const eventRevision=qaState.revision+1;
  publish({hand:hand.slice(1),counts:[7,6,5,7,6,5],top:hand[0],color:'red',turn:1,animating:true,motion:{revision:eventRevision,flights:[{kind:'play',seat:0,count:1,card:hand[0]}]}});
  toggleSort('during host card movement');
  await pause(90);
  check(reduced?document.querySelectorAll('.uno-flying-card').length===0:document.querySelectorAll('.uno-flying-card').length===1,'New plays fly from the hand, respecting reduced motion');
  check(reduced||$('discard').src.includes('yellow-draw2'),'Previous discard stays visible until the played card lands');
  const animation=document.querySelector('.uno-flying-card')?.getAnimations()[0];publish({},false);
  check(reduced||document.querySelector('.uno-flying-card')?.getAnimations()[0]===animation,'Duplicate snapshots preserve active movement');
  publish({animating:false,turn:0,legal_cards:[30,42,97,100]});check(reduced||$('deck').disabled,'Local movement stays locked after an early host settle');
  toggleSort('while local movement settles');
  const before=qaSent.length;if(!reduced)$('draw').click();check(qaSent.length===before,'Taps during movement are discarded');
  await pause(500);check(!$('deck').disabled,'Input unlocks after host and local movement both settle');
  const penaltyRevision=qaState.revision+1;
  publish({top:{id:104,color:'wild',kind:'draw4',selected_color:'blue'},color:'blue',turn:2,animating:true,motion:{revision:penaltyRevision,flights:[{kind:'play',seat:0,count:1,card:{id:104,color:'wild',kind:'draw4',selected_color:'blue'}},{kind:'draw',seat:1,count:4,card:{}}]}});
  await pause(550);check(reduced?document.querySelectorAll('.uno-flying-card').length===0:document.querySelectorAll('.uno-flying-card').length===4,'Four penalty cards travel from the deck to the recipient');
  publish({paused:true});check(document.querySelectorAll('.uno-flying-card').length===0&&$('turn-arrow').hidden&&$('deck').disabled,'Pause cancels local flights and hides the moving arrow');
  toggleSort('while gameplay is paused');
  const pausedOrbit=document.querySelector('#orbit-shape > path').getAttribute('d');await pause(120);
  check(document.querySelector('#orbit-shape > path').getAttribute('d')===pausedOrbit&&!$('notice').hidden,'Pause freezes the table arrows and displays exceptional feedback');
  publish({paused:false,animating:false,motion:{},turn:0,hand,legal_cards:[9],drawn:9});
  check(!$('draw-preview').hidden&&$('drawn-card').src.endsWith('red-5.svg')&&$('hand').classList.contains('is-draw-decision'),'Drawn card is shown over a dimmed deck even outside the fan window');
  check(getComputedStyle($('hand-cards')).filter==='brightness(0.6)','The private hand dims behind the new card');
  await capture('draw-preview');
  check($('draw-preview').getBoundingClientRect().top>=$('local-player').getBoundingClientRect().bottom+8&&$('draw-preview').getBoundingClientRect().bottom<=$('hand-actions').getBoundingClientRect().top+2,'Drawn-card choices fit in the private-hand area: '+JSON.stringify({preview:$('draw-preview').getBoundingClientRect().toJSON(),owner:$('local-player').getBoundingClientRect().toJSON(),actions:$('hand-actions').getBoundingClientRect().toJSON(),hand:$('hand').getBoundingClientRect().toJSON()}));
  check(!$('pass').hidden&&!$('pass').disabled,'Playable drawn card may be kept');window.qaDrawClickReady=true;while(!window.qaDrawClickDone)await pause(25);check(window.qaRealPlayCard===9,'A real held touch plays the focused card');check(window.qaRealKeep==='pass','A real held mouse click keeps the focused card');
  publish({hand:hand.slice(0,2),counts:[2,6,5,7,6,5],drawn:9,legal_cards:[9]});
  check(!$('uno').hidden&&!$('play-drawn').hidden,'Drawing to two cards offers UNO before the Play Card decision');
  check(['uno','play-drawn','pass'].every(id=>{const r=$(id).getBoundingClientRect(),b=$('board').getBoundingClientRect();return r.left>=b.left-1&&r.right<=b.right+1&&r.bottom<=$('board').getBoundingClientRect().bottom+2;}),'All drawn-card and UNO decisions fit together within the table');
  await capture('drawn-uno-selection');
  $('uno').click();check(qaSent.at(-1).action==='uno','The drawn penultimate declaration is separate from its play');
  publish({uno_armed:true});$('play-drawn').click();check(qaSent.at(-1).card===9&&!('call_uno' in qaSent.at(-1)),'The focused drawn card plays immediately after its declaration');
  publish({uno_armed:false});
  publish({hand,counts:[8,6,5,7,6,5],drawn:-1,legal_cards:[9]});
  qaHandlers.disconnected();check($('deck').disabled&&$('connection').textContent.includes('Reconnecting'),'Disconnect disables input');
  toggleSort('while reconnecting');
  qaHandlers.connected(players[0]);publish({drawn:-1,animating:false,motion:{revision:qaState.revision+1,flights:[{kind:'draw',seat:0,count:4,card:{}}]}});
  check(document.querySelectorAll('.uno-flying-card').length===0&&$('board').getAttribute('aria-busy')==='false','Reconnect restores settled cards without replaying flights');
  publish({viewer:-1,hand:[]});check($('hand').querySelectorAll('[data-card]').length===8,'Public snapshots do not erase the private hand');qaState.viewer=0;
  for(const count of [4,5,6]){publish({players:players.slice(0,count),counts:[8,6,5,7,6,5].slice(0,count),hand,motion:{},turn:0});check(document.querySelectorAll('.uno-player-box').length===count,'Table adapts to four, five and six seats');}
  publish({hand,players,counts:[8,6,5,7,6,5],top:{id:44,color:'yellow',kind:'draw2'},color:'yellow',motion:{},turn:0,legal_cards:[30,42,97,100],status:"Player 1's turn"});await pause(250);await frames();
  const board=$('board').getBoundingClientRect(),handRect=$('hand').getBoundingClientRect(),boxes=[...document.querySelectorAll('#players .uno-player-box')].map(el=>el.getBoundingClientRect());
  check(document.documentElement.scrollWidth<=innerWidth,'No horizontal overflow');
  check(board.left>=-1&&board.right<=innerWidth+1&&board.bottom<=innerHeight,'Table fits the viewport');
  check(boxes.every(rect=>rect.left>=0&&rect.right<=innerWidth&&(rect.bottom<=handRect.top+2||rect.right<=handRect.left||rect.left>=handRect.right)),'Opponent badges fit around the table without overlapping the private hand: '+JSON.stringify({hand:handRect.toJSON(),boxes:boxes.map(rect=>rect.toJSON())}));
  check($('local-player').getBoundingClientRect().bottom<=handRect.top+2,'Own identity stays above the private hand');
  check([...$('hand-cards').children].every(card=>card.getBoundingClientRect().top>=$('discard').getBoundingClientRect().bottom+12||card.getBoundingClientRect().left>=$('discard').getBoundingClientRect().right+12),'Private cards have a clear gap below both center piles: '+JSON.stringify({board:board.toJSON(),pile:$('discard').getBoundingClientRect().toJSON(),hand:handRect.toJSON(),cards:[...$('hand-cards').children].map(card=>card.getBoundingClientRect().toJSON())}));
  const largeHand=hand.concat(Array.from({length:24},(_,i)=>({id:20+i,color:'red',kind:String(i%10)})).filter(card=>!hand.some(own=>own.id===card.id)));
  publish({hand:largeHand,counts:[largeHand.length,6,5,7,6,5]});window.qaHoldReady=true;while(!window.qaHoldDone)await pause(25);
  check(window.qaMouseHeldStart>0&&window.qaMouseHeldFinal>window.qaMouseHeldStart&&window.qaMouseStopped===window.qaMouseHeldFinal,'A mouse hold scrolls immediately, repeats, and stops on release');
  check(window.qaTouchHeldStart<window.qaMouseStopped&&window.qaTouchHeldFinal<window.qaTouchHeldStart,'A touch hold scrolls before release and continues while held');
  check($('hand').querySelectorAll('[data-card]').length===largeHand.length,'A very large fan retains every private card');
  const gesture=async(type,point,dx=0)=>{window.qaGesture={type,...point,dx};while(window.qaGesture)await pause(25);await pause(300);};
  for(const type of ['mouse','touch']){
   const start=Number($('hand').dataset.start),sent=qaSent.length,rect=$('hand').getBoundingClientRect(),visible=[...$('hand-cards').querySelectorAll('.uno-card:not(.is-piled)')];
   const spacing=parseFloat(visible[1].style.left)-parseFloat(visible[0].style.left),direction=start<largeHand.length-9?-1:1;
   await gesture(type,{x:rect.left+rect.width/2,y:rect.top+rect.height/2},direction*spacing*1.4);
   check(Math.abs(Math.abs(window.qaDragPosition-start)-1.4)<.05,type+' drag follows fractional card spacing continuously '+JSON.stringify({start,position:qaDragPosition,spacing,hand:$('hand').getBoundingClientRect().toJSON(),rect:rect.toJSON(),sent:qaSent.length}));
   check(qaSent.length===sent&&!$('colors').open,type+' drag release never plays or selects a card');
  }
  while(!$('hand-right').hidden){$('hand-right').click();await pause(280);}
  check(!$('hand-cards').lastElementChild.classList.contains('is-piled')&&$('hand-left').textContent.includes(String(largeHand.length-7))&&$('hand-left').getAttribute('aria-label').includes(String(largeHand.length-7)),'Every final card is reachable and the left cue counts all earlier stacked cards');
  const target=$('hand-cards').querySelector('[data-card="30"]'),targetRect=target.getBoundingClientRect(),beforeSimpleTap=qaSent.length;
  await gesture('tap',{x:targetRect.left+Math.min(8,targetRect.width/3),y:targetRect.top+targetRect.height/2});
  check(qaSent.length===beforeSimpleTap+1&&qaSent.at(-1).card===30,'A simple tap after dragging still plays the selected legal card');
  check([...$('hand-cards').children].every(card=>{const r=card.getBoundingClientRect();return r.left>=handRect.left-1&&r.right<=handRect.right+1;}),'Extra cards collect inside the hand bounds instead of being cropped');
  publish({pending_draw:4,legal_cards:[]});check(!$('draw').hidden&&$('draw').disabled&&$('deck').disabled,'Automatic penalties keep Draw visible and disabled');
  publish({pending_draw:4,legal_cards:[97]});check($('draw-total').textContent==='+4'&&$('draw').textContent==='DRAW 4','Draw Four exposes its pending total');
  publish({pending_draw:8});check($('draw-total').textContent==='+8'&&!$('draw-total').hidden&&$('deck').getAttribute('aria-label')==='Draw 8 cards','Two stacked Draw Fours display +8 and offer the full penalty');
  await capture('stack-eight');
  publish({pending_draw:0});check($('draw-total').hidden&&$('draw').textContent==='DRAW','Taking the stack clears the counter');
  publish({counts:[largeHand.length,2,5,7,6,5],feedback:{revision:qaState.revision+1,events:[{kind:'uno',seat:1,color:'red',amount:0}]}});
  const logo=document.querySelector('[data-kind=uno]');check(Boolean(logo?.querySelector('img')),'UNO logo pops over the calling player');
  publish({},false);check(document.querySelector('[data-kind=uno]')===logo,'Duplicate snapshots preserve the same UNO pop');
  publish({counts:[largeHand.length,1,5,7,6,5],uno_players:[false,true,false,false,false,false],feedback:{}});
  await pause(1100);check(document.querySelector('[data-kind=uno]')===logo&&logo.classList.contains('is-uno-hover'),'UNO settles over the last card and persists beyond the initial pop');
  check(getComputedStyle(logo.querySelector('img')).animationName===(reduced?'none':'uno-breathe'),'The last-card logo breathes gently, remaining static with reduced motion');
  await capture('uno-last-card-opponent');
  publish({},false);check(document.querySelector('[data-kind=uno]')===logo,'Duplicate snapshots preserve the hovering marker');
  publish({feedback:{revision:qaState.revision+1,events:[{kind:'skip',seat:2,color:'green',amount:0}]}});
  check(document.querySelector('[data-kind=skip][data-seat="2"]')?.textContent.includes('SKIPPED'),'Skip marks the affected player');
  publish({paused:true});check(!document.querySelector('[data-kind=skip]')&&document.querySelector('[data-kind=uno].is-uno-hover'),'Pause clears temporary feedback while retaining the last-card marker');
  check(reduced||getComputedStyle(document.querySelector('[data-kind=uno] img')).animationPlayState==='paused','Pause freezes the UNO breathing');
  publish({paused:false});
  qaHandlers.disconnected();check(!document.querySelector('[data-kind=uno]'),'Disconnect clears local UNO effects');
  qaHandlers.connected(players[0]);publish({},false);check(document.querySelector('[data-kind=uno].is-uno-hover'),'Reconnect restores the authoritative last-card marker without replaying the pop');
  publish({counts:[largeHand.length,2,5,7,6,5],uno_players:[false,false,false,false,false,false]});check(!document.querySelector('[data-kind=uno]'),'Drawing another card removes the hovering UNO');
  publish({hand:[hand[0]],counts:[1,2,5,7,6,5],uno_players:[true,false,false,false,false,false],drawn:-1,turn:0,legal_cards:[9]});
  await pause(400);await capture('uno-last-card-owner');
  const ownLogo=document.querySelector('[data-kind=uno][data-seat="0"]'),ownCard=$('hand-cards').firstElementChild.getBoundingClientRect();
  check(ownLogo.getBoundingClientRect().bottom<=ownCard.top+1,'The owner UNO hovers above the remaining private card');
  check(ownLogo.getBoundingClientRect().left>=0&&ownLogo.getBoundingClientRect().right<=innerWidth,'UNO fits beside the final card on every viewport');
  publish({hand:largeHand,counts:[largeHand.length,6,5,7,6,5],uno_players:[false,false,false,false,false,false]});
  // Variant controls: only host-validated exact matches can play out of turn.
  publish({turn:1,hand:hand.slice(0,2),counts:[2,6,5,7,6,5],top:{id:10,color:'red',kind:'5'},color:'red',phase:'play',drawn:-1,pending_draw:0,legal_cards:[9],jump_cards:[9],motion:{},animating:false});
  check(!$('hand').querySelector('[data-card="9"]').disabled&&$('hand').querySelector('[data-card="9"]').classList.contains('is-jump-in')&&$('hand').querySelector('[data-card="13"]').disabled,'Only the exact owned jump-in is enabled out of turn');
  check($('hand').querySelector('[data-card="9"]').getAttribute('aria-label').includes('Jump in')&&$('draw').disabled,'Jump-in is accessible while drawing remains restricted to the current turn');
  check(!$('draw').hidden&&$('draw').disabled,'DRAW stays visible and grey on another player’s turn even with a jump-in available');
  const beforeJump=qaSent.length;check(!$('uno').hidden,'A two-card jump-in offers UNO before selecting the matching card');
  $('uno').click();check(qaSent.length===beforeJump+1&&qaSent.at(-1).action==='uno','Jump-in UNO is a separate declaration');
  publish({uno_armed:true});clickCard(9);check(qaSent.at(-1).card===9&&qaSent.at(-1).revision===qaState.revision&&!('call_uno' in qaSent.at(-1)),'Jump-in sends an immediate revision-validated play');
  publish({uno_armed:false});
  publish({legal_cards:[],jump_cards:[]});check([...$('hand-cards').children].every(card=>card.disabled),'Closing the jump-in window disables out-of-turn cards');
  publish({turn:0,phase:'swap',swap_seat:0,swap_targets:[1,2,3,4,5],legal_cards:[],status:'Player 1 · choose a player to swap hands with'});
  const targets=()=>[...document.querySelectorAll('.is-swap-target')];
  check(!$('swaps')&&!$('swap')&&targets().length===5&&$('deck').disabled,'Seven uses opponent name boxes and blocks ordinary actions');
  check(targets().every(button=>button.classList.contains('game-turn-glow')&&getComputedStyle(button).boxShadow!=='none'&&button.getAttribute('aria-label').includes('Swap hands with')&&!button.disabled),'Every eligible name has shared turn glow and accessible activation');
  check(targets().every(button=>{const r=button.getBoundingClientRect();return r.left>=0&&r.right<=innerWidth&&r.top>=0&&r.bottom<=innerHeight;}),'All name targets fit the viewport');await capture('seven-swap');
  publish({paused:true});check(targets().length===0,'Pause removes all swap highlights');publish({paused:false});
  qaHandlers.disconnected();check(targets().length===0,'Disconnect disables name targets');qaHandlers.connected(players[0]);publish({},false);check(targets().length===5,'Reconnect restores the pending name choices');
  const nameTarget=document.querySelector('.uno-player[data-seat="2"] .uno-player-box');nameTarget.focus();publish({},false);
  check(document.activeElement===nameTarget,'Duplicate snapshots preserve the focused name target');
  window.qaSwapReady=true;while(!window.qaSwapDone)await pause(25);
  check(qaSent.at(-1).action==='swap'&&qaSent.at(-1).target===2&&qaSent.at(-1).revision===qaState.revision,'A held touch on the player name sends its seat and current revision');
  const outgoingWidth=$('hand-cards').querySelector('img').getBoundingClientRect().width;
  publish({phase:'play',swap_seat:-1,swap_targets:[],turn:1,hand:hand.slice(2,5),counts:[3,6,2,7,6,5],status:"Player 2's turn",motion:{revision:qaState.revision+1,flights:[{kind:'hand',seat:0,target:2,count:1,hand_count:2,card:{}},{kind:'hand',seat:2,target:0,count:1,hand_count:3,card:{}}]},animating:true});
  check(targets().length===0&&[...document.querySelectorAll('.uno-flying-hand img')].every(img=>img.src.endsWith('wild-back.svg')),'Transfers remove choices and reveal only card backs');
  if(!reduced){
    const fans=[...document.querySelectorAll('.uno-flying-hand')];
    check(fans.length===2&&fans.map(fan=>fan.children.length).join(',')==='2,3','Each exchanged hand flies as one fan with its own card count');
    check(Math.abs(parseFloat(fans[0].querySelector('img').style.width)-outgoingWidth)<1,'Outgoing fans retain the current private card size');
    check(fans[0].getAnimations()[0].effect.getTiming().delay===fans[1].getAnimations()[0].effect.getTiming().delay,'Both sides of a Seven exchange move simultaneously');
    check($('hand-cards').classList.contains('is-transferring'),'Received cards wait for the hand flight to land');
    const fan=fans[0];publish({},false);check(document.querySelector('.uno-flying-hand')===fan,'Duplicate snapshots preserve whole-hand movement');
    await pause(160);await capture('seven-transfer');
  }
  await pause(1000);publish({animating:false,motion:{},hand,counts:[8,6,5,7,6,5],turn:0,legal_cards:[9],jump_cards:[]});
  check($('hand-cards').children.length===8,'Transferred private hand replaces the old hand without losing fan navigation');
  check([...$('hand-cards').children].map(button=>Number(button.dataset.card)).join(',')==='9,13,30,42,59,79,97,100','Hands group colors and ascending numbers, with Wilds last');
  const zeroFlights=players.map((_,seat)=>({kind:'hand',seat,target:(seat+1)%6,count:1,hand_count:[7,8,5,7,6,5][seat],card:{},start:.48,duration:.72}));
  publish({top:{id:0,color:'red',kind:'0'},color:'red',animating:true,motion:{revision:qaState.revision+1,flights:[{kind:'play',seat:0,count:1,card:{id:0,color:'red',kind:'0'}},...zeroFlights]}});
  if(!reduced){
    const fans=[...document.querySelectorAll('.uno-flying-hand')];
    check(fans.length===6&&fans.every(fan=>fan.children.length>1),'Zero moves all complete hands, including stacked cards');
    check(fans.find(fan=>fan.dataset.seat==='1').children.length===8,'An eight-card hand moves as eight cards without duplicated end stacks');
    check(new Set(fans.map(fan=>fan.getAnimations()[0].effect.getTiming().delay)).size===1,'Every Zero rotation begins at the same instant after the played card lands');
    await pause(600);await capture('zero-rotation');
    const before=qaSent.length;$('deck').click();check(qaSent.length===before,'Inputs during whole-hand movement are discarded');
    await pause(700);
    check(!document.querySelector('.uno-flying-hand')&&!$('hand-cards').classList.contains('is-transferring'),'All fans settle together without duplicate stationary hands');
  }else check(!document.querySelector('.uno-flying-hand'),'Reduced motion restores transferred hands instantly');
  publish({animating:false,motion:{}});
  publish({turn:0,hand:hand.slice(0,2),counts:[2,6,5,7,6,5],drawn:9,legal_cards:[9],options:{force_play:true},forced_play:true,auto_draw:false});
  check($('pass').hidden&&!$('draw-preview').hidden,'Force Play hides Keep while preserving the focused drawn card');
  check(!$('uno').hidden,'A forced penultimate draw offers UNO without needing to select the card');$('uno').click();check(qaSent.at(-1).action==='uno','Forced draw UNO declares without delaying for a manual card selection');
  publish({drawn:-1,legal_cards:[],auto_draw:true,forced_play:false});check(!$('draw').hidden&&$('draw').disabled&&$('deck').disabled,'Required automatic draws grey out the manual Draw button');
  publish({hand:[{id:104,color:'wild',kind:'draw4'},hand[0]],drawn:104,phase:'drawn_color',auto_draw:false,animating:true});check(!$('colors').open,'A forced drawn Wild waits for its flight to land');
  publish({animating:false});check($('colors').open&&$('color-card').src.endsWith('wild-draw4.svg')&&!$('color-uno').hidden&&$('cancel-color').hidden,'A forced Wild Draw Four opens its own pie with a manual UNO option');
  $('color-uno').click();check(qaSent.at(-1).action==='uno','UNO can be declared before choosing the forced Wild color');
  publish({uno_armed:true});check($('colors').open&&$('color-uno').hidden,'A declaration refreshes the pending color selection without losing it');
  qaHandlers.disconnected();check(!$('colors').open,'Disconnect closes the forced color picker');qaHandlers.connected(players[0]);publish({},false);check($('colors').open,'Reconnect restores the forced Wild color choice');
  document.querySelector('[data-color="red"]').dispatchEvent(new MouseEvent('click',{bubbles:true}));check(qaSent.at(-1).action==='color'&&qaSent.at(-1).color==='red'&&qaSent.at(-1).revision===qaState.revision,'Forced Wild selection sends the current authoritative color action');
  publish({phase:'play',drawn:-1,hand,counts:[8,6,5,7,6,5],options:{force_play:false},uno_armed:false,legal_cards:[9],auto_draw:false});
  for(const color of ['red','yellow','green','blue'])for(const kind of ['wild','draw4']){
   publish({top:{id:100,color:'wild',kind,selected_color:color},color,motion:{}});await frames();
   check(!$('color-indicator')&&!$('color-dot'),'The main deck has no separate color indicator for '+color);
   check($('discard').src.endsWith(color+'-'+kind+'-chosen.svg'),'Chosen '+color+' '+kind+' appears directly on the discard');
  }
  await pause(100);check([...document.images].every(img=>img.complete&&img.naturalWidth>0),'Chosen Wild artwork loads offline');
  publish({hand,counts:[8,6,5,7,6,5],reduced_motion:true});check($('turn-arrow').hidden,'The obsolete pointer stays hidden with reduced motion');
  check(getComputedStyle(document.querySelector('.uno-orbit-arrows')).animationName==='none','Host reduced motion keeps direction arrows static');
  check(getComputedStyle($('local-player')).animationName==='none','Reduced motion keeps the personal turn glow static');
  publish({reduced_motion:false});
  publish({phase:'finished',winner:0,session_wins:[1,0,0,0,0,0],status:'Player 1 WINS!'});await frames();
  check($('local-player').classList.contains('is-winner')&&document.querySelectorAll('.is-winner').length===1&&getComputedStyle($('local-player'),'::before').backgroundImage.includes('table-crown.svg')&&getComputedStyle($('local-player'),'::before').zIndex==='1','Only the winner gets a crown above the avatar');
  await capture('winner');
  check(!$('replay').hidden&&$('replay').getBoundingClientRect().bottom<=innerHeight,'One reachable Play Again remains');
  check(Math.abs($('board').getBoundingClientRect().top-board.top)<1,'Winning does not shift the board');$('replay').click();check(qaSent.at(-1).action==='play_again','Replay follows the shared host route');
  publish({phase:'play',winner:-1,round_id:'2',status:"Player 1's turn"});await frames();
  check(!document.querySelector('.is-winner'),'Replay clears the winner crown');
  const lightHand=[{id:20,color:'red',kind:'flip',side:'light'},{id:21,color:'red',kind:'draw1',side:'light'},{id:111,color:'wild',kind:'draw2',side:'light'},{id:22,color:'blue',kind:'1',side:'light'}];
  const darkHand=[{id:20,color:'pink',kind:'flip',side:'dark'},{id:21,color:'teal',kind:'draw5',side:'dark'},{id:111,color:'wild',kind:'draw_color',side:'dark'},{id:22,color:'purple',kind:'skip_all',side:'dark'}];
  const darkBacks=players.map(()=>darkHand.slice(0,3).map(({color,kind,side})=>({color,kind,side}))),lightBacks=players.map(()=>lightHand.slice(0,3).map(({color,kind,side})=>({color,kind,side})));
  publish({gamemode:'flip',side:'light',colors:['red','yellow','green','blue'],hand:lightHand,backs:darkBacks,deck_back:darkBacks[0][1],counts:Array(6).fill(3),players,viewer:0,turn:0,phase:'play',winner:-1,drawn:-1,legal_cards:lightHand.map(card=>card.id),round_id:'flip-light',motion:{},pending_draw:0,pending_color:'',options:{},animating:false});await pause(100);await frames();
  check(!$('gamemode-side')&&$('board').getAttribute('aria-label')==='UNO Flip table, light side','Flip side stays accessible without a visible text indicator');
  check($('deck').querySelector('img').src.endsWith('flip-dark-teal-draw5.svg')&&document.querySelector('.uno-backs img').src.endsWith('flip-dark-pink-flip.svg'),'Light-side draw pile and opposing public inactive faces are visible');
  clickCard(111);check($('colors').open&&$('color-card').src.endsWith('wild-draw2.svg'),'Light Wild Draw Two has its own picker art');
  document.querySelector('[data-color="green"]').dispatchEvent(new MouseEvent('click',{bubbles:true}));check(qaSent.at(-1).card===111&&qaSent.at(-1).color==='green','Flip IDs above 107 pass through the normal controller action');
  await capture('flip-light');
  const flipRevision=qaState.revision+1;
  publish({side:'dark',colors:['pink','teal','orange','purple'],hand:darkHand,backs:lightBacks,deck_back:lightBacks[0][1],top:{id:55,color:'purple',kind:'4',side:'dark'},color:'purple',legal_cards:darkHand.map(card=>card.id),animating:true,motion:{revision:flipRevision,flights:[{kind:'play',seat:0,count:1,card:lightHand[0]},{kind:'flip',seat:0,count:1,card:{}}]}});
  const flipInput=qaSent.length;await pause(550);
  check(reduced||$('hand-cards').querySelector('[data-card="21"] img').src.endsWith('red-draw1.svg'),'Held cards retain their previous face until the Flip midpoint');
  publish({animating:false},false);$('draw').click();
  check(reduced||qaSent.length===flipInput,'A local Flip remains locked after an early host settle');
  await pause(500);check(!$('deck').disabled,'Flip input unlocks only after both movements settle');
  check($('board').getAttribute('aria-label')==='UNO Flip table, dark side'&&$('discard').src.endsWith('flip-dark-purple-4.svg'),'Flip restores the authoritative exposed discard and dark side');
  check([...document.querySelectorAll('.uno-backs img')].every(img=>!img.src.includes('flip-dark-')),'Dark-side phones show only the public light backs of opposing hands');
  await capture('flip-dark');clickCard(111);
  check($('colors').open&&$('color-card').src.endsWith('flip-dark-wild-draw_color.svg'),'Dark Wild Draw Color uses the dark artwork');
  check([...document.querySelectorAll('#color-sectors [data-color]')].map(sector=>sector.dataset.color).join(',')==='pink,purple,orange,teal','Dark Wild choices use all four dark colors');
  await capture('flip-dark-picker');document.querySelector('[data-color="purple"]').dispatchEvent(new MouseEvent('click',{bubbles:true}));
  check(qaSent.at(-1).card===111&&qaSent.at(-1).color==='purple','Dark color selection remains an ordinary revision-validated play');
  publish({phase:'flip_color',top:{id:55,color:'wild',kind:'wild',side:'dark'},legal_cards:[],motion:{}});if($('colors').open)$('cancel-color').click();$('discard').click();document.querySelector('[data-color="teal"]').dispatchEvent(new MouseEvent('click',{bubbles:true}));
  check(qaSent.at(-1).action==='color'&&qaSent.at(-1).color==='teal','A Wild exposed by a Flip restores a color choice');
  publish({phase:'play',legal_cards:darkHand.map(card=>card.id),top:{id:55,color:'purple',kind:'4',side:'dark'}});
  qaHandlers.disconnected();qaHandlers.connected(players[0]);publish({motion:{revision:qaState.revision+1,flights:[{kind:'flip',seat:0,count:1,card:{}}]}});
  check($('board').getAttribute('aria-label')==='UNO Flip table, dark side'&&$('hand-cards').children.length===4&&!$('deck').disabled,'Refresh restores the dark private hand without replaying Flip motion');
  for(const color of ['pink','teal','orange','purple'])for(const kind of ['wild','draw_color']){publish({top:{id:111,color:'wild',kind,side:'dark',selected_color:color},color,motion:{}});await frames();check($('discard').src.endsWith('flip-dark-'+color+'-'+kind+'-chosen.svg'),'Chosen dark Wild art: '+color+' '+kind);}
  await pause(100);check([...document.images].every(img=>img.complete&&img.naturalWidth>0),'Both Flip sides and Wild choices load fully offline');
  check(!document.querySelector('#challenge,#accept,#proof,[title]'),'Flip adds no challenge controls or hover popups');
  publish({gamemode:'classic',side:'light',colors:['red','yellow','green','blue'],backs:[],deck_back:{color:'wild',kind:'back'},hand,top:{id:44,color:'yellow',kind:'draw2'},color:'yellow',motion:{}});
  check(!$('gamemode-side')&&$('deck').querySelector('img').src.endsWith('wild-back.svg'),'Returning to Classic restores its original presentation');
  const mercyHand=[{id:40,color:'red',kind:'draw4'},{id:41,color:'red',kind:'discard_all'},{id:42,color:'blue',kind:'skip_all'},{id:144,color:'wild',kind:'reverse_draw4'},{id:160,color:'wild',kind:'draw6'},{id:164,color:'wild',kind:'draw10'},{id:152,color:'wild',kind:'color_roulette'}];
  publish({gamemode:'no_mercy',round_id:'mercy',hand:mercyHand,counts:[7,0,24,7,6,5],players,eliminated:[false,true,false,false,false,false],viewer:0,turn:0,phase:'play',drawn:-1,legal_cards:mercyHand.map(card=>card.id),jump_cards:[],top:{id:40,color:'red',kind:'draw4'},color:'red',motion:{},feedback:{},animating:false,can_uno:false,options:{allow_stacking:true,allow_seven_zero:true,allow_mercy:true,draw_until_play:true,allow_jump_ins:false,force_play:false}});
  await pause(150);await frames();
  check($('board').getAttribute('aria-label')==='UNO No Mercy table'&&document.querySelector('[data-seat="1"] .uno-player-count').textContent==='OUT'&&!document.querySelector('[data-seat="1"] .uno-backs img'),'Eliminated opponents keep a visible seat without held cards');
  check([...$('hand-cards').querySelectorAll('img')].every(img=>img.complete&&img.naturalWidth>0)&&$('discard').alt==='red Draw Four','All No Mercy actions load locally and have accessible names');
  check($('deck').querySelector('img').src.endsWith('no-mercy-wild-back.svg')&&[...$('hand-cards').querySelectorAll('img')].every(img=>img.src.includes('/no-mercy-')),'No Mercy has dedicated faces and backs throughout the table');
  await capture('no-mercy');
  clickCard(152);
  check(qaSent.at(-1).action==='play'&&qaSent.at(-1).card===152&&!$('colors').open,'Color Roulette plays directly without asking its sender for a color');
  publish({phase:'roulette_color',turn:0,hand:mercyHand.slice(0,6),counts:[6,0,24,7,6,5],legal_cards:[],top:{id:152,color:'wild',kind:'color_roulette'},status:'Player 1 · choose a color for Color Roulette'});
  check($('colors').open&&$('cancel-color').hidden&&$('color-uno').hidden&&$('deck').disabled,'The roulette recipient receives a required color choice');
  await capture('no-mercy-roulette');
  qaHandlers.disconnected();qaHandlers.connected(players[0]);publish({},false);
  check($('colors').open,'Reconnect restores the recipient roulette choice');
  document.querySelector('[data-color="green"]').dispatchEvent(new MouseEvent('click',{bubbles:true}));
  check(qaSent.at(-1).action==='color'&&qaSent.at(-1).color==='green','Roulette choice sends only the chosen color and revision');
  publish({phase:'play',turn:2,hand:[],counts:[0,0,24,7,6,5],eliminated:[true,true,false,false,false,false],legal_cards:[],top:{id:152,color:'wild',kind:'color_roulette',selected_color:'green'},color:'green',status:"Player 3's turn"});
  check($('local-player').querySelector('.uno-player-count').textContent==='OUT'&&!$('notice').hidden&&$('notice').textContent.includes('watching')&&$('deck').disabled&&!$('draw').hidden&&$('draw').disabled&&!$('uno').hidden&&$('uno').disabled,'Eliminated owner remains a spectator with disabled Draw and UNO controls');
  await capture('no-mercy-out');
  publish({phase:'finished',winner:2,animating:false,status:'Player 3 WINS!'});check($('notice').textContent==='Player 3 WINS!'&&!$('replay').hidden,'Eliminated spectators receive the final winner and replay control');
  publish({phase:'play',winner:-1});
  for(const color of ['red','yellow','green','blue'])for(const kind of ['reverse_draw4','draw6','draw10','color_roulette']){
    publish({top:{id:164,color:'wild',kind,selected_color:color},color,motion:{}});await pause(20);await frames();
    check($('discard').src.endsWith(color+'-'+kind+'-chosen.svg')&&$('discard').complete&&$('discard').naturalWidth>0,'Chosen No Mercy Wild face: '+color+' '+kind);
  }
  publish({phase:'play',turn:0,hand:[{id:41,color:'red',kind:'discard_all'},{id:1,color:'red',kind:'8'},{id:2,color:'red',kind:'9'},{id:3,color:'blue',kind:'8'}],counts:[4,6,7,8,6,5],eliminated:Array(6).fill(false),can_uno:true,legal_cards:[41],top:{id:40,color:'red',kind:'draw4'},color:'red',uno_armed:false});
  check(!$('uno').hidden,'UNO is reachable before Discard All reduces a larger hand to one card');
  publish({gamemode:'classic',round_id:'back-classic',hand,can_uno:false,eliminated:Array(6).fill(false),phase:'play',turn:0,legal_cards:[9],counts:[8,6,5,7,6,5],options:{}});
  check(!document.querySelector('[title]'),'No Mercy adds no hover popups');
  const addonsHand=[{id:108,color:'red',kind:'reverse_draw2',addon:'reverse'},{id:109,color:'red',kind:'stack1',addon:'stack'},{id:110,color:'blue',kind:'swap1',addon:'swap'},{id:111,color:'yellow',kind:'1',addon:'speed',speed:1},{id:112,color:'red',kind:'reveal_hands',addon:'billie_eilish'},{id:113,color:'wild',kind:'nemesis',addon:'frenemies'},{id:114,color:'wild',kind:'block',addon:'defense'}];
  publish({gamemode:'classic',round_id:'addons',phase:'play',turn:0,winner:-1,hand:addonsHand,counts:[7,5,6,8,6,5],legal_cards:addonsHand.map(card=>card.id),drawn:-1,can_uno:false,uno_armed:false,options:{},pending_draw:0,pending_color:'',top:addonsHand[0],motion:{},feedback:{},speed:1,speed_remaining:1,addon_choice:{},enabled_addons:{reverse:true,stack:true,swap:true,speed:true,billie_eilish:true,frenemies:true,defense:true,comeback:true,love_island:true}});
  await pause(200);await frames();
  check([...$('hand-cards').querySelectorAll('img')].every(img=>img.complete&&img.naturalWidth>0),'Add-on faces load offline in the normal private fan');
  check($('hand-cards').querySelector('[data-card="111"] img').src.endsWith('addon-speed-yellow-1.svg'),'Speed number cards keep distinct artwork');
  publish({active_addons:['Reverse','Stack','Swap','Speed','Billie Eilish','Frenemies','Defense','Comeback','Love Island']});await pause(150);await frames();
  const addonIcons=[...$('rules-list').querySelectorAll('.game-rule-item img')].slice(1);
  check(addonIcons.length===9&&new Set(addonIcons.map(icon=>icon.src)).size===9&&addonIcons.every(icon=>icon.complete&&icon.naturalWidth>0&&!icon.src.endsWith('/addon.svg')),'All nine add-ons have different offline icons');
  check([...$('rules-list').querySelectorAll('.game-rule-section')].map(heading=>heading.textContent).join('|')==='Game Mode|Add-Ons','Empty House Rules sections are omitted');
  $('active-rules').querySelector('summary').click();$('rules-list').scrollTop=0;await frames();await capture('addons-rules');
  $('rules-list').scrollTop=$('rules-list').scrollHeight;await frames();
  const lastRule=$('rules-list').lastElementChild.getBoundingClientRect();
  check(lastRule.bottom<=$('rules-list').getBoundingClientRect().bottom+1&&$('close-rules').getBoundingClientRect().bottom<=innerHeight,'Every add-on and the rules Close action remain reachable');
  await capture('addons-rules-scrolled');$('close-rules').click();await frames();
  await capture('addons-hand');clickCard(114);
  check($('colors').open&&$('color-card').alt.includes('Block'),'Add-on Wilds use the existing accessible color picker');
  document.querySelector('[data-color="green"]').dispatchEvent(new MouseEvent('click',{bubbles:true}));check(qaSent.at(-1).card===114&&qaSent.at(-1).color==='green','Add-on card IDs and chosen colors use the normal play action');
  publish({phase:'addon_response',legal_cards:[109,114],pending_draw:2,addon_draw:true,addon_accept:''});await frames();
  check([109,114].every(id=>!$('hand-cards').querySelector('[data-card="'+id+'"]').disabled)&&!$('draw').disabled&&!$('deck').disabled&&$('draw-label').textContent==='DRAW 2','Stacking, defense cards and the regular Draw action are available for the penalty');
  check(!$('addon-controls')&&![...document.querySelectorAll('button')].some(button=>button.textContent==='DRAW PENALTY'),'The penalty has no duplicate action below the toolbar');
  $('draw').click();check(qaSent.at(-1).action==='draw','The regular Draw button accepts the full host-authoritative add-on penalty');
  await capture('addons-defense');
  publish({paused:true});check($('draw').disabled&&$('deck').disabled,'A paused penalty disables both Draw targets');
  publish({paused:false,turn:1});check($('draw').disabled&&$('deck').disabled,'Other players cannot accept the penalty');
  publish({turn:0,addon_draw:false,addon_accept:'ACCEPT SKIP',pending_draw:0,legal_cards:[114]});await frames();
  check($('draw').disabled&&document.querySelector('[data-context-action="accept"]')?.textContent==='ACCEPT SKIP'&&!document.querySelector('.game-player-focus').hidden,'Skip-only defense keeps its explicit action in the right-side prompt');
  document.querySelector('[data-context-action="accept"]').click();check(qaSent.at(-1).action==='draw','Accept Skip uses the current host-authorized action');
  for(const kind of ['swap1','swap_hands','nemesis','match_max','coupled','chat','eggs','petty','redirect','trade_first','trade_second']){
    const offeredTargets=kind==='trade_first'?[0,1,2,3]:kind==='trade_second'?[0,2,3]:[1,2,3];
    publish({phase:'addon_choice',status:'Player 1 is choosing an add-on action.',legal_cards:[],pending_draw:0,addon_accept:'',addon_choice:{kind,prompt:'Choose a player for '+kind+'.',owner:0,targets:offeredTargets,cards:[]}});
    check(document.querySelectorAll('.is-player-target').length===offeredTargets.length&&!$('addon-controls')&&!document.querySelector('.game-player-focus').hidden,'Every add-on chooses players through eligible badges: '+kind);
    if(kind==='trade_first'){check($('local-player').getBoundingClientRect().height>=44,'An eligible own badge retains a 44-pixel touch target');$('local-player').dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true}));check(qaSent.at(-1).action==='addon_choose'&&qaSent.at(-1).target===0,'The chooser can use their own badge by keyboard when the card permits it');}
  }
  qaHandlers.disconnected();check(document.querySelector('.game-player-focus').hidden,'Disconnect removes the private targeting overlay');qaHandlers.connected(players[0]);publish({},false);await frames();
  check(!document.querySelector('.game-player-focus').hidden&&document.querySelectorAll('.is-player-target').length===3,'Reconnection restores the pending choice and its current eligible targets');
  publish({paused:true});check(document.querySelector('.game-player-focus').hidden,'Pause removes the scrim and choice inputs');publish({paused:false});
  publish({phase:'addon_choice',status:'Player 1 is choosing an add-on action.',legal_cards:[],pending_draw:0,addon_accept:'',addon_choice:{kind:'instigator',prompt:'Choose players and 1–4 cards each, then confirm.',owner:0,targets:[1,2,3],amounts:{1:2},cards:[]}});
  await frames();
  const choiceButton=document.querySelector('#players .uno-player[data-seat="1"] .uno-player-box');choiceButton.click();check(qaSent.at(-1).action==='addon_choose'&&qaSent.at(-1).target===1&&qaSent.at(-1).amount===3,'Instigator chooses a player and staged amount directly on their badge');
  publish({},false);check(document.querySelector('#players .uno-player[data-seat="1"] .uno-player-box')===choiceButton,'Duplicate snapshots preserve player badge click targets');
  const focus=document.querySelector('.game-player-focus'),prompt=focus.querySelector('.game-player-focus-prompt');
  check(!$('addon-controls')&&!focus.hidden&&prompt.textContent.includes('Tap players')&&$('notice').hidden,'The decision prompt floats away from the bottom controls');
  const promptRect=prompt.getBoundingClientRect(),overlap=(a,b)=>a.left<b.right&&a.right>b.left&&a.top<b.bottom&&a.bottom>b.top;
  check(promptRect.left+promptRect.width/2>innerWidth/2&&promptRect.top>=0&&promptRect.bottom<=innerHeight,'The prompt stays on the right inside the viewport');
  check(!overlap(promptRect,$('hand-actions').getBoundingClientRect())&&!overlap(promptRect,$('active-rules').getBoundingClientRect()),'The floating prompt leaves Draw, UNO, Sort and Rules uncovered');
  check([...document.querySelectorAll('.is-player-target')].every(badge=>!overlap(promptRect,badge.getBoundingClientRect())&&badge.classList.contains('game-turn-glow')),'Every eligible player remains clear of the prompt and has a breathing halo');
  check([...document.querySelectorAll('.is-player-target')].every(badge=>(getComputedStyle(badge).animationName==='none')===Boolean(reduced||qaState.reduced_motion)),'Target halos breathe normally and stay static with reduced motion');
  check([...document.querySelectorAll('.is-player-target')].every(badge=>{const rect=badge.getBoundingClientRect();return document.elementFromPoint(rect.left+rect.width/2,rect.top+rect.height/2)?.closest('.uno-player-box')===badge;}),'The dimming overlay leaves player badges clickable');
  check(focus.querySelectorAll('.game-player-focus-counter').length===3&&focus.querySelector('svg path').getAttribute('d').length>30,'The light scrim and amount captions follow the selected player badges');
  focus.querySelector('button').click();check(qaSent.at(-1).action==='addon_choose'&&qaSent.at(-1).value==='done','Confirm stays with the right-side prompt');
  await capture('addons-instigator');
  check($('actions').getBoundingClientRect().top>=$('board').getBoundingClientRect().bottom-8,'Add-on decisions use the shared reserved footer without covering the table');
  const peekCards=[{id:180,color:'wild',kind:'swap_hands',addon:'comeback',letter:'U'},{id:181,color:'wild',kind:'chat',addon:'love_island'},{id:182,color:'yellow',kind:'text',addon:'love_island'}];
  publish({addon_choice:{kind:'chat_take',prompt:'View this hand. Choose a card to exchange, or skip.',owner:0,target:1,cards:peekCards}});await pause(100);
  check($('addon-view').open&&$('addon-view').querySelectorAll('[data-addon-card]').length===3&&[...$('addon-view').querySelectorAll('img')].every(img=>img.complete&&img.naturalWidth>0),'Private Chat cards display only in the authoritative private viewer');
  check([...$('addon-view-actions').children].every(button=>{const rect=button.getBoundingClientRect();return rect.top>=0&&rect.bottom<=innerHeight&&rect.height>=44;}),'Private viewer actions stay visible with 44-pixel targets in every viewport');
  const chatRevision=qaState.revision;$('close-addon-view').click();await frames();
  check(!$('addon-view').open&&qaState.revision===chatRevision&&!document.querySelector('.game-player-focus').hidden,'Closing a private choice does not accept it or introduce a bottom control');
  document.querySelector('.uno-player[data-seat="1"] .uno-player-box').click();check($('addon-view').open,'The highlighted target badge reopens the pending Chat cards');
  $('addon-view').querySelector('[data-addon-card="181"]').click();check(qaSent.at(-1).card===181&&qaSent.at(-1).action==='addon_choose','Chat selects an explicitly offered card');
  await capture('addons-chat');
  qaHandlers.disconnected();qaHandlers.connected(players[0]);publish({},false);check($('addon-view').open&&$('addon-view').querySelectorAll('[data-addon-card]').length===3,'Refresh restores the private add-on choice');
  for(const kind of ['give','double','combo_keep']){
    publish({phase:'addon_choice',addon_choice:{kind,prompt:'Choose a card.',owner:0,cards:[addonsHand[0],addonsHand[2]]},legal_cards:[]});await frames();
    check(!$('addon-view').open&&[...$('hand-cards').querySelectorAll('button:not(:disabled)')].map(button=>Number(button.dataset.card)).sort().join()==='108,110','Own-card choices use the existing hand and only offered cards: '+kind);
    clickCard(108);check(qaSent.at(-1).action==='addon_choose'&&qaSent.at(-1).card===108,'Tapping an own-card choice sends a validated add-on selection: '+kind);
  }
  publish({addon_choice:{kind:'text',prompt:'Choose a rule.',owner:0,cards:[]}});await frames();
  check($('addon-view').open&&$('addon-view-body').querySelectorAll('button').length===3,'Text rule choices use a temporary dialog');
  $('close-addon-view').click();$('discard').dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true}));check($('addon-view').open,'The discard card reopens a dismissed Text choice by keyboard');
  [...$('addon-view-body').querySelectorAll('button')].find(button=>button.textContent==='OTHERS DRAW 1').click();check(qaSent.at(-1).value==='draw'&&qaSent.at(-1).action==='addon_choose','Text submits only an explicit offered rule');
  publish({addon_choice:{kind:'combo_color',prompt:'Choose a color.',owner:0,cards:[]}});await frames();
  check($('colors').open&&!$('addon-view').open,'Combo colors reuse the existing Wild picker');
  document.querySelector('[data-color="blue"]').dispatchEvent(new MouseEvent('click',{bubbles:true}));check(qaSent.at(-1).action==='addon_choose'&&qaSent.at(-1).value==='blue','Combo colors retain the add-on command and current revision');
  publish({phase:'play',addon_choice:{},revealed_cards:{1:peekCards},legal_cards:[108]});await frames();
  check($('addon-view').open&&$('addon-view-heading').textContent==='COLOR CHALLENGE'&&$('addon-view-body').querySelectorAll('.game-card-tile').length===3&&!document.querySelector('.uno-backs img[src*="addon-"]'),'Color Challenge proof stays inside the private viewer, away from public seat fans');
  $('close-addon-view').click();document.querySelector('.uno-player[data-seat="1"] .uno-player-box').click();check($('addon-view').open,'A highlighted player badge reopens private Color Challenge results');
  publish({revealed_cards:{}});await frames();check(!$('addon-view').open,'Removing the authoritative proof closes and clears the private viewer');
  const publicHands=[addonsHand,peekCards,hand.slice(0,6),hand,hand.slice(0,6),hand.slice(0,5)];
  publish({phase:'play',addon_choice:{},legal_cards:[108],counts:publicHands.map(cards=>cards.length),revealed_hands:[]});await pause(100);await frames();
  const beforeReveal=[$('board'),$('hand-actions')].map(element=>element.getBoundingClientRect());
  publish({revealed_hands:publicHands});await pause(100);await frames();
  const seatFaces=[...document.querySelectorAll('.uno-player[data-seat="1"] .uno-backs img')];
  check(seatFaces.length===peekCards.length&&seatFaces.every(img=>img.src.includes('addon-')&&img.complete&&img.naturalWidth>0),'Reveal Hands shows authorized faces in the existing opponent fan');
  check(!$('addon-controls')&&!document.querySelector('.uno-addon-reveal'),'Reveal Hands adds no bottom panel or disclosure');
  check([$('board'),$('hand-actions')].every((element,index)=>{const rect=element.getBoundingClientRect(),before=beforeReveal[index];return ['top','left','width','height'].every(key=>Math.abs(rect[key]-before[key])<1);}), 'Revealing cards preserves the table and action row geometry: '+JSON.stringify({before:beforeReveal,after:[$('board'),$('hand-actions')].map(element=>element.getBoundingClientRect())}));
  await capture('addons-reveal');
  qaHandlers.disconnected();qaHandlers.connected(players[0]);publish({},false);await frames();
  check(!$('addon-controls')&&[...document.querySelectorAll('.uno-player[data-seat="1"] .uno-backs img')].every(img=>img.src.includes('addon-')),'Reconnect restores face-up seat cards without adding a footer');
  publish({revealed_hands:[]});await frames();
  check([...document.querySelectorAll('.uno-player[data-seat="1"] .uno-backs img')].every(img=>img.src.endsWith('wild-back.svg'))&&!$('addon-controls'),'Expired reveals return to card backs without a footer');
  publish({revealed_hands:[],speed:3,speed_remaining:2,can_combo:true,can_end_enemy:true,enemies:{0:1},couple:[0,2],basket:[0,3]});
  check(!$('draw').hidden&&$('draw').disabled&&$('deck').disabled&&$('notice').textContent.includes('Speed 3'),'Speed exposes the required remaining plays and leaves crashes to the host');
  document.querySelector('[data-context-action="combo"]').click();check(qaSent.at(-1).action==='addon_combo','The U-N-O combination has an explicit right-side action');
  document.querySelector('[data-context-action="end_enemy"]').click();check(qaSent.at(-1).action==='addon_end_enemy','The owner can explicitly end their Nemesis from the right');
  check($('rules-list').textContent.includes('Active Effects')&&['Coupled','Basket','Nemesis'].every(text=>$('rules-list').textContent.includes(text))&&document.querySelectorAll('.uno-seat-effects img').length>0,'Relationships use player-badge icons and the existing rules dialog');
  check(document.querySelector('.game-player-focus > svg').hasAttribute('hidden')&&[...document.querySelectorAll('.avatar-badge')].every(avatar=>avatar.children.length===1),'Context actions have no scrim and effect icons leave avatar artwork intact');
  check([...$('actions').children].map(child=>child.id).join()==='active-rules'&&!$('opening'),'The complete controller has no generic bottom add-on or color-recovery area');
  await frames();const specialPrompt=document.querySelector('.game-player-focus-prompt').getBoundingClientRect();check(!overlap(specialPrompt,$('hand-actions').getBoundingClientRect())&&!overlap(specialPrompt,$('active-rules').getBoundingClientRect()),'Context actions leave the stable bottom controls uncovered');await capture('addons-context');
  publish({phase:'finished',winner:0,speed:1,can_combo:false,can_end_enemy:false});await frames();
  check(!$('replay').hidden&&$('sort').hidden&&$('replay').parentElement===$('hand-actions')&&$('replay').getBoundingClientRect().right<=$('hand-actions').getBoundingClientRect().right+1,'Phone replay replaces Sort in the existing action row');
  check(!document.querySelector('[title]'),'Add-ons add no hover popups');
  window.qaResult={checks,failures:0};
 }catch(error){window.qaResult={checks,failures:1,error:String(error)};}
})();
`;
let html=await readFile(join(root,'Games/uno/controller/index.html'),'utf8');
html=html.replace('<script src="/controller-sdk.js"></script>',`<script src="/controller-sdk.js"></script><script>${boot}</script>`).replace('</body>',`<script>${assertions}</script></body>`);
const types={'.css':'text/css','.js':'application/javascript','.svg':'image/svg+xml','.png':'image/png','.html':'text/html'};
const server=createServer(async(request,response)=>{
 try{
  const url=new URL(request.url,'http://127.0.0.1');
  if(url.pathname==='/game/uno/'){response.writeHead(200,{'Content-Type':'text/html'});response.end(html);return;}
  if(url.pathname==='/game/uno/background.json'){response.writeHead(200,{'Content-Type':'application/json'});response.end(JSON.stringify({image:'/game/uno/art/sunset-lounge.png',videos:[]}));return;}
  let name=url.pathname.startsWith('/game/')?'Games/'+url.pathname.slice(6):url.pathname.startsWith('/ui/')?url.pathname.slice(1):'web/'+url.pathname.slice(1);
  if(/^Games\/uno\/(style.css|controller.js)$/.test(name))name=name.replace('uno/','uno/controller/');
  const file=resolve(root,name);if(!file.startsWith(root+sep))throw Error('Unsafe fixture path');
  const body=await readFile(file);response.writeHead(200,{'Content-Type':types[extname(file)]||'application/octet-stream'});response.end(body);
 }catch{response.writeHead(404);response.end();}
});
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function protocol(url){
 const socket=new WebSocket(url),requests=new Map();let id=0;
 socket.addEventListener('message',event=>{const message=JSON.parse(event.data),request=requests.get(message.id);if(request){requests.delete(message.id);message.error?request.reject(Error(JSON.stringify(message.error))):request.resolve(message.result);}});
 await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
 return {socket,send(method,params={}){return new Promise((resolve,reject)=>{const requestId=++id;const timer=setTimeout(()=>reject(Error('Chromium timeout: '+method)),5000);requests.set(requestId,{resolve:value=>{clearTimeout(timer);resolve(value);},reject:error=>{clearTimeout(timer);reject(error);}});socket.send(JSON.stringify({id:requestId,method,params}));});}};
}
await mkdir(output,{recursive:true});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const child=spawn(chrome,['--headless','--no-sandbox','--disable-gpu','--no-first-run','--disable-background-networking','--remote-debugging-port=0',`--user-data-dir=${join(output,'chrome-profile-'+process.pid)}`],{windowsHide:true,stdio:['ignore','ignore','pipe']});
let browser,failed=false,startup;
try{
 const endpoint=await Promise.race([new Promise((resolve,reject)=>{child.on('error',reject);child.stderr.on('data',chunk=>{const match=String(chunk).match(/DevTools listening on (ws:\/\/[^\s]+)/);if(match)resolve(match[1]);});}),new Promise((_,reject)=>{startup=setTimeout(()=>reject(Error('Chromium did not start')),15000);})]);
 clearTimeout(startup);browser=await protocol(endpoint);
 const target=await browser.send('Target.createTarget',{url:'about:blank'}),tabs=await(await fetch(`http://127.0.0.1:${new URL(endpoint).port}/json/list`)).json();
 const page=await protocol(tabs.find(tab=>tab.id===target.targetId).webSocketDebuggerUrl);await page.send('Page.enable');
 for(const [name,width,height,reduced] of [['portrait',390,844,false],['small',360,640,false],['landscape',844,390,false],['tablet',768,1024,false],['desktop',1440,900,false],['reduced',390,844,true]]){
  if(process.env.UNO_VIEWS&&!process.env.UNO_VIEWS.split(',').includes(name))continue;
  if(process.env.UNO_VIEW&&name!==process.env.UNO_VIEW)continue;
  await page.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
  await page.send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:reduced?'reduce':'no-preference'}]});
  await page.send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/game/uno/?fixture=${name}`});
  let result,tapDone=false,holdDone=false,drawDone=false,colorDone=false,swapDone=false;
  for(let attempt=0;attempt<480;attempt++){
   await wait(50);
   if(!swapDone&&(await page.send('Runtime.evaluate',{expression:'Boolean(window.qaSwapReady)',returnByValue:true})).result.value){
    swapDone=true;
    const point=(await page.send('Runtime.evaluate',{expression:"(()=>{const r=document.querySelector('.uno-player[data-seat=\"2\"] .uno-player-box').getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2};})()",returnByValue:true})).result.value;
    await page.send('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:1});
    await page.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[point]});await wait(180);
    await page.send('Runtime.evaluate',{expression:'qaHandlers.message(structuredClone(qaState))'});
    await page.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await wait(80);
    await page.send('Emulation.setTouchEmulationEnabled',{enabled:false});
    await page.send('Runtime.evaluate',{expression:'window.qaSwapDone=true'});
   }
   if(!colorDone&&(await page.send('Runtime.evaluate',{expression:'Boolean(window.qaColorReady)',returnByValue:true})).result.value){
    colorDone=true;
    const point=(await page.send('Runtime.evaluate',{expression:'(()=>{const r=document.getElementById("color-card").getBoundingClientRect(),angle=25*Math.PI/180;return {x:r.left+(60+18*Math.cos(angle)-28*Math.sin(angle))*r.width/120,y:r.top+(90+18*Math.sin(angle)+28*Math.cos(angle))*r.height/180};})()',returnByValue:true})).result.value;
    await page.send('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:1});
    await page.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[point]});await wait(150);await page.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    await page.send('Emulation.setTouchEmulationEnabled',{enabled:false});
    await page.send('Runtime.evaluate',{expression:'window.qaRealColor=qaSent.at(-1)?.color;window.qaColorDone=true'});
   }
   if(!tapDone&&(await page.send('Runtime.evaluate',{expression:'Boolean(window.qaHandTapReady)',returnByValue:true})).result.value){
    tapDone=true;
    const point=async id=>(await page.send('Runtime.evaluate',{expression:`(()=>{const r=document.getElementById(${JSON.stringify(id)}).getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2};})()`,returnByValue:true})).result.value;
    const right=await point('hand-right');
    await page.send('Input.dispatchMouseEvent',{type:'mousePressed',...right,button:'left',buttons:1,clickCount:1});
    await page.send('Input.dispatchMouseEvent',{type:'mouseReleased',...right,button:'left',buttons:0,clickCount:1});await wait(320);
    await page.send('Runtime.evaluate',{expression:'window.qaMouseStart=Number(document.getElementById("hand").dataset.start)'});
    await page.send('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:1});
    const left=await point('hand-left');
    await page.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[left]});
    await page.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await wait(320);
    await page.send('Runtime.evaluate',{expression:'window.qaTouchStart=Number(document.getElementById("hand").dataset.start);window.qaHandTapDone=true'});
   }
   if(!holdDone&&(await page.send('Runtime.evaluate',{expression:'Boolean(window.qaHoldReady)',returnByValue:true})).result.value){
    holdDone=true;
    const point=async id=>(await page.send('Runtime.evaluate',{expression:`(()=>{const r=document.getElementById(${JSON.stringify(id)}).getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2};})()`,returnByValue:true})).result.value;
    const right=await point('hand-right');
    await page.send('Input.dispatchMouseEvent',{type:'mousePressed',...right,button:'left',buttons:1,clickCount:1});await wait(80);
    await page.send('Runtime.evaluate',{expression:'window.qaMouseHeldStart=Number(document.getElementById("hand").dataset.start)'});await wait(640);
    await page.send('Runtime.evaluate',{expression:'window.qaMouseHeldFinal=Number(document.getElementById("hand").dataset.start)'});
    await page.send('Input.dispatchMouseEvent',{type:'mouseReleased',...right,button:'left',buttons:0,clickCount:1});await wait(350);
    await page.send('Runtime.evaluate',{expression:'window.qaMouseStopped=Number(document.getElementById("hand").dataset.start)'});
    await page.send('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:1});
    const left=await point('hand-left');await page.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[left]});await wait(80);
    await page.send('Runtime.evaluate',{expression:'window.qaTouchHeldStart=Number(document.getElementById("hand").dataset.start)'});await wait(640);
    await page.send('Runtime.evaluate',{expression:'window.qaTouchHeldFinal=Number(document.getElementById("hand").dataset.start)'});
    await page.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await wait(320);
    await page.send('Runtime.evaluate',{expression:'window.qaHoldDone=true'});
   }
   if(!drawDone&&(await page.send('Runtime.evaluate',{expression:'Boolean(window.qaDrawClickReady)',returnByValue:true})).result.value){
    drawDone=true;
    const point=async id=>(await page.send('Runtime.evaluate',{expression:`(()=>{const r=document.getElementById(${JSON.stringify(id)}).getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2};})()`,returnByValue:true})).result.value;
    const keep=await point('pass');await page.send('Input.dispatchMouseEvent',{type:'mousePressed',...keep,button:'left',buttons:1,clickCount:1});await wait(180);
    await page.send('Runtime.evaluate',{expression:'qaHandlers.message(structuredClone(qaState))'});
    await page.send('Input.dispatchMouseEvent',{type:'mouseReleased',...keep,button:'left',buttons:0,clickCount:1});await wait(80);
    await page.send('Runtime.evaluate',{expression:'window.qaRealKeep=qaSent.at(-1)?.action'});
    const play=await point('play-drawn');await page.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[play]});await wait(180);
    await page.send('Runtime.evaluate',{expression:'qaHandlers.message(structuredClone(qaState))'});
    await page.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await wait(80);
    await page.send('Runtime.evaluate',{expression:'window.qaRealPlayCard=qaSent.at(-1)?.card;window.qaDrawClickDone=true'});
   }
   const gesture=(await page.send('Runtime.evaluate',{expression:'window.qaGesture',returnByValue:true})).result.value;
   if(gesture){
    if(gesture.type==='touch'){
     await page.send('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:1});await page.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:gesture.x,y:gesture.y}]});
     for(let step=1;step<=10;step++){await page.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:gesture.x+gesture.dx*step/10,y:gesture.y}]});await wait(12);}
    }else{
     await page.send('Input.dispatchMouseEvent',{type:'mousePressed',x:gesture.x,y:gesture.y,button:'left',buttons:1,clickCount:1});
     if(gesture.type==='mouse')for(let step=1;step<=10;step++){await page.send('Input.dispatchMouseEvent',{type:'mouseMoved',x:gesture.x+gesture.dx*step/10,y:gesture.y,button:'left',buttons:1});await wait(12);}
    }
    await page.send('Runtime.evaluate',{expression:'new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))',awaitPromise:true});
    await page.send('Runtime.evaluate',{expression:'window.qaDragPosition=Number(document.getElementById("hand").dataset.position)'});
    if(gesture.type==='touch')await page.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    else await page.send('Input.dispatchMouseEvent',{type:'mouseReleased',x:gesture.x+gesture.dx,y:gesture.y,button:'left',buttons:0,clickCount:1});
    await page.send('Runtime.evaluate',{expression:'window.qaGesture=null'});
   }
   const captureName=(await page.send('Runtime.evaluate',{expression:'window.qaCapture',returnByValue:true})).result.value;
   if(captureName){const shot=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});await writeFile(join(output,name+'-'+captureName+'.png'),Buffer.from(shot.data,'base64'));await page.send('Runtime.evaluate',{expression:'window.qaCapture=null'});}
   const value=await page.send('Runtime.evaluate',{expression:'window.qaResult',returnByValue:true});if(value.result.value){result=value.result.value;break;}
  }
  if(!result)throw Error(name+': assertions timed out');
  console.log(name+': '+JSON.stringify(result));failed ||= result.failures>0;
  const screenshot=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});await writeFile(join(output,name+'.png'),Buffer.from(screenshot.data,'base64'));
 }
 page.socket.close();
}finally{clearTimeout(startup);if(browser){await browser.send('Browser.close').catch(()=>{});browser.socket.close();}else child.kill();await new Promise(resolve=>server.close(resolve));}
if(failed)process.exitCode=1;
