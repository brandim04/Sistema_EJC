<script setup>
import AppHeader from '../components/AppHeader.vue'
import AppSidebar from '../components/AppSidebar.vue'
</script>

<template>
  <div class="layout">

    <AppSidebar />

    <div class="main">

      <AppHeader />

      <main class="content">
        <RouterView />
      </main>

    </div>

  </div>
</template>

<style scoped>
.layout{
  display:flex;
  width:100%;
  height:100vh;
  overflow:hidden;
  background:#eef3f8;
}

.main{
  flex:1;
  display:flex;
  flex-direction:column;
  min-width:0;
  height:100vh;
}

.content{
  flex:1;
  overflow-y:auto;
  overflow-x:hidden;
  padding:28px;
  background:
    radial-gradient(circle at top right,#f7fbff 0%,#eef3f8 70%);
}

.sidebar{
  width:300px;
  min-width:300px;
  max-width:300px;

  height:100vh;

  display:flex;
  flex-direction:column;

  overflow:hidden;

  position:sticky;
  top:0;

  background:
    radial-gradient(circle at bottom, rgba(255,255,255,.30), transparent 30%),
    linear-gradient(180deg,#88bddc 0%,#4b8eb8 38%,#0b3558 100%);
}

@media (max-width:768px){

  .content{
    padding:18px;
  }

}
</style>