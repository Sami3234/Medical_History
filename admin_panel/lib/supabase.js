import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_ANON_KEY');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export async function getDashboardStats() {
  try {
    const [familiesRes, membersRes, doctorsRes, visitsRes] = await Promise.all([
      supabase.from('families').select('id', { count: 'exact', head: true }),
      supabase.from('members').select('id', { count: 'exact', head: true }),
      supabase.from('doctors').select('id', { count: 'exact', head: true }),
      supabase.from('visits').select('id', { count: 'exact', head: true }),
    ]);

    return {
      familiesCount: familiesRes.count ?? 0,
      membersCount: membersRes.count ?? 0,
      doctorsCount: doctorsRes.count ?? 0,
      visitsCount: visitsRes.count ?? 0,
    };
  } catch (error) {
    console.error('Error fetching dashboard stats:', error);
    return {
      familiesCount: 0,
      membersCount: 0,
      doctorsCount: 0,
      visitsCount: 0,
    };
  }
}
