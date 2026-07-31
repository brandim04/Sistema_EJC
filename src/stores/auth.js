import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'

export const useAuthStore = defineStore('auth', () => {
  const user = ref(null)
  const session = ref(null)
  const usuario = ref(null)

  async function carregarSessao() {
    const {
      data: { session: currentSession }
    } = await supabase.auth.getSession()

    session.value = currentSession
    user.value = currentSession?.user ?? null

    if (user.value) {
      await carregarUsuario()
    }
  }

  async function carregarUsuario() {
    if (!user.value) {
      usuario.value = null
      return
    }

    const { data, error } = await supabase
      .from('usuarios')
      .select('*')
      .eq('id', user.value.id)
      .single()

    console.log('DATA:', data)
    console.log('ERROR:', error)

    if (error) throw error

    usuario.value = data
  }

  async function login(email, password) {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    })

    if (error) throw error

    session.value = data.session
    user.value = data.user

    await carregarUsuario()
  }

  async function logout() {
    await supabase.auth.signOut()

    session.value = null
    user.value = null
    usuario.value = null
  }

  return {
    user,
    session,
    usuario,
    carregarSessao,
    carregarUsuario,
    login,
    logout
  }
})