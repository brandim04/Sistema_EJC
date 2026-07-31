import { createRouter, createWebHistory } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'

import LoginView from '../views/LoginView.vue'
import VendasView from '../views/VendasView.vue'
import DashboardView from '../views/DashboardView.vue'
import PessoasView from '../views/PessoasView.vue'
import ProdutosView from '../views/ProdutosView.vue'
import UsuariosView from '../views/UsuariosView.vue'
import RelatoriosView from '../views/RelatoriosView.vue'

const routes = [
  {
    path: '/login',
    component: LoginView
  },
  {
    path: '/',
    component: VendasView,
    meta: {
      requiresAuth: true,
      roles: ['ADMIN', 'VENDEDOR']
    }
  },
  {
    path: '/dashboard',
    component: DashboardView,
    meta: {
      requiresAuth: true,
      roles: ['ADMIN']
    }
  },
  {
    path: '/pessoas',
    component: PessoasView,
    meta: {
      requiresAuth: true,
      roles: ['ADMIN', 'VENDEDOR']
    }
  },
  {
    path: '/produtos',
    component: ProdutosView,
    meta: {
      requiresAuth: true,
      roles: ['ADMIN', 'VENDEDOR']
    }
  },
  {
    path: '/usuarios',
    component: UsuariosView,
    meta: {
      requiresAuth: true,
      roles: ['ADMIN']
    }
  },
  {
    path: '/vendas',
    component: VendasView,
    meta: {
      requiresAuth: true,
      roles: ['ADMIN', 'VENDEDOR']
    }
  },
  {
    path: '/relatorios',
    component: RelatoriosView,
    meta: {
      requiresAuth: true,
      roles: ['ADMIN']
    }
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()

  const {
    data: { session }
  } = await supabase.auth.getSession()

  // Não está logado
  if (!session && to.path !== '/login') {
    return '/login'
  }

  // Já está logado e tentou acessar o login
  if (session && to.path === '/login') {
    return '/'
  }

  // Carrega a sessão e o perfil
  if (session) {
    await auth.carregarSessao()
  }

  // Usuário não encontrado na tabela
  if (session && !auth.usuario) {
    await supabase.auth.signOut()
    return '/login'
  }

  // Usuário desativado
  if (session && auth.usuario.ativo === false) {
    await supabase.auth.signOut()
    return '/login'
  }

  // Verifica permissão de acesso
  const roles = to.meta.roles

  if (roles && !roles.includes(auth.usuario.perfil)) {
    return '/'
  }
})

export default router