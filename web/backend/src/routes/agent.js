import { Router } from 'express';
import fs from 'fs';
import path from 'path';
import { getDb } from '../db.js';
import { agentMiddleware } from '../auth.js';
import { buildClientConfig } from '../wireguard.js';

const router = Router();

router.post('/register', (req, res) => {
  const { agentToken, hostname } = req.body || {};
  if (!agentToken) return res.status(400).json({ error: 'agentToken requerido' });

  const db = getDb();
  const device = db.prepare('SELECT * FROM devices WHERE agent_token = ?').get(agentToken);
  if (!device) return res.status(404).json({ error: 'Dispositivo no registrado' });

  if (hostname && hostname !== device.name) {
    db.prepare('UPDATE devices SET name = ? WHERE id = ?').run(hostname, device.id);
  }
  db.prepare('UPDATE devices SET last_seen = datetime(\'now\') WHERE id = ?').run(device.id);

  res.json({ ok: true, deviceId: device.id, name: device.name });
});

router.get('/status', agentMiddleware, (req, res) => {
  const db = getDb();
  const device = db.prepare('SELECT * FROM devices WHERE agent_token = ?').get(req.agentToken);
  if (!device) return res.status(404).json({ error: 'Dispositivo no encontrado' });

  db.prepare('UPDATE devices SET last_seen = datetime(\'now\') WHERE id = ?').run(device.id);

  const session = db.prepare('SELECT active_device_id FROM sessions WHERE id = 1').get();
  const shouldConnect = session?.active_device_id === device.id;
  const config = buildClientConfig(device, shouldConnect);

  res.json({
    deviceId: device.id,
    name: device.name,
    shouldConnect,
    vpnActive: shouldConnect,
    config,
  });
});

router.get('/install-script', (_req, res) => {
  const scriptPath = path.join(process.cwd(), 'agent', 'vpn-agent.ps1');
  if (!fs.existsSync(scriptPath)) {
    return res.status(404).json({ error: 'Script no disponible' });
  }
  res.type('text/plain').send(fs.readFileSync(scriptPath, 'utf8'));
});

export default router;
