-- Guarda quando a carteirinha foi enviada por e-mail, para não enviar duas vezes.
-- Rodar no SQL Editor ANTES de subir o painel novo (o painel passa a ler esta coluna).
alter table public.membros add column if not exists carteirinha_enviada_em timestamptz;
