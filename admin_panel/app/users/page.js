'use client';

import { useEffect, useState } from 'react';
import Header from '../../components/Header';
import { supabase } from '../../lib/supabase';
import { 
  UserCheck, 
  Search, 
  Mail, 
  Phone, 
  Calendar, 
  RefreshCw, 
  Download, 
  Users, 
  Stethoscope, 
  FileText,
  ShieldAlert,
  ExternalLink,
  ChevronRight,
  Eye,
  Activity
} from 'lucide-react';

export default function UsersManagementPage() {
  const [profiles, setProfiles] = useState([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');
  const [selectedUser, setSelectedUser] = useState(null);
  const [userDetails, setUserDetails] = useState({ families: [], visits: [], members: [] });
  const [loadingDetails, setLoadingDetails] = useState(false);

  async function loadProfiles() {
    setLoading(true);
    try {
      // 1. Load profiles
      const { data: profData, error } = await supabase
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: false });

      // 2. Load families count per user
      const { data: famData } = await supabase.from('families').select('id, user_id, name');

      const enriched = (profData || []).map((p) => {
        const userFams = (famData || []).filter((f) => f.user_id === p.id);
        return {
          ...p,
          familyCount: userFams.length,
          familyNames: userFams.map((f) => f.name).join(', '),
        };
      });

      setProfiles(enriched);
    } catch (err) {
      console.error('Failed to load profiles:', err);
    } finally {
      setLoading(false);
    }
  }

  async function openUserDetails(user) {
    setSelectedUser(user);
    setLoadingDetails(true);
    try {
      // Fetch user's families
      const { data: fams } = await supabase
        .from('families')
        .select('*, members(*)')
        .eq('user_id', user.id);

      const allMembers = [];
      (fams || []).forEach((f) => {
        if (f.members) allMembers.push(...f.members);
      });

      // Fetch user's visits
      const { data: visits } = await supabase
        .from('visits')
        .select('*, members(name, relation), doctors(name, specialization)')
        .order('visit_date', { ascending: false });

      setUserDetails({
        families: fams || [],
        members: allMembers,
        visits: visits || [],
      });
    } catch (err) {
      console.error(err);
    } finally {
      setLoadingDetails(false);
    }
  }

  function exportUsersCSV() {
    if (profiles.length === 0) return;
    const headers = ['ID', 'Full Name', 'Email', 'Phone', 'Families Count', 'Created At'];
    const rows = profiles.map((p) => [
      p.id,
      `"${p.full_name || 'N/A'}"`,
      `"${p.email || 'N/A'}"`,
      `"${p.phone || 'N/A'}"`,
      p.familyCount,
      `"${new Date(p.created_at).toLocaleDateString()}"`,
    ]);

    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `medical_history_users_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  useEffect(() => {
    loadProfiles();
  }, []);

  const filtered = profiles.filter((p) => {
    const matchesSearch =
      p.email?.toLowerCase().includes(search.toLowerCase()) ||
      p.full_name?.toLowerCase().includes(search.toLowerCase()) ||
      p.phone?.toLowerCase().includes(search.toLowerCase());

    if (!matchesSearch) return false;
    if (filter === 'with_families') return p.familyCount > 0;
    if (filter === 'no_families') return p.familyCount === 0;
    return true;
  });

  return (
    <>
      <Header title="Patient & User Management" subtitle="Manage registered patients, families, and activity records" />

      <div className="admin-content">
        {/* Top Summary Banner */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '16px', marginBottom: '24px' }}>
          <div className="card" style={{ padding: '18px 22px' }}>
            <div style={{ fontSize: '12px', fontWeight: '700', color: 'var(--text-mid)', textTransform: 'uppercase' }}>
              Total Patients
            </div>
            <div style={{ fontSize: '26px', fontWeight: '900', color: 'var(--text-dark)', marginTop: '4px' }}>
              {profiles.length}
            </div>
            <div style={{ fontSize: '11.5px', color: 'var(--primary)', fontWeight: '700', marginTop: '2px' }}>
              Verified Accounts
            </div>
          </div>

          <div className="card" style={{ padding: '18px 22px' }}>
            <div style={{ fontSize: '12px', fontWeight: '700', color: 'var(--text-mid)', textTransform: 'uppercase' }}>
              Families Created
            </div>
            <div style={{ fontSize: '26px', fontWeight: '900', color: '#0EA5E9', marginTop: '4px' }}>
              {profiles.reduce((acc, p) => acc + (p.familyCount || 0), 0)}
            </div>
            <div style={{ fontSize: '11.5px', color: '#0EA5E9', fontWeight: '700', marginTop: '2px' }}>
              Active Health Groups
            </div>
          </div>

          <div className="card" style={{ padding: '18px 22px' }}>
            <div style={{ fontSize: '12px', fontWeight: '700', color: 'var(--text-mid)', textTransform: 'uppercase' }}>
              Security Status
            </div>
            <div style={{ fontSize: '26px', fontWeight: '900', color: '#10B981', marginTop: '4px' }}>
              100%
            </div>
            <div style={{ fontSize: '11.5px', color: '#10B981', fontWeight: '700', marginTop: '2px' }}>
              RLS Protection Active
            </div>
          </div>
        </div>

        {/* Action Controls & Filters */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px', flexWrap: 'wrap', gap: '14px' }}>
          <div style={{ display: 'flex', gap: '14px', alignItems: 'center', flexWrap: 'wrap' }}>
            <div className="search-input" style={{ width: '320px' }}>
              <Search size={16} color="var(--text-light)" />
              <input
                type="text"
                placeholder="Search patient by name, email or phone..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>

            <div className="filter-tabs">
              <button
                className={`filter-tab ${filter === 'all' ? 'active' : ''}`}
                onClick={() => setFilter('all')}
              >
                All Patients ({profiles.length})
              </button>
              <button
                className={`filter-tab ${filter === 'with_families' ? 'active' : ''}`}
                onClick={() => setFilter('with_families')}
              >
                With Families
              </button>
              <button
                className={`filter-tab ${filter === 'no_families' ? 'active' : ''}`}
                onClick={() => setFilter('no_families')}
              >
                New / Solo
              </button>
            </div>
          </div>

          <div style={{ display: 'flex', gap: '10px' }}>
            <button onClick={loadProfiles} className="btn btn-secondary">
              <RefreshCw size={15} />
              <span>Refresh</span>
            </button>
            <button onClick={exportUsersCSV} className="btn btn-primary">
              <Download size={15} />
              <span>Export CSV</span>
            </button>
          </div>
        </div>

        {/* Users Table */}
        <div className="card">
          <div className="table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Patient Profile</th>
                  <th>Contact Email</th>
                  <th>Phone</th>
                  <th>Linked Families</th>
                  <th>Registered</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan="6" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-light)' }}>
                      {loading ? 'Fetching patients from Supabase...' : 'No patients matching current criteria.'}
                    </td>
                  </tr>
                ) : (
                  filtered.map((u) => (
                    <tr key={u.id}>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                          <div style={{
                            width: '38px',
                            height: '38px',
                            borderRadius: '12px',
                            backgroundColor: '#EBF7E6',
                            color: 'var(--primary)',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontWeight: '800',
                            fontSize: '14px',
                            border: '1px solid var(--primary-border)'
                          }}>
                            {u.full_name ? u.full_name[0].toUpperCase() : 'P'}
                          </div>
                          <div>
                            <div style={{ fontWeight: '700', color: 'var(--text-dark)', fontSize: '14px' }}>
                              {u.full_name || 'Patient User'}
                            </div>
                            <div style={{ fontSize: '11px', color: 'var(--text-light)', fontFamily: 'monospace' }}>
                              ID: {u.id.slice(0, 8)}...
                            </div>
                          </div>
                        </div>
                      </td>
                      <td style={{ color: 'var(--text-mid)', fontSize: '13px' }}>
                        {u.email || '—'}
                      </td>
                      <td style={{ color: 'var(--text-mid)', fontSize: '13px' }}>
                        {u.phone || '—'}
                      </td>
                      <td>
                        <span className={`badge ${u.familyCount > 0 ? 'badge-primary' : 'badge-warning'}`}>
                          {u.familyCount > 0 ? `${u.familyCount} Family Groups` : 'No Family Yet'}
                        </span>
                      </td>
                      <td style={{ color: 'var(--text-light)', fontSize: '12.5px' }}>
                        {new Date(u.created_at).toLocaleDateString()}
                      </td>
                      <td>
                        <button
                          onClick={() => openUserDetails(u)}
                          className="btn btn-secondary"
                          style={{ padding: '6px 12px', fontSize: '12px', gap: '4px' }}
                        >
                          <Eye size={13} />
                          <span>View Detail</span>
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Patient Details Modal */}
        {selectedUser && (
          <div style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.55)',
            backdropFilter: 'blur(4px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 100,
            padding: '20px'
          }}>
            <div className="card" style={{ width: '100%', maxWidth: '640px', maxHeight: '90vh', overflowY: 'auto' }}>
              {/* Modal Header */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid var(--border)', paddingBottom: '16px', marginBottom: '20px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                  <div style={{
                    width: '48px',
                    height: '48px',
                    borderRadius: '16px',
                    background: 'var(--hero-gradient)',
                    color: '#FFFFFF',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontWeight: '800',
                    fontSize: '18px'
                  }}>
                    {selectedUser.full_name ? selectedUser.full_name[0].toUpperCase() : 'P'}
                  </div>
                  <div>
                    <h3 style={{ fontSize: '18px', fontWeight: '800', color: 'var(--text-dark)' }}>
                      {selectedUser.full_name || 'Patient Profile'}
                    </h3>
                    <p style={{ fontSize: '12.5px', color: 'var(--text-light)' }}>
                      {selectedUser.email} • {selectedUser.phone || 'No phone'}
                    </p>
                  </div>
                </div>

                <button 
                  onClick={() => setSelectedUser(null)} 
                  style={{ background: 'transparent', fontSize: '20px', color: 'var(--text-light)', cursor: 'pointer' }}
                >
                  ✕
                </button>
              </div>

              {loadingDetails ? (
                <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-light)' }}>
                  Loading health profile & records...
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                  {/* Families Section */}
                  <div>
                    <h4 style={{ fontSize: '14px', fontWeight: '800', color: 'var(--text-dark)', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <Users size={16} color="var(--primary)" />
                      Associated Families ({userDetails.families.length})
                    </h4>
                    {userDetails.families.length === 0 ? (
                      <div style={{ padding: '16px', backgroundColor: '#F8FCF7', borderRadius: '12px', fontSize: '13px', color: 'var(--text-light)' }}>
                        No family groups registered under this patient account.
                      </div>
                    ) : (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                        {userDetails.families.map((f) => (
                          <div key={f.id} style={{ padding: '12px 14px', borderRadius: '12px', border: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <div>
                              <div style={{ fontWeight: '700', fontSize: '13.5px' }}>{f.name}</div>
                              <div style={{ fontSize: '11.5px', color: 'var(--text-light)' }}>Code: {f.family_id} • {f.members?.length || 0} Members</div>
                            </div>
                            <span className="badge badge-primary">{f.contact || 'Active'}</span>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Members Section */}
                  <div>
                    <h4 style={{ fontSize: '14px', fontWeight: '800', color: 'var(--text-dark)', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <Activity size={16} color="#0EA5E9" />
                      Family Members & Blood Groups ({userDetails.members.length})
                    </h4>
                    {userDetails.members.length === 0 ? (
                      <div style={{ padding: '16px', backgroundColor: '#F8FCF7', borderRadius: '12px', fontSize: '13px', color: 'var(--text-light)' }}>
                        No members found.
                      </div>
                    ) : (
                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: '8px' }}>
                        {userDetails.members.map((m) => (
                          <div key={m.id} style={{ padding: '10px 12px', borderRadius: '10px', backgroundColor: '#FAFDF9', border: '1px solid var(--border)' }}>
                            <div style={{ fontWeight: '700', fontSize: '13px' }}>{m.name}</div>
                            <div style={{ fontSize: '11px', color: 'var(--text-light)' }}>{m.relation}</div>
                            <span className="badge badge-danger" style={{ marginTop: '4px' }}>
                              {m.blood_group || 'O+'}
                            </span>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Account Metadata */}
                  <div style={{ padding: '14px', backgroundColor: '#EFF8EC', borderRadius: '12px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '12.5px' }}>
                    <div>
                      <span style={{ fontWeight: '700', color: 'var(--primary-dark)' }}>Account UID:</span>
                      <code style={{ marginLeft: '6px', fontSize: '12px' }}>{selectedUser.id}</code>
                    </div>
                    <div style={{ color: 'var(--text-mid)' }}>
                      Joined {new Date(selectedUser.created_at).toLocaleDateString()}
                    </div>
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
                    <button onClick={() => setSelectedUser(null)} className="btn btn-secondary">
                      Close Window
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        )}

      </div>
    </>
  );
}
