// Pagamento da camiseta do batismo pelo Mercado Pago (mesmo modelo do app do encontro).
// Uma função só, com dois papéis:
//   1) a página batismo.html chama com {telefone, tipo} logo depois da inscrição, ou {id, tipo}
//      pelo link de cobrança do painel →
//      cria a order e devolve o link do checkout (o valor é definido aqui, nunca pelo site);
//   2) o Mercado Pago chama a mesma URL quando a order muda (webhook) →
//      confere status e valor na API do MP e marca inscricoes_batismo.pagamento_status = 'aprovado'.
//   3) {acao:"email", telefone, email} logo depois da inscrição → manda o e-mail de confirmação
//      com o link de pagamento da camiseta (batismo.html?pagar=<id>).
// Usa a API de Orders do Checkout Pro (a de Preferences vai ser descontinuada).
//
// Publicar no Supabase → Edge Functions → pagamento-batismo, com "Verify JWT" DESLIGADO
// (o Mercado Pago não manda token).
// No Mercado Pago → aplicação "Batismo Igreja Fonte" → Webhooks → Produção:
//   URL = https://iheracfrwyswhfxqrfrs.supabase.co/functions/v1/pagamento-batismo
//   evento = "Order (Mercado Pago)"
// Segredos (Supabase → Edge Functions → Secrets):
//   MP_ACCESS_TOKEN = access token de produção do Mercado Pago da igreja (APP_USR-…)
//   RESEND_API_KEY  = já existe (é a mesma da carteirinha); usada no e-mail de confirmação
// SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY já vêm prontas na função.

import { createClient } from "jsr:@supabase/supabase-js@2";

const SITE = "https://igrejaapostolicafonte.com.br";
const VALOR_CAMISETA = 42;          // o mesmo do painel e da página
const PREFIXO = "batismo-";         // external_reference = batismo-<id da inscrição>
const MINUTOS_VALIDADE = 60;        // link antigo não pode ser pago depois
const REMETENTE = "Igreja Fonte <batismo@mail.igrejaapostolicafonte.com.br>";   // domínio já verificado no Resend (carteirinha)

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const resposta = (status: number, corpo: Record<string, unknown>) =>
  new Response(JSON.stringify(corpo), { status, headers: { ...cors, "Content-Type": "application/json" } });
const soNumeros = (v: unknown) => String(v ?? "").replace(/\D/g, "");
const esc = (v: unknown) =>
  String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return resposta(405, { erro: "Use POST" });

  const token = Deno.env.get("MP_ACCESS_TOKEN");
  if (!token) return resposta(500, { erro: "MP_ACCESS_TOKEN não configurado" });
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const url = new URL(req.url);
  const corpo = await req.json().catch(() => ({} as Record<string, unknown>));

  // ---------- 2) aviso do Mercado Pago (API de Orders) ----------
  // Webhook do painel do MP, evento "Order (Mercado Pago)": {type:"order", data:{id}} ou ?type=order&data.id=…
  // Não confia no aviso: busca a order na API do MP com o nosso token antes de marcar pago.
  const tipoAviso = (corpo as { type?: string }).type ?? url.searchParams.get("type") ?? url.searchParams.get("topic");
  if (tipoAviso) {
    const orderId = (corpo as { data?: { id?: string } }).data?.id ?? url.searchParams.get("data.id") ?? url.searchParams.get("id");
    if (tipoAviso !== "order" || !orderId) return resposta(200, { ok: "ignorado" });

    const r = await fetch(`https://api.mercadopago.com/v1/orders/${orderId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!r.ok) {
      console.error(`batismo: MP devolveu ${r.status} ao consultar a order ${orderId}`);
      return resposta(500, { erro: "erro ao consultar a order" });   // o MP tenta de novo
    }
    const order = await r.json();
    const ref = String(order.external_reference ?? "");
    console.log(`batismo: order ${orderId} status=${order.status}/${order.status_detail} ref="${ref}" valor=${order.total_amount}`);
    if (!ref.startsWith(PREFIXO)) return resposta(200, { ok: "não é do batismo" });
    if (order.status !== "processed" || order.status_detail !== "accredited") return resposta(200, { ok: "não aprovado" });
    const pago = Number(order.total_paid_amount ?? order.total_amount);
    if (pago + 0.01 < VALOR_CAMISETA) {
      console.error(`batismo: valor pago ${pago} menor que ${VALOR_CAMISETA} (${ref})`);
      return resposta(200, { ok: "valor divergente" });
    }
    const id = ref.slice(PREFIXO.length);
    const { data, error } = await admin.from("inscricoes_batismo")
      .update({ pagamento_status: "aprovado", pagamento_id: String(orderId) })
      .eq("id", id).select("id");
    if (error) {
      console.error("batismo: erro ao marcar pago", error.message);
      return resposta(500, { erro: error.message });
    }
    if (!data?.length) console.error(`batismo: inscrição ${id} não encontrada (order ${orderId})`);
    return resposta(200, { ok: "pago" });
  }

  // ---------- 3) e-mail de confirmação da inscrição ----------
  // A página chama com {acao:"email", telefone, email} logo depois da inscrição.
  // Só vale para inscrição feita nos últimos 30 min e que ainda não tem e-mail: ninguém
  // consegue reenviar nem trocar o e-mail de uma inscrição antiga pelo site.
  if ((corpo as { acao?: string }).acao === "email") {
    const chaveResend = Deno.env.get("RESEND_API_KEY");
    if (!chaveResend) return resposta(500, { erro: "RESEND_API_KEY não configurada" });
    const email = String((corpo as { email?: string }).email ?? "").trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 200) return resposta(400, { erro: "E-mail inválido." });
    const tel = soNumeros((corpo as { telefone?: string }).telefone);
    if (tel.length < 10) return resposta(400, { erro: "Telefone inválido." });
    const desde = new Date(Date.now() - 30 * 60_000).toISOString();
    const { data: lista, error } = await admin.from("inscricoes_batismo")
      .select("id,nome,telefone,camiseta_opcao,camiseta_numero,pagamento_status,email")
      .gte("created_at", desde).order("created_at", { ascending: false }).limit(50);
    if (error) return resposta(500, { erro: error.message });
    const insc = (lista ?? []).find((i) => soNumeros(i.telefone).endsWith(tel.slice(-10)));
    if (!insc) return resposta(404, { erro: "Inscrição recente não encontrada." });
    if (insc.email) return resposta(409, { erro: "Esta inscrição já tem e-mail." });
    const { error: e2 } = await admin.from("inscricoes_batismo").update({ email }).eq("id", insc.id);
    if (e2) return resposta(500, { erro: e2.message });

    const { data: cfg } = await admin.from("site_config").select("valor").eq("chave", "batismo").maybeSingle();
    const v = (cfg?.valor ?? {}) as { data?: string; hora?: string };
    const quando = v.data ? `${v.data.split("-").reverse().join("/")}${v.hora ? " · " + v.hora : ""}` : "";
    const primeiroNome = String(insc.nome ?? "").trim().split(/\s+/)[0] ?? "";
    const pagar = insc.camiseta_opcao === "comprar" && insc.pagamento_status !== "aprovado";
    const linkPagar = `${SITE}/batismo.html?pagar=${insc.id}`;
    const p = (t: string) => `<p style="margin:0 0 12px">${t}</p>`;
    const html = `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head><body style="margin:0;background:#f2f4f4;padding:24px 12px">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center">
<table role="presentation" width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%;background:#ffffff;border-radius:18px">
  <tr><td style="background:#0a0a0b;border-radius:18px 18px 0 0;padding:22px"><img src="${SITE}/assets/fonte-logo.png" width="96" alt="Fonte" style="display:block;width:96px;height:auto"></td></tr>
  <tr><td style="font:16px/1.5 Arial,sans-serif;color:#15181a;padding:24px 24px 8px">
    ${p(`Shalom, ${esc(primeiroNome)}! 💧`)}
    ${p(`Sua inscrição para o <b>batismo</b> da Igreja Fonte${quando ? ` (${esc(quando)})` : ""} foi recebida.`)}
    ${p(insc.camiseta_opcao === "comprar"
      ? `Camiseta: <b>${esc(insc.camiseta_numero)}</b> — R$ ${VALOR_CAMISETA.toFixed(2).replace(".", ",")}.`
      : `Camiseta: você vai usar a sua (${esc(insc.camiseta_numero)}).`)}
    ${pagar ? p("Se ainda não pagou a camiseta, é só usar o botão abaixo (PIX ou cartão):") : ""}
  </td></tr>
  ${pagar ? `<tr><td align="center" style="padding:4px 24px 20px">
    <a href="${linkPagar}" style="display:inline-block;background:#4bb6b0;color:#06201e;font:700 15px Arial,sans-serif;text-decoration:none;padding:13px 22px;border-radius:12px">Pagar a camiseta</a>
    <div style="font:12px/1.5 Arial,sans-serif;color:#5b6469;padding-top:10px">Se o botão não abrir, copie este link: ${linkPagar}</div>
  </td></tr>` : ""}
  <tr><td style="font:13px/1.5 Arial,sans-serif;color:#5b6469;padding:8px 24px 24px">Qualquer dúvida, fale com a equipe do batismo. Nos vemos lá!</td></tr>
</table></td></tr></table></body></html>`;

    const envio = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${chaveResend}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: REMETENTE, to: [email], subject: "Inscrição no batismo · Igreja Fonte", html }),
    });
    if (!envio.ok) {
      console.error("batismo: Resend recusou o e-mail", (await envio.text()).slice(0, 300));
      return resposta(502, { erro: "Não foi possível enviar o e-mail." });
    }
    console.log(`batismo: e-mail de confirmação enviado (inscrição ${insc.id})`);
    return resposta(200, { ok: true });
  }

  // ---------- 1) criar o checkout ----------
  // {id} vem do link de cobrança que a equipe manda no WhatsApp (batismo.html?pagar=<id>);
  // {telefone} vem da própria página, logo depois da inscrição.
  const credito = (corpo as { tipo?: string }).tipo === "credito";
  const idPedido = String((corpo as { id?: string }).id ?? "").trim();
  const campos = "id,nome,telefone,camiseta_opcao,pagamento_status,created_at";
  let insc: { id: string; nome: string; pagamento_status: string | null } | undefined;
  if (idPedido) {
    if (!/^[0-9a-f-]{36}$/i.test(idPedido)) return resposta(400, { erro: "Link de pagamento inválido." });
    const { data, error } = await admin.from("inscricoes_batismo").select(campos)
      .eq("id", idPedido).eq("camiseta_opcao", "comprar").maybeSingle();
    if (error) return resposta(500, { erro: error.message });
    insc = data ?? undefined;
    if (!insc) return resposta(404, { erro: "Inscrição com compra de camiseta não encontrada." });
  } else {
    const tel = soNumeros((corpo as { telefone?: string }).telefone);
    if (tel.length < 10) return resposta(400, { erro: "Telefone inválido." });
    // a inscrição mais recente com compra de camiseta para este telefone (últimos 30 dias)
    const desde = new Date(Date.now() - 30 * 86_400_000).toISOString();
    const { data: lista, error } = await admin.from("inscricoes_batismo")
      .select(campos)
      .eq("camiseta_opcao", "comprar").gte("created_at", desde)
      .order("created_at", { ascending: false }).limit(200);
    if (error) return resposta(500, { erro: error.message });
    insc = (lista ?? []).find((i) => soNumeros(i.telefone).endsWith(tel.slice(-10)));
    if (!insc) return resposta(404, { erro: "Inscrição com compra de camiseta não encontrada para este telefone." });
  }
  if (insc.pagamento_status === "aprovado") return resposta(409, { erro: "A camiseta desta inscrição já está paga." });

  const volta = (pago: string) => `${SITE}/batismo.html?pago=${pago}`;
  const valor = VALOR_CAMISETA.toFixed(2);
  const basica = {
    type: "online",
    processing_mode: "manual",
    total_amount: valor,
    external_reference: PREFIXO + insc.id,
    description: "Camiseta do batismo",
    items: [{ title: "Camiseta do batismo — Igreja Fonte", unit_price: valor, quantity: 1 }],
  };
  const completa = {
    ...basica,
    expiration_time: `PT${MINUTOS_VALIDADE}M`,
    config: {
      online: { success_url: volta("true"), failure_url: volta("false"), pending_url: volta("pending"), auto_return: "approved" },
      payment_method: {
        max_installments: 1,
        not_allowed_types: credito ? ["ticket", "bank_transfer"] : ["credit_card", "debit_card", "ticket"],
      },
    },
  };
  const criar = (corpoOrder: Record<string, unknown>) => fetch("https://api.mercadopago.com/v1/orders", {
    method: "POST",
    headers: {
      "Content-Type": "application/json", accept: "application/json",
      Authorization: `Bearer ${token}`, "X-Idempotency-Key": crypto.randomUUID(),
    },
    body: JSON.stringify(corpoOrder),
  }).then((r) => r.json());

  let mp = await criar(completa);
  if (!mp.checkout_url) {
    // se o MP recusar alguma configuração (prazo, restrição de meio), tenta só com o essencial + volta ao site
    console.error("batismo: MP recusou a order completa", JSON.stringify(mp));
    mp = await criar({ ...basica, config: { online: completa.config.online } });
  }
  if (!mp.checkout_url) {
    console.error("batismo: MP recusou a order", JSON.stringify(mp));
    return resposta(500, { erro: "Não foi possível abrir o pagamento agora." });
  }
  await admin.from("inscricoes_batismo").update({ pagamento_status: "pendente" })
    .eq("id", insc.id).neq("pagamento_status", "aprovado");
  console.log(`batismo: order ${mp.id} para a inscrição ${insc.id} (${credito ? "cartão" : "pix"})`);
  return resposta(200, { init_point: mp.checkout_url });
});
