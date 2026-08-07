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
  async function updateProfileName(name) { if (!supabase || !session?.user) throw new Error('Supabase belum dikonfigurasi.'); const { data, error } = await supabase.from('profiles').update({ name }).eq('id', session.user.id).select('*').single(); if (error) throw error; setProfile(data); return data; }
  async function signOut() { await supabase?.auth.signOut(); }
  return <AuthContext.Provider value={{ session, profile, loading, signIn, signUp, signInWithOtp, verifyOtp, signInWithGoogle, updateProfileName, signOut, configured: isSupabaseConfigured }}>{children}</AuthContext.Provider>;
}
export const useAuth = () => useContext(AuthContext);
