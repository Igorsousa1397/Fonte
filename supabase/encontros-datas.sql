-- Datas dos encontros editáveis pelo painel (tela Encontros).
-- Rodar uma vez no SQL Editor do Supabase, depois do encontros.sql.

alter table public.encontro_config add column if not exists inicio date;
alter table public.encontro_config add column if not exists fim    date;

-- datas atuais (as que estavam fixas no site)
update public.encontro_config set inicio = '2026-09-04', fim = '2026-09-06' where slug = 'submergidos' and inicio is null;
update public.encontro_config set inicio = '2026-11-20', fim = '2026-11-22' where slug = 'peniel'      and inicio is null;

-- escrita só pela RPC, e só para admin
create or replace function public.encontro_set_datas(p_slug text, p_inicio date, p_fim date)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Sem permissão';
  end if;
  if p_inicio is null then
    raise exception 'Informe a data de início';
  end if;
  if p_fim is not null and p_fim < p_inicio then
    raise exception 'A data final é antes da inicial';
  end if;
  insert into encontro_config (slug, inicio, fim, atualizado_em) values (p_slug, p_inicio, p_fim, now())
  on conflict (slug) do update set inicio = excluded.inicio, fim = excluded.fim, atualizado_em = now();
end;
$$;

revoke all on function public.encontro_set_datas(text, date, date) from public, anon;
grant execute on function public.encontro_set_datas(text, date, date) to authenticated;
