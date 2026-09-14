import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
import {createRelay} from '../server.mjs';

test('all reward art and stylesheet are served through explicit routes', async () => {
  const relay = createRelay(); await new Promise(r => relay.http.listen(0,'127.0.0.1',r));
  const base = `http://127.0.0.1:${relay.http.address().port}`;
  try {
    for (const key of ['stitch','spark','stride','charge','guard','mend']) {
      const response = await fetch(`${base}/boons/${key}.png`);
      assert.equal(response.status,200);assert.equal(response.headers.get('content-type'),'image/png');
      const data = Buffer.from(await response.arrayBuffer());assert.equal(data.subarray(1,4).toString(),'PNG');
    }
    assert.equal((await fetch(`${base}/reward.css`)).status,200);
    assert.equal((await fetch(`${base}/boons/unknown.png`)).status,404);
  } finally {await relay.close();}
});

test('phone retains selected gift, sends reselection and cancellation, then clears next wave', async () => {
  class Element {
    children=[];style={};attrs={};textContent='';value='ABC234';classList={toggle(){}};
    append(...children){this.children.push(...children);}replaceChildren(){this.children=[];}
    setAttribute(k,v){this.attrs[k]=v;}
    getContext(){return new Proxy({},{get:()=>()=>{}});}
  }
  const elements = new Map();const get=id=>{if(!elements.has(id))elements.set(id,new Element());return elements.get(id);};
  let socket;
  class Socket {static OPEN=1;readyState=1;sent=[];constructor(){socket=this;}send(data){this.sent.push(JSON.parse(data));}}
  const context = {document:{getElementById:get,createElement:()=>new Element()},WebSocket:Socket,location:{protocol:'http:',host:'localhost'},performance:{now:()=>0},console};
  vm.runInNewContext(await readFile(new URL('../public/controller.js',import.meta.url),'utf8'),context);
  get('connect').onclick();socket.onmessage({data:JSON.stringify({type:'joined',slots:[1]})});
  const players=[0,1].map(id=>({id,x:0,z:0,hp:4,max_hp:4,ready:false,reward:false,reward_choice:-1,charges:2,statuses:{}}));
  const state={phase:'reward',wave:1,turn:4,timer:0,reward_options:['stitch','spark','guard'],players,enemies:[]};
  const update=()=>socket.onmessage({data:JSON.stringify({type:'snapshot',state})});
  update();assert.equal(get('choices').children.length,3);
  const button=get('choices').children[1];button.onclick();assert.equal(socket.sent.at(-1).slot,1);assert.equal(socket.sent.at(-1).data.choice,1);
  players[1].reward=true;players[1].reward_choice=1;update();
  assert.equal(get('choices').children[1],button);assert.equal(button.attrs['aria-pressed'],'true');
  get('choices').children[0].onclick();assert.equal(socket.sent.at(-1).data.choice,0);
  get('cancel-reward').onclick();assert.equal(socket.sent.at(-1).data.action,'cancel');
  players[0].reward=true;state.timer=1.6;update();assert.match(get('reward-status').textContent,/Все готовы/);
  state.phase='plan';state.wave=2;update();assert.equal(get('choices').children.length,0);
  socket.onclose();assert.equal(get('pad').style.display,'none');
});
