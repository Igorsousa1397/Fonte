-- Posições das células conferidas em 11/11/2026: o pino estava no meio da rua (ou em outra rua) e não no número da casa.
-- Cada ponto novo foi conferido em duas fontes (ponto do endereço com número + traçado da rua).
-- Rodar no SQL Editor do Supabase. Pode rodar mais de uma vez.

update public.celulas set lat = -23.345961, lng = -46.826125 where nome = 'Fire';   -- estava a 4888 m (Rua Alto Porã, 306)
update public.celulas set lat = -23.41103, lng = -46.847518 where nome = 'Pedra Angular';   -- estava a 936 m (Rua Gilberto de Carvalho, 239)
update public.celulas set lat = -23.399847, lng = -46.863315 where nome = 'Kerygma';   -- estava a 479 m (Av. dos Ingás, 416)
update public.celulas set lat = -23.395618, lng = -46.859727 where nome = 'Ebenézer';   -- estava a 355 m (Rua das Alpínias, 577)
update public.celulas set lat = -23.397666, lng = -46.860111 where nome = 'Identidade';   -- estava a 321 m (Rua das Caliandras, 401)
update public.celulas set lat = -23.430819, lng = -46.858277 where nome = 'Siloé';   -- estava a 250 m (Rua Bento Crispim de Oliveira, 141)
update public.celulas set lat = -23.411253, lng = -46.844681 where nome = 'Atos 29';   -- estava a 212 m (Rua Campos do Jordão, 175)
update public.celulas set lat = -23.404007, lng = -46.86461 where nome = 'Betel';   -- estava a 190 m (Av. das Palmeiras, 720)
update public.celulas set lat = -23.399534, lng = -46.857456 where nome = 'Brasa Viva';   -- estava a 167 m (Rua das Nogueiras, 267)
update public.celulas set lat = -23.407335, lng = -46.852179 where nome = 'Emaús';   -- estava a 159 m (Rua Waldemar Meira, 434)
update public.celulas set lat = -23.423094, lng = -46.860581 where nome = 'Gileade';   -- estava a 106 m (Rua Rouxinol, 106)
