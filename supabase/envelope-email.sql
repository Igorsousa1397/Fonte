-- Envelope virtual com verificação por e-mail (mesmo esquema da carteirinha).
-- A pessoa informa CPF + e-mail, recebe um código (Supabase Auth, OTP por e-mail) e só
-- com a sessão verificada vê e registra as contribuições daquele CPF.
--   * Membro: o e-mail tem que ser o do cadastro (membros.email).
--   * Quem não é membro: o primeiro e-mail verificado fica vinculado ao CPF; dali em
--     diante só esse e-mail abre o envelope daquele CPF.
-- Rodar uma vez no SQL Editor do Supabase, depois do carteirinha-email.sql.

-- vínculo CPF → e-mail de quem não é membro (só as funções abaixo leem/escrevem)
create table if not exists public.envelope_emails (
  cpf       text primary key,          -- só dígitos
  email     text not null,
  criado_em timestamptz not null default now()
);
alter table public.envelope_emails enable row level security;
-- sem policies: anon/authenticated não leem nem gravam direto

-- antes de mandar o código. Retorna: ok | sem_email | email_diferente
create or replace function public.envelope_confere_email(p_cpf text, p_email text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cpf   text := regexp_replace(coalesce(p_cpf, ''), '\D', '', 'g');
  v_email text := lower(trim(coalesce(p_email, '')));
  v_membro boolean;
  v_cad   text;
begin
  select true, email into v_membro, v_cad from membros
   where regexp_replace(cpf, '\D', '', 'g') = v_cpf limit 1;
  if v_membro then
    if v_cad is null then return 'sem_email'; end if;
    return case when lower(v_cad) = v_email then 'ok' else 'email_diferente' end;
  end if;
  select email into v_cad from envelope_emails where cpf = v_cpf;
  if v_cad is not null and v_cad <> v_email then return 'email_diferente'; end if;
  return 'ok';
end;
$$;
revoke all on function public.envelope_confere_email(text, text) from public;
grant execute on function public.envelope_confere_email(text, text) to anon, authenticated;

-- a sessão (e-mail verificado) pode mexer no envelope deste CPF? Vincula no primeiro uso.
create or replace function public.envelope_email_autorizado(p_cpf text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cpf   text := regexp_replace(coalesce(p_cpf, ''), '\D', '', 'g');
  v_email text := lower(auth.jwt() ->> 'email');
  v_membro boolean;
  v_cad   text;
begin
  if v_email is null or length(v_cpf) <> 11 then return false; end if;
  select true, email into v_membro, v_cad from membros
   where regexp_replace(cpf, '\D', '', 'g') = v_cpf limit 1;
  if v_membro then
    return v_cad is not null and lower(v_cad) = v_email;
  end if;
  insert into envelope_emails (cpf, email) values (v_cpf, v_email) on conflict (cpf) do nothing;
  select email into v_cad from envelope_emails where cpf = v_cpf;
  return v_cad = v_email;
end;
$$;
revoke all on function public.envelope_email_autorizado(text) from public, anon, authenticated;

create or replace function public.envelope_abrir_verificado(p_cpf text)
returns json
language plpgsql
security definer
set search_path = public
as $$
begin
  if not envelope_email_autorizado(p_cpf) then
    raise exception 'Verificação necessária';
  end if;
  return to_json(envelope_abrir(regexp_replace(p_cpf, '\D', '', 'g')));
end;
$$;
revoke all on function public.envelope_abrir_verificado(text) from public, anon;
grant execute on function public.envelope_abrir_verificado(text) to authenticated;

create or replace function public.contribuicao_declarar_verificado(
  p_cpf text, p_nome text, p_tipo text, p_competencia date, p_valor numeric, p_forma text, p_obs text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not envelope_email_autorizado(p_cpf) then
    raise exception 'Verificação necessária';
  end if;
  perform contribuicao_declarar(
    p_cpf => regexp_replace(p_cpf, '\D', '', 'g'), p_nome => p_nome, p_tipo => p_tipo,
    p_competencia => p_competencia, p_valor => p_valor, p_forma => p_forma, p_obs => p_obs);
end;
$$;
revoke all on function public.contribuicao_declarar_verificado(text, text, text, date, numeric, text, text) from public, anon;
grant execute on function public.contribuicao_declarar_verificado(text, text, text, date, numeric, text, text) to authenticated;

-- fecha o acesso direto às funções antigas (só as de cima usam elas agora)
do $$
declare f regprocedure;
begin
  for f in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname in ('envelope_abrir', 'contribuicao_declarar')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
  end loop;
end $$;
