# Igreja Fonte · Cajamar — Site

Site da Igreja Apostólica Fonte (Cajamar/SP): site institucional, formulários públicos
e painel administrativo. HTML/CSS/JS puro (sem build, sem framework), responsivo, tema
escuro. Backend no **Supabase** (banco, Auth e Storage); hospedado na **Vercel**.

## Estrutura

```
Fonte/
├── index.html                  # site principal
├── servir.html                 # "Quero Servir" — inscrição em ministérios
├── batismo.html                # inscrição para batismo
├── acao-social.html            # ação social (doações, reservas, solicitações)
├── envelope.html               # envelope virtual (dízimo / primícia / oferta)
├── carteirinha.html            # carteirinha do membro
├── galeria.html                # fotos dos cultos
├── condicoes.html              # condições e suporte
├── politica-de-privacidade.html
├── login.html                  # login da área administrativa
├── painel.html                 # painel administrativo
└── assets/
    ├── supabase.js             # config do cliente Supabase
    ├── celulas/                # fotos das células
    ├── galeria/                # fotos dos cultos
    └── ...                     # logo, favicon, banners, fotos dos templos
```

Cada página é autocontida (HTML + CSS + JS no mesmo arquivo). As que falam com o banco
carregam o SDK `@supabase/supabase-js` via CDN e depois `assets/supabase.js`.

## Site principal (`index.html`)
Hero (banner rotativo dos próximos eventos) · Eventos/Encontros · Quem somos · Cultos ·
Templos · Células (mapa Leaflet + lista) · Agenda · Contribuir (PIX) · Seja membro
(formulário) · Contato ("Fale com a gente").

Conteúdo editado direto no código:
- **Agenda/eventos:** array de eventos no `<script>` do `index.html` (`inicio`, `fim`,
  `titulo`, `tipo`, `destaque`, `link`, `cta`…).
- **Células:** array `CELULAS` (nome, líder, endereço, horário, `lat`/`lng`, foto em
  `assets/celulas/`, WhatsApp).

## Supabase

A chave em `assets/supabase.js` é a **anon** (pública); a segurança fica nas políticas
RLS e nas funções RPC do banco. Nunca coloque a `service_role` no front.

As páginas públicas gravam por **RPC**:

| Página | RPCs | Storage |
|---|---|---|
| `index.html` | `criar_membro`, `membro_set_extras`, `criar_contato` | `membros-fotos` |
| `servir.html` | `ministerios_abertos`, `ministerio_inscrever` | — |
| `batismo.html` | `criar_inscricao_batismo` | — |
| `acao-social.html` | `acao_identificar`, `acao_registrar_pessoa`, `acao_registrar_doacao`, `acao_criar_reserva`, `acao_criar_solicitacao` | `acao-doacoes` |
| `envelope.html` | `envelope_abrir`, `contribuicao_declarar` | — |
| `carteirinha.html` | `membro_carteirinha` | — |

## Painel administrativo (`login.html` → `painel.html`)
Login via Supabase Auth. O acesso é definido por `profiles.role`:

- `admin` — tudo
- `acao_social` — Ação Social
- `ministerios` — Ministérios

Telas:
- **Membros** — lista, carteirinha, exclusão, exportação em PDF
- **Batismo** — inscrições
- **Ministérios** — abrir/fechar ministérios para inscrição (`ministerio_config`),
  inscrições com filtro e contagem, exportação em PDF
- **Ação Social** — itens (mercadinho/rouparia), doações, reservas
  (pendente → separado → entregue), solicitações, pessoas
- **Contatos** — mensagens do "Fale com a gente"
- **Financeiro** — contribuições declaradas no envelope (confirmar/recusar)

Tabelas usadas: `membros`, `inscricoes_batismo`, `ministerio_config`,
`ministerio_inscricoes`, `contatos`, `contribuicoes`, `acao_itens`, `acao_doacoes`,
`acao_reservas`, `acao_solicitacoes`, `acao_pessoas`, `profiles`.

## Rodar localmente
Sirva a pasta por http (mapas e Supabase não funcionam bem em `file://`):

```bash
npx serve .
# ou
python3 -m http.server 3000
```

## Deploy na Vercel
Projeto estático — Framework Preset **"Other"**, Root Directory `.`, sem build.
Pela CLI:

```bash
vercel          # preview
vercel --prod   # produção
```
