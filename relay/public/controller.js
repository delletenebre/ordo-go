import { ROOM_PATTERN, normalizeCode } from './room-code.js';
import { AVATARS, avatarId } from './avatars.js';
const $ = id => document.getElementById(id);
const connection = globalThis.ORDO_CONNECTION || {};
const colors = ['#43cfff', '#ffc65c', '#58e0a0', '#ff6d78'];
const boonNames = { stitch: 'Крепкий шов · +1 максимальное здоровье', spark: 'Жаркий уголь · +1 урон', stride: 'Попутный ветер · +15% скорости', charge: 'Запасная нить · +1 заряд за волну', guard: 'Стёганый панцирь · защита от первого удара', mend: 'Тёплый очаг · восстановить огонь' };
let ws, slot = -1, state, angle = -Math.PI / 2, power = .65, lastAim = 0;
let selectedAvatar = 'ilbirs';
try { selectedAvatar = avatarId(localStorage.getItem('ordo-avatar'), 'ilbirs'); } catch {}
function refreshAvatars() {
  for (const button of $('avatars').children) {
    const selected = button.dataset.avatar === selectedAvatar;
    button.classList.toggle('selected', selected); button.setAttribute('aria-pressed', String(selected));
  }
}
for (const [id, name] of Object.entries(AVATARS)) {
  const button = document.createElement('button'); button.className = 'avatar'; button.dataset.avatar = id;
  button.setAttribute('aria-label', name);
  const image = document.createElement('img'); image.src = `/avatars/${id}.png`; image.alt = '';
  const label = document.createElement('span'); label.textContent = name; button.append(image, label);
  button.onclick = () => {
    selectedAvatar = id; refreshAvatars();
    try { localStorage.setItem('ordo-avatar', id); } catch {}
    if (slot >= 0) send({ type: 'avatar', slot, avatar: id });
  };
  $('avatars').append(button);
}
refreshAvatars();
$('change-avatar').onclick = () => { $('avatar-picker').hidden = !$('avatar-picker').hidden; };
const status = text => { $('status').textContent = text; };
const send = msg => { if (ws?.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg)); };
const command = (action, extra = {}) => {
  if (!state || slot < 0 || playerSlot() === undefined) return;
  send({ type: 'command', slot, data: { action, turn: state.turn, ...extra } });
};
function reset(message) {
	$('change-avatar').hidden = false;
  rewardKey = ''; $('choices').replaceChildren(); state = null; slot = -1; $('pad').style.display = 'none'; $('join').style.display = 'block'; $('connect').disabled = false; $('avatar-picker').hidden = false; status(message);
}
$('connect').onclick = () => {
  const code = normalizeCode($('code').value);
  if (!connection.controller && !ROOM_PATTERN.test(code)) { $('code').focus(); return status('Введите шесть цифр, например 482731.'); }
  if (ws) { ws.onclose = null; ws.close(); }
  $('connect').disabled = true; status('Соединяемся…');
  const address = `${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${connection.websocketPort ? `${location.hostname}:${connection.websocketPort}` : location.host}`;
  ws = new WebSocket(address);
  ws.onopen = () => send({ type: 'join', ...(connection.controller ? { controller: true } : { code }), count: 1, avatar: selectedAvatar });
  ws.onclose = () => reset(connection.controller ? 'Связь с ТВ закрыта. Нажмите «Подключить», когда ТВ будет готов.' : 'Соединение закрыто. Войдите в новую комнату.');
  ws.onerror = () => status('Не удалось связаться с сервером.');
  ws.onmessage = ({ data }) => {
    let msg; try { msg = JSON.parse(data); } catch { return; }
    if (msg.type === 'error') { status(msg.message); $('connect').disabled = false; }
    if (msg.type === 'ended') reset(msg.message);
    if (msg.type === 'joined' || msg.type === 'slots') {
      slot = msg.slots[0]; $('join').style.display = 'none'; $('pad').style.display = 'block';
      $('identity').textContent = `P${slot + 1} · ${AVATARS[selectedAvatar]}`; $('identity').style.color = colors[slot];
      $('avatar-picker').hidden = true; $('pad').classList.toggle('waiting', true);
      status('Вы в комнате. Ждём начала партии.');
    }
    if (msg.type === 'roster') {
      const own = msg.players.find(player => player.slot === slot);
      if (own) { selectedAvatar = own.avatar; refreshAvatars(); $('identity').textContent = `P${slot + 1} · ${AVATARS[selectedAvatar]}`; }
      if (!msg.started) status(connection.controller ? 'Контроллер подключён. Ждём игру на ТВ.' : `${msg.code} · ${msg.players.map(player => player.name).join(', ')} · Ждём ведущего`);
    }
    if (msg.type === 'controller_wait') {
      state = null; rewardKey = ''; $('choices').replaceChildren();
      $('pad').classList.toggle('waiting', true); $('pad').classList.toggle('reward-phase', false);
      $('change-avatar').hidden = false; status('Контроллер подключён. Ждём новую игру на ТВ.');
    }
    if (msg.type === 'start') { $('avatar-picker').hidden = true; $('change-avatar').hidden = true; }
    if (msg.type === 'snapshot') { $('pad').classList.toggle('waiting', false); state = msg.state; render(); }
  };
};
$('ability').onclick = () => command('ability');
$('ready').onclick = () => command('ready');
$('power').oninput = () => { power = Number($('power').value) / 100; command('aim', { angle, power }); };
const playerSlot = () => state?.controller_slots ? state.controller_slots[String(slot)] : slot;
const canvas = $('arena'), ctx = canvas.getContext('2d');
const point = e => ({ x: 320 + e.x * 46, y: 320 + e.z * 46 });
function drawElement(body) {
  const effects = body.statuses || {};
  const cold = effects.frost || effects.frozen;
  if ((!effects.burn && !cold) || body.hp <= 0) return;
  const p = point(body), radius = (body.r || .43) * 46 + 5;
  ctx.strokeStyle = cold ? '#b7ebff' : '#ff983f'; ctx.lineWidth = 3;
  ctx.beginPath(); ctx.arc(p.x, p.y, radius, 0, Math.PI * 2); ctx.stroke();
  ctx.fillStyle = cold ? '#dcf6ff' : '#ffdb9d'; ctx.font = 'bold 14px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(cold ? '❄' : String(effects.burn), p.x, p.y - radius - 5);
}
function aim(event) {
  if (!state || playerSlot() === undefined || state.phase !== 'plan' || state.players[playerSlot()]?.ready) return;
  const rect = canvas.getBoundingClientRect();
  const x = (event.clientX - rect.left) * 640 / rect.width, y = (event.clientY - rect.top) * 640 / rect.height;
  const p = point(state.players[playerSlot()]);
  angle = Math.atan2(y - p.y, x - p.x);
  if (performance.now() - lastAim > 50 || event.type === 'pointerdown' || event.type === 'pointerup') {
    command('aim', { angle, power }); lastAim = performance.now();
  }
}
canvas.onpointerdown = event => { canvas.setPointerCapture(event.pointerId); aim(event); };
canvas.onpointermove = event => { if (canvas.hasPointerCapture(event.pointerId)) aim(event); };
canvas.onpointerup = aim;
let rewardKey = '';
function render() {
  const player = state.players[playerSlot()]; if (!player) return;
  $('change-avatar').hidden = true;
  $('identity').textContent = `P${player.id + 1} · ${AVATARS[selectedAvatar]}`;
  $('identity').style.color = colors[player.id];
  $('health').textContent = '●'.repeat(Math.max(0, player.hp)) + '○'.repeat(Math.max(0, player.max_hp - player.hp));
  $('health').style.color = colors[player.id];
  const phases = { plan: `Выберите бросок · ${Math.ceil(state.timer)} с`, resolve: 'Фишки в движении…', enemy: 'Атака противников', reward: 'Выберите новую нить', clear: 'Волна пройдена!', win: 'Вы сохранили огонь!', lose: 'Огонь погас' };
  status(`Волна ${state.wave} / 9 · ${phases[state.phase] || ''}`);
  const frozen = Boolean(player.statuses.frozen && player.freeze_turn === state.turn);
  $('ready').textContent = frozen ? '❄ ПРОПУСК БРОСКА' : player.ready ? '↶ ИЗМЕНИТЬ' : '✓ ГОТОВ';
  $('ready').disabled = state.phase !== 'plan' || player.hp <= 0 || frozen;
  $('ability').disabled = state.phase !== 'plan' || frozen || player.ready || player.charges <= 0;
  $('ability').textContent = `${player.ability ? '✓' : '✦'} УМЕНИЕ · ${player.charges}`;
  $('power').disabled = state.phase !== 'plan' || frozen || player.ready;
  $('hint').textContent = Object.keys(player.statuses).map(x => ({ frost: 'Холод: −40% скорости', snare: 'Нити: −30% скорости', weak: 'Слабость: −1 урон', burn: `Огонь: ${player.statuses.burn} · −1/ход`, frozen: frozen ? 'Лёд: пропуск броска · разбивает сильный удар' : 'Лёд: пропуск следующего броска' }[x])).join(' · ') || 'Проведите от своей фишки в сторону броска.';
  $('pad').classList.toggle('reward-phase', state.phase === 'reward');
  const nextReward = state.phase === 'reward' ? `${state.wave}:${state.reward_options.join()}` : '';
  if (nextReward !== rewardKey) {
    rewardKey = nextReward; $('choices').replaceChildren();
    if (rewardKey) state.reward_options.forEach((key, choice) => {
      const b = document.createElement('button'); b.className = 'boon'; b.setAttribute('aria-label',boonNames[key]);
      const art = document.createElement('span'); art.className = 'boon-art';
      const img = document.createElement('img'); img.src = `/boons/${key}.png`; img.alt = ''; art.append(img);
      const label = document.createElement('span'); label.className = 'boon-label'; label.textContent = boonNames[key];
      b.append(art,label); b.onclick = () => command('reward', { choice }); $('choices').append(b);
    });
  }
  if (rewardKey) {
    const ready = state.players.filter(p => p.reward).length;
    $('reward-status').textContent = ready === state.players.length ? `Все готовы · новая волна через ${Math.max(1,Math.ceil(state.timer))}` : `Готовы ${ready} / ${state.players.length} · ${player.reward ? 'Ваш дар выбран' : 'Выберите дар — и вы готовы'}`;
    [...$('choices').children].forEach((button,index) => {
      const chosen = player.reward && player.reward_choice === index;
      button.classList.toggle('chosen',chosen); button.setAttribute('aria-pressed',String(chosen));
    });
    $('reward-party').textContent = state.players.map(p => `P${p.id+1}: ${p.reward ? 'готов' : 'выбирает'}`).join(' · ');
    $('cancel-reward').hidden = !player.reward;
  }
  ctx.clearRect(0, 0, 640, 640);
  ctx.fillStyle = '#68463f'; ctx.beginPath(); ctx.arc(320, 320, 284, 0, Math.PI * 2); ctx.fill();
  for (const radius of [280, 236, 76]) { ctx.strokeStyle = '#baa17a'; ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(320, 320, radius, 0, Math.PI * 2); ctx.stroke(); }
  ctx.fillStyle = '#ffbd59'; ctx.beginPath(); ctx.arc(320, 320, 40, 0, Math.PI * 2); ctx.fill();
  for (const a of [.3, 1.85, 3.4, 4.95]) { ctx.fillStyle = '#a49784'; ctx.beginPath(); ctx.arc(320 + Math.cos(a) * 4.6 * 46, 320 + Math.sin(a) * 4.6 * 46, 21, 0, Math.PI * 2); ctx.fill(); }
  for (const item of state.pickups || []) {
    if (item.kind !== 'element' || item.used) continue;
    const p = point(item); ctx.fillStyle = item.element === 'fire' ? '#ffc063' : '#d2f3ff';
    ctx.font = '22px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(item.element === 'fire' ? '🔥' : '❄', p.x, p.y + 7);
  }
  for (const e of state.enemies) {
    const p = point(e); ctx.fillStyle = '#25252f'; ctx.beginPath(); ctx.arc(p.x, p.y, e.r * 46, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#ffd174'; for (const x of [-5, 5]) { ctx.beginPath(); ctx.arc(p.x + x, p.y, 2.5, 0, Math.PI * 2); ctx.fill(); }
    if (state.phase === 'plan' && !(e.statuses?.frozen && e.freeze_turn === state.turn)) { ctx.strokeStyle = '#fdbb9977'; ctx.setLineDash([6, 8]); ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(320 + e.tx * 46, 320 + e.tz * 46); ctx.stroke(); ctx.setLineDash([]); }
    drawElement(e);
  }
  for (const p of state.players) {
    const v = point(p); ctx.globalAlpha = p.hp > 0 ? 1 : .3; ctx.fillStyle = colors[p.id]; ctx.beginPath(); ctx.arc(v.x, v.y, 20, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#fff2da'; ctx.font = 'bold 19px system-ui'; ctx.textAlign = 'center'; ctx.fillText(String(p.id + 1), v.x, v.y + 7); ctx.globalAlpha = 1;
    drawElement(p);
  }
  if (state.phase === 'plan' && !frozen) {
    const p = point(player); ctx.strokeStyle = colors[player.id]; ctx.lineWidth = 5;
    ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x + Math.cos(angle) * (50 + power * 95), p.y + Math.sin(angle) * (50 + power * 95)); ctx.stroke();
  }
}

$('cancel-reward').onclick = () => command('cancel');

if (connection.controller) {
  $('code').hidden = true; $('code-label').hidden = true;
  $('connect').textContent = 'ПОДКЛЮЧИТЬ';
  document.querySelector('#join h2').textContent = 'Подключение к ТВ';
  document.querySelector('#join p').textContent = 'Выберите аватар и нажмите «Подключить». Код не нужен.';
}
