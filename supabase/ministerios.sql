-- Ministérios cadastráveis pelo painel (tela Ministérios).
-- A lista passa a viver em ministerio_config (uma linha por ministério); o painel,
-- o "Quero servir" e o "Seja membro" leem daqui. Inscrições antigas não mudam.
-- Rodar uma vez no SQL Editor do Supabase.

-- garante uma linha para cada ministério que estava fixo no código
insert into public.ministerio_config (nome, aberto)
select m, false
from unnest(array[
  'Ação Social','Boas-vindas','Dança','Dorcas','Estacionamento','Fonte Coffee','Fonte Store',
  'Intercessão','Líder de célula','Louvor','Mídia Social','Mídia Técnica','Ministério Baby',
  'Ministério Kids','Ministério Juniores','Ministério Teens','Obreiros','Voluntários'
]) as m
where not exists (select 1 from public.ministerio_config c where c.nome = m);

-- lista pública (só nomes), para os formulários do site
create or replace function public.ministerios_lista()
returns setof text
language sql
stable
security definer
set search_path = public
as $$
  select nome from ministerio_config order by nome collate "C";
$$;
revoke all on function public.ministerios_lista() from public;
grant execute on function public.ministerios_lista() to anon, authenticated;

-- cadastrar (admin): entra fechado; abre pela chave no painel
create or replace function public.ministerio_criar(p_nome text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_nome text := btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g'));
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Sem permissão';
  end if;
  if length(v_nome) < 2 then raise exception 'Informe o nome do ministério'; end if;
  if exists (select 1 from ministerio_config where lower(nome) = lower(v_nome)) then
    raise exception 'Esse ministério já existe';
  end if;
  insert into ministerio_config (nome, aberto) values (v_nome, false);
end;
$$;
revoke all on function public.ministerio_criar(text) from public, anon;
grant execute on function public.ministerio_criar(text) to authenticated;

-- remover (admin): sai da lista e do "Quero servir"; inscrições já feitas continuam
create or replace function public.ministerio_remover(p_nome text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Sem permissão';
  end if;
  delete from ministerio_config where nome = p_nome;
end;
$$;
revoke all on function public.ministerio_remover(text) from public, anon;
grant execute on function public.ministerio_remover(text) to authenticated;
