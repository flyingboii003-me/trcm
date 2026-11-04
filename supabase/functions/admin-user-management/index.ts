import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, PATCH, DELETE, OPTIONS"
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (!["POST", "PATCH", "DELETE"].includes(req.method)) {
    return json({ error: "Method tidak didukung." }, 405);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceRoleKey) return json({ error: "Konfigurasi function tidak lengkap." }, 500);

  const admin = createClient(url, serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const authorization = req.headers.get("Authorization") || "";
  const token = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
  if (!token) return json({ error: "Authorization diperlukan." }, 401);

  const { data: authData, error: authError } = await admin.auth.getUser(token);
  if (authError || !authData.user) return json({ error: "Sesi tidak valid." }, 401);

  const { data: caller } = await admin
    .from("users")
    .select("id,is_active,role_id,roles!inner(is_active)")
    .eq("id", authData.user.id)
    .single();

  if (!caller?.is_active || !caller.roles?.is_active || !caller.role_id) {
    return json({ error: "Profil aktif tidak ditemukan." }, 403);
  }

  const requiredPermission = req.method === "POST" ? "create" : req.method === "PATCH" ? "update" : "delete";
  const { data: rolePermissions, error: rolePermissionsError } = await admin
    .from("role_permissions")
    .select("resources!inner(key,is_active),permissions!inner(key)")
    .eq("role_id", caller.role_id);

  if (rolePermissionsError) {
    return json({ error: "Permission pengguna gagal diverifikasi." }, 500);
  }

  const isAllowed = (rolePermissions || []).some((entry: any) =>
    entry.resources?.key === "user_role" &&
    entry.resources?.is_active === true &&
    entry.permissions?.key === requiredPermission
  );

  if (!isAllowed) {
    return json({ error: "Anda tidak memiliki permission user_role." + requiredPermission + "." }, 403);
  }

  let body: Record<string, unknown> = {};
  try { body = await req.json(); } catch {}

  if (req.method === "POST") {
    const email = String(body.auth_email || "").trim().toLowerCase();
    const password = String(body.password || "");
    const fullName = String(body.full_name || "").trim();
    const username = String(body.username || "").trim();
    const roleId = String(body.role_id || "");
    const isActive = body.is_active !== false;

    if (!email || !password || !fullName || !username || !roleId) return json({ error: "Nama, username, email, password, dan role wajib diisi." }, 400);
    if (password.length < 8) return json({ error: "Password minimal 8 karakter." }, 400);

    const { data: role } = await admin.from("roles").select("id,key,is_active").eq("id", roleId).single();
    if (!role?.is_active) return json({ error: "Role tidak valid atau tidak aktif." }, 400);

    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email, password, email_confirm: true,
      user_metadata: { username, full_name: fullName }
    });
    if (createError || !created.user) return json({ error: createError?.message || "Akun Auth gagal dibuat." }, 400);

    const { data: profile, error: profileError } = await admin.from("users").insert({
      id: created.user.id, username, full_name: fullName, auth_email: email,
      role: role.key, role_id: role.id, is_active: isActive
    }).select("id,username,full_name,auth_email,role_id,is_active,created_at,updated_at,roles(id,key,name)").single();

    if (profileError) {
      await admin.auth.admin.deleteUser(created.user.id);
      return json({ error: "Akun Auth dibuat tetapi profil gagal disimpan: " + profileError.message }, 500);
    }
    return json({ user: profile }, 201);
  }

  const id = String(body.id || "");
  if (!id) return json({ error: "ID user wajib diisi." }, 400);
  if (id === authData.user.id) return json({ error: "Pengguna yang sedang login tidak dapat mengubah atau menghapus akun sendiri." }, 403);

  if (req.method === "PATCH") {
    const updates: Record<string, unknown> = {};
    if (body.full_name !== undefined) updates.full_name = String(body.full_name || "").trim();
    if (body.username !== undefined) updates.username = String(body.username || "").trim();
    if (body.auth_email !== undefined) updates.auth_email = String(body.auth_email || "").trim().toLowerCase();
    if (body.is_active !== undefined) updates.is_active = Boolean(body.is_active);
    if (body.role_id !== undefined) {
      const { data: role } = await admin.from("roles").select("id,key,is_active").eq("id", String(body.role_id)).single();
      if (!role?.is_active) return json({ error: "Role tidak valid atau tidak aktif." }, 400);
      updates.role_id = role.id;
      updates.role = role.key;
    }
    if (!Object.keys(updates).length) return json({ error: "Tidak ada perubahan." }, 400);

    const { data: profile, error: profileError } = await admin.from("users").update(updates).eq("id", id)
      .select("id,username,full_name,auth_email,role_id,is_active,created_at,updated_at,roles(id,key,name)").single();
    if (profileError || !profile) return json({ error: profileError?.message || "Profil user gagal diperbarui." }, 400);

    const authUpdates: Record<string, unknown> = {};
    if (updates.auth_email) authUpdates.email = updates.auth_email;
    if (updates.full_name !== undefined || updates.username !== undefined) {
      authUpdates.user_metadata = {};
      if (updates.full_name !== undefined) authUpdates.user_metadata.full_name = updates.full_name;
      if (updates.username !== undefined) authUpdates.user_metadata.username = updates.username;
    }
    if (Object.keys(authUpdates).length) {
      const { error } = await admin.auth.admin.updateUserById(id, authUpdates);
      if (error) return json({ error: "Profil tersimpan tetapi akun Auth gagal diperbarui: " + error.message }, 500);
    }
    return json({ user: profile });
  }

  if (req.method === "DELETE") {
    const { error } = await admin.from("users").delete().eq("id", id);
    if (error) return json({ error: error.message }, 400);
    const { error: authDeleteError } = await admin.auth.admin.deleteUser(id);
    if (authDeleteError) return json({ error: "Profil dihapus tetapi akun Auth gagal dihapus: " + authDeleteError.message }, 500);
    return json({ success: true });
  }

  return json({ error: "Method tidak didukung." }, 405);
});
