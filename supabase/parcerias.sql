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
select 'Parcerias Fonte', 'Benefícios exclusivos para membros da Fonte em estabelecimentos parceiros.',
       'assets/banners/parcerias.jpg', 'parcerias.html', 'Ver benefícios', true
where not exists (select 1 from public.banners where link = 'parcerias.html');
