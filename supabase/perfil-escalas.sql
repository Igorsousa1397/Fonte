-- Perfil "escalas": só a tela Ministérios → Escalas, com todos os ministérios que têm escala.
-- Não vê membros, financeiro, inscrições nem o resto do painel, e não liga/desliga
-- quais ministérios têm escala (isso continua só com o admin).
-- Rodar uma vez no SQL Editor do Supabase, depois do escalas.sql.

-- 1) quem pode mexer na escala: admin e escalas (todos), líder (os ministérios dele)
alter table public.profiles add column if not exists ministerios text[];
update public.profiles set ministerios = array[ministerio]
where role = 'lider_ministerio' and ministerio is not null and ministerios is null;

create or replace function public.pode_escala(p_ministerio text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select tem_papel('admin', 'escalas') or exists (
    select 1 from profiles
    where id = auth.uid() and role = 'lider_ministerio' and p_ministerio = any(ministerios)
  );
$$;

-- 2) a lista de ministérios (para escolher qual escala montar)
drop policy if exists ministerio_config_escalas_select on public.ministerio_config;
create policy ministerio_config_escalas_select on public.ministerio_config for select to authenticated
  using (tem_papel('escalas'));

-- 3) para dar o perfil a uma pessoa: crie o usuário em Authentication → Users → Add user,
--    troque o e-mail abaixo e rode só este trecho.
-- insert into public.profiles (id, role)
-- select id, 'escalas' from auth.users where email = 'pessoa@exemplo.com'
-- on conflict (id) do update set role = 'escalas';
