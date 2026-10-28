-- "Líder de ministério": nova opção de ministério que libera a carteirinha sem célula.
-- Rodar uma vez no SQL Editor do Supabase (depois de membros-filtros.sql e ministerios.sql).

-- 1) a opção aparece no painel, no "Seja membro" e no "Quero servir"
insert into public.ministerio_config (nome, aberto)
select 'Líder de ministério', false
where not exists (select 1 from public.ministerio_config where nome = 'Líder de ministério');

-- 2) validar (liberar a carteirinha) exige célula, exceto para Líder de ministério
create or replace function public.membros_regras()
returns trigger
language plpgsql
as $$
begin
  if new.validado is true and coalesce(old.validado, false) is false
     and not tem_celula(new.celula)
     and coalesce(btrim(new.ministerio), '') <> 'Líder de ministério' then
    raise exception 'Para validar, o membro precisa fazer parte de uma célula ou ser Líder de ministério.';
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
