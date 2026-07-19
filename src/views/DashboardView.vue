<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { useToast } from 'vue-toastification'

const toast = useToast()

function sucesso(msg) {
  toast.clear()
  toast.success(msg)
}

function erro(msg) {
  toast.clear()
  toast.error(msg)
}

/* ==========================
   DADOS
========================== */

const pessoas = ref([])
const vendas = ref([])
const pagamentos = ref([])
const itensVenda = ref([])

const loading = ref(false)

/* ==========================
   KPIs
========================== */

const totalVendido = ref(0)
const totalRecebido = ref(0)
const saldoPendente = ref(0)
const pessoasPendentes = ref(0)

const vendasHoje = ref(0)
const arrecadadoHoje = ref(0)
const compradoresHoje = ref(0)
const ticketMedio = ref(0)

/* ==========================
   RANKINGS
========================== */

const produtosMaisVendidos = ref([])
const rankingCirculos = ref([])
const rankingEquipes = ref([])
const ultimasVendas = ref([])

/* ==========================
   CARREGAR DADOS
========================== */

async function carregarDashboard() {

  loading.value = true

  const [
    pessoasResult,
    vendasResult,
    pagamentosResult,
    itensResult
  ] = await Promise.all([

    supabase
      .from('pessoas')
      .select(`
        *,
        circulos(nome),
        equipes(nome)
      `),

    supabase
      .from('vendas')
      .select(`
        *,
        pessoas(
          id,
          nome,
          tipo,
          circulos(nome),
          equipes(nome)
        )
      `)
      .order('created_at', {
        ascending: false
      }),

    supabase
      .from('pagamentos')
      .select('*'),

    supabase
      .from('itens_venda')
      .select(`
        *,
        produtos(
          nome
        )
      `)

  ])

  pessoas.value = pessoasResult.data || []
  vendas.value = vendasResult.data || []
  pagamentos.value = pagamentosResult.data || []
  itensVenda.value = itensResult.data || []

  calcularKPIs()
  calcularIndicadoresHoje()
  calcularProdutosMaisVendidos()
  calcularRankingCirculos()
  calcularRankingEquipes()
  carregarUltimas()

  loading.value = false

}

/* ==========================
   KPIs
========================== */

function calcularKPIs() {

  totalVendido.value =
    vendas.value.reduce(
      (total, venda) =>
        total + Number(venda.valor_total || 0),
      0
    )

  totalRecebido.value =
    pagamentos.value.reduce(
      (total, pagamento) =>
        total + Number(pagamento.valor || 0),
      0
    )

  saldoPendente.value =
    pessoas.value.reduce(
      (total, pessoa) =>
        total + Number(pessoa.saldo_pendente || 0),
      0
    )

  pessoasPendentes.value =
    pessoas.value.filter(
      pessoa => Number(pessoa.saldo_pendente) > 0
    ).length

}

/* ==========================
   INDICADORES DO DIA
========================== */

function calcularIndicadoresHoje() {

  const hoje = new Date().toISOString().split('T')[0]

  const vendasDoDia =
    vendas.value.filter(venda =>
      venda.created_at.startsWith(hoje)
    )

  vendasHoje.value =
    vendasDoDia.length

  arrecadadoHoje.value =
    vendasDoDia.reduce(
      (total, venda) =>
        total + Number(venda.valor_total || 0),
      0
    )

  compradoresHoje.value =
    new Set(
      vendasDoDia.map(v => v.pessoa_id)
    ).size

  ticketMedio.value =
    vendasHoje.value > 0
      ? arrecadadoHoje.value / vendasHoje.value
      : 0

}
/* ==========================
   PRODUTOS MAIS VENDIDOS
========================== */

function calcularProdutosMaisVendidos() {

  const mapa = {}

  itensVenda.value.forEach(item => {

    const nome = item.produtos?.nome || 'Produto'

    if (!mapa[nome]) {
      mapa[nome] = {
        nome,
        quantidade: 0,
        valor: 0
      }
    }

    mapa[nome].quantidade += Number(item.quantidade || 0)
    mapa[nome].valor += Number(item.subtotal || 0)

  })

  produtosMaisVendidos.value = Object.values(mapa)
    .sort((a, b) => b.quantidade - a.quantidade)
    .slice(0, 5)

}

/* ==========================
   RANKING DOS CÍRCULOS
========================== */

function calcularRankingCirculos() {

  const mapa = {}

  vendas.value.forEach(venda => {

    const nome = venda.pessoas?.circulos?.nome

    if (!nome) return

    if (!mapa[nome]) {

      mapa[nome] = {
        nome,
        vendas: 0,
        valor: 0
      }

    }

    mapa[nome].vendas++
    mapa[nome].valor += Number(venda.valor_total || 0)

  })

  rankingCirculos.value = Object.values(mapa)
    .sort((a, b) => b.valor - a.valor)

}

/* ==========================
   RANKING DAS EQUIPES
========================== */

function calcularRankingEquipes() {

  const mapa = {}

  vendas.value.forEach(venda => {

    const nome = venda.pessoas?.equipes?.nome

    if (!nome) return

    if (!mapa[nome]) {

      mapa[nome] = {
        nome,
        vendas: 0,
        valor: 0
      }

    }

    mapa[nome].vendas++
    mapa[nome].valor += Number(venda.valor_total || 0)

  })

  rankingEquipes.value = Object.values(mapa)
    .sort((a, b) => b.valor - a.valor)

}

/* ==========================
   ÚLTIMAS VENDAS
========================== */

function carregarUltimas() {

  ultimasVendas.value = vendas.value.slice(0, 8)

}

/* ==========================
   COMPUTEDS
========================== */

const percentualRecebido = computed(() => {

  if (!totalVendido.value) return 0

  return (
    totalRecebido.value /
    totalVendido.value
  ) * 100

})

const percentualPendente = computed(() => {

  if (!totalVendido.value) return 0

  return (
    saldoPendente.value /
    totalVendido.value
  ) * 100

})

/* ==========================
   FORMATAÇÕES
========================== */

function formatarMoeda(valor) {

  return Number(valor || 0).toLocaleString(
    'pt-BR',
    {
      style: 'currency',
      currency: 'BRL'
    }
  )

}

function formatarData(data) {

  if (!data) return ''

  return new Date(data).toLocaleString(
    'pt-BR',
    {
      dateStyle: 'short',
      timeStyle: 'short'
    }
  )

}

/* ==========================
   ATUALIZAR DASHBOARD
========================== */

async function atualizarDashboard() {

  await carregarDashboard()

  sucesso('Dashboard atualizado!')

}

/* ==========================
   ON MOUNTED
========================== */

onMounted(() => {

  carregarDashboard()

})
</script>

<template>
  <div class="dashboard">

    <!-- Cabeçalho -->
    <div class="cabecalho">

      <div>
        <h1>Painel de Controle</h1>
        <p>Resumo geral das vendas do VIII EJC.</p>
      </div>

      <button
        class="btn-atualizar"
        @click="atualizarDashboard"
      >
        Atualizar
      </button>

    </div>

    <!-- Loading -->

    <div
      v-if="loading"
      class="loading"
    >
      Carregando dashboard...
    </div>

    <template v-else>

      <!-- KPIs -->

      <div class="cards-grid">

        <div class="card card-primary">

          <span class="titulo-card">
            Total Vendido
          </span>

          <strong>
            {{ formatarMoeda(totalVendido) }}
          </strong>

        </div>

        <div class="card card-success">

          <span class="titulo-card">
            Total Recebido
          </span>

          <strong>
            {{ formatarMoeda(totalRecebido) }}
          </strong>

          <small>
            {{ percentualRecebido.toFixed(1) }}%
            do total vendido
          </small>

        </div>

        <div class="card card-warning">

          <span class="titulo-card">
            Saldo Pendente
          </span>

          <strong>
            {{ formatarMoeda(saldoPendente) }}
          </strong>

          <small>
            {{ percentualPendente.toFixed(1) }}%
            ainda em aberto
          </small>

        </div>

        <div class="card card-danger">

          <span class="titulo-card">
            Pessoas com Pendência
          </span>

          <strong>
            {{ pessoasPendentes }}
          </strong>

          <small>
            aguardando pagamento
          </small>

        </div>

      </div>

      <!-- Indicadores de Hoje -->

      <div class="cards-grid">

        <div class="card">

          <span class="titulo-card">
            Vendas Hoje
          </span>

          <strong>
            {{ vendasHoje }}
          </strong>

        </div>

        <div class="card">

          <span class="titulo-card">
            Arrecadado Hoje
          </span>

          <strong>
            {{ formatarMoeda(arrecadadoHoje) }}
          </strong>

        </div>

        <div class="card">

          <span class="titulo-card">
            Compradores Hoje
          </span>

          <strong>
            {{ compradoresHoje }}
          </strong>

        </div>

        <div class="card">

          <span class="titulo-card">
            Ticket Médio
          </span>

          <strong>
            {{ formatarMoeda(ticketMedio) }}
          </strong>

        </div>

      </div>
      <!-- Rankings -->

      <div class="ranking-grid">

        <!-- Produtos Mais Vendidos -->
        <div class="painel">

          <div class="painel-header">
            <h2>🏆 Produtos Mais Vendidos</h2>
          </div>

          <div
            v-if="produtosMaisVendidos.length === 0"
            class="sem-dados"
          >
            Nenhum produto vendido.
          </div>

          <table
            v-else
            class="tabela-ranking"
          >
            <thead>
              <tr>
                <th>#</th>
                <th>Produto</th>
                <th>Qtd.</th>
                <th>Total</th>
              </tr>
            </thead>

            <tbody>

              <tr
                v-for="(produto,index) in produtosMaisVendidos"
                :key="produto.nome"
              >
                <td>{{ index + 1 }}</td>

                <td>{{ produto.nome }}</td>

                <td>{{ produto.quantidade }}</td>

                <td>
                  {{ formatarMoeda(produto.valor) }}
                </td>

              </tr>

            </tbody>

          </table>

        </div>

        <!-- Ranking dos Círculos -->

        <div class="painel">

          <div class="painel-header">
            <h2>🟣 Ranking dos Círculos</h2>
          </div>

          <div
            v-if="rankingCirculos.length === 0"
            class="sem-dados"
          >
            Nenhum registro encontrado.
          </div>

          <table
            v-else
            class="tabela-ranking"
          >
            <thead>

              <tr>

                <th>#</th>

                <th>Círculo</th>

                <th>Vendas</th>

                <th>Total</th>

              </tr>

            </thead>

            <tbody>

              <tr
                v-for="(circulo,index) in rankingCirculos"
                :key="circulo.nome"
              >

                <td>{{ index + 1 }}</td>

                <td>{{ circulo.nome }}</td>

                <td>{{ circulo.vendas }}</td>

                <td>
                  {{ formatarMoeda(circulo.valor) }}
                </td>

              </tr>

            </tbody>

          </table>

        </div>

        <!-- Ranking das Equipes -->

        <div class="painel">

          <div class="painel-header">
            <h2>👥 Ranking das Equipes</h2>
          </div>

          <div
            v-if="rankingEquipes.length === 0"
            class="sem-dados"
          >
            Nenhum registro encontrado.
          </div>

          <table
            v-else
            class="tabela-ranking"
          >

            <thead>

              <tr>

                <th>#</th>

                <th>Equipe</th>

                <th>Vendas</th>

                <th>Total</th>

              </tr>

            </thead>

            <tbody>

              <tr
                v-for="(equipe,index) in rankingEquipes"
                :key="equipe.nome"
              >

                <td>{{ index + 1 }}</td>

                <td>{{ equipe.nome }}</td>

                <td>{{ equipe.vendas }}</td>

                <td>
                  {{ formatarMoeda(equipe.valor) }}
                </td>

              </tr>

            </tbody>

          </table>

        </div>

      </div>
            <!-- Últimas Vendas -->

      <div class="painel">

        <div class="painel-header">

          <h2>🕒 Últimas Vendas</h2>

        </div>

        <div
          v-if="ultimasVendas.length === 0"
          class="sem-dados"
        >
          Nenhuma venda registrada.
        </div>

        <table
          v-else
          class="tabela-vendas"
        >

          <thead>

            <tr>

              <th>Cliente</th>

              <th>Tipo</th>

              <th>Valor</th>

              <th>Status</th>

              <th>Pagamento</th>

              <th>Data</th>

            </tr>

          </thead>

          <tbody>

            <tr
              v-for="venda in ultimasVendas"
              :key="venda.id"
            >

              <td>

                {{ venda.pessoas?.nome || '-' }}

              </td>

              <td>

                {{ venda.pessoas?.tipo || '-' }}

              </td>

              <td>

                {{ formatarMoeda(venda.valor_total) }}

              </td>

              <td>

                <span
                  :class="[
                    'status',
                    venda.status_pagamento === 'Pago'
                      ? 'status-pago'
                      : 'status-pendente'
                  ]"
                >

                  {{ venda.status_pagamento }}

                </span>

              </td>

              <td>

                {{ venda.forma_pagamento || '-' }}

              </td>

              <td>

                {{ formatarData(venda.created_at) }}

              </td>

            </tr>

          </tbody>

        </table>

      </div>

      <!-- Resumo Financeiro -->

      <div class="painel resumo-financeiro">

        <div class="painel-header">

          <h2>📊 Resumo Financeiro</h2>

        </div>

        <div class="resumo-grid">

          <div class="resumo-item">

            <span>Total Vendido</span>

            <strong>

              {{ formatarMoeda(totalVendido) }}

            </strong>

          </div>

          <div class="resumo-item">

            <span>Total Recebido</span>

            <strong>

              {{ formatarMoeda(totalRecebido) }}

            </strong>

          </div>

          <div class="resumo-item">

            <span>Saldo Pendente</span>

            <strong>

              {{ formatarMoeda(saldoPendente) }}

            </strong>

          </div>

          <div class="resumo-item">

            <span>Pessoas com Pendência</span>

            <strong>

              {{ pessoasPendentes }}

            </strong>

          </div>

        </div>

      </div>

    </template>

  </div>

</template>

<style scoped>
/* ===========================
   LAYOUT
=========================== */

.dashboard {
  display: flex;
  flex-direction: column;
  gap: 24px;
  padding: 30px;
  background: #f5f7fb;
  min-height: 100vh;
}

/* ===========================
   CABEÇALHO
=========================== */

.cabecalho {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 20px;
}

.cabecalho h1 {
  margin: 0;
  font-size: 30px;
  font-weight: 700;
  color: #1f2937;
}

.cabecalho p {
  margin-top: 6px;
  color: #6b7280;
  font-size: 15px;
}

/* ===========================
   BOTÃO
=========================== */

.btn-atualizar {
  border: none;
  outline: none;
  cursor: pointer;
  background: #22c55e;
  color: white;
  padding: 12px 24px;
  border-radius: 10px;
  font-weight: 600;
  transition: .25s;
}

.btn-atualizar:hover {
  background: #16a34a;
  transform: translateY(-2px);
}

/* ===========================
   GRID DOS CARDS
=========================== */

.cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(230px,1fr));
  gap: 18px;
}

/* ===========================
   CARDS
=========================== */

.card {
  background: white;
  border-radius: 16px;
  padding: 22px;
  box-shadow: 0 8px 25px rgba(0,0,0,.06);
  display: flex;
  flex-direction: column;
  gap: 10px;
  transition: .25s;
}

.card:hover {
  transform: translateY(-4px);
  box-shadow: 0 15px 35px rgba(0,0,0,.10);
}

.card strong {
  font-size: 30px;
  color: #111827;
}

.card small {
  color: #6b7280;
  font-size: 14px;
}

.titulo-card {
  color: #6b7280;
  font-size: 15px;
  font-weight: 600;
}

/* ===========================
   CORES DOS CARDS
=========================== */

.card-primary {
  border-left: 6px solid #3b82f6;
}

.card-success {
  border-left: 6px solid #22c55e;
}

.card-warning {
  border-left: 6px solid #f59e0b;
}

.card-danger {
  border-left: 6px solid #ef4444;
}

/* ===========================
   GRID DOS PAINÉIS
=========================== */

.ranking-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit,minmax(320px,1fr));
  gap: 22px;
}

/* ===========================
   PAINÉIS
=========================== */

.painel {
  background: white;
  border-radius: 16px;
  padding: 22px;
  box-shadow: 0 8px 25px rgba(0,0,0,.06);
}

.painel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 18px;
}

.painel-header h2 {
  margin: 0;
  font-size: 20px;
  color: #1f2937;
}

.sem-dados {
  text-align: center;
  padding: 35px;
  color: #9ca3af;
}

/* ===========================
   LOADING
=========================== */

.loading {
  background: white;
  padding: 40px;
  text-align: center;
  border-radius: 16px;
  font-size: 18px;
  color: #6b7280;
  box-shadow: 0 8px 25px rgba(0,0,0,.06);
}

/* ===========================
   TABELAS
=========================== */

table {
  width: 100%;
  border-collapse: collapse;
}

thead {
  background: #f8fafc;
}

thead th {
  padding: 14px;
  text-align: left;
  font-size: 14px;
  color: #374151;
  font-weight: 600;
  border-bottom: 2px solid #e5e7eb;
}

tbody td {
  padding: 14px;
  border-bottom: 1px solid #edf2f7;
  color: #374151;
  font-size: 14px;
}

tbody tr {
  transition: .2s;
}

tbody tr:hover {
  background: #f9fafb;
}

.tabela-ranking td:first-child,
.tabela-ranking th:first-child {
  width: 45px;
  text-align: center;
}

.tabela-vendas td,
.tabela-vendas th {
  white-space: nowrap;
}

/* ===========================
   STATUS
=========================== */

.status {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 90px;
  padding: 6px 12px;
  border-radius: 999px;
  font-size: 13px;
  font-weight: 600;
}

.status-pago {
  background: #dcfce7;
  color: #15803d;
}

.status-pendente {
  background: #fee2e2;
  color: #b91c1c;
}

/* ===========================
   RESUMO FINANCEIRO
=========================== */

.resumo-financeiro {
  margin-top: 5px;
}

.resumo-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px,1fr));
  gap: 20px;
}

.resumo-item {
  background: #f8fafc;
  border-radius: 12px;
  padding: 18px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  border: 1px solid #e5e7eb;
}

.resumo-item span {
  color: #6b7280;
  font-size: 14px;
}

.resumo-item strong {
  font-size: 24px;
  color: #111827;
}

/* ===========================
   SCROLL DAS TABELAS
=========================== */

.painel {
  overflow-x: auto;
}

.tabela-ranking,
.tabela-vendas {
  min-width: 650px;
}

/* ===========================
   BARRA DE ROLAGEM
=========================== */

::-webkit-scrollbar {
  width: 10px;
  height: 10px;
}

::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 10px;
}

::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}

::-webkit-scrollbar-track {
  background: transparent;
}

/* ===========================
   RESPONSIVIDADE
=========================== */

@media (max-width: 1100px) {

  .ranking-grid {
    grid-template-columns: 1fr;
  }

}

@media (max-width: 768px) {

  .dashboard {
    padding: 18px;
    gap: 18px;
  }

  .cabecalho {
    flex-direction: column;
    align-items: flex-start;
  }

  .cabecalho h1 {
    font-size: 24px;
  }

  .cards-grid {
    grid-template-columns: 1fr;
  }

  .btn-atualizar {
    width: 100%;
  }

  .card strong {
    font-size: 24px;
  }

  .painel {
    padding: 16px;
  }

  .painel-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 10px;
  }

}

@media (max-width: 480px) {

  .dashboard {
    padding: 12px;
  }

  .card {
    padding: 18px;
  }

  .painel {
    padding: 14px;
  }

  .titulo-card {
    font-size: 13px;
  }

  .card strong {
    font-size: 22px;
  }

  .resumo-item strong {
    font-size: 20px;
  }

}
</style>