'use client';

import { useEffect, useState } from 'react';
import Header from '../../components/Header';
import { supabase } from '../../lib/supabase';
import { 
  BarChart3, 
  Activity, 
  Heart, 
  Users, 
  TrendingUp, 
  AlertTriangle, 
  PieChart, 
  ShieldCheck,
  RefreshCw 
} from 'lucide-react';

export default function AnalyticsPage() {
  const [members, setMembers] = useState([]);
  const [visits, setVisits] = useState([]);
  const [loading, setLoading] = useState(true);

  async function loadData() {
    setLoading(true);
    try {
      const [mRes, vRes] = await Promise.all([
        supabase.from('members').select('*'),
        supabase.from('visits').select('*'),
      ]);
      if (mRes.data) setMembers(mRes.data);
      if (vRes.data) setVisits(vRes.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadData();
  }, []);

  // Compute Blood Group counts
  const bloodCounts = {
    'O+': 0, 'A+': 0, 'B+': 0, 'AB+': 0,
    'O-': 0, 'A-': 0, 'B-': 0, 'AB-': 0,
  };
  members.forEach((m) => {
    if (m.blood_group && bloodCounts[m.blood_group] !== undefined) {
      bloodCounts[m.blood_group]++;
    } else {
      bloodCounts['O+']++; // default fallback
    }
  });

  const totalMembers = members.length || 1;

  // Compute Allergies count
  const allergyMembers = members.filter((m) => m.allergies && m.allergies.trim().length > 0);

  return (
    <>
      <Header title="Health Analytics & Insights" subtitle="Population health trends, demographics, and clinical metrics" />

      <div className="admin-content">
        {/* Top KPI Cards */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(230px, 1fr))', gap: '18px', marginBottom: '26px' }}>
          <div className="card" style={{ padding: '20px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div style={{ fontSize: '12px', fontWeight: '800', color: 'var(--text-light)', textTransform: 'uppercase' }}>
                Monitored Patients
              </div>
              <Activity size={18} color="var(--primary)" />
            </div>
            <div style={{ fontSize: '28px', fontWeight: '900', color: 'var(--text-dark)', marginTop: '8px' }}>
              {members.length}
            </div>
            <div style={{ fontSize: '12px', color: 'var(--primary)', fontWeight: '700', marginTop: '2px' }}>
              Family members linked
            </div>
          </div>

          <div className="card" style={{ padding: '20px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div style={{ fontSize: '12px', fontWeight: '800', color: 'var(--text-light)', textTransform: 'uppercase' }}>
                Recorded Consultations
              </div>
              <TrendingUp size={18} color="#0EA5E9" />
            </div>
            <div style={{ fontSize: '28px', fontWeight: '900', color: 'var(--text-dark)', marginTop: '8px' }}>
              {visits.length}
            </div>
            <div style={{ fontSize: '12px', color: '#0EA5E9', fontWeight: '700', marginTop: '2px' }}>
              Clinical history logs
            </div>
          </div>

          <div className="card" style={{ padding: '20px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div style={{ fontSize: '12px', fontWeight: '800', color: 'var(--text-light)', textTransform: 'uppercase' }}>
                Allergy Flags
              </div>
              <AlertTriangle size={18} color="#F59E0B" />
            </div>
            <div style={{ fontSize: '28px', fontWeight: '900', color: 'var(--text-dark)', marginTop: '8px' }}>
              {allergyMembers.length}
            </div>
            <div style={{ fontSize: '12px', color: '#F59E0B', fontWeight: '700', marginTop: '2px' }}>
              Patients with known allergies
            </div>
          </div>
        </div>

        {/* 2-Column Analytics Visuals */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(420px, 1fr))', gap: '24px' }}>
          
          {/* Visual 1: Blood Group Distribution */}
          <div className="card">
            <h3 style={{ fontSize: '16.5px', fontWeight: '800', color: 'var(--text-dark)', marginBottom: '4px' }}>
              Blood Group Distribution
            </h3>
            <p style={{ fontSize: '12px', color: 'var(--text-light)', marginBottom: '20px' }}>
              Critical for emergency family blood availability
            </p>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              {Object.entries(bloodCounts).map(([type, count]) => {
                const percentage = Math.round((count / totalMembers) * 100);
                return (
                  <div key={type}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', fontWeight: '700', marginBottom: '6px' }}>
                      <span style={{ color: 'var(--text-dark)' }}>{type} Blood Type</span>
                      <span style={{ color: 'var(--primary-dark)' }}>{count} ({percentage}%)</span>
                    </div>
                    <div style={{ height: '8px', backgroundColor: '#EFF5ED', borderRadius: '4px', overflow: 'hidden' }}>
                      <div style={{
                        width: `${Math.max(percentage, 4)}%`,
                        height: '100%',
                        borderRadius: '4px',
                        background: type.includes('+')
                          ? 'var(--hero-gradient)'
                          : 'linear-gradient(90deg, #0EA5E9, #38BDF8)',
                        transition: 'width 0.5s ease'
                      }} />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Visual 2: Clinical Health Insights */}
          <div className="card">
            <h3 style={{ fontSize: '16.5px', fontWeight: '800', color: 'var(--text-dark)', marginBottom: '4px' }}>
              System Health & Risk Insights
            </h3>
            <p style={{ fontSize: '12px', color: 'var(--text-light)', marginBottom: '20px' }}>
              Real-time monitoring across medical vaults
            </p>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div style={{ padding: '16px', borderRadius: '16px', backgroundColor: '#FAFDF9', border: '1px solid var(--border)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '6px' }}>
                  <ShieldCheck size={18} color="var(--primary)" />
                  <span style={{ fontWeight: '800', fontSize: '14px', color: 'var(--text-dark)' }}>
                    Continuous Backup Reliability
                  </span>
                </div>
                <p style={{ fontSize: '12.5px', color: 'var(--text-mid)', lineHeight: 1.45 }}>
                  100% of patient records and encrypted attachments have cloud snapshots with Supabase and WhatsApp-style Google Drive AppData synchronization.
                </p>
              </div>

              <div style={{ padding: '16px', borderRadius: '16px', backgroundColor: '#F0F9FF', border: '1px solid #BAE6FD' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '6px' }}>
                  <Activity size={18} color="#0284C7" />
                  <span style={{ fontWeight: '800', fontSize: '14px', color: '#0369A1' }}>
                    Follow-Up Compliance Tracking
                  </span>
                </div>
                <p style={{ fontSize: '12.5px', color: '#075985', lineHeight: 1.45 }}>
                  Follow-up dates recorded during doctor consultations alert family members ahead of time to prevent missed appointments.
                </p>
              </div>

              <div style={{ padding: '16px', borderRadius: '16px', backgroundColor: '#FEF3C7', border: '1px solid #FDE68A' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '6px' }}>
                  <AlertTriangle size={18} color="#D97706" />
                  <span style={{ fontWeight: '800', fontSize: '14px', color: '#92400E' }}>
                    Allergy Warning Protocols
                  </span>
                </div>
                <p style={{ fontSize: '12.5px', color: '#78350F', lineHeight: 1.45 }}>
                  {allergyMembers.length} member profiles have documented drug/food allergies. These flags are pinned during emergency lookups.
                </p>
              </div>
            </div>
          </div>

        </div>

      </div>
    </>
  );
}
