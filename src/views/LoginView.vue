<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useToast } from 'vue-toastification'

import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()
const router = useRouter()
const toast = useToast()

const email = ref('')
const senha = ref('')
const carregando = ref(false)

async function entrar() {
  carregando.value = true

  try {
    await auth.login(email.value, senha.value)

    toast.success('Login realizado com sucesso!')

    router.push('/')
  } catch (error) {
    toast.error(error.message)
  } finally {
    carregando.value = false
  }
}
</script>

<template>
  <div class="login-container">
    <div class="login-card">

      <h1>Sistema EJC</h1>

      <input
        v-model="email"
        type="email"
        placeholder="E-mail"
      >

      <input
        v-model="senha"
        type="password"
        placeholder="Senha"
      >

      <button
        @click="entrar"
        :disabled="carregando"
      >
        {{ carregando ? 'Entrando...' : 'Entrar' }}
      </button>

    </div>
  </div>
</template>

<style scoped>
.login-container{
    min-height:100vh;
    display:flex;
    justify-content:center;
    align-items:center;
    background:#f4f4f4;
}

.login-card{
    width:350px;
    background:white;
    padding:30px;
    border-radius:12px;
    display:flex;
    flex-direction:column;
    gap:15px;
    box-shadow:0 5px 20px rgba(0,0,0,.1);
}

input{
    padding:12px;
    border-radius:8px;
    border:1px solid #ccc;
}

button{
    padding:12px;
    border:none;
    border-radius:8px;
    cursor:pointer;
}
</style>