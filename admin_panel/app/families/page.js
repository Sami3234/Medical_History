'use client';

import { useEffect, useState } from 'react';
import Header from '../../components/Header';
import { supabase } from '../../lib/supabase';
import { Users, Search, Plus, UserPlus, Phone, MapPin, RefreshCw } from 'lucide-react';

export default function FamiliesPage() {
  const [families, setFamilies] = useState([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [selectedFamily, setSelectedFamily] = useState(null);
  const [members, setMembers] = useState([]);
  const [loadingMembers, setLoadingMembers] = useState(false);

  async function loadFamilies() {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('families')
        .select('*')
        .order('created_at', { ascending: false });

      if (data) setFamilies(data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }

  async function loadMembers(familyId) {
    setLoadingMembers(true);
    try {
      const { data } = await supabase
        .from('members')
        .select('*')
        .eq('family_id', familyId)
        .order('created_at', { ascending: true });

      if (data) setMembers(data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoadingMembers(false);
    }
  }

  useEffect(() => {
    loadFamilies();
  }, []);

  const filtered = families.filter((f) =>
    f.name?.toLowerCase().includes(search.toLowerCase()) ||
    f.family_id?.toLowerCase().includes(search.toLowerCase()) ||
    f.contact?.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <>
      <Header title="Families & Members" subtitle="Manage family trees and member health profiles" />

      <div className="admin-content">
        {/* Top Control Bar */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', flexWrap: 'wrap', gap: '14px' }}>
          <div className="search-input" style={{ width: '320px' }}>
            <Search size={16} color="var(--text-light)" />
            <input
              type="text"
              placeholder="Search family by name, ID or phone..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <div style={{ display: 'flex', gap: '12px' }}>
            <button onClick={loadFamilies} className="btn btn-secondary">
              <RefreshCw size={15} />
              <span>Refresh</span>
            </button>
          </div>
        </div>

        {/* Content Layout: Families List on Left, Selected Family Members on Right */}
        <div style={{ display: 'grid', gridTemplateColumns: selectedFamily ? '1.4fr 1fr' : '1fr', gap: '24px' }}>
          
          {/* Families Table Card */}
          <div className="card">
            <h3 style={{ fontSize: '17px', fontWeight: '800', color: 'var(--text-dark)', marginBottom: '16px' }}>
              Family Groups ({filtered.length})
            </h3>

            <div className="table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Family Name</th>
                    <th>Code</th>
                    <th>Contact</th>
                    <th>Address</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.length === 0 ? (
                    <tr>
                      <td colSpan="5" style={{ textAlign: 'center', padding: '36px', color: 'var(--text-light)' }}>
                        {loading ? 'Loading families...' : 'No families found.'}
                      </td>
                    </tr>
                  ) : (
                    filtered.map((fam) => {
                      const isSelected = selectedFamily?.id === fam.id;
                      return (
                        <tr 
                          key={fam.id} 
                          style={{ backgroundColor: isSelected ? '#F3FAF0' : 'transparent', cursor: 'pointer' }}
                          onClick={() => {
                            setSelectedFamily(fam);
                            loadMembers(fam.id);
                          }}
                        >
                          <td style={{ fontWeight: '700', color: 'var(--text-dark)' }}>
                            {fam.name}
                          </td>
                          <td>
                            <span className="badge badge-primary">{fam.family_id}</span>
                          </td>
                          <td style={{ color: 'var(--text-mid)', fontSize: '13px' }}>
                            {fam.contact || '—'}
                          </td>
                          <td style={{ color: 'var(--text-mid)', fontSize: '13px' }}>
                            {fam.address || '—'}
                          </td>
                          <td>
                            <button 
                              className="btn btn-secondary" 
                              style={{ padding: '6px 12px', fontSize: '12px' }}
                              onClick={(e) => {
                                e.stopPropagation();
                                setSelectedFamily(fam);
                                loadMembers(fam.id);
                              }}
                            >
                              View Members
                            </button>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Members Detail Card if selected */}
          {selectedFamily && (
            <div className="card" style={{ border: '2px solid var(--primary-border)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
                <div>
                  <h3 style={{ fontSize: '16px', fontWeight: '800', color: 'var(--text-dark)' }}>
                    {selectedFamily.name} Members
                  </h3>
                  <p style={{ fontSize: '12px', color: 'var(--text-light)' }}>
                    Code: {selectedFamily.family_id}
                  </p>
                </div>
                <button 
                  onClick={() => setSelectedFamily(null)} 
                  style={{ background: 'transparent', color: 'var(--text-light)', fontSize: '18px', fontWeight: 'bold' }}
                >
                  ✕
                </button>
              </div>

              {loadingMembers ? (
                <div style={{ textAlign: 'center', padding: '30px', color: 'var(--text-light)' }}>
                  Loading members...
                </div>
              ) : members.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '30px', color: 'var(--text-light)' }}>
                  No members added to this family yet.
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  {members.map((m) => (
                    <div 
                      key={m.id} 
                      style={{
                        padding: '14px',
                        borderRadius: '14px',
                        backgroundColor: '#F8FCF7',
                        border: '1px solid var(--border)',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center'
                      }}
                    >
                      <div>
                        <div style={{ fontWeight: '700', fontSize: '14px', color: 'var(--text-dark)' }}>
                          {m.name}
                        </div>
                        <div style={{ fontSize: '12px', color: 'var(--text-mid)', marginTop: '2px' }}>
                          Relation: <span style={{ fontWeight: '600' }}>{m.relation}</span> • Gender: {m.gender || 'N/A'}
                        </div>
                        {m.allergies && (
                          <div style={{ fontSize: '11px', color: 'var(--danger)', marginTop: '4px' }}>
                            Allergies: {m.allergies}
                          </div>
                        )}
                      </div>
                      <span className="badge badge-danger" style={{ fontWeight: '800' }}>
                        {m.blood_group || 'N/A'}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

        </div>
      </div>
    </>
  );
}
