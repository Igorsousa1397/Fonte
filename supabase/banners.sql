-- Banners do topo do site (carrossel), editáveis pelo painel.
-- Enquanto não houver nenhum banner ativo, o site mostra os banners automáticos da agenda.
-- Rodar uma vez no SQL Editor do Supabase.

create table if not exists public.banners (
  id         uuid primary key default gen_random_uuid(),
  titulo     text not null,
  descricao  text,
  imagem_url text,
  data       date,                -- dia do evento (aparece na etiqueta e na contagem "faltam X dias")
  data_fim   date,                -- opcional: último dia, para eventos de vários dias
  link       text,                -- opcional: botão principal leva para cá
  cta        text,                -- opcional: texto do botão (padrão "Saiba mais")
  ativo      boolean not null default true,
  criado_em  timestamptz not null default now()
);

alter table public.banners enable row level security;

-- site: lê só os ativos
drop policy if exists banners_select_publico on public.banners;
create policy banners_select_publico on public.banners
  for select to anon, authenticated using (ativo);

-- painel: admin vê e altera tudo
drop policy if exists banners_admin on public.banners;
create policy banners_admin on public.banners
  for all to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- fotos dos banners (pasta pública no Storage)
insert into storage.buckets (id, name, public)
values ('banners', 'banners', true)
on conflict (id) do update set public = true;

drop policy if exists banners_fotos_admin_insert on storage.objects;
create policy banners_fotos_admin_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'banners'
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

drop policy if exists banners_fotos_admin_update on storage.objects;
create policy banners_fotos_admin_update on storage.objects
  for update to authenticated
  using (bucket_id = 'banners'
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

drop policy if exists banners_fotos_admin_delete on storage.objects;
create policy banners_fotos_admin_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'banners'
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));
