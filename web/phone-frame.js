(() => {
  'use strict';
  if(window!==top){const url=new URL(location.href);url.searchParams.set('sg-phone','1');location.replace(url.href);return;}
  const phone=document.getElementById('phone');
  const destination=new URL(location.href);
  destination.searchParams.set('sg-phone','1');
  phone.src=destination.href;
  function fit() {
    const width=innerWidth,height=innerHeight;
    const touch=matchMedia('(pointer:coarse)').matches;
    const landscape=touch&&screen.orientation ? screen.orientation.type.startsWith('landscape') : width>height;
    const logicalWidth=landscape?844:390,logicalHeight=landscape?390:844;
    const scale=Math.min(width/logicalWidth,height/logicalHeight);
    phone.style.width=logicalWidth+'px';phone.style.height=logicalHeight+'px';
    phone.style.left=(width-logicalWidth*scale)/2+'px';phone.style.top=(height-logicalHeight*scale)/2+'px';
    phone.style.transform='scale('+scale+')';
  }
  addEventListener('resize',fit);screen.orientation?.addEventListener('change',fit);
  phone.addEventListener('load',()=>{
    try {
      const page=phone.contentWindow;
      document.title=page.document.title||'The Star Games Controller';
      const url=new URL(page.location.href);url.searchParams.delete('sg-phone');
      history.replaceState(null,'',url.pathname+url.search+url.hash);
    } catch (_) { /* Navigation remains owned by the controller SDK. */ }
  });
  fit();
})();
