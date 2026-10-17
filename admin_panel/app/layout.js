import './globals.css';
import Sidebar from '../components/Sidebar';

export const metadata = {
  title: 'Medical History Admin Console',
  description: 'Web Admin Panel for Medical History Platform - Powered by Supabase & Next.js',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <div className="admin-layout">
          <Sidebar />
          <main className="admin-main">
            {children}
          </main>
        </div>
      </body>
    </html>
  );
}
