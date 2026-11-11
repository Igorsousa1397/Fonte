-- Página batismo.html: troca a foto pela nova (assets/banners/batismo-foto.jpg), mantendo data e hora.
-- A arte do carrossel (assets/banners/batismo.jpg) muda sozinha com o site, não precisa de SQL.
-- Rodar no SQL Editor do Supabase. Pode rodar mais de uma vez.
update public.site_config
set valor = jsonb_set(valor, '{imagem_url}', '"assets/banners/batismo-foto.jpg"'), atualizado_em = now()
where chave = 'batismo';
