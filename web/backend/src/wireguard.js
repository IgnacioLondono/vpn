import { execSync, spawnSync } from 'child_process';
import { v4 as uuidv4 } from 'uuid';
import fs from 'fs';
import path from 'path';

const WG_DIR = process.env.WG_CONFIG_DIR || '/etc/wireguard';
const WG_CONF = path.join(WG_DIR, 'wg0.conf');
const WG_INTERFACE = 'wg0';
const WG_PORT = process.env.WG_PORT || '51820';
const WG_HOST = process.env.WG_HOST || '127.0.0.1';
const SUBNET = process.env.WG_SUBNET || '10.8.0';
const SERVER_PRIVATE_KEY_FILE = path.join(WG_DIR, 'server_private.key');
const ACTIVE_PEER_FILE = path.join(WG_DIR, 'active_peer');
const WG_MTU = process.env.WG_MTU || '1280';
const VPN_MODE = process.env.VPN_MODE || 'gaming';

/** Rutas según modo: gaming = túnel sin tocar juegos; full = todo por VPN */
function getAllowedIps(active) {
  if (!active) return `${SUBNET}.1/32`;
  if (VPN_MODE === 'full') return '0.0.0.0/0, ::/0';
  // gaming / escudo: túnel activo pero el tráfico de juegos va directo (sin 0.0.0.0/0)
  return `${SUBNET}.0/24`;
}

export function getVpnModeInfo() {
  return {
    mode: VPN_MODE,
    port: WG_PORT,
    mtu: WG_MTU,
    keepalive: process.env.WG_PERSISTENT_KEEPALIVE || '15',
    gamingFriendly: VPN_MODE === 'gaming',
    description:
      VPN_MODE === 'gaming'
        ? 'Modo juegos: la VPN no reenruta tus partidas (evita expulsiones y lag)'
        : 'Modo completo: todo el tráfico pasa por la VPN',
  };
}

function run(cmd, opts = {}) {
  return execSync(cmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], ...opts }).trim();
}

function runWg(args) {
  const r = spawnSync('wg', args, { encoding: 'utf8' });
  if (r.status !== 0) throw new Error(r.stderr || 'wg command failed');
  return r.stdout.trim();
}

export function ensureServerKeys() {
  fs.mkdirSync(WG_DIR, { recursive: true });
  if (!fs.existsSync(SERVER_PRIVATE_KEY_FILE)) {
    const priv = run('wg genkey');
    fs.writeFileSync(SERVER_PRIVATE_KEY_FILE, priv, { mode: 0o600 });
  }
  const priv = fs.readFileSync(SERVER_PRIVATE_KEY_FILE, 'utf8').trim();
  const pub = run(`echo "${priv}" | wg pubkey`);
  return { privateKey: priv, publicKey: pub };
}

export function generateClientKeys() {
  const priv = run('wg genkey');
  const pub = run(`echo "${priv}" | wg pubkey`);
  return { privateKey: priv, publicKey: pub };
}

function getNextIp(db) {
  const rows = db.prepare('SELECT vpn_ip FROM devices ORDER BY vpn_ip').all();
  const used = new Set(rows.map((r) => parseInt(r.vpn_ip.split('.')[3], 10)));
  for (let i = 2; i <= 254; i++) {
    if (!used.has(i)) return `${SUBNET}.${i}`;
  }
  throw new Error('No hay IPs disponibles en la subred VPN');
}

function buildServerConfig(peers, serverKeys) {
  const activeId = fs.existsSync(ACTIVE_PEER_FILE)
    ? fs.readFileSync(ACTIVE_PEER_FILE, 'utf8').trim()
    : '';

  let conf = `[Interface]
Address = ${SUBNET}.1/24
ListenPort = ${WG_PORT}
PrivateKey = ${serverKeys.privateKey}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth+ -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth+ -j MASQUERADE

`;

  for (const peer of peers) {
    const marker = peer.is_active ? 'ACTIVE' : 'STANDBY';
    conf += `[Peer]
# ${peer.id} | ${peer.name} | ${marker}
PublicKey = ${peer.public_key}
AllowedIPs = ${peer.vpn_ip}/32

`;
  }
  return conf;
}

export function writeServerConfig(db) {
  const serverKeys = ensureServerKeys();
  const peers = db.prepare('SELECT * FROM devices ORDER BY vpn_ip').all();
  fs.writeFileSync(WG_CONF, buildServerConfig(peers, serverKeys), { mode: 0o600 });
  return WG_CONF;
}

export function syncWireGuard(db) {
  writeServerConfig(db);
  const tmpStrip = path.join(WG_DIR, 'wg0.strip');
  try {
    runWg(['show', WG_INTERFACE]);
    const stripped = run(`wg-quick strip ${WG_INTERFACE}`, { shell: '/bin/sh' });
    fs.writeFileSync(tmpStrip, stripped);
    runWg(['syncconf', WG_INTERFACE, tmpStrip]);
  } catch {
    try {
      run(`wg-quick down ${WG_INTERFACE} 2>/dev/null; wg-quick up ${WG_INTERFACE}`, { shell: '/bin/sh' });
    } catch (e) {
      console.warn('[WG] sync:', e.message);
    }
  }
}

export function buildClientConfig(device, active) {
  const serverKeys = ensureServerKeys();
  const allowedIps = getAllowedIps(active);
  return `[Interface]
PrivateKey = ${device.private_key}
Address = ${device.vpn_ip}/32
DNS = ${process.env.WG_DEFAULT_DNS || '1.1.1.1, 8.8.8.8'}
MTU = ${WG_MTU}

[Peer]
PublicKey = ${serverKeys.publicKey}
Endpoint = ${WG_HOST}:${WG_PORT}
AllowedIPs = ${allowedIps}
PersistentKeepalive = ${process.env.WG_PERSISTENT_KEEPALIVE || '15'}
`;
}

export function activateDevice(db, deviceId) {
  db.prepare('UPDATE devices SET is_active = 0').run();
  db.prepare('UPDATE devices SET is_active = 1 WHERE id = ?').run(deviceId);
  db.prepare('UPDATE sessions SET active_device_id = ?, activated_at = datetime(\'now\'), activated_by = ? WHERE id = 1')
    .run(deviceId, deviceId);
  fs.writeFileSync(ACTIVE_PEER_FILE, deviceId);
  syncWireGuard(db);
}

export function deactivateDevice(db, deviceId) {
  db.prepare('UPDATE devices SET is_active = 0 WHERE id = ?').run(deviceId);
  const session = db.prepare('SELECT active_device_id FROM sessions WHERE id = 1').get();
  if (session?.active_device_id === deviceId) {
    db.prepare('UPDATE sessions SET active_device_id = NULL, activated_at = NULL, activated_by = NULL WHERE id = 1').run();
    if (fs.existsSync(ACTIVE_PEER_FILE)) fs.unlinkSync(ACTIVE_PEER_FILE);
  }
  syncWireGuard(db);
}

export function deactivateAll(db) {
  db.prepare('UPDATE devices SET is_active = 0').run();
  db.prepare('UPDATE sessions SET active_device_id = NULL, activated_at = NULL, activated_by = NULL WHERE id = 1').run();
  if (fs.existsSync(ACTIVE_PEER_FILE)) fs.unlinkSync(ACTIVE_PEER_FILE);
  syncWireGuard(db);
}

export function registerDevice(db, userId, name) {
  const keys = generateClientKeys();
  const vpnIp = getNextIp(db);
  const id = uuidv4();
  const agentToken = uuidv4();

  db.prepare(`
    INSERT INTO devices (id, user_id, name, public_key, private_key, vpn_ip, agent_token)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `).run(id, userId, name, keys.publicKey, keys.privateKey, vpnIp, agentToken);

  syncWireGuard(db);
  return db.prepare('SELECT * FROM devices WHERE id = ?').get(id);
}

export function getWireGuardStatus() {
  try {
    const out = runWg(['show', WG_INTERFACE]);
    const peers = [];
    let current = {};
    for (const line of out.split('\n')) {
      if (line.startsWith('peer:')) {
        if (current.publicKey) peers.push(current);
        current = { publicKey: line.replace('peer:', '').trim() };
      } else if (line.includes('latest handshake:')) {
        current.handshake = line.split(':').slice(1).join(':').trim();
      } else if (line.includes('transfer:')) {
        current.transfer = line.split(':').slice(1).join(':').trim();
      } else if (line.includes('endpoint:')) {
        current.endpoint = line.split(':').slice(1).join(':').trim();
      }
    }
    if (current.publicKey) peers.push(current);
    return { up: true, peers };
  } catch {
    return { up: false, peers: [] };
  }
}
