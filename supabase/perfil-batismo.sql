-- Perfil "batismo": só a tela Batismo do painel. Vê a lista de inscritos e o pagamento
-- da camiseta, e edita a foto e a data da página de inscrição. Não vê membros, financeiro,
-- ação social, contatos nem o resto do painel.
-- Rodar uma vez no SQL Editor do Supabase (depois do perfil-site.sql, que cria tem_papel).

-- 1) lista de inscritos do batismo: só leitura
drop policy if exists inscricoes_batismo_perfil_batismo on public.inscricoes_batismo;
create policy inscricoes_batismo_perfil_batismo on public.inscricoes_batismo for select to authenticated
  using (public.tem_papel('batismo'));

-- 2) foto e data da página de inscrição (site_config, só a chave 'batismo')
drop policy if exists site_config_perfil_batismo on public.site_config;
create policy site_config_perfil_batismo on public.site_config for all to authenticated
  using (chave = 'batismo' and public.tem_papel('batismo'))
  with check (chave = 'batismo' and public.tem_papel('batismo'));

-- 3) envio da foto: só na pasta batismo/ do bucket banners
drop policy if exists batismo_fotos_perfil_insert on storage.objects;
create policy batismo_fotos_perfil_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'banners' and name like 'batismo/%' and public.tem_papel('batismo'));

-- 4) dar o perfil à conta batismo@fonte.com. Antes, crie o usuário em
--    Authentication → Users → Add user → Create new user (e-mail batismo@fonte.com,
--    senha escolhida por você, "Auto Confirm User" marcado).
insert into public.profiles (id, role)
select id, 'batismo' from auth.users where email = 'batismo@fonte.com'
on conflict (id) do update set role = 'batismo';

-- conferência: deve voltar uma linha com role = batismo
select u.email, p.role from auth.users u join public.profiles p on p.id = u.id
where u.email = 'batismo@fonte.com';
