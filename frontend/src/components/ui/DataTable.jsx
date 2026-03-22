import { useState, useEffect, useMemo } from 'react';
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  flexRender,
} from '@tanstack/react-table';

/* ─── Debounce hook ──────────────────────────────────────────────────── */

function useDebounce(value, delay) {
  const [deb, setDeb] = useState(value);
  useEffect(() => {
    const id = setTimeout(() => setDeb(value), delay);
    return () => clearTimeout(id);
  }, [value, delay]);
  return deb;
}

/* ─── Skeleton shimmer row ───────────────────────────────────────────── */

function SkeletonRow({ colCount }) {
  return (
    <tr>
      {Array.from({ length: colCount }).map((_, i) => (
        <td key={i} style={{ padding: '13px 16px' }}>
          <div style={{
            height:     13,
            borderRadius: 6,
            width:      `${55 + (i * 17) % 35}%`,
            background: 'linear-gradient(90deg, #F2F4F7 25%, #E8EAED 50%, #F2F4F7 75%)',
            backgroundSize: '200% 100%',
            animation:  'dt-shimmer 1.4s infinite',
          }} />
        </td>
      ))}
    </tr>
  );
}

/* ─── Sort indicator icon ────────────────────────────────────────────── */

function SortIcon({ dir }) {
  if (!dir) return <span style={{ opacity: 0.3, fontSize: 11, lineHeight: 1 }}>⇅</span>;
  return <span style={{ fontSize: 11, lineHeight: 1 }}>{dir === 'asc' ? '↑' : '↓'}</span>;
}

/* ─── Pagination button ──────────────────────────────────────────────── */

function PagBtn({ onClick, disabled, active, label }) {
  const [hov, setHov] = useState(false);
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      onMouseEnter={() => setHov(true)}
      onMouseLeave={() => setHov(false)}
      style={{
        minWidth:   30,
        height:     30,
        padding:    '0 6px',
        border:     active ? '1.5px solid #2563EB' : '1px solid #E4E7EC',
        borderRadius: 6,
        background: active ? '#EFF6FF' : hov && !disabled ? '#F2F4F7' : '#fff',
        color:      active ? '#2563EB' : disabled ? '#D0D5DD' : '#344054',
        fontSize:   13,
        fontWeight: active ? 600 : 400,
        fontFamily: "'Inter', sans-serif",
        cursor:     disabled ? 'not-allowed' : 'pointer',
        transition: 'all 0.1s',
        lineHeight: 1,
      }}
    >
      {label}
    </button>
  );
}

/* Compute compact ellipsis page number list */
function pageNumbers(current, total) {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i);
  const pages = [0];
  if (current > 2) pages.push('...');
  for (let i = Math.max(1, current - 1); i <= Math.min(total - 2, current + 1); i++) {
    pages.push(i);
  }
  if (current < total - 3) pages.push('...');
  pages.push(total - 1);
  return pages;
}

/* ─── DataTable ──────────────────────────────────────────────────────── */

/**
 * Column definition shape:
 *   { header, accessorKey, cell: (info) => <JSX />, sortable, width }
 */
export default function DataTable({
  columns,
  data          = [],
  loading       = false,
  pagination:   showPagination = true,
  pageSize:     initPageSize   = 10,
  searchable    = false,
  searchPlaceholder = 'Search…',
  emptyMessage  = 'No records found',
  stickyHeader  = false,
}) {
  const [sorting,      setSorting]   = useState([]);
  const [globalFilter, setGlobalFilter] = useState('');
  const [paginState,   setPaginState]   = useState({
    pageIndex: 0,
    pageSize:  showPagination ? initPageSize : 100_000,
  });

  const debouncedFilter = useDebounce(globalFilter, 300);

  // Map custom `sortable` prop → TanStack `enableSorting`
  const mappedColumns = useMemo(() =>
    columns.map(col => ({ ...col, enableSorting: col.sortable ?? false })),
    [columns],
  );

  const table = useReactTable({
    data,
    columns:    mappedColumns,
    state:      { sorting, globalFilter: debouncedFilter, pagination: paginState },
    onSortingChange:       setSorting,
    onGlobalFilterChange:  setGlobalFilter,
    onPaginationChange:    setPaginState,
    getCoreRowModel:       getCoreRowModel(),
    getSortedRowModel:     getSortedRowModel(),
    getFilteredRowModel:   getFilteredRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
  });

  const { pageIndex, pageSize } = table.getState().pagination;
  const totalRows  = table.getFilteredRowModel().rows.length;
  const pageCount  = table.getPageCount();
  const rows       = table.getRowModel().rows;
  const startRow   = pageIndex * pageSize + 1;
  const endRow     = Math.min(startRow + pageSize - 1, totalRows);
  const colCount   = columns.length;

  return (
    <div style={{
      border:       '1px solid #EAECF0',
      borderRadius: 12,
      overflow:     'hidden',
      boxShadow:    '0 1px 3px rgba(16,24,40,.10), 0 1px 2px rgba(16,24,40,.06)',
      background:   '#fff',
      fontFamily:   "'Inter', sans-serif",
    }}>
      <style>{`
        @keyframes dt-shimmer {
          0%   { background-position:  200% 0; }
          100% { background-position: -200% 0; }
        }
      `}</style>

      {/* ── Search toolbar ── */}
      {searchable && (
        <div style={{
          display:       'flex',
          alignItems:    'center',
          padding:       '12px 16px',
          borderBottom:  '1px solid #EAECF0',
          background:    '#fff',
        }}>
          <div style={{ position: 'relative', width: 260 }}>
            <span style={{
              position:      'absolute',
              left:          10,
              top:           '50%',
              transform:     'translateY(-50%)',
              color:         '#98A2B3',
              pointerEvents: 'none',
              display:       'flex',
              alignItems:    'center',
            }}>
              <svg width="15" height="15" viewBox="0 0 15 15" fill="none">
                <circle cx="6.5" cy="6.5" r="4.5" stroke="currentColor" strokeWidth="1.5" />
                <line x1="10" y1="10" x2="13.5" y2="13.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
              </svg>
            </span>
            <input
              type="text"
              value={globalFilter}
              onChange={e => setGlobalFilter(e.target.value)}
              placeholder={searchPlaceholder}
              style={{
                width:        '100%',
                boxSizing:    'border-box',
                padding:      '7px 12px 7px 32px',
                fontSize:     13,
                border:       '1.5px solid #D0D5DD',
                borderRadius: 8,
                outline:      'none',
                color:        '#101828',
                background:   '#fff',
                fontFamily:   "'Inter', sans-serif",
                lineHeight:   1.5,
              }}
            />
          </div>
        </div>
      )}

      {/* ── Table scroll wrapper ── */}
      <div style={{ overflowX: 'auto', width: '100%' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 400 }}>

          {/* Header */}
          <thead style={{
            position:     stickyHeader ? 'sticky' : 'relative',
            top:          0,
            zIndex:       stickyHeader ? 2 : undefined,
            background:   '#F9FAFB',
            borderBottom: '1px solid #EAECF0',
          }}>
            {table.getHeaderGroups().map(hg => (
              <tr key={hg.id}>
                {hg.headers.map(header => {
                  const canSort = header.column.getCanSort();
                  const sortDir = header.column.getIsSorted();
                  return (
                    <th
                      key={header.id}
                      onClick={canSort ? header.column.getToggleSortingHandler() : undefined}
                      style={{
                        padding:       '10px 16px',
                        textAlign:     'left',
                        fontSize:      12,
                        fontWeight:    600,
                        color:         '#475467',
                        textTransform: 'uppercase',
                        letterSpacing: '0.05em',
                        cursor:        canSort ? 'pointer' : 'default',
                        userSelect:    'none',
                        whiteSpace:    'nowrap',
                        width:         header.column.columnDef.width,
                      }}
                    >
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                        {flexRender(header.column.columnDef.header, header.getContext())}
                        {canSort && <SortIcon dir={sortDir} />}
                      </span>
                    </th>
                  );
                })}
              </tr>
            ))}
          </thead>

          {/* Body */}
          <tbody>
            {loading ? (
              Array.from({ length: 5 }).map((_, i) => (
                <SkeletonRow key={i} colCount={colCount} />
              ))
            ) : rows.length === 0 ? (
              <tr>
                <td
                  colSpan={colCount}
                  style={{ padding: '48px 16px', textAlign: 'center', color: '#98A2B3', fontSize: 14 }}
                >
                  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
                    <span style={{ fontSize: 30 }}>📭</span>
                    <span>{emptyMessage}</span>
                  </div>
                </td>
              </tr>
            ) : (
              rows.map((row, idx) => (
                <tr
                  key={row.id}
                  style={{ background: idx % 2 === 1 ? '#F9FAFB' : '#fff', cursor: 'default' }}
                  onMouseEnter={e => { e.currentTarget.style.background = '#F5F7FA'; }}
                  onMouseLeave={e => { e.currentTarget.style.background = idx % 2 === 1 ? '#F9FAFB' : '#fff'; }}
                >
                  {row.getVisibleCells().map(cell => (
                    <td
                      key={cell.id}
                      style={{
                        padding:     '13px 16px',
                        fontSize:    14,
                        color:       '#101828',
                        borderBottom: '1px solid #F2F4F7',
                      }}
                    >
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* ── Pagination footer ── */}
      {showPagination && !loading && totalRows > 0 && (
        <div style={{
          display:        'flex',
          alignItems:     'center',
          justifyContent: 'space-between',
          padding:        '10px 16px',
          borderTop:      '1px solid #EAECF0',
          background:     '#fff',
          flexWrap:       'wrap',
          gap:            8,
        }}>
          <span style={{ fontSize: 13, color: '#475467' }}>
            Showing {startRow}–{endRow} of {totalRows}
          </span>

          <div style={{ display: 'flex', gap: 4, alignItems: 'center', flexWrap: 'wrap' }}>
            <PagBtn onClick={() => table.setPageIndex(0)}          disabled={!table.getCanPreviousPage()} label="«" />
            <PagBtn onClick={() => table.previousPage()}           disabled={!table.getCanPreviousPage()} label="‹" />

            {pageNumbers(pageIndex, pageCount).map((n, i) =>
              n === '...'
                ? <span key={`e${i}`} style={{ padding: '4px 4px', color: '#98A2B3', fontSize: 13 }}>…</span>
                : <PagBtn key={n} onClick={() => table.setPageIndex(n)} active={n === pageIndex} label={n + 1} />
            )}

            <PagBtn onClick={() => table.nextPage()}               disabled={!table.getCanNextPage()} label="›" />
            <PagBtn onClick={() => table.setPageIndex(pageCount - 1)} disabled={!table.getCanNextPage()} label="»" />
          </div>
        </div>
      )}
    </div>
  );
}
