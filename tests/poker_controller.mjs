import {createServer} from 'node:http';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {resolve,join,extname,sep} from 'node:path';
import {spawn} from 'node:child_process';

const root=resolve(import.meta.dirname,'..'),output=join(root,'.test_data/poker-controller');
const chrome=process.argv[2]||process.env.CHROME_BIN||'C:/Program Files/Google/Chrome/Application/chrome.exe';
const fixtures={};for(const mode of ['texas','omaha'])fixtures[mode]=JSON.parse(await readFile(join(root,'.test_data/poker-visual/'+mode+'-controller.json'),'utf8'));
const resultFixtures={};for(const mode of ['texas','omaha'])resultFixtures[mode]=JSON.parse(await readFile(join(root,'.test_data/poker-visual/'+mode+'-results-controller.json'),'utf8'));
const assertionCode=`(async()=>{
let checks=0;const check=(ok,label)=>{checks++;window.qaProgress=label;if(!ok)throw Error(label);},pause=ms=>new Promise(r=>setTimeout(r,ms)),$=id=>document.getElementById(id);
const publish=patch=>{qaState={...qaState,...patch};qaHandlers.message(structuredClone(qaState));};
try{
await pause(300);
check(document.documentElement.scrollWidth<=innerWidth+1,'No horizontal overflow');
check(!document.querySelector('[title]'),'No hover tooltips');
check($('hand').children.length===(qaState.variant==='omaha'?4:2),'Only the owner’s complete private hand is rendered');
check($('community').children.length===5,'Five stable community positions');
check($('stages').closest('header')&&$('current-bet').closest('#pot'),'Stage map is in the top bar and current bet is next to the pot');
check($('stages').closest('header').getBoundingClientRect().width>=document.querySelector('.poker-controller').clientWidth-32,'The centered Poker header spans the controller in portrait and landscape');
check($('current-bet').textContent===qaState.current_bet.toLocaleString('en-US')&&$('your-bet').textContent===qaState.players[qaState.viewer].street.toLocaleString('en-US'),'Current and personal bets follow authoritative state');
const publicTable=$('table').getBoundingClientRect();check([...$('community').children].every(card=>{const rect=card.getBoundingClientRect();return rect.x>=publicTable.x+publicTable.width*.19&&rect.right<=publicTable.x+publicTable.width*.81&&rect.bottom<=publicTable.y+publicTable.height*.74;}),'Community cards stay inside the felt in both phone orientations');
check(!$('identity').querySelector('strong'),'Player identity omits the chip balance');
check([...document.images].every(image=>image.complete&&image.naturalWidth>0),'Artwork loads completely offline');
check($('identity').classList.contains('game-casino-player')&&getComputedStyle($('identity').querySelector('.avatar-badge span')).maskImage.includes('avatar-'+qaState.identities[qaState.viewer].pose+'.svg'),'Rounded casino plaques retain the original player profile avatar');
check(getComputedStyle($('identity')).getPropertyValue('--player-color')===qaState.identities[qaState.viewer].color,'Player avatars preserve the identity color');
check(!$('identity').classList.contains('game-player-chip')&&getComputedStyle($('identity')).backgroundImage.includes('rgb(51, 59, 64)'),'The rounded plaque retains its border and has no extra color dot');
check(!$('call').disabled&&$('call').textContent.includes('20'),'Current player can call the authoritative amount');
check(getComputedStyle($('call')).backgroundImage.includes('rgb(8, 121, 195)'),'Casino call inherits the shared blue palette');
for(const selector of ['#fold','#call','#bet','#raise-slider'])for(const node of document.querySelectorAll(selector)){const rect=node.getBoundingClientRect();check(rect.height>=44&&rect.width>=44,'Touch target '+selector+' is at least 44px');}
const face=$('hand').firstElementChild.getBoundingClientRect();check(Math.abs(face.width/face.height-2/3)<.03,'Private cards retain portrait proportions');
window.qaCapture='table';while(window.qaCapture)await pause(20);
$('raise-slider').value=Math.min(qaState.legal.max_raise_to,qaState.legal.min_raise_to+qaState.big_blind);$('raise-slider').dispatchEvent(new Event('input'));check($('raise-slider').value===$('raise-value').value,'Slider synchronizes the custom raise total');check(parseFloat($('raise-slider').style.getPropertyValue('--range-progress'))>0,'The decorated slider fill follows the selected total');const amount=$('raise-value').value;$('raise-value').focus();publish({clock:{...qaState.clock,remaining:18}});await pause(120);
check($('raise-value').value===amount&&document.activeElement===$('raise-value'),'Clock packets preserve focused raise input');
const before=qaSent.length;$('call').click();check(qaSent.length===before+1&&qaSent.at(-1).action==='call'&&qaSent.at(-1).revision===qaState.revision,'Call sends one revision-bound action');
check(!document.querySelector('[data-pot],#all-in,#presets'),'Pot presets and the separate All In control are removed');
const beforeFeedback=structuredClone(qaState.players),feedback=structuredClone(beforeFeedback);feedback[qaState.viewer].last_action='raise';feedback[qaState.viewer].last_amount=40;publish({revision:qaState.revision+1,players:feedback});check($('my-action').textContent==='RAISED +40'&&getComputedStyle($('my-action')).color==='rgb(142, 229, 173)','Raised feedback includes the authoritative increase in readable green');feedback[qaState.viewer].last_action='call';feedback[qaState.viewer].last_amount=20;publish({revision:qaState.revision+1,players:structuredClone(feedback)});check($('my-action').textContent==='CALLED 20'&&!$('my-action').classList.contains('game-raised'),'Called feedback includes the amount paid');feedback[qaState.viewer].last_amount=0;publish({revision:qaState.revision+1,players:structuredClone(feedback)});check(!$('my-action').textContent,'Older saves omit unavailable betting amounts');publish({revision:qaState.revision+1,players:beforeFeedback});
const foldedFeedback=structuredClone(beforeFeedback);foldedFeedback[qaState.viewer].folded=true;publish({revision:qaState.revision+1,players:foldedFeedback});check(getComputedStyle($('identity')).opacity==='0.5'&&$('your-bet').closest('#identity'),'Folded identities dim with their chip bet inside the box');publish({revision:qaState.revision+1,players:beforeFeedback});
if(qaState.variant==='omaha')check(Number($('raise-slider').max)<qaState.players[qaState.viewer].stack+qaState.players[qaState.viewer].street&&$('bet').textContent==='BET','Omaha caps the slider at the legal pot maximum');
check(!document.getElementById('raise'),'The redundant Raise button is removed');$('bet').click();check(qaSent.at(-1).action==='raise'&&qaSent.at(-1).amount===Number(amount),'BET submits the explicit total');
$('raise-slider').value=qaState.legal.max_raise_to;$('raise-slider').dispatchEvent(new Event('input'));check($('bet').textContent===(qaState.legal.all_in&&qaState.legal.max_raise_to===qaState.players[qaState.viewer].stack+qaState.players[qaState.viewer].street?'ALL IN':'BET'),'The maximum slider position labels a legal whole-stack wager All In');
$('raise-value').value=amount;$('raise-value').dispatchEvent(new Event('input'));check($('raise-slider').value===amount,'Custom typing also updates the slider');
const current=qaState.legal;publish({paused:true,pause_reason:'Waiting for Player'});check($('fold').disabled&&$('call').disabled,'Disconnect pause disables betting');
const pausedCount=qaSent.length;$('call').click();check(qaSent.length===pausedCount,'Paused taps are discarded');
publish({paused:false,pause_reason:'',animating:true,motion:{...qaState.motion,active:true,revision:qaState.motion.revision+1,elapsed:0,duration:.3,flights:[]}});check($('call').disabled,'Host movement locks betting');
publish({animating:false,motion:{...qaState.motion,active:false,elapsed:0}});if(!matchMedia('(prefers-reduced-motion: reduce)').matches&&!qaState.reduced_motion)check($('call').disabled,'Early host unlock still waits for local movement');
await pause(350);publish({animating:false,motion:{...qaState.motion,active:false,elapsed:.3}});check(!$('call').disabled,'Betting returns when authoritative and local movement settle');
// A real held mouse/touch target survives a timer publication before release.
$('call').scrollIntoView({block:'center'});await pause(50);const button=$('call').getBoundingClientRect(),heldBefore=qaSent.length;
window.qaGesture={x:button.x+button.width/2,y:button.y+button.height/2};setTimeout(()=>publish({clock:{...qaState.clock,remaining:17}}),80);while(window.qaGesture)await pause(20);
check(qaSent.length===heldBefore+1&&qaSent.at(-1).action==='call','Held press survives clock updates and fires once');
qaHandlers.disconnected();check($('call').disabled&&$('hand').style.visibility==='hidden','Socket loss hides private cards and disables input');
qaHandlers.connected();qaHandlers.message(structuredClone(qaState));check(!$('call').disabled&&$('hand').children.length===qaState.hand.length,'Reconnect restores the same hand and actions');
$('help-open').click();check($('help').open&&$('mode-rules').textContent.includes(qaState.variant==='omaha'?'exactly two':'two private'),'Explicit help states the selected variant');$('help-close').click();
const names=structuredClone(qaState.identities);names[0].display_name='<img src=x onerror=alert(1)>';
publish({revision:qaState.revision+1,identities:names});check($('identity').textContent.includes('<img src=x')&&!$('identity').querySelector('img[src="x"]'),'Player names remain literal text');
const table=structuredClone(qaState.players);table[0].hand=qaState.hand;table[1].folded=true;table[1].hand=[];
publish({revision:qaState.revision+1,phase:'hand_over',stage:'showdown',turn:-1,showdown:true,players:table,phase_remaining:12,clock:{...qaState.clock,running:false},hand_winners:[0],winning_cards:{'0':qaState.hand.slice(0,2).concat(qaState.board.slice(0,3))},hand_results:[{seat:0,rank:1,category:'One Pair',cards:qaState.hand.slice(0,2).concat(qaState.board.slice(0,3)),amount:60},{seat:1,rank:0,category:'Folded',cards:[],amount:0}],awards:[{amount:60,winners:[0],shares:[{seat:0,amount:60}]}],legal:{...current,can_raise:false,call:-1,check:false}});
check($('showdown').open&&$('showdown-close').disabled&&$('review-countdown').textContent.includes('12'),'Results open automatically with a non-skippable twelve-second countdown');
check($('showdown-hands').children.length===1&&$('showdown-hands').firstElementChild.dataset.rank==='1'&&$('showdown-hands').querySelectorAll('.game-standard-card').length===5,'Ranked results show the best five cards and omit folded players entirely');
check(!$('awards').textContent&&$('showdown-heading').textContent===qaState.identities[0].display_name+' with One Pair'&&$('showdown-hands').querySelector('.game-ranked-amount img')&&$('showdown-hands').textContent.includes('+60'),'Results name the winner and hand with a chip award and no duplicate Main or Side pot text');
check($('showdown-hands').querySelectorAll('.is-marked').length===2&&[...$('showdown-hands').querySelectorAll('.is-marked')].every(card=>card.classList.contains('is-selected')&&card.querySelector('.game-ranked-card-mark')?.textContent==='HOLE'&&card.getAttribute('aria-label').includes('HOLE')),'Hole cards in the best five have a visible highlight, label and accessible name');window.qaCapture='showdown';while(window.qaCapture)await pause(20);
publish({phase_remaining:7,paused:true});await pause(120);check($('review-countdown').textContent.includes('7')&&$('review-countdown').textContent.includes('PAUSED'),'Paused reviews preserve the host countdown');
publish({phase_remaining:0,paused:false});check(!$('showdown-close').disabled,'The review unlocks only after the host countdown finishes');$('showdown-close').click();
$('showdown-open').click();check($('showdown').open,'Finished rankings remain available after dismissing the automatic review');$('showdown-close').click();
publish({...qaResults,revision:qaState.revision+1,reduced_motion:qaState.reduced_motion,motion:{...qaResults.motion,revision:qaState.motion.revision+1}});
check($('showdown').open&&$('showdown-hands').children.length===qaResults.hand_results.filter(entry=>entry.rank>0).length,'Actual ten-player host results open with the complete roster');
check([...$('showdown-hands').children].every((row,index)=>Number(row.dataset.seat)===qaResults.hand_results.filter(entry=>entry.rank>0)[index].seat),'All results preserve the authoritative best-to-worst ordering');
check([...$('showdown-hands').children].every(row=>Number(row.dataset.rank)>0),'Folded and earlier eliminated entries are absent from the review');
check([...$('showdown-hands').children].every(row=>{const entry=qaResults.hand_results.find(entry=>entry.seat===Number(row.dataset.seat));return row.querySelectorAll('.is-marked').length===entry.cards.filter(card=>qaResults.players[entry.seat].hand.includes(card)).length;}),'Each real result highlights only its own hole cards and leaves shared board cards unmarked');
const losses=qaResults.hand_results.filter(entry=>entry.rank>0&&entry.net<0);check(losses.length>0&&losses.every(entry=>{const amount=$('showdown-hands').querySelector('[data-seat="'+entry.seat+'"] .game-ranked-amount');return amount?.classList.contains('is-loss')&&amount.textContent.startsWith('-')&&getComputedStyle(amount).color==='rgb(255, 125, 134)';}),'Actual losing hands show signed net losses in red');
check($('showdown-hands').scrollWidth<=$('showdown-hands').clientWidth+1,'Full rankings have no horizontal scrolling or cropped fifth cards');
const listRect=$('showdown-hands').getBoundingClientRect();check([...$('showdown-hands').querySelectorAll('.game-standard-card')].every(card=>card.getBoundingClientRect().right<=listRect.right+1),'Every best-five card fits inside the scrollable results body');
const closeRect=$('showdown-close').getBoundingClientRect();check(closeRect.y>=0&&closeRect.bottom<=innerHeight,'Full-roster results keep their action visible while rankings scroll');
if(innerHeight>=640)check($('showdown-hands').scrollHeight<=$('showdown-hands').clientHeight+1,'Compact full-roster results fit without a vertical scrollbar');
window.qaCapture='full-results';while(window.qaCapture)await pause(20);
publish({phase_remaining:7});qaHandlers.disconnected();await pause(1100);check($('review-countdown').textContent.includes('7')&&$('review-countdown').textContent.includes('RECONNECTING'),'Socket loss freezes the local review countdown while waiting for authoritative reconnect');
qaHandlers.connected();qaHandlers.message(structuredClone(qaState));check($('showdown').open&&$('showdown-close').disabled,'Reconnect retains the ranked review and its remaining minimum duration');
window.dispatchEvent(new Event('pagehide'));check(!document.querySelector('.game-card-flights')?.children.length,'Page exit clears earlier flights');
window.qaResult={checks,failures:0};
}catch(error){window.qaResult={checks,failures:1,error:String(error),progress:window.qaProgress};}
})();`;
new Function(assertionCode);
const types={'.css':'text/css','.js':'application/javascript','.svg':'image/svg+xml','.png':'image/png','.html':'text/html'};
const server=createServer(async(req,res)=>{try{
 const url=new URL(req.url,'http://127.0.0.1'),mode=url.pathname.includes('poker-omaha')?'omaha':'texas',id=mode==='omaha'?'poker-omaha':'poker-texas-holdem';
 if(url.pathname==='/game/'+id+'/'){
  let html=await readFile(join(root,'Games',id,'controller/index.html'),'utf8');
  const boot='window.qaState='+JSON.stringify(fixtures[mode])+';window.qaResults='+JSON.stringify(resultFixtures[mode])+';window.qaSent=[];class FixtureController extends StarGamesController{constructor(id,handlers){super(id,handlers);window.qaHandlers=handlers;}connect(){qaHandlers.connected({});qaHandlers.message(structuredClone(qaState));}send(input){qaSent.push(input);}}window.StarGamesController=FixtureController;';
  html=html.replace('<script src="/controller-sdk.js"></script>',()=>'<script src="/controller-sdk.js"></script><script>'+boot+'</script>').replace('</body>',()=>'<script>'+assertionCode+'</script></body>');
  res.writeHead(200,{'Content-Type':'text/html'});res.end(html);return;
 }
 if(url.pathname.endsWith('/background.json')){res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({image:'/game/'+id+'/art/lounge.png',videos:[]}));return;}
 let name=url.pathname.startsWith('/game/')?'Games/'+url.pathname.slice(6):url.pathname.startsWith('/ui/')?url.pathname.slice(1):'web/'+url.pathname.slice(1);
 name=name.replace(/^(Games\/poker-(?:texas-holdem|omaha))\/(controller.js|style.css)$/,'$1/controller/$2');
 const file=resolve(root,name);if(!file.startsWith(root+sep))throw Error('Unsafe path');const body=await readFile(file);res.writeHead(200,{'Content-Type':types[extname(file)]||'application/octet-stream'});res.end(body);
}catch{res.writeHead(404);res.end();}});
const wait=ms=>new Promise(r=>setTimeout(r,ms));
async function protocol(url){const socket=new WebSocket(url),requests=new Map();let id=0;socket.addEventListener('message',event=>{const message=JSON.parse(event.data),request=requests.get(message.id);if(message.method==='Runtime.exceptionThrown')console.error(JSON.stringify(message.params));if(request){requests.delete(message.id);message.error?request.reject(Error(JSON.stringify(message.error))):request.resolve(message.result);}});await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});return{socket,send(method,params={}){return new Promise((resolve,reject)=>{const current=++id,timer=setTimeout(()=>reject(Error('Chromium timeout: '+method)),5000);requests.set(current,{resolve:value=>{clearTimeout(timer);resolve(value);},reject:error=>{clearTimeout(timer);reject(error);}});socket.send(JSON.stringify({id:current,method,params}));});}};}
await mkdir(output,{recursive:true});await new Promise(r=>server.listen(0,'127.0.0.1',r));
const child=spawn(chrome,['--headless','--no-sandbox','--disable-gpu','--no-first-run','--disable-background-networking','--remote-debugging-port=0','--user-data-dir='+join(output,'chrome-'+process.pid)],{windowsHide:true,stdio:['ignore','ignore','pipe']});
let browser,failed=false;
try{
 const endpoint=await new Promise((resolve,reject)=>{child.on('error',reject);child.stderr.on('data',data=>{const match=String(data).match(/DevTools listening on (ws:\/\/[^\s]+)/);if(match)resolve(match[1]);});});browser=await protocol(endpoint);
 const target=await browser.send('Target.createTarget',{url:'about:blank'}),tabs=await(await fetch('http://127.0.0.1:'+new URL(endpoint).port+'/json/list')).json(),page=await protocol(tabs.find(tab=>tab.id===target.targetId).webSocketDebuggerUrl);await page.send('Page.enable');await page.send('Runtime.enable');
 for(const mode of ['texas','omaha'])for(const [name,width,height,reduced]of [['portrait',390,844,false],['small',360,640,false],['landscape',844,390,false],['tablet',768,1024,false],['desktop',1440,900,false],['reduced',390,844,true]]){
  if(process.env.POKER_VIEW&&name!==process.env.POKER_VIEW)continue;
  await page.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});await page.send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:reduced?'reduce':'no-preference'}]});
  await page.send('Page.navigate',{url:'http://127.0.0.1:'+server.address().port+'/game/'+(mode==='omaha'?'poker-omaha':'poker-texas-holdem')+'/'});let result;
  for(let attempt=0;attempt<250;attempt++){
   await wait(40);const read=expression=>page.send('Runtime.evaluate',{expression,returnByValue:true});
   const gesture=(await read('window.qaGesture')).result.value;
   if(gesture){await page.send('Input.dispatchMouseEvent',{type:'mousePressed',x:gesture.x,y:gesture.y,button:'left',buttons:1,clickCount:1});await wait(180);await page.send('Input.dispatchMouseEvent',{type:'mouseReleased',x:gesture.x,y:gesture.y,button:'left',buttons:0,clickCount:1});await read('window.qaGesture=null');}
   const capture=(await read('window.qaCapture')).result.value;
   if(capture){const picture=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});await writeFile(join(output,mode+'-'+name+'-'+capture+'.png'),Buffer.from(picture.data,'base64'));await read('window.qaCapture=null');}
   result=(await read('window.qaResult')).result.value;if(result)break;
  }
  if(!result){const progress=(await page.send('Runtime.evaluate',{expression:'window.qaProgress',returnByValue:true})).result.value;throw Error(mode+'/'+name+' timed out: '+progress);}
  console.log(mode+'/'+name+': '+JSON.stringify(result));failed ||= !!result.failures;
 }
 page.socket.close();
}finally{if(browser){await browser.send('Browser.close').catch(()=>{});browser.socket.close();}else child.kill();server.closeAllConnections();await new Promise(r=>server.close(r));}
if(failed)process.exitCode=1;
