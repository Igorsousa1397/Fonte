-- Banners com as artes dos avisos do culto (imagens em assets/banners/).
-- Rodar uma vez no SQL Editor do Supabase, depois de subir as imagens.

-- Quarta Profética e Domingo em Família: arte nova (o Domingo volta a aparecer)
insert into public.banners (auto, titulo, descricao, imagem_url, ativo) values
  ('quarta',  'Quarta Profética',
              'Toda quarta tem palavra profética pra sua semana. Culto às 20h.',
              'assets/banners/quarta.jpg', true),
  ('domingo', 'Domingo em Família',
              'Nosso culto de domingo em família, às 10h e 18h30. Traga todo mundo pra adorar com a Fonte.',
              'assets/banners/domingo.jpg', true)
on conflict (auto) do update set imagem_url = excluded.imagem_url, ativo = true;

-- Célula: aviso fixo, sem data
insert into public.banners (titulo, descricao, imagem_url, link, cta, ativo)
select 'Célula toda sexta',
       'Toda sexta tem célula: louvor, palavra e comunhão perto da sua casa. Encontre a sua.',
       'assets/banners/celula.jpg', '#celulas', 'Encontrar uma célula', true
where not exists (select 1 from public.banners where imagem_url = 'assets/banners/celula.jpg');

-- Cantina: hambúrguer da Beraká em 01/11 (sai do site sozinho depois da data)
insert into public.banners (titulo, descricao, imagem_url, data, ativo)
select 'Hambúrguer artesanal da Beraká',
       'Cantina Fonte: hambúrguer artesanal por R$ 25, nos cultos da manhã e da noite. A venda é da Célula Beraká.',
       'assets/banners/hamburguer-beraka.jpg', '2026-11-01', true
where not exists (select 1 from public.banners where imagem_url = 'assets/banners/hamburguer-beraka.jpg');
