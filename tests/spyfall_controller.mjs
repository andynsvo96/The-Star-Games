import {createServer} from 'node:http';
import {readFile, mkdir, writeFile} from 'node:fs/promises';
import {resolve, join, extname, sep} from 'node:path';
import {spawn} from 'node:child_process';

const root = resolve(import.meta.dirname, '..'), output = join(root, '.test_data', 'spyfall-controller');
const chrome = process.argv[2] || process.env.CHROME_BIN || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const locations = JSON.parse(await readFile(join(root, 'Games/spyfall/locations.json'), 'utf8')).locations;
const players = Array.from({length: 8}, (_, seat) => ({id: `p${seat}`, display_name: seat === 7 ? 'Agent <Seven> & Friends' : `Agent ${seat + 1}`, color: ['#2463eb','#e53935','#ffffff','#202020','#ffdf00','#00ced1','#ff8c00','#8b35c9'][seat]}));
const initial = {viewer: 0, players, phase: 'playing', revision: 1, round: 1, duration: 480, remaining: 480, timer_started: true, vote_duration: 60, vote_remaining: 60, vote_timer_started: false, vote_number: 0, paused: false, missing: [], locations, suspect: -1, accuser: -1, vote_count: 0, session_points: Array(8).fill(0), session_wins: Array(8).fill(0), history: [], outcome: {}, status: 'Agent 1 asks first. Conversation is aloud.', secret: {spy: false, location: 'Space Station'}, can_accuse: true, can_guess: false, can_vote: false, voted: false};
const boot = `window.qaState=${JSON.stringify(initial)};window.qaSent=[];
class FixtureController extends window.StarGamesController {
 constructor(id,handlers){super(id,handlers);window.qaHandlers=handlers;this.handlers=handlers;}
 connect(){this.handlers.connected(qaState.players[0]);this.handlers.message(structuredClone(qaState));}
 send(input){qaSent.push(input);}
}
window.StarGamesController=FixtureController;
window.qaRealAudioContext=window.AudioContext;
window.qaSoundStarts=0;window.qaSoundStops=0;
window.AudioContext=class {
 state='running';destination={};resume(){return Promise.resolve();}
 decodeAudioData(){return Promise.resolve({});}
 createBufferSource(){return {connect(){},start(){qaSoundStarts++;},stop(){qaSoundStops++;}};}
};`;
const assertions = `(async()=>{
 const $=id=>document.getElementById(id),pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
 let checks=0; const check=(ok,message)=>{checks++;if(!ok)throw Error(message);};
 const publish=patch=>{qaState={...qaState,...patch,revision:qaState.revision+1};qaHandlers.message(structuredClone(qaState));};
 const capture=async name=>{window.qaCapture=name;while(window.qaCapture)await pause(25);};
 try {
  await pause(250);
  const realAudio=new qaRealAudioContext();
  for (const name of ['countdown','timer_up','vote','spy_win','non_spies_win']) { const cue=await realAudio.decodeAudioData(await (await fetch('audio/'+name+'.wav')).arrayBuffer());check(cue.duration>.1&&cue.duration<2&&cue.numberOfChannels===1,'Offline cue decodes in the real browser: '+name); } await realAudio.close();
  check($('secret').textContent==='Hidden'&&!$('ready')&&!$('accuse').hidden,'Private cards start hidden while the round is immediately playable');
  check(!$('show-locations')&&!$('locations-dialog')&&!$('players')&&!document.querySelector('details'),'Removed player controls leave no hidden markup');
  $('peek').click();check($('secret').textContent==='Space Station'&&$('peek').getAttribute('aria-expanded')==='true','Owner can reveal the location immediately');
  const ignored=structuredClone(qaState);ignored.viewer=-1;delete ignored.secret;qaHandlers.message(ignored);check($('secret').textContent==='Space Station','Public snapshots cannot overwrite the private card');
  await pause(1500);publish({remaining:478});await pause(1600);
  check($('secret').textContent==='Hidden'&&$('peek').textContent==='SHOW CARD'&&$('peek').getAttribute('aria-expanded')==='false','Cards automatically hide after three seconds despite timer snapshots');
  $('peek').click();await pause(1500);$('peek').click();$('peek').click();await pause(1650);
  check($('secret').textContent==='Space Station','Manually hiding and reopening cancels the old hide timer');
  await pause(1450);check($('secret').textContent==='Hidden','A reopened card gets its own three-second timeout');
  check(!document.querySelector('[title]')&&!document.querySelector('input,textarea'),'There are no hover popups or typed conversation fields');
  check([...document.images].every(img=>img.complete&&img.naturalWidth>0),'All artwork loads offline');
  check(document.documentElement.scrollWidth<=innerWidth+1,'Portrait and landscape have no horizontal overflow');
  check(!$('show-help')&&!$('help-dialog')&&!$('replay')&&$('status').hidden,'Player instructions and replay markup are removed');
  check($('clock-status').textContent==='ROUND TIMER'&&$('vote-clock').hidden&&Number($('timer').textContent.split(':')[0])===7,'Discussion runs its round clock while voting time remains unstarted');
  const logo=document.querySelector('.game-title-art'),header=logo.parentElement.getBoundingClientRect();
  check(logo.complete&&logo.getBoundingClientRect().width>=Math.min(header.width,200)&&logo.getBoundingClientRect().right<=innerWidth+1,'The compact offline stencil logo stays readable without overflowing');
  check(document.body.classList.contains('game-story')&&getComputedStyle($('private-card')).borderImageSource.includes('/ui/playful/paper-fill.png'),'Private cards inherit the shared textured dossier paper styling');
  const portrait=$('private-card').querySelector('.game-card-portrait');
  check(portrait.complete&&portrait.naturalWidth>1000&&portrait.src.includes('private-agent.png')&&getComputedStyle($('clock')).borderImageSource==='none','Dossier uses the larger offline spy portrait and the dark phone clock from the reference');
  await capture('playing');
  document.dispatchEvent(new Event('pointerdown'));await pause(100);
  publish({remaining:9.9,timer_started:true});
  check($('timer').textContent==='10'&&$('timer').classList.contains('game-danger-text')&&qaSoundStarts===1,'Final ten seconds show red numbers with one local sound cue');
  const beforeTick=qaSoundStarts;qaHandlers.message(structuredClone(qaState));
  check(qaSoundStarts===beforeTick,'Duplicate snapshots cannot repeat countdown audio');
  check(getComputedStyle($('timer')).animationName===(matchMedia('(prefers-reduced-motion: reduce)').matches?'none':'game-countdown-tick'),'Countdown follows the device motion preference');
  await capture('countdown');
  publish({paused:true,remaining:9.9});check(!$('timer').classList.contains('game-countdown-tick')&&qaSoundStops>0,'Pause cancels countdown motion and audio');
  publish({paused:false,remaining:8.9,reduced_motion:true});
  check(!$('timer').classList.contains('game-countdown-tick')&&qaSoundStarts===beforeTick+1,'Host reduced motion freezes numbers while preserving sound');
  publish({remaining:50,reduced_motion:false});
  check(!$('accuse').hidden&&$('guess').hidden,'Non-spies have accusations and no guess action');
  check(getComputedStyle($('accuse')).borderColor==='rgb(165, 43, 57)','Accuse uses the shared red action palette');
  $('accuse').click();check($('target-dialog').open&&$('target').querySelectorAll('[role=radio]').length===7&&!$('target').querySelector('[data-seat="0"]')&&!$('target-dialog').querySelector('select'),'Accusations exclude the owner');
  check($('confirm-target').disabled&&$('target').getAttribute('role')==='radiogroup','Confirm stays disabled until an icon is selected');
  const beforePick=qaSent.length;
  const target3=$('target').querySelector('[data-seat="3"]');target3.click();
  check(qaSent.length===beforePick&&target3.getAttribute('aria-checked')==='true'&&!$('confirm-target').disabled,'Tapping an icon selects it without submitting');
  qaHandlers.message(structuredClone(qaState));check(target3===$('target').querySelector('[data-seat="3"]')&&target3.getAttribute('aria-checked')==='true','Duplicate snapshots preserve the icon selection');
  check($('target').querySelector('[data-seat="7"] .game-player-name').textContent==='Agent <Seven> & Friends'&&!$('target').querySelector('img'),'Player names remain plain text and icons reuse offline avatars');
  check(getComputedStyle(target3.querySelector('.avatar')).backgroundColor==='rgb(32, 32, 32)','Icons use each player color');
  target3.dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowRight',bubbles:true}));check($('target').querySelector('[data-seat="4"]').getAttribute('aria-checked')==='true','Arrow keys select a different eligible player');target3.click();
  await capture('suspect-icons');
  check($('target-dialog').scrollWidth<=$('target-dialog').clientWidth+1,'Icon picker fits the dialog in portrait and landscape'); const confirmRect=$('confirm-target').getBoundingClientRect();check(confirmRect.top>=0&&confirmRect.bottom<=innerHeight,'Confirm remains visible while the icon grid scrolls');
  check([...$('target').querySelectorAll('[role=radio]')].every(button=>{const box=button.getBoundingClientRect(),icon=button.querySelector('.avatar').getBoundingClientRect(),name=button.querySelector('.game-player-name').getBoundingClientRect();return box.height>=120&&icon.top>=box.top&&name.bottom<=box.bottom+1;}),'Short landscape layouts scroll complete player cards without compressing their icons');
  $('confirm-target').click();check(qaSent.at(-1).action==='accuse'&&qaSent.at(-1).target===3,'Accusation submits only the selected target');
  $('accuse').click();publish({paused:true,missing:[2]});check(!$('target-dialog').open&&$('accuse').disabled,'Authoritative pause cancels pending accusations');
  const before=qaSent.length;$('accuse').click();check(qaSent.length===before,'Paused input is discarded');
  publish({paused:false,missing:[]});$('peek').click();qaHandlers.disconnected();check($('secret').textContent==='Hidden'&&$('peek').disabled&&$('accuse').disabled,'Disconnect conceals the secret and disables input');
  qaHandlers.connected(qaState.players[0]);publish({});check(qaSent.at(-1).action==='sync'&&!$('accuse').disabled,'Reconnect requests authoritative state');
  publish({phase:'vote',vote_remaining:60,vote_timer_started:true,vote_number:1,suspect:0,accuser:1,can_accuse:false,can_vote:false,voted:false,status:'Agent 2 accused Agent 1.'});
  check(!$('vote').hidden&&$('agree').hidden&&$('vote-status').textContent.includes('do not vote'),'Accused player cannot vote');
  publish({suspect:2,can_vote:true});$('agree').click();check(qaSent.at(-1).action==='vote'&&qaSent.at(-1).agree===true,'Vote submits an actual boolean');
  check(getComputedStyle($('disagree')).borderColor==='rgb(165, 43, 57)','No uses the shared red action palette');
  const agree=$('agree');qaHandlers.message(structuredClone(qaState));check(agree===$('agree'),'Timer and duplicate snapshots preserve live button targets');
  publish({remaining:40,vote_remaining:40});
  const voteDeadline=performance.now()+3500;
  while($('vote-timer').textContent==='00:40'&&performance.now()<voteDeadline)await pause(100);
  check($('timer').textContent==='00:40'&&Number($('vote-timer').textContent.split(':').at(-1))<=39&&$('clock-status').textContent==='ROUND TIMER PAUSED'&&$('vote-clock-status').textContent==='VOTING DEADLINE','Voting runs its own clock while the round time freezes');
  await capture('vote');
  publish({phase:'playing',vote_timer_started:false,suspect:-1,secret:{spy:true,location:''},can_guess:true,can_accuse:true,can_vote:false,status:'Conversation is aloud.'});
  $('peek').click();check($('secret').textContent==='YOU ARE THE SPY'&&!$('guess').hidden,'Spy sees its role without the selected location');
  check($('secret').classList.contains('game-danger-text')&&getComputedStyle($('secret')).color==='rgb(255, 91, 85)','Spy role text uses the shared red text color');
  check($('accuse').hidden&&getComputedStyle($('guess')).borderColor==='rgb(68, 215, 198)','Spies have only the shared teal Guess Location action');
  const beforeSpyAccuse=qaSent.length;$('accuse').click();check(qaSent.length===beforeSpyAccuse&&!$('target-dialog').open,'A spy cannot trigger accusations even from a stale eligible snapshot');
  await capture('spy');
  $('guess').click();check($('guess-dialog').open&&$('location').options.length===30,'Spy guesses from the same complete pool');
  $('location').value='Beach';$('confirm-guess').click();check(qaSent.at(-1).action==='guess'&&qaSent.at(-1).location==='Beach','Guess submits one explicit location');
  const beforeExpiry=qaSoundStarts; $('guess').click();publish({sound_sequence:1,sound_events:[{sequence:1,kind:'timer_up'}],phase:'final_vote',remaining:0,vote_remaining:60,vote_timer_started:false,vote_number:2,can_guess:false,can_accuse:false,can_vote:true,voted:false,status:'Time is up.'});
  check(qaSoundStarts===beforeExpiry+1,'Time expiry plays its own cue once');qaHandlers.message(structuredClone(qaState));check(qaSoundStarts===beforeExpiry+1,'Duplicate expiry snapshots stay silent');
  check(!$('guess-dialog').open&&!$('final-vote').hidden&&$('timer').textContent==='00:00','Time expiry cancels an unsent guess and restores the final vote');
  check(!$('final-vote').querySelector('h2')&&$('final-status').hidden&&$('role-actions').hidden,'Final vote has no heading or instruction spacer above its action');
  await pause(650);check($('vote-timer').textContent==='01:00'&&$('vote-clock-status').textContent==='VOTING · AWAITING FIRST VOTE','Final voting time waits for the first accepted ballot');
  const finalGap=$('choose-final').getBoundingClientRect().top-$('private-card').getBoundingClientRect().bottom;
  check(finalGap>=0&&finalGap<24,'Choose a suspect sits immediately below the private card');await capture('final-vote');
  $('choose-final').click();check($('confirm-target').disabled,'Opening another choice clears the old selection');$('target').querySelector('[data-seat="5"]').click();await capture('final-suspect-icons');$('confirm-target').click();check(qaSent.at(-1).action==='final_vote'&&qaSent.at(-1).target===5,'Final vote uses its separate validated action');
  const beforeVoteSound=qaSoundStarts;publish({voted:true,can_vote:false,vote_timer_started:true,sound_sequence:2,sound_events:[{sequence:1,kind:'timer_up'},{sequence:2,kind:'vote'}]});check(qaSoundStarts===beforeVoteSound+1,'An accepted vote triggers one authoritative ballot cue');check($('choose-final').hidden&&$('final-status').textContent.includes('recorded'),'Submitted final vote cannot be changed');
  check($('vote-clock-status').textContent==='VOTING DEADLINE','First accepted final ballot starts the voting deadline');
  const beforeVoteTick=qaSoundStarts;publish({vote_remaining:9.9});
  check($('timer').textContent==='00:00'&&$('vote-timer').textContent==='10'&&$('vote-timer').classList.contains('game-danger-text')&&qaSoundStarts===beforeVoteTick+1,'Vote urgency has its own countdown cue, independent of the earlier round countdown');
  qaHandlers.message(structuredClone(qaState));check(qaSoundStarts===beforeVoteTick+1,'Duplicate voting snapshots cannot replay their countdown cue');
  await capture('vote-countdown');
  const outcome={spy_wins:true,reason:'escaped',spy:0,location:'Hospital',points:[2,0,0,0,0,0,0,0],winners:[0],round:1};
  const beforeResultSound=qaSoundStarts;publish({sound_sequence:3,sound_events:[{sequence:1,kind:'timer_up'},{sequence:2,kind:'vote'},{sequence:3,kind:'spy_win'}],phase:'finished',outcome,session_points:[2,0,0,0,0,0,0,0],session_wins:[1,0,0,0,0,0,0,0],status:'The spy wins!'});
  check(!$('result').hidden&&!$('replay')&&$('clock').hidden&&$('reveal').textContent.includes('Hospital')&&$('earned').textContent.includes('2 points'),'Completion reveals secrets and points with host-only replay');
  check(qaSoundStarts===beforeResultSound+1,'The spy victory plays its distinct result cue');
  const spyName=$('reveal').querySelector('.game-danger-text');check(spyName?.textContent===qaState.players[0].display_name&&getComputedStyle(spyName).color==='rgb(255, 91, 85)'&&$('connection').querySelector('.game-danger-text'),'The complete spy name turns red only in the completed result');
  const beforeReconnectSound=qaSoundStarts;qaHandlers.disconnected();qaHandlers.connected(qaState.players[0]);qaHandlers.message(structuredClone(qaState));check(qaSoundStarts===beforeReconnectSound,'Reconnect restores a result without replaying its fanfare');
  check($('result-team').children.length===1&&$('result-team').querySelector('figcaption').textContent===qaState.players[0].display_name&&document.body.classList.contains('game-result-danger'),'Spy victory reveals only the spy against the red result theme');
  check(!qaSent.some(input=>['replay','next'].includes(input.action)),'Controllers never send restart actions');await capture('result');
  publish({sound_sequence:3,sound_events:[],round:2,phase:'playing',remaining:480,timer_started:true,vote_remaining:60,vote_timer_started:false,vote_number:0,outcome:{},secret:{spy:false,location:'Library'},can_accuse:true});check($('secret').textContent==='Hidden'&&!$('accuse').hidden&&!$('secret').classList.contains('game-danger-text'),'Replay starts immediately with concealed cards and fresh role actions');
  check(!$('result-team').children.length&&!document.body.classList.contains('game-result-screen')&&$('timer').textContent==='08:00'&&$('vote-clock').hidden,'Replay clears the lineup and result background and resets both clocks');
  check(!$('reveal').querySelector('.game-danger-text')&&!$('connection').querySelector('.game-danger-text'),'New rounds clear the public red spy-name marker');
  const beforeNonSpySound=qaSoundStarts;
  publish({phase:'finished',outcome:{...outcome,spy_wins:false,spy:7,points:[1,1,1,1,1,1,1,0],reason:'caught'},sound_sequence:4,sound_events:[{sequence:4,kind:'non_spies_win'}]});
  check(qaSoundStarts===beforeNonSpySound+1&&$('winner').textContent==='CIVILIANS WIN!'&&$('reveal').querySelector('.game-danger-text').textContent==='Agent <Seven> & Friends'&&!$('reveal').querySelector('img'),'Non-spy victory uses its distinct cue and safely colors the complete spy name');check($('result-team').children.length===7&&[...$('result-team').querySelectorAll('figcaption')].every(name=>name.textContent!=='Agent <Seven> & Friends')&&!document.body.classList.contains('game-result-danger'),'Civilian victory reveals every civilian and excludes the spy in the teal theme');check(document.documentElement.scrollWidth<=innerWidth+1,'Winning team wraps without horizontal overflow');await capture('non-spy-result');
  publish({round:3,phase:'playing',outcome:{},sound_events:[],secret:{spy:false,location:'Library'},can_accuse:true,can_guess:false});
  publish({locations:['A'.repeat(60),'Harbor <img src=x>'],players:qaState.players.slice(0,4),session_points:[2,0,0,0],session_wins:[1,0,0,0]});
  publish({secret:{spy:true,location:''},can_guess:true,can_accuse:false});
  $('guess').click();check($('location').options.length===2&&$('location').options[1].text==='Harbor <img src=x>'&&!$('location').querySelector('img'),'Customized pools update the guess picker and remain plain text');
  check($('guess-dialog').scrollWidth<=$('guess-dialog').clientWidth+1,'Long custom names stay inside the guess dialog');$('guess-dialog').close();
  $('peek').click();window.dispatchEvent(new PageTransitionEvent('pagehide'));check($('secret').textContent==='Hidden','Leaving the page immediately conceals the card');
  window.qaResult={checks,failures:0};
 } catch(error){window.qaResult={checks,failures:1,error:error.stack};}
})();`;
let html = await readFile(join(root, 'Games/spyfall/controller/index.html'), 'utf8');
html = html.replace('<script src="/controller-sdk.js"></script>', `<script src="/controller-sdk.js"></script><script>${boot}</script>`).replace('</body>', `<script>${assertions}</script></body>`);
const types = {'.html':'text/html','.css':'text/css','.js':'application/javascript','.svg':'image/svg+xml','.png':'image/png','.json':'application/json','.wav':'audio/wav'};
const server = createServer(async(req,res) => {
 try {
  const url = new URL(req.url,'http://127.0.0.1');
  if (url.pathname === '/game/spyfall/') {res.writeHead(200,{'Content-Type':'text/html'});res.end(html);return;}
  if (url.pathname === '/game/spyfall/background.json') {res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({image:'/game/spyfall/art/spy-office.png',videos:[]}));return;}
  let name = url.pathname.startsWith('/game/') ? 'Games/'+url.pathname.slice(6) : url.pathname.startsWith('/ui/') ? url.pathname.slice(1) : 'web/'+url.pathname.slice(1);
  if (/^Games\/spyfall\/(style.css|controller.js)$/.test(name)) name = name.replace('spyfall/','spyfall/controller/');
  const file = resolve(root,name);if(!file.startsWith(root+sep))throw Error('Unsafe fixture path');
  const body=await readFile(file);res.writeHead(200,{'Content-Type':types[extname(file)] || 'application/octet-stream'});res.end(body);
 } catch {res.writeHead(404);res.end();}
});
const wait = ms => new Promise(resolve=>setTimeout(resolve,ms));
async function protocol(url) {
 const socket = new WebSocket(url), requests = new Map();let id=0;
 socket.addEventListener('message',event=>{const message=JSON.parse(event.data),request=requests.get(message.id);if(request){requests.delete(message.id);message.error?request.reject(Error(JSON.stringify(message.error))):request.resolve(message.result);}});
 await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
 return {socket,send(method,params={}){return new Promise((resolve,reject)=>{const requestId=++id,timer=setTimeout(()=>reject(Error('Chromium timeout: '+method)),5000);requests.set(requestId,{resolve:value=>{clearTimeout(timer);resolve(value);},reject:error=>{clearTimeout(timer);reject(error);}});socket.send(JSON.stringify({id:requestId,method,params}));});}};
}
await mkdir(output,{recursive:true});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const child = spawn(chrome,['--headless','--no-sandbox','--disable-gpu','--no-first-run','--disable-background-networking','--remote-debugging-port=0',`--user-data-dir=${join(output,'chrome-profile-'+process.pid)}`],{windowsHide:true,stdio:['ignore','ignore','pipe']});
let browser,failed=false,startup;
try {
 const endpoint=await Promise.race([new Promise((resolve,reject)=>{child.on('error',reject);child.stderr.on('data',chunk=>{const match=String(chunk).match(/DevTools listening on (ws:\/\/[^\s]+)/);if(match)resolve(match[1]);});}),new Promise((_,reject)=>{startup=setTimeout(()=>reject(Error('Chromium did not start')),15000);})]);
 clearTimeout(startup);browser=await protocol(endpoint);
 const target=await browser.send('Target.createTarget',{url:'about:blank'}), tabs=await(await fetch(`http://127.0.0.1:${new URL(endpoint).port}/json/list`)).json();
 const page=await protocol(tabs.find(tab=>tab.id===target.targetId).webSocketDebuggerUrl);await page.send('Page.enable');
 for(const [name,width,height,reduced] of [['portrait',390,844,false],['small',360,640,false],['landscape',844,390,false],['tablet',768,1024,false],['desktop',1440,900,false],['reduced',390,844,true]]) {
  await page.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
  await page.send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:reduced?'reduce':'no-preference'}]});
  await page.send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/game/spyfall/?fixture=${name}`});
  let result;
  for(let attempt=0;attempt<400;attempt++) {
   await wait(50);
   const captureName=(await page.send('Runtime.evaluate',{expression:'window.qaCapture',returnByValue:true})).result.value;
   if(captureName){const shot=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});await writeFile(join(output,name+'-'+captureName+'.png'),Buffer.from(shot.data,'base64'));await page.send('Runtime.evaluate',{expression:'window.qaCapture=null'});}
   result=(await page.send('Runtime.evaluate',{expression:'window.qaResult',returnByValue:true})).result.value;
   if(result)break;
  }
  if(!result)throw Error(name+': assertions timed out');
  console.log(name+': '+JSON.stringify(result));failed ||= result.failures>0;
 }
 page.socket.close();
} finally {clearTimeout(startup);if(browser){await browser.send('Browser.close').catch(()=>{});browser.socket.close();}else child.kill();await new Promise(resolve=>server.close(resolve));}
if(failed)process.exitCode=1;
