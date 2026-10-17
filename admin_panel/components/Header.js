'use client';

import { Search, Bell, ShieldCheck, Database } from 'lucide-react';

export default function Header({ title = 'Dashboard Overview', subtitle = 'Family Health Management Console' }) {
  return (
    <header className="admin-header">
      <div>
        <h2 style={{ fontSize: '18px', fontWeight: '800', color: 'var(--text-dark)', lineHeight: 1.2 }}>
          {title}
        </h2>
        <p style={{ fontSize: '12px', color: 'var(--text-mid)', marginTop: '2px' }}>
          {subtitle}
        </p>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: '18px' }}>
        {/* Supabase status badge */}
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '6px 14px',
          borderRadius: '20px',
          backgroundColor: '#EFF8EC',
          border: '1px solid #D3ECD0'
        }}>
          <span style={{
            width: '8px',
            height: '8px',
            borderRadius: '50%',
            backgroundColor: '#3FA722',
            display: 'inline-block',
            boxShadow: '0 0 0 2px rgba(63, 167, 34, 0.25)'
          }} />
          <Database size={14} color="#3FA722" />
          <span style={{ fontSize: '12px', fontWeight: '700', color: '#246D16' }}>
            Supabase PostgreSQL Active
          </span>
        </div>

        {/* Global Search Bar */}
        <div className="search-input">
          <Search size={16} color="var(--text-light)" />
          <input type="text" placeholder="Search members, doctors, visits..." />
        </div>

        {/* Admin security badge */}
        <div style={{
          width: '38px',
          height: '38px',
          borderRadius: '12px',
          backgroundColor: '#F3F7F2',
          border: '1px solid var(--border)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: 'var(--text-mid)',
          cursor: 'pointer'
        }} title="System Security Active">
          <ShieldCheck size={18} color="#3FA722" />
        </div>
      </div>
    </header>
  );
}
