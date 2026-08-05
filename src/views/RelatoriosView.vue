<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import { supabase } from '../lib/supabase'
import { useToast } from 'vue-toastification'
import { useAuthStore } from '../stores/auth'

const toast = useToast()
const auth = useAuthStore()
const menuVendaAberto = ref(null)
const modalExcluirVendaAberto = ref(false)
const vendaSelecionada = ref(null)
const excluindoVenda = ref(false)

function obterVendasComStatus(pessoaId) {
  const vendasPessoa = vendas.value
    .filter(venda => venda.pessoa_id === pessoaId)
    .sort((a, b) => new Date(a.created_at) - new Date(b.created_at))

  let pagamentoDisponivel = pagamentos.value
    .filter(p => p.pessoa_id === pessoaId)
    .reduce((total, p) => total + Number(p.valor || 0), 0)

  return vendasPessoa.map(venda => {
    let statusVisual = venda.status_pagamento

    if (venda.status_pagamento === 'Pendente') {
      if (pagamentoDisponivel >= Number(venda.valor_total)) {
        pagamentoDisponivel -= Number(venda.valor_total)
        statusVisual = 'Quitado depois'
      } else {
        statusVisual = 'Pendente'
      }
    }

    return {
      ...venda,
      status_visual: statusVisual
    }
  })
}

function sucesso(msg) {
  toast.clear()
  toast.success(msg)
}

function erro(msg) {
  toast.clear()
  toast.error(msg)
}

function aviso(msg) {
  toast.clear()
  toast.warning(msg)
}

function toggleMenuVenda(id) {
  if (menuVendaAberto.value === id) {
    menuVendaAberto.value = null
  } else {
    menuVendaAberto.value = id
  }
}

function abrirModalExcluir(venda) {
  vendaSelecionada.value = venda
  modalExcluirVendaAberto.value = true
  menuVendaAberto.value = null
}

async function excluirVenda() {
  if (!vendaSelecionada.value) return

  excluindoVenda.value = true

  const { error } = await supabase
    .from('vendas')
    .update({
      ativo: false,
      excluida_em: new Date().toISOString(),
      excluida_por: auth.usuario.id
    })
    .eq('id', vendaSelecionada.value.id)

  if (error) {
    console.error(error)
    erro('Erro ao excluir venda')
    excluindoVenda.value = false
    return
  }

  sucesso('Venda excluída com sucesso')

// Guarda o ID antes de atualizar tudo
const pessoaId = pessoaSelecionada.value?.id

await carregarDados()
await nextTick()

if (pessoaId) {
  const pessoaAtualizada = pessoasComResumo.value.find(
    p => p.id === pessoaId
  )

  if (pessoaAtualizada) {
    pessoaSelecionada.value = pessoaAtualizada
  }
}

}

modalExcluirVendaAberto.value = false
vendaSelecionada.value = null
menuVendaAberto.value = null
excluindoVenda.value = false

const pessoas = ref([])
const vendas = ref([])
const pagamentos = ref([])

const busca = ref('')
const filtroStatus = ref('pendentes')

const pessoaSelecionada = ref(null)
const modalDetalhesAberto = ref(false)
const modalPagamentoAberto = ref(false)

const quitando = ref(false)

const formPagamento = ref({
  forma_pagamento: 'Pix',
  valor: '',
  observacao: ''
})

async function buscarTodasVendas() {
  const todas = []
  let inicio = 0
  const tamanhoPagina = 1000

  while (true) {
    const { data, error } = await supabase
      .from('vendas')
      .select(`
        *,
        pessoas (
          id,
          nome,
          telefone,
          tipo,
          saldo_pendente,
          circulos(nome),
          equipes(nome)
        ),
        usuario:usuarios!vendas_usuario_id_fkey (
          id,
          nome
        ),
        itens_venda (
          id,
          quantidade,
          preco_unitario,
          subtotal,
          produtos (
            id,
            nome
          )
        )
      `)
      .eq('ativo', true) // <-- ADICIONE ESTA LINHA
      .order('created_at', { ascending: false })
      .range(inicio, inicio + tamanhoPagina - 1)

    if (error) throw error

    todas.push(...data)

    if (data.length < tamanhoPagina) break

    inicio += tamanhoPagina
  }

  return todas
}

async function carregarDados() {
  const { data: pessoasData, error: erroPessoas } = await supabase
    .from('pessoas')
    .select(`
     *,
      circulos(nome),
      equipes(nome)
    `)
    .order('nome')

  if (erroPessoas) {
    console.error(erroPessoas)
    erro('Erro ao carregar pessoas')
    return
  }

  pessoas.value = pessoasData || []
  console.log(pessoas.value)

let vendasData

try {
  vendasData = await buscarTodasVendas()
} catch (erroVendas) {
  console.error('ERRO VENDAS:', erroVendas)
  erro('Erro ao carregar vendas')
  return
}


vendas.value = vendasData

  const { data: pagamentosData, error: erroPagamentos } = await supabase
    .from('pagamentos')
    .select('*')
    .order('created_at', { ascending: false })

  if (erroPagamentos) {
    console.error(erroPagamentos)
    erro('Erro ao carregar pagamentos')
    return
  }

  pagamentos.value = pagamentosData || []
}

const pessoasComResumo = computed(() => {
  return pessoas.value.map((pessoa) => {
    const vendasPessoa = vendas.value.filter(
      (venda) => venda.pessoa_id === pessoa.id
    )

    const totalVendido = vendasPessoa.reduce(
      (total, venda) => total + Number(venda.valor_total || 0),
      0
    )

    const totalPagoNaHora = vendasPessoa
      .filter((venda) => venda.status_pagamento === 'Pago')
      .reduce((total, venda) => total + Number(venda.valor_total || 0), 0)

    const pagamentosDaPessoa = pagamentos.value.filter((pagamento) => {
    return String(pagamento.pessoa_id) === String(pessoa.id)
    })

    const pagamentosPosteriores = pagamentosDaPessoa.reduce(
    (total, pagamento) => total + Number(pagamento.valor || 0),
    0
    )

    const totalPago = totalPagoNaHora + pagamentosPosteriores
    const totalPendente = Math.max(0, totalVendido - totalPago)

    // 👇 COLOQUE AQUI
    if (pessoa.nome === 'Larissa Gabriela dos Santos Brandim') {
      console.log('ID pessoa:', pessoa.id)
      console.log('Pagamentos encontrados:', pagamentosDaPessoa)
      console.log('Pagamentos posteriores:', pagamentosPosteriores)
      console.log(
      'Pagamentos da pessoa:',
        pagamentos.value.filter(
        p => p.pessoa_id === pessoa.id
      )
)
    }

    return {
      ...pessoa,
      total_vendido: totalVendido,
      total_pago: totalPago,
      total_pendente: totalPendente,
      vendas: vendasPessoa
    }
  })
})

const pessoasFiltradas = computed(() => {
  const termo = busca.value.toLowerCase().trim()

  let lista = pessoasComResumo.value

  switch (filtroStatus.value) {
    case 'pendentes':
      lista = lista.filter(
        pessoa => Number(pessoa.total_pendente || 0) > 0
      )
      break

    case 'pagos':
      lista = lista.filter(
        pessoa =>
          Number(pessoa.total_vendido || 0) > 0 &&
          Number(pessoa.total_pendente || 0) === 0
      )
      break

    case 'todos':
    default:
      break
  }

  if (!termo) return lista

  return lista.filter(pessoa =>
    pessoa.nome?.toLowerCase().includes(termo) ||
    pessoa.telefone?.toLowerCase().includes(termo)
  )
})

const totalVendidoGeral = computed(() => {
  return vendas.value.reduce(
    (total, venda) => total + Number(venda.valor_total || 0),
    0
  )
})

const totalPagoGeral = computed(() => {
  const pagoNaHora = vendas.value
    .filter((venda) => venda.status_pagamento === 'Pago')
    .reduce((total, venda) => total + Number(venda.valor_total || 0), 0)

  const pagoDepois = pagamentos.value.reduce(
    (total, pagamento) => total + Number(pagamento.valor || 0),
    0
  )

  return pagoNaHora + pagoDepois
})

const totalPendenteGeral = computed(() => {
  return pessoasComResumo.value.reduce(
    (total, pessoa) => total + Number(pessoa.total_pendente || 0),
    0
  )
})

const quantidadeDevedores = computed(() => {
  return pessoasComResumo.value.filter(
    (pessoa) => Number(pessoa.total_pendente || 0) > 0
  ).length
})

const quantidadePagos = computed(() => {
  return pessoasComResumo.value.filter(
    (pessoa) =>
      Number(pessoa.total_vendido || 0) > 0 &&
      Number(pessoa.total_pendente || 0) === 0
  ).length
})

const tituloLista = computed(() => {
  return filtroStatus.value === 'pendentes'
    ? 'Pessoas com pendência'
    : 'Pessoas com pagamento em dia'
})

const subtituloLista = computed(() => {
  return filtroStatus.value === 'pendentes'
    ? 'Pessoas que ainda possuem valor para cobrança.'
    : 'Pessoas que já estão sem saldo pendente.'
})

const vendasDaPessoaSelecionada = computed(() => {
  if (!pessoaSelecionada.value) return []

  return obterVendasComStatus(pessoaSelecionada.value.id)
})

const pagamentosDaPessoaSelecionada = computed(() => {
  if (!pessoaSelecionada.value) return []

  return pagamentos.value.filter(
    (pagamento) => pagamento.pessoa_id === pessoaSelecionada.value.id
  )
})

const totalPagoPessoaSelecionada = computed(() => {
  if (!pessoaSelecionada.value) return 0

  return Number(pessoaSelecionada.value.total_pago || 0)
})

const totalPendentePessoaSelecionada = computed(() => {
  if (!pessoaSelecionada.value) return 0

  return Number(pessoaSelecionada.value.total_pendente || 0)
})

function abrirPagamento(pessoa) {
  pessoaSelecionada.value = pessoa
  formPagamento.value = {
    forma_pagamento: 'Pix',
    valor: Number(pessoa.total_pendente || 0),
    observacao: ''
  }
  modalPagamentoAberto.value = true
}

function abrirDetalhes(pessoa) {
  pessoaSelecionada.value = pessoa
  modalDetalhesAberto.value = true
}

async function registrarPagamento() {
  if (!pessoaSelecionada.value) return

  const valor = Number(formPagamento.value.valor || 0)

  if (valor <= 0) {
    aviso('Informe um valor válido')
    return
  }

  if (valor > Number(pessoaSelecionada.value.total_pendente || 0)) {
    aviso('O valor não pode ser maior que o saldo pendente')
    return
  }

  quitando.value = true

  const novoSaldo = Number(pessoaSelecionada.value.total_pendente || 0) - valor

  const { error: erroPagamento } = await supabase
    .from('pagamentos')
    .insert({
      pessoa_id: pessoaSelecionada.value.id,
      valor,
      forma_pagamento: formPagamento.value.forma_pagamento,
      observacao: formPagamento.value.observacao || null
    })

  if (erroPagamento) {
    console.error(erroPagamento)
    erro('Erro ao registrar pagamento')
    quitando.value = false
    return
  }

  const { error: erroSaldo } = await supabase
    .from('pessoas')
    .update({
      saldo_pendente: novoSaldo
    })
    .eq('id', pessoaSelecionada.value.id)

  if (erroSaldo) {
    console.error(erroSaldo)
    erro('Erro ao atualizar saldo')
    quitando.value = false
    return
  }

  sucesso('Pagamento registrado com sucesso')

  modalPagamentoAberto.value = false
  quitando.value = false

  await carregarDados()
}

function gerarMensagemWhatsApp(pessoa) {
  const vendasPessoa = obterVendasComStatus(pessoa.id)

  let mensagem = `Olá, ${pessoa.nome}!\n\n`
  mensagem += `Segue o resumo das suas compras no VIII Encontro do EJC.\n\n`

  vendasPessoa.forEach((venda) => {
    venda.itens_venda?.forEach((item) => {
      const nomeProduto = item.produtos?.nome || 'Produto'
      const quantidade = item.quantidade || 1

      const status =
        venda.status_visual === 'Quitado depois'
          ? '(quitado depois)'
          : venda.status_pagamento === 'Pago'
            ? '(pago)'
            : '(pendente)'

      mensagem += `${quantidade}x ${nomeProduto} - ${formatarMoeda(item.subtotal)} ${status}\n`
    })
  })

  mensagem += `\nTotal comprado: ${formatarMoeda(
    pessoa.total_vendido || 0
  )}\n`

  mensagem += `Total já pago: ${formatarMoeda(
    pessoa.total_pago || 0
  )}\n`

  mensagem += `Total pendente: ${formatarMoeda(
    pessoa.total_pendente || 0
  )}\n\n`

  if (Number(pessoa.total_pendente || 0) > 0) {
    mensagem += `💰 Valor para pagamento: ${formatarMoeda(
      pessoa.total_pendente || 0
    )}\n\n`

    mensagem += `💳 PIX para pagamento\n`
    mensagem += `📱 Chave: *86999967724*\n\n`
    mensagem += `Após realizar o pagamento, envie o comprovante por este WhatsApp para registrarmos a quitação.\n\n`
  } else {
    mensagem += `✅ Todas as suas compras já estão quitadas. Muito obrigado!\n\n`
  }

  mensagem += `Deus abençoe! 🙏\n`
  mensagem += `EJC - Paróquia Nossa Senhora de Guadalupe`

  return mensagem
}

function abrirWhatsApp(pessoa) {
  const telefone = limparTelefone(pessoa.telefone)

  if (!telefone) {
    aviso('Pessoa sem telefone cadastrado')
    return
  }

  const mensagem = gerarMensagemWhatsApp(pessoa)

  window.open(
    `https://wa.me/55${telefone}?text=${encodeURIComponent(mensagem)}`,
    '_blank'
  )
}

function limparTelefone(telefone) {
  return String(telefone || '').replace(/\D/g, '')
}

function detalhePessoa(pessoa) {
  if (pessoa.tipo === 'Jovem') {
    return `Jovem • ${pessoa.circulos?.nome || 'Sem círculo'}`
  }

  return `Servo • ${pessoa.equipes?.nome || 'Sem equipe'}`
}

function statusPessoaTexto(pessoa) {
  return Number(pessoa.total_pendente || 0) > 0
    ? 'Pendente'
    : 'Pago'
}

function formatarMoeda(valor) {
  return Number(valor || 0).toLocaleString('pt-BR', {
    style: 'currency',
    currency: 'BRL'
  })
}

function formatarData(data) {
  if (!data) return ''

  return new Date(data).toLocaleString('pt-BR')
}

onMounted(() => {
  carregarDados()
})
</script>

<template>
  <div class="page">
    <div class="page-header">
      <div>
        <h1>Relatórios</h1>
        <p>Acompanhe vendas, pagamentos, pendências e cobranças do evento.</p>
      </div>
    </div>

    <div class="cards-resumo">
      <div class="card-resumo">
        <span>Total vendido</span>
        <small>Soma de todas as compras registradas</small>
        <strong>{{ formatarMoeda(totalVendidoGeral) }}</strong>
      </div>

      <div class="card-resumo">
        <span>Total pago</span>
        <small>Pagamentos feitos na hora e depois</small>
        <strong>{{ formatarMoeda(totalPagoGeral) }}</strong>
      </div>

      <div class="card-resumo pendente">
        <span>Total pendente</span>
        <small>Valor ainda em aberto para cobrança</small>
        <strong>{{ formatarMoeda(totalPendenteGeral) }}</strong>
      </div>

      <div class="card-resumo">
        <span>Pessoas com pendência</span>
        <small>Quantidade de pessoas devendo</small>
        <strong>{{ quantidadeDevedores }}</strong>
      </div>
    </div>

    <section class="card">
      <div class="section-header">

  <div class="header-text">
    <h2>{{ tituloLista }}</h2>
    <p>{{ subtituloLista }}</p>
  </div>

  <div class="header-search">
    <input
      v-model="busca"
      placeholder="Buscar pessoa ou telefone"
    />
  </div>

</div>

      <div class="toolbar">

  <div class="toolbar">

  <p class="contador-registros">
    {{ pessoasFiltradas.length }}
    {{ pessoasFiltradas.length === 1 ? 'pessoa encontrada' : 'pessoas encontradas' }}
  </p>

</div>

</div>

      <div class="tabs">
        <button
          :class="{ active: filtroStatus === 'todos' }"
           @click="filtroStatus = 'todos'"
        >
          Todos
        </button>

        <button
          :class="{ active: filtroStatus === 'pendentes' }"
          @click="filtroStatus = 'pendentes'"
        >
          Pendentes
        </button>

        <button
          :class="{ active: filtroStatus === 'pagos' }"
          @click="filtroStatus = 'pagos'"
        >
            Pagos
        </button>
</div>

      <div class="lista-pessoas">
        <div
          v-for="pessoa in pessoasFiltradas"
          :key="pessoa.id"
          class="pessoa-card"
        >
          <div>
            <h3>{{ pessoa.nome }}</h3>
            <span>{{ detalhePessoa(pessoa) }}</span>
            <small>{{ pessoa.telefone }}</small>
          </div>

          <div class="valor-card">
            <span>Total comprado</span>
            <strong>{{ formatarMoeda(pessoa.total_vendido) }}</strong>
          </div>

          <div class="valor-card">
            <span>Total pago</span>
            <strong>{{ formatarMoeda(pessoa.total_pago) }}</strong>
          </div>

          <div class="valor-card pendente">
            <span>Total pendente</span>
            <strong>{{ formatarMoeda(pessoa.total_pendente) }}</strong>
          </div>

          <div class="status-area">
            <span
              class="badge"
              :class="statusPessoaTexto(pessoa) === 'Pago' ? 'pago' : 'pendente'"
            >
              {{ statusPessoaTexto(pessoa) }}
            </span>
          </div>

          <div class="acoes">
            <button
              class="btn-secondary"
              @click="abrirDetalhes(pessoa)"
            >
              Detalhes
            </button>

            <button
              v-if="pessoa.total_pendente > 0"
              class="btn-secondary"
              @click="abrirWhatsApp(pessoa)"
            >
              WhatsApp
            </button>

            <button
              v-if="pessoa.total_pendente > 0"
              @click="abrirPagamento(pessoa)"
            >
              Registrar pagamento
            </button>
          </div>
        </div>

        <p
          v-if="pessoasFiltradas.length === 0"
          class="empty"
        >
          Nenhum registro encontrado.
        </p>
      </div>
    </section>

    <div
      v-if="modalDetalhesAberto && pessoaSelecionada"
      class="modal-overlay"
    >
      <div class="modal">
        <div class="modal-header">
          <div>
            <h2>{{ pessoaSelecionada.nome }}</h2>
            <p>{{ detalhePessoa(pessoaSelecionada) }}</p>
          </div>

          <button
            class="btn-close"
            @click="modalDetalhesAberto = false"
          >
            ×
          </button>
        </div>

        <div class="detalhes-resumo cards">
          <div class="card-total">
            <span>Total comprado</span>
            <strong>{{ formatarMoeda(pessoaSelecionada.total_vendido) }}</strong>
          </div>

          <div class="card-total">
            <span>Total pago</span>
            <strong>{{ formatarMoeda(totalPagoPessoaSelecionada) }}</strong>
          </div>

          <div class="card-total pendente">
            <span>Saldo pendente</span>
            <strong>{{ formatarMoeda(totalPendentePessoaSelecionada) }}</strong>
          </div>
        </div>

        <div class="lista-vendas">
          <div
  v-for="venda in vendasDaPessoaSelecionada"
  :key="venda.id"
  class="venda-card"
>
<div class="venda-top">

  <strong>
    {{ formatarData(venda.created_at) }}
    <span class="venda-vendedor">
      • {{ venda.usuario?.nome || 'Não informado' }}
    </span>
  </strong>

  <div class="venda-actions">

    <span
      class="badge"
      :class="{
        pago: venda.status_visual === 'Pago',
        quitado: venda.status_visual === 'Quitado depois',
        pendente: venda.status_visual === 'Pendente'
      }"
    >
      {{ venda.status_visual }}
    </span>

    <button
      v-if="auth.usuario?.perfil === 'ADMIN'"
      class="btn-menu"
      @click="toggleMenuVenda(venda.id)"
    >
      ⋮
    </button>

    <div
  v-if="menuVendaAberto === venda.id"
  class="menu-venda"
>
  <button @click="abrirModalExcluir(venda)">
    🗑 Excluir venda
  </button>
</div>

  </div>

</div>

<div
  v-if="venda.observacao"
  class="venda-observacao"
>
  <strong>Observação:</strong>
  {{ venda.observacao }}
</div>

  <div
    v-for="item in venda.itens_venda"
    :key="item.id"
    class="item-venda"
  >
    <span>
      {{ item.quantidade }}x
      {{ item.produtos?.nome || 'Produto' }}
    </span>

    <strong>{{ formatarMoeda(item.subtotal) }}</strong>
  </div>

  <div class="venda-total">
    <span>Total da venda</span>
    <strong>{{ formatarMoeda(venda.valor_total) }}</strong>
  </div>
</div>

          <p
            v-if="vendasDaPessoaSelecionada.length === 0"
            class="empty"
          >
            Nenhuma venda encontrada para essa pessoa.
          </p>
        </div>

        <div
          v-if="pagamentosDaPessoaSelecionada.length > 0"
          class="pagamentos-box"
        >
          <h3>Pagamentos registrados depois</h3>

          <div
  v-for="pagamento in pagamentosDaPessoaSelecionada"
  :key="pagamento.id"
  class="pagamento-item"
>
  <div>
    <span>
      {{ formatarData(pagamento.created_at) }} •
      {{ pagamento.forma_pagamento }}
    </span>

    <small
      v-if="pagamento.observacao"
      class="observacao"
    >
      {{ pagamento.observacao }}
    </small>
  </div>
                <strong>{{ formatarMoeda(pagamento.valor) }}</strong>
        </div>
      </div>

      <div class="modal-actions">
        <button
          v-if="pessoaSelecionada.total_pendente > 0"
          class="btn-secondary"
          @click="abrirWhatsApp(pessoaSelecionada)"
        >
          Abrir WhatsApp
        </button>

        <button
          v-if="pessoaSelecionada.total_pendente > 0"
          @click="abrirPagamento(pessoaSelecionada)"
        >
          Registrar pagamento
        </button>
      </div>
    </div>
  </div>

  <div
    v-if="modalPagamentoAberto && pessoaSelecionada"
    class="modal-overlay"
  >
    <div class="modal pagamento-modal">
      <div class="modal-header">
        <div>
          <h2>Registrar pagamento</h2>
          <p>{{ pessoaSelecionada.nome }}</p>
        </div>

        <button
          class="btn-close"
          @click="modalPagamentoAberto = false"
        >
          ×
        </button>
      </div>

      <div class="saldo-info">
        <span>Saldo pendente atual</span>
        <strong>{{ formatarMoeda(pessoaSelecionada.total_pendente) }}</strong>
      </div>

      <div class="field">
        <label for="valorPagamento">
          Valor pago
        </label>

        <input
          id="valorPagamento"
          v-model="formPagamento.valor"
          type="number"
          step="0.01"
          min="0.01"
        />
      </div>

      <div class="field">
        <label>Forma de pagamento</label>

        <select v-model="formPagamento.forma_pagamento">
          <option value="Pix">Pix</option>
          <option value="Dinheiro">Dinheiro</option>
          <option value="Crédito">Crédito</option>
          <option value="Débito">Débito</option>
        </select>
      </div>

      <div class="field">
        <label>Observação</label>

        <textarea
  v-model="formPagamento.observacao"
  placeholder="Ex.: Pagamento realizado em dinheiro."
></textarea>
      </div>

      <button
        class="btn-finalizar"
        :disabled="quitando"
        @click="registrarPagamento"
      >
        {{ quitando ? 'Registrando...' : 'Confirmar pagamento' }}
      </button>
    </div>
  </div>
</div>

<div
  v-if="modalExcluirVendaAberto"
  class="modal-overlay"
>
  <div class="modal pagamento-modal">

    <div class="modal-header">
      <h2>Excluir venda</h2>

      <button
        class="btn-close"
        @click="modalExcluirVendaAberto = false"
      >
        ×
      </button>
    </div>

    <p>
      Deseja realmente excluir esta venda?
    </p>

    <div class="saldo-info">
      <span>Valor da venda</span>
      <strong>
        {{ formatarMoeda(vendaSelecionada?.valor_total || 0) }}
      </strong>
    </div>

    <p>
      Esta ação removerá:
    </p>

    <ul>
      <li>A venda</li>
      <li>Os itens da venda</li>
      <li>Os pagamentos vinculados</li>
    </ul>

    <div class="modal-actions">
      <button
        class="btn-secondary"
        @click="modalExcluirVendaAberto = false"
      >
        Cancelar
      </button>

      <button
        class="btn-danger"
        @click="excluirVenda"
        :disabled="excluindoVenda"
      >
        {{ excluindoVenda ? 'Excluindo...' : 'Excluir venda' }}
      </button>
    </div>

  </div>
</div>
</template>

<style scoped>
.page {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.page-header h1 {
  margin: 0;
  font-size: 34px;
}

.page-header p {
  margin: 6px 0 0;
  color: #6b7c8d;
}

.cards-resumo{
    display:grid;
    grid-template-columns:repeat(auto-fit,minmax(220px,1fr));
    gap:18px;
}

.card-resumo{
    padding:18px 22px;
    min-height:auto;
}

.pendencias-card {
  background: #fff;
  border-radius: 16px;
  padding: 28px;
  box-shadow: 0 8px 20px rgba(15,23,42,.06);
}

.card-resumo,
.card {
  background: white;
  border-radius: 18px;
  border: 1px solid #e3edf4;
  box-shadow: 0 8px 22px rgba(11, 53, 88, 0.06);
}

.card-resumo {
  padding: 20px;
}

.card-resumo span {
  display: block;
  color: #0b3558;
  font-weight: 700;
  margin-bottom: 4px;
}

.card-resumo small {
  display: block;
  color: #6b7c8d;
  min-height: 34px;
  margin-bottom: 10px;
}

.card-resumo strong {
  font-size: 22px;
  color: #0b3558;
}

.card-resumo.pendente {
  border-color: #d6b35f;
}

.card {
  padding: 20px;
}

.stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 20px;
  margin-bottom: 24px;
}

.stat-card {
  background: #fff;
  border-radius: 16px;
  padding: 24px;
  border: 1px solid #dbeafe;
  box-shadow: 0 8px 20px rgba(15, 23, 42, .06);
}

.stat-card h3 {
  font-size: 18px;
  color: #1e3a8a;
  margin-bottom: 6px;
}

.stat-card p {
  color: #64748b;
  margin-bottom: 20px;
}

.stat-card strong {
  font-size: 34px;
  color: #0f172a;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: end;
  gap: 20px;
  margin-bottom: 16px;
}

.section-header h2 {
  margin: 0;
}

.section-header p {
  margin: 6px 0 0;
  color: #6b7c8d;
}

.section-header input{
    width:320px;
    height:42px;
    padding:0 14px;
    border-radius:10px;
    border:1px solid #d6dbe5;
}

.tabs {
  display: flex;
  gap: 10px;
  margin-bottom: 18px;
}

.tabs button {
  background: #eef6fb;
  color: #0b3558;
}

.tabs button.active {
  background: #0b3558;
  color: white;
}

.lista-pessoas {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.pessoa-card {
  border: 1px solid #e3edf4;
  border-radius: 16px;
  padding: 16px;
  background: #f8fbfd;
  display: grid;
  grid-template-columns: 1.8fr 1fr 1fr 1fr auto auto;
  gap: 14px;
  align-items: center;
}

.pessoa-card h3 {
  margin: 0;
}

.pessoa-card span {
  display: block;
  color: #5c7285;
}

.pessoa-card small {
  display: block;
  color: #7b8b98;
  margin-top: 4px;
}

.valor-card span {
  color: #6b7c8d;
  font-size: 13px;
}

.valor-card strong {
  display: block;
  margin-top: 4px;
  font-size: 18px;
  color: #0b3558;
}

.valor-card.pendente strong {
  color: #c48b00;
}

.status-area {
  display: flex;
  justify-content: center;
}

.acoes {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  justify-content: flex-end;
}

.btn-secondary {
  background: #eef6fb;
  color: #0b3558;
}

.btn-pagamento{
    background:#2563eb;
    color:#fff;
}

.btn-pagamento:hover{
    background:#1d4ed8;
}

.btn-detalhes{
    background:#eef5ff;
    color:#1d4ed8;
    border:1px solid #cddcf7;
}

.empty {
  text-align: center;
  color: #777;
  padding: 24px;
}

.modal-confirmar {
  max-width: 420px;
}

.warning {
  color: #b91c1c;
  font-weight: 600;
  margin-top: 12px;
}

.btn-danger {
  background: #dc2626;
  color: white;
}

.btn-danger:hover {
  background: #b91c1c;
}

.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,.45);
  display: flex;
  justify-content: center;
  align-items: flex-start;
  padding: 30px 16px;
  overflow-y: auto;
  z-index: 9999;
}

.modal {
  width: 900px;
  max-width: 95%;
  max-height: calc(100vh - 60px);
  overflow-y: auto;
  background: white;
  border-radius: 18px;
  padding: 24px;
  box-shadow: 0 16px 40px rgba(0,0,0,.22);
}

.pagamento-modal {
  width: 520px;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: start;
  margin-bottom: 20px;
}

.modal-header h2 {
  margin: 0;
}

.modal-header{
    display:flex;
    justify-content:space-between;
    align-items:flex-start;
    margin-bottom:24px;
    padding-bottom:18px;
    border-bottom:1px solid #e7eef5;
}

.btn-close{
    width:42px;
    height:42px;
    border:none;
    border-radius:50%;
    background:#eef5ff;
    color:#0b3558;
    font-size:22px;
    cursor:pointer;
    transition:.2s;
}

.btn-close:hover{
    background:#dce9ff;
}

.detalhes-resumo {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 14px;
  margin-bottom: 20px;
}

.detalhes-resumo div{
    background:#f8fbff;
    border:1px solid #d9e7f5;
    border-radius:16px;
    padding:18px;
    transition:.2s;
}

.detalhes-resumo div:hover{
    transform:translateY(-2px);
    box-shadow:0 10px 22px rgba(15,23,42,.08);
}

.detalhes-resumo span {
  display: block;
  color: #5c7285;
  margin-bottom: 6px;
}

.detalhes-resumo strong {
  font-size: 22px;
  color: #0b3558;
}

.acoes button,
.modal-actions button{
    height:42px;
    border:none;
    border-radius:10px;
    padding:0 18px;
    font-weight:600;
    cursor:pointer;
    transition:.2s;
}

.acoes button:hover,
.modal-actions button:hover{
    transform:translateY(-1px);
}

.lista-vendas {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.venda-card{
    background:white;
    border:1px solid #dbe7f4;
    border-radius:16px;
    padding:18px;
    box-shadow:0 6px 18px rgba(15,23,42,.05);
    transition:.2s;
}

.venda-card:hover{
    transform:translateY(-2px);
    box-shadow:0 10px 24px rgba(15,23,42,.08);
}

.venda-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.venda-vendedor {
  font-weight: 500;
  color: #6b7280;
  font-size: 0.9rem;
  margin-left: 8px;
}

.venda-actions{
    display:flex;
    align-items:center;
    gap:10px;
    position:relative;
}

.menu-venda{
    position:absolute;
    top:42px;
    right:0;

    background:#fff;
    border:1px solid #dbe7f4;
    border-radius:10px;

    box-shadow:0 8px 20px rgba(0,0,0,.15);

    overflow:hidden;

    z-index:100;
}

.menu-venda button{
    width:170px;
    padding:12px 16px;

    border:none;
    background:white;

    text-align:left;
    cursor:pointer;
}

.menu-venda button:hover{
    background:#f5f7fb;
}

.badge {
  padding: 6px 12px;
  border-radius: 999px;
  font-size: 13px;
  font-weight: 700;
}

.badge.pago {
  background: #e4f7ed;
  color: #1d7a45;
}

.badge.pendente {
  background: #fff3cd;
  color: #9a6a00;
}

.badge.quitado {
  background: #dbeafe;
  color: #1d4ed8;
}

.item-venda {
  display: flex;
  justify-content: space-between;
  padding: 9px 0;
  gap: 14px;
}

.venda-total {
  display: flex;
  justify-content: space-between;
  margin-top: 12px;
  padding-top: 12px;
  border-top: 1px solid #dbe6ee;
  font-weight: 700;
}

.pagamentos-box {
  margin-top: 22px;
  border-top: 1px solid #e3edf4;
  padding-top: 18px;
}

.pagamentos-box h3 {
  margin-top: 0;
}

.pagamento-item {
  display: flex;
  justify-content: space-between;
  background: #f8fbfd;
  border: 1px solid #e3edf4;
  border-radius: 12px;
  padding: 12px;
  margin-bottom: 8px;
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  margin-top: 20px;
}

.field{
    display:flex;
    flex-direction:column;
    gap:8px;
    margin-bottom:20px;
}

.field label{
    font-size:14px;
    font-weight:600;
    color:#234c70;
}

.field input,
.field select,
.field textarea{
    width:100%;
    padding:12px 14px;

    border:1px solid #d8e2ec;
    border-radius:10px;

    font-size:15px;
    font-family:inherit;
    background:#fff;
    color:#0b3558;

    transition:.2s;
    box-sizing:border-box;
}

.field textarea{
    min-height:90px;
    resize:vertical;
}

.field input:focus,
.field select:focus,
.field textarea:focus{
    outline:none;
    border-color:#4b8eb8;
    box-shadow:0 0 0 3px rgba(75,142,184,.15);
}

.saldo-info{
    margin:22px 0 26px;
    padding:18px 20px;

    background:#edf5fb;
    border-left:5px solid #4b8eb8;
    border-radius:14px;
}

.saldo-info span{
    display:block;
    color:#5f7386;
    font-size:13px;
    margin-bottom:6px;
}

.saldo-info strong{
    display:block;
    font-size:30px;
    color:#0b3558;
    font-weight:700;
}

.btn-finalizar{
    width:100%;
    height:48px;
    margin-top:10px;

    border:none;
    border-radius:12px;

    background:#4b8eb8;
    color:#fff;

    font-size:15px;
    font-weight:700;

    cursor:pointer;
    transition:.2s;
}

.btn-finalizar:hover:not(:disabled){
    background:#3a7da6;
}

.btn-finalizar:disabled{
    opacity:.7;
    cursor:not-allowed;
}

.btn-finalizar:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-whatsapp{
    background:#25D366;
    color:white;
}

.btn-whatsapp:hover{
    background:#1fb857;
}

.busca input{
  width:100%;
  height:46px;
  border:1px solid #cbd5e1;
  border-radius:10px;
  padding:0 14px;
  font-size:15px;
  margin:18px 0;
}

.busca input:focus{
  border-color:#2563eb;
  outline:none;
  box-shadow:0 0 0 3px rgba(37,99,235,.15);
}

.filtros{
  display:flex;
  gap:10px;
  margin:18px 0 24px;
}

.filtros button{
  padding:8px 18px;
  border:none;
  border-radius:8px;
  background:#e2e8f0;
  cursor:pointer;
  transition:.2s;
  font-weight:600;
}

.filtros button:hover{
  background:#cbd5e1;
}

.filtros .ativo{
  background:#2563eb;
  color:white;
}

.venda-actions{
    display:flex;
    align-items:center;
    gap:10px;
}

.btn-menu{
    width:34px;
    height:34px;

    border:none;
    border-radius:50%;

    background:#eef5ff;
    color:#0b3558;

    font-size:20px;
    font-weight:bold;

    cursor:pointer;
    transition:.2s;
}

.btn-menu:hover{
    background:#dbeafe;
}

.venda-observacao {
  margin: 8px 0 12px;
  padding: 8px 12px;
  background: #f8fafc;
  border-left: 4px solid #3b82f6;
  border-radius: 6px;
  font-size: 0.9rem;
  color: #475569;
}

.venda-observacao strong {
  color: #1e293b;
}

.sem-registros{
  height:220px;
  display:flex;
  align-items:center;
  justify-content:center;
  color:#94a3b8;
  font-size:17px;
}

.toolbar{
    display:flex;
    justify-content:space-between;
    align-items:center;
    margin:20px 0;
    gap:20px;
    flex-wrap:wrap;
}

.tabs{
    display:flex;
    gap:10px;
}

.tabs button{
    padding:10px 18px;
    border:none;
    border-radius:10px;
    background:#eef4ff;
    color:#1e3a8a;
    cursor:pointer;
    font-weight:600;
}

.tabs button.active{
    background:#2563eb;
    color:#fff;
}

.btn-danger{
    background:#dc2626;
    color:white;
}

.btn-danger:hover{
    background:#b91c1c;
}

@media (max-width: 1200px) {
  .pessoa-card {
    grid-template-columns: 1fr 1fr;
  }

  .status-area,
  .acoes {
    justify-content: flex-start;
  }
}

@media (max-width: 1000px) {
  .cards-resumo {
    grid-template-columns: 1fr 1fr;
  }

  .detalhes-resumo {
    grid-template-columns: 1fr;
  }

  .section-header {
    flex-direction: column;
    align-items: stretch;
  }

  .section-header input {
    max-width: 100%;
  }
}

@media (max-width: 600px) {
  .cards-resumo,
  .pessoa-card {
    grid-template-columns: 1fr;
  }
}
</style>