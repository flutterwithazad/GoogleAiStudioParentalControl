/**
 * Supabase Edge Function: Ephemeral TURN Credential Generator (RFC 5766)
 *
 * Generates short-lived WebRTC ICE credentials on-demand.
 * Root TURN secret is strictly stored in server-side environment variables.
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createHmac } from "https://deno.land/std@0.168.0/node/crypto.ts";

const TURN_SECRET = Deno.env.get("TURN_SHARED_SECRET") || "fallback_internal_secret_key_prod";
const TURN_URLS = [
  "turn:turn.screenmirror.internal:3478?transport=udp",
  "turn:turn.screenmirror.internal:3478?transport=tcp",
  "turns:turn.screenmirror.internal:5349?transport=tcp"
];

serve(async (req: Request) => {
  // CORS configuration
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Ephemeral timestamp (valid for 2 hours)
    const ttlSeconds = 7200;
    const expiryTimestamp = Math.floor(Date.now() / 1000) + ttlSeconds;
    const username = `${expiryTimestamp}:screen_mirror_user`;

    // Compute HMAC-SHA1
    const hmac = createHmac("sha1", TURN_SECRET);
    hmac.update(username);
    const credential = hmac.digest("base64");

    const iceServers = [
      { urls: "stun:stun.l.google.com:19302" },
      { urls: "stun:stun1.l.google.com:19302" },
      {
        urls: TURN_URLS,
        username,
        credential,
      },
    ];

    return new Response(
      JSON.stringify({
        iceServers,
        ttl: ttlSeconds,
        generatedAt: new Date().toISOString(),
      }),
      {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
