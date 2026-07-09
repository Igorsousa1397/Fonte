// Config do Supabase — chave anon é pública (protegida por RLS no banco).
// Requer que @supabase/supabase-js já esteja carregado (CDN) antes deste arquivo.
const SUPABASE_URL  = 'https://iheracfrwyswhfxqrfrs.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImloZXJhY2Zyd3lzd2hmeHFyZnJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM1ODY5NTksImV4cCI6MjA5OTE2Mjk1OX0.xqsyWHDSsfy5N9XIWhEO7vxCmtd9sRhAR-r95wkoGVs';
const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON);
