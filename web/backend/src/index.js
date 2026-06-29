import express from 'express';
import cookieParser from 'cookie-parser';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import path from 'path';
import { fileURLToPath } from 'url';
import { getDb } from './db.js';
import { getVpnModeInfo, syncWireGuard, ensureServerKeys } from './wireguard.js';
import authRoutes from './routes/auth.js';
import deviceRoutes from './routes/devices.js';
import agentRoutes from './routes/agent.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = process.env.WEB_PORT || 8443;
const app = express();

app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors({ origin: true, credentials: true }));
app.use(express.json());
app.use(cookieParser());
app.use(rateLimit({ windowMs: 15 * 60 * 1000, max: 200 }));

app.use('/api/auth', authRoutes);
app.use('/api/devices', deviceRoutes);
app.use('/api/agent', agentRoutes);

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', service: 'vpn-portal', version: '1.0.0' });
});

app.get('/api/status', (_req, res) => {
  const db = getDb();
  const session = db.prepare('SELECT active_device_id, activated_at FROM sessions WHERE id = 1').get();
  const activeDevice = session?.active_device_id
    ? db.prepare('SELECT id, name, vpn_ip FROM devices WHERE id = ?').get(session.active_device_id)
    : null;
  res.json({
    vpnActive: Boolean(activeDevice),
    activeDevice,
    activatedAt: session?.activated_at,
    config: getVpnModeInfo(),
  });
});

const staticDir = path.join(__dirname, '../public');
app.use(express.static(staticDir));
app.get('*', (req, res, next) => {
  if (req.path.startsWith('/api')) return next();
  res.sendFile(path.join(staticDir, 'index.html'), (err) => {
    if (err) next();
  });
});

getDb();
ensureServerKeys();

setTimeout(() => {
  try {
    syncWireGuard(getDb());
    console.log('[WG] WireGuard sincronizado');
  } catch (e) {
    console.warn('[WG] Inicio diferido:', e.message);
  }
}, 2000);

app.listen(PORT, '0.0.0.0', () => {
  console.log(`[VPN Portal] http://0.0.0.0:${PORT}`);
});
