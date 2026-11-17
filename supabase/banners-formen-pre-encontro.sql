-- 17/11/2026: arte nova do For Men (01/12) e banner do Pré-Encontro (quinta, 19/11).
-- Rodar no SQL Editor do Supabase. Pode rodar mais de uma vez.

-- 1) For Men: troca a arte e o texto do banner que já existe
update public.banners
set imagem_url = 'assets/banners/formen.jpg', data = '2026-12-01',
    descricao = 'Culto de homens For Men: preparando o altar para 2027. Terça, 1º de dezembro, às 19h30. Traga os homens da sua casa e da sua célula.'
where titulo = 'Culto For Men';

-- 2) For Men na agenda (01/12)
insert into public.agenda (titulo, tipo, inicio, hora, imagem_url, ativo)
select 'Culto de Homens · For Men', 'culto', '2026-12-01', '19h30', 'assets/banners/formen.jpg', true
where not exists (select 1 from public.agenda where titulo = 'Culto de Homens · For Men' and inicio = '2026-12-01');

-- 3) Pré-Encontro: banner novo; sai sozinho do carrossel depois do dia 19/11
insert into public.banners (titulo, descricao, imagem_url, data, ativo)
select 'Pré-Encontro', 'Atenção, encontristas: pré-encontro na igreja com as instruções sobre o encontro. Quinta, 19/11, às 20h. A sua participação é extremamente importante.',
       'assets/banners/pre-encontro.jpg', '2026-11-19', true
where not exists (select 1 from public.banners where imagem_url = 'assets/banners/pre-encontro.jpg');

-- 4) Pré-Encontro na agenda (o botão do banner leva para lá)
insert into public.agenda (titulo, tipo, inicio, hora, ativo)
select 'Pré-Encontro', 'evento', '2026-11-19', '20h', true
where not exists (select 1 from public.agenda where titulo = 'Pré-Encontro' and inicio = '2026-11-19');
