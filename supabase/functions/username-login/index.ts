import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const { username, password } = await req.json();

    if (typeof username !== "string" || typeof password !== "string" ||
        !username.trim() || !password) {
      return new Response(JSON.stringify({ error: "Username dan password wajib diisi." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

    if (!supabaseUrl || !serviceRoleKey || !anonKey) {
      throw new Error("Supabase Auth environment belum lengkap.");
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const normalizedUsername = username.trim();

    const { data: profile, error: profileError } = await adminClient
      .from("users")
      .select("id, username, role, auth_email, is_active")
      .eq("username", normalizedUsername)
      .maybeSingle();

    if (profileError) {
      throw profileError;
    }

    if (!profile?.auth_email) {
      return new Response(JSON.stringify({ error: "Username atau password salah." }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (profile.is_active === false) {
      return new Response(JSON.stringify({
        error: "Akun Anda saat ini tidak aktif. Silakan hubungi administrator.",
        code: "ACCOUNT_INACTIVE",
      }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const authResponse = await fetch(
      `${supabaseUrl}/auth/v1/token?grant_type=password`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: anonKey,
        },
        body: JSON.stringify({
          email: profile.auth_email,
          password,
        }),
      },
    );

    const authData = await authResponse.json();

    if (!authResponse.ok) {
      return new Response(JSON.stringify({ error: "Username atau password salah." }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({
      access_token: authData.access_token,
      refresh_token: authData.refresh_token,
      expires_in: authData.expires_in,
      expires_at: authData.expires_at,
      token_type: authData.token_type,
      user: {
        id: profile.id,
        username: profile.username,
        role: profile.role,
      },
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("username-login error:", error);

    return new Response(JSON.stringify({
      error: "Terjadi kesalahan saat memproses login.",
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
