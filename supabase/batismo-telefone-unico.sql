-- Batismo: um telefone só pode ter uma inscrição.
-- Rodar uma vez no SQL Editor do Supabase.
-- Vale para qualquer forma de inserir (página, rpc criar_inscricao_batismo, painel).
-- Compara só os dígitos, sem o 55 do país: "(11) 90000-0000" = "+55 11 90000-0000".

create or replace function public.batismo_tel_normal(t text)
returns text language sql immutable as $$
  select case when length(d) > 11 and d like '55%' then substr(d, 3) else d end
  from (select regexp_replace(coalesce(t, ''), '\D', '', 'g') as d) x
$$;

create or replace function public.batismo_tel_unico()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  tel text := public.batismo_tel_normal(new.telefone);
begin
  if tel = '' then return new; end if;
  -- trava por telefone: duas inscrições iguais ao mesmo tempo não passam juntas
  perform pg_advisory_xact_lock(hashtext('batismo_tel:' || tel));
  if exists (
    select 1 from public.inscricoes_batismo i
    where public.batismo_tel_normal(i.telefone) = tel
      and i.id is distinct from new.id
  ) then
    raise exception 'Este telefone já tem inscrição no batismo.' using errcode = '23505';
  end if;
  return new;
end $$;

drop trigger if exists batismo_tel_unico on public.inscricoes_batismo;
create trigger batismo_tel_unico
  before insert or update of telefone on public.inscricoes_batismo
  for each row execute function public.batismo_tel_unico();

-- Conferir se já existem repetidos (o gatilho não apaga nada; só barra os novos):
-- select public.batismo_tel_normal(telefone) as tel, count(*), array_agg(nome order by created_at)
-- from public.inscricoes_batismo group by 1 having count(*) > 1;
