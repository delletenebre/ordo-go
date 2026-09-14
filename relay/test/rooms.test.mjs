import test from 'node:test';
import assert from 'node:assert/strict';
import { WebSocket } from 'ws';
import { createRelay } from '../server.mjs';
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
    const joined = await host.wait('joined'); assert.match(joined.code, /^[A-Z2-9]{6}$/); assert.deepEqual(joined.slots, [0]);
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
