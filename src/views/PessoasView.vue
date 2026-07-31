<script setup>
import { supabase } from '../lib/supabase'
import { useToast } from 'vue-toastification'
import { ref, computed, watch, onMounted } from 'vue'
const toast = useToast()

const pessoas = ref([])
const circulos = ref([])
const equipes = ref([])

const pesquisa = ref('')
const mostrarFiltros = ref(false)
const filtrosSelecionados = ref([])

const modalCadastro = ref(false)
const modalEdicao = ref(false)

const pessoaEditando = ref(null)

const form = ref({
  nome: '',
  telefone: '',
  tipo: 'Jovem',
  circulo_id: null,
  equipe_id: null,
  responsavel: '',
  observacao: ''
})

async function carregarCirculos() {
  const { data, error } = await supabase
    .from('circulos')
    .select('*')
    .order('nome')

  console.log('CIRCULOS:', data)
  console.log('ERRO CIRCULOS:', error)

  if (error) {
    console.error(error)
    toast.error('Erro ao carregar círculos.')
    return
  }

  circulos.value = data || []
}

async function carregarEquipes() {
  const { data, error } = await supabase
    .from('equipes')
    .select('*')
    .order('nome')

  if (error) {
    console.error(error)
    toast.error('Erro ao carregar equipes.')
    return
  }

  equipes.value = data || []
}

async function carregarPessoas() {

  const { data, error } = await supabase
    .from('pessoas')
    .select(`
      *,
      circulos (
        id,
        nome
      ),
      equipes (
        id,
        nome
      )
    `)
    .order('nome')

  if (error) {
    console.error(error)
    toast.error('Erro ao carregar pessoas.')
    return
  }

  pessoas.value = data || []
}

const pessoasFiltradas = computed(() => {
  const texto = pesquisa.value.trim().toLowerCase()

  return pessoas.value.filter((p) => {
    const passouPesquisa =
      !texto ||
      p.nome.toLowerCase().includes(texto) ||
      p.telefone.includes(texto)

    const passouFiltro =
      filtrosSelecionados.value.length === 0 ||
      filtrosSelecionados.value.includes(p.circulos?.nome) ||
      filtrosSelecionados.value.includes(p.equipes?.nome)

    return passouPesquisa && passouFiltro
  })
})

function limparFormulario() {

  form.value = {
    nome: '',
    telefone: '',
    tipo: 'Jovem',
    circulo_id: null,
    equipe_id: null,
    responsavel: '',
    observacao: ''
  }

}

async function salvarPessoa() {

  if (!form.value.nome.trim()) {
    toast.warning('Informe o nome.')
    return
  }

  if (!form.value.telefone.trim()) {
    toast.warning('Informe o telefone.')
    return
  }

  if (
    form.value.tipo === 'Jovem' &&
    !form.value.circulo_id
  ) {
    toast.warning('Selecione um círculo.')
    return
  }

  if (
    form.value.tipo === 'Servo' &&
    !form.value.equipe_id
  ) {
    toast.warning('Selecione uma equipe.')
    return
  }

  const { error } = await supabase
    .from('pessoas')
    .insert({

      nome: form.value.nome.trim(),

      telefone: form.value.telefone,

      tipo: form.value.tipo,

      circulo_id:
        form.value.tipo === 'Jovem'
          ? form.value.circulo_id
          : null,

      equipe_id:
        form.value.tipo === 'Servo'
          ? form.value.equipe_id
          : null,

      responsavel: form.value.responsavel,

      observacao: form.value.observacao

    })

  if (error) {
  console.log(error)
  alert(error.message)
  toast.error(error.message)
  return
}

  toast.success('Pessoa cadastrada.')

  modalCadastro.value = false

  limparFormulario()

  carregarPessoas()

}

function editarPessoa(pessoa) {

  pessoaEditando.value = pessoa.id

  form.value = {

    nome: pessoa.nome,

    telefone: pessoa.telefone,

    tipo: pessoa.tipo,

    circulo_id: pessoa.circulo_id,

    equipe_id: pessoa.equipe_id,

    responsavel: pessoa.responsavel || '',

    observacao: pessoa.observacao || ''

  }

  modalEdicao.value = true

}

async function atualizarPessoa() {

  const { error } = await supabase

    .from('pessoas')

    .update({

      nome: form.value.nome,

      telefone: form.value.telefone,

      tipo: form.value.tipo,

      circulo_id:
        form.value.tipo === 'Jovem'
          ? form.value.circulo_id
          : null,

      equipe_id:
        form.value.tipo === 'Servo'
          ? form.value.equipe_id
          : null,

      responsavel: form.value.responsavel,

      observacao: form.value.observacao

    })

    .eq('id', pessoaEditando.value)

  if (error) {

    console.error(error)

    toast.error('Erro ao atualizar.')

    return

  }

  toast.success('Pessoa atualizada.')

  modalEdicao.value = false

  limparFormulario()

  await carregarPessoas()

}

async function excluirPessoa(id) {

  const { error } = await supabase
    .from('pessoas')
    .delete()
    .eq('id', id)

  if (error) {

    console.error(error)

    if (error.code === '23503') {
      toast.error('Não é possível excluir esta pessoa, pois ela possui vendas ou pagamentos registrados.')
      return
    }

    toast.error('Erro ao excluir a pessoa.')
    return
  }

  toast.success('Pessoa removida.')

  await carregarPessoas()

}

onMounted(async () => {

  await carregarCirculos()

  await carregarEquipes()

  await carregarPessoas()

})

const paginaAtual = ref(1)

const itensPorPagina = 10

const totalPaginas = computed(() =>
  Math.ceil(pessoasFiltradas.value.length / itensPorPagina)
)

const pessoasPaginadas = computed(() => {

  const inicio = (paginaAtual.value - 1) * itensPorPagina

  const fim = inicio + itensPorPagina

  return pessoasFiltradas.value.slice(inicio, fim)

})

watch(pesquisa, () => {

  paginaAtual.value = 1

})

function paginaAnterior() {

  if (paginaAtual.value > 1)

    paginaAtual.value--

}

function proximaPagina() {

  if (paginaAtual.value < totalPaginas.value)

    paginaAtual.value++

}
</script>

<template>
  <div class="page">

    <!-- CABEÇALHO -->
    <div class="page-header">

      <div>
        <h1>Pessoas</h1>
        <p>
          Gerencie os jovens e servos cadastrados no sistema.
        </p>
      </div>

      <button
        class="btn-primary"
        @click="modalCadastro = true"
      >
        Cadastrar Pessoa
      </button>

    </div>

    <!-- CARDS -->
    <div class="cards-resumo">

      <div class="card-info">

        <span>Total de Pessoas</span>

        <strong>
          {{ pessoas.length }}
        </strong>

      </div>

      <div class="card-info">

        <span>Jovens</span>

        <strong>
          {{ pessoas.filter(p => p.tipo === 'Jovem').length }}
        </strong>

      </div>

      <div class="card-info">

        <span>Servos</span>

        <strong>
          {{ pessoas.filter(p => p.tipo === 'Servo').length }}
        </strong>

      </div>

    </div>

    <!-- CARD PRINCIPAL -->

    <section class="card">

      <!-- PESQUISA -->

      <div class="toolbar">

  <input
    v-model="pesquisa"
    class="search"
    autocomplete="off"
    placeholder="Pesquisar por nome ou telefone..."
  />

  <div class="filtro-dropdown">

    <button
      type="button"
      class="btn-filtro"
      @click="mostrarFiltros = !mostrarFiltros"
    >
      Filtros
      <span v-if="filtrosSelecionados.length">
        ({{ filtrosSelecionados.length }})
      </span>
    </button>

    <div
  v-if="mostrarFiltros"
  class="dropdown-menu"
>
  <div class="filtro-grupo">
    <h4>Círculos</h4>

    <label
      v-for="circulo in circulos"
      :key="'c' + circulo.id"
      class="item-filtro"
    >
      <input
        type="checkbox"
        :value="circulo.nome"
        v-model="filtrosSelecionados"
      >
      {{ circulo.nome }}
    </label>
  </div>

  <hr>

  <div class="filtro-grupo">
    <h4>Equipes</h4>

    <label
      v-for="equipe in equipes"
      :key="'e' + equipe.id"
      class="item-filtro"
    >
      <input
        type="checkbox"
        :value="equipe.nome"
        v-model="filtrosSelecionados"
      >
      {{ equipe.nome }}
    </label>
  </div>

  <div class="acoes-filtro">
    <button
      type="button"
      class="btn-limpar"
      @click="filtrosSelecionados = []"
    >
      Limpar filtros
    </button>
  </div>
</div>

  </div>

</div>

      <!-- TABELA -->

      <div class="table-responsive">

        <table>

          <thead>

            <tr>

              <th>Nome</th>

              <th>Telefone</th>

              <th>Tipo</th>

              <th>Círculo / Equipe</th>

              <th>Responsável</th>

              <th width="170">
                Ações
              </th>

            </tr>

          </thead>

          <tbody>

            <tr
              v-for="pessoa in pessoasPaginadas"
              :key="pessoa.id"
            >

              <td>

                <div class="nome">

                  {{ pessoa.nome }}

                </div>

              </td>

              <td>

                {{ pessoa.telefone }}

              </td>

              <td>

                <span
                  class="badge"
                  :class="pessoa.tipo === 'Jovem'
                    ? 'badge-jovem'
                    : 'badge-servo'"
                >

                  {{ pessoa.tipo }}

                </span>

              </td>

              <td>

                <span
                  v-if="pessoa.tipo === 'Jovem'"
                >

                  {{ pessoa.circulos?.nome || '-' }}

                </span>

                <span
                  v-else
                >

                  {{ pessoa.equipes?.nome || '-' }}

                </span>

              </td>

              <td>

                {{ pessoa.responsavel || '-' }}

              </td>

              <td>

                <div class="acoes">

                  <button
                    class="btn-edit"
                    @click="editarPessoa(pessoa)"
                  >
                    Editar
                  </button>

                  <button
                    class="btn-delete"
                    @click="excluirPessoa(pessoa.id)"
                  >
                    Excluir
                  </button>

                </div>

              </td>

            </tr>

            <tr
              v-if="!pessoasPaginadas.length"
            >

              <td
                colspan="6"
                class="empty"
              >

                Nenhuma pessoa encontrada.

              </td>

            </tr>

          </tbody>

        </table>

        <div
  class="paginacao"
  v-if="totalPaginas > 1"
>

  <button
    @click="paginaAnterior"
    :disabled="paginaAtual === 1"
  >
    ← Anterior
  </button>

  <span>

    Página {{ paginaAtual }} de {{ totalPaginas }}

  </span>

  <button
    @click="proximaPagina"
    :disabled="paginaAtual === totalPaginas"
  >
    Próxima →
  </button>

</div>

      </div>

    </section>

    <!-- ========================= -->
        <!-- ========================= -->
    <!-- MODAL DE CADASTRO -->
    <!-- ========================= -->

    <Transition name="fade">

      <div
        v-if="modalCadastro"
        class="modal-overlay"
      >

        <div class="modal">

          <div class="modal-header">

            <div>

              <h2>Nova Pessoa</h2>

              <p>
                Preencha os dados para realizar o cadastro.
              </p>

            </div>

            <button
              class="btn-close"
              @click="modalCadastro = false"
            >
              ×
            </button>

          </div>

          <div class="form-grid">

            <!-- Nome -->

            <div class="field">

              <label>Nome *</label>

              <input
                v-model="form.nome"
                type="text"
                placeholder="Nome completo"
                autofocus
              />

            </div>

            <!-- Telefone -->

            <div class="field">

              <label>Telefone *</label>

              <input
                v-model="form.telefone"
                type="text"
                placeholder="(99) 99999-9999"
              />

            </div>

            <!-- Tipo -->

            <div class="field">

              <label>Tipo *</label>

              <select
                v-model="form.tipo"
              >

                <option value="Jovem">
                  Jovem
                </option>

                <option value="Servo">
                  Servo
                </option>

              </select>

            </div>

            <!-- Circulo -->

            <div
              class="field"
              v-if="form.tipo === 'Jovem'"
            >

              <label>Círculo *</label>

              <select
                v-model="form.circulo_id"
              >

                <option :value="null">
                  Selecione
                </option>

                <option
                  v-for="circulo in circulos"
                  :key="circulo.id"
                  :value="circulo.id"
                >

                  {{ circulo.nome }}

                </option>

              </select>

            </div>

            <!-- Equipe -->

            <div
              class="field"
              v-if="form.tipo === 'Servo'"
            >

              <label>Equipe *</label>

              <select
                v-model="form.equipe_id"
              >

                <option :value="null">
                  Selecione
                </option>

                <option
                  v-for="equipe in equipes"
                  :key="equipe.id"
                  :value="equipe.id"
                >

                  {{ equipe.nome }}

                </option>

              </select>

            </div>

            <!-- Responsável -->

            <div class="field full">

              <label>Responsável</label>

              <input
                v-model="form.responsavel"
                type="text"
                placeholder="Nome do responsável (opcional)"
              />

            </div>

            <!-- Observação -->

            <div class="field full">

              <label>Observação</label>

              <textarea
                v-model="form.observacao"
                rows="4"
                placeholder="Observações adicionais..."
              />

            </div>

          </div>

          <div class="modal-footer">

            <button
              class="btn-secondary"
              @click="modalCadastro = false"
            >

              Cancelar

            </button>

            <button
              class="btn-primary"
              @click="salvarPessoa"
            >

              Salvar Pessoa

            </button>

          </div>

        </div>

      </div>

    </Transition>

        <!-- ========================= -->
    <!-- MODAL DE EDIÇÃO -->
    <!-- ========================= -->

    <Transition name="fade">

      <div
        v-if="modalEdicao"
        class="modal-overlay"
      >

        <div class="modal">

          <div class="modal-header">

            <div>

              <h2>Editar Pessoa</h2>

              <p>
                Atualize as informações da pessoa cadastrada.
              </p>

            </div>

            <button
              class="btn-close"
              @click="modalEdicao = false"
            >
              ×
            </button>

          </div>

          <div class="form-grid">

            <!-- Nome -->

            <div class="field">

              <label>Nome *</label>

              <input
                v-model="form.nome"
                type="text"
                placeholder="Nome completo"
              />

            </div>

            <!-- Telefone -->

            <div class="field">

              <label>Telefone *</label>

              <input
                v-model="form.telefone"
                type="text"
                placeholder="(99) 99999-9999"
              />

            </div>

            <!-- Tipo -->

            <div class="field">

              <label>Tipo *</label>

              <select
                v-model="form.tipo"
              >

                <option value="Jovem">
                  Jovem
                </option>

                <option value="Servo">
                  Servo
                </option>

              </select>

            </div>

            <!-- Círculo -->

            <div
              class="field"
              v-if="form.tipo === 'Jovem'"
            >

              <label>Círculo *</label>

              <select
                v-model="form.circulo_id"
              >

                <option :value="null">
                  Selecione
                </option>

                <option
                  v-for="circulo in circulos"
                  :key="circulo.id"
                  :value="circulo.id"
                >
                  {{ circulo.nome }}
                </option>

              </select>

            </div>

            <!-- Equipe -->

            <div
              class="field"
              v-if="form.tipo === 'Servo'"
            >

              <label>Equipe *</label>

              <select
                v-model="form.equipe_id"
              >

                <option :value="null">
                  Selecione
                </option>

                <option
                  v-for="equipe in equipes"
                  :key="equipe.id"
                  :value="equipe.id"
                >
                  {{ equipe.nome }}
                </option>

              </select>

            </div>

            <!-- Responsável -->

            <div class="field full">

              <label>Responsável</label>

              <input
                v-model="form.responsavel"
                type="text"
                placeholder="Nome do responsável"
              />

            </div>

            <!-- Observação -->

            <div class="field full">

              <label>Observação</label>

              <textarea
                v-model="form.observacao"
                rows="4"
                placeholder="Observações adicionais..."
              />

            </div>

          </div>

          <div class="modal-footer">

            <button
              class="btn-secondary"
              @click="modalEdicao = false"
            >
              Cancelar
            </button>

            <button
              class="btn-primary"
              @click="atualizarPessoa"
            >
              Atualizar Pessoa
            </button>

          </div>

        </div>

      </div>

    </Transition>

  </div>

</template>

<style scoped>
/* ==========================================
   PÁGINA
========================================== */

.page{
    padding:32px;
    display:flex;
    flex-direction:column;
    gap:24px;
    background:#f5f7fb;
    min-height:100vh;
}

/* ==========================================
   CABEÇALHO
========================================== */

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
    font-weight:700;
    color:#163b63;
}

.page-header p{
    margin-top:6px;
    color:#6c7a89;
    font-size:15px;
}

/* ==========================================
   BOTÕES
========================================== */

.btn-primary{
    border:none;
    background:#163b63;
    color:#fff;
    padding:14px 24px;
    border-radius:10px;
    font-size:15px;
    font-weight:600;
    cursor:pointer;
    transition:.25s;
}

.btn-primary:hover{
    background:#20558d;
    transform:translateY(-1px);
}

.btn-secondary{
    border:none;
    background:#edf1f5;
    color:#163b63;
    padding:14px 22px;
    border-radius:10px;
    font-size:15px;
    cursor:pointer;
    transition:.25s;
}

.btn-secondary:hover{
    background:#dfe6ee;
}

/* ==========================================
   CARDS
========================================== */

.cards-resumo{
    display:grid;
    grid-template-columns:repeat(3,1fr);
    gap:20px;
}

.card-info{
    background:white;
    border-radius:18px;
    padding:24px;
    box-shadow:0 8px 25px rgba(0,0,0,.06);
    display:flex;
    flex-direction:column;
}

.card-info span{
    color:#8a96a8;
    font-size:14px;
}

.card-info strong{
    margin-top:10px;
    font-size:34px;
    color:#163b63;
}

/* ==========================================
   CARD
========================================== */

.card{
    background:white;
    border-radius:18px;
    padding:25px;
    box-shadow:0 8px 25px rgba(0,0,0,.06);
}

/* ==========================================
   PESQUISA
========================================== */

.toolbar{
    display:flex;
    align-items:center;
    gap:12px;
}

.search{
    width:100%;
    height:48px;
    border:1px solid #d7dde5;
    border-radius:10px;
    padding:0 16px;
    font-size:15px;
    transition:.25s;
    flex:1;
}

.search:focus{
    outline:none;
    border-color:#163b63;
    box-shadow:0 0 0 3px rgba(22,59,99,.10);
}

/* ==========================================
   TABELA
========================================== */

.table-responsive{
    overflow-x:auto;
}

table{
    width:100%;
    border-collapse:collapse;
    min-width:900px;
}

thead tr{
    background:#163b63;
}

th{
    padding:16px;
    color:white;
    text-align:left;
    font-size:14px;
    font-weight:600;
}

td{
    padding:16px;
    border-bottom:1px solid #eef1f5;
    color:#3c4958;
    vertical-align:middle;
}

tbody tr{
    transition:.2s;
}

tbody tr:hover{
    background:#f8fbff;
}

.nome{
    font-weight:600;
    color:#163b63;
}

.empty{
    text-align:center;
    padding:45px;
    color:#8c97a7;
}

/* ==========================================
   BADGES
========================================== */

.badge{
    display:inline-flex;
    align-items:center;
    justify-content:center;
    min-width:82px;
    padding:7px 16px;
    border-radius:30px;
    font-size:13px;
    font-weight:600;
}

.badge-jovem{
    background:#e7f1ff;
    color:#1d64d6;
}

.badge-servo{
    background:#e9f8ef;
    color:#138b47;
}

/* ==========================================
   AÇÕES
========================================== */

.acoes{
    display:flex;
    gap:10px;
}

.btn-edit{
    border:none;
    background:#f39c12;
    color:white;
    padding:9px 14px;
    border-radius:8px;
    cursor:pointer;
    transition:.25s;
}

.btn-edit:hover{
    background:#db8b0f;
}

.btn-delete{
    border:none;
    background:#e74c3c;
    color:white;
    padding:9px 14px;
    border-radius:8px;
    cursor:pointer;
    transition:.25s;
}

.btn-delete:hover{
    background:#cc3d30;
}

/* ==========================================
   MODAL
========================================== */

.modal-overlay{
    position:fixed;
    inset:0;
    background:rgba(15,23,42,.55);
    backdrop-filter:blur(4px);
    display:flex;
    justify-content:center;
    align-items:center;
    padding:24px;
    z-index:9999;
}

.modal{
    width:100%;
    max-width:850px;
    max-height:90vh;
    overflow-y:auto;
    background:#fff;
    border-radius:20px;
    box-shadow:0 25px 60px rgba(0,0,0,.18);
    animation:modalOpen .25s ease;
}

/* ==========================================
   CABEÇALHO
========================================== */

.modal-header{
    display:flex;
    justify-content:space-between;
    align-items:flex-start;
    gap:20px;
    padding:28px 30px;
    border-bottom:1px solid #edf1f5;
}

.modal-header h2{
    margin:0;
    font-size:28px;
    color:#163b63;
}

.modal-header p{
    margin-top:8px;
    color:#7d8797;
    font-size:14px;
}

.btn-close{
    width:42px;
    height:42px;
    border:none;
    border-radius:50%;
    background:#eef3f8;
    color:#163b63;
    font-size:24px;
    cursor:pointer;
    transition:.25s;
    flex-shrink:0;
}

.btn-close:hover{
    background:#163b63;
    color:#fff;
    transform:rotate(90deg);
}

/* ==========================================
   FORMULÁRIO
========================================== */

.form-grid{
    display:grid;
    grid-template-columns:repeat(2,minmax(280px,1fr));
    gap:22px;
    padding:30px;
}

.field{
    display:flex;
    flex-direction:column;
}

.field.full{
    grid-column:1 / -1;
}

.field label{
    margin-bottom:8px;
    color:#163b63;
    font-weight:600;
    font-size:14px;
}

.field input,
.field select,
.field textarea{
    width:100%;
    border:1px solid #d8dee8;
    border-radius:10px;
    padding:13px 15px;
    font-size:15px;
    transition:.25s;
    box-sizing:border-box;
    background:#fff;
}

.field textarea{
    resize:vertical;
    min-height:120px;
}

.field input:focus,
.field select:focus,
.field textarea:focus{
    outline:none;
    border-color:#163b63;
    box-shadow:0 0 0 3px rgba(22,59,99,.12);
}

/* ==========================================
   RODAPÉ
========================================== */

.modal-footer{
    display:flex;
    justify-content:flex-end;
    gap:14px;
    padding:24px 30px;
    border-top:1px solid #edf1f5;
}

.modal-footer .btn-primary,
.modal-footer .btn-secondary{
    min-width:160px;
}

/* ==========================================
   SCROLLBAR
========================================== */

.modal::-webkit-scrollbar{
    width:8px;
}

.modal::-webkit-scrollbar-thumb{
    background:#c6cfda;
    border-radius:20px;
}

.modal::-webkit-scrollbar-track{
    background:transparent;
}

/* ==========================================
   ANIMAÇÕES
========================================== */

.fade-enter-active,
.fade-leave-active{
    transition:.25s;
}

.fade-enter-from,
.fade-leave-to{
    opacity:0;
}

@keyframes modalOpen{

    from{
        opacity:0;
        transform:translateY(-20px) scale(.98);
    }

    to{
        opacity:1;
        transform:translateY(0) scale(1);
    }

}

/* ==========================================
   FILTRO
========================================== */

.filtro-dropdown{
    position:relative;
}

.btn-filtro{
    height:48px;
    min-width:120px;
    padding:0 18px;
    border:none;
    border-radius:12px;
    background:#163b63;
    color:#fff;
    font-size:14px;
    font-weight:600;
    cursor:pointer;
    transition:.25s;
}

.btn-filtro:hover{
    background:#1d4f84;
}

.dropdown-menu{
    position:absolute;
    top:56px;
    right:0;
    width:300px;
    max-height:420px;
    overflow-y:auto;
    background:#fff;
    border-radius:16px;
    box-shadow:0 15px 35px rgba(0,0,0,.15);
    padding:18px;
    z-index:999;
    border:1px solid #e5e7eb;
}

.filtro-grupo{
    display:flex;
    flex-direction:column;
    gap:6px;
}

.filtro-grupo h4{
    margin:0 0 8px;
    font-size:13px;
    color:#163b63;
    text-transform:uppercase;
    letter-spacing:.6px;
}

.item-filtro{
    display:flex;
    align-items:center;
    gap:10px;
    padding:8px 10px;
    border-radius:8px;
    cursor:pointer;
    transition:.2s;
}

.item-filtro:hover{
    background:#f5f7fb;
}

.item-filtro input{
    width:16px;
    height:16px;
    cursor:pointer;
}

.dropdown-menu hr{
    border:none;
    border-top:1px solid #e8edf3;
    margin:16px 0;
}

.acoes-filtro{
    margin-top:18px;
}

.btn-limpar{
    width:100%;
    border:none;
    border-radius:10px;
    background:#163b63;
    color:#fff;
    padding:10px;
    font-weight:600;
    cursor:pointer;
    transition:.2s;
}

.btn-limpar:hover{
    background:#1d4f84;
}

/* ==========================================
   NOTEBOOKS (até 1200px)
========================================== */

@media (max-width:1200px){

    .cards-resumo{
        grid-template-columns:repeat(3,1fr);
    }

    .modal{
        max-width:760px;
    }

}

/* ==========================================
   TABLETS (até 992px)
========================================== */

@media (max-width:992px){

    .page{
        padding:24px;
    }

    .page-header{
        flex-direction:column;
        align-items:flex-start;
    }

    .page-header button{
        width:100%;
    }

    .cards-resumo{
        grid-template-columns:1fr;
    }

    .card-info{
        padding:20px;
    }

    .card-info strong{
        font-size:28px;
    }

    .modal{
        width:95%;
    }

    .form-grid{
        grid-template-columns:1fr;
        padding:24px;
    }

    .field.full{
        grid-column:auto;
    }

}

/* ==========================================
   CELULARES (até 768px)
========================================== */

@media (max-width:768px){

    .page{
        padding:16px;
        gap:18px;
    }

    .page-header h1{
        font-size:26px;
    }

    .page-header p{
        font-size:14px;
    }

    .btn-primary,
    .btn-secondary{
        width:100%;
    }

    .card{
        padding:16px;
    }

    .card-info{
        padding:18px;
    }

    .card-info strong{
        font-size:24px;
    }

    .toolbar{
    display:flex;
    align-items:center;
    gap:12px;
    margin-bottom:18px;
}

.search{
    flex:1;
    height:46px;
    font-size:14px;
}

    .table-responsive{
        overflow-x:auto;
        border-radius:12px;
    }

    table{
        min-width:700px;
    }

    th,
    td{
        padding:12px;
        font-size:14px;
    }

    .acoes{
        flex-direction:column;
        gap:8px;
    }

    .btn-edit,
    .btn-delete{
        width:100%;
    }

    .modal-overlay{
        padding:10px;
        align-items:flex-end;
    }

    .modal{
        width:100%;
        max-width:none;
        max-height:95vh;
        border-radius:20px 20px 0 0;
    }

    .modal-header{
        padding:20px;
    }

    .modal-header h2{
        font-size:22px;
    }

    .modal-header p{
        font-size:13px;
    }

    .btn-close{
        width:38px;
        height:38px;
        font-size:20px;
    }

    .form-grid{
        padding:20px;
        grid-template-columns:1fr;
        gap:18px;
    }

    .field label{
        font-size:13px;
    }

    .field input,
    .field select,
    .field textarea{
        font-size:14px;
        padding:12px;
    }

    .modal-footer{
        padding:20px;
        flex-direction:column-reverse;
    }

    .modal-footer button{
        width:100%;
    }

}

.filtro-dropdown {
  position: relative;
}

.btn-filtro{
    display:flex;
    align-items:center;
    justify-content:center;
    gap:6px;

    min-width:120px;
    height:46px;

    padding:0 18px;

    background:#ffffff;
    color:#163b63;

    border:1px solid #d5dce5;
    border-radius:12px;

    font-size:14px;
    font-weight:600;

    cursor:pointer;
    transition:.2s;
}

.btn-filtro:hover{
    background:#f7f9fc;
    border-color:#163b63;
}

.btn-filtro:hover {
  background: #f5f7fb;
}

.dropdown-menu {
  position: absolute;
  top: 50px;
  right: 0;
  width: 260px;
  max-height: 320px;
  overflow-y: auto;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  box-shadow: 0 10px 30px rgba(0,0,0,.12);
  padding: 10px;
  z-index: 999;
}

/* ==========================================
   CELULARES PEQUENOS (até 480px)
========================================== */

@media (max-width:480px){

    .page{
        padding:12px;
    }

    .page-header h1{
        font-size:22px;
    }

    .card-info{
        padding:16px;
    }

    .card-info strong{
        font-size:22px;
    }

    .modal-header{
        padding:18px;
    }

    .form-grid{
        padding:18px;
    }

    .modal-footer{
        padding:18px;
    }

}
.paginacao{

  display:flex;

  justify-content:center;

  align-items:center;

  gap:20px;

  margin-top:20px;

}

.paginacao button{

  padding:10px 18px;

}

.paginacao button:disabled{

  opacity:.5;

  cursor:not-allowed;

}

</style>