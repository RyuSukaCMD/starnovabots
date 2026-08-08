export const demoProducts = [
  { id:'private-bot', name:'Private Bot', description:'WhatsApp Bot untuk grup dengan maksimal 6 member.', category:'Sewa Bot', type:'rental', icon:'bot', plans:[{duration:30,price:25000},{duration:90,price:65000},{duration:180,price:110000},{duration:365,price:190000}], stock:null, status:'active', details:'Maks. 6 member per group, tidak termasuk bot.' },
  { id:'public-bot', name:'Public Bot', description:'WhatsApp Bot untuk grup tanpa batas jumlah member.', category:'Sewa Bot', type:'rental', icon:'public', plans:[{duration:30,price:45000},{duration:90,price:120000},{duration:180,price:210000},{duration:365,price:380000}], stock:null, status:'active', details:'Tanpa batas jumlah member.' },
  { id:'jadi-bot', name:'Jadi Bot', description:'Jalankan bot menggunakan nomor WhatsApp milikmu.', category:'Layanan', type:'bot', icon:'phone', price:99000, duration:null, stock:null, status:'active', details:'Nomor utama tetap milikmu.' },
  { id:'script', name:'Beli Script', description:'Source code bot, License Key, dan dokumentasi aktivasi.', category:'Script', type:'script', icon:'code', price:899000, duration:null, stock:20, status:'active', details:'Script + License Key + dokumentasi.' }
];
export const money = value => new Intl.NumberFormat('id-ID',{style:'currency',currency:'IDR',maximumFractionDigits:0}).format(value||0);
export const getPrice = product => product.type==='rental' ? product.plans?.[0]?.price || 0 : product.price || 0;
export const getDemoProducts = () => { try { const saved=localStorage.getItem('starnova_products'); return saved?JSON.parse(saved):demoProducts; } catch { return demoProducts; } };
export const saveDemoProducts = products => localStorage.setItem('starnova_products',JSON.stringify(products));
