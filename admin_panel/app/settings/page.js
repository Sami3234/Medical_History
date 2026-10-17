'use client';

import { useState } from 'react';
import Header from '../../components/Header';
import { Database, ShieldCheck, Cloud, Server, CheckCircle2, Lock } from 'lucide-react';

export default function SettingsPage() {
  const [copied, setCopied] = useState(false);

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://fqcnpqrdxwttcxrcdnyg.supabase.co';

  return (
    <>
      <Header title="System & Cloud Settings" subtitle="Backend connectivity, database status and security" />

      <div className="admin-content">
        <div style={{ maxWidth: '800px', display: 'flex', flexDirection: 'column', gap: '24px' }}>
          
          {/* Card 1: Supabase PostgreSQL */}
          <div className="card">
            <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '16px' }}>
              <div style={{
                width: '44px',
                height: '44px',
                borderRadius: '12px',
                backgroundColor: '#EFF8EC',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'var(--primary)'
              }}>
                <Database size={22} />
              </div>
              <div>
                <h3 style={{ fontSize: '16px', fontWeight: '800', color: 'var(--text-dark)' }}>
                  Supabase PostgreSQL Cloud
                </h3>
                <span className="badge badge-primary" style={{ marginTop: '2px' }}>
                  Connected & Synchronized
                </span>
              </div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', fontSize: '13.5px' }}>
              <div>
                <label style={{ fontSize: '12px', fontWeight: '700', color: 'var(--text-light)', display: 'block', marginBottom: '4px' }}>
                  Project Endpoint URL
                </label>
                <input
                  type="text"
                  readOnly
                  value={supabaseUrl}
                  style={{
                    width: '100%',
                    padding: '10px 14px',
                    borderRadius: '10px',
                    border: '1px solid var(--border)',
                    backgroundColor: '#F7FAF6',
                    fontFamily: 'monospace',
                    fontSize: '13px',
                    color: 'var(--text-dark)'
                  }}
                />
              </div>

              <div>
                <label style={{ fontSize: '12px', fontWeight: '700', color: 'var(--text-light)', display: 'block', marginBottom: '4px' }}>
                  Managed Tables
                </label>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
                  {['profiles', 'families', 'members', 'doctors', 'visits', 'medications', 'medical_records'].map((t) => (
                    <span key={t} style={{
                      padding: '4px 10px',
                      borderRadius: '8px',
                      backgroundColor: '#F3F7F2',
                      fontSize: '12px',
                      fontWeight: '600',
                      color: 'var(--text-dark)'
                    }}>
                      public.{t}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          </div>

          {/* Card 2: Google Drive Backup Status */}
          <div className="card">
            <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '14px' }}>
              <div style={{
                width: '44px',
                height: '44px',
                borderRadius: '12px',
                backgroundColor: '#E0F2FE',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#0EA5E9'
              }}>
                <Cloud size={22} />
              </div>
              <div>
                <h3 style={{ fontSize: '16px', fontWeight: '800', color: 'var(--text-dark)' }}>
                  Google Drive AppData Backup
                </h3>
                <p style={{ fontSize: '12px', color: 'var(--text-light)' }}>
                  WhatsApp-style private cloud backup engine
                </p>
              </div>
            </div>

            <p style={{ fontSize: '13.5px', color: 'var(--text-mid)', lineHeight: 1.5 }}>
              Mobile clients back up their encrypted family records directly into their authenticated Google Drive hidden AppData folder (Scope: <code>drive.appdata</code>).
            </p>
          </div>

          {/* Card 3: Security & Encryption */}
          <div className="card">
            <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '14px' }}>
              <div style={{
                width: '44px',
                height: '44px',
                borderRadius: '12px',
                backgroundColor: '#FEF3C7',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#B45309'
              }}>
                <Lock size={22} />
              </div>
              <div>
                <h3 style={{ fontSize: '16px', fontWeight: '800', color: 'var(--text-dark)' }}>
                  Access Control & Row-Level Security
                </h3>
                <p style={{ fontSize: '12px', color: 'var(--text-light)' }}>
                  PostgreSQL RLS Policies & Encrypted Transit
                </p>
              </div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '13px', color: 'var(--text-mid)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <CheckCircle2 size={16} color="var(--primary)" />
                <span>SSL/TLS 1.3 encrypted data transit between client, web admin & Supabase</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <CheckCircle2 size={16} color="var(--primary)" />
                <span>Biometric authentication verified on mobile end</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <CheckCircle2 size={16} color="var(--primary)" />
                <span>PostgreSQL database backup and automated point-in-time recovery</span>
              </div>
            </div>
          </div>

        </div>
      </div>
    </>
  );
}
