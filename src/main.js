import { createApp } from 'vue'
import { createPinia } from 'pinia'
import Toast from 'vue-toastification'

import 'vue-toastification/dist/index.css'

import App from './App.vue'
import router from './router'

const app = createApp(App)

app.use(createPinia())
app.use(router)
app.use(Toast, {
  timeout: 2500,
  maxToasts: 1,
  newestOnTop: true,
  hideProgressBar: false,
  closeOnClick: true,
  pauseOnHover: true
})

app.mount('#app')