-- Células que estavam na lista da liderança (27/10/2026) e faltavam no site.
-- Sem horário na lista = 20h (padrão das células).
-- Rodar uma vez no SQL Editor do Supabase. Depois, ajustes finos (foto, WhatsApp,
-- horário, ponto exato no mapa) ficam pelo painel → Células → Editar.
-- Localização: Brasa Viva, El Shadday e Renovo pela rua; Siloé aproximada (mesma rua da
-- Luz do Mundo); Manancial no mesmo condomínio da Jeová Rafah.

insert into public.celulas (nome, lider, endereco, horario, cidade, tag, lat, lng) values
  ('Brasa Viva', 'Cledinho e Lorena', 'Rua das Nogueiras, 267 — Portal dos Ipês',                         '20h',   'Cajamar',             null, -23.3992024, -46.8590481),
  ('Siloé',      'Wesley e Esther',   'Rua Bento Crispim de Oliveira, 141 — Gleba C, São Pedro',          '20h',   'Santana de Parnaíba', null, -23.4300000, -46.8560000),
  ('Manancial',  'Pr. Alexandre e Pra. Meire', 'Rua Cruzeiro do Sul, 430 — Cond. dos Pássaros, casa 143 (Vila Parque)', '19h45', 'Santana de Parnaíba', null, -23.4126946, -46.8987276),
  ('El Shadday', 'Diego e Prisc',     'Av. Batista Borba, 37 — São Pedro',                                '20h',   'Santana de Parnaíba', null, -23.4242286, -46.8579423),
  ('Renovo',     'Paulo e Lucivania', 'Rua Canário, 73 — Recanto do Paraíso, Perus',                      '20h',   'Perus',               null, -23.4179908, -46.7514556)
on conflict (nome) do nothing;
