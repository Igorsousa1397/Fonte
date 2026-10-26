-- Liga/desliga dos encontros (cards "Os encontros do ano" no index.html).
-- Rodar uma vez no SQL Editor do Supabase.

create table if not exists public.encontro_config (
  slug          text primary key,          -- bate com o campo `id` do encontro no AGENDA do index.html
  ativo         boolean not null default true,
  atualizado_em timestamptz not null default now()
);

insert into public.encontro_config (slug, ativo) values
  ('submergidos', true),
  ('peniel', true)
on conflict (slug) do nothing;

alter table public.encontro_config enable row level security;

-- leitura pública (o site precisa saber quais estão ligados)
drop policy if exists encontro_config_select on public.encontro_config;
create policy encontro_config_select on public.encontro_config
  for select to anon, authenticated using (true);

-- escrita só pela RPC, e só para admin
create or replace function public.encontro_set_ativo(p_slug text, p_ativo boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Sem permissão';
  end if;
  insert into encontro_config (slug, ativo, atualizado_em) values (p_slug, p_ativo, now())
  on conflict (slug) do update set ativo = excluded.ativo, atualizado_em = now();
end;
$$;

revoke all on function public.encontro_set_ativo(text, boolean) from public, anon;
grant execute on function public.encontro_set_ativo(text, boolean) to authenticated;
