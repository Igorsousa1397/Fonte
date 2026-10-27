// Envia a carteirinha de membro por e-mail (Resend), chamada pelo painel ao validar o membro.
// Só um admin logado pode chamar. O membro precisa estar validado, ativo, com célula e e-mail.
//
// Segredos (Supabase → Edge Functions → Secrets):
//   RESEND_API_KEY  = a mesma chave re_… usada no SMTP do Resend
// SUPABASE_URL, SUPABASE_ANON_KEY e SUPABASE_SERVICE_ROLE_KEY já vêm prontas na função.

import { createClient } from "jsr:@supabase/supabase-js@2";

const SITE = "https://igrejaapostolicafonte.com.br";
const REMETENTE = "Igreja Fonte <carteirinha@mail.igrejaapostolicafonte.com.br>";
const SEM_CELULA = ["ainda não participo", "não participo de célula", "não pertenço a nenhuma célula", "não participo", "nao participo", "sem célula"];
const MESES = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"];

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const resposta = (status: number, corpo: Record<string, unknown>) =>
  new Response(JSON.stringify(corpo), { status, headers: { ...cors, "Content-Type": "application/json" } });

const esc = (v: unknown) =>
  String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return resposta(405, { erro: "Use POST" });

  const url = Deno.env.get("SUPABASE_URL")!;
  const chaveResend = Deno.env.get("RESEND_API_KEY");
  if (!chaveResend) return resposta(500, { erro: "RESEND_API_KEY não configurada" });

  // quem chamou é admin?
  const quem = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: { user } } = await quem.auth.getUser();
  if (!user) return resposta(401, { erro: "Faça login no painel" });
  const banco = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: perfil } = await banco.from("profiles").select("role").eq("id", user.id).maybeSingle();
  if (perfil?.role !== "admin") return resposta(403, { erro: "Sem permissão" });

  const { membro_id } = await req.json().catch(() => ({}));
  if (!membro_id) return resposta(400, { erro: "membro_id obrigatório" });

  const { data: m, error } = await banco.from("membros")
    .select("id,nome,email,celula,ministerio,data_nascimento,membro_desde,created_at,foto_url,ativo,validado,arquivado")
    .eq("id", membro_id).maybeSingle();
  if (error || !m) return resposta(404, { erro: "Membro não encontrado" });
  if (!m.email) return resposta(422, { erro: "O membro não tem e-mail no cadastro" });
  if (m.validado !== true) return resposta(422, { erro: "O membro ainda não foi validado" });
  if (m.ativo === false || m.arquivado === true) return resposta(422, { erro: "O membro está inativo" });
  const cel = (m.celula ?? "").trim();
  if (!cel || SEM_CELULA.includes(cel.toLowerCase())) return resposta(422, { erro: "O membro não faz parte de uma célula" });

  const partes = String(m.nome ?? "").trim().split(/\s+/);
  const primeiroNome = partes[0] ?? "";
  const nasc = m.data_nascimento ? String(m.data_nascimento).split("-").reverse().join("/") : "—";
  let desde = "—";
  if (m.membro_desde) { const [a, mes] = String(m.membro_desde).split("-"); desde = `${MESES[+mes - 1]} de ${a}`; }
  else if (m.created_at) { const d = new Date(m.created_at); desde = `${MESES[d.getMonth()]} de ${d.getFullYear()}`; }
  const ministerio = m.ministerio && m.ministerio !== "Não serve em nenhum" ? m.ministerio : "—";
  const cod = "FONTE-" + String(m.id).replace(/-/g, "").slice(0, 8).toUpperCase();
  const iniciais = partes.map((p) => p[0]).slice(0, 2).join("").toUpperCase();

  const foto = m.foto_url
    ? `<img src="${esc(m.foto_url)}" width="96" height="96" alt="" style="display:block;width:96px;height:96px;border-radius:14px;object-fit:cover;border:2px solid #4bb6b0">`
    : `<div style="width:96px;height:96px;border-radius:14px;background:#12312f;color:#7ad4cf;font:700 32px/96px Arial,sans-serif;text-align:center">${esc(iniciais)}</div>`;
  const linha = (k: string, v: string) =>
    `<tr><td style="padding:3px 0;color:#8b8b95;font:12px Arial,sans-serif;width:110px">${k}</td><td style="padding:3px 0;color:#f5f5f6;font:600 13px Arial,sans-serif">${esc(v)}</td></tr>`;

  const html = `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head><body style="margin:0;background:#f2f4f4;padding:24px 12px">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center">
<table role="presentation" width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%">
  <tr><td style="font:16px/1.5 Arial,sans-serif;color:#15181a;padding:0 4px 18px">
    <p style="margin:0 0 10px">Olá, ${esc(primeiroNome)}! 🙌</p>
    <p style="margin:0">Seu cadastro de membro da <b>Igreja Fonte</b> foi aprovado. Esta é a sua carteirinha:</p>
  </td></tr>
  <tr><td style="background:#0a0a0b;border-radius:18px;padding:22px">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
      <tr><td colspan="2" style="padding-bottom:16px"><img src="${SITE}/assets/fonte-logo.png" width="96" alt="Fonte" style="display:block;width:96px;height:auto"></td>
          <td align="right" style="padding-bottom:16px;color:#7ad4cf;font:700 11px Arial,sans-serif;letter-spacing:2px">MEMBRO</td></tr>
      <tr><td width="112" valign="top">${foto}</td>
          <td colspan="2" valign="top">
            <div style="color:#f5f5f6;font:700 20px/1.2 Arial,sans-serif;margin-bottom:2px">${esc(m.nome)}</div>
            <div style="color:#8b8b95;font:11px Arial,sans-serif;letter-spacing:1px;margin-bottom:10px">IGREJA APOSTÓLICA FONTE</div>
            <table role="presentation" cellpadding="0" cellspacing="0">
              ${linha("Célula", cel)}${linha("Ministério", ministerio)}${linha("Nascimento", nasc)}${linha("Membro desde", desde)}
            </table>
          </td></tr>
      <tr><td colspan="3" style="padding-top:16px;border-top:1px solid #2a2a31;color:#7ad4cf;font:700 13px monospace;letter-spacing:1px">${cod}
        <span style="color:#8b8b95;font:10px Arial,sans-serif;letter-spacing:0;float:right">Uso interno da igreja · sem valor como documento oficial</span></td></tr>
    </table>
  </td></tr>
  <tr><td align="center" style="padding:22px 0 8px">
    <a href="${SITE}/carteirinha.html" style="display:inline-block;background:#4bb6b0;color:#06201e;font:700 15px Arial,sans-serif;text-decoration:none;padding:13px 22px;border-radius:12px">Abrir minha carteirinha</a>
  </td></tr>
  <tr><td style="font:13px/1.5 Arial,sans-serif;color:#5b6469;padding:8px 4px;text-align:center">
    No site, entre com seu CPF e este e-mail. Você recebe um código para confirmar e pode salvar a carteirinha no celular.
  </td></tr>
</table></td></tr></table></body></html>`;

  const envio = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${chaveResend}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: REMETENTE, to: [m.email], subject: "Sua carteirinha de membro da Fonte", html }),
  });
  if (!envio.ok) {
    const det = await envio.text();
    return resposta(502, { erro: "O Resend recusou o envio", detalhe: det.slice(0, 300) });
  }
  return resposta(200, { ok: true, email: m.email });
});
