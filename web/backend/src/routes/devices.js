import { Router } from 'express';
import { getDb } from '../db.js';
import { authMiddleware } from '../auth.js';
import {
  registerDevice,
  activateDevice,
  deactivateDevice,
  deactivateAll,
  buildClientConfig,
  getWireGuardStatus,
  syncWireGuard,
} from '../wireguard.js';

const router = Router();
router.use(authMiddleware);

router.get('/', (req, res) => {
  const db = getDb();
  const devices = db.prepare('SELECT id, name, vpn_ip, is_active, last_seen, created_at FROM devices WHERE user_id = ? ORDER BY created_at DESC')
    .all(req.user.id);
  const session = db.prepare('SELECT active_device_id, activated_at FROM sessions WHERE id = 1').get();
  const wgStatus = getWireGuardStatus();

  res.json({
    devices: devices.map((d) => ({
      ...d,
      is_active: Boolean(d.is_active),
      isConnected: wgStatus.peers.some((p) => {
        const full = db.prepare('SELECT public_key FROM devices WHERE id = ?').get(d.id);
        return full && p.publicKey === full.public_key && p.handshake;
      }),
    })),
    activeDeviceId: session?.active_device_id || null,
    activatedAt: session?.activated_at || null,
    wireguard: wgStatus,
  });
});

router.post('/register', (req, res) => {
  const name = (req.body?.name || '').trim() || `Dispositivo-${Date.now()}`;
  const db = getDb();
  const device = registerDevice(db, req.user.id, name);

  res.status(201).json({
    device: {
      id: device.id,
      name: device.name,
      vpn_ip: device.vpn_ip,
      agent_token: device.agent_token,
    },
    config: buildClientConfig(device, false),
  });
});

router.post('/:id/activate', (req, res) => {
  const db = getDb();
  const device = db.prepare('SELECT * FROM devices WHERE id = ? AND user_id = ?').get(req.params.id, req.user.id);
  if (!device) return res.status(404).json({ error: 'Dispositivo no encontrado' });

  deactivateAll(db);
  activateDevice(db, device.id);

  res.json({
    ok: true,
    message: 'VPN activada solo en este dispositivo',
    device: { id: device.id, name: device.name, is_active: true },
    config: buildClientConfig(device, true),
  });
});

router.post('/:id/deactivate', (req, res) => {
  const db = getDb();
  const device = db.prepare('SELECT * FROM devices WHERE id = ? AND user_id = ?').get(req.params.id, req.user.id);
  if (!device) return res.status(404).json({ error: 'Dispositivo no encontrado' });

  deactivateDevice(db, device.id);

  res.json({
    ok: true,
    message: 'VPN desactivada',
    config: buildClientConfig(device, false),
  });
});

router.get('/:id/config', (req, res) => {
  const db = getDb();
  const device = db.prepare('SELECT * FROM devices WHERE id = ? AND user_id = ?').get(req.params.id, req.user.id);
  if (!device) return res.status(404).json({ error: 'Dispositivo no encontrado' });

  const active = Boolean(device.is_active);
  const config = buildClientConfig(device, active);

  res.setHeader('Content-Disposition', `attachment; filename="${device.name}.conf"`);
  res.type('text/plain').send(config);
});

router.delete('/:id', (req, res) => {
  const db = getDb();
  const device = db.prepare('SELECT * FROM devices WHERE id = ? AND user_id = ?').get(req.params.id, req.user.id);
  if (!device) return res.status(404).json({ error: 'Dispositivo no encontrado' });

  if (device.is_active) deactivateDevice(db, device.id);
  db.prepare('DELETE FROM devices WHERE id = ?').run(device.id);
  syncWireGuard(db);

  res.json({ ok: true });
});

export default router;
