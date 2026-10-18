'use client';

import { useState, useEffect } from 'react';
import Header from '../../components/Header';
import { supabase } from '../../lib/supabase';
import { 
  HardDriveDownload, 
  Cloud, 
  Database, 
  Download, 
  CheckCircle2, 
  FileJson, 
  FileSpreadsheet, 
  ShieldCheck, 
  RefreshCw,
  Clock,
  Sparkles,
  Server
} from 'lucide-react';

export default function BackupHubPage() {
  const [counts, setCounts] = useState({
    profiles: 0,
    families: 0,
    members: 0,
    doctors: 0,
    visits: 0,
    records: 0,
  });
  const [loading, setLoading] = useState(true);
  const [exporting, setExporting] = useState(false);
  const [lastExportTime, setLastExportTime] = useState(null);

  async function loadTableCounts() {
    setLoading(true);
    try {
      const [pRes, fRes, mRes, dRes, vRes, rRes] = await Promise.all([
        supabase.from('profiles').select('id', { count: 'exact', head: true }),
        supabase.from('families').select('id', { count: 'exact', head: true }),
        supabase.from('members').select('id', { count: 'exact', head: true }),
        supabase.from('doctors').select('id', { count: 'exact', head: true }),
        supabase.from('visits').select('id', { count: 'exact', head: true }),
        supabase.from('med_files').select('id', { count: 'exact', head: true }),
      ]);

      setCounts({
        profiles: pRes.count ?? 0,
        families: fRes.count ?? 0,
        members: mRes.count ?? 0,
        doctors: dRes.count ?? 0,
        visits: vRes.count ?? 0,
        records: rRes.count ?? 0,
      });
    } catch (err) {
      console.error('Error fetching table counts:', err);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadTableCounts();
  }, []);

  async function downloadFullJsonBackup() {
    setExporting(true);
    try {
      const [profiles, families, members, doctors, visits, medFiles, appointments] = await Promise.all([
        supabase.from('profiles').select('*'),
        supabase.from('families').select('*'),
        supabase.from('members').select('*'),
        supabase.from('doctors').select('*'),
        supabase.from('visits').select('*'),
        supabase.from('med_files').select('*'),
        supabase.from('appointments').select('*'),
      ]);

      const backupPackage = {
        app: 'Medical History System',
        type: 'Admin Full Database Snapshot',
        version: '1.0.0',
        exported_at: new Date().toISOString(),
        environment: 'Supabase PostgreSQL',
        data: {
          profiles: profiles.data || [],
          families: families.data || [],
          members: members.data || [],
          doctors: doctors.data || [],
          visits: visits.data || [],
          med_files: medFiles.data || [],
          appointments: appointments.data || [],
        },
      };

      const jsonStr = JSON.stringify(backupPackage, null, 2);
      const blob = new Blob([jsonStr], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `medical_history_full_backup_${new Date().toISOString().slice(0, 10)}.json`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);

      setLastExportTime(new Date());
    } catch (err) {
      alert('Failed to export JSON backup: ' + err.message);
    } finally {
      setExporting(false);
    }
  }

  async function downloadTableCsv(tableName, columns) {
    try {
      const { data, error } = await supabase.from(tableName).select('*');
      if (error || !data) throw error || new Error('No data');

      const headers = columns.join(',');
      const rows = data.map((row) =>
        columns.map((c) => `"${(row[c] !== null && row[c] !== undefined ? String(row[c]) : '').replace(/"/g, '""')}"`).join(',')
      );

      const csvContent = 'data:text/csv;charset=utf-8,' + [headers, ...rows].join('\n');
      const encodedUri = encodeURI(csvContent);
      const link = document.createElement('a');
      link.setAttribute('href', encodedUri);
      link.setAttribute('download', `${tableName}_export_${new Date().toISOString().slice(0, 10)}.csv`);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } catch (err) {
      alert(`Failed to export ${tableName}: ` + err.message);
    }
  }

  return (
    <>
      <Header title="Cloud Backup & Export Center" subtitle="Comprehensive database snapshots, JSON dumps and CSV exports" />

      <div className="admin-content">
        {/* Hero Card matching Mobile App's Signature Style */}
        <div className="app-hero-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '16px' }}>
            <div style={{ maxWidth: '600px' }}>
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
                marginBottom: '14px'
              }}>
                <ShieldCheck size={14} /> Master Data Vault
              </div>
              <h2 style={{ fontSize: '24px', fontWeight: '900', lineHeight: 1.25 }}>
                Cloud Backups & Data Portability
              </h2>
              <p style={{ fontSize: '13.5px', color: 'rgba(255, 255, 255, 0.88)', marginTop: '8px', lineHeight: 1.5 }}>
                Your PostgreSQL database is synchronized in real-time with Supabase cloud and backed up via WhatsApp-style Google Drive AppData on user devices. Generate full data archives anytime below.
              </p>
            </div>

            <button
              onClick={downloadFullJsonBackup}
              disabled={exporting}
              style={{
                backgroundColor: '#FFFFFF',
                color: 'var(--primary-dark)',
                padding: '14px 22px',
                borderRadius: '16px',
                fontWeight: '800',
                fontSize: '14px',
                display: 'flex',
                alignItems: 'center',
                gap: '10px',
                boxShadow: '0 8px 20px rgba(0, 0, 0, 0.15)',
                transition: 'transform 0.18s ease'
              }}
            >
              <FileJson size={18} color="var(--primary)" />
              <span>{exporting ? 'Generating JSON Package...' : 'Download Full JSON Archive'}</span>
            </button>
          </div>
        </div>

        {/* Database Tables Live Statistics */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '16px', marginBottom: '28px' }}>
          <div className="card" style={{ padding: '16px 20px' }}>
            <div style={{ fontSize: '11px', fontWeight: '800', color: 'var(--text-light)', textTransform: 'uppercase' }}>Profiles</div>
            <div style={{ fontSize: '24px', fontWeight: '900', color: 'var(--text-dark)', marginTop: '4px' }}>{counts.profiles}</div>
            <div style={{ fontSize: '11px', color: 'var(--primary)', fontWeight: '700' }}>Active Users</div>
          </div>
          <div className="card" style={{ padding: '16px 20px' }}>
            <div style={{ fontSize: '11px', fontWeight: '800', color: 'var(--text-light)', textTransform: 'uppercase' }}>Families</div>
            <div style={{ fontSize: '24px', fontWeight: '900', color: 'var(--text-dark)', marginTop: '4px' }}>{counts.families}</div>
            <div style={{ fontSize: '11px', color: 'var(--primary)', fontWeight: '700' }}>Health Trees</div>
          </div>
          <div className="card" style={{ padding: '16px 20px' }}>
            <div style={{ fontSize: '11px', fontWeight: '800', color: 'var(--text-light)', textTransform: 'uppercase' }}>Members</div>
            <div style={{ fontSize: '24px', fontWeight: '900', color: 'var(--text-dark)', marginTop: '4px' }}>{counts.members}</div>
            <div style={{ fontSize: '11px', color: '#0EA5E9', fontWeight: '700' }}>Patients</div>
          </div>
          <div className="card" style={{ padding: '16px 20px' }}>
            <div style={{ fontSize: '11px', fontWeight: '800', color: 'var(--text-light)', textTransform: 'uppercase' }}>Doctors</div>
            <div style={{ fontSize: '24px', fontWeight: '900', color: 'var(--text-dark)', marginTop: '4px' }}>{counts.doctors}</div>
            <div style={{ fontSize: '11px', color: '#8B5CF6', fontWeight: '700' }}>Providers</div>
          </div>
          <div className="card" style={{ padding: '16px 20px' }}>
            <div style={{ fontSize: '11px', fontWeight: '800', color: 'var(--text-light)', textTransform: 'uppercase' }}>Visits</div>
            <div style={{ fontSize: '24px', fontWeight: '900', color: 'var(--text-dark)', marginTop: '4px' }}>{counts.visits}</div>
            <div style={{ fontSize: '11px', color: '#F59E0B', fontWeight: '700' }}>Consultations</div>
          </div>
        </div>

        {/* 1-Click Table CSV Exports */}
        <div className="card" style={{ marginBottom: '28px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px' }}>
            <div>
              <h3 style={{ fontSize: '17px', fontWeight: '800', color: 'var(--text-dark)' }}>
                Granular Table CSV Exports
              </h3>
              <p style={{ fontSize: '12.5px', color: 'var(--text-light)', marginTop: '2px' }}>
                Export individual medical tables directly for spreadsheet analysis or reporting
              </p>
            </div>
            <button onClick={loadTableCounts} className="btn btn-secondary" style={{ padding: '6px 12px', fontSize: '12px' }}>
              <RefreshCw size={13} />
              <span>Refresh Counts</span>
            </button>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '16px' }}>
            {/* Export 1: Families */}
            <div style={{ padding: '16px', borderRadius: '16px', border: '1px solid var(--border)', backgroundColor: '#FAFDF9' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontWeight: '800', fontSize: '14px', color: 'var(--text-dark)' }}>Families Table</span>
                <span className="badge badge-primary">{counts.families} Rows</span>
              </div>
              <p style={{ fontSize: '12px', color: 'var(--text-mid)', margin: '8px 0 14px' }}>
                Family names, unique codes, phone contact, and addresses.
              </p>
              <button
                onClick={() => downloadTableCsv('families', ['id', 'family_id', 'name', 'contact', 'address', 'created_at'])}
                className="btn btn-secondary"
                style={{ width: '100%', justifyContent: 'center', fontSize: '12.5px' }}
              >
                <FileSpreadsheet size={14} color="var(--primary)" />
                <span>Export Families CSV</span>
              </button>
            </div>

            {/* Export 2: Members */}
            <div style={{ padding: '16px', borderRadius: '16px', border: '1px solid var(--border)', backgroundColor: '#FAFDF9' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontWeight: '800', fontSize: '14px', color: 'var(--text-dark)' }}>Members Table</span>
                <span className="badge badge-info">{counts.members} Rows</span>
              </div>
              <p style={{ fontSize: '12px', color: 'var(--text-mid)', margin: '8px 0 14px' }}>
                Names, relationships, dates of birth, blood groups, allergies.
              </p>
              <button
                onClick={() => downloadTableCsv('members', ['id', 'family_id', 'name', 'relation', 'gender', 'blood_group', 'allergies', 'created_at'])}
                className="btn btn-secondary"
                style={{ width: '100%', justifyContent: 'center', fontSize: '12.5px' }}
              >
                <FileSpreadsheet size={14} color="#0EA5E9" />
                <span>Export Members CSV</span>
              </button>
            </div>

            {/* Export 3: Doctors */}
            <div style={{ padding: '16px', borderRadius: '16px', border: '1px solid var(--border)', backgroundColor: '#FAFDF9' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontWeight: '800', fontSize: '14px', color: 'var(--text-dark)' }}>Doctors Table</span>
                <span className="badge badge-purple">{counts.doctors} Rows</span>
              </div>
              <p style={{ fontSize: '12px', color: 'var(--text-mid)', margin: '8px 0 14px' }}>
                Doctor directory, hospitals, contact phones, specializations.
              </p>
              <button
                onClick={() => downloadTableCsv('doctors', ['id', 'name', 'specialization', 'hospital', 'phone', 'address', 'created_at'])}
                className="btn btn-secondary"
                style={{ width: '100%', justifyContent: 'center', fontSize: '12.5px' }}
              >
                <FileSpreadsheet size={14} color="#8B5CF6" />
                <span>Export Doctors CSV</span>
              </button>
            </div>

            {/* Export 4: Visits */}
            <div style={{ padding: '16px', borderRadius: '16px', border: '1px solid var(--border)', backgroundColor: '#FAFDF9' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontWeight: '800', fontSize: '14px', color: 'var(--text-dark)' }}>Visits & Rx Table</span>
                <span className="badge badge-warning">{counts.visits} Rows</span>
              </div>
              <p style={{ fontSize: '12px', color: 'var(--text-mid)', margin: '8px 0 14px' }}>
                Symptoms, medical diagnosis, treatments, follow-up dates.
              </p>
              <button
                onClick={() => downloadTableCsv('visits', ['id', 'member_id', 'doctor_id', 'visit_date', 'symptoms', 'diagnosis', 'treatment', 'created_at'])}
                className="btn btn-secondary"
                style={{ width: '100%', justifyContent: 'center', fontSize: '12.5px' }}
              >
                <FileSpreadsheet size={14} color="#F59E0B" />
                <span>Export Visits CSV</span>
              </button>
            </div>
          </div>
        </div>

        {/* WhatsApp Google Drive Backup Integration Info */}
        <div className="card">
          <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '14px' }}>
            <div style={{
              width: '46px',
              height: '46px',
              borderRadius: '14px',
              backgroundColor: '#EFF8EC',
              color: 'var(--primary)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <Cloud size={24} />
            </div>
            <div>
              <h3 style={{ fontSize: '16.5px', fontWeight: '800', color: 'var(--text-dark)' }}>
                Client-Side Google Drive AppData Synchronization
              </h3>
              <p style={{ fontSize: '12px', color: 'var(--text-light)' }}>
                Zero-Knowledge Encrypted Backup Protocol
              </p>
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '16px', fontSize: '13px', color: 'var(--text-mid)' }}>
            <div style={{ padding: '14px', backgroundColor: '#F8FAF7', borderRadius: '12px', border: '1px solid var(--border)' }}>
              <div style={{ fontWeight: '700', color: 'var(--text-dark)', marginBottom: '4px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                <CheckCircle2 size={15} color="var(--primary)" /> Hidden Folder Storage
              </div>
              Backups are stored inside Google Drive's protected <code>appDataFolder</code> container, isolated from personal files.
            </div>

            <div style={{ padding: '14px', backgroundColor: '#F8FAF7', borderRadius: '12px', border: '1px solid var(--border)' }}>
              <div style={{ fontWeight: '700', color: 'var(--text-dark)', marginBottom: '4px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                <CheckCircle2 size={15} color="var(--primary)" /> Seamless One-Tap Restore
              </div>
              When a patient logs in on a new phone, the app detects their Google Drive backup and recovers the complete health tree instantly.
            </div>
          </div>
        </div>

      </div>
    </>
  );
}
