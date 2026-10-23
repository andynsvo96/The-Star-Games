// Synthetic offline skin/reconnect regression using the real controller SDK.
import {createServer} from 'node:http';
import {readFile, mkdir, writeFile} from 'node:fs/promises';
import {resolve, join} from 'node:path';
import {spawn} from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const output = join(root, '.test_data', 'skin-controller');
const chrome = process.argv[2] || process.env.CHROME_BIN || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const sdk = await readFile(join(root, 'web/controller-sdk.js'));

const assertions = `
(async () => {
 let checks = 0;
 const check = (ok, text) => { checks++; if (!ok) throw new Error(text); };
 const settle = async () => { for (let i=0;i<10;i++) await new Promise(requestAnimationFrame); };
 class Socket {
  static OPEN = 1;
  constructor() { this.readyState=1; this.listeners={}; window.qaSocket=this; }
  addEventListener(kind, fn) { this.listeners[kind]=fn; }
  send(value) { (this.sent ||= []).push(JSON.parse(value)); }
  deliver(message) { this.listeners.message({data:JSON.stringify(message)}); }
 }
 window.WebSocket=Socket;
 try {
  let received=0;
  const controller = new StarGamesController('skin-fixture', {message:payload => {
   check(controller.themeRevision === payload.theme.revision, 'Revision is applied before the module renders its snapshot');
   received++;
  }});
  controller.connect();
  const publish = revision => qaSocket.deliver({type:'game',game_id:'skin-fixture',payload:{type:'state',theme:{id:revision,name:'Literal <Skin>',revision,labels:{}},hand:['own-card']}});
  publish('blue');
  await settle();
  check(controller.themeRevision==='blue' && received===1, 'Initial private state restores the host skin');
  check(document.querySelector('.game-background-layer img')?.naturalWidth===24, 'Skin artwork loads from a local source');
  const generation=controller.background.generation;
  publish('blue'); await settle();
  check(controller.background.generation===generation, 'Duplicate snapshots do not reload or restart background artwork');
  check(received===2, 'Duplicate snapshots still reach the game handler');
  publish('default'); await settle();
  check(controller.themeRevision==='default' && controller.background.generation>generation, 'Returning to Default reloads its offline artwork');
  check(!document.querySelector('skin'), 'Skin names never become markup');
  controller.connect();
  qaSocket.deliver({type:'joined',game_id:'skin-fixture',player:{display_name:'Player',color:'#2463eb'},reconnect_token:'fixture'});
  publish('default'); await settle();
  check(controller.themeRevision==='default' && received===4, 'Reconnect restores the same pinned host revision');
  controller.background.setVariant('',false,true); await settle();
  check(controller.background.hostReduced, 'Host reduced motion remains active with a skin');
  check(document.querySelectorAll('.game-background-layer').length===1, 'Skin reloads clean up earlier background layers');
  check(!document.querySelector('[title]'), 'Skin support adds no hover tooltips');
  window.qaResult={checks,failures:0};
 } catch(error) { window.qaResult={checks,failures:1,error:String(error.stack||error)}; }
})();`;
const html = '<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body><main class="game-controller"><h1>Fixture</h1></main><script src="/controller-sdk.js"></script><script>' + assertions + '</script></body></html>';
const server = createServer((req,res) => {
 const path=new URL(req.url,'http://localhost').pathname;
 res.setHeader('Cache-Control','no-store');
 if(path==='/') {res.setHeader('Content-Type','text/html');res.end(html);}
 else if(path==='/controller-sdk.js') {res.setHeader('Content-Type','application/javascript');res.end(sdk);}
 else if(path==='/game/skin-fixture/background.json') {res.setHeader('Content-Type','application/json');res.end(JSON.stringify({image:'/game/skin-fixture/art/background.svg',videos:[]}));}
 else if(path==='/game/skin-fixture/art/background.svg') {res.setHeader('Content-Type','image/svg+xml');res.end('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><rect width="24" height="24" fill="#17354b"/></svg>');}
 else {res.writeHead(404);res.end();}
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
await mkdir(output,{recursive:true});

async function protocol(url) {
 const socket=new WebSocket(url), pending=new Map(); let id=0;
 socket.addEventListener('message',event=>{const message=JSON.parse(event.data),request=pending.get(message.id);if(request){pending.delete(message.id);message.error?request.reject(Error(JSON.stringify(message.error))):request.resolve(message.result);}});
 await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
 return {socket,send(method,params={}) {return new Promise((resolve,reject)=>{pending.set(++id,{resolve,reject});socket.send(JSON.stringify({id,method,params}));});}};
}

const child=spawn(chrome,['--headless=new','--no-sandbox','--disable-gpu','--remote-debugging-port=0','--user-data-dir='+join(output,'profile-'+Date.now()),'about:blank'],{stdio:['ignore','ignore','pipe']});
let browser,page,timer,checks=0,failures=0;
try {
 const ready=new Promise((resolve,reject)=>{let text='';child.stderr.on('data',chunk=>{text+=chunk;const match=text.match(/DevTools listening on (ws:\/\/[^\s]+)/);if(match)resolve(match[1]);});child.on('error',reject);child.on('exit',code=>reject(Error('Chromium exited: '+code)));});
 const endpoint=await Promise.race([ready,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Chromium did not start')),15000);})]);clearTimeout(timer);
 browser=await protocol(endpoint);
 const target=await browser.send('Target.createTarget',{url:'about:blank'});
 const tabs=await(await fetch('http://127.0.0.1:'+new URL(endpoint).port+'/json/list')).json();
 page=await protocol(tabs.find(tab=>tab.id===target.targetId).webSocketDebuggerUrl);await page.send('Page.enable');
 for(const [name,width,height,reduced] of [['portrait',390,844,false],['landscape',844,390,false],['reduced',390,844,true]]) {
  await page.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
  await page.send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:reduced?'reduce':'no-preference'}]});
  await page.send('Page.navigate',{url:'http://127.0.0.1:'+server.address().port+'/'});
  let result;
  for(let attempt=0;attempt<100;attempt++){await delay(50);const response=await page.send('Runtime.evaluate',{expression:'window.qaResult',returnByValue:true});result=response.result.value;if(result)break;}
  if(!result)throw Error(name+': assertions did not finish');
  checks+=result.checks;failures+=result.failures;console.log(name+': '+JSON.stringify(result));
  const screenshot=await page.send('Page.captureScreenshot',{format:'png'});await writeFile(join(output,name+'.png'),Buffer.from(screenshot.data,'base64'));
 }
} finally {
 clearTimeout(timer);page?.socket.close();
 if(browser){await browser.send('Browser.close').catch(()=>{});browser.socket.close();}else child.kill();
 await new Promise(resolve=>server.close(resolve));
}
console.log('Skin controllers: '+checks+' checks, '+failures+' failures');
if(failures)process.exitCode=1;
