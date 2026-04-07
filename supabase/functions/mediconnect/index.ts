/// <reference path="./deno-shim.d.ts" />
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * El runtime de Supabase puede pasar el pathname completo (`/functions/v1/mediconnect/...`)
 * o solo el sufijo bajo la función (`/mediconnect/...`). Hay que quitar ambos para que
 * el upstream reciba `/api/...` y no `/mediconnect/api/...` (404 en Express).
 */
function stripFunctionPath(pathname: string): string {
  const full = "/functions/v1/mediconnect";
  if (pathname === full) return "/";
  if (pathname.startsWith(full + "/")) {
    const rest = pathname.slice(full.length);
    return rest.startsWith("/") ? rest : "/" + rest;
  }

  const fn = "/mediconnect";
  if (pathname === fn) return "/";
  if (pathname.startsWith(fn + "/")) {
    const rest = pathname.slice(fn.length);
    return rest.startsWith("/") ? rest : "/" + rest;
  }

  return pathname;
}

Deno.serve(async (req: Request) => {
  const upstreamBase = (Deno.env.get("API_UPSTREAM") ?? "").trim().replace(/\/+$/, "");

  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET,POST,PATCH,PUT,DELETE,OPTIONS",
        "Access-Control-Allow-Headers":
          "Authorization, Content-Type, X-Client-Info, apikey, Prefer",
        "Access-Control-Max-Age": "86400",
      },
    });
  }

  if (!upstreamBase) {
    return new Response(
      JSON.stringify({
        error:
          "Falta el secreto API_UPSTREAM en Supabase (URL https del backend Node, p. ej. https://appmedicina-api.onrender.com).",
      }),
      {
        status: 503,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      },
    );
  }

  const inUrl = new URL(req.url);
  const path = stripFunctionPath(inUrl.pathname);
  const target = `${upstreamBase}${path}${inUrl.search}`;

  const headers = new Headers(req.headers);
  headers.delete("host");

  let body: ArrayBuffer | undefined;
  if (req.method !== "GET" && req.method !== "HEAD") {
    body = await req.arrayBuffer();
  }

  const upstreamRes = await fetch(target, {
    method: req.method,
    headers,
    body: body && body.byteLength ? body : undefined,
    redirect: "manual",
  });

  const out = new Headers(upstreamRes.headers);
  out.set("Access-Control-Allow-Origin", "*");

  return new Response(upstreamRes.body, {
    status: upstreamRes.status,
    headers: out,
  });
});
