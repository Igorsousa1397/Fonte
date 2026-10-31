-- Pagamento da camiseta do batismo pelo Mercado Pago (função pagamento-batismo).
-- Rodar uma vez no SQL Editor do Supabase, antes de publicar a função.

-- id do pagamento no Mercado Pago (distingue baixa automática de marcação manual)
alter table public.inscricoes_batismo add column if not exists pagamento_id text;
