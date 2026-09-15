import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
import {createRelay} from '../server.mjs';
import { ROOM_PATTERN, normalizeCode } from '../public/room-code.js';
import { AVATARS, avatarId } from '../public/avatars.js';

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
    children=[];style={};attrs={};dataset={};textContent='';value='001234';classList={toggle(){}};
    addEventListener(){} focus(){}
    append(...children){this.children.push(...children);}replaceChildren(){this.children=[];}
    setAttribute(k,v){this.attrs[k]=v;}
    getContext(){return new Proxy({},{get:()=>()=>{}});}
  }
  const elements = new Map();const get=id=>{if(!elements.has(id))elements.set(id,new Element());return elements.get(id);};
  let socket;
  class Socket {static OPEN=1;readyState=1;sent=[];constructor(){socket=this;}send(data){this.sent.push(JSON.parse(data));}}
  const context = {document:{getElementById:get,createElement:()=>new Element()},WebSocket:Socket,location:{protocol:'http:',host:'localhost'},performance:{now:()=>0},console};
  Object.assign(context, { ROOM_PATTERN, normalizeCode, AVATARS, avatarId });
  const source = (await readFile(new URL('../public/controller.js',import.meta.url),'utf8')).replace(/^import .*;\n/gm, '');
  vm.runInNewContext(source,context);
  assert.equal(get('avatars').children.length,12);
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
  // A phone's local hub slot may address P4 after its TV joins another TV.
  state.players.push(...[2,3].map(id=>({...players[0],id})));
  state.controller_slots={'1':3};update();
  get('ability').onclick();assert.equal(socket.sent.at(-1).slot,1);
  assert.match(get('identity').textContent,/P4/);
  // Host-owned freeze applies to the mapped player, including the next-turn warning.
  const mapped = state.players[3];
  mapped.statuses = { frozen: 1 }; mapped.freeze_turn = state.turn + 1; mapped.ready = false;
  state.pickups = [{id:900,kind:'element',element:'fire',x:2,z:1}]; update();
  assert.equal(get('ready').disabled,false); assert.match(get('hint').textContent,/следующего броска/);
  state.turn += 1; mapped.ready = true; update();
  assert.equal(get('ready').disabled,true); assert.equal(get('ability').disabled,true); assert.equal(get('power').disabled,true);
  assert.match(get('ready').textContent,/ПРОПУСК БРОСКА/);
  mapped.statuses = {}; mapped.ready = false; state.turn += 1; update();
  assert.equal(get('ready').disabled,false); assert.equal(get('power').disabled,false);
  socket.onmessage({data:JSON.stringify({type:'controller_wait'})});
  assert.equal(get('pad').style.display,'block');assert.equal(get('change-avatar').hidden,false);
  const before=socket.sent.length;get('ready').onclick();assert.equal(socket.sent.length,before);
  socket.onclose();assert.equal(get('pad').style.display,'none');
});

test('native phone requires Connect click, then joins without a room code', async () => {
  class Element {
    children=[];style={};attrs={};dataset={};textContent='';value='';hidden=false;classList={toggle(){}};
    focus(){} append(...children){this.children.push(...children);}replaceChildren(){this.children=[];}
    setAttribute(k,v){this.attrs[k]=v;}
    getContext(){return new Proxy({},{get:()=>()=>{}});}
  }
  const elements=new Map();
  const get=id=>{if(!elements.has(id))elements.set(id,new Element());return elements.get(id);};
  const sockets=[];
  class Socket {
    static OPEN=1;readyState=1;sent=[];
    constructor(url){this.url=url;sockets.push(this);}send(data){this.sent.push(JSON.parse(data));}
  }
  const context={document:{getElementById:get,querySelector:get,createElement:()=>new Element()},WebSocket:Socket,
    location:{protocol:'http:',host:'192.168.1.20:8787',hostname:'192.168.1.20'},
    performance:{now:()=>0},console,ROOM_PATTERN,normalizeCode,AVATARS,avatarId,
    ORDO_CONNECTION:{controller:true,websocketPort:8788}};
  const source=(await readFile(new URL('../public/controller.js',import.meta.url),'utf8')).replace(/^import .*;\n/gm,'');
  vm.runInNewContext(source,context);
  assert.equal(sockets.length,0,'Opening the page must not occupy a player slot');
  assert.equal(get('code').hidden,true);assert.equal(get('code-label').hidden,true);
  assert.equal(get('connect').textContent,'ПОДКЛЮЧИТЬ');
  get('connect').onclick();assert.equal(sockets.length,1);
  const socket=sockets[0];assert.equal(socket.url,'ws://192.168.1.20:8788');
  socket.onopen();assert.deepEqual(socket.sent[0],{type:'join',controller:true,count:1,avatar:'ilbirs'});
  socket.onmessage({data:JSON.stringify({type:'joined',code:'4827',slots:[1]})});
  socket.onmessage({data:JSON.stringify({type:'roster',code:'4827',started:false,players:[{slot:1,avatar:'ilbirs',name:'Илбирс'}]})});
  assert.equal(get('join').style.display,'none');assert.equal(get('pad').style.display,'block');
  assert.doesNotMatch(get('status').textContent,/4827/);
});
