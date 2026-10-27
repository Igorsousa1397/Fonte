-- Carteirinha com verificação por e-mail.
-- O membro informa CPF + e-mail cadastrado, recebe um código (Supabase Auth, OTP por e-mail)
-- e só com a sessão verificada consegue ler a carteirinha.
-- Rodar uma vez no SQL Editor do Supabase.

-- 1) e-mail no cadastro do membro
alter table public.membros add column if not exists email text;
create index if not exists membros_email_lower_idx on public.membros (lower(email));

-- 2) cadastro público ("Seja membro") grava o e-mail logo depois do criar_membro.
--    Só preenche se ainda estiver vazio e o cadastro tiver acabado de ser criado,
--    pra ninguém trocar o e-mail de um membro existente e pegar a carteirinha dele.
create or replace function public.membro_set_email(p_cpf text, p_email text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_email is null or p_email !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'E-mail inválido';
  end if;
  update membros
     set email = lower(trim(p_email))
   where regexp_replace(cpf, '\D', '', 'g') = regexp_replace(p_cpf, '\D', '', 'g')
     and email is null
     and created_at > now() - interval '30 minutes';
end;
$$;
revoke all on function public.membro_set_email(text, text) from public;
grant execute on function public.membro_set_email(text, text) to anon, authenticated;

-- 3) antes de mandar o código: o CPF existe, está liberado e o e-mail bate?
--    Retorna: ok | sem_email | email_diferente | analise | inativo | nao_encontrado
create or replace function public.membro_confere_email(p_cpf text, p_email text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_email  text;
begin
  select status into v_status from membro_carteirinha(p_cpf) limit 1;
  if v_status is distinct from 'ok' then
    return coalesce(v_status, 'nao_encontrado');
  end if;
  select email into v_email from membros
   where regexp_replace(cpf, '\D', '', 'g') = regexp_replace(p_cpf, '\D', '', 'g')
   limit 1;
  if v_email is null then return 'sem_email'; end if;
  if lower(v_email) <> lower(trim(coalesce(p_email, ''))) then return 'email_diferente'; end if;
  return 'ok';
end;
$$;
revoke all on function public.membro_confere_email(text, text) from public;
grant execute on function public.membro_confere_email(text, text) to anon, authenticated;

-- 4) carteirinha só para quem verificou o e-mail do próprio cadastro
create or replace function public.membro_carteirinha_verificada(p_cpf text)
returns json
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from membros
     where regexp_replace(cpf, '\D', '', 'g') = regexp_replace(p_cpf, '\D', '', 'g')
       and email is not null
       and lower(email) = lower(auth.jwt() ->> 'email')
  ) then
    raise exception 'Verificação necessária';
  end if;
  return (select coalesce(json_agg(t), '[]'::json) from membro_carteirinha(p_cpf) t);
end;
$$;
revoke all on function public.membro_carteirinha_verificada(text) from public, anon;
grant execute on function public.membro_carteirinha_verificada(text) to authenticated;

-- 5) fecha o acesso direto à função antiga (só as funções acima usam ela agora)
revoke execute on function public.membro_carteirinha(text) from public, anon, authenticated;
