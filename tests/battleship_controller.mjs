// Isolated offline Chromium fixtures; run with Node 22+ and CHROME_BIN if needed.
import {createServer} from 'node:http';
import {readFile, mkdir, writeFile} from 'node:fs/promises';
import {resolve, join, extname, sep} from 'node:path';
import {spawn} from 'node:child_process';
const root=resolve(import.meta.dirname,'..'), output=join(root,'.test_data','battleship-controller');
const chrome=process.argv[2] || process.env.CHROME_BIN || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const fleet=[5,4,3,3,2].map((length,ship)=>({ship,length,cell:ship*20,vertical:false,cells:Array.from({length},(_,i)=>ship*20+i)}));
const initial={viewer:1,fleets:[[],[]],incoming:[Array(100).fill(0),Array(100).fill(0)],ready:[false,false],phase:'setup',turn:1,starter:1,outcome:0,revision:0,round_id:'1',round:1,session_wins:[0,0],remaining:[17,17],sunk:[0,0],last_shot:{},players:[{id:'phone',display_name:'Captain One',color:'#2463eb'},{id:'other',display_name:'Captain Two',color:'#e53935'}],paused:false,animating:false,reduced_motion:false,status:'Deploy your fleet: 0 of 5 ships placed.',history:'No completed games yet.'};
const boot=`
window.qaState=${JSON.stringify(initial)}; window.qaSent=[];
class StarGamesController extends window.StarGamesController {
  constructor(id,handlers) { super(id,handlers); window.qaHandlers=handlers; this.handlers=handlers; }
  connect() { this.handlers.connected(qaState.players[0]); this.handlers.message(structuredClone(qaState)); }
  send(input) { qaSent.push(input); }
}
window.StarGamesController=StarGamesController;
`;
const assertions=`
(async()=>{
 let checks=0; const check=(ok,message)=>{checks++;if(!ok)throw new Error(message);};
 const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
 const frames=()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
 const publish=patch=>{qaState={...qaState,...patch};qaHandlers.message(structuredClone(qaState));};
 const cells=[...document.querySelectorAll('#board .fleet-cell')], ownShips=${JSON.stringify(fleet)};
 const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
 const hold=async(cell,type='touch')=>{cells[cell].dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,pointerId:77,pointerType:type,button:0,isPrimary:true,clientX:20,clientY:20}));await pause(500);window.dispatchEvent(new PointerEvent('pointerup',{pointerId:77,pointerType:type}));cells[cell].click();};
 try {
  check(cells.length===100 && !cells[0].disabled,'Ten-by-ten deployment grid is available');
  await frames();
  check(document.querySelector('header').getBoundingClientRect().top<=20 && !document.querySelector('.game-note'),'Heading stays near the top without below-board instructions');
  const deployment=document.querySelector('#deployment'), controls=['ship-type','auto','clear','ready'].map(id=>document.getElementById(id));
  check(controls.every(control=>deployment.contains(control)) && !document.querySelector('#enemy-console button'),'All setup controls stay together on the player side');
  // Compare placement in the monitor's local plane, before its artwork rotation.
  const positions=controls.map(control=>({left:control.offsetLeft,right:control.offsetLeft+control.offsetWidth,top:control.offsetTop,bottom:control.offsetTop+control.offsetHeight}));
  check(positions[0].bottom<=positions[1].top && positions[1].bottom<=positions[2].top && positions[2].top===positions[3].top && document.querySelector('#ready').textContent==='READY','Setup order is ship selection, Auto Place, then Clear and READY side by side');
  if(document.querySelector('#fleet-consoles').classList.contains('is-docked')) {
   const pane=document.querySelector('#own-console');
   check(positions.every(rect=>rect.left>=0 && rect.right<=pane.clientWidth && rect.top>=0 && rect.bottom+2<=pane.clientHeight),'Tilted controls and their shadows fit inside the player monitor');
   check(Math.abs(new DOMMatrix(getComputedStyle(pane).transform).b)<.001,'Deployment controls remain upright inside the monitor');
  }
  const beforeInvalid=qaSent.length;cells[98].click();check(qaSent.length===beforeInvalid,'Invalid edge placement never sends a request');
  cells[0].click();check(qaSent.at(-1).action==='place' && qaSent.at(-1).ship===0 && qaSent.at(-1).cell===0 && qaSent.at(-1).revision===0,'Placement includes ship, start, orientation and revision');
  publish({fleets:[[ownShips[0]],[]],revision:1});
  check(document.querySelector('#ship-type').value==='1','Accepted placement selects the next unplaced ship');
  check(document.querySelectorAll('#board .ship-placement').length===1,'Host placement renders one ship');
  const art=document.querySelector('#board .ship-art'), animation=art.getAnimations()[0];
  publish({revision:1});check(!animation || art.getAnimations()[0]===animation,'Duplicate snapshots preserve ship animation');
  const beforeHold=qaSent.length;await hold(9);check(qaSent.length===beforeHold && document.querySelectorAll('#board .ship-placement').length===1 && document.querySelector('#ship-type').value==='1' && cells[39].classList.contains('placement-ghost'),'Touch hold rotates only the preview, without placing or advancing selection');
  cells[9].click();check(qaSent.length===beforeHold+1 && qaSent.at(-1).action==='place' && qaSent.at(-1).vertical && qaSent.at(-1).cell===9,'A separate tap places the rotated preview');
  const upright={ship:1,length:4,cell:9,vertical:true,cells:[9,19,29,39]};publish({fleets:[[ownShips[0],upright],[]],revision:2});
  await hold(2,'mouse');check(qaSent.at(-1).action==='rotate' && qaSent.at(-1).cell===2 && !('ship' in qaSent.at(-1)),'Mouse hold requests only rotation of the existing ship');
  publish({fleets:[[{...ownShips[0],vertical:true,cells:[0,10,20,30,40]},upright],[]],revision:2});
  check(document.querySelector('#ship-type').value==='0' && document.querySelectorAll('#board .ship-placement').length===2,'Existing-ship rotation keeps the same ship selected without adding a ship');
  const beforeBadHold=qaSent.length;await hold(19);check(qaSent.length===beforeBadHold,'An invalid held rotation preserves its ship and sends nothing');
  cells[50].dispatchEvent(new PointerEvent('pointerdown',{pointerId:78,pointerType:'touch',button:0,isPrimary:true}));window.dispatchEvent(new PointerEvent('pointercancel',{pointerId:78}));await pause(500);cells[50].click();check(qaSent.length===beforeBadHold,'Cancelled touch cannot queue a placement');
  check(!document.querySelector('#rotate') && ![...document.querySelectorAll('summary')].some(node=>node.textContent==='HOW TO PLAY'),'Direction toggle and How to Play are removed');
  publish({fleets:[ownShips,[]],revision:2});
  document.querySelector('#ready').click();check(qaSent.at(-1).action==='ready','READY is host validated');
  publish({phase:'battle',ready:[true,true],revision:3,status:"Captain One's turn."});await frames();
  check(document.querySelector('#deployment').hidden && document.querySelector('#board').classList.contains('enemy-fleet'),'Battle restores enemy targeting');
  check(document.querySelectorAll('#board .ship-placement').length===0 && document.querySelectorAll('#home-board .ship-placement').length===5,'Unsunk opponent ships never enter the target DOM');
  check(document.querySelectorAll('#own-ships li').length===5 && document.querySelectorAll('#enemy-ships li').length===5 && !document.querySelector('#enemy-ships .damaged'),'Both monitors show five ships without leaking enemy damage');
  const monitors=['own','enemy'].map(prefix=>document.getElementById(prefix+'-console'));
  check(monitors[0].clientWidth===monitors[1].clientWidth && monitors[0].clientHeight===monitors[1].clientHeight && Math.abs(parseFloat(getComputedStyle(monitors[0].querySelector('h2')).fontSize)-parseFloat(getComputedStyle(monitors[1].querySelector('h2')).fontSize))<.01,'Both fleet displays use identical dimensions and heading sizes');
  if(document.querySelector('#fleet-consoles').classList.contains('is-docked'))check(monitors.every(pane=>Math.abs(new DOMMatrix(getComputedStyle(pane).transform).b)<.001),'Both fleet monitors remain upright');
  // Undo the monitor's rotation before comparing its inset rows and columns.
  for(const pane of monitors) {
   const localRect=element=>{
    const rect=element.getBoundingClientRect(), frame=pane.getBoundingClientRect();
    const inverse=new DOMMatrix(getComputedStyle(pane).transform).inverse();
    const center=new DOMPoint(rect.x+rect.width/2-frame.x-frame.width/2,rect.y+rect.height/2-frame.y-frame.height/2).matrixTransform(inverse);
    return {x:center.x+pane.clientWidth/2-element.offsetWidth/2,y:center.y+pane.clientHeight/2-element.offsetHeight/2,width:element.offsetWidth,height:element.offsetHeight};
   };
   const status=pane.querySelector('[id$="-fleet-status"]'), bounds=localRect(status);
   check(bounds.x>=-1 && bounds.y>=-1 && bounds.x+bounds.width<=pane.clientWidth+1 && bounds.y+bounds.height<=pane.clientHeight+1,'Fleet status stays inside its monitor');
   if(!document.querySelector('#fleet-consoles').classList.contains('is-docked'))check(Math.abs(pane.getBoundingClientRect().width/pane.getBoundingClientRect().height-240/180)<.01,'Standalone monitor follows its frame aspect ratio without letterboxing');
   const fits=rect=>rect.x>=bounds.x-1 && rect.y>=bounds.y-1 && rect.x+rect.width<=bounds.x+bounds.width+1 && rect.y+rect.height<=bounds.y+bounds.height+1;
   const rows=[...pane.querySelectorAll('li')].map(row=>({ship:localRect(row.querySelector('img')),name:localRect(row.querySelector('.fleet-name')),lamp:localRect(row.querySelector('.fleet-lamp'))}));
   check(fits(localRect(status.querySelector('h2'))) && rows.every(row=>fits(row.ship) && fits(row.name) && fits(row.lamp)),'Every heading, ship and lamp stays inside the fleet monitor inset: '+JSON.stringify({bounds,heading:localRect(status.querySelector('h2')),rows}));
   check(rows.every(row=>Math.abs(row.ship.y+row.ship.height/2-row.lamp.y-row.lamp.height/2)<1 && Math.abs(row.ship.x-rows[0].ship.x)<1 && Math.abs(row.lamp.x+row.lamp.width/2-rows[0].lamp.x-rows[0].lamp.width/2)<1),'Ships and lamps share row centers and consistent columns');
   const images=[...pane.querySelectorAll('li img')];
   check(new Set(images.map(image=>image.getAttribute('src'))).size===5 && rows[0].ship.width>rows[1].ship.width && rows[1].ship.width>rows[2].ship.width && Math.abs(rows[2].ship.width-rows[3].ship.width)<1 && rows[3].ship.width>rows[4].ship.width,'Five distinct ship profiles retain the 5/4/3/3/2 size order');
  }
  check(!document.querySelector('.game-details,#history,#own-score,#enemy-score') && ![...document.querySelectorAll('summary')].some(node=>/session|history/i.test(node.textContent)),'Session and History controls are host only');
  const buttonColor=getComputedStyle(document.querySelector('#show-enemy')).color;
  check(document.body.classList.contains('game-naval') && document.body.classList.contains('game-admiral') && buttonColor==='rgb(244, 234, 213)' && getComputedStyle(document.querySelector('#ship-type')).backgroundColor==='rgb(16, 46, 62)','Buttons and selectors inherit the shared admiral palette');
  const casing=document.querySelector('#board').getBoundingClientRect(), water=document.querySelector('#board .fleet-cells').getBoundingClientRect(), square=cells[0].getBoundingClientRect();
  check(getComputedStyle(document.querySelector('#home-board .fleet-cell')).backgroundColor==='rgba(0, 0, 0, 0)','Disabled own-fleet cells preserve the water and private ship artwork');
  check(casing.bottom-water.bottom>=casing.width*.08 && Math.abs(square.width-square.height)<.1,'The enlarged casing contains a square grid with bottom clearance');
  const scale=casing.width/424, safe={left:casing.left+24*scale,right:casing.left+400*scale,top:casing.top+64*scale,bottom:casing.top+434*scale};
  check([...document.querySelectorAll('#board .fleet-coordinates span')].every(span=>{const rect=span.getBoundingClientRect();return rect.left>=safe.left && rect.right<=safe.right && rect.top>=safe.top && rect.bottom<=safe.bottom;}),'All letters and numbers fit inside the inner casing');
  cells[55].click();check(qaSent.at(-1).action==='fire' && qaSent.at(-1).cell===55 && qaSent.at(-1).revision===3,'Firing sends only a target and revision');
  const outgoing=Array(100).fill(0);outgoing[55]=1;
  publish({incoming:[Array(100).fill(0),outgoing],turn:2,last_shot:{id:4,seat:1,cell:55,result:1,ship:-1},revision:4,animating:true,status:'CANNON FIRE!'});
  check(cells.every(cell=>cell.disabled),'Host movement flag blocks all targeting');
  check(document.querySelector('#board').getAttribute('aria-busy')===(reduced?'false':'true'),'Local shell effect honors reduced motion');
  const shotRequests=qaSent.length;cells[56].click();check(qaSent.length===shotRequests,'Taps during shell flight are discarded');
  publish({animating:false,turn:1});check(reduced || cells.every(cell=>cell.disabled),'Local effect lock survives an early host unlock');
  publish({animating:false,turn:1});
  await pause(1350);check(!cells[56].disabled && cells[55].disabled,'Settled effects re-enable only untried targets');
  outgoing[67]=2;publish({incoming:[Array(100).fill(0),outgoing],last_shot:{id:5,seat:1,cell:67,result:2,ship:-1},revision:5,animating:true});
  await pause(600);check(cells[67].querySelector('img')?.src.endsWith('hit.svg') && !cells[67].classList.contains('pending-impact'),'Hit appears at impact');
  publish({animating:false});await pause(750);
  outgoing[77]=3;outgoing[78]=3;const wreck={ship:4,length:2,cell:77,vertical:false,cells:[77,78]};
  publish({incoming:[Array(100).fill(0),outgoing],fleets:[ownShips,[wreck]],sunk:[0,1],remaining:[17,14],last_shot:{id:6,seat:1,cell:77,result:3,ship:4},revision:6,animating:true});
  await pause(1350);publish({animating:false});check(document.querySelectorAll('#board .wreck').length===1 && cells[77].classList.contains('is-sunk'),'Sinking reveals only a public wreck and gold marker');
  check(document.querySelectorAll('#enemy-ships .sunk').length===1 && document.querySelector('#enemy-ships li:last-child').getAttribute('aria-label').includes('sunk'),'A public wreck switches the matching fleet lamp off');
  const incoming=Array(100).fill(0);incoming[60]=2;publish({incoming:[incoming,outgoing],last_shot:{id:7,seat:2,cell:60,result:2,ship:-1},revision:7,animating:true,turn:1});
  const single=matchMedia('(max-width: 680px), (max-height: 560px)').matches;
  check(!single || !document.querySelector('#board').classList.contains('enemy-fleet'),'Small screens follow incoming fire onto the player fleet');
  publish({animating:false});await pause(1350);check(document.querySelector('#board').classList.contains('enemy-fleet') && !cells[56].disabled,'Settling returns to enemy targeting for the next shot');
  qaHandlers.disconnected();check(cells.every(cell=>cell.disabled) && document.querySelector('#connection').textContent.includes('Reconnecting'),'Connection loss disables local input');
  qaHandlers.connected(qaState.players[0]);qaHandlers.message(structuredClone(qaState));
  check(document.querySelector('#board').getAttribute('aria-busy')==='false' && document.querySelectorAll('#home-board .ship-placement').length===5,'Reconnect restores settled ships without replaying effects');
  const board=document.querySelector('#board').getBoundingClientRect();
  check(document.documentElement.scrollWidth<=innerWidth,'No horizontal overflow');
  check(board.left>=0 && board.right<=innerWidth && board.bottom<=innerHeight,'Entire targeting board fits the viewport');
  publish({phase:'finished',outcome:1,session_wins:[1,0],revision:7,status:'FLEET SUNK! Captain One wins.'});await frames();
  const replay=document.querySelector('#replay').getBoundingClientRect();
  check(!document.querySelector('#replay').hidden && replay.bottom<=innerHeight,'Single Play Again control stays reachable');
  check(Math.abs(document.querySelector('#board').getBoundingClientRect().top-board.top)<1,'Victory does not shift the board');
  document.querySelector('#replay').click();check(qaSent.at(-1).action==='play_again','Replay requests the host action');
  publish({phase:'setup',outcome:0,round_id:'2',round:2,starter:2,fleets:[[],[]],incoming:[Array(100).fill(0),Array(100).fill(0)],ready:[false,false],last_shot:{},revision:8});
  check(document.querySelectorAll('#board .ship-placement').length===0 && !document.querySelector('#deployment').hidden && !document.querySelector('#auto').disabled,'Replay clears ships and restores deployment controls');
  // A second captain uses authoritative seat indexes while seeing the same UI.
  qaHandlers.connected(qaState.players[1]);publish({viewer:2,fleets:[[],ownShips],revision:9});
  check(document.querySelectorAll('#board .ship-placement').length===5 && document.querySelector('#connection').textContent==='Connected as Captain Two','Seat two receives its own fleet and identity');
  check(!document.querySelector('button[title], [title]'),'Controls have no hover text');
  publish({phase:'battle',ready:[true,true],turn:2,revision:10,status:"Captain Two's turn.",incoming:[outgoing,Array(100).fill(0)],fleets:[[wreck],ownShips],sunk:[1,0],remaining:[14,17]});await frames();
  window.qaResult={checks,failures:0};
 } catch(error) {window.qaResult={checks,failures:1,error:String(error)};}
})();`;
let html=await readFile(join(root,'Games/battleship/controller/index.html'),'utf8');
html=html.replace('<script src="/controller-sdk.js"></script>',`<script src="/controller-sdk.js"></script><script>${boot}</script>`).replace('</body>',`<script>${assertions}</script></body>`);
const types={'.css':'text/css','.js':'application/javascript','.svg':'image/svg+xml','.png':'image/png'};
const server=createServer(async(request,response)=>{
 try {
  const url=new URL(request.url,'http://127.0.0.1');
  if(url.pathname==='/game/battleship/') {response.writeHead(200,{'Content-Type':'text/html'});response.end(html);return;}
  if(url.pathname==='/game/battleship/background.json') {response.writeHead(200,{'Content-Type':'application/json'});response.end(JSON.stringify({image:'/game/battleship/art/command-bridge.png',videos:[]}));return;}
  let name=url.pathname.startsWith('/game/')?'Games/'+url.pathname.slice(6):url.pathname.startsWith('/ui/')?url.pathname.slice(1):'web/'+url.pathname.slice(1);
  if(/^Games\/battleship\/(style.css|controller.js)$/.test(name))name=name.replace('battleship/','battleship/controller/');
  const file=resolve(root,name);if(!file.startsWith(root+sep))throw Error('Unsafe fixture path');
  const body=await readFile(file);response.writeHead(200,{'Content-Type':types[extname(file)]||'application/octet-stream'});response.end(body);
 }catch {response.writeHead(404);response.end();}
});
async function protocol(url){
 const socket=new WebSocket(url),requests=new Map();let id=0;
 socket.addEventListener('message',event=>{const message=JSON.parse(event.data),request=requests.get(message.id);if(request){requests.delete(message.id);message.error?request.reject(Error(JSON.stringify(message.error))):request.resolve(message.result);}});
 await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
 return {socket,send(method,params={}){return new Promise((resolve,reject)=>{const requestId=++id;const timer=setTimeout(()=>{requests.delete(requestId);reject(Error('Chromium timeout: '+method));},5000);requests.set(requestId,{resolve:value=>{clearTimeout(timer);resolve(value);},reject:error=>{clearTimeout(timer);reject(error);}});socket.send(JSON.stringify({id:requestId,method,params}));});}};
}
await mkdir(output,{recursive:true});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const child=spawn(chrome,['--headless','--no-sandbox','--disable-gpu','--no-first-run','--disable-background-networking','--remote-debugging-port=0',`--user-data-dir=${join(output,'chrome-profile-'+process.pid)}`],{windowsHide:true,stdio:['ignore','ignore','pipe']});
let browser, failed=false, startup;
try {
 const endpoint=await Promise.race([new Promise((resolve,reject)=>{child.on('error',reject);child.stderr.on('data',chunk=>{const match=String(chunk).match(/DevTools listening on (ws:\/\/[^\s]+)/);if(match)resolve(match[1]);});}),new Promise((_,reject)=>{startup=setTimeout(()=>reject(Error('Chromium did not start')),15000);})]);
 clearTimeout(startup);console.log('Chromium renderer ready');browser=await protocol(endpoint);
 const target=await browser.send('Target.createTarget',{url:'about:blank'}),tabs=await(await fetch(`http://127.0.0.1:${new URL(endpoint).port}/json/list`)).json();
 const page=await protocol(tabs.find(tab=>tab.id===target.targetId).webSocketDebuggerUrl);await page.send('Page.enable');
 for(const [name,width,height,reduced] of [['portrait',390,844,false],['landscape',844,390,false],['tablet',768,1024,false],['desktop',1440,900,false],['wide',1600,900,false],['hd',1280,720,false],['reduced',390,844,true],['small',360,640,false]]) {
  await page.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
  await page.send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:reduced?'reduce':'no-preference'}]});
  await page.send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/game/battleship/?fixture=${name}`});
  let result;
  for(let attempt=0;attempt<160;attempt++){await wait(50);const value=await page.send('Runtime.evaluate',{expression:'window.qaResult',returnByValue:true});if(value.result.value){result=value.result.value;break;}}
  if(!result) { const errors=await page.send('Runtime.evaluate',{expression:'document.body.innerText',returnByValue:true});throw Error(name+': assertions timed out '+errors.result.value); }
  console.log(name+': '+JSON.stringify(result));failed ||= result.failures>0;
  await wait(150);const screenshot=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});await writeFile(join(output,name+'.png'),Buffer.from(screenshot.data,'base64'));
  if(!result.failures){
   await page.send('Runtime.evaluate',{expression:"document.querySelector('#show-own').click()"});await wait(100);
   const own=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});await writeFile(join(output,name+'-own.png'),Buffer.from(own.data,'base64'));
   await page.send('Runtime.evaluate',{expression:"if(!document.querySelector('#fleet-consoles').classList.contains('is-docked'))document.querySelector('#fleet-consoles').scrollIntoView({block:'center'});"});await wait(100);
   const monitors=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});await writeFile(join(output,name+'-fleets.png'),Buffer.from(monitors.data,'base64'));
   await page.send('Runtime.evaluate',{expression:'scrollTo(0,0)'});
   await page.send('Runtime.evaluate',{expression:`qaHandlers.connected(qaState.players[0]);qaState={...qaState,viewer:1,phase:'setup',outcome:0,round_id:'3',ready:[false,false],fleets:[${JSON.stringify(fleet)},[]],incoming:[Array(100).fill(0),Array(100).fill(0)],last_shot:{},status:'Deploy your fleet: 5 of 5 ships placed.'};qaHandlers.message(structuredClone(qaState));`});await wait(150);
   const placement=await page.send('Runtime.evaluate',{expression:"({ready:document.getElementById('ready').getBoundingClientRect().bottom<=innerHeight,board:document.getElementById('board').getBoundingClientRect().bottom<=innerHeight})",returnByValue:true});
   if(!placement.result.value.ready || !placement.result.value.board){failed=true;console.log(name+': deployment controls overflow '+JSON.stringify(placement.result.value));}
   const setup=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});await writeFile(join(output,name+'-setup.png'),Buffer.from(setup.data,'base64'));
   if(['wide','hd'].includes(name)) {
    const point=await page.send('Runtime.evaluate',{expression:"(()=>{const r=document.querySelector('#auto').getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};})()",returnByValue:true});
    await page.send('Input.dispatchMouseEvent',{type:'mousePressed',...point.result.value,button:'left',clickCount:1});
    await page.send('Input.dispatchMouseEvent',{type:'mouseReleased',...point.result.value,button:'left',clickCount:1});
    const clicked=await page.send('Runtime.evaluate',{expression:"qaSent.at(-1)?.action==='auto'",returnByValue:true});
    console.log(name+': tilted Auto Place click '+clicked.result.value);failed ||= !clicked.result.value;
   }
  }
 }
 // Real Chromium touch/mouse events verify the held gesture beyond synthetic fixtures.
 await page.send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});
 await page.send('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:5});
 const resetTouch=async()=>{await page.send('Runtime.evaluate',{expression:`qaHandlers.connected(qaState.players[0]);qaState=${JSON.stringify(initial)};qaState.round_id='touch';qaHandlers.message(structuredClone(qaState));qaSent=[];scrollTo(0,0);`});await wait(150);};
 const cellPoint=async cell=>{const rect=await page.send('Runtime.evaluate',{expression:`(()=>{const r=document.querySelectorAll('#board .fleet-cell')[${cell}].getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};})()`,returnByValue:true});return rect.result.value;};
 await resetTouch();let point=await cellPoint(9);
 await page.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...point,id:1}]});await wait(600);
 await page.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await wait(100);
 let real=await page.send('Runtime.evaluate',{expression:"qaSent.length===0 && document.querySelectorAll('#board .placement-ghost').length===5 && document.querySelectorAll('#board .ship-placement').length===0",returnByValue:true});
 console.log('Real touch hold: '+real.result.value);failed ||= !real.result.value;
 await resetTouch();point=await cellPoint(0);
 await page.send('Input.dispatchMouseEvent',{type:'mousePressed',...point,button:'left',clickCount:1});await wait(600);
 await page.send('Input.dispatchMouseEvent',{type:'mouseReleased',...point,button:'left',clickCount:1});await wait(100);
 real=await page.send('Runtime.evaluate',{expression:"qaSent.length===0 && document.querySelectorAll('#board .placement-ghost').length===5 && document.querySelectorAll('#board .ship-placement').length===0",returnByValue:true});
 console.log('Real mouse hold: '+real.result.value);failed ||= !real.result.value;
 await page.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...point,id:3}]});await wait(80);
 await page.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await wait(100);
 real=await page.send('Runtime.evaluate',{expression:"qaSent.length===1 && qaSent[0].action==='place' && qaSent[0].cell===0 && qaSent[0].vertical",returnByValue:true});
 console.log('Separate tap deploys rotated preview: '+real.result.value);failed ||= !real.result.value;
 await resetTouch();point=await cellPoint(50);
 await page.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...point,id:2}]});await wait(100);
 await page.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:point.x,y:point.y+60,id:2}]});await wait(600);
 await page.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await wait(100);
 real=await page.send('Runtime.evaluate',{expression:'qaSent.length===0',returnByValue:true});
 console.log('Real touch scroll cancellation: '+real.result.value);failed ||= !real.result.value;
 page.socket.close();
} finally {clearTimeout(startup);if(browser){await browser.send('Browser.close').catch(()=>{});browser.socket.close();}else child.kill();await new Promise(resolve=>server.close(resolve));}
if(failed)process.exitCode=1;
