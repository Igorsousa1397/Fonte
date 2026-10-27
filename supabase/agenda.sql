-- Agenda ministerial editável pelo painel (tela Agenda).
-- Os cultos fixos (Domingo e Quarta Profética) continuam automáticos, e os encontros
-- (Submergidos, Peniel) continuam na tela Encontros.
-- Rodar uma vez no SQL Editor do Supabase.

create table if not exists public.agenda (
  id         uuid primary key default gen_random_uuid(),
  titulo     text not null,
  tipo       text not null default 'evento'
             check (tipo in ('culto','evento','conferencia','lideranca','marco')),
  inicio     date not null,
  fim        date,                 -- opcional: eventos de vários dias
  hora       text,                 -- opcional, ex.: 20h
  destaque   boolean not null default false,
  imagem_url text,                 -- opcional: flyer (aparece no topo do site no mês do evento)
  link       text,                 -- opcional: botão na agenda
  cta        text,                 -- opcional: texto do botão
  ativo      boolean not null default true,
  criado_em  timestamptz not null default now(),
  check (fim is null or fim >= inicio)
);

alter table public.agenda enable row level security;

drop policy if exists agenda_select_publico on public.agenda;
create policy agenda_select_publico on public.agenda
  for select to anon, authenticated using (ativo);

drop policy if exists agenda_admin on public.agenda;
create policy agenda_admin on public.agenda
  for all to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- eventos que já estavam no site (só entra se a tabela estiver vazia, para não duplicar)
insert into public.agenda (titulo, tipo, inicio, fim, hora, destaque, imagem_url, link, cta)
select * from (values
  ('Culto Jovens DN4', 'culto', date '2026-07-11', null, null, false, 'assets/dn4-jovens.jpg', null, null),
  ('Através de Você', 'culto', date '2026-07-14', null, null, false, 'assets/atraves-de-voce.jpg', null, null),
  ('Aniversário da Igreja', 'conferencia', date '2026-07-23', date '2026-07-26', null, true, 'assets/firmamento.jpg', null, null),
  ('Discipulado com Líderes de Célula', 'lideranca', date '2026-07-28', null, null, false, 'assets/discipulado-lideres.jpg', null, null),
  ('Culto “À Fonte do Empreendedor”', 'culto', date '2026-08-04', null, null, false, null, null, null),
  ('Culto DN4', 'culto', date '2026-08-08', null, null, false, null, null, null),
  ('Culto de Mulheres', 'culto', date '2026-08-14', null, null, false, null, null, null),
  ('Pastores Comprometidos', 'evento', date '2026-09-10', date '2026-09-14', null, false, null, null, null),
  ('Culto DN4', 'culto', date '2026-09-12', null, null, false, null, null, null),
  ('Batismo', 'marco', date '2026-09-27', null, null, false, null, null, null),
  ('Através de Você na Mesa', 'evento', date '2026-09-29', null, null, false, null, null, null),
  ('Culto de Mulheres', 'culto', date '2026-10-06', null, null, false, null, null, null),
  ('Festa Dia das Crianças', 'evento', date '2026-10-12', null, null, false, null, null, null),
  ('Seminário de Honra', 'evento', date '2026-10-16', date '2026-10-18', null, true, null, null, null),
  ('Culto DN4', 'culto', date '2026-10-24', null, null, false, null, null, null),
  ('Discipulado com Líderes de Célula', 'lideranca', date '2026-10-26', null, null, false, 'assets/discipulado-lideres.jpg', null, null),
  ('Último Culto de Homens', 'culto', date '2026-11-13', null, null, false, null, null, null),
  ('Casamento do Tiago', 'marco', date '2026-11-14', null, null, false, null, null, null),
  ('Discipulado com Líderes de Ministério', 'lideranca', date '2026-11-17', null, null, false, null, null, null),
  ('Último Culto DN4 · Batismo (manhã)', 'marco', date '2026-11-28', null, null, false, null, null, null),
  ('Culto de Mulheres — Encerramento', 'culto', date '2026-12-04', null, null, false, null, null, null),
  ('Última Célula do Ano', 'evento', date '2026-12-11', null, null, false, null, null, null),
  ('Confraternização de Líderes de Célula', 'lideranca', date '2026-12-18', null, null, false, null, null, null),
  ('Culto Especial de Natal', 'culto', date '2026-12-20', null, null, false, null, null, null),
  ('Culto da Virada', 'culto', date '2026-12-31', null, null, false, null, null, null)
) as v(titulo, tipo, inicio, fim, hora, destaque, imagem_url, link, cta)
where not exists (select 1 from public.agenda);

-- flyers da agenda vão para a mesma pasta pública dos banners (bucket banners)
