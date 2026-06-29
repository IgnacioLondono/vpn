import { useState, useEffect, useCallback } from 'react';
import { api, downloadConfig } from '../api';

export default function Dashboard({ user, onLogout }) {
  const [devices, setDevices] = useState([]);
  const [activeDeviceId, setActiveDeviceId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(null);
  const [error, setError] = useState('');
  const [vpnConfig, setVpnConfig] = useState(null);
  const [agentToken, setAgentToken] = useState(
    () => localStorage.getItem('vpn_agent_token') || null
  );
  const [currentDeviceId, setCurrentDeviceId] = useState(
    () => localStorage.getItem('vpn_device_id') || null
  );

  const refresh = useCallback(async () => {
    try {
      const data = await api.getDevices();
      setDevices(data.devices);
      setActiveDeviceId(data.activeDeviceId);
      setError('');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
    api.getStatus().then((d) => setVpnConfig(d.config)).catch(() => {});
    const interval = setInterval(() => {
      refresh();
      api.getStatus().then((d) => setVpnConfig(d.config)).catch(() => {});
    }, 5000);
    return () => clearInterval(interval);
  }, [refresh]);

  async function registerThisDevice() {
    setActionLoading('register');
    try {
      const hostname = window.navigator.userAgent.includes('Windows')
        ? `PC-${navigator.platform}`
        : `Dispositivo-${Date.now()}`;
      const data = await api.registerDevice(hostname);
      localStorage.setItem('vpn_device_id', data.device.id);
      localStorage.setItem('vpn_agent_token', data.device.agent_token);
      setCurrentDeviceId(data.device.id);
      setAgentToken(data.device.agent_token);
      await refresh();
    } catch (err) {
      setError(err.message);
    } finally {
      setActionLoading(null);
    }
  }

  async function toggleVpn(device) {
    setActionLoading(device.id);
    try {
      if (device.is_active) {
        await api.deactivate(device.id);
      } else {
        await api.activate(device.id);
        localStorage.setItem('vpn_device_id', device.id);
        setCurrentDeviceId(device.id);
      }
      await refresh();
    } catch (err) {
      setError(err.message);
    } finally {
      setActionLoading(null);
    }
  }

  async function handleLogout() {
    await api.logout();
    onLogout();
  }

  const currentDevice = devices.find((d) => d.id === currentDeviceId);
  const vpnOn = Boolean(activeDeviceId);
  const isThisPcActive = currentDevice?.is_active;

  return (
    <div className="dashboard">
      <header className="header">
        <div className="header-brand">
          <span className="brand-icon-sm">⬡</span>
          <span>VP´N</span>
        </div>
        <div className="header-user">
          <span>{user.username}</span>
          <button className="btn btn-ghost btn-sm" onClick={handleLogout}>Salir</button>
        </div>
      </header>

      <main className="main">
        {error && <div className="alert alert-error">{error}</div>}

        {vpnConfig && (
          <div className="info-banner">
            <strong>Modo {vpnConfig.mode === 'gaming' ? 'juegos' : 'completo'}</strong>
            <span>{vpnConfig.description}</span>
            <span className="mono">Puerto UDP {vpnConfig.port} · MTU {vpnConfig.mtu}</span>
          </div>
        )}

        <section className="hero-card">
          <div className="hero-status">
            <div className={`status-ring ${vpnOn ? 'active' : ''}`}>
              <div className="status-inner">
                {vpnOn ? 'ON' : 'OFF'}
              </div>
            </div>
            <div className="hero-text">
              <h2>{vpnOn ? 'VPN activa' : 'VPN apagada'}</h2>
              <p>
                {vpnOn
                  ? `Tráfico enrutado en: ${devices.find((d) => d.is_active)?.name || '—'}`
                  : 'Enciende la VPN solo en este PC con el botón de abajo'}
              </p>
            </div>
          </div>

          {currentDevice ? (
            <button
              className={`btn btn-xl power-btn ${isThisPcActive ? 'power-on' : 'power-off'}`}
              onClick={() => toggleVpn(currentDevice)}
              disabled={actionLoading === currentDevice.id}
            >
              {actionLoading === currentDevice.id
                ? 'Procesando...'
                : isThisPcActive
                  ? 'Apagar VPN en este PC'
                  : 'Encender VPN en este PC'}
            </button>
          ) : (
            <button
              className="btn btn-xl btn-primary"
              onClick={registerThisDevice}
              disabled={actionLoading === 'register'}
            >
              {actionLoading === 'register' ? 'Registrando...' : 'Registrar este PC'}
            </button>
          )}

          {vpnOn && !isThisPcActive && currentDevice && (
            <p className="notice">
              Otro dispositivo tiene la VPN activa. Al encender aquí, se desactivará allí.
            </p>
          )}
        </section>

        <section className="panel">
          <div className="panel-header">
            <h3>Mis dispositivos</h3>
            <button className="btn btn-secondary btn-sm" onClick={registerThisDevice} disabled={!!actionLoading}>
              + Añadir
            </button>
          </div>

          {loading ? (
            <div className="empty">Cargando...</div>
          ) : devices.length === 0 ? (
            <div className="empty">
              <p>No hay dispositivos registrados.</p>
              <p>Registra este PC para empezar.</p>
            </div>
          ) : (
            <ul className="device-list">
              {devices.map((device) => (
                <li key={device.id} className={`device-item ${device.is_active ? 'active' : ''}`}>
                  <div className="device-info">
                    <span className="device-name">
                      {device.name}
                      {device.id === currentDeviceId && <span className="badge">Este PC</span>}
                    </span>
                    <span className="device-meta mono">{device.vpn_ip}</span>
                    <span className={`device-state ${device.isConnected ? 'online' : 'offline'}`}>
                      {device.is_active ? 'VPN activa' : device.isConnected ? 'Conectado (standby)' : 'Desconectado'}
                    </span>
                  </div>
                  <div className="device-actions">
                    {device.id !== currentDeviceId && (
                      <button
                        className="btn btn-sm btn-secondary"
                        onClick={() => toggleVpn(device)}
                        disabled={!!actionLoading}
                      >
                        {device.is_active ? 'Apagar' : 'Encender'}
                      </button>
                    )}
                    <button
                      className="btn btn-sm btn-ghost"
                      onClick={() => downloadConfig(device.id, device.name)}
                    >
                      .conf
                    </button>
                    <button
                      className="btn btn-sm btn-danger-ghost"
                      onClick={async () => {
                        if (confirm(`¿Eliminar ${device.name}?`)) {
                          await api.deleteDevice(device.id);
                          if (device.id === currentDeviceId) {
                            localStorage.removeItem('vpn_device_id');
                            setCurrentDeviceId(null);
                          }
                          refresh();
                        }
                      }}
                    >
                      ✕
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className="panel setup-panel">
          <h3>Agente Windows (recomendado)</h3>
          <p>
            Ejecuta en PowerShell como administrador para que este PC conecte/desconecte
            automáticamente al pulsar el botón en el panel:
          </p>
          {agentToken ? (
            <>
              <pre className="code-block">{`.\\scripts\\vpn-agent.ps1 -ServerUrl "${window.location.origin}" -AgentToken "${agentToken}"`}</pre>
              <button
                className="btn btn-secondary btn-sm"
                onClick={() => navigator.clipboard.writeText(
                  `.\\scripts\\vpn-agent.ps1 -ServerUrl "${window.location.origin}" -AgentToken "${agentToken}"`
                )}
              >
                Copiar comando
              </button>
            </>
          ) : (
            <p className="hint">Registra este PC para obtener el Agent Token.</p>
          )}
        </section>
      </main>
    </div>
  );
}
