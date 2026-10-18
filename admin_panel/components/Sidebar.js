'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useRouter } from 'next/navigation';
import { supabase } from '../lib/supabase';
import { 
  LayoutDashboard, 
  Users, 
  UserCheck, 
  Stethoscope, 
  CalendarDays, 
  FolderArchive,
  Clock,
  BarChart3,
  HardDriveDownload,
  Settings, 
  Heart,
  LogOut,
  Shield
} from 'lucide-react';

const mainNav = [
  { name: 'Dashboard', href: '/', icon: LayoutDashboard },
  { name: 'User Management', href: '/users', icon: UserCheck, badge: 'Active' },
  { name: 'Families & Trees', href: '/families', icon: Users },
  { name: 'Doctors Directory', href: '/doctors', icon: Stethoscope },
  { name: 'Visits & Diagnosis', href: '/visits', icon: CalendarDays },
];

const healthNav = [
  { name: 'Document Vault', href: '/documents', icon: FolderArchive },
  { name: 'Appointments', href: '/appointments', icon: Clock },
  { name: 'Health Analytics', href: '/analytics', icon: BarChart3 },
];

const systemNav = [
  { name: 'Backup & Cloud Hub', href: '/backup', icon: HardDriveDownload, highlight: true },
  { name: 'System Settings', href: '/settings', icon: Settings },
];

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();

  async function signOut() {
    await supabase.auth.signOut();
    router.replace('/login');
    router.refresh();
  }

  function renderNavItem(item) {
    const isActive = pathname === item.href;
    const Icon = item.icon;
    return (
      <Link
        key={item.name}
        href={item.href}
        prefetch={false}
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '10px 14px',
          borderRadius: '12px',
          fontSize: '13px',
          fontWeight: isActive ? '700' : '500',
          color: isActive ? '#FFFFFF' : 'rgba(255, 255, 255, 0.72)',
          backgroundColor: isActive ? 'var(--primary)' : 'transparent',
          transition: 'all 0.15s ease',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '11px' }}>
          <Icon size={18} color={isActive ? '#FFFFFF' : 'rgba(255, 255, 255, 0.7)'} />
          <span>{item.name}</span>
        </div>
        {item.badge && (
          <span style={{
            fontSize: '10px',
            fontWeight: '800',
            padding: '2px 7px',
            borderRadius: '8px',
            backgroundColor: isActive ? 'rgba(255,255,255,0.25)' : 'rgba(63, 167, 34, 0.25)',
            color: isActive ? '#FFFFFF' : '#88D84C',
          }}>
            {item.badge}
          </span>
        )}
        {item.highlight && (
          <span style={{
            width: '6px',
            height: '6px',
            borderRadius: '50%',
            backgroundColor: '#88D84C',
          }} />
        )}
      </Link>
    );
  }

  return (
    <aside className="admin-sidebar">
      {/* Brand Logo Header matching App style */}
      <div style={{ padding: '22px 20px', borderBottom: '1px solid rgba(255, 255, 255, 0.08)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{
            width: '42px',
            height: '42px',
            borderRadius: '13px',
            background: 'var(--hero-gradient)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: '0 4px 14px rgba(63, 167, 34, 0.4)'
          }}>
            <Heart size={22} color="#FFFFFF" fill="#FFFFFF" />
          </div>
          <div>
            <h1 style={{ fontSize: '16px', fontWeight: '900', letterSpacing: '0.4px', color: '#FFFFFF', lineHeight: 1.15 }}>
              Medical History
            </h1>
            <span style={{ fontSize: '10.5px', color: '#88D84C', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.8px' }}>
              Web Console Pro
            </span>
          </div>
        </div>
      </div>

      {/* Navigation Sections */}
      <nav style={{ padding: '16px 14px', flex: 1, display: 'flex', flexDirection: 'column', gap: '18px', overflowY: 'auto' }}>
        {/* Main Section */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
          <div style={{ fontSize: '10.5px', fontWeight: '800', color: 'rgba(255, 255, 255, 0.35)', textTransform: 'uppercase', letterSpacing: '0.9px', padding: '0 12px 4px' }}>
            Core Management
          </div>
          {mainNav.map(renderNavItem)}
        </div>

        {/* Health Data Section */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
          <div style={{ fontSize: '10.5px', fontWeight: '800', color: 'rgba(255, 255, 255, 0.35)', textTransform: 'uppercase', letterSpacing: '0.9px', padding: '0 12px 4px' }}>
            Clinical & Records
          </div>
          {healthNav.map(renderNavItem)}
        </div>

        {/* System & Cloud Section */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
          <div style={{ fontSize: '10.5px', fontWeight: '800', color: 'rgba(255, 255, 255, 0.35)', textTransform: 'uppercase', letterSpacing: '0.9px', padding: '0 12px 4px' }}>
            Cloud & Storage
          </div>
          {systemNav.map(renderNavItem)}
        </div>
      </nav>

      {/* Bottom User info bar */}
      <div style={{
        padding: '14px 18px',
        borderTop: '1px solid rgba(255, 255, 255, 0.08)',
        backgroundColor: 'rgba(0, 0, 0, 0.22)'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{
              width: '34px',
              height: '34px',
              borderRadius: '10px',
              backgroundColor: 'rgba(63, 167, 34, 0.25)',
              border: '1px solid rgba(136, 216, 76, 0.4)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontWeight: '800',
              fontSize: '13px',
              color: '#88D84C'
            }}>
              AD
            </div>
            <div>
              <div style={{ fontSize: '13px', fontWeight: '700', color: '#FFFFFF' }}>Master Admin</div>
              <div style={{ fontSize: '10.5px', color: '#88D84C', display: 'flex', alignItems: 'center', gap: '4px' }}>
                <span style={{ width: '6px', height: '6px', borderRadius: '50%', backgroundColor: '#88D84C' }} />
                Supabase Online
              </div>
            </div>
          </div>
          <button
            type="button"
            onClick={signOut}
            title="Sign out"
            style={{ color: 'rgba(255, 255, 255, 0.45)', padding: '6px', background: 'none', border: 0, cursor: 'pointer' }}
          >
            <LogOut size={16} />
          </button>
        </div>
      </div>
    </aside>
  );
}
