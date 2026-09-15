import { ROOM_PATTERN, normalizeCode } from './room-code.js';
const $ = id => document.getElementById(id);
const connection = globalThis.ORDO_CONNECTION || {};
const colors = ['#43cfff', '#ffc65c', '#58e0a0', '#ff6d78'];
let ws, slot = -1, state;
let stickPointer = null, stickRewardDirection = 0;
let angle = 0, power = .15, spin = 0, choice = 0, phaseKey = '';
let chargeStarted = null, lastTick = performance.now(), aimDirty = false;
const held = new Map();
const buttons = ['up', 'left', 'right', 'down', 'l1', 'r1', 'a', 'b', 'x'];
const status = text => { if ($('status').textContent !== text) $('status').textContent = text; };
const send = msg => { if (ws?.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg)); };
const playerSlot = () => state?.controller_slots ? state.controller_slots[String(slot)] : slot;
const player = () => state?.players?.[playerSlot()];
const command = (action, extra = {}) => {
  if (!state || slot < 0 || !player()) return;
  send({ type: 'command', slot, data: { action, turn: state.turn, ...extra } });
};
const frozen = () => Boolean(player()?.statuses?.frozen && player().freeze_turn === state.turn);
const canAim = () => state?.phase === 'plan' && player()?.hp > 0 && !player().ready && !frozen();
const sendAim = () => { command('aim', { angle, power, spin }); aimDirty = false; };
function clearHeld(cancel = false) {
  const charging = chargeStarted !== null;
  resetStick(); held.clear(); chargeStarted = null; aimDirty = false;
  for (const id of buttons) $(id).classList.toggle('pressed', false);
  if (cancel && charging) command('cancel');
}
function reset(message) {
  clearHeld(); phaseKey = ''; state = null; slot = -1;
  document.body.classList.toggle('connected', false);
  $('pad').style.display = 'none'; $('join').style.display = 'block'; $('connect').disabled = false; status(message);
}
$('connect').onclick = () => {
  const code = normalizeCode($('code').value);
  if (!connection.controller && !ROOM_PATTERN.test(code)) { $('code').focus(); return status('Введите шесть цифр, например 482731.'); }
  if (ws) { ws.onclose = null; ws.close(); }
  $('connect').disabled = true; status('Соединяемся…');
  const address = `${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${connection.websocketPort ? `${location.hostname}:${connection.websocketPort}` : location.host}`;
  ws = new WebSocket(address);
  ws.onopen = () => send({ type: 'join', ...(connection.controller ? { controller: true } : { code }), count: 1, avatar: 'ilbirs' });
  ws.onclose = () => reset(connection.controller ? 'Связь с ТВ закрыта. Нажмите «Подключить», когда ТВ будет готов.' : 'Соединение закрыто. Войдите в новую комнату.');
  ws.onerror = () => status('Не удалось связаться с сервером.');
  ws.onmessage = ({ data }) => {
    let msg; try { msg = JSON.parse(data); } catch { return; }
    if (msg.type === 'error') { status(msg.message); $('connect').disabled = false; }
    if (msg.type === 'ended') reset(msg.message);
    if (msg.type === 'joined' || msg.type === 'slots') {
      slot = msg.slots[0]; $('join').style.display = 'none'; $('pad').style.display = 'flex'; document.body.classList.toggle('connected', true);
      $('identity').textContent = `P${slot + 1}`; $('identity').style.color = colors[slot];
      render();
      status('Вы в комнате. Ждём начала партии.');
    }
    if (msg.type === 'roster') {
      if (!msg.started) status(connection.controller ? 'Контроллер подключён. Ждём игру на ТВ.' : `${msg.code} · ${msg.players.map(player => player.name).join(', ')} · Ждём ведущего`);
    }
    if (msg.type === 'controller_wait') {
      clearHeld(); state = null; phaseKey = ''; render();
      status('Контроллер подключён. Ждём новую игру на ТВ.');
    }
    if (msg.type === 'snapshot') { state = msg.state; render(); }
  };
};

function press(id, pointer) {
  if ($(id).disabled || held.has(id)) return;
  held.set(id, pointer); $(id).classList.toggle('pressed', true);
  if (state.phase === 'reward') {
    if (id === 'left' || id === 'right') {
      choice = (choice + (id === 'left' ? 2 : 1)) % 3;
      command('reward_focus', { choice });
    }
    if (id === 'a') command('reward', { choice });
    if (id === 'b') command('cancel');
    return;
  }
  if (id === 'b') { chargeStarted = null; command('cancel'); return; }
  if (!canAim()) return;
  if (id === 'a') { chargeStarted = performance.now(); power = .15; sendAim(); }
  if (id === 'x') command('ability');
  if (id === 'l1' || id === 'r1') {
    spin = held.has('l1') && held.has('r1') ? 0 : Math.max(-1, Math.min(1, spin + (id === 'l1' ? -.12 : .12)));
    aimDirty = true;
  }
  aimDirection();
  if (aimDirty) sendAim();
}
function aimDirection() {
  const x = Number(held.has('right')) - Number(held.has('left'));
  const y = Number(held.has('down')) - Number(held.has('up'));
  if (x || y) { angle = Math.atan2(y, x); aimDirty = true; }
}
function release(id, pointer, cancelled = false) {
  if (held.get(id) !== pointer) return;
  held.delete(id); $(id).classList.toggle('pressed', false);
  if (id === 'a' && chargeStarted !== null) {
    if (!cancelled && canAim()) {
      power = .15 + .85 * Math.min(1, (performance.now() - chargeStarted) / 600);
      sendAim(); command('ready');
    } else if (cancelled) command('cancel');
    chargeStarted = null;
  }
  if (canAim()) aimDirection();
}
for (const id of buttons) {
  const button = $(id);
  button.onpointerdown = event => {
    event.preventDefault();
    if (button.disabled || held.has(id)) return;
    button.setPointerCapture(event.pointerId); press(id, event.pointerId);
  };
  button.onpointerup = event => release(id, event.pointerId);
  button.onpointercancel = event => release(id, event.pointerId, true);
  button.onlostpointercapture = event => release(id, event.pointerId, true);
  button.oncontextmenu = event => event.preventDefault();
  button.onkeydown = event => {
    if (event.key === ' ' || event.key === 'Enter') { event.preventDefault(); if (!event.repeat) press(id, 'keyboard'); }
  };
  button.onkeyup = event => {
    if (event.key === ' ' || event.key === 'Enter') { event.preventDefault(); release(id, 'keyboard'); }
  };
  // Assistive technology activates buttons with a click, without pointer events.
  button.onclick = event => { if (event.detail === 0) { press(id, 'accessible'); release(id, 'accessible'); } };
}
function resetStick() {
  stickPointer = null; stickRewardDirection = 0;
  $('stick-knob').style.transform = 'translate(0px, 0px)';
  $('stick').classList.toggle('active', false);
}
function setMode(mode) {
  clearHeld(true);
  $('stick').hidden = mode !== 'stick'; $('dpad').hidden = mode !== 'arrows';
  $('mode-stick').setAttribute('aria-pressed', String(mode === 'stick'));
  $('mode-arrows').setAttribute('aria-pressed', String(mode === 'arrows'));
  try { localStorage.setItem('ordo-control-mode', mode); } catch {}
}
$('mode-stick').onclick = () => setMode('stick');
$('mode-arrows').onclick = () => setMode('arrows');
function moveStick(event) {
  const rect = $('stick').getBoundingClientRect();
  let x = event.clientX - rect.left - rect.width / 2;
  let y = event.clientY - rect.top - rect.height / 2;
  const radius = (rect.width - 68) / 2, length = Math.hypot(x, y);
  if (length > radius) { x *= radius / length; y *= radius / length; }
  $('stick-knob').style.transform = `translate(${x}px, ${y}px)`;
  if (state?.phase === 'reward') {
    const direction = Math.abs(x) > radius * .5 ? Math.sign(x) : 0;
    if (direction && direction !== stickRewardDirection) {
      choice = (choice + (direction < 0 ? 2 : 1)) % 3;
      command('reward_focus', { choice });
    }
    stickRewardDirection = direction;
  } else if (canAim() && length > radius * .18) {
    angle = Math.atan2(y, x); aimDirty = true;
  }
}
$('stick').onpointerdown = event => {
  event.preventDefault();
  if ($('stick').disabled || stickPointer !== null) return;
  stickPointer = event.pointerId; $('stick').setPointerCapture(event.pointerId);
  $('stick').classList.toggle('active', true); moveStick(event);
  if (aimDirty) sendAim();
};
$('stick').onpointermove = event => { if (event.pointerId === stickPointer) moveStick(event); };
$('stick').onpointerup = event => {
  if (event.pointerId !== stickPointer) return;
  moveStick(event); if (aimDirty) sendAim(); resetStick();
};
$('stick').onpointercancel = $('stick').onlostpointercapture = event => { if (event.pointerId === stickPointer) resetStick(); };
$('stick').oncontextmenu = event => event.preventDefault();
$('stick').onkeydown = event => {
  const direction = { ArrowLeft: 'left', ArrowRight: 'right', ArrowUp: 'up', ArrowDown: 'down' }[event.key];
  if (direction) { event.preventDefault(); press(direction, 'keyboard'); }
};
$('stick').onkeyup = event => {
  const direction = { ArrowLeft: 'left', ArrowRight: 'right', ArrowUp: 'up', ArrowDown: 'down' }[event.key];
  if (direction) { event.preventDefault(); release(direction, 'keyboard'); }
};
try { if (localStorage.getItem('ordo-control-mode') === 'arrows') setMode('arrows'); } catch {}

window.addEventListener('blur', () => clearHeld(true));
window.addEventListener('pagehide', () => clearHeld(true));
document.addEventListener('visibilitychange', () => { if (document.hidden) clearHeld(true); });
setInterval(() => {
  const now = performance.now(), dt = Math.min(.1, (now - lastTick) / 1000); lastTick = now;
  if (!canAim()) return;
  if (chargeStarted !== null) { power = .15 + .85 * Math.min(1, (now - chargeStarted) / 600); aimDirty = true; }
  const direction = Number(held.has('r1')) - Number(held.has('l1'));
  if (direction) { spin = Math.max(-1, Math.min(1, spin + direction * dt)); aimDirty = true; }
  if (aimDirty) sendAim();
}, 50);
function render() {
  const p = player();
  const key = p ? `${state.turn}:${state.phase}:${playerSlot()}` : '';
  if (key !== phaseKey) {
    clearHeld(); phaseKey = key;
    angle = p?.angle ?? 0; power = p?.power ?? .15; spin = p?.spin ?? 0;
    choice = Math.max(0, p?.reward_choice ?? -1);
  }
  if (p) {
    $('identity').textContent = `P${p.id + 1}`;
    $('identity').style.color = colors[p.id];
    const phases = { plan: frozen() ? 'Лёд · пропуск броска' : p.ready ? 'Бросок готов · B — изменить' : `Бросок · ${Math.ceil(state.timer)} с`, resolve: 'Фишки в движении', enemy: 'Ход противников', reward: p.reward ? 'Дар выбран · B — отменить' : 'Выберите дар на ТВ', clear: 'Волна пройдена', win: 'Огонь сохранён!', lose: 'Огонь погас' };
    status(`Волна ${state.wave} · ${phases[state.phase] || ''}`);
  }
  const reward = Boolean(p && state.phase === 'reward');
  for (const id of buttons) {
    const enabled = reward ? ['left', 'right', 'a', 'b'].includes(id) : id === 'b' ? Boolean(p && state.phase === 'plan' && p.hp > 0 && !frozen()) : canAim() && (id !== 'x' || p.charges > 0);
    $(id).disabled = !enabled;
  }
  $('stick').disabled = !canAim() && !reward;
  $('x').setAttribute('aria-pressed', String(Boolean(p?.ability)));
  $('hint').textContent = !p ? 'Смотрите на ТВ' : reward ? '← → выбрать · A подтвердить · B отменить' : 'A удерживать и отпустить · B отменить\nL1 / R1 подкрутка · X умение';
}
render();
if (connection.controller) {
  $('code').hidden = true; $('code-label').hidden = true;
  $('connect').textContent = 'ПОДКЛЮЧИТЬ';
  document.querySelector('#join h2').textContent = 'Подключение к ТВ';
  document.querySelector('#join p').textContent = 'Нажмите «Подключить». Код не нужен.';
}
