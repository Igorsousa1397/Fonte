// Pagamento da camiseta do batismo pelo Mercado Pago (mesmo modelo do app do encontro).
// Uma função só, com dois papéis:
//   1) a página batismo.html chama com {telefone, tipo} logo depois da inscrição →
//      cria o checkout e devolve o init_point (o valor é definido aqui, nunca pelo site);
//   2) o Mercado Pago chama a mesma URL quando há pagamento (notification_url) →
//      confere status e valor na API do MP e marca inscricoes_batismo.pagamento_status = 'aprovado'.
//
// Publicar no Supabase → Edge Functions → pagamento-batismo, com "Verify JWT" DESLIGADO
// (o Mercado Pago não manda token).
// Segredos (Supabase → Edge Functions → Secrets):
//   MP_ACCESS_TOKEN = access token de produção do Mercado Pago da igreja (APP_USR-…)
// SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY já vêm prontas na função.

import { createClient } from "jsr:@supabase/supabase-js@2";

const SITE = "https://igrejaapostolicafonte.com.br";
const VALOR_CAMISETA = 42;          // o mesmo do painel e da página
const PREFIXO = "batismo||";        // external_reference = batismo||<id da inscrição>
const MINUTOS_VALIDADE = 60;        // link antigo não pode ser pago depois

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const resposta = (status: number, corpo: Record<string, unknown>) =>
  new Response(JSON.stringify(corpo), { status, headers: { ...cors, "Content-Type": "application/json" } });
const soNumeros = (v: unknown) => String(v ?? "").replace(/\D/g, "");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return resposta(405, { erro: "Use POST" });

  const token = Deno.env.get("MP_ACCESS_TOKEN");
  if (!token) return resposta(500, { erro: "MP_ACCESS_TOKEN não configurado" });
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const url = new URL(req.url);
  const corpo = await req.json().catch(() => ({} as Record<string, unknown>));

  // ---------- 2) aviso do Mercado Pago ----------
  // Webhooks mandam {type, data:{id}}; o IPN antigo manda ?topic=payment&id=…
  const tipoAviso = (corpo as { type?: string }).type ?? url.searchParams.get("type") ?? url.searchParams.get("topic");
  if (tipoAviso) {
    const pagamentoId = (corpo as { data?: { id?: string } }).data?.id ?? url.searchParams.get("data.id") ?? url.searchParams.get("id");
    if (tipoAviso !== "payment" || !pagamentoId) return resposta(200, { ok: "ignorado" });

    const r = await fetch(`https://api.mercadopago.com/v1/payments/${pagamentoId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!r.ok) {
      console.error(`batismo: MP devolveu ${r.status} ao consultar ${pagamentoId}`);
      return resposta(500, { erro: "erro ao consultar o pagamento" });   // o MP tenta de novo
    }
    const pag = await r.json();
    const ref = String(pag.external_reference ?? "");
    console.log(`batismo: pagamento ${pagamentoId} status=${pag.status} ref="${ref}" valor=${pag.transaction_amount}`);
    if (!ref.startsWith(PREFIXO)) return resposta(200, { ok: "não é do batismo" });
    if (pag.status !== "approved") return resposta(200, { ok: "não aprovado" });
    if (Number(pag.transaction_amount) + 0.01 < VALOR_CAMISETA) {
      console.error(`batismo: valor pago ${pag.transaction_amount} menor que ${VALOR_CAMISETA} (${ref})`);
      return resposta(200, { ok: "valor divergente" });
    }
    const id = ref.slice(PREFIXO.length);
    const { data, error } = await admin.from("inscricoes_batismo")
      .update({ pagamento_status: "aprovado", pagamento_id: String(pagamentoId) })
      .eq("id", id).select("id");
    if (error) {
      console.error("batismo: erro ao marcar pago", error.message);
      return resposta(500, { erro: error.message });
    }
    if (!data?.length) console.error(`batismo: inscrição ${id} não encontrada (pagamento ${pagamentoId})`);
    return resposta(200, { ok: "pago" });
  }

  // ---------- 1) criar o checkout ----------
  const tel = soNumeros((corpo as { telefone?: string }).telefone);
  if (tel.length < 10) return resposta(400, { erro: "Telefone inválido." });
  const credito = (corpo as { tipo?: string }).tipo === "credito";

  // a inscrição mais recente com compra de camiseta para este telefone (últimos 30 dias)
  const desde = new Date(Date.now() - 30 * 86_400_000).toISOString();
  const { data: lista, error } = await admin.from("inscricoes_batismo")
    .select("id,nome,telefone,camiseta_opcao,pagamento_status,created_at")
    .eq("camiseta_opcao", "comprar").gte("created_at", desde)
    .order("created_at", { ascending: false }).limit(200);
  if (error) return resposta(500, { erro: error.message });
  const insc = (lista ?? []).find((i) => soNumeros(i.telefone).endsWith(tel.slice(-10)));
  if (!insc) return resposta(404, { erro: "Inscrição com compra de camiseta não encontrada para este telefone." });
  if (insc.pagamento_status === "aprovado") return resposta(409, { erro: "A camiseta desta inscrição já está paga." });

  const volta = (pago: string) => `${SITE}/batismo.html?pago=${pago}`;
  const preferencia = {
    items: [{ title: "Camiseta do batismo — Igreja Fonte", quantity: 1, unit_price: VALOR_CAMISETA, currency_id: "BRL" }],
    payer: { name: insc.nome },
    external_reference: PREFIXO + insc.id,
    expires: true,
    expiration_date_to: new Date(Date.now() + MINUTOS_VALIDADE * 60_000).toISOString(),
    back_urls: { success: volta("true"), failure: volta("false"), pending: volta("pending") },
    auto_return: "approved",
    payment_methods: {
      excluded_payment_types: credito
        ? [{ id: "ticket" }, { id: "digital_currency" }, { id: "digital_wallet" }]
        : [{ id: "credit_card" }, { id: "digital_currency" }, { id: "digital_wallet" }],
      installments: 1,
    },
    notification_url: `${Deno.env.get("SUPABASE_URL")}/functions/v1/pagamento-batismo`,
  };
  const r = await fetch("https://api.mercadopago.com/checkout/preferences", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify(preferencia),
  });
  const mp = await r.json();
  if (!mp.init_point) {
    console.error("batismo: MP recusou a preferência", JSON.stringify(mp));
    return resposta(500, { erro: "Não foi possível abrir o pagamento agora." });
  }
  await admin.from("inscricoes_batismo").update({ pagamento_status: "pendente" })
    .eq("id", insc.id).neq("pagamento_status", "aprovado");
  console.log(`batismo: checkout ${mp.id} para a inscrição ${insc.id} (${credito ? "cartão" : "pix"})`);
  return resposta(200, { init_point: mp.init_point });
});
