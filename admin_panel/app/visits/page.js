'use client';

import { useEffect, useState } from 'react';
import Header from '../../components/Header';
import { supabase } from '../../lib/supabase';
import { CalendarDays, Search, RefreshCw, FileText, Stethoscope, User } from 'lucide-react';

export default function VisitsPage() {
  const [visits, setVisits] = useState([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);

  async function loadVisits() {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('visits')
        .select('*, members(name, relation, blood_group), doctors(name, specialization, hospital)')
        .order('visit_date', { ascending: false });

      if (data) setVisits(data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadVisits();
  }, []);

  const filtered = visits.filter((v) =>
    v.diagnosis?.toLowerCase().includes(search.toLowerCase()) ||
    v.symptoms?.toLowerCase().includes(search.toLowerCase()) ||
    v.members?.name?.toLowerCase().includes(search.toLowerCase()) ||
    v.doctors?.name?.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <>
      <Header title="Consultations & Visits" subtitle="Track patient medical visits, diagnosis and treatment history" />

      <div className="admin-content">
        {/* Top Control Bar */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', flexWrap: 'wrap', gap: '14px' }}>
          <div className="search-input" style={{ width: '340px' }}>
            <Search size={16} color="var(--text-light)" />
            <input
              type="text"
              placeholder="Search by diagnosis, symptoms, patient or doctor..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <button onClick={loadVisits} className="btn btn-secondary">
            <RefreshCw size={15} />
            <span>Refresh</span>
          </button>
        </div>

        {/* Visits Table */}
        <div className="card">
          <div className="table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Patient Member</th>
                  <th>Attending Doctor</th>
                  <th>Diagnosis</th>
                  <th>Symptoms / Reason</th>
                  <th>Treatment / Rx</th>
                  <th>Visit Date</th>
                </tr>
              </thead>
              <tbody>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan="6" style={{ textAlign: 'center', padding: '36px', color: 'var(--text-light)' }}>
                      {loading ? 'Fetching consultations...' : 'No visits recorded yet.'}
                    </td>
                  </tr>
                ) : (
                  filtered.map((v) => (
                    <tr key={v.id}>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <User size={15} color="var(--primary)" />
                          <div>
                            <div style={{ fontWeight: '700', color: 'var(--text-dark)' }}>
                              {v.members?.name || 'Unknown Patient'}
                            </div>
                            <div style={{ fontSize: '11px', color: 'var(--text-light)' }}>
                              {v.members?.relation} • Blood: {v.members?.blood_group || 'N/A'}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <Stethoscope size={15} color="#8B5CF6" />
                          <div>
                            <div style={{ fontWeight: '600', color: 'var(--text-dark)' }}>
                              {v.doctors?.name || 'General Practitioner'}
                            </div>
                            <div style={{ fontSize: '11px', color: 'var(--text-light)' }}>
                              {v.doctors?.specialization || v.doctors?.hospital || 'Clinic'}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td>
                        <span className="badge badge-info" style={{ fontWeight: '700' }}>
                          {v.diagnosis || 'General Consultation'}
                        </span>
                      </td>
                      <td style={{ color: 'var(--text-mid)', fontSize: '13px', maxWidth: '200px' }}>
                        {v.symptoms || '—'}
                      </td>
                      <td style={{ color: 'var(--text-mid)', fontSize: '13px', maxWidth: '200px' }}>
                        {v.treatment || '—'}
                      </td>
                      <td style={{ color: 'var(--text-light)', fontSize: '12.5px', whiteSpace: 'nowrap' }}>
                        {new Date(v.visit_date).toLocaleDateString()}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

      </div>
    </>
  );
}
