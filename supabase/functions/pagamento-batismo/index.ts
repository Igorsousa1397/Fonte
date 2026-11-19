// Pagamento da camiseta do batismo pelo Mercado Pago (mesmo modelo do app do encontro).
// Uma função só, com dois papéis:
//   1) a página batismo.html chama com {telefone} logo depois da inscrição, ou {id}
//      pelo link de cobrança do painel →
//      cria a preferência do Checkout Pro e devolve o link (o valor é definido aqui, nunca pelo site);
//   2) o Mercado Pago chama a mesma URL quando o pagamento muda (notification_url da preferência) →
//      confere status e valor na API do MP e marca inscricoes_batismo.pagamento_status = 'aprovado'.
//   3) {acao:"email", telefone, email} logo depois da inscrição → manda o e-mail de confirmação
//      com o link de pagamento da camiseta (batismo.html?pagar=<id>).
//   4) pagamento na própria página (Checkout Transparente, API de Payments):
//      {acao:"pix", id|telefone, cpf, email}  → cria o PIX e devolve o QR Code e o copia e cola;
//      {acao:"cartao", id|telefone, token, payment_method_id, issuer_id, cpf, email, device_id}
//        → cobra o cartão (o número nunca passa por aqui: a página manda só o token do Mercado Pago);
//      {acao:"status", id|telefone, pagamento_id} → diz se a camiseta já está paga (a página pergunta a cada poucos segundos).
// Usa a API de Preferences do Checkout Pro, como o app do encontro. Com a API de Orders o PIX não
// aparecia no checkout (só cartão), mesmo com chave Pix na conta. Avisos de orders antigas continuam aceitos.
//
// Publicar no Supabase → Edge Functions → pagamento-batismo, com "Verify JWT" DESLIGADO
// (o Mercado Pago não manda token).
// O aviso de pagamento vai pela notification_url de cada preferência (não depende do painel de Webhooks).
// O webhook do painel (evento "Order") pode ficar como está: só serve para orders criadas antes.
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
// "Maria da Silva" -> "Maria S.": a página mostra para a pessoa conferir que está pagando a inscrição certa,
// sem expor o nome completo de quem só digitou um telefone.
const nomeCurto = (n: unknown) => {
  const p = String(n ?? "").trim().split(/\s+/).filter(Boolean);
  if (!p.length) return "";
  const prim = p[0].charAt(0).toUpperCase() + p[0].slice(1).toLowerCase();
  return p.length > 1 ? `${prim} ${p[p.length - 1].charAt(0).toUpperCase()}.` : prim;
};
const cpfValido = (v: string) => {
  const c = soNumeros(v);
  if (c.length !== 11 || /^(\d)\1{10}$/.test(c)) return false;
  const dv = (n: number) => { let s = 0; for (let i = 0; i < n; i++) s += +c[i] * (n + 1 - i); const r = (s * 10) % 11; return r === 10 ? 0 : r; };
  return dv(9) === +c[9] && dv(10) === +c[10];
};
const emailValido = (v: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v) && v.length <= 200;
// motivo da recusa do cartão em português (status_detail do Mercado Pago)
const RECUSA: Record<string, string> = {
  cc_rejected_bad_filled_card_number: "Confira o número do cartão.",
  cc_rejected_bad_filled_date: "Confira a validade do cartão.",
  cc_rejected_bad_filled_security_code: "Confira o código de segurança do cartão.",
  cc_rejected_bad_filled_other: "Confira os dados do cartão.",
  cc_rejected_insufficient_amount: "O cartão não tem limite ou saldo suficiente.",
  cc_rejected_call_for_authorize: "O banco pediu para você autorizar este pagamento. Ligue para o banco e tente de novo.",
  cc_rejected_card_disabled: "Este cartão está bloqueado ou não foi ativado. Fale com o seu banco.",
  cc_rejected_duplicated_payment: "Já existe um pagamento igual a este. Espere alguns minutos antes de tentar de novo.",
  cc_rejected_high_risk: "O pagamento foi recusado pela análise de segurança. Tente com PIX ou com outro cartão.",
  cc_rejected_max_attempts: "Você chegou ao limite de tentativas com este cartão. Use outro cartão ou PIX.",
  cc_rejected_blacklist: "O pagamento não pôde ser feito com este cartão. Use outro cartão ou PIX.",
  cc_rejected_invalid_installments: "O cartão não aceita esse número de parcelas.",
  cc_rejected_card_type_not_allowed: "Este tipo de cartão não é aceito. Use outro cartão ou PIX.",
};
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

  // ---------- 2) aviso do Mercado Pago ----------
  // notification_url da preferência: {type:"payment", data:{id}} ou ?type=payment&data.id=… ou IPN ?topic=payment&id=…
  // Orders antigas: {type:"order", data:{id}}. Não confia no aviso: busca na API do MP com o nosso token.
  const tipoAviso = (corpo as { type?: string }).type ?? url.searchParams.get("type") ?? url.searchParams.get("topic");
  if (tipoAviso) {
    const idAviso = (corpo as { data?: { id?: string } }).data?.id ?? url.searchParams.get("data.id") ?? url.searchParams.get("id");
    if ((tipoAviso !== "payment" && tipoAviso !== "order") || !idAviso) return resposta(200, { ok: "ignorado" });

    const ehOrder = tipoAviso === "order";
    const r = await fetch(`https://api.mercadopago.com/v1/${ehOrder ? "orders" : "payments"}/${idAviso}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!r.ok) {
      console.error(`batismo: MP devolveu ${r.status} ao consultar ${tipoAviso} ${idAviso}`);
      return resposta(500, { erro: "erro ao consultar o pagamento" });   // o MP tenta de novo
    }
    const mpObj = await r.json();
    const ref = String(mpObj.external_reference ?? "");
    const aprovado = ehOrder
      ? mpObj.status === "processed" && mpObj.status_detail === "accredited"
      : mpObj.status === "approved";
    const pago = Number(ehOrder ? (mpObj.total_paid_amount ?? mpObj.total_amount) : mpObj.transaction_amount);
    console.log(`batismo: ${tipoAviso} ${idAviso} status=${mpObj.status}/${mpObj.status_detail} ` +
      `meio=${mpObj.payment_method_id ?? "-"} ref="${ref}" valor=${pago}`);
    if (!ref.startsWith(PREFIXO)) return resposta(200, { ok: "não é do batismo" });
    if (!aprovado) return resposta(200, { ok: "não aprovado" });
    if (!(pago + 0.01 >= VALOR_CAMISETA)) {
      console.error(`batismo: valor pago ${pago} menor que ${VALOR_CAMISETA} (${ref})`);
      return resposta(200, { ok: "valor divergente" });
    }
    const id = ref.slice(PREFIXO.length);
    const { data, error } = await admin.from("inscricoes_batismo")
      .update({ pagamento_status: "aprovado", pagamento_id: String(idAviso) })
      .eq("id", id).select("id");
    if (error) {
      console.error("batismo: erro ao marcar pago", error.message);
      return resposta(500, { erro: error.message });
    }
    if (!data?.length) console.error(`batismo: inscrição ${id} não encontrada (${tipoAviso} ${idAviso})`);
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

  // ---------- inscrição que vai pagar ----------
  // {id} vem do link de cobrança que a equipe manda no WhatsApp (batismo.html?pagar=<id>);
  // {telefone} vem da própria página, logo depois da inscrição.
  type Insc = { id: string; nome: string; telefone: string | null; email: string | null; pagamento_status: string | null };
  const acharInscricao = async (): Promise<Insc | Response> => {
    const idPedido = String((corpo as { id?: string }).id ?? "").trim();
    const campos = "id,nome,telefone,email,camiseta_opcao,pagamento_status,created_at";
    if (idPedido) {
      if (!/^[0-9a-f-]{36}$/i.test(idPedido)) return resposta(400, { erro: "Link de pagamento inválido." });
      const { data, error } = await admin.from("inscricoes_batismo").select(campos)
        .eq("id", idPedido).eq("camiseta_opcao", "comprar").maybeSingle();
      if (error) return resposta(500, { erro: error.message });
      return data ?? resposta(404, { erro: "Inscrição com compra de camiseta não encontrada." });
    }
    const tel = soNumeros((corpo as { telefone?: string }).telefone);
    if (tel.length < 10) return resposta(400, { erro: "Telefone inválido." });
    // a inscrição mais recente com compra de camiseta para este telefone (últimos 60 dias)
    const desde = new Date(Date.now() - 60 * 86_400_000).toISOString();
    const { data: lista, error } = await admin.from("inscricoes_batismo")
      .select(campos)
      .eq("camiseta_opcao", "comprar").gte("created_at", desde)
      .order("created_at", { ascending: false }).limit(200);
    if (error) return resposta(500, { erro: error.message });
    return (lista ?? []).find((i) => soNumeros(i.telefone).endsWith(tel.slice(-10)))
      ?? resposta(404, { erro: "Inscrição com compra de camiseta não encontrada para este telefone." });
  };
  const achou = await acharInscricao();
  if (achou instanceof Response) return achou;
  const insc = achou;
  const marcarPago = async (pagamentoId: string) => {
    const { error } = await admin.from("inscricoes_batismo")
      .update({ pagamento_status: "aprovado", pagamento_id: pagamentoId }).eq("id", insc.id);
    if (error) console.error("batismo: erro ao marcar pago", error.message);
  };
  const acao = String((corpo as { acao?: string }).acao ?? "");

  // ---------- 4c) a página pergunta se já pagou ----------
  if (acao === "status") {
    const ok = (o: Record<string, unknown>) => resposta(200, { ...o, nome: nomeCurto(insc.nome) });
    if (insc.pagamento_status === "aprovado") return ok({ pago: true });
    // se o aviso do Mercado Pago ainda não chegou, confere direto o pagamento que esta página criou
    const pid = soNumeros((corpo as { pagamento_id?: string }).pagamento_id);
    if (pid) {
      const r = await fetch(`https://api.mercadopago.com/v1/payments/${pid}`, { headers: { Authorization: `Bearer ${token}` } });
      if (r.ok) {
        const pg = await r.json();
        if (pg.external_reference !== PREFIXO + insc.id) return ok({ pago: false });   // pagamento de outra inscrição
        if (pg.status === "approved" && Number(pg.transaction_amount) + 0.01 >= VALOR_CAMISETA) {
          await marcarPago(pid);
          return ok({ pago: true });
        }
        return ok({ pago: false, status: pg.status });
      }
    }
    return ok({ pago: false });
  }

  if (insc.pagamento_status === "aprovado") return resposta(409, { erro: "A camiseta desta inscrição já está paga." });

  // ---------- 4a/4b) PIX e cartão na própria página ----------
  if (acao === "pix" || acao === "cartao") {
    const cpf = soNumeros((corpo as { cpf?: string }).cpf);
    if (!cpfValido(cpf)) return resposta(400, { erro: "Confira o CPF." });
    const email = String((corpo as { email?: string }).email ?? insc.email ?? "").trim().toLowerCase();
    if (!emailValido(email)) return resposta(400, { erro: "Informe um e-mail válido." });
    const partes = String(insc.nome ?? "").trim().split(/\s+/).filter(Boolean);
    const payer: Record<string, unknown> = {
      email, identification: { type: "CPF", number: cpf },
      ...(partes.length ? { first_name: partes[0] } : {}),
      ...(partes.length > 1 ? { last_name: partes.slice(1).join(" ") } : {}),
    };
    const base: Record<string, unknown> = {
      transaction_amount: VALOR_CAMISETA,
      description: "Camiseta do batismo - Igreja Fonte",
      external_reference: PREFIXO + insc.id,
      notification_url: `${Deno.env.get("SUPABASE_URL")}/functions/v1/pagamento-batismo`,
      statement_descriptor: "IGR FONTE",
      payer,
      additional_info: {
        items: [{ id: "camiseta-batismo", title: "Camiseta do batismo", description: "Camiseta do batismo da Igreja Fonte",
          category_id: "fashion", quantity: 1, unit_price: VALOR_CAMISETA }],
        payer: { first_name: partes[0] ?? "", last_name: partes.slice(1).join(" ") },
      },
    };
    let corpoPg: Record<string, unknown>;
    const headers: Record<string, string> = {
      "Content-Type": "application/json", Authorization: `Bearer ${token}`, "X-Idempotency-Key": crypto.randomUUID(),
    };
    if (acao === "pix") {
      corpoPg = { ...base, payment_method_id: "pix", date_of_expiration: new Date(Date.now() + MINUTOS_VALIDADE * 60_000).toISOString() };
    } else {
      const c = corpo as { token?: string; payment_method_id?: string; issuer_id?: string | number; device_id?: string };
      if (!c.token || !c.payment_method_id) return resposta(400, { erro: "Confira os dados do cartão." });
      corpoPg = { ...base, token: String(c.token), payment_method_id: String(c.payment_method_id), installments: 1,
        ...(c.issuer_id ? { issuer_id: Number(c.issuer_id) } : {}), binary_mode: true, capture: true };
      if (c.device_id) headers["X-meli-session-id"] = String(c.device_id).slice(0, 200);   // ajuda o antifraude
    }
    const r = await fetch("https://api.mercadopago.com/v1/payments", { method: "POST", headers, body: JSON.stringify(corpoPg) });
    const pg = await r.json().catch(() => ({}));
    if (!r.ok || !pg.id) {
      console.error(`batismo: MP recusou o ${acao} (${r.status})`, JSON.stringify(pg).slice(0, 500));
      const semPix = acao === "pix" && /key|chave|qr/i.test(JSON.stringify(pg));
      return resposta(502, { erro: semPix
        ? "O PIX não está disponível agora. Pague com cartão ou fale com a equipe do batismo."
        : acao === "pix" ? "Não foi possível gerar o PIX agora. Tente de novo em instantes."
        : "Não foi possível processar o cartão agora. Confira os dados e tente de novo." });
    }
    console.log(`batismo: ${acao} ${pg.id} status=${pg.status}/${pg.status_detail} inscrição ${insc.id}`);
    await admin.from("inscricoes_batismo").update({ pagamento_status: "pendente", pagamento_id: String(pg.id) })
      .eq("id", insc.id).neq("pagamento_status", "aprovado");
    if (acao === "pix") {
      const t = pg.point_of_interaction?.transaction_data ?? {};
      if (!t.qr_code) return resposta(502, { erro: "Não foi possível gerar o PIX agora. Tente de novo em instantes." });
      return resposta(200, { pagamento_id: String(pg.id), qr_code: t.qr_code, qr_code_base64: t.qr_code_base64, ticket_url: t.ticket_url,
        expira_em: pg.date_of_expiration });
    }
    if (pg.status === "approved") { await marcarPago(String(pg.id)); return resposta(200, { pago: true, pagamento_id: String(pg.id) }); }
    if (pg.status === "in_process" || pg.status === "pending")
      return resposta(200, { pago: false, em_analise: true, pagamento_id: String(pg.id) });
    return resposta(200, { pago: false, recusado: true,
      motivo: RECUSA[pg.status_detail] ?? "O banco recusou o pagamento. Tente outro cartão ou pague com PIX." });
  }

  // ---------- 1) checkout no site do Mercado Pago (opção reserva) ----------
  const volta = (pago: string) => `${SITE}/batismo.html?pago=${pago}`;
  // Dados de quem paga: sem eles o antifraude do MP recusa muito cartão (high_risk).
  const partesNome = String(insc.nome ?? "").trim().split(/\s+/).filter(Boolean);
  const telPagador = soNumeros(insc.telefone).replace(/^55(?=\d{10,11}$)/, "");
  const emailPagador = String(insc.email ?? "").trim().toLowerCase();
  const payer: Record<string, unknown> = {};
  if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailPagador)) payer.email = emailPagador;
  if (partesNome.length) payer.name = partesNome[0];
  if (partesNome.length > 1) payer.surname = partesNome.slice(1).join(" ");
  if (telPagador.length >= 10) payer.phone = { area_code: telPagador.slice(0, 2), number: telPagador.slice(2) };

  const agora = Date.now();
  const basica = {
    items: [{
      id: "camiseta-batismo", title: "Camiseta do batismo - Igreja Fonte", description: "Camiseta do batismo da Igreja Fonte",
      category_id: "fashion", quantity: 1, unit_price: VALOR_CAMISETA, currency_id: "BRL",
    }],
    ...(Object.keys(payer).length ? { payer } : {}),
    external_reference: PREFIXO + insc.id,
    back_urls: { success: volta("true"), failure: volta("false"), pending: volta("pending") },
    auto_return: "approved",
    notification_url: `${Deno.env.get("SUPABASE_URL")}/functions/v1/pagamento-batismo`,
  };
  const completa = {
    ...basica,
    statement_descriptor: "IGR FONTE",   // nome na fatura do cartão
    expires: true,                       // link antigo não pode ser pago depois
    expiration_date_from: new Date(agora - 60_000).toISOString(),
    expiration_date_to: new Date(agora + MINUTOS_VALIDADE * 60_000).toISOString(),
    // PIX, crédito e débito no mesmo checkout; boleto fica fora (o link vale 1 hora)
    payment_methods: { excluded_payment_types: [{ id: "ticket" }], installments: 1 },
  };
  const criar = (pref: Record<string, unknown>) => fetch("https://api.mercadopago.com/checkout/preferences", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}`, "X-Idempotency-Key": crypto.randomUUID() },
    body: JSON.stringify(pref),
  }).then((r) => r.json());

  let mp = await criar(completa);
  if (!mp.init_point) {
    // se o MP recusar alguma configuração (prazo, restrição de meio), tenta só com o essencial
    console.error("batismo: MP recusou a preferência completa", JSON.stringify(mp));
    mp = await criar(basica);
  }
  if (!mp.init_point) {
    console.error("batismo: MP recusou a preferência", JSON.stringify(mp));
    return resposta(500, { erro: "Não foi possível abrir o pagamento agora." });
  }
  await admin.from("inscricoes_batismo").update({ pagamento_status: "pendente" })
    .eq("id", insc.id).neq("pagamento_status", "aprovado");
  console.log(`batismo: preferência ${mp.id} para a inscrição ${insc.id}`);
  return resposta(200, { init_point: mp.init_point });
});
