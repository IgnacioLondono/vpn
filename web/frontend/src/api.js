const API = '/api';
const TOKEN_KEY = 'vpn_token';

function authHeaders() {
  const token = sessionStorage.getItem(TOKEN_KEY);
  return token ? { Authorization: `Bearer ${token}` } : {};
}

async function request(path, options = {}) {
  const res = await fetch(`${API}${path}`, {
    credentials: 'include',
    headers: { 'Content-Type': 'application/json', ...authHeaders(), ...options.headers },
    ...options,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || 'Error de servidor');
  return data;
}

export const api = {
  login: async (username, password) => {
    const data = await request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    });
    sessionStorage.setItem(TOKEN_KEY, data.token);
    return data;
  },
  logout: async () => {
    sessionStorage.removeItem(TOKEN_KEY);
    try {
      await request('/auth/logout', { method: 'POST' });
    } catch {
      /* ok */
    }
  },
  me: () => request('/auth/me'),
  getDevices: () => request('/devices'),
  registerDevice: (name) =>
    request('/devices/register', { method: 'POST', body: JSON.stringify({ name }) }),
  activate: (id) => request(`/devices/${id}/activate`, { method: 'POST' }),
  deactivate: (id) => request(`/devices/${id}/deactivate`, { method: 'POST' }),
  deleteDevice: (id) => request(`/devices/${id}`, { method: 'DELETE' }),
  getStatus: () => request('/status'),
};

export function downloadConfig(id) {
  const token = sessionStorage.getItem(TOKEN_KEY);
  const url = token
    ? `${API}/devices/${id}/config?token=${encodeURIComponent(token)}`
    : `${API}/devices/${id}/config`;
  window.open(url, '_blank');
}
