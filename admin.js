const svgIcons = {
  home:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 10.5 12 4l8 6.5V20a1 1 0 0 1-1 1h-4.5v-6h-5v6H5a1 1 0 0 1-1-1v-9.5Z"/></svg>',
  user:'<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="8" r="3.2"/><path d="M5.5 20c.7-3.3 2.9-5 6.5-5s5.8 1.7 6.5 5"/></svg>',
  box:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m4 7 8-4 8 4-8 4-8-4Z"/><path d="M4 7v10l8 4 8-4V7M12 11v10"/></svg>',
  arrow:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 18 18 6M9 6h9v9"/></svg>',
  settings:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6 7 7M17 17l1.4 1.4M18.4 5.6 17 7M7 17l-1.4 1.4"/><circle cx="12" cy="12" r="4"/></svg>',
  check:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m5 12 4 4L19 6"/></svg>',
  star:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m12 3 2.1 5.7L20 11l-5.9 2.3L12 19l-2.1-5.7L4 11l5.9-2.3L12 3Z"/></svg>',
  spark:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v18M3 12h18M5.6 5.6l12.8 12.8M18.4 5.6 5.6 18.4"/></svg>',
  plus:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>',
  bell:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 10a6 6 0 0 1 12 0c0 5 2 5 2 7H4c0-2 2-2 2-7ZM10 20h4"/></svg>'
};
const iconReplace = (selector, icon) => document.querySelectorAll(selector).forEach(el => { el.innerHTML = svgIcons[icon]; el.classList.add('svg-ready'); });
iconReplace('.nav-item:nth-of-type(1) .nav-icon','home');
iconReplace('.nav-item:nth-of-type(2) .nav-icon','user');
iconReplace('.nav-item:nth-of-type(3) .nav-icon','box');
iconReplace('.nav-item:nth-of-type(4) .nav-icon','arrow');
iconReplace('.nav-item:nth-of-type(5) .nav-icon','user');
iconReplace('.nav-item:nth-of-type(6) .nav-icon','settings');
iconReplace('.notification','bell');
iconReplace('.metric-icon.purple','arrow'); iconReplace('.metric-icon.blue','user'); iconReplace('.metric-icon.pink','spark'); iconReplace('.metric-icon.green','check');
iconReplace('.rank-icon.purple-bg,.product-card-icon:not(.blue-icon):not(.pink-icon)','spark');
iconReplace('.rank-icon.blue-bg,.product-card-icon.blue-icon','user'); iconReplace('.rank-icon.pink-bg,.product-card-icon.pink-icon','box');
iconReplace('.role-symbol.purple-bg','star'); iconReplace('.role-symbol.blue-bg','user'); iconReplace('.role-symbol.pink-bg','check');
document.querySelectorAll('.page-header .primary-btn').forEach(btn => { btn.innerHTML = svgIcons.plus + btn.textContent.replace('＋',''); });

document.querySelectorAll('.page-header h1 span').forEach(el => { el.innerHTML = svgIcons.star; });

const navItems = document.querySelectorAll('.nav-item');
const pages = document.querySelectorAll('.page-section');
const breadcrumbText = document.getElementById('breadcrumbText');
const sidebar = document.getElementById('sidebar');
const overlay = document.getElementById('overlay');
const toast = document.getElementById('toast');
const modal = document.getElementById('modal');
const pageNames = { overview:'Overview', users:'User', products:'Produk', orders:'Pesanan', roles:'Role & akses', settings:'Pengaturan' };

function showPage(name){
  const page=pageNames[name]?name:'overview';
  pages.forEach(section=>section.classList.toggle('active',section.id===`page-${page}`));
  navItems.forEach(item=>item.classList.toggle('active',item.dataset.page===page));
  breadcrumbText.textContent=pageNames[page]; history.replaceState(null,'',`#${page}`);
  sidebar.classList.remove('open'); overlay.classList.remove('open');
}
navItems.forEach(item=>item.addEventListener('click',e=>{e.preventDefault();showPage(item.dataset.page)}));
document.querySelectorAll('a[href^="#"]').forEach(link=>link.addEventListener('click',e=>{const target=link.getAttribute('href').slice(1);if(pageNames[target]){e.preventDefault();showPage(target)}}));
showPage(location.hash.slice(1)||'overview');

document.getElementById('openSidebar')?.addEventListener('click',()=>{sidebar.classList.add('open');overlay.classList.add('open')});
document.getElementById('closeSidebar')?.addEventListener('click',()=>{sidebar.classList.remove('open');overlay.classList.remove('open')});
overlay.addEventListener('click',()=>{sidebar.classList.remove('open');overlay.classList.remove('open')});

const notificationButton=document.getElementById('notificationButton');
const notificationPopover=document.getElementById('notificationPopover');
notificationButton?.addEventListener('click',e=>{e.stopPropagation();notificationPopover.classList.toggle('open')});
document.addEventListener('click',e=>{if(!notificationPopover?.contains(e.target))notificationPopover?.classList.remove('open')});

function openModal(){modal.classList.add('open');modal.querySelector('input')?.focus()}
function closeModal(){modal.classList.remove('open')}
document.getElementById('quickAction')?.addEventListener('click',openModal);
document.getElementById('productAction')?.addEventListener('click',openModal);
document.getElementById('closeModal')?.addEventListener('click',closeModal);
document.getElementById('cancelModal')?.addEventListener('click',closeModal);
modal.addEventListener('click',e=>{if(e.target===modal)closeModal()});
function showToast(message='Perubahan berhasil disimpan ✓'){toast.textContent=message;toast.classList.add('show');setTimeout(()=>toast.classList.remove('show'),2600)}
document.getElementById('saveModal')?.addEventListener('click',()=>{closeModal();showToast('Produk baru berhasil ditambahkan ✓')});
document.querySelector('.settings-panel .primary-btn')?.addEventListener('click',()=>showToast());

// Live sync label keeps the dashboard feeling like a working workspace.
const syncTime=document.getElementById('syncTime');
setInterval(()=>{if(syncTime){const now=new Date();syncTime.textContent=`${now.getHours().toString().padStart(2,'0')}.${now.getMinutes().toString().padStart(2,'0')}`}},30000);

// Search across the currently visible management table.
document.querySelectorAll('.search-box input').forEach(input=>input.addEventListener('input',()=>{
  const query=input.value.toLowerCase().trim();
  const table=input.closest('.table-panel')?.querySelector('tbody');
  if(!table)return;
  table.querySelectorAll('tr').forEach(row=>row.style.display=row.textContent.toLowerCase().includes(query)?'':'none');
}));

// Lightweight dropdown filters for the management tables.
document.querySelectorAll('.filter-btn').forEach(button=>{
  button.addEventListener('click',e=>{
    e.stopPropagation();
    document.querySelectorAll('.filter-menu').forEach(menu=>menu.remove());
    const menu=document.createElement('div'); menu.className='filter-menu';
    const isRole=button.textContent.toLowerCase().includes('role');
    const options=isRole?['Semua role','Admin','User']:['Semua status','Aktif','Berhasil','Menunggu','Nonaktif'];
    options.forEach(option=>{const item=document.createElement('button');item.textContent=option;item.addEventListener('click',()=>{button.innerHTML=`${option}⌄`;button.classList.toggle('active-filter',!option.toLowerCase().startsWith('semua'));const table=button.closest('.table-panel')?.querySelector('tbody');if(table){table.querySelectorAll('tr').forEach(row=>row.style.display=option.toLowerCase().startsWith('semua')||row.textContent.toLowerCase().includes(option.toLowerCase())?'':'none')}menu.remove()});menu.appendChild(item)});
    button.style.position='relative';button.appendChild(menu);
  });
});
document.addEventListener('click',()=>document.querySelectorAll('.filter-menu').forEach(menu=>menu.remove()));

// Table rows open a compact detail view instead of being dead ends.
document.querySelectorAll('table tbody tr').forEach(row=>row.addEventListener('click',e=>{
  if(e.target.closest('button, a, select'))return;
  const first=row.querySelector('strong')?.textContent||'Detail pesanan';
  const title=first.startsWith('#SN')?first:(row.querySelector('.customer strong')?.textContent||first);
  const detail=document.createElement('div');detail.className='modal-backdrop open detail-modal';detail.innerHTML=`<div class="modal"><button class="modal-close">×</button><span class="eyebrow">Detail aktivitas</span><h2>${title}</h2><p>Informasi ringkas dari data workspace Starnova.</p><div class="modal-summary"><div><small>Produk / role</small><strong>${row.cells[1]?.textContent||'—'}</strong></div><div><small>Status</small><strong>${row.querySelector('.status')?.textContent||row.cells[4]?.textContent||'Aktif'}</strong></div><div><small>Tanggal</small><strong>${row.cells[row.cells.length-1]?.textContent||'Hari ini'}</strong></div><div><small>Nilai</small><strong>${row.querySelector('.amount')?.textContent||'—'}</strong></div></div><div class="modal-actions"><button class="primary-btn close-detail">Tutup</button></div></div>`;
  document.body.appendChild(detail);detail.querySelector('.modal-close').onclick=()=>detail.remove();detail.querySelector('.close-detail').onclick=()=>detail.remove();detail.onclick=ev=>{if(ev.target===detail)detail.remove()};
}));
