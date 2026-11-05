-- Parcerias: estabelecimentos com benefícios para membros da Fonte (página parcerias.html),
-- editáveis pelo painel (aba Parcerias). Também cria o banner do carrossel.
-- Rodar uma vez no SQL Editor do Supabase, depois de perfil-site.sql.

create table if not exists public.parcerias (
  id         uuid primary key default gen_random_uuid(),
  nome       text not null,
  categoria  text,                 -- ex.: "Seminovos"
  logo_url   text,
  beneficios text,                 -- um benefício por linha
  observacao text,                 -- detalhe do benefício no modal, ex.: "Na compra do seu seminovo."
  periodo    text,                 -- ex.: "Novembro de 2026" (texto livre, aparece no card)
  site       text,
  instagram  text,                 -- só o @
  whatsapp   text,
  endereco   text,
  ordem      int not null default 0,
  ativo      boolean not null default true,
  criado_em  timestamptz not null default now()
);

alter table public.parcerias add column if not exists observacao text;
alter table public.parcerias enable row level security;

-- site: lê só os ativos
drop policy if exists parcerias_select_publico on public.parcerias;
create policy parcerias_select_publico on public.parcerias
  for select to anon, authenticated using (ativo);

-- painel: admin e site (conteúdo) editam
drop policy if exists parcerias_admin on public.parcerias;
create policy parcerias_admin on public.parcerias for all to authenticated
  using (tem_papel('admin', 'site')) with check (tem_papel('admin', 'site'));

-- primeiro parceiro
insert into public.parcerias (nome, categoria, logo_url, beneficios, observacao, periodo, site, instagram, whatsapp, endereco, ordem)
select 'Baruc Autocar', 'Seminovos', 'assets/parceiros/baruc.png',
       E'Tanque cheio\nDocumentação grátis', 'Na compra do seu seminovo.', 'Novembro de 2026',
       'https://barucautocar.com.br/', 'baruc.autocar', '(11) 4448-5734',
       'Av. Ten. Marques, 4232 · Polvilho · Cajamar', 1
where not exists (select 1 from public.parcerias where nome = 'Baruc Autocar');

-- banner no carrossel (sem data: fica até ser desligado na aba Banners)
insert into public.banners (titulo, descricao, imagem_url, link, cta, ativo)
select 'Parceiros Fonte', 'Benefícios exclusivos para membros da Fonte em estabelecimentos parceiros.',
       'assets/banners/parcerias.jpg', 'parcerias.html', 'Ver benefícios', true
where not exists (select 1 from public.banners where link = 'parcerias.html');

insert into public.parcerias (nome, categoria, logo_url, beneficios, observacao, periodo, ordem)
select 'My Life Decor', 'Decoração', 'assets/parceiros/mylifedecor.png',
       '10% de desconto', 'Na contratação de qualquer serviço.', 'Novembro de 2026', 2
where not exists (select 1 from public.parcerias where nome = 'My Life Decor');

insert into public.parcerias (nome, categoria, logo_url, beneficios, ordem)
select 'Camarote do Corte', 'Beleza', 'assets/parceiros/camarote-do-corte.png', 'R$ 10 de desconto', 3
where not exists (select 1 from public.parcerias where nome = 'Camarote do Corte');

insert into public.parcerias (nome, categoria, logo_url, beneficios, observacao, periodo, ordem)
select 'Plant', 'Jardinagem e Paisagismo', 'assets/parceiros/plant.jpg',
       E'Avaliação gratuita\n10% de desconto', 'Na contratação do serviço.', 'Novembro de 2026', 4
where not exists (select 1 from public.parcerias where nome = 'Plant');

-- contatos (também atualiza se os parceiros já tiverem sido cadastrados)
update public.parcerias set instagram = 'mylifedecor', whatsapp = '(11) 98234-1714' where nome = 'My Life Decor';
update public.parcerias set site = 'https://camarotedocortejc.com/', whatsapp = '(11) 97435-8961' where nome = 'Camarote do Corte';
update public.parcerias set site = 'https://plantjardinagem.neocities.org/', whatsapp = '(11) 97179-2236' where nome = 'Plant';

-- categorias amplas (a página tem filtro por categoria)
update public.parcerias set categoria = 'Automóveis'       where nome = 'Baruc Autocar';
update public.parcerias set categoria = 'Casa e Decoração' where nome = 'My Life Decor';
update public.parcerias set categoria = 'Beleza'           where nome = 'Camarote do Corte';
update public.parcerias set categoria = 'Paisagismo'       where nome = 'Plant';

-- nome do banner
update public.banners set titulo = 'Parceiros Fonte' where link = 'parcerias.html';

-- benefício do Camarote do Corte
update public.parcerias set beneficios = 'R$ 10 de desconto', observacao = 'Em qualquer corte de cabelo.', periodo = 'Novembro de 2026' where nome = 'Camarote do Corte';

insert into public.parcerias (nome, categoria, logo_url, beneficios, observacao, periodo, instagram, whatsapp, ordem)
select 'Tha Store', 'Vestuário', 'assets/parceiros/tha-store.jpg',
       E'10% de desconto em compras à vista\nCompras acima de R$ 200 à vista ganham 1 blusinha',
       'Moda feminina. Fale com a Thais.', 'Novembro de 2026', 'tha.store_modafeminina', '(11) 99718-7584', 5
where not exists (select 1 from public.parcerias where nome = 'Tha Store');

insert into public.parcerias (nome, categoria, logo_url, beneficios, observacao, periodo, instagram, whatsapp, ordem)
select 'Bea Toledo', 'Alimentação', 'assets/parceiros/bea-toledo.png',
       '15% de desconto', 'Em atendimento de personal chef.', 'Novembro de 2026', 'beatoledopersonalchef', '(11) 97342-5383', 6
where not exists (select 1 from public.parcerias where nome = 'Bea Toledo');

insert into public.parcerias (nome, categoria, logo_url, beneficios, observacao, periodo, instagram, whatsapp, ordem)
select 'Riso & Luz Decor', 'Festas e Eventos', 'assets/parceiros/riso-e-luz.jpg',
       '10% de desconto', 'Nos serviços de decoração. Fale com a Fran.', 'Novembro de 2026', 'risoeluzdecor', '(11) 94553-5536', 7
where not exists (select 1 from public.parcerias where nome = 'Riso & Luz Decor');
