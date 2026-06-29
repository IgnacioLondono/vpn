import Database from 'better-sqlite3';
import bcrypt from 'bcryptjs';
import path from 'path';
import fs from 'fs';

const DB_PATH = process.env.DB_PATH || '/data/vpn.db';

export function initDb() {
  fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
  const db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');

  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS devices (
      id TEXT PRIMARY KEY,
      user_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      public_key TEXT UNIQUE NOT NULL,
      private_key TEXT NOT NULL,
      vpn_ip TEXT NOT NULL,
      agent_token TEXT UNIQUE NOT NULL,
      is_active INTEGER DEFAULT 0,
      last_seen TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id)
    );

    CREATE TABLE IF NOT EXISTS sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      active_device_id TEXT,
      activated_at TEXT,
      activated_by TEXT
    );
  `);

  const adminUser = process.env.ADMIN_USER || 'admin';
  const adminPass = process.env.ADMIN_PASSWORD || 'changeme';
  const existing = db.prepare('SELECT id FROM users WHERE username = ?').get(adminUser);

  if (!existing) {
    const hash = bcrypt.hashSync(adminPass, 12);
    db.prepare('INSERT INTO users (username, password_hash) VALUES (?, ?)').run(adminUser, hash);
    console.log(`[DB] Usuario admin creado: ${adminUser}`);
  }

  const session = db.prepare('SELECT id FROM sessions LIMIT 1').get();
  if (!session) {
    db.prepare('INSERT INTO sessions (active_device_id) VALUES (NULL)').run();
  }

  return db;
}

export function getDb() {
  if (!global.__vpnDb) global.__vpnDb = initDb();
  return global.__vpnDb;
}
