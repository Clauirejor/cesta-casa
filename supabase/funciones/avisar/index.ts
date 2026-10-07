// Cesta Casa · función «avisar»: manda un aviso push a los móviles de la casa (menos al de quien hace el cambio).
// Se pega en Supabase → Edge Functions → Deploy a new function → Via Editor, con el nombre: avisar
// Necesita estos secretos (Edge Functions → Secrets): VAPID_PUBLIC y VAPID_PRIVATE.
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (o: unknown, status = 200) =>
  new Response(JSON.stringify(o), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    // Actúa con los permisos de quien llama (vale con las claves nuevas y las antiguas de Supabase)
    const auth = req.headers.get("Authorization") || "";
    const apikey = req.headers.get("apikey") || Deno.env.get("SUPABASE_ANON_KEY") || "";
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, apikey, { global: { headers: { Authorization: auth } } });
    const token = auth.replace(/^Bearer\s+/i, "");
    const { data: { user }, error } = await admin.auth.getUser(token);
    if (error || !user) return json({ error: "sin sesión" }, 401);

    const { hogar_id, titulo, texto } = await req.json();
    // solo puede avisar quien es de esa casa
    const { data: yo } = await admin.from("miembros").select("id").eq("hogar_id", hogar_id).eq("user_id", user.id).maybeSingle();
    if (!yo) return json({ error: "no eres de esta casa" }, 403);

    const { data: subs } = await admin.from("push_subs").select("*").eq("hogar_id", hogar_id).neq("user_id", user.id);
    webpush.setVapidDetails("https://clauirejor.github.io/cesta-casa/", Deno.env.get("VAPID_PUBLIC")!, Deno.env.get("VAPID_PRIVATE")!);
    const payload = JSON.stringify({ title: String(titulo || "Cesta Casa").slice(0, 120), body: String(texto || "").slice(0, 300), url: "./#compra" });

    let enviados = 0;
    const caducadas: string[] = [];
    await Promise.all((subs || []).map(async (s) => {
      try {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 43200 });
        enviados++;
      } catch (e) {
        const code = (e as { statusCode?: number }).statusCode;
        if (code === 404 || code === 410) caducadas.push(s.id); // el móvil ya no acepta avisos: se borra
      }
    }));
    if (caducadas.length) await admin.from("push_subs").delete().in("id", caducadas);
    return json({ enviados, moviles: (subs || []).length });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
