import { Routes, Route, Navigate } from 'react-router-dom';
import { useState, useEffect } from 'react';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import { api } from './api';

export default function App() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.me()
      .then((d) => setUser(d.user))
      .catch(() => setUser(null))
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="loader-screen">
        <div className="loader" />
        <p>Cargando VP´N...</p>
      </div>
    );
  }

  return (
    <Routes>
      <Route
        path="/login"
        element={user ? <Navigate to="/" /> : <Login onLogin={setUser} />}
      />
      <Route
        path="/"
        element={user ? <Dashboard user={user} onLogout={() => setUser(null)} /> : <Navigate to="/login" />}
      />
    </Routes>
  );
}
