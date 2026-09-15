import { spawn } from 'node:child_process';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRelay } from '../server.mjs';

const project = fileURLToPath(new URL('../../', import.meta.url));
const temp = await mkdtemp(path.join(tmpdir(), 'ordo-controller-'));
const relay = createRelay();
await new Promise((resolve, reject) => {
  relay.http.once('error', reject);
  relay.http.listen(0, '127.0.0.1', resolve);
});
let child;
try {
  child = spawn(process.env.GODOT || path.join(project, 'run.command'), [
    '--headless', '--log-file', path.join(temp, 'godot.log'), '--path', project,
    '--script', process.argv[2] || 'res://tests/controller_network_test.gd', '--',
    `--url=ws://127.0.0.1:${relay.http.address().port}`,
    `--relay=ws://127.0.0.1:${relay.http.address().port}`,
  ]);
  let output = '';
  child.stdout.on('data', data => { output += data; });
  child.stderr.on('data', data => { output += data; });
  const timeout = setTimeout(() => child.kill(), 90000);
  try {
    const code = await new Promise((resolve, reject) => {
      child.on('error', reject); child.on('exit', resolve);
    });
    console.log(output.trim());
    if (code !== 0 || !output.includes(process.argv[2] ? 'MIXED LOBBY: failures=0' : 'CONTROLLER NETWORK: failures=0') || output.includes('SCRIPT ERROR')) {
      throw new Error(`Controller integration failed: ${code}`);
    }
  } finally { clearTimeout(timeout); }
} finally {
  if (child && child.exitCode === null) child.kill();
  await relay.close(); await rm(temp, { recursive: true, force: true });
}
