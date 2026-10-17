'use client';

import { useEffect, useState } from 'react';
import Header from '../../components/Header';
import { supabase } from '../../lib/supabase';
import { Stethoscope, Search, Phone, Building2, MapPin, Plus, RefreshCw } from 'lucide-react';

export default function DoctorsPage() {
  const [doctors, setDoctors] = useState([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    specialization: '',
    hospital: '',
    phone: '',
    address: '',
    notes: '',
  });

  async function loadDoctors() {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('doctors')
        .select('*')
        .order('name', { ascending: true });

      if (data) setDoctors(data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }

  async function handleAddDoctor(e) {
    e.preventDefault();
    if (!formData.name) return;

    try {
      const { error } = await supabase.from('doctors').insert([
        {
          name: formData.name,
          specialization: formData.specialization,
          hospital: formData.hospital,
          phone: formData.phone,
          address: formData.address,
          notes: formData.notes,
        },
      ]);

      if (!error) {
        setShowAddModal(false);
        setFormData({ name: '', specialization: '', hospital: '', phone: '', address: '', notes: '' });
        loadDoctors();
      }
    } catch (err) {
      console.error(err);
    }
  }

  useEffect(() => {
    loadDoctors();
  }, []);

  const filtered = doctors.filter((d) =>
    d.name?.toLowerCase().includes(search.toLowerCase()) ||
    d.specialization?.toLowerCase().includes(search.toLowerCase()) ||
    d.hospital?.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <>
      <Header title="Doctors Directory" subtitle="Manage healthcare providers, specialists & hospitals" />

      <div className="admin-content">
        {/* Top Control Bar */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', flexWrap: 'wrap', gap: '14px' }}>
          <div className="search-input" style={{ width: '320px' }}>
            <Search size={16} color="var(--text-light)" />
            <input
              type="text"
              placeholder="Search by doctor name or specialty..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <div style={{ display: 'flex', gap: '12px' }}>
            <button onClick={loadDoctors} className="btn btn-secondary">
              <RefreshCw size={15} />
              <span>Refresh</span>
            </button>
            <button onClick={() => setShowAddModal(true)} className="btn btn-primary">
              <Plus size={16} />
              <span>Add New Doctor</span>
            </button>
          </div>
        </div>

        {/* Doctors Grid Cards */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '20px' }}>
          {filtered.length === 0 ? (
            <div className="card" style={{ gridColumn: '1 / -1', textAlign: 'center', padding: '40px', color: 'var(--text-light)' }}>
              {loading ? 'Fetching doctor directory...' : 'No doctors found.'}
            </div>
          ) : (
            filtered.map((doc) => (
              <div key={doc.id} className="card" style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                  <div style={{
                    width: '48px',
                    height: '48px',
                    borderRadius: '16px',
                    backgroundColor: '#EBF7E6',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: 'var(--primary)',
                    flexShrink: 0
                  }}>
                    <Stethoscope size={24} />
                  </div>
                  <div>
                    <h4 style={{ fontSize: '16px', fontWeight: '800', color: 'var(--text-dark)' }}>
                      {doc.name}
                    </h4>
                    <span className="badge badge-primary" style={{ marginTop: '4px' }}>
                      {doc.specialization || 'General Physician'}
                    </span>
                  </div>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '13px', color: 'var(--text-mid)', marginTop: '4px' }}>
                  {doc.hospital && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <Building2 size={15} color="var(--primary)" />
                      <span>{doc.hospital}</span>
                    </div>
                  )}
                  {doc.phone && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <Phone size={15} color="var(--primary)" />
                      <span>{doc.phone}</span>
                    </div>
                  )}
                  {doc.address && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <MapPin size={15} color="var(--primary)" />
                      <span>{doc.address}</span>
                    </div>
                  )}
                </div>

                {doc.notes && (
                  <div style={{
                    padding: '10px 12px',
                    backgroundColor: '#F8FAF7',
                    borderRadius: '10px',
                    fontSize: '12px',
                    color: 'var(--text-mid)',
                    lineHeight: 1.4
                  }}>
                    {doc.notes}
                  </div>
                )}
              </div>
            ))
          )}
        </div>

        {/* Add Doctor Modal */}
        {showAddModal && (
          <div style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 100,
            padding: '20px'
          }}>
            <div className="card" style={{ width: '100%', maxWidth: '480px', maxHeight: '90vh', overflowY: 'auto' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
                <h3 style={{ fontSize: '18px', fontWeight: '800' }}>Add Doctor</h3>
                <button onClick={() => setShowAddModal(false)} style={{ fontSize: '18px', background: 'transparent' }}>✕</button>
              </div>

              <form onSubmit={handleAddDoctor} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div>
                  <label style={{ fontSize: '13px', fontWeight: '700', color: 'var(--text-dark)', display: 'block', marginBottom: '6px' }}>Doctor Name *</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Dr. Ahmed Khan"
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    style={{ width: '100%', padding: '10px 14px', borderRadius: '10px', border: '1px solid var(--border)', fontSize: '14px' }}
                  />
                </div>

                <div>
                  <label style={{ fontSize: '13px', fontWeight: '700', color: 'var(--text-dark)', display: 'block', marginBottom: '6px' }}>Specialization</label>
                  <input
                    type="text"
                    placeholder="e.g. Cardiologist, Pediatrician"
                    value={formData.specialization}
                    onChange={(e) => setFormData({ ...formData, specialization: e.target.value })}
                    style={{ width: '100%', padding: '10px 14px', borderRadius: '10px', border: '1px solid var(--border)', fontSize: '14px' }}
                  />
                </div>

                <div>
                  <label style={{ fontSize: '13px', fontWeight: '700', color: 'var(--text-dark)', display: 'block', marginBottom: '6px' }}>Hospital / Clinic</label>
                  <input
                    type="text"
                    placeholder="e.g. City General Hospital"
                    value={formData.hospital}
                    onChange={(e) => setFormData({ ...formData, hospital: e.target.value })}
                    style={{ width: '100%', padding: '10px 14px', borderRadius: '10px', border: '1px solid var(--border)', fontSize: '14px' }}
                  />
                </div>

                <div>
                  <label style={{ fontSize: '13px', fontWeight: '700', color: 'var(--text-dark)', display: 'block', marginBottom: '6px' }}>Phone Number</label>
                  <input
                    type="text"
                    placeholder="+92 300 1234567"
                    value={formData.phone}
                    onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                    style={{ width: '100%', padding: '10px 14px', borderRadius: '10px', border: '1px solid var(--border)', fontSize: '14px' }}
                  />
                </div>

                <div>
                  <label style={{ fontSize: '13px', fontWeight: '700', color: 'var(--text-dark)', display: 'block', marginBottom: '6px' }}>Clinic Address</label>
                  <input
                    type="text"
                    placeholder="Clinic street address"
                    value={formData.address}
                    onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                    style={{ width: '100%', padding: '10px 14px', borderRadius: '10px', border: '1px solid var(--border)', fontSize: '14px' }}
                  />
                </div>

                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '12px' }}>
                  <button type="button" onClick={() => setShowAddModal(false)} className="btn btn-secondary">
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary">
                    Save Doctor
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

      </div>
    </>
  );
}
