'use client';

import { useEffect, useState } from 'react';
import Header from '../../components/Header';
import { supabase } from '../../lib/supabase';
import { 
  FolderArchive, 
  Search, 
  FileText, 
  Image, 
  FileSpreadsheet, 
  Download, 
  Eye, 
  Plus, 
  Filter, 
  Calendar, 
  User,
  RefreshCw,
  CheckCircle2
} from 'lucide-react';

export default function DocumentsVaultPage() {
  const [documents, setDocuments] = useState([]);
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('all');
  const [loading, setLoading] = useState(true);

  async function loadDocuments() {
    setLoading(true);
    try {
      const { data } = await supabase
        .from('med_files')
        .select('*, members(name)')
        .order('created_at', { ascending: false });

      if (data && data.length > 0) {
        setDocuments(data.map((document) => ({
          ...document,
          title: document.description,
          category: document.file_type,
          fileSize: document.file_size ? `${Math.ceil(document.file_size / 1024)} KB` : null,
          memberName: document.members?.name,
          createdAt: document.created_at,
          fileUrl: document.file_url,
        })));
      } else {
        setDocuments([]);
      }
    } catch (_) {
      setDocuments([]);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadDocuments();
  }, []);

  const filtered = documents.filter((doc) => {
    const matchesSearch =
      doc.title?.toLowerCase().includes(search.toLowerCase()) ||
      doc.memberName?.toLowerCase().includes(search.toLowerCase()) ||
      doc.doctorName?.toLowerCase().includes(search.toLowerCase());

    if (!matchesSearch) return false;
    if (category === 'all') return true;
    return doc.category?.toLowerCase() === category.toLowerCase();
  });

  return (
    <>
      <Header title="Medical Document Vault" subtitle="Prescriptions, laboratory test reports, and imaging archives" />

      <div className="admin-content">
        {/* Top Control Bar */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', flexWrap: 'wrap', gap: '14px' }}>
          <div style={{ display: 'flex', gap: '14px', alignItems: 'center', flexWrap: 'wrap' }}>
            <div className="search-input" style={{ width: '320px' }}>
              <Search size={16} color="var(--text-light)" />
              <input
                type="text"
                placeholder="Search report, patient, or doctor..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>

            <div className="filter-tabs">
              <button
                className={`filter-tab ${category === 'all' ? 'active' : ''}`}
                onClick={() => setCategory('all')}
              >
                All Documents
              </button>
              <button
                className={`filter-tab ${category === 'lab report' ? 'active' : ''}`}
                onClick={() => setCategory('lab report')}
              >
                Lab Reports
              </button>
              <button
                className={`filter-tab ${category === 'prescription' ? 'active' : ''}`}
                onClick={() => setCategory('prescription')}
              >
                Prescriptions
              </button>
              <button
                className={`filter-tab ${category === 'radiology' ? 'active' : ''}`}
                onClick={() => setCategory('radiology')}
              >
                Radiology / X-Ray
              </button>
            </div>
          </div>

          <button onClick={loadDocuments} className="btn btn-secondary">
            <RefreshCw size={15} />
            <span>Refresh</span>
          </button>
        </div>

        {/* Documents Grid Cards */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '20px' }}>
          {filtered.length === 0 ? (
            <div className="card" style={{ gridColumn: '1 / -1', textAlign: 'center', padding: '40px', color: 'var(--text-light)' }}>
              No cloud documents found. Mobile reports are stored on the
              customer&apos;s device and appear here only after cloud synchronization.
            </div>
          ) : (
            filtered.map((doc) => (
              <div key={doc.id} className="card" style={{ display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '14px' }}>
                    <div style={{
                      width: '46px',
                      height: '46px',
                      borderRadius: '14px',
                      backgroundColor: doc.fileType === 'PDF' ? '#FEE2E2' : '#E0F2FE',
                      color: doc.fileType === 'PDF' ? '#B91C1C' : '#0369A1',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontWeight: '800',
                      fontSize: '12px'
                    }}>
                      <FileText size={22} />
                    </div>
                    <span className="badge badge-primary">{doc.category || 'Clinical'}</span>
                  </div>

                  <h4 style={{ fontSize: '15.5px', fontWeight: '800', color: 'var(--text-dark)', lineHeight: 1.3, marginBottom: '8px' }}>
                    {doc.title || doc.description || 'Medical Document'}
                  </h4>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', fontSize: '12.5px', color: 'var(--text-mid)', marginTop: '8px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <User size={14} color="var(--primary)" />
                      <span>Patient: <strong style={{ color: 'var(--text-dark)' }}>{doc.memberName || 'Family Member'}</strong></span>
                    </div>
                    {doc.doctorName && (
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <CheckCircle2 size={14} color="#0EA5E9" />
                        <span>Doctor: {doc.doctorName}</span>
                      </div>
                    )}
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <Calendar size={14} color="var(--text-light)" />
                      <span>Uploaded {doc.createdAt ? new Date(doc.createdAt).toLocaleDateString() : 'Recent'}</span>
                    </div>
                  </div>
                </div>

                <div style={{ marginTop: '18px', paddingTop: '14px', borderTop: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: '11.5px', fontWeight: '700', color: 'var(--text-light)' }}>
                    {doc.fileSize || 'Encrypted File'}
                  </span>
                  <button
                    onClick={() => doc.fileUrl && window.open(doc.fileUrl, '_blank', 'noopener,noreferrer')}
                    disabled={!doc.fileUrl}
                    className="btn btn-secondary"
                    style={{ padding: '6px 12px', fontSize: '12px', gap: '4px' }}
                  >
                    <Eye size={13} />
                    <span>View File</span>
                  </button>
                </div>
              </div>
            ))
          )}
        </div>

      </div>
    </>
  );
}
