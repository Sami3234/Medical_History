'use client';

import { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { supabase } from '../lib/supabase';
import Sidebar from './Sidebar';

export default function AdminShell({ children }) {
  const pathname = usePathname();
  const router = useRouter();
  const [authorized, setAuthorized] = useState(false);
  const [checking, setChecking] = useState(pathname !== '/login');

  useEffect(() => {
    if (pathname === '/login') {
      setAuthorized(false);
      setChecking(false);
      return undefined;
    }

    let active = true;

    async function verifyAdmin() {
      setChecking(true);
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        if (active) router.replace('/login');
        return;
      }

      const { data: profile, error } = await supabase
        .from('profiles')
        .select('is_admin')
        .eq('id', session.user.id)
        .maybeSingle();

      if (error || !profile?.is_admin) {
        await supabase.auth.signOut();
        if (active) router.replace('/login');
        return;
      }

      if (active) {
        setAuthorized(true);
        setChecking(false);
      }
    }

    verifyAdmin();
    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      if (!session && active) router.replace('/login');
    });

    return () => {
      active = false;
      listener.subscription.unsubscribe();
    };
  }, [pathname, router]);

  if (pathname === '/login') return children;

  if (checking || !authorized) {
    return (
      <div className="admin-auth-loading" role="status" aria-live="polite">
        Verifying administrator access...
      </div>
    );
  }

  return (
    <div className="admin-layout">
      <Sidebar />
      <main className="admin-main">{children}</main>
    </div>
  );
}
