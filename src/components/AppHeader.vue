<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useLayoutStore } from '../stores/layout'
import { useAuthStore } from '../stores/auth'

const layout = useLayoutStore()
const auth = useAuthStore()
const router = useRouter()

const usuario = computed(() => auth.usuario)

const menuAberto = ref(false)

function toggleMenu() {
  menuAberto.value = !menuAberto.value
}

function fecharMenu() {
  menuAberto.value = false
}

async function fazerLogout() {
  await auth.logout()
  fecharMenu()
  router.push('/login')
}

function clicarFora(event) {
  if (!event.target.closest('.user-menu')) {
    fecharMenu()
  }
}

onMounted(() => {
  document.addEventListener('click', clicarFora)
})

onUnmounted(() => {
  document.removeEventListener('click', clicarFora)
})
</script>

<template>
  <header class="header">

    <div class="header-left">

      <button
        class="menu-button"
        @click.stop="layout.toggleSidebar()"
      >
        ☰
      </button>

      <div class="brand">

        <!-- depois colocaremos a logo -->
        <div class="logo-circle">
            <img
                src="/img/logo-ejc.png"
                alt="Logo EJC"
            >
        </div>

        <div class="brand-text">
          <h1>Sistema EJC</h1>
          <span>Gestão do Encontro de Jovens com Cristo</span>
        </div>

      </div>

    </div>

    <div class="user-menu">

      <button
        class="user-button"
        @click.stop="toggleMenu"
      >
        <div class="avatar">
            {{ usuario?.nome?.charAt(0) || '?' }}
        </div>

        <div class="user-info">
            <strong>{{ usuario?.nome || 'Carregando...' }}</strong>
            <small>{{ usuario?.perfil || '' }}</small>
        </div>

        <span class="arrow">▼</span>
      </button>

      <Transition name="fade">

        <div
          v-if="menuAberto"
          class="dropdown"
        >
          <button>Meu perfil</button>

          <button>Alterar senha</button>

          <hr>

          <button
            class="logout"
            @click="fazerLogout"
        >
            Sair
        </button>
        </div>

      </Transition>

    </div>

  </header>
</template>

<style scoped>

.header{
  height:74px;

  background:#fff;

  display:flex;
  align-items:center;
  justify-content:space-between;

  padding:0 28px;

  border-bottom:1px solid #e7edf3;

  box-shadow:0 3px 10px rgba(0,0,0,.04);

  position:sticky;
  top:0;
  z-index:100;
}

/* =======================
        ESQUERDA
======================= */

.header-left{
  display:flex;
  align-items:center;
  gap:18px;
}

.menu-button{
  width:44px;
  height:44px;

  border:none;

  border-radius:12px;

  background:#f2f5f9;

  color:#0b3558;

  font-size:22px;

  cursor:pointer;

  transition:.25s;
}

.menu-button:hover{
  background:#0b3558;
  color:white;
}

.brand{
  display:flex;
  align-items:center;
  gap:14px;
}

.logo-circle{

  width:50px;
  height:50px;

  border-radius:50%;

  background:white;

  display:flex;
  align-items:center;
  justify-content:center;

  box-shadow:0 4px 12px rgba(0,0,0,.08);

  overflow:hidden;
}

.logo-circle img{
  width:42px;
  height:42px;
  object-fit:contain;
}

.brand-text h1{
  margin:0;

  color:#0b3558;

  font-size:21px;

  font-weight:700;
}

.brand-text span{
  display:block;

  margin-top:3px;

  color:#7b8794;

  font-size:13px;
}

/* =======================
      USUÁRIO
======================= */

.user-menu{
  position:relative;
}

.user-button{

  display:flex;
  align-items:center;
  gap:12px;

  background:white;

  border:1px solid #e6edf3;

  border-radius:14px;

  padding:8px 12px;

  cursor:pointer;

  transition:.25s;
}

.user-button:hover{

  box-shadow:0 8px 20px rgba(0,0,0,.08);

  border-color:#d9e3ec;
}

.avatar{

  width:42px;
  height:42px;

  border-radius:50%;

  background:linear-gradient(135deg,#3f84ad,#0b3558);

  color:white;

  display:flex;
  align-items:center;
  justify-content:center;

  font-size:16px;
  font-weight:700;
}

.user-info{

  display:flex;
  flex-direction:column;
  align-items:flex-start;
}

.user-info strong{

  color:#17324d;

  font-size:14px;
}

.user-info small{

  color:#7b8794;

  font-size:12px;
}

.arrow{

  color:#6c7a89;

  font-size:11px;
}

/* =======================
      DROPDOWN
======================= */

.dropdown{

  position:absolute;

  top:58px;
  right:0;

  width:220px;

  background:white;

  border-radius:16px;

  overflow:hidden;

  border:1px solid #e8edf2;

  box-shadow:0 18px 35px rgba(0,0,0,.12);
}

.dropdown button{

  width:100%;

  padding:14px 18px;

  background:white;

  border:none;

  text-align:left;

  cursor:pointer;

  font-size:14px;

  transition:.2s;
}

.dropdown button:hover{

  background:#f5f8fb;
}

.dropdown hr{

  margin:0;

  border:none;

  border-top:1px solid #eceff3;
}

.logout{

  color:#d93025;

  font-weight:600;
}

/* =======================
      ANIMAÇÃO
======================= */

.fade-enter-active,
.fade-leave-active{
  transition:.2s;
}

.fade-enter-from,
.fade-leave-to{
  opacity:0;
  transform:translateY(-8px);
}

/* =======================
      RESPONSIVO
======================= */

@media (max-width:768px){

  .header{
    padding:0 16px;
  }

  .brand-text span{
    display:none;
  }

  .brand-text h1{
    font-size:18px;
  }

  .user-info,
  .arrow{
    display:none;
  }

}

</style>