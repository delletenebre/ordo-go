import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { randomInt, randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { WebSocketServer, WebSocket } from 'ws';

export function createRelay({ maxRooms = 250 } = {}) {
  const rooms = new Map();
  const http = createServer(async (req, res) => {
    if (req.url === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ ok: true, rooms: rooms.size }));
    }
    const pathname = new URL(req.url, 'http://localhost').pathname;
    const files = { '/': 'index.html', '/controller.js': 'controller.js' };
    for (const key of ['stitch','spark','stride','charge','guard','mend']) files[`/boons/${key}.png`] = `../../assets/boons/${key}.png`;
    files['/reward.css'] = 'reward.css';
    if (!files[pathname]) { res.writeHead(404); return res.end('Not found'); }
    try {
      const content = await readFile(new URL(`./public/${files[pathname]}`, import.meta.url));
      res.writeHead(200, { 'Content-Type': pathname.endsWith('.png') ? 'image/png' : pathname.endsWith('.css') ? 'text/css; charset=utf-8' : pathname.endsWith('.js') ? 'text/javascript; charset=utf-8' : 'text/html; charset=utf-8', 'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'no-referrer' });
      res.end(content);
    } catch { res.writeHead(500); res.end('Unavailable'); }
  });
  const wss = new WebSocketServer({ server: http, maxPayload: 262144, perMessageDeflate: false });
  const send = (peer, msg) => {
    if (peer.readyState === WebSocket.OPEN && peer.bufferedAmount < 524288) peer.send(JSON.stringify(msg));
  };
  const broadcast = (room, msg, exclude) => {
    for (const peer of room.peers.values()) if (peer !== exclude) send(peer, msg);
  };
  const roster = room => ({ type: 'roster', code: room.code, started: room.started,
    players: [...room.peers.values()].flatMap(p => p.slots.map(slot => ({ slot, name: p.name, owner: p.id, host: p === room.host }))) });
  const error = (peer, text) => send(peer, { type: 'error', message: text });
  const clean = peer => {
    const room = rooms.get(peer.room);
    if (!room) return;
    if (peer === room.host || room.started) {
      broadcast(room, { type: 'ended', message: peer === room.host ? 'Ведущий отключился. Создайте новую комнату.' : 'Игрок отключился. Матч остановлен; соберите комнату заново.' }, peer);
      for (const p of room.peers.values()) p.room = null;
      rooms.delete(room.code);
    } else {
      room.peers.delete(peer.id);
      broadcast(room, roster(room));
    }
    peer.room = null;
  };
  wss.on('connection', peer => {
    peer.id = randomUUID(); peer.slots = []; peer.alive = true; peer.windowStart = Date.now(); peer.messages = 0;
    peer.on('error', () => {});
    peer.on('pong', () => { peer.alive = true; });
    peer.on('message', (raw, binary) => {
      if (binary) return error(peer, 'Ожидается JSON.');
      if (Date.now() - peer.windowStart > 1000) { peer.windowStart = Date.now(); peer.messages = 0; }
      if (++peer.messages > 100) return peer.close(1008, 'Rate limit');
      let msg;
      try { msg = JSON.parse(raw.toString()); } catch { return error(peer, 'Некорректное сообщение.'); }
      if (!msg || typeof msg !== 'object' || Array.isArray(msg)) return;
      if (msg.type === 'leave') return clean(peer);
      if (msg.type === 'create' || msg.type === 'join') {
        if (peer.room) return error(peer, 'Вы уже в комнате.');
        const count = msg.count ?? 1;
        if (!Number.isInteger(count) || count < 1 || count > 4) return error(peer, 'Нужно от 1 до 4 игроков.');
        let room;
        if (msg.type === 'create') {
          if (rooms.size >= maxRooms) return error(peer, 'Сервер заполнен.');
          let code;
          do { code = Array.from({ length: 6 }, () => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[randomInt(32)]).join(''); } while (rooms.has(code));
          room = { code, host: peer, peers: new Map(), started: false, snapshot: null };
          rooms.set(code, room);
        } else {
          room = rooms.get(String(msg.code ?? '').trim().toUpperCase());
          if (!room) return error(peer, 'Комната не найдена.');
          if (room.started) return error(peer, 'Матч уже начался.');
        }
        const used = new Set([...room.peers.values()].flatMap(p => p.slots));
        const free = [0, 1, 2, 3].filter(x => !used.has(x));
        if (free.length < count) return error(peer, 'В комнате недостаточно мест.');
        peer.name = String(msg.name ?? 'Хранитель').slice(0, 24);
        peer.slots = free.slice(0, count); peer.room = room.code;
        room.peers.set(peer.id, peer);
        send(peer, { type: 'joined', id: peer.id, code: room.code, slots: peer.slots, host: room.host === peer });
        broadcast(room, roster(room));
        return;
      }
      const room = rooms.get(peer.room);
      if (!room) return error(peer, 'Сначала войдите в комнату.');
      if (msg.type === 'start') {
        if (room.host !== peer || room.started) return error(peer, 'Начать может только ведущий.');
        // Reassign compact slots after lobby departures, before the host creates its simulation.
        let slot = 0;
        for (const p of room.peers.values()) {
          p.slots = p.slots.map(() => slot++);
          send(p, { type: 'slots', slots: p.slots });
        }
        room.started = true;
        broadcast(room, { type: 'start', count: slot, difficulty: Number.isInteger(msg.difficulty) ? Math.max(0, Math.min(2, msg.difficulty)) : 1 });
      } else if (msg.type === 'snapshot') {
        if (peer !== room.host || !room.started || !msg.state || typeof msg.state !== 'object') return;
        room.snapshot = msg.state;
        broadcast(room, { type: 'snapshot', state: msg.state }, peer);
      } else if (msg.type === 'command') {
        if (!room.started || !peer.slots.includes(msg.slot)) return error(peer, 'Эта фишка принадлежит другому игроку.');
        const data = msg.data;
        if (!data || !Number.isInteger(data.turn) || !['aim', 'ready', 'cancel', 'ability', 'reward'].includes(data.action)) return;
        const safe = { action: data.action, turn: data.turn };
        if (data.action === 'aim') {
          if (!Number.isFinite(data.angle) || !Number.isFinite(data.power)) return;
          safe.angle = data.angle; safe.power = Math.max(0.15, Math.min(1, data.power));
        }
        if (data.action === 'reward') {
          if (!Number.isInteger(data.choice) || data.choice < 0 || data.choice > 2) return;
          safe.choice = data.choice;
        }
        send(room.host, { type: 'command', slot: msg.slot, data: safe });
      }
    });
    peer.on('close', () => clean(peer));
  });
  const heartbeat = setInterval(() => {
    for (const peer of wss.clients) {
      if (!peer.alive) { peer.terminate(); continue; }
      peer.alive = false; peer.ping();
    }
  }, 15000);
  heartbeat.unref();
  return { http, wss, rooms, async close() {
    clearInterval(heartbeat);
    for (const peer of wss.clients) peer.terminate();
    await new Promise(resolve => wss.close(resolve));
    await new Promise(resolve => http.close(resolve));
  } };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const relay = createRelay();
  const port = Number(process.env.PORT || 8787);
  relay.http.listen(port, '0.0.0.0', () => console.log(`ORDO relay listening on :${port}`));
}
