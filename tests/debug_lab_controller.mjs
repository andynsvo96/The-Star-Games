// Synthetic controllers and the public template, all served by the real LAN server.
import {readFile, writeFile, mkdir, unlink} from 'node:fs/promises';
import {resolve, join} from 'node:path';
import {spawn} from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const output = join(root, '.test_data', 'debug-lab-lan');
const godot = process.env.GODOT_BIN || 'C:/Users/Administrator/Desktop/Godot_v4.7-stable_win64.exe';
const chrome = process.argv[2] || process.env.CHROME_BIN || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
await mkdir(output, {recursive:true});
for (const name of ['port.json','stop']) await unlink(join(output,name)).catch(error => {if(error.code!=='ENOENT')throw error;});

const fixture = `<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/styles.css"></head>
<body><main class="game-controller"><h1>Debug fixture</h1><p id="status"></p><button id="play" type="button">Play</button>
<section id="concealed-panel" hidden><div style="display:none;opacity:0" id="nested"><button id="hidden-action" type="button">Hidden decision</button></div></section>
<dialog id="choice" class="game-dialog"><h2>Fixture choice</h2><button type="button">Confirm</button></dialog><div id="dynamic"></div></main>
<script>
window.sent=[];window.renders=0;window.closeEvents=0;
class Socket {
 static OPEN=1;
 constructor(){this.readyState=1;this.listeners={};window.socket=this;}
 addEventListener(name,fn){this.listeners[name]=fn;}
 send(encoded){const value=JSON.parse(encoded);sent.push(value);if(value.payload?.action==='sync')setTimeout(()=>publish(fixtureState),0);}
 deliver(value){this.listeners.message({data:JSON.stringify(value)});}
}
window.WebSocket=Socket;
window.fixtureState={status:'Live state',revision:1,phase:'play',hand:['own-private-card']};
</script><script src="/controller-sdk.js"></script><script>
window.ctrl=new StarGamesController('debug-fixture',{
 connected:()=>ctrl.send({action:'sync'}),
 message:payload=>{renders++;document.querySelector('#status').textContent=payload.status;document.querySelector('#dynamic').replaceChildren();if(payload.phase==='decision'){const button=document.createElement('button');button.id='dynamic-choice';button.textContent='Generated decision';document.querySelector('#dynamic').append(button);}},
 debugScenarios:()=>[{id:'generated',label:'Generated choice',description:'Synthetic triggered UI',payload:{status:'Preview choice',revision:900,phase:'decision'}},{id:'literal',label:'Literal <b>label</b>',selectors:['#choice']}]
});
window.publish=payload=>{fixtureState=payload;socket.deliver({type:'game',game_id:'debug-fixture',payload});};
ctrl.connect();socket.deliver({type:'joined',game_id:'debug-fixture',player:{display_name:'Literal <player>',color:'#2463eb'},reconnect_token:'fixture-credential'});publish(fixtureState);
document.querySelector('#play').addEventListener('click',()=>ctrl.send({action:'play',revision:fixtureState.revision}));
document.querySelector('#choice').addEventListener('close',()=>closeEvents++);
window.fixtureReady=true;
</script></body></html>`;
await writeFile(join(output,'index.html'),fixture);
const env = {...process.env, APPDATA:join(output,'appdata')};
await mkdir(env.APPDATA,{recursive:true});
const host = spawn(godot,['--headless','--path',root,'--script','res://tests/debug_lab.gd','--','--serve-debug-lab'],{env,windowsHide:true,stdio:['ignore','pipe','pipe']});
let hostLog='';host.stdout.on('data',chunk=>{hostLog+=chunk;});host.stderr.on('data',chunk=>{hostLog+=chunk;});
let hostError;host.on('error',error=>{hostError=error;});
let browser, page, child, total=0;
const browserErrors = [];

async function protocol(url) {
 const socket=new WebSocket(url),pending=new Map();let id=0;
 socket.addEventListener('message',event=>{const value=JSON.parse(event.data),request=pending.get(value.id);if(request){pending.delete(value.id);value.error?request.reject(Error(JSON.stringify(value.error))):request.resolve(value.result);}});
 await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
 return {socket,send(method,params={}){return new Promise((resolve,reject)=>{pending.set(++id,{resolve,reject});socket.send(JSON.stringify({id,method,params}));});}};
}
async function evaluate(expression){const result=await page.send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(result.exceptionDetails)throw Error(JSON.stringify(result.exceptionDetails));return result.result.value;}
async function until(expression){for(let attempt=0;attempt<150;attempt++){if(await evaluate(expression))return;await delay(40);}throw Error('Timed out: '+expression);}

const assertions = `(async()=>{
 let checks=0;const check=(ok,text)=>{checks++;if(!ok)throw Error(text);};
 const $=id=>document.getElementById(id),frame=$('controller'),view=frame.contentWindow,doc=frame.contentDocument;
 const wait=()=>new Promise(resolve=>setTimeout(resolve,350));
 const choose=(id,text)=>{const list=$(id),item=[...list.options].find(item=>item.textContent.includes(text));check(Boolean(item),'List contains '+text);list.value=item.value;list.dispatchEvent(new Event('change'));};
 try {
  $('tools').click();check(!$('inspector').hidden,'Tools opens without changing controller viewport');
  check(view.innerWidth===390&&view.innerHeight===844,'Exact phone CSS viewport is preserved');
  check($('connection').textContent==='Connected as Literal <player>','Identity renders as literal text');
  check(!$('connection').children.length&&!document.querySelector('[title]'),'No markup injection or hover tooltips');
  $('rotate').click();await wait();check(view.innerWidth===844&&view.innerHeight===390,'Rotation changes the real frame viewport');
  $('device').value='360,640';$('device').dispatchEvent(new Event('change'));await wait();check(view.innerWidth===360&&view.innerHeight===640,'Small phone preset reaches module media queries');
  $('device').value='390,844';$('device').dispatchEvent(new Event('change'));
  $('width').value='1';$('width').dispatchEvent(new Event('change'));check(view.innerWidth===390,'Invalid dimensions retain the previous value');
  $('scan').click();check([...$('element-list').options].some(item=>item.textContent.includes('[hidden]')&&item.textContent.includes('#hidden-action')),'Hidden descendants are inventoried');
  choose('element-list','#hidden-action');$('reveal').click();await wait();
  check(frame.inert&&!$('preview-status').hidden,'Element preview is visibly read-only');
  check(!doc.querySelector('#concealed-panel').hidden&&view.getComputedStyle(doc.querySelector('#nested')).display!=='none','Preview reveals nested hidden ancestors');
  const sent=view.sent.length;view.ctrl.send({action:'forged-preview-input'});doc.querySelector('#play').click();check(view.sent.length===sent,'SDK and DOM both block preview gameplay input');
  $('mark').click();check($('coverage').textContent.includes('1 marked checked'),'Manual coverage records inspected elements');
  $('restore').click();await wait();
  check(!frame.inert&&doc.querySelector('#concealed-panel').hidden,'Live return restores hidden attributes');
  check(doc.querySelector('#nested').style.display==='none'&&doc.querySelector('#nested').style.opacity==='0','Original display and opacity are restored');
  check(view.sent.at(-1).payload.action==='sync','Live return requests authoritative state');
  $('hold').click();const renders=view.renders;
  view.publish({status:'New host state',revision:2,phase:'play',hand:['own-private-card']});await wait();
  check(view.renders===renders&&doc.querySelector('#status').textContent==='Live state','Holding suppresses rendering while receiving new host state');
  $('hold').click();await wait();check(doc.querySelector('#status').textContent==='New host state','Live return restores the newest host state');
  document.querySelector('[data-tab="snapshots"]').click();await wait();
  check($('snapshot-list').options.length===2,'Identical packets are deduplicated');
  $('snapshot-list').value='1';$('snapshot-list').dispatchEvent(new Event('change'));
  check($('snapshot-info').textContent.includes('own-private-card')&&!$('snapshot-info').textContent.includes('fixture-credential'),'Inspector contains delivered state and omits join credentials');
  $('snapshot-preview').click();check(doc.querySelector('#status').textContent==='Live state'&&frame.inert,'Historical snapshots are read-only');
  $('restore').click();await wait();
  document.querySelector('[data-tab="scenarios"]').click();choose('scenario-list','Generated choice');$('scenario-preview').click();await wait();
  check(Boolean(doc.querySelector('#dynamic-choice'))&&frame.inert,'Named synthetic payload creates triggered UI without host input');
  choose('scenario-list','Literal <b>label</b>');$('scenario-preview').click();await wait();
  check(doc.querySelector('#choice').open&&!doc.querySelector('#choice').matches(':modal'),'Closed dialogs preview without modal game callbacks');
  check(view.closeEvents===0&&!$('scenario-list').querySelector('b'),'Scenario labels are literal and preview emits no close callbacks');
  $('restore').click();await wait();check(!doc.querySelector('#choice').open&&view.closeEvents===0&&!doc.querySelector('#dynamic-choice'),'Live return removes scenario UI and restores closed dialogs');
  $('hold').click();for(let revision=3;revision<70;revision++)view.publish({status:'Host '+revision,revision,phase:'play'});
  check($('snapshot-list').options.length<=48&&$('activity-list').children.length<=80,'Snapshot history and activity are bounded');
  $('hold').click();await wait();check(doc.querySelector('#status').textContent==='Host 69','Overflow recovers through current host sync');
  $('hold').click();view.socket.listeners.close();check($('connection').textContent.includes('Reconnecting'),'Disconnect is visible while inspecting');
  clearTimeout(view.ctrl.retryTimer);view.ctrl.connect();view.socket.deliver({type:'joined',game_id:'debug-fixture',player:{display_name:'Literal <player>',color:'#2463eb'},reconnect_token:'fixture-credential'});
  view.publish({status:'Reconnected state',revision:70,phase:'play'});check(frame.inert,'Reconnect preserves the preview input lock');
  $('hold').click();await wait();check(doc.querySelector('#status').textContent==='Reconnected state','Live return restores state received after reconnection');
  check(!$('activity-list').textContent.includes('fixture-credential')&&!$('activity-list').textContent.includes('own-private-card'),'Activity summaries omit message contents and credentials');
  const before=view.sent.length;doc.querySelector('#play').click();check(view.sent.length===before+1,'Live gameplay input works again');
  const stage=$('stage').getBoundingClientRect(),preview=$('device-frame').getBoundingClientRect();check(preview.width<=stage.width+1&&preview.height<=stage.height+1,'Preview fits available space without altering its CSS viewport');
  check(document.documentElement.scrollWidth===innerWidth,'Debug tools have no sideways page overflow');
  window.qaResult={checks,failures:0};
 }catch(error){window.qaResult={checks,failures:1,error:String(error.stack||error)};}
})();`;

try {
 let port;
 for(let attempt=0;attempt<200;attempt++){if(hostError)throw hostError;if(host.exitCode!==null)throw Error(hostLog);try{port=JSON.parse(await readFile(join(output,'port.json'),'utf8')).port;break;}catch(error){if(error.code!=='ENOENT')throw error;}await delay(50);}
 if(!port)throw Error('LAN server did not start: '+hostLog);
 const base='http://127.0.0.1:'+port;
 for(const [path,type] of [['/debug.html','text/html'],['/debug-lab.js','javascript'],['/debug-lab.css','text/css']]){const response=await fetch(base+path);if(!response.ok||!response.headers.get('content-type').includes(type))throw Error('Missing LAN asset '+path);}
 child=spawn(chrome,['--headless=new','--no-sandbox','--disable-gpu','--remote-debugging-port=0','--user-data-dir='+join(output,'profile-'+Date.now()),'about:blank'],{windowsHide:true,stdio:['ignore','ignore','pipe']});
 const endpoint=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Chromium did not start')),15000);let log='';child.stderr.on('data',chunk=>{log+=chunk;const match=log.match(/DevTools listening on (ws:\/\/[^\s]+)/);if(match){clearTimeout(timer);resolve(match[1]);}});child.on('error',reject);child.on('exit',code=>reject(Error('Chromium exited '+code)));});
 browser=await protocol(endpoint);const target=await browser.send('Target.createTarget',{url:'about:blank'});
 const tabs=await(await fetch('http://127.0.0.1:'+new URL(endpoint).port+'/json/list')).json();
 page=await protocol(tabs.find(tab=>tab.id===target.targetId).webSocketDebuggerUrl);await page.send('Page.enable');await page.send('Runtime.enable');await page.send('Network.enable');
 page.socket.addEventListener('message',event=>{const value=JSON.parse(event.data);if(value.method==='Runtime.exceptionThrown')browserErrors.push(value.params.exceptionDetails);if(value.method==='Network.responseReceived'&&value.params.response.status>=400)browserErrors.push({status:value.params.response.status,url:value.params.response.url});});
 for(const [name,width,height,reduced] of [['desktop',1280,900,false],['phone',422,984,false],['landscape',844,390,false],['reduced',390,844,true]]){
  await page.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
  await page.send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:reduced?'reduce':'no-preference'}]});
  await page.send('Page.navigate',{url:base+'/debug.html?width=390&height=844'});
  await until('Boolean(window.StarGamesDebugLab&&document.getElementById("controller").contentDocument?.body)');
  await evaluate('document.getElementById("controller").src="/game/debug-fixture/"');
  await until('Boolean(document.getElementById("controller").contentWindow.fixtureReady&&document.getElementById("snapshot-list").options.length)');
  await evaluate(assertions);const result=await evaluate('window.qaResult');console.log(name+': '+JSON.stringify(result));total+=result.checks;
  const screenshot=await page.send('Page.captureScreenshot',{format:'png'});await writeFile(join(output,name+'.png'),Buffer.from(screenshot.data,'base64'));
  if(result.failures)throw Error(result.error);
 }
 // Real public-template scripts register examples through the same interface.
 await evaluate('document.getElementById("controller").src="/game/replace-with-game-id/"');
 await until('[...document.getElementById("scenario-list").options].some(item=>item.textContent==="Public ranked results")');
 if(!await evaluate('document.getElementById("snapshot-list").options.length===0&&!document.getElementById("controller").inert'))throw Error('Navigation retained private history or preview input lock');total++;
 await evaluate('const choices=document.getElementById("scenario-list");choices.value=[...choices.options].find(item=>item.textContent==="Public ranked results").value;choices.dispatchEvent(new Event("change"));document.getElementById("scenario-preview").click()');
 await delay(400);
 if(!await evaluate('(()=>{const element=document.getElementById("controller").contentDocument.getElementById("example-ranked-results"),rect=element.getBoundingClientRect();return !element.hidden&&rect.height>0&&rect.top>=0&&rect.bottom<=844;})()'))throw Error('Template scenario failed or remained outside the preview');total++;
 const templateCapture=await page.send('Page.captureScreenshot',{format:'png'});await writeFile(join(output,'template.png'),Buffer.from(templateCapture.data,'base64'));
 // Ordinary phones do not attach debug hooks and keep normal SDK input behavior.
 await page.send('Page.navigate',{url:base+'/game/debug-fixture/'});await until('Boolean(window.fixtureReady)');
 if(!await evaluate('ctrl.debugLab===null'))throw Error('Standalone controller attached a debug bridge');total++;
 if(!await evaluate('(()=>{const before=sent.length;ctrl.send({action:"normal"});return sent.length===before+1;})()'))throw Error('Standalone controller input changed');total++;
 console.log('Debug Lab controllers: '+total+' checks, 0 failures');
} finally {
 page?.socket.close();
 if(browser){await browser.send('Browser.close').catch(()=>{});browser.socket.close();}else child?.kill();
 await writeFile(join(output,'stop'),'stop');
 for(let attempt=0;attempt<30&&host.exitCode===null;attempt++)await delay(100);
 if(host.exitCode===null)host.kill();
 await writeFile(join(output,'host.log'),hostLog);
 await writeFile(join(output,'browser-errors.json'),JSON.stringify(browserErrors,null,2));
}
