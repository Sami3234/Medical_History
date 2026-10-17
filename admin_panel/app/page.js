'use client';

import { useEffect, useState } from 'react';
import Header from '../components/Header';
import { supabase } from '../lib/supabase';
import Link from 'next/link';
import { 
  Users, 
  UserCheck, 
  Stethoscope, 
  CalendarDays, 
  ArrowUpRight, 
  Plus, 
  ExternalLink,
  Activity,
  HeartPulse,
  RefreshCw,
  HardDriveDownload,
  FolderArchive,
  Clock,
  ShieldCheck,
  Heart
} from 'lucide-react';

export default function DashboardPage() {
  const [stats, setStats] = useState({
    families: 0,
    members: 0,
    doctors: 0,
    visits: 0,
  });
  const [recentFamilies, setRecentFamilies] = useState([]);
  const [recentVisits, setRecentVisits] = useState([]);
  const [loading, setLoading] = useState(true);

  async function loadDashboardData() {
    setLoading(true);
    try {
      const [fCount, mCount, dCount, vCount] = await Promise.all([
        supabase.from('families').select('id', { count: 'exact', head: true }),
        supabase.from('members').select('id', { count: 'exact', head: true }),
        supabase.from('doctors').select('id', { count: 'exact', head: true }),
        supabase.from('visits').select('id', { count: 'exact', head: true }),
      ]);

      setStats({
        families: fCount.count || 0,
        members: mCount.count || 0,
        doctors: dCount.count || 0,
        visits: vCount.count || 0,
      });

      const { data: familiesData } = await supabase
        .from('families')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(5);

      if (familiesData) setRecentFamilies(familiesData);

      const { data: visitsData } = await supabase
        .from('visits')
        .select('*, members(name, relation), doctors(name, specialization)')
        .order('visit_date', { ascending: false })
        .limit(5);

      if (visitsData) setRecentVisits(visitsData);
    } catch (err) {
      console.error('Failed to load dashboard data:', err);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadDashboardData();
  }, []);

  return (
    <>
      <Header 
        title="Dashboard Overview" 
        subtitle="Real-time Family Health Monitoring & Analytics" 
      />

      <div className="admin-content">
        {/* Mobile App Style Hero Banner */}
        <div className="app-hero-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '16px' }}>
            <div style={{ maxWidth: '620px' }}>
              <div style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '6px',
                padding: '4px 12px',
                borderRadius: '20px',
                backgroundColor: 'rgba(255, 255, 255, 0.22)',
                fontSize: '11px',
                fontWeight: '800',
                letterSpacing: '0.8px',
                textTransform: 'uppercase',
                marginBottom: '12px'
              }}>
                <Heart size={14} fill="#FFFFFF" /> Medical History Central
              </div>
              <h1 style={{ fontSize: '26px', fontWeight: '900', lineHeight: 1.25 }}>
                Family Healthcare Control Center
              </h1>
              <p style={{ fontSize: '13.5px', color: 'rgba(255, 255, 255, 0.9)', marginTop: '8px', lineHeight: 1.5 }}>
                Manage patient family trees, registered specialists, consultation timelines, and WhatsApp-style Google Drive backups with real-time Supabase cloud synchronization.
              </p>
            </div>

            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
              <Link
                href="/backup"
                style={{
                  backgroundColor: '#FFFFFF',
                  color: 'var(--primary-dark)',
                  padding: '12px 18px',
                  borderRadius: '14px',
                  fontWeight: '800',
                  fontSize: '13.5px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  boxShadow: '0 6px 16px rgba(0,0,0,0.12)'
                }}
              >
                <HardDriveDownload size={16} color="var(--primary)" />
                <span>Backup Hub</span>
              </Link>
              <button
                onClick={loadDashboardData}
                style={{
                  backgroundColor: 'rgba(255, 255, 255, 0.2)',
                  color: '#FFFFFF',
                  padding: '12px 16px',
                  borderRadius: '14px',
                  fontWeight: '700',
                  fontSize: '13.5px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  border: '1px solid rgba(255, 255, 255, 0.3)'
                }}
              >
                <RefreshCw size={15} className={loading ? 'animate-spin' : ''} />
                <span>{loading ? 'Syncing...' : 'Sync Data'}</span>
              </button>
            </div>
          </div>
        </div>

        {/* 4 Metric Cards */}
        <div className="stat-grid">
          {/* Card 1: Families */}
          <Link href="/families" className="stat-card">
            <div>
              <div className="stat-title">Family Groups</div>
              <div className="stat-value">{stats.families}</div>
              <div style={{ fontSize: '12px', color: 'var(--primary)', fontWeight: '700', marginTop: '4px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                <ArrowUpRight size={14} /> Active family trees
              </div>
            </div>
            <div className="stat-icon" style={{ backgroundColor: '#EBF7E6', color: '#3FA722' }}>
              <Users size={26} />
            </div>
          </Link>

          {/* Card 2: Members */}
          <Link href="/users" className="stat-card">
            <div>
              <div className="stat-title">Patient Profiles</div>
              <div className="stat-value">{stats.members}</div>
              <div style={{ fontSize: '12px', color: '#0EA5E9', fontWeight: '700', marginTop: '4px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                <Activity size={14} /> Tracked members
              </div>
            </div>
            <div className="stat-icon" style={{ backgroundColor: '#E0F2FE', color: '#0EA5E9' }}>
              <UserCheck size={26} />
            </div>
          </Link>

          {/* Card 3: Doctors */}
          <Link href="/doctors" className="stat-card">
            <div>
              <div className="stat-title">Doctors & Specialists</div>
              <div className="stat-value">{stats.doctors}</div>
              <div style={{ fontSize: '12px', color: '#8B5CF6', fontWeight: '700', marginTop: '4px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                <HeartPulse size={14} /> Medical providers
              </div>
            </div>
            <div className="stat-icon" style={{ backgroundColor: '#F3E8FF', color: '#8B5CF6' }}>
              <Stethoscope size={26} />
            </div>
          </Link>

          {/* Card 4: Consultations */}
          <Link href="/visits" className="stat-card">
            <div>
              <div className="stat-title">Doctor Visits</div>
              <div className="stat-value">{stats.visits}</div>
              <div style={{ fontSize: '12px', color: '#F59E0B', fontWeight: '700', marginTop: '4px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                <CalendarDays size={14} /> Clinical consultations
              </div>
            </div>
            <div className="stat-icon" style={{ backgroundColor: '#FEF3C7', color: '#F59E0B' }}>
              <CalendarDays size={26} />
            </div>
          </Link>
        </div>

        {/* Quick Hub Navigation Cards */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '14px', marginBottom: '26px' }}>
          <Link href="/users" className="card" style={{ padding: '16px', display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{ width: '40px', height: '40px', borderRadius: '12px', backgroundColor: '#EBF7E6', color: 'var(--primary)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <UserCheck size={20} />
            </div>
            <div>
              <div style={{ fontWeight: '800', fontSize: '13.5px', color: 'var(--text-dark)' }}>User Accounts</div>
              <div style={{ fontSize: '11px', color: 'var(--text-light)' }}>Manage patient profiles</div>
            </div>
          </Link>

          <Link href="/documents" className="card" style={{ padding: '16px', display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{ width: '40px', height: '40px', borderRadius: '12px', backgroundColor: '#E0F2FE', color: '#0EA5E9', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <FolderArchive size={20} />
            </div>
            <div>
              <div style={{ fontWeight: '800', fontSize: '13.5px', color: 'var(--text-dark)' }}>Document Vault</div>
              <div style={{ fontSize: '11px', color: 'var(--text-light)' }}>Lab tests & prescriptions</div>
            </div>
          </Link>

          <Link href="/appointments" className="card" style={{ padding: '16px', display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{ width: '40px', height: '40px', borderRadius: '12px', backgroundColor: '#FEF3C7', color: '#B45309', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Clock size={20} />
            </div>
            <div>
              <div style={{ fontWeight: '800', fontSize: '13.5px', color: 'var(--text-dark)' }}>Appointments</div>
              <div style={{ fontSize: '11px', color: 'var(--text-light)' }}>Schedule & timings</div>
            </div>
          </Link>

          <Link href="/backup" className="card" style={{ padding: '16px', display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{ width: '40px', height: '40px', borderRadius: '12px', backgroundColor: '#F3E8FF', color: '#7E22CE', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <HardDriveDownload size={20} />
            </div>
            <div>
              <div style={{ fontWeight: '800', fontSize: '13.5px', color: 'var(--text-dark)' }}>Data Snapshots</div>
              <div style={{ fontSize: '11px', color: 'var(--text-light)' }}>JSON & CSV export</div>
            </div>
          </Link>
        </div>

        {/* Two-Column Grid: Recent Families & Recent Consultations */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(450px, 1fr))', gap: '24px' }}>
          
          {/* Section: Recent Families */}
          <div className="card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px' }}>
              <div>
                <h3 style={{ fontSize: '16px', fontWeight: '800', color: 'var(--text-dark)' }}>
                  Recent Families
                </h3>
                <p style={{ fontSize: '12px', color: 'var(--text-light)', marginTop: '2px' }}>
                  Newly created family health groups
                </p>
              </div>
              <Link href="/families" style={{ fontSize: '13px', fontWeight: '700', color: 'var(--primary)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                View All <ExternalLink size={13} />
              </Link>
            </div>

            <div className="table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Family Name</th>
                    <th>Code / ID</th>
                    <th>Contact</th>
                    <th>Created</th>
                  </tr>
                </thead>
                <tbody>
                  {recentFamilies.length === 0 ? (
                    <tr>
                      <td colSpan="4" style={{ textAlign: 'center', padding: '32px', color: 'var(--text-light)' }}>
                        {loading ? 'Fetching live families...' : 'No families registered yet.'}
                      </td>
                    </tr>
                  ) : (
                    recentFamilies.map((fam) => (
                      <tr key={fam.id}>
                        <td style={{ fontWeight: '700', color: 'var(--text-dark)' }}>
                          {fam.name}
                        </td>
                        <td>
                          <span className="badge badge-primary">{fam.family_id || 'FAM'}</span>
                        </td>
                        <td style={{ color: 'var(--text-mid)', fontSize: '13px' }}>
                          {fam.contact || '—'}
                        </td>
                        <td style={{ color: 'var(--text-light)', fontSize: '12.5px' }}>
                          {new Date(fam.created_at).toLocaleDateString()}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Section: Recent Doctor Visits */}
          <div className="card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px' }}>
              <div>
                <h3 style={{ fontSize: '16px', fontWeight: '800', color: 'var(--text-dark)' }}>
                  Latest Consultations
                </h3>
                <p style={{ fontSize: '12px', color: 'var(--text-light)', marginTop: '2px' }}>
                  Recent medical visits & diagnosis logs
                </p>
              </div>
              <Link href="/visits" style={{ fontSize: '13px', fontWeight: '700', color: 'var(--primary)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                View All <ExternalLink size={13} />
              </Link>
            </div>

            <div className="table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Patient</th>
                    <th>Doctor</th>
                    <th>Diagnosis</th>
                    <th>Date</th>
                  </tr>
                </thead>
                <tbody>
                  {recentVisits.length === 0 ? (
                    <tr>
                      <td colSpan="4" style={{ textAlign: 'center', padding: '32px', color: 'var(--text-light)' }}>
                        {loading ? 'Fetching consultations...' : 'No visits recorded yet.'}
                      </td>
                    </tr>
                  ) : (
                    recentVisits.map((v) => (
                      <tr key={v.id}>
                        <td>
                          <div style={{ fontWeight: '700', color: 'var(--text-dark)' }}>
                            {v.members?.name || 'Member'}
                          </div>
                          <div style={{ fontSize: '11px', color: 'var(--text-light)' }}>
                            {v.members?.relation || 'Family'}
                          </div>
                        </td>
                        <td style={{ color: 'var(--text-mid)', fontSize: '13px' }}>
                          {v.doctors?.name || 'General Doctor'}
                        </td>
                        <td>
                          <span className="badge badge-info">
                            {v.diagnosis || 'Routine Checkup'}
                          </span>
                        </td>
                        <td style={{ color: 'var(--text-light)', fontSize: '12.5px' }}>
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

      </div>
    </>
  );
}
