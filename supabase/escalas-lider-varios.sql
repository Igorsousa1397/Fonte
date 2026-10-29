-- Escalas: um líder pode cuidar de mais de um ministério
-- (ex.: Voluntários, Obreiros e Estacionamento com o mesmo líder).
-- Rodar uma vez no SQL Editor do Supabase, depois do escalas.sql.

-- 1) lista de ministérios do líder (a coluna antiga "ministerio" vira o primeiro da lista)
alter table public.profiles add column if not exists ministerios text[];
update public.profiles set ministerios = array[ministerio]
where role = 'lider_ministerio' and ministerio is not null and ministerios is null;

-- 2) pode mexer na escala deste ministério? (admin: todos; líder: os da lista dele)
create or replace function public.pode_escala(p_ministerio text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select tem_papel('admin') or exists (
    select 1 from profiles
    where id = auth.uid() and role = 'lider_ministerio' and p_ministerio = any(ministerios)
  );
$$;

-- 3) para dar o perfil a um líder: crie o usuário em Authentication → Users → Add user,
--    troque o e-mail e os ministérios (escritos iguais aos da lista) e rode só este trecho.
-- insert into public.profiles (id, role, ministerios)
-- select id, 'lider_ministerio', array['Voluntários', 'Obreiros', 'Estacionamento']
-- from auth.users where email = 'lider@exemplo.com'
-- on conflict (id) do update set role = 'lider_ministerio', ministerios = excluded.ministerios;
