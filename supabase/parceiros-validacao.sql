-- Acesso dos parceiros: login (ex.: parceiros@fonte.com) que no painel só vê "Membros":
-- busca por nome ou CPF e leitura do QR da carteirinha, para conferir se a pessoa é membro ativo.
-- As funções devolvem só nome, foto e situação (nada de CPF, telefone ou endereço).
--
-- Antes de rodar: crie o usuário em Supabase → Authentication → Users → Add user
-- (e-mail parceiros@fonte.com, senha à sua escolha, "Auto Confirm User" marcado).
-- Depois rode este arquivo no SQL Editor, depois de perfil-site.sql.

-- 1) papel "parceiro" para esse login
update public.profiles set role = 'parceiro'
where id = (select id from auth.users where lower(email) = 'parceiros@fonte.com');

-- 2) valida a carteirinha pelo código do QR (FONTE-XXXXXXXX ou o link inteiro do QR)
--    Devolve só o necessário para conferir a pessoa: nome curto, foto e se está ativo.
create or replace function public.parceiro_valida_membro(p_cod text)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  cod text;
  m record;
  partes text[];
begin
  if not tem_papel('admin', 'parceiro') then
    raise exception 'Sem permissão';
  end if;

  -- aceita "https://…/?membro=FONTE-1A2B3C4D", "FONTE-1A2B3C4D" ou só "1A2B3C4D"
  cod := upper(coalesce(p_cod, ''));
  cod := regexp_replace(cod, '^.*MEMBRO=', '');
  cod := regexp_replace(cod, '^FONTE-', '');
  cod := lower(substring(regexp_replace(cod, '[^0-9A-F]', '', 'g') from 1 for 8));
  if length(cod) <> 8 then
    return json_build_object('valido', false, 'motivo', 'Código inválido');
  end if;

  select id, nome, foto_url, ativo, validado, arquivado, membro_desde, created_at
    into m
    from membros
   where replace(id::text, '-', '') like cod || '%'
   limit 1;

  if not found then
    return json_build_object('valido', false, 'motivo', 'Carteirinha não encontrada');
  end if;

  partes := regexp_split_to_array(trim(coalesce(m.nome, '')), '\s+');

  return json_build_object(
    'valido', coalesce(m.ativo, true) and coalesce(m.validado, false) and not coalesce(m.arquivado, false),
    'motivo', case
                when coalesce(m.arquivado, false) or not coalesce(m.ativo, true) then 'Membro inativo'
                when not coalesce(m.validado, false) then 'Cadastro ainda não aprovado'
                else null end,
    'nome', case when array_length(partes, 1) > 1 then partes[1] || ' ' || partes[array_length(partes, 1)] else partes[1] end,
    'foto_url', m.foto_url,
    'codigo', 'FONTE-' || upper(cod),
    'membro_desde', coalesce(m.membro_desde::text, to_char(m.created_at, 'YYYY-MM'))
  );
end;
$$;
revoke all on function public.parceiro_valida_membro(text) from public, anon;
grant execute on function public.parceiro_valida_membro(text) to authenticated;

-- 3) busca por nome (mínimo 3 letras) ou CPF completo; no máximo 10 resultados
create or replace function public.parceiro_busca_membro(p_termo text)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  termo text := trim(coalesce(p_termo, ''));
  dig text := regexp_replace(coalesce(p_termo, ''), '\D', '', 'g');
begin
  if not tem_papel('admin', 'parceiro') then
    raise exception 'Sem permissão';
  end if;
  if length(dig) <> 11 and length(regexp_replace(termo, '[^[:alpha:]]', '', 'g')) < 3 then
    return '[]'::json;
  end if;

  return (
    select coalesce(json_agg(json_build_object(
      'nome', t.nome,
      'foto_url', t.foto_url,
      'codigo', 'FONTE-' || upper(substring(replace(t.id::text, '-', '') from 1 for 8)),
      'valido', coalesce(t.ativo, true) and coalesce(t.validado, false) and not coalesce(t.arquivado, false),
      'motivo', case
                  when coalesce(t.arquivado, false) or not coalesce(t.ativo, true) then 'Inativo'
                  when not coalesce(t.validado, false) then 'Cadastro não aprovado'
                  else null end
    ) order by t.nome), '[]'::json)
    from (
      select id, nome, foto_url, ativo, validado, arquivado
        from membros
       where (length(dig) = 11 and regexp_replace(coalesce(cpf, ''), '\D', '', 'g') = dig)
          or (length(dig) <> 11 and nome ilike '%' || termo || '%')
       order by nome
       limit 10
    ) t
  );
end;
$$;
revoke all on function public.parceiro_busca_membro(text) from public, anon;
grant execute on function public.parceiro_busca_membro(text) to authenticated;
