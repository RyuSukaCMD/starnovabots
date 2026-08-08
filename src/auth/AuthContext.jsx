import { createContext, useContext, useEffect, useState } from 'react';
import { supabase, isSupabaseConfigured } from '../lib/supabase';

const AuthContext = createContext(null);
export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    if (!isSupabaseConfigured) { setLoading(false); return; }
    supabase.auth.getSession().then(({ data }) => { setSession(data.session); if (data.session) loadProfile(data.session.user.id); else setLoading(false); });
    const { data: listener } = supabase.auth.onAuthStateChange((_event, next) => { setSession(next); if (next) loadProfile(next.user.id); else { setProfile(null); setLoading(false); } });
    return () => listener.subscription.unsubscribe();
  }, []);
  async function loadProfile(id) { const { data } = await supabase.from('profiles').select('*').eq('id', id).single(); setProfile(data); setLoading(false); }
  async function signIn(email, password) { if (!supabase) throw new Error('Supabase belum dikonfigurasi. Isi file .env terlebih dahulu.'); const { error } = await supabase.auth.signInWithPassword({ email, password }); if (error) throw error; }
  async function signUp(email, password, name) { if (!supabase) throw new Error('Supabase belum dikonfigurasi.'); const { error } = await supabase.auth.signUp({ email, password, options: { data: { name } } }); if (error) throw error; }
  async function signInWithOtp(email, name='') { if (!supabase) throw new Error('Supabase belum dikonfigurasi.'); const options = { shouldCreateUser: true }; if (name) options.data = { name }; const { error } = await supabase.auth.signInWithOtp({ email, options }); if (error) throw error; }
  async function verifyOtp(email, token) { if (!supabase) throw new Error('Supabase belum dikonfigurasi.'); const { error } = await supabase.auth.verifyOtp({ email, token, type: 'email' }); if (error) throw error; }
  async function signInWithGoogle() { if (!supabase) throw new Error('Supabase belum dikonfigurasi.'); const { error } = await supabase.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: window.location.origin + '/login' } }); if (error) throw error; }
  async function checkUsername(username) { if (!supabase || !session?.user) return false; const { data, error } = await supabase.rpc('is_username_available', { candidate: username, requesting_user: session.user.id }); if (error) throw error; return Boolean(data); }
  async function updateUsername(username) { const normalized = username.trim().toLowerCase(); if (!/^[a-z0-9_]{3,24}$/.test(normalized)) throw new Error('Username harus 3–24 karakter: huruf kecil, angka, atau underscore.'); if (!supabase || !session?.user) throw new Error('Supabase belum dikonfigurasi.'); const available = await checkUsername(normalized); if (!available) throw new Error('Username sudah digunakan.'); return updateProfileFields({ username: normalized, name: normalized, display_name: normalized }); }
  async function updateProfileFields(fields) { if (!supabase || !session?.user) throw new Error('Supabase belum dikonfigurasi.'); let result = await supabase.from('profiles').update({ ...fields, updated_at: new Date().toISOString() }).eq('id', session.user.id).select('*').single(); if (result.error && /column|schema cache|display_name|avatar|updated_at/i.test(result.error.message||'')) { result = await supabase.from('profiles').update({ name: fields.display_name || fields.name || fields.username }).eq('id', session.user.id).select('*').single(); } if (result.error) throw result.error; setProfile(result.data); return result.data; }
  async function signOut() { await supabase?.auth.signOut(); }
  return <AuthContext.Provider value={{ session, profile, loading, signIn, signUp, signInWithOtp, verifyOtp, signInWithGoogle, checkUsername, updateUsername, updateProfileFields, signOut, configured: isSupabaseConfigured }}>{children}</AuthContext.Provider>;
}
export const useAuth = () => useContext(AuthContext);
