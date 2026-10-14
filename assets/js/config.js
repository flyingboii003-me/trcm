const SUPABASE_URL = "https://pcednpmjyfkuomfcmian.supabase.co";
const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_ERlBrySRotVM5jfLA1oukQ_Cg0gmgIp";

function getTrcmSession() {
  try {
    return JSON.parse(sessionStorage.getItem("trcm_session") || "null");
  } catch {
    return null;
  }
}

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, function (character) {
    return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[character];
  });
}
