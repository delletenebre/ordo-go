import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
import {createRelay} from '../server.mjs';
import { ROOM_PATTERN, normalizeCode } from '../public/room-code.js';

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

class Element {
  style={};attrs={};textContent='';value='001234';hidden=false;disabled=false;
  classList={toggle(){}};
  focus(){} setAttribute(k,v){this.attrs[k]=v;}
  setPointerCapture(){}
  getBoundingClientRect(){return {left:0,top:0,width:180,height:180};}
}
async function controller(native=false) {
  const elements=new Map(), listeners=new Map(), timers=[], sockets=[];
  const get=id=>{if(!elements.has(id))elements.set(id,new Element());return elements.get(id);};
  let now=0;
  class Socket {
    static OPEN=1;readyState=1;sent=[];
    constructor(url){this.url=url;sockets.push(this);}send(data){this.sent.push(JSON.parse(data));}close(){}
  }
  const listen=(key,fn)=>listeners.set(key,fn);
  const context={document:{getElementById:get,querySelector:get,body:new Element(),addEventListener:listen},
    window:{addEventListener:listen},setInterval:fn=>timers.push(fn),
    localStorage:{getItem(){},setItem(k,v){context.savedMode=v;}},WebSocket:Socket,
    location:{protocol:'http:',host:'192.168.1.20:8787',hostname:'192.168.1.20'},
    performance:{now:()=>now},console,ROOM_PATTERN,normalizeCode,
    ORDO_CONNECTION:native?{controller:true,websocketPort:8788}:{}};
  const source=(await readFile(new URL('../public/controller.js',import.meta.url),'utf8')).replace(/^import .*;\n/gm,'');
  vm.runInNewContext(source,context);
  const players=[0,1,2,3].map(id=>({id,angle:.7,power:.15,spin:0,hp:4,max_hp:4,ready:false,reward:false,reward_choice:-1,charges:2,statuses:{}}));
  const state={phase:'plan',wave:1,turn:4,timer:10,reward_options:['stitch','spark','guard'],players,controller_slots:{'1':3}};
  const message=msg=>sockets[0].onmessage({data:JSON.stringify(msg)});
  const event=(id=1,x=90,y=90)=>({pointerId:id,clientX:x,clientY:y,preventDefault(){}});
  return {get,context,sockets,state,listeners,event,
    connect(){get('connect').onclick();sockets[0].onopen();message({type:'joined',slots:[1]});},
    update(){message({type:'snapshot',state});},message,
    down(id,pointer=1){get(id).onpointerdown(event(pointer));},up(id,pointer=1){get(id).onpointerup(event(pointer));},
    advance(ms){now+=ms;timers.forEach(fn=>fn());},
    commands(){return sockets[0].sent.filter(m=>m.type==='command');}
  };
}

test('large pad replaces the arena, slider, reward cards and avatar picker', async () => {
  const html=await readFile(new URL('../public/index.html',import.meta.url),'utf8');
  assert.doesNotMatch(html,/<canvas|type="range"|id="(?:avatars|avatar-picker|change-avatar|choices)"/);
  for(const id of ['stick','mode-stick','mode-arrows','up','down','left','right','l1','r1','a','b']) assert.ok(html.includes(`id="${id}"`));
});

test('native phone connects explicitly without code or avatar selection', async () => {
  const c=await controller(true);
  assert.equal(c.sockets.length,0);assert.equal(c.get('code').hidden,true);
  assert.equal(c.get('connect').textContent,'ПОДКЛЮЧИТЬ');
  c.connect();assert.equal(c.sockets[0].url,'ws://192.168.1.20:8788');
  assert.deepEqual(c.sockets[0].sent[0],{type:'join',controller:true,count:1,avatar:'ilbirs'});
  assert.equal(c.get('pad').style.display,'flex');assert.equal(c.get('a').disabled,true);
  c.update();assert.equal(c.get('identity').textContent,'P4');
  c.message({type:'controller_wait'});assert.equal(c.get('pad').style.display,'flex');
  const count=c.commands().length;c.down('a');assert.equal(c.commands().length,count);
  c.sockets[0].onclose();assert.equal(c.get('pad').style.display,'none');
});

test('analog aiming and A charging work with independent fingers; B cancels and shoulders spin', async () => {
  const c=await controller();c.connect();c.update();
  c.get('stick').onpointerdown(c.event(11,145,112));
  c.down('a',22);c.advance(300);
  assert.ok(Math.abs(c.commands().at(-1).data.angle-Math.atan2(22,55))<1e-8);
  assert.ok(Math.abs(c.commands().at(-1).data.power-.575)<1e-8);
  c.get('stick').onpointermove(c.event(11,45,50));c.advance(50);
  assert.ok(Math.abs(c.commands().at(-1).data.angle-Math.atan2(-40,-45))<1e-8);
  c.down('r1',33);assert.ok(c.commands().at(-1).data.spin>0);
  c.down('l1',44);assert.equal(c.commands().at(-1).data.spin,0);
  c.advance(400);c.up('a',22);
  assert.equal(c.commands().at(-2).data.power,1);assert.equal(c.commands().at(-1).data.action,'ready');
  assert.ok(c.commands().every(m=>m.slot===1 && m.data.turn===4));
  c.state.players[3].ready=true;c.update();c.down('b');assert.equal(c.commands().at(-1).data.action,'cancel');
  c.get('stick').onpointerup(c.event(11,45,50));
  assert.equal(c.get('stick-knob').style.transform,'translate(0px, 0px)');
});

test('switching to arrows saves mode, supports diagonals and releases old gestures', async () => {
  const c=await controller();c.connect();c.update();
  c.down('a');c.advance(100);c.get('mode-arrows').onclick();
  assert.equal(c.commands().at(-1).data.action,'cancel');
  assert.equal(c.get('stick').hidden,true);assert.equal(c.get('dpad').hidden,false);assert.equal(c.context.savedMode,'arrows');
  c.down('left',3);c.down('up',4);assert.equal(c.commands().at(-1).data.angle,-3*Math.PI/4);
  c.up('left',3);c.advance(50);assert.equal(c.commands().at(-1).data.angle,-Math.PI/2);
  c.up('a');assert.notEqual(c.commands().at(-1).data.action,'ready');
  c.get('mode-stick').onclick();assert.equal(c.get('stick').hidden,false);assert.equal(c.get('dpad').hidden,true);
});

test('pointer cancellation, backgrounding and new turns never launch a held shot', async () => {
  const c=await controller();c.connect();c.update();
  c.down('a');c.advance(200);c.get('a').onpointercancel(c.event());
  assert.equal(c.commands().at(-1).data.action,'cancel');
  c.down('a');c.advance(200);c.listeners.get('blur')();c.up('a');
  assert.equal(c.commands().filter(m=>m.data.action==='ready').length,0);
  c.down('a');c.state.turn++;c.update();c.up('a');
  assert.equal(c.commands().filter(m=>m.data.action==='ready').length,0);
  c.state.players[3].statuses={frozen:1};c.state.players[3].freeze_turn=c.state.turn;c.update();
  assert.equal(c.get('a').disabled,true);assert.equal(c.get('stick').disabled,true);
  c.state.players[3].freeze_turn++;c.update();assert.equal(c.get('a').disabled,false);
});

test('reward navigation focuses the TV without selecting; A confirms and B cancels', async () => {
  const c=await controller();c.connect();c.state.phase='reward';c.update();
  c.down('right');c.up('right');
  assert.deepEqual(c.commands().at(-1).data,{action:'reward_focus',turn:4,choice:1});
  c.down('a');c.up('a');assert.equal(c.commands().at(-1).data.action,'reward');assert.equal(c.commands().at(-1).data.choice,1);
  c.state.players[3].reward=true;c.state.players[3].reward_choice=1;c.update();
  c.get('stick').onpointerdown(c.event(7,145,90));
  assert.equal(c.commands().at(-1).data.choice,2);
  const count=c.commands().length;c.get('stick').onpointermove(c.event(7,155,90));assert.equal(c.commands().length,count);
  c.get('stick').onpointermove(c.event(7,90,90));c.get('stick').onpointermove(c.event(7,35,90));assert.equal(c.commands().at(-1).data.choice,1);
  c.down('b');c.up('b');assert.equal(c.commands().at(-1).data.action,'cancel');
  c.state.turn++;c.state.wave++;c.state.phase='plan';c.update();
  c.down('a');c.advance(300);c.up('a');assert.equal(c.commands().at(-1).data.action,'ready');
});
