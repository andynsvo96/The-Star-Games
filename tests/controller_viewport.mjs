// Synthetic shared phone-frame regression. No local game modules required.
import {createServer} from 'node:http';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {resolve,join,extname} from 'node:path';
import {spawn} from 'node:child_process';
const root=resolve(import.meta.dirname,'..'),output=join(root,'.test_data','controller-viewport');
const chrome=process.argv[2]||process.env.CHROME_BIN||'C:/Program Files/Google/Chrome/Application/chrome.exe';
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function protocol(url) {
	const socket = new WebSocket(url), requests = new Map();
	let id = 0;
	socket.addEventListener('message', event => {
		const message = JSON.parse(event.data), pending = requests.get(message.id);
		if (pending) {
			requests.delete(message.id);
			message.error ? pending.reject(new Error(JSON.stringify(message.error))) : pending.resolve(message.result);
		}
	});
	await new Promise((resolve, reject) => {
		socket.addEventListener('open', resolve, {once:true});
		socket.addEventListener('error', reject, {once:true});
	});
	return {socket, send(method, params = {}) {
		return new Promise((resolve, reject) => {
			requests.set(++id, {resolve, reject});
			socket.send(JSON.stringify({id, method, params}));
		});
	}};
}

const fixture=`<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/styles.css"></head><body class="playful-game game-modern-table"><main class="game-controller game-top-controller"><h1>Phone controller</h1><button id="tap">Tap target</button><button id="next">Next screen</button><div id="preview"></div><div id="rent"></div></main><script src="/card-ui.js"></script><script>
localStorage.setItem('fixture-player',localStorage.getItem('fixture-player')||'same-player');
document.getElementById('tap').onclick=()=>localStorage.setItem('fixture-taps',String(Number(localStorage.getItem('fixture-taps')||0)+1));
document.getElementById('next').onclick=()=>location.href='/game/synthetic/?screen=next';
const options=[0,1].map(i=>({label:'Player '+i,players:[{display_name:'Player '+i,bank_total:i}],cards:[]}));
window.chosen=-1;document.getElementById('preview').append(StarGamesActionPreview(options,{presentation:'players',selected:-1,onSelect:index=>window.chosen=index}));
document.getElementById('rent').append(StarGamesTableUI.rent('Brown',2,7,[{kind:'house'},{kind:'hotel'}]));
</script></body></html>`;
const server=createServer(async(req,res)=>{try{
 const url=new URL(req.url,'http://localhost');
 if(url.pathname==='/'||url.pathname.startsWith('/game/')){
  res.setHeader('Content-Type','text/html');
  res.end(url.searchParams.get('sg-phone')==='1'||req.headers['sec-fetch-dest']==='iframe'?fixture:await readFile(join(root,'web/phone-frame.html')));return;
 }
 const name=url.pathname.startsWith('/ui/')?url.pathname.slice(1):'web/'+url.pathname.slice(1);
 res.setHeader('Content-Type',({'.js':'application/javascript','.css':'text/css','.svg':'image/svg+xml'})[extname(name)]||'application/octet-stream');res.end(await readFile(join(root,name)));
}catch{res.statusCode=404;res.end();}});
await mkdir(output,{recursive:true});await new Promise(r=>server.listen(0,'127.0.0.1',r));
const child=spawn(chrome,['--headless','--no-sandbox','--disable-gpu','--no-first-run','--disable-background-networking','--remote-debugging-port=0','--user-data-dir='+join(output,'profile-'+process.pid)],{windowsHide:true,stdio:['ignore','ignore','pipe']});
const ready=new Promise((resolve,reject)=>{child.on('error',reject);child.stderr.on('data',data=>{const match=String(data).match(/DevTools listening on (ws:\/\/[^\s]+)/);if(match)resolve(match[1]);});});
let browser,page,checks=0;
const check=(ok,caption)=>{checks++;if(!ok)throw Error(caption);};
try {
 const endpoint=await ready;browser=await protocol(endpoint);const target=await browser.send('Target.createTarget',{url:'about:blank'});
 const tabs=await(await fetch('http://127.0.0.1:'+new URL(endpoint).port+'/json/list')).json();page=await protocol(tabs.find(tab=>tab.id===target.targetId).webSocketDebuggerUrl);await page.send('Page.enable');
 const evaluate=async expression=>(await page.send('Runtime.evaluate',{expression,returnByValue:true})).result.value;
 for(const [width,height] of [[320,568],[390,844],[768,1024],[1920,1080],[3440,1440],[2160,3840],[3840,2160]]){
  await page.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
  await page.send('Page.navigate',{url:'http://127.0.0.1:'+server.address().port+'/?size='+width});
  for(let n=0;n<100;n++){if(await evaluate('Boolean(document.getElementById("phone")?.contentWindow.document.getElementById("tap"))'))break;await delay(30);}
  await delay(80);
  const result=await evaluate(`(()=>{const frame=document.getElementById('phone'),rect=frame.getBoundingClientRect(),child=frame.contentWindow;return{viewport:[child.innerWidth,child.innerHeight],rect:rect.toJSON(),frames:document.querySelectorAll('iframe').length,childFrames:child.document.querySelectorAll('iframe').length,overflow:child.document.documentElement.scrollWidth>child.innerWidth,selected:child.document.querySelectorAll('.game-preview-player-choice.is-selected').length,bonus:child.document.querySelector('.game-rent-bonus')?.textContent,icons:child.document.querySelectorAll('.game-building-icon').length};})()`);
  const portrait=height>=width,w=portrait?390:844,h=portrait?844:390;
  check(result.viewport[0]===w&&result.viewport[1]===h,width+' keeps a phone layout viewport at unlimited output resolution');
  check(Math.abs(result.rect.width/result.rect.height-w/h)<.001&&Math.abs(result.rect.x*2+result.rect.width-width)<1,width+' fits and centers the phone ratio');
  check(result.rect.right<=width+1&&result.rect.bottom<=height+1&&!result.overflow,width+' has no clipping or sideways page overflow');
  check(result.frames===1&&result.childFrames===0,'Controllers have exactly one frame');
  check(result.selected===0&&result.bonus==='+ $7'&&result.icons===2,'Explicit choices start empty and rent shows the separate upgrade bonus');
  const position=await evaluate(`(()=>{const frame=document.getElementById('phone'),rect=frame.getBoundingClientRect(),button=frame.contentWindow.document.getElementById('tap').getBoundingClientRect(),scale=rect.width/frame.contentWindow.innerWidth;return{x:rect.left+(button.left+button.width/2)*scale,y:rect.top+(button.top+button.height/2)*scale,before:Number(frame.contentWindow.localStorage.getItem('fixture-taps')||0)};})()`);
  await page.send('Input.dispatchMouseEvent',{type:'mousePressed',x:position.x,y:position.y,button:'left',clickCount:1});await page.send('Input.dispatchMouseEvent',{type:'mouseReleased',x:position.x,y:position.y,button:'left',clickCount:1});
  check(await evaluate('Number(document.getElementById("phone").contentWindow.localStorage.getItem("fixture-taps"))')===position.before+1,'Scaled input reaches the correct phone control');
  await evaluate('document.getElementById("phone").contentWindow.document.getElementById("next").click()');await delay(150);
  check(await evaluate('location.pathname==="/game/synthetic/"&&document.getElementById("phone").contentWindow.document.querySelectorAll("iframe").length===0'),'SDK-style navigation updates the address without nesting frames');
  await page.send('Page.reload');await delay(180);
  check(await evaluate('document.getElementById("phone").contentWindow.localStorage.getItem("fixture-player")==="same-player"'),'Refresh preserves controller identity in the same origin');
  if(width<=1920){const png=await page.send('Page.captureScreenshot',{format:'png'});await writeFile(join(output,width+'x'+height+'.png'),Buffer.from(png.data,'base64'));}
  console.log(width+'x'+height+': passed');
 }
} finally {page?.socket.close();if(browser){await browser.send('Browser.close').catch(()=>{});browser.socket.close();}else child.kill();await new Promise(r=>server.close(r));}
console.log('Controller viewport browser: '+checks+' checks, 0 failures');
