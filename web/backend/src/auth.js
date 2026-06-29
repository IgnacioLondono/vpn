import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'change-this-secret-in-production';
const JWT_EXPIRES = process.env.JWT_EXPIRES || '7d';

export function signToken(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES });
}

export function authMiddleware(req, res, next) {
  const header = req.headers.authorization;
  const cookie = req.cookies?.token;
  const token = header?.startsWith('Bearer ') ? header.slice(7) : cookie;

  if (!token) return res.status(401).json({ error: 'No autenticado' });

  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ error: 'Sesión expirada' });
  }
}

export function agentMiddleware(req, res, next) {
  const token = req.headers['x-agent-token'];
  if (!token) return res.status(401).json({ error: 'Token de agente requerido' });
  req.agentToken = token;
  next();
}
