const $ = id => document.getElementById(id);
const colors = ['#43cfff', '#ffc65c', '#58e0a0', '#ff6d78'];
const names = ['ТАРАН', 'СТРАЖ', 'ВЕТЕР', 'ИСКРА'];
const boonNames = { stitch: 'Крепкий шов · +1 максимальное здоровье', spark: 'Жаркий уголь · +1 урон', stride: 'Попутный ветер · +15% скорости', charge: 'Запасная нить · +1 заряд за волну', guard: 'Стёганый панцирь · защита от первого удара', mend: 'Тёплый очаг · восстановить огонь' };
let ws, slot = -1, state, angle = -Math.PI / 2, power = .65, lastAim = 0;
const status = text => { $('status').textContent = text; };
const send = msg => { if (ws?.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg)); };
const command = (action, extra = {}) => {
  if (!state || slot < 0) return;
  send({ type: 'command', slot, data: { action, turn: state.turn, ...extra } });
};
function reset(message) {
  state = null; slot = -1; $('pad').style.display = 'none'; $('join').style.display = 'block'; $('connect').disabled = false; status(message);
}
$('connect').onclick = () => {
  const code = $('code').value.trim().toUpperCase();
  if (!/^[A-Z2-9]{6}$/.test(code)) return status('Введите код из шести символов.');
  if (ws) { ws.onclose = null; ws.close(); }
  $('connect').disabled = true; status('Соединяемся…');
  ws = new WebSocket(`${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}`);
  ws.onopen = () => send({ type: 'join', code, count: 1, name: 'Телефон' });
  ws.onclose = () => reset('Соединение закрыто. Войдите в новую комнату.');
  ws.onerror = () => status('Не удалось связаться с сервером.');
  ws.onmessage = ({ data }) => {
    let msg; try { msg = JSON.parse(data); } catch { return; }
    if (msg.type === 'error') { status(msg.message); $('connect').disabled = false; }
    if (msg.type === 'ended') reset(msg.message);
    if (msg.type === 'joined' || msg.type === 'slots') {
      slot = msg.slots[0]; $('join').style.display = 'none'; $('pad').style.display = 'block';
      $('identity').textContent = `P${slot + 1} · ${names[slot]}`; $('identity').style.color = colors[slot];
      status('Вы в комнате. Ждём начала партии.');
    }
    if (msg.type === 'snapshot') { state = msg.state; render(); }
  };
};
$('ability').onclick = () => command('ability');
$('ready').onclick = () => command('ready');
$('power').oninput = () => { power = Number($('power').value) / 100; command('aim', { angle, power }); };
const canvas = $('arena'), ctx = canvas.getContext('2d');
const point = e => ({ x: 320 + e.x * 46, y: 320 + e.z * 46 });
function aim(event) {
  if (!state || state.phase !== 'plan' || state.players[slot]?.ready) return;
  const rect = canvas.getBoundingClientRect();
  const x = (event.clientX - rect.left) * 640 / rect.width, y = (event.clientY - rect.top) * 640 / rect.height;
  const p = point(state.players[slot]);
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
  const player = state.players[slot]; if (!player) return;
  $('health').textContent = '●'.repeat(Math.max(0, player.hp)) + '○'.repeat(Math.max(0, player.max_hp - player.hp));
  $('health').style.color = colors[slot];
  const phases = { plan: `Выберите бросок · ${Math.ceil(state.timer)} с`, resolve: 'Фишки в движении…', enemy: 'Атака противников', reward: 'Выберите новую нить', clear: 'Волна пройдена!', win: 'Вы сохранили огонь!', lose: 'Огонь погас' };
  status(`Волна ${state.wave} / 9 · ${phases[state.phase] || ''}`);
  $('ready').textContent = player.ready ? '↶ ИЗМЕНИТЬ' : '✓ ГОТОВ';
  $('ready').disabled = state.phase !== 'plan' || player.hp <= 0;
  $('ability').disabled = state.phase !== 'plan' || player.ready || player.charges <= 0;
  $('ability').textContent = `${player.ability ? '✓' : '✦'} УМЕНИЕ · ${player.charges}`;
  $('power').disabled = state.phase !== 'plan' || player.ready;
  $('hint').textContent = Object.keys(player.statuses).map(x => ({ frost: 'Холод: −40% скорости', snare: 'Нити: −30% скорости', weak: 'Слабость: −1 урон', burn: 'Горение: −1 здоровье' }[x])).join(' · ') || 'Проведите от своей фишки в сторону броска.';
  const nextReward = state.phase === 'reward' && !player.reward ? `${state.wave}:${state.reward_options.join()}` : '';
  if (nextReward !== rewardKey) {
    rewardKey = nextReward; $('choices').replaceChildren();
    if (rewardKey) state.reward_options.forEach((key, choice) => {
      const b = document.createElement('button'); b.textContent = boonNames[key]; b.onclick = () => command('reward', { choice }); $('choices').append(b);
    });
  }
  ctx.clearRect(0, 0, 640, 640);
  ctx.fillStyle = '#68463f'; ctx.beginPath(); ctx.arc(320, 320, 284, 0, Math.PI * 2); ctx.fill();
  for (const radius of [280, 236, 76]) { ctx.strokeStyle = '#baa17a'; ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(320, 320, radius, 0, Math.PI * 2); ctx.stroke(); }
  ctx.fillStyle = '#ffbd59'; ctx.beginPath(); ctx.arc(320, 320, 40, 0, Math.PI * 2); ctx.fill();
  for (const a of [.3, 1.85, 3.4, 4.95]) { ctx.fillStyle = '#a49784'; ctx.beginPath(); ctx.arc(320 + Math.cos(a) * 4.6 * 46, 320 + Math.sin(a) * 4.6 * 46, 21, 0, Math.PI * 2); ctx.fill(); }
  for (const e of state.enemies) {
    const p = point(e); ctx.fillStyle = '#25252f'; ctx.beginPath(); ctx.arc(p.x, p.y, e.r * 46, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#ffd174'; for (const x of [-5, 5]) { ctx.beginPath(); ctx.arc(p.x + x, p.y, 2.5, 0, Math.PI * 2); ctx.fill(); }
    if (state.phase === 'plan') { ctx.strokeStyle = '#fdbb9977'; ctx.setLineDash([6, 8]); ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(320 + e.tx * 46, 320 + e.tz * 46); ctx.stroke(); ctx.setLineDash([]); }
  }
  for (const p of state.players) {
    const v = point(p); ctx.globalAlpha = p.hp > 0 ? 1 : .3; ctx.fillStyle = colors[p.id]; ctx.beginPath(); ctx.arc(v.x, v.y, 20, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#fff2da'; ctx.font = 'bold 19px system-ui'; ctx.textAlign = 'center'; ctx.fillText(String(p.id + 1), v.x, v.y + 7); ctx.globalAlpha = 1;
  }
  if (state.phase === 'plan') {
    const p = point(player); ctx.strokeStyle = colors[slot]; ctx.lineWidth = 5;
    ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x + Math.cos(angle) * (50 + power * 95), p.y + Math.sin(angle) * (50 + power * 95)); ctx.stroke();
  }
}
