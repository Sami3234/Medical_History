'use client';

import { useEffect, useState } from 'react';
import Header from '../../components/Header';
import { supabase } from '../../lib/supabase';
import { Clock, Calendar, Search, Stethoscope, User, Plus, CheckCircle2, AlertCircle } from 'lucide-react';

export default function AppointmentsPage() {
  const [search, setSearch] = useState('');
  const [tab, setTab] = useState('upcoming');

  const [appointments, setAppointments] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadAppointments() {
      const { data, error } = await supabase
        .from('appointments')
        .select('*, members(name, relation)')
        .order('appointment_time', { ascending: false });

      if (!error) {
        setAppointments((data || []).map((appointment) => ({
          id: appointment.id,
          patientName: appointment.members?.name || 'Family member',
          relation: appointment.members?.relation || '',
          doctorName: appointment.doctor_name,
          specialty: appointment.specialty || '',
          hospital: appointment.hospital || 'Not specified',
          dateTime: new Date(appointment.appointment_time).toLocaleString(),
          type: appointment.notes || 'Consultation',
          status: appointment.status || 'upcoming',
        })));
      }
      setLoading(false);
    }
    loadAppointments();
  }, []);

  const filtered = appointments.filter((apt) => {
    const matchesSearch =
      apt.patientName.toLowerCase().includes(search.toLowerCase()) ||
      apt.doctorName.toLowerCase().includes(search.toLowerCase()) ||
      apt.specialty.toLowerCase().includes(search.toLowerCase());

    if (!matchesSearch) return false;
    if (tab === 'upcoming') return apt.status.toLowerCase() !== 'completed';
    if (tab === 'completed') return apt.status.toLowerCase() === 'completed';
    return true;
  });

  return (
    <>
      <Header title="Appointments & Consultations" subtitle="Schedule and track clinical visits with registered doctors" />

      <div className="admin-content">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', flexWrap: 'wrap', gap: '14px' }}>
          <div style={{ display: 'flex', gap: '14px', alignItems: 'center', flexWrap: 'wrap' }}>
            <div className="search-input" style={{ width: '320px' }}>
              <Search size={16} color="var(--text-light)" />
              <input
                type="text"
                placeholder="Search by patient, doctor or clinic..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>

            <div className="filter-tabs">
              <button
                className={`filter-tab ${tab === 'upcoming' ? 'active' : ''}`}
                onClick={() => setTab('upcoming')}
              >
                Upcoming Appointments ({appointments.filter(a => a.status.toLowerCase() !== 'completed').length})
              </button>
              <button
                className={`filter-tab ${tab === 'completed' ? 'active' : ''}`}
                onClick={() => setTab('completed')}
              >
                Completed History
              </button>
              <button
                className={`filter-tab ${tab === 'all' ? 'active' : ''}`}
                onClick={() => setTab('all')}
              >
                All Records
              </button>
            </div>
          </div>
        </div>

        {/* Appointments Table */}
        <div className="card">
          <div className="table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Patient Member</th>
                  <th>Healthcare Provider</th>
                  <th>Hospital / Location</th>
                  <th>Appointment Time</th>
                  <th>Reason / Type</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan="6" style={{ textAlign: 'center', padding: '36px', color: 'var(--text-light)' }}>
                      Loading appointments...
                    </td>
                  </tr>
                ) : filtered.length === 0 ? (
                  <tr>
                    <td colSpan="6" style={{ textAlign: 'center', padding: '36px', color: 'var(--text-light)' }}>
                      No appointments matching current criteria.
                    </td>
                  </tr>
                ) : (
                  filtered.map((apt) => (
                    <tr key={apt.id}>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <User size={15} color="var(--primary)" />
                          <div>
                            <div style={{ fontWeight: '700', color: 'var(--text-dark)' }}>{apt.patientName}</div>
                            <div style={{ fontSize: '11px', color: 'var(--text-light)' }}>{apt.relation}</div>
                          </div>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <Stethoscope size={15} color="#8B5CF6" />
                          <div>
                            <div style={{ fontWeight: '600', color: 'var(--text-dark)' }}>{apt.doctorName}</div>
                            <div style={{ fontSize: '11px', color: 'var(--text-light)' }}>{apt.specialty}</div>
                          </div>
                        </div>
                      </td>
                      <td style={{ color: 'var(--text-mid)', fontSize: '13px' }}>
                        {apt.hospital}
                      </td>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12.5px', color: 'var(--text-dark)', fontWeight: '600' }}>
                          <Clock size={13} color="var(--primary)" />
                          <span>{apt.dateTime}</span>
                        </div>
                      </td>
                      <td style={{ color: 'var(--text-mid)', fontSize: '13px' }}>
                        {apt.type}
                      </td>
                      <td>
                        <span className={`badge ${
                          apt.status === 'Confirmed' ? 'badge-primary' :
                          apt.status === 'Completed' ? 'badge-info' : 'badge-warning'
                        }`}>
                          {apt.status}
                        </span>
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
