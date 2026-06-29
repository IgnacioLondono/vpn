const API = '/api';

async function request(path, options = {}) {
  const res = await fetch(`${API}${path}`, {
    credentials: 'include',
    headers: { 'Content-Type': 'application/json', ...options.headers },
    ...options,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || 'Error de servidor');
  return data;
}

export const api = {
  login: (username, password) =>
    request('/auth/login', { method: 'POST', body: JSON.stringify({ username, password }) }),
  logout: () => request('/auth/logout', { method: 'POST' }),
  me: () => request('/auth/me'),
  getDevices: () => request('/devices'),
  registerDevice: (name) =>
    request('/devices/register', { method: 'POST', body: JSON.stringify({ name }) }),
  activate: (id) => request(`/devices/${id}/activate`, { method: 'POST' }),
  deactivate: (id) => request(`/devices/${id}/deactivate`, { method: 'POST' }),
  deleteDevice: (id) => request(`/devices/${id}`, { method: 'DELETE' }),
  getStatus: () => request('/status'),
};

export function downloadConfig(id, name) {
  window.open(`${API}/devices/${id}/config`, '_blank');
}
