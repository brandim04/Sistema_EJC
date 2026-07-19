import { createRouter, createWebHistory } from 'vue-router'

import VendasView from '../views/VendasView.vue'
import DashboardView from '../views/DashboardView.vue'
import PessoasView from '../views/PessoasView.vue'
import ProdutosView from '../views/ProdutosView.vue'
import RelatoriosView from '../views/RelatoriosView.vue'

const routes = [
  {
    path: '/',
    component: VendasView
  },
  {
    path: '/dashboard',
    component: DashboardView
  },
  {
    path: '/pessoas',
    component: PessoasView
  },
  {
    path: '/produtos',
    component: ProdutosView
  },
  {
    path: '/vendas',
    component: VendasView
  },
  {
    path: '/relatorios',
    component: RelatoriosView
  }
]

export default createRouter({
  history: createWebHistory(),
  routes
})