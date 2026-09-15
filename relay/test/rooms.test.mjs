import test from 'node:test';
import assert from 'node:assert/strict';
import { WebSocket } from 'ws';
import { createRelay, allocateRoomCode } from '../server.mjs';
import { ROOM_PATTERN, normalizeCode } from '../public/room-code.js';
const sleep = ms => new Promise(r => setTimeout(r, ms));
async function client(url) {
  const ws = new WebSocket(url); const inbox = [];
  ws.on('message', raw => inbox.push(JSON.parse(raw)));
  await new Promise((resolve, reject) => { ws.once('open', resolve); ws.once('error', reject); });
  return { ws, inbox, send: data => ws.send(JSON.stringify(data)), async wait(type) {
    for (let i = 0; i < 300; i++) { const n = inbox.findIndex(m => m.type === type); if (n >= 0) return inbox.splice(n, 1)[0]; await sleep(5); }
    throw new Error(`Timeout waiting for ${type}`);
  } };
}
test('room ownership, two TV snapshots, stale slots, capacity, disconnect', async () => {
  const relay = createRelay(); await new Promise(r => relay.http.listen(0, '127.0.0.1', r));
  const url = `ws://127.0.0.1:${relay.http.address().port}`;
  try {
    const host = await client(url); host.send({ type: 'create', count: 1 });
    const joined = await host.wait('joined'); assert.match(joined.code, ROOM_PATTERN); assert.deepEqual(joined.slots, [0]);
    const tv = await client(url); tv.send({ type: 'join', code: joined.code, count: 2 });
    assert.deepEqual((await tv.wait('joined')).slots, [1, 2]);
    const phone = await client(url); phone.send({ type: 'join', code: joined.code, count: 1 });
    assert.deepEqual((await phone.wait('joined')).slots, [3]);
    const extra = await client(url); extra.send({ type: 'join', code: joined.code, count: 1 });
    assert.match((await extra.wait('error')).message, /мест/);
    tv.send({ type: 'start' }); assert.match((await tv.wait('error')).message, /ведущий/);
    host.send({ type: 'start', difficulty: 2 }); assert.equal((await host.wait('start')).count, 4); await tv.wait('start');
    tv.send({ type: 'command', slot: 0, data: { action: 'ready', turn: 1 } });
    assert.match((await tv.wait('error')).message, /другому/);
    tv.send({ type: 'command', slot: 1, data: { action: 'aim', turn: 1, angle: 1.2, power: 8 } });
    const command = await host.wait('command'); assert.equal(command.data.power, 1); assert.equal(command.slot, 1);
    phone.send({type:'command',slot:3,data:{action:'reward_focus',turn:1,choice:2}});
    assert.deepEqual((await host.wait('command')).data,{action:'reward_focus',turn:1,choice:2});
    phone.send({type:'command',slot:3,data:{action:'reward_focus',turn:1,choice:99}});
    phone.send({type:'command',slot:3,data:{action:'reward_focus',turn:1,choice:1}});
    assert.equal((await host.wait('command')).data.choice,1,'Invalid focus never reaches the host');

    tv.send({ type: 'command', slot: 1, data: { action: 'aim', turn: 1, angle: 1.2, power: .575, spin: -8 } });
    assert.equal((await host.wait('command')).data.spin, -1);
    tv.send({ type: 'command', slot: 1, data: { action: 'aim', turn: 1, angle: 1.2, power: .575, spin: 'invalid' } });
    tv.send({ type: 'command', slot: 1, data: { action: 'aim', turn: 1, angle: 1.2, power: 1, spin: .8 } });
    tv.send({ type: 'command', slot: 1, data: { action: 'ready', turn: 1 } });
    const charged = await host.wait('command'); assert.equal(charged.data.spin, .8); assert.equal(charged.data.power, 1);
    assert.equal((await host.wait('command')).data.action, 'ready');
    const snapshot = { turn: 1, phase: 'plan', fire: 8, players: [{ id: 0, x: 1.3 }], enemies: [] };
    host.send({ type: 'snapshot', state: snapshot }); assert.deepEqual((await tv.wait('snapshot')).state, snapshot); assert.deepEqual((await phone.wait('snapshot')).state, snapshot);
    tv.send({ type: 'snapshot', state: { fire: 0 } }); await sleep(30);
    assert.equal(host.inbox.some(m => m.type === 'snapshot'), false);
    tv.ws.close(); assert.equal((await host.wait('ended')).type, 'ended'); assert.equal(relay.rooms.size, 0);
  } finally { await relay.close(); }
});
test('lobby departures compact slots at start; malformed input rejected', async () => {
  const relay = createRelay(); await new Promise(r => relay.http.listen(0, '127.0.0.1', r));
  const url = `ws://127.0.0.1:${relay.http.address().port}`;
  try {
    const host = await client(url); host.send({ type: 'create', count: 5 }); await host.wait('error');
    host.send({ type: 'create', count: 1 }); const { code } = await host.wait('joined');
    const a = await client(url); a.send({ type: 'join', code, count: 1 }); await a.wait('joined');
    const b = await client(url); b.send({ type: 'join', code, count: 1 }); await b.wait('joined');
    a.ws.close(); await sleep(30); host.send({ type: 'start' });
    assert.equal((await host.wait('start')).count, 2); assert.deepEqual((await b.wait('slots')).slots, [1]);
    const health = await fetch(url.replace('ws:', 'http:') + '/health'); assert.equal((await health.json()).ok, true);
  } finally { await relay.close(); }
});
test('actual local seats and remote joins define the frozen run roster', async () => {
  const relay=createRelay();await new Promise(r=>relay.http.listen(0,'127.0.0.1',r));
  const url=`ws://127.0.0.1:${relay.http.address().port}`;
  try {
    const host=await client(url);host.send({type:'create',count:0});const {code}=await host.wait('joined');
    host.send({type:'start'});assert.match((await host.wait('error')).message,/подключите/);
    host.send({type:'seats',count:1});assert.equal((await host.wait('slots')).slots.length,1);
    const phone=await client(url);phone.send({type:'join',code,count:1});await phone.wait('joined');
    const tv=await client(url);tv.send({type:'join',code,count:0});assert.deepEqual((await tv.wait('joined')).slots,[]);
    host.send({type:'seats',count:3});assert.equal((await host.wait('slots')).slots.length,3);
    tv.send({type:'seats',count:1});assert.deepEqual((await tv.wait('seats_rejected')).slots,[]);
    host.send({type:'seats',count:1});assert.equal((await host.wait('slots')).slots.length,1);
    tv.send({type:'seats',count:1});assert.equal((await tv.wait('slots')).slots.length,1);
    phone.ws.close();await sleep(30);
    host.send({type:'start'});const run=await host.wait('start');assert.equal(run.count,2);assert.equal(run.difficulty,1);
    assert.deepEqual((await host.wait('slots')).slots,[0]);assert.deepEqual((await tv.wait('slots')).slots,[1]);
    tv.send({type:'seats',count:3});assert.match((await tv.wait('error')).message,/зафиксирован/);
    assert.equal([...relay.rooms.get(code).peers.values()].reduce((sum,p)=>sum+p.slots.length,0),2);
  } finally {await relay.close();}
});


test('room codes stay readable, preserve leading zeroes and resolve collisions', () => {
  const rooms = new Map();
  for (let i = 0; i < 260; i++) {
    const code = allocateRoomCode(rooms, () => 0);
    assert.match(code, ROOM_PATTERN); assert.equal(rooms.has(code), false); rooms.set(code, {});
  }
  assert.equal([...rooms.keys()][0], '000000');
  assert.equal(normalizeCode(' 00-0042 '), '000042');
  for (const code of ['12345', '1234567', 'HK1234', '12.345', '-12345']) assert.equal(ROOM_PATTERN.test(code), false);
  assert.equal(allocateRoomCode(new Map([['999999', {}]]), () => 999999), '000000');
  assert.equal(ROOM_PATTERN.test('CO1234'), false);
});

test('avatars survive roster updates and compact slots; formatted codes join', async () => {
  const relay = createRelay(); await new Promise(r => relay.http.listen(0, '127.0.0.1', r));
  const url = `ws://127.0.0.1:${relay.http.address().port}`;
  try {
    const host = await client(url); host.send({ type: 'create', count: 2, avatars: ['manas', 'kanykei'] });
    const { code } = await host.wait('joined');
    assert.deepEqual((await host.wait('roster')).players.map(p => p.avatar), ['manas', 'kanykei']);
    const phone = await client(url);
    phone.send({ type: 'join', code: 'OI1234', avatar: 'ilbirs' });
    assert.match((await phone.wait('error')).message, /шесть цифр/);
    phone.send({ type: 'join', code: `${code.slice(0,2).toLowerCase()} ${code.slice(2)}`, avatar: 'ilbirs' });
    await phone.wait('joined'); await host.wait('roster');
    host.send({ type: 'seats', count: 2, avatars: ['manas', 'bugu'] }); await host.wait('slots');
    assert.deepEqual((await host.wait('roster')).players.map(p => p.avatar), ['manas', 'bugu', 'ilbirs']);
    host.send({ type: 'seats', count: 1 }); await host.wait('slots'); await host.wait('roster');
    host.send({ type: 'start' }); await host.wait('start');
    assert.deepEqual((await host.wait('roster')).players.map(p => [p.slot,p.avatar]), [[0,'manas'],[1,'ilbirs']]);
    assert.equal((await fetch(url.replace('ws:', 'http:')+'/room-code.js')).status, 200);
  } finally { await relay.close(); }
});


test('two TV households own two avatars each and only edit their own slots', async () => {
  const relay = createRelay(); await new Promise(r => relay.http.listen(0,'127.0.0.1',r));
  const url = `ws://127.0.0.1:${relay.http.address().port}`;
  try {
    const host = await client(url); host.send({type:'create',count:2,avatars:['manas','kanykei']});
    const {code} = await host.wait('joined'); await host.wait('roster');
    const tv = await client(url); tv.send({type:'join',code,count:2,avatars:['ilbirs','tulpar']});
    assert.deepEqual((await tv.wait('joined')).slots,[2,3]); await tv.wait('roster');
    assert.deepEqual((await host.wait('roster')).players.map(p=>p.avatar),['manas','kanykei','ilbirs','tulpar']);
    tv.send({type:'avatar',slot:0,avatar:'bakai'}); assert.match((await tv.wait('error')).message,/другого/);
    tv.send({type:'avatar',slot:2,avatar:'../../bad'}); assert.match((await tv.wait('error')).message,/списка/);
    tv.send({type:'avatar',slot:3,avatar:'janyl'});
    assert.equal((await host.wait('roster')).players[3].avatar,'janyl');await tv.wait('roster');
    host.send({type:'start'});assert.equal((await host.wait('start')).count,4);await tv.wait('start');
    tv.send({type:'avatar',slot:3,avatar:'bugu'});assert.match((await tv.wait('error')).message,/началом/);
  } finally { await relay.close(); }
});
