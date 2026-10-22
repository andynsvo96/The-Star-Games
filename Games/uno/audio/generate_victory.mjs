// Original warm bell fanfare, generated offline; no card foley in this cue.
import {writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';
const rate=48000,duration=1.65,count=Math.round(rate*duration);
const notes=[[0,523.25,.8],[.13,659.25,.8],[.26,783.99,.8],[.43,1046.5,1],[.43,659.25,.35],[.43,783.99,.35]];
const samples=Array.from({length:count},(_,index)=>{
 const time=index/rate;
 return notes.reduce((sum,[start,pitch,gain])=>{
  const t=time-start;if(t<0)return sum;
  const envelope=(1-Math.exp(-t*220))*Math.exp(-t*4.5);
  return sum+gain*envelope*(Math.sin(t*pitch*2*Math.PI)+.28*Math.sin(t*pitch*4*Math.PI)*Math.exp(-t*4)+.09*Math.sin(t*pitch*6*Math.PI)*Math.exp(-t*8));
 },0)*Math.min(1,(duration-time)/.12);
});
const peak=Math.max(...samples.map(Math.abs).slice(0,48000),...samples.map(Math.abs).slice(48000));
const data=Buffer.alloc(44+count*2);
data.write('RIFF');data.writeUInt32LE(data.length-8,4);data.write('WAVEfmt ',8);data.writeUInt32LE(16,16);data.writeUInt16LE(1,20);data.writeUInt16LE(1,22);data.writeUInt32LE(rate,24);data.writeUInt32LE(rate*2,28);data.writeUInt16LE(2,32);data.writeUInt16LE(16,34);data.write('data',36);data.writeUInt32LE(count*2,40);
samples.forEach((value,index)=>data.writeInt16LE(Math.round(value/peak*.8*32767),44+index*2));
await writeFile(resolve(import.meta.dirname,'../../../asset/uno/audio/victory-source.wav'),data);
