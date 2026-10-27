-- Banners automáticos (os que o site já gerava sozinho) passam a aparecer no painel,
-- com liga/desliga e edição de título, descrição e foto. A data continua automática
-- (próxima quarta, próximo domingo, primeiro domingo do mês para a Santa Ceia).
-- Rodar uma vez no SQL Editor do Supabase, depois do banners.sql.

alter table public.banners add column if not exists auto text unique;
  -- null = banner avulso; 'agenda' | 'quarta' | 'domingo' | 'ceia' = automático

insert into public.banners (auto, titulo, descricao, imagem_url, ativo) values
  ('agenda',  'Eventos especiais da agenda',
              'Eventos do mês com destaque na agenda (encontros, conferências, aniversário da igreja…).',
              null, true),
  ('quarta',  'Quarta Profética',
              'Toda quarta tem palavra profética pra sua semana. Culto às 20h.',
              'assets/banner-quarta.jpg', true),
  ('domingo', 'Domingo em Família',
              'Nosso culto de domingo em família, às 10h e 18h30. Traga todo mundo pra adorar com a Fonte.',
              null, true),
  ('ceia',    'Santa Ceia',
              'Nosso Domingo de Santa Ceia, às 10h e 18h30. Venha participar da mesa do Senhor com a família Fonte.',
              'assets/banner-ceia.jpg', true)
on conflict (auto) do nothing;
