-- Um login por ministério: cada um só vê e monta a escala do próprio ministério
-- (perfil lider_ministerio, já existente no painel). Padrão do e-mail: escalas.<ministério>@fonte.com
--
-- Antes de rodar: crie o usuário em Supabase → Authentication → Users → Add user
-- (e-mail abaixo, senha à sua escolha, "Auto Confirm User" marcado).
-- Precisa do escalas.sql e do perfil-escalas.sql já rodados.

-- Boas-vindas
update public.ministerio_config set escala = true where nome = 'Boas-vindas';

insert into public.profiles (id, role, ministerios)
select id, 'lider_ministerio', array['Boas-vindas']
from auth.users where lower(email) = 'escalas.boasvindas@fonte.com'
on conflict (id) do update set role = 'lider_ministerio', ministerios = excluded.ministerios;

-- conferência: deve voltar uma linha com lider_ministerio e {Boas-vindas}
select u.email, p.role, p.ministerios
from auth.users u join public.profiles p on p.id = u.id
where lower(u.email) = 'escalas.boasvindas@fonte.com';

-- Próximos ministérios: copie o bloco acima trocando o e-mail e o nome
-- (escrito igual à lista de Ministérios do painel, ex.: 'Louvor', 'Mídia Técnica').
