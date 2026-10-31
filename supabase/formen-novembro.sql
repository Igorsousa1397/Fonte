-- Culto de Homens For Men em 13/11: evento na agenda com a arte, aparece no carrossel do site em novembro.
-- Rodar uma vez no SQL Editor do Supabase.
update public.agenda
set tipo = 'culto', hora = '19h30', imagem_url = 'assets/banners/formen.jpg', ativo = true
where inicio = '2026-11-13' and titulo ilike '%homens%';

insert into public.agenda (titulo, tipo, inicio, hora, imagem_url, ativo)
select 'Culto de Homens · For Men', 'culto', '2026-11-13', '19h30', 'assets/banners/formen.jpg', true
where not exists (select 1 from public.agenda where inicio = '2026-11-13' and titulo ilike '%homens%');
