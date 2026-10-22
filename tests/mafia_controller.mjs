import {createServer} from 'node:http';
import {readFile, mkdir, writeFile} from 'node:fs/promises';
import {resolve, join, extname, sep} from 'node:path';
import {spawn} from 'node:child_process';

const root = resolve(import.meta.dirname, '..'), output = join(root, '.test_data', 'mafia-controller');
const chrome = process.argv[2] || process.env.CHROME_BIN || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const players = Array.from({length:16}, (_,seat) => ({id:`p${seat}`,display_name:seat===15?'Player <Sixteen> & Friends':`Player ${seat+1}`,color:['#2463eb','#e53935','#ffffff','#202020'][seat%4],pose:seat%6,alive:true,connected:true}));
const initial = {viewer:0,players,phase:'night',revision:1,round:1,day:1,options:{godfather:true,boxer:true},paused:false,missing:[],status:'Night 1. Private actions are open.',ballots:[],vote_count:0,alive_count:16,outcome:{},history:[],events:[],session_wins:Array(16).fill(0),secret:{role:'godfather',allies:[0,1,2,3],mafia_votes:[],reports:[]},can_act:true,can_vote:false,submitted:false,choice:-1,targets:Array.from({length:12},(_,i)=>i+4)};
const boot = `window.qaState=${JSON.stringify(initial)};window.qaSent=[];
class FixtureController extends window.StarGamesController {
 constructor(id,handlers){super(id,handlers);window.qaHandlers=handlers;window.qaBackground=this.background;this.handlers=handlers;}
 connect(){this.handlers.connected(qaState.players[0]);this.handlers.message(structuredClone(qaState));}
 send(input){qaSent.push(input);}
}
window.StarGamesController=FixtureController;`;
const assertions = `(async()=>{
 const $=id=>document.getElementById(id),pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
 let checks=0; const check=(ok,message)=>{checks++;if(!ok)throw Error(message);};
 const publish=patch=>{qaState={...qaState,...patch,revision:qaState.revision+1};qaHandlers.message(structuredClone(qaState));};
 const capture=async name=>{window.qaCapture=name;while(window.qaCapture)await pause(25);};
 try {
  await pause(250);
  check($('secrets').hidden&&$('role').textContent===''&&$('choose').disabled===false,'Private roles start hidden with an available night decision');
  check(!document.querySelector('[title]')&&!document.querySelector('input,textarea'),'Offline controller has no hover popups or identity fields');
  check(document.documentElement.scrollWidth<=innerWidth+1,'Controller fits portrait, landscape and tablets');
  check(document.body.classList.contains('game-story')&&getComputedStyle($('private-card')).borderImageSource.includes('/ui/playful/paper-fill.png'),'Private card inherits the shared textured noir paper styling');
  check([...$('living-team').querySelectorAll('.avatar')].every(a=>a.getBoundingClientRect().width>=40&&a.getBoundingClientRect().height>=40),'Living-player figures have readable shared avatar dimensions');
  const darkAvatar=$('living-team').children[3].querySelector('.avatar'),darkStyle=getComputedStyle(darkAvatar);
  check(darkStyle.backgroundColor==='rgb(32, 32, 32)'&&darkStyle.maskImage.includes('assembly-avatar.svg')&&getComputedStyle(darkAvatar,'::after').backgroundImage.includes('assembly-avatar-detail.svg'),'Black public avatars retain their identity color with a shared bust and contrasting rim');
  check(getComputedStyle($('living-team').children[3].querySelector('figcaption')).position==='static','Player names stay visible on short phones');
  await capture('night');
  const fullRoster=qaState.players;
  const fullSecret=qaState.secret,fullTargets=qaState.targets;
  const fourPlayers=fullRoster.slice(0,4).map((player,seat)=>({...player,display_name:['Andy','Jack','John','Tony'][seat],color:['#008000','#202020','#ffffff','#e53935'][seat]}));
  publish({players:fourPlayers,alive_count:4,secret:{...fullSecret,role:'detective',allies:[]},targets:[1,2,3]});
  const fourAvatars=[...$('living-team').querySelectorAll('.avatar')].map(a=>a.getBoundingClientRect());
  check(fourAvatars[3].right-fourAvatars[0].left<=280&&fourAvatars.every(a=>a.height>=(innerHeight>700?64:48)),'Four-player roster remains a closely grouped set of larger busts');
  await capture('four-player-glow');
  $('choose').click();
  check($('target').children.length===3&&$('target').querySelector('[data-seat="1"] .avatar').classList.contains('game-avatar-bust'),'Four-player private actions show Jack with the same contrasted bust');
  await capture('four-player-targets');$('cancel').click();
  publish({players:fullRoster,alive_count:16,secret:fullSecret,targets:fullTargets});
  check(Number(document.querySelector('.mafia-sky').dataset.cycle)===1&&document.querySelector('[data-planet="moon"]').getBoundingClientRect().top>=0,'Initial night restores a visible moon without replaying an orbit');
  const cityLayers=[...document.querySelectorAll('.mafia-sky [data-city]')],moon=document.querySelector('[data-planet="moon"]'),scenery=qaBackground.layer.getBoundingClientRect();
  check(cityLayers.length===2&&cityLayers.every(city=>city.complete&&city.naturalWidth>0&&city.getBoundingClientRect().width===scenery.width&&city.getBoundingClientRect().height===scenery.height&&(moon.compareDocumentPosition(city)&Node.DOCUMENT_POSITION_FOLLOWING)),'Offline city layers match the background coverage in front of the orbiting planets');
  $('peek').click();check($('role').textContent==='Godfather'&&$('allies').textContent.includes('Player 4'),'Mafia privately reveals their role and fellow mafia');
  publish({secret:{...qaState.secret,mafia_votes:[{voter:1,target:15}]}});
  check($('mafia-votes').textContent.includes('Player 2 confirmed: Player <Sixteen> & Friends')&&!$('mafia-votes').querySelector('img'),'Live confirmed mafia votes are plain text');
  const publicState=structuredClone(qaState);publicState.viewer=-1;delete publicState.secret;qaHandlers.message(publicState);
  check($('role').textContent==='Godfather','Public packets do not overwrite a private view');
  await capture('mafia-collaboration');
  $('choose').click();check($('target-dialog').open&&$('target').children.length===12&&!$('target').querySelector('[data-seat="0"]')&&!$('target').querySelector('[data-seat="1"]'),'Mafia picker excludes self and teammates');
  check($('confirm').disabled,'Confirm requires an explicit selection');
  const first=$('target').querySelector('[data-seat="4"]');first.click();
  first.dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowLeft',bubbles:true}));
  check($('target').querySelector('[data-seat="15"]').getAttribute('aria-checked')==='true','Keyboard wraps through eligible targets only');
  const chosen=$('target').querySelector('[data-seat="15"]');
  qaHandlers.message(structuredClone(qaState));
  check(chosen===$('target').querySelector('[data-seat="15"]')&&!$('confirm').disabled,'Duplicate snapshots retain live picker controls and selection');
  check($('target-dialog').scrollWidth<=$('target-dialog').clientWidth+1,'Sixteen-player picker has no horizontal overflow');
  const darkTarget=$('target').querySelector('[data-seat="7"] .avatar');
  check(getComputedStyle(darkTarget).maskImage.includes('assembly-avatar.svg')&&getComputedStyle(darkTarget,'::after').backgroundImage.includes('assembly-avatar-detail.svg')&&darkTarget.getBoundingClientRect().height>=80,'Dark picker targets use a larger outlined bust');
  const confirmBox=$('confirm').getBoundingClientRect();check(confirmBox.top>=0&&confirmBox.bottom<=innerHeight,'Confirm remains reachable while player icons scroll');
  await capture('targets');
  $('confirm').click();check(qaSent.at(-1).action==='night_action'&&qaSent.at(-1).target===15&&qaSent.at(-1).revision===qaState.revision,'Confirm sends the chosen seat and revision only');
  check($('choose').disabled&&!$('target-dialog').open,'Pending submission disables repeat input');
  publish({submitted:true,can_act:false,choice:15,targets:[]});check($('choose').disabled&&$('decision-status').textContent.includes('Player <Sixteen> & Friends'),'Confirmed private choice remains visible until dawn');
  publish({phase:'vote',can_act:false,submitted:false,can_vote:true,targets:Array.from({length:15},(_,i)=>i+1),status:'Day 1. Everyone survived.'});
  check(!$('decisions').hidden&&$('secrets').hidden&&!$('choose').disabled,'Dawn immediately opens voting and conceals the role');
  check(!$('cast-vote')&&!$('suspicions')&&!$('target-dialog').open,'Dawn needs no Cast Vote trigger or voting popup');
  check($('choose').textContent==='VOTE'&&$('choose').classList.contains('game-danger')&&!$('choose').classList.contains('game-primary')&&$('pass').classList.contains('game-success'),'Day has red VOTE and green Skip controls from shared styles');
  await pause(120);
  const firstOrbit=Number(document.querySelector('.mafia-sky').dataset.cycle);
  check(matchMedia('(prefers-reduced-motion: reduce)').matches?firstOrbit===0:firstOrbit>1&&firstOrbit<2,'Live dawn rotates the sky while reduced motion restores it immediately');
  qaHandlers.message(structuredClone(qaState));
  check(Number(document.querySelector('.mafia-sky').dataset.cycle)===firstOrbit,'Duplicate snapshots keep the active sun/moon orbit');
  for(let attempt=0;attempt<80&&!qaBackground.layer?.querySelector('img')?.src.includes('town-day');attempt++)await pause(10);
  check(qaBackground.layer.querySelector('img').src.includes('town-day'),'Day selects the shared daytime scenery variant');
  const dayLayer=qaBackground.layer;qaHandlers.message(structuredClone(qaState));check(qaBackground.layer===dayLayer,'Duplicate day snapshots do not replay the background transition');
  check(getComputedStyle(dayLayer).transitionDuration===(matchMedia('(prefers-reduced-motion: reduce)').matches?'0s':'0.9s'),'Scenery crossfade respects reduced motion');
  await pause(450);await capture('dawn-orbit');await pause(550);
  check(getComputedStyle(dayLayer).opacity==='1'&&qaBackground.layers.size===1,'Daytime scenery becomes fully visible and the old night layer is released');
  await capture('day');
  await pause(850);
  check(Number(document.querySelector('.mafia-sky').dataset.cycle)%2===0,'Sun completes the dawn rise opposite the setting moon');
  check(!$('private-card').hidden&&Boolean($('decisions').compareDocumentPosition($('vote-summary'))&Node.DOCUMENT_POSITION_FOLLOWING),'Voting keeps private role access and puts decisions before supplementary lists');
  await capture('vote');
  check($('choose').getBoundingClientRect().bottom<=innerHeight&&$('pass').getBoundingClientRect().bottom<=innerHeight,'Vote and Skip remain immediately reachable');
  check(!$('pass').hidden&&$('pass').textContent==='SKIP','Daytime Skip remains available for every role');
  $('choose').click();check($('target').children.length===15&&!$('target').querySelector('[data-seat="0"]'),'Town ballot offers living opponents');
  $('target').querySelector('[data-seat="2"]').click();publish({paused:true,missing:[3]});
  check(!$('target-dialog').open&&$('choose').disabled&&$('secrets').hidden,'Authoritative pause cancels open decisions');
  const beforePause=qaSent.length;$('choose').click();$('pass').click();check(qaSent.length===beforePause,'Paused taps are discarded');
  publish({paused:false,missing:[]});$('pass').click();check(qaSent.at(-1).action==='vote'&&qaSent.at(-1).target===-1,'Skip submits the explicit abstention');
  publish({submitted:false,can_vote:false,phase:'night',day:2,secret:{role:'doctor',allies:[],mafia_votes:[],reports:[]},can_act:true,targets:Array.from({length:16},(_,i)=>i)});
  const beforeDoctorPass=qaSent.length;$('pass').click();check($('pass').hidden&&qaSent.length===beforeDoctorPass,'Doctor has no Pass button and hidden-button taps cannot submit a pass');
  $('choose').click();check($('target').children.length===16&&$('target').querySelector('[data-seat="0"]'),'Doctor can select themself');
  $('cancel').click();$('peek').click();qaHandlers.disconnected();
  check($('secrets').hidden&&$('role').textContent===''&&$('peek').disabled&&$('choose').disabled,'Disconnect hides private data and locks choices');
  qaHandlers.connected(qaState.players[0]);check(qaSent.at(-1).action==='sync'&&$('choose').disabled,'Reconnect waits for a fresh host snapshot');
  publish({});check(!$('choose').disabled&&$('secrets').hidden,'A new snapshot restores input without revealing the role');
  $('peek').click();
  if(new URL(location.href).searchParams.get('fixture')==='portrait'){
   await pause(1500);publish({});await pause(1700);
   check($('secrets').hidden&&$('role').textContent==='','Role auto-hides after three seconds without extending on sync');
  }
  publish({can_act:true,secret:{role:'detective',allies:[],mafia_votes:[],reports:[]}});
  if(!$('secrets').hidden)$('peek').click();
  const beforeDetectivePass=qaSent.length;$('pass').click();check($('pass').hidden&&qaSent.length===beforeDetectivePass&&$('peek').textContent==='SHOW ROLE','Detective has no Pass and starts without a results label');
  publish({phase:'vote',can_act:false,secret:{role:'detective',allies:[],mafia_votes:[],reports:[{night:2,target:1,result:'civilian'},{night:1,target:3,result:'blocked'}]}});
  check($('peek').textContent==='SHOW ROLE/VIEW RESULTS'&&!$('private-card').hidden,'Investigated Detective can find private results during daytime voting');
  $('peek').click();check($('reports').textContent.includes('Player 2 appears civilian')&&$('reports').textContent.includes('investigation was blocked'),'Detective reports are privately restored');
  window.dispatchEvent(new PageTransitionEvent('pagehide'));check($('secrets').hidden&&$('role').textContent==='','Page exit conceals the private card');
  const deadPlayers=structuredClone(qaState.players);deadPlayers[0].alive=false;
  publish({players:deadPlayers,phase:'vote',can_act:false,can_vote:false,can_suspect:true,suspect_targets:Array.from({length:15},(_,i)=>i+1),suspect_submitted:false,targets:[]});
  check($('decisions').hidden&&$('life').textContent.includes('You are out')&&!$('suspect-decisions').hidden,'Eliminated players cannot vote but have a final suspicion');
  check($('living-team').children.length===16&&$('living-team').firstElementChild.classList.contains('game-team-eliminated')&&getComputedStyle($('living-team').querySelector('.avatar')).backgroundImage.includes('tombstone.svg'),'Eliminated seats remain as shared tombstones');
  check(getComputedStyle($('living-team').querySelector('figcaption')).textDecorationLine.includes('line-through'),'Eliminated player names inherit shared strikethrough styling');
  check((await fetch('/ui/playful/tombstone.svg')).ok,'Shared tombstone artwork is served offline');
  check(document.querySelector('#instructions summary').textContent==='Instructions'&&$('role-instructions').textContent.includes('Detective')&&!$('role-instructions').textContent.includes('You are the Doctor'),'Instructions describe only the current role');
  $('suspect').click();check($('target-dialog').open&&!$('target').querySelector('[data-seat="0"]'),'Last will uses the shared eligible-player picker');
  $('target').querySelector('[data-seat="1"]').click();$('confirm').click();check(qaSent.at(-1).action==='suspect'&&qaSent.at(-1).target===1,'Last will submits one chosen suspect');
  publish({can_suspect:false,suspect_submitted:true,suspect_choice:1,last_will_used:true});
  const afterWill=qaSent.length;$('suspect').click();$('suspect-none').click();check(qaSent.length===afterWill&&$('suspect-status').textContent.includes('Revealed next day'),'Used last will cannot be sent again');
  const ejection={seat:1,mafia:false,day:2,elapsed:.8,duration:6.5};
  const ejectedPlayers=structuredClone(qaState.players);ejectedPlayers[1].alive=false;
  publish({phase:'ejection',ejection,players:ejectedPlayers});
  check(!$('ejection').hidden&&$('ejection-dialog').open&&$('ejection-message').textContent==='Player 2 is innocent.'&&$('living-team').children.length===16,'Optional ejection reveals alignment while keeping eliminated seats');
  check(getComputedStyle($('ejection-message')).color==='rgb(255, 255, 255)'&&(matchMedia('(prefers-reduced-motion: reduce)').matches?getComputedStyle($('ejected-avatar')).animationName==='none':getComputedStyle($('ejected-avatar')).animationDuration==='6.5s'),'Vote-out reveal has white text and the longer authoritative timeline with static reduced motion');
  check($('ejection-stage').contains($('ejection-message'))&&Number(getComputedStyle($('ejection-message')).zIndex)<Number(getComputedStyle($('ejected-avatar')).zIndex),'Alignment is layered behind the moving figure');
  check($('ejection-dialog').getBoundingClientRect().bottom<=innerHeight&&$('ejection-dialog').getBoundingClientRect().top>=0,'Ejection remains visible in portrait and landscape');
  if(matchMedia('(prefers-reduced-motion: reduce)').matches) {
   check(getComputedStyle($('ejected-avatar')).animationName==='none','Reduced motion keeps the innocence reveal static');
   check($('ejection-message').getBoundingClientRect().bottom<=$('ejected-avatar').getBoundingClientRect().top,'Static figure leaves the full alignment unobscured');
  }
  const ejected=$('ejected-avatar');qaHandlers.message(structuredClone(qaState));check(ejected===$('ejected-avatar')&&$('ejection-stage').style.getPropertyValue('--ejection-offset')==='-0.8s','Duplicate ejection snapshots retain motion and refresh elapsed offset');
  await capture('ejection');
  await pause(1000);await capture('ejection-reveal');
  publish({ejection:{seat:1,day:2,elapsed:1.8,duration:6.5,reveal:false}});
  check($('ejection-dialog').open&&$('ejection-message').textContent==='Player 2 was voted out.','Disabling alignment reveals keeps a visible ejection without disclosing Mafia or innocence');
  qaHandlers.disconnected();qaHandlers.connected(qaState.players[0]);
  publish({ejection:{...ejection,elapsed:1.9}});
  check($('ejection-stage').style.getPropertyValue('--ejection-offset')==='-1.9s','Ejection reconnect restores the authoritative elapsed time instead of replaying the flight');
  const outcome={mafia_wins:false,winners:Array.from({length:12},(_,i)=>i+4),roles:['godfather','mafia','mafia','mafia','detective','doctor','boxer',...Array(9).fill('civilian')]};
  publish({phase:'finished',outcome});
  check(!$('result').hidden&&$('private-card').hidden&&$('team').children.length===12&&$('role-reveal').children.length===16,'Results reveal the complete winning team and role list');
  check($('role-reveal').textContent.includes('Player <Sixteen> & Friends')&&!$('role-reveal').querySelector('img')&&!$('replay'),'Results use plain names and host-only replay');
  check($('role-reveal').firstElementChild.querySelector('span').classList.contains('game-danger-text')&&$('role-reveal').firstElementChild.querySelector('span').classList.contains('game-player-eliminated'),'Finished Mafia names are red and dead names are crossed out');
  check(!$('role-reveal').textContent.includes(' · +1 point')&&$('role-reveal').textContent.includes('Detective +1 point'),'Winning points follow the role with only a plus sign');
  check(document.documentElement.scrollWidth<=innerWidth+1,'Long results wrap within the viewport');
  await capture('town-result');
  publish({outcome:{...outcome,mafia_wins:true,winners:[0,1,2,3]}});
  check(document.body.classList.contains('game-result-danger')&&$('team').children.length===4&&$('result-points').textContent.includes('+1'),'Mafia victory inherits the shared red team palette');
  await capture('mafia-result');
  publish({round:2,phase:'night',players:qaState.players.map(p=>({...p,alive:true})),outcome:{},can_act:false,can_vote:false,can_suspect:true,suspect_submitted:false,last_will_used:false,suspect_targets:Array.from({length:15},(_,i)=>i+1),secret:{role:'civilian',allies:[],mafia_votes:[],reports:[]}});
  check(!document.body.classList.contains('game-result-screen')&&$('result').hidden&&$('team').children.length===0&&$('secrets').hidden,'Replay clears results and private reveals');
  check(!$('suspect-decisions').hidden&&!$('suspicions')&&$('role-instructions').textContent.includes('You are a Civilian')&&!$('role-instructions').textContent.includes('You are the Detective'),'Civilian night has a dedicated private choice and role instructions');
  $('suspect').click();$('target').querySelector('[data-seat="2"]').click();$('confirm').click();check(qaSent.at(-1).action==='suspect'&&qaSent.at(-1).target===2,'Living civilian can confirm a suspicion');
  publish({suspect_submitted:true,suspect_choice:2,can_suspect:false});check($('suspect').disabled&&$('suspect-status').textContent.includes('Player 3'),'Civilian choice locks after confirmation');
  publish({day:2,suspect_submitted:false,can_suspect:true});$('suspect-none').click();check(qaSent.at(-1).action==='suspect'&&qaSent.at(-1).target===-1,'No One submits an explicit empty suspicion');
  window.qaResult={checks,failures:0};
 }catch(error){window.qaResult={checks,failures:1,error:error.stack};}
})();`;
let html = await readFile(join(root, 'Games/mafia/controller/index.html'), 'utf8');
html = html.replace('<script src="/controller-sdk.js"></script>', `<script src="/controller-sdk.js"></script><script>${boot}</script>`).replace('</body>', `<script>${assertions}</script></body>`);
const types = {'.html':'text/html','.css':'text/css','.js':'application/javascript','.svg':'image/svg+xml','.png':'image/png','.json':'application/json','.wav':'audio/wav'};
const server = createServer(async(req,res) => {
 try {
  const url = new URL(req.url,'http://127.0.0.1');
  if (url.pathname === '/game/mafia/') {res.writeHead(200,{'Content-Type':'text/html'});res.end(html);return;}
  if (url.pathname === '/game/mafia/background.json') {res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({image:'/game/mafia/art/town-night.png',videos:[],variants:{day:{image:'/game/mafia/art/town-day.png',videos:[]}}}));return;}
  let name = url.pathname.startsWith('/game/') ? 'Games/'+url.pathname.slice(6) : url.pathname.startsWith('/ui/') ? url.pathname.slice(1) : 'web/'+url.pathname.slice(1);
  if (/^Games\/mafia\/(style.css|controller.js|sky.js)$/.test(name)) name = name.replace('mafia/','mafia/controller/');
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
  await page.send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/game/mafia/?fixture=${name}`});
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
