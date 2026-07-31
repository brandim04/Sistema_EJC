<script setup>
import { ref, computed, onMounted } from 'vue'
import QRCode from 'qrcode'
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

function aviso(msg) {
  toast.clear()
  toast.warning(msg)
}

const pessoas = ref([])
const produtos = ref([])
const equipesBanco = ref([])
const circulosBanco = ref([])

const buscaProduto = ref('')
const buscaPessoa = ref('')
const carrinho = ref([])
const pessoaSelecionada = ref(null)

const statusPagamento = ref('Pendente')
const formaPagamento = ref('')
const observacao = ref('')
const finalizando = ref(false)

const valorRecebido = ref('')
const trocoCalculado = ref(null)

const qrCodeUrl = ref('')
const pixCopiaCola = ref('')
const modalPixAberto = ref(false)

const modalPessoaAberto = ref(false)
const modalSelecionarPessoaAberto = ref(false)

const chavePix = 'COLOQUE_A_CHAVE_PIX_AQUI'
const nomeRecebedorPix = 'EJC PNSG'
const cidadePix = 'TIMON'

const circulos = [
  'Lilás',
  'Azul',
  'Verde',
  'Amarelo',
  'Laranja',
  'Vermelho'
]

const equipes = [
  'Sala',
  'Cozinha',
  'Lanche',
  'Minimercado',
  'Batran',
  'Bate papo',
  'Secretaria',
  'Liturgia',
  'Ordem',
  'Visitação tios',
  'Visitação jovens',
  'Coordenação geral'
]

const formPessoa = ref({
  nome: '',
  telefone: '',
  tipo: 'Jovem',
  circulo: '',
  equipe: '',
  observacao: ''
})

async function carregarDados() {
  const { data: pessoasData, error: erroPessoas } = await supabase
  .from('pessoas')
  .select(`
    id,
    nome,
    tipo,
    saldo_pendente,
    circulo_id,
    equipe_id
  `)

  if (erroPessoas) {
    console.error(erroPessoas)
    erro('Erro ao carregar pessoas')
    return
  }

  pessoas.value = pessoasData || []
  console.log(pessoas.value[0])

const { data: usuario } = await supabase.auth.getUser()


const { data: equipesData, error: erroEquipes } = await supabase
  .from('equipes')
  .select('id, nome')
  .order('nome')


if (erroEquipes) {
  console.error(erroEquipes)
} else {
  equipesBanco.value = equipesData || []
}

const { data: circulosData, error: erroCirculos } = await supabase
  .from('circulos')
  .select('id, nome')
  .order('nome')


if (erroCirculos) {
  console.error(erroCirculos)
} else {
  circulosBanco.value = circulosData || []
}

  const { data: produtosData, error: erroProdutos } = await supabase
    .from('produtos')
    .select('*')
    .eq('ativo', true)
    .gt('estoque', 0)
    .order('nome')

  if (erroProdutos) {
    console.error(erroProdutos)
    erro('Erro ao carregar produtos')
    return
  }

  produtos.value = produtosData || []
}

const produtosFiltrados = computed(() => {
  const termo = buscaProduto.value.toLowerCase().trim()
  if (!termo) return produtos.value

  return produtos.value.filter((produto) =>
    produto.nome?.toLowerCase().includes(termo)
  )
})

const pessoasFiltradas = computed(() => {
  const termo = buscaPessoa.value.toLowerCase().trim()

  if (termo.length < 2) return []

  return pessoas.value.filter((pessoa) =>
    pessoa.nome?.toLowerCase().includes(termo) ||
    pessoa.telefone?.toLowerCase().includes(termo)
  )
})

const totalCarrinho = computed(() => {
  return carrinho.value.reduce((total, item) => {
    return total + item.preco * item.quantidade
  }, 0)
})

function adicionarProduto(produto) {
  const itemExistente = carrinho.value.find((item) => item.id === produto.id)

  if (itemExistente) {
    aumentarQuantidade(itemExistente)
    return
  }

  carrinho.value.push({
    id: produto.id,
    nome: produto.nome,
    preco: Number(produto.preco),
    estoque: produto.estoque,
    quantidade: 1
  })

  sucesso('Produto adicionado')
}

function aumentarQuantidade(item) {
  if (item.quantidade >= item.estoque) {
    aviso('Estoque insuficiente')
    return
  }

  item.quantidade++
}

function diminuirQuantidade(item) {
  item.quantidade--

  if (item.quantidade <= 0) {
    removerItem(item.id)
  }
}

function alterarQuantidade(item) {
  let quantidade = Number(item.quantidade)

  if (!quantidade || quantidade < 1) {
    removerItem(item.id)
    return
  }

  if (quantidade > item.estoque) {
    item.quantidade = item.estoque
    aviso('Quantidade ajustada ao estoque disponível')
    return
  }

  item.quantidade = quantidade
}

function removerItem(id) {
  carrinho.value = carrinho.value.filter((item) => item.id !== id)
}

function selecionarPessoa(pessoa) {
  pessoaSelecionada.value = pessoa
  modalSelecionarPessoaAberto.value = false
  sucesso('Pessoa selecionada')
}

async function salvarPessoa() {
  if (!formPessoa.value.nome || !formPessoa.value.telefone) {
    aviso('Preencha nome e telefone')
    return
  }

  if (formPessoa.value.tipo === 'Jovem' && !formPessoa.value.circulo_id){
    aviso('Selecione o círculo do jovem')
    return
  }

  if (formPessoa.value.tipo === 'Servo' && !formPessoa.value.equipe_id) {
    aviso('Selecione a equipe do servo')
    return
  }

  const payload = {
    nome: formPessoa.value.nome.trim(),
    telefone: formPessoa.value.telefone,
    tipo: formPessoa.value.tipo,

    circulo_id:
      formPessoa.value.tipo === 'Jovem'
        ? formPessoa.value.circulo_id
        : null,

    equipe_id:
      formPessoa.value.tipo === 'Servo'
        ? formPessoa.value.equipe_id
        : null,

    responsavel: formPessoa.value.responsavel || null,
    observacao: formPessoa.value.observacao || null
  }

  const { data, error } = await supabase
    .from('pessoas')
    .insert(payload)
    .select()
    .single()

  if (error) {
    console.error('Erro ao cadastrar pessoa:', error)
    erro(error.message || 'Erro ao cadastrar pessoa')
    return
  }

  sucesso('Pessoa cadastrada com sucesso')

  formPessoa.value = {
    nome: '',
    telefone: '',
    tipo: 'Jovem',
    circulo_id: null,
    equipe_id: null,
    observacao: '',
    responsavel: ''
  }

  modalPessoaAberto.value = false
  await carregarDados()
  pessoaSelecionada.value = data
}

function calcularTroco() {
  const recebido = Number(valorRecebido.value || 0)

  if (recebido < totalCarrinho.value) {
    aviso('Valor recebido menor que o total')
    trocoCalculado.value = null
    return
  }

  trocoCalculado.value = recebido - totalCarrinho.value
}

function gerarPixCopiaCola() {
  if (chavePix === 'COLOQUE_A_CHAVE_PIX_AQUI') {
    aviso('Coloque a chave Pix no código antes de gerar o QR Code')
    return ''
  }

  const valor = totalCarrinho.value.toFixed(2)

  return `PIX EJC PNSG | Chave: ${chavePix} | Valor: R$ ${valor}`
}

async function gerarQrCodePix() {
  if (totalCarrinho.value <= 0) {
    aviso('Adicione produtos ao carrinho')
    return
  }

  const textoPix = gerarPixCopiaCola()

  if (!textoPix) return

  pixCopiaCola.value = textoPix
  qrCodeUrl.value = await QRCode.toDataURL(textoPix)
  modalPixAberto.value = true
}

async function copiarPix() {
  await navigator.clipboard.writeText(pixCopiaCola.value)
  sucesso('Pix copia e cola copiado')
}

function limparVenda() {
  carrinho.value = []
  pessoaSelecionada.value = null
  buscaProduto.value = ''
  buscaPessoa.value = ''
  statusPagamento.value = 'Pendente'
  formaPagamento.value = ''
  observacao.value = ''
  valorRecebido.value = ''
  trocoCalculado.value = null
  qrCodeUrl.value = ''
  pixCopiaCola.value = ''
}

async function finalizarVenda() {
  if (carrinho.value.length === 0) {
    aviso('Adicione pelo menos um produto')
    return
  }

  if (!pessoaSelecionada.value) {
    aviso('Selecione uma pessoa')
    modalSelecionarPessoaAberto.value = true
    return
  }

  if (statusPagamento.value === 'Pago' && !formaPagamento.value) {
    aviso('Informe a forma de pagamento')
    return
  }

  finalizando.value = true

  const { data: usuario } = await supabase.auth.getUser()
  const { data: venda, error: erroVenda } = await supabase
    .from('vendas')
    .insert({
    pessoa_id: pessoaSelecionada.value.id,
    usuario_id: usuario.user.id,
    status_pagamento: statusPagamento.value,
    forma_pagamento: statusPagamento.value === 'Pago'
      ? formaPagamento.value
      : null,
    valor_total: totalCarrinho.value,
    observacao: observacao.value || null
  })
  .select()
  .single()

  if (erroVenda) {
    console.error(erroVenda)
    erro('Erro ao registrar venda')
    finalizando.value = false
    return
  }

  for (const item of carrinho.value) {
    const { error: erroEstoque } = await supabase.rpc('baixar_estoque', {
      produto_id_param: item.id,
      quantidade_param: item.quantidade
    })

    if (erroEstoque) {
      console.error(erroEstoque)
      erro('Estoque insuficiente em algum produto')
      finalizando.value = false
      return
    }

    const { error: erroItem } = await supabase
      .from('itens_venda')
      .insert({
        venda_id: venda.id,
        produto_id: item.id,
        quantidade: item.quantidade,
        preco_unitario: item.preco,
        subtotal: item.preco * item.quantidade
      })

    if (erroItem) {
      console.error(erroItem)
      erro('Erro ao salvar itens da venda')
      finalizando.value = false
      return
    }
  }

  if (statusPagamento.value === 'Pendente') {
    const saldoAtual = Number(pessoaSelecionada.value.saldo_pendente || 0)

    const { error: erroSaldo } = await supabase
      .from('pessoas')
      .update({
        saldo_pendente: saldoAtual + totalCarrinho.value
      })
      .eq('id', pessoaSelecionada.value.id)

    if (erroSaldo) {
      console.error(erroSaldo)
      erro('Venda salva, mas erro ao atualizar saldo pendente')
    }
  }

  sucesso('Venda registrada com sucesso')

  await carregarDados()
  limparVenda()
  finalizando.value = false
}

function detalhePessoa(pessoa) {
  if (pessoa.tipo === 'Jovem') {
    const circulo = circulosBanco.value.find(
      c => c.id === pessoa.circulo_id
    )

    return `Jovem • ${circulo?.nome || 'Sem círculo'}`
  }

  const equipe = equipesBanco.value.find(
    e => e.id === pessoa.equipe_id
  )

  return `Servo • ${equipe?.nome || 'Sem equipe'}`
}

function formatarMoeda(valor) {
  return Number(valor || 0).toLocaleString('pt-BR', {
    style: 'currency',
    currency: 'BRL'
  })
}

onMounted(() => {
  carregarDados()
})
</script>

<template>
  <div class="page">
    <div class="page-header">
      <div>
        <h1>Vendas</h1>
        <p>Adicione os produtos ao carrinho, selecione a pessoa e finalize a venda.</p>
      </div>
    </div>

    <div class="venda-layout">
      <section class="card produtos-card">
        <h2>Produtos</h2>

        <input
          v-model="buscaProduto"
          placeholder="Buscar produto"
        />

        <div class="produtos-grid">
          <div
            v-for="produto in produtosFiltrados"
            :key="produto.id"
            class="produto-item"
          >
            <div>
              <strong>{{ produto.nome }}</strong>
              <span>{{ formatarMoeda(produto.preco) }}</span>
              <small :class="{ estoqueBaixo: produto.estoque <= 5 }">
                Estoque: {{ produto.estoque }}
              </small>
            </div>

            <button @click="adicionarProduto(produto)">
              Adicionar
            </button>
          </div>

          <p v-if="produtosFiltrados.length === 0" class="empty">
            Nenhum produto disponível.
          </p>
        </div>
      </section>

      <aside class="card carrinho-card">
        <h2>Carrinho</h2>

        <div v-if="carrinho.length === 0" class="empty">
          Nenhum produto adicionado.
        </div>

        <div
          v-for="item in carrinho"
          :key="item.id"
          class="cart-item"
        >
          <div class="cart-top">
            <div>
              <strong>{{ item.nome }}</strong>
              <span>{{ formatarMoeda(item.preco) }} cada</span>
            </div>

            <button
              class="btn-remove"
              @click="removerItem(item.id)"
            >
              Remover
            </button>
          </div>

          <div class="qty">
            <button @click="diminuirQuantidade(item)">-</button>

            <input
              v-model.number="item.quantidade"
              type="number"
              min="1"
              :max="item.estoque"
              @change="alterarQuantidade(item)"
            />

            <button @click="aumentarQuantidade(item)">+</button>
          </div>

          <p class="subtotal">
            Subtotal:
            <strong>{{ formatarMoeda(item.preco * item.quantidade) }}</strong>
          </p>
        </div>

        <div class="total-box">
          <span>Total</span>
          <strong>{{ formatarMoeda(totalCarrinho) }}</strong>
        </div>

        <div class="pessoa-box">
  <h3>Pessoa</h3>

  <input
  v-model="buscaPessoa"
  placeholder="Buscar nome ou telefone"
  @input="pessoaSelecionada = null"
/>

  <div
    v-if="pessoaSelecionada"
    class="pessoa-selecionada"
  >
    <strong>{{ pessoaSelecionada.nome }}</strong>

    <small>
      {{ detalhePessoa(pessoaSelecionada) }}
    </small>

    <small>
      Saldo:
      {{ formatarMoeda(pessoaSelecionada.saldo_pendente) }}
    </small>
  </div>

  <div
    v-if="pessoasFiltradas.length && !pessoaSelecionada"
    class="lista-pessoas"
>
  <button
    v-for="pessoa in pessoasFiltradas.slice(0,5)"
    :key="pessoa.id"
    class="pessoa-item"
    @click="selecionarPessoa(pessoa)"
  >
    {{ pessoa.nome }}
  </button>

  <p
    v-if="pessoasFiltradas.length === 0"
    class="empty-small"
  >
    Nenhuma pessoa encontrada.
  </p>
</div>

  <button
    class="btn-secondary"
    @click="modalPessoaAberto = true"
  >
    + Cadastrar pessoa
  </button>
</div>

        <div class="payment-box">
          <label class="radio-option">
            <input
              v-model="statusPagamento"
              type="radio"
              value="Pago"
            />
            <span>Pago na hora</span>
          </label>

          <div v-if="statusPagamento === 'Pago'" class="formas">
            <label class="radio-option">
              <input
                v-model="formaPagamento"
                type="radio"
                value="Pix"
              />
              <span>Pix</span>
            </label>

            <div v-if="formaPagamento === 'Pix'" class="optional-box">
              <button
                class="btn-secondary"
                @click="gerarQrCodePix"
              >
                Gerar QR Code Pix
              </button>
            </div>

            <label class="radio-option">
              <input
                v-model="formaPagamento"
                type="radio"
                value="Dinheiro"
              />
              <span>Dinheiro</span>
            </label>

            <div v-if="formaPagamento === 'Dinheiro'" class="optional-box">
              <input
                v-model="valorRecebido"
                type="number"
                step="0.01"
                placeholder="Valor recebido"
              />

              <button
                class="btn-secondary"
                @click="calcularTroco"
              >
                Calcular troco
              </button>

              <p v-if="trocoCalculado !== null">
                Troco:
                <strong>{{ formatarMoeda(trocoCalculado) }}</strong>
              </p>
            </div>

            <label class="radio-option">
              <input
                v-model="formaPagamento"
                type="radio"
                value="Crédito"
              />
               <span>Crédito</span>
            </label>

              <label class="radio-option">
                <input
                  v-model="formaPagamento"
                  type="radio"
                  value="Débito"
                />
                  <span>Débito</span>
              </label>
          </div>

          <label class="radio-option">
            <input
              v-model="statusPagamento"
              type="radio"
              value="Pendente"
            />
            <span>Pagar depois</span>
          </label>
        </div>

        <textarea
          v-model="observacao"
          placeholder="Observação da venda, se necessário"
        ></textarea>

        <button
          class="btn-finalizar"
          :disabled="finalizando"
          @click="finalizarVenda"
        >
          {{ finalizando ? 'Finalizando...' : 'Finalizar venda' }}
        </button>
      </aside>
    </div>

    <div v-if="modalSelecionarPessoaAberto" class="modal-overlay">
      <div class="modal">
        <div class="modal-header">
          <h2>Selecionar pessoa</h2>

          <button
            class="btn-close"
            @click="modalSelecionarPessoaAberto = false"
          >
            ×
          </button>
        </div>

        <input
          v-model="buscaPessoa"
          placeholder="Buscar por nome ou telefone"
        />

        <div class="modal-list">
          <button
            v-if="!pessoaSelecionada"
            v-for="pessoa in pessoasFiltradas"
            :key="pessoa.id"
            class="list-item"
            @click="selecionarPessoa(pessoa)"
          >
            <strong>{{ pessoa.nome }}</strong>
            <span>{{ detalhePessoa(pessoa) }}</span>
            <small>{{ pessoa.telefone }}</small>
          </button>

          <p v-if="pessoasFiltradas.length === 0" class="empty">
            Nenhuma pessoa encontrada.
          </p>
        </div>

        <button
          class="btn-secondary full"
          @click="modalPessoaAberto = true"
        >
          Cadastrar nova pessoa
        </button>
      </div>
    </div>

    <div v-if="modalPessoaAberto" class="modal-overlay">
      <div class="modal">
        <div class="modal-header">
          <h2>Cadastrar pessoa</h2>

          <button
            class="btn-close"
            @click="modalPessoaAberto = false"
          >
            ×
          </button>
        </div>

        <div class="form-grid">
          <div class="field">
            <label>Nome</label>
            <input
              v-model="formPessoa.nome"
              placeholder="Nome completo"
            />
          </div>

          <div class="field">
            <label>WhatsApp</label>
            <input
              v-model="formPessoa.telefone"
              placeholder="(86) 99999-9999"
            />
          </div>

          <div class="field">
            <label>Tipo</label>
            <select v-model="formPessoa.tipo">
              <option>Jovem</option>
              <option>Servo</option>
            </select>
          </div>

          <div
            v-if="formPessoa.tipo === 'Jovem'"
            class="field"
          >
            <label>Círculo</label>

<select v-model="formPessoa.circulo_id">
  <option :value="null">Selecione o círculo</option>

  <option
    v-for="circulo in circulosBanco"
    :key="circulo.id"
    :value="circulo.id"
  >
    {{ circulo.nome }}
  </option>
</select>
          </div>

          <div
            v-if="formPessoa.tipo === 'Servo'"
            class="field"
          >
            <label>Equipe</label>

<select v-model="formPessoa.equipe_id">
  <option :value="null">Selecione a equipe</option>

  <option
    v-for="equipe in equipesBanco"
    :key="equipe.id"
    :value="equipe.id"
  >
    {{ equipe.nome }}
  </option>
</select>
          </div>

          <div class="field">
            <label>Observação</label>
            <textarea
              v-model="formPessoa.observacao"
              placeholder="Opcional"
            ></textarea>
          </div>
        </div>

        <button @click="salvarPessoa">
          Salvar pessoa
        </button>
      </div>
    </div>

    <div v-if="modalPixAberto" class="modal-overlay">
      <div class="modal pix-modal">
        <div class="modal-header">
          <h2>QR Code Pix</h2>

          <button
            class="btn-close"
            @click="modalPixAberto = false"
          >
            ×
          </button>
        </div>

        <div class="pix-content">
          <p>Total do Pix:</p>
          <strong>{{ formatarMoeda(totalCarrinho) }}</strong>

          <img
            v-if="qrCodeUrl"
            :src="qrCodeUrl"
            alt="QR Code Pix"
            class="qr-code"
          />

          <textarea
            v-model="pixCopiaCola"
            readonly
          ></textarea>

          <button @click="copiarPix">
            Copiar Pix
          </button>
        </div>
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

.venda-layout {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 20px;
  align-items: start;
}

.card {
  background: white;
  border-radius: 18px;
  padding: 20px;
  border: 1px solid #e3edf4;
  box-shadow: 0 8px 22px rgba(11, 53, 88, 0.06);
}

.card h2 {
  margin-top: 0;
  color: #0b3558;
}

.cart-item{

    background:white;

    border:1px solid #dce8f0;

    border-radius:14px;

    padding:16px;

    box-shadow:0 2px 8px rgba(11,53,88,.05);

}

input,
select,
textarea {
  width: 100%;
  margin-bottom: 14px;
}

.produtos-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(185px, 1fr));
  gap: 10px;
  max-height: 620px;
  overflow-y: auto;
  padding-right: 4px;
}

.produto-item {
  background: #f8fbfd;
  border: 1px solid #dce8f0;
  border-radius: 12px;
  padding: 12px;

  display: flex;
  flex-direction: column;
  gap: 8px;

  transition: .2s;
}

.produto-item:hover{
  border-color:#9ecce5;
  box-shadow:0 5px 14px rgba(11,53,88,.08);
}

.produto-item strong{
    font-size:15px;
    color:#0b3558;
}

.produto-item span{
    display:block;
    margin-top:3px;
    color:#2f6c93;
    font-weight:700;
}

.produto-item small{
    margin-top:2px;
    color:#66788b;
    font-size:12px;
}

.produto-item button{
    margin-top:auto;

    width:100%;

    height:38px;

    border:none;

    border-radius:8px;

    background:#0b3558;

    color:#fff;

    font-size:14px;

    font-weight:600;

    cursor:pointer;

    transition:.2s;
}

.produto-item button:hover{
    background:#174b73;
}

.produto-item button:active{
    transform:scale(.98);
}

.produto-item{
    justify-content:space-between;
    min-height:145px;
}

.estoqueBaixo {
  color: #b7791f;
  font-weight: 700;
}

.carrinho-card {
  position: sticky;
  top: 20px;
}

.cart-item{
    background:#fafcfe;
    border:1px solid #dce8f0;
    border-radius:12px;
    padding:12px;
    margin-bottom:10px;
}

.cart-top {
  display: flex;
  justify-content: space-between;
  gap: 12px;
}

.cart-top span {
  display: block;
  color: #5c7285;
  margin-top: 4px;
}

.qty{
    display:flex;
    align-items:center;
    gap:8px;
    margin:10px 0;
}

.qty button{

    width:34px;
    height:34px;

    border:none;

    border-radius:10px;

    background:#0b3558;

    color:#fff;

    font-size:18px;
    font-weight:bold;

    display:flex;
    align-items:center;
    justify-content:center;

    cursor:pointer;

    transition:.2s;
}

.qty button:hover{
    background:#174b73;
}

.qty input{

    width:70px;

    text-align:center;

    font-weight:600;

    border:1px solid #d8e6ef;

    border-radius:10px;
}

.subtotal{

    margin-top:12px;

    color:#617789;

    font-size:14px;
}

.subtotal strong{

    color:#0b3558;

    font-size:16px;
}

.btn-remove{
    background:#fef2f2;
    color:#c62828;
    border:1px solid #efb5b5;

    padding:8px 12px;

    border-radius:8px;

    font-size:13px;
    font-weight:600;

    cursor:pointer;

    transition:.2s;
}

.btn-remove:hover{
    background:#fde4e4;
}

.total-box{
    background:#eef6fb;
    border:1px solid #dbe6ef;
    border-radius:14px;
    padding:16px;

    display:flex;
    justify-content:space-between;
    align-items:center;

    margin:18px 0;

    font-size:22px;
    font-weight:700;
}

.pessoa-box{
    margin-top:18px;
    padding:18px;
    background:#f8fbfd;
    border:1px solid #dce8f0;
    border-radius:14px;
}

.pessoa-selecionada{
    margin-top:12px;
    padding:14px;
    background:#fff;
    border:1px solid #dce8f0;
    border-radius:10px;
}

.pessoa-selecionada strong{
    display:block;
    color:#0b3558;
    font-size:16px;
}

.pessoa-selecionada small{
    display:block;
    color:#617789;
    margin-top:3px;
}

.pessoa-box span {
  color: #5c7285;
}

.pessoa-box small {
  display: block;
  color: #5c7285;
}

.payment-box{
    margin-top:22px;
    padding:18px;

    background:#f8fbfd;

    border:1px solid #dce8f0;

    border-radius:14px;
}

.radio-option{
    display:flex;
    align-items:center;
    gap:10px;

    margin-bottom:10px;

    font-weight:600;

    color:#0b3558;
}

.radio-option input{
    width:18px;
    height:18px;
}

.radio-option input {
  width: 18px;
  height: 18px;
  margin: 0;
}

.formas {
  margin-left: 28px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.optional-box{
    margin:12px 0 18px 28px;

    padding:16px;

    background:white;

    border:1px solid #dce8f0;

    border-radius:12px;
}

.optional-box p{
    margin-top:12px;

    color:#0b3558;

    font-size:15px;
}

.optional-box input{
    width:100%;
    margin-bottom:10px;
}

.optional-box button{
    width:100%;

    background:#0b3558;

    color:white;

    border:none;

    border-radius:8px;

    padding:10px;

    font-weight:600;
}

.optional-box button:hover{
    background:#174b73;
}

.btn-finalizar{
    width:100%;
    padding:15px;

    border-radius:12px;

    background:#0b3558;
    color:white;

    font-size:16px;
    font-weight:700;

    transition:.2s;
}

.btn-finalizar:hover{
    background:#12476f;
}

.btn-finalizar:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-secondary{
    width:100%;
    margin-top:14px;

    padding:11px;

    background:#eef5fb;

    color:#0b3558;

    border:1px solid #cfe0ec;

    border-radius:10px;

    font-weight:600;

    cursor:pointer;

    transition:.2s;
}

.btn-secondary:hover{
    background:#dfeef9;
}

.full {
  width: 100%;
}

.empty {
  text-align: center;
  color: #777;
  padding: 20px;
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
  width: 650px;
  max-width: 95%;
  max-height: calc(100vh - 60px);
  overflow-y: auto;
  background: white;
  border-radius: 18px;
  padding: 24px;
  box-shadow: 0 16px 40px rgba(0,0,0,.22);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 18px;
}

.btn-close {
  background: transparent;
  color: #0b3558;
  font-size: 26px;
  padding: 0;
}

.modal-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
  max-height: 450px;
  overflow-y: auto;
  margin-bottom: 14px;
}

.list-item {
  border: 1px solid #e3edf4;
  border-radius: 14px;
  background: #f8fbfd;
  padding: 13px;
  text-align: left;
  color: #0b3558;
}

.list-item span,
.list-item small {
  display: block;
  color: #5c7285;
  margin-top: 4px;
}

.form-grid {
  display: grid;
  gap: 14px;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.field label {
  font-weight: 600;
  color: #0b3558;
}

.pix-modal {
  max-width: 500px;
}

.pix-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
}

.qr-code {
  width: 250px;
  height: 250px;
  object-fit: contain;
  border: 1px solid #e3edf4;
  border-radius: 12px;
  padding: 10px;
  background: white;
}

.pix-content textarea {
  min-height: 90px;
}

textarea{
    margin-top:18px;

    width:100%;
    min-height:90px;

    resize:vertical;
}

@media (max-width: 1000px) {
  .venda-layout {
    grid-template-columns: 1fr;
  }

  .carrinho-card{
    display:flex;
    flex-direction:column;
    gap:16px;
  }

  .produtos-grid {
    grid-template-columns: 1fr;
  }
}

.pessoa-box h3 {
  margin: 0 0 12px;
  color: #0b3558;
}

.lista-pessoas {
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-height: 180px;
  overflow-y: auto;
}

.pessoa-item {
  text-align: left;
  background: white;
  border: 1px solid #dbe6ee;
  color: #0b3558;
}

.pessoa-selecionada {
  background: white;
  border-radius: 12px;
  padding: 10px;
  margin-bottom: 10px;
}

.pessoa-selecionada small {
  display: block;
  color: #5c7285;
}

input,
select,
textarea{

    border:1px solid #d7e4ec;

    border-radius:10px;

    padding:10px 12px;

    transition:.2s;

    background:white;
}

input:focus,
select:focus,
textarea:focus{

    border-color:#5f9fc4;

    outline:none;

    box-shadow:0 0 0 3px rgba(95,159,196,.15);

}

</style>