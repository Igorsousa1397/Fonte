-- Através de Você: projeto da Pra. Thamires. Todo mês tem um culto com data, tema e paleta de cores.
-- Aparece na página atraves-de-voce.html, num destaque na home e na agenda do site (na cor do tema).
-- Editável no painel (aba Através de Você). Rodar uma vez no SQL Editor do Supabase, depois de perfil-site.sql.

create table if not exists public.atraves_de_voce (
  id           uuid primary key default gen_random_uuid(),
  data         date not null,
  hora         text,                         -- ex.: 19h30
  tema         text not null,                -- ex.: Revival
  subtitulo    text,                         -- ex.: Último do ano
  frase        text,                         -- ex.: Preparando o altar para 2027
  preletores   text,                         -- um por linha
  endereco     text,
  paleta_nome  text,                         -- ex.: Paleta Glow
  cores        jsonb not null default '[]',  -- [{"nome":"Champagne","hex":"#F8EBD9"}, …]
  cor          text not null default '#B8734F' check (cor ~ '^#[0-9A-Fa-f]{6}$'),  -- cor do tema na agenda
  flyer_url    text,                         -- arte em pé (celular)
  banner_url   text,                         -- arte deitada (computador), opcional
  paleta_url   text,                         -- arte da paleta, opcional
  ativo        boolean not null default true,
  criado_em    timestamptz not null default now()
);

alter table public.atraves_de_voce enable row level security;

-- site: lê só as edições ligadas
drop policy if exists adv_select_publico on public.atraves_de_voce;
create policy adv_select_publico on public.atraves_de_voce
  for select to anon, authenticated using (ativo);

-- painel: admin e site (conteúdo) editam
drop policy if exists adv_admin on public.atraves_de_voce;
create policy adv_admin on public.atraves_de_voce for all to authenticated
  using (tem_papel('admin', 'site')) with check (tem_papel('admin', 'site'));

-- edição de novembro de 2026
insert into public.atraves_de_voce (data, hora, tema, subtitulo, frase, preletores, endereco, paleta_nome, cores, cor, flyer_url, banner_url, paleta_url)
select date '2026-11-27', '19h30', 'Revival', 'Último do ano', 'Preparando o altar para 2027',
       E'Pra. Thamires Ponciano\nPra. Jemima Gonzalez\nMiss Rhayline Resplande',
       'Rua Catiguá, 130 · Cajamar/SP', 'Paleta Glow',
       '[{"nome":"Champagne","hex":"#F8EBD9"},{"nome":"Nude Glow","hex":"#E7C6B8"},{"nome":"Rosé Brilho","hex":"#D4A496"},
         {"nome":"Dourado Suave","hex":"#CFA370"},{"nome":"Terracota","hex":"#B8734F"},{"nome":"Marrom Glow","hex":"#6B4A3A"}]'::jsonb,
       '#B8734F', 'assets/atraves/2026-11-revival.jpg', 'assets/atraves/2026-11-revival-largo.jpg', 'assets/atraves/2026-11-paleta.jpg'
where not exists (select 1 from public.atraves_de_voce where data = date '2026-11-27');

-- Inspire-se: fotos de looks nas cores do tema (carrossel na página). [{"url":"…","legenda":"Champagne"}, …]
alter table public.atraves_de_voce add column if not exists fotos jsonb not null default '[]';
update public.atraves_de_voce set fotos = '[
  {"url":"assets/atraves/2026-11-look-champagne.jpg","legenda":"Champagne"},
  {"url":"assets/atraves/2026-11-look-nude-glow.jpg","legenda":"Nude Glow"},
  {"url":"assets/atraves/2026-11-look-rose-brilho.jpg","legenda":"Rosé Brilho"},
  {"url":"assets/atraves/2026-11-look-dourado-suave.jpg","legenda":"Dourado Suave"},
  {"url":"assets/atraves/2026-11-look-terracota.jpg","legenda":"Terracota"},
  {"url":"assets/atraves/2026-11-look-marrom-glow.jpg","legenda":"Marrom Glow"}
]'::jsonb where data = date '2026-11-27' and jsonb_array_length(fotos) = 0;
