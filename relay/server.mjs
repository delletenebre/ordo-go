import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { randomInt, randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { WebSocketServer, WebSocket } from 'ws';
import { ROOM_PATTERN, normalizeCode } from './public/room-code.js';
import { AVATARS, avatarId } from './public/avatars.js';

export function allocateRoomCode(rooms, pick = randomInt) {
  const capacity = 1000000;
  const start = pick(capacity);
  // A collision probes the next free code, with a strict finite bound.
  for (let step = 0; step <= rooms.size && step < capacity; step++) {
    const index = (start + step) % capacity;
    const code = String(index).padStart(6, '0');
    if (!rooms.has(code)) return code;
  }
  return null;
}

function playerAvatars(message, count, previous = []) {
  const avatars = Array.isArray(message.avatars) ? message.avatars : [];
  return Array.from({ length: count }, (_, index) =>
    avatarId(avatars[index] ?? (index === 0 ? message.avatar : null) ?? previous[index], Object.keys(AVATARS)[index]));
}

export function createRelay({ maxRooms = 250 } = {}) {
  const rooms = new Map();
  const http = createServer(async (req, res) => {
    const pathname = new URL(req.url, 'http://localhost').pathname;
    if (pathname === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
      return res.end(JSON.stringify({ ok: true, rooms: rooms.size }));
    }
    const files = { '/': 'index.html', '/controller.js': 'controller.js', '/connection-config.js': 'connection-config.js', '/room-code.js': 'room-code.js', '/avatars.js': 'avatars.js' };
    for (const key of Object.keys(AVATARS)) files[`/avatars/${key}.png`] = `../../assets/avatars/${key}.png`;
    for (const key of ['stitch','spark','stride','charge','guard','mend']) files[`/boons/${key}.png`] = `../../assets/boons/${key}.png`;
    files['/reward.css'] = 'reward.css';
    for (const size of [32, 180, 192, 512]) files[`/icons/icon-${size}.png`] = `../../assets/icons/web/icon-${size}.png`;
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
    players: [...room.peers.values()].flatMap(p => p.slots.map((slot, index) => ({ slot, avatar: p.avatars[index], name: AVATARS[p.avatars[index]], owner: p.id, host: p === room.host }))) });
  const error = (peer, text) => send(peer, { type: 'error', message: text });
  const backToLobby = room => {
    room.started = false;
    room.snapshot = null;
    broadcast(room, { type: 'lobby' });
    broadcast(room, roster(room));
  };
  const clean = peer => {
    const room = rooms.get(peer.room);
    if (!room) return;
    if (peer === room.host) {
      broadcast(room, { type: 'ended', message: 'Ведущий завершил комнату.' }, peer);
      for (const p of room.peers.values()) p.room = null;
      rooms.delete(room.code);
    } else {
      room.peers.delete(peer.id);
      if (room.started) backToLobby(room);
      else broadcast(room, roster(room));
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
        if (!Number.isInteger(count) || count < 0 || count > 4) return error(peer, 'Нужно от 0 до 4 местных игроков.');
        let room;
        if (msg.type === 'create') {
          if (rooms.size >= maxRooms) return error(peer, 'Сервер заполнен.');
          const code = allocateRoomCode(rooms);
          if (!code) return error(peer, 'Сервер заполнен.');
          room = { code, host: peer, peers: new Map(), started: false, controllerHub: msg.controllerHub === true, controllersPlaying: false, snapshot: null };
          rooms.set(code, room);
        } else {
          const code = normalizeCode(msg.code);
          if (!ROOM_PATTERN.test(code)) return error(peer, 'Код комнаты: шесть цифр, например 482731.');
          room = rooms.get(code);
          if (!room) return error(peer, 'Комната не найдена.');
          if (room.started || room.controllersPlaying) return error(peer, 'Матч уже начался. Подключитесь перед следующим матчем.');
        }
        const used = new Set([...room.peers.values()].flatMap(p => p.slots));
        const free = [0, 1, 2, 3].filter(x => !used.has(x));
        if (free.length < count) return error(peer, 'В комнате недостаточно мест.');
        peer.avatars = playerAvatars(msg, count);
        peer.slots = free.slice(0, count); peer.room = room.code;
        room.peers.set(peer.id, peer);
        send(peer, { type: 'joined', id: peer.id, code: room.code, slots: peer.slots, host: room.host === peer });
        broadcast(room, roster(room));
        return;
      }
      const room = rooms.get(peer.room);
      if (!room) return error(peer, 'Сначала войдите в комнату.');
      if (msg.type === 'seats') {
        if (room.started) return error(peer, 'Состав забега уже зафиксирован.');
        const count = msg.count;
        if (!Number.isInteger(count) || count < 0 || count > 4) return;
        const used = new Set([...room.peers.values()].filter(p => p !== peer).flatMap(p => p.slots));
        const available = [0,1,2,3].filter(slot => !used.has(slot));
        if (available.length < count) return send(peer, {type:'seats_rejected', slots:peer.slots, message:'Все четыре места уже заняты.'});
        const retained = peer.slots.slice(0,count);
        peer.slots = retained.concat(available.filter(slot => !retained.includes(slot))).slice(0,count);
        peer.avatars = playerAvatars(msg, count, peer.avatars);
        send(peer, {type:'slots', slots:peer.slots});
        broadcast(room, roster(room));
        return;
      }
      if (msg.type === 'avatar') {
        if (room.started || room.controllersPlaying) return error(peer, 'Аватар можно сменить перед началом игры.');
        const index = peer.slots.indexOf(msg.slot);
        if (index < 0) return error(peer, 'Это аватар другого игрока.');
        if (!Object.hasOwn(AVATARS, msg.avatar)) return error(peer, 'Выберите аватар из списка.');
        peer.avatars[index] = msg.avatar;
        broadcast(room, roster(room));
      } else if (msg.type === 'controller_status') {
        if (peer !== room.host || !room.controllerHub || typeof msg.playing !== 'boolean') return;
        room.controllersPlaying = msg.playing;
        if (!msg.playing) {
          room.snapshot = null;
          broadcast(room, { type: 'controller_wait' }, peer);
          broadcast(room, roster(room));
        }
      } else if (msg.type === 'lobby') {
        if (peer !== room.host || room.controllerHub) return error(peer, 'Вернуть комнату в ожидание может только ведущий.');
        if (room.started) backToLobby(room);
      } else if (msg.type === 'start') {
        if (room.host !== peer || room.started) return error(peer, 'Начать может только ведущий.');
        if (![...room.peers.values()].some(p => p.slots.length)) return error(peer, 'Сначала подключите хотя бы одного игрока.');
        // Reassign compact slots after lobby departures, before the host creates its simulation.
        let slot = 0;
        for (const p of room.peers.values()) {
          p.slots = p.slots.map(() => slot++);
          send(p, { type: 'slots', slots: p.slots });
        }
        room.started = true;
        broadcast(room, roster(room));
        broadcast(room, { type: 'start', count: slot, difficulty: Number.isInteger(msg.difficulty) ? Math.max(0, Math.min(2, msg.difficulty)) : 1 });
      } else if (msg.type === 'snapshot') {
        if (peer !== room.host || (!room.started && !room.controllerHub) || !msg.state || typeof msg.state !== 'object') return;
        room.snapshot = msg.state;
        broadcast(room, { type: 'snapshot', state: msg.state }, peer);
      } else if (msg.type === 'command') {
        if ((!room.started && !(room.controllerHub && room.controllersPlaying)) || !peer.slots.includes(msg.slot)) return error(peer, 'Эта фишка принадлежит другому игроку.');
        const data = msg.data;
        if (!data || !Number.isInteger(data.turn) || !['aim', 'ready', 'cancel', 'ability', 'reward', 'reward_focus'].includes(data.action)) return;
        const safe = { action: data.action, turn: data.turn };
        if (data.action === 'aim') {
          if (!Number.isFinite(data.angle) || !Number.isFinite(data.power)) return;
          if (data.spin !== undefined && !Number.isFinite(data.spin)) return;
          if (data.charging !== undefined && typeof data.charging !== 'boolean') return;
          if (data.charging !== undefined) safe.charging = data.charging;
          safe.angle = data.angle; safe.power = Math.max(0.15, Math.min(1, data.power));
          if (data.spin !== undefined) safe.spin = Math.max(-1, Math.min(1, data.spin));
        }
        if (data.action === 'reward' || data.action === 'reward_focus') {
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
