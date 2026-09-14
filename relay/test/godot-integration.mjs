import { spawn } from 'node:child_process';
import { access, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRelay } from '../server.mjs';
const godot = process.env.GODOT || 'godot';
const project = fileURLToPath(new URL('../../', import.meta.url));
const relay = createRelay();
await new Promise(r => relay.http.listen(0, '127.0.0.1', r));
const temp = await mkdtemp(path.join(tmpdir(), 'ordo-network-'));
const code = path.join(temp, 'code.txt');
const url = `ws://127.0.0.1:${relay.http.address().port}`;
const processes = [];
function run(host) {
  const child = spawn(godot, ['--headless', '--path', project, '--script', 'res://tests/network_peer.gd', '--', `--url=${url}`, `--code-file=${code}`, ...(host ? ['--host'] : [])]);
  processes.push(child);
  let output = '';
  child.stdout.on('data', data => { output += data; }); child.stderr.on('data', data => { output += data; });
  return new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('exit', status => {
      console.log(output.trim());
      if (status !== 0 || !output.includes(host ? 'HOST_OK' : 'CLIENT_OK') || output.includes('SCRIPT ERROR')) reject(new Error(`Godot peer failed: ${status}`)); else resolve();
    });
  });
}
try {
  const host = run(true);
  for (let i = 0; i < 100; i++) { try { await access(code); break; } catch { await new Promise(r => setTimeout(r, 30)); } }
  const client = run(false);
  await Promise.all([host, client]);
  console.log('PASS: two real Godot processes share one authoritative match through relay');
} finally {
  processes.forEach(child => { if (child.exitCode === null) child.kill(); });
  await relay.close(); await rm(temp, { recursive: true, force: true });
}
