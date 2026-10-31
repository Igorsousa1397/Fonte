-- Batismo de 29/11 (último domingo do mês): arte nova na página de batismo e no carrossel do site.
-- Rodar uma vez no SQL Editor do Supabase.

-- 1) página batismo.html: foto e data
insert into public.site_config (chave, valor)
values ('batismo', '{"data": "2026-11-29", "imagem_url": "assets/banners/batismo.jpg"}'::jsonb)
on conflict (chave) do update set valor = excluded.valor;

-- 2) agenda + carrossel: evento com arte e botão de inscrição
--    (o carrossel mostra os eventos com arte do mês atual, então ele entra a partir de 01/11)
update public.agenda
set tipo = 'marco', destaque = true, imagem_url = 'assets/banners/batismo.jpg',
    link = 'batismo.html', cta = 'Inscrever-se', ativo = true
where titulo = 'Batismo' and inicio = '2026-11-29';

insert into public.agenda (titulo, tipo, inicio, destaque, imagem_url, link, cta, ativo)
select 'Batismo', 'marco', '2026-11-29', true, 'assets/banners/batismo.jpg', 'batismo.html', 'Inscrever-se', true
where not exists (select 1 from public.agenda where titulo = 'Batismo' and inicio = '2026-11-29');
