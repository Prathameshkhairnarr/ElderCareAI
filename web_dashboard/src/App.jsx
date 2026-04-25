import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { 
  LayoutDashboard, 
  Users, 
  Activity, 
  Settings, 
  Bell, 
  Plus, 
  HeartPulse, 
  MapPin, 
  ShieldAlert,
  ShieldX,
  LogOut,
  Loader,
  MessageSquare,
  PhoneCall
} from 'lucide-react';
import './index.css';

const API_BASE_URL = 'https://eldercareai-1.onrender.com'; // Pointing to Render Backend

function App() {
  const [token, setToken] = useState(localStorage.getItem('guardian_token'));
  const [user, setUser] = useState(JSON.parse(localStorage.getItem('guardian_user') || 'null'));
  
  const [phone, setPhone] = useState('');
  const [pin, setPin] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const [activeTab, setActiveTab] = useState('dashboard');
  const [dashboardData, setDashboardData] = useState(null);
  const [fetchingData, setFetchingData] = useState(false);

  // Scams State
  const [scamLogs, setScamLogs] = useState([]);
  const [fetchingScams, setFetchingScams] = useState(false);
  const [selectedScamElderId, setSelectedScamElderId] = useState(null);

  // Add Profile State
  const [showAddProfileModal, setShowAddProfileModal] = useState(false);
  const [newProfilePhone, setNewProfilePhone] = useState('');
  const [addProfileLoading, setAddProfileLoading] = useState(false);
  const [addProfileError, setAddProfileError] = useState('');

  // Fetch Dashboard Data
  useEffect(() => {
    if (token) {
      fetchDashboard();
    }
  }, [token]);

  const fetchDashboard = async () => {
    setFetchingData(true);
    try {
      const response = await axios.get(`${API_BASE_URL}/guardian/dashboard`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setDashboardData(response.data);
    } catch (err) {
      console.error(err);
      if (err.response?.status === 401) {
        handleLogout();
      }
    } finally {
      setFetchingData(false);
    }
  };

  const fetchScamLogs = async (elderId) => {
    if (!elderId || !token) return;
    setFetchingScams(true);
    try {
      const response = await axios.get(`${API_BASE_URL}/guardian/elder/${elderId}/scam_logs`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setScamLogs(response.data);
    } catch (err) {
      console.error(err);
    } finally {
      setFetchingScams(false);
    }
  };

  useEffect(() => {
    if (activeTab === 'scams' && selectedScamElderId) {
      fetchScamLogs(selectedScamElderId);
    }
  }, [activeTab, selectedScamElderId]);

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const formData = new URLSearchParams();
      formData.append('username', phone);
      formData.append('password', pin);

      const response = await axios.post(`${API_BASE_URL}/auth/login`, formData, {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
      });

      const { access_token, user: loggedInUser } = response.data;
      
      if (loggedInUser.role !== 'guardian') {
        setError('Access Denied: Only Guardian accounts can log into the Web Dashboard.');
        setLoading(false);
        return;
      }
      
      localStorage.setItem('guardian_token', access_token);
      localStorage.setItem('guardian_user', JSON.stringify(loggedInUser));
      
      setToken(access_token);
      setUser(loggedInUser);
    } catch (err) {
      setError(err.response?.data?.detail || 'Login failed. Check your Phone and PIN.');
    } finally {
      setLoading(false);
    }
  };

  const handleAddProfile = async (e) => {
    e.preventDefault();
    setAddProfileLoading(true);
    setAddProfileError('');

    try {
      await axios.post(`${API_BASE_URL}/guardian/link`, { elder_phone: newProfilePhone }, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setShowAddProfileModal(false);
      setNewProfilePhone('');
      fetchDashboard(); // Refresh dashboard to show the new profile
    } catch (err) {
      setAddProfileError(err.response?.data?.detail || 'Failed to link profile. Make sure they have installed the app.');
    } finally {
      setAddProfileLoading(false);
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('guardian_token');
    localStorage.removeItem('guardian_user');
    setToken(null);
    setUser(null);
    setDashboardData(null);
  };

  // ---------------- LOGIN SCREEN ----------------
  if (!token) {
    return (
      <div className="dashboard-container" style={{ justifyContent: 'center', alignItems: 'center' }}>
        <div className="stat-card" style={{ width: '400px', padding: '40px' }}>
          <div className="brand" style={{ justifyContent: 'center', marginBottom: '30px' }}>
            <HeartPulse size={36} color="#6366f1" />
            ElderCareAI
          </div>
          <h2 style={{ textAlign: 'center', marginBottom: '20px' }}>Guardian Login</h2>
          
          {error && <div style={{ color: 'var(--danger)', marginBottom: '15px', textAlign: 'center', fontSize: '14px' }}>{error}</div>}
          
          <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <div>
              <label style={{ color: 'var(--text-muted)', fontSize: '14px', marginBottom: '8px', display: 'block' }}>Phone Number</label>
              <input 
                type="text" 
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="e.g. 9876543210"
                style={{ width: '100%', padding: '12px', borderRadius: '10px', background: 'rgba(0,0,0,0.2)', border: '1px solid var(--card-border)', color: 'white' }}
                required
              />
            </div>
            <div>
              <label style={{ color: 'var(--text-muted)', fontSize: '14px', marginBottom: '8px', display: 'block' }}>PIN</label>
              <input 
                type="password" 
                value={pin}
                onChange={(e) => setPin(e.target.value)}
                placeholder="****"
                style={{ width: '100%', padding: '12px', borderRadius: '10px', background: 'rgba(0,0,0,0.2)', border: '1px solid var(--card-border)', color: 'white' }}
                required
              />
            </div>
            <button type="submit" className="btn-primary" style={{ width: '100%', justifyContent: 'center', marginTop: '10px' }} disabled={loading}>
              {loading ? <Loader className="animate-spin" size={20} /> : 'Login to Dashboard'}
            </button>
          </form>
        </div>
      </div>
    );
  }

  // ---------------- DATE FORMATTERS ----------------
  const formatDateTime = (dateString) => {
    if (!dateString) return '';
    const utcDate = dateString.endsWith('Z') ? dateString : `${dateString}Z`;
    return new Date(utcDate).toLocaleString();
  };

  const formatTime = (dateString) => {
    if (!dateString) return '';
    const utcDate = dateString.endsWith('Z') ? dateString : `${dateString}Z`;
    return new Date(utcDate).toLocaleTimeString();
  };

  const formatDate = (dateString) => {
    if (!dateString) return '';
    const utcDate = dateString.endsWith('Z') ? dateString : `${dateString}Z`;
    return new Date(utcDate).toLocaleDateString();
  };

  // ---------------- DASHBOARD SCREEN ----------------
  const elders = dashboardData?.elders || [];
  
  return (
    <div className="dashboard-container">
      {/* Sidebar */}
      <aside className="sidebar">
        <div className="brand">
          <HeartPulse size={28} color="#6366f1" />
          ElderCareAI
        </div>
        
        <ul className="nav-menu">
          <li className={`nav-item ${activeTab === 'dashboard' ? 'active' : ''}`} onClick={() => setActiveTab('dashboard')}>
            <LayoutDashboard size={20} /> Dashboard
          </li>
          <li className={`nav-item ${activeTab === 'profiles' ? 'active' : ''}`} onClick={() => setActiveTab('profiles')}>
            <Users size={20} /> Manage Profiles
          </li>
          <li className={`nav-item ${activeTab === 'activity' ? 'active' : ''}`} onClick={() => setActiveTab('activity')}>
            <Activity size={20} /> Activity & Health
          </li>
          <li className={`nav-item ${activeTab === 'alerts' ? 'active' : ''}`} onClick={() => setActiveTab('alerts')}>
            <ShieldAlert size={20} /> Alerts
          </li>
          <li className={`nav-item ${activeTab === 'scams' ? 'active' : ''}`} onClick={() => {
            setActiveTab('scams');
            if (!selectedScamElderId && elders.length > 0) {
              setSelectedScamElderId(elders[0].elder_id);
            }
          }}>
            <ShieldX size={20} /> Fraud Monitor
          </li>
          <li className={`nav-item ${activeTab === 'settings' ? 'active' : ''}`} onClick={() => setActiveTab('settings')}>
            <Settings size={20} /> Settings
          </li>
        </ul>

        <div style={{ marginTop: 'auto' }}>
          <li className="nav-item" style={{ color: '#ef4444' }} onClick={handleLogout}>
            <LogOut size={20} /> Logout
          </li>
        </div>
      </aside>

      {/* Main Content */}
      <main className="main-content">
        <header className="header">
          <div>
            <h1>Guardian Dashboard</h1>
            <p>Welcome back, {user?.name || 'Guardian'}! Here's the status of your family.</p>
          </div>
          
          <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
            <div style={{ position: 'relative', cursor: 'pointer' }}>
              <Bell size={24} color="#94a3b8" />
              <span style={{ position: 'absolute', top: 0, right: 0, width: 8, height: 8, background: '#ef4444', borderRadius: '50%' }}></span>
            </div>
            <div className="user-profile">
              <div className="avatar">{user?.name ? user.name.charAt(0).toUpperCase() : 'G'}</div>
              <span style={{ fontWeight: 500 }}>{user?.name || 'Profile'}</span>
            </div>
          </div>
        </header>

        {fetchingData ? (
          <div style={{ display: 'flex', justifyContent: 'center', marginTop: '100px' }}>
            <Loader className="animate-spin" size={40} color="#6366f1" />
          </div>
        ) : (
          <>
            {activeTab === 'dashboard' && (
              <>
                {/* Stats */}
                <div className="stats-grid">
                  <div className="stat-card">
                    <div className="stat-title">Linked Profiles</div>
                    <div className="stat-value">{elders.length}</div>
                  </div>
                  <div className="stat-card">
                    <div className="stat-title">Total Unread Alerts</div>
                    <div className="stat-value" style={{ color: elders.some(e => e.unread_alerts_count > 0) ? 'var(--danger)' : 'var(--success)' }}>
                      {elders.reduce((sum, e) => sum + e.unread_alerts_count, 0)}
                    </div>
                  </div>
                  <div className="stat-card">
                    <div className="stat-title">System Status</div>
                    <div className="stat-value" style={{ fontSize: '24px', marginTop: '10px', color: 'var(--success)' }}>Connected Live</div>
                  </div>
                </div>

                {/* Profiles */}
                <div className="section-title">
                  <span>Monitored Family Members</span>
                  <button className="btn-primary" onClick={fetchDashboard}>
                    <Activity size={18} /> Refresh Data
                  </button>
                </div>

                {elders.length === 0 ? (
                  <div className="stat-card" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>
                    <Users size={48} style={{ margin: '0 auto 10px', opacity: 0.5 }} />
                    <h3>No profiles linked yet.</h3>
                    <p>Users need to add your phone number as their guardian in their mobile app.</p>
                  </div>
                ) : (
                  <div className="profiles-grid">
                    {elders.map((elder) => (
                      <div className="profile-card" key={elder.elder_id}>
                        <div className="profile-header">
                          <div className="profile-avatar" style={{ overflow: 'hidden' }}>
                            {elder.elder_photo ? (
                              <img src={`data:image/jpeg;base64,${elder.elder_photo}`} alt={elder.elder_name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                            ) : (
                              <Users size={24} color="#6366f1" />
                            )}
                          </div>
                          <div className="profile-info">
                            <h3>{elder.elder_name}</h3>
                            <p>{elder.elder_phone}</p>
                          </div>
                          <span className="badge" style={{ marginLeft: 'auto', background: 'rgba(99, 102, 241, 0.15)', color: '#6366f1' }}>Monitored</span>
                        </div>
                        
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', margin: '10px 0' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-muted)', fontSize: '14px' }}>
                            <HeartPulse size={16} /> Risk Score: <span style={{ color: elder.risk_score > 50 ? 'var(--danger)' : 'var(--success)' }}>{elder.risk_score}</span>
                          </div>
                          {elder.last_sos_at && (
                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--danger)', fontSize: '14px' }}>
                              <ShieldAlert size={16} /> Last SOS: <span>{formatDateTime(elder.last_sos_at)}</span>
                            </div>
                          )}
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-muted)', fontSize: '14px' }}>
                            <Bell size={16} /> Unread Alerts: <span style={{ color: elder.unread_alerts_count > 0 ? 'var(--danger)' : 'var(--text-main)' }}>{elder.unread_alerts_count}</span>
                          </div>
                        </div>

                        <div className="profile-actions">
                          <button className="btn-secondary" onClick={() => setActiveTab('alerts')}>View Alerts</button>
                          <button className="btn-secondary" onClick={() => setActiveTab('activity')}>Health Stats</button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </>
            )}

            {activeTab === 'alerts' && (
              <div>
                <div className="section-title">
                  <span>Recent Alerts</span>
                  <button className="btn-primary" onClick={fetchDashboard}>
                    <Activity size={18} /> Refresh Alerts
                  </button>
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  {elders.flatMap(e => e.recent_alerts.map(a => ({...a, elder_name: e.elder_name}))).sort((a, b) => new Date(b.created_at) - new Date(a.created_at)).length === 0 ? (
                    <div className="stat-card" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>
                      <ShieldAlert size={48} style={{ margin: '0 auto 10px', opacity: 0.5 }} />
                      <h3>No recent alerts.</h3>
                    </div>
                  ) : (
                    elders.flatMap(e => e.recent_alerts.map(a => ({...a, elder_name: e.elder_name})))
                      .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
                      .map((alert, idx) => (
                      <div key={idx} className="stat-card" style={{ display: 'flex', gap: '16px', alignItems: 'center', padding: '16px' }}>
                        <div style={{ background: alert.severity === 'high' || alert.severity === 'critical' ? 'rgba(239, 68, 68, 0.15)' : 'rgba(245, 158, 11, 0.15)', padding: '12px', borderRadius: '12px', color: alert.severity === 'high' || alert.severity === 'critical' ? 'var(--danger)' : '#f59e0b' }}>
                          <ShieldAlert size={24} />
                        </div>
                        <div>
                          <h4 style={{ fontSize: '16px', fontWeight: 600, color: 'var(--text-main)', margin: '0 0 4px 0' }}>{alert.title} <span style={{ fontSize: '12px', color: 'var(--text-muted)', fontWeight: 'normal' }}>for {alert.elder_name}</span></h4>
                          <p style={{ color: 'var(--text-muted)', fontSize: '14px', margin: 0 }}>{alert.details || alert.alert_type}</p>
                          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>{formatDateTime(alert.created_at)}</span>
                        </div>
                        {!alert.is_read && <span style={{ marginLeft: 'auto', background: 'var(--danger)', color: 'white', padding: '2px 8px', borderRadius: '12px', fontSize: '12px', fontWeight: 600 }}>New</span>}
                      </div>
                    ))
                  )}
                </div>
              </div>
            )}

            {activeTab === 'profiles' && (
              <div>
                <div className="section-title">
                  <span>Manage Monitored Profiles</span>
                  <button className="btn-primary" onClick={() => setShowAddProfileModal(true)}>
                    <Plus size={18} /> Add New Profile
                  </button>
                </div>
                
                <div className="stat-card" style={{ padding: '0' }}>
                  <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                    <thead>
                      <tr style={{ borderBottom: '1px solid var(--card-border)', color: 'var(--text-muted)', textAlign: 'left' }}>
                        <th style={{ padding: '16px' }}>Name</th>
                        <th style={{ padding: '16px' }}>Phone Number</th>
                        <th style={{ padding: '16px' }}>Risk Score</th>
                        <th style={{ padding: '16px' }}>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {elders.map((elder) => (
                        <tr key={elder.elder_id} style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                          <td style={{ padding: '16px', display: 'flex', alignItems: 'center', gap: '12px' }}>
                            <div style={{ width: '32px', height: '32px', borderRadius: '50%', background: 'rgba(99, 102, 241, 0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#6366f1', overflow: 'hidden' }}>
                              {elder.elder_photo ? (
                                <img src={`data:image/jpeg;base64,${elder.elder_photo}`} alt={elder.elder_name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                              ) : (
                                <Users size={16} />
                              )}
                            </div>
                            <span style={{ fontWeight: 500 }}>{elder.elder_name}</span>
                          </td>
                          <td style={{ padding: '16px', color: 'var(--text-muted)' }}>{elder.elder_phone}</td>
                          <td style={{ padding: '16px' }}>
                            <span style={{ color: elder.risk_score > 50 ? 'var(--danger)' : 'var(--success)', fontWeight: 600 }}>{elder.risk_score}</span>
                          </td>
                          <td style={{ padding: '16px' }}>
                            <div style={{ display: 'flex', gap: '8px' }}>
                              <button style={{ background: 'transparent', border: '1px solid var(--card-border)', color: 'var(--text-main)', padding: '6px 12px', borderRadius: '6px', cursor: 'pointer' }}>Edit</button>
                              <button style={{ background: 'rgba(239, 68, 68, 0.1)', border: 'none', color: 'var(--danger)', padding: '6px 12px', borderRadius: '6px', cursor: 'pointer' }}>Remove</button>
                            </div>
                          </td>
                        </tr>
                      ))}
                      {elders.length === 0 && (
                        <tr>
                          <td colSpan="4" style={{ padding: '32px', textAlign: 'center', color: 'var(--text-muted)' }}>No profiles found.</td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            )}

            {activeTab === 'activity' && (
              <div>
                <div className="section-title">
                  <span>Activity & Health Overview</span>
                </div>
                
                <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
                  {elders.map((elder) => (
                    <div key={elder.elder_id} className="stat-card" style={{ display: 'flex', gap: '24px', alignItems: 'flex-start' }}>
                      <div style={{ flex: 1 }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px' }}>
                          <div style={{ width: '48px', height: '48px', borderRadius: '12px', background: 'var(--accent-gradient)', display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }}>
                            {elder.elder_photo ? (
                              <img src={`data:image/jpeg;base64,${elder.elder_photo}`} alt={elder.elder_name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                            ) : (
                              <HeartPulse size={24} color="white" />
                            )}
                          </div>
                          <div>
                            <h3 style={{ margin: 0, fontSize: '18px' }}>{elder.elder_name}</h3>
                            <p style={{ margin: 0, color: 'var(--text-muted)', fontSize: '14px' }}>Phone: {elder.elder_phone}</p>
                          </div>
                        </div>
                        
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                          <div style={{ background: 'rgba(0,0,0,0.2)', padding: '16px', borderRadius: '12px' }}>
                            <p style={{ margin: '0 0 8px 0', color: 'var(--text-muted)', fontSize: '12px', textTransform: 'uppercase' }}>Current Risk Score</p>
                            <span style={{ fontSize: '28px', fontWeight: 'bold', color: elder.risk_score > 50 ? 'var(--danger)' : 'var(--success)' }}>{elder.risk_score}</span>
                          </div>
                          <div style={{ background: 'rgba(0,0,0,0.2)', padding: '16px', borderRadius: '12px' }}>
                            <p style={{ margin: '0 0 8px 0', color: 'var(--text-muted)', fontSize: '12px', textTransform: 'uppercase' }}>Last SOS Time</p>
                            <span style={{ fontSize: '16px', fontWeight: 500, color: elder.last_sos_at ? 'var(--danger)' : 'var(--success)' }}>
                              {elder.last_sos_at ? formatTime(elder.last_sos_at) : 'No SOS Events'}
                            </span>
                          </div>
                        </div>
                      </div>
                      
                      <div style={{ flex: 1, background: 'rgba(255,255,255,0.02)', padding: '20px', borderRadius: '16px', border: '1px solid var(--card-border)' }}>
                        <h4 style={{ margin: '0 0 16px 0', display: 'flex', alignItems: 'center', gap: '8px' }}><Activity size={18} color="var(--accent-color)"/> Recent Activity Logs</h4>
                        {elder.recent_alerts.length > 0 ? (
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                            {elder.recent_alerts.slice(0, 3).map((a, i) => (
                              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: '12px', fontSize: '14px' }}>
                                <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: a.severity === 'high' ? 'var(--danger)' : '#f59e0b' }}></div>
                                <span style={{ color: 'var(--text-main)', flex: 1 }}>{a.title}</span>
                                <span style={{ color: 'var(--text-muted)', fontSize: '12px' }}>{formatDate(a.created_at)}</span>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <p style={{ color: 'var(--text-muted)', fontSize: '14px', margin: 0 }}>No recent activities recorded.</p>
                        )}
                      </div>
                    </div>
                  ))}
                  
                  {elders.length === 0 && (
                    <div style={{ textAlign: 'center', color: 'var(--text-muted)', padding: '40px' }}>No health data available. Add profiles first.</div>
                  )}
                </div>
              </div>
            )}

            {activeTab === 'scams' && (
              <div>
                <div className="section-title">
                  <span>Fraud & Scam Monitor</span>
                  <div style={{ display: 'flex', gap: '10px' }}>
                    <select 
                      value={selectedScamElderId || ''} 
                      onChange={(e) => setSelectedScamElderId(Number(e.target.value))}
                      style={{ padding: '8px 12px', borderRadius: '8px', background: 'rgba(0,0,0,0.2)', border: '1px solid var(--card-border)', color: 'white', cursor: 'pointer' }}
                    >
                      {elders.map(elder => (
                        <option key={elder.elder_id} value={elder.elder_id} style={{ background: '#1e293b' }}>{elder.elder_name}</option>
                      ))}
                    </select>
                    <button className="btn-primary" onClick={() => fetchScamLogs(selectedScamElderId)} disabled={fetchingScams}>
                      {fetchingScams ? <Loader className="animate-spin" size={18} /> : <Activity size={18} />} Refresh
                    </button>
                  </div>
                </div>

                <div className="stat-card" style={{ padding: '0', overflow: 'hidden' }}>
                  <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                    <thead>
                      <tr style={{ borderBottom: '1px solid var(--card-border)', background: 'rgba(0,0,0,0.2)', color: 'var(--text-muted)', textAlign: 'left' }}>
                        <th style={{ padding: '16px' }}>Type</th>
                        <th style={{ padding: '16px' }}>Content</th>
                        <th style={{ padding: '16px' }}>Category</th>
                        <th style={{ padding: '16px' }}>Threat Level</th>
                        <th style={{ padding: '16px' }}>Time</th>
                      </tr>
                    </thead>
                    <tbody>
                      {scamLogs.length === 0 ? (
                        <tr>
                          <td colSpan="5" style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
                            {fetchingScams ? 'Loading...' : 'No fraud attempts detected for this profile! 🎉'}
                          </td>
                        </tr>
                      ) : (
                        scamLogs.map(log => (
                          <tr key={log.id} style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                            <td style={{ padding: '16px' }}>
                              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: log.type === 'sms' ? '#3b82f6' : '#10b981' }}>
                                {log.type === 'sms' ? <MessageSquare size={16} /> : <PhoneCall size={16} />}
                                <span style={{ textTransform: 'uppercase', fontSize: '12px', fontWeight: 600 }}>{log.type}</span>
                              </div>
                            </td>
                            <td style={{ padding: '16px', maxWidth: '300px' }}>
                              <p style={{ margin: 0, fontSize: '14px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }} title={log.content}>{log.content}</p>
                              {log.explanation && <p style={{ margin: '4px 0 0 0', fontSize: '12px', color: 'var(--danger)' }}>{log.explanation}</p>}
                            </td>
                            <td style={{ padding: '16px', fontSize: '14px' }}>
                              <span style={{ padding: '4px 8px', background: 'rgba(255,255,255,0.1)', borderRadius: '4px' }}>{log.category}</span>
                            </td>
                            <td style={{ padding: '16px' }}>
                              <span style={{ color: log.confidence > 80 ? 'var(--danger)' : '#f59e0b', fontWeight: 600 }}>{log.confidence}%</span>
                            </td>
                            <td style={{ padding: '16px', color: 'var(--text-muted)', fontSize: '14px' }}>
                              {formatDateTime(log.created_at)}
                            </td>
                          </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            )}

            {activeTab === 'settings' && (
              <div className="stat-card" style={{ textAlign: 'center', padding: '60px', color: 'var(--text-muted)' }}>
                <Settings size={48} style={{ margin: '0 auto 15px', opacity: 0.5, color: 'var(--accent-color)' }} />
                <h2>Settings</h2>
                <p style={{ marginTop: '10px' }}>Dashboard settings and preferences will be available here soon.</p>
              </div>
            )}
          </>
        )}
      </main>

      {/* Add Profile Modal */}
      {showAddProfileModal && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.7)', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div className="stat-card" style={{ width: '400px', padding: '30px' }}>
            <h2 style={{ marginBottom: '20px' }}>Link New Profile</h2>
            <p style={{ color: 'var(--text-muted)', fontSize: '14px', marginBottom: '20px' }}>
              Enter the phone number of the elder/child you want to monitor. They must have an account on the ElderCareAI mobile app first.
            </p>
            
            {addProfileError && <div style={{ color: 'var(--danger)', marginBottom: '15px', fontSize: '14px' }}>{addProfileError}</div>}
            
            <form onSubmit={handleAddProfile} style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
              <div>
                <label style={{ color: 'var(--text-muted)', fontSize: '14px', marginBottom: '8px', display: 'block' }}>Phone Number</label>
                <input 
                  type="text" 
                  value={newProfilePhone}
                  onChange={(e) => setNewProfilePhone(e.target.value)}
                  placeholder="e.g. 9876543210"
                  style={{ width: '100%', padding: '12px', borderRadius: '8px', background: 'rgba(0,0,0,0.2)', border: '1px solid var(--card-border)', color: 'white' }}
                  required
                />
              </div>
              <div style={{ display: 'flex', gap: '10px', marginTop: '10px' }}>
                <button type="button" className="btn-secondary" style={{ flex: 1 }} onClick={() => setShowAddProfileModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" style={{ flex: 1, justifyContent: 'center' }} disabled={addProfileLoading}>
                  {addProfileLoading ? <Loader className="animate-spin" size={18} /> : 'Link Profile'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
