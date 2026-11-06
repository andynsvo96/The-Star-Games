// Synthetic shared interaction checks; no installed game modules or game assets.
import {createServer} from 'node:http';
import {readFile,mkdir} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import {spawn} from 'node:child_process';
const root=resolve(import.meta.dirname,'..'),output=join(root,'.test_data/board-piece-drag');
const chrome=process.argv[2]||process.env.CHROME_BIN||'C:/Program Files/Google/Chrome/Application/chrome.exe';
const source=await readFile(join(root,'web/board-ui.js'),'utf8');
const html=`<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/styles.css"><style>body{margin:0}#surface{display:flex;gap:80px;width:280px;height:120px;margin:16px}#surface button{flex:none;width:64px;height:64px;margin:0}</style><main class="game-board-ui"><div id="surface"><button data-piece-drag>A</button><button>B</button></div></main><script>${source}</script><script>
window.qaRevision=0;window.qaEnabled=true;window.qaMoves=[];window.qaClicks=0;
const surface=document.querySelector('#surface'),cells=[...surface.children];
cells[0].addEventListener('click',()=>qaClicks++);
window.qaDrag=new StarGamesPieceDrag(surface,{
 hitTest:(x,y)=>cells.findIndex(cell=>{const r=cell.getBoundingClientRect();return x>=r.left&&x<r.right&&y>=r.top&&y<r.bottom;}),
 canStart:cell=>qaEnabled&&cell===0,revision:()=>qaRevision,
 createPreview:()=>{const preview=document.createElement('div');preview.textContent='A';Object.assign(preview.style,{width:'44px',height:'44px'});return preview;},
 onStart:cell=>cells[cell].style.visibility='hidden',onEnd:cell=>cells[cell].style.visibility='',
 onDrop:(from,to)=>{if(from===0&&to===1){qaMoves.push({from,to});qaRevision++;}}
});window.qaReady=true;
</script>`;
const server=createServer(async(req,res)=>{try{res.writeHead(200,{'Content-Type':req.url==='/styles.css'?'text/css':'text/html'});res.end(req.url==='/styles.css'?await readFile(join(root,'web/styles.css')):html);}catch{res.writeHead(404);res.end();}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));await mkdir(output,{recursive:true});
const child=spawn(chrome,['--headless','--no-sandbox','--disable-gpu','--no-first-run','--disable-background-networking','--remote-debugging-port=0',`--user-data-dir=${join(output,'profile-'+process.pid)}`],{windowsHide:true,stdio:['ignore','ignore','pipe']});
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function protocol(url){const socket=new WebSocket(url),pending=new Map();let id=0;socket.addEventListener('message',e=>{const m=JSON.parse(e.data),p=pending.get(m.id);if(p){pending.delete(m.id);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}});await new Promise((r,j)=>{socket.addEventListener('open',r,{once:true});socket.addEventListener('error',j,{once:true});});return {socket,send:(method,params={})=>new Promise((resolve,reject)=>{pending.set(++id,{resolve,reject});socket.send(JSON.stringify({id,method,params}));})};}
let browser,timer,failed=false;
try{
 const endpoint=await Promise.race([new Promise((r,j)=>{child.on('error',j);child.stderr.on('data',b=>{const m=String(b).match(/DevTools listening on (ws:\/\/[^\s]+)/);if(m)r(m[1]);});}),new Promise((_,j)=>{timer=setTimeout(()=>j(Error('Chrome did not start')),15000);})]);clearTimeout(timer);browser=await protocol(endpoint);
 const target=await browser.send('Target.createTarget',{url:'about:blank'}),tabs=await(await fetch(`http://127.0.0.1:${new URL(endpoint).port}/json/list`)).json(),page=await protocol(tabs.find(t=>t.id===target.targetId).webSocketDebuggerUrl);await page.send('Page.enable');
 const evaluate=async expression=>{const r=await page.send('Runtime.evaluate',{expression,returnByValue:true});if(r.exceptionDetails)throw Error(r.exceptionDetails.text);return r.result.value;};
 const mouse=(type,p,pressed=false)=>page.send('Input.dispatchMouseEvent',{type,x:p.x,y:p.y,button:type==='mouseMoved'?'none':'left',buttons:pressed?1:0,clickCount:type==='mouseMoved'?0:1});
 for(const [name,width,height,reduced] of [['portrait',390,844,false],['small',320,568,false],['landscape',844,390,false],['reduced',390,844,true]]){
  let checks=0;const check=(ok,text)=>{checks++;if(!ok)throw Error(text);};
  try{
   await page.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});await page.send('Emulation.setTouchEmulationEnabled',{enabled:true});await page.send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:reduced?'reduce':'no-preference'}]});await page.send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/`});
   for(let attempt=0;attempt<100;attempt++){if(await evaluate('window.qaReady'))break;await delay(20);}await delay(50);
   const points=await evaluate('[...document.querySelectorAll("#surface button")].map(e=>{const r=e.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};})'),[from,to]=points;
   await mouse('mousePressed',from,true);await mouse('mouseReleased',from);
   check(await evaluate('qaClicks===1&&qaMoves.length===0'),'Normal clicks retain their existing action');
   const begin=async()=>{await mouse('mouseMoved',from);await mouse('mousePressed',from,true);await mouse('mouseMoved',to,true);};
   await begin();check(await evaluate('!!document.querySelector(".game-piece-drag-preview")&&document.querySelector("#surface button").style.visibility==="hidden"'),'Drag lifts one preview and hides its static piece');
   const rect=await evaluate('document.querySelector(".game-piece-drag-preview").getBoundingClientRect().toJSON()');check(Math.abs(rect.x+rect.width/2-to.x)<1&&Math.abs(rect.y+rect.height/2-to.y)<1,'Preview follows the pointer');
   await mouse('mouseReleased',to);check(await evaluate('qaMoves.length===1&&qaMoves[0].from===0&&qaMoves[0].to===1&&qaClicks===1&&!document.querySelector(".game-piece-drag-preview")'),'One drop submits once without a follow-up click');
   await begin();await mouse('mouseMoved',{x:310,y:200},true);await mouse('mouseReleased',{x:310,y:200});check(await evaluate('qaMoves.length===1&&!qaDrag.gesture'),'Outside drops cancel');
   for(const [expression,caption] of [['qaEnabled=false;qaDrag.validate()','Pause'],['qaRevision++;qaDrag.validate()','Stale revision'],['window.dispatchEvent(new Event("resize"))','Reflow'],['window.dispatchEvent(new Event("blur"))','Focus loss']]){
    await evaluate('qaEnabled=true');await begin();await evaluate(expression);await mouse('mouseReleased',to);check(await evaluate('qaMoves.length===1&&!qaDrag.gesture&&!document.querySelector(".game-piece-drag-preview")'),caption+' cancels without a move');
   }
   await evaluate('qaEnabled=true');
   await page.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[from]});await page.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[to]});check(await evaluate('!!qaDrag.gesture?.dragging'),'Touch can lift a piece');await page.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});check(await evaluate('qaMoves.length===2&&qaClicks===1'),'Touch release submits once');
   await page.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[from]});await page.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[to]});await page.send('Input.dispatchTouchEvent',{type:'touchCancel',touchPoints:[]});check(await evaluate('qaMoves.length===2&&!qaDrag.gesture'),'Canceled touch cannot move a piece');
   const beforeKey=await evaluate('qaClicks');await evaluate('document.querySelector("#surface button").focus()');await page.send('Input.dispatchKeyEvent',{type:'keyDown',key:'Enter',code:'Enter',windowsVirtualKeyCode:13,text:'\r',unmodifiedText:'\r'});await page.send('Input.dispatchKeyEvent',{type:'keyUp',key:'Enter',code:'Enter',windowsVirtualKeyCode:13});check(await evaluate('qaClicks')===beforeKey+1,'Keyboard activation remains available: '+JSON.stringify(await evaluate('({clicks:qaClicks,focus:document.activeElement.outerHTML})')));
   console.log(name+': '+JSON.stringify({checks,failures:0}));
  }catch(error){failed=true;console.log(name+': '+JSON.stringify({checks,failures:1,error:String(error)}));}
 }
 page.socket.close();
}finally{clearTimeout(timer);if(browser){await browser.send('Browser.close').catch(()=>{});browser.socket.close();}else child.kill();await new Promise(r=>server.close(r));}
if(failed)process.exitCode=1;
