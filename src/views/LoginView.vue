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
    <section class="login-card" aria-labelledby="login-title">
      <img class="login-mark" src="/img/xi-ejc-pss.png" alt="Logo XI EJC PSS">
      <h1 id="login-title">XI EJC PSS</h1>

      <div class="login-form">
        <input
          v-model="email"
          type="email"
          placeholder="E-mail"
          aria-label="E-mail"
          autocomplete="username"
        >
        <input
          v-model="senha"
          type="password"
          placeholder="Senha"
          aria-label="Senha"
          autocomplete="current-password"
        >
        <button type="button" @click="entrar" :disabled="carregando">
          {{ carregando ? 'Entrando...' : 'Entrar' }}
        </button>
      </div>
    </section>
  </div>
</template>

<style scoped>
.login-container {
  width: 100%;
  min-height: 100vh;
  min-height: 100dvh;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 20px;
  background: radial-gradient(ellipse at top, #292720 0%, #171614 48%, #0b0b0b 100%);
}

.login-card {
  width: min(100%, 380px);
  padding: 30px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 18px;
  border-radius: 18px;
  background: #fff;
  box-shadow: 0 16px 42px rgba(0, 0, 0, .28);
  text-align: center;
}

.login-mark {
  width: 70px;
  height: 70px;
  object-fit: contain;
}

h1 {
  color: #151515;
  font-size: 24px;
  line-height: 1.2;
  font-weight: 700;
}

.login-form {
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 13px;
}

.login-form input {
  width: 100%;
  min-height: 46px;
  padding: 12px 14px;
  border: 1px solid #dedbd2;
  border-radius: 10px;
  background: #fff;
  color: #1b1b1b;
}

.login-form input:focus {
  border-color: #b98616;
  outline: 2px solid rgba(253, 181, 46, .25);
}

.login-form button {
  min-height: 46px;
  padding: 12px;
  border: 1px solid #fdb52e;
  border-radius: 10px;
  background: #fdb52e;
  color: #151515;
  font-weight: 700;
  transition: background .2s ease, transform .2s ease;
}

.login-form button:hover:not(:disabled) {
  background: #e5a11d;
  transform: translateY(-1px);
}

.login-form button:disabled {
  opacity: .7;
  cursor: wait;
}

@media (max-width: 480px) {
  .login-container {
    padding: 16px;
  }

  .login-card {
    padding: 26px 22px;
    gap: 16px;
  }
}
</style>
