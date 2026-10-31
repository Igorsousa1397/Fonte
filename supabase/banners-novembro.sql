-- Banners de novembro na aba Banners do painel: For Men (13/11) e Batismo (29/11).
-- Cada um sai do site sozinho depois da data. Rodar uma vez no SQL Editor do Supabase.
insert into public.banners (titulo, descricao, imagem_url, data, ativo)
select 'Culto de Homens · For Men',
       'Culto de homens For Men, sexta às 19h30. Traga os homens da sua casa e da sua célula.',
       'assets/banners/formen.jpg', '2026-11-13', true
where not exists (select 1 from public.banners where imagem_url = 'assets/banners/formen.jpg');

insert into public.banners (titulo, descricao, imagem_url, data, link, cta, ativo)
select 'Batismo',
       'No último domingo do mês tem batismo. Deixe o velho para trás e nasça para uma nova vida com Cristo.',
       'assets/banners/batismo.jpg', '2026-11-29', 'batismo.html', 'Inscrever-se', true
where not exists (select 1 from public.banners where imagem_url = 'assets/banners/batismo.jpg');
