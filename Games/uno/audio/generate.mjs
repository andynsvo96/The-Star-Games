// Original deterministic card rustle and short celebratory cues, generated offline.
import {mkdir,writeFile} from 'node:fs/promises';
import {join} from 'node:path';
const rate=22050, root=import.meta.dirname;
await mkdir(root,{recursive:true});
let seed=52471;const noise=()=>{seed=(Math.imul(seed,1664525)+1013904223)|0;return (seed>>>0)/2147483648-1;};
for(const [name,duration] of [['card',.17],['uno',.32],['win',.9]]){
 const count=Math.round(duration*rate),data=Buffer.alloc(44+count*2);
 data.write('RIFF');data.writeUInt32LE(data.length-8,4);data.write('WAVEfmt ',8);data.writeUInt32LE(16,16);data.writeUInt16LE(1,20);data.writeUInt16LE(1,22);data.writeUInt32LE(rate,24);data.writeUInt32LE(rate*2,28);data.writeUInt16LE(2,32);data.writeUInt16LE(16,34);data.write('data',36);data.writeUInt32LE(count*2,40);
 for(let index=0;index<count;index++){
  const t=index/rate,fade=Math.exp(-t*(name==='card'?34:6)),note=name==='win'?[523.25,659.25,783.99][Math.min(2,Math.floor(t/.15))]:660;
  const value=name==='card'?(noise()*.24+Math.sin(t*760)*.12)*fade:(Math.sin(t*note*Math.PI*2)+Math.sin(t*note*Math.PI*4)*.18)*fade*.17;
  data.writeInt16LE(Math.round(Math.max(-1,Math.min(1,value))*32767),44+index*2);
 }
 await writeFile(join(root,name+'.wav'),data);
}
console.log('Generated original offline card, UNO and win cues.');
