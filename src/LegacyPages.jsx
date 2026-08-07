import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from './auth/AuthContext';
import landingSource from '../legacy-landing.html?raw';
import adminSource from '../legacy-admin.html?raw';
import '../legacy-styles.css';
import '../legacy-admin.css';
import { supabase, isSupabaseConfigured } from './lib/supabase';

function bodyOf(source){ return source.replace(/<script[\s\S]*?<\/script>/gi,'').match(/<body[^>]*>([\s\S]*?)<\/body>/i)?.[1] || source; }
async function hydrateAdmin(root){
  if(!isSupabaseConfigured || !supabase) return;
  root.querySelectorAll('table tbody').forEach(body=>body.innerHTML='<tr><td colspan="6" class="empty-state">Memuat data live…</td></tr>');
  root.querySelectorAll('.metric-card strong').forEach(metric=>metric.textContent='—');
  const [{data:orders,error:ordersError},{data:users},{data:products}]=await Promise.all([
    supabase.from('purchases').select('id,user_id,product_id,product_name,amount,status,created_at,profiles(name,email),products(name,plan)').order('created_at',{ascending:false}),
    supabase.from('profiles').select('id,name,email,role,created_at').order('created_at',{ascending:false}),
    supabase.from('products').select('*').order('created_at',{ascending:true})
  ]);
  if(ordersError) return;
  const money=value=>new Intl.NumberFormat('id-ID',{style:'currency',currency:'IDR',maximumFractionDigits:0}).format(Number(value||0));
  const date=value=>new Intl.DateTimeFormat('id-ID',{day:'2-digit',month:'short',year:'numeric'}).format(new Date(value));
  const initials=value=>(value||'SN').split(' ').map(x=>x[0]).slice(0,2).join('').toUpperCase();
  const statusLabel={paid:'Berhasil',active:'Aktif',pending:'Menunggu',cancelled:'Dibatalkan'};
  const statusClass={paid:'success',active:'success',pending:'pending',cancelled:'pending'};
  const orderRows=(orders||[]).map(order=>{const person=order.profiles?.name||order.profiles?.email||'Pengguna';const product=order.products?`${order.products.name} — ${order.products.plan}`:order.product_name;return `<tr><td><div class="customer"><span class="customer-avatar a1">${initials(person)}</span><div><strong>${person}</strong><small>${order.profiles?.email||'—'}</small></div></div></td><td>${product}</td><td>${date(order.created_at)}</td><td><span class="status ${statusClass[order.status]||'pending'}">${statusLabel[order.status]||order.status}</span></td><td class="amount">${money(order.amount)}</td></tr>`}).join('');
  const overviewBody=root.querySelector('#page-overview table tbody'); if(overviewBody) overviewBody.innerHTML=orderRows||'<tr><td colspan="5" class="empty-state">Belum ada pesanan.</td></tr>';
  const ordersBody=root.querySelector('#page-orders table tbody'); if(ordersBody) ordersBody.innerHTML=(orders||[]).map(order=>{const person=order.profiles?.name||order.profiles?.email||'Pengguna';const product=order.products?`${order.products.name} — ${order.products.plan}`:order.product_name;return `<tr><td><strong class="invoice">#${order.id.slice(0,8).toUpperCase()}</strong></td><td>${person}</td><td>${product}</td><td><span class="status ${statusClass[order.status]||'pending'}">${statusLabel[order.status]||order.status}</span></td><td class="amount">${money(order.amount)}</td><td>${date(order.created_at)}</td></tr>`}).join('')||'<tr><td colspan="6" class="empty-state">Belum ada pesanan.</td></tr>';
  const usersBody=root.querySelector('#page-users table tbody'); if(usersBody) usersBody.innerHTML=(users||[]).map(user=>`<tr><td><div class="customer"><span class="customer-avatar a2">${initials(user.name||user.email)}</span><div><strong>${user.name||'Tanpa nama'}</strong><small>${user.email}</small></div></div></td><td><span class="role-tag user">${user.role}</span></td><td>${(orders||[]).filter(o=>o.user_id===user.id&&['paid','active'].includes(o.status)).length} produk</td><td>${date(user.created_at)}</td><td><span class="status success">Aktif</span></td><td class="row-more">•••</td></tr>`).join('')||'<tr><td colspan="6" class="empty-state">Belum ada user.</td></tr>';
  const metrics=root.querySelectorAll('.metric-card strong'); if(metrics.length>=4){metrics[0].textContent=money((orders||[]).filter(o=>['paid','active'].includes(o.status)).reduce((sum,o)=>sum+Number(o.amount||0),0));metrics[1].textContent=(users||[]).length;metrics[2].textContent=(orders||[]).length;metrics[3].textContent=(orders||[]).filter(o=>o.status==='active').length;}
  root.querySelectorAll('.admin-product-card').forEach((card,i)=>{const product=products?.[i];if(product){const title=card.querySelector('h2');const desc=card.querySelector('p');if(title)title.textContent=product.name;if(desc)desc.textContent=product.description||product.plan;}});
  root.querySelectorAll('table tbody tr').forEach(row=>row.addEventListener('click',()=>row.classList.add('selected-row')));
}

function RawPage({source,admin=false}){
  const navigate=useNavigate(); const {session}=useAuth(); const [html]=useState(()=>bodyOf(source));
  useEffect(()=>{
    const root=document.querySelector('.raw-page'); if(!root)return;
    if(admin) hydrateAdmin(root);
    const header=root.querySelector('.site-header');
    const onScroll=()=>header?.classList.toggle('scrolled',scrollY>12); window.addEventListener('scroll',onScroll,{passive:true});
    const observer=new IntersectionObserver(entries=>entries.forEach(e=>{if(e.isIntersecting){e.target.classList.add('visible');observer.unobserve(e.target)}}),{threshold:.12});
    root.querySelectorAll('.reveal').forEach(el=>observer.observe(el));
    const links=root.querySelectorAll('a[href*="wa.me"],a[href*="whatsapp"]');
    const guard=e=>{if(!session){e.preventDefault();navigate('/login?next=checkout')}}; links.forEach(l=>l.addEventListener('click',guard));
    const faqItems=root.querySelectorAll('.faq-list details');
    const faqHandlers=[];
    faqItems.forEach(item=>{const summary=item.querySelector('summary');const handler=e=>{e.preventDefault();if(item.open){item.classList.add('is-closing');setTimeout(()=>{item.open=false;item.classList.remove('is-closing')},380)}else{faqItems.forEach(other=>{if(other!==item){other.open=false;other.classList.remove('is-closing')}});item.open=true;item.classList.add('is-opening');requestAnimationFrame(()=>item.classList.remove('is-opening'))}};summary?.addEventListener('click',handler);faqHandlers.push([summary,handler])});
    const menuToggle=root.querySelector('.menu-toggle');
    const siteNav=root.querySelector('.nav');
    const toggleMenu=()=>{const open=siteNav?.classList.toggle('menu-open');menuToggle?.setAttribute('aria-expanded',String(Boolean(open)))};
    const delegatedMenuClick=e=>{if(e.target.closest?.('.menu-toggle')){e.preventDefault();e.stopPropagation();toggleMenu()}};
    root.addEventListener('click',delegatedMenuClick,true);
    const mobileLinks=siteNav?.querySelectorAll('.nav-links a')||[];
    mobileLinks.forEach(link=>link.addEventListener('click',()=>{siteNav?.classList.remove('menu-open');menuToggle?.setAttribute('aria-expanded','false')}));
    const openSidebar=root.querySelector('#openSidebar'); const closeSidebar=root.querySelector('#closeSidebar'); const overlay=root.querySelector('#overlay'); const sidebar=root.querySelector('#sidebar');
    const showSidebar=()=>{sidebar?.classList.add('open');overlay?.classList.add('open')};
    const hideSidebar=()=>{sidebar?.classList.remove('open');overlay?.classList.remove('open')};
    openSidebar?.addEventListener('click',showSidebar); closeSidebar?.addEventListener('click',hideSidebar); overlay?.addEventListener('click',hideSidebar);
    const navItems=admin?root.querySelectorAll('.nav-item[data-page]'):[];
    const adminClick=e=>{e.preventDefault();const name=e.currentTarget.dataset.page;root.querySelectorAll('.page-section').forEach(p=>p.classList.toggle('active',p.id===`page-${name}`));navItems.forEach(n=>n.classList.toggle('active',n===e.currentTarget));const crumb=root.querySelector('#breadcrumbText');if(crumb)crumb.textContent=e.currentTarget.textContent.trim();history.replaceState(null,'',`#${name}`)};
    navItems.forEach(n=>n.addEventListener('click',adminClick));
    return()=>{window.removeEventListener('scroll',onScroll);observer.disconnect();root.removeEventListener('click',delegatedMenuClick,true);links.forEach(l=>l.removeEventListener('click',guard));navItems.forEach(n=>n.removeEventListener('click',adminClick));faqHandlers.forEach(([summary,handler])=>summary?.removeEventListener('click',handler))};
  },[navigate,session]);
  return <div className={`raw-page ${admin?'raw-admin':''}`} dangerouslySetInnerHTML={{__html:html}}/>;
}
export function LegacyLanding(){return <RawPage source={landingSource}/>}
export function LegacyAdmin(){const {profile,loading}=useAuth();if(loading)return null;if(!profile||!['admin','owner'].includes(profile.role))return <RawPage source={landingSource}/>;return <RawPage source={adminSource} admin/>}
