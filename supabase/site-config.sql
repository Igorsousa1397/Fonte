-- Configurações simples do site editáveis pelo painel (chave → valor em JSON).
-- Primeiro uso: página de inscrição do Batismo (foto e data), chave 'batismo'.
-- Rodar uma vez no SQL Editor do Supabase. Fotos vão para a pasta pública "banners".

create table if not exists public.site_config (
  chave         text primary key,
  valor         jsonb not null default '{}'::jsonb,
  atualizado_em timestamptz not null default now()
);

alter table public.site_config enable row level security;

drop policy if exists site_config_select_publico on public.site_config;
create policy site_config_select_publico on public.site_config
  for select to anon, authenticated using (true);

drop policy if exists site_config_admin on public.site_config;
create policy site_config_admin on public.site_config
  for all to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- valores atuais da página de batismo
insert into public.site_config (chave, valor) values
  ('batismo', '{"data": "2026-09-27", "imagem_url": "assets/batismo.jpg"}')
on conflict (chave) do nothing;
