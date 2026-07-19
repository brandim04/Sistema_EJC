<template>
  <div class="app">
    <aside class="sidebar">
      <div class="logo-area">
        <img src="/img/logo-ejc.png" alt="Logo EJC" class="logo" />

        <h1>EJC</h1>
        <p>Paróquia N. Sra. de Guadalupe</p>
      </div>

      <nav class="menu">
        <router-link to="/dashboard">Painel de controle</router-link>
        <router-link to="/pessoas">Pessoas</router-link>
        <router-link to="/produtos">Produtos</router-link>
        <router-link to="/vendas">Vendas</router-link>
        <router-link to="/relatorios">Relatórios</router-link>
      </nav>

      <section class="theme-card">
        <span>VIII ENCONTRO</span>

        <h2>
          TUA VONTADE<br />
          É O MEU CÉU
        </h2>

  <div class="gold-line"></div>

  <p>
    “O mundo e os desejos que vêm dele passam.
    Por outro lado, quem faz a vontade de Deus
    permanece para sempre.”
  </p>

  <strong>1 JOÃO 2,17</strong>
    </section>

    </aside>

    <main class="content">
      <router-view />
    </main>
  </div>
</template>

<style>
@import url('https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap');

:root {
  --azul-claro: #9ecce5;
  --azul-medio: #5f9fc4;
  --azul-escuro: #0b3558;
  --azul-profundo: #062f52;
  --dourado: #d6b35f;
  --branco: #ffffff;
  --fundo: #f8fbfd;
  --texto: #0b2f4f;
}

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  font-family: 'Poppins', sans-serif;
  background: var(--fundo);
  color: var(--texto);
}

.app {
  min-height: 100vh;
  display: flex;
}

.sidebar {
  width: 300px;
  min-height: 100vh;
  padding: 24px 18px;
  background:
    radial-gradient(circle at bottom, rgba(255,255,255,0.35), transparent 28%),
    linear-gradient(180deg, #88bddc 0%, #3f84ad 42%, #07375b 100%);
  color: white;
  position: relative;
  overflow: hidden;
}

.logo-area {
  text-align: center;
  position: relative;
  z-index: 2;
}

.logo {
  width: 105px;
  height: 105px;
  object-fit: contain;
  background: white;
  border-radius: 50%;
  padding: 8px;
  margin-bottom: 14px;
  box-shadow: 0 8px 20px rgba(0,0,0,0.16);
}

.logo-area h1 {
  margin: 0;
  color: var(--azul-escuro);
  font-size: 42px;
  font-weight: 800;
  line-height: 1;
}

.logo-area p {
  margin: 10px 0 22px;
  font-size: 17px;
  line-height: 1.3;
  color: white;
  font-weight: 500;
}

.theme-card {
  background: rgba(255, 255, 255, 0.96);
  color: var(--azul-escuro);
  border: 2px solid var(--dourado);
  border-radius: 18px;
  padding: 20px;
  margin-bottom: 22px;
  box-shadow: 0 10px 26px rgba(0,0,0,0.16);
  position: relative;
  z-index: 2;
}

.theme-card span {
  display: block;
  color: var(--dourado);
  font-weight: 800;
  font-size: 14px;
  margin-bottom: 14px;
}

.theme-card h2 {
  margin: 0;
  color: var(--azul-profundo);
  font-size: 27px;
  font-weight: 900;
  line-height: 1.08;
  letter-spacing: -0.5px;
}

.gold-line {
  width: 70px;
  height: 3px;
  background: var(--dourado);
  margin: 24px 0 18px;
  border-radius: 999px;
}

.theme-card p {
  margin: 0;
  color: #163b5c;
  font-size: 15px;
  line-height: 1.6;
  font-weight: 500;
}

.theme-card strong {
  display: block;
  color: var(--dourado);
  margin-top: 18px;
  font-size: 20px;
  font-weight: 900;
}

.menu {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-bottom: 32px;
}

.menu a {
  color: var(--azul-escuro);
  background: rgba(255,255,255,0.95);
  text-decoration: none;
  padding: 16px 20px;
  border-radius: 14px;
  font-size: 18px;
  font-weight: 600;
  letter-spacing: 0.2px;
  box-shadow: 0 6px 14px rgba(0,0,0,0.08);
  transition: all 0.2s ease;
}

.menu a:hover,
.menu a.router-link-active {
  background: white;
  border-left: 4px solid var(--dourado);
  padding-left: 16px;
}

.sidebar-illustration {
  position: absolute;
  left: 0;
  right: 0;
  bottom: -8px;
  height: 210px;
  opacity: 0.45;
  pointer-events: none;
}

.halo {
  width: 150px;
  height: 150px;
  border: 2px solid var(--dourado);
  border-radius: 50%;
  margin: 30px auto 0;
}

.clouds {
  position: absolute;
  left: -20px;
  right: -20px;
  bottom: 0;
  height: 90px;
  background:
    radial-gradient(circle at 20% 60%, white 0 28px, transparent 29px),
    radial-gradient(circle at 38% 40%, white 0 38px, transparent 39px),
    radial-gradient(circle at 58% 58%, white 0 32px, transparent 33px),
    radial-gradient(circle at 78% 42%, white 0 40px, transparent 41px);
}

.content {
  flex: 1;
  padding: 30px;
  background: var(--fundo);
}

h1, h2, h3 {
  color: var(--azul-escuro);
}

button {
  background: var(--azul-escuro);
  color: white;
  border: none;
  border-radius: 10px;
  padding: 11px 16px;
  cursor: pointer;
  font-weight: bold;
}

input,
select,
textarea {
  border: 1px solid #d7e4ec;
  border-radius: 10px;
  padding: 11px;
  outline: none;
}

input:focus,
select:focus,
textarea:focus {
  border-color: var(--azul-medio);
}

@media (max-width: 850px) {
  .app {
    flex-direction: column;
  }

  .sidebar {
    width: 100%;
    min-height: auto;
  }

  .sidebar-illustration {
    display: none;
  }

  .content {
    padding: 18px;
  }
}
</style>