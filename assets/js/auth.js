const SUPABASE_URL="https://pcednpmjyfkuomfcmian.supabase.co";
const SUPABASE_PUBLISHABLE_KEY="sb_publishable_ERlBrySRotVM5jfLA1oukQ_Cg0gmgIp";
const USERNAME_LOGIN_URL=SUPABASE_URL+"/functions/v1/username-login";

const loginForm=document.getElementById("loginForm");
const usernameInput=document.getElementById("username");
const passwordInput=document.getElementById("password");
const passwordToggle=document.getElementById("toggle-password");
const loginButton=document.getElementById("btn-submit");
const loginButtonLabel=document.getElementById("btn-submit-label");
const loginError=document.getElementById("login-error");

function showError(title="Gagal masuk",message="Periksa nama pengguna dan kata sandi, lalu coba lagi."){
  loginError.querySelector("[data-error-title]").textContent=title;
  loginError.querySelector("[data-error-message]").textContent=message;
  loginError.classList.add("is-visible");
}
function hideError(){loginError.classList.remove("is-visible")}

passwordToggle.addEventListener("click",()=>{
  const isPassword=passwordInput.type==="password";
  passwordInput.type=isPassword?"text":"password";
  passwordToggle.setAttribute("aria-label",isPassword?"Sembunyikan kata sandi":"Tampilkan kata sandi");
  passwordToggle.querySelector("i").className=isPassword?"bi bi-eye-slash":"bi bi-eye";
});

loginForm.addEventListener("submit",async event=>{
  event.preventDefault();
  hideError();
  const username=usernameInput.value.trim();
  const password=passwordInput.value;
  if(!username||!password){
    showError("Data belum lengkap","Isi nama pengguna dan kata sandi untuk melanjutkan.");
    (!username?usernameInput:passwordInput).focus();
    return;
  }
  loginButton.disabled=true;
  loginButtonLabel.textContent="Memproses...";
  try{
    const response=await fetch(USERNAME_LOGIN_URL,{
      method:"POST",
      headers:{"Content-Type":"application/json","apikey":SUPABASE_PUBLISHABLE_KEY},
      body:JSON.stringify({username,password})
    });
    const data=await response.json().catch(()=>({}));
    if(!response.ok)throw new Error(data.error||"Nama pengguna atau kata sandi salah.");
    if(!data.access_token||!data.refresh_token||!data.user)throw new Error("Respons autentikasi dari server tidak valid.");
    sessionStorage.setItem("trcm_session",JSON.stringify(data));
    window.location.href="pages/dashboard.html";
  }catch(error){
    showError("Gagal masuk",error.message||"Periksa nama pengguna dan kata sandi, lalu coba lagi.");
  }finally{
    loginButton.disabled=false;
    loginButtonLabel.textContent="Masuk";
  }
});
