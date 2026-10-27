-- Perfil "site" (conteúdo do site): banners, encontros, agenda, células, ministérios e a
-- página de inscrição do batismo. Não vê membros, financeiro, ação social, contatos nem
-- a lista de inscritos do batismo.
-- Rodar uma vez no SQL Editor do Supabase, depois dos SQLs de banners, encontros,
-- células, agenda, site-config e ministérios.

-- 1) profiles.role: sem regra de valores permitidos. (Uma versão anterior deste arquivo
--    criava profiles_role_check, e isso quebrou a criação de usuários, porque a função que
--    monta o profile de cada usuário novo grava um papel fora da lista.)
alter table public.profiles drop constraint if exists profiles_role_check;

-- 2) atalho: a pessoa logada tem algum destes papéis?
create or replace function public.tem_papel(variadic p_papeis text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from profiles where id = auth.uid() and role = any(p_papeis));
$$;
revoke all on function public.tem_papel(text[]) from public, anon;
grant execute on function public.tem_papel(text[]) to authenticated;

-- 3) tabelas de conteúdo: admin e site editam
drop policy if exists banners_admin on public.banners;
create policy banners_admin on public.banners for all to authenticated
  using (tem_papel('admin', 'site')) with check (tem_papel('admin', 'site'));

drop policy if exists celulas_admin on public.celulas;
create policy celulas_admin on public.celulas for all to authenticated
  using (tem_papel('admin', 'site')) with check (tem_papel('admin', 'site'));

drop policy if exists agenda_admin on public.agenda;
create policy agenda_admin on public.agenda for all to authenticated
  using (tem_papel('admin', 'site')) with check (tem_papel('admin', 'site'));

drop policy if exists site_config_admin on public.site_config;
create policy site_config_admin on public.site_config for all to authenticated
  using (tem_papel('admin', 'site')) with check (tem_papel('admin', 'site'));

-- fotos (banners/agenda/batismo e células)
drop policy if exists banners_fotos_admin_insert on storage.objects;
create policy banners_fotos_admin_insert on storage.objects for insert to authenticated
  with check (bucket_id in ('banners', 'celulas') and public.tem_papel('admin', 'site'));
drop policy if exists banners_fotos_admin_update on storage.objects;
create policy banners_fotos_admin_update on storage.objects for update to authenticated
  using (bucket_id in ('banners', 'celulas') and public.tem_papel('admin', 'site'));
drop policy if exists banners_fotos_admin_delete on storage.objects;
create policy banners_fotos_admin_delete on storage.objects for delete to authenticated
  using (bucket_id in ('banners', 'celulas') and public.tem_papel('admin', 'site'));
drop policy if exists celulas_fotos_admin_insert on storage.objects;
drop policy if exists celulas_fotos_admin_delete on storage.objects;

-- 4) encontros: liga/desliga e datas
create or replace function public.encontro_set_ativo(p_slug text, p_ativo boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not tem_papel('admin', 'site') then raise exception 'Sem permissão'; end if;
  insert into encontro_config (slug, ativo, atualizado_em) values (p_slug, p_ativo, now())
  on conflict (slug) do update set ativo = excluded.ativo, atualizado_em = now();
end; $$;

create or replace function public.encontro_set_datas(p_slug text, p_inicio date, p_fim date)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not tem_papel('admin', 'site') then raise exception 'Sem permissão'; end if;
  if p_inicio is null then raise exception 'Informe a data de início'; end if;
  if p_fim is not null and p_fim < p_inicio then raise exception 'A data final é antes da inicial'; end if;
  insert into encontro_config (slug, inicio, fim, atualizado_em) values (p_slug, p_inicio, p_fim, now())
  on conflict (slug) do update set inicio = excluded.inicio, fim = excluded.fim, atualizado_em = now();
end; $$;

-- 5) ministérios: o perfil site vê tudo (liberação e inscrições) e cadastra/remove
drop policy if exists ministerio_config_site_select on public.ministerio_config;
create policy ministerio_config_site_select on public.ministerio_config for select to authenticated
  using (tem_papel('site'));
drop policy if exists ministerio_inscricoes_site_select on public.ministerio_inscricoes;
create policy ministerio_inscricoes_site_select on public.ministerio_inscricoes for select to authenticated
  using (tem_papel('site'));

drop function if exists public.ministerio_set_aberto(text, boolean);
create function public.ministerio_set_aberto(p_nome text, p_aberto boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not tem_papel('admin', 'ministerios', 'site') then raise exception 'Sem permissão'; end if;
  update ministerio_config set aberto = p_aberto where nome = p_nome;
  if not found then insert into ministerio_config (nome, aberto) values (p_nome, p_aberto); end if;
end; $$;
revoke all on function public.ministerio_set_aberto(text, boolean) from public, anon;
grant execute on function public.ministerio_set_aberto(text, boolean) to authenticated;

create or replace function public.ministerio_criar(p_nome text)
returns void language plpgsql security definer set search_path = public as $$
declare v_nome text := btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g'));
begin
  if not tem_papel('admin', 'ministerios', 'site') then raise exception 'Sem permissão'; end if;
  if length(v_nome) < 2 then raise exception 'Informe o nome do ministério'; end if;
  if exists (select 1 from ministerio_config where lower(nome) = lower(v_nome)) then
    raise exception 'Esse ministério já existe';
  end if;
  insert into ministerio_config (nome, aberto) values (v_nome, false);
end; $$;

create or replace function public.ministerio_remover(p_nome text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not tem_papel('admin', 'ministerios', 'site') then raise exception 'Sem permissão'; end if;
  delete from ministerio_config where nome = p_nome;
end; $$;

-- 6) para dar o perfil a uma pessoa: crie o usuário em Authentication → Users → Add user,
--    troque o e-mail abaixo e rode só este trecho.
-- insert into public.profiles (id, role)
-- select id, 'site' from auth.users where email = 'pessoa@exemplo.com'
-- on conflict (id) do update set role = 'site';
