-- Escalas dos ministérios: o líder de cada ministério monta a escala do mês no painel
-- (Ministérios → Escalas), escolhendo entre os membros do ministério dele.
-- Rodar uma vez no SQL Editor do Supabase, depois de perfil-site.sql e ministerios.sql.

-- 1) o perfil "lider_ministerio" fica preso a um ministério
alter table public.profiles add column if not exists ministerio text;

-- ministério da pessoa logada, se ela for líder de ministério
create or replace function public.meu_ministerio()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select ministerio from profiles where id = auth.uid() and role = 'lider_ministerio';
$$;
revoke all on function public.meu_ministerio() from public, anon;
grant execute on function public.meu_ministerio() to authenticated;

-- pode mexer na escala deste ministério? (admin: todos; líder: só o dele)
create or replace function public.pode_escala(p_ministerio text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select tem_papel('admin') or (p_ministerio is not null and p_ministerio = meu_ministerio());
$$;
revoke all on function public.pode_escala(text) from public, anon;
grant execute on function public.pode_escala(text) to authenticated;

-- 2) nem todo ministério tem escala: o admin liga em Ministérios → Escalas
alter table public.ministerio_config add column if not exists escala boolean not null default false;
-- começa ligada em todos, menos nos que não usam escala (dá para mudar depois no painel)
update public.ministerio_config set escala = nome not in
  ('Ação Social', 'Fonte Coffee', 'Fonte Store', 'Líder de célula', 'Líder de ministério');

create or replace function public.ministerio_set_escala(p_nome text, p_escala boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not tem_papel('admin') then raise exception 'Sem permissão'; end if;
  update ministerio_config set escala = p_escala where nome = p_nome;
end;
$$;
revoke all on function public.ministerio_set_escala(text, boolean) from public, anon;
grant execute on function public.ministerio_set_escala(text, boolean) to authenticated;

-- 3) escala: uma linha por pessoa escalada em um culto
create table if not exists public.escalas (
  id         uuid primary key default gen_random_uuid(),
  ministerio text not null,
  data       date not null,
  hora       text not null default '',      -- '10h', '18h30', '20h'… (vazio = dia todo)
  titulo     text not null default '',      -- 'Culto da Família', 'Quarta Profética', evento extra…
  membro_id  uuid not null references public.membros(id) on delete cascade,
  funcao     text,                          -- opcional: Vocal, Bateria, Recepção…
  criado_em  timestamptz not null default now()
);
create index if not exists escalas_min_data_idx on public.escalas (ministerio, data);

alter table public.escalas enable row level security;
drop policy if exists escalas_lider on public.escalas;
create policy escalas_lider on public.escalas for all to authenticated
  using (pode_escala(ministerio)) with check (pode_escala(ministerio));

-- 4) membros do ministério (só o que a escala precisa: nome e telefone)
create or replace function public.escala_membros(p_ministerio text)
returns table (id uuid, nome text, telefone text)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not pode_escala(p_ministerio) then raise exception 'Sem permissão'; end if;
  return query
    select m.id, m.nome, m.telefone from membros m
    where m.ministerio = p_ministerio and m.ativo is not false and m.arquivado is not true
    order by m.nome;
end;
$$;
revoke all on function public.escala_membros(text) from public, anon;
grant execute on function public.escala_membros(text) to authenticated;

-- 5) o líder vê a lista de ministérios (para o nome aparecer certo no painel)
drop policy if exists ministerio_config_lider_select on public.ministerio_config;
create policy ministerio_config_lider_select on public.ministerio_config for select to authenticated
  using (tem_papel('lider_ministerio'));

-- 6) (líder de vários ministérios: rode também escalas-lider-varios.sql e use o exemplo de lá)
--    para dar o perfil a um líder: crie o usuário em Authentication → Users → Add user,
--    troque o e-mail e o ministério (escrito igual ao da lista) e rode só este trecho.
-- insert into public.profiles (id, role, ministerio)
-- select id, 'lider_ministerio', 'Louvor' from auth.users where email = 'lider@exemplo.com'
-- on conflict (id) do update set role = 'lider_ministerio', ministerio = excluded.ministerio;
