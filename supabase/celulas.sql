-- Células editáveis pelo painel (tela Células). O site, o batismo e o "Quero servir"
-- passam a ler a lista daqui; sem conseguir ler o banco, usam a lista antiga do código.
-- Rodar uma vez no SQL Editor do Supabase.

create table if not exists public.celulas (
  id        uuid primary key default gen_random_uuid(),
  nome      text not null unique,
  lider     text,
  endereco  text,
  horario   text,
  cidade    text not null,
  tag       text,                 -- ex.: Mulheres, Jovens (opcional)
  lat       double precision not null,
  lng       double precision not null,
  foto_url  text,
  whatsapp  text,                 -- só números, com DDI 55
  ativo     boolean not null default true,
  criado_em timestamptz not null default now()
);

alter table public.celulas enable row level security;

drop policy if exists celulas_select_publico on public.celulas;
create policy celulas_select_publico on public.celulas
  for select to anon, authenticated using (ativo);

drop policy if exists celulas_admin on public.celulas;
create policy celulas_admin on public.celulas
  for all to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- células que já estavam no site
insert into public.celulas (nome, lider, endereco, horario, cidade, tag, lat, lng, foto_url, whatsapp) values
  ('Betesda', 'Cris e Carol', 'Rua dos Flox, 400 — Cond. San Miguel (T8 ap.05)', '20h', 'Cajamar', 'Mulheres', -23.4035007, -46.8587154, 'assets/celulas/betesda.jpg', '5511916405273'),
  ('Beraká', 'Pr. Amilton e Pra. Kátia', 'Na Igreja (R. Catiguá, 130) — Templo Kids', '20h', 'Cajamar', null, -23.40868, -46.86781, 'assets/celulas/beraka.jpg', '5511953656812'),
  ('Reobote', 'Thais e Junior', 'Rua Irmã Daria Moreira, 39 — Pq. Paraíso', '20h', 'Cajamar', null, -23.4106936, -46.8272042, 'assets/celulas/reobote.jpg', '5511997187584'),
  ('Emaús', 'Simone e Tiago', 'Rua Waldemar Meira, 434 — Portal', '20h', 'Cajamar', null, -23.4077369, -46.853676, 'assets/celulas/emaus.jpg', '5511914680682'),
  ('Fire', 'Paulo e Fabiana', 'Rua Alto Porã, 306 — Apto 22B, Colina Maria Luiza (Jordanésia)', '20h', 'Cajamar', null, -23.3608, -46.8712, 'assets/celulas/fire.jpg', '5511997093085'),
  ('Kerygma', 'João e Anchelly', 'Av. dos Ingás, 416 — Portal dos Ipês', '20h', 'Cajamar', null, -23.3970186, -46.8668598, 'assets/celulas/kerygma.jpg', '5511942418154'),
  ('Ebenézer', 'Sóstenes e Kelly', 'Rua das Alpínias, 577 — Portal dos Ipês', '20h', 'Cajamar', null, -23.3988088, -46.859581, 'assets/celulas/ebenezer.jpg', '5511950413682'),
  ('Betel', 'Rodnei e Débora', 'Av. das Palmeiras, 720 — ap.97 (Portal)', '19h30', 'Cajamar', null, -23.4041966, -46.8627586, 'assets/celulas/betel.jpg', '5511950932007'),
  ('Transbordo', 'Marlucia e Cícero', 'Rua Cosmópolis, 123 — Pq. Paraíso', 'Sáb 19h', 'Cajamar', null, -23.4192869, -46.8263836, 'assets/celulas/transbordo.jpg', '55119'),
  ('Ekklesia', 'Carol e Claiton', 'Rua das Malvas, 245 — Portal dos Ipês', '20h', 'Cajamar', null, -23.3968332, -46.8646969, 'assets/celulas/ekklesia.jpg', '5511971792236'),
  ('Ekballo', 'Felipe e Larissa', 'Na Igreja (R. Catiguá, 130) — Sala Pastoral', '20h', 'Santana de Parnaíba', null, -23.40868, -46.86807, 'assets/celulas/ekballo.jpg', '5511939345629'),
  ('Atos 29', 'Nicolas e Agatha', 'Rua Campos do Jordão, 175 — Cond. Vitória 1 (Polvilho/Panorama)', '19h30', 'Cajamar', null, -23.4129728, -46.8455715, 'assets/celulas/atos-29.jpg', '5511955850282'),
  ('Identidade', 'Douglas e Fran', 'Rua das Caliandras, 401 — Portal 3', '20h', 'Cajamar', null, -23.3991101, -46.8573909, 'assets/celulas/identidade.jpg', '5511950932007'),
  ('Pedra Angular', 'Miriam', 'Rua Gilberto de Carvalho, 239 — Panorama', '20h', 'Cajamar', 'Mulheres', -23.4184663, -46.851825, 'assets/celulas/pedra-angular.jpg', '5511993174500'),
  ('Carta Viva', 'Mateus e Ingrid', 'Rua Takaharu Urano, 706 — Portal 1', '20h', 'Cajamar', null, -23.4101862, -46.8484336, 'assets/celulas/carta-viva.jpg', '5511957810047'),
  ('Luz do Mundo', 'Ev. Islany e Ev. Silas', 'Rua Bento Crispim, 842 — Gleba C', '20h', 'Santana de Parnaíba', null, -23.4305852, -46.856698, null, '5511951709482'),
  ('Gileade', 'Carol e Sávio', 'Rua Rouxinol, 106 — Cidade São Pedro', '20h', 'Santana de Parnaíba', null, -23.4238086, -46.8598876, 'assets/celulas/gileade.jpg', '5511958851937'),
  ('A Forja', 'Jhonny e Tais', 'Rua Geraldo Ramos da Silva Filho, 35 — Gleba B, São Pedro', '20h', 'Santana de Parnaíba', null, -23.4251156, -46.8505617, 'assets/celulas/a-forja.jpg', '5511950932007'),
  ('Nahal', 'Larissa e Inês', 'Rua Spártaco Bastianon, 10 — Gleba B, São Pedro', '20h', 'Santana de Parnaíba', null, -23.4286921, -46.8488236, null, '5511978083493'),
  ('Deus Forte', 'Joabio e Kátia', 'Rua Alfa, 09 — Pq. Jaguari', 'Sex 20h', 'Santana de Parnaíba', null, -23.4182965, -46.8720568, 'assets/celulas/deus-forte.jpg', '5511975449567'),
  ('Essência', 'Rafael e Ana Clara', 'Rua do Mandi, 531b — Gleba B, São Pedro', '20h', 'Santana de Parnaíba', null, -23.4293941, -46.8497347, 'assets/celulas/essencia.jpg', '5511932261526'),
  ('Jeová Rafah', 'Jardel e Tamiris', 'Rua Cruzeiro do Sul, 430 — Cond. dos Pássaros (Chác. Solar)', '20h', 'Santana de Parnaíba', null, -23.4123946, -46.8990276, null, '5511947851715'),
  ('Fonte Barueri', 'Samuel e Luana', 'Rua Laura, 47 — Parque dos Camargos, Barueri', '20h', 'Barueri', null, -23.5403764, -46.8909511, 'assets/celulas/fonte.jpg', '5511965731601'),
  ('Peniel', 'Alex Sandro e Tati', 'Rua Fermino Vieira Cordeiro, 1200 — Espinheiro (Bloco G / Apto 202), Itajaí/SC', 'Sex 20h', 'Itajaí/SC', null, -26.89586808748668, -48.7307609691978, 'assets/celulas/peniel.jpg', '5517992325979')
on conflict (nome) do nothing;

-- fotos das células (pasta pública no Storage)
insert into storage.buckets (id, name, public)
values ('celulas', 'celulas', true)
on conflict (id) do update set public = true;

drop policy if exists celulas_fotos_admin_insert on storage.objects;
create policy celulas_fotos_admin_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'celulas'
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

drop policy if exists celulas_fotos_admin_delete on storage.objects;
create policy celulas_fotos_admin_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'celulas'
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));
