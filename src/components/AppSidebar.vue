<script setup>
import { useRoute } from 'vue-router'
import { useLayoutStore } from '../stores/layout'
import { useAuthStore } from '../stores/auth'

const route = useRoute()
const layout = useLayoutStore()
const auth = useAuthStore()

const menu = [
  {
    titulo: 'Principal',
    itens: [
      {
        nome: 'Vendas',
        rota: '/',
        perfis: ['ADMIN', 'VENDEDOR']
      }
    ]
  },

  {
    titulo: 'Gestão',
    itens: [
      {
        nome: 'Dashboard',
        rota: '/dashboard',
        perfis: ['ADMIN']
      },
      {
        nome: 'Relatórios',
        rota: '/relatorios',
        perfis: ['ADMIN']
      }
    ]
  },

  {
    titulo: 'Cadastros',
    itens: [
      {
        nome: 'Pessoas',
        rota: '/pessoas',
        perfis: ['ADMIN', 'VENDEDOR']
      },
      {
        nome: 'Produtos',
        rota: '/produtos',
        perfis: ['ADMIN', 'VENDEDOR']
      },
      {
        nome: 'Usuários',
        rota: '/usuarios',
        perfis: ['ADMIN']
      }
    ]
  }
]

function fecharNoMobile() {
  if (window.innerWidth <= 768 && layout.sidebarOpen) {
    layout.toggleSidebar()
  }
}
</script>

<template>
  <aside
    class="sidebar"
    :class="{ closed: !layout.sidebarOpen }"
  >

    <!-- Logo -->

    <div class="sidebar-title">
        <h2>MENU</h2>
    </div>

    <!-- Menu -->

    <nav class="navigation">

      <section
        v-for="grupo in menu"
        :key="grupo.titulo"
        class="group"
      >

        <h4>{{ grupo.titulo }}</h4>

        <RouterLink
  v-for="item in grupo.itens.filter(i => i.perfis.includes(auth.usuario?.perfil))"
  :key="item.rota"
  :to="item.rota"
  class="link"
  :class="{ active: route.path === item.rota }"
  @click="fecharNoMobile"
>
  {{ item.nome }}
</RouterLink>

      </section>

    </nav>

    <!-- Card do Tema -->

    <div class="theme-card">

      <span>XI EJC PSS</span>

      <h2>
        FAZ DO MEU NÃO
        <br>
        UM EIS-ME AQUI!
      </h2>

      <div class="gold-line"></div>

      <p class="theme-verse">
        “Se alguém está em Cristo, é uma nova criatura.”
        <strong>2 Coríntios 5,17</strong>
      </p>

    </div>

    <!-- Rodapé -->

    <div class="sidebar-illustration">

      <div class="halo"></div>

      <div class="clouds"></div>

    </div>

  </aside>
</template>

<style scoped>

.sidebar{
  position: sticky;
  top: 0;

  width:300px;
  min-width:300px;
  max-width:300px;

  height:100vh;

  display:flex;
  flex-direction:column;

  overflow:hidden;

  background:
    radial-gradient(circle at bottom, rgba(255,255,255,.30), transparent 30%),
    linear-gradient(180deg,#171715 0%,#10100f 56%,#080808 100%);
}

.sidebar.closed{
  width:0;
  min-width:0;
  overflow:hidden;
}

/* =======================
        LOGO
======================= */

.sidebar-title{
  padding:24px 20px 14px;

  border-bottom:1px solid rgba(255,255,255,.15);

  margin-bottom:10px;
}

.sidebar-title h2{
  margin:0;

  color:white;

  font-size:20px;

  font-weight:700;

  letter-spacing:1px;
}

/* =======================
        MENU
======================= */

.navigation{
  flex:1;
  padding:10px 16px;
  position:relative;
  z-index:2;
}

.group{
  margin-bottom:16px;
}

.group h4{
  margin:0 8px 8px;

  color:rgba(255,255,255,.9);

  font-size:12px;

  font-weight:700;

  letter-spacing:1px;

  text-transform:uppercase;
}

.link{
  display:flex;
  align-items:center;

  margin-bottom:8px;

  padding:11px 16px;

  background:white;

  color:#151515;

  text-decoration:none;

  border-radius:12px;

  font-size:15px;

  font-weight:600;

  box-shadow:0 4px 10px rgba(0,0,0,.08);

  transition:.25s;
}

.link:hover{
  transform:translateX(5px);
  background:#ffffff;
}

.link.active{
  background:white;

  border-left:4px solid #fdb52e;

  padding-left:12px;

  font-weight:700;
}

/* =======================
      CARD DO TEMA
======================= */

.theme-card{
  margin:10px 16px 90px;

  padding-top:14px;

  border-top:1px solid rgba(255,255,255,.25);

  position:relative;

  z-index:2;
}

.theme-card span{
  display:block;

  margin-bottom:8px;

  color:#fdb52e;

  font-size:12px;

  font-weight:800;

  letter-spacing:1px;
}

.theme-card h2{
  margin:0;

  color:#f3ead0;

  font-size:20px;

  line-height:1.15;

  font-weight:900;
}

.gold-line{
  width:55px;

  height:3px;

  margin:14px 0;

  background:#fdb52e;

  border-radius:999px;
}

.theme-card p{
  margin:0;

  color:#ddd6c5;

  font-size:13px;

  line-height:1.5;

  font-weight:500;
}

.theme-verse strong{
  display:block;
  margin-top:5px;
  color:#fdb52e;
  font-size:11px;
}

/* =======================
      ILUSTRAÇÃO
======================= */

.sidebar-illustration{
  position:absolute;

  left:0;
  right:0;
  bottom:-5px;

  height:130px;

  opacity:.35;

  pointer-events:none;
}

.halo{
  width:100px;
  height:100px;

  margin:18px auto 0;

  border:2px solid #fdb52e;

  border-radius:50%;
}

.clouds{
  position:absolute;

  left:-20px;
  right:-20px;

  bottom:0;

  height:70px;

  background:
    radial-gradient(circle at 20% 60%, white 0 20px, transparent 21px),
    radial-gradient(circle at 40% 40%, white 0 28px, transparent 29px),
    radial-gradient(circle at 60% 55%, white 0 22px, transparent 23px),
    radial-gradient(circle at 80% 40%, white 0 30px, transparent 31px);
}

/* =======================
        MOBILE
======================= */

@media (max-width:768px){

  .sidebar{
    position:fixed;
    top:0;
    left:0;
    z-index:999;
    height:100vh;

    width:280px;
    min-width:280px;
    max-width:85vw;
  }

  .sidebar.closed{
    transform:translateX(-100%);
  }

}

</style>
