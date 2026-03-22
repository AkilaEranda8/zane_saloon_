import { useState, useEffect, useCallback } from 'react';
import { useAuth } from '../context/AuthContext';
import api from '../api/axios';
import Button from '../components/ui/Button';
import { Input, FormGroup } from '../components/ui/FormElements';
import PageWrapper from '../components/layout/PageWrapper';
import { useToast } from '../components/ui/Toast';
import {
  IconPlus, IconEdit, IconTrash, IconTag,
  ActionBtn, StatCard, PKModal as Modal, SearchBar, FilterBar,
} from '../components/ui/PageKit';

const DEFAULT_COLORS = {
  Hair:    { bg: '#EFF6FF', color: '#2563EB' },
  Beard:   { bg: '#F5F3FF', color: '#7C3AED' },
  Skin:    { bg: '#FFF7ED', color: '#EA580C' },
  Nail:    { bg: '#FFFBEB', color: '#D97706' },
  Massage: { bg: '#ECFDF5', color: '#059669' },
  Other:   { bg: '#F8FAFC', color: '#64748B' },
};
const PALETTE = ['#2563EB','#7C3AED','#EA580C','#D97706','#059669','#DC2626','#0891B2','#DB2777','#4F46E5','#64748B'];

function getCatStyle(name) {
  if (DEFAULT_COLORS[name]) return DEFAULT_COLORS[name];
  let hash = 0;
  for (let i = 0; i < name.length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash);
  const c = PALETTE[Math.abs(hash) % PALETTE.length];
  return { bg: c + '18', color: c };
}

export default function CategoriesPage() {
  const { user } = useAuth();
  const { toast } = useToast();
  const canEdit = ['superadmin', 'admin'].includes(user?.role);
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [showAdd, setShowAdd] = useState(false);
  const [showRename, setShowRename] = useState(false);
  const [newName, setNewName] = useState('');
  const [renameCat, setRenameCat] = useState(null);
  const [renameVal, setRenameVal] = useState('');
  const [saving, setSaving] = useState(false);
  const [formErr, setFormErr] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.get('/services/categories');
      setCategories(Array.isArray(res.data) ? res.data : []);
    } catch { }
    setLoading(false);
  }, []);
  useEffect(() => { load(); }, [load]);

  const totalServices = categories.reduce((s, c) => s + Number(c.count || 0), 0);
  const displayed = categories.filter(c => !search || c.category?.toLowerCase().includes(search.toLowerCase()));

  const handleAdd = async () => {
    if (!newName.trim()) return setFormErr('Enter category name');
    if (categories.some(c => c.category?.toLowerCase() === newName.trim().toLowerCase()))
      return setFormErr('Category already exists');
    setSaving(true);
    try {
      // Create a placeholder service then delete it — or just create via service
      // Better: Create an actual service with that category so it exists
      await api.post('/services', { name: `${newName.trim()} - Default`, category: newName.trim(), price: 0, duration_minutes: 30 });
      setShowAdd(false); setNewName(''); setFormErr('');
      toast('Category added!', 'success');
      load();
    } catch (e) { setFormErr(e.response?.data?.message || 'Failed to add'); }
    setSaving(false);
  };

  const handleRename = async () => {
    if (!renameVal.trim()) return setFormErr('Enter new name');
    if (renameVal.trim() === renameCat) return setFormErr('Name is the same');
    if (categories.some(c => c.category?.toLowerCase() === renameVal.trim().toLowerCase() && c.category !== renameCat))
      return setFormErr('Category already exists');
    setSaving(true);
    try {
      await api.put('/services/categories/rename', { oldName: renameCat, newName: renameVal.trim() });
      setShowRename(false); setRenameCat(null); setRenameVal(''); setFormErr('');
      toast('Category renamed!', 'success');
      load();
    } catch (e) { setFormErr(e.response?.data?.message || 'Failed to rename'); }
    setSaving(false);
  };

  const handleDelete = async (name) => {
    if (!window.confirm(`Delete "${name}"? All services in this category will be moved to "Other".`)) return;
    try {
      await api.post('/services/categories/delete', { name });
      toast('Category deleted', 'success');
      load();
    } catch { toast('Failed to delete', 'error'); }
  };

  return (
    <PageWrapper title="Categories" subtitle="Manage service categories"
      actions={canEdit && <Button variant="primary" onClick={() => { setNewName(''); setFormErr(''); setShowAdd(true); }} style={{ display: 'flex', alignItems: 'center', gap: 6 }}><IconPlus /> Add Category</Button>}>

      {/* Stats */}
      <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
        <StatCard label="Categories" value={categories.length} color="#6366F1" icon={<IconTag />} />
        <StatCard label="Total Services" value={totalServices} color="#059669" icon={<IconTag />} />
      </div>

      {/* Search */}
      <FilterBar>
        <SearchBar value={search} onChange={setSearch} placeholder="Search categories" />
      </FilterBar>

      {/* Category Grid */}
      {loading ? (
        <div style={{ textAlign: 'center', padding: 60, color: '#98A2B3' }}>Loading...</div>
      ) : displayed.length === 0 ? (
        <div style={{ textAlign: 'center', padding: 60 }}>
          <div style={{ fontSize: 40, marginBottom: 8 }}>📂</div>
          <div style={{ fontSize: 16, fontWeight: 700, color: '#101828', marginBottom: 4 }}>No categories found</div>
          <div style={{ fontSize: 13, color: '#98A2B3' }}>Add a category to organize your services</div>
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: 16 }}>
          {displayed.map(cat => {
            const s = getCatStyle(cat.category);
            return (
              <div key={cat.category} style={{
                background: '#fff', borderRadius: 16, border: '1px solid #E4E7EC',
                padding: 24, display: 'flex', flexDirection: 'column', gap: 12,
                transition: 'box-shadow 0.15s',
                boxShadow: '0 1px 3px rgba(16,24,40,0.06)',
              }}
              onMouseEnter={e => e.currentTarget.style.boxShadow = '0 4px 16px rgba(16,24,40,0.1)'}
              onMouseLeave={e => e.currentTarget.style.boxShadow = '0 1px 3px rgba(16,24,40,0.06)'}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <div style={{
                      width: 42, height: 42, borderRadius: 12, background: s.bg,
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      color: s.color, flexShrink: 0,
                    }}>
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                        strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z" />
                        <line x1="7" y1="7" x2="7.01" y2="7" />
                      </svg>
                    </div>
                    <div>
                      <div style={{ fontSize: 16, fontWeight: 700, color: '#101828', fontFamily: "'Outfit',sans-serif" }}>{cat.category}</div>
                      <div style={{ fontSize: 12, color: '#98A2B3', marginTop: 2 }}>
                        {cat.count} service{cat.count != 1 ? 's' : ''}
                      </div>
                    </div>
                  </div>
                  {canEdit && (
                    <div style={{ display: 'flex', gap: 4 }}>
                      <ActionBtn onClick={() => { setRenameCat(cat.category); setRenameVal(cat.category); setFormErr(''); setShowRename(true); }} title="Rename" color="#D97706"><IconEdit /></ActionBtn>
                      <ActionBtn onClick={() => handleDelete(cat.category)} title="Delete" color="#DC2626"><IconTrash /></ActionBtn>
                    </div>
                  )}
                </div>
                <div style={{
                  height: 4, borderRadius: 4, background: '#F2F4F7', overflow: 'hidden',
                }}>
                  <div style={{
                    height: '100%', borderRadius: 4, background: s.color,
                    width: totalServices > 0 ? `${(Number(cat.count) / totalServices) * 100}%` : '0%',
                    transition: 'width 0.3s',
                  }} />
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Add Modal */}
      <Modal open={showAdd} onClose={() => setShowAdd(false)} title="Add Category" size="sm"
        footer={<><Button variant="secondary" onClick={() => setShowAdd(false)}>Cancel</Button>
          <Button variant="primary" loading={saving} onClick={handleAdd}>Add Category</Button></>}>
        {formErr && <div style={{ background: '#FEF2F2', color: '#DC2626', padding: '9px 13px', borderRadius: 9, marginBottom: 14, fontSize: 13, border: '1px solid #FEE2E2' }}>{formErr}</div>}
        <FormGroup label="Category Name" required>
          <Input value={newName} onChange={e => setNewName(e.target.value)} placeholder="e.g. Facial, Spa, Bridal" autoFocus />
        </FormGroup>
      </Modal>

      {/* Rename Modal */}
      <Modal open={showRename} onClose={() => setShowRename(false)} title={`Rename "${renameCat}"`} size="sm"
        footer={<><Button variant="secondary" onClick={() => setShowRename(false)}>Cancel</Button>
          <Button variant="primary" loading={saving} onClick={handleRename}>Rename</Button></>}>
        {formErr && <div style={{ background: '#FEF2F2', color: '#DC2626', padding: '9px 13px', borderRadius: 9, marginBottom: 14, fontSize: 13, border: '1px solid #FEE2E2' }}>{formErr}</div>}
        <FormGroup label="New Name" required>
          <Input value={renameVal} onChange={e => setRenameVal(e.target.value)} autoFocus />
        </FormGroup>
      </Modal>
    </PageWrapper>
  );
}
