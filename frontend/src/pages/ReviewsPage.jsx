import { useState, useEffect, useCallback } from 'react';
import { useAuth } from '../context/AuthContext';
import api from '../api/axios';
import Button from '../components/ui/Button';
import PageWrapper from '../components/layout/PageWrapper';
import {
  IconTrash, IconStar, ActionBtn, StatCard, FilterBar,
  DataTable,
} from '../components/ui/PageKit';

function StarIcon({ filled }) {
  return <svg width="14" height="14" viewBox="0 0 24 24" fill={filled?'#F59E0B':'none'} stroke="#F59E0B" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>;
}

function Stars({ rating, size = 14 }) {
  const r = Math.round(rating);
  return <span style={{ display:'inline-flex', gap:1 }}>{[1,2,3,4,5].map(i => <StarIcon key={i} filled={i<=r} />)}</span>;
}

function RatingBar({ label, count, total }) {
  const pct = total > 0 ? (count / total) * 100 : 0;
  return (
    <div style={{ display:'flex', alignItems:'center', gap:8, fontSize:12, color:'#475467', fontFamily:"'Inter',sans-serif" }}>
      <span style={{ width:8, textAlign:'right', fontWeight:600, color:'#101828' }}>{label}</span>
      <StarIcon filled />
      <div style={{ flex:1, height:6, background:'#F1F5F9', borderRadius:6, overflow:'hidden' }}>
        <div style={{ width:`${pct}%`, height:'100%', background:'#F59E0B', borderRadius:6, transition:'width 0.4s' }} />
      </div>
      <span style={{ width:24, color:'#98A2B3' }}>{count}</span>
    </div>
  );
}

export default function ReviewsPage() {
  const { user } = useAuth();
  const isAdmin  = ['superadmin','admin'].includes(user?.role);
  const [reviews, setReviews]       = useState([]);
  const [stats, setStats]           = useState(null);
  const [loading, setLoading]       = useState(true);
  const [filterStatus, setFilterStatus] = useState('all');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [revR, statsR] = await Promise.all([
        api.get('/reviews'),
        api.get('/reviews/stats'),
      ]);
      setReviews(Array.isArray(revR.data) ? revR.data : (revR.data?.reviews ?? []));
      setStats(statsR.data);
    } catch { }
    setLoading(false);
  }, []);
  useEffect(() => { load(); }, [load]);

  const handleApprove = async id => {
    if (!isAdmin) return;
    try { await api.patch(`/reviews/${id}/approve`); load(); } catch { }
  };
  const handleDelete = async id => {
    if (!window.confirm('Delete this review?')) return;
    await api.delete(`/reviews/${id}`); load();
  };

  const filtered = reviews.filter(r =>
    filterStatus === 'all' ? true : filterStatus === 'approved' ? r.is_approved : !r.is_approved
  );

  const dist  = stats?.ratingDistribution || {};
  const total = stats?.totalReviews || 0;

  return (
    <PageWrapper title="Reviews" subtitle="Customer satisfaction and feedback">

      {/* Rating Summary Card */}
      {stats && (
        <div style={{ background:'#fff', borderRadius:16, border:'1px solid #EAECF0', boxShadow:'0 1px 4px rgba(16,24,40,0.07)', padding:20, display:'grid', gridTemplateColumns:'auto 1fr', gap:20 }}>
          <div style={{ display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', padding:'0 24px', borderRight:'1px solid #EAECF0', minWidth:120 }}>
            <div style={{ fontFamily:"'Outfit',sans-serif", fontWeight:800, fontSize:52, color:'#101828', lineHeight:1 }}>{Number(stats.overallAvg||0).toFixed(1)}</div>
            <Stars rating={stats.overallAvg||0} size={18} />
            <div style={{ fontSize:12, color:'#98A2B3', marginTop:6 }}>{total} reviews</div>
          </div>
          <div style={{ padding:'4px 0', display:'flex', flexDirection:'column', gap:8 }}>
            {[5,4,3,2,1].map(n => <RatingBar key={n} label={n} count={dist[n]||0} total={total} />)}
          </div>
        </div>
      )}

      {/* Stat Cards */}
      <div style={{ display:'flex', gap:12, flexWrap:'wrap' }}>
        <StatCard label="Total Reviews"   value={total}                                          color="#2563EB" icon={<IconStar />} />
        <StatCard label="Approved"        value={reviews.filter(r=>r.is_approved).length}        color="#059669" icon={<IconStar />} />
        <StatCard label="Pending Approval" value={reviews.filter(r=>!r.is_approved).length}      color="#D97706" icon={<IconStar />} />
        <StatCard label="Avg Rating"      value={`${Number(stats?.overallAvg||0).toFixed(1)} / 5`} color="#F59E0B" icon={<IconStar />} />
      </div>

      {/* Filter Tabs */}
      <FilterBar>
        {[{ val:'all', label:'All' }, { val:'approved', label:'Approved' }, { val:'pending', label:'Pending Approval' }].map(f => (
          <button key={f.val} onClick={() => setFilterStatus(f.val)}
            style={{ padding:'5px 14px', borderRadius:20, border:'1.5px solid', cursor:'pointer', transition:'all 0.15s', fontSize:13, fontFamily:"'Inter',sans-serif",
              borderColor: filterStatus===f.val ? '#2563EB' : '#E4E7EC',
              background:  filterStatus===f.val ? '#EFF6FF' : '#fff',
              color:       filterStatus===f.val ? '#2563EB' : '#475467',
              fontWeight:  filterStatus===f.val ? 600 : 400 }}>
            {f.label}
            {f.val !== 'all' && <span style={{ marginLeft:5 }}>({reviews.filter(r=>f.val==='approved'?r.is_approved:!r.is_approved).length})</span>}
          </button>
        ))}
      </FilterBar>

      {/* Table */}
      <DataTable
        columns={[
          { accessorKey:'customer_name', header:'Customer', meta:{ width:'18%' },
            cell: ({ row }) => {
              const r = row.original;
              return (
                <>
                  <div style={{ fontWeight:600, color:'#101828', fontSize:14 }}>{r.customer_name}</div>
                  <div style={{ fontSize:12, color:'#98A2B3' }}>{r.customer_phone}</div>
                  <div style={{ fontSize:11, color:'#98A2B3', marginTop:2 }}>{r.createdAt ? new Date(r.createdAt).toLocaleDateString() : ''}</div>
                </>
              );
            }
          },
          { accessorKey:'service_rating', header:'Service', meta:{ width:'11%', align:'center' },
            cell: ({ getValue }) => <Stars rating={getValue()} />
          },
          { accessorKey:'staff_rating', header:'Staff', meta:{ width:'11%', align:'center' },
            cell: ({ getValue }) => <Stars rating={getValue()} />
          },
          { accessorKey:'comment', header:'Comment', meta:{ width:'24%' },
            cell: ({ getValue }) => {
              const c = getValue();
              return c ? <span style={{ fontSize:13, color:'#475467', fontStyle:'italic' }}>"{String(c).slice(0,70)}{c.length>70?'':''}"</span> : <span style={{ color:'#E4E7EC' }}></span>;
            }
          },
          { id:'serviceName', header:'Service', meta:{ width:'13%' },
            accessorFn: r => r.service?.name || '',
            cell: ({ getValue }) => <span style={{ fontSize:13, color:'#475467' }}>{getValue()}</span>
          },
          { id:'staffName', header:'Staff Member', meta:{ width:'13%' },
            accessorFn: r => r.staff?.name || '',
            cell: ({ getValue }) => <span style={{ fontSize:13, color:'#475467' }}>{getValue()}</span>
          },
          { id:'status', header:'Status', meta:{ width:'10%', align:'center' },
            cell: ({ row }) => {
              const r = row.original;
              return (
                <div style={{ display:'flex', gap:4, justifyContent:'center', flexDirection:'column', alignItems:'center' }}>
                  <button onClick={() => isAdmin && handleApprove(r.id)} disabled={r.is_approved}
                    style={{ padding:'3px 10px', borderRadius:6, fontSize:11, fontWeight:600, border:'none', cursor:isAdmin&&!r.is_approved?'pointer':'default',
                      background:r.is_approved?'#ECFDF5':'#FFFBEB', color:r.is_approved?'#059669':'#D97706' }}>
                    {r.is_approved ? 'Approved' : 'Pending'}
                  </button>
                  {isAdmin && <ActionBtn onClick={() => handleDelete(r.id)} title="Delete" color="#DC2626"><IconTrash /></ActionBtn>}
                </div>
              );
            }
          },
        ]}
        data={filtered}
        loading={loading}
        emptyMessage="No reviews found"
        emptySub="Customer reviews will appear here after appointments"
      />
    </PageWrapper>
  );
}
