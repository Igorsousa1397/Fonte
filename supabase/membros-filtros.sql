-- Membros: arquivar inativos e só validar (liberar a carteirinha) quem faz parte de uma célula.
-- Rodar no SQL Editor do Supabase ANTES de subir o painel novo: o painel passa a ler a
-- coluna "arquivado", e sem ela a lista de membros não carrega.

alter table public.membros add column if not exists arquivado boolean not null default false;

-- célula "de verdade": não vazia e não uma das respostas de "não participo"
create or replace function public.tem_celula(p_celula text)
returns boolean
language sql
immutable
as $$
  select coalesce(btrim(p_celula), '') <> ''
     and lower(btrim(p_celula)) not in (
       'ainda não participo', 'não participo de célula', 'não pertenço a nenhuma célula',
       'nao participo', 'não participo', 'sem célula'
     );
$$;

create or replace function public.membros_regras()
returns trigger
language plpgsql
as $$
begin
  -- validar dados = liberar a carteirinha: exige célula
  if new.validado is true and coalesce(old.validado, false) is false and not tem_celula(new.celula) then
    raise exception 'Para validar, o membro precisa fazer parte de uma célula.';
  end if;
  -- só arquiva quem está inativo; reativar tira do arquivo
  if new.ativo is not false and old.ativo is false then
    new.arquivado := false;
  end if;
  if new.arquivado is true and new.ativo is not false then
    raise exception 'Só é possível arquivar um membro inativo.';
  end if;
  return new;
end;
$$;

drop trigger if exists membros_regras on public.membros;
create trigger membros_regras
  before update on public.membros
  for each row execute function public.membros_regras();
