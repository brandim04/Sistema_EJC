<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { fetchAllRows } from '../lib/supabasePagination'
import { useToast } from 'vue-toastification'
import { useAuthStore } from '../stores/auth'

const toast = useToast()
const auth = useAuthStore()
const podeVerCusto = computed(() => auth.usuario?.perfil === 'ADMIN')

const produtos = ref([])
const pesquisa = ref('')

const modalCadastro = ref(false)
const modalEditar = ref(false)
const modalExcluir = ref(false)

const produtoSelecionado = ref(null)

const categorias = [
  'Bebidas',
  'Lanches',
  'Doces',
  'Itens Religiosos',
  'Outros'
]

const form = ref({
  nome: '',
  categoria: '',
  preco: '',
  preco_custo: '',
  estoque: ''
})

const formEditar = ref({
  id: null,
  codigo: '',
  nome: '',
  categoria: '',
  preco: '',
  preco_custo: '',
  estoque: ''
})

const produtosFiltrados = computed(() => {

  if (!pesquisa.value) return produtos.value

  const texto = pesquisa.value.toLowerCase()

  return produtos.value.filter(produto =>
    produto.nome.toLowerCase().includes(texto) ||

    produto.categoria.toLowerCase().includes(texto) ||

    String(produto.codigo).padStart(3, '0').includes(texto)
  )

})

async function carregarProdutos() {

  try {
    produtos.value = await fetchAllRows(supabase
    .from('produtos')
    .select('id, codigo, nome, categoria, preco, estoque, ativo')
    .order('codigo'))
    if (podeVerCusto.value) {
      const custos = await fetchAllRows(supabase.rpc('listar_custos_produtos'), 1000, 'produto_id')
      const custosPorId = new Map((custos || []).map(item => [String(item.produto_id), Number(item.preco_custo)]))
      produtos.value = produtos.value.map(produto => ({ ...produto, preco_custo: custosPorId.get(String(produto.id)) ?? null }))
    }
  } catch (error) {
    console.error(error)
    toast.error('Erro ao carregar produtos')
  }

}

async function salvarProduto() {

  if (!validarPrecoCusto(form.value.preco_custo)) {
    toast.warning('O preço de custo deve ser numérico e igual ou maior que zero.')
    return
  }

  if (
    !form.value.nome ||
    !form.value.preco ||
    form.value.estoque === ''
  ) {

    toast.warning('Preencha todos os campos.')

    return
  }

  const { data: produtoCriado, error } = await supabase

    .from('produtos')

    .insert({

      nome: form.value.nome,

      categoria: form.value.categoria,

      preco: Number(form.value.preco),

      estoque: Number(form.value.estoque),
      ativo: true

    })
    .select('id')
    .single()

  if (error) {

    console.error(error)

    toast.error('Erro ao cadastrar produto.')

    return

  }

  if (podeVerCusto.value && form.value.preco_custo !== '') {
    const { error: erroCusto } = await supabase.rpc('definir_custo_produto', {
      p_produto_id: produtoCriado.id,
      p_preco_custo: Number(form.value.preco_custo)
    })
    if (erroCusto) {
      console.error(erroCusto)
      toast.error('Produto criado, mas não foi possível salvar o custo. Revise a migração SQL.')
      modalCadastro.value = false
      limparFormulario()
      await carregarProdutos()
      return
    }
  }

  toast.success('Produto cadastrado!')

  modalCadastro.value = false

  limparFormulario()

  carregarProdutos()

}

function editarProduto(produto){

  formEditar.value = {

    id: produto.id,

    codigo: produto.codigo,

    nome: produto.nome,

    categoria: produto.categoria,

    preco: produto.preco,
    preco_custo: produto.preco_custo ?? '',

    estoque: produto.estoque

  }

  modalEditar.value = true

}

async function atualizarProduto(){

  if (!validarPrecoCusto(formEditar.value.preco_custo)) {
    toast.warning('O preço de custo deve ser numérico e igual ou maior que zero.')
    return
  }

  const { error } = await supabase

    .from('produtos')

    .update({

      nome: formEditar.value.nome,

      categoria: formEditar.value.categoria,

      preco: Number(formEditar.value.preco),

      estoque: Number(formEditar.value.estoque)

    })

    .eq('id', formEditar.value.id)

  if(error){

    console.error(error)

    toast.error('Erro ao atualizar.')

    return

  }

  if (podeVerCusto.value) {
    const { error: erroCusto } = await supabase.rpc('definir_custo_produto', {
      p_produto_id: formEditar.value.id,
      p_preco_custo: formEditar.value.preco_custo === '' ? null : Number(formEditar.value.preco_custo)
    })
    if (erroCusto) {
      console.error(erroCusto)
      toast.error('Produto atualizado, mas não foi possível salvar o custo. Revise a migração SQL.')
      await carregarProdutos()
      return
    }
  }

  toast.success('Produto atualizado.')

  modalEditar.value=false

  carregarProdutos()

}

function confirmarExcluir(produto){

  produtoSelecionado.value = produto

  modalExcluir.value = true

}

async function excluirProduto(){

  const { error } = await supabase

    .from('produtos')

    .delete()

    .eq('id',produtoSelecionado.value.id)

  if(error){

    console.error(error)

    toast.error('Erro ao excluir.')

    return

  }

  toast.success('Produto excluído.')

  modalExcluir.value=false

  carregarProdutos()

}

function limparFormulario(){

  form.value={

    nome:'',

    categoria:'Bebidas',

    preco:'',

    preco_custo:'',

    estoque:''

  }

}

function validarPrecoCusto(valor) {
  if (valor === '' || valor === null || valor === undefined) return true
  const custo = Number(valor)
  return Number.isFinite(custo) && custo >= 0
}

function formatarCodigo(codigo){

  return String(codigo).padStart(3,'0')

}

function formatarMoeda(valor){

  return Number(valor).toLocaleString(

    'pt-BR',

    {

      style:'currency',

      currency:'BRL'

    }

  )

}

onMounted(()=>{

  carregarProdutos()

})
</script>

<template>
  <div class="page">

    <div class="page-header">
      <div>
        <h1>Produtos</h1>
        <p>Cadastre e gerencie os produtos vendidos na barraca.</p>
      </div>

      <button class="btn-primary" @click="modalCadastro = true">
        + Novo Produto
      </button>
    </div>

    <section class="card">

      <div class="table-header">

        <input
          v-model="pesquisa"
          class="search"
          placeholder="Pesquisar por código, nome ou categoria..."
        />

      </div>

      <table>

        <thead>

          <tr>

            <th>Código</th>

            <th>Produto</th>

            <th>Categoria</th>

            <th>Preço</th>

            <th v-if="podeVerCusto">Custo / lucro</th>
            <th>Estoque</th>

            <th width="180">Ações</th>

          </tr>

        </thead>

        <tbody>

          <tr
            v-for="produto in produtosFiltrados"
            :key="produto.id"
          >

            <td>

              <span class="codigo">

                {{ formatarCodigo(produto.codigo) }}

              </span>

            </td>

            <td>

              {{ produto.nome }}

            </td>

            <td>

              <span
                class="categoria"
                :class="produto.categoria.toLowerCase()"
              >

                {{ produto.categoria }}

              </span>

            </td>

            <td>

              {{ formatarMoeda(produto.preco) }}

            </td>

            <td v-if="podeVerCusto">
              <div>{{ produto.preco_custo == null ? 'Sem custo cadastrado' : `${formatarMoeda(produto.preco_custo)} custo` }}</div>
              <small>Lucro unitário: {{ produto.preco_custo == null ? '—' : formatarMoeda(Number(produto.preco) - Number(produto.preco_custo)) }}</small>
            </td>

            <td>

              <span
                class="estoque"
                :class="{ vazio: produto.estoque <= 0 }"
              >

                {{ produto.estoque }}

              </span>

            </td>

            <td>

              <div class="acoes">

                <button
                  class="btn-secondary"
                  @click="editarProduto(produto)"
                >

                  Editar

                </button>

                <button
                  class="btn-danger"
                  @click="confirmarExcluir(produto)"
                >

                  Excluir

                </button>

              </div>

            </td>

          </tr>

          <tr v-if="produtosFiltrados.length === 0">

            <td
              :colspan="podeVerCusto ? 7 : 6"
              class="empty"
            >

              Nenhum produto encontrado.

            </td>

          </tr>

        </tbody>

      </table>

    </section>

    <!-- MODAL CADASTRO -->

    <div
      v-if="modalCadastro"
      class="modal-overlay"
    >

      <div class="modal">

        <div class="modal-header">

          <h2>Novo Produto</h2>

          <button
            class="btn-close"
            @click="modalCadastro = false"
          >

            ×

          </button>

        </div>

        <div class="form-grid">

          <div class="field">

            <label>Nome</label>

            <input
              v-model="form.nome"
            >

          </div>

          <div class="field">

            <label>Categoria</label>

            <select
              v-model="form.categoria"
            >

              <option
                v-for="categoria in categorias"
                :key="categoria"
              >

                {{ categoria }}

              </option>

            </select>

          </div>

          <div class="field">

            <label>Preço</label>

            <input
              type="number"
              step="0.01"
              v-model="form.preco"
            >

          </div>

          <div v-if="podeVerCusto" class="field">
            <label>Preço de custo</label>
            <input v-model="form.preco_custo" type="number" min="0" step="0.01">
            <small>Lucro unitário: {{ form.preco_custo === '' ? 'Sem custo cadastrado' : formatarMoeda(Number(form.preco || 0) - Number(form.preco_custo)) }}</small>
          </div>

          <div class="field">

            <label>Estoque</label>

            <input
              type="number"
              min="0"
              v-model="form.estoque"
            >

          </div>

        </div>

        <div class="modal-actions">

          <button
            class="btn-secondary"
            @click="modalCadastro = false"
          >

            Cancelar

          </button>

          <button
            class="btn-primary"
            @click="salvarProduto"
          >

            Salvar Produto

          </button>

        </div>

      </div>

    </div>

    <!-- MODAL EDITAR -->

    <div
      v-if="modalEditar"
      class="modal-overlay"
    >

      <div class="modal">

        <div class="modal-header">

          <h2>Editar Produto</h2>

          <button
            class="btn-close"
            @click="modalEditar = false"
          >

            ×

          </button>

        </div>

        <div class="form-grid">

          <div class="field">

            <label>Código</label>

            <input
              :value="formatarCodigo(formEditar.codigo)"
              disabled
            >

          </div>

          <div class="field">

            <label>Nome</label>

            <input
              v-model="formEditar.nome"
            >

          </div>

          <div class="field">

            <label>Categoria</label>

            <select
              v-model="formEditar.categoria"
            >

              <option
                v-for="categoria in categorias"
                :key="categoria"
              >

                {{ categoria }}

              </option>

            </select>

          </div>

          <div class="field">

            <label>Preço</label>

            <input
              type="number"
              step="0.01"
              v-model="formEditar.preco"
            >

          </div>

          <div v-if="podeVerCusto" class="field">
            <label>Preço de custo</label>
            <input v-model="formEditar.preco_custo" type="number" min="0" step="0.01">
            <small>Lucro unitário: {{ formEditar.preco_custo === '' ? 'Sem custo cadastrado' : formatarMoeda(Number(formEditar.preco || 0) - Number(formEditar.preco_custo)) }}</small>
          </div>

          <div class="field">

            <label>Estoque</label>

            <input
              type="number"
              min="0"
              v-model="formEditar.estoque"
            >

          </div>

        </div>

        <div class="modal-actions">

          <button
            class="btn-secondary"
            @click="modalEditar = false"
          >

            Cancelar

          </button>

          <button
            class="btn-primary"
            @click="atualizarProduto"
          >

            Salvar Alterações

          </button>

        </div>

      </div>

    </div>

    <!-- MODAL EXCLUIR -->

    <div
      v-if="modalExcluir"
      class="modal-overlay"
    >

      <div class="modal modal-small">

        <h2>Excluir Produto</h2>

        <p>

          Deseja realmente excluir
          <strong>{{ produtoSelecionado?.nome }}</strong>?

        </p>

        <div class="modal-actions">

          <button
            class="btn-secondary"
            @click="modalExcluir = false"
          >

            Cancelar

          </button>

          <button
            class="btn-danger"
            @click="excluirProduto"
          >

            Excluir

          </button>

        </div>

      </div>

    </div>

  </div>
</template>

<style scoped>

.page{
    display:flex;
    flex-direction:column;
    gap:24px;
}

.page-header{
    display:flex;
    justify-content:space-between;
    align-items:center;
    gap:20px;
    flex-wrap:wrap;
}

.page-header h1{
    margin:0;
    font-size:32px;
    color:#151515;
}

.page-header p{
    margin-top:6px;
    color:#6d7f90;
}

.card{
    background:#fff;
    border-radius:18px;
    padding:22px;
    border:1px solid #e2edf5;
    box-shadow:0 8px 22px rgba(0,0,0,.06);
}

.table-header{
    margin-bottom:18px;
}

.search{
    width:100%;
    padding:13px 16px;
    border:1px solid #d7e4ef;
    border-radius:12px;
    outline:none;
    font-size:15px;
    transition:.2s;
}

.search:focus{
    border-color:#151515;
}

table{
    width:100%;
    border-collapse:collapse;
}

th{
    background:#f6f2e8;
    color:#151515;
    padding:14px;
    text-align:left;
    font-size:14px;
}

td{
    padding:14px;
    border-bottom:1px solid #edf2f7;
    vertical-align:middle;
}

.codigo{
    background:#f6f2e8;
    color:#151515;
    padding:6px 12px;
    border-radius:999px;
    font-weight:700;
    font-size:13px;
}

.estoque{
    background:#f6f2e8;
    color:#151515;
    padding:6px 12px;
    border-radius:999px;
    font-weight:700;
    display:inline-block;
    min-width:50px;
    text-align:center;
}

.estoque.vazio{
    background:#fdeaea;
    color:#c62828;
}

.categoria{
    padding:6px 12px;
    border-radius:999px;
    font-size:13px;
    font-weight:700;
    display:inline-block;
}

.categoria.bebidas{
    background:#dbeeff;
    color:#916b16;
}

.categoria.lanches{
    background:#fff3d6;
    color:#d17b00;
}

.categoria.doces{
    background:#ffe1ee;
    color:#d63384;
}

.acoes{
    display:flex;
    gap:10px;
}

button{
    cursor:pointer;
    border:none;
    transition:.2s;
    font-weight:600;
}

.btn-primary{

    background:#151515;
    color:white;
    padding:11px 18px;
    border-radius:10px;

}

.btn-primary:hover{

    background:#2c281c;

}

.btn-secondary{

    background:#f6f2e8;
    color:#151515;
    padding:10px 16px;
    border-radius:10px;

}

.btn-secondary:hover{

    background:#dbeaf5;

}

.btn-danger{

    background:#e53935;
    color:white;
    padding:10px 16px;
    border-radius:10px;

}

.btn-danger:hover{

    background:#c62828;

}

.modal-overlay{

    position:fixed;
    inset:0;
    background:rgba(0,0,0,.45);

    display:flex;

    justify-content:center;

    align-items:center;

    z-index:999;

}

.modal{

    width:600px;
    max-width:95%;

    background:white;

    border-radius:18px;

    padding:24px;

    box-shadow:0 18px 45px rgba(0,0,0,.20);

}

.modal-small{

    width:430px;

}

.modal-header{

    display:flex;

    justify-content:space-between;

    align-items:center;

    margin-bottom:20px;

}

.modal-header h2{

    margin:0;

    color:#151515;

}

.btn-close{

    background:none;

    color:#151515;

    font-size:28px;

    padding:0;

}

.form-grid{

    display:grid;

    grid-template-columns:repeat(2,1fr);

    gap:18px;

}

.field{

    display:flex;

    flex-direction:column;

    gap:8px;

}

.field label{

    color:#151515;

    font-weight:600;

}

.field input,
.field select{

    border:1px solid #d7e4ef;

    border-radius:12px;

    padding:12px 14px;

    font-size:15px;

    outline:none;

    transition:.2s;

}

.field input:focus,
.field select:focus{

    border-color:#151515;

}

.modal-actions{

    display:flex;

    justify-content:flex-end;

    gap:12px;

    margin-top:24px;

}

.empty{

    text-align:center;

    color:#7a8c9d;

    padding:35px;

}

@media(max-width:850px){

    .page-header{

        flex-direction:column;

        align-items:flex-start;

    }

    .form-grid{

        grid-template-columns:1fr;

    }

    .acoes{

        flex-direction:column;

    }

    table{

        display:block;

        overflow-x:auto;

    }

}

</style>
