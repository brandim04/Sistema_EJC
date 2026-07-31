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

.dashboard {
  display: flex;
  flex-direction: column;
  gap: 32px;
  padding: 32px;
  background: #f6f5fb;
  min-height: 100vh;
}

.cabecalho {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 24px;
}

.cabecalho h1 {
  margin: 0;
  font-size: 2rem;
  font-weight: 700;
  color: #312e81;
  letter-spacing: -.5px;
}

.cabecalho p {
  margin-top: 8px;
  font-size: .95rem;
  color: #6b7280;
}

.btn-atualizar {
  border: none;
  background: #5b21b6;
  color: #fff;
  padding: 12px 22px;
  border-radius: 12px;
  font-weight: 600;
  font-size: .95rem;
  cursor: pointer;
  transition: .25s;
  box-shadow: 0 8px 20px rgba(91,33,182,.18);
}

.btn-atualizar:hover {
  background: #4c1d95;
  transform: translateY(-2px);
  box-shadow: 0 12px 28px rgba(91,33,182,.25);
}

.loading {
  background: #fff;
  border-radius: 18px;
  padding: 60px;
  text-align: center;
  color: #6b7280;
  font-size: 1rem;
  border: 1px solid #ebe7fb;
  box-shadow: 0 10px 30px rgba(91,33,182,.05);
}

.cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit,minmax(240px,1fr));
  gap: 22px;
}

.card {
  background: #fff;
  border-radius: 18px;
  padding: 24px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  border: 1px solid #ece8fa;
  box-shadow: 0 10px 30px rgba(15,23,42,.04);
  transition: .25s;
}

.card:hover {
  transform: translateY(-4px);
  box-shadow: 0 18px 35px rgba(15,23,42,.08);
}

.card strong {
  font-size: 2rem;
  font-weight: 700;
  color: #1f2937;
  line-height: 1;
}

.card small {
  font-size: .82rem;
  color: #6b7280;
}

.titulo-card {
  font-size: .85rem;
  font-weight: 600;
  color: #7c3aed;
  text-transform: uppercase;
  letter-spacing: .08em;
}

.card-primary {
  border-top: 4px solid #5b21b6;
}

.card-success {
  border-top: 4px solid #7c3aed;
}

.card-warning {
  border-top: 4px solid #8b5cf6;
}

.card-danger {
  border-top: 4px solid #a855f7;
}

.ranking-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit,minmax(340px,1fr));
  gap: 24px;
}

.painel {
  background: #fff;
  border-radius: 18px;
  padding: 24px;
  border: 1px solid #ece8fa;
  box-shadow: 0 10px 30px rgba(15,23,42,.04);
  overflow-x: auto;
}

.painel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 22px;
  padding-bottom: 14px;
  border-bottom: 1px solid #f1eff9;
}

.painel-header h2 {
  margin: 0;
  font-size: 1.05rem;
  color: #312e81;
  font-weight: 700;
}

.sem-dados {
  padding: 50px 20px;
  text-align: center;
  color: #9ca3af;
  font-size: .95rem;
}
table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
}

thead {
  background: #f8f7fd;
}

thead th {
  padding: 15px 18px;
  text-align: left;
  font-size: .82rem;
  font-weight: 700;
  color: #5b21b6;
  text-transform: uppercase;
  letter-spacing: .06em;
  border-bottom: 1px solid #ece8fa;
}

tbody td {
  padding: 16px 18px;
  color: #374151;
  font-size: .9rem;
  border-bottom: 1px solid #f3f2f9;
}

tbody tr {
  transition: .2s;
}

tbody tr:hover {
  background: #faf9fe;
}

tbody tr:last-child td {
  border-bottom: none;
}

.tabela-ranking td:first-child,
.tabela-ranking th:first-child {
  width: 60px;
  text-align: center;
}

.tabela-vendas td,
.tabela-vendas th {
  white-space: nowrap;
}

.tabela-ranking,
.tabela-vendas {
  min-width: 700px;
}

.status {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 90px;
  padding: 7px 14px;
  border-radius: 999px;
  font-size: .75rem;
  font-weight: 700;
  letter-spacing: .02em;
}

.status-pago {
  background: #ede9fe;
  color: #5b21b6;
}

.status-pendente {
  background: #f3e8ff;
  color: #7e22ce;
}

.resumo-financeiro {
  margin-top: 4px;
}

.resumo-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit,minmax(230px,1fr));
  gap: 20px;
}

.resumo-item {
  background: #faf9fe;
  border: 1px solid #ece8fa;
  border-radius: 16px;
  padding: 22px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  transition: .2s;
}

.resumo-item:hover {
  background: #fff;
  transform: translateY(-2px);
}

.resumo-item span {
  font-size: .82rem;
  font-weight: 600;
  color: #7c3aed;
  text-transform: uppercase;
  letter-spacing: .05em;
}

.resumo-item strong {
  font-size: 1.7rem;
  color: #1f2937;
  line-height: 1.1;
}

::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-thumb {
  background: #c4b5fd;
  border-radius: 999px;
}

::-webkit-scrollbar-thumb:hover {
  background: #a78bfa;
}

::-webkit-scrollbar-track {
  background: transparent;
}

@media (max-width:1100px) {

  .ranking-grid {
    grid-template-columns: 1fr;
  }

}

@media (max-width:768px) {

  .dashboard {
    padding: 20px;
    gap: 24px;
  }

  .cabecalho {
    flex-direction: column;
    align-items: flex-start;
  }

  .cabecalho h1 {
    font-size: 1.7rem;
  }

  .cards-grid {
    grid-template-columns: 1fr;
  }

  .btn-atualizar {
    width: 100%;
    justify-content: center;
  }

  .card,
  .painel,
  .resumo-item {
    padding: 20px;
  }

  .card strong {
    font-size: 1.7rem;
  }

  .painel-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 10px;
  }

}

@media (max-width:480px) {

  .dashboard {
    padding: 14px;
  }

  .cabecalho h1 {
    font-size: 1.45rem;
  }

  .card,
  .painel,
  .resumo-item {
    padding: 18px;
    border-radius: 14px;
  }

  .card strong,
  .resumo-item strong {
    font-size: 1.45rem;
  }

  .titulo-card,
  .resumo-item span {
    font-size: .75rem;
  }

}

</style>