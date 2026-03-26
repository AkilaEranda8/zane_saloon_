import { useCallback, useEffect, useMemo, useState } from 'react';
import PageWrapper from '../components/layout/PageWrapper';
import Button from '../components/ui/Button';
import api from '../api/axios';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../components/ui/Toast';

export default function OfferSmsPage() {
  const { user } = useAuth();
  const { toast } = useToast();
  const isSuperAdmin = user?.role === 'superadmin';

  const [customers, setCustomers] = useState([]);
  const [branches, setBranches] = useState([]);
  const [branchId, setBranchId] = useState(isSuperAdmin ? '' : String(user?.branch_id || ''));
  const [search, setSearch] = useState('');
  const [selectedIds, setSelectedIds] = useState([]);
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);
  const [sending, setSending] = useState(false);

  const loadCustomers = useCallback(async () => {
    setLoading(true);
    try {
      const [cuR, brR] = await Promise.all([
        api.get('/customers', { params: { limit: 500, ...(branchId ? { branchId } : {}) } }),
        api.get('/branches', { params: { limit: 100 } }),
      ]);
      const list = Array.isArray(cuR.data) ? cuR.data : (cuR.data?.data || []);
      const branchList = Array.isArray(brR.data) ? brR.data : (brR.data?.data || []);
      setCustomers(list);
      setBranches(branchList);
      setSelectedIds([]);
    } catch {
      toast('Failed to load customers.', 'error');
    } finally {
      setLoading(false);
    }
  }, [branchId, toast]);

  useEffect(() => {
    loadCustomers();
  }, [loadCustomers]);

  const visibleCustomers = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return customers;
    return customers.filter((c) =>
      String(c.name || '').toLowerCase().includes(q) ||
      String(c.phone || '').toLowerCase().includes(q) ||
      String(c.email || '').toLowerCase().includes(q)
    );
  }, [customers, search]);

  const visibleIds = visibleCustomers.map((c) => c.id);
  const allVisibleSelected = visibleIds.length > 0 && visibleIds.every((id) => selectedIds.includes(id));

  const toggleOne = (id) => {
    setSelectedIds((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));
  };

  const toggleAllVisible = () => {
    setSelectedIds((prev) => {
      if (allVisibleSelected) return prev.filter((id) => !visibleIds.includes(id));
      return Array.from(new Set([...prev, ...visibleIds]));
    });
  };

  const handleSend = async () => {
    const cleanMsg = message.trim();
    if (!selectedIds.length) return toast('Select at least one customer.', 'error');
    if (!cleanMsg) return toast('Type an offer SMS message.', 'error');
    setSending(true);
    try {
      const res = await api.post('/notifications/offer-sms', {
        customerIds: selectedIds,
        message: cleanMsg,
      });
      toast(res.data?.message || 'Offer SMS sent.', 'success');
      setMessage('');
    } catch (err) {
      toast(err?.response?.data?.message || 'Failed to send offer SMS.', 'error');
    } finally {
      setSending(false);
    }
  };

  return (
    <PageWrapper
      title="Offer SMS"
      subtitle="Select customers and send promotional SMS messages"
      actions={
        <Button onClick={handleSend} disabled={sending || loading}>
          {sending ? 'Sending...' : `Send SMS (${selectedIds.length})`}
        </Button>
      }
    >
      <div style={{ display: 'grid', gridTemplateColumns: '1.1fr 1fr', gap: 16 }}>
        <div style={{ background: '#fff', border: '1px solid #EAECF0', borderRadius: 12, overflow: 'hidden' }}>
          <div style={{ padding: 14, borderBottom: '1px solid #F2F4F7', display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search by name / phone"
              style={{ flex: 1, minWidth: 180, padding: '8px 10px', borderRadius: 8, border: '1px solid #E4E7EC', fontSize: 13 }}
            />
            {isSuperAdmin && (
              <select
                value={branchId}
                onChange={(e) => setBranchId(e.target.value)}
                style={{ minWidth: 180, padding: '8px 10px', borderRadius: 8, border: '1px solid #E4E7EC', fontSize: 13 }}
              >
                <option value="">All branches</option>
                {branches.map((b) => (
                  <option key={b.id} value={b.id}>{b.name}</option>
                ))}
              </select>
            )}
            <Button variant="ghost" onClick={toggleAllVisible} disabled={!visibleIds.length}>
              {allVisibleSelected ? 'Unselect Visible' : 'Select Visible'}
            </Button>
          </div>

          <div style={{ maxHeight: 480, overflow: 'auto' }}>
            {loading ? (
              <div style={{ padding: 18, fontSize: 13, color: '#667085' }}>Loading customers...</div>
            ) : visibleCustomers.length === 0 ? (
              <div style={{ padding: 18, fontSize: 13, color: '#667085' }}>No customers found.</div>
            ) : (
              visibleCustomers.map((c) => (
                <label
                  key={c.id}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 10,
                    padding: '10px 14px',
                    borderBottom: '1px solid #F8FAFC',
                    cursor: 'pointer',
                    background: selectedIds.includes(c.id) ? '#F5F8FF' : '#fff',
                  }}
                >
                  <input
                    type="checkbox"
                    checked={selectedIds.includes(c.id)}
                    onChange={() => toggleOne(c.id)}
                  />
                  <div style={{ minWidth: 0 }}>
                    <div style={{ fontSize: 13, fontWeight: 600, color: '#101828' }}>{c.name}</div>
                    <div style={{ fontSize: 12, color: '#667085' }}>{c.phone || 'No phone number'}</div>
                  </div>
                </label>
              ))
            )}
          </div>
        </div>

        <div style={{ background: '#fff', border: '1px solid #EAECF0', borderRadius: 12, padding: 14 }}>
          <div style={{ fontSize: 14, fontWeight: 700, color: '#101828', marginBottom: 10 }}>Message</div>
          <textarea
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            placeholder="Type your offer message here..."
            maxLength={480}
            rows={12}
            style={{
              width: '100%',
              borderRadius: 10,
              border: '1px solid #E4E7EC',
              padding: 12,
              fontSize: 13,
              resize: 'vertical',
              boxSizing: 'border-box',
            }}
          />
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, fontSize: 12, color: '#667085' }}>
            <span>Selected: {selectedIds.length}</span>
            <span>{message.length}/480</span>
          </div>
          <div style={{ marginTop: 12, display: 'flex', gap: 8 }}>
            <Button onClick={handleSend} disabled={sending || loading}>
              {sending ? 'Sending...' : 'Send Offer SMS'}
            </Button>
            <Button variant="ghost" onClick={() => setMessage('')}>
              Clear Message
            </Button>
          </div>
        </div>
      </div>
    </PageWrapper>
  );
}
