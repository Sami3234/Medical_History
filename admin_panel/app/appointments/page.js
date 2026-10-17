'use client';

import { useState } from 'react';
import Header from '../../components/Header';
import { Clock, Calendar, Search, Stethoscope, User, Plus, CheckCircle2, AlertCircle } from 'lucide-react';

export default function AppointmentsPage() {
  const [search, setSearch] = useState('');
  const [tab, setTab] = useState('upcoming');

  const [appointments, setAppointments] = useState([
    {
      id: 'apt-1',
      patientName: 'Ali Khan',
      relation: 'Father',
      doctorName: 'Dr. Sarah Ahmed',
      specialty: 'Cardiologist',
      hospital: 'National Heart Institute',
      dateTime: '2026-10-22 at 10:30 AM',
      type: 'Routine Follow-up',
      status: 'Confirmed',
    },
    {
      id: 'apt-2',
      patientName: 'Fatima Bibi',
      relation: 'Mother',
      doctorName: 'Dr. Tariq Mahmood',
      specialty: 'Orthopedic',
      hospital: 'City Care Hospital',
      dateTime: '2026-10-25 at 04:00 PM',
      type: 'Joint Pain Review',
      status: 'Pending',
    },
    {
      id: 'apt-3',
      patientName: 'Mohammad Khan',
      relation: 'Son',
      doctorName: 'Dr. Bilal Qureshi',
      specialty: 'Pediatrician',
      hospital: 'Children Medical Center',
      dateTime: '2026-10-28 at 11:15 AM',
      type: 'Annual Health Check',
      status: 'Confirmed',
    },
    {
      id: 'apt-4',
      patientName: 'Zainab Bibi',
      relation: 'Daughter',
      doctorName: 'Dr. Ayesha Malik',
      specialty: 'Dermatologist',
      hospital: 'Skin & Laser Clinic',
      dateTime: '2026-10-15 at 02:30 PM',
      type: 'Allergy Evaluation',
      status: 'Completed',
    },
  ]);

  const filtered = appointments.filter((apt) => {
    const matchesSearch =
      apt.patientName.toLowerCase().includes(search.toLowerCase()) ||
      apt.doctorName.toLowerCase().includes(search.toLowerCase()) ||
      apt.specialty.toLowerCase().includes(search.toLowerCase());

    if (!matchesSearch) return false;
    if (tab === 'upcoming') return apt.status !== 'Completed';
    if (tab === 'completed') return apt.status === 'Completed';
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
                Upcoming Appointments ({appointments.filter(a => a.status !== 'Completed').length})
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
                {filtered.length === 0 ? (
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
