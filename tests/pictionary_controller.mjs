import {createServer} from 'node:http';
import {readFile, mkdir, writeFile} from 'node:fs/promises';
import {resolve, join, extname, sep} from 'node:path';
import {spawn} from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const output = join(root, '.test_data', 'pictionary-controller');
const chrome = process.argv[2] || process.env.CHROME_BIN || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const players = ['Jane','Alex','Sam','Riley'].map((display_name,seat) => ({id:'p'+seat, display_name, color:['#e43c45','#398552','#efbd23','#286ac2'][seat]}));
const paths = [[[200,470],[810,470],[710,590],[300,590],[200,470]],[[490,90],[490,470]],[[460,130],[230,420],[460,420],[460,130]],[[530,150],[750,420],[530,420],[530,150]],[[100,660],[170,635],[240,660],[310,635],[380,660],[450,635],[520,660],[590,635],[660,660],[730,635],[800,660],[870,635]]];
const initial = {kind:'state',viewer:0,players,phase:'drawing',revision:2,match:1,turn_id:1,turn:1,total_turns:4,drawer:0,remaining:42,paused:false,missing:[],options:{seconds:60,laps:1,category:'mixed',difficulty:'mixed',hints:'length'},scores:[275,350,200,150],session_wins:[0,0,0,0],guessed:[1],feed:[{seat:1,correct:true,quality:'correct',seconds:8.4,rank:1,points:100,text:''},{seat:2,correct:false,quality:'close',seconds:12.5,rank:0,points:0,text:'sailbaot'},{seat:3,correct:false,quality:'wrong',seconds:15.3,rank:0,points:0,text:'ship'}],guess_results:[],hint:'_ _ _ _ _ _ _ _',epoch:1,drawing_version:5,drawing_limit:false,outcome:{},secret:'sailboat',strokes:paths.map((points,index) => ({id:'demo'+index,sequence:0,color:0,width:1,points,end:true})),sound_sequence:0};
const boot = `window.qaState=${JSON.stringify(initial)};window.qaSent=[];window.qaPlayed=[];window.qaPaused=[];window.qaErrors=[];window.addEventListener('error',event=>qaErrors.push(event.message));
HTMLMediaElement.prototype.play=function(){qaPlayed.push(new URL(this.src).pathname);return Promise.resolve();};
const pauseAudio=HTMLMediaElement.prototype.pause;HTMLMediaElement.prototype.pause=function(){qaPaused.push(new URL(this.src).pathname);return pauseAudio.call(this);};
class FixtureController extends window.StarGamesController {
 constructor(id,handlers){super(id,handlers);window.qaHandlers=handlers;this.handlers=handlers;}
 connect(){document.documentElement.style.setProperty('--player-color',qaState.players[qaState.viewer].color);this.handlers.connected(qaState.players[qaState.viewer]);this.handlers.message(structuredClone(qaState));}
 send(input){qaSent.push(input);if(input.action==='sync')this.handlers.message(structuredClone(qaState));}
}
window.StarGamesController=FixtureController;`;
const assertions = `(async()=>{
 const $=id=>document.getElementById(id),wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
 let checks=0;const check=(ok,message)=>{checks++;if(!ok)throw Error(message);};
 const publish=patch=>{qaState={...qaState,...patch};qaHandlers.message(structuredClone(qaState));};
 const capture=async name=>{window.qaCapture=name;while(window.qaCapture)await wait(25);};
 try {
  await wait(300);
  check(!document.querySelector('[title]'),'No hover popups');
  check($('secret').textContent==='sailboat'&&!$('private-card').hidden&&!$('drawing-controls').hidden&&$('guess-form').hidden,'Drawer receives a private word and drawing tools');
  check($('hint').textContent===''&&!$('score')&&!$('feedback').textContent,'Drawer canvas has no duplicate word, guessed count or points');
  check(document.querySelectorAll('[data-color]').length===7&&document.querySelector('[aria-label="Brown ink"]')&&document.querySelector('[aria-label="Purple ink"]'),'Palette includes brown and purple');
  check(document.querySelectorAll('.game-brush-size').length===2&&$('brush-size').dataset.size==='medium'&&$('eraser').dataset.size==='medium'&&$('brush-size').textContent.includes('Brush')&&$('eraser').textContent.includes('Eraser'),'Two labelled dot buttons retain Brush and Eraser text');
  check(!$('player-name')&&!document.querySelector('.game-identity-strip'),'The bottom player status strip is removed');
  check([...document.images].every(image=>image.complete&&image.naturalWidth>0),'Offline title artwork loads');
  check(!document.querySelector('details')&&$('replay').hidden,'Host options and replay are absent on phones');
  check(document.documentElement.scrollWidth<=innerWidth+1,'Phone layout has no horizontal overflow');
  await capture('drawer');
  const board=$('board').getBoundingClientRect(),controls=document.querySelector('.game-board-controls').getBoundingClientRect();
  const paper=$('drawing').getBoundingClientRect();
  if(innerWidth<=390&&innerHeight>=640)check(paper.width>=innerWidth*.85&&paper.height>=innerWidth*.7,'Portrait phones give the actual drawing canvas most of the width and a taller square surface');
  check(innerHeight<520 ? controls.left>=$('drawing').getBoundingClientRect().right : controls.top>=$('drawing').getBoundingClientRect().bottom+8,'Tools stay outside the drawing surface');
  document.querySelector('[data-color="5"]').click();
  check(document.querySelector('[data-color="5"]').getAttribute('aria-pressed')==='true','Brown ink can be selected');
  document.querySelector('[data-color="6"]').click();$('brush-size').click();
  check(document.querySelector('[data-color="6"]').getAttribute('aria-pressed')==='true'&&$('brush-size').dataset.size==='large'&&$('brush-size').getAttribute('aria-label').includes('Large'),'Purple ink and the large dot can be selected');
  $('brush-size').click();check($('brush-size').dataset.size==='small','Large cycles to small');
  $('brush-size').click();check($('brush-size').dataset.size==='medium','Small cycles to medium');
  $('brush-size').click();
  window.qaPointerProbe=$('drawing').getBoundingClientRect().toJSON();
  while(window.qaPointerProbe)await wait(25);
  const chunks=qaSent.filter(packet=>packet.action==='ink');
  check(chunks.length>=2&&chunks[0].sequence===0&&chunks.at(-1).end,'Real pointer press streams and completes a stroke');
  check(chunks.every(packet=>packet.epoch===1&&packet.turn_id===1&&packet.points.length<=32),'Stroke chunks carry bounded points and turn/epoch guards');
  check(chunks.every(packet=>packet.color===6&&packet.width===2),'Selected purple ink and large brush reach the host');
  check(chunks.flatMap(packet=>packet.points).every(point=>point[0]>=0&&point[0]<=1000&&point[1]>=0&&point[1]<=700),'Pointer coordinates normalize to the authoritative canvas');
  let localVersion=5;
  for(const packet of chunks)qaHandlers.message({...packet,kind:'ink',version:++localVersion});
  $('eraser').click();
  check($('eraser').getAttribute('aria-pressed')==='true'&&$('brush-size').getAttribute('aria-pressed')==='false'&&$('eraser').dataset.size==='medium','Eraser activates at its retained size');
  $('eraser').click();
  check($('eraser').dataset.size==='large'&&$('eraser').querySelector('.game-brush-dot').style.getPropertyValue('--brush-dot-size')==='18px','Active eraser cycles the hollow circle size');
  const brushCount=qaSent.filter(packet=>packet.action==='ink').length;
  window.qaPointerProbe=$('drawing').getBoundingClientRect().toJSON();
  while(window.qaPointerProbe)await wait(25);
  const erased=qaSent.filter(packet=>packet.action==='ink').slice(brushCount);
  check(erased.length>=2&&erased.every(packet=>packet.color===7&&packet.width===2)&&erased.at(-1).end,'Real eraser strokes send the selected eraser size to the host');
  for(const packet of erased)qaHandlers.message({...packet,kind:'ink',version:++localVersion});
  $('eraser').click();check($('eraser').dataset.size==='small','Eraser large cycles to small');
  $('eraser').click();check($('eraser').dataset.size==='medium','Eraser small cycles to medium');
  $('brush-size').click();
  check($('brush-size').dataset.size==='large'&&$('brush-size').getAttribute('aria-pressed')==='true'&&document.querySelector('[data-color="6"]').getAttribute('aria-pressed')==='true','Returning to Brush preserves its independent size and purple ink');
  await capture('tools');
  qaHandlers.message({kind:'clock',turn_id:1,revision:2,phase:'drawing',remaining:10,paused:false,hint:qaState.hint});
  check($('timer').classList.contains('game-danger-text')&&$('timer').classList.contains('game-countdown-blink'),'Final ten drawing seconds enable a blinking red timer');
  const animation=getComputedStyle($('timer')).animationName;
  check(matchMedia('(prefers-reduced-motion: reduce)').matches?animation==='none':animation==='game-countdown-blink','Reduced motion keeps the red clock static');
  publish({remaining:10,reduced_motion:true});check(getComputedStyle($('timer')).animationName==='none','The host reduced-motion preference also keeps the countdown static');
  publish({remaining:10,reduced_motion:false});
  const beforeSounds=qaPlayed.length;
  qaHandlers.message({kind:'sound',sound:'correct',sequence:1,turn_id:1});
  qaHandlers.message({kind:'sound',sound:'correct',sequence:1,turn_id:1});
  qaHandlers.message({kind:'sound',sound:'countdown',sequence:2,turn_id:1});
  qaHandlers.message({kind:'sound',sound:'countdown',sequence:2,turn_id:1});
  qaHandlers.message({kind:'sound',sound:'wrong',sequence:3,turn_id:1});
  qaHandlers.message({kind:'sound',sound:'correct',sequence:4,turn_id:0});
  check(qaPlayed.length===beforeSounds+2&&qaPlayed.at(-2).endsWith('/correct.wav')&&qaPlayed.at(-1).endsWith('/countdown.wav'),'Correct-guess and clock cues play once; host-only wrong cues, duplicates and stale turns stay silent');
  await capture('countdown');
  const boardBefore=$('board').getBoundingClientRect().toJSON();
  qaHandlers.message({kind:'clock',turn_id:1,revision:2,phase:'drawing',remaining:40,paused:false,hint:qaState.hint});
  check($('drawing').getBoundingClientRect().width>0&&!$('undo').disabled,'Clock sync does not recreate or disable drawing targets');
  $('undo').click();check(qaSent.at(-1).action==='undo','Undo submits a host action');
  publish({epoch:2,drawing_version:6,strokes:structuredClone(initialStrokes)});
  $('clear').click();check(qaSent.at(-1).action==='clear','Clear submits a host action');
  publish({epoch:3,drawing_version:7,strokes:[],paused:true,missing:[2],revision:3});
  const beforePause=qaSent.length; $('clear').click();
  check($('undo').disabled&&qaSent.length===beforePause,'Pause rejects drawing tools locally');
  check(!$('timer').classList.contains('game-countdown-blink'),'Pause stops timer blinking');
  const pausedSounds=qaPlayed.length;qaHandlers.message({kind:'sound',sound:'countdown',sequence:5,turn_id:1});
  check(qaPlayed.length===pausedSounds,'Paused countdown packets stay silent');
  const time=$('timer').textContent;await wait(450);check($('timer').textContent===time,'Paused clocks freeze');
  await capture('paused');
  qaHandlers.disconnected();check($('secret').textContent===''&&$('private-card').hidden&&$('undo').disabled,'Disconnect conceals the word and disables drawing');
  qaHandlers.connected(qaState.players[0]);
  publish({...initialState,revision:4,epoch:4,drawing_version:5});
  check($('secret').textContent==='sailboat'&&!$('undo').disabled,'Reconnect snapshot restores private word and tools');
  publish({viewer:3,revision:5,secret:undefined,strokes:structuredClone(initialStrokes),scores:[275,350,200,150],guessed:[1]});
  check($('private-card').hidden&&$('secret').textContent===''&&$('drawing-controls').hidden&&!$('guess-form').hidden,'Guesser gets no private word or drawing tools');
  check($('hint').textContent==='_ _ _ _ _ _ _ _'&&!$('score'),'Guesser sees the hint without an individual points panel');
  $('guess-input').value='boat';$('guess-form').requestSubmit();
  check(qaSent.at(-1).action==='guess'&&qaSent.at(-1).guess==='boat','Guess submits input, never scores or profile IDs');
  const sent=qaSent.length;$('guess-input').value='sailboat';$('guess-form').requestSubmit();check(qaSent.length===sent,'Rapid repeat guesses stay blocked');
  publish({feed:[{seat:3,correct:false,quality:'wrong',seconds:15.3,points:0,text:'boat'}]});check($('feedback').textContent.includes('Try again')&&$('feedback').classList.contains('game-guess-wrong'),'Wrong guess feedback is red');
  publish({last_guess:{seat:3,correct:false,quality:'close',seconds:16.2,points:0,text:'sailbaot'}});
  check($('feedback').textContent.includes('Close')&&$('feedback').classList.contains('game-guess-close'),'Misspelled guesses have orange feedback');
  await capture('close-guess');
  await wait(1000);check(!$('guess-button').disabled,'Guessing becomes available after the cooldown');$('guess-input').value='';await capture('guesser');
  const guesserBoard=$('board').getBoundingClientRect();
  publish({guessed:[1,3],scores:[300,350,200,245],last_guess:{seat:3,correct:true,quality:'correct',seconds:18.7,points:95,rank:2,text:''},feed:[{seat:3,correct:true,quality:'correct',seconds:18.7,text:''}]});
  check($('guess-form').hidden&&$('feedback').textContent.includes('18.7s')&&$('feedback').classList.contains('game-guess-correct')&&!$('score'),'Correct guesses show green feedback and elapsed seconds without personal points');
  await capture('correct-guess');
  const successBoard=$('board').getBoundingClientRect(),successFeedback=$('feedback').getBoundingClientRect(),successControls=document.querySelector('.game-board-controls').getBoundingClientRect();
  check(Math.abs(successBoard.top-guesserBoard.top)<2&&Math.abs(successBoard.width-guesserBoard.width)<2,'A correct guess keeps the canvas in place');
  check(Math.abs(successFeedback.left+successFeedback.width/2-successControls.left-successControls.width/2)<2,'Correct-guess feedback is horizontally centered');
  if(innerHeight>=520)check(successFeedback.top-successBoard.bottom>=8&&successFeedback.top-successBoard.bottom<=24,'Correct-guess feedback stays close below the canvas after the form hides');
  const beforeRevealPauses=qaPaused.length;
  publish({phase:'reveal',revision:6,remaining:6,word:'sailboat',hint:'SAILBOAT',guess_results:[{seat:1,quality:'correct',correct:true,text:'sailboat',seconds:8.4},{seat:2,quality:'close',correct:false,text:'sailbaot',seconds:12.5},{seat:3,quality:'correct',correct:true,text:'Sail Boat',seconds:18.7}]});
  check(qaPaused.slice(beforeRevealPauses).every(path=>path.endsWith('/countdown.wav')),'Turn completion stops only the countdown without cutting off correct or time-up sounds');
  check($('guess-form').hidden&&$('hint').textContent==='SAILBOAT','Reveal shows the answer only after the turn ends');
  await wait(100);
  const reveal=$('board').getBoundingClientRect();
  check(Math.abs(reveal.width-guesserBoard.width)<2||innerHeight<520,'Reveal retains normal phone board fitting');
  check(!$('feedback').textContent,'Turn reveal hides last guesses even if a stale payload includes results');
  check(!$('timer').classList.contains('game-countdown-blink')&&!$('timer').classList.contains('game-danger-text'),'Turn reveal clears urgent clock feedback');
  const revealedSounds=qaPlayed.length;qaHandlers.message({kind:'sound',sound:'countdown',sequence:6,turn_id:1});
  check(qaPlayed.length===revealedSounds,'Late countdown packets cannot play after the turn ends');
  await capture('reveal');
  publish({phase:'choosing',turn_id:2,revision:7,viewer:0,drawer:0,secret:undefined,word:undefined,last_guess:undefined,guess_results:[],remaining:10,choices:['cat','pizza','sailboat'],strokes:[],epoch:5,hint:'',guessed:[],outcome:{}});
  const choice=$('word-choices').querySelector('button');
  check($('word-choices').children.length===3&&$('secret').textContent==='','Private selection exposes three choices without an old word');
  qaHandlers.message({kind:'clock',turn_id:2,revision:7,phase:'choosing',remaining:9,paused:false,hint:''});
  check(choice===$('word-choices').querySelector('button'),'Clock snapshots retain held choice buttons');
  choice.click();check(qaSent.at(-1).action==='choose'&&qaSent.at(-1).choice===0,'Choice sends one offered index');
  await capture('word-choice');
  publish({phase:'finished',revision:8,remaining:0,choices:undefined,outcome:{winners:[1],draw:false},scores:[275,350,200,250],guess_results:[{seat:0,quality:'wrong',correct:false,text:'<img src=x>',seconds:60}]});
  check($('board-message').textContent==='Alex wins!'&&$('replay').hidden,'Finished screen uses host-only replay');
  check($('feedback').textContent.includes('<img src=x>')&&!$('feedback').querySelector('img')&&$('feedback').classList.contains('game-guess-wrong'),'Match completion shows literal last guess text in its result color');
  check($('feedback').textContent.includes('60.0s'),'Unsuccessful final guess displays the full turn duration');
  publish({guess_results:[{seat:0,quality:'wrong',correct:false,text:'',seconds:60}]});
  check($('feedback').textContent.includes('No guess')&&$('feedback').textContent.includes('60.0s'),'Absent guesses show a full duration instead of zero');
  await capture('finished');
  publish({phase:'drawing',turn_id:3,revision:9,viewer:0,drawer:0,secret:'<img src=x>',remaining:60,epoch:6,strokes:[],outcome:{}});
  check($('secret').textContent==='<img src=x>'&&!$('secret').querySelector('img'),'Private text is rendered literally');
  publish({players:qaState.players.map((player,index)=>({...player,display_name:index===0?'Artist <img src=x> & Friends':player.display_name}))});
  publish({viewer:3,drawer:0});check(!$('turn-status').querySelector('img')&&$('turn-status').textContent.includes('<img'),'Player names cannot inject markup');
  window.dispatchEvent(new PageTransitionEvent('pagehide'));
  const exitedSounds=qaPlayed.length;
  qaHandlers.message({kind:'clock',turn_id:3,revision:9,phase:'drawing',remaining:9,paused:false,hint:''});
  qaHandlers.message({kind:'sound',sound:'countdown',sequence:99,turn_id:3});
  check(qaPlayed.length===exitedSounds&&!$('timer').classList.contains('game-countdown-blink')&&$('private-card').hidden,'Page exit stops audio/blinking and hides private cards even if late packets arrive');
  check(qaErrors.length===0,'Controller has no uncaught runtime errors: '+qaErrors.join(';'));
  window.qaResult={checks,failures:0};
 }catch(error){window.qaResult={checks,failures:1,error:error.stack};}
})();`;
const prep = `window.initialState=${JSON.stringify(initial)};window.initialStrokes=structuredClone(initialState.strokes);`;
let html = await readFile(join(root,'Games/pictionary/controller/index.html'),'utf8');
html = html.replace('<script src="/controller-sdk.js"></script>', `<script src="/controller-sdk.js"></script><script>${boot}</script>`).replace('</body>', `<script>${prep}${assertions}</script></body>`);
const types = {'.html':'text/html','.css':'text/css','.js':'application/javascript','.svg':'image/svg+xml','.png':'image/png','.json':'application/json','.wav':'audio/wav'};
const server=createServer(async(req,res)=>{
 try {
  const url=new URL(req.url,'http://127.0.0.1');
  if(url.pathname==='/game/pictionary/'){res.writeHead(200,{'Content-Type':'text/html'});res.end(html);return;}
  if(url.pathname==='/game/pictionary/background.json'){res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({image:'/game/pictionary/art/studio.png',videos:[]}));return;}
  let name=url.pathname.startsWith('/game/')?'Games/'+url.pathname.slice(6):url.pathname.startsWith('/ui/')?url.pathname.slice(1):'web/'+url.pathname.slice(1);
  if(/^Games\/pictionary\/(style.css|controller.js)$/.test(name))name=name.replace('pictionary/','pictionary/controller/');
  const file=resolve(root,name);if(!file.startsWith(root+sep))throw Error('Unsafe fixture path');
  const data=await readFile(file);res.writeHead(200,{'Content-Type':types[extname(file)]||'application/octet-stream'});res.end(data);
 }catch{res.writeHead(404);res.end();}
});
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function protocol(url){
 const socket=new WebSocket(url),requests=new Map();let id=0;
 socket.addEventListener('message',event=>{const message=JSON.parse(event.data),request=requests.get(message.id);if(request){requests.delete(message.id);message.error?request.reject(Error(JSON.stringify(message.error))):request.resolve(message.result);}});
 await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
 return {socket,send(method,params={}){return new Promise((resolve,reject)=>{const requestId=++id,timer=setTimeout(()=>reject(Error('Chromium timeout: '+method)),5000);requests.set(requestId,{resolve:value=>{clearTimeout(timer);resolve(value);},reject:error=>{clearTimeout(timer);reject(error);}});socket.send(JSON.stringify({id:requestId,method,params}));});}};
}
await mkdir(output,{recursive:true});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const child=spawn(chrome,['--headless','--no-sandbox','--disable-gpu','--no-first-run','--disable-background-networking','--remote-debugging-port=0',`--user-data-dir=${join(output,'chrome-profile-'+process.pid)}`],{windowsHide:true,stdio:['ignore','ignore','pipe']});
let browser,startup,failed=false;
try{
 const endpoint=await Promise.race([new Promise((resolve,reject)=>{child.on('error',reject);child.stderr.on('data',chunk=>{const match=String(chunk).match(/DevTools listening on (ws:\/\/[^\s]+)/);if(match)resolve(match[1]);});}),new Promise((_,reject)=>{startup=setTimeout(()=>reject(Error('Chromium did not start')),15000);})]);
 clearTimeout(startup);browser=await protocol(endpoint);
 const target=await browser.send('Target.createTarget',{url:'about:blank'}),tabs=await(await fetch(`http://127.0.0.1:${new URL(endpoint).port}/json/list`)).json();
 const page=await protocol(tabs.find(tab=>tab.id===target.targetId).webSocketDebuggerUrl);await page.send('Page.enable');
 for(const [name,width,height,reduced]of[['portrait',390,844,false],['small',360,640,false],['landscape',844,390,false],['tablet',768,1024,false],['desktop',1440,900,false],['reduced',390,844,true]]){
  await page.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
  await page.send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:reduced?'reduce':'no-preference'}]});
  await page.send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/game/pictionary/?fixture=${name}`});
  let result;
  for(let attempt=0;attempt<160;attempt++){
   await wait(50);
   const probe=(await page.send('Runtime.evaluate',{expression:'window.qaPointerProbe',returnByValue:true})).result.value;
   if(probe){
    const x=probe.x+probe.width*.25,y=probe.y+probe.height*.4;
    await page.send('Input.dispatchMouseEvent',{type:'mousePressed',x,y,button:'left',buttons:1,clickCount:1});
    await wait(70);
    await page.send('Runtime.evaluate',{expression:"qaHandlers.message({kind:'clock',turn_id:1,revision:2,phase:'drawing',remaining:41,paused:false,hint:qaState.hint})"});
    await page.send('Input.dispatchMouseEvent',{type:'mouseMoved',x:x+probe.width*.2,y:y+probe.height*.2,button:'left',buttons:1});
    await wait(70);
    await page.send('Input.dispatchMouseEvent',{type:'mouseReleased',x:x+probe.width*.2,y:y+probe.height*.2,button:'left',buttons:0,clickCount:1});
    await page.send('Runtime.evaluate',{expression:'window.qaPointerProbe=null'});
   }
   const capture=(await page.send('Runtime.evaluate',{expression:'window.qaCapture',returnByValue:true})).result.value;
   if(capture){const shot=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});await writeFile(join(output,name+'-'+capture+'.png'),Buffer.from(shot.data,'base64'));await page.send('Runtime.evaluate',{expression:'window.qaCapture=null'});}
   result=(await page.send('Runtime.evaluate',{expression:'window.qaResult',returnByValue:true})).result.value;
   if(result)break;
  }
  if(!result)throw Error(name+': assertions timed out');
  console.log(name+': '+JSON.stringify(result));failed ||= result.failures>0;
 }
 page.socket.close();
}finally{clearTimeout(startup);if(browser){await browser.send('Browser.close').catch(()=>{});browser.socket.close();}else child.kill();await new Promise(resolve=>server.close(resolve));}
if(failed)process.exitCode=1;
