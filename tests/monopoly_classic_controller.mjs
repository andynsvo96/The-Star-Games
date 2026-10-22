import {createServer} from 'node:http';
import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {resolve, join, sep, extname} from 'node:path';
import {spawn} from 'node:child_process';
const root=resolve(import.meta.dirname,'..'), output=join(root,'.test_data/monopoly-classic-controller');
const chrome=process.argv[2]||process.env.CHROME_BIN||'C:/Program Files/Google/Chrome/Application/chrome.exe';
const initial=JSON.parse(await readFile(join(root,'.test_data/monopoly-classic-visual/controller-state.json'),'utf8'));
const boot=`window.qaState=${JSON.stringify(initial)};window.qaSent=[];class ClassicFixtureController extends window.StarGamesController{constructor(id,handlers){super(id,handlers);window.qaHandlers=handlers;}connect(){qaHandlers.connected(qaState.players[0]);qaHandlers.message(structuredClone(qaState));}send(input){qaSent.push(input);}}window.StarGamesController=ClassicFixtureController;`;
const assertions=`(async()=>{
 let checks=0;const check=(ok,message)=>{checks++;window.qaProgress=message;if(!ok)throw Error(message);},pause=ms=>new Promise(r=>setTimeout(r,ms)),$=id=>document.getElementById(id);
 const publish=async patch=>{qaState={...qaState,...patch,revision:qaState.revision+1};qaHandlers.message(structuredClone(qaState));await pause(290);};
 const capture=async name=>{window.qaCapture=name;while(window.qaCapture)await pause(20);};
 try{
 await pause(350);await publish({reduced_motion:false});
 check(!document.getElementById('board')&&!document.querySelector('canvas'),'Phone never renders a board');
 check(document.documentElement.scrollWidth<=innerWidth+1,'Phone has no horizontal page overflow');
 check($('identity').textContent.includes(qaState.players[0].display_name)&&$('stats').textContent.includes('total wealth'),'Own identity, cash and total wealth are visible');
 check($('properties').querySelectorAll('.game-card-tile').length===qaState.properties.filter(p=>p.owner===qaState.viewer).length,'Portfolio contains only owned properties');
 check(!$('last-card')&&$('turn-order').querySelectorAll('.game-turn-name').length===qaState.players.length,'Redundant last-card control is removed and every player appears in the turn strip');
 check([...document.images].every(image=>image.complete&&image.naturalWidth>0&&new URL(image.src).origin===location.origin),'All card and title artwork loads offline');
 check(!document.querySelector('[title]'),'No hover tooltips');
 check([...document.querySelectorAll('#actions button')].every(node=>node.getBoundingClientRect().height>=44),'Decision buttons meet the touch target size');
 await capture('playing');
 const first=qaState.properties.find(p=>p.owner===0),originalActions=structuredClone(qaState.actions);
 $('properties').querySelector('.game-card-tile').click();
 const reader=document.getElementById('card-reader');
 check(reader.open&&reader.querySelector('.game-reader-card').getBoundingClientRect().width>=250,'Tapping a deed opens the shared large reader');
 check(reader.scrollWidth<=reader.clientWidth+1,'Deed reader fits the phone');
 check(reader.querySelector('.game-reader-subtitle').textContent==='Owned by '+qaState.players[0].display_name&&reader.querySelectorAll('.game-deed-row.is-active').length===1,'The reader identifies the owner and highlights only its current rent');
 await capture('deed');reader.querySelector('footer button').click();
 const originalProperties=structuredClone(qaState.properties),mortgage=qaState.properties.find(card=>card.owner===0&&!card.buildings);
 if(mortgage){await publish({properties:qaState.properties.map(card=>card.id===mortgage.id?{...card,mortgaged:true,deed_state:{...card.deed_state,rows:card.deed_state.rows.map(row=>({...row,active:false}))}}:card)});$('properties').querySelector('[data-card="'+mortgage.id+'"]').closest('button').click();check(reader.querySelector('.is-mortgaged .game-mortgage-stamp')?.textContent==='MORTGAGED'&&!reader.querySelector('.game-deed-row.is-active'),'Mortgaged deeds show the diagonal stamp and no active rent');await capture('mortgaged');reader.querySelector('footer button').click();await publish({properties:originalProperties});}
 const payload=originalActions.find(c=>c.payload.action==='roll').payload;
 const before=qaSent.length;$('actions').querySelector('[data-command="roll"]').click();
 check(qaSent.length===before+1&&qaSent.at(-1).action==='roll'&&qaSent.at(-1).revision===qaState.revision,'Roll uses the host revision and never supplies dice');
 const cashMotion={revision:90,active:true,elapsed:0,duration:1.15,flights:[],effects:[],money:[{start:0,duration:1.15,seat:0,target:1,changes:[{seat:0,amount:-50},{seat:1,amount:50}]}]};
 await publish({animating:true,motion:cashMotion});
 check(document.querySelector('.game-cash-change.is-loss')?.textContent==='−$50','Cash payments display red signed loss feedback at the owning identity');
 const cashBounds=document.querySelector('[data-money-amount]').getBoundingClientRect(),lossBounds=document.querySelector('.game-cash-change.is-loss').getBoundingClientRect();
 check(lossBounds.top>=cashBounds.bottom&&Math.abs(lossBounds.x+lossBounds.width/2-cashBounds.x-cashBounds.width/2)<1,'Loss feedback is centered directly below the displayed money amount');
 check(!document.querySelector('.game-cash-change.is-gain'),'A phone does not invent another player name or money target');
 await capture('cash-feedback');
 await publish({paused:true,motion:{...cashMotion,elapsed:.4}});
 const cashTop=document.querySelector('.game-cash-change')?.style.top;await pause(120);
 check(document.querySelector('.game-cash-change')?.style.top===cashTop,'Pausing freezes cash feedback at the host elapsed time');
 await publish({paused:false,reduced_motion:true,motion:{...cashMotion,revision:91,active:false,money:[{start:0,duration:1.15,seat:-1,target:-1,changes:[{seat:0,amount:30}]}]}});
 check(document.querySelector('.game-cash-change.is-gain')?.textContent==='+$30'&&!document.querySelector('.game-money-effect img'),'Reduced motion keeps a static green gain without flying cash');
 const gainBounds=document.querySelector('.game-cash-change.is-gain').getBoundingClientRect(),balanceBounds=document.querySelector('[data-money-amount]').getBoundingClientRect();
 check(gainBounds.bottom<=balanceBounds.top&&Math.abs(gainBounds.x+gainBounds.width/2-balanceBounds.x-balanceBounds.width/2)<1,'Gain feedback is centered directly above the displayed money amount');
 const firstSync=new StarGamesMoneyEffect(()=>document.getElementById('identity').getBoundingClientRect());firstSync.update({...cashMotion,revision:92,active:false},{reduced:true});
 check(!firstSync.layer.children.length,'Refreshing a settled reduced-motion snapshot does not replay old cash feedback');firstSync.clear();firstSync.layer.remove();
 await publish({reduced_motion:false,motion:{revision:93,active:true,elapsed:0,duration:.95,flights:[],money:[],effects:[{start:0,duration:.95,card:qaState.last_card,label:'Community Chest card'}]}});
 check(!!document.querySelector('.game-card-impact'),'Drawing an event card uses the shared animated card reveal on controllers');
 await capture('card-reveal');
 await publish({motion:{revision:94,active:false,elapsed:0,duration:0,flights:[],effects:[],money:[]}});
 check([...$('actions').querySelectorAll('[data-command]')].every(node=>node.disabled),'Authoritative movement locks actions');
 $('properties').querySelector('.game-card-tile').click();
 check(reader.open&&[...reader.querySelectorAll('[data-reader-action]')].every(node=>node.disabled),'Deeds remain readable while their actions are locked');
 reader.querySelector('footer button').click();await publish({animating:false});
 await publish({phase:'auction',actor:0,auction:{property:39,leader:1,amount:40,seat:0,passed:[],ticket:8,step:1},actions:[{label:'Bid',payload:{action:'bid',amount:41}},{label:'Pass',payload:{action:'pass_bid'}}]});
 const input=$('bid-amount');input.value='75';qaHandlers.message({type:'clock',revision:qaState.revision,clocks:{...qaState.clocks,turn:32}});await pause(25);
 check($('bid-amount')===input&&input.value==='75','Clock packets preserve a typed auction bid and input identity');
 const bidBefore=qaSent.length;$('context').querySelector('[data-command="bid"]').click();
 check(qaSent.length===bidBefore+1&&qaSent.at(-1).amount===75&&qaSent.at(-1).action==='bid','Explicit bid submits the entered whole-dollar amount');
 await capture('auction');
 await publish({phase:'building_interest',auction:{},building_sale:{kind:'house'},actions:[{label:'Request',payload:{action:'claim_building',property:first.id}},{label:'Pass',payload:{action:'decline_building'}}]});
 check($('context').textContent.includes('one house left')&&$('actions').querySelector('[data-command="claim_building"]'),'Scarce-building requests name the eligible street');
 $('actions').querySelector('[data-command="claim_building"]').click();check(qaSent.at(-1).action==='claim_building'&&qaSent.at(-1).property===first.id,'Building request submits only the selected eligible placement');
 await capture('building-request');
 await publish({phase:'auction',building_sale:{},auction:{kind:'building',building:'hotel',eligible:{'0':[first.id,3]},property:first.id,leader:1,amount:60,seat:0,passed:[],ticket:12,step:1},actions:[{label:'Bid',payload:{action:'bid',amount:61,property:first.id}},{label:'Pass',payload:{action:'pass_bid'}}]});
 $('bid-property').value='3';$('bid-amount').value='80';$('context').querySelector('[data-command="bid"]').click();
 check(qaSent.at(-1).action==='bid'&&qaSent.at(-1).property===3&&qaSent.at(-1).amount===80,'Building auction preserves the explicit bid and chosen street');
 check($('context').textContent.includes('Last hotel auction'),'Building auction identifies which finite building is offered');
 await capture('building-auction');
 await publish({phase:'debt',actor:0,debt:{seat:0,target:1,amount:3000},auction:{},actions:[{label:'Mortgage',payload:{action:'mortgage',property:first.id}},{label:'Declare bankruptcy',payload:{action:'bankrupt'}},{label:'Trade',payload:{action:'offer_trade'}}]});
 check($('context').textContent.includes('$3000')&&!$('context').querySelector('input'),'Debt identifies the amount without automatic asset selection');
 check(!$('trade').hidden,'Debtor can explicitly compose a trade');
 await capture('debt');
 await publish({phase:'manage',actor:0,debt:{},actions:originalActions});
 $('trade').click();check($('trade-dialog').open,'Trade opens an explicit proposal form');
 $('give-cash').value='25';$('take-cash').value='0';const target=Number($('trade-target').value);
 const giveTile=$('give-properties').querySelector('.game-card-tile:not([disabled])'),takeTile=$('take-properties').querySelector('.game-card-tile:not([disabled])');
 giveTile.click();takeTile.click();
 check(giveTile.classList.contains('is-selected')&&takeTile.classList.contains('is-selected')&&!$('trade-dialog').querySelector('input[type="checkbox"]'),'Trade highlights real offered/requested property cards');
 await capture('trade');$('trade-form').requestSubmit();
 check(qaSent.at(-1).action==='offer_trade'&&qaSent.at(-1).to===target&&qaSent.at(-1).give_cash===25&&qaSent.at(-1).give_properties.includes(Number(giveTile.dataset.property))&&qaSent.at(-1).take_properties.includes(Number(takeTile.dataset.property))&&!$('trade-dialog').open,'Trade sends cash and selected assets only on submit');
 await publish({phase:'trade',actor:0,trade:{from:1,to:0,give_cash:50,take_cash:0,give_properties:[],take_properties:[first.id],give_jail:[],take_jail:[],ticket:9},actions:[{label:'Accept',payload:{action:'accept_trade'}},{label:'Decline',payload:{action:'decline_trade'}}]});
 check($('context').querySelectorAll('section').length===2&&$('context').querySelector('strong.game-success-text').textContent==='$50'&&$('context').querySelector('[data-card="'+first.id+'"] .game-deed-state'),'Trade response shows green cash and the actual transferred deed with its live state');
 await capture('trade-response');
 await publish({phase:'manage',actor:0,trade:{},actions:originalActions,paused:true});
 check([...$('actions').querySelectorAll('[data-command]')].every(node=>node.disabled),'Paused snapshots lock the same controls');
 qaHandlers.disconnected();check([...$('actions').querySelectorAll('[data-command]')].every(node=>node.disabled),'Disconnect disables stale commands');
 qaHandlers.connected(qaState.players[0]);await publish({paused:false});
 check(qaSent.some(input=>input.action==='sync')&&!$('actions').querySelector('[data-command="roll"]').disabled,'Reconnection asks for authoritative state and restores control');
 const escaped='<img src=x onerror="window.qaInjected=true">';await publish({theme:{...qaState.theme,labels:{[first.key]:escaped}}});
 check($('properties').textContent.includes(escaped)&&!window.qaInjected,'Skin names remain literal text');
 await publish({practice:true});check(!$('practice'),'Practice remains authoritative without a redundant UI banner');
 await publish({phase:'finished',winner:1,actions:[],players:qaState.players.map((p,i)=>({...p,wealth:i===1?2000:1800-i*100})),tie_rolls:[]});
 check(!$('results').hidden&&$('standings').textContent.split('WINNER').length===2&&$('standings').textContent.split('LOSS').length===qaState.players.length,'Results contain exactly one winner and every other player loses');
 await capture('results');
 $('help').click();check($('help-dialog').open,'Explicit help is reachable');$('close-help').click();
 check(document.documentElement.scrollWidth<=innerWidth+1,'All decisions preserve responsive page width');
 window.qaResult={checks,failures:0};
 }catch(error){window.qaResult={checks,failures:1,error:error.message,stack:error.stack};}
})();`;
let html=await readFile(join(root,'Games/monopoly-classic/controller/index.html'),'utf8');
html=html.replace('<script src="/controller-sdk.js"></script>',()=>`<script src="/controller-sdk.js"></script><script>${boot}</script>`).replace('</body>',()=>`<script>${assertions}</script></body>`);
let templateHtml=await readFile(join(root,'Games/_Template/controller/index.html'),'utf8');
templateHtml=templateHtml.replace('<script src="/controller-sdk.js"></script>',()=>`<script src="/controller-sdk.js"></script><script>${boot}</script>`);
const types={'.css':'text/css','.js':'application/javascript','.svg':'image/svg+xml','.png':'image/png','.html':'text/html'};
const server=createServer(async(req,res)=>{try{
 const url=new URL(req.url,'http://127.0.0.1');
 if(url.pathname==='/sdk-probe'){
  const to=url.searchParams.get('to')||'',type=url.searchParams.get('type')||'screen';
  const probe=`<!doctype html><body><script>window.WebSocket=class extends EventTarget{constructor(){super();setTimeout(()=>this.dispatchEvent(new MessageEvent('message',{data:JSON.stringify(${JSON.stringify({type,game_id:to,player:{display_name:'QA',color:'#2463eb'},reconnect_token:'qa'})})})),20);}send(){}};</script><script src="/controller-sdk.js"></script><script>new StarGamesController('qa-source').connect();</script></body>`;
  res.writeHead(200,{'Content-Type':'text/html'});res.end(probe);return;
 }
 if(url.pathname==='/'||url.pathname==='/game/qa-target/'){res.writeHead(200,{'Content-Type':'text/html'});res.end('<!doctype html><body>SDK destination</body>');return;}
 if(url.pathname==='/game/monopoly-classic/'){res.writeHead(200,{'Content-Type':'text/html'});res.end(html);return;}
 if(url.pathname==='/game/_Template/'){res.writeHead(200,{'Content-Type':'text/html'});res.end(templateHtml);return;}
 if(url.pathname.endsWith('/background.json')){res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({image:'/game/monopoly-classic/art/table.svg',videos:[]}));return;}
 let relative=url.pathname.startsWith('/game/')?'Games/'+url.pathname.slice(6):url.pathname.startsWith('/ui/')?url.pathname.slice(1):'web/'+url.pathname.slice(1);
 if(/^Games\/monopoly-classic\/(style.css|controller.js)$/.test(relative))relative=relative.replace('monopoly-classic/','monopoly-classic/controller/');
 if(/^Games\/_Template\/(style.css|controller.js)$/.test(relative))relative=relative.replace('_Template/','_Template/controller/');
 const file=resolve(root,relative);if(!file.startsWith(root+sep))throw Error('Unsafe path');
 const body=await readFile(file);res.writeHead(200,{'Content-Type':types[extname(file)]||'application/octet-stream'});res.end(body);
}catch{res.writeHead(404);res.end();}});
const wait=ms=>new Promise(r=>setTimeout(r,ms));
async function protocol(url){
 const socket=new WebSocket(url),requests=new Map();let sequence=0;
 socket.addEventListener('message',event=>{const response=JSON.parse(event.data),pending=requests.get(response.id);if(pending){requests.delete(response.id);response.error?pending.reject(Error(JSON.stringify(response.error))):pending.resolve(response.result);}});
 await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
 return{socket,send(method,params={}){return new Promise((resolve,reject)=>{const id=++sequence,timer=setTimeout(()=>reject(Error('Browser timeout: '+method)),5000);requests.set(id,{resolve:value=>{clearTimeout(timer);resolve(value);},reject:error=>{clearTimeout(timer);reject(error);}});socket.send(JSON.stringify({id,method,params}));});}};
}
await mkdir(output,{recursive:true});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const child=spawn(chrome,['--headless','--no-sandbox','--disable-gpu','--no-first-run','--disable-background-networking','--remote-debugging-port=0',`--user-data-dir=${join(output,'profile-'+process.pid)}`],{windowsHide:true,stdio:['ignore','ignore','pipe']});
let browser,failed=false;
try{
 const endpoint=await new Promise((resolve,reject)=>{child.on('error',reject);child.stderr.on('data',data=>{const match=String(data).match(/DevTools listening on (ws:\/\/[^\s]+)/);if(match)resolve(match[1]);});});
 browser=await protocol(endpoint);
 const target=await browser.send('Target.createTarget',{url:'about:blank'}),tabs=await(await fetch(`http://127.0.0.1:${new URL(endpoint).port}/json/list`)).json();
 const page=await protocol(tabs.find(tab=>tab.id===target.targetId).webSocketDebuggerUrl);await page.send('Page.enable');await page.send('Runtime.enable');
 for(const [label,width,height,reduced]of[['portrait',390,844,false],['small',360,640,false],['landscape',844,390,false],['tablet',768,1024,false],['desktop',1440,900,false],['reduced',390,844,true]]){
  await page.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
  await page.send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:reduced?'reduce':'no-preference'}]});
  await page.send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/game/monopoly-classic/?view=${label}`});
  let result;
  for(let attempt=0;attempt<400;attempt++){
   await wait(40);
   const capture=(await page.send('Runtime.evaluate',{expression:'window.qaCapture',returnByValue:true})).result.value;
   if(capture){const picture=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});await writeFile(join(output,label+'-'+capture+'.png'),Buffer.from(picture.data,'base64'));await page.send('Runtime.evaluate',{expression:'window.qaCapture=null'});}
   result=(await page.send('Runtime.evaluate',{expression:'window.qaResult',returnByValue:true})).result.value;if(result)break;
  }
  if(!result){const status=(await page.send('Runtime.evaluate',{expression:'JSON.stringify({progress:window.qaProgress,status:document.getElementById("status")?.textContent})',returnByValue:true})).result.value;throw Error(label+' timed out: '+status);}
  console.log(label+': '+JSON.stringify(result));failed ||= result.failures>0;
 }
 for(const [label,width,height,reduced]of[['portrait',390,844,false],['landscape',844,390,true]]){
  await page.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
  await page.send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:reduced?'reduce':'no-preference'}]});
  await page.send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/game/_Template/`});await wait(250);
  const template=(await page.send('Runtime.evaluate',{expression:`(() => {
    const connected=document.getElementById('connection').textContent.includes('Connected as');
    qaHandlers.disconnected();const disconnected=document.getElementById('connection').textContent.includes('Reconnecting');
    qaHandlers.connected(qaState.players[0]);qaHandlers.message(structuredClone(qaState));
    return {connected,disconnected,reconnected:qaSent.some(input=>input.action==='sync'),money:document.querySelectorAll('.game-money-effect').length===1,empty:!document.querySelector('.game-money-effect').children.length,fits:document.documentElement.scrollWidth<=innerWidth+1};
  })()`,returnByValue:true})).result.value;
  if(!template||!Object.values(template).every(Boolean))throw Error('Template '+label+': '+JSON.stringify(template));
  const picture=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});await writeFile(join(output,'template-'+label+'.png'),Buffer.from(picture.data,'base64'));
  console.log('Template '+label+': 6 checks, 0 failures');
 }
 let routeChecks=0;
 for(const [type,to,expected]of[['screen','qa-source','/sdk-probe'],['screen','qa-target','/game/qa-target/'],['screen','','/'],['joined','qa-target','/game/qa-target/'],['joined','','/']]){
  await page.send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/sdk-probe?type=${type}&to=${to}`});
  await wait(160);
  const actual=(await page.send('Runtime.evaluate',{expression:'location.pathname',returnByValue:true})).result.value;
  if(actual!==expected)throw Error('SDK '+type+' route '+to+': '+actual+' != '+expected);
  routeChecks++;
 }
 console.log('Shared SDK routing: '+routeChecks+' checks, 0 failures');
 page.socket.close();
}finally{if(browser){await browser.send('Browser.close').catch(()=>{});browser.socket.close();}else child.kill();server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
if(failed)process.exitCode=1;
