# Igreja Fonte · Cajamar — Site

Site institucional estático da Igreja Apostólica Fonte (Cajamar/SP).
Página única (`index.html`), responsiva, tema escuro (preto/grafite + acento água).

## Estrutura

```
fonte-site/
├── index.html            # o site inteiro (HTML + CSS + JS)
├── assets/
│   ├── fonte-logo.png    # logo (usado no header e rodapé)
│   ├── campo.jpg         # fundo do card Encontro Peniel
│   └── welcome-bg.jpg    # fundo do card Encontro Submergidos
├── .gitignore
└── README.md
```

## Seções
Hero (banner rotativo dos próximos eventos) · Encontros/Inscrições · Quem somos ·
Cultos · Células (mapa Leaflet + lista) · Agenda 2026 · Contribuir (PIX) ·
Seja membro (formulário) · Contato · Rodapé com mapa.

## Rodar localmente
Basta abrir o `index.html` no navegador. (Os mapas — Leaflet e Google — precisam de
internet e funcionam melhor servidos por http, não `file://`.)

Servir localmente, se quiser:
```bash
npx serve .
# ou
python3 -m http.server 3000
```

## Subir no GitHub
```bash
git init
git add .
git commit -m "Site institucional Igreja Fonte"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/fonte-site.git
git push -u origin main
```

## Deploy na Vercel
- **Pelo painel:** New Project → Import do repositório → Framework Preset **"Other"**
  → Root Directory `.` → Deploy. (Não precisa de build; é estático.)
- **Pela CLI:**
  ```bash
  npm i -g vercel
  vercel          # preview
  vercel --prod   # produção
  ```

## Pontos a revisar antes de publicar
- Chave PIX e dados bancários (seção Contribuir) — hoje estão como CNPJ / "a confirmar".
- E-mail de contato (`contato@fontecajamar.com.br` é placeholder).
- Texto de "Quem somos" (rascunho).
- 4 células têm coordenada aproximada (Beraká, Ebenézer, Kerygma; Fire/Ekballo ficam na igreja).
- O formulário de "Seja membro" e o de "Contato" enviam via WhatsApp por enquanto
  (há um `// TODO: gravar no banco` no `index.html` para integrar ao banco depois).

## Data do evento
- Encontro Submergidos: 4–6 de setembro de 2026
- Encontro Peniel: 20–22 de novembro de 2026
