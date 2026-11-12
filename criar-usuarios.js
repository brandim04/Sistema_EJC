
import 'dotenv/config'
import { createClient } from '@supabase/supabase-js'

const url = process.env.SUPABASE_URL
const key = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!url || !key) {
  throw new Error('Configure SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY no .env')
}

const supabase = createClient(url, key, {
  auth: { autoRefreshToken: false, persistSession: false }
})

const senha = 'ejcpss2026'

const usuarios = [
  ['Vinícius Rodriguees', 'vinicius', 'ADMIN'],
  ['Jayana Andrade', 'jayana', 'ADMIN'],
  ['Tio Cecilío', 'cecilio', 'ADMIN'],
  ['Tia Jordânia', 'jordania', 'ADMIN'],
  ['Tia Antônia Danielle', 'antonia', 'VENDEDOR'],
  ['Tio Denilson Ribeiro', 'denilson', 'VENDEDOR'],
  ['Tio Francisco Lucas Eustáquio', 'francisco', 'VENDEDOR'],
  ['Tia Ariadina Dantas', 'ariadina', 'VENDEDOR'],
  ['Andressa Laís', 'andressa', 'VENDEDOR'],
  ['Maricelmo Barroso', 'maricelmo', 'VENDEDOR'],
  ['Natania Mairla', 'natania', 'VENDEDOR'],
  ['Leonardo Mendes', 'leonardo', 'VENDEDOR'],
  ['Maria Eduarda Stefani', 'maria.eduarda', 'VENDEDOR'],
  ['Pedro Iam Rodrigues', 'pedro', 'VENDEDOR'],
  ['Lara Beatriz', 'lara', 'VENDEDOR'],
  ['Eric Arthur', 'eric', 'VENDEDOR'],
  ['Maria Júlia', 'maria.julia', 'VENDEDOR'],
  ['Gabriel WILLIAM', 'gabriel', 'VENDEDOR'],
  ['Mayra Beatriz', 'mayra', 'VENDEDOR'],
  ['Evergestys Sirac', 'evergestys', 'VENDEDOR']
]

async function buscarUsuario(email) {
  let pagina = 1
  while (true) {
    const { data, error } = await supabase.auth.admin.listUsers({
      page: pagina,
      perPage: 1000
    })
    if (error) throw error

    const encontrado = data.users.find(
      user => user.email?.toLowerCase() === email.toLowerCase()
    )
    if (encontrado) return encontrado
    if (data.users.length < 1000) return null
    pagina++
  }
}

let sucessos = 0
let falhas = 0

for (const [nome, login, perfil] of usuarios) {
  const email = `${login}@ejc.local`

  try {
    let usuario = await buscarUsuario(email)
    let criadoAgora = false

    if (!usuario) {
      const { data, error } = await supabase.auth.admin.createUser({
        email,
        password: senha,
        email_confirm: true
      })
      if (error) throw error
      usuario = data.user
      criadoAgora = true
    }

    const { error } = await supabase.from('usuarios').upsert({
      id: usuario.id,
      nome,
      email,
      perfil,
      ativo: true
    }, { onConflict: 'id' })

    if (error) {
      if (criadoAgora) {
        await supabase.auth.admin.deleteUser(usuario.id)
      }
      throw error
    }

    console.log(`OK: ${nome} | ${email} | ${perfil}`)
    sucessos++
  } catch (error) {
    console.error(`ERRO: ${nome} | ${error.message}`)
    falhas++
  }
}

console.log(`\nFinalizado: ${sucessos} usuários configurados, ${falhas} erros.`)
