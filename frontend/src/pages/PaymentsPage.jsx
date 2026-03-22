import { useState, useEffect, useCallback } from 'react';
import { createPortal } from 'react-dom';
import { useAuth } from '../context/AuthContext';
import api from '../api/axios';
import Button from '../components/ui/Button';
import { Input, Select, FormGroup } from '../components/ui/FormElements';
import PageWrapper from '../components/layout/PageWrapper';
import { useToast } from '../components/ui/Toast';
import {
  IconEye, IconPlus, IconDollar, IconReceipt, IconCalendar,
  ActionBtn, StatCard, PKModal as Modal, FilterBar, SearchBar,
  DataTable,
} from '../components/ui/PageKit';

const METHODS = ['Cash','Card','Online Transfer','Loyalty Points','Package'];
const METHOD_LABEL = { 'Cash':'Cash', 'Card':'Card', 'Online Transfer':'Bank Transfer', 'Loyalty Points':'Loyalty Pts', 'Package':'Package' };
const EMPTY_FORM = { branch_id:'', staff_id:'', customer_id:'', service_ids:[], total_amount:'', loyalty_discount:0, splits:[{ method:'Cash', amount:'' }] };

function PrintIcon() {
  return <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect x="6" y="14" width="12" height="8"/></svg>;
}

function InvoiceModal({ open, onClose, payment }) {
  if (!open || !payment) return null;
  return createPortal(
    <div style={{ position:'fixed', inset:0, zIndex:9000, display:'flex', alignItems:'center', justifyContent:'center', background:'rgba(16,24,40,0.55)', backdropFilter:'blur(2px)' }}>
      <div style={{ background:'#fff', borderRadius:20, padding:36, width:400, maxWidth:'95vw', boxShadow:'0 24px 64px rgba(16,24,40,0.25)', fontFamily:"'Inter',sans-serif" }}>
        <div style={{ textAlign:'center', marginBottom:24 }}>
          <div style={{ width:48, height:48, borderRadius:14, background:'#EFF6FF', display:'flex', alignItems:'center', justifyContent:'center', margin:'0 auto 10px', color:'#2563EB' }}>
            <IconReceipt />
          </div>
          <h2 style={{ margin:0, fontFamily:"'Outfit',sans-serif", fontWeight:800, fontSize:20, color:'#101828' }}>LuxeSalon</h2>
          <p style={{ margin:'4px 0 0', color:'#98A2B3', fontSize:12 }}>Payment Receipt</p>
        </div>
        <div style={{ borderTop:'2px dashed #E4E7EC', paddingTop:16, marginBottom:16 }}>
          {[
            { label:'Customer', value: payment.customer_name },
            { label:'Service',  value: payment.service?.name || '' },
            { label:'Staff',    value: payment.staff?.name || '' },
            { label:'Date',     value: payment.date ? new Date(payment.date).toLocaleDateString() : '' },
          ].map(({ label, value }) => (
            <div key={label} style={{ display:'flex', justifyContent:'space-between', marginBottom:8, fontSize:13 }}>
              <span style={{ color:'#98A2B3' }}>{label}</span>
              <span style={{ fontWeight:600, color:'#101828' }}>{value}</span>
            </div>
          ))}
          <div style={{ borderTop:'1px solid #EAECF0', marginTop:8, paddingTop:8 }}>
            {(payment.splits||[]).map((sp, i) => (
              <div key={i} style={{ display:'flex', justifyContent:'space-between', marginBottom:6, fontSize:13 }}>
                <span style={{ color:'#475467' }}>{METHOD_LABEL[sp.method]||sp.method}</span>
                <span style={{ fontWeight:600 }}>Rs. {Number(sp.amount||0).toLocaleString()}</span>
              </div>
            ))}
          </div>
        </div>
        <div style={{ background:'#EFF6FF', padding:'12px 16px', borderRadius:10, display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:20 }}>
          <span style={{ fontWeight:700, color:'#2563EB' }}>Total</span>
          <span style={{ fontFamily:"'Outfit',sans-serif", fontWeight:800, fontSize:18, color:'#2563EB' }}>Rs. {Number(payment.total_amount||0).toLocaleString()}</span>
        </div>
        <div style={{ display:'flex', gap:8 }}>
          <Button variant="secondary" fullWidth onClick={onClose}>Close</Button>
          <Button variant="primary" fullWidth onClick={() => window.print()} style={{ display:'flex', alignItems:'center', justifyContent:'center', gap:6 }}><PrintIcon /> Print</Button>
        </div>
      </div>
    </div>,
    document.body
  );
}

function ServiceMultiSelect({ services, selected, onChange }) {
  const [open, setOpen] = useState(false);
  const selSvcs = services.filter(s => selected.includes(s.id));
  const toggle = id => onChange(selected.includes(id) ? selected.filter(x => x !== id) : [...selected, id]);
  return (
    <div style={{ position:'relative' }}>
      {open && <div onClick={() => setOpen(false)} style={{ position:'fixed', inset:0, zIndex:99 }} />}
      <div onClick={() => setOpen(o => !o)} style={{
        minHeight:38, padding:'6px 10px', borderRadius:10, border:'1.5px solid #D0D5DD',
        background:'#fff', cursor:'pointer', display:'flex', flexWrap:'wrap', gap:5, alignItems:'center',
      }}>
        {selSvcs.length === 0
          ? <span style={{ color:'#98A2B3', fontSize:13, userSelect:'none' }}>Select services…</span>
          : selSvcs.map(s => (
            <span key={s.id} style={{ display:'inline-flex', alignItems:'center', gap:3, padding:'2px 8px 2px 10px', borderRadius:99, background:'#EFF6FF', color:'#2563EB', fontSize:12, fontWeight:600 }}>
              {s.name}
              <span onMouseDown={e => { e.stopPropagation(); toggle(s.id); }} style={{ cursor:'pointer', color:'#93C5FD', fontWeight:700, fontSize:14, lineHeight:1, marginLeft:3 }}>×</span>
            </span>
          ))}
        <span style={{ marginLeft:'auto', fontSize:11, color:'#98A2B3', userSelect:'none', paddingLeft:4 }}>▾</span>
      </div>
      {open && (
        <div style={{
          position:'absolute', top:'calc(100% + 4px)', left:0, right:0, zIndex:100,
          background:'#fff', border:'1.5px solid #E4E7EC', borderRadius:10,
          boxShadow:'0 8px 24px rgba(16,24,40,0.12)', maxHeight:230, overflowY:'auto',
        }}>
          {services.length === 0 && <div style={{ padding:'12px 14px', fontSize:13, color:'#98A2B3' }}>No services found</div>}
          {services.map(s => (
            <label key={s.id} style={{
              display:'flex', alignItems:'center', gap:10, padding:'9px 14px', cursor:'pointer',
              background: selected.includes(s.id) ? '#F0F9FF' : 'transparent',
              borderBottom:'1px solid #F8FAFC',
            }}>
              <input type="checkbox" checked={selected.includes(s.id)} onChange={() => toggle(s.id)}
                style={{ accentColor:'#2563EB', width:15, height:15, flexShrink:0, cursor:'pointer' }} />
              <span style={{ flex:1, fontSize:13, color:'#344054', fontWeight: selected.includes(s.id) ? 600 : 400 }}>{s.name}</span>
              <span style={{ fontSize:12, color:'#059669', fontWeight:700, fontFamily:"'Outfit',sans-serif" }}>Rs. {Number(s.price||0).toLocaleString()}</span>
            </label>
          ))}
        </div>
      )}
    </div>
  );
}

export default function PaymentsPage() {
  const { user } = useAuth();
  const { toast } = useToast();
  const canEdit  = ['superadmin','admin','manager'].includes(user?.role);
  const isAdmin  = ['superadmin','admin'].includes(user?.role);
  const hasFixedBranch = !!user?.branchId;
  const today = new Date().toISOString().slice(0,10);
  const curMonth = today.slice(0,7);
  const [payments, setPayments]   = useState([]);
  const [summary, setSummary]     = useState(null);
  const [branches, setBranches]   = useState([]);
  const [customers, setCustomers] = useState([]);
  const [staffList, setStaffList] = useState([]);
  const [services, setServices]   = useState([]);
  const [loading, setLoading]     = useState(true);
  const [filterBranch, setFilterBranch] = useState(hasFixedBranch ? user.branchId : '');
  const [filterMonth, setFilterMonth]   = useState(curMonth);
  const [search, setSearch]       = useState('');
  const [showForm, setShowForm]   = useState(false);
  const [showInvoice, setShowInvoice] = useState(false);
  const [invoiceItem, setInvoiceItem] = useState(null);
  const [form, setForm]           = useState(EMPTY_FORM);
  const [saving, setSaving]       = useState(false);
  const [formErr, setFormErr]     = useState('');
  const [custPackages, setCustPackages] = useState([]);
  const [loadingPkgs, setLoadingPkgs]   = useState(false);

  // Load reference data once on mount (independent of payment filters)
  useEffect(() => {
    Promise.allSettled([
      api.get('/branches',  { params:{ limit:100 } }),
      api.get('/customers', { params:{ limit:500 } }),
      api.get('/staff',     { params:{ limit:200 } }),
      api.get('/services',  { params:{ limit:200 } }),
    ]).then(([brR, cuR, stR, svR]) => {
      if (brR.status === 'fulfilled') setBranches(Array.isArray(brR.value.data) ? brR.value.data : (brR.value.data?.data ?? []));
      if (cuR.status === 'fulfilled') setCustomers(Array.isArray(cuR.value.data) ? cuR.value.data : (cuR.value.data?.data ?? []));
      if (stR.status === 'fulfilled') setStaffList(Array.isArray(stR.value.data) ? stR.value.data : (stR.value.data?.data ?? []));
      if (svR.status === 'fulfilled') setServices(Array.isArray(svR.value.data) ? svR.value.data : (svR.value.data?.data ?? []));
    });
  }, []);

  // Load payments + summary whenever filters change
  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = {
        limit: 500,
        ...(filterBranch ? { branchId: filterBranch } : {}),
        ...(filterMonth  ? { month:    filterMonth  } : {}),
      };
      const [pmR, sumR] = await Promise.allSettled([
        api.get('/payments', { params }),
        api.get('/payments/summary', { params }),
      ]);
      if (pmR.status === 'fulfilled')
        setPayments(Array.isArray(pmR.value.data) ? pmR.value.data : (pmR.value.data?.data ?? []));
      // summary endpoint returns an array grouped by branch — aggregate it
      if (sumR.status === 'fulfilled') {
        const sumArr = Array.isArray(sumR.value.data) ? sumR.value.data : [];
        setSummary(sumArr.reduce((acc, b) => ({
          revenue:    acc.revenue    + Number(b.revenue    || 0),
          commission: acc.commission + Number(b.commission || 0),
          count:      acc.count      + Number(b.count      || 0),
        }), { revenue: 0, commission: 0, count: 0 }));
      }
    } catch { }
    setLoading(false);
  }, [filterBranch, filterMonth]);
  useEffect(() => { load(); }, [load]);

  const openAdd = () => { setForm({ ...EMPTY_FORM, branch_id: user?.branchId||'' }); setFormErr(''); setCustPackages([]); setShowForm(true); };
  const setSplit = (idx, field, val) => {
    setForm(f => {
      const s = [...f.splits];
      s[idx] = { ...s[idx], [field]: val };
      // Clear customer_package_id when method changes away from Package
      if (field === 'method' && val !== 'Package') delete s[idx].customer_package_id;
      return { ...f, splits: s };
    });
  };
  const addSplit    = () => setForm(f => ({ ...f, splits: [...f.splits, { method:'Cash', amount:'' }] }));
  const removeSplit = idx => setForm(f => ({ ...f, splits: f.splits.filter((_,i) => i!==idx) }));

  const handleSave = async () => {
    if (!form.total_amount || !form.service_ids.length) return setFormErr('Total amount and at least one service are required');
    const splitTotal = form.splits.reduce((s, sp) => s + Number(sp.amount||0), 0);
    if (Math.abs(splitTotal - Number(form.total_amount)) > 0.01 && form.splits.length > 0)
      return setFormErr(`Split total (Rs. ${splitTotal.toLocaleString()}) must equal total (Rs. ${Number(form.total_amount).toLocaleString()})`);
    setSaving(true);
    try {
      const { service_ids, ...rest } = form;
      // Include customer_package_id in splits payload
      const payload = { ...rest, service_id: service_ids[0] || null };
      await api.post('/payments', payload); setShowForm(false); load();
      toast('Payment recorded successfully!', 'success');
    } catch (e) { setFormErr(e.response?.data?.message || 'Save failed'); }
    setSaving(false);
  };

  const displayed = payments.filter(p => {
    if (!search) return true;
    const q = search.toLowerCase();
    return p.customer_name?.toLowerCase().includes(q) || p.service?.name?.toLowerCase().includes(q) || p.staff?.name?.toLowerCase().includes(q);
  });

  return (
    <PageWrapper title="Payments" subtitle="Revenue tracking and payment recording"
      actions={canEdit && <Button variant="primary" onClick={openAdd} style={{ display:'flex', alignItems:'center', gap:6 }}><IconPlus /> Record Payment</Button>}>

      {/* Stat Cards */}
      {summary && (
        <div style={{ display:'flex', gap:12, flexWrap:'wrap' }}>
          <StatCard label="Revenue"      value={`Rs. ${Number(summary.revenue||0).toLocaleString()}`}                          color="#059669" icon={<IconDollar />} />
          <StatCard label="Commission"   value={`Rs. ${Number(summary.commission||0).toLocaleString()}`}                       color="#D97706" icon={<IconReceipt />} />
          <StatCard label="Transactions" value={summary.count||0}                                                               color="#2563EB" icon={<IconCalendar />} />
          <StatCard label="Avg Ticket"   value={`Rs. ${summary.count ? Math.round((summary.revenue||0)/(summary.count||1)).toLocaleString() : 0}`} color="#7C3AED" icon={<IconReceipt />} />
        </div>
      )}

      {/* Filter Bar */}
      <FilterBar>
        <SearchBar value={search} onChange={setSearch} placeholder="Search payments" />
        <input type="month" value={filterMonth} onChange={e => setFilterMonth(e.target.value)}
          style={{ padding:'7px 12px', borderRadius:9, border:'1.5px solid #E4E7EC', fontSize:13, fontFamily:"'Inter',sans-serif", outline:'none', color:'#344054' }} />
        {isAdmin && !hasFixedBranch && (
          <select value={filterBranch} onChange={e => setFilterBranch(e.target.value)}
            style={{ padding:'7px 12px', borderRadius:9, border:'1.5px solid #E4E7EC', fontSize:13, fontFamily:"'Inter',sans-serif", outline:'none', color:'#344054', background:'#fff' }}>
            <option value="">All Branches</option>
            {branches.map(b => <option key={b.id} value={b.id}>{b.name}</option>)}
          </select>
        )}
      </FilterBar>

      {/* Table */}
      <DataTable
        columns={[
          { id:'date', header:'Date', meta:{ width:'12%' },
            accessorFn: r => r.date || '',
            cell: ({ row }) => {
              const d = row.original.date;
              return (
                <>
                  <div style={{ fontSize:13, fontWeight:600, color:'#344054' }}>{d ? new Date(d).toLocaleDateString('en-US',{day:'numeric',month:'short'}) : ''}</div>
                  <div style={{ fontSize:11, color:'#98A2B3' }}>{d ? new Date(d).getFullYear() : ''}</div>
                </>
              );
            }
          },
          { accessorKey:'customer_name', header:'Customer', meta:{ width:'18%' },
            cell: ({ row }) => (
              <>
                <div style={{ fontWeight:600, color:'#101828', fontSize:14 }}>{row.original.customer_name || 'Walk-in'}</div>
                <div style={{ fontSize:12, color:'#98A2B3' }}>{row.original.staff?.name || ''}</div>
              </>
            )
          },
          { id:'service', header:'Service', meta:{ width:'16%' },
            accessorFn: r => r.service?.name || '',
            cell: ({ getValue }) => <span style={{ fontSize:13, color:'#475467' }}>{getValue()}</span>
          },
          { id:'payment', header:'Payment', meta:{ width:'20%' },
            cell: ({ row }) => (
              <div style={{ display:'flex', gap:4, flexWrap:'wrap' }}>
                {(row.original.splits||[]).map((sp, i) => (
                  <span key={i} style={{ padding:'2px 7px', borderRadius:5, background:'#F9FAFB', border:'1px solid #E4E7EC', fontSize:11, color:'#475467' }}>
                    {METHOD_LABEL[sp.method]||sp.method} Rs.{Number(sp.amount||0).toLocaleString()}
                  </span>
                ))}
              </div>
            )
          },
          { accessorKey:'total_amount', header:'Total', meta:{ width:'12%', align:'right' },
            cell: ({ getValue }) => <span style={{ fontWeight:800, color:'#059669', fontFamily:"'Outfit',sans-serif", fontSize:15 }}>Rs. {Number(getValue()||0).toLocaleString()}</span>
          },
          { accessorKey:'commission_amount', header:'Commission', meta:{ width:'12%', align:'right' },
            cell: ({ getValue }) => <span style={{ fontWeight:800, color:'#D97706', fontFamily:"'Outfit',sans-serif", fontSize:15 }}>Rs. {Number(getValue()||0).toLocaleString()}</span>
          },
          { id:'invoice', header:'Invoice', meta:{ width:'10%', align:'center' },
            cell: ({ row }) => <ActionBtn onClick={() => { setInvoiceItem(row.original); setShowInvoice(true); }} title="View Invoice" color="#2563EB"><IconEye /></ActionBtn>
          },
        ]}
        data={displayed}
        loading={loading}
        emptyMessage="No payments recorded"
        emptySub="Use the Record Payment button to add transactions"
      />

      {/* Record Payment Modal */}
      <Modal open={showForm} onClose={() => setShowForm(false)} title="Record Payment" size="md"
        footer={<><Button variant="secondary" onClick={() => setShowForm(false)}>Cancel</Button>
          <Button variant="primary" loading={saving} onClick={handleSave}>Record Payment</Button></>}>
        {formErr && <div style={{ background:'#FEF2F2', color:'#DC2626', padding:'9px 13px', borderRadius:9, marginBottom:14, fontSize:13, border:'1px solid #FEE2E2' }}>{formErr}</div>}
        <div style={{ display:'flex', flexDirection:'column', gap:14 }}>
          {(isAdmin && !hasFixedBranch) && (
            <FormGroup label="Branch">
              <Select value={form.branch_id||''} onChange={e => setForm(f=>({...f, branch_id:e.target.value, staff_id:''}))}>
                <option value="">Select branch</option>
                {branches.map(b => <option key={b.id} value={b.id}>{b.name}</option>)}
              </Select>
            </FormGroup>
          )}
          <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:14 }}>
            <FormGroup label="Customer">
              <Select value={form.customer_id||''} onChange={e => {
                const cid = e.target.value;
                setForm(f=>({...f, customer_id:cid}));
                setCustPackages([]);
                if (cid) {
                  setLoadingPkgs(true);
                  api.get(`/packages/customer/${cid}/active`).then(r => {
                    setCustPackages(Array.isArray(r.data) ? r.data : []);
                  }).catch(() => {}).finally(() => setLoadingPkgs(false));
                }
              }}>
                <option value="">Walk-in / select</option>
                {customers.map(c => <option key={c.id} value={c.id}>{c.name} ({c.phone})</option>)}
              </Select>
            </FormGroup>
            <FormGroup label="Staff">
              <Select value={form.staff_id||''} onChange={e => setForm(f=>({...f, staff_id:e.target.value}))}>
                <option value="">Select staff</option>
                {(form.branch_id ? staffList.filter(s => s.branch_id == form.branch_id) : staffList).map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
              </Select>
            </FormGroup>
          </div>
          <FormGroup label="Services" required>
            <ServiceMultiSelect
              services={services.filter(s => s.is_active !== false)}
              selected={form.service_ids}
              onChange={ids => {
                const svcs = services.filter(s => ids.includes(s.id));
                const total = svcs.reduce((sum, s) => sum + Number(s.price || 0), 0);
                setForm(f => ({
                  ...f,
                  service_ids: ids,
                  total_amount: total > 0 ? String(total) : '',
                  splits: total > 0 && f.splits.length === 1
                    ? [{ ...f.splits[0], amount: String(total) }]
                    : f.splits,
                }));
              }}
            />
            {form.service_ids.length > 0 && (
              <div style={{ marginTop:6, display:'flex', gap:6, flexWrap:'wrap' }}>
                {services.filter(s => form.service_ids.includes(s.id)).map(s => (
                  <span key={s.id} style={{ fontSize:11, color:'#475467', background:'#F8FAFC', border:'1px solid #E4E7EC', padding:'2px 8px', borderRadius:6 }}>
                    {s.name} — Rs. {Number(s.price||0).toLocaleString()}
                  </span>
                ))}
                {form.service_ids.length > 1 && (
                  <span style={{ fontSize:11, fontWeight:700, color:'#059669', background:'#ECFDF5', border:'1px solid #A7F3D0', padding:'2px 8px', borderRadius:6 }}>
                    Total: Rs. {services.filter(s => form.service_ids.includes(s.id)).reduce((sum, s) => sum + Number(s.price||0), 0).toLocaleString()}
                  </span>
                )}
              </div>
            )}
          </FormGroup>
          <FormGroup label="Total Amount (Rs.)" required>
            <Input type="number" value={form.total_amount||''} onChange={e => setForm(f=>({...f, total_amount:e.target.value}))} />
          </FormGroup>
          <FormGroup label="Loyalty Discount (Rs.)">
            <Input type="number" value={form.loyalty_discount||0} onChange={e => setForm(f=>({...f, loyalty_discount:Number(e.target.value)}))} />
          </FormGroup>
          <div>
            <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:8 }}>
              <span style={{ fontSize:12, fontWeight:700, color:'#344054', textTransform:'uppercase', letterSpacing:'0.04em', fontFamily:"'Inter',sans-serif" }}>Payment Splits</span>
              <Button variant="ghost" size="sm" onClick={addSplit}>+ Add Split</Button>
            </div>
            {form.splits.map((sp, i) => (
              <div key={i} style={{ marginBottom:8 }}>
                <div style={{ display:'flex', gap:8, alignItems:'center' }}>
                  <Select value={sp.method} onChange={e => setSplit(i,'method',e.target.value)} style={{ flex:'0 0 155px' }}>
                    {METHODS.map(m => <option key={m} value={m}>{METHOD_LABEL[m]}</option>)}
                  </Select>
                  <Input type="number" value={sp.amount} placeholder="Amount" onChange={e => setSplit(i,'amount',e.target.value)} style={{ flex:1 }} />
                  {form.splits.length > 1 && (
                    <button onClick={() => removeSplit(i)} style={{ background:'none', border:'none', cursor:'pointer', color:'#DC2626', fontSize:18, padding:'0 4px' }}>×</button>
                  )}
                </div>
                {sp.method === 'Package' && (
                  <div style={{ marginTop:6, marginLeft:0 }}>
                    {!form.customer_id ? (
                      <div style={{ fontSize:12, color:'#D97706', background:'#FFFBEB', padding:'6px 10px', borderRadius:7, border:'1px solid #FDE68A' }}>Select a customer first to use package payment</div>
                    ) : loadingPkgs ? (
                      <div style={{ fontSize:12, color:'#98A2B3' }}>Loading packages...</div>
                    ) : custPackages.length === 0 ? (
                      <div style={{ fontSize:12, color:'#D97706', background:'#FFFBEB', padding:'6px 10px', borderRadius:7, border:'1px solid #FDE68A' }}>No active packages for this customer</div>
                    ) : (
                      <Select value={sp.customer_package_id||''} onChange={e => setSplit(i,'customer_package_id',e.target.value)}
                        style={{ marginTop:2, fontSize:12 }}>
                        <option value="">Select package…</option>
                        {custPackages.map(cp => (
                          <option key={cp.id} value={cp.id}>
                            {cp.package?.name || 'Package'} — {cp.sessions_remaining || (cp.sessions_total - cp.sessions_used)} sessions left (expires {new Date(cp.expiry_date).toLocaleDateString()})
                          </option>
                        ))}
                      </Select>
                    )}
                  </div>
                )}
              </div>
            ))}
            {form.splits.length > 0 && form.total_amount && (
              <div style={{ fontSize:12, color:'#98A2B3', textAlign:'right' }}>
                Split total: Rs. {form.splits.reduce((s,sp)=>s+Number(sp.amount||0),0).toLocaleString()} / Rs. {Number(form.total_amount||0).toLocaleString()}
              </div>
            )}
          </div>
        </div>
      </Modal>

      <InvoiceModal open={showInvoice} onClose={() => setShowInvoice(false)} payment={invoiceItem} />
    </PageWrapper>
  );
}
