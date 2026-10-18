import './globals.css';
import AdminShell from '../components/AdminShell';

export const metadata = {
  title: 'Medical History Admin Console',
  description: 'Web Admin Panel for Medical History Platform - Powered by Supabase & Next.js',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <AdminShell>{children}</AdminShell>
      </body>
    </html>
  );
}
